extends "res://scripts/enemy.gd"
## Crawler: the cave's first enemy. Small and slow. It walks up to you, rears
## up (the warning), then bites. A hit while it's rearing up cancels the bite,
## so attacking first is the lesson.

const BITE := 8.0
const REAR_TIME := 0.5
const BITE_TIME := 0.12
const RECOVER_TIME := 0.55

var mode := "emerge"
var mode_t := 0.5
var side := 1.0            # which way it circles as it closes in
var bitten := false


func _setup() -> void:
	kind = "crawler"
	art_set = "cave"
	lift = 1.4   # the rooms they live in are dark; with the lit rim in the art this is enough
	max_hp = 14.0
	speed = 50.0
	radius = 11.0
	contact_damage = 0.0
	color = Color("#c9923a")
	side = 1.0 if randf() < 0.5 else -1.0
	mode_t = randf_range(0.35, 0.6)


func _set_mode(m: String, time: float) -> void:
	mode = m
	mode_t = time


## The helm crab is drawn from the front, so it never needs mirroring.
func _flip(_anim: String) -> bool:
	return false


func _think(delta: float) -> Vector2:
	mode_t -= delta
	if target == null:
		return Vector2.ZERO
	var to_p: Vector2 = target.global_position - global_position
	var dist := to_p.length()
	match mode:
		"emerge":
			if mode_t <= 0.0:
				_set_mode("chase", 0.0)
		"chase":
			if dist > 0.01:
				facing = to_p / dist
			if dist < radius + 16.0 + 12.0:
				_set_mode("rear", REAR_TIME)
				Sfx.play(self, "warn", -16.0, 0.8)
				return Vector2.ZERO
			# A slight curve, so a group fans out round you and doesn't queue up.
			return (facing + facing.orthogonal() * side * 0.35).normalized() * speed
		"rear":
			if mode_t <= 0.0:
				_set_mode("bite", BITE_TIME)
				bitten = false
		"bite":
			if not bitten:
				bitten = true
				for p in players():
					var rel: Vector2 = p.global_position - global_position
					if rel.length() < radius + 16.0 + 22.0 and absf(facing.angle_to(rel)) < 1.2:
						p.take_damage(BITE, global_position)
			if mode_t <= 0.0:
				_set_mode("recover", RECOVER_TIME)
			return facing * 150.0   # a short snap forward
		"recover":
			if mode_t <= 0.0:
				_set_mode("chase", 0.0)
	return Vector2.ZERO


## A hit while it rears up cancels the bite.
func _on_hit() -> void:
	if mode == "rear" or mode == "bite":
		_set_mode("recover", 0.35)


func _anim() -> Array:
	var strips: Dictionary = _art_info().get("strips", {})
	var hit_strip: Dictionary = strips.get("hit", {})
	if not hit_strip.is_empty() and hit_anim < float(hit_strip["frames"]) / float(hit_strip["fps"]):
		return ["hit", hit_anim, false]
	match mode:
		"rear":
			return ["attack", 0.0, false]
		"bite":
			return ["attack", 0.1, false]
		"recover":
			if mode_t > RECOVER_TIME - 0.15:
				return ["attack", 0.2, false]
		"emerge":
			return ["idle", anim_time, true]
	if velocity.length() > 15.0:
		return ["move", anim_time, true]
	return ["idle", anim_time, true]


func _draw() -> void:
	# Fades in as it crawls out of the dark.
	modulate.a = 1.0 if mode != "emerge" else clampf(1.0 - mode_t / 0.5, 0.2, 1.0)
	super._draw()
	if mode == "rear":
		# The warning: a red flash that quickens just before the bite.
		var k := 1.0 - mode_t / REAR_TIME
		var on := int(k * k * 9.0) % 2 == 0
		if on:
			draw_arc(Vector2(0, -2), radius + 9.0, 0.0, TAU, 20, Color(1.8, 0.3, 0.2, 0.9), 2.0)
