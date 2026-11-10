extends CharacterBody2D

const WeaponBuild := preload("res://scripts/weapon/weapon_build.gd")
## Enemies. Set `kind` before adding to the scene:
## "slime" (chaser), "charger" (winds up and dashes), "brute" (slow and tough),
## "dummy" (training dummy: never moves, never dies).
## The cave's enemies (scripts/cave/) extend this and override _setup, _think,
## _anim and _on_hit.
##
## Being hit: the enemy freezes for a few frames (the hit "sticks"), is knocked
## back, and can't act for a moment (hit_stun). Nothing else in the game stops.

signal died(enemy)

const DamageNumber := preload("res://scripts/fx/damage_number.gd")
const Fx := preload("res://scripts/fx/fx.gd")
const Art := preload("res://scripts/art.gd")
const SpriteOnce := preload("res://scripts/fx/sprite_once.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Glow := preload("res://scripts/glow.gd")
const Warn := preload("res://scripts/fx/warn.gd")

var kind := "slime"
var max_hp := 30.0
var hp := 30.0
var speed := 85.0
var radius := 14.0
var color := Color(0.5, 0.9, 0.4)
var contact_damage := 10.0
var knock_resist := 1.0
var dead := false
var art_set := "enemies"   # "enemies": art/enemies + anchors.json. "cave": art/cave + cave.json
var show_bar := true       # small health bar over its head once hurt
var immune := false        # can't be hurt right now (burrowed, a statue)

var knock := Vector2.ZERO
var flash := 0.0
var flash_tint := 3.0     # how hard the sprite whites out when hit
var lift := 1.0           # sprite brightness; set above 1 for an enemy that sinks into a dark floor
var freeze := 0.0          # frozen on the frame it was hit
var hit_stun := 0.0        # can't move or attack after a hit
var burn_time := 0.0
var burn_tick := 0.0
var burn_damage := 2.0
var slow_time := 0.0
var slow_amount := 0.0
var stun_time := 0.0
var facing := Vector2.RIGHT
var anim_time := randf() * 2.0
var hit_anim := 99.0  # time since the last hit, while the hit animation plays
var target = null     # the player it's after: the nearest one still standing

# Training dummy: damage log for the damage-per-second readout.
const DPS_WINDOW := 3.0
var dps_log: Array = []  # [[time_seconds, damage], ...]

# Charger state
var state := "chase"
var state_timer := 0.0
var charge_dir := Vector2.RIGHT


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("foes")
	_setup()
	hp = max_hp
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 2 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	# Two extra surfaces the dark never dims: warnings painted on the floor under
	# everyone, and the health bar, stars and warnings on top of the sprite.
	_ground = Node2D.new()
	_ground.material = Art.unshaded()
	_ground.z_index = -5
	add_child(_ground)
	_ground.draw.connect(func(): _draw_ground(_ground))
	_over = Node2D.new()
	_over.material = Art.unshaded()
	add_child(_over)
	_over.draw.connect(func(): _draw_over(_over))


## Stats for this kind. Cave enemies override this.
func _setup() -> void:
	match kind:
		"charger":
			max_hp = 22.0
			speed = 120.0
			radius = 13.0
			color = Color(0.95, 0.45, 0.35)
			contact_damage = 14.0
		"brute":
			max_hp = 120.0
			speed = 52.0
			radius = 26.0
			color = Color(0.55, 0.45, 0.8)
			contact_damage = 20.0
			knock_resist = 0.3
		"dummy":
			max_hp = 100.0
			speed = 0.0
			radius = 18.0
			color = Color(0.7, 0.55, 0.35)
			contact_damage = 0.0
			knock_resist = 0.0
		_:
			pass


## Everyone still standing.
func players() -> Array:
	var out: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.is_down:
			out.append(p)
	return out


func nearest_player():
	var best = null
	var best_d := INF
	for p in players():
		var d: float = p.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _physics_process(delta: float) -> void:
	if dead:
		return
	flash = maxf(flash - delta, 0.0)
	hit_anim += delta
	if freeze > 0.0:
		freeze -= delta
		return
	slow_time = maxf(slow_time - delta, 0.0)
	stun_time = maxf(stun_time - delta, 0.0)
	hit_stun = maxf(hit_stun - delta, 0.0)
	_update_burn(delta)
	if kind == "dummy":
		return

	target = nearest_player()
	var desired := Vector2.ZERO
	if stun_time <= 0.0 and hit_stun <= 0.0:
		desired = _think(delta)
	if slow_time > 0.0:
		desired *= 1.0 - slow_amount
	if knock.length() > 60.0:
		desired *= 0.2
	knock = knock.move_toward(Vector2.ZERO, 1300.0 * delta)
	velocity = desired + knock
	move_and_slide()


## What it wants to do this tick: returns the velocity it wants. Not called while
## it's stunned or reeling from a hit.
func _think(delta: float) -> Vector2:
	if target == null:
		return Vector2.ZERO
	var to_p: Vector2 = target.global_position - global_position
	if to_p.length() > 0.01:
		facing = to_p.normalized()
	touch_damage()
	if kind == "charger":
		return _charger_ai(to_p, delta)
	return facing * speed


## Hurts any player it's touching.
func touch_damage(amount := -1.0, extra_reach := 0.0) -> bool:
	var dmg := contact_damage if amount < 0.0 else amount
	if dmg <= 0.0:
		return false
	var any := false
	for p in players():
		if p.global_position.distance_to(global_position) < radius + 16.0 + 2.0 + extra_reach and p.invuln <= 0.0:
			p.take_damage(dmg, global_position)
			any = true
	return any


func _charger_ai(to_p: Vector2, delta: float) -> Vector2:
	state_timer -= delta
	match state:
		"chase":
			if to_p.length() < 240.0 and state_timer <= 0.0:
				state = "windup"
				state_timer = 0.55
				return Vector2.ZERO
			return to_p.normalized() * speed
		"windup":
			charge_dir = to_p.normalized()
			if state_timer <= 0.0:
				state = "charge"
				state_timer = 0.35
			return Vector2.ZERO
		"charge":
			if state_timer <= 0.0:
				state = "rest"
				state_timer = 0.7
			return charge_dir * 560.0
		"rest":
			if state_timer <= 0.0:
				state = "chase"
				state_timer = 0.5
			return Vector2.ZERO
	return Vector2.ZERO


func _update_burn(delta: float) -> void:
	if burn_time <= 0.0:
		return
	burn_time -= delta
	burn_tick -= delta
	if burn_tick <= 0.0:
		burn_tick = 0.5
		_apply_damage(burn_damage, false, WeaponBuild.ELEMENT_COLORS["fire"])


## A hit from the player. num_color colours the damage number (by element).
## stun: how long it can't act afterwards. freeze_time: the hit-frame freeze.
func take_hit(dmg: float, dir: Vector2, knockback: float, crit: bool, num_color: Color, stun := 0.0, freeze_time := 0.0) -> void:
	if dead or immune:
		return
	flash = maxf(0.1, freeze_time + 0.05)
	hit_anim = 0.0
	knock = dir * knockback * knock_resist
	hit_stun = maxf(hit_stun, stun * minf(knock_resist * 1.5, 1.0))
	freeze = maxf(freeze, freeze_time)
	_on_hit()
	_apply_damage(dmg, crit, num_color)


## Called on every hit that lands. A good hit interrupts a charger's wind-up.
func _on_hit() -> void:
	if kind == "charger" and state == "windup":
		state = "rest"
		state_timer = 0.6


func apply_burn(damage_per_tick: float, duration: float) -> void:
	burn_damage = maxf(burn_damage if burn_time > 0.0 else 0.0, damage_per_tick)
	burn_time = maxf(burn_time, duration)


func apply_slow(amount: float, duration: float) -> void:
	slow_amount = amount
	slow_time = maxf(slow_time, duration)


func apply_stun(duration: float) -> void:
	if kind == "dummy" or knock_resist <= 0.0:
		return
	stun_time = maxf(stun_time, duration)


func _apply_damage(dmg: float, crit: bool, num_color: Color) -> void:
	hp -= dmg
	var n := DamageNumber.new()
	n.text = str(roundi(dmg)) + ("!" if crit else "")
	n.color = num_color
	n.font_size = 32 if crit else 16   # the pixel font is drawn for 8 screen pixels and its doubles
	get_parent().add_child(n)
	n.global_position = global_position + Vector2(randf_range(-8, 8), -radius - 6.0)
	if kind == "dummy":
		dps_log.append([Time.get_ticks_msec() / 1000.0, dmg])
		if hp <= 0.0:
			hp = max_hp
		return
	if hp <= 0.0:
		_die()


## Damage per second over the last few seconds (training dummy).
func current_dps() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	while not dps_log.is_empty() and now - float(dps_log[0][0]) > DPS_WINDOW:
		dps_log.pop_front()
	if dps_log.is_empty():
		return 0.0
	var total := 0.0
	for entry in dps_log:
		total += float(entry[1])
	var span := clampf(now - float(dps_log[0][0]), 1.0, DPS_WINDOW)
	return total / span


func _die() -> void:
	dead = true
	# What was awake goes back to green: a verdigris ring and bronze flakes.
	if Art.play_piece(self, "death_burst", global_position, 0.0, clampf(radius / 14.0, 0.8, 2.0)) == null:
		var b := Fx.new()
		b.kind = "burst"
		b.radius = radius * 1.6
		b.color = color
		b.life = 0.25
		get_parent().add_child(b)
		b.global_position = global_position
	var info := _art_info()
	var death := _art_tex("death")
	if death != null and info.get("strips", {}).has("death"):
		var splat := SpriteOnce.new()
		splat.texture = death
		splat.glow_texture = _art_tex("death_glow")
		splat.frames = int(info["strips"]["death"]["frames"])
		splat.fps = float(info["strips"]["death"]["fps"])
		splat.origin = Vector2(info["origin_feet"][0], info["origin_feet"][1])
		splat.feet = _feet()
		splat.flip = _flip("death")
		splat.z_index = 0
		get_parent().add_child(splat)
		splat.global_position = global_position
	Sfx.play(self, "squish", -9.0)
	died.emit(self)
	queue_free()


func _process(delta: float) -> void:
	if freeze <= 0.0:
		anim_time += delta
	_redraw()


## Everything this enemy draws: the sprite, its glow, and the two bright surfaces.
func _redraw() -> void:
	queue_redraw()
	_ground.queue_redraw()
	_over.queue_redraw()
	_update_glow()


# --- Drawing ------------------------------------------------------------------

func _art_info() -> Dictionary:
	if art_set == "cave":
		return Art.json("cave/cave.json").get("enemies", {}).get(kind, {})
	return Art.anchors().get("enemies", {}).get(kind, {})


func _art_tex(anim: String) -> Texture2D:
	if anim == "":
		return Art.texture("%s/%s.png" % [art_set, kind])
	return Art.texture("%s/%s_%s.png" % [art_set, kind, anim])


func _feet() -> Vector2:
	return Vector2(0, radius * 0.7)


## Sprites are drawn facing right and mirrored to look left. Front views say no.
func _flip(_anim: String) -> bool:
	return facing.x < 0.0


## The strip and frame to show right now: {tex, glow, frames, frame, origin, flip},
## or empty when this enemy has no sprite.
func _sprite() -> Dictionary:
	var info := _art_info()
	if info.is_empty() or not info.has("strips"):
		return {}
	var a := _anim()
	var anim: String = a[0]
	var strip: Dictionary = info["strips"].get(anim, {})
	if strip.is_empty():
		strip = Art.piece("%s_%s" % [kind, anim])   # strips drawn later live in art/gaps.json
	if strip.is_empty():
		anim = "idle"
		strip = info["strips"].get(anim, {})
	var tex := _art_tex(anim)
	var glow := _art_tex(anim + "_glow")
	if tex == null:
		tex = _art_tex("")
		glow = _art_tex("glow")
	if tex == null or strip.is_empty():
		return {}
	var frame := int(float(a[1]) * float(strip["fps"]))
	if not a[2]:
		frame = mini(frame, int(strip["frames"]) - 1)
	var o: Array = info["origin_feet"]
	return {"tex": tex, "glow": glow, "frames": int(strip["frames"]), "frame": frame, "origin": Vector2(o[0], o[1]), "flip": _flip(anim)}


var _glow: Node2D

## Eyes, embers and runes on the sprite stay bright in the dark (see glow.gd).
func _update_glow() -> void:
	var sp := _sprite()
	var tex: Texture2D = sp.get("glow")
	if tex == null and _glow == null:
		return
	if _glow == null:
		_glow = Glow.new()
		add_child(_glow)
	if tex == null or flash > 0.0:
		_glow.put(null)
	else:
		_glow.put(tex, sp["frames"], sp["frame"], _feet(), sp["origin"], sp["flip"])


## Which strip to show: [name, seconds into it, loops].
func _anim() -> Array:
	var strips: Dictionary = _art_info().get("strips", {})
	var hit_strip: Dictionary = strips.get("hit", {})
	if not hit_strip.is_empty() and hit_anim < float(hit_strip["frames"]) / float(hit_strip["fps"]):
		return ["hit", hit_anim, false]
	if kind == "charger" and state == "windup":
		return ["windup", anim_time, true]
	if velocity.length() > 15.0 and strips.has("move"):
		return ["move", anim_time, true]
	return ["idle", anim_time, true]


func _draw_shadow() -> void:
	var size := "s" if radius <= 14.0 else ("m" if radius <= 20.0 else ("l" if radius <= 30.0 else "xl"))
	if Art.draw_piece(self, "shadow_" + size, 0, _feet()):
		return
	draw_set_transform(_feet(), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


var _over: Node2D      # on top of the sprite, never dimmed
var _ground: Node2D    # on the floor under everyone, never dimmed

## How far a charger's dash carries it (its speed times its dash time).
const CHARGE_REACH := 560.0 * 0.35


## Warnings on the floor. The horned crab shows the lane it is about to dash down.
func _draw_ground(ci: CanvasItem) -> void:
	if kind == "charger" and state == "windup":
		Warn.lane(ci, "thin", state_timer < 0.15, Vector2.ZERO, charge_dir, CHARGE_REACH + radius, anim_time)


static var _tops: Dictionary = {}

## How high the top of its picture is above this node (world units, negative is up),
## so the bar and the stars sit over the head whatever its size.
func _head_y() -> float:
	var info := _art_info()
	var tex := _art_tex("idle")
	if tex == null or not info.has("origin_feet"):
		return -radius
	var key := "%s/%s" % [art_set, kind]
	if not _tops.has(key):
		var top := 0.0
		var img := tex.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			top = float(img.get_used_rect().position.y)
		_tops[key] = top
	var o: Array = info["origin_feet"]
	return minf(_feet().y - (float(o[1]) - float(_tops[key])) * Art.PIXEL, -radius)


## Is it reeling with stars round its head?
func _starry() -> bool:
	return stun_time > 0.0


## Stars and the health bar, above the head.
func _draw_over(ci: CanvasItem) -> void:
	if _starry():
		var stars := Art.piece("stun_stars")
		var n := int(stars.get("frames", 6))
		if not Art.draw_piece(ci, "stun_stars", int(Time.get_ticks_msec() / 1000.0 * float(stars.get("fps", 10))) % maxi(n, 1), Vector2(0, _head_y() - 4.0)):
			for i in 3:
				var ang := Time.get_ticks_msec() / 150.0 + i * TAU / 3.0
				ci.draw_circle(Vector2(cos(ang), sin(ang) * 0.4) * radius * 0.8 + Vector2(0, -radius - 6.0), 2.5, Color(1.0, 0.95, 0.5))
	if show_bar and hp < max_hp and kind != "dummy" and not dead:
		_draw_bar(ci)


func _draw_bar(ci: CanvasItem) -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	var fill := Art.piece_texture("enemy_bar_fill")
	# In art pixels: the frame is a nine-patch with a 2 px edge, the fill sits 2 in and 1 down.
	var w := clampf(roundf(radius * 1.2), 14.0, 40.0)
	var at := Vector2(-w, _head_y() - 18.0 - (12.0 if _starry() else 0.0))
	ci.draw_set_transform(at, 0.0, Vector2(Art.PIXEL, Art.PIXEL))
	if fill != null and Art.draw_nine(ci, "hud/enemy_bar_frame.png", Rect2(0, 0, w, 5), 2):
		var fw := roundf((w - 4.0) * frac)
		if fw > 0.0:
			ci.draw_texture_rect_region(fill, Rect2(2, 1, fw, 3), Rect2(0, 0, 22.0 * frac, 3))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var ww := radius * 2.0
	ci.draw_rect(Rect2(-ww * 0.5, -radius - 10.0, ww, 4.0), Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(-ww * 0.5, -radius - 10.0, ww * frac, 4.0), Color(0.9, 0.25, 0.25))


func _draw() -> void:
	var c := color
	if burn_time > 0.0:
		c = c.lerp(WeaponBuild.ELEMENT_COLORS["fire"], 0.45)
	elif slow_time > 0.0:
		c = c.lerp(WeaponBuild.ELEMENT_COLORS["water"], 0.4)
	if flash > 0.0:
		c = Color.WHITE

	_draw_shadow()
	var sp := _sprite()
	if sp.is_empty():
		_draw_shape(c)
	else:
		var tint := Color(lift, lift, lift)
		if flash > 0.0:
			tint = Color(flash_tint, flash_tint, flash_tint)
		elif burn_time > 0.0:
			tint *= Color(1.0, 0.7, 0.55)
		elif slow_time > 0.0:
			tint *= Color(0.65, 0.8, 1.0)
		Art.draw_strip(self, sp["tex"], sp["frames"], sp["frame"], _feet(), sp["origin"], sp["flip"], tint)

	if kind == "dummy":
		var dps := current_dps()
		if dps > 0.0:
			var font := Art.font("Silkscreen-Regular")
			var label := "DPS %.1f" % dps
			draw_string_outline(font, Vector2(-60, -radius - 14.0), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 8, Color(0.06, 0.04, 0.09))
			draw_string(font, Vector2(-60, -radius - 14.0), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color("#ffc850"))


## Stand-in shapes until the enemy sprites land.
func _draw_shape(c: Color) -> void:
	match kind:
		"charger":
			var tip := facing * (radius + 6.0)
			var side := facing.orthogonal() * radius
			draw_colored_polygon(PackedVector2Array([tip, -facing * radius + side, -facing * radius - side]), c)
			if state == "windup":
				var pulse := 0.5 + 0.5 * sin(state_timer * 40.0)
				draw_line(Vector2.ZERO, charge_dir * 200.0, Color(1, 0.2, 0.2, 0.3 + 0.4 * pulse), 4.0)
		"dummy":
			draw_circle(Vector2.ZERO, radius, c)
			draw_line(Vector2(-radius, 0), Vector2(radius, 0), c.darkened(0.4), 3.0)
			draw_line(Vector2(0, -radius), Vector2(0, radius), c.darkened(0.4), 3.0)
		_:
			draw_circle(Vector2.ZERO, radius, c)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, c.darkened(0.4), 2.5)
			draw_circle(facing * radius * 0.45, radius * 0.18, Color(0.1, 0.1, 0.1))
