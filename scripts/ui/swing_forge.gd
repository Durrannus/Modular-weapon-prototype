extends CanvasLayer
## The forge for the swing path (layout from art/swing/mockup_forge_A.png).
## Left: the parts tray (blades, grips, runes, bands) and a details box.
## Centre: the sword upright over the anvil, slot numbers up the left and
## band-to-rune brackets on the right, plus the A/B test swords.
## Right: what each slot does, read from the grip up, and the finisher summary.
## Free to swap. Pauses the game while open. Drawn at the 640x360 base size.

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
const LEFT := Rect2(6, 30, 203, 324)     # the plate behind the tray
const RIGHT := Rect2(412, 34, 222, 302)  # the plate behind "what it does"
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
var buttons := {}          # key -> Rect2, rebuilt every draw
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
	if Input.is_action_just_pressed("move_left"):
		card = maxi(card - 1, 0)
	if Input.is_action_just_pressed("menu_place"):
		_use_card(card)
	if Input.is_action_just_pressed("menu_rotate"):
		_put("")
	root.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if finishing >= 0.0:
		if event is InputEventMouseButton and event.pressed:
			_really_close()
			get_viewport().set_input_as_handled()
		return
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
		"try":
			_try()
			return
	Sfx.play(self, "click", -14.0)


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
					out.append({"id": id, "name": SwingBuild.FITTINGS[id]["name"], "locked": false})
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

func _nine(name: String, r: Rect2) -> void:
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
		root.draw_rect(r, PLATE)
		root.draw_rect(r, FAINT, false, 1.0)
	else:
		root.draw_style_box(_styles[name], r)


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


func _icon(kind: String, id: String, center: Vector2, part_scale := 2.0) -> void:
	match kind:
		"runes", "bands", "rare":
			var tex := Art.texture("swing/%s/%s_icon.png" % [kind, id])
			if tex != null:
				root.draw_texture(tex, (center - tex.get_size() * 0.5).round())
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
				root.draw_texture(ptex, (center - ptex.get_size() * 0.5).round())
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
				root.draw_texture(card_tex, (center - card_tex.get_size() * 0.5).round())
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
	# A still backdrop (the forge's niche), then a plate behind each column of words.
	var backdrop := Art.texture("swing/ui/forge_backdrop.png")
	if backdrop != null:
		root.draw_texture(backdrop, Vector2.ZERO)
	else:
		root.draw_rect(Rect2(Vector2.ZERO, root.size), WELL)
	_nine("panel", LEFT)
	_nine("panel", RIGHT)
	_head("The forge", Vector2(14, 24), AMBER, 16)
	if whose != "":
		_head(whose, Vector2(150, 24), INK, 8)
	var stats := build.compute()
	_draw_tray()
	_draw_sword(stats)
	_draw_does(stats)
	if dragging:
		for i in build.line.size():
			var r := _slot_screen(i)
			var on := hover == "slot:%d" % i
			root.draw_rect(r.grow(5 if on else 3), FOCUS if on else Color(1, 1, 1, 0.35), false, 1.0)
		var f: Dictionary = SwingBuild.FITTINGS[drag_id]
		var kind := "runes" if f["kind"] == "rune" else ("bands" if f["kind"] == "band" else "rare")
		_icon(kind, drag_id, root.get_local_mouse_position())


