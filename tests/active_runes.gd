extends SceneTree
## Checks for the active runes (Hook and Leap on a press, Whirlwind on a hold),
## their meters, what the bands do to them, and the passive Weak Point, run in
## the real arena with a scripted player. Prints PASS / FAIL lines.
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
	p.input.ability_held = [false, false, false]
	p.input.ability_pressed = [false, false, false]


## Stands still with nothing pressed until every meter is full again.
func _rest() -> void:
	_release()
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.input.dash_pressed = false
	p.input.stick_aim = Vector2.RIGHT
	await _frames(40)
	p.ability_charge = [1.0, 1.0, 1.0]
	p.ability_wait = [0.0, 0.0, 0.0]
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


## A brute (a big enemy: Weak Point puts a spot on its side) that stands still.
func _brute(offset: Vector2):
	var e = EnemyScript.new()
	e.kind = "brute"
	e.position = p.global_position + offset
	m.world.add_child(e)
	e.max_hp = 5000.0
	e.hp = 5000.0
	e.speed = 0.0
	e.contact_damage = 0.0
	e.knock_resist = 0.0
	return e


## The first swing of the chain, once, aimed along `dir`. Returns after it has landed.
func _swing(dir := Vector2.RIGHT) -> void:
	p._reset_combo()
	p.input.stick_aim = dir
	await _frames(2)
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(28)
	p._reset_combo()


## Swings the whole chain once, aimed along `dir`, and stops after the finisher.
func _chain(dir := Vector2.RIGHT) -> void:
	p._reset_combo()
	p.input.stick_aim = dir
	await _frames(2)
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	for i in 200:
		await _frames(1)
		if p.current_step == p._steps().size() - 1:
			break
	p.input.attack_held = false
	for i in 90:
		await _frames(1)
		if p.current_step < 0:
			break
	await _frames(4)
	p._reset_combo()


