extends "res://scripts/foes/creature.gd"
## The capercaillie, the big moor grouse (version 63; the Art builder's moor sheet). Neutral and timid
## (creature.gd): it pecks and struts about its home and now and then fans its tail. Hit it, or one of its group,
## and it RUNS OFF FLAPPING, away from whoever is nearest, until nobody is within SAFE; there it stands, wary, and
## runs again if you come on. It never fights. (Claude's numbers.)

static var HP := 10.0
static var SPEED := 70.0             # strutting
static var FLEE := 175.0             # running off
static var SAFE := 300.0             # it runs until nobody is this near
static var DISPLAY := 0.25           # of its stops, the share where it fans its tail
const DISPLAY_TIME := 2.0


func _setup() -> void:
	kind = "capercaillie"
	timid = true
	_stats()
	radius = 10.0
	contact_damage = 0.0
	knock_resist = 1.0
	color = Color("#2c2a34")
	add_to_group("creatures")


func _stats() -> void:
	max_hp = HP
	speed = SPEED


func _fight(delta: float) -> Vector2:
	var to_p: Vector2 = target.global_position - global_position
	var dist := to_p.length()
	match mode:
		"idle", "amble", "display":
			_set_mode("flee")
		"flee":
			if dist >= SAFE:
				_set_mode("wary")
				return Vector2.ZERO
			var v := _away(target.global_position, delta)
			if v.length() > 0.01:
				facing = v.normalized()
			return v * FLEE
		"wary":
			if dist > 0.01:
				facing = -to_p / dist
			if dist < SAFE * 0.75:
				_set_mode("flee")
	return Vector2.ZERO


## Some of its stops it fans its tail.
func _rest() -> void:
	if _dice.randf() < float(DISPLAY):
		_set_mode("display", DISPLAY_TIME)
	else:
		super._rest()


func _anim() -> Array:
	if _hit_showing():
		return ["hit", hit_anim, false]
	match mode:
		"flee":
			if velocity.length() > 15.0:
				return ["flee", anim_time, true]
		"display":
			return ["display", anim_time, true]
	return _walk_or_stand()
