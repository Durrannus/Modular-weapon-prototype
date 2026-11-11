extends SceneTree
## Smoke check: opens the forge in the real scene with every fitting on the sword,
## draws a few frames and fires every rune on the player. Any script error shows in the log.
##   godot --headless --path . -s tests/smoke_forge.gd

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var forge = null
	for n in main.find_children("*", "", true, false):
		if n.get_script() == preload("res://scripts/ui/swing_forge.gd"):
			forge = n
	if forge == null:
		print("FAIL: no forge found")
		quit(1)
		return
	forge.open()
	var lines := [
		["twice", "shockwave", "relay", "leap"],
		["every_hit", "shockwave", "mirror", "saved_up"],
		["on_dodge", "leap", "mirror", "shards"],
		["relay", "mirror", "wider", ""],
	]
	forge.build.set_grip("gilded_grip")
	forge.build.set_blade("iron_broadsword")
	for l in lines:
		forge.build.line = l.duplicate()
		for t in forge.TABS.size():
			forge._set_tab(t)
			forge.root.queue_redraw()
			await process_frame
		for i in l.size():
			forge.selected = i
			forge.root.queue_redraw()
			await process_frame
	if not forge.buttons.has("tab:3"):
		print("FAIL: the forge never drew")
	forge._set_tab(3)
	forge.selected = 0
	forge._put("mirror")
	forge.selected = 3
	forge._put("relay")
	print("one bender kept: ", forge.build.line)
	# Drag and drop: tray card onto slot 0, slot 0 onto slot 1 (swap), slot 1 off the sword.
	forge.build.line = ["", "leap", "", ""]
	forge._set_tab(1)
	forge.drag_id = forge._drag_source("card:0"); forge.drag_from = -1; forge.drag_key = "card:0"; forge.dragging = true
	forge._drop("slot:0")
	print("drag card->slot0: ", forge.build.line)
	forge.drag_id = forge._drag_source("slot:0"); forge.drag_from = 0; forge.drag_key = "slot:0"; forge.dragging = true
	forge._drop("slot:1")
	print("drag slot0->slot1 swap: ", forge.build.line)
	forge.drag_id = forge._drag_source("slot:1"); forge.drag_from = 1; forge.drag_key = "slot:1"; forge.dragging = true
	forge._drop("")
	print("drag slot1 off: ", forge.build.line)
	forge.drag_id = forge._drag_source("card:2"); forge.drag_from = -1; forge.drag_key = "card:2"; forge.dragging = false
	forge._drop("")
	print("press without drag = click, selected card: ", forge.card)
	await _check_words(forge)
	await _check_presets(forge)
	forge._set_tab(0)
	for i in forge._cards().size():
		forge._use_card(i)
	print("sword tab used: ", forge.build.blade, " ", forge.build.grip, " ", forge.build.pommel)
	forge.close()
	var player = main.find_children("*", "CharacterBody2D", true, false)[0]
	forge.build.line = ["every_hit", "shards", "on_dodge", "leap"]
	player.set_weapon(forge.build.compute())
	for k in 6:
		main._spawn_enemy()
	for e in player.get_tree().get_nodes_in_group("enemies"):
		e.global_position = player.global_position + Vector2(50, 0).rotated(randf() * TAU)
	for trig in ["dodge", "dodge_attack", "finisher", "finisher", "finisher", "hit", "kill"]:
		player._trigger(trig, [])
		for f in 12:
			await physics_frame
	forge.build.line = ["on_dodge", "whirlwind", "wider", "leap"]
	player.set_weapon(forge.build.compute())
	for e in player.get_tree().get_nodes_in_group("enemies"):
		e.global_position = player.global_position + Vector2(50, 0).rotated(randf() * TAU)
	for trig in ["dodge", "dodge_attack", "finisher", "finisher", "finisher", "hit", "kill"]:
		player._trigger(trig, [])
		for f in 12:
			await physics_frame
	if fails > 0:
		print("smoke FAILED: %d" % fails)
		quit(1)
		return
	print("smoke done")
	quit(0)


var fails := 0


func _fail(what: String) -> void:
	fails += 1
	print("FAIL: ", what)


