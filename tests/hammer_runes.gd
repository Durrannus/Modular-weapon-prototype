extends SceneTree
## Checks for the hammer's six runes (15 November), run in the real arena with a
## scripted player: Momentum, Stagger and Aftershock (passive), Quake, Bulwark and
## Hook (on the ability buttons), and what every band does to each.
##   godot --headless --path . --fixed-fps 60 -s tests/hammer_runes.gd

const EnemyScript := preload("res://scripts/enemy.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Player := preload("res://scripts/player.gd")
const Art := preload("res://scripts/art.gd")
const BowArt := preload("res://scripts/weapon/bow_art.gd")

const SWING := 18.7          # one swing of the iron maul
const SLAM := 28.05          # the chain's third move
const CHAIN := 65.45         # swing, swing, slam
const RUNES := ["momentum", "stagger", "aftershock", "quake", "bulwark", "hook"]

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


## A slime that stands where it's put and can't be killed or shoved. `stuns`: it
## can be stunned (what nothing shoves, nothing stuns either: see apply_stun).
func _slime(offset: Vector2, stuns := false):
	var e = EnemyScript.new()
	e.kind = "slime"
	e.position = p.global_position + offset
	m.world.add_child(e)
	e.max_hp = 500000.0
	e.hp = 500000.0
	e.speed = 0.0
	e.contact_damage = 0.0
	e.knock_resist = 0.001 if stuns else 0.0
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


func _still(frames := 40) -> void:
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.input.dash_pressed = false
	p.input.ability_held = [false, false, false]
	p.input.ability_pressed = [false, false, false]
	p.input.stick_aim = Vector2.RIGHT
	p._reset_combo()
	await _frames(frames)
	p._reset_combo()
	p.weapon["crit"] = 0.0   # no luck in the sums


## Puts this hammer in the hand: an iron maul on the bound haft (four slots), with
## these fittings bottom to top.
func _hammer(line: Array, home: Vector2) -> void:
	await _clear()
	while line.size() < 4:
		line.append("")
	m.build.set_data(["iron_maul", "bound_haft", "plain_weight", line])
	m.build.changed.emit()
	await _still()
	p.global_position = home
	p.reset_physics_interpolation()
	p.dodge_charges = 1
	p.ability_charge = [1.0, 1.0, 1.0]
	p.ability_wait = [0.0, 0.0, 0.0]
	p.hp = p.max_hp
	p.invuln = 0.0
	await _frames(2)
	p.weapon["crit"] = 0.0


## Swings the first `count` moves of the chain and waits for the last to end.
func _swings(count: int) -> void:
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
	await _frames(10)
	p._reset_combo()


## Presses ability button `b`.
func _press(b: int) -> void:
	var on := [false, false, false]
	on[b] = true
	p.input.ability_pressed = on.duplicate()
	p.input.ability_held = on.duplicate()
	await _frames(1)
	p.input.ability_pressed = [false, false, false]
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


## Waits for the rumbles on their way to go off.
func _rumbled() -> void:
	for i in 200:
		if p.rumbles.is_empty():
			break
		await _frames(1)
	await _frames(4)


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

	# --- The rules: six runes, the hammer's own -----------------------------------------
	var passive := 0
	var active := 0
	for id in RUNES:
		var f: Dictionary = SwingBuild.FITTINGS.get(id, {})
		_check(f.get("kind", "") == "rune" and f.get("weapon", "") == "hammer" and not f.get("parked", false) and id in SwingBuild.FITTING_ORDER, "%s is a hammer rune in the forge" % id)
		if f.get("trigger", "") == "active":
			active += 1
		else:
			passive += 1
		for pic in ["icon", "forge", "forge_lit", "hand", "hand_lit"]:
			if Art.texture("swing/runes/%s_%s.png" % [id, pic]) == null:
				_check(false, "%s has its %s picture" % [id, pic])
		_check(Art.texture("swing/previews/%s.png" % id) != null, "%s has a preview picture" % id)
	_check(passive == 3 and active == 3, "three passive, three active")
	for g in ["quake", "bulwark", "hook"]:
		_check(Art.texture("hud/glyph_%s.png" % g) != null, "%s has its button glyph" % g)
	for fx in ["momentum_ring", "stagger_break", "stagger_stars", "aftershock_crack", "aftershock_burst", "quake_erupt", "bulwark_shield", "bulwark_block", "bulwark_end"]:
		_check(BowArt.fx_texture(fx) != null and not BowArt.fx(fx).is_empty(), "effect strip %s is in the game" % fx)
	_check(Art.texture("hud/stagger_frame.png") != null and Art.texture("hud/stagger_fill.png") != null, "the stagger meter has its pictures")
	_check(SwingBuild.valid_data(["iron_maul", "bound_haft", "plain_weight", ["momentum", "quake", "twice", "bulwark"]]), "a hammer takes its runes")
	_check(not SwingBuild.valid_data(["iron_broadsword", "wrapped_grip", "plain_pommel", ["quake", "", "", ""]]), "a sword does not")
	_check(not SwingBuild.valid_data(["iron_shortbow", "wrapped_bow_grip", "plain_string", ["hook", "", "", ""], "iron_arrows"]), "nor a bow")
	var test_abilities: Array = SwingBuild.abilities(SwingBuild.resolve(SwingBuild.TEST_HAMMER[3])["effects"])
	var got: Array = []
	for a in test_abilities:
		got.append([a["id"], a["use"], a["recharge"]])
	_check(got == [["quake", "press", 5.0], ["bulwark", "press", 10.0], ["hook", "press", 4.0]], "the arena's hammer has Quake, Bulwark and Hook on its three buttons: %s" % [got])
	_check(_near(SwingBuild.momentum_step(_effect(["momentum"])), 0.08) and _near(SwingBuild.momentum_step(_effect(["wider", "momentum"])), 0.128), "Momentum: +8% a step, +13% with Wider")
	_check(_near(SwingBuild.momentum_step(_effect(["saved_up", "momentum"])), 0.2) and _near(SwingBuild.momentum_step(_effect(["wider", "saved_up", "momentum"])), 0.2), "a step is never more than +20%: at its most Momentum doubles a swing")
	_check(_near(SwingBuild.bulwark_time(1.0, 1.0), 3.0) and _near(SwingBuild.bulwark_time(SwingBuild.wider_size(1), 1.0), 4.0) and _near(SwingBuild.bulwark_time(1.0, 3.0), 9.0), "Bulwark: 3 seconds, 4 with Wider, 9 with Saved Up")
	_check(SwingBuild.bulwark_hits(3.0) == 3 and SwingBuild.bulwark_hits(4.0) == 4 and SwingBuild.bulwark_hits(9.0) == 9 and SwingBuild.bulwark_hits(1.0) == 1, "and it takes a hit for each of those seconds: 3, 4, 9, and one for a dodge's")
	var says := {
		["momentum"]: "Each swing that lands adds a step of +8% to your swings, up to +40%. Stop hitting and it drains away.",
		["twice", "momentum"]: "Each swing that lands adds two steps of +8% to your swings, up to +40%. Stop hitting and it drains away.",
		["wider", "momentum"]: "Each swing that lands adds a step of +13% to your swings, up to +64%. Stop hitting and it drains away.",
		["every_hit", "momentum"]: "Each enemy you hit adds a step of +8% to your swings, up to +40%. Stop hitting and it drains away.",
		["saved_up", "momentum"]: "Every third swing that lands adds a step of +20% to your swings, up to +100%. Stop hitting and it drains away.",
		["on_dodge", "momentum"]: "Each swing that lands adds a step of +8% to your swings, up to +40%. Stop hitting and it drains away. A dodge counts as a hit.",
		["stagger"]: "Your hits fill a meter on the enemy. When it is full the enemy takes a heavy blow and is stunned for 1.5 seconds.",
		["twice", "stagger"]: "Your hits fill a meter on the enemy twice as fast. When it is full the enemy takes a heavy blow and is stunned for 1.5 seconds.",
		["wider", "stagger"]: "Your hits fill a meter on the enemy. When it is full the enemy takes a heavy blow and is stunned for 1.5 seconds, and so is everything near it.",
		["saved_up", "stagger"]: "Your hits fill a meter on the enemy slowly. When it is full the enemy takes a huge blow and is stunned for 4.5 seconds.",
		["on_dodge", "stagger"]: "Your hits fill a meter on the enemy. When it is full the enemy takes a heavy blow and is stunned for 1.5 seconds. Dodging past an enemy counts as a hit on it.",
		["aftershock"]: "Your finisher sets off a rumble in the ground a moment later that hurts whatever is still near.",
		["twice", "aftershock"]: "Your finisher sets off two rumbles in the ground a moment later that hurt whatever is still near.",
		["wider", "aftershock"]: "Your finisher sets off a big rumble in the ground a moment later that hurts whatever is still near.",
		["every_hit", "aftershock"]: "Every hit sets off a small rumble in the ground a moment later that hurts whatever is still near, at half strength.",
		["saved_up", "aftershock"]: "Every third finisher sets off a huge rumble in the ground a moment later that hurts whatever is still near, three times as strong.",
		["on_dodge", "aftershock"]: "Your finisher sets off a rumble in the ground a moment later that hurts whatever is still near. A dodge leaves one where you were.",
		["quake"]: "Press right mouse: the ground erupts under the enemy nearest your aim. Recharges in 5 seconds.",
		["twice", "quake"]: "Press right mouse: the ground erupts under the enemy nearest your aim, then under the next one. Recharges in 5 seconds.",
		["wider", "quake"]: "Press right mouse: the ground erupts under the enemy nearest your aim, over a bigger patch. Recharges in 5 seconds.",
		["every_hit", "quake"]: "Press right mouse: the ground erupts under the enemy nearest your aim. Recharges in 5 seconds. Each hit you land takes half a second off.",
		["saved_up", "quake"]: "Press right mouse: the ground erupts under the enemy nearest your aim, three times as strong. Recharges in 15 seconds.",
		["on_dodge", "quake"]: "Press right mouse: the ground erupts under the enemy nearest your aim. Recharges in 5 seconds. Dodging sets one off too, at half strength.",
		["bulwark"]: "Press right mouse: for 3 seconds a shield blocks three hits; the third bursts it, stunning enemies near you. Recharges in 10 seconds.",
		["twice", "bulwark"]: "Press right mouse: for 3 seconds a shield blocks three hits; the third bursts it, stunning enemies near you for twice as long. Recharges in 10 seconds.",
		["wider", "bulwark"]: "Press right mouse: for 4 seconds a shield blocks four hits; the fourth bursts it, stunning enemies near you. Recharges in 10 seconds.",
		["saved_up", "bulwark"]: "Press right mouse: for 9 seconds a shield blocks nine hits; the ninth bursts it, stunning enemies near you. Recharges in 30 seconds.",
		["on_dodge", "bulwark"]: "Press right mouse: for 3 seconds a shield blocks three hits; the third bursts it, stunning enemies near you. Recharges in 10 seconds. Dodging puts it up for a second.",
		["hook"]: "Press right mouse: a chain drags the enemy nearest your aim to you. Recharges in 4 seconds.",
		["twice", "hook"]: "Press right mouse: a chain drags the enemy nearest your aim to you, then another. Recharges in 4 seconds.",
		["wider", "hook"]: "Press right mouse: a chain drags the enemy nearest your aim to you from further away. Recharges in 4 seconds.",
		["every_hit", "hook"]: "Press right mouse: a chain drags the enemy nearest your aim to you. Recharges in 4 seconds. Each hit you land takes half a second off.",
		["saved_up", "hook"]: "Press right mouse: a chain drags the enemy nearest your aim to you, stunned for 2 seconds. Recharges in 12 seconds.",
		["on_dodge", "hook"]: "Press right mouse: a chain drags the enemy nearest your aim to you. Recharges in 4 seconds. Dodging throws a quick one at the nearest enemy.",
	}
	for line in says:
		var said: String = SwingBuild.sentence(_effect(line))
		_check(said == says[line], "%s reads: %s" % [line, said])
	var none: Dictionary = SwingBuild.resolve(["every_hit", "stagger"])
	_check(none["slots"][0].get("unused", false) and str(none["slots"][0].get("why", "")) == "Stagger already works on every hit.", "Every Hit under Stagger does nothing, and the forge says why")

	# --- In the arena: the test hammer ---------------------------------------------------
	m.swap_weapon(0, "hammer")
	await _frames(2)
	_check(m.build.weapon() == "hammer" and p.weapon["abilities"].size() == 3, "the arena's hammer comes with its three buttons")
	_check(p.weapon["effects"].size() == 4 and p.weapon["effects"][3]["id"] == "aftershock", "and Aftershock as its passive rune")

	# --- Momentum -----------------------------------------------------------------------
	await _hammer(["momentum"], home)
	var post = _slime(Vector2(40, 0))
	await _frames(2)
	await _swings(3)
	_check(_near(_lost(post), SWING + SWING * 1.08 + SLAM * 1.16), "Momentum: each swing that lands makes the next 8%% harder: 18.7, 20.196, then a slam of 32.538 (%.3f)" % _lost(post))
	_check(p.momentum == 3 and _near(p.momentum_bonus(), 0.24), "three steps after a chain")
	await _swings(3)
	_check(p.momentum == 5 and _near(p.momentum_bonus(), 0.4) and p.momentum_full, "five steps at the most: +40%")
	_check(_near(_lost(post), SWING * (1.0 + 1.08 + 1.24 + 1.32) + SLAM * (1.16 + 1.4)), "the second chain: 23.188, 24.684 and a slam of 39.27 (%.3f)" % _lost(post))
	post.hp = post.max_hp
	await _swings(3)
	_check(_near(_lost(post), CHAIN * 1.4), "and there it stays while you keep hitting: a whole chain at +40%% (%.3f)" % _lost(post))
	# Stop hitting: after two seconds a step goes every half second.
	p.momentum_idle = 0.0
	await _frames(144)
	_check(p.momentum == 5, "it holds for two seconds after the last hit")
	await _frames(12)
	_check(p.momentum == 4 and not p.momentum_full, "then it drains: a step is gone at 2.5 seconds")
	await _frames(60)
	_check(p.momentum == 2, "and one more every half second")
	await _frames(90)
	_check(p.momentum == 0 and p.momentum_bonus() == 0.0, "until none is left")
	await _clear()
	await _swings(3)
	_check(p.momentum == 0, "a swing that hits nothing builds none")
	# One swing is one step, however many it catches.
	var two_a = _slime(Vector2(45, -30))
	var two_b = _slime(Vector2(45, 30))
	await _frames(2)
	await _swings(1)
	_check(_near(_lost(two_a), SWING) and _near(_lost(two_b), SWING) and p.momentum == 1, "a swing that catches two enemies is still one step")
	m.swap_weapon(0, "sword")
	await _frames(2)
	_check(p.momentum == 0 and p.momentum_rune.is_empty(), "it is the hammer's: put the hammer away and it is gone")
	m.swap_weapon(0, "hammer")
	await _frames(2)

	await _hammer(["twice", "momentum"], home)
	post = _slime(Vector2(40, 0))
	await _frames(2)
	await _swings(2)
	_check(p.momentum == 4 and _near(_lost(post), SWING + SWING * 1.16), "Twice: two steps a swing (%.3f)" % _lost(post))

	await _hammer(["wider", "momentum"], home)
	post = _slime(Vector2(40, 0))
	await _frames(2)
	await _swings(2)
	_check(p.momentum == 2 and _near(_lost(post), SWING + SWING * 1.128), "Wider: bigger steps, +12.8%% each (%.3f)" % _lost(post))

	await _hammer(["saved_up", "momentum"], home)
	post = _slime(Vector2(40, 0))
	await _frames(2)
	await _swings(3)
	_check(p.momentum == 1 and _near(_lost(post), CHAIN), "Saved Up: a step only on every third swing that lands (%.3f)" % _lost(post))
	post.hp = post.max_hp
	await _swings(1)
	_check(_near(_lost(post), SWING * 1.2), "but a big one: +20%% (%.3f)" % _lost(post))

	await _hammer(["every_hit", "momentum"], home)
	two_a = _slime(Vector2(45, -30))
	two_b = _slime(Vector2(45, 30))
	await _frames(2)
	await _swings(1)
	_check(p.momentum == 2, "Every Hit: every enemy the swing catches is a step")

	await _hammer(["on_dodge", "momentum"], home)
	await _dodge()
	_check(p.momentum == 1, "On Dodge: a dodge counts as a hit")
	await _still()

	# Momentum is for your swings: what a rune does stays as it was.
	await _hammer(["momentum", "quake"], home)
	post = _slime(Vector2(40, 0))
	await _frames(2)
	await _swings(3)
	await _swings(3)
	var before: float = _lost(post)
	_check(p.momentum == 5, "(five steps built)")
	await _press(0)
	await _frames(10)
	_check(_near(_lost(post) - before, SLAM), "Momentum makes swings hit harder, not runes: a Quake is still 28.05 (%.3f)" % (_lost(post) - before))

	# --- Stagger ------------------------------------------------------------------------
	await _hammer(["stagger"], home)
	post = _slime(Vector2(40, 0), true)
	await _frames(2)
	await _swings(3)
	_check(_near(post.stagger, 3.5) and _near(_lost(post), CHAIN, 0.02), "Stagger: a chain fills three and a half of the meter's four (a slam counts one and a half): %.2f" % post.stagger)
	_check(post.staggered == 0.0, "not full yet, nothing happens")
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	var broke := 0.0
	var stunned := 0.0
	for i in 60:
		await _frames(1)
		if post.staggered > 0.0 and broke == 0.0:
			broke = post.staggered
			stunned = post.stun_time
	await _still()
	_check(_near(_lost(post), CHAIN + SWING * 2.0, 0.02), "the next swing fills it: the enemy takes the swing and a heavy blow of another 18.7 (%.3f)" % _lost(post))
	_check(broke > 1.4 and broke <= 1.5 and stunned > 1.4 and stunned <= 1.5, "and is stunned for 1.5 seconds (%.2f, %.2f)" % [broke, stunned])
	_check(post.stagger == 0.0, "the meter is empty again")
	post.staggered = 1.0
	_check(not post.add_stagger(1.0) and post.stagger == 0.0, "while it is staggered the meter doesn't fill")
	post.staggered = 0.0
	post.stun_time = 0.0
	await _frames(2)
	await _swings(2)
	_check(_near(post.stagger, 2.0), "afterwards it fills again from nothing")
	post.stagger_idle = 0.0
	await _frames(170)
	_check(_near(post.stagger, 2.0), "leave the enemy alone and the meter holds for three seconds")
	await _frames(40)
	_check(post.stagger > 0.8 and post.stagger < 1.4, "then it empties (%.2f)" % post.stagger)
	await _frames(60)
	_check(post.stagger == 0.0, "all the way")

	# What nothing stuns (the forge guardian) takes the blow and no more.
	await _hammer(["stagger"], home)
	var rock = _slime(Vector2(40, 0))
	await _frames(2)
	await _swings(3)
	await _swings(1)
	_check(_near(_lost(rock), CHAIN + SWING * 2.0) and rock.staggered == 0.0 and rock.stun_time == 0.0 and rock.stagger == 0.0, "an enemy that can't be stunned only takes the blow (%.3f)" % _lost(rock))

	await _hammer(["twice", "stagger"], home)
	post = _slime(Vector2(40, 0), true)
	await _frames(2)
	await _swings(1)
	_check(_near(post.stagger, 2.0) and post.staggered == 0.0, "Twice: a swing fills two")
	post.stun_time = 0.0
	await _swings(1)
	_check(_near(_lost(post), SWING * 3.0, 0.02) and post.staggered > 0.0, "so the second swing breaks it (%.3f)" % _lost(post))

	await _hammer(["saved_up", "stagger"], home)
	post = _slime(Vector2(40, 0), true)
	await _frames(2)
	await _swings(3)
	_check(_near(post.stagger, 3.5 / 3.0), "Saved Up: the meter fills a third as fast (%.3f after a chain)" % post.stagger)
	await _swings(3)
	await _swings(3)
	_check(_near(post.stagger, 3.5) and post.staggered == 0.0, "three chains and it still holds")
	post.hp = post.max_hp
	await _swings(1)
	_check(post.staggered == 0.0, "eleven swings: not yet")
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	broke = 0.0
	for i in 60:
		await _frames(1)
		if post.staggered > 0.0 and broke == 0.0:
			broke = post.staggered
	await _still()
	_check(_near(_lost(post), SWING * 2.0 + SWING * 3.0, 0.03), "the twelfth breaks it with a huge blow: three swings' worth, 56.1 (%.3f)" % (_lost(post) - SWING * 2.0))
	_check(broke > 4.4 and broke <= 4.5, "and a stun of 4.5 seconds (%.2f)" % broke)

	# Wider: the break stuns what stands near it too (80 px round it).
	await _hammer(["stagger"], home)
	post = _slime(Vector2(40, 0), true)
	var beside = _slime(Vector2(130, 0), true)
	await _frames(2)
	await _swings(3)
	await _swings(1)
	_check(post.staggered > 0.0 and beside.staggered == 0.0 and beside.stun_time == 0.0, "a plain break stuns only the enemy it is on")
	await _hammer(["wider", "stagger"], home)
	post = _slime(Vector2(40, 0), true)
	beside = _slime(Vector2(130, 0), true)
	var apart = _slime(Vector2(40, 140), true)
	await _frames(2)
	await _swings(3)
	await _swings(1)
	_check(post.staggered > 0.0 and beside.staggered > 0.0 and beside.stun_time > 0.5 and _lost(beside) == 0.0, "Wider: it stuns what stands near it too (and doesn't hurt it)")
	_check(apart.staggered == 0.0 and apart.stun_time == 0.0, "but not what stands 140 px off")

	# On Dodge: dodging past an enemy counts as a hit on it.
	await _hammer(["on_dodge", "stagger"], home)
	post = _slime(Vector2(50, 40), true)
	var off = _slime(Vector2(-150, 0), true)
	await _frames(2)
	await _dodge(Vector2.RIGHT)
	_check(_near(post.stagger, 1.0) and off.stagger == 0.0, "On Dodge: a dodge past an enemy fills its meter by a swing (%.2f)" % post.stagger)
	await _still()

	# --- Aftershock ---------------------------------------------------------------------
	# The slam lands 41 px in front. A rumble reaches 60 px from there (and an
	# enemy's own 14): one standing 95 px in front is out of the slam's reach and
	# inside the rumble's; one at 121 px is outside both.
	await _hammer(["aftershock"], home)
	post = _slime(Vector2(40, 0))
	var near_by = _slime(Vector2(95, 0))
	var far_off = _slime(Vector2(121, 0))
	await _frames(2)
	p._reset_combo()
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	var waited := 0
	var at_slam := -1.0
	for i in 900:
		await _frames(1)
		if not p.rumbles.is_empty() and at_slam < 0.0:
			at_slam = _lost(near_by)
			p.input.attack_held = false
		if at_slam >= 0.0:
			if p.rumbles.is_empty():
				break
			waited += 1
	await _still()
	_check(at_slam == 0.0, "Aftershock: when the slam lands the ground only cracks")
	_check(waited >= 34 and waited <= 38, "0.6 seconds later it rumbles (%d ticks)" % waited)
	_check(_near(_lost(post), CHAIN + SWING * 0.7), "the enemy the chain hit takes 13.09 more (%.3f)" % (_lost(post) - CHAIN))
	_check(_near(_lost(near_by), SWING * 0.7), "and so does one the slam missed, 54 px from where it landed (%.3f)" % _lost(near_by))
	_check(_lost(far_off) == 0.0, "but not one 80 px from it")
	post.queue_free()
	near_by.hp = near_by.max_hp
	await _frames(2)
	await _swings(3)
	await _rumbled()
	_check(_near(_lost(near_by), SWING * 0.7), "a finisher that hits nothing sets it off too (%.3f)" % _lost(near_by))
	near_by.hp = near_by.max_hp
	await _swings(2)
	await _frames(60)
	_check(_lost(near_by) == 0.0 and p.rumbles.is_empty(), "the swings before the finisher don't")

	await _hammer(["twice", "aftershock"], home)
	near_by = _slime(Vector2(95, 0))
	await _frames(2)
	await _swings(3)
	_check(p.rumbles.size() + roundi(_lost(near_by) / (SWING * 0.7)) == 2, "Twice: two rumbles, one after the other")
	await _rumbled()
	_check(_near(_lost(near_by), SWING * 0.7 * 2.0), "each as strong (%.3f)" % _lost(near_by))

	await _hammer(["wider", "aftershock"], home)
	far_off = _slime(Vector2(121, 0))
	var way_off = _slime(Vector2(166, 0))
	await _frames(2)
	await _swings(3)
	await _rumbled()
	_check(_near(_lost(far_off), SWING * 0.7) and _lost(way_off) == 0.0, "Wider: a bigger rumble reaches the one 80 px away (96 px round), not one 125 px away (%.3f)" % _lost(far_off))

	# Every Hit: a small rumble (42 px round) at half strength where every swing lands.
	await _hammer(["every_hit", "aftershock"], home)
	post = _slime(Vector2(40, 0))
	near_by = _slime(Vector2(95, 0))
	far_off = _slime(Vector2(121, 0))
	await _frames(2)
	await _swings(3)
	await _rumbled()
	_check(_near(_lost(post), CHAIN + SWING * 0.35 * 3.0), "Every Hit: every swing that lands sets off a small one at half strength: three of 6.545 (%.3f)" % (_lost(post) - CHAIN))
	_check(_near(_lost(near_by), SWING * 0.35 * 3.0) and _lost(far_off) == 0.0, "which reach less far")
	post.queue_free()
	near_by.hp = near_by.max_hp
	await _frames(2)
	await _swings(3)
	await _frames(80)
	_check(_lost(near_by) == 0.0, "and a swing that hits nothing sets off none")

	await _hammer(["saved_up", "aftershock"], home)
	near_by = _slime(Vector2(95, 0))
	far_off = _slime(Vector2(121, 0))
	way_off = _slime(Vector2(150, 0))
	await _frames(2)
	await _swings(3)
	await _swings(3)
	await _rumbled()
	_check(_lost(near_by) == 0.0, "Saved Up: the first two finishers set off nothing")
	await _swings(3)
	await _rumbled()
	_check(_near(_lost(near_by), SWING * 0.7 * 3.0) and _near(_lost(far_off), SWING * 0.7 * 3.0), "the third a huge one, three times as strong: 39.27 (%.3f)" % _lost(near_by))
	_check(_lost(way_off) == 0.0, "90 px round: it doesn't reach one 109 px away")

	await _hammer(["on_dodge", "aftershock"], home)
	near_by = _slime(Vector2(0, 60))
	await _frames(2)
	await _dodge(Vector2.RIGHT)
	_check(p.rumbles.size() == 1 and _lost(near_by) == 0.0, "On Dodge: a dodge leaves one behind")
	await _rumbled()
	_check(_near(_lost(near_by), SWING * 0.7) and p.global_position.distance_to(home) > 60.0, "where you were, not where you are now (%.3f)" % _lost(near_by))
	await _still()

	# --- Quake --------------------------------------------------------------------------
	await _hammer(["quake"], home)
	var target = _slime(Vector2(150, 0), true)
	var close_by = _slime(Vector2(150, 50))
	var outside = _slime(Vector2(150, 110))
	await _frames(2)
	await _press(0)
	_check(_near(_lost(target), SLAM) and _near(_lost(close_by), SLAM), "Quake: the ground erupts under the enemy in front for a swing and a half, 28.05, and catches one 50 px from it (%.3f, %.3f)" % [_lost(target), _lost(close_by)])
	_check(_lost(outside) == 0.0, "44 px round: not one 110 px away")
	_check(target.stun_time > 0.5 and target.stun_time <= 0.6, "it stuns for 0.6 seconds (%.2f)" % target.stun_time)
	_check(p.ability_charge[0] < 0.05, "and its button is spent")
	await _press(0)
	await _frames(10)
	_check(_near(_lost(target), SLAM) and p.game_time - float(p.ability_denied[0]) < 1.0, "pressed again too soon, nothing happens")
	await _frames(300)
	_check(p.ability_ready(0), "five seconds later it is back")

	# The enemy you are pointing at, not just the nearest.
	await _hammer(["quake"], home)
	var beside_you = _slime(Vector2(20, -100))
	var aimed = _slime(Vector2(200, 0))
	var behind = _slime(Vector2(-60, 0))
	await _frames(2)
	await _press(0)
	_check(_near(_lost(aimed), SLAM) and _lost(beside_you) == 0.0 and _lost(behind) == 0.0, "it picks the enemy you aim at over a nearer one to the side or behind")
	await _hammer(["quake"], home)
	behind = _slime(Vector2(-60, 0))
	await _frames(2)
	await _press(0)
	_check(_near(_lost(behind), SLAM), "with nobody in front it takes the one behind")
	await _hammer(["quake"], home)
	var too_far = _slime(Vector2(280, 0))
	var ahead = _slime(Vector2(120, 30))
	ahead.immune = true
	await _frames(2)
	await _press(0)
	_check(_lost(too_far) == 0.0 and p.ability_charge[0] < 0.05, "with nobody within 240 px it erupts a little way in front of you")

	await _hammer(["twice", "quake"], home)
	target = _slime(Vector2(150, 0))
	var second = _slime(Vector2(150, 150))
	await _frames(2)
	await _press(0)
	_check(_near(_lost(target), SLAM) and _lost(second) == 0.0, "Twice: first under the one you aim at")
	await _frames(30)
	_check(_near(_lost(target), SLAM) and _near(_lost(second), SLAM), "then under the next one (%.3f, %.3f)" % [_lost(target), _lost(second)])
	second.queue_free()
	target.hp = target.max_hp
	p.ability_charge[0] = 1.0
	await _frames(70)
	await _press(0)
	await _frames(30)
	_check(_near(_lost(target), SLAM * 2.0), "with only one enemy about, twice under that one (%.3f)" % _lost(target))

	await _hammer(["wider", "quake"], home)
	target = _slime(Vector2(150, 0))
	outside = _slime(Vector2(150, 80))
	await _frames(2)
	await _press(0)
	_check(_near(_lost(outside), SLAM), "Wider: a bigger patch (70 px round) catches one 80 px from the middle")
	await _hammer(["quake"], home)
	target = _slime(Vector2(150, 0))
	outside = _slime(Vector2(150, 80))
	await _frames(2)
	await _press(0)
	_check(_lost(outside) == 0.0, "which a plain one misses")

	await _hammer(["saved_up", "quake"], home)
	target = _slime(Vector2(150, 0))
	await _frames(2)
	await _press(0)
	_check(_near(_lost(target), SLAM * 3.0) and _near(float(p.weapon["abilities"][0]["recharge"]), 15.0), "Saved Up: three times as strong, 84.15, and three times the recharge (%.3f)" % _lost(target))

	await _hammer(["on_dodge", "quake"], home)
	target = _slime(Vector2(150, 0))
	await _frames(2)
	await _dodge(Vector2.UP)
	await _frames(5)
	_check(_near(_lost(target), SLAM * 0.5) and float(p.ability_charge[0]) >= 1.0, "On Dodge: a dodge sets one off at half strength, 14.025, and leaves the button full (%.3f)" % _lost(target))
	await _still()

	await _hammer(["every_hit", "quake"], home)
	post = _slime(Vector2(40, 0))
	await _frames(2)
	await _press(0)
	await _frames(20)
	p.ability_charge[0] = 0.0
	var jump := 0.0
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	for i in 60:
		var last: float = p.ability_charge[0]
		await _frames(1)
		jump = maxf(jump, float(p.ability_charge[0]) - last)
	_check(_near(jump, 0.5 / 5.0 + 1.0 / 300.0, 0.004) and p.game_time - float(p.ability_refunded[0]) < 2.0, "Every Hit: a swing that lands takes half a second off Quake's five (%.3f of the meter)" % jump)
	await _still()

	# --- Bulwark ------------------------------------------------------------------------
	m._set_invincible(false)
	await _hammer(["bulwark"], home)
	var biter = _slime(Vector2(60, 0), true)
	await _frames(2)
	await _press(0)
	_check(p.bulwark_left > 2.9 and p.bulwark_left <= 3.0 and is_instance_valid(p.bulwark_fx), "Bulwark: the shield goes up for 3 seconds (%.2f)" % p.bulwark_left)
	var hp0: float = p.hp
	_check(p.bulwark_hits == 3, "it can take three hits (%d)" % p.bulwark_hits)
	p.take_damage(10.0, biter.global_position)
	_check(p.hp == hp0, "a hit that comes from an enemy doesn't hurt")
	_check(biter.stun_time == 0.0 and biter.knock == Vector2.ZERO, "and it does nothing to whoever dealt it: no stun, no shove (since 19 November)")
	_check(p.game_time - p.bulwark_blocked < 0.1 and p.invuln == 0.0 and p.bulwark_hits == 2, "the shield took it: two hits left")
	p.take_damage(10.0)
	_check(_near(p.hp, hp0 - 10.0), "a hit that comes from nowhere still hurts")
	p.hp = p.max_hp
	p.invuln = 0.0
	_check(float(p.ability_charge[0]) < 0.05, "its button is spent")
	var up := 0
	for i in 400:
		if p.bulwark_left <= 0.0:
			break
		await _frames(1)
		up += 1
	_check(up >= 176 and up <= 180 and not is_instance_valid(p.bulwark_fx), "three seconds later it is down (%d ticks)" % up)
	_check(float(p.ability_charge[0]) < 0.01, "only now does the button start to recharge")
	hp0 = p.hp
	p.take_damage(10.0, biter.global_position)
	_check(_near(p.hp, hp0 - 10.0), "and the same hit hurts again")
	await _frames(590)
	_check(not p.ability_ready(0), "ten seconds to come back: not yet")
	await _frames(15)
	_check(p.ability_ready(0), "now")

	# Enemies break it: the third hit it stops bursts it, and the burst stuns
	# everything near you (not the one far off), for 1.5 seconds. Nothing is hurt.
	await _hammer(["bulwark"], home)
	biter = _slime(Vector2(60, 0), true)
	beside = _slime(Vector2(0, 80), true)
	far_off = _slime(Vector2(-200, 0), true)
	await _frames(2)
	await _press(0)
	hp0 = p.hp
	p.take_damage(10.0, biter.global_position)
	await _frames(20)
	p.take_damage(10.0, biter.global_position)
	await _frames(20)
	_check(p.bulwark_left > 0.0 and p.bulwark_hits == 1 and biter.stun_time == 0.0, "two hits in, the shield is still up and nobody is stunned")
	p.take_damage(10.0, biter.global_position)
	_check(p.hp == hp0, "the third hit is stopped too")
	_check(p.bulwark_left == 0.0 and p.bulwark_hits == 0 and not is_instance_valid(p.bulwark_fx), "and it breaks the shield")
	_check(biter.stun_time > 1.4 and biter.stun_time <= 1.5 and beside.stun_time > 1.4, "the burst stuns the enemies around you for 1.5 seconds (%.2f, %.2f)" % [biter.stun_time, beside.stun_time])
	_check(far_off.stun_time == 0.0, "but not one 200 away")
	_check(_lost(biter) == 0.0 and _lost(beside) == 0.0, "the burst hurts nobody")
	p.take_damage(10.0, biter.global_position)
	_check(_near(p.hp, hp0 - 10.0), "with the shield gone the next hit hurts")
	p.hp = p.max_hp
	p.invuln = 0.0

	# A shield that just runs out doesn't burst.
	await _hammer(["bulwark"], home)
	biter = _slime(Vector2(60, 0), true)
	await _frames(2)
	await _press(0)
	p.take_damage(10.0, biter.global_position)
	await _frames(190)
	_check(p.bulwark_left == 0.0 and biter.stun_time == 0.0, "a shield that runs out with hits to spare stuns nobody")

	# An enemy that walks into it: bitten for nothing. Leaning on it, it counts as
	# a hit every 0.3 seconds, so it breaks the shield by itself and is stunned.
	await _hammer(["bulwark"], home)
	await _press(0)
	hp0 = p.hp
	biter = _slime(Vector2(27, 0), true)
	biter.contact_damage = 10.0
	await _frames(12)
	_check(p.hp == hp0 and p.bulwark_hits == 2 and biter.stun_time == 0.0, "an enemy that touches the shield bites nothing, and is not stunned for it (%d hits left)" % p.bulwark_hits)
	await _frames(40)
	_check(p.hp == hp0 and p.bulwark_left == 0.0 and biter.stun_time > 0.5, "leaning on it, it breaks the shield in under a second and is stunned by the burst (%.2f)" % biter.stun_time)
	biter.contact_damage = 0.0
	await _hammer(["bulwark"], home)
	await _press(0)
	m.swap_weapon(0, "sword")
	await _frames(2)
	_check(p.bulwark_left == 0.0 and not is_instance_valid(p.bulwark_fx), "putting the hammer away drops the shield")
	m.swap_weapon(0, "hammer")
	await _frames(2)

	await _hammer(["wider", "bulwark"], home)
	await _press(0)
	_check(p.bulwark_left > 3.9 and p.bulwark_left <= 4.0 and p.bulwark_hits == 4, "Wider: 4 seconds, and four hits (%.2f, %d)" % [p.bulwark_left, p.bulwark_hits])

	await _hammer(["saved_up", "bulwark"], home)
	await _press(0)
	_check(p.bulwark_left > 8.9 and p.bulwark_left <= 9.0 and p.bulwark_hits == 9 and _near(float(p.weapon["abilities"][0]["recharge"]), 30.0), "Saved Up: 9 seconds and nine hits, and 30 to recharge (%.2f, %d)" % [p.bulwark_left, p.bulwark_hits])

	await _hammer(["twice", "bulwark"], home)
	biter = _slime(Vector2(60, 0), true)
	await _frames(2)
	await _press(0)
	_check(p.bulwark_left > 2.9 and p.bulwark_left <= 3.0 and p.bulwark_hits == 3, "Twice: still 3 seconds and three hits")
	for i in 3:
		p.take_damage(10.0, biter.global_position)
		await _frames(20)
	_check(p.bulwark_left == 0.0 and biter.stun_time > 2.5 and biter.stun_time <= 3.0, "but its burst stuns twice as long (%.2f)" % biter.stun_time)

	await _hammer(["on_dodge", "bulwark"], home)
	await _dodge(Vector2.UP)
	_check(p.bulwark_left > 0.7 and p.bulwark_left <= 1.0 and p.bulwark_hits == 1 and float(p.ability_charge[0]) >= 1.0, "On Dodge: a dodge puts it up for a second, good for one hit, and leaves the button full (%.2f)" % p.bulwark_left)
	await _frames(60)
	_check(p.bulwark_left == 0.0, "a second later it is down")
	await _still()

	# With the arena's Invincible switch on it still blocks (so it can be tried there).
	m._set_invincible(true)
	await _hammer(["bulwark"], home)
	biter = _slime(Vector2(60, 0), true)
	await _frames(2)
	await _press(0)
	for i in 3:
		p.take_damage(10.0, biter.global_position)
		await _frames(20)
	_check(biter.stun_time > 1.0 and p.bulwark_left == 0.0, "with Invincible on the shield still blocks, breaks and bursts")
	m._set_invincible(false)

	# --- Hook: the hammer's now ---------------------------------------------------------
	await _hammer(["hook"], home)
	var pulled = _slime(Vector2(200, 0))
	pulled.knock_resist = 1.0
	await _frames(3)
	var d0: float = pulled.global_position.distance_to(p.global_position)
	await _press(0)
	await _frames(30)
	var d1: float = pulled.global_position.distance_to(p.global_position)
	_check(d1 < 60.0, "Hook from a hammer drags a far enemy all the way to you (%.0f -> %.0f)" % [d0, d1])
	_check(_near(_lost(pulled), SWING * 0.3), "and hurts it a little: three tenths of a swing (%.3f)" % _lost(pulled))
	_check(float(p.ability_charge[0]) < 0.2 and _near(float(p.weapon["abilities"][0]["recharge"]), 4.0), "four seconds to recharge")
	await _still()

	# --- The whole kit together: the arena's hammer -------------------------------------
	await _clear()
	m.build.set_data(SwingBuild.TEST_HAMMER)
	m.build.changed.emit()
	await _still()
	p.global_position = home
	p.ability_charge = [1.0, 1.0, 1.0]
	post = _slime(Vector2(40, 0))
	await _frames(2)
	await _press(0)
	await _frames(20)
	await _press(1)
	await _frames(20)
	await _press(2)
	await _frames(20)
	_check(_near(_lost(post), SLAM + SWING * 0.3) and p.bulwark_left > 0.0, "the arena's hammer: Quake, Bulwark and Hook all go off from their buttons (%.3f)" % _lost(post))
	await _still(200)
	await _clear()

	print("")
	print("RESULT: %d failed" % fails)
	quit(1 if fails > 0 else 0)
