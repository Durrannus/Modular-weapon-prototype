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
	await _check_back(forge)
	await _check_bow(forge, main)
	await _check_other(forge, main, "hammer", [["iron_maul", "studded_haft"], ["wooden_maul", "wooden_haft"], ["iron_warhammer", "bound_haft"]],
		["momentum", "stagger", "aftershock", "quake", "bulwark", "hook"], [
			["quake", "bulwark", "hook", "aftershock", "momentum"],
			["quake", "bulwark", "hook", "stagger", "momentum"],
			["on_dodge", "bulwark", "every_hit", "quake", "hook"],
			["saved_up", "bulwark", "on_dodge", "quake", "aftershock"],
			["twice", "quake", "every_hit", "hook", "stagger"],
			["on_dodge", "wider", "momentum", "every_hit", "aftershock"],
			["saved_up", "momentum", "on_dodge", "stagger", "aftershock"],
			["every_hit", "saved_up", "aftershock", "on_dodge", "stagger"],
			["wider", "on_dodge", "bulwark", "every_hit", "quake"],
			["on_dodge", "quake", "on_dodge", "bulwark", "hook"],
			["every_hit", "saved_up", "on_dodge", "bulwark", "quake"],
			["twice", "wider", "saved_up", "on_dodge", "momentum"],
			["twice", "wider", "saved_up", "on_dodge", "stagger"],
			["twice", "wider", "saved_up", "on_dodge", "aftershock"],
			["twice", "wider", "saved_up", "on_dodge", "bulwark"],
			["twice", "wider", "saved_up", "on_dodge", "quake"],
			["wider", "saved_up", "on_dodge", "momentum", "quake"],
			["wider", "saved_up", "on_dodge", "stagger", "bulwark"],
		])
	await _check_other(forge, main, "staff", [["iron_storm", "twisted_shaft"], ["wooden_apprentice", "wooden_shaft"], ["iron_apprentice", "carved_shaft"]],
		["orbit", "chain", "overflow", "nova", "lance", "spectre"], [
			["nova", "lance", "spectre", "chain", "orbit"],
			["nova", "lance", "spectre", "overflow", "orbit"],
			["on_dodge", "lance", "every_hit", "nova", "spectre"],
			["saved_up", "lance", "on_dodge", "nova", "chain"],
			["twice", "nova", "every_hit", "spectre", "overflow"],
			["on_dodge", "wider", "orbit", "every_hit", "chain"],
			["saved_up", "orbit", "on_dodge", "overflow", "chain"],
			["every_hit", "saved_up", "chain", "on_dodge", "overflow"],
			["wider", "on_dodge", "lance", "every_hit", "nova"],
			["on_dodge", "nova", "on_dodge", "lance", "spectre"],
			["every_hit", "saved_up", "on_dodge", "lance", "nova"],
			["twice", "wider", "saved_up", "on_dodge", "orbit"],
			["twice", "wider", "saved_up", "on_dodge", "chain"],
			["twice", "wider", "saved_up", "on_dodge", "overflow"],
			["twice", "every_hit", "saved_up", "on_dodge", "overflow"],
			["twice", "wider", "saved_up", "on_dodge", "lance"],
			["twice", "wider", "saved_up", "on_dodge", "nova"],
			["twice", "wider", "saved_up", "on_dodge", "spectre"],
			["wider", "saved_up", "on_dodge", "orbit", "nova"],
			["wider", "saved_up", "on_dodge", "overflow", "spectre"],
		])
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