## Nothing on the forge screen may overlap: every part's sentence fits its plate,
## "what it does" fits its plate for the fullest swords, and every number fits its
## column with the biggest change beside it.
func _check_words(forge) -> void:
	var Forge := preload("res://scripts/ui/swing_forge.gd")
	var parts: Array = []
	parts.append_array(SwingBuild.BLADES.keys())
	parts.append_array(SwingBuild.GRIPS.keys())
	parts.append_array(SwingBuild.POMMELS.keys())
	parts.append_array(SwingBuild.FITTINGS.keys())
	for id in parts:
		var n: int = forge.info_lines(id).size()
		if n > 3:
			_fail("%s: its sentence takes %d lines on the info plate (3 fit)" % [id, n])
	print("sentences fit: ", parts.size(), " parts")
	# Every rune in the tray has its "hold Alt" picture.
	for id in SwingBuild.FITTING_ORDER:
		var fit: Dictionary = SwingBuild.FITTINGS[id]
		if fit["kind"] == "rune" and not fit.get("parked", false) and not FileAccess.file_exists("res://art/swing/previews/%s.png" % id):
			_fail("%s has no preview picture" % id)
	# Hook left the sword for the hammer (11 November): the tray no longer offers it.
	forge._set_tab(1)
	var tray_ids: Array = []
	for c in forge._cards():
		tray_ids.append(str(c.get("id", "")))
	if "hook" in tray_ids or not ("whirlwind" in tray_ids and "leap" in tray_ids and "ghostwield" in tray_ids):
		_fail("the rune tray should offer Whirlwind, Leap and Ghostwield, and not Hook: %s" % [tray_ids])
	# The fullest swords, with keyboard and with controller button names.
	var full := [
		["whirlwind", "leap", "shards", "weak_point"],
		["whirlwind", "twice", "leap", "saved_up"],
		["shockwave", "every_hit", "shards", "on_dodge"],
		["leap", "wider", "relay", "weak_point"],
		["every_hit", "whirlwind", "every_hit", "leap"],
		["twice", "wider", "saved_up", "every_hit"],
		["leap", "on_dodge", "whirlwind", "every_hit"],
		# Ghostwield has the longest sentences of all.
		["whirlwind", "leap", "ghostwield", "weak_point"],
		["every_hit", "ghostwield", "on_dodge", "ghostwield"],
		["on_dodge", "ghostwield", "every_hit", "leap"],
		["saved_up", "ghostwield", "every_hit", "whirlwind"],
		["twice", "wider", "every_hit", "ghostwield"],
		["leap", "every_hit", "on_dodge", "ghostwield"],
	]
	forge.build.set_blade("iron_greatsword")
	forge._set_tab(1)
	var was_keys = forge.keys
	for keys in [SwingBuild.ABILITY_KEYS["kbm"], SwingBuild.ABILITY_KEYS["pad"]]:
		forge.keys = keys
		for grip in ["gilded_grip", "wrapped_grip", "ringed_grip"]:
			forge.build.set_grip(grip)
			for l in full:
				forge.build.line = l.duplicate()
				forge.root.queue_redraw()
				await process_frame
				await process_frame
				if not forge.does_fits:
					_fail("what it does runs off its plate: %s %s" % [grip, l])
	forge.keys = was_keys
	print("what it does fits: ", full.size() * 6, " swords")
	# Compare on hover. The Game Bible's example: a sabre fitted, pointing at a
	# greatsword shows more reach and damage, less crit and speed.
	forge.build.set_grip("wrapped_grip")
	forge.build.set_pommel("plain_pommel")
	forge.build.set_blade("iron_sabre")
	var now: Dictionary = Forge.stat_values(forge.build.compute())
	var then: Dictionary = Forge.stat_values(forge.stats_with("iron_greatsword"))
	var ch: Dictionary = Forge.stat_changes(now, then)
	print("sabre -> greatsword: ", ch)
	for key in ["damage", "reach"]:
		if not str(ch.get(key, "")).begins_with("+"):
			_fail("sabre to greatsword should gain %s" % key)
	for key in ["crit", "speed", "move"]:
		if not str(ch.get(key, "")).begins_with("-"):
			_fail("sabre to greatsword should lose %s" % key)
	if ch.has("slots") or ch.has("crit_damage"):
		_fail("sabre to greatsword should leave slots and crit damage alone")
	ch = Forge.stat_changes(now, Forge.stat_values(forge.stats_with("long_grip")))
	if ch != {"slots": "+1"}:
		_fail("a long grip should only add a slot, got %s" % ch)
	# Every sword, pointing at every part: each number and its change fit the column.
	var widest := -999.0
	var tight := ""
	var pairs := 0
	for blade in SwingBuild.BLADES:
		for grip in SwingBuild.GRIPS:
			for pommel in SwingBuild.POMMELS:
				forge.build.set_blade(blade)
				forge.build.set_grip(grip)
				forge.build.set_pommel(pommel)
				now = Forge.stat_values(forge.build.compute())
				var others: Array = []
				others.append_array(SwingBuild.BLADES.keys())
				others.append_array(SwingBuild.GRIPS.keys())
				others.append_array(SwingBuild.POMMELS.keys())
				for id in others:
					then = Forge.stat_values(forge.stats_with(id))
					pairs += 1
					for row in Forge.STAT_ROWS:
						var key: String = row[0]
						var w: float = forge.stat_width(Forge.stat_text(key, now[key]), Forge.delta_text(key, float(then[key]) - float(now[key])))
						var room: float = Forge.STAT_COL - 3.0
						if key == "move" or int(row[1]) == 1:
							room = Forge.STATS.size.x - Forge.stat_at(row).x - 6.0
						if w - room > widest:
							widest = w - room
							tight = "%s on a %s %s %s, pointing at %s (%d of %d px)" % [key, blade, grip, pommel, id, w, room]
						if w > room:
							_fail("%s on a %s %s %s, pointing at %s: %d px wide, %d fit" % [key, blade, grip, pommel, id, w, room])
							return
	print("numbers fit: %d comparisons, the tightest is %s" % [pairs, tight])


