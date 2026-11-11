extends CanvasLayer
## The forge for the swing path. Drawn at the 640x360 base size.
## Left: the parts tray (blades, grips and pommels; runes in a passive and an
## active group; bands; rule-benders), then a plate with the name and one plain
## sentence for the part under the cursor, then how to use the screen.
## Centre: the sword upright over the anvil. Its sockets are the menu.
## Right: the three loadout presets (A, B and C: whole saved swords, one click to
## switch), what the sword does, a line per rune, and the sword's numbers on a
## plate of their own. Pointing at a part you could fit shows what it would
## change beside each number.
## Nothing on this screen may overlap (Game Bible, 11 November): every kind of
## words has its own plate, and the words are made to fit it.
## Free to swap. Pauses the game while open.

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const SwordArt := preload("res://scripts/weapon/sword_art.gd")
const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")

signal try_at_dummy
signal closed

## Which parts show in the tray. null = everything (the test arena). In the cave
## it's the list of part ids this player owns.
var owned = null
var hotkey := true         # Tab / Y opens it anywhere (the test arena)
var sandbox := true        # test swords (1, 2, 3, 4) and "try at the dummy" (T)
var keys: Array = SwingBuild.ABILITY_KEYS["kbm"]   # what this player's ability buttons are called
var whose := ""            # "Player 2" when two players share the forge
var pauses := true         # false online: the game can't stop for one player's forge

const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const FAINT := Color("#5f8072")
const AMBER := Color("#ffc850")
const TEAL := Color("#86d4a4")
const FOCUS := Color("#fff0b4")
const PLATE := Color("#19142a")
const WELL := Color("#0f0b18")

const TABS := ["sword", "runes", "bands", "rare"]
const TRAY := Rect2(6, 30, 203, 188)        # tabs and part cards
const INFO := Rect2(6, 221, 203, 88)        # the part under the cursor: its name and one sentence
const HELP := Rect2(6, 312, 203, 42)        # how to use the screen
const PRESETS := Rect2(396, 8, 238, 23)     # loadout presets A, B and C, and the chosen one's name
const DOES := Rect2(396, 34, 238, 234)      # what the sword does, a line per rune
const STATS := Rect2(396, 271, 238, 83)     # the sword's numbers
const STAT_COL := 116.0                     # the width of a column of numbers
const PREVIEW := Rect2(211, 92, 184, 150)   # the picture shown while Alt is held (fits between the plates)
const GAIN := Color("#86d4a4")              # compare: this number would go up
const LOSS := Color("#ff6a4a")              # compare: it would go down
const SWORD_TOP := 4.0
const SWORD_SLACK := 7.0     # what a sword too tall for that may borrow (4 above, 3 below)
const CENTRE_X := 300.0
const SWORD_BOTTOM := 326.0  # the pommel sits just above the anvil
var sword_bottom := SWORD_BOTTOM

var build: SwingBuild
var root: Control
var is_open := false
var selected := 0          # slot index, 0 = bottom of the grip
var tab := 1               # runes
var card := 0              # keyboard cursor in the tray
var hover := ""
var keys_on_cards := false # the tray cursor was last moved with keys or a pad, not the mouse
var buttons := {}          # key -> Rect2, rebuilt every draw
var renaming := false      # typing a name for the chosen preset
var rename_text := ""
var _rename_guard := 0     # frames to ignore keys after typing ends (Enter and Esc mean other things too)
var note := ""             # a line the help plate shows for a few seconds
var note_until := -9.0
var _styles := {}

# Forge feel: heat, embers, sparks, the hammer strike and the finish.
var t := 0.0
var heat := 0.3            # 0..1, jumps to 1 on a hammer strike, cools back down
var strike_t := 9.0        # time since the last hammer strike
var strike_at := Vector2.ZERO
var embers: Array = []     # [pos, vel, life, max_life]
var sparks: Array = []
var steam: Array = []
var dirty := false         # changed since the forge opened
var finishing := -1.0      # >= 0 while the "forged" finish plays
const FINISH_TIME := 1.75
var playing: Array = []   # forge fx strips: [name, pos, start time, normal-blend?]
var sword_top := Vector2.ZERO
var zoom := 2.0
var drag_id := ""          # the fitting being dragged ("" = none)
var drag_from := -1        # the slot it came from, or -1 from the tray
var drag_key := ""         # the button the press started on
var drag_start := Vector2.ZERO
var dragging := false      # true once the mouse has moved far enough            # the sword is drawn this many times its forge size
var sword_size := Vector2.ZERO
var heat_mask: Control     # draws the sword; its child is clipped to the sword's pixels
var heat_fill: Control
var fx_top: Control
var banner: Control
var preview: Control


func _ready() -> void:
	layer = 10
	add_to_group("covers_version")   # its plates fill the corner the version number sits in
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.size = Vector2(640, 360)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)
	root.draw.connect(_draw_forge)
	# Heat on the sword itself: a mask that draws the sword, with an additive
	# fill clipped to it (glowing metal, the shine sweep when it's done).
	heat_mask = Control.new()
	heat_mask.size = root.size
	heat_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	heat_mask.draw.connect(_draw_heat_mask)
	root.add_child(heat_mask)
	heat_fill = Control.new()
	heat_fill.size = root.size
	heat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_fill.material = _additive()
	heat_fill.draw.connect(_draw_heat_fill)
	heat_mask.add_child(heat_fill)
	# Embers, sparks and flashes on top, glowing.
	fx_top = Control.new()
	fx_top.size = root.size
	fx_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_top.material = _additive()
	fx_top.draw.connect(_draw_fx)
	root.add_child(fx_top)
	banner = Control.new()
	banner.size = root.size
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.draw.connect(_draw_banner)
	root.add_child(banner)
	# The "hold Alt" picture goes over everything.
	preview = Control.new()
	preview.size = root.size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.draw.connect(_draw_preview)
	root.add_child(preview)


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func setup(b: SwingBuild) -> void:
	set_build(b)


## Whose sword is on the anvil.
func set_build(b: SwingBuild) -> void:
	if build != null and build.changed.is_connected(_on_changed):
		build.changed.disconnect(_on_changed)
	build = b
	build.changed.connect(_on_changed)
	selected = clampi(selected, 0, build.slot_count() - 1)


## Every change is a hammer blow: the metal heats up, sparks fly, the anvil rings.
func _on_changed() -> void:
	if not is_open:
		return
	dirty = true
	heat = 1.0
	strike_t = 0.0
	var i := clampi(selected, 0, build.slot_count() - 1)
	strike_at = sword_top + SwordArt.slot_center(build.blade, build.grip, "forge", i) * zoom
	if sword_size == Vector2.ZERO:
		strike_at = Vector2(CENTRE_X, 150)
	playing.append(["sparks", strike_at, t])
	playing.append(["hammer_strike", Vector2(CENTRE_X, sword_bottom + 4), t])
	for n in 12:
		var a := randf_range(-PI, 0.0)
		sparks.append([strike_at, Vector2(cos(a), sin(a)) * randf_range(40.0, 150.0), 0.0, randf_range(0.3, 0.7)])
	Sfx.play(self, "anvil", -6.0, randf_range(0.95, 1.08))


func open() -> void:
	dirty = false
	finishing = -1.0
	heat = 0.3
	is_open = true
	root.visible = true
	selected = clampi(selected, 0, build.slot_count() - 1)
	opened_at = t
	_stat_last.clear()
	_stat_lit.clear()
	if owned != null:
		# In the cave start on the tab that has something new to fit.
		tab = 1 if _has_unfitted_rune() else 0
		card = 0
	if pauses:
		get_tree().paused = true


var opened_at := -9.0
var _stat_last := {}       # stat name -> the value last shown
var _stat_lit := {}        # stat name -> when it last changed (its icon lights for a moment)