## The way out: a BACK button at the top left. It, the screen's name and "Player 2"
## share one row above the tray and must not touch; a click on it leaves.
func _check_back(forge) -> void:
	var was_keys = forge.keys
	for keys in [SwingBuild.ABILITY_KEYS["kbm"], SwingBuild.ABILITY_KEYS["pad"]]:
		forge.keys = keys
		for whose in ["", "Player 2", "Player 4"]:
			forge.whose = whose
			forge.root.queue_redraw()
			await process_frame
			var what := "BACK button (%s%s)" % ["controller" if forge._on_pad() else "keyboard", ", " + whose if whose != "" else ""]
			if not forge.buttons.has("back"):
				_fail("%s: not drawn" % what)
				continue
			var r: Rect2 = forge.buttons["back"]
			if forge._head_width(forge.back_label()) > r.size.x - 8.0:
				_fail("%s: its words don't fit it" % what)
			if r.end.y > forge.TRAY.position.y or r.position.x < 0.0 or r.position.y < 0.0:
				_fail("%s: it leaves its row %s" % [what, r])
			for k in forge.buttons:
				if k != "back" and r.intersects(forge.buttons[k]):
					_fail("%s: it covers the button %s" % [what, k])
			var title_x: float = forge.title_at().x
			var row_end: float = title_x + forge._head_width("The forge", 16)
			if title_x < r.end.x + 4.0:
				_fail("%s: the screen's name touches it" % what)
			if whose != "":
				if forge.whose_at().x < row_end + 4.0:
					_fail("%s: '%s' touches the screen's name" % [what, whose])
				row_end = forge.whose_at().x + forge._head_width(whose)
			if row_end > forge.TRAY.end.x:
				_fail("%s: the row runs past the tray (%d px, the tray ends at %d)" % [what, row_end, forge.TRAY.end.x])
	forge.keys = was_keys
	forge.whose = ""
	# A click with nothing changed leaves at once; after a change the "forged"
	# finish plays first, as it does for Esc and Tab.
	forge.dirty = false
	forge._click("back")
	if forge.is_open or paused:
		_fail("a click on BACK did not leave the forge")
	forge.open()
	forge.dirty = true
	forge._click("back")
	if not forge.is_open or forge.finishing < 0.0:
		_fail("BACK after a change should play the forged finish first")
	forge._really_close()
	if forge.is_open or paused:
		_fail("the forge did not close after the finish")
	forge.open()
	forge.root.queue_redraw()
	await process_frame
	print("back button: fits its row, and a click leaves")


