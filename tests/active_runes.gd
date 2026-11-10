extends SceneTree
## Checks for the active runes (Hook on a press, Whirlwind on a hold), their
## meters, and what the bands do to them, run in the real arena with a scripted
## player. Prints PASS / FAIL lines.
##   godot --headless --path . --fixed-fps 60 -s tests/active_runes.gd

const EnemyScript := preload("res://scripts/enemy.gd")
const RuneFx := preload("res://scripts/fx/rune_fx.gd")

var m
var p
var fails := 0
var swings := 0
var last_step := -1
var most_turns := 0
var lowest := 1.0     # the emptiest button one's meter has been


func _init() -> void:
	m = load("res://scripts/main.gd").new()
	root.add_child(m)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		if p.current_step != last_step:
			if p.current_step >= 0:
				swings += 1
			last_step = p.current_step
		most_turns = maxi(most_turns, p.hold_turns)
		lowest = minf(lowest, float(p.ability_charge[0]))


## One tick of a button going down. Leaves it held if `hold` is true.
func _press(b: int, hold := false) -> void:
	p.input.ability_pressed[b] = true
	p.input.ability_held[b] = true
	await _frames(1)
	p.input.ability_pressed[b] = false
	p.input.ability_held[b] = hold


func _release() -> void:
	p.input.ability_held = [false, false]
	p.input.ability_pressed = [false, false]


## Stands still with nothing pressed until both meters are full again.
func _rest() -> void:
	_release()
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.input.dash_pressed = false
	p.input.stick_aim = Vector2.RIGHT
	await _frames(40)
	p.ability_charge = [1.0, 1.0]
	p.ability_wait = [0.0, 0.0]
	p.dodge_charges = 1
	swings = 0
	most_turns = 0
	lowest = 1.0


func _sword(line: Array) -> void:
	m.build.line = line.duplicate()
	m.build.changed.emit()


## A slime that stands where it's put and can't be shoved or killed.
func _slime(offset: Vector2, pinned := true):
	var e = EnemyScript.new()
	e.kind = "slime"
	e.position = p.global_position + offset
	m.world.add_child(e)
	e.max_hp = 5000.0
	e.hp = 5000.0
	e.speed = 0.0
	e.contact_damage = 0.0
	if pinned:
		e.knock_resist = 0.0
	return e


func _clear() -> void:
	for e in get_nodes_in_group("enemies"):
		if e.kind != "dummy":
			e.queue_free()
	await _frames(2)


func _spins() -> int:
	var n := 0
	for node in m.fx_layer.get_children():
		if node is RuneFx and node.kind == "spin":
			n += 1
	return n