func _sword_exact(line: Array) -> void:
	_sword(line)
	p.weapon["crit"] = 0.0


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

	# --- The starting sword: Whirlwind, Hook and Leap on buttons one, two and three ---
	var list: Array = p.weapon["abilities"]
	_check(list.size() == 3 and list[0]["id"] == "whirlwind" and list[1]["id"] == "hook" and list[2]["id"] == "leap", "the arena's sword has Whirlwind, Hook and Leap on buttons one, two and three")
	p.weapon["crit"] = 0.0   # no lucky crits, so the numbers below are exact

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

	near.queue_free()
	far.queue_free()
	await _leap_checks(dmg)
	await _weak_point_checks(dmg)

	print("RESULT: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(1 if fails > 0 else 0)


# --- Leap (active since 11 November): lands at the blade's reach, with a strike ---
func _leap_checks(dmg: float) -> void:
	_sword_exact(["leap", "", "", ""])
	await _rest()
	var stand: float = p._hit_reach() + 14.0 - 12.0
	var far = _slime(Vector2(230, 0))
	await _frames(3)
	var x0: float = p.global_position.x
	await _press(0)
	await _frames(4)
	_check(p.current_step < 0 and not p.leap_landing.is_empty(), "pressing Leap's button sets off the jump")
	await _frames(20)
	var d: float = far.global_position.distance_to(p.global_position)
	_check(p.global_position.x > x0 + 100.0, "Leap jumps you toward a far enemy (%.0f px)" % (p.global_position.x - x0))
	_check(absf(d - stand) < 6.0, "and lands you at the blade's reach from it, not on top (%.0f away, reach %.0f)" % [d, p._hit_reach()])
	_check(absf((5000.0 - far.hp) - dmg) < 0.01, "with one strike as you land (%.1f, blade %.0f)" % [5000.0 - far.hp, dmg])
	_check(float(p.ability_charge[0]) < 0.2, "Leap's meter is empty after use (%.2f)" % p.ability_charge[0])
	var hp_now: float = far.hp
	await _press(0)
	await _frames(20)
	_check(far.hp == hp_now, "pressing again before it's back does nothing")
	await _frames(170)
	_check(p.ability_ready(0), "Leap is ready again after its 3 seconds (%.2f)" % p.ability_charge[0])

	# Standing on top of the enemy: it hops you back out to the blade's reach.
	await _rest()
	p.global_position = far.global_position + Vector2(-30, 0)
	await _frames(3)
	await _press(0)
	await _frames(24)
	d = far.global_position.distance_to(p.global_position)
	_check(absf(d - stand) < 6.0, "from on top of an enemy, Leap hops back out to the blade's reach (%.0f away)" % d)
	far.queue_free()
	await _frames(2)

	# Nobody in range: a short jump the way you aim.
	await _rest()
	x0 = p.global_position.x
	await _press(0)
	await _frames(24)
	_check(absf((p.global_position.x - x0) - 130.0) < 8.0, "with nobody in range, Leap jumps a short way where you aim (%.0f px)" % (p.global_position.x - x0))

	# It prefers the enemy you aim at over a nearer one behind you.
	await _rest()
	var behind = _slime(Vector2(-120, 0))
	var ahead = _slime(Vector2(220, 0))
	await _frames(3)
	await _press(0)
	await _frames(24)
	_check(ahead.hp < 5000.0 and behind.hp == 5000.0, "Leap goes for the enemy you aim at, not a nearer one behind you")
	behind.queue_free()
	ahead.queue_free()
	await _frames(2)

	# Twice: a second leap, to the next enemy.
	_sword_exact(["twice", "leap", "", ""])
	await _rest()
	var one = _slime(Vector2(160, 0))
	var two = _slime(Vector2(160, 150))
	await _frames(3)
	await _press(0)
	await _frames(50)
	_check(one.hp < 5000.0 and two.hp < 5000.0, "Twice: Leap strikes one enemy, then leaps on to the next")
	one.queue_free()
	two.queue_free()
	await _frames(2)

	# On Dodge: a dodge leaps for free.
	_sword_exact(["on_dodge", "leap", "", ""])
	await _rest()
	far = _slime(Vector2(200, 0))
	await _frames(3)
	p.input.dash_pressed = true
	await _frames(1)
	p.input.dash_pressed = false
	await _frames(30)
	_check(far.hp < 5000.0, "On Dodge: a dodge leaps and strikes")
	_check(float(p.ability_charge[0]) >= 1.0, "and leaves its meter full")
	far.queue_free()
	await _frames(2)

	# All three buttons on one sword.
	_sword_exact(["whirlwind", "hook", "leap", ""])
	await _rest()
	far = _slime(Vector2(220, 0))
	await _frames(3)
	await _press(2)
	await _frames(24)
	_check(far.hp < 5000.0 and float(p.ability_charge[2]) < 0.2 and float(p.ability_charge[0]) >= 1.0 and float(p.ability_charge[1]) >= 1.0, "the third button uses the third active rune and only its meter")
	far.queue_free()
	await _frames(2)


# --- Weak Point (passive, 11 November): the finisher marks, the next hit is a big crit ---
func _weak_point_checks(dmg: float) -> void:
	_sword_exact(["weak_point", "", "", ""])
	await _rest()
	var near = _slime(Vector2(50, 0))
	await _frames(3)
	await _swing()
	_check(near.weak_marks.is_empty() and absf((5000.0 - near.hp) - dmg) < 0.01, "an ordinary hit doesn't mark (%.1f)" % (5000.0 - near.hp))
	await _chain()
	_check(near.weak_marks.size() == 1 and p.weak_marks.size() == 1, "the finisher marks the enemy it hit")
	near.hp = 5000.0
	await _swing()
	_check(absf((5000.0 - near.hp) - dmg * 2.5) < 0.01, "the next hit on the mark is a big crit: 2.5 hits' worth (%.1f, blade %.0f)" % [5000.0 - near.hp, dmg])
	_check(near.weak_marks.is_empty() and p.weak_marks.is_empty(), "and it uses the mark up")
	near.hp = 5000.0
	await _swing()
	_check(absf((5000.0 - near.hp) - dmg) < 0.01, "the hit after that is ordinary again (%.1f)" % (5000.0 - near.hp))

	# One mark at a time: marking another enemy takes the first mark away.
	await _chain()
	var other = _slime(Vector2(-50, 0))
	await _frames(3)
	near.global_position += Vector2(400, 0)
	await _chain(Vector2.LEFT)
	_check(other.weak_marks.size() == 1 and near.weak_marks.is_empty(), "one mark at a time: marking a second enemy takes the first mark away")
	near.queue_free()
	other.queue_free()
	await _frames(2)

	# A mark fades if you leave it.
	await _rest()
	near = _slime(Vector2(50, 0))
	await _frames(3)
	await _chain()
	_check(near.weak_marks.size() == 1, "(marked again)")
	await _frames(int(near.WEAK_LIFE * 60.0) + 10)
	_check(near.weak_marks.is_empty(), "a mark fades after %d seconds" % int(near.WEAK_LIFE))
	near.queue_free()
	await _frames(2)

	# A big enemy gets a spot on one side: you have to hit it from that side.
	await _rest()
	var big = _brute(Vector2(70, 0))
	await _frames(3)
	await _chain()
	_check(big.weak_marks.size() == 1 and big.weak_big(), "a big enemy is marked with a spot")
	var mark: Dictionary = big.weak_marks[0]
	var spot_dir := Vector2.RIGHT.rotated(float(mark["angle"]))
	var from_player: Vector2 = (p.global_position - big.global_position).normalized()
	_check(absf(spot_dir.angle_to(from_player)) > deg_to_rad(70.0), "the spot is never on the side you marked it from (%.0f degrees round)" % rad_to_deg(absf(spot_dir.angle_to(from_player))))
	# From the far side of the spot: an ordinary hit, and the spot stays.
	p.global_position = big.global_position - spot_dir * 75.0
	big.hp = 5000.0
	await _swing(spot_dir)
	_check(absf((5000.0 - big.hp) - dmg) < 0.01 and big.weak_marks.size() == 1, "hitting it from the wrong side is an ordinary hit and leaves the spot (%.1f)" % (5000.0 - big.hp))
	# From the spot's side: the crit.
	p.global_position = big.global_position + spot_dir * 75.0
	big.hp = 5000.0
	await _swing(-spot_dir)
	_check(absf((5000.0 - big.hp) - dmg * 2.5) < 0.01 and big.weak_marks.is_empty(), "stepping round and hitting the spot is the big crit (%.1f)" % (5000.0 - big.hp))

	# Twice: two spots on a big enemy.
	_sword_exact(["twice", "weak_point", "", ""])
	await _rest()
	p.global_position = big.global_position + Vector2(-70, 0)
	await _frames(3)
	await _chain()
	_check(big.weak_marks.size() == 2 and p.weak_marks.size() == 2, "Twice: two spots on a big enemy (%d)" % big.weak_marks.size())
	big.queue_free()
	await _frames(2)

	# Twice on small enemies: two of them marked at once.
	await _rest()
	near = _slime(Vector2(50, -20))
	other = _slime(Vector2(50, 20))
	await _frames(3)
	await _chain()
	_check(near.weak_marks.size() == 1 and other.weak_marks.size() == 1, "Twice: two small enemies marked at once")
	near.queue_free()
	other.queue_free()
	await _frames(2)

	# Every Hit: every hit marks, with a smaller crit, and a crit doesn't re-mark.
	_sword_exact(["every_hit", "weak_point", "", ""])
	await _rest()
	near = _slime(Vector2(50, 0))
	await _frames(3)
	await _swing()
	_check(near.weak_marks.size() == 1, "Every Hit: an ordinary hit marks")
	near.hp = 5000.0
	await _swing()
	_check(absf((5000.0 - near.hp) - dmg * 1.75) < 0.01, "and the next hit is a smaller crit: 1.75 hits' worth (%.2f)" % (5000.0 - near.hp))
	_check(near.weak_marks.is_empty(), "the hit that strikes a mark doesn't put a new one on")
	near.queue_free()
	await _frames(2)

	# Saved Up: every third finisher, a huge crit.
	_sword_exact(["saved_up", "weak_point", "", ""])
	await _rest()
	near = _slime(Vector2(50, 0))
	await _frames(3)
	await _chain()
	await _chain()
	_check(near.weak_marks.is_empty(), "Saved Up: the first two finishers don't mark")
	await _chain()
	_check(near.weak_marks.size() == 1, "the third one does")
	near.hp = 5000.0
	await _swing()
	_check(absf((5000.0 - near.hp) - dmg * 5.5) < 0.01, "and its crit is huge: 5.5 hits' worth (%.1f)" % (5000.0 - near.hp))
	near.queue_free()
	await _frames(2)

	# On Dodge: dodging past an enemy marks it.
	_sword_exact(["on_dodge", "weak_point", "", ""])
	await _rest()
	near = _slime(Vector2(60, 30))
	await _frames(3)
	p.input.move = Vector2.RIGHT
	p.input.dash_pressed = true
	await _frames(1)
	p.input.dash_pressed = false
	p.input.move = Vector2.ZERO
	await _frames(20)
	_check(near.weak_marks.size() == 1, "On Dodge: dodging past an enemy marks it")
	near.queue_free()
	await _frames(2)

	# A Heavy pommel's crit damage adds to the mark's crit.
	_sword(["weak_point", "", "", ""])
	m.build.set_pommel("heavy_pommel")
	p.weapon["crit"] = 0.0
	await _rest()
	near = _slime(Vector2(50, 0))
	await _frames(3)
	await _chain()
	near.hp = 5000.0
	await _swing()
	_check(absf((5000.0 - near.hp) - dmg * 2.9) < 0.01, "a Heavy pommel's +40%% crit damage adds to it (%.1f)" % (5000.0 - near.hp))
	m.build.set_pommel("plain_pommel")
	near.queue_free()
	await _frames(2)