## The bow on the anvil (14 November): every part has its pictures and a sentence
## that fits, the four rows of the BOW tab stay inside the tray, every number fits
## its column whatever is pointed at, and each tab draws.
func _check_bow(forge, main) -> void:
	var Forge := preload("res://scripts/ui/swing_forge.gd")
	main.swap_weapon(0)
	if forge.build.weapon() != "bow":
		_fail("swapping in the arena did not put a bow on the anvil")
		return
	var parts: Array = []
	for table in [SwingBuild.LIMBS, SwingBuild.BOW_GRIPS, SwingBuild.STRINGS, SwingBuild.ARROWS]:
		parts.append_array(table.keys())
	for id in parts:
		if forge.info_lines(id).size() > 3:
			_fail("%s: its sentence takes %d lines on the info plate (3 fit)" % [id, forge.info_lines(id).size()])
	for id in SwingBuild.LIMBS:
		for what in ["hand", "forge_upper", "forge_lower", "icon"]:
			if not FileAccess.file_exists("res://art/swing/bow/limbs/%s_%s.png" % [id, what]):
				_fail("%s has no %s picture" % [id, what])
	for id in SwingBuild.BOW_GRIPS:
		for what in ["hand", "forge", "icon"]:
			if not FileAccess.file_exists("res://art/swing/bow/grips/%s_%s.png" % [id, what]):
				_fail("%s has no %s picture" % [id, what])
	for id in SwingBuild.ARROWS:
		for what in ["fly", "stuck", "forge", "icon"]:
			if not FileAccess.file_exists("res://art/swing/bow/arrows/%s_%s.png" % [id, what]):
				_fail("%s has no %s picture" % [id, what])
	for id in SwingBuild.STRINGS:
		if not FileAccess.file_exists("res://art/swing/bow/strings/%s_icon.png" % id):
			_fail("%s has no icon" % id)
	# Every tab draws with the tallest and the smallest bow; the BOW tab's cards
	# stay inside the tray and don't touch each other.
	for bow in [["iron_longbow", "horn_bow_grip"], ["wooden_shortbow", "wooden_bow_grip"], ["iron_shortbow", "wrapped_bow_grip"]]:
		forge.build.set_blade(bow[0])
		forge.build.set_grip(bow[1])
		for t in forge.TABS.size():
			forge._set_tab(t)
			forge.root.queue_redraw()
			await process_frame
			await process_frame
		for i in forge.build.line.size():
			var slot: Rect2 = forge._slot_screen(i)
			if slot.position.y < 0.0 or slot.end.y > 360.0 or slot.position.x < forge.TRAY.end.x or slot.end.x > forge.DOES.position.x:
				_fail("%s on a %s: slot %d is off the anvil's space %s" % [bow[0], bow[1], i, slot])
	forge._set_tab(0)
	var was_owned = forge.owned
	for owned in [null, parts]:      # the arena's tray, and the fullest a cave could ever show
		forge.owned = owned
		forge.root.queue_redraw()
		await process_frame
		await process_frame
		var rects: Array = []
		for k in forge.buttons:
			if str(k).begins_with("card:"):
				rects.append(forge.buttons[k])
		if rects.size() != forge._cards().size() or rects.is_empty():
			_fail("the BOW tab drew %d cards for %d parts" % [rects.size(), forge._cards().size()])
		for a in rects.size():
			if not forge.TRAY.grow(-4).encloses(rects[a]):
				_fail("a BOW tab card leaves the tray: %s" % rects[a])
			for b in a:
				if (rects[a] as Rect2).intersects(rects[b]):
					_fail("two BOW tab cards overlap: %s %s" % [rects[a], rects[b]])
	forge.owned = was_owned
	# Bands with no rune to boost: "what it does" says so for each, and still fits.
	forge.build.set_blade("iron_longbow")
	forge.build.set_grip("horn_bow_grip")
	forge.build.line = ["twice", "wider", "every_hit", "saved_up", "on_dodge"]
	forge._set_tab(2)
	forge.root.queue_redraw()
	await process_frame
	await process_frame
	if not forge.does_fits:
		_fail("what it does runs off its plate for a bow with five bands")
	# The fullest bows (five slots on the longbow with the horn grip, four on the
	# shortbow with the wrapped one), with keyboard and with controller button names.
	var full := [
		["volley", "snipe", "arrow_rain", "ricochet", "pierce"],
		["volley", "snipe", "arrow_rain", "steady_aim", "pierce"],
		["on_dodge", "snipe", "every_hit", "arrow_rain", "volley"],
		["saved_up", "arrow_rain", "on_dodge", "volley", "steady_aim"],
		["twice", "arrow_rain", "every_hit", "snipe", "ricochet"],
		["on_dodge", "wider", "steady_aim", "every_hit", "pierce"],
		["saved_up", "steady_aim", "on_dodge", "pierce", "ricochet"],
		["every_hit", "ricochet", "on_dodge", "ricochet", "pierce"],
		["wider", "on_dodge", "snipe", "every_hit", "volley"],
		["on_dodge", "arrow_rain", "on_dodge", "snipe", "volley"],
		["every_hit", "saved_up", "on_dodge", "arrow_rain", "snipe"],
	]
	var was_keys = forge.keys
	var bows := 0
	for keys in [SwingBuild.ABILITY_KEYS["kbm"], SwingBuild.ABILITY_KEYS["pad"]]:
		forge.keys = keys
		for kit in [["iron_longbow", "horn_bow_grip", 5], ["iron_shortbow", "wrapped_bow_grip", 4], ["iron_shortbow", "wooden_bow_grip", 3]]:
			forge.build.set_blade(kit[0])
			forge.build.set_grip(kit[1])
			for l in full:
				forge.build.line = l.slice(0, kit[2])
				forge.root.queue_redraw()
				await process_frame
				await process_frame
				bows += 1
				if not forge.does_fits:
					_fail("what it does runs off its plate: %s %s" % [kit, forge.build.line])
	forge.keys = was_keys
	print("what it does fits: ", bows, " bows")
	# The bow's tray of runes: its own six and the bands, and none of the sword's.
	forge._set_tab(1)
	var tray: Array = []
	for c in forge._cards():
		tray.append(str(c.get("id", "")))
	if tray != ["pierce", "ricochet", "steady_aim", "volley", "snipe", "arrow_rain"]:
		_fail("the bow's rune tray should offer its six runes: %s" % [tray])
	forge.build.set_blade("iron_longbow")
	forge.build.set_grip("horn_bow_grip")
	forge.build.line = ["", "", "", "", ""]
	# Every bow, pointing at every part: each number and its change fit the column.
	var widest := -999.0
	var tight := ""
	var pairs := 0
	for limbs in SwingBuild.LIMBS:
		for grip in SwingBuild.BOW_GRIPS:
			for string in SwingBuild.STRINGS:
				for arrows in SwingBuild.ARROWS:
					forge.build.set_data([limbs, grip, string, [], arrows])
					forge.build._refit(forge.build.grip_slots())
					var stats: Dictionary = forge.build.compute()
					var now: Dictionary = Forge.stat_values(stats)
					for id in parts:
						var then: Dictionary = Forge.stat_values(forge.stats_with(id))
						pairs += 1
						for row in Forge.stat_rows(stats):
							var key: String = row[0]
							var w: float = forge.stat_width(Forge.stat_text(key, now[key]), Forge.delta_text(key, float(then[key]) - float(now[key])))
							var room: float = Forge.STAT_COL - 3.0
							if key == "shoot_move" or int(row[1]) == 1:
								room = Forge.STATS.size.x - Forge.stat_at(row).x - 6.0
							if w - room > widest:
								widest = w - room
								tight = "%s on a %s %s %s %s, pointing at %s (%d of %d px)" % [key, limbs, grip, string, arrows, id, w, room]
							if w > room:
								_fail("%s on a %s %s %s %s, pointing at %s: %d px wide, %d fit" % [key, limbs, grip, string, arrows, id, w, room])
								return
	print("bow numbers fit: %d comparisons, the tightest is %s" % [pairs, tight])
	forge.build.set_data(SwingBuild.TEST_BOW)
	forge.build.changed.emit()
	main.swap_weapon(0, "sword")
	if forge.build.weapon() != "sword":
		_fail("swapping back did not return the sword to the anvil")
	print("bow at the forge: parts, pictures, tabs and numbers")


