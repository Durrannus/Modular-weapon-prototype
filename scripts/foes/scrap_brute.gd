extends "res://scripts/foes/foe.gd"
## The Scrap Brute (version 43). The Game Bible: "a bigger, tanky goblin with a battered shield made from old
## forge scrap. It blocks from the front, so hit it from behind or after it swings." Darren, 23 November:
## "uncommon so the shield doesn't get annoying. Usually one at a time."
##
## It walks at you behind its shield and turns to keep the shield on you, but it turns slowly. A blow that comes
## at the shield does nothing (BLOCKED). A blow from the side or behind lands. It raises its weapon (the
## warning), swings, and then for a second the shield hangs at its side and the weapon is on the ground: it is
## OPEN, and a blow from anywhere lands. Stunned or staggered, its shield is down too.
##
## The ELITE has a bronze-plated shield and, every third attack, BASHES with it: a short charge, shield first,
## that knocks you a long way back. After the bash it is open like after a swing.

static var HP := 75.0
static var SPEED := 62.0
static var CLUB := 18.0
static var TURN := 2.6               # how fast it turns its shield towards you, in radians a second
static var GUARD := 65.0             # the shield covers this many degrees to each side of where it points
static var WINDUP := 0.65            # the weapon raised before the swing (a boulder on a pole, in the art since version 44)
static var OPEN := 1.0               # how long the shield is down after a swing
static var REACH := 56.0             # from its middle to the end of its weapon
static var ELITE_HP := 200.0
static var ELITE_CLUB := 22.0
static var BASH_EVERY := 3           # every this many attacks the elite bashes
static var BASH_WINDUP := 0.75
static var BASH_SPEED := 430.0
static var BASH_DIST := 170.0
static var BASH := 14.0
static var BASH_PUSH := 640.0        # how hard a bash throws you back (a plain hit is 330)
const SWING_ARC := 1.25              # the swing reaches this far to each side of where it points (radians)
const SWING_TIME := 0.3
const LOCK_TIME := 0.2

var attacks := 0               # how many it has made (the elite counts to its bash)
var cool := 0.6                # seconds before it may attack again
var bash_dir := Vector2.RIGHT
var bash_left := 0.0
var struck := {}
var swung := false
var swing_missed := false           # its last swing hit nobody
var block_anim := 9.0          # seconds since a blow last landed on the shield
var _blocked_tick := -1


func _setup() -> void:
	kind = "scrap_brute"
	_stats()
	radius = 16.0
	contact_damage = 0.0
	knock_resist = 0.3 if not elite else 0.15
	color = Color("#c9923a")
	cool = Sim.between(0.4, 0.9)
	add_to_group("goblins")


func _stats() -> void:
	max_hp = ELITE_HP if elite else HP
	speed = SPEED


## Is the shield up?
func guarding() -> bool:
	return not dead and stun_time <= 0.0 and staggered <= 0.0 and mode in ["idle", "advance", "windup", "bash_windup", "bash"]


## Would a blow travelling in direction `dir` land on the shield? (A blow from above, with no direction, never does.)
func blocks(dir: Vector2) -> bool:
	if not guarding() or dir.length() < 0.01:
		return false
	return absf(facing.angle_to(-dir)) <= deg_to_rad(GUARD)


func _physics_process(delta: float) -> void:
	block_anim += delta
	super._physics_process(delta)


