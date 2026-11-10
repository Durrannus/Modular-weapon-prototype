extends "res://scripts/enemy.gd"
## Burrower: teaches dodging. It travels underground as a mound (it can't be
## hurt), comes up near you, flashes a warning, then lunges in a straight line.
## If the lunge misses it lies stunned and open. Hitting it does not stop the
## lunge, so the dodge is the answer.

const LUNGE_DAMAGE := 12.0
const LUNGE_SPEED := 540.0
const LUNGE_DIST := 240.0
const WARN_TIME := 0.7
const LOCK_TIME := 0.18       # the aim stops following you this long before it goes
const STUN_MISS := 1.5
const STUN_HIT := 0.7
const SURFACE_AT := 170.0     # how close it comes before surfacing

var mode := "burrowed"
var mode_t := 1.0
var lunge_dir := Vector2.RIGHT
var lunge_left := 0.0
var struck := {}
var hit_someone := false


func _setup() -> void:
	kind = "burrower"
	art_set = "cave"
	lift = 1.4   # the rooms they live in are dark; with the lit rim in the art this is enough
	max_hp = 18.0
	speed = 105.0
	radius = 12.0
	contact_damage = 0.0
	color = Color("#9a5fd0")
	mode_t = randf_range(0.8, 1.4)


func _ready() -> void:
	super._ready()
	_go_under()


func _go_under() -> void:
	mode = "burrowed"
	mode_t = randf_range(1.0, 1.8)
	immune = true
	# Underground it isn't a target for swings or runes, and slips past the others.
	if is_in_group("enemies"):
		remove_from_group("enemies")
	collision_mask = 4
	collision_layer = 0


func _come_up() -> void:
	mode = "surface"
	mode_t = 0.4
	immune = false
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 2 | 4
	_puff()


func _puff() -> void:
	var tex := Art.texture("cave/dust_puff.png")
	if tex == null:
		return
	for i in 3:
		var n := SpriteOnce.new()
		n.texture = tex
		n.frames = 4
		n.fps = 12.0
		n.origin = Vector2(8, 10)
		get_parent().add_child(n)
		n.z_index = 0
		n.global_position = global_position + Vector2(randf_range(-14, 14), randf_range(2, 14))


func _think(delta: float) -> Vector2:
	mode_t -= delta
	if target == null:
		return Vector2.ZERO
	var to_p: Vector2 = target.global_position - global_position
	var dist := to_p.length()
	match mode:
		"burrowed":
			if dist > 0.01:
				facing = to_p / dist
			if dist < SURFACE_AT and mode_t <= 0.0:
				_come_up()
				return Vector2.ZERO
			if dist < SURFACE_AT - 30.0:
				return -facing * speed * 0.6   # too close: back off before coming up
			return facing * speed if dist > SURFACE_AT - 10.0 else Vector2.ZERO
		"surface":
			if dist > 0.01:
				facing = to_p / dist
			if mode_t <= 0.0:
				mode = "warn"
				mode_t = WARN_TIME
				Sfx.play(self, "warn", -10.0)
		"warn":
			if mode_t > LOCK_TIME and dist > 0.01:
				facing = to_p / dist
			lunge_dir = facing
			if mode_t <= 0.0:
				mode = "lunge"
				lunge_left = LUNGE_DIST
				struck.clear()
				hit_someone = false
				Sfx.play(self, "dodge", -6.0, 0.7)
		"lunge":
			lunge_left -= LUNGE_SPEED * delta
			for p in players():
				if struck.has(p.get_instance_id()):
					continue
				if p.global_position.distance_to(global_position) < radius + 16.0 + 4.0 and p.invuln <= 0.0:
					struck[p.get_instance_id()] = true
					hit_someone = true
					p.take_damage(LUNGE_DAMAGE, global_position - lunge_dir * 20.0)
			if lunge_left <= 0.0 or get_slide_collision_count() > 0 and lunge_left < LUNGE_DIST - 40.0:
				mode = "stunned"
				mode_t = STUN_HIT if hit_someone else STUN_MISS
				return Vector2.ZERO
			return lunge_dir * LUNGE_SPEED
		"stunned":
			if mode_t <= 0.0:
				_puff()
				_go_under()
	return Vector2.ZERO


## Nothing interrupts the warning or the lunge.
func _on_hit() -> void:
	if mode == "warn" or mode == "lunge":
		hit_stun = 0.0
		knock = Vector2.ZERO


func _anim() -> Array:
	var strips: Dictionary = _art_info().get("strips", {})
	var hit_strip: Dictionary = strips.get("hit", {})
	if mode != "lunge" and not hit_strip.is_empty() and hit_anim < float(hit_strip["frames"]) / float(hit_strip["fps"]):
		return ["hit", hit_anim, false]
	match mode:
		"burrowed":
			return ["move", anim_time, true]
		"warn":
			return ["warn", anim_time, true]
		"lunge":
			return ["lunge", 0.08 if lunge_left > 30.0 else 0.16, false]
		"stunned":
			return ["stunned", anim_time, true]
	return ["idle", anim_time, true]


func _draw_shadow() -> void:
	if mode != "burrowed":
		super._draw_shadow()


func _draw() -> void:
	show_bar = mode != "burrowed"
	if mode == "warn":
		# Where the lunge will go: a thin red lane that firms up once the aim locks.
		var locked := mode_t <= LOCK_TIME
		var n := lunge_dir.orthogonal() * (radius + 6.0)
		var b := lunge_dir * LUNGE_DIST
		var a := 0.5 if locked else 0.22
		draw_colored_polygon(PackedVector2Array([-n, b - n, b + n, n]), Color(1.6, 0.3, 0.25, a * 0.5))
		draw_line(-n, b - n, Color(1.6, 0.3, 0.25, a + 0.3), 2.0)
		draw_line(n, b + n, Color(1.6, 0.3, 0.25, a + 0.3), 2.0)
	super._draw()
	if mode == "stunned":
		# Stars: it's open.
		for i in 3:
			var ang := Time.get_ticks_msec() / 150.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(ang), sin(ang) * 0.4) * radius * 0.9 + Vector2(0, -radius - 8.0), 2.5, Color(1.0, 0.95, 0.5))