func _has_unfitted_rune() -> bool:
	if owned == null:
		return false
	for id in owned:
		if SwingBuild.FITTINGS.has(id) and not (id in build.line):
			return true
	return false


## Leaving after changes plays the "forged" finish first (press again to skip).
func close() -> void:
	if dirty and finishing < 0.0:
		finishing = 0.0
		Sfx.play(self, "forged", -4.0)
		playing.append(["hammer_strike", Vector2(CENTRE_X, sword_bottom + 4), t])
		return
	_really_close()


func _really_close() -> void:
	finishing = -1.0
	dirty = false
	is_open = false
	renaming = false
	root.visible = false
	if pauses:
		get_tree().paused = false
	drag_id = ""
	dragging = false
	closed.emit()


# --- Input ------------------------------------------------------------------

func _process(delta: float) -> void:
	if is_open:
		_update_fx(delta)
	if renaming or _rename_guard > 0:
		# The keyboard is writing a preset's name: its keys do nothing else.
		_rename_guard = maxi(_rename_guard - 1, 0)
		return
	if Input.is_action_just_pressed("build") and (hotkey or is_open) and t - opened_at > 0.2:
		if finishing >= 0.0:
			_really_close()
		elif is_open:
			close()
		else:
			open()
		return
	if not is_open:
		return
	if finishing >= 0.0:
		finishing += delta
		if finishing >= FINISH_TIME:
			_really_close()
			if _try_after:
				_try_after = false
				try_at_dummy.emit()
		return
	if Input.is_action_just_pressed("menu_back"):
		close()
		return
	if Input.is_action_just_pressed("move_up"):
		selected = mini(selected + 1, build.slot_count() - 1)
	if Input.is_action_just_pressed("move_down"):
		selected = maxi(selected - 1, 0)
	if Input.is_action_just_pressed("menu_next"):
		_set_tab(tab + 1)
	if Input.is_action_just_pressed("menu_prev"):
		_set_tab(tab - 1)
	if Input.is_action_just_pressed("move_right"):
		card = mini(card + 1, _cards().size() - 1)
		keys_on_cards = true
	if Input.is_action_just_pressed("move_left"):
		card = maxi(card - 1, 0)
		keys_on_cards = true
	if Input.is_action_just_pressed("menu_place"):
		_use_card(card)
	if Input.is_action_just_pressed("menu_rotate"):
		_put("")
	if Input.is_action_just_pressed("menu_preset"):
		_use_preset((build.preset + 1) % build.preset_data.size())
	root.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if finishing >= 0.0:
		if event is InputEventMouseButton and event.pressed:
			_really_close()
			get_viewport().set_input_as_handled()
		return
	if renaming:
		if event is InputEventKey:
			if event.pressed:
				_rename_key(event as InputEventKey)
			get_viewport().set_input_as_handled()
			root.queue_redraw()
			return
		if event is InputEventMouseButton and event.pressed:
			_end_rename(true)   # a click anywhere keeps the name, and still does what it would have
	if event is InputEventKey and event.pressed and not event.echo:
		if sandbox:
			match (event as InputEventKey).physical_keycode:
				KEY_1: _load_test("A")
				KEY_2: _load_test("B")
				KEY_3: _load_test("C")
				KEY_4: _load_test("D")
				KEY_T: _try()
	if event is InputEventMouseMotion:
		var m := root.get_local_mouse_position()
		hover = _button_at(m)
		keys_on_cards = false
		if drag_id != "" and not dragging and m.distance_to(drag_start) > 4.0:
			dragging = true
		root.queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()
		get_viewport().set_input_as_handled()
		root.queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		var key := _button_at(root.get_local_mouse_position())
		if mb.button_index == MOUSE_BUTTON_LEFT and _drag_source(key) != "":
			# Runes and bands can be dragged from the tray, or from one slot to another.
			# A press without a drag still acts as a click when the button comes up.
			drag_id = _drag_source(key)
			drag_from = int(key.split(":")[1]) if key.begins_with("slot:") else -1
			drag_key = key
			drag_start = root.get_local_mouse_position()
			dragging = false
		elif mb.button_index == MOUSE_BUTTON_LEFT and key != "":
			_click(key)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and key.begins_with("slot:"):
			selected = int(key.split(":")[1])
			_put("")
		get_viewport().set_input_as_handled()
		root.queue_redraw()


## What a press on this button would pick up: a fitting from the tray or a slot, or "".
func _drag_source(key: String) -> String:
	if key.begins_with("card:") and TABS[tab] != "sword":
		var cards := _cards()
		var i := int(key.split(":")[1])
		if i < cards.size() and not cards[i]["locked"]:
			return cards[i]["id"]
	if key.begins_with("slot:"):
		var i := int(key.split(":")[1])
		if i < build.line.size():
			return build.line[i]
	return ""


func _end_drag() -> void:
	_drop(_button_at(root.get_local_mouse_position()))


## Let go of a dragged part over the button `over` ("" = nowhere).
func _drop(over: String) -> void:
	if drag_id == "":
		return
	var id := drag_id
	var key := drag_key
	var was_drag := dragging
	drag_id = ""
	dragging = false
	if not was_drag:
		_click(key)
		return
	if over.begins_with("slot:"):
		var to := int(over.split(":")[1])
		if drag_from >= 0:
			# Slot to slot: swap the two.
			var other: String = build.line[to] if to < build.line.size() else ""
			build.line[drag_from] = other
			selected = to
			_put(id)
		else:
			selected = to
			_put(id)
	elif drag_from >= 0:
		# Dragged off the sword: take it off.
		selected = drag_from
		_put("")
	Sfx.play(self, "click", -14.0)


func _click(key: String) -> void:
	var p := key.split(":")
	match p[0]:
		"slot":
			selected = int(p[1])
		"tab":
			_set_tab(int(p[1]))
		"card":
			card = int(p[1])
			_use_card(card)
		"use":
			_use_card(card)
		"test":
			_load_test(p[1])
		"preset":
			_use_preset(int(p[1]))
		"rename":
			renaming = true
			rename_text = str(build.preset_names[build.preset])
		"try":
			_try()
			return
	Sfx.play(self, "click", -14.0)


## Switches to loadout preset i: the whole sword changes in one click.
func _use_preset(i: int) -> void:
	if i == build.preset:
		return
	var missing: Array = build.use_preset(i, owned)
	selected = clampi(selected, 0, build.slot_count() - 1)
	if not missing.is_empty():
		var names: Array = []
		for id in missing:
			names.append(_name(id))
		note = "Left off, you don't own it: " + ", ".join(names) + "."
		note_until = t + 6.0


## A key while a preset's name is being typed.
func _rename_key(k: InputEventKey) -> void:
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_end_rename(true)
		KEY_ESCAPE:
			_end_rename(false)
		KEY_BACKSPACE:
			rename_text = rename_text.left(-1) if rename_text != "" else ""
		_:
			var c := char(k.unicode) if k.unicode > 0 else ""
			if c != "" and c.to_upper() in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -'&!" and rename_text.length() < SwingBuild.PRESET_NAME_MAX:
				rename_text += c


func _end_rename(keep: bool) -> void:
	if not renaming:
		return
	renaming = false
	_rename_guard = 2
	if keep:
		build.preset_names[build.preset] = rename_text.strip_edges()


func _set_tab(t: int) -> void:
	tab = posmod(t, TABS.size())
	card = 0


## Every part id, in tray order (the cave shows the owned ones from this list).
const ALL_BLADES := ["wooden_blade", "tin_blade", "iron_dagger", "iron_sabre", "iron_broadsword", "iron_rapier", "iron_falchion", "iron_greatsword"]
const ALL_GRIPS := ["wooden_grip", "tin_grip", "wrapped_grip", "long_grip", "ringed_grip", "gilded_grip"]


