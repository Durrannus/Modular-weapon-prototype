extends SceneTree
## Checks for the first bow (14 November), run in the real arena with a scripted
## player: swapping sword and bow, the bow's numbers, what an arrow hits and where
## it stops, aiming while you draw, walking while you shoot, and that a bow does
## less damage a second than the sword it stands beside.
##   godot --headless --path . --fixed-fps 60 -s tests/bow.gd

const EnemyScript := preload("res://scripts/enemy.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Player := preload("res://scripts/player.gd")
const Arrow := preload("res://scripts/arrow.gd")

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


func _arrows() -> Array:
	var out: Array = []
	for a in get_nodes_in_group("arrows"):
		if is_instance_valid(a) and not a.is_queued_for_deletion():
			out.append(a)
	return out


func _still() -> void:
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.input.stick_aim = Vector2.RIGHT
	p._reset_combo()
	await _frames(100)     # long enough for every arrow to land and fade (they fly slower since version 34)
	p._reset_combo()
	p.weapon["crit"] = 0.0   # no luck in the sums


## Shoots (or swings) the first `count` moves of the chain and waits for the last
## to end and its arrow to land.
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
	await _frames(40)
	p._reset_combo()


## A real key press, the way the keyboard sends it.
func _key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.pressed = down
		ev.keycode = code
		ev.physical_keycode = code
		Input.parse_input_event(ev)
		await _frames(3)


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

	# --- The parts: what counts as a bow -------------------------------------------
	var test_bow: Array = SwingBuild.TEST_BOW
	_check(SwingBuild.valid_data(test_bow), "the arena's test bow is a whole weapon (limbs, grip, string, slots, arrows)")
	_check(SwingBuild.valid_data(SwingBuild.STARTERS["bow"]) and SwingBuild.valid_data(SwingBuild.STARTERS["sword"]), "and so are the plain wooden sword and bow everyone starts from")
	_check(not SwingBuild.valid_data(["iron_shortbow", "wrapped_grip", "plain_string", ["", "", "", ""], "iron_arrows"]), "a bow can't take a sword's grip")
	_check(not SwingBuild.valid_data(["iron_shortbow", "wrapped_bow_grip", "plain_pommel", ["", "", "", ""], "iron_arrows"]), "nor a pommel for a string")
	_check(not SwingBuild.valid_data(["iron_shortbow", "wrapped_bow_grip", "plain_string", ["", "", "", ""]]), "a bow with no arrows isn't one")
	_check(not SwingBuild.valid_data(["iron_broadsword", "wrapped_grip", "plain_pommel", ["", "", "", ""], "iron_arrows"]), "and a sword doesn't come with arrows")
	_check(not SwingBuild.valid_data(["iron_shortbow", "wrapped_bow_grip", "plain_string", ["", ""], "iron_arrows"]), "the slots must fit the limbs and grip (iron shortbow 2 + wrapped grip 2)")
	for id in SwingBuild.LIMBS:
		_check(_has_art("swing/bow/limbs/%s_hand.png" % id), "%s has its picture" % SwingBuild.LIMBS[id]["name"])
	for id in SwingBuild.BOW_GRIPS:
		_check(_has_art("swing/bow/grips/%s_hand.png" % id), "%s has its picture" % SwingBuild.BOW_GRIPS[id]["name"])
	for id in SwingBuild.ARROWS:
		_check(_has_art("swing/bow/arrows/%s_fly.png" % id) and _has_art("swing/bow/arrows/%s_stuck.png" % id), "%s have their pictures (flying and stuck)" % SwingBuild.ARROWS[id]["name"])

	# --- Swapping: B / the right stick, the button, and back again unchanged ---------
	var sword: Array = m.build.get_data()
	_check(m.build.weapon() == "sword" and p.weapon.get("weapon") == "sword", "the arena starts with the sword in your hand")
	await _frames(2)
	_check(m.hud.swap_button.text == "SWAP TO BOW (B)", "and a button offers the bow")
	m.swap_weapon(0)
	await _frames(2)
	_check(m.build.weapon() == "bow" and m.build.get_data() == test_bow, "swapping puts the iron shortbow in your hand")
	_check(p.weapon.get("weapon") == "bow" and p._is_bow(), "and the player knows it is a bow")
	_check(m.build.stowed.get("sword") == sword and not m.build.stowed.has("bow"), "the sword waits, exactly as it was")
	_check(m.hud.swap_button.text == "SWAP TO HAMMER (B)", "the button now offers the next weapon, the hammer")
	_check(is_equal_approx(float(p.weapon["damage"]), 7.0 * SwingBuild.BOW_DAMAGE) and is_equal_approx(float(p.weapon["damage"]), 4.9), "an iron arrow does 4.9: seven tenths of an iron sword's 7 (Darren's lab metals, version 57)")
	_check(is_equal_approx(float(p.weapon["range"]), 520.0) and is_equal_approx(float(p.weapon["flight"]), 800.0), "it flies 520 px at 800 a second")
	var chain: Array = []
	for st in p.weapon["steps"]:
		chain.append(st["move"])
	_check(chain == ["quick_shot", "quick_shot", "quick_shot"], "shortbow: three quick shots (no heavy last arrow until a later bow part)")
	_check(p.weapon.get("arrows") == "iron_arrows", "with iron arrows")
	m.swap_weapon(0, "sword")
	await _frames(2)
	_check(m.build.get_data() == sword and p.weapon.get("weapon") == "sword", "swapping back gives the same sword, runes and all")
	_check(m.build.stowed.get("bow") == test_bow and not m.build.stowed.has("sword"), "and now the bow waits")
	await _key(KEY_B)
	_check(m.build.weapon() == "bow", "the B key swaps too")
	await _key(KEY_B)
	await _key(KEY_B)
	await _key(KEY_B)
	_check(m.build.weapon() == "sword", "and three more presses come round to the sword (by way of the hammer and the staff)")
	m.hud.swap_button.pressed.emit()
	await _frames(2)
	_check(m.build.weapon() == "bow", "so does the button on the screen")
	# A build that never held a bow gets the plain wooden one.
	var fresh = SwingBuild.new()
	fresh.set_data(SwingBuild.STARTERS["sword"])
	fresh.take("bow")
	_check(fresh.get_data() == SwingBuild.STARTERS["bow"] and fresh.compute()["weapon"] == "bow", "someone who never had a bow gets the wooden shortbow")
	_check(is_equal_approx(float(fresh.compute()["damage"]), 2.1), "whose wooden arrows do 2.1: seven of them are one crawler's 14")
	fresh.take("spear")
	_check(fresh.weapon() == "bow", "(asking for a weapon that doesn't exist changes nothing)")

	# --- The bow at the forge: its own parts, its own presets, no sword runes -----------
	var Forge := preload("res://scripts/ui/swing_forge.gd")
	var forge = m.build_menu
	m.open_forge(0)
	_check(forge.is_open and forge.build.weapon() == "bow", "with the bow in your hand the forge opens on the bow")
	forge._set_tab(0)
	_check(forge._tab_label(0) == "bow", "its first tab is called BOW")
	var rows := {}
	for c in forge._cards():
		rows[c["kind"]] = int(rows.get(c["kind"], 0)) + 1
	_check(rows == {"limbs": 2, "bow_grips": 3, "strings": 4, "arrows": 3}, "and offers limbs (shortbow, longbow), three grips, four strings and three kinds of arrows: %s" % [rows])
	forge._set_tab(1)
	var offered: Array = []
	for c in forge._cards():
		offered.append(c["id"])
	_check(offered == ["pierce", "ricochet", "steady_aim", "volley", "snipe", "arrow_rain"], "the rune tray offers the bow's six runes and none of the sword's: %s" % [offered])
	_check(not SwingBuild.valid_data(["iron_shortbow", "wrapped_bow_grip", "plain_string", ["shockwave", "", "", ""], "iron_arrows"]), "a sword's rune can't be fitted to a bow")
	_check(SwingBuild.valid_data(["iron_shortbow", "wrapped_bow_grip", "plain_string", ["twice", "", "wider", ""], "iron_arrows"]), "bands can")
	_check(SwingBuild.fits("leap", "sword") and not SwingBuild.fits("leap", "bow") and SwingBuild.fits("twice", "bow"), "(every weapon has its own runes; bands fit them all)")
	# The numbers plate: range where a sword has reach, and what a part would change.
	var now: Dictionary = Forge.stat_values(forge.build.compute())
	_check(now.has("range") and now.has("shoot_move") and not now.has("reach"), "a bow's numbers show range and walking while shooting")
	_check(Forge.stat_text("damage", now["damage"]) == "Damage 4.9" and Forge.stat_text("range", now["range"]) == "Range 100%", "an iron shortbow reads Damage 4.9, Range 100%")
	var change: Dictionary = Forge.stat_changes(now, Forge.stat_values(forge.stats_with("iron_longbow")))
	_check(str(change.get("range", "")) == "+35%" and not change.has("damage") and str(change.get("shoot_move", "")) == "-10%", "pointing at the longbow shows more range and slower feet, the same arrows: %s" % [change])
	change = Forge.stat_changes(now, Forge.stat_values(forge.stats_with("tin_arrows")))
	_check(change.size() == 1 and str(change.get("damage", "")).begins_with("-"), "tin arrows only change the damage: %s" % [change])
	change = Forge.stat_changes(now, Forge.stat_values(forge.stats_with("horn_bow_grip")))
	_check(change == {"slots": "+1"}, "a horn grip only adds a slot")
	change = Forge.stat_changes(now, Forge.stat_values(forge.stats_with("light_string")))
	_check(change == {"speed": "+10%"}, "a light string only draws faster")
	# Fitting parts from the tray.
	forge._set_tab(0)
	var tray: Array = forge._cards()
	for i in tray.size():
		if tray[i]["id"] in ["iron_longbow", "horn_bow_grip", "keen_string", "tin_arrows"]:
			forge._use_card(i)
	_check(m.build.get_data() == ["iron_longbow", "horn_bow_grip", "keen_string", ["volley", "snipe", "", "arrow_rain", "ricochet"], "tin_arrows"], "clicking limbs, a grip, a string and arrows fits them: %s" % [m.build.get_data()])
	_check(is_equal_approx(float(p.weapon["damage"]), 5.0 * 0.7) and is_equal_approx(float(p.weapon["range"]), 702.0), "a longbow with tin arrows: 3.5 damage, 702 px")
	forge._load_test("A")
	_check(m.build.weapon() == "bow", "the test-sword keys do nothing while a bow is on the anvil")
	# Presets: a bow has three of its own.
	var bow_a: Array = m.build.get_data()
	forge._click("preset:1")
	m.build.set_blade("iron_shortbow")
	m.build.set_arrows("iron_arrows")
	var bow_b: Array = m.build.get_data()
	_check(m.build.preset == 1 and m.build.preset_sword(0) == bow_a, "preset B starts as a copy and is changed; A keeps the longbow")
	forge._really_close()
	await _frames(2)
	m.swap_weapon(0, "sword")
	await _frames(2)
	_check(m.build.get_data() == sword and m.build.preset == 0 and m.build.preset_data == [null, null, null], "the sword's presets are its own: still on A, untouched by the bow's")
	m.swap_weapon(0, "bow")
	await _frames(2)
	_check(m.build.get_data() == bow_b and m.build.preset == 1 and m.build.preset_sword(0) == bow_a, "back on the bow: still on its preset B, with A waiting")
	m.build.use_preset(0)
	# (No runes on it from here: this is about the bow itself. tests/bow_runes.gd has the runes.)
	m.build.set_data(["iron_shortbow", "wrapped_bow_grip", "plain_string", ["", "", "", ""], "iron_arrows"])
	m.build.changed.emit()
	await _frames(2)

	# --- A chain at one enemy: 4.9, 4.9, 4.9 ---------------------------------------------
	await _still()
	var post = _slime(Vector2(200, 0))
	await _frames(2)
	await _shots(1)
	_check(is_equal_approx(_lost(post), 4.9), "a quick shot hits an enemy 200 px away for 4.9 (%.3f)" % _lost(post))
	post.hp = post.max_hp
	await _shots(3)
	_check(absf(_lost(post) - 4.9 * 3.0) < 0.001, "the whole chain: three arrows of 4.9 = 14.7 (%.3f)" % _lost(post))
	_check(_arrows().is_empty(), "an arrow that hits is gone")
	_check(is_equal_approx(p.global_position.x, home.x) and is_equal_approx(p.global_position.y, home.y), "shooting doesn't move you")
	post.queue_free()
	await _frames(2)

	# --- The first enemy in the way stops it -------------------------------------------
	var near = _slime(Vector2(150, 0))
	var far = _slime(Vector2(260, 0))
	var beside = _slime(Vector2(200, 40))
	await _frames(2)
	await _shots(1)
	_check(_lost(near) > 0.0 and _lost(far) == 0.0, "an arrow stops in the first enemy it meets")
	_check(_lost(beside) == 0.0, "and it is narrow: one standing 40 px off its line is missed")
	for e in [near, far, beside]:
		e.queue_free()
	await _frames(2)

	# --- Range: 520 px, and it stops on the floor there -------------------------------
	var edge: float = 520.0 + 14.0 + Arrow.HALF_WIDTH
	var inside = _slime(Vector2(edge - 5.0, 0))
	await _frames(2)
	await _shots(1)
	_check(_lost(inside) > 0.0, "an enemy whose edge is just inside 520 px is hit")
	inside.global_position = p.global_position + Vector2(edge + 8.0, 0)
	inside.hp = inside.max_hp
	await _frames(2)
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	var spent = null
	for i in 80:
		await _frames(1)
		for a in _arrows():
			if not a.flying:
				spent = a
		if spent != null:
			break
	_check(_lost(inside) == 0.0, "one just past it is not")
	_check(spent != null and not spent.in_wall and absf(spent.global_position.x - (home.x + 520.0)) < 0.5, "the arrow drops to the floor 520 px out")
	await _frames(roundi(Arrow.STUCK_TIME * 60.0) + 4)
	_check(_arrows().is_empty(), "and fades away after a moment")
	inside.queue_free()
	await _still()

	# --- A wall stops it ---------------------------------------------------------------
	var wall_x: float = m.ARENA.end.x
	p.global_position = Vector2(wall_x - 150.0, 560)
	p.reset_physics_interpolation()
	var behind_wall = _slime(Vector2(190, 0))      # outside the room
	await _frames(2)
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	spent = null
	for i in 80:
		await _frames(1)
		for a in _arrows():
			if not a.flying:
				spent = a
		if spent != null:
			break
	_check(spent != null and spent.in_wall and absf(spent.global_position.x - wall_x) < 0.5, "an arrow sticks in the wall it meets (150 px away)")
	_check(_lost(behind_wall) == 0.0, "and never reaches an enemy on the other side")
	behind_wall.queue_free()
	p.global_position = home
	p.reset_physics_interpolation()
	await _still()

	# --- You aim while you draw: the arrow goes where you point as it leaves ------------
	var above = _slime(Vector2(0, -200))
	var right = _slime(Vector2(200, 0))
	await _frames(2)
	p.input.stick_aim = Vector2.RIGHT
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(3)
	_check(_arrows().is_empty() and p.current_step == 0, "the string is drawn first: nothing leaves for a moment")
	p.input.stick_aim = Vector2.UP
	await _frames(60)
	_check(_lost(above) > 0.0 and _lost(right) == 0.0, "turning while you draw turns the shot (began aiming right, loosed up)")
	above.queue_free()
	right.queue_free()
	await _still()

	# --- You can walk while you shoot, a little slower ----------------------------------
	p.input.move = Vector2.LEFT
	p.input.attack_held = true
	await _frames(40)
	var v_bow: float = p.walk_vel.length()
	p.input.attack_held = false
	p.input.move = Vector2.ZERO
	_check(absf(v_bow - Player.MOVE_SPEED * SwingBuild.BOW_MOVE) < 1.0, "you walk at 80%% speed while shooting (%d of %d)" % [roundi(v_bow), roundi(Player.MOVE_SPEED)])
	p.global_position = home
	p.reset_physics_interpolation()
	await _still()

	# --- An arrow in the air when you swap is still an arrow ----------------------------
	var target = _slime(Vector2(480, 0))
	await _frames(2)
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	for i in 60:
		await _frames(1)
		if not _arrows().is_empty():
			break
	_check(_arrows().size() == 1, "an arrow is on its way")
	var before: int = m.net_state().size()
	m.swap_weapon(0, "sword")
	await _frames(1)
	_check(m.build.weapon() == "sword", "swapping to the sword while it flies")
	await _frames(70)
	_check(is_equal_approx(_lost(target), 4.9), "it still lands for its 4.9 (%.3f)" % _lost(target))
	_check(m.net_state().size() == before - 3, "(online, both computers compare where every arrow is while it flies)")
	target.queue_free()
	await _still()

	# --- The sword still works, and a knocked-out player can't swap ---------------------
	var close = _slime(Vector2(50, 0))
	await _frames(2)
	await _shots(1)
	_check(_lost(close) >= 7.0, "back on the sword, a slash hits for the sword's 7 (%.2f)" % _lost(close))
	_check(_arrows().is_empty(), "and no arrow leaves a sword")
	close.queue_free()
	p.is_down = true
	m.swap_weapon(0)
	_check(m.build.weapon() == "sword", "a player who is down can't swap")
	p.is_down = false
	await _still()

	# --- The longbow: shot, shot, a charged heavy shot; further; within a tenth of the shortbow ----
	m.swap_weapon(0, "bow")
	await _frames(2)
	m.build.set_blade("iron_longbow")
	await _still()
	var long_steps: Array = []
	for st in p.weapon["steps"]:
		long_steps.append(st["move"])
	_check(long_steps == ["quick_shot", "quick_shot", "charged_shot"], "longbow: shot, shot, charged shot (the later part with the heavy last arrow)")
	var far_post = _slime(Vector2(650, 0))
	await _frames(2)
	await _shots(1)
	_check(is_equal_approx(_lost(far_post), 4.9), "a longbow's arrow reaches an enemy 650 px away for 4.9 (%.3f)" % _lost(far_post))
	far_post.hp = far_post.max_hp
	await _shots(3)
	_check(absf(_lost(far_post) - 4.9 * (2.0 + float(Player.MOVES["charged_shot"]["power"]))) < 0.001, "its whole chain: 4.9 + 4.9 + a charged 8.6 (%.3f)" % _lost(far_post))
	_check(float(Player.MOVES["charged_shot"]["windup"]) > float(Player.MOVES["quick_shot"]["windup"]) * 2.0, "the last arrow takes a moment to charge")
	far_post.queue_free()
	p.input.move = Vector2.LEFT
	p.input.attack_held = true
	await _frames(40)
	var v_long: float = p.walk_vel.length()
	p.input.attack_held = false
	p.input.move = Vector2.ZERO
	_check(absf(v_long - Player.MOVE_SPEED * 0.7) < 1.0, "you walk at 70%% speed while shooting a longbow (%d of %d)" % [roundi(v_long), roundi(Player.MOVE_SPEED)])
	p.global_position = home
	p.reset_physics_interpolation()
	await _still()
	var long_dps: float = await _dps(Vector2(200, 0))
	m.build.set_blade("iron_shortbow")
	await _still()
	var short_dps: float = await _dps(Vector2(200, 0))
	_check(absf(long_dps / short_dps - 1.0) < 0.1, "longbow %.1f damage a second, shortbow %.1f: within a tenth (%.2f)" % [long_dps, short_dps, long_dps / short_dps])
	m.swap_weapon(0, "sword")
	await _still()

	# --- Ranged must not beat melee: the bow does less a second than the sword ----------
	for i in m.build.line.size():
		m.build.line[i] = ""
	m.build.changed.emit()
	await _still()
	var sword_dps: float = await _dps(Vector2(34, 0))
	m.swap_weapon(0, "bow")
	await _still()
	var bow_dps: float = await _dps(Vector2(200, 0))
	var ratio := bow_dps / sword_dps
	_check(ratio > 0.6 and ratio < 0.9, "iron shortbow %.1f damage a second, iron broadsword %.1f: the bow does %.2f of the sword's" % [bow_dps, sword_dps, ratio])

	print("RESULT: " + ("all passed" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)


func _has_art(path: String) -> bool:
	return load("res://scripts/art.gd").texture(path) != null