## Left: tabs and icon-only cards. Details show for the hovered (or keyboard) card.
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
	var row_n := [0, 0, 0]
	var row_total := [0, 0, 0]
	for c in cards:
		if c.has("row"):
			row_total[int(c["row"])] += 1
	if cards.is_empty():
		_body("Nothing here yet.", Vector2(14, 78), DIM)
	# More than three blades go in rows of three (the greatsword's picture is 62
	# wide), and the grip and pommel rows move down to make room.
	var blade_rows := (int(row_total[0]) + 2) / 3 if int(row_total[0]) > 3 else 1
	var push := (blade_rows - 1) * 26.0 - (7.0 if blade_rows > 1 else 0.0)
	if TABS[tab] == "sword":
		for ri in 3:
			_head(["Blade", "Grip", "Pommel"][ri], Vector2(14, 66 + ri * 44 + (push if ri > 0 else 0.0)), DIM)
	for i in cards.size():
		var c: Dictionary = cards[i]
		var r := Rect2(14 + (i % 3) * 44, 60 + (i / 3) * 44, 38, 38)
		var icon_scale := 2.0
		if c.has("row"):
			var ri: int = c["row"]
			var w := clampi(192 / maxi(int(row_total[ri]), 1), 30, 64 if ri == 0 else 34)
			r = Rect2(14 + row_n[ri] * w, 70 + ri * 44 + (push if ri > 0 else 0.0), w - 3, 31)
			if ri == 0 and blade_rows > 1:
				r = Rect2(14 + (row_n[ri] % 3) * 64, 70 + (row_n[ri] / 3) * 26, 62, 24)
			row_n[ri] += 1
		buttons["card:%d" % i] = r
		_nine("well_selected" if i == card else "well", r)
		if hover == "card:%d" % i and i != card:
			root.draw_rect(r, FOCUS, false, 1.0)
		if c["locked"]:
			var lock := Art.texture("swing/ui/padlock.png")
			if lock != null:
				root.draw_texture(lock, (r.get_center() - lock.get_size() * 0.5).round())
			continue
		_icon(c.get("kind", TABS[tab]), c["id"], r.get_center(), icon_scale)
		if _on_sword(c["id"]):
			var fitted := Art.texture("swing/ui/fitted_mark.png")
			if fitted != null:
				root.draw_texture(fitted, Vector2(r.end.x - 7, r.position.y + 2))
			else:
				root.draw_rect(Rect2(r.end.x - 6, r.position.y + 2, 4, 4), AMBER)
	var di := card
	var text_end := 0.0
	if hover.begins_with("card:"):
		di = int(hover.split(":")[1])
	if di < cards.size():
		var id: String = cards[di]["id"]
		var y := 216.0 + push if TABS[tab] == "sword" else 166.0
		root.draw_string(Art.font("PixelifySans-Regular"), Vector2(14, y), cards[di]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AMBER)
		y += 13
		_body(_kind_line(id), Vector2(14, y), DIM)
		y += 16
		for l in _wrap(_desc(id), 186):
			_body(l, Vector2(14, y))
			y += 13
		text_end = y - 13.0
	# The how-to lines give way to a long description: nothing here may overlap.
	if text_end < 290.0:
		_body("Drag a part onto a slot, or", Vector2(14, 300), DIM)
		_body("click a slot, then a part.", Vector2(14, 313), DIM)
	_body("Drag off or right-click: take off", Vector2(14, 332), FAINT)
	_body("T: try at the dummy   Tab: leave" if sandbox else "Tab, Esc or B: done", Vector2(14, 345), FAINT)


func _short(name: String) -> String:
	return name.replace("Iron ", "").replace(" Grip", "")


func _on_sword(id: String) -> bool:
	return id != "" and (id == build.blade or id == build.grip or id == build.pommel or id in build.line)


func _kind_line(id: String) -> String:
	if SwingBuild.BLADES.has(id):
		var b: Dictionary = SwingBuild.BLADES[id]
		return "Blade, %d slot%s" % [b["slots"], "" if b["slots"] == 1 else "s"]
	if SwingBuild.GRIPS.has(id):
		var g: Dictionary = SwingBuild.GRIPS[id]
		return "Grip, %d slot%s" % [g["slots"], "" if g["slots"] == 1 else "s"]
	if SwingBuild.POMMELS.has(id):
		return "Pommel, stats only"
	var f: Dictionary = SwingBuild.FITTINGS[id]
	if f["kind"] == "band":
		return "Band"
	if f["kind"] == "bender":
		return "Rule-bender, 1 per sword"
	if f["trigger"] == "active":
		return "Active rune: %s a button" % ("hold" if f["use"] == "hold" else "press")
	return "Passive rune, " + {"finisher": "on the finisher", "hit": "every hit", "kill": "on a kill"}[f["trigger"]]


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
	# Twice its size whenever that fits, so the sword's pixels stay square.
	zoom = 2.0 if size.y * 2.0 <= SWORD_BOTTOM - 4.0 else (SWORD_BOTTOM - 4.0) / size.y
	sword_bottom = SWORD_BOTTOM
	var top := Vector2(CENTRE_X - size.x * zoom * 0.5, sword_bottom - size.y * zoom).round()
	sword_top = top
	sword_size = size * zoom
	var anvil := Art.texture("swing/ui/anvil.png")
	if anvil != null:
		root.draw_texture(anvil, Vector2(CENTRE_X - anvil.get_width() * 0.5, sword_bottom - 2).round())
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


