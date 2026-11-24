extends SceneTree
## Checks for the bow's six runes (14 November), run in the real arena with a
## scripted player: Pierce, Ricochet and Steady Aim (passive), Volley, Snipe and
## Arrow Rain (on the ability buttons), and what every band does to each.
##   godot --headless --path . --fixed-fps 60 -s tests/bow_runes.gd

const EnemyScript := preload("res://scripts/enemy.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Player := preload("res://scripts/player.gd")
const Art := preload("res://scripts/art.gd")
const BowArt := preload("res://scripts/weapon/bow_art.gd")

## One iron arrow from the shortbow, read from the game (4.9 since Darren's lab in version 57; 7.7 before).
var ARROW: float = float(SwingBuild.limb_info("iron_shortbow", "iron_arrows")["damage"])
var HEAVY: float = ARROW     # the chain's third shot (a plain one too since version 34: no heavy last arrow on a shortbow)
const RUNES := ["pierce", "ricochet", "steady_aim", "volley", "snipe", "arrow_rain"]

var m
var p
var fails := 0
var made: Array = []


func _init() -> void:
	m = load("res://scripts/main.gd").new()
	root.add_child(m)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _near(a: float, b: float, slack := 0.01) -> bool:
	return absf(a - b) <= slack


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## A slime that stands where it's put and can't be killed or shoved.
func _slime(offset: Vector2):
	var e = EnemyScript.new()
	e.kind = "slime"
	e.position = p.global_position + offset
	m.world.add_child(e)
	e.max_hp = 500000.0
	e.hp = 500000.0
	e.speed = 0.0
	e.contact_damage = 0.0
	e.knock_resist = 0.0
	made.append(e)
	return e


func _clear() -> void:
	for e in made:
		if is_instance_valid(e):
			e.queue_free()
	made.clear()
	await _frames(2)


func _lost(e) -> float:
	return e.max_hp - e.hp


func _arrows(rune := "*") -> Array:
	var out: Array = []
	for a in get_nodes_in_group("arrows"):
		if is_instance_valid(a) and not a.is_queued_for_deletion() and (rune == "*" or a.rune == rune):
			out.append(a)
	return out


func _still(frames := 70) -> void:
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.input.dash_pressed = false
	p.input.ability_held = [false, false, false]
	p.input.ability_pressed = [false, false, false]
	p.input.stick_aim = Vector2.RIGHT
	p._reset_combo()
	await _frames(frames)      # long enough for every arrow to land and fade
	p._reset_combo()
	p.weapon["crit"] = 0.0   # no luck in the sums


## Puts this bow in the hand: an iron shortbow on the wrapped grip (four slots),
## with these fittings bottom to top.
func _bow(line: Array, home: Vector2) -> void:
	await _clear()
	while line.size() < 4:
		line.append("")
	m.build.set_data(["iron_shortbow", "wrapped_bow_grip", "plain_string", line, "iron_arrows"])
	m.build.changed.emit()
	await _still(100)
	p.global_position = home
	p.reset_physics_interpolation()
	p.rains.clear()
	p.dodge_charges = 1
	await _frames(2)
	p.weapon["crit"] = 0.0


## Shoots the first `count` shots of the chain and waits for the last to land.
func _shots(count: int) -> void:
	p._reset_combo()
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	for i in 600:
		await _frames(1)
		if p.current_step == count - 1:
			break
	p.input.attack_held = false
	for i in 300:
		await _frames(1)
		if p.current_step < 0:
			break
	await _frames(45)
	p._reset_combo()


## Presses ability button `b` and keeps it down for `hold` ticks in all.
func _press(b: int, hold := 1) -> void:
	var on := [false, false, false]
	on[b] = true
	p.input.ability_pressed = on.duplicate()
	p.input.ability_held = on.duplicate()
	await _frames(1)
	p.input.ability_pressed = [false, false, false]
	if hold > 1:
		await _frames(hold - 1)
	p.input.ability_held = [false, false, false]
	await _frames(1)


func _dodge(dir := Vector2.ZERO) -> void:
	p.dodge_charges = 1
	p.input.move = dir
	p.input.dash_pressed = true
	await _frames(1)
	p.input.dash_pressed = false
	await _frames(12)
	p.input.move = Vector2.ZERO


func _effect(line: Array) -> Dictionary:
	return SwingBuild.resolve(line)["effects"][0]


func _run() -> void:
	await process_frame
	await _frames(5)
	p = m.player
	p.input.kind = "script"
	m.spawning = false
	m.min_hp = 100.0
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(5)
	p.auto_respawn = true
	var home := Vector2(900, 560)      # the middle of the room, far from every wall
	p.global_position = home
	p.reset_physics_interpolation()
	await _frames(2)

	# --- The rules: six runes, the bow's own -------------------------------------------
	var passive := 0
	var active := 0
	for id in RUNES:
		var f: Dictionary = SwingBuild.FITTINGS.get(id, {})
		_check(f.get("kind", "") == "rune" and f.get("weapon", "") == "bow" and id in SwingBuild.FITTING_ORDER, "%s is a bow rune in the forge" % id)
		if f.get("trigger", "") == "active":
			active += 1
		else:
			passive += 1
		for pic in ["icon", "forge", "forge_lit", "hand", "hand_lit"]:
			if Art.texture("swing/runes/%s_%s.png" % [id, pic]) == null:
				_check(false, "%s has its %s picture" % [id, pic])
		_check(Art.texture("swing/previews/%s.png" % id) != null, "%s has a preview picture" % id)
	_check(passive == 3 and active == 3, "three passive, three active")
	for g in ["volley", "snipe", "arrow_rain"]:
		_check(Art.texture("hud/glyph_%s.png" % g) != null, "%s has its button glyph" % g)
	for fx in ["pierce_trail", "ricochet_spark", "steady_ring", "volley_fan", "snipe_charge", "snipe_sweet", "snipe_trail", "snipe_hit", "rain_mark", "rain_arrow", "rain_hit"]:
		_check(BowArt.fx_texture(fx) != null and not BowArt.fx(fx).is_empty(), "effect strip %s is in the game" % fx)
	_check(SwingBuild.valid_data(["iron_shortbow", "wrapped_bow_grip", "plain_string", ["pierce", "volley", "twice", "snipe"], "iron_arrows"]), "a bow takes its runes")
	_check(not SwingBuild.valid_data(["iron_broadsword", "wrapped_grip", "plain_pommel", ["volley", "", "", ""]]), "a sword does not")
	var test_abilities: Array = SwingBuild.abilities(SwingBuild.resolve(SwingBuild.TEST_BOW[3])["effects"])
	var got: Array = []
	for a in test_abilities:
		got.append([a["id"], a["use"], a["recharge"]])
	_check(got == [["volley", "press", 4.0], ["snipe", "charge", 6.0], ["arrow_rain", "press", 8.0]], "the arena's bow has Volley, Snipe and Arrow Rain on its three buttons: %s" % [got])
	_check(SwingBuild.pierce_count(_effect(["pierce"])) == 1 and SwingBuild.pierce_count(_effect(["twice", "pierce"])) == 2 and SwingBuild.pierce_count(_effect(["saved_up", "pierce"])) == 3, "Pierce goes through one enemy, two with Twice, three with Saved Up")
	_check(_near(SwingBuild.steady_rate(_effect(["steady_aim"])), 0.1) and _near(SwingBuild.steady_cap(_effect(["steady_aim"])), 0.5), "Steady Aim: a tenth a second, up to half")
	_check(_near(SwingBuild.steady_rate(_effect(["twice", "steady_aim"])), 0.2) and _near(SwingBuild.steady_cap(_effect(["wider", "steady_aim"])), 0.8), "Twice builds it twice as fast, Wider takes it to +80%")
	_check(SwingBuild.volley_arrows(1.0) == 3 and SwingBuild.volley_arrows(SwingBuild.wider_size(1)) == 5 and SwingBuild.volley_arrows(SwingBuild.wider_size(3)) == 7, "Volley: three arrows, five with Wider, seven at the most")
	var says := {
		["pierce"]: "Your finisher's arrow goes on through the enemy it hits.",
		["twice", "pierce"]: "Your finisher's arrow goes on through two enemies.",
		["every_hit", "pierce"]: "Every arrow goes on through the enemy it hits, hitting those behind at half strength.",
		["saved_up", "pierce"]: "Every third finisher's arrow goes on through three enemies.",
		["on_dodge", "wider", "pierce"]: "Your finisher's arrow goes on through the enemy it hits, on a wider path. The first arrow after a dodge does it too.",
		["ricochet"]: "An arrow that hits jumps on to the nearest other enemy, for half its damage.",
		["twice", "ricochet"]: "An arrow that hits jumps on twice, from enemy to enemy, for half its damage.",
		["every_hit", "ricochet"]: "An arrow that hits jumps on to the nearest other enemy, splitting in two, for a quarter of its damage.",
		["saved_up", "ricochet"]: "Every third arrow that hits jumps on to the nearest other enemy, for 1.5 times its damage.",
		["steady_aim"]: "Stand still while you shoot and you shoot faster and faster, up to +50%. Moving resets it.",
		["wider", "on_dodge", "steady_aim"]: "Stand still while you shoot and you shoot faster and faster, up to +80%. Walking resets it, dodging doesn't.",
		["saved_up", "steady_aim"]: "Stand still while you shoot and you shoot faster and faster slowly, up to +50%. Once it is full, every third arrow hits three times as hard. Moving resets it.",
		["volley"]: "Press right mouse: looses three arrows in a spread. Recharges in 4 seconds.",
		["wider", "twice", "volley"]: "Press right mouse: looses five arrows in a spread, twice. Recharges in 4 seconds.",
		["snipe"]: "Hold right mouse, then let go: one heavy shot that does more the farther it flies. Recharges in 6 seconds.",
		["on_dodge", "snipe"]: "Hold right mouse, then let go: one heavy shot that does more the farther it flies. Recharges in 6 seconds. Dodging looses a quick, weak one too.",
		["arrow_rain"]: "Press right mouse: marks the ground where you aim, and arrows pour down on it for 3 seconds. Recharges in 8 seconds.",
		["saved_up", "arrow_rain"]: "Press right mouse: marks the ground where you aim, and arrows pour down on it for 3 seconds, three times as strong and pinning enemies. Recharges in 24 seconds.",
		["every_hit", "twice", "arrow_rain"]: "Press right mouse: marks the ground where you aim, and arrows pour down on it for 3 seconds, then again. Recharges in 8 seconds. Each hit you land takes half a second off.",
	}
	for line in says:
		var said: String = SwingBuild.sentence(_effect(line))
		_check(said == says[line], "%s reads: %s" % [line, said])

	# --- In the arena: the test bow ---------------------------------------------------------
	m.swap_weapon(0)
	await _frames(2)
	_check(m.build.weapon() == "bow" and p.weapon["abilities"].size() == 3, "the arena's bow comes with its three buttons")
	_check(p.weapon["effects"].size() == 4 and p.weapon["effects"][3]["id"] == "ricochet", "and Ricochet as its passive rune")

	# --- Pierce ---------------------------------------------------------------------------------
	await _bow(["pierce"], home)
	var a1 = _slime(Vector2(200, 0))
	var a2 = _slime(Vector2(262, 0))
	var a3 = _slime(Vector2(324, 0))
	await _frames(2)
	await _shots(3)
	_check(_near(_lost(a1), ARROW * 2.0 + HEAVY), "Pierce: the one in front takes the whole chain (%.3f)" % _lost(a1))
	_check(_near(_lost(a2), HEAVY), "the finisher's arrow goes on through it to the one behind (%.3f)" % _lost(a2))
	_check(_lost(a3) == 0.0, "and stops there: through one enemy")

	await _bow(["twice", "pierce"], home)
	a1 = _slime(Vector2(200, 0))
	a2 = _slime(Vector2(262, 0))
	a3 = _slime(Vector2(324, 0))
	var a4 = _slime(Vector2(386, 0))
	await _frames(2)
	await _shots(3)
	_check(_near(_lost(a2), HEAVY) and _near(_lost(a3), HEAVY) and _lost(a4) == 0.0, "Twice: through two enemies (%.2f, %.2f, %.2f)" % [_lost(a2), _lost(a3), _lost(a4)])

	await _bow(["every_hit", "pierce"], home)
	a1 = _slime(Vector2(200, 0))
	a2 = _slime(Vector2(262, 0))
	a3 = _slime(Vector2(324, 0))
	await _frames(2)
	await _shots(3)
	_check(_near(_lost(a1), ARROW * 2.0 + HEAVY) and _near(_lost(a2), (ARROW * 2.0 + HEAVY) * 0.5) and _lost(a3) == 0.0, "Every Hit: every arrow goes through one, at half strength behind (%.3f, %.3f)" % [_lost(a1), _lost(a2)])

	await _bow(["saved_up", "pierce"], home)
	a1 = _slime(Vector2(200, 0))
	a2 = _slime(Vector2(262, 0))
	a3 = _slime(Vector2(324, 0))
	a4 = _slime(Vector2(386, 0))
	var a5 = _slime(Vector2(448, 0))
	await _frames(2)
	await _shots(3)
	await _shots(3)
	_check(_lost(a2) == 0.0, "Saved Up: the first two finishers stop in the first enemy")
	await _shots(3)
	_check(_near(_lost(a2), HEAVY) and _near(_lost(a3), HEAVY) and _near(_lost(a4), HEAVY) and _lost(a5) == 0.0, "the third goes through three (%.2f, %.2f, %.2f, %.2f)" % [_lost(a2), _lost(a3), _lost(a4), _lost(a5)])

	await _bow(["on_dodge", "pierce"], home)
	a1 = _slime(Vector2(200, 0))
	a2 = _slime(Vector2(262, 0))
	await _frames(2)
	await _shots(1)
	_check(_near(_lost(a1), ARROW) and _lost(a2) == 0.0, "On Dodge: a first shot without a dodge stops in the first enemy")
	await _dodge(Vector2.ZERO)
	p.global_position = home
	await _still(20)
	await _shots(1)
	_check(_near(_lost(a2), ARROW), "after a dodge the first arrow goes on through (%.3f)" % _lost(a2))
	await _shots(1)
	_check(_near(_lost(a2), ARROW), "and the one after it does not")

	# Wider: one standing 22 px off the arrow's line behind the first is missed by a
	# plain piercing arrow (it reaches 18 px), and caught by the wider one (26).
	await _bow(["pierce"], home)
	a1 = _slime(Vector2(200, 0))
	a2 = _slime(Vector2(262, 22))
	await _frames(2)
	await _shots(3)
	_check(_lost(a2) == 0.0, "a piercing arrow is as narrow as any other")
	await _bow(["wider", "pierce"], home)
	a1 = _slime(Vector2(200, 0))
	a2 = _slime(Vector2(262, 22))
	await _frames(2)
	await _shots(3)
	_check(_near(_lost(a2), HEAVY), "Wider: it cuts a wider path (%.2f)" % _lost(a2))

	# --- Ricochet -------------------------------------------------------------------------------
	await _bow(["ricochet"], home)
	var r1 = _slime(Vector2(200, 0))
	var r2 = _slime(Vector2(200, 100))
	var r3 = _slime(Vector2(200, 200))
	await _frames(2)
	await _shots(1)
	_check(_near(_lost(r1), ARROW) and _near(_lost(r2), ARROW * 0.5), "Ricochet: the arrow jumps on to the nearest other enemy for half its damage (%.3f, %.3f)" % [_lost(r1), _lost(r2)])
	_check(_lost(r3) == 0.0, "one jump, no further")
	await _shots(3)
	_check(_near(_lost(r2), (ARROW * 3.0 + HEAVY) * 0.5), "every arrow that hits does it, the heavy one harder (%.3f)" % _lost(r2))

	await _bow(["twice", "ricochet"], home)
	r1 = _slime(Vector2(200, 0))
	r2 = _slime(Vector2(200, 100))
	r3 = _slime(Vector2(200, 200))
	await _frames(2)
	await _shots(1)
	_check(_near(_lost(r2), ARROW * 0.5) and _near(_lost(r3), ARROW * 0.5), "Twice: it jumps on twice, from enemy to enemy (%.3f, %.3f)" % [_lost(r2), _lost(r3)])
	_check(_near(_lost(r1), ARROW), "and never back to one it has hit")

	await _bow(["every_hit", "ricochet"], home)
	r1 = _slime(Vector2(200, 0))
	r2 = _slime(Vector2(200, 100))
	r3 = _slime(Vector2(200, -110))
	await _frames(2)
	await _shots(1)
	_check(_near(_lost(r2), ARROW * 0.25) and _near(_lost(r3), ARROW * 0.25), "Every Hit: it splits in two as it jumps, a quarter each (%.3f, %.3f)" % [_lost(r2), _lost(r3)])

	await _bow(["ricochet"], home)
	r1 = _slime(Vector2(200, 0))
	r2 = _slime(Vector2(200, 200))
	await _frames(2)
	await _shots(1)
	_check(_lost(r2) == 0.0, "an enemy 200 px away is too far for the jump")
	await _bow(["wider", "ricochet"], home)
	r1 = _slime(Vector2(200, 0))
	r2 = _slime(Vector2(200, 200))
	await _frames(2)
	await _shots(1)
	_check(_near(_lost(r2), ARROW * 0.5), "Wider: it jumps further")

	await _bow(["saved_up", "ricochet"], home)
	r1 = _slime(Vector2(200, 0))
	r2 = _slime(Vector2(200, 100))
	await _frames(2)
	await _shots(1)
	await _shots(1)
	_check(_lost(r2) == 0.0, "Saved Up: the first two hits don't jump")
	await _shots(1)
	_check(_near(_lost(r2), ARROW * 1.5), "the third does, three times as strong (%.3f)" % _lost(r2))

	await _bow(["on_dodge", "ricochet"], home)
	r1 = _slime(Vector2(0, 120))
	await _frames(2)
	await _dodge(Vector2.ZERO)
	await _frames(30)
	_check(_near(_lost(r1), ARROW * 0.5), "On Dodge: a dodge sends one from you to the nearest enemy (%.3f)" % _lost(r1))
	p.global_position = home

	# --- Steady Aim -----------------------------------------------------------------------------
	await _bow(["steady_aim"], home)
	_check(p.steady == 0.0 and _near(p._speed(), 1.0), "Steady Aim starts at nothing")
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(120)
	_check(p.steady > 0.17 and p.steady <= 0.205, "two seconds of standing and shooting: about +20%% (%.3f)" % p.steady)
	_check(p.steady_step() == 2, "two of the ring's five steps are lit")
	await _frames(240)
	_check(_near(p.steady, 0.5) and _near(p._speed(), 1.5) and p.steady_step() == 5, "it stops at +50%%: the bow shoots half as fast again (%.3f)" % p.steady)
	p.input.move = Vector2.RIGHT
	await _frames(2)
	_check(p.steady == 0.0, "a step to the side and it is gone")
	p.input.move = Vector2.ZERO
	await _frames(60)
	_check(p.steady > 0.05, "standing again, it builds again")
	p.input.attack_held = false
	await _frames(60)
	var kept: float = p.steady
	await _frames(60)
	_check(kept > 0.0 and p.steady == kept, "not shooting, it neither builds nor goes (%.3f)" % kept)
	await _dodge(Vector2.ZERO)
	_check(p.steady == 0.0, "a dodge empties it")
	p.global_position = home

	await _bow(["on_dodge", "steady_aim"], home)
	p.steady = 0.3
	await _dodge(Vector2.RIGHT)
	_check(_near(p.steady, 0.3), "On Dodge: a dodge keeps it (%.2f)" % p.steady)
	await _frames(20)
	p.input.move = Vector2.RIGHT
	await _frames(2)
	p.input.move = Vector2.ZERO
	_check(p.steady == 0.0, "walking still empties it")
	p.global_position = home

	await _bow(["twice", "steady_aim"], home)
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(60)
	_check(p.steady > 0.17 and p.steady <= 0.205, "Twice: +20%% after one second (%.3f)" % p.steady)
	await _still()

	await _bow(["wider", "steady_aim"], home)
	p.steady = 0.79
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(30)
	_check(_near(p.steady, 0.8), "Wider: up to +80%% (%.3f)" % p.steady)
	await _still()

	await _bow(["every_hit", "steady_aim"], home)
	var post = _slime(Vector2(200, 0))
	await _frames(2)
	await _shots(1)
	# One shot: its draw and the rest of the move build a little, and the hit adds 5%.
	var one_shot: float = p.steady
	await _bow(["steady_aim"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	await _shots(1)
	_check(_near(one_shot - p.steady, 0.05, 0.004), "Every Hit: an arrow that lands adds 5%% (%.3f against %.3f)" % [one_shot, p.steady])

	await _bow(["saved_up", "steady_aim"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(180)
	p.input.attack_held = false
	_check(p.steady > 0.08 and p.steady <= 0.102, "Saved Up: it builds a third as fast, +10%% in three seconds (%.3f)" % p.steady)
	await _still()
	var before_burst: float = _lost(post)
	p.steady = 0.5
	p.steady_arrows = 0
	await _shots(3)
	_check(_near(_lost(post) - before_burst, ARROW * 2.0 + HEAVY * 3.0), "once it is full, every third arrow hits three times as hard (%.3f)" % (_lost(post) - before_burst))

	# Full, the bow does half as much again a second.
	await _bow(["steady_aim"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	p.steady = 0.5
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(30)
	var d0: float = _lost(post)
	await _frames(600)
	var full_dps: float = (_lost(post) - d0) / 10.0
	p.input.attack_held = false
	var plain_dps: float = ARROW * 2.545   # a plain shortbow looses about two and a half arrows a second (19.6 with the 7.7 arrows before version 57)
	_check(full_dps > plain_dps * 1.4 and full_dps < plain_dps * 1.6, "at +50%% the bow does about half as much again a second: %.1f against %.1f" % [full_dps, plain_dps])
	await _still()

	# --- Volley ---------------------------------------------------------------------------------
	await _bow(["volley"], home)
	var close = _slime(Vector2(50, 0))
	await _frames(2)
	await _press(0)
	_check(_arrows("volley").size() + (3 if _lost(close) > 0.0 else 0) >= 3, "Volley looses three arrows")
	_check(p.ability_charge[0] < 0.05, "and its button is spent")
	await _frames(30)
	_check(_near(_lost(close), ARROW * 3.0), "up close all three hit the same enemy (%.3f)" % _lost(close))
	await _press(0)
	await _frames(30)
	_check(_near(_lost(close), ARROW * 3.0) and p.game_time - float(p.ability_denied[0]) < 1.0, "pressed again too soon, nothing leaves")
	await _frames(200)
	_check(p.ability_ready(0), "four seconds later it is back")
	await _clear()
	var far = _slime(Vector2(300, 0))
	await _frames(2)
	await _press(0)
	await _frames(40)
	_check(_near(_lost(far), ARROW), "from far only the middle one hits (%.3f)" % _lost(far))

	await _bow(["wider", "volley"], home)
	await _press(0)
	_check(_arrows("volley").size() == 5, "Wider: five arrows (%d)" % _arrows("volley").size())
	await _bow(["twice", "volley"], home)
	close = _slime(Vector2(50, 0))
	await _frames(2)
	await _press(0)
	await _frames(40)
	_check(_near(_lost(close), ARROW * 6.0), "Twice: two volleys (%.3f)" % _lost(close))
	await _bow(["saved_up", "volley"], home)
	close = _slime(Vector2(50, 0))
	await _frames(2)
	await _press(0)
	await _frames(40)
	_check(_near(_lost(close), ARROW * 9.0) and _near(float(p.weapon["abilities"][0]["recharge"]), 12.0), "Saved Up: three times as strong, three times the recharge (%.3f)" % _lost(close))
	await _bow(["on_dodge", "volley"], home)
	close = _slime(Vector2(60, 0))
	await _frames(2)
	p.ability_charge[0] = 0.0
	await _dodge(Vector2.LEFT)
	await _frames(30)
	_check(_near(_lost(close), ARROW * 1.5), "On Dodge: a dodge looses one too, at half strength, button or no button (%.3f)" % _lost(close))
	p.global_position = home
	await _bow(["every_hit", "volley"], home)
	far = _slime(Vector2(200, 0))
	await _frames(2)
	p.ability_charge[0] = 0.0
	await _shots(1)
	# (One arrow's draw, flight and rest is about a second: that much comes back by itself.)
	var plain_back: float = p.ability_charge[0]
	await _bow(["volley"], home)
	far = _slime(Vector2(200, 0))
	await _frames(2)
	p.ability_charge[0] = 0.0
	await _shots(1)
	_check(_near(plain_back - float(p.ability_charge[0]), 0.5 / 4.0, 0.004), "Every Hit: an arrow that lands takes half a second off the recharge")

	# A rune's arrow sets no other rune off.
	await _bow(["volley", "ricochet"], home)
	close = _slime(Vector2(50, 0))
	var bystander = _slime(Vector2(50, 100))
	await _frames(2)
	await _press(0)
	await _frames(40)
	_check(_near(_lost(close), ARROW * 3.0) and _lost(bystander) == 0.0, "a Volley's arrows don't ricochet: a rune's arrow sets no other rune off")

	# --- Snipe ----------------------------------------------------------------------------------
	await _bow(["snipe"], home)
	far = _slime(Vector2(500, 0))
	await _frames(2)
	p.input.attack_held = true
	var on := [true, false, false]
	p.input.ability_pressed = on.duplicate()
	p.input.ability_held = on.duplicate()
	await _frames(1)
	p.input.ability_pressed = [false, false, false]
	await _frames(20)
	_check(p.snipe_button == 0 and _arrows().is_empty() and p.current_step < 0, "holding Snipe's button draws it: no arrow yet, and no chain shots meanwhile")
	_check(_near(float(p.ability_charge[0]), 1.0), "it isn't spent until it is let go")
	p.input.move = Vector2.UP
	await _frames(20)
	_check(_near(p.walk_vel.length(), Player.MOVE_SPEED * 0.5, 1.0), "you walk at half speed while you draw (%.0f)" % p.walk_vel.length())
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	await _frames(5)
	p.input.ability_held = [false, false, false]
	p.global_position = home
	await _frames(1)
	# Held 46 ticks in all: 0.77 s, inside the perfect moment (0.7 to 0.95 s).
	_check(p.snipe_button < 0 and _arrows("snipe").size() == 1 and p.snipe_perfect, "let go as the ring closes: a perfect shot leaves")
	_check(p.ability_charge[0] < 0.05, "and the button is spent")
	await _frames(40)
	_check(_lost(far) > ARROW * 6.0 * 1.5 * 0.97 and _lost(far) <= ARROW * 6.0 * 1.5 + 0.01, "from far away a perfect Snipe is nine arrows' worth (%.2f of %.2f)" % [_lost(far), ARROW * 9.0])

	await _bow(["snipe"], home)
	far = _slime(Vector2(500, 0))
	await _frames(2)
	await _press(0, 10)
	await _frames(40)
	_check(_near(_lost(far), ARROW * 6.0 * 0.5), "let go too early: half strength (%.2f)" % _lost(far))
	await _bow(["snipe"], home)
	far = _slime(Vector2(500, 0))
	await _frames(2)
	await _press(0, 70)
	await _frames(40)
	_check(_near(_lost(far), ARROW * 6.0) and not p.snipe_perfect, "held past the moment: a plain full shot (%.2f)" % _lost(far))
	await _bow(["snipe"], home)
	close = _slime(Vector2(40, 0))
	await _frames(2)
	await _press(0, 45)
	await _frames(40)
	var want_near: float = ARROW * lerpf(2.0, 6.0, 22.0 / 480.0) * 1.5
	_check(_near(_lost(close), want_near, 0.05), "up close even a perfect one is little more than three arrows (%.2f, want %.2f)" % [_lost(close), want_near])
	await _bow(["snipe"], home)
	far = _slime(Vector2(500, 0))
	await _frames(2)
	p.input.ability_pressed = on.duplicate()
	p.input.ability_held = on.duplicate()
	await _frames(1)
	p.input.ability_pressed = [false, false, false]
	await _frames(20)
	p.input.dash_pressed = true
	await _frames(1)
	p.input.dash_pressed = false
	await _frames(20)
	p.input.ability_held = [false, false, false]
	await _frames(30)
	_check(p.snipe_button < 0 and _lost(far) == 0.0 and _near(float(p.ability_charge[0]), 1.0), "a dodge drops the draw, and the rune isn't used up")
	p.global_position = home
	await _still(20)
	p.input.ability_pressed = on.duplicate()
	p.input.ability_held = on.duplicate()
	await _frames(1)
	p.input.ability_pressed = [false, false, false]
	await _frames(180)
	_check(p.snipe_button < 0 and _lost(far) > 0.0, "held for two and a half seconds, it goes by itself")
	p.input.ability_held = [false, false, false]

	await _bow(["wider", "snipe"], home)
	far = _slime(Vector2(500, 0))
	await _frames(2)
	await _press(0, 62)
	await _frames(40)
	_check(_near(_lost(far), ARROW * 9.0), "Wider: a longer perfect moment (let go after a second: %.2f)" % _lost(far))
	await _bow(["twice", "snipe"], home)
	far = _slime(Vector2(500, 0))
	await _frames(2)
	await _press(0, 70)
	await _frames(60)
	_check(_near(_lost(far), ARROW * 12.0), "Twice: two shots (%.2f)" % _lost(far))
	await _bow(["saved_up", "snipe"], home)
	far = _slime(Vector2(500, 0))
	await _frames(2)
	await _press(0, 70)
	await _frames(40)
	_check(_near(_lost(far), ARROW * 18.0) and _near(float(p.weapon["abilities"][0]["recharge"]), 18.0), "Saved Up: three times as strong, three times the recharge (%.2f)" % _lost(far))
	await _bow(["on_dodge", "snipe"], home)
	far = _slime(Vector2(500, 0))
	await _frames(2)
	await _dodge(Vector2.ZERO)
	await _frames(40)
	_check(_lost(far) > 0.0 and _lost(far) <= ARROW * 6.0 * 0.25 + 0.01, "On Dodge: a dodge looses a quick, weak one (%.2f)" % _lost(far))
	p.global_position = home

	# --- Arrow Rain -----------------------------------------------------------------------------
	await _bow(["arrow_rain"], home)
	var mid = _slime(Vector2(250, 0))
	var edge = _slime(Vector2(350, 0))
	var outside = _slime(Vector2(250, 120))
	await _frames(2)
	await _press(0)
	_check(p.rains.size() == 1 and (p.rains[0]["at"] as Vector2).distance_to(mid.global_position) < 1.0, "Arrow Rain marks the ground under the enemy you aim at")
	await _frames(30)
	_check(_near(_lost(mid), ARROW * 0.35), "its arrows start to fall: the first after 0.3 s (%.3f)" % _lost(mid))
	await _frames(170)
	_check(_near(_lost(mid), ARROW * 3.5) and p.rains.is_empty(), "three seconds of rain is ten falls: three and a half arrows' worth (%.3f)" % _lost(mid))
	_check(_near(_lost(edge), ARROW * 3.5), "to everyone standing on the marked ground")
	_check(_lost(outside) == 0.0, "and nobody outside it")
	await _clear()
	await _frames(300)
	await _press(0)
	_check(p.rains.size() == 1 and (p.rains[0]["at"] as Vector2).distance_to(home + Vector2(200, 0)) < 1.0, "with nobody near your aim it lands 200 px ahead")
	await _frames(200)
	# A mouse: the mark goes where the pointer is, no further than 420 px.
	p.input.kind = "net"
	p.input.using_pad = false
	p.input.aim_offset = Vector2(120, -90)
	p.ability_charge[0] = 1.0
	await _press(0)
	_check(p.rains.size() == 1 and (p.rains[0]["at"] as Vector2).distance_to(p.global_position + Vector2(120, -90)) < 1.0, "with a mouse it lands on the pointer")
	await _frames(200)
	p.input.aim_offset = Vector2(900, 0)
	p.ability_charge[0] = 1.0
	await _press(0)
	_check(p.rains.size() == 1 and _near((p.rains[0]["at"] as Vector2).distance_to(p.global_position), 420.0, 0.5), "and no further away than 420 px")
	p.input.kind = "script"
	p.input.aim_offset = Vector2.ZERO
	await _frames(200)

	await _bow(["arrow_rain"], home)
	mid = _slime(Vector2(250, 0))
	edge = _slime(Vector2(250 + 140, 0))
	await _frames(2)
	await _press(0)
	await _frames(200)
	_check(_lost(edge) == 0.0, "an enemy 140 px from the middle is outside it")
	await _bow(["wider", "arrow_rain"], home)
	mid = _slime(Vector2(250, 0))
	edge = _slime(Vector2(250 + 140, 0))
	await _frames(2)
	await _press(0)
	await _frames(200)
	_check(_near(_lost(edge), ARROW * 3.5), "Wider: a bigger area reaches it")
	await _bow(["twice", "arrow_rain"], home)
	mid = _slime(Vector2(250, 0))
	await _frames(2)
	await _press(0)
	await _frames(200)
	_check(p.rains.size() == 1 and _lost(mid) > ARROW * 3.5, "Twice: a second shower comes as the first ends")
	await _frames(200)
	_check(_near(_lost(mid), ARROW * 7.0) and p.rains.is_empty(), "twenty falls in all (%.3f)" % _lost(mid))
	await _bow(["saved_up", "arrow_rain"], home)
	mid = _slime(Vector2(250, 0))
	mid.knock_resist = 1.0
	await _frames(2)
	await _press(0)
	await _frames(30)
	_check(_near(_lost(mid), ARROW * 0.35 * 3.0) and mid.stun_time > 0.0, "Saved Up: each fall is three times as heavy and pins what it hits (%.3f)" % _lost(mid))
	_check(_near(float(p.weapon["abilities"][0]["recharge"]), 24.0), "for three times the recharge")
	await _frames(170)
	await _bow(["on_dodge", "arrow_rain"], home)
	mid = _slime(Vector2(0, 40))
	await _frames(2)
	p.ability_charge[0] = 0.0
	await _dodge(Vector2.LEFT)
	_check(p.rains.size() == 1 and (p.rains[0]["at"] as Vector2).distance_to(home) < 1.0, "On Dodge: a small shower falls where you dodged from")
	await _frames(80)
	_check(_near(_lost(mid), ARROW * 0.35 * 3.0) and p.rains.is_empty(), "one second of it: three falls (%.3f)" % _lost(mid))
	p.global_position = home

	# The rain belongs to the ground, not the hand: it goes on after a swap.
	await _bow(["arrow_rain"], home)
	mid = _slime(Vector2(250, 0))
	await _frames(2)
	await _press(0)
	await _frames(20)
	m.swap_weapon(0, "sword")
	await _frames(180)
	_check(m.build.weapon() == "sword" and _near(_lost(mid), ARROW * 3.5), "swap to the sword and the rain keeps falling (%.3f)" % _lost(mid))
	m.swap_weapon(0, "bow")
	await _frames(2)

	# --- The numbers the two computers compare (online) ------------------------------------
	var state: Array = m.net_state()
	_check(state.has(p.steady) and state.size() > 20, "Steady Aim, Snipe's draw and the rain are in the online checksum")

	await _clear()
	print("RESULT: %s" % ("all passed" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
