extends "res://scripts/foes/foe.gd"
## The Cliff Hound (version 43). The Game Bible: "lean grey wild dogs in packs that circle before lunging. They
## teach watching your sides", and (23 November) "a mix of pairs and packs of three or four".
##
## A hound runs up, then circles you at a few steps' distance, each going its own way round so a pack ends up on
## every side. One at a time (two, in a pack of four or more) a hound crouches, which is the warning, and lunges
## in a straight line. A hit while it crouches or as it comes knocks it out of the lunge. After a lunge it stands
## a moment, open.
##
## The ELITE is the pack's white, scarred leader: tougher, bites harder, and it HOWLS to call more hounds in
## ("so take it down first"). A hit while it howls cuts the howl off.

const Rest := preload("res://scripts/foes/pack.gd")

static var HP := 20.0
static var SPEED := 150.0            # circling
static var RUN := 195.0              # running up to you
static var BITE := 9.0
static var CROUCH_TIME := 0.5        # the warning before the lunge
static var LUNGE_SPEED := 560.0
static var LUNGE_DIST := 200.0
static var RING := 118.0             # how far from you it circles
static var REST_MIN := 1.6           # seconds between one hound's lunges, at least and at most
static var REST_MAX := 3.2
static var ELITE_HP := 75.0
static var ELITE_BITE := 13.0
static var HOWL_TIME := 1.1          # how long the howl takes (hit it to cut it off)
static var HOWL_EVERY := 13.0
static var HOWL_CALLS := 2           # hounds that answer one howl
static var HOWL_MOST := 3            # howls in one fight
const LOCK_TIME := 0.15              # the aim stops following you this long before it goes
const RECOVER_TIME := 0.65
const PACK_MOST := 5                 # a howl is not answered while this many hounds are already there

var side := 1.0                # which way round it circles
var ring_off := 0.0            # each hound keeps its own distance, a little nearer or farther
var rest := 1.0                # seconds until it may lunge again
var lunge_dir := Vector2.RIGHT
var lunge_left := 0.0
var struck := {}
var howl_in := 3.0             # the leader: seconds until its next howl
var _turned := 0.0


func _setup() -> void:
	kind = "hound"
	_stats()
	radius = 11.0
	contact_damage = 0.0
	knock_resist = 0.9 if not elite else 0.5
	color = Color("#8c8894") if not elite else Color("#e0e2d0")
	side = 1.0 if Sim.chance() < 0.5 else -1.0
	ring_off = Sim.between(-14.0, 18.0)
	rest = Sim.between(0.8, 2.2)
	howl_in = Sim.between(2.0, 3.0)
	add_to_group("hounds")


func _stats() -> void:
	max_hp = ELITE_HP if elite else HP
	speed = SPEED


func _bite() -> float:
	return ELITE_BITE if elite else BITE


## Hounds of this pack that are crouching or in the air right now.
func _lunging() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("hounds"):
		if is_instance_valid(e) and not e.dead and e.pack == pack and e.mode in ["crouch", "lunge"]:
			n += 1
	return n


func _pack_hounds() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("hounds"):
		if is_instance_valid(e) and not e.dead and e.pack == pack:
			n += 1
	return n


