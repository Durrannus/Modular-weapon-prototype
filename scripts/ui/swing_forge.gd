extends CanvasLayer
## The forge for the swing path: pick a blade and a grip, then fill the slots
## with runes and bands. Free to swap. Pauses the game while open.

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const SwordArt := preload("res://scripts/weapon/sword_art.gd")
const Sfx := preload("res://scripts/sfx.gd")

const CELL := 54.0                  # 3x the 18 px forge sprites
const SWORD_POS := Vector2(110, 118)
const LIST_X := 620.0
const LIST_W := 250.0
const ROW := 31.0
const INFO_X := 900.0
const INFO_W := 350.0

var build: SwingBuild
var root: Control
var is_open := false
var selected := 0          # slot index, 0 = bottom of the grip
var hover := ""            # what the mouse is over, e.g. "fit:hook"
var flash_t := 0.0         # brief highlight after a change
var buttons := {}          # key -> Rect2, rebuilt every draw


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	scale = Vector2(0.5, 0.5)  # laid out at 1280x720, drawn on the 640x360 screen
	root = Control.new()
	root.size = Vector2(1280, 720)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)
	root.draw.connect(_draw_forge)


func setup(b: SwingBuild) -> void:
	build = b


func open() -> void:
	is_open = true
	root.visible = true
	selected = clampi(selected, 0, build.slot_count() - 1)
	get_tree().paused = true


func close() -> void:
	is_open = false
	root.visible = false
	get_tree().paused = false


func _process(delta: float) -> void:
	flash_t = maxf(flash_t - delta, 0.0)
	if Input.is_action_just_pressed("build"):
		if is_open:
			close()
		else:
			open()
		return
	if not is_open:
		return
	if Input.is_action_just_pressed("menu_back"):
		close()
		return
	if Input.is_action_just_pressed("move_up"):
		selected = mini(selected + 1, build.slot_count() - 1)
	if Input.is_action_just_pressed("move_down"):
		selected = maxi(selected - 1, 0)
	if Input.is_action_just_pressed("move_left"):
		_cycle_blade(-1)
	if Input.is_action_just_pressed("move_right"):
		_cycle_blade(1)
	if Input.is_action_just_pressed("menu_rotate"):
		_cycle_grip(1)
	if Input.is_action_just_pressed("menu_next"):
		_cycle_fitting(1)
	if Input.is_action_just_pressed("menu_prev"):
		_cycle_fitting(-1)
	root.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_1:
			_load_test("A")
		elif k == KEY_2:
			_load_test("B")
	if event is InputEventMouseMotion:
		hover = _button_at(root.get_local_mouse_position())
		root.queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		var key := _button_at(root.get_local_mouse_position())
		if mb.button_index == MOUSE_BUTTON_LEFT and key != "":
			_click(key)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and key.begins_with("slot:"):
			selected = int(key.split(":")[1])
			_set_selected("")
		get_viewport().set_input_as_handled()
		root.queue_redraw()


func _click(key: String) -> void:
	var parts := key.split(":")
	match parts[0]:
		"slot":
			selected = int(parts[1])
		"fit":
			_set_selected(parts[1])
		"empty":
			_set_selected("")
		"blade":
			build.set_blade(parts[1])
			_changed()
		"grip":
			build.set_grip(parts[1])
			_changed()
		"test":
			_load_test(parts[1])
	Sfx.play(self, "click", -14.0)


func _set_selected(id: String) -> void:
	build.set_slot(selected, id)
	_changed()


func _changed() -> void:
	selected = clampi(selected, 0, build.slot_count() - 1)
	flash_t = 0.3


func _load_test(k: String) -> void:
	build.load_test(k)
	_changed()


func _cycle_fitting(step: int) -> void:
	var options: Array = [""] + SwingBuild.FITTING_ORDER
	var i := options.find(build.line[selected])
	_set_selected(options[posmod(i + step, options.size())])


func _cycle_blade(step: int) -> void:
	var i := SwingBuild.BLADE_ORDER.find(build.blade)
	build.set_blade(SwingBuild.BLADE_ORDER[posmod(i + step, SwingBuild.BLADE_ORDER.size())])
	_changed()


func _cycle_grip(step: int) -> void:
	var i := SwingBuild.GRIP_ORDER.find(build.grip)
	build.set_grip(SwingBuild.GRIP_ORDER[posmod(i + step, SwingBuild.GRIP_ORDER.size())])
	_changed()


func _button_at(m: Vector2) -> String:
	for k in buttons:
		if (buttons[k] as Rect2).has_point(m):
			return k
	return ""


# --- Drawing ----------------------------------------------------------------

