extends "res://scripts/enemy.gd"
## The forge guardian: the tutorial's boss. A statue until the rune is fitted.
##
## Two attacks, both warned on the ground first:
## - Slam: it walks up, raises both fists (a red circle fills), then smashes.
## - Charge: it lowers a shoulder (a red lane shows the path), then runs until
##   it hits a wall. Hitting the wall stuns it: that's the opening.
## Below half health the slam comes three times in a row and the charge is faster.
## With two players it has more health and also brings rocks down on everyone.

const Hazard := preload("res://scripts/cave/hazard.gd")

signal woke
signal defeated(guardian)

const SLAM_RADIUS := 92.0
const SLAM_DAMAGE := 15.0
const CHARGE_DAMAGE := 18.0
const CHARGE_SPEED := 620.0
const ROCK_DAMAGE := 12.0

var mode := "dormant"
var mode_t := 0.0
var attacks := 0
var slams_left := 0
var charge_struck := {}
var charge_time := 0.0
var lane: Node2D = null
var team := 1               # how many players (set by the cave)
var rage := false           # below half health
var room := Rect2()         # it never leaves the forge room


func _setup() -> void:
	kind = "guardian"
	art_set = "cave"
	max_hp = 300.0
	speed = 64.0
	radius = 30.0
	contact_damage = 0.0
	knock_resist = 0.06
	show_bar = false
	immune = true
	color = Color("#7f8aa8")


func _feet() -> Vector2:
	return Vector2(0, 24)


func wake() -> void:
	if mode != "dormant":
		return
	mode = "wake"
	mode_t = 0.9
	anim_time = 0.0
	Sfx.play(self, "rumble", -2.0)


func _set_mode(m: String, time: float) -> void:
	mode = m
	mode_t = time
	anim_time = 0.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	if mode == "dormant":
		flash = 0.0
		return
	super._physics_process(delta)
	if room.size != Vector2.ZERO:
		var inner := room.grow(-radius)
		global_position = Vector2(clampf(global_position.x, inner.position.x, inner.end.x), clampf(global_position.y, inner.position.y, inner.end.y))


func _think(delta: float) -> Vector2:
	mode_t -= delta
	if not rage and hp <= max_hp * 0.5:
		rage = true
		_shake(10.0)
		Sfx.play(self, "rumble", -4.0, 1.3)
	var to_p := Vector2.ZERO
	if target != null:
		to_p = target.global_position - global_position
	var dist := to_p.length()
	match mode:
		"wake":
			if mode_t <= 0.0:
				immune = false
				woke.emit()
				_set_mode("walk", 3.0)
		"walk":
			if target == null:
				return Vector2.ZERO
			if dist > 0.01:
				facing = to_p / dist
			# Every third attack is a charge; so is anyone standing far away.
			var want_charge := attacks % 3 == 2 or dist > 330.0
			if want_charge and mode_t < 2.4:
				_start_charge()
				return Vector2.ZERO
			if dist < 104.0 or mode_t <= 0.0:
				slams_left = 3 if rage else 1
				_start_slam()
				return Vector2.ZERO
			return facing * speed * (1.25 if rage else 1.0)
		"telegraph":
			if mode_t <= 0.0:
				_set_mode("slam", 0.34)
		"slam":
			if mode_t <= 0.0:
				slams_left -= 1
				if slams_left > 0 and target != null:
					# Again: a short hop toward whoever is nearest, then another.
					if dist > 0.01:
						facing = to_p / dist
					_set_mode("hop", 0.22)
				else:
					attacks += 1
					_set_mode("recover", 0.75 if not rage else 0.55)
		"hop":
			if mode_t <= 0.0:
				_start_slam()
				return Vector2.ZERO
			return facing * 430.0
		"recover":
			if mode_t <= 0.0:
				_set_mode("walk", 3.0)
		"charge_ready":
			# It tracks you while it winds up, then commits.
			if mode_t > 0.3 and dist > 0.01:
				facing = to_p / dist
				charge_dir = facing
				if is_instance_valid(lane):
					lane.dir = charge_dir
					lane.length = _lane_length()
			if mode_t <= 0.0:
				_set_mode("charge", 1.6)
				charge_struck.clear()
				charge_time = 0.0
				Sfx.play(self, "dodge", -2.0, 0.5)
		"charge":
			charge_time += delta
			for p in players():
				if charge_struck.has(p.get_instance_id()):
					continue
				if p.global_position.distance_to(global_position) < radius + 16.0 + 6.0 and p.invuln <= 0.0:
					charge_struck[p.get_instance_id()] = true
					p.take_damage(CHARGE_DAMAGE, global_position - charge_dir * 30.0)
			var hit_wall := false
			for i in get_slide_collision_count():
				var c := get_slide_collision(i)
				if c.get_collider() is StaticBody2D and c.get_normal().dot(charge_dir) < -0.5:
					hit_wall = true
			if room.size != Vector2.ZERO and charge_time > 0.1:
				var inner := room.grow(-radius - 1.0)
				if not inner.has_point(global_position + charge_dir * 4.0):
					hit_wall = true
			if hit_wall and charge_time > 0.1:
				attacks += 1
				_shake(12.0)
				Sfx.play(self, "slam", -2.0, 0.8)
				_dust_burst()
				stun_time = 0.0
				_set_mode("stunned", 2.4 if not rage else 2.0)
				return Vector2.ZERO
			if mode_t <= 0.0:
				attacks += 1
				_set_mode("recover", 0.6)
				return Vector2.ZERO
			return charge_dir * CHARGE_SPEED * (1.15 if rage else 1.0)
		"stunned":
			if mode_t <= 0.0:
				if team > 1:
					_rock_rain()
				_set_mode("walk", 3.0)
	return Vector2.ZERO