## Loadout presets on the forge screen: switching, naming, and help that fits.
func _check_presets(forge) -> void:
	forge.build.load_test("D")
	forge.build.preset_names = ["", "", ""]
	var first: Array = forge.build.get_data()
	forge.root.queue_redraw()
	await process_frame
	await process_frame
	for key in ["preset:0", "preset:1", "preset:2", "rename"]:
		if not forge.buttons.has(key):
			_fail("the forge has no %s button" % key)
	forge._click("preset:1")
	forge.build.set_blade("iron_greatsword")
	forge.build.set_slot(0, "shockwave")
	var second: Array = forge.build.get_data()
	forge._click("preset:0")
	if forge.build.get_data() != first:
		_fail("clicking preset A did not bring the first sword back")
	forge._click("preset:1")
	if forge.build.get_data() != second:
		_fail("clicking preset B did not bring the second sword back")
	# Naming it: the keys write the name and do nothing else (T would leave for the dummy).
	forge._click("rename")
	for ch in "Bossing!":
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.keycode = OS.find_keycode_from_string(ch.to_upper())
		ev.unicode = ch.unicode_at(0)
		forge._input(ev)
	# The same through the real input path: Tab leaves the forge and T tries the
	# sword at the dummy, but not while a name is being typed.
	for code in [KEY_TAB, KEY_T, KEY_BACKSPACE]:
		for down in [true, false]:
			var real := InputEventKey.new()
			real.pressed = down
			real.keycode = code
			real.physical_keycode = code
			real.unicode = 116 if code == KEY_T and down else 0
			Input.parse_input_event(real)
			await process_frame
			await process_frame
	if not forge.is_open or not forge.renaming or forge.finishing >= 0.0:
		_fail("typing a preset's name closed the forge or stopped the naming")
	if forge.rename_text != "Bossing!":
		_fail("typed Bossing!, then t and backspace, and got '%s'" % forge.rename_text)
	for l in forge.help_lines():
		_fits_help(forge, l[0])
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	Input.parse_input_event(enter)
	await process_frame
	await process_frame
	var card_was: Array = forge.build.get_data()
	if forge.build.preset_names[1] != "Bossing!" or forge.build.preset_title(1) != "Preset B: Bossing!":
		_fail("the preset's name was not kept: %s" % forge.build.preset_names)
	await process_frame
	await process_frame
	await process_frame
	if not forge.is_open or forge.finishing >= 0.0 or forge.build.get_data() != card_was:
		_fail("the Enter that ended the naming also did something else")
	enter = enter.duplicate()
	enter.pressed = false
	Input.parse_input_event(enter)
	await process_frame
	forge._click("rename")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	await process_frame
	if not forge.is_open or forge.finishing >= 0.0 or forge.renaming or forge.build.preset_names[1] != "Bossing!":
		_fail("Esc while naming should only cancel the naming")
	esc = esc.duplicate()
	esc.pressed = false
	Input.parse_input_event(esc)
	await process_frame
	# A part that is no longer owned is left off, and the help plate says so.
	forge._click("preset:0")
	var was_owned = forge.owned
	forge.owned = ["iron_broadsword", "wrapped_grip", "plain_pommel", "whirlwind", "leap", "weak_point"]
	forge._click("preset:1")
	if forge.build.blade != "iron_broadsword" or "shockwave" in forge.build.line:
		_fail("a preset put on parts the player does not own: %s" % [forge.build.get_data()])
	if forge.note == "" or forge.help_lines().is_empty():
		_fail("nothing said which parts were left off")
	for l in forge.help_lines():
		_fits_help(forge, l[0])
	forge.root.queue_redraw()
	await process_frame
	forge.owned = was_owned
	forge.note_until = -9.0
	# Every set of help lines fits its plate: mouse, controller, pointing at the presets.
	var was_keys = forge.keys
	for keys in [SwingBuild.ABILITY_KEYS["kbm"], SwingBuild.ABILITY_KEYS["pad"]]:
		forge.keys = keys
		for h in ["", "preset:2", "rename"]:
			forge.hover = h
			for sandbox in [true, false]:
				forge.sandbox = sandbox
				var lines: Array = forge.help_lines()
				if lines.size() > 3:
					_fail("more than three lines of help")
				for l in lines:
					_fits_help(forge, l[0])
			forge.root.queue_redraw()
			await process_frame
	forge.keys = was_keys
	forge.hover = ""
	forge.sandbox = true
	forge._click("preset:0")
	print("presets: switched, named and loaded with a part missing")


func _fits_help(forge, text: String) -> void:
	var w: float = preload("res://scripts/art.gd").font("PixelifySans-Regular").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	if w > forge.HELP.size.x - 14.0:
		_fail("help line too wide (%d px): %s" % [w, text])