func _run() -> void:
	await process_frame
	await process_frame
	p = m.player
	p.input.kind = "script"
	m.spawning = false
	m.min_hp = 100.0
	await _clear()
	p.global_position = m.ARENA.get_center() + Vector2(-300, 150)
	await _frames(5)
	var dmg := float(p.weapon["damage"])

	# --- The starting sword: Whirlwind on button one, Hook on button two ---
	var list: Array = p.weapon["abilities"]
	_check(list.size() == 2 and list[0]["id"] == "whirlwind" and list[1]["id"] == "hook", "the arena's sword has Whirlwind on button one and Hook on button two")

	# --- Hook: one press pulls enemies in, then it has to recharge ---
	await _rest()
	var far = _slime(Vector2(200, 0), false)
	await _frames(3)
	var d0: float = far.global_position.distance_to(p.global_position)
	await _press(1)
	await _frames(30)
	var d1: float = far.global_position.distance_to(p.global_position)
	_check(d1 < d0 - 80.0, "pressing Hook's button pulls a far enemy in (%.0f -> %.0f)" % [d0, d1])
	_check(far.hp < 5000.0, "and hurts it a little (%.1f)" % (5000.0 - far.hp))
	_check(float(p.ability_charge[1]) < 0.2, "Hook's meter is empty after use (%.2f)" % p.ability_charge[1])
	var hp_now: float = far.hp
	far.global_position = p.global_position + Vector2(200, 0)
	await _press(1)
	await _frames(20)
	_check(far.hp == hp_now, "pressing again before it's back does nothing")
	_check(p.game_time - float(p.ability_denied[1]) < 1.0, "and the press is noted, so the HUD can shake the slot")
	await _frames(200)
	_check(p.ability_ready(1), "Hook is ready again after its 4 seconds (%.2f)" % p.ability_charge[1])
	_check(swings == 0, "using Hook never swings the sword")
	far.queue_free()

	# --- Whirlwind: hold to keep spinning, turn after turn, until the meter is empty ---
	await _rest()
	var ring: Array = []
	for o in [Vector2(60, 0), Vector2(-60, 0), Vector2(0, 60), Vector2(0, -60)]:
		ring.append(_slime(o))
	await _frames(3)
	await _press(0, true)
	_check(p.hold_button == 0, "holding Whirlwind's button starts the spin")
	await _frames(20)   # into the second turn
	_check(p.hold_turns == 2, "still held, a second turn follows the first (%d)" % p.hold_turns)
	await _frames(100)
	_check(most_turns == 3, "a full meter is three turns (%d)" % most_turns)
	_check(p.hold_button < 0, "then the spin stops, even with the button still down")
	var worst := 0.0
	var best := 9999.0
	for e in ring:
		worst = maxf(worst, 5000.0 - e.hp)
		best = minf(best, 5000.0 - e.hp)
	_check(absf(best - dmg * 0.9 * 3.0) < 0.01 and absf(worst - best) < 0.01, "every enemy around was cut once a turn (%.1f each, blade %.0f)" % [best, dmg])
	_check(lowest < 0.01, "the meter was emptied (%.2f)" % lowest)
	_release()
	await _frames(5)
	await _press(0, true)
	await _frames(5)
	_check(p.hold_button < 0, "an empty meter won't start a spin")
	_release()
	await _frames(330)
	_check(float(p.ability_charge[0]) >= 1.0, "the meter is full again 5 seconds after stopping (%.2f)" % p.ability_charge[0])

	# A tap is one turn.
	await _rest()
	await _press(0)
	await _frames(40)
	_check(most_turns == 1 and p.hold_button < 0, "a tap is exactly one turn")
	_check(absf(float(p.ability_charge[0]) - 2.0 / 3.0) < 0.12, "and costs a third of the meter (%.2f left)" % p.ability_charge[0])

	# No swinging mid-spin; the swing comes as the spin ends.
	await _rest()
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _press(0, true)
	p.input.attack_pressed = false
	await _frames(10)
	_check(swings == 0 and p.current_step < 0, "the sword doesn't swing in the middle of a spin")
	_release()
	await _frames(30)
	_check(swings >= 1, "with attack still held, the chain starts as the spin ends")
	p.input.attack_held = false

	# Walking while spinning is slower, but you do move.
	await _rest()
	p.input.move = Vector2.DOWN
	await _frames(20)
	await _press(0, true)
	await _frames(10)
	var y0: float = p.global_position.y
	await _frames(30)
	var speed: float = (p.global_position.y - y0) * 2.0
	_check(absf(speed - 220.0 * 0.75) < 12.0, "you walk at three quarters speed while spinning (%.0f)" % speed)
	p.input.move = Vector2.ZERO

	# A dodge cuts the spin short.
	await _rest()
	await _press(0, true)
	await _frames(6)
	p.input.dash_pressed = true
	await _frames(1)
	p.input.dash_pressed = false
	await _frames(2)
	_check(p.hold_button < 0 and _spins() == 0, "a dodge ends the spin and takes its blade off the screen")
	_release()
	for e in ring:
		e.queue_free()

	# --- Bands on active runes ---
	# Twice: a hold rune gets twice the turns.
	_sword(["twice", "whirlwind", "", ""])
	await _rest()
	_check(int(p.weapon["abilities"][0]["turns"]) == 6, "Twice gives Whirlwind six turns")
	await _press(0, true)
	await _frames(150)
	_check(most_turns == 6, "and holding spins all six (%d)" % most_turns)
	_release()

	# Wider: a bigger circle.
	_sword(["wider", "whirlwind", "", ""])
	await _rest()
	var edge = _slime(Vector2(110, 0))
	await _frames(3)
	await _press(0)
	await _frames(30)
	_check(edge.hp < 5000.0, "Wider makes the circle reach an enemy 110 away")
	edge.queue_free()

	# Twice on a press rune: it fires twice.
	_sword(["twice", "hook", "", ""])
	await _rest()
	far = _slime(Vector2(200, 0))
	await _frames(3)
	await _press(0)
	await _frames(30)
	_check(absf((5000.0 - far.hp) - dmg * 0.3 * 2.0) < 0.01, "Twice makes one press of Hook pull twice (%.1f)" % (5000.0 - far.hp))

	# Saved Up: three times as strong, three times the recharge.
	_sword(["saved_up", "hook", "", ""])
	await _rest()
	far.hp = 5000.0
	await _press(0)
	await _frames(30)
	_check(absf((5000.0 - far.hp) - dmg * 0.3 * 3.0) < 0.01, "Saved Up makes Hook three times as strong (%.1f)" % (5000.0 - far.hp))
	await _frames(240 - 31)
	_check(absf(float(p.ability_charge[0]) - 1.0 / 3.0) < 0.02, "and three times as slow to come back (a third full after 4 seconds: %.2f)" % p.ability_charge[0])

	# On Dodge: a dodge does it too, without touching the meter.
	_sword(["on_dodge", "hook", "", ""])
	await _rest()
	far.hp = 5000.0
	p.input.dash_pressed = true
	await _frames(1)
	p.input.dash_pressed = false
	await _frames(30)
	_check(far.hp < 5000.0, "On Dodge: a dodge fires Hook")
	_check(float(p.ability_charge[0]) >= 1.0, "and leaves its meter full")
	far.queue_free()

	# Every Hit: the rune goes back to firing by itself, with no button.
	_sword(["every_hit", "whirlwind", "", ""])
	await _rest()
	_check(p.weapon["abilities"].is_empty(), "Every Hit takes Whirlwind off its button")
	var near = _slime(Vector2(50, 0))
	var side = _slime(Vector2(0, 60))
	await _frames(3)
	p.input.attack_pressed = true
	p.input.attack_held = true
	await _frames(1)
	p.input.attack_pressed = false
	p.input.attack_held = false
	await _frames(30)
	_check(absf((5000.0 - side.hp) - dmg * 0.9 * 0.5) < 0.01, "and every hit spins by itself at half strength (%.2f to an enemy beside you)" % (5000.0 - side.hp))
	near.queue_free()
	side.queue_free()

	# --- Shockwave is a light hit now ---
	_sword(["shockwave", "", "", ""])
	await _rest()
	near = _slime(Vector2(50, 0))
	far = _slime(Vector2(190, 0))
	await _frames(3)
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	for i in 80:
		await _frames(1)
		if p.step_index == 0 and p.current_step < 0:
			break
	p.input.attack_held = false
	await _frames(40)
	_check(absf((5000.0 - far.hp) - dmg * 0.4) < 0.01, "Shockwave does 0.4 of the blade's damage, less than a slash (%.1f, blade %.0f)" % [5000.0 - far.hp, dmg])

	print("RESULT: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(1 if fails > 0 else 0)
