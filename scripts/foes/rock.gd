extends Node2D
## What a Pebble Slinger throws (version 43). Darren's rule (23 November): slingers "keep their distance, throwing
## rocks from behind rubble or boulders", so a rock is LOBBED: it goes up and over whatever the slinger hides
## behind, and comes down on the spot the slinger aimed at. You see it in the air over its shadow, which runs
## along the ground to that spot and grows as the rock comes down (version 44); keep moving and it lands behind
## you. Nothing is marked on the ground (Darren, 23 November: "Not every enemy has to have telegraph markers for
## its moves, only bosses"): the shadow is the rock's own, under it, not a mark of where it will hurt.
##
## A pebble hurts whoever is on the spot when it lands. The elite's big rock does too, and then bursts: its shards
## fly out flat from where it landed, and each hurts the first player it meets.
##
## kind "pebble" or "rock": the lobbed thing. kind "shard": one flying piece of a burst rock.

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Foe := preload("res://scripts/foes/foe.gd")
const Sim := preload("res://scripts/sim.gd")

const ARC := 44.0              # how high a lobbed rock goes, in world units
const SHARD_SPEED := 300.0
const SHADOW := {"pebble": [3.0, 5.0], "rock": [4.0, 9.0]}     # half the shadow's width in art pixels: at the top of the arc, on the ground

var kind := "pebble"
var from := Vector2.ZERO
var to := Vector2.ZERO
var flight := 0.65
var damage := 7.0
var splash := 18.0             # whoever is within this of the spot is hit (world units)
var shards := 0                # the big rock: how many pieces it bursts into
var shard_damage := 5.0
var shard_reach := 110.0
var nav = null                 # where there is a map, a shard stops at rock
var by = null                  # the slinger that threw it (it may have fallen since)
var dir := Vector2.RIGHT       # a shard's heading
var left := 0.0                # a shard: how far it still flies
var t := 0.0
var done := false


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("hazards")
	if kind == "shard":
		left = shard_reach
		return
	global_position = from


func _physics_process(delta: float) -> void:
	t += delta
	if kind == "shard":
		_fly_shard(delta)
		queue_redraw()
		return
	var k := clampf(t / flight, 0.0, 1.0)
	global_position = from.lerp(to, k)
	if not done and t >= flight:
		done = true
		_land()
		queue_free()
		return
	queue_redraw()


func _players() -> Array:
	var out: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.is_down:
			out.append(p)
	return out


## The slinger that threw it, if it is still standing.
func _thrower():
	return by if by != null and is_instance_valid(by) and not by.dead else null


func _land() -> void:
	var missed := true
	for p in _players():
		if p.global_position.distance_to(to) <= splash + 10.0:
			if p.invuln <= 0.0:
				missed = false
			p.take_damage(damage, to, _thrower())
	if missed and _thrower() != null and by.has_method("rock_missed"):
		by.rock_missed()
	if kind == "pebble":
		Sfx.play(self, "click", -9.0, 0.6)
		Foe.play_shot(self, "pebble_puff", to)
		return
	Sfx.play(self, "slam", -9.0, 1.6)
	var burst := Foe.play_shot(self, "rock_burst", to)
	if burst != null:
		burst.z_index = 0
	var turn := Sim.between(0.0, TAU)
	for i in shards:
		var s = get_script().new()
		s.kind = "shard"
		s.dir = Vector2.from_angle(turn + TAU * float(i) / float(shards))
		s.damage = shard_damage
		s.shard_reach = shard_reach
		s.nav = nav
		s.by = by
		get_parent().add_child(s)
		s.global_position = to + s.dir * 10.0
	for p in _players():
		if p.rig != null:
			p.rig.add_shake(3.0)
			break


func _fly_shard(delta: float) -> void:
	var step := SHARD_SPEED * delta
	global_position += dir * step
	left -= step
	for p in _players():
		if p.global_position.distance_to(global_position) <= 16.0 + 6.0 and p.invuln <= 0.0:
			p.take_damage(damage, global_position - dir * 12.0, _thrower())
			queue_free()
			return
	if left <= 0.0 or (nav != null and not nav.sees(global_position - dir * 4.0, global_position + dir * 4.0)):
		queue_free()


func _draw() -> void:
	if kind == "shard":
		if not Foe.draw_shot(self, "shard", int(t * 10.0) % 2, Vector2(0, -8.0), dir.angle()):
			draw_rect(Rect2(-3, -11, 6, 6), Color("#8c8894"))
		return
	var k := clampf(t / flight, 0.0, 1.0)
	var up := sin(k * PI) * ARC * (1.3 if kind == "rock" else 1.0)
	# Its own shadow on the ground under it (not a mark of where it will hurt): small and faint while the rock is
	# high, and growing broad and dark as it comes down, so you see it fall. Three rows, in whole art pixels.
	var near := 1.0 - sin(k * PI)
	var half := roundf(lerpf(SHADOW[kind][0] if SHADOW.has(kind) else 2.0, SHADOW[kind][1] if SHADOW.has(kind) else 5.0, near)) * Art.PIXEL
	var shade := Color(0.098, 0.078, 0.165, lerpf(0.35, 0.6, near))
	draw_rect(Rect2(-half + Art.PIXEL, -2.0 * Art.PIXEL, half * 2.0 - 2.0 * Art.PIXEL, Art.PIXEL), shade)
	draw_rect(Rect2(-half, -Art.PIXEL, half * 2.0, 2.0 * Art.PIXEL), shade)
	draw_rect(Rect2(-half + Art.PIXEL, Art.PIXEL, half * 2.0 - 2.0 * Art.PIXEL, Art.PIXEL), shade)
	var info := Foe.shot(kind)
	var frame := int(t * float(info.get("fps", 10))) if not info.is_empty() else 0
	if not Foe.draw_shot(self, kind, frame, Vector2(0, -up - 10.0)):
		draw_rect(Rect2(-4, -up - 14.0, 8, 8), Color("#8c8894"))