func _fight(delta: float) -> Vector2:
	var to_p: Vector2 = target.global_position - global_position
	var dist := to_p.length()
	_turned -= delta
	match mode:
		"idle":
			_set_mode("circle")
		"circle":
			rest -= delta
			if dist > 0.01:
				facing = to_p / dist
			if elite:
				howl_in -= delta
				if howl_in <= 0.0 and _may_howl():
					_set_mode("howl", HOWL_TIME)
					Sfx.play(self, "rumble", -13.0, 2.6)
					return Vector2.ZERO
			var ring := RING + ring_off
			if dist > ring + 90.0 or not sees(target.global_position):
				return _go(target.global_position, RUN, delta)
			if rest <= 0.0 and dist < ring + 60.0 and _lunging() < (2 if _pack_hounds() >= 4 else 1):
				_set_mode("crouch", CROUCH_TIME)
				lunge_dir = facing
				Sfx.play(self, "warn", -15.0, 0.7)
				return Vector2.ZERO
			# Round the ring: sideways, and in or out to keep the distance. Meeting a wall, it turns back the other way.
			if get_slide_collision_count() > 0 and _turned <= 0.0:
				side = -side
				_turned = 0.7
			var v := facing.orthogonal() * side + facing * clampf((dist - ring) / 40.0, -1.0, 1.0)
			# And not on top of another hound.
			for e in allies():
				var gap: Vector2 = global_position - e.global_position
				if gap.length() < 46.0 and gap.length() > 0.1:
					v += gap.normalized() * 0.6
			return v.normalized() * speed
		"crouch":
			if mode_t > LOCK_TIME and dist > 0.01:
				facing = to_p / dist
			lunge_dir = facing
			if mode_t <= 0.0:
				_set_mode("lunge")
				lunge_left = LUNGE_DIST
				struck.clear()
				Sfx.play(self, "dodge", -8.0, 0.8)
		"lunge":
			lunge_left -= LUNGE_SPEED * delta
			for p in players():
				if struck.has(p.get_instance_id()):
					continue
				if p.global_position.distance_to(global_position) < radius + 16.0 + 4.0 and p.invuln <= 0.0:
					struck[p.get_instance_id()] = true
					p.take_damage(_bite(), global_position - lunge_dir * 20.0, self)
			if lunge_left <= 0.0 or (get_slide_collision_count() > 0 and lunge_left < LUNGE_DIST - 40.0):
				_recover(RECOVER_TIME)
				# A lunge that bit nobody: it is Open while it gathers itself (the Striker's word).
				if struck.is_empty():
					open_for(RECOVER_TIME)
				return Vector2.ZERO
			return lunge_dir * LUNGE_SPEED
		"recover":
			if mode_t <= 0.0:
				_set_mode("circle")
		"howl":
			if mode_t <= 0.0:
				_howl()
				_set_mode("circle")
	return Vector2.ZERO


func _recover(time: float) -> void:
	_set_mode("recover", time)
	rest = Sim.between(REST_MIN, REST_MAX)


func _may_howl() -> bool:
	if pack != null and pack.howls >= HOWL_MOST:
		return false
	return _pack_hounds() < PACK_MOST


## The howl is done: hounds come running, from out of sight where the land allows.
func _howl() -> void:
	howl_in = HOWL_EVERY
	if pack != null:
		pack.howls += 1
	var game = get_tree().get_first_node_in_group("game")
	for i in HOWL_CALLS:
		if _pack_hounds() >= PACK_MOST:
			break
		if game != null and game.has_method("call_foe"):
			game.call_foe(self, "hound")


## A hit knocks it out of a crouch or a lunge, and cuts a howl off.
func _on_hit() -> void:
	if mode in ["crouch", "lunge"]:
		_recover(0.4)
	elif mode == "howl":
		_set_mode("circle")
		howl_in = 5.0


func _stand_down() -> void:
	super._stand_down()
	howl_in = Sim.between(2.0, 3.0)


func _anim() -> Array:
	var strips: Dictionary = _art_info().get("strips", {})
	var hit_strip: Dictionary = strips.get("hit", {})
	if mode != "lunge" and not hit_strip.is_empty() and hit_anim < float(hit_strip["frames"]) / float(hit_strip["fps"]):
		return ["hit", hit_anim, false]
	match mode:
		"crouch":
			return ["crouch", 0.0 if mode_t > CROUCH_TIME * 0.5 else 0.2, false]
		"lunge":
			return ["lunge", 0.0 if lunge_left > LUNGE_DIST * 0.6 else 0.1, false]
		"recover":
			if mode_t > RECOVER_TIME - 0.2:
				return ["lunge", 0.2, false]
		"howl":
			return ["howl", HOWL_TIME - mode_t, false]
	if velocity.length() > 15.0:
		return ["move", anim_time, true]
	return ["idle", anim_time, true]
