extends SceneTree
## Checks for the hammer (15 November), run in the real arena with a scripted
## player: its parts, swapping to it, the maul's swing, swing, slam and what each
## hits, that it pins enemies and slows your feet, the warhammer, and that it does
## a little more a second than the sword it stands beside (it has to get closer).
##   godot --headless --path . --fixed-fps 60 -s tests/hammer.gd

const EnemyScript := preload("res://scripts/enemy.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Player := preload("res://scripts/player.gd")
const Art := preload("res://scripts/art.gd")

## The runes the forge offers a hammer: its three passive ones, then its three active ones.
const RUNES := ["momentum", "stagger", "aftershock", "quake", "bulwark", "hook"]
## An iron maul with nothing in its slots (the arena's test hammer carries runes;
## this test is about the hammer itself, and tests/hammer_runes.gd has the runes).
const BARE := ["iron_maul", "bound_haft", "plain_weight", ["", "", "", ""]]

var m
var p
var fails := 0


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


## A slime that stands where it's put and can't be killed.
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
	return e


func _lost(e) -> float:
	return e.max_hp - e.hp


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _has_art(rel: String) -> bool:
	return Art.texture(rel) != null


func _still() -> void:
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.input.stick_aim = Vector2.RIGHT
	p._reset_combo()
	await _frames(40)
	p._reset_combo()
	p.weapon["crit"] = 0.0   # no luck in the sums


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


## Damage a second of whole chains against a post at `offset`.
func _dps(offset: Vector2) -> float:
	var post = _slime(offset)
	await _frames(2)
	p._reset_combo()
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	var chains := 0
	var t0 := -1
	var d0 := 0.0
	var t1 := 0
	var d1 := 0.0
	var prev := 0
	for i in 60 * 40:
		await _frames(1)
		if prev == 2 and p.current_step != 2:
			if t0 < 0:
				t0 = i
				d0 = _lost(post)
			else:
				chains += 1
				t1 = i
				d1 = _lost(post)
				if chains >= 8:
					break
		prev = p.current_step
	p.input.attack_held = false
	post.queue_free()
	await _still()
	return (d1 - d0) / (float(t1 - t0) / 60.0)


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

	# --- The parts: what counts as a hammer ---------------------------------------------
	var test_hammer: Array = SwingBuild.TEST_HAMMER
	_check(SwingBuild.valid_data(test_hammer), "the arena's test hammer is a whole weapon (head, haft, counterweight, slots)")
	_check(SwingBuild.valid_data(SwingBuild.STARTERS["hammer"]), "and so is the plain wooden maul everyone starts from")
	_check(not SwingBuild.valid_data(["iron_maul", "wrapped_grip", "plain_weight", ["", "", "", ""]]), "a hammer can't take a sword's grip")
	_check(not SwingBuild.valid_data(["iron_maul", "bound_haft", "plain_pommel", ["", "", "", ""]]), "nor a pommel for a counterweight")
	_check(not SwingBuild.valid_data(["iron_broadsword", "bound_haft", "plain_pommel", ["", "", "", ""]]), "and a sword can't stand on a haft")
	_check(not SwingBuild.valid_data(["iron_maul", "bound_haft", "plain_weight", ["", "", "", ""], "iron_arrows"]), "a hammer has no fourth part")
	_check(not SwingBuild.valid_data(["iron_maul", "bound_haft", "plain_weight", ["", ""]]), "the slots must fit the head and haft (iron maul 2 + bound haft 2)")
	_check(SwingBuild.weapon_of("iron_maul") == "hammer" and SwingBuild.weapon_of("iron_warhammer") == "hammer" and not SwingBuild.ranged("hammer"), "a maul and a warhammer are hammers, and a hammer fights up close")
	for id in SwingBuild.HEADS:
		_check(_has_art("swing/hammer/heads/%s_hand.png" % id), "%s has its picture" % SwingBuild.HEADS[id]["name"])
	for id in SwingBuild.HAFTS:
		_check(_has_art("swing/hammer/hafts/%s_hand.png" % id), "%s has its picture" % SwingBuild.HAFTS[id]["name"])
	for id in SwingBuild.WEIGHTS:
		_check(_has_art("swing/hammer/weights/%s_hand.png" % id), "%s has its picture" % SwingBuild.WEIGHTS[id]["name"])
	for name in ["hammer_smear", "hammer_slam_smear", "hammer_impact", "hammer_hit"]:
		_check(Art.piece_texture(name) != null, "the %s effect has its picture" % name)

	# --- Swapping to it -----------------------------------------------------------------
	var sword: Array = m.build.get_data()
	m.swap_weapon(0)
	m.swap_weapon(0)
	await _frames(2)
	_check(m.build.weapon() == "hammer" and m.build.get_data() == test_hammer, "two swaps from the sword (past the bow) put the iron maul in your hand")
	_check(p.weapon.get("weapon") == "hammer" and p._is_hammer() and not p._ranged(), "and the player knows it is a hammer")
	_check(m.build.stowed.get("sword") == sword and m.build.stowed.has("bow") and not m.build.stowed.has("hammer"), "the sword and the bow wait, exactly as they were")
	_check(m.hud.swap_button.text == "SWAP TO STAFF (B)", "the button now offers the staff")
	_check(_near(float(p.weapon["damage"]), 7.0 * 2.8) and _near(float(p.weapon["damage"]), 19.6), "an iron maul's swing does 19.6: nearly three of an iron sword's 7 (slow but heavy since version 34; Darren's lab metals since version 57)")
	_check(_near(float(p.weapon["speed"]), 0.45) and _near(float(p.weapon["reach"]), 0.75), "it swings at under half a sword's speed and reaches three quarters as far")
	_check(_near(float(p.weapon["impact"]), 38.0), "its slam lands on a patch 38 px round")
	var chain: Array = []
	for st in p.weapon["steps"]:
		chain.append(st["move"])
	_check(chain == ["maul_swing", "maul_swing", "maul_slam"], "maul: swing, swing, slam")
	_check(not p.weapon.has("arrows") and not p.weapon.has("range"), "it shoots nothing")
	var fresh = SwingBuild.new()
	fresh.set_data(SwingBuild.STARTERS["sword"])
	fresh.take("hammer")
	_check(fresh.get_data() == SwingBuild.STARTERS["hammer"] and fresh.compute()["weapon"] == "hammer", "someone who never had a hammer gets the wooden maul")
	_check(_near(float(fresh.compute()["damage"]), 8.4), "whose swing does 8.4: two swings for a crawler's 14")
	await _still()

	# --- The hammer at the forge: its own parts, its own numbers, its own presets ---------
	var Forge := preload("res://scripts/ui/swing_forge.gd")
	var forge = m.build_menu
	m.open_forge(0)
	await _frames(2)
	_check(forge.is_open and forge.build.weapon() == "hammer", "with the hammer in your hand the forge opens on the hammer")
	forge._set_tab(0)
	_check(forge._tab_label(0) == "hammer", "its first tab is called HAMMER")
	var rows := {}
	for c in forge._cards():
		rows[c["kind"]] = int(rows.get(c["kind"], 0)) + 1
	_check(rows == {"heads": 2, "hafts": 3, "weights": 4}, "and offers two heads (maul, warhammer), three hafts and four counterweights: %s" % [rows])
	forge._set_tab(1)
	var offered: Array = []
	for c in forge._cards():
		offered.append(c["id"])
	_check(offered == RUNES, "the rune tray offers the hammer's own runes and none of the sword's: %s" % [offered])
	_check(not SwingBuild.valid_data(["iron_maul", "bound_haft", "plain_weight", ["shockwave", "", "", ""]]), "a sword's rune can't be fitted to a hammer")
	_check(SwingBuild.valid_data(["iron_maul", "bound_haft", "plain_weight", ["twice", "", "wider", ""]]), "bands can")
	# The numbers plate: impact beside reach, and what a part would change.
	var now: Dictionary = Forge.stat_values(forge.build.compute())
	_check(now.has("reach") and now.has("impact") and now.has("move") and not now.has("range"), "a hammer's numbers show reach, impact and walking while swinging")
	_check(Forge.stat_text("damage", now["damage"]) == "Damage 19.6" and Forge.stat_text("impact", now["impact"]) == "Impact 100%" and Forge.stat_text("move", now["move"]) == "Walk, swinging 80%",
		"an iron maul reads Damage 19.6, Impact 100%, Walk, swinging 80%")
	_check(Forge.stat_rows(forge.build.compute()).size() == 8, "eight numbers, on five rows")
	var change: Dictionary = Forge.stat_changes(now, Forge.stat_values(forge.stats_with("iron_warhammer")))
	_check(change == {"damage": "-2.4", "impact": "-15%", "move": "-10%"}, "pointing at the warhammer shows a lighter hit, a smaller patch, slower feet: %s" % [change])
	change = Forge.stat_changes(now, Forge.stat_values(forge.stats_with("studded_haft")))
	_check(change == {"slots": "+1"}, "a studded haft only adds a slot")
	change = Forge.stat_changes(now, Forge.stat_values(forge.stats_with("light_weight")))
	_check(change == {"speed": "+5%"}, "a light counterweight only swings faster, by a tenth of the maul's 45%%: %s" % [change])
	change = Forge.stat_changes(now, Forge.stat_values(forge.stats_with("heavy_weight")))
	_check(change == {"crit_damage": "+0.4"}, "a heavy one only crits harder: %s" % [change])
	_check(forge.info_lines("iron_warhammer").size() <= forge.INFO_LINES and forge._name("iron_warhammer") == "Iron Warhammer", "the info plate names a part and says what it is in the lines it has")
	# Fitting parts from the tray.
	forge._set_tab(0)
	var tray: Array = forge._cards()
	for i in tray.size():
		if tray[i]["id"] in ["iron_warhammer", "studded_haft", "keen_weight"]:
			forge._use_card(i)
	_check(m.build.get_data() == ["iron_warhammer", "studded_haft", "keen_weight", ["quake", "bulwark", "", "hook", "aftershock"]], "clicking a head, a haft and a counterweight fits them, and the runes keep their places (a new slot on the haft): %s" % [m.build.get_data()])
	_check(_near(float(p.weapon["damage"]), 17.15) and p.weapon["steps"][0]["move"] == "crush" and p.weapon["line"].size() == 5, "and the hammer in your hand is that warhammer: 17.15 a blow, five slots")
	forge._load_test("A")
	_check(m.build.weapon() == "hammer", "the test-sword keys do nothing while a hammer is on the anvil")
	# Presets: a hammer has three of its own.
	var hammer_a: Array = m.build.get_data()
	forge._click("preset:1")
	m.build.set_blade("iron_maul")
	var hammer_b: Array = m.build.get_data()
	_check(m.build.preset == 1 and m.build.preset_sword(0) == hammer_a, "preset B starts as a copy and is changed; A keeps the warhammer")
	forge._really_close()
	await _frames(2)
	m.swap_weapon(0, "sword")
	await _frames(2)
	_check(m.build.get_data() == sword and m.build.preset == 0 and m.build.preset_data == [null, null, null], "the sword's presets are its own: still on A, untouched by the hammer's")
	m.swap_weapon(0, "hammer")
	await _frames(2)
	_check(m.build.get_data() == hammer_b and m.build.preset == 1 and m.build.preset_sword(0) == hammer_a, "back on the hammer: still on its preset B, with A waiting")
	m.build.use_preset(0)
	m.build.set_data(BARE)
	m.build.changed.emit()
	await _still()

	# --- A chain at one enemy: 19.6, 19.6, 21.56 -------------------------------------------
	var post = _slime(Vector2(40, 0))
	await _frames(2)
	await _swings(1)
	_check(_near(_lost(post), 19.6), "a swing hits an enemy in front for 19.6 (%.3f)" % _lost(post))
	post.hp = post.max_hp
	await _swings(3)
	_check(_near(_lost(post), 19.6 + 19.6 + 21.56), "the whole chain: 19.6 + 19.6 + a slam's 21.56 = 60.76 (%.3f)" % _lost(post))
	_check(get_nodes_in_group("arrows").is_empty(), "nothing flies off a hammer")
	_check(is_equal_approx(p.global_position.x, home.x) and is_equal_approx(p.global_position.y, home.y), "swinging doesn't move you")
	post.queue_free()
	await _frames(2)

	# --- Reach: three quarters of a sword's -----------------------------------------------
	var reach: float = p._hit_reach()
	_check(_near(reach, 91.0 * 0.75), "the hit reaches 68 px from your middle (a broadsword: 91)")
	var inside = _slime(Vector2(reach + 14.0 - 2.0, 0))
	var outside = _slime(Vector2(0, -(reach + 14.0 + 3.0)))
	var behind = _slime(Vector2(-40, 0))
	await _frames(2)
	await _swings(1)
	_check(_lost(inside) > 0.0, "a swing hits an enemy whose edge is just inside that")
	_check(_lost(behind) == 0.0, "but not one behind you")
	p.input.stick_aim = Vector2.UP
	await _frames(20)
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(50)
	_check(_lost(outside) == 0.0, "nor one just past its reach")
	for e in [inside, outside, behind]:
		e.queue_free()
	await _still()

	# --- The slam hits a patch of floor -----------------------------------------------------
	# The head comes down six tenths of the way along the reach: 41 px in front.
	var centre: float = reach * Player.IMPACT_AT
	var mid = _slime(Vector2(centre, 0))
	var up = _slime(Vector2(centre, -40))
	var down = _slime(Vector2(centre, 40))
	var beyond = _slime(Vector2(reach + 14.0 + 8.0, 0))       # past a swing's reach, inside the patch
	var wide = _slime(Vector2(30, 85))                         # outside both
	await _frames(2)
	await _swings(2)
	_check(_near(_lost(mid), 39.2) and _lost(beyond) == 0.0, "two swings: the one in front is hit twice, the one a step further not at all")
	for e in [mid, up, down, beyond, wide]:
		e.hp = e.max_hp
	# The slam alone: the third move of a chain.
	p._reset_combo()
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	for i in 600:
		await _frames(1)
		if p.current_step == 2:
			break
	for e in [mid, up, down, beyond, wide]:
		e.hp = e.max_hp
	p.input.attack_held = false
	for i in 300:
		await _frames(1)
		if p.current_step < 0:
			break
	await _frames(10)
	_check(_near(_lost(mid), 21.56) and _near(_lost(up), 21.56) and _near(_lost(down), 21.56), "the slam hits everything on its patch for 21.56: the middle and 40 px to either side (%.2f, %.2f, %.2f)" % [_lost(mid), _lost(up), _lost(down)])
	_check(_near(_lost(beyond), 21.56), "it comes down a little further out than the swings reach")
	_check(_lost(wide) == 0.0, "and misses whatever stands off the patch")
	for e in [mid, up, down, beyond, wide]:
		e.queue_free()
	await _still()

	# --- It pins: a long stun and a small shove ---------------------------------------------
	_check(float(Player.MOVES["maul_swing"]["stun"]) > float(Player.MOVES["slash"]["stun"]) * 1.5 and float(Player.MOVES["maul_swing"]["knock"]) < float(Player.MOVES["slash"]["knock"]) * 0.6,
		"a maul's swing stuns for nearly twice as long as a slash and shoves about half as far")
	_check(float(Player.MOVES["maul_slam"]["stun"]) >= float(Player.MOVES["overhead"]["stun"]) * 2.0 and float(Player.MOVES["maul_slam"]["knock"]) < float(Player.MOVES["overhead"]["knock"]) * 0.5,
		"and its slam twice as long as an overhead, for less than half the shove")
	var held = _slime(Vector2(40, 0))
	held.knock_resist = 1.0
	await _frames(2)
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	var stunned := 0.0
	for i in 60:
		await _frames(1)
		stunned = maxf(stunned, held.hit_stun)
	_check(stunned > 0.25 and stunned <= 0.3 + 0.001, "an enemy a swing hits can't act for 0.3 s (%.2f)" % stunned)
	_check(held.global_position.distance_to(home) < 40.0 + 40.0, "and is still within reach afterwards (%d px away)" % roundi(held.global_position.distance_to(home)))
	held.queue_free()
	await _still()

	# --- Heavy on your feet -------------------------------------------------------------------
	p.input.move = Vector2.LEFT
	p.input.attack_held = true
	await _frames(40)
	var v_swing: float = p.walk_vel.length()
	p.input.attack_held = false
	p.input.move = Vector2.ZERO
	_check(absf(v_swing - Player.MOVE_SPEED * SwingBuild.HAMMER_MOVE) < 1.0, "you walk at 80%% speed while swinging a maul (%d of %d)" % [roundi(v_swing), roundi(Player.MOVE_SPEED)])
	p.global_position = home
	p.reset_physics_interpolation()
	await _still()

	# --- The warhammer: three crushing blows ---------------------------------------------------
	m.build.set_blade("iron_warhammer")
	await _still()
	chain = []
	for st in p.weapon["steps"]:
		chain.append(st["move"])
	_check(chain == ["crush", "crush", "crush"], "warhammer: three crushing blows")
	_check(_near(float(p.weapon["damage"]), 17.15) and _near(float(p.weapon["impact"]), 38.0 * 0.85), "each is 17.15 before its weight, on a patch a little smaller than a maul's (32 px)")
	post = _slime(Vector2(centre, 0))
	var side = _slime(Vector2(centre, 36))
	await _frames(2)
	await _swings(1)
	_check(_near(_lost(post), 18.865) and _near(_lost(side), 18.865), "a crushing blow hits everything on its patch for 18.9 (%.2f, %.2f)" % [_lost(post), _lost(side)])
	post.queue_free()
	side.queue_free()
	p.input.move = Vector2.LEFT
	p.input.attack_held = true
	await _frames(40)
	v_swing = p.walk_vel.length()
	p.input.attack_held = false
	p.input.move = Vector2.ZERO
	_check(absf(v_swing - Player.MOVE_SPEED * 0.7) < 1.0, "and you walk at 70%% speed while swinging one (%d of %d)" % [roundi(v_swing), roundi(Player.MOVE_SPEED)])
	p.global_position = home
	p.reset_physics_interpolation()
	await _still()
	var war_dps: float = await _dps(Vector2(34, 0))
	m.build.set_blade("iron_maul")
	await _still()
	var maul_dps: float = await _dps(Vector2(34, 0))
	# Every crush is a finisher, so the finisher's strength sets how the two heads compare.
	# At 150% they were level; at Darren's 110% (his lab, version 57) the warhammer does
	# about a fifth less a second. The sum below is the one the shapes were made with.
	var mv: Dictionary = Player.MOVES
	var war_chain: float = 3.0 * float(mv["crush"]["power"]) * float(SwingBuild.HAMMER_SHAPES["warhammer"]["damage"]) / (3.0 * float(mv["crush"]["time"]))
	var maul_chain: float = (2.0 * float(mv["maul_swing"]["power"]) + float(mv["maul_slam"]["power"])) * float(SwingBuild.HAMMER_SHAPES["maul"]["damage"]) / (2.0 * float(mv["maul_swing"]["time"]) + float(mv["maul_slam"]["time"]))
	var want: float = war_chain / maul_chain
	_check(absf(war_dps / maul_dps - want) < 0.05, "warhammer %.1f damage a second, maul %.1f: %.2f of it, as the finishers make it (%.2f)" % [war_dps, maul_dps, war_dps / maul_dps, want])

	# --- Against the sword: a fifth more a second, from closer in --------------------------------
	m.swap_weapon(0, "sword")
	await _frames(2)
	for i in m.build.line.size():
		m.build.line[i] = ""
	m.build.changed.emit()
	await _still()
	var sword_dps: float = await _dps(Vector2(34, 0))
	var ratio := maul_dps / sword_dps
	_check(ratio > 1.1 and ratio < 1.3, "the iron maul does %.1f a second, the iron broadsword %.1f: about a fifth more (%.2f)" % [maul_dps, sword_dps, ratio])
	m.swap_weapon(0, "hammer")
	await _frames(2)
	_check(m.build.get_data() == BARE, "and back on the hammer it is as it was")

	print("RESULT: %s (%d failed)" % ["all passed" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