## Right: one short line per rune, its bar in its group colour; then the
## fittings that do nothing (and why); then the blade and grip.
func _draw_does(stats: Dictionary) -> void:
	const X := 420.0
	const W := 172.0
	_head("What it does", Vector2(X, 48), DIM)
	var effects: Array = stats["effects"]
	var info: Dictionary = stats["slot_info"]
	var y := 62.0
	if effects.is_empty():
		for l in _wrap("Nothing fitted yet. Pick a rune on the left, then click a slot.", W):
			_body(l, Vector2(X, y + 10), DIM)
			y += 13
	for ei in effects.size():
		var e: Dictionary = effects[ei]
		var lines := _wrap(SwingBuild.sentence(e, keys), W - 36)
		var h := maxf(28.0, lines.size() * 13.0 + 4.0)
		root.draw_rect(Rect2(X, y, 3, h), _group_color(ei))
		_icon("runes", e["id"], Vector2(X + 20, y + 14))
		var ly := y + 11
		for l in lines:
			_body(l, Vector2(X + 38, ly))
			ly += 13
		y += h + 10
	for i in build.line.size():
		var si: Dictionary = info.get(i, {})
		if build.line[i] != "" and si.has("unused"):
			for l in _wrap("%s: %s" % [SwingBuild.FITTINGS[build.line[i]]["name"], si.get("why", "does nothing here.")], W):
				_body(l, Vector2(X, y + 8), DIM)
				y += 13
			y += 6
	var bl := SwingBuild.blade_info(build.blade)
	var spd := float(stats["speed"])
	var spd_word := "fast" if spd >= 1.15 else ("slow" if spd <= 0.85 else "normal")
	var pm: Dictionary = SwingBuild.POMMELS[build.pommel]
	_body("%s + %s" % [bl["name"], SwingBuild.GRIPS[build.grip]["name"]], Vector2(X, 284), DIM)
	_body("%s: %s" % [pm["name"], pm["desc"]], Vector2(X, 298), DIM)
	# The numbers, each with its icon. An icon lights for a moment when its number changes.
	var reach := float(stats["reach"])
	var reach_word := "long" if reach >= 1.1 else ("short" if reach <= 0.95 else "normal")
	_stat("damage", "Damage %d" % roundi(float(stats["damage"])), Vector2(X, 312))
	_stat("speed", "Speed %s" % spd_word, Vector2(X + 96, 312))
	_stat("reach", "Reach %s" % reach_word, Vector2(X, 326))
	_stat("crit", "Crit %d%%" % roundi(float(stats["crit"]) * 100.0), Vector2(X + 96, 326))
	_stat("crit_damage", "x%s" % str(snappedf(float(stats["crit_damage"]), 0.1)), Vector2(X + 158, 326))


## One number in "what it does": its icon, then the words. pos is the text baseline.
func _stat(name: String, text: String, pos: Vector2) -> void:
	if _stat_last.has(name) and _stat_last[name] != text:
		_stat_lit[name] = t
	_stat_last[name] = text
	var lit: bool = t - float(_stat_lit.get(name, -9.0)) < 1.2
	var icon := Art.texture("swing/ui/stat_%s%s.png" % [name, "_hot" if lit else ""])
	var x := pos.x
	if icon != null:
		root.draw_texture(icon, Vector2(x, pos.y - 8))
		x += icon.get_width() + 3.0
	_body(text, Vector2(x, pos.y), AMBER if lit else DIM)
