extends "res://scripts/foes/creature.gd"
## The moor boar (version 63; the Art builder's moor sheet). Neutral (creature.gd): it roots about its home and
## leaves you alone. Hit it and it turns on you: it trots up, and once you are near enough and in sight it PAWS THE
## GROUND (the warning: no mark on the floor) and CHARGES in a straight line, throwing whoever it meets. It does
## not stop for blows while it paws. Missing, it stands a moment to gather itself, Open; charging into rock, it
## stands dazed for longer, Open too. (Claude's numbers.)

static var HP := 40.0
static var TROT := 95.0              # going after you
static var GORE := 12.0              # what its charge does
static var WINDUP := 0.6             # pawing the ground before it charges (the warning)
static var CHARGE_SPEED := 430.0
static var CHARGE_DIST := 230.0
static var CHARGE_FROM := 210.0      # it charges once you are this near, with no rock between
static var PUSH := 520.0             # how hard the charge throws you (a plain hit is 330)
static var COOL_MIN := 1.2           # seconds between charges, at least and at most
static var COOL_MAX := 2.4
static var DAZED := 1.1              # seconds it stands dazed after charging into rock
const LOCK_TIME := 0.15              # its aim stops following you this long before it goes
const RECOVER_TIME := 0.7

var cool := 0.8
var rush_dir := Vector2.RIGHT
var charge_left := 0.0
var struck := {}


func _setup() -> void:
	kind = "boar"
	_stats()
	radius = 14.0
	contact_damage = 0.0
	knock_resist = 0.5
	color = Color("#5a3c4c")
	add_to_group("creatures")


func _stats() -> void:
	max_hp = HP
	speed = TROT


func _fight(delta: float) -> Vector2:
	var to_p: Vector2 = target.global_position - global_position
	var dist := to_p.length()
	match mode:
		"idle", "amble", "display":
			_set_mode("trot")
			cool = Sim.between(0.4, 0.9)
		"trot":
			cool -= delta
			if dist > 0.01:
				facing = to_p / dist
			if cool <= 0.0 and dist < CHARGE_FROM and sees(target.global_position):
				_set_mode("windup", WINDUP)
				rush_dir = facing
				Sfx.play(self, "warn", -13.0, 0.55)
				return Vector2.ZERO
			if dist > 54.0 or not sees(target.global_position):
				return _go(target.global_position, speed, delta)
		"windup":
			if mode_t > LOCK_TIME and dist > 0.01:
				facing = to_p / dist
			rush_dir = facing
			if mode_t <= 0.0:
				_set_mode("charge")
				charge_left = CHARGE_DIST
				struck.clear()
				Sfx.play(self, "dodge", -7.0, 0.6)
		"charge":
			charge_left -= CHARGE_SPEED * delta
			for p in players():
				if struck.has(p.get_instance_id()):
					continue
				if p.global_position.distance_to(global_position) < radius + 16.0 + 4.0 and p.can_be_hit(self):
					struck[p.get_instance_id()] = true
					p.take_damage(GORE, global_position - rush_dir * 20.0, self)
					if "hurt_vel" in p:
						p.hurt_vel = rush_dir * PUSH
			if get_slide_collision_count() > 0 and charge_left < CHARGE_DIST - 30.0:
				# Into rock (or something as solid): it stands dazed, Open.
				_set_mode("dazed", DAZED)
				open_for(DAZED)
				Sfx.play(self, "thud", -8.0, 0.7)
				return Vector2.ZERO
			if charge_left <= 0.0:
				_set_mode("recover", RECOVER_TIME)
				if struck.is_empty():
					open_for(RECOVER_TIME)
				return Vector2.ZERO
			return rush_dir * CHARGE_SPEED
		"recover", "dazed":
			if mode_t <= 0.0:
				_set_mode("trot")
				cool = Sim.between(COOL_MIN, maxf(COOL_MAX, COOL_MIN))
	return Vector2.ZERO


func _anim() -> Array:
	if mode != "charge" and _hit_showing():
		return ["hit", hit_anim, false]
	match mode:
		"windup":
			return ["charge_windup", WINDUP - mode_t, true]
		"charge":
			return ["charge", anim_time, true]
		"dazed":
			return ["hit", 0.1, false]
	return _walk_or_stand()
