extends "res://scripts/foes/foe.gd"
## One bat of a Goblin Shaman's swarm (version 43): they "swoop and nip at you. Kill the shaman and the bats
## scatter."
##
## A bat flies (rock and boulders do not stop it). It flutters round you at a couple of steps' distance, then
## swoops straight through where you stand and nips if it meets you, and flutters again. One blow kills it. When
## its shaman dies, or the fight is over, it scatters: it flies off and is gone.

static var HP := 4.0
static var SPEED := 150.0
static var DIVE_SPEED := 350.0  # Darren's lab, 24 Nov (version 57; was 300.0)
static var NIP := 4.0
static var HOVER := 78.0             # how far from you it flutters
static var REST_MIN := 1.0           # seconds between its swoops (Darren's lab, version 57; was 1.6)
static var REST_MAX := 2.0  # Darren's lab, 24 Nov (version 57; was 2.8)
const FLY_HEIGHT := 22.0             # how far above its shadow it is drawn (world units)
const DIVE_PAST := 70.0              # a swoop carries on this far past where you stood

var shaman = null
var leaving := false
var side := 1.0
var rest := 1.0
var dive_dir := Vector2.RIGHT
var dive_left := 0.0
var nipped := false
var bob := 0.0
var flutter := 0.0                   # its own clock for the flutter (never the drawing's: that one starts by chance)


func _setup() -> void:
	kind = "bat"
	_stats()
	radius = 7.0
	contact_damage = 0.0
	knock_resist = 1.3
	show_bar = false
	color = Color("#4a4458")
	side = 1.0 if Sim.chance() < 0.5 else -1.0
	rest = Sim.between(0.9, 2.0)
	bob = Sim.between(0.0, TAU)
	_set_mode("hover")


func _ready() -> void:
	super._ready()
	# It flies: nothing on the ground stops it, and it does not shove the others about.
	collision_mask = 0
	collision_layer = 0
	add_to_group("bats")


func _stats() -> void:
	max_hp = HP
	speed = SPEED


func _think(delta: float) -> Vector2:
	mode_t -= delta
	flutter += delta
	if not fighting() or not is_instance_valid(shaman) or shaman.dead:
		scatter()
		return Vector2.ZERO
	if target == null:
		return Vector2.ZERO
	var to_p: Vector2 = target.global_position - global_position
	var dist := to_p.length()
	match mode:
		"hover":
			rest -= delta
			if dist > 0.01:
				facing = to_p / dist
			if rest <= 0.0 and dist < HOVER + 80.0:
				_set_mode("dive")
				dive_dir = facing
				dive_left = dist + DIVE_PAST
				nipped = false
				return Vector2.ZERO
			if dist > HOVER + 120.0:
				return facing * speed * 1.3
			var v := facing.orthogonal() * side + facing * clampf((dist - HOVER) / 30.0, -1.0, 1.0)
			return v.normalized() * speed * (0.8 + 0.2 * sin(flutter * 5.0 + bob))
		"dive":
			dive_left -= DIVE_SPEED * delta
			if not nipped:
				for p in players():
					if p.global_position.distance_to(global_position) < radius + 16.0 and p.can_be_hit(self):
						nipped = true
						p.take_damage(NIP, global_position - dive_dir * 10.0, self)
						break
			if dive_left <= 0.0:
				_set_mode("hover")
				rest = Sim.between(REST_MIN, REST_MAX)
				side = -side
				return Vector2.ZERO
			return dive_dir * DIVE_SPEED
	return Vector2.ZERO


## It scatters and is gone (its shaman died, or the fight is over). Nobody gets a kill for it.
func scatter() -> void:
	if leaving or dead:
		return
	leaving = true
	dead = true
	_puff()
	queue_free()


func _puff() -> void:
	var info: Dictionary = _art_info().get("strips", {}).get("puff", {})
	var tex := strip_tex(info.get("box"))
	if tex == null:
		return
	var n := SpriteOnce.new()
	n.texture = tex
	n.frames = int(info.get("frames", 3))
	n.fps = float(info.get("fps", 10))
	n.origin = Vector2(8, 8)
	get_parent().add_child(n)
	n.global_position = global_position + Vector2(0, -FLY_HEIGHT)


func _on_hit() -> void:
	if mode == "dive":
		_set_mode("hover")
		rest = Sim.between(REST_MIN, REST_MAX)


## A bat leaves no body: only the puff it goes in.
func _die() -> void:
	dead = true
	_puff()
	Sfx.play(self, "squish", -14.0, 1.8)
	died.emit(self)
	queue_free()


## It is drawn above its shadow, and its picture's origin is its middle.
func _feet() -> Vector2:
	return Vector2(0, -FLY_HEIGHT + sin(anim_time * 7.0 + bob) * 2.0)


func _head_y() -> float:
	return -FLY_HEIGHT - 10.0


func _draw_shadow() -> void:
	draw_rect(Rect2(-6, 4, 12, 4), Color(0.098, 0.078, 0.165, 0.35))


func _flip(_anim: String) -> bool:
	return (dive_dir.x if mode == "dive" else facing.x) < 0.0


func _anim() -> Array:
	if mode == "dive":
		return ["dive", anim_time, true]
	return ["fly", anim_time, true]