func _has(id: String) -> bool:
	return owned == null or id in owned


## The cards on the current tab: [{id, name, locked}]
func _cards() -> Array:
	var out: Array = []
	match TABS[tab]:
		"sword":  # three rows: blades, grips, pommels
			for id in (SwingBuild.BLADE_ORDER if owned == null else ALL_BLADES):
				if _has(id):
					out.append({"id": id, "name": SwingBuild.BLADES[id]["name"], "locked": false, "row": 0, "kind": "blades"})
			for id in (SwingBuild.GRIP_ORDER if owned == null else ALL_GRIPS):
				if _has(id):
					out.append({"id": id, "name": SwingBuild.GRIPS[id]["name"], "locked": SwingBuild.GRIPS[id].get("locked", false), "row": 1, "kind": "grips"})
			for id in SwingBuild.POMMEL_ORDER:
				if _has(id):
					out.append({"id": id, "name": SwingBuild.POMMELS[id]["name"], "locked": false, "row": 2, "kind": "pommels"})
		"runes":
			for id in SwingBuild.FITTING_ORDER:
				if SwingBuild.FITTINGS[id]["kind"] == "rune" and not SwingBuild.FITTINGS[id].get("parked", false) and _has(id):
					out.append({"id": id, "name": SwingBuild.FITTINGS[id]["name"], "locked": false,
						"group": "active" if SwingBuild.FITTINGS[id]["trigger"] == "active" else "passive"})
		"bands":
			for id in SwingBuild.FITTING_ORDER:
				if SwingBuild.FITTINGS[id]["kind"] == "band" and _has(id):
					out.append({"id": id, "name": SwingBuild.FITTINGS[id]["name"], "locked": false})
		"rare":
			for id in SwingBuild.FITTING_ORDER:
				if SwingBuild.FITTINGS[id]["kind"] == "bender" and not SwingBuild.FITTINGS[id].get("parked", false) and _has(id):
					out.append({"id": id, "name": SwingBuild.FITTINGS[id]["name"], "locked": false})
	return out


func _use_card(i: int) -> void:
	var cards := _cards()
	if i < 0 or i >= cards.size() or cards[i]["locked"]:
		return
	var id: String = cards[i]["id"]
	if SwingBuild.BLADES.has(id):
		build.set_blade(id)
	elif SwingBuild.GRIPS.has(id):
		build.set_grip(id)
	elif SwingBuild.POMMELS.has(id):
		build.set_pommel(id)
	else:
		_put(id)
	selected = clampi(selected, 0, build.slot_count() - 1)


func _put(id: String) -> void:
	# One rule-bender per sword: fitting a new one takes the old one off.
	if id != "" and SwingBuild.FITTINGS[id]["kind"] == "bender":
		for i in build.line.size():
			if i != selected and build.line[i] != "" and SwingBuild.FITTINGS[build.line[i]]["kind"] == "bender":
				build.line[i] = ""
	build.set_slot(selected, id)


func _load_test(k: String) -> void:
	build.load_test(k)
	selected = clampi(selected, 0, build.slot_count() - 1)


var _try_after := false

func _try() -> void:
	if dirty:
		_try_after = true
		close()
		return
	close()
	try_at_dummy.emit()


func _button_at(m: Vector2) -> String:
	for k in buttons:
		if (buttons[k] as Rect2).has_point(m):
			return k
	return ""


# --- Drawing helpers ----------------------------------------------------------

func _nine(name: String, r: Rect2, ci: CanvasItem = null) -> void:
	if ci == null:
		ci = root
	if not _styles.has(name):
		var tex := Art.texture("swing/ui/%s.png" % name)
		if tex == null:
			_styles[name] = null
		else:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			var m: Array = SwordArt.data().get("ui", {}).get(name + ".png", {}).get("nine_patch_margins", [4, 4, 4, 4])
			if name == "focus_corners":
				m = [4, 4, 4, 4]
			sb.texture_margin_left = m[0]
			sb.texture_margin_top = m[1]
			sb.texture_margin_right = m[2]
			sb.texture_margin_bottom = m[3]
			if name == "focus_corners":
				sb.draw_center = false
			_styles[name] = sb
	if _styles[name] == null:
		ci.draw_rect(r, PLATE)
		ci.draw_rect(r, FAINT, false, 1.0)
	else:
		ci.draw_style_box(_styles[name], r)


func _head(text: String, pos: Vector2, col := INK, size := 8, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	root.draw_string(Art.font("Silkscreen-Regular"), pos, text.to_upper(), align, width, size, col)


func _body(text: String, pos: Vector2, col := INK, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	root.draw_string(Art.font("PixelifySans-Regular"), pos, text, align, width, 11, col)


## Word-wraps body text to a width; returns the lines.
func _wrap(text: String, width: float) -> Array:
	var f := Art.font("PixelifySans-Regular")
	var lines: Array = []
	var cur := ""
	for w in text.split(" "):
		var tryline := w if cur == "" else cur + " " + w
		if f.get_string_size(tryline, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > width and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = tryline
	if cur != "":
		lines.append(cur)
	return lines


func _icon(kind: String, id: String, center: Vector2, part_scale := 2.0, tint := Color.WHITE) -> void:
	match kind:
		"runes", "bands", "rare":
			var tex := Art.texture("swing/%s/%s_icon.png" % [kind, id])
			if tex != null:
				root.draw_texture(tex, (center - tex.get_size() * 0.5).round(), tint)
			elif SwingBuild.FITTINGS.has(id):
				# No art yet: a plain stone (rune), ring (band) or gem (rule-bender) in its colour.
				var f: Dictionary = SwingBuild.FITTINGS[id]
				var c: Color = f["color"]
				match f["kind"]:
					"rune":
						root.draw_circle(center, 7.0, c.darkened(0.5))
						root.draw_circle(center, 5.0, c)
					"band":
						root.draw_rect(Rect2(center - Vector2(9, 3), Vector2(18, 6)), c.darkened(0.4))
						root.draw_rect(Rect2(center - Vector2(9, 1), Vector2(18, 2)), c)
					_:
						root.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(7, 0), center + Vector2(0, 8), center + Vector2(-7, 0)]), c)
		"pommels":
			var ptex := Art.texture("swing/pommels/%s_icon.png" % id)
			if ptex != null:
				root.draw_texture(ptex, (center - ptex.get_size() * 0.5).round(), tint)
				return
			# No art: a round knob in the pommel's colour.
			var pc: Color = SwingBuild.POMMELS[id]["color"]
			root.draw_circle(center, 8.0, pc.darkened(0.55))
			root.draw_circle(center, 6.5, pc)
			root.draw_circle(center + Vector2(-2, -2), 2.0, pc.lightened(0.5))
		"blades", "grips":
			# Its own picture for the tray, lying down with the tip to the right.
			var card_tex := Art.texture("swing/%s/%s_icon.png" % [kind, id])
			if card_tex != null:
				root.draw_texture(card_tex, (center - card_tex.get_size() * 0.5).round(), tint)
				return
			# No picture: the in-hand sprite at 2x, turned on its side.
			var tex := Art.texture("swing/%s/%s_hand.png" % [kind, id])
			if tex != null:
				root.draw_set_transform(center, PI * 0.5, Vector2(part_scale, part_scale))
				root.draw_texture(tex, (-tex.get_size() * 0.5).round())
				root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- The screen ---------------------------------------------------------------