## The hammer or the staff on the anvil (15 November), checked as the bow is: every
## part has its pictures and a sentence that fits, the rows of the first tab stay
## inside the tray, the slots stay on the anvil, each tab draws, and every number
## fits its column whatever is pointed at. `kits` are [head, grip] pairs to draw.
## `runes`: what its rune tray must offer.  `full`: the fullest lines of runes and
## bands to read out in "what it does" (cut to the slots each kit has).
func _check_other(forge, main, weapon: String, kits: Array, runes: Array = [], full: Array = []) -> void:
	var Forge := preload("res://scripts/ui/swing_forge.gd")
	main.swap_weapon(0, weapon)
	if forge.build.weapon() != weapon:
		_fail("swapping in the arena did not put a %s on the anvil" % weapon)
		return
	var rows: Array = Forge.PART_ROWS[weapon]
	var parts: Array = []
	for row in rows:
		for id in row[3]:
			parts.append(id)
			if forge.info_lines(id).size() > 3:
				_fail("%s: its sentence takes %d lines on the info plate (3 fit)" % [id, forge.info_lines(id).size()])
			if forge.info_lines(id).is_empty() or str(forge._name(id)) == "":
				_fail("%s has no name or no sentence" % id)
			for what in ["hand", "forge", "icon"]:
				if not FileAccess.file_exists("res://art/swing/%s/%s_%s.png" % [Forge.ICON_DIRS[row[1]], id, what]):
					_fail("%s has no %s picture" % [id, what])
		for id in row[2]:
			if not row[3].has(id):
				_fail("%s is offered in the arena but is not in the full list" % id)
	if forge.TABS[0] != "sword" or forge._tab_label(0).to_lower() != weapon:
		_fail("the first tab should be named after the %s: %s" % [weapon, forge._tab_label(0)])
	# Every tab draws with the tallest and the smallest; the slots stay on the anvil.
	for kit in kits:
		forge.build.set_blade(kit[0])
		forge.build.set_grip(kit[1])
		for t in forge.TABS.size():
			forge._set_tab(t)
			forge.root.queue_redraw()
			await process_frame
			await process_frame
		for i in forge.build.line.size():
			var slot: Rect2 = forge._slot_screen(i)
			if slot.position.y < 0.0 or slot.end.y > 360.0 or slot.position.x < forge.TRAY.end.x or slot.end.x > forge.DOES.position.x:
				_fail("%s on a %s: slot %d is off the anvil's space %s" % [kit[0], kit[1], i, slot])
	# The first tab's cards stay inside the tray and don't touch each other.
	forge._set_tab(0)
	var was_owned = forge.owned
	for owned in [null, parts]:      # the arena's tray, and the fullest a cave could ever show
		forge.owned = owned
		forge.root.queue_redraw()
		await process_frame
		await process_frame
		var rects: Array = []
		for k in forge.buttons:
			if str(k).begins_with("card:"):
				rects.append(forge.buttons[k])
		var want := 0
		for row in rows:
			want += (row[2] if owned == null else row[3]).size()
		if rects.size() != forge._cards().size() or rects.size() != want:
			_fail("the %s tab drew %d cards for %d parts" % [weapon, rects.size(), want])
		for a in rects.size():
			if not forge.TRAY.grow(-4).encloses(rects[a]):
				_fail("a %s tab card leaves the tray: %s" % [weapon, rects[a]])
			for b in a:
				if (rects[a] as Rect2).intersects(rects[b]):
					_fail("two %s tab cards overlap: %s %s" % [weapon, rects[a], rects[b]])
	forge.owned = was_owned
	# Bands with no rune to boost: "what it does" says so for each, and still fits.
	forge.build.set_blade(kits[0][0])
	forge.build.set_grip(kits[0][1])
	forge.build.line = ["twice", "wider", "every_hit", "saved_up", "on_dodge"].slice(0, forge.build.slot_count())
	forge._set_tab(2)
	forge.root.queue_redraw()
	await process_frame
	await process_frame
	if not forge.does_fits:
		_fail("what it does runs off its plate for a %s full of bands" % weapon)
	# Its fullest lines of runes, with keyboard and with controller button names.
	var was_keys = forge.keys
	var read := 0
	for keys in [SwingBuild.ABILITY_KEYS["kbm"], SwingBuild.ABILITY_KEYS["pad"]]:
		forge.keys = keys
		for kit in (kits if not full.is_empty() else []):
			forge.build.set_blade(kit[0])
			forge.build.set_grip(kit[1])
			for l in full:
				forge.build.line = l.slice(0, forge.build.slot_count())
				forge.root.queue_redraw()
				await process_frame
				await process_frame
				read += 1
				if not forge.does_fits:
					_fail("what it does runs off its plate: %s %s" % [kit, forge.build.line])
	forge.keys = was_keys
	if read > 0:
		print("what it does fits: ", read, " ", weapon, "s")
	# Its tray of runes: its own and none of another weapon's.
	forge._set_tab(1)
	var offered: Array = []
	for c in forge._cards():
		offered.append(str(c.get("id", "")))
	if offered != runes:
		_fail("the %s's rune tray should offer %s: %s" % [weapon, runes, offered])
	for id in runes:
		if forge.info_lines(id).size() > 3:
			_fail("%s: its sentence takes %d lines on the info plate (3 fit)" % [id, forge.info_lines(id).size()])
	forge.build.set_blade(kits[0][0])
	forge.build.set_grip(kits[0][1])
	forge.build.line = ["", "", "", "", ""].slice(0, forge.build.slot_count())
	# Every one of them, pointing at every part: each number and its change fit the column.
	var tables: Array = []
	for row in rows:
		tables.append(row[3])
	while tables.size() < 4:
		tables.append([""])
	var widest := -999.0
	var tight := ""
	var pairs := 0
	for head in tables[0]:
		for grip in tables[1]:
			for butt in tables[2]:
				for shot in tables[3]:
					var data: Array = [head, grip, butt, []]
					if shot != "":
						data.append(shot)
					forge.build.set_data(data)
					forge.build._refit(forge.build.grip_slots())
					var stats: Dictionary = forge.build.compute()
					var now: Dictionary = Forge.stat_values(stats)
					var table: Array = Forge.stat_rows(stats)
					for id in parts:
						var then: Dictionary = Forge.stat_values(forge.stats_with(id))
						pairs += 1
						for row in table:
							var key: String = row[0]
							if not now.has(key) or Forge.stat_text(key, now[key]) == "":
								_fail("the %s's stats plate has no words for %s" % [weapon, key])
								return
							var w: float = forge.stat_width(Forge.stat_text(key, now[key]), Forge.delta_text(key, float(then[key]) - float(now[key])))
							var room: float = Forge.STAT_COL - 3.0
							if key in ["move", "cast_move"] or int(row[1]) == 1:
								room = Forge.STATS.size.x - Forge.stat_at(row, table).x - 6.0
							if w - room > widest:
								widest = w - room
								tight = "%s on a %s %s %s %s, pointing at %s (%d of %d px)" % [key, head, grip, butt, shot, id, w, room]
							if w > room:
								_fail("%s on a %s %s %s %s, pointing at %s: %d px wide, %d fit" % [key, head, grip, butt, shot, id, w, room])
								return
	# The last row of numbers stays on the plate.
	var last: Array = Forge.stat_rows(forge.build.compute())[-1]
	if Forge.stat_at(last, Forge.stat_rows(forge.build.compute())).y > Forge.STATS.size.y - 4.0:
		_fail("the %s's last row of numbers hangs off the stats plate" % weapon)
	print("%s numbers fit: %d comparisons, the tightest is %s" % [weapon, pairs, tight])
	# Fitting from the tray: the first card of each row goes onto the anvil.
	forge.build.set_data(SwingBuild.TEST_HAMMER if weapon == "hammer" else SwingBuild.TEST_STAFF)
	forge.build.changed.emit()
	forge._set_tab(0)
	var cards: Array = forge._cards()
	for i in cards.size():
		forge._use_card(i)
		if not forge._on_sword(cards[i]["id"]):
			_fail("clicking %s in the tray did not fit it" % cards[i]["id"])
	forge.build.set_data(SwingBuild.TEST_HAMMER if weapon == "hammer" else SwingBuild.TEST_STAFF)
	forge.build.changed.emit()
	main.swap_weapon(0, "sword")
	if forge.build.weapon() != "sword":
		_fail("swapping back did not return the sword to the anvil")
	print("%s at the forge: parts, pictures, tabs and numbers" % weapon)


func _fits_help(forge, text: String) -> void:
	var w: float = preload("res://scripts/art.gd").font("PixelifySans-Regular").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	if w > forge.HELP.size.x - 14.0:
		_fail("help line too wide (%d px): %s" % [w, text])
