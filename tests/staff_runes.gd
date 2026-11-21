extends SceneTree
## Checks for the staff's six runes (15 November), run in the real arena with two
## scripted players: Orbit, Chain and Overflow (passive), Nova, Lance and Spectre
## (on the ability buttons), what every band does to each, and what each costs in
## mana (21 November: the basic attack is free, the runes are not).
##   godot --headless --path . --fixed-fps 60 -s tests/staff_runes.gd

const EnemyScript := preload("res://scripts/enemy.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Player := preload("res://scripts/player.gd")
const PlayerInput := preload("res://scripts/player_input.gd")
const Art := preload("res://scripts/art.gd")
const BowArt := preload("res://scripts/weapon/bow_art.gd")

const BOLT := 6.6            # one bolt of the iron apprentice staff
const CHAIN := 19.8          # its chain: three bolts
const PASSIVE := 5.0         # mana a passive rune costs each time it goes off
const RUNES := ["orbit", "chain", "overflow", "nova", "lance", "spectre"]

var m
var p
var mate                     # player two, kept out of the way until the Spectre needs a teammate
var fails := 0
var made: Array = []
var low := 100.0             # the least mana player one has had since it was last set


func _init() -> void:
	m = load("res://scripts/main.gd").new()
	m.inputs = [PlayerInput.make("script"), PlayerInput.make("script")]
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
		if p != null:
			low = minf(low, float(p.mana))


## A slime that stands where it's put and can't be killed or shoved.
func _slime(offset: Vector2, from = null):
	var e = EnemyScript.new()
	e.kind = "slime"
	e.position = (p if from == null else from).global_position + offset
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


func _bolts() -> Array:
	var out: Array = []
	for a in get_nodes_in_group("arrows"):
		if is_instance_valid(a) and not a.is_queued_for_deletion():
			out.append(a)
	return out


func _quiet(q) -> void:
	q.input.move = Vector2.ZERO
	q.input.attack_held = false
	q.input.attack_pressed = false
	q.input.dash_pressed = false
	q.input.ability_held = [false, false, false]
	q.input.ability_pressed = [false, false, false]
	q.input.stick_aim = Vector2.RIGHT


func _still(frames := 45) -> void:
	_quiet(p)
	p._reset_combo()
	await _frames(frames)
	p._reset_combo()
	p.mana = SwingBuild.MANA
	p.weapon["crit"] = 0.0   # no luck in the sums


## Puts this staff in the hand: an iron apprentice head on the carved shaft (four
## slots) with an iron crystal, and these fittings bottom to top.
func _staff(line: Array, home: Vector2) -> void:
	await _clear()
	while line.size() < 4:
		line.append("")
	m.build.set_data(["iron_apprentice", "carved_shaft", "plain_cap", line, "iron_crystal"])
	m.build.changed.emit()
	await _still()
	p.global_position = home
	p.reset_physics_interpolation()
	mate.global_position = home + Vector2(-170, 60)   # behind you: never on your aim
	mate.reset_physics_interpolation()
	p.dodge_charges = 1
	p.ability_charge = [1.0, 1.0, 1.0]
	p.ability_wait = [0.0, 0.0, 0.0]
	p.hp = p.max_hp
	p.invuln = 0.0
	await _frames(2)
	p.weapon["crit"] = 0.0
	p.mana = SwingBuild.MANA


## Casts the first `count` moves of the chain and waits for the last bolt to land.
func _casts(count: int, who = null) -> void:
	var q = p if who == null else who
	q._reset_combo()
	q.input.attack_held = true
	q.input.attack_pressed = true
	await _frames(1)
	q.input.attack_pressed = false
	for i in 600:
		await _frames(1)
		if q.current_step == count - 1:
			break
	q.input.attack_held = false
	for i in 300:
		await _frames(1)
		if q.current_step < 0:
			break
	await _frames(45)
	q._reset_combo()


## One press of the attack button, then waits for the first thing to leave the staff.
func _first_bolt():
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	for i in 80:
		await _frames(1)
		if not _bolts().is_empty():
			return _bolts()[0]
	return null


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


## Holds ability button `b` down for `frames` and leaves it down.
func _hold(b: int, frames: int) -> void:
	var on := [false, false, false]
	on[b] = true
	p.input.ability_pressed = on.duplicate()
	p.input.ability_held = on.duplicate()
	await _frames(1)
	p.input.ability_pressed = [false, false, false]
	await _frames(frames - 1)


func _let_go() -> void:
	p.input.ability_held = [false, false, false]
	await _frames(20)


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
	mate = m.players[1]
	m.spawning = false
	m.min_hp = 100.0
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(5)
	p.auto_respawn = true
	mate.auto_respawn = true
	_quiet(mate)
	var home := Vector2(900, 560)      # the middle of the room, far from every wall
	p.global_position = home
	p.reset_physics_interpolation()
	await _frames(2)

	# --- The rules: six runes, the staff's own -------------------------------------------
	var passive := 0
	var active := 0
	for id in RUNES:
		var f: Dictionary = SwingBuild.FITTINGS.get(id, {})
		_check(f.get("kind", "") == "rune" and f.get("weapon", "") == "staff" and not f.get("parked", false) and id in SwingBuild.FITTING_ORDER, "%s is a staff rune in the forge" % id)
		if f.get("trigger", "") == "active":
			active += 1
		else:
			passive += 1
		for pic in ["icon", "forge", "forge_lit", "hand", "hand_lit"]:
			if Art.texture("swing/runes/%s_%s.png" % [id, pic]) == null:
				_check(false, "%s has its %s picture" % [id, pic])
		_check(Art.texture("swing/previews/%s.png" % id) != null, "%s has a preview picture" % id)
	_check(passive == 3 and active == 3, "three passive, three active")
	for g in ["nova", "lance", "spectre"]:
		_check(Art.texture("hud/glyph_%s.png" % g) != null, "%s has its button glyph" % g)
	for fx in ["orbit_orb", "orbit_hit", "chain_arc", "chain_hit", "overflow_glow", "overflow_aura", "nova_ring", "lance_beam_1", "lance_beam_2", "lance_beam_3",
			"lance_start", "lance_end", "spectre_appear"]:
		_check(BowArt.fx_texture(fx) != null and not BowArt.fx(fx).is_empty(), "effect strip %s is in the game" % fx)
	_check(SwingBuild.valid_data(["iron_apprentice", "carved_shaft", "plain_cap", ["overflow", "nova", "twice", "lance"], "iron_crystal"]), "a staff takes its runes")
	_check(not SwingBuild.valid_data(["iron_broadsword", "wrapped_grip", "plain_pommel", ["nova", "", "", ""]]), "a sword does not")
	_check(not SwingBuild.valid_data(["iron_maul", "bound_haft", "plain_weight", ["orbit", "", "", ""]]), "nor a hammer")
	var test_abilities: Array = SwingBuild.abilities(SwingBuild.resolve(SwingBuild.TEST_STAFF[3])["effects"])
	var got: Array = []
	for a in test_abilities:
		got.append([a["id"], a["use"], a["recharge"]])
	_check(got == [["nova", "press", 6.0], ["lance", "hold", 8.0], ["spectre", "press", 30.0]], "the arena's staff has Nova, Lance and Spectre on its three buttons: %s" % [got])
	_check(_near(SwingBuild.spectre_time(1.0), 6.0) and _near(SwingBuild.spectre_time(SwingBuild.wider_size(1)), 9.0), "Spectre: 6 seconds, 9 with Wider")
	_check(_near(SwingBuild.spectre_power(1.0), 0.5) and _near(SwingBuild.spectre_power(3.0), 1.0), "its copies are half an attack; Saved Up makes them whole ones, never more")
	_check(SwingBuild.lance_stage(1, 12) == 1 and SwingBuild.lance_stage(4, 12) == 1 and SwingBuild.lance_stage(5, 12) == 2 and SwingBuild.lance_stage(9, 12) == 3 and SwingBuild.lance_stage(12, 12) == 3,
		"Lance grows a step for each third of a full hold: four pulses at each strength")
	_check(SwingBuild.lance_stage(8, 24) == 1 and SwingBuild.lance_stage(9, 24) == 2 and SwingBuild.lance_stage(17, 24) == 3, "with Twice the hold is twice as long, and so is each step")
	_check(_near(SwingBuild.lance_time(1), 3.0) and _near(SwingBuild.lance_time(2), 6.25), "a full bar is 3 seconds of beam (twelve pulses of 8 mana), about 6 with Twice (twenty-five of 4)")
	var says := {
		["orbit"]: "Your finisher leaves an orb circling you. It strikes the first enemy that comes near. Costs 5 mana each time.",
		["twice", "orbit"]: "Your finisher leaves two orbs circling you. They strike the first enemy that comes near. Costs 5 mana each time.",
		["wider", "orbit"]: "Your finisher leaves an orb circling you. It strikes the first enemy that comes near, from further off. Costs 5 mana each time.",
		["every_hit", "orbit"]: "Every bolt that hits leaves an orb circling you, at half strength. It strikes the first enemy that comes near. Costs 5 mana each time.",
		["saved_up", "orbit"]: "Every third finisher leaves an orb circling you, three times as strong. It strikes the first enemy that comes near. Costs 5 mana each time.",
		["on_dodge", "orbit"]: "Your finisher leaves an orb circling you. It strikes the first enemy that comes near. A dodge leaves one too. Costs 5 mana each time.",
		["chain"]: "Your finisher's bolt sends lightning jumping to three more enemies. Costs 5 mana each time.",
		["twice", "chain"]: "Your finisher's bolt sends lightning jumping to six more enemies. Costs 5 mana each time.",
		["wider", "chain"]: "Your finisher's bolt sends lightning jumping to three more enemies, from further away. Costs 5 mana each time.",
		["every_hit", "chain"]: "Every bolt that hits sends lightning jumping to three more enemies, at half strength. Costs 5 mana each time.",
		["saved_up", "chain"]: "Every third finisher's bolt sends lightning jumping to three more enemies, three times as strong. Costs 5 mana each time.",
		["on_dodge", "chain"]: "Your finisher's bolt sends lightning jumping to three more enemies. A dodge sends it out from you too. Costs 5 mana each time.",
		["overflow"]: "On full mana your next bolt is bigger and hits 30% harder. Costs 5 mana each time.",
		["twice", "overflow"]: "On full mana your next bolt is bigger and hits 30% harder. Every other one is cast twice. Costs 5 mana each time.",
		["wider", "overflow"]: "On full mana your next bolt hits 30% harder and bursts wide where it lands. Costs 5 mana each time.",
		["every_hit", "overflow"]: "On full mana your next bolt is bigger and hits 30% harder. Each bolt that lands gives back 3 mana. Costs 5 mana each time.",
		["saved_up", "overflow"]: "After three seconds on full mana, your next bolt is a huge blast, three times as strong. Costs 5 mana each time.",
		["wider", "saved_up", "overflow"]: "After three seconds on full mana, your next bolt is a huge, wider blast, three times as strong. Costs 5 mana each time.",
		["on_dodge", "overflow"]: "On full mana your next bolt is bigger and hits 30% harder. A dodge gives back 10 mana. Costs 5 mana each time.",
		["nova"]: "Press right mouse: a ring bursts out from you and shoves the crowd back. Costs 25 mana and recharges in 6 seconds.",
		["twice", "nova"]: "Press right mouse: two rings burst out from you and shove the crowd back. Costs 25 mana and recharges in 6 seconds.",
		["wider", "nova"]: "Press right mouse: a big ring bursts out from you and shoves the crowd back. Costs 25 mana and recharges in 6 seconds.",
		["every_hit", "nova"]: "Press right mouse: a ring bursts out from you and shoves the crowd back. Costs 25 mana and recharges in 6 seconds. Each hit you land takes half a second off.",
		["saved_up", "nova"]: "Press right mouse: a ring bursts out from you and shoves the crowd back, three times as strong. Costs 25 mana and recharges in 18 seconds.",
		["on_dodge", "nova"]: "Press right mouse: a ring bursts out from you and shoves the crowd back. Costs 25 mana and recharges in 6 seconds. Dodging sets one off too, at half strength.",
		["lance"]: "Hold right mouse: a beam into the first enemy on your aim that builds until your mana runs out, about three seconds on a full bar. Costs 8 mana a pulse and recharges in 8 seconds.",
		["twice", "lance"]: "Hold right mouse: a beam into the first enemy on your aim that builds until your mana runs out, about six seconds on a full bar. Costs 4 mana a pulse and recharges in 8 seconds.",
		["wider", "lance"]: "Hold right mouse: a thick beam into the first enemy on your aim that builds until your mana runs out, about three seconds on a full bar. Costs 8 mana a pulse and recharges in 8 seconds.",
		["saved_up", "lance"]: "Hold right mouse: a beam into the first enemy on your aim that builds until your mana runs out, about three seconds on a full bar, three times as strong. Costs 8 mana a pulse and recharges in 24 seconds.",
		["on_dodge", "lance"]: "Hold right mouse: a beam into the first enemy on your aim that builds until your mana runs out, about three seconds on a full bar. Costs 8 mana a pulse and recharges in 8 seconds. Dodging fires one flash of it.",
		["spectre"]: "Press right mouse: a ghost of you, or of the teammate you aim at, copies their basic attacks for 6 seconds, at half strength. Costs 40 mana and recharges in 30 seconds.",
		["twice", "spectre"]: "Press right mouse: two ghosts of you, or of the teammate you aim at, copy their basic attacks for 6 seconds, at half strength. Costs 40 mana and recharges in 30 seconds.",
		["wider", "spectre"]: "Press right mouse: a ghost of you, or of the teammate you aim at, copies their basic attacks for 9 seconds, at half strength. Costs 40 mana and recharges in 30 seconds.",
		["saved_up", "spectre"]: "Press right mouse: a ghost of you, or of the teammate you aim at, copies their basic attacks for 6 seconds, at full strength. Costs 40 mana and recharges in 90 seconds.",
		["on_dodge", "spectre"]: "Press right mouse: a ghost of you, or of the teammate you aim at, copies their basic attacks for 6 seconds, at half strength. Costs 40 mana and recharges in 30 seconds. When they dodge, it bursts where it stood.",
	}
	for line in says:
		var said: String = SwingBuild.sentence(_effect(line))
		_check(said == says[line], "%s reads: %s" % [line, said])
	var none: Dictionary = SwingBuild.resolve(["every_hit", "every_hit", "overflow"])
	_check(none["slots"][0].get("unused", false) or none["slots"][1].get("unused", false), "a second Every Hit under Overflow does nothing, and the forge says so")

	# --- In the arena: the test staff ----------------------------------------------------
	m.swap_weapon(0, "staff")
	await _frames(2)
	_check(m.build.weapon() == "staff" and p.weapon["abilities"].size() == 3, "the arena's staff comes with its three buttons")
	_check(p.weapon["effects"].size() == 4 and p.weapon["effects"][3]["id"] == "chain", "and Chain as its passive rune")

	# --- What a passive rune costs (21 November) ---------------------------------------------
	p.mana = 4.0
	_check(not p._spend_passive() and _near(p.mana, 4.0) and p.game_time - float(p.mana_denied) < 0.05, "with less than 5 mana a staff's passive rune doesn't go off, and the mana bar blinks")
	p.mana = 5.0
	_check(p._spend_passive() and _near(p.mana, 0.0), "with 5 it does, and takes them")
	_check(_near(float(p.weapon["abilities"][0]["mana"]), 25.0) and _near(float(p.weapon["abilities"][1]["mana"]), 8.0) and p.weapon["abilities"][1]["drain"] and _near(float(p.weapon["abilities"][2]["mana"]), 40.0),
		"Nova costs 25 mana, Lance 8 a pulse and Spectre 40: more than a passive rune's 5")
	m.swap_weapon(0, "sword")
	await _frames(2)
	p.mana = 0.0
	_check(p._spend_passive() and _near(p.mana, 0.0), "(another weapon's runes cost no mana)")
	m.swap_weapon(0, "staff")
	await _frames(2)

	# --- Overflow -----------------------------------------------------------------------
	await _staff(["overflow"], home)
	var post = _slime(Vector2(200, 0))
	await _frames(3)
	_check(p.mana_full() and is_instance_valid(p.overflow_aura), "Overflow: with mana full the crystal shows its sign")
	var bolt = await _first_bolt()
	_check(bolt != null and bolt.halo == "overflow_glow" and _near(bolt.big, 1.25) and _near(bolt.half_width, SwingBuild.BOLT_WIDTH * 1.25) and _near(bolt.damage, BOLT * 1.3),
		"a bolt cast on full mana is a quarter bigger, has its halo and hits 30% harder (8.58)")
	_check(_near(p.mana, 100.0 - PASSIVE, 0.3), "it costs 5 mana, like every passive rune of the staff's (%.1f left)" % p.mana)
	await _frames(3)
	_check(not p.mana_full() and not is_instance_valid(p.overflow_aura), "so the bar isn't full any more, and the sign goes")
	await _frames(45)
	_check(_near(_lost(post), BOLT * 1.3), "it lands for 8.58 (%.3f)" % _lost(post))
	post.hp = post.max_hp
	p.mana = SwingBuild.MANA
	await _casts(3)
	_check(_near(_lost(post), BOLT * 1.3 + BOLT + BOLT), "in a chain only the first cast is on full mana: 8.58, then 6.6 and 6.6 (%.3f)" % _lost(post))
	post.hp = post.max_hp
	p.mana = 50.0
	bolt = await _first_bolt()
	_check(bolt != null and bolt.halo == "" and _near(bolt.big, 1.0) and _near(bolt.damage, BOLT), "on half mana a bolt is a plain one")
	await _still()
	# Its bands are Darren's (11 November, "Overflow bands" in the Game Bible).
	await _staff(["twice", "overflow"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	bolt = await _first_bolt()
	var paid: float = p.mana
	await _frames(9)
	var pair := _bolts()
	_check(pair.size() == 2 and pair[1].quiet and _near(float(pair[1].crit), 0.0) and pair[1].halo == "overflow_glow" and _near(float(pair[1].damage), BOLT * 1.3) and p.mana >= paid,
		"Twice: the Overflow bolt is cast again a moment later, free of mana, and it can't crit")
	await _frames(45)
	_check(_near(_lost(post), BOLT * 1.3 * 2.0) and p.overflow_count == 1, "both land: 8.58 and 8.58 (%.3f)" % _lost(post))
	post.hp = post.max_hp
	p.mana = SwingBuild.MANA
	await _casts(1)
	_check(_near(_lost(post), BOLT * 1.3) and p.overflow_count == 2, "every other one: the next Overflow bolt is cast once (%.3f)" % _lost(post))
	post.hp = post.max_hp
	p.mana = SwingBuild.MANA
	await _casts(1)
	_check(_near(_lost(post), BOLT * 1.3 * 2.0) and p.overflow_count == 3, "and the one after it twice again (%.3f)" % _lost(post))
	await _staff(["wider", "overflow"], home)
	post = _slime(Vector2(200, 0))
	var beside = _slime(Vector2(200, 42))   # out of the bolt's path, inside its burst
	var apart = _slime(Vector2(200, -90))
	await _frames(2)
	bolt = await _first_bolt()
	_check(bolt != null and _near(bolt.splash, SwingBuild.OVERFLOW_SPLASH) and _near(bolt.damage, BOLT * 1.3), "Wider: an Overflow bolt bursts where it lands, 36 px wide")
	await _frames(45)
	_check(_near(_lost(post), BOLT * 1.3) and _near(_lost(beside), BOLT * 1.3) and _near(_lost(apart), 0.0), "so it hits the enemy beside the one it lands on too (%.3f, %.3f)" % [_lost(post), _lost(beside)])
	post.hp = post.max_hp
	beside.hp = beside.max_hp
	p.mana = 50.0
	await _casts(1)
	_check(_near(_lost(post), BOLT) and _near(_lost(beside), 0.0), "a plain bolt keeps its own very small splash: the one 42 px off is missed")
	await _still()
	await _staff(["every_hit", "overflow"], home)
	post = _slime(Vector2(120, 0))
	await _frames(2)
	p.mana = 50.0
	bolt = await _first_bolt()
	paid = p.mana
	await _frames(15)
	_check(_near(_lost(post), BOLT) and _near(p.mana, paid + 15.0 / 12.0 + SwingBuild.OVERFLOW_REFUND, 0.4), "Every Hit: a bolt that lands gives 3 mana back (%.2f from %.2f)" % [p.mana, paid])
	await _clear()
	await _still()
	p.mana = 50.0
	bolt = await _first_bolt()
	paid = p.mana
	await _frames(15)
	_check(_near(p.mana, paid + 15.0 / 12.0, 0.4), "one that hits nothing gives none (%.2f from %.2f)" % [p.mana, paid])
	await _still()
	post = _slime(Vector2(120, 0))
	await _frames(2)
	bolt = await _first_bolt()
	paid = p.mana
	await _frames(15)
	_check(_near(_lost(post), BOLT * 1.3) and paid < 95.5 and _near(p.mana, paid + 15.0 / 12.0 + SwingBuild.OVERFLOW_REFUND, 0.4),
		"so an Overflow bolt that lands gets 3 of its 5 mana back, and the bar is full again sooner (%.2f from %.2f)" % [p.mana, paid])
	await _staff(["saved_up", "overflow"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	p.overflow_charge = 0.0
	bolt = await _first_bolt()
	_check(bolt != null and bolt.halo == "" and _near(bolt.damage, BOLT) and p.mana_full(), "Saved Up: a bolt cast on full mana is a plain one, and costs nothing...")
	await _frames(50)
	p.mana = SwingBuild.MANA
	p.overflow_charge = 0.0
	await _frames(170)
	_check(not p.overflow_charged() and not is_instance_valid(p.overflow_aura), "...until your mana has stayed full for three seconds (not after 2.8)")
	await _frames(14)
	_check(p.overflow_charged() and is_instance_valid(p.overflow_aura), "then the crystal shows its sign")
	post.hp = post.max_hp
	bolt = await _first_bolt()
	_check(bolt != null and bolt.halo == "overflow_glow" and _near(bolt.damage, BOLT * 3.0) and _near(bolt.big, 2.15) and _near(bolt.splash, SwingBuild.OVERFLOW_BLAST_SPLASH),
		"and the next bolt is a blast: three times as strong (19.8), huge, and it bursts")
	await _frames(45)
	_check(_near(_lost(post), BOLT * 3.0) and not p.overflow_charged(), "it lands for 19.8, and the charge is spent (%.3f)" % _lost(post))
	await _staff(["on_dodge", "overflow"], home)
	p.mana = 40.0
	p.dodge_charges = 1
	p.input.dash_pressed = true
	await _frames(1)
	p.input.dash_pressed = false
	_check(p.mana >= 50.0 and p.mana < 51.5, "On Dodge: a dodge gives 10 mana back (40 to %.1f)" % p.mana)
	await _frames(30)
	await _staff(["overflow"], home)
	p.mana = 40.0
	p.dodge_charges = 1
	p.input.dash_pressed = true
	await _frames(1)
	p.input.dash_pressed = false
	_check(p.mana < 41.5, "without the band it gives none (%.1f)" % p.mana)
	await _frames(30)

	# --- Orbit ---------------------------------------------------------------------------
	await _staff(["orbit"], home)
	post = _slime(Vector2(220, 0))
	await _frames(2)
	low = 100.0
	await _casts(2)
	_check(p.orbs.is_empty() and _near(low, 100.0), "Orbit: two bolts leave nothing, and cost nothing")
	await _casts(3)
	_check(p.orbs.size() == 1 and _near(float(p.orbs[0]["dmg"]), BOLT), "the finisher leaves an orb circling you, worth one bolt")
	_check(_near(low, 100.0 - PASSIVE, 0.05), "which costs 5 mana (down to %.1f)" % low)
	_check(_near(_lost(post), BOLT * 2.0 + CHAIN), "it waits: an enemy 220 px away only takes the casts (%.3f)" % _lost(post))
	var r: float = post.radius
	var far = _slime(Vector2(0, -(SwingBuild.ORBIT_REACH + r + 4.0)))
	await _frames(20)
	_check(_near(_lost(far), 0.0) and p.orbs.size() == 1, "one whose edge is just outside 62 px is left alone")
	var close = _slime(Vector2(0, SwingBuild.ORBIT_REACH + r - 4.0))
	await _frames(3)
	_check(_near(_lost(close), BOLT) and p.orbs.is_empty() and _near(_lost(far), 0.0), "one that comes just inside is struck for 6.6, and the orb is spent (%.3f)" % _lost(close))
	var col: Color = SwingBuild.FITTINGS["orbit"]["color"]
	for i in 4:
		p._orbit(1.0, float(i + 1), col)
	_check(p.orbs.size() == SwingBuild.ORBIT_MAX and _near(float(p.orbs[0]["dmg"]), BOLT * 2.0), "three at the most: a fourth takes the oldest one's place")
	await _frames(5)
	_check(p.orbs.size() == 3 and _near(_lost(close), BOLT), "one strike every quarter of a second: the next orb waits its turn")
	await _frames(12)
	_check(p.orbs.size() == 2 and _near(_lost(close), BOLT * 3.0), "then the oldest strikes first (%.3f)" % _lost(close))
	await _frames(5)
	_check(p.orbs.size() == 2, "and the one after it waits again")
	await _frames(12)
	_check(p.orbs.size() == 1, "then strikes")
	await _clear()
	p.orbs[0]["until"] = p.game_time + 0.05
	await _frames(5)
	_check(p.orbs.is_empty(), "an orb nobody comes near goes after its eight seconds")
	p._orbit(1.0, 1.0, col)
	m.build.changed.emit()
	await _frames(2)
	_check(p.orbs.is_empty(), "the orbs go when the staff is changed")
	# Without the mana for it the finisher leaves nothing. (Nothing comes back
	# while this is checked, or the chain's second or so would pay for it.)
	await _staff(["orbit"], home)
	post = _slime(Vector2(220, 0))
	await _frames(2)
	var regen: float = SwingBuild.MANA_REGEN
	SwingBuild.MANA_REGEN = 0.0
	p.mana = 4.0
	await _casts(3)
	_check(p.orbs.is_empty() and _near(p.mana, 4.0) and _near(_lost(post), CHAIN), "with 4 mana the chain is cast as ever, but its finisher leaves no orb")
	SwingBuild.MANA_REGEN = regen
	await _staff(["twice", "orbit"], home)
	post = _slime(Vector2(220, 0))
	await _frames(2)
	low = 100.0
	await _casts(3)
	_check(p.orbs.size() == 2 and _near(low, 100.0 - PASSIVE, 0.05), "Twice: the finisher leaves two, for the same 5 mana")
	await _staff(["wider", "orbit"], home)
	post = _slime(Vector2(220, 0))
	await _frames(2)
	await _casts(3)
	far = _slime(Vector2(0, -(SwingBuild.ORBIT_REACH * SwingBuild.wider_size(1) + r - 4.0)))
	await _frames(3)
	_check(_near(_lost(far), BOLT), "Wider: it strikes from further off (%.3f)" % _lost(far))
	await _staff(["every_hit", "orbit"], home)
	post = _slime(Vector2(220, 0))
	await _frames(2)
	await _casts(1)
	_check(p.orbs.size() == 1 and _near(float(p.orbs[0]["dmg"]), BOLT * 0.5), "Every Hit: every bolt that hits leaves one, at half strength")
	await _staff(["saved_up", "orbit"], home)
	post = _slime(Vector2(220, 0))
	await _frames(2)
	await _casts(3)
	await _casts(3)
	_check(p.orbs.is_empty(), "Saved Up: nothing from the first two finishers")
	await _casts(3)
	_check(p.orbs.size() == 1 and _near(float(p.orbs[0]["dmg"]), BOLT * 3.0), "the third leaves one three times as strong")
	await _staff(["on_dodge", "orbit"], home)
	low = 100.0
	await _dodge()
	_check(p.orbs.size() == 1 and _near(low, 100.0 - PASSIVE, 0.05), "On Dodge: a dodge leaves one, for 5 mana")

	# --- Chain ---------------------------------------------------------------------------
	# A is on your aim; B, C, D and E stand in a row beside it, 110 px apart: out of
	# a bolt's very small splash, inside the lightning's reach (150).
	var row := [Vector2(200, 0), Vector2(200, 110), Vector2(200, 220), Vector2(310, 220), Vector2(420, 220)]
	await _staff(["chain"], home)
	var posts: Array = []
	for at in row:
		posts.append(_slime(at))
	await _frames(2)
	await _casts(2)
	_check(_near(_lost(posts[0]), BOLT * 2.0) and _near(_lost(posts[1]), 0.0), "Chain: a bolt that isn't the finisher doesn't fork")
	posts[0].hp = posts[0].max_hp
	low = 100.0
	await _casts(3)
	_check(_near(low, 100.0 - PASSIVE, 0.05), "the fork costs 5 mana (down to %.1f)" % low)
	_check(_near(_lost(posts[0]), CHAIN), "the finisher's bolt lands as usual on the one it hits (%.3f)" % _lost(posts[0]))
	_check(_near(_lost(posts[1]), BOLT * 0.5) and _near(_lost(posts[2]), BOLT * 0.5) and _near(_lost(posts[3]), BOLT * 0.5),
		"and lightning jumps on to three more, half a bolt each (%.2f, %.2f, %.2f)" % [_lost(posts[1]), _lost(posts[2]), _lost(posts[3])])
	_check(_near(_lost(posts[4]), 0.0), "three jumps and no further")
	await _staff(["twice", "chain"], home)
	posts = []
	for at in row:
		posts.append(_slime(at))
	await _frames(2)
	await _casts(3)
	_check(_near(_lost(posts[4]), BOLT * 0.5), "Twice: six jumps, so it gets to the fifth (%.3f)" % _lost(posts[4]))
	await _staff(["chain"], home)
	post = _slime(Vector2(200, 0))
	r = post.radius
	far = _slime(Vector2(200, SwingBuild.CHAIN_RANGE + r + 12.0))
	await _frames(2)
	await _casts(3)
	_check(_near(_lost(far), 0.0), "an enemy more than 150 px off is out of its reach")
	await _staff(["wider", "chain"], home)
	post = _slime(Vector2(200, 0))
	far = _slime(Vector2(200, SwingBuild.CHAIN_RANGE + r + 12.0))
	await _frames(2)
	await _casts(3)
	_check(_near(_lost(far), BOLT * 0.5), "Wider: it jumps further (%.3f)" % _lost(far))
	await _staff(["every_hit", "chain"], home)
	post = _slime(Vector2(200, 0))
	far = _slime(Vector2(200, 110))
	await _frames(2)
	await _casts(1)
	_check(_near(_lost(far), BOLT * 0.25), "Every Hit: every bolt that hits forks, at half strength: 1.65 (%.3f)" % _lost(far))
	await _staff(["saved_up", "chain"], home)
	post = _slime(Vector2(200, 0))
	far = _slime(Vector2(200, 110))
	await _frames(2)
	await _casts(3)
	await _casts(3)
	_check(_near(_lost(far), 0.0), "Saved Up: nothing from the first two finishers")
	await _casts(3)
	_check(_near(_lost(far), BOLT * 1.5), "the third forks three times as strong: 9.9 (%.3f)" % _lost(far))
	await _staff(["on_dodge", "chain"], home)
	far = _slime(Vector2(-20, 110))
	await _frames(2)
	await _dodge()
	_check(_near(_lost(far), BOLT * 0.5), "On Dodge: a dodge sends it out from you to whoever is near (%.3f)" % _lost(far))

	# --- Nova ----------------------------------------------------------------------------
	await _staff(["nova"], home)
	post = _slime(Vector2(100, 0))
	r = post.radius
	var above = _slime(Vector2(0, -55))
	var out_side = _slime(Vector2(-(SwingBuild.NOVA_RADIUS + r + 14.0), 0))
	var out_below = _slime(Vector2(0, SwingBuild.NOVA_RADIUS * SwingBuild.NOVA_FLAT + r + 26.0))
	await _frames(2)
	await _press(0)
	await _frames(3)
	_check(_near(_lost(post), BOLT * 1.2) and _near(_lost(above), BOLT * 1.2), "Nova: everyone inside the ring takes 1.2 bolts: 7.92 (%.3f, %.3f)" % [_lost(post), _lost(above)])
	_check(_near(p.mana, 75.0, 0.6), "it costs 25 mana (%.1f left)" % p.mana)
	_check(_near(_lost(out_side), 0.0) and _near(_lost(out_below), 0.0), "it reaches 110 px to the sides and less up and down: those outside are missed")
	_check(float(p.ability_charge[0]) < 0.05 and _near(float(p.weapon["abilities"][0]["recharge"]), 6.0), "it is used up, and comes back in 6 seconds")
	await _press(0)
	await _frames(3)
	_check(_near(_lost(post), BOLT * 1.2), "pressing again before it is back does nothing")
	# Recharged, but without the mana for it: nothing, and the mana bar blinks.
	p.ability_charge = [1.0, 1.0, 1.0]
	p.mana = 20.0
	await _press(0)
	await _frames(3)
	_check(_near(_lost(post), BOLT * 1.2) and float(p.ability_charge[0]) > 0.99 and p.mana >= 20.0 and p.game_time - float(p.mana_denied) < 0.3,
		"with 20 mana a recharged Nova doesn't go off: it is not used up, and the mana bar blinks")
	await _staff(["twice", "nova"], home)
	post = _slime(Vector2(100, 0))
	await _frames(2)
	await _press(0)
	await _frames(8)
	_check(_near(_lost(post), BOLT * 1.2), "Twice: one ring first...")
	await _frames(20)
	_check(_near(_lost(post), BOLT * 2.4) and p.mana > 74.0, "...and a second a moment later, both for the one 25 mana (%.3f)" % _lost(post))
	await _staff(["wider", "nova"], home)
	out_side = _slime(Vector2(-(SwingBuild.NOVA_RADIUS + r + 14.0), 0))
	await _frames(2)
	await _press(0)
	await _frames(3)
	_check(_near(_lost(out_side), BOLT * 1.2), "Wider: a bigger ring reaches it (%.3f)" % _lost(out_side))
	await _staff(["saved_up", "nova"], home)
	post = _slime(Vector2(100, 0))
	await _frames(2)
	await _press(0)
	await _frames(3)
	_check(_near(_lost(post), BOLT * 3.6) and _near(float(p.weapon["abilities"][0]["recharge"]), 18.0), "Saved Up: three times as strong (23.76), back in 18 seconds (%.3f)" % _lost(post))
	await _staff(["on_dodge", "nova"], home)
	post = _slime(Vector2(-70, 0))
	await _frames(2)
	await _dodge(Vector2.RIGHT)
	_check(_near(_lost(post), BOLT * 0.6) and float(p.ability_charge[0]) > 0.99 and p.mana_full(), "On Dodge: a half ring where you dodged from (3.96), free of mana, and the button isn't used (%.3f)" % _lost(post))

	# --- Lance ---------------------------------------------------------------------------
	await _staff(["lance"], home)
	post = _slime(Vector2(200, 0))
	var behind = _slime(Vector2(300, 0))
	await _frames(2)
	await _press(0)
	await _frames(20)
	_check(_near(_lost(post), BOLT * 0.75), "Lance: a tap is one pulse of the beam, three quarters of a bolt: 4.95 (%.3f)" % _lost(post))
	_check(_near(p.mana, 92.0, 1.0), "a pulse costs 8 mana (%.1f left)" % p.mana)
	_check(float(p.ability_charge[0]) < 0.05, "and once the beam stops, its whole 8 second recharge starts (%.2f)" % p.ability_charge[0])
	await _press(0)
	await _frames(20)
	_check(_near(_lost(post), BOLT * 0.75), "so it can't be tapped again straight away")
	_check(_near(_lost(behind), 0.0), "it stops at the first enemy on your aim")
	post.hp = post.max_hp
	p.ability_charge = [1.0, 1.0, 1.0]
	p.ability_wait = [0.0, 0.0, 0.0]
	p.mana = SwingBuild.MANA
	await _hold(0, 30)
	_check(p._beaming() and is_instance_valid(p.lance_fx) and p.lance_on == post, "held, the beam stays on it")
	_check(_near(_lost(post), BOLT * 0.75 * 2.0), "a pulse every quarter of a second (%.3f)" % _lost(post))
	_check(_near(float(p.ability_charge[0]), 1.0) and _near(p.mana, 84.0, 0.05), "it burns mana and not its meter, and none comes back while it burns (%.1f)" % p.mana)
	await _frames(200)
	_check(_near(_lost(post), BOLT * 0.75 * (4.0 + 8.0 + 12.0)), "a full bar is twelve pulses, growing to twice and three times as strong: 118.8 in all (%.3f)" % _lost(post))
	_check(p.lance_stage == 3 and not p._beaming() and not is_instance_valid(p.lance_fx) and p.mana < 12.0, "at full strength when the mana runs out, and then it stops by itself (%.1f mana left)" % p.mana)
	_check(float(p.ability_charge[0]) < 0.3, "and goes on its recharge (%.2f)" % p.ability_charge[0])
	await _let_go()
	# On less than a full bar it lasts as long as the mana does.
	await _staff(["lance"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	p.mana = 20.0
	await _hold(0, 90)
	_check(_near(_lost(post), BOLT * 0.75 * 2.0) and not p._beaming(), "with 20 mana the beam is two pulses and stops (%.3f)" % _lost(post))
	await _let_go()
	await _staff(["lance"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	p.mana = 6.0
	await _hold(0, 20)
	_check(_near(_lost(post), 0.0) and not p._beaming() and float(p.ability_charge[0]) > 0.99, "with less than a pulse's 8 mana it doesn't start, and isn't used up")
	await _let_go()
	await _staff(["lance"], home)
	p.input.move = Vector2.UP
	await _hold(0, 30)
	var walking: float = p.walk_vel.length()
	_check(_near(walking, Player.MOVE_SPEED * (1.0 + float(p.weapon.get("move_speed", 0.0))) * SwingBuild.LANCE_MOVE, 2.0), "you walk at half speed while you hold it (%.1f)" % walking)
	await _dodge(Vector2.UP)
	_check(not p._beaming() and not is_instance_valid(p.lance_fx), "a dodge drops the beam")
	await _let_go()
	await _staff(["lance"], home)
	r = 13.0
	far = _slime(Vector2(float(p.weapon["range"]) + 40.0, 0))
	r = far.radius
	beside = _slime(Vector2(200, r + SwingBuild.LANCE_WIDTH + 2.0))
	await _frames(2)
	await _press(0)
	await _frames(20)
	_check(_near(_lost(far), 0.0), "it reaches as far as the staff's bolts and no further")
	_check(_near(_lost(beside), 0.0), "one standing just beside the beam is missed")
	await _staff(["wider", "lance"], home)
	beside = _slime(Vector2(200, r + SwingBuild.LANCE_WIDTH + 2.0))
	await _frames(2)
	await _press(0)
	await _frames(20)
	_check(_near(_lost(beside), BOLT * 0.75), "Wider: a thicker beam catches it (%.3f)" % _lost(beside))
	await _staff(["twice", "lance"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	await _hold(0, 420)
	_check(_near(_lost(post), BOLT * 0.75 * (9.0 + 16.0 + 24.0)), "Twice: a pulse costs half the mana, so a full bar is twenty-five of them: 242.55 (%.3f)" % _lost(post))
	await _let_go()
	await _staff(["saved_up", "lance"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	await _press(0)
	await _frames(20)
	_check(_near(_lost(post), BOLT * 2.25) and _near(float(p.weapon["abilities"][0]["recharge"]), 24.0), "Saved Up: three times as strong (14.85 a pulse), back in 24 seconds (%.3f)" % _lost(post))
	await _staff(["on_dodge", "lance"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	await _dodge(Vector2.UP)
	_check(_near(_lost(post), BOLT * 0.75 * 3.0 * 0.5) and float(p.ability_charge[0]) > 0.99 and p.mana_full(), "On Dodge: one flash at full strength, halved (7.43), free of mana, and the button isn't used (%.3f)" % _lost(post))

	# --- Spectre -------------------------------------------------------------------------
	await _staff(["spectre"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	await _press(0)
	_check(_near(p.spectre_left, 6.0, 0.1) and p.spectre_by == p and p.spectre_on == p and _near(p.spectre_out(), 1.0, 0.05), "Spectre: with no teammate on your aim it comes to you, for 6 seconds")
	_check(float(p.ability_charge[0]) < 0.05 and _near(float(p.weapon["abilities"][0]["recharge"]), 30.0), "it is used up, and comes back in 30 seconds")
	_check(_near(p.mana, 60.0, 0.6), "it costs 40 mana (%.1f left)" % p.mana)
	p.mana = 60.0
	bolt = await _first_bolt()
	var had: float = p.mana
	await _frames(11)
	var flying := _bolts()
	_check(flying.size() == 2 and _near(float(flying[1].copy), 0.5) and _near(float(flying[1].damage), BOLT * 0.5), "it casts your bolt again a moment later, at half strength")
	_check(p.mana >= had, "and its copy costs no mana (%.1f, was %.1f)" % [p.mana, had])
	await _frames(45)
	_check(_near(_lost(post), BOLT * 1.5), "6.6 and 3.3 land (%.3f)" % _lost(post))
	post.hp = post.max_hp
	p.mana = SwingBuild.MANA
	await _casts(3)
	_check(_near(_lost(post), CHAIN * 1.5), "a whole chain is copied: 29.7 (%.3f)" % _lost(post))
	await _frames(300)
	_check(p.spectre_left <= 0.0 and p.spectre_on == null and _near(p.spectre_out(), 0.0), "after 6 seconds it is gone")
	post.hp = post.max_hp
	await _casts(1)
	_check(_near(_lost(post), BOLT), "and your bolts are your own again (%.3f)" % _lost(post))
	await _staff(["twice", "spectre"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	await _press(0)
	await _casts(1)
	_check(_near(_lost(post), BOLT * 2.0) and p.spectre_count == 2 and p._spectre_places().size() == 2, "Twice: two ghosts, and each copies the attack (%.3f)" % _lost(post))
	await _staff(["wider", "spectre"], home)
	await _press(0)
	_check(_near(p.spectre_left, 9.0, 0.1), "Wider: it stays 9 seconds")
	await _staff(["saved_up", "spectre"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	await _press(0)
	await _casts(1)
	_check(_near(_lost(post), BOLT * 2.0) and _near(float(p.weapon["abilities"][0]["recharge"]), 90.0), "Saved Up: whole copies, back in 90 seconds (%.3f)" % _lost(post))
	# On Dodge is Darren's too: the ghost dodges with you and bursts where it stood.
	await _staff(["on_dodge", "spectre"], home)
	post = _slime(Vector2(44, 0))
	var outside = _slime(Vector2(0, 120))
	await _frames(2)
	await _dodge(Vector2.LEFT)
	_check(_near(_lost(post), 0.0) and p.spectre_left <= 0.0 and float(p.ability_charge[0]) > 0.99, "On Dodge: with no ghost out, a dodge does nothing")
	p.global_position = home
	p.reset_physics_interpolation()
	await _frames(20)
	await _press(0)
	_check(_near(p.spectre_burst, BOLT), "with the band, the ghost you call has a burst worth one bolt")
	await _dodge(Vector2.LEFT)
	_check(_near(_lost(post), BOLT) and _near(_lost(outside), 0.0) and p.spectre_left > 5.0, "your dodge leaves it where you stood: 6.6 to everything within 56 px (%.3f)" % _lost(post))
	await _staff(["saved_up", "on_dodge", "spectre"], home)
	await _press(0)
	_check(_near(p.spectre_burst, BOLT * 2.0), "a whole ghost's burst is worth two")
	await _staff(["spectre"], home)
	post = _slime(Vector2(44, 0))
	await _frames(2)
	await _press(0)
	await _dodge(Vector2.LEFT)
	_check(_near(_lost(post), 0.0) and _near(p.spectre_burst, 0.0), "without the band there is no burst")
	# Its copies set your passive runes off, at their share.
	await _staff(["spectre", "orbit"], home)
	post = _slime(Vector2(220, 0))
	await _frames(2)
	await _press(0)
	low = 100.0
	await _casts(3)
	_check(p.orbs.size() == 2 and _near(float(p.orbs[0]["dmg"]), BOLT) and _near(float(p.orbs[1]["dmg"]), BOLT * 0.5), "its finisher leaves an Orbit orb too, at half strength")
	# (The Spectre left 60; about 4 came back before the finisher. Two orbs paid for would be near 54.)
	_check(low > 57.0 and low < 60.0, "your orb costs its 5 mana; the ghost's is free (down to %.1f after the Spectre's 40)" % low)
	await _staff(["spectre", "chain"], home)
	post = _slime(Vector2(200, 0))
	far = _slime(Vector2(200, 110))
	await _frames(2)
	await _press(0)
	await _casts(3)
	_check(_near(_lost(far), BOLT * 0.75), "its bolt forks into a Chain at half strength: 3.3 and 1.65 (%.3f)" % _lost(far))
	await _staff(["spectre", "overflow"], home)
	post = _slime(Vector2(200, 0))
	await _frames(2)
	await _press(0)
	p.mana = SwingBuild.MANA
	await _casts(1)
	_check(_near(_lost(post), BOLT * 1.3 * 1.5), "it copies an Overflow bolt as it is: 8.58 and 4.29 (%.3f)" % _lost(post))
	# A second Spectre rune's On Dodge can't stack one on top of the other.
	p._end_spectre(true)

	# --- Spectre for a teammate ------------------------------------------------------------
	await _staff(["spectre"], home)
	m.builds[1].set_data(["iron_broadsword", "wrapped_grip", "plain_pommel", ["", "", "", ""]])
	m.builds[1].changed.emit()
	mate.global_position = home + Vector2(150, 20)   # in front of you, a little off your aim
	mate.reset_physics_interpolation()
	_quiet(mate)
	await _frames(3)
	mate.weapon["crit"] = 0.0
	post = _slime(Vector2(36, 0), mate)
	await _frames(2)
	await _press(0)
	_check(_near(mate.spectre_left, 6.0, 0.1) and mate.spectre_by == p and p.spectre_left <= 0.0, "aimed at a teammate, the Spectre goes to them")
	_check(p.spectre_on == mate and p.spectre_out() > 0.9, "and your button shows how long it has left")
	var swing: float = float(mate.weapon["damage"])
	await _casts(1, mate)
	_check(_near(_lost(post), swing * 1.5), "it copies their swing at half strength: %.1f and %.1f (%.3f)" % [swing, swing * 0.5, _lost(post)])
	m.build.changed.emit()   # your staff is changed: the ghost was its rune's
	await _frames(3)
	_check(mate.spectre_left <= 0.0 and p.spectre_on == null, "it goes when the staff it came from is changed")
	# With a bow in their hands it looses their arrows again.
	await _staff(["spectre"], home)
	m.swap_weapon(1, "bow")
	await _frames(2)
	m.builds[1].set_data(["iron_shortbow", "wrapped_bow_grip", "plain_string", ["", "", "", ""], "iron_arrows"])
	m.builds[1].changed.emit()
	mate.global_position = home + Vector2(150, 20)
	mate.reset_physics_interpolation()
	_quiet(mate)
	await _frames(3)
	mate.weapon["crit"] = 0.0
	post = _slime(Vector2(200, 0), mate)
	await _frames(2)
	await _press(0)
	await _casts(1, mate)
	_check(_near(_lost(post), float(mate.weapon["damage"]) * 1.5), "a teammate's arrow is loosed again at half strength (%.3f)" % _lost(post))
	# On Dodge belongs to the ghost: the teammate who has it leaves the burst.
	p._end_spectre(true)
	mate._end_spectre(true)
	await _staff(["on_dodge", "spectre"], home)
	mate.global_position = home + Vector2(150, 20)
	mate.reset_physics_interpolation()
	_quiet(mate)
	await _frames(3)
	post = _slime(Vector2(40, 0), mate)
	await _frames(2)
	await _press(0)
	_check(mate.spectre_left > 5.0 and _near(mate.spectre_burst, BOLT), "given to a teammate with On Dodge, the burst is a bolt of your staff")
	mate.dodge_charges = 1
	mate.input.move = Vector2.UP
	mate.input.dash_pressed = true
	await _frames(1)
	mate.input.dash_pressed = false
	await _frames(14)
	_quiet(mate)
	_check(_near(_lost(post), BOLT), "their dodge leaves it where they stood (%.3f)" % _lost(post))
	# Far away, or off your aim, it stays with you.
	p._end_spectre(true)
	mate._end_spectre(true)
	await _staff(["spectre"], home)
	mate.global_position = home + Vector2(0, -150)
	mate.reset_physics_interpolation()
	await _frames(2)
	await _press(0)
	_check(p.spectre_left > 5.0 and mate.spectre_left <= 0.0, "a teammate who isn't on your aim doesn't get it")

	print("RESULT: %d failed" % fails)
	quit(1 if fails > 0 else 0)