func _draw_forge() -> void:
	buttons.clear()
	# A still backdrop (the forge's niche), then a plate behind every kind of words.
	var backdrop := Art.texture("swing/ui/forge_backdrop.png")
	if backdrop != null:
		root.draw_texture(backdrop, Vector2.ZERO)
	else:
		root.draw_rect(Rect2(Vector2.ZERO, root.size), WELL)
	_nine("panel", TRAY)
	_nine("panel_titled", INFO)
	_nine("well", HELP)
	_nine("well", PRESETS)
	_nine("panel", DOES)
	_nine("panel_titled", STATS)
	_head("The forge", Vector2(14, 24), AMBER, 16)
	if whose != "":
		_head(whose, Vector2(150, 24), INK, 8)
	var stats := build.compute()
	_draw_tray()
	_draw_sword(stats)
	_draw_presets()
	_draw_does(stats)
	_draw_info()
	_draw_stats(stats)
	_draw_help()
	if dragging:
		for i in build.line.size():
			var r := _slot_screen(i)
			var on := hover == "slot:%d" % i
			root.draw_rect(r.grow(5 if on else 3), FOCUS if on else Color(1, 1, 1, 0.35), false, 1.0)
		var f: Dictionary = SwingBuild.FITTINGS[drag_id]
		var kind := "runes" if f["kind"] == "rune" else ("bands" if f["kind"] == "band" else "rare")
		_icon(kind, drag_id, root.get_local_mouse_position())