func _start_slam() -> void:
	var time := 0.75 if slams_left == (3 if rage else 1) else 0.48
	_set_mode("telegraph", time)
	var h := Hazard.new()
	h.radius = SLAM_RADIUS
	h.delay = time
	h.damage = SLAM_DAMAGE
	get_parent().add_child(h)
	h.global_position = _slam_point()


func _slam_point() -> Vector2:
	return global_position + _feet() + Vector2(0, -8) + facing * 26.0


func _start_charge() -> void:
	_set_mode("charge_ready", 1.0 if not rage else 0.8)
	charge_dir = facing
	lane = Hazard.new()
	lane.shape = "lane"
	lane.dir = charge_dir
	lane.width = radius * 2.0 + 12.0
	lane.length = _lane_length()
	lane.delay = mode_t
	lane.follow = self
	get_parent().add_child(lane)
	lane.global_position = global_position
	Sfx.play(self, "warn", -6.0, 0.6)


## How far the charge will run before a wall, for the warning lane.
func _lane_length() -> float:
	if room.size == Vector2.ZERO:
		return 600.0
	var inner := room.grow(-radius)
	var best := 1400.0
	if charge_dir.x > 0.001:
		best = minf(best, (inner.end.x - global_position.x) / charge_dir.x)
	elif charge_dir.x < -0.001:
		best = minf(best, (inner.position.x - global_position.x) / charge_dir.x)
	if charge_dir.y > 0.001:
		best = minf(best, (inner.end.y - global_position.y) / charge_dir.y)
	elif charge_dir.y < -0.001:
		best = minf(best, (inner.position.y - global_position.y) / charge_dir.y)
	return maxf(best + radius, 60.0)


## Two players: rocks come down where each of them stands, plus a couple nearby.
func _rock_rain() -> void:
	Sfx.play(self, "rumble", -6.0, 1.2)
	_shake(6.0)
	var spots: Array = []
	for p in players():
		spots.append(p.global_position)
		spots.append(p.global_position + Vector2(randf_range(-150, 150), randf_range(-110, 110)))
	for i in spots.size():
		var h := Hazard.new()
		h.radius = 58.0
		h.delay = 1.0 + 0.12 * i
		h.damage = ROCK_DAMAGE
		h.impact = "rock"
		get_parent().add_child(h)
		var pos: Vector2 = spots[i]
		if room.size != Vector2.ZERO:
			var inner := room.grow(-40.0)
			pos = Vector2(clampf(pos.x, inner.position.x, inner.end.x), clampf(pos.y, inner.position.y, inner.end.y))
		h.global_position = pos


func _shake(amount: float) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.rig != null:
			p.rig.add_shake(amount)
			return


func _dust_burst() -> void:
	var tex := Art.texture("cave/dust_puff.png")
	if tex == null:
		return
	for i in 6:
		var n := SpriteOnce.new()
		n.texture = tex
		n.frames = 4
		n.fps = 10.0
		n.origin = Vector2(8, 10)
		n.size = 1.5
		get_parent().add_child(n)
		n.z_index = 0
		n.global_position = global_position + charge_dir * radius + Vector2(randf_range(-30, 30), randf_range(-20, 30))


## Nothing staggers it; hits only flash it.
func _on_hit() -> void:
	hit_stun = 0.0
	freeze = 0.0
	stun_time = 0.0


func apply_stun(_duration: float) -> void:
	pass


func _die() -> void:
	dead = true
	if is_instance_valid(lane):
		lane.queue_free()
	Sfx.play(self, "rumble", -2.0, 0.8)
	_shake(14.0)
	defeated.emit(self)
	died.emit(self)
	# The crumble plays out and the rubble stays.
	mode = "dead"
	anim_time = 0.0
	remove_from_group("enemies")
	remove_from_group("foes")
	collision_layer = 0
	collision_mask = 0
	z_index = -1


func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()


func _anim() -> Array:
	match mode:
		"dormant":
			return ["dormant", 0.0, false]
		"wake":
			return ["wake", anim_time * 0.75, false]
		"dead":
			return ["death", anim_time, false]
		"telegraph":
			# Fists up; the last frame (white) just before they come down.
			return ["telegraph", 0.0 if mode_t > 0.3 else (0.17 if mode_t > 0.1 else 0.34), false]
		"slam":
			return ["slam", anim_time, false]
		"charge_ready":
			return ["charge_ready", anim_time, true]
		"charge":
			return ["charge", anim_time, true]
		"stunned":
			return ["stunned", anim_time, true]
	if hit_anim < 0.12 and mode != "hop":
		return ["hit", hit_anim, false]
	if velocity.length() > 15.0:
		return ["move", anim_time, true]
	return ["idle", anim_time, true]


func _draw() -> void:
	if mode == "dead":
		flash = 0.0
	super._draw()