func _draw_forge() -> void:
	buttons.clear()
	var font := ThemeDB.fallback_font
	var white := Color.WHITE
	var dim := Color(0.72, 0.75, 0.82)
	var gold := Color(1, 0.85, 0.45)
	root.draw_rect(Rect2(Vector2.ZERO, root.size), Color(0.05, 0.06, 0.09, 0.94))
	root.draw_string(font, Vector2(60, 52), "Forge: the swing path", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, white)
	root.draw_string(font, Vector2(60, 82), "Read the sword from the bottom of the grip to the tip. A band boosts the next rune above it; bands in a row stack.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, dim)

	var stats := build.compute()
	var info: Dictionary = stats["slot_info"]
	var effects: Array = stats["effects"]

	# The sword, big, with its slots.
	var rows := SwordArt.rows(build.grip)
	var top := SWORD_POS + Vector2(0, (8 - rows) * CELL * 0.5)
	root.draw_string(font, top + Vector2(0, -8), "TIP", HORIZONTAL_ALIGNMENT_CENTER, CELL * 3, 13, dim)
	SwordArt.draw(root, build.blade, build.grip, build.line, info, CELL, true, {selected: 0.0}, top)
	root.draw_string(font, top + Vector2(0, rows * CELL + 18), "GRIP END", HORIZONTAL_ALIGNMENT_CENTER, CELL * 3, 13, dim)

	# Slot labels to the right, with arrows from each band to the rune it boosts.
	for i in build.line.size():
		var c := top + SwordArt.slot_center(build.blade, build.grip, i) * CELL
		var r := Rect2(c - Vector2(CELL * 0.5, CELL * 0.5), Vector2(CELL, CELL))
		buttons["slot:%d" % i] = Rect2(r.position, Vector2(CELL + 250, CELL))
		if i == selected:
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
			root.draw_rect(r.grow(2), Color(1, 1, 1, pulse), false, 3.0)
		var id: String = build.line[i]
		var where := "grip" if i < build.grip_slots() else "blade"
		var label := "%d  %s:  " % [i + 1, where]
		var lx := top.x + CELL * 3 + 46
		var col := dim
		var what := "empty"
		if id != "":
			var f: Dictionary = SwingBuild.FITTINGS[id]
			what = str(f["name"])
			col = f["color"]
			var si: Dictionary = info.get(i, {})
			if si.has("band"):
				what += "  boosts %s" % SwingBuild.FITTINGS[effects[int(si["band"])]["id"]]["name"]
			elif si.has("unused"):
				what += "  (no rune above: does nothing)"
				col = Color(0.6, 0.5, 0.5)
		var hl := hover == "slot:%d" % i or i == selected
		root.draw_string(font, Vector2(lx, c.y + 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, white if hl else dim)
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		root.draw_string(font, Vector2(lx + lw, c.y + 6), what, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
	# Band -> rune arrows on the left side of the sword.
	for e in effects:
		var to := top + SwordArt.slot_center(build.blade, build.grip, int(e["slot"])) * CELL
		for s in e["band_slots"]:
			var from := top + SwordArt.slot_center(build.blade, build.grip, int(s)) * CELL
			var x := top.x - 14.0 - float(s) * 0.0
			var acol: Color = SwingBuild.FITTINGS["twice"]["color"]
			root.draw_polyline(PackedVector2Array([from - Vector2(CELL * 0.5, 0), Vector2(x, from.y), Vector2(x, to.y), to - Vector2(CELL * 0.5 + 4, 0)]), acol, 3.0)
			root.draw_colored_polygon(PackedVector2Array([to - Vector2(CELL * 0.5, 0), to - Vector2(CELL * 0.5 + 10, -6), to - Vector2(CELL * 0.5 + 10, 6)]), acol)

	# Middle: blade, grip, fittings.
	var y := 112.0
	root.draw_string(font, Vector2(LIST_X, y - 8), "Blade   left / right", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, dim)
	for id in SwingBuild.BLADE_ORDER:
		var b: Dictionary = SwingBuild.BLADES[id]
		y = _row(font, "blade:" + id, y, str(b["name"]), "%d slot%s" % [b["slots"], "" if b["slots"] == 1 else "s"], id == build.blade, Color(0.8, 0.85, 0.95))
	y += 30.0
	root.draw_string(font, Vector2(LIST_X, y - 8), "Grip   R / X", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, dim)
	for id in SwingBuild.GRIP_ORDER:
		var g: Dictionary = SwingBuild.GRIPS[id]
		y = _row(font, "grip:" + id, y, str(g["name"]), "%d slot%s" % [g["slots"], "" if g["slots"] == 1 else "s"], id == build.grip, Color(0.85, 0.7, 0.5))
	y += 30.0
	root.draw_string(font, Vector2(LIST_X, y - 8), "Fittings   Q / E", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, dim)
	for id in SwingBuild.FITTING_ORDER:
		var f: Dictionary = SwingBuild.FITTINGS[id]
		var kind := "rune" if f["kind"] == "rune" else "band"
		y = _row(font, "fit:" + id, y, "%s  (%s)" % [f["name"], kind], "", build.line[selected] == id, f["color"])
	y = _row(font, "empty", y, "Empty the slot", "", false, dim)

	# Right: test swords, then what the sword does.
	var p := Vector2(INFO_X, 118)
	root.draw_string(font, p + Vector2(0, -8), "Order test   1 / 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, dim)
	for k in ["A", "B"]:
		var t: Dictionary = SwingBuild.TEST_SWORDS[k]
		var names: Array = []
		for f in t["line"]:
			names.append(SwingBuild.FITTINGS[f]["name"])
		var r := Rect2(p, Vector2(INFO_W, 46))
		buttons["test:" + k] = r
		var active: bool = build.blade == t["blade"] and build.grip == t["grip"] and build.line == t["line"]
		root.draw_rect(r, Color(0.3, 0.26, 0.14) if active else (Color(0.2, 0.22, 0.29) if hover == "test:" + k else Color(0.12, 0.13, 0.18)))
		if active:
			root.draw_rect(r, gold, false, 2.0)
		root.draw_string(font, p + Vector2(12, 20), "Test sword " + k, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold if active else white)
		root.draw_string(font, p + Vector2(12, 38), " > ".join(names), HORIZONTAL_ALIGNMENT_LEFT, INFO_W - 20, 13, dim)
		p.y += 54
	p.y += 24
	root.draw_string(font, p, "What your sword does", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, white)
	p.y += 28
	var chain: Array = SwingBuild.BLADES[build.blade]["chain"]
	root.draw_string(font, p, "Chain:  %s  (finisher last)" % " > ".join(chain), HORIZONTAL_ALIGNMENT_LEFT, INFO_W, 15, gold)
	p.y += 26
	if effects.is_empty():
		root.draw_string(font, p, "No runes yet: it just swings.", HORIZONTAL_ALIGNMENT_LEFT, INFO_W, 15, dim)
		p.y += 24
	for e in effects:
		var col: Color = SwingBuild.FITTINGS[e["id"]]["color"]
		root.draw_multiline_string(font, p, SwingBuild.sentence(e), HORIZONTAL_ALIGNMENT_LEFT, INFO_W, 15, -1, col)
		p.y += 42 if font.get_string_size(SwingBuild.sentence(e), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > INFO_W else 24
	p.y += 8
	root.draw_string(font, p, "Damage %.0f    Attack speed x%.2f    Reach x%.2f" % [stats["damage"], stats["speed"], stats["reach"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, white)
	p.y += 22
	var el: Array = stats["elements"]
	if not el.is_empty():
		root.draw_string(font, p, "Element: " + str(el[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SwingBuild.ELEMENT_COLORS[el[0]])
	# Selected fitting's description.
	var sel_id: String = build.line[selected]
	var hover_id := hover.split(":")[1] if hover.begins_with("fit:") else sel_id
	if hover_id != "":
		root.draw_multiline_string(font, Vector2(INFO_X, 560), str(SwingBuild.FITTINGS[hover_id]["desc"]), HORIZONTAL_ALIGNMENT_LEFT, INFO_W, 15, -1, Color(0.85, 0.88, 0.95))

	var help := "Mouse: click a slot on the sword, then click a fitting. Right-click a slot to empty it.\nKeys / pad: up/down pick a slot, Q/E or LB/RB change its fitting, left/right change blade, R or X change grip, 1/2 test swords.   Tab or Y: back to the fight."
	root.draw_multiline_string(font, Vector2(60, root.size.y - 46), help, HORIZONTAL_ALIGNMENT_LEFT, root.size.x - 120, 13, -1, dim)


func _row(font: Font, key: String, y: float, title: String, sub: String, on: bool, col: Color) -> float:
	var r := Rect2(LIST_X, y, LIST_W, ROW - 4)
	buttons[key] = r
	var bg := Color(0.12, 0.13, 0.18)
	if hover == key:
		bg = Color(0.2, 0.22, 0.29)
	if on:
		bg = Color(0.26, 0.24, 0.16)
	root.draw_rect(r, bg)
	if on:
		root.draw_rect(r, Color(1, 0.85, 0.45), false, 2.0)
	root.draw_rect(Rect2(r.position, Vector2(5, r.size.y)), col)
	root.draw_string(font, Vector2(LIST_X + 14, y + 20), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	if sub != "":
		root.draw_string(font, Vector2(LIST_X + 140, y + 20), sub, HORIZONTAL_ALIGNMENT_RIGHT, LIST_W - 150, 12, Color(0.7, 0.72, 0.8))
	return y + ROW