## Left: tabs and icon-only cards.
func _draw_tray() -> void:
	var x := 14.0
	var f := Art.font("Silkscreen-Regular")
	for i in TABS.size():
		var w := f.get_string_size(str(TABS[i]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := Rect2(x - 5, 38, w + 10, 14)
		buttons["tab:%d" % i] = r
		# The chosen tab stands proud (its picture starts 2 px higher than the others').
		var drawn := Art.draw_nine(root, "swing/ui/tab_selected.png" if i == tab else "swing/ui/tab.png", r, 4)
		_head(TABS[i], Vector2(x, 48), INK if i == tab else (FOCUS if hover == "tab:%d" % i else DIM))
		if i == tab and not drawn:
			root.draw_rect(Rect2(x, 51, w, 1), AMBER)
		x += w + 13
	var cards := _cards()
	card = clampi(card, 0, maxi(cards.size() - 1, 0))
	if cards.is_empty():
		_body("Nothing here yet.", Vector2(14, 78), DIM)
	var rects := _place_cards(cards)
	for i in cards.size():
		var c: Dictionary = cards[i]
		var r: Rect2 = rects[i]
		buttons["card:%d" % i] = r
		_nine("well_selected" if i == card else "well", r)
		if hover == "card:%d" % i and i != card:
			root.draw_rect(r, FOCUS, false, 1.0)
		if c["locked"]:
			var lock := Art.texture("swing/ui/padlock.png")
			if lock != null:
				root.draw_texture(lock, (r.get_center() - lock.get_size() * 0.5).round())
			continue
		_icon(c.get("kind", TABS[tab]), c["id"], r.get_center())
		if c.get("group", "") == "active":
			_badge(r.get_center())
		if _on_sword(c["id"]):
			var fitted := Art.texture("swing/ui/fitted_mark.png")
			if fitted != null:
				root.draw_texture(fitted, Vector2(r.end.x - 7, r.position.y + 2))
			else:
				root.draw_rect(Rect2(r.end.x - 6, r.position.y + 2, 4, 4), AMBER)


## Where each card on the current tab goes, in card order. Draws the headings of
## the rows and groups on the way.
func _place_cards(cards: Array) -> Array:
	var rects: Array = []
	rects.resize(cards.size())
	match TABS[tab]:
		"sword":
			# Three rows: blades, grips, pommels. More than three blades go in rows
			# of three (the greatsword's picture is 62 wide), and the rows below
			# move down to make room.
			var totals := [0, 0, 0]
			for c in cards:
				totals[int(c["row"])] += 1
			var blade_rows: int = (int(totals[0]) + 2) / 3 if int(totals[0]) > 3 else 1
			var push := (blade_rows - 1) * 26.0 - (7.0 if blade_rows > 1 else 0.0)
			for ri in 3:
				_head(["Blade", "Grip", "Pommel"][ri], Vector2(14, 66 + ri * 44 + (push if ri > 0 else 0.0)), DIM)
			var n := [0, 0, 0]
			for i in cards.size():
				var ri: int = cards[i]["row"]
				var w := clampi(192 / maxi(int(totals[ri]), 1), 30, 64 if ri == 0 else 34)
				var r := Rect2(14 + int(n[ri]) * w, 70 + ri * 44 + (push if ri > 0 else 0.0), w - 3, 31)
				if ri == 0 and blade_rows > 1:
					r = Rect2(14 + (int(n[ri]) % 3) * 64, 70 + (int(n[ri]) / 3) * 26, 62, 24)
				n[ri] += 1
				rects[i] = r
		"runes":
			# Two groups, so the two kinds can be told apart before reading anything:
			# passive runes (round stones), then active ones (square, with a button badge).
			var y := 58.0
			for group in ["passive", "active"]:
				var k := 0
				for i in cards.size():
					if cards[i]["group"] != group:
						continue
					if k == 0:
						var tag := Art.texture("swing/ui/tray_%s.png" % group)
						if tag != null:
							root.draw_texture(tag, Vector2(14, y))
						else:
							_head(group, Vector2(14, y + 8), DIM)
					rects[i] = Rect2(14 + (k % 3) * 44, y + 12 + (k / 3) * 44, 38, 38)
					k += 1
				if k > 0:
					y += 12 + ((k + 2) / 3) * 44 + 4
		_:
			for i in cards.size():
				rects[i] = Rect2(14 + (i % 3) * 44, 60 + (i / 3) * 44, 38, 38)
	return rects


## The little button cap on an active rune's stone. `center` is the middle of the
## stone's 26 x 26 picture.
func _badge(center: Vector2) -> void:
	var tex := Art.texture("swing/ui/active_badge.png")
	if tex == null:
		return
	var at: Array = SwordArt.data().get("stones", {}).get("active_badge", {}).get("at_on_icon", [18, 18])
	root.draw_texture(tex, (center - Vector2(13, 13)).round() + Vector2(at[0], at[1]))


## The part the info plate is about: what the mouse is on (a card in the tray or
## a fitting on the sword), else the card the keys are on.
func _info_id() -> String:
	if _preset_hover() >= 0:
		return ""
	var cards := _cards()
	if hover.begins_with("card:"):
		var i := int(hover.split(":")[1])
		if i < cards.size():
			return cards[i]["id"]
	if hover.begins_with("slot:"):
		var i := int(hover.split(":")[1])
		if i < build.line.size() and build.line[i] != "":
			return build.line[i]
	if card < cards.size():
		return cards[card]["id"]
	return ""


func _name(id: String) -> String:
	if SwingBuild.BLADES.has(id):
		return SwingBuild.BLADES[id]["name"]
	if SwingBuild.GRIPS.has(id):
		return SwingBuild.GRIPS[id]["name"]
	if SwingBuild.POMMELS.has(id):
		return SwingBuild.POMMELS[id]["name"]
	return SwingBuild.FITTINGS[id]["name"]


func _is_rune(id: String) -> bool:
	return SwingBuild.FITTINGS.has(id) and SwingBuild.FITTINGS[id]["kind"] == "rune"


func _on_pad() -> bool:
	return keys == SwingBuild.ABILITY_KEYS["pad"]


## Under the tray: the part's name and one plain sentence, never more, on a plate
## of its own. A rune's picture shows while Alt (LT on a controller) is held.
func _draw_info() -> void:
	var at := INFO.position
	if _preset_hover() >= 0:
		_draw_preset_info(_preset_hover())
		return
	var id := _info_id()
	if id == "":
		_head("Parts", at + Vector2(14, 14), DIM)
		return
	root.draw_string(Art.font("PixelifySans-Regular"), at + Vector2(14, 16), _name(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AMBER)
	var y := at.y + 35.0
	for l in info_lines(id):
		_body(l, Vector2(at.x + 10, y))
		y += 13
	if _is_rune(id):
		_body("Hold %s to preview" % ("LT" if _on_pad() else "Alt"), Vector2(at.x + 10, INFO.end.y - 10), DIM)


## A part's sentence, wrapped for the info plate. (Three lines at most fit above
## the preview hint: tests/smoke_forge.gd checks every part.)
func info_lines(id: String) -> Array:
	return _wrap(_desc(id), INFO.size.x - 20)


func _draw_help() -> void:
	var at := HELP.position + Vector2(8, 0)
	var y := 13.0
	for l in help_lines():
		_body(l[0], at + Vector2(0, y), l[1])
		y += 12.0


## How to use the screen, three lines at most, as [words, colour]. It follows what
## the player is doing: naming a preset, pointing at the presets, on a controller.
func help_lines() -> Array:
	if renaming:
		return [["Type a name for this preset.", INK], ["Enter: keep it   Esc: cancel", DIM]]
	if t < note_until:
		var out: Array = []
		for l in _wrap(note, HELP.size.x - 14).slice(0, 3):
			out.append([l, INK])
		return out
	if _preset_hover() >= 0:
		return [["A preset is a whole saved sword.", DIM], ["Click A, B or C to switch to it.", DIM], ["Click its name to change the name.", DIM]]
	if _on_pad():
		return [["Stick: pick   A: fit   X: take off", DIM], ["LB RB: tabs   Select: next preset", DIM], ["Y or B: done", FAINT]]
	return [["Drag a part onto a slot to fit it.", DIM], ["Right-click a slot to take it off.", DIM],
		["T: try at the dummy   Tab: leave" if sandbox else "Tab, Esc or B: done", FAINT]]


## The preset the mouse is on (its tab, or the name beside the tabs), or the one
## being named. -1 = none.
func _preset_hover() -> int:
	if renaming or hover == "rename":
		return build.preset
	if hover.begins_with("preset:"):
		return int(hover.split(":")[1])
	return -1


## Top right: the three loadout presets as tabs, then the chosen one's name.
func _draw_presets() -> void:
	var at := PRESETS.position
	_head("Preset", at + Vector2(8, 15), DIM)
	for i in build.preset_data.size():
		var r := Rect2(at.x + 50 + i * 21, at.y + 5, 18, 14)
		var key := "preset:%d" % i
		buttons[key] = r
		var on: bool = i == build.preset
		var drawn := Art.draw_nine(root, "swing/ui/tab_selected.png" if on else "swing/ui/tab.png", r, 4)
		# A preset that has never been used is fainter.
		var col := INK if on else (FOCUS if hover == key else (DIM if build.preset_data[i] != null else FAINT))
		_head(SwingBuild.PRESET_LETTERS[i], Vector2(r.position.x + 1, at.y + 15), col, 8, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if on and not drawn:
			root.draw_rect(Rect2(r.position.x + 3, r.end.y - 1, r.size.x - 6, 1), AMBER)
	var nr := Rect2(at.x + 116, at.y + 4, PRESETS.size.x - 122, 15)
	buttons["rename"] = nr
	var name := str(build.preset_names[build.preset])
	if renaming:
		root.draw_rect(nr, WELL)
		root.draw_rect(nr, FOCUS, false, 1.0)
		_head(rename_text + ("_" if fmod(t, 0.8) < 0.5 else ""), Vector2(nr.position.x + 4, at.y + 15), FOCUS)
	elif name != "":
		_head(name, Vector2(nr.position.x + 4, at.y + 15), FOCUS if hover == "rename" else INK)
	else:
		_head("Name it", Vector2(nr.position.x + 4, at.y + 15), FOCUS if hover == "rename" else FAINT)


## The info plate while the mouse is on a preset: its name, and the sword it
## holds as pictures (blade, grip and pommel, then what is in the slots). A part
## the player no longer owns is greyed out under a padlock.
func _draw_preset_info(i: int) -> void:
	var at := INFO.position
	root.draw_string(Art.font("PixelifySans-Regular"), at + Vector2(14, 16), build.preset_title(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AMBER)
	var data = build.preset_sword(i)
	if data == null:
		var y := at.y + 35.0
		for l in _wrap("Empty. Click it to start it as a copy of this sword.", INFO.size.x - 20):
			_body(l, Vector2(at.x + 10, y))
			y += 13
		return
	var missing := SwingBuild.parts_missing(data, owned)
	_part_icon("blades", data[0], Vector2(at.x + 42, at.y + 38), missing)
	_part_icon("grips", data[1], Vector2(at.x + 96, at.y + 38), missing)
	_part_icon("pommels", data[2], Vector2(at.x + 130, at.y + 38), missing)
	var x := at.x + 10.0
	for id in data[3]:
		if id == "":
			root.draw_rect(Rect2(x + 8, at.y + 61, 14, 14), WELL)
			root.draw_rect(Rect2(x + 8, at.y + 61, 14, 14), FAINT, false, 1.0)
		else:
			var kind: String = SwingBuild.FITTINGS[id]["kind"]
			_part_icon("runes" if kind == "rune" else ("bands" if kind == "band" else "rare"), id, Vector2(x + 15, at.y + 68), missing)
		x += 32.0


func _part_icon(kind: String, id: String, center: Vector2, missing: Array) -> void:
	if id in missing:
		_icon(kind, id, center, 2.0, Color(0.42, 0.44, 0.5, 0.55))
		var lock := Art.texture("swing/ui/padlock.png")
		if lock != null:
			root.draw_texture(lock, (center - lock.get_size() * 0.5).round())
		return
	_icon(kind, id, center)
	if SwingBuild.FITTINGS.has(id) and SwingBuild.FITTINGS[id].get("trigger", "") == "active":
		_badge(center)


func _preview_held() -> bool:
	if Input.is_key_pressed(KEY_ALT):
		return true
	for pad in Input.get_connected_joypads():
		if Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > 0.5:
			return true
	return false


## While Alt is held on a rune: a still picture of it firing, over the sword.
func _draw_preview() -> void:
	if not is_open or finishing >= 0.0 or dragging:
		return
	var id := _info_id()
	if id == "" or not _is_rune(id) or not (_preview_held() or preview_always):
		return
	_nine("panel_titled", PREVIEW, preview)
	preview.draw_string(Art.font("Silkscreen-Regular"), PREVIEW.position + Vector2(14, 14), _name(id).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, AMBER)
	var frame := Rect2(PREVIEW.position + Vector2(4, 24), Vector2(176, 120))   # the pictures are 352 x 240
	var tex := Art.texture("swing/previews/%s.png" % id)
	if tex != null:
		preview.draw_texture_rect(tex, frame, false)
	else:
		preview.draw_rect(frame, WELL)
		preview.draw_string(Art.font("PixelifySans-Regular"), frame.position + Vector2(0, 64), "No picture yet", HORIZONTAL_ALIGNMENT_CENTER, frame.size.x, 11, DIM)


var preview_always := false   # for screenshots: show the picture without Alt


func _short(name: String) -> String:
	return name.replace("Iron ", "").replace(" Grip", "")


func _on_sword(id: String) -> bool:
	return id != "" and (id == build.blade or id == build.grip or id == build.pommel or id in build.line)


func _desc(id: String) -> String:
	if SwingBuild.POMMELS.has(id):
		return SwingBuild.POMMELS[id]["desc"]
	if SwingBuild.BLADES.has(id):
		return SwingBuild.blade_info(id)["desc"]
	if SwingBuild.GRIPS.has(id):
		return SwingBuild.GRIPS[id]["desc"]
	return SwingBuild.FITTINGS[id]["desc"]


func _boost_text(band: String, rune: String) -> String:
	match band:
		"twice":
			return {"shockwave": "two waves", "hook": "hooks twice", "shards": "two chains", "weak_point": "two marks", "leap": "two leaps", "whirlwind": "spins twice as long"}.get(rune, "twice")
		"wider":
			return {"shockwave": "a bigger wave", "hook": "reaches further", "shards": "jumps further", "weak_point": "a bigger spot", "leap": "leaps from further away", "whirlwind": "a bigger circle"}.get(rune, "bigger")
		"every_hit":
			if SwingBuild.FITTINGS.get(rune, {}).get("trigger", "") == "active":
				return "back sooner with each hit"
			return "on every hit, half strength"
		"saved_up":
			return "every third time, 3x strong"
		"on_dodge":
			return "when you dodge too"
	return ""


## What a band does to its rune, as a short sentence for the side panel.
func _band_line(band: String, rune: String) -> String:
	var rn: String = SwingBuild.FITTINGS[rune]["name"]
	match band:
		"twice":
			return "%s fires twice." % rn
		"wider":
			return "%s %s." % [rn, _boost_text("wider", rune)]
		"every_hit":
			if rune == "shards":
				return "Shards split in two at each jump, at half strength."
			return "%s happens on every hit, at half strength." % rn
		"saved_up":
			return "%s happens every third time, three times as strong." % rn
		"on_dodge":
			return "%s also happens when you dodge." % rn
	return ""


## Group colours: a band (or Relay) and the rune it boosts share one outline,
## and the same colour marks that rune's line on the right.
const GROUP_COLORS := [Color("#ffc850"), Color("#78c0cc"), Color("#a878d0"), Color("#86d4a4"), Color("#f078b4")]


func _group_color(effect_index: int) -> Color:
	return GROUP_COLORS[effect_index % GROUP_COLORS.size()]


## Centre: the sword big over the anvil. Its sockets are the menu.
func _draw_sword(stats: Dictionary) -> void:
	var blade := build.blade
	var grip := build.grip
	var size := SwordArt.frame_size(blade, grip, "forge")
	# Twice its size whenever that fits. A taller sword is drawn smaller, by a
	# whole number of screen pixels for each of its own, so they stay square.
	# The very tallest (a greatsword on a long grip) may use the few pixels above
	# SWORD_TOP and sit a little lower on the anvil, rather than drop a whole size.
	var screen := maxf(roundf(float(get_window().size.y) / 360.0), 1.0)
	var fit := minf((SWORD_BOTTOM - SWORD_TOP + SWORD_SLACK) / size.y, 2.0)
	zoom = maxf(floorf(fit * screen) / screen, 1.0 / screen)
	var top_y := maxf(SWORD_BOTTOM - size.y * zoom, minf(SWORD_TOP, 0.0) if size.y * zoom > SWORD_BOTTOM - SWORD_TOP else SWORD_TOP)
	sword_bottom = top_y + size.y * zoom
	var top := Vector2(CENTRE_X - size.x * zoom * 0.5, top_y).round()
	sword_top = top
	sword_size = size * zoom
	var anvil := Art.texture("swing/ui/anvil.png")
	if anvil != null:
		root.draw_texture(anvil, Vector2(CENTRE_X - anvil.get_width() * 0.5, SWORD_BOTTOM - 2).round())
	root.draw_set_transform(top, 0.0, Vector2(zoom, zoom))
	SwordArt.draw(root, blade, grip, build.line, "forge", {}, Vector2.ZERO, Color.WHITE, build.pommel)
	root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Group outlines.
	var info: Dictionary = stats["slot_info"]
	var effects: Array = stats["effects"]
	for ei in effects.size():
		var group: Array = [int(effects[ei]["slot"])]
		for s2 in info:
			if int(info[s2].get("band", -1)) == ei:
				group.append(int(s2))
		if group.size() < 2:
			continue
		var rr := _slot_screen(group[0])
		for s2 in group:
			rr = rr.merge(_slot_screen(s2))
		root.draw_rect(rr.grow(4), _group_color(ei), false, 1.0)
	# Sockets: clickable, empty ones darkened, focus on the selected one.
	for i in build.line.size():
		var r := _slot_screen(i)
		buttons["slot:%d" % i] = r.grow(3)
		if build.line[i] == "":
			root.draw_rect(r.grow(-2), Color(0.02, 0.02, 0.03, 0.9))
		if hover == "slot:%d" % i:
			root.draw_rect(r.grow(2), Color(1, 1, 1, 0.5), false, 1.0)
		if i == selected:
			_nine("focus_corners", r.grow(7))


func _slot_screen(i: int) -> Rect2:
	var r := SwordArt.slot_rect(build.blade, build.grip, "forge", i)
	return Rect2(sword_top + r.position * zoom, r.size * zoom)


# --- Forge effects -----------------------------------------------------------

func _update_fx(delta: float) -> void:
	t += delta
	strike_t += delta
	heat = move_toward(heat, 0.3, delta * 0.5)
	if finishing >= 0.0:
		heat = 0.0
	for list in [embers, sparks, steam]:
		var keep: Array = []
		for p in list:
			p[2] += delta
			if p[2] < p[3]:
				if list == sparks:
					p[1].y += 260.0 * delta  # sparks fall
				elif list == embers:
					p[1].x += sin(t * 3.0 + p[0].y) * 8.0 * delta
				p[0] += p[1] * delta
				keep.append(p)
		list.assign(keep)
	heat_mask.queue_redraw()
	heat_fill.queue_redraw()
	fx_top.queue_redraw()
	banner.queue_redraw()
	preview.queue_redraw()
	root.queue_redraw()


func _draw_heat_mask() -> void:
	if sword_size != Vector2.ZERO:
		heat_mask.draw_set_transform(sword_top, 0.0, Vector2(zoom, zoom))
		SwordArt.draw(heat_mask, build.blade, build.grip, build.line, "forge", {}, Vector2.ZERO, Color.WHITE, build.pommel)
		heat_mask.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Additive colour on the sword's own pixels: orange heat, hottest at the blade,
## and when it's finished, white-hot cooling to steel with a shine sweeping up.
func _draw_heat_fill() -> void:
	var r := Rect2(sword_top, sword_size)
	if finishing >= 0.0 and Art.texture("swing/forge-fx/heat_%s.png" % build.blade) != null:
		return  # the art's heat and shine strips take over (drawn on the banner layer)
	if finishing >= 0.0:
		var k := finishing / FINISH_TIME
		var white := clampf(1.0 - k * 2.5, 0.0, 1.0)
		heat_fill.draw_rect(r, Color(1.0, 0.75, 0.45, 0.8 * white))
		var sweep_y := lerpf(r.end.y, r.position.y - 20.0, clampf((k - 0.25) / 0.5, 0.0, 1.0))
		for i in 10:
			heat_fill.draw_rect(Rect2(r.position.x, sweep_y + i * 2.0 - 10.0, r.size.x, 2), Color(1, 1, 1, 0.08 * (5.0 - absf(i - 4.5))))
		return
	# No idle glow: the sword only flashes when a part goes on.
	var pulse := 0.0
	var steps := 0
	for i in steps:
		var y0 := r.position.y + r.size.y * i / steps
		var hotness := 1.0 - float(i) / steps  # the blade end is hottest
		var a := heat * pulse * (0.12 + 0.5 * hotness * hotness)
		heat_fill.draw_rect(Rect2(r.position.x, y0, r.size.x, r.size.y / steps + 1), Color(1.0, 0.42 + 0.3 * hotness, 0.12, a))
	if strike_t < 0.15:
		heat_fill.draw_rect(r, Color(1, 0.9, 0.7, 0.6 * (1.0 - strike_t / 0.15)))


## Draws one frame of a forge-fx strip, or nothing once it has finished.
func _fx_strip(ci: CanvasItem, name: String, pos: Vector2, start: float, hold := false, alpha := 1.0) -> void:
	var info: Dictionary = Art.json("swing/forge-fx/forge_fx.json").get("strips", {}).get(name, {})
	var tex := Art.texture("swing/forge-fx/%s.png" % name)
	if tex == null or info.is_empty() or t < start:
		return
	var frames := int(info["frames"])
	var frame := int((t - start) * float(info["fps"]))
	if frame >= frames:
		if not hold:
			return
		frame = frames - 1
	var o = info.get("origin")
	var origin := Vector2.ZERO if o == null else Vector2(o[0], o[1])
	Art.draw_strip(ci, tex, frames, frame, pos, origin, false, Color(1, 1, 1, alpha), 1.0)


func _draw_fx() -> void:
	for p in playing:
		if p[0] == "sparks":
			_fx_strip(fx_top, "sparks", p[1], p[2])
	for p in embers:
		var k: float = p[2] / p[3]
		var c := Color(1.0, 0.55 + 0.3 * (1.0 - k), 0.2, (1.0 - k) * 0.9)
		fx_top.draw_rect(Rect2((p[0] as Vector2).round(), Vector2(1, 1)), c)
	for p in sparks:
		var k: float = p[2] / p[3]
		var c := Color(1.0, 0.85 - 0.4 * k, 0.4 - 0.3 * k, 1.0 - k)
		var tail: Vector2 = p[1] * 0.02
		fx_top.draw_line(p[0], p[0] - tail, c, 1.0)
	if strike_t < 0.25:
		var k := strike_t / 0.25
		fx_top.draw_circle(strike_at, 4.0 + k * 22.0, Color(1.0, 0.8, 0.5, 0.5 * (1.0 - k)))
		fx_top.draw_arc(strike_at, 6.0 + k * 30.0, 0.0, TAU, 24, Color(1.0, 0.7, 0.3, 1.0 - k), 1.0)
	for p in steam:
		var k: float = p[2] / p[3]
		fx_top.draw_circle(p[0], 2.0 + k * 7.0, Color(0.6, 0.65, 0.7, 0.18 * (1.0 - k)))


func _draw_banner() -> void:
	# Hammer strikes and steam (normal blend).
	var keep: Array = []
	for p in playing:
		if t - float(p[2]) < 1.5:
			keep.append(p)
		if p[0] != "sparks":
			_fx_strip(banner, p[0], p[1], p[2])
	playing = keep
	if finishing < 0.0:
		return
	var heat_tex := Art.texture("swing/forge-fx/heat_%s.png" % build.blade)
	var banner_tex := Art.texture("swing/forge-fx/forged_banner.png")
	if heat_tex != null and banner_tex != null:
		var start := t - finishing
		var blade_pos := sword_top + Vector2(SwordArt.blade_x(build.blade, "forge"), 0) * zoom
		var bsrc := SwordArt.blade_size(build.blade, "forge")
		var bsize := bsrc * zoom
		# Heat cools from white-hot to steel, then a glint sweeps up the blade.
		var heat_k := (finishing - 0.1) * 10.0
		if finishing >= 0.1 and heat_k < 8.0:
			var hf := mini(int(heat_k), 7)
			banner.draw_texture_rect_region(heat_tex, Rect2(blade_pos, bsize), Rect2(hf * bsrc.x, 0, bsrc.x, bsrc.y))
		var shine_tex := Art.texture("swing/forge-fx/shine_%s.png" % build.blade)
		var shine_k := (finishing - 0.9) * 16.0
		if shine_tex != null and finishing >= 0.9 and shine_k < 8.0:
			banner.draw_texture_rect_region(shine_tex, Rect2(blade_pos, bsize), Rect2(mini(int(shine_k), 7) * bsrc.x, 0, bsrc.x, bsrc.y))
		var fade := clampf((FINISH_TIME - finishing) / 0.3, 0.0, 1.0)
		_fx_strip(banner, "forged_banner", Vector2(CENTRE_X, sword_top.y + 40), start + 0.2, true, fade)
		return
	var k := finishing / FINISH_TIME
	var a := clampf(k * 4.0, 0.0, 1.0) * clampf((1.0 - k) * 4.0, 0.0, 1.0)
	var y := 150.0 - 8.0 * (1.0 - clampf(k * 3.0, 0.0, 1.0))
	banner.draw_rect(Rect2(0, y - 22, 640, 34), Color(0, 0, 0, 0.55 * a))
	var f := Art.font("Silkscreen-Regular")
	banner.draw_string_outline(f, Vector2(0, y + 4), "FORGED!", HORIZONTAL_ALIGNMENT_CENTER, 640, 16, 4, Color(0.1, 0.05, 0.02, a))
	banner.draw_string(f, Vector2(0, y + 4), "FORGED!", HORIZONTAL_ALIGNMENT_CENTER, 640, 16, Color(1.0, 0.75, 0.3, a))
	var names: Array = []
	for e in build.compute()["effects"]:
		names.append(SwingBuild.FITTINGS[e["id"]]["name"])
	var sub := "%s + %s" % [SwingBuild.BLADES[build.blade]["name"], SwingBuild.GRIPS[build.grip]["name"]]
	if not names.is_empty():
		sub += ":  " + ", ".join(names)
	banner.draw_string(Art.font("PixelifySans-Regular"), Vector2(0, y + 18), sub, HORIZONTAL_ALIGNMENT_CENTER, 640, 11, Color(0.9, 0.86, 0.8, a))


## How "what it does" is set out, roomiest first. The first one that fits is used:
## stone size, where the words start, line height, the gap between runes.
const DOES_PLANS := [
	{"stone": 26, "text_x": 38.0, "line": 13.0, "gap": 8.0, "least": 28.0},
	{"stone": 26, "text_x": 38.0, "line": 13.0, "gap": 3.0, "least": 27.0},
	{"stone": 9, "text_x": 16.0, "line": 13.0, "gap": 5.0, "least": 13.0},
	{"stone": 9, "text_x": 16.0, "line": 12.0, "gap": 2.0, "least": 12.0},
]


## Sets out the "what it does" rows for one plan: {rows: [{lines, h}], notes, height}.
func _plan_does(effects: Array, notes: Array, plan: Dictionary) -> Dictionary:
	var width := DOES.size.x - 16.0
	var rows: Array = []
	var height := 0.0
	for e in effects:
		var lines := _wrap(SwingBuild.sentence(e, keys), width - float(plan["text_x"]))
		var h := maxf(float(plan["least"]), lines.size() * float(plan["line"]))
		rows.append({"lines": lines, "h": h})
		height += h + float(plan["gap"])
	var note_lines: Array = []
	for n in notes:
		note_lines.append(_wrap(n, width))
		height += (note_lines[-1] as Array).size() * float(plan["line"]) + 4.0
	return {"rows": rows, "notes": note_lines, "height": height}


## Right: one short line per rune, its bar in its group colour; then the
## fittings that do nothing (and why). It never runs off its plate: with more
## to say, the rows close up and the stones get smaller.
func _draw_does(stats: Dictionary) -> void:
	var x := DOES.position.x + 8.0
	_head("What it does", Vector2(x, DOES.position.y + 14), DIM)
	var effects: Array = stats["effects"]
	var info: Dictionary = stats["slot_info"]
	var top := DOES.position.y + 24.0
	var bottom := DOES.end.y - 8.0
	var notes: Array = []
	for i in build.line.size():
		var si: Dictionary = info.get(i, {})
		if build.line[i] != "" and si.has("unused"):
			notes.append("%s: %s" % [SwingBuild.FITTINGS[build.line[i]]["name"], si.get("why", "does nothing here.")])
	if effects.is_empty() and notes.is_empty():
		# (With bands but no rune, the notes below say why nothing happens instead.)
		var ey := top + 10.0
		for l in _wrap("Nothing fitted yet. Pick a rune on the left, then click a slot.", DOES.size.x - 16.0):
			_body(l, Vector2(x, ey), DIM)
			ey += 13
	var plan: Dictionary = DOES_PLANS[0]
	var set_out := {}
	for pl in DOES_PLANS:
		plan = pl
		set_out = _plan_does(effects, notes, pl)
		if float(set_out["height"]) <= bottom - top:
			break
	does_fits = float(set_out["height"]) <= bottom - top
	var y := top
	var line_h: float = plan["line"]
	var rows: Array = set_out["rows"]
	for ei in effects.size():
		var row: Dictionary = rows[ei]
		var h: float = row["h"]
		if y + h > bottom + 0.5:
			# (Only with more runes than any sword in the prototype can hold.)
			_body("and %d more" % (effects.size() - ei), Vector2(x, bottom - 2), DIM)
			return
		var e: Dictionary = effects[ei]
		root.draw_rect(Rect2(x, y, 3, h), _group_color(ei))
		if int(plan["stone"]) == 26:
			_icon("runes", e["id"], Vector2(x + 20, y + 14))
			if SwingBuild.FITTINGS[e["id"]]["trigger"] == "active":
				_badge(Vector2(x + 20, y + 14))
		else:
			var stone := Art.texture("swing/runes/%s_forge.png" % e["id"])
			if stone != null:
				root.draw_texture(stone, Vector2(x + 5, y + 2))
		var ly := y + line_h - 2.0
		for l in row["lines"]:
			_body(l, Vector2(x + float(plan["text_x"]), ly))
			ly += line_h
		y += h + float(plan["gap"])
	for lines in set_out["notes"]:
		for l in lines:
			if y + line_h > bottom + 0.5:
				return
			_body(l, Vector2(x, y + line_h - 3.0), DIM)
			y += line_h
		y += 4.0


var does_fits := true   # the last "what it does" fitted its plate (checked by tests/smoke_forge.gd)


## What each number is called, and where it sits on the stats plate (column, row).
const STAT_ROWS := [
	["damage", 0, 0], ["speed", 1, 0],
	["reach", 0, 1], ["crit", 1, 1],
	["crit_damage", 0, 2], ["slots", 1, 2],
	["move", 0, 3],
]


## A sword's numbers as the stats plate shows them.
static func stat_values(s: Dictionary) -> Dictionary:
	return {
		"damage": float(s["damage"]),
		"speed": roundf(float(s["speed"]) * 100.0),
		"reach": roundf(float(s["reach"]) * 100.0),
		"crit": roundf(float(s["crit"]) * 100.0),
		"crit_damage": float(s["crit_damage"]),
		"slots": float((s["line"] as Array).size()),
		"move": roundf(float(s.get("swing_move", SwingBuild.SWING_MOVE)) * 100.0),
	}


static func _plain(v: float) -> String:
	return ("%d" % roundi(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)


static func stat_text(key: String, v: float) -> String:
	match key:
		"damage": return "Damage %s" % _plain(v)
		"speed": return "Speed %d%%" % roundi(v)
		"reach": return "Reach %d%%" % roundi(v)
		"crit": return "Crit %d%%" % roundi(v)
		"crit_damage": return "Crit hits x%s" % _plain(v)
		"slots": return "Slots %d" % roundi(v)
		"move": return "Walk while swinging %d%%" % roundi(v)
	return ""


## The change in a number, as it is written beside it: "+8.3", "-60%". Empty for no change.
static func delta_text(key: String, d: float) -> String:
	if absf(d) < 0.05:
		return ""
	var amount := _plain(absf(d))
	if key in ["speed", "reach", "crit", "move"]:
		amount += "%"
	return ("+" if d > 0.0 else "-") + amount


## The part whose effect the stats plate should show: a blade, grip or pommel in
## the tray that isn't the one fitted, under the mouse (or the keys' cursor).
func _compare_id() -> String:
	if TABS[tab] != "sword":
		return ""
	var cards := _cards()
	var i := -1
	if hover.begins_with("card:"):
		i = int(hover.split(":")[1])
	elif keys_on_cards:
		i = card
	if i < 0 or i >= cards.size() or cards[i]["locked"]:
		return ""
	var id: String = cards[i]["id"]
	return "" if _on_sword(id) else id


## What the sword's numbers would be with this blade, grip or pommel fitted.
func stats_with(id: String) -> Dictionary:
	var b := SwingBuild.new()
	b.set_data(build.get_data())
	if SwingBuild.BLADES.has(id):
		b.set_blade(id)
	elif SwingBuild.GRIPS.has(id):
		b.set_grip(id)
	elif SwingBuild.POMMELS.has(id):
		b.set_pommel(id)
	return b.compute()


## The sword's numbers, on a bordered plate of their own. While the cursor is on
## a part you could fit, each number it would change shows the change beside it:
## green with a plus for a gain, red with a minus for a loss.
func _draw_stats(stats: Dictionary) -> void:
	var at := STATS.position
	var with_id := _compare_id()
	var now := stat_values(stats)
	var then := now if with_id == "" else stat_values(stats_with(with_id))
	if with_id == "":
		_head("Stats", at + Vector2(14, 14), INK)
		_head(_name(build.blade), at + Vector2(14, 14), DIM, 8, STATS.size.x - 26, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_head("With the " + _name(with_id), at + Vector2(14, 14), FOCUS)
		if stat_changes(now, then).is_empty():
			_head("same numbers", at + Vector2(14, 14), DIM, 8, STATS.size.x - 26, HORIZONTAL_ALIGNMENT_RIGHT)
	for row in STAT_ROWS:
		var key: String = row[0]
		var d: float = float(then[key]) - float(now[key])
		_stat(key, stat_text(key, now[key]), at + stat_at(row), delta_text(key, d), d > 0.0)


## Where a number sits on the stats plate (its text baseline), from the plate's corner.
static func stat_at(row: Array) -> Vector2:
	return Vector2(8 + int(row[1]) * STAT_COL, 32 + int(row[2]) * 13)


## The numbers a part would change: {name: "+8.3"}.
static func stat_changes(now: Dictionary, then: Dictionary) -> Dictionary:
	var out := {}
	for key in now:
		var d := delta_text(key, float(then[key]) - float(now[key]))
		if d != "":
			out[key] = d
	return out


## How wide a number is on the plate with a change beside it (icon, words, change).
func stat_width(text: String, change: String) -> float:
	var f := Art.font("PixelifySans-Regular")
	var w := 12.0 + f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	if change != "":
		w += 4.0 + f.get_string_size(change, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	return w


## One number on the stats plate: its icon, the words, then the change a hovered
## part would make. pos is the text baseline. The icon lights for a moment when
## the number itself changes.
func _stat(name: String, text: String, pos: Vector2, change := "", gain := true) -> void:
	if _stat_last.has(name) and _stat_last[name] != text:
		_stat_lit[name] = t
	_stat_last[name] = text
	var lit: bool = t - float(_stat_lit.get(name, -9.0)) < 1.2
	var icon := Art.texture("swing/ui/stat_%s%s.png" % [name, "_hot" if lit else ""])
	var x := pos.x
	if icon != null:
		root.draw_texture(icon, Vector2(x, pos.y - 8))
	x += 12.0
	_body(text, Vector2(x, pos.y), AMBER if lit else INK)
	if change != "":
		x += Art.font("PixelifySans-Regular").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 4.0
		_body(change, Vector2(x, pos.y), GAIN if gain else LOSS)