func _turn_to(dir: Vector2, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var by := clampf(facing.angle_to(dir), -TURN * delta, TURN * delta)
	facing = facing.rotated(by).normalized()


func _fight(delta: float) -> Vector2:
	var to_p: Vector2 = target.global_position - global_position
	var dist := to_p.length()
	match mode:
		"idle":
			_set_mode("advance")
		"advance":
			cool -= delta
			_turn_to(to_p, delta)
			var facing_it := dist > 0.01 and absf(facing.angle_to(to_p)) < 0.5
			if cool <= 0.0 and facing_it:
				if elite and attacks % BASH_EVERY == BASH_EVERY - 1 and dist < BASH_DIST + 30.0 and sees(target.global_position):
					_set_mode("bash_windup", BASH_WINDUP)
					bash_dir = facing
					Sfx.play(self, "warn", -11.0, 0.6)
					return Vector2.ZERO
				if dist < REACH + 8.0:
					_set_mode("windup", WINDUP)
					Sfx.play(self, "warn", -13.0, 0.8)
					return Vector2.ZERO
			if dist > REACH - 6.0:
				return _go(target.global_position, speed, delta)
		"windup":
			if mode_t > WINDUP - LOCK_TIME:
				_turn_to(to_p, delta)
			if mode_t <= 0.0:
				_set_mode("swing", SWING_TIME)
				swung = false
		"swing":
			if not swung and mode_t <= SWING_TIME - 0.1:
				swung = true
				attacks += 1
				Sfx.play(self, "swing", -6.0, 0.6)
				swing_missed = true
				for p in players():
					var rel: Vector2 = p.global_position - global_position
					if rel.length() < REACH + 16.0 and absf(facing.angle_to(rel)) <= SWING_ARC:
						if p.can_be_hit(self):
							swing_missed = false
						p.take_damage(ELITE_CLUB if elite else CLUB, global_position, self)
			if mode_t <= 0.0:
				_set_mode("open", OPEN)
				# A swing that hit nobody: it is Open (the Striker's word) for the second its shield is down.
				if swing_missed:
					open_for(OPEN)
		"open":
			if mode_t <= 0.0:
				_set_mode("advance")
				cool = 0.5
		"bash_windup":
			if mode_t > LOCK_TIME:
				_turn_to(to_p, delta * 2.0)
			bash_dir = facing
			if mode_t <= 0.0:
				_set_mode("bash")
				bash_left = BASH_DIST
				struck.clear()
				attacks += 1
				Sfx.play(self, "dodge", -5.0, 0.6)
		"bash":
			bash_left -= BASH_SPEED * delta
			for p in players():
				if struck.has(p.get_instance_id()):
					continue
				if p.global_position.distance_to(global_position) < radius + 16.0 + 6.0 and p.can_be_hit(self):
					struck[p.get_instance_id()] = true
					var before: float = p.hp
					p.take_damage(BASH, global_position - bash_dir * 20.0, self)
					if p.hp < before or p.knocked_out_timer > 0.0:
						p.hurt_vel = bash_dir * BASH_PUSH
						Sfx.play(self, "anvil", -12.0, 0.7)
			if bash_left <= 0.0 or (get_slide_collision_count() > 0 and bash_left < BASH_DIST - 40.0):
				_set_mode("open", OPEN + 0.2)
				if struck.is_empty():
					open_for(OPEN + 0.2)
				return Vector2.ZERO
			return bash_dir * BASH_SPEED
	return Vector2.ZERO


func take_hit(dmg: float, dir: Vector2, knockback: float, crit: bool, num_color: Color, stun := 0.0, freeze_time := 0.0) -> void:
	if dead or immune:
		return
	if warded <= 0.0 and blocks(dir):
		if pack != null:
			pack.wake()
		_blocked_tick = Engine.get_physics_frames()
		block_anim = 0.0
		_say("BLOCKED", Color("#e0e2d0"))
		Sfx.play(self, "anvil", -15.0, 1.5)
		Sfx.play(self, "click", -8.0, 0.5)
		return
	super.take_hit(dmg, dir, knockback, crit, num_color, stun, freeze_time)


## What rides on a blow the shield stopped (a stun, a stagger, a burn) is stopped with it.
func _just_blocked() -> bool:
	return _blocked_tick == Engine.get_physics_frames()


func add_stagger(points: float) -> bool:
	return false if _just_blocked() else super.add_stagger(points)


func apply_stun(duration: float) -> void:
	if not _just_blocked():
		super.apply_stun(duration)


func apply_burn(damage_per_tick: float, duration: float) -> void:
	if not _just_blocked():
		super.apply_burn(damage_per_tick, duration)


func apply_slow(amount: float, duration: float) -> void:
	if not _just_blocked():
		super.apply_slow(amount, duration)


## Nothing but a stun stops its swing or its bash.
func _on_hit() -> void:
	if mode in ["bash_windup", "bash"]:
		hit_stun = 0.0
		knock = Vector2.ZERO


func _stand_down() -> void:
	super._stand_down()
	cool = 0.6


func _anim() -> Array:
	var strips: Dictionary = _art_info().get("strips", {})
	var block_strip: Dictionary = strips.get("block", {})
	if not block_strip.is_empty() and block_anim < float(block_strip["frames"]) / float(block_strip["fps"]) and guarding():
		return ["block", block_anim, false]
	var hit_strip: Dictionary = strips.get("hit", {})
	if not mode in ["bash", "bash_windup"] and not hit_strip.is_empty() and hit_anim < float(hit_strip["frames"]) / float(hit_strip["fps"]):
		return ["hit", hit_anim, false]
	match mode:
		"windup":
			return ["windup", anim_time, true]
		"swing":
			return ["swing", SWING_TIME - mode_t, false]
		"open":
			return ["open", anim_time, true]
		"bash_windup":
			return ["bash_windup", anim_time, true]
		"bash":
			return ["bash", 0.0 if bash_left > BASH_DIST * 0.5 else 0.1, false]
	if _starry() and strips.has("open"):
		return ["open", anim_time, true]
	if velocity.length() > 10.0:
		return ["move", anim_time, true]
	return ["idle", anim_time, true]
