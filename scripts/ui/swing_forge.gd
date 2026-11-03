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

const INK := Color("#e6dccb")
const DIM := Color("#8e877b")
const FAINT := Color("#5a5650")
const AMBER := Color("#ffb24a")
const TEAL := Color("#6fd6cb")
const FOCUS := Color("#fff3c4")
const PLATE := Color("#14171d")
const WELL := Color("#0b0d11")

const TABS := ["blades", "grips", "runes", "bands"]
const LEFT := Rect2(10, 32, 195, 296)
const RIGHT := Rect2(436, 32, 194, 296)
const CENTRE_X := 322.0
const SWORD_BOTTOM := 236.0

var build: SwingBuild
var root: Control
var is_open := false
var selected := 0          # slot index, 0 = bottom of the grip
var tab := 2               # runes
var card := 0              # keyboard cursor in the tray
var hover := ""
var buttons := {}          # key -> Rect2, rebuilt every draw
var _styles := {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.size = Vector2(640, 360)
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


# --- Input ------------------------------------------------------------------

func _process(_delta: float) -> void:
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
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_1: _load_test("A")
			KEY_2: _load_test("B")
			KEY_T: _try()
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
			_put("")
		get_viewport().set_input_as_handled()
		root.queue_redraw()


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


## The cards on the current tab: [{id, name, locked}]
func _cards() -> Array:
	var out: Array = []
	match TABS[tab]:
		"blades":
			for id in SwingBuild.BLADE_ORDER:
				out.append({"id": id, "name": SwingBuild.BLADES[id]["name"], "locked": false})
		"grips":
			for id in SwingBuild.GRIP_ORDER:
				out.append({"id": id, "name": SwingBuild.GRIPS[id]["name"], "locked": SwingBuild.GRIPS[id].get("locked", false)})
		"runes":
			for id in SwingBuild.FITTING_ORDER:
				if SwingBuild.FITTINGS[id]["kind"] == "rune":
					out.append({"id": id, "name": SwingBuild.FITTINGS[id]["name"], "locked": false})
			out.append({"id": "lunge", "name": "Lunge", "locked": true})
		"bands":
			for id in SwingBuild.FITTING_ORDER:
				if SwingBuild.FITTINGS[id]["kind"] == "band":
					out.append({"id": id, "name": SwingBuild.FITTINGS[id]["name"], "locked": false})
			out.append({"id": "", "name": "", "locked": true})
	return out


func _use_card(i: int) -> void:
	var cards := _cards()
	if i < 0 or i >= cards.size() or cards[i]["locked"]:
		return
	var id: String = cards[i]["id"]
	match TABS[tab]:
		"blades":
			build.set_blade(id)
		"grips":
			build.set_grip(id)
		_:
			_put(id)
	selected = clampi(selected, 0, build.slot_count() - 1)


func _put(id: String) -> void:
	build.set_slot(selected, id)


func _load_test(k: String) -> void:
	build.load_test(k)
	selected = clampi(selected, 0, build.slot_count() - 1)


func _try() -> void:
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


func _icon(kind: String, id: String, center: Vector2) -> void:
	match kind:
		"runes", "bands":
			var tex := Art.texture("swing/%s/%s_icon.png" % [kind, id])
			if tex != null:
				root.draw_texture(tex, (center - tex.get_size() * 0.5).round())
		"blades", "grips":
			# The in-hand sprite at 2x, lying on its side, tip to the right.
			var tex := Art.texture("swing/%s/%s_hand.png" % [kind, id])
			if tex != null:
				root.draw_set_transform(center, PI * 0.5, Vector2(2, 2))
				root.draw_texture(tex, (-tex.get_size() * 0.5).round())
				root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- The screen ---------------------------------------------------------------

func _draw_forge() -> void:
	buttons.clear()
	root.draw_rect(Rect2(Vector2.ZERO, root.size), Color(0.035, 0.04, 0.055, 1.0))
	_head("The forge", Vector2(14, 22), AMBER, 16)
	_body("Read the sword from the grip up.", Vector2(134, 20), DIM)
	var stats := build.compute()
	_draw_tray()
	_draw_sword(stats)
	_draw_does(stats)
	_draw_keys()


func _draw_tray() -> void:
	_nine("panel_titled", LEFT)
	root.draw_rect(Rect2(LEFT.position + Vector2(10, 9), Vector2(2, 9)), AMBER)
	_head("Parts", LEFT.position + Vector2(16, 17))
	# Tabs
	for i in TABS.size():
		var r := Rect2(LEFT.position.x + 6 + i * 46, LEFT.position.y + 26, 44, 14)
		buttons["tab:%d" % i] = r
		if i == tab:
			root.draw_rect(r, Color(0.16, 0.18, 0.23))
			root.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), INK)
		_head(TABS[i], r.position + Vector2(0, 10), INK if i == tab else (FOCUS if hover == "tab:%d" % i else DIM), 8, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# Cards
	var cards := _cards()
	card = clampi(card, 0, maxi(cards.size() - 1, 0))
	for i in cards.size():
		var c: Dictionary = cards[i]
		var r := Rect2(LEFT.position.x + 6 + (i % 3) * 61, LEFT.position.y + 44 + (i / 3) * 52, 58, 49)
		buttons["card:%d" % i] = r
		var on_sword := _on_sword(c["id"])
		_nine("well_selected" if i == card else "well", r)
		if c["locked"]:
			var lock := Art.texture("swing/ui/padlock.png")
			if lock != null:
				root.draw_texture(lock, (r.get_center() - Vector2(3.5, 9)).round())
			if c["name"] != "":
				_head(c["name"], r.position + Vector2(0, 44), FAINT, 8, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			continue
		_icon(TABS[tab], c["id"], r.position + Vector2(29, 20))
		var label_col := AMBER if i == card else (FOCUS if hover == "card:%d" % i else INK)
		_head(_short(c["name"]), r.position + Vector2(0, 44), label_col, 8, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if on_sword:
			root.draw_rect(Rect2(r.end.x - 10, r.position.y + 3, 7, 7), AMBER)
			root.draw_polyline(PackedVector2Array([r.end - Vector2(8.5, 42), r.end - Vector2(7, 40.5), r.end - Vector2(4.5, 44)]), Color(0.1, 0.07, 0.03), 1.0)
	# Details for the hovered card, or the keyboard card.
	var di := card
	if hover.begins_with("card:"):
		di = int(hover.split(":")[1])
	var box := Rect2(LEFT.position.x + 6, LEFT.position.y + 152, LEFT.size.x - 12, LEFT.size.y - 158)
	_nine("well", box)
	if di < cards.size() and not cards[di]["locked"]:
		var c: Dictionary = cards[di]
		_icon(TABS[tab], c["id"], box.position + Vector2(18, 18))
		_head(c["name"], box.position + Vector2(36, 15), AMBER)
		_head(_kind_line(c["id"]), box.position + Vector2(36, 27), DIM)
		var y := box.position.y + 48
		for l in _wrap(_desc(c["id"]), box.size.x - 12):
			_body(l, Vector2(box.position.x + 6, y))
			y += 13
		if TABS[tab] == "runes":
			y += 4
			root.draw_rect(Rect2(box.position.x + 6, y - 6, box.size.x - 12, 1), FAINT)
			_head("A band below boosts it", Vector2(box.position.x + 6, y + 4), TEAL)
			y += 16
			for band in ["twice", "wider"]:
				root.draw_rect(Rect2(box.position.x + 6, y - 5, 6, 2), TEAL)
				_body("%s: %s" % [SwingBuild.FITTINGS[band]["name"], _boost_text(band, c["id"])], Vector2(box.position.x + 16, y), INK)
				y += 13
		var br := Rect2(box.position.x + 6, box.end.y - 22, box.size.x - 12, 16)
		buttons["use"] = br
		_nine("button_hot" if hover == "use" else "button", br)
		var verb := "Put in slot %d" % (selected + 1)
		if TABS[tab] == "blades":
			verb = "Use this blade"
		elif TABS[tab] == "grips":
			verb = "Use this grip"
		_head("Enter  " + verb, br.position + Vector2(0, 11), Color(0.1, 0.07, 0.03) if hover == "use" else INK, 8, br.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _short(name: String) -> String:
	return name.replace("Iron ", "").replace(" Grip", "").replace("Second Wind", "2nd Wind")


func _on_sword(id: String) -> bool:
	return id != "" and (id == build.blade or id == build.grip or id in build.line)


func _kind_line(id: String) -> String:
	if SwingBuild.BLADES.has(id):
		var b: Dictionary = SwingBuild.BLADES[id]
		return "Blade, %d slot%s" % [b["slots"], "" if b["slots"] == 1 else "s"]
	if SwingBuild.GRIPS.has(id):
		var g: Dictionary = SwingBuild.GRIPS[id]
		return "Grip, %d slot%s" % [g["slots"], "" if g["slots"] == 1 else "s"]
	var f: Dictionary = SwingBuild.FITTINGS[id]
	if f["kind"] == "band":
		return "Band"
	return "Rune, " + {"finisher": "on the finisher", "hit": "every hit", "kill": "on a kill"}[f["trigger"]]


func _desc(id: String) -> String:
	if SwingBuild.BLADES.has(id):
		return SwingBuild.BLADES[id]["desc"]
	if SwingBuild.GRIPS.has(id):
		return SwingBuild.GRIPS[id]["desc"]
	return SwingBuild.FITTINGS[id]["desc"]


func _boost_text(band: String, rune: String) -> String:
	if band == "twice":
		return {"shockwave": "two waves", "hook": "hooks twice", "cleave": "two behind", "second_wind": "two dodges"}.get(rune, "twice")
	return {"shockwave": "a bigger wave", "hook": "reaches further", "cleave": "further back", "second_wind": "pushes enemies away"}.get(rune, "bigger")


func _draw_sword(stats: Dictionary) -> void:
	var blade := build.blade
	var grip := build.grip
	var size := SwordArt.frame_size(blade, grip, "forge")
	var top := Vector2(CENTRE_X - size.x * 0.5, SWORD_BOTTOM - size.y).round()
	# Backdrop and anvil.
	root.draw_rect(Rect2(244, 30, 156, 240), Color(0.05, 0.055, 0.075))
	root.draw_rect(Rect2(244, 30, 156, 240), Color(0.12, 0.13, 0.17), false, 1.0)
	var anvil := Art.texture("swing/ui/anvil.png")
	if anvil != null:
		root.draw_texture(anvil, Vector2(CENTRE_X - 47, SWORD_BOTTOM - 6).round())
	SwordArt.draw(root, blade, grip, build.line, "forge", {}, top)
	# Grip-to-tip arrow up the left.
	var ax := 262.0
	for y in range(int(SWORD_BOTTOM - 20), int(top.y + 14), -4):
		root.draw_rect(Rect2(ax, y, 1, 2), AMBER.darkened(0.3))
	root.draw_colored_polygon(PackedVector2Array([Vector2(ax + 0.5, top.y + 6), Vector2(ax - 3.5, top.y + 12), Vector2(ax + 4.5, top.y + 12)]), AMBER)
	_head("Tip", Vector2(ax - 10, top.y + 2), AMBER, 8, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_head("Grip", Vector2(ax - 12, SWORD_BOTTOM - 8), AMBER, 8, 26, HORIZONTAL_ALIGNMENT_CENTER)
	# Slots: numbers on the left, clickable sockets, focus corners on the selected one.
	var info: Dictionary = stats["slot_info"]
	for i in build.line.size():
		var r := SwordArt.slot_rect(blade, grip, "forge", i)
		r.position += top
		buttons["slot:%d" % i] = r.grow(3)
		var cy := r.get_center().y
		_head(str(i + 1), Vector2(ax + 8, cy + 3), INK if i == selected else TEAL.darkened(0.2))
		for x in range(int(ax + 18), int(r.position.x - 4), 3):
			root.draw_rect(Rect2(x, cy, 1, 1), FAINT)
		if build.line[i] == "":
			root.draw_rect(r.grow(-2), Color(0.02, 0.02, 0.03, 0.9))
		if hover == "slot:%d" % i:
			root.draw_rect(r.grow(2), Color(1, 1, 1, 0.5), false, 1.0)
		if i == selected:
			_nine("focus_corners", r.grow(4))
	# Brackets on the right: each band to the rune it boosts.
	var bx := top.x + size.x + 6
	for e in stats["effects"]:
		if (e["band_slots"] as Array).is_empty():
			continue
		var y0 := top.y + SwordArt.slot_rect(blade, grip, "forge", int(e["slot"])).position.y
		var y1 := top.y + SwordArt.slot_rect(blade, grip, "forge", int(e["band_slots"][0])).end.y
		root.draw_rect(Rect2(bx, y0, 1, y1 - y0), TEAL)
		root.draw_rect(Rect2(bx - 3, y0, 4, 1), TEAL)
		root.draw_rect(Rect2(bx - 3, y1 - 1, 4, 1), TEAL)
		root.draw_rect(Rect2(bx - 6, y0 - 2, 4, 1), TEAL)
		var tags: Array = []
		if int(e["count"]) > 1:
			tags.append("x%d" % int(e["count"]))
		if float(e["size"]) > 1.0:
			tags.append("big")
		_head(" ".join(tags), Vector2(bx + 4, (y0 + y1) * 0.5 + 3), TEAL)
	# Name, slots, test swords and the dummy.
	var g: Dictionary = SwingBuild.GRIPS[grip]
	_head("%s  +  %s" % [SwingBuild.BLADES[blade]["name"], g["name"]], Vector2(222, 284), INK, 8, 200, HORIZONTAL_ALIGNMENT_CENTER)
	var spd := float(stats["speed"])
	var spd_word := "quick" if spd >= 1.03 else ("steady" if spd >= 0.94 else "slow")
	_head("%d slots, speed %s" % [build.slot_count(), spd_word], Vector2(222, 295), DIM, 8, 200, HORIZONTAL_ALIGNMENT_CENTER)
	_head("Test swords  1 / 2", Vector2(222, 307), DIM, 8, 200, HORIZONTAL_ALIGNMENT_CENTER)
	for k in ["A", "B"]:
		var t: Dictionary = SwingBuild.TEST_SWORDS[k]
		var r := Rect2(CENTRE_X - 48 + (0 if k == "A" else 50), 310, 46, 13)
		buttons["test:" + k] = r
		var active: bool = blade == t["blade"] and grip == t["grip"] and build.line == t["line"]
		if active:
			root.draw_rect(r, AMBER.darkened(0.25))
		else:
			_nine("button_hot" if hover == "test:" + k else "button", r)
		_head(k, r.position + Vector2(0, 10), Color(0.1, 0.07, 0.03) if active else INK, 8, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var tr := Rect2(CENTRE_X - 60, 326, 120, 14)
	buttons["try"] = tr
	_nine("button_hot" if hover == "try" else "button", tr)
	_head("T  Try at the dummy", tr.position + Vector2(0, 10), INK, 8, tr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_does(stats: Dictionary) -> void:
	_nine("panel_titled", RIGHT)
	root.draw_rect(Rect2(RIGHT.position + Vector2(10, 9), Vector2(2, 9)), AMBER)
	_head("What this sword does", RIGHT.position + Vector2(16, 17))
	_head("From the grip up", RIGHT.position + Vector2(10, 36), AMBER)
	var effects: Array = stats["effects"]
	var info: Dictionary = stats["slot_info"]
	var w := RIGHT.size.x - 20
	var y := RIGHT.position.y + 42
	var summary := _finisher_summary(effects)
	var summary_lines := _wrap(summary, w - 4)
	var bottom := RIGHT.end.y - 22 - summary_lines.size() * 13
	for i in build.line.size():
		var id: String = build.line[i]
		var title := "%d  %s" % [i + 1, "empty" if id == "" else SwingBuild.FITTINGS[id]["name"]]
		var text := "Empty slot."
		var bar := FAINT
		var si: Dictionary = info.get(i, {})
		if id != "":
			if SwingBuild.FITTINGS[id]["kind"] == "band":
				bar = TEAL
				if si.has("band"):
					var e: Dictionary = effects[int(si["band"])]
					var rn: String = SwingBuild.FITTINGS[e["id"]]["name"]
					text = ("%s fires twice." % rn) if id == "twice" else ("%s %s." % [rn, _boost_text("wider", e["id"])])
				else:
					text = "No rune above it, so it does nothing."
					bar = FAINT
			else:
				bar = AMBER
				text = SwingBuild.sentence(effects[int(si["rune"])])
		var lines := _wrap(text, w - 14)
		var h := 15.0 + lines.size() * 12.0
		if y + h > bottom - 6:
			lines = [lines[0] + "..."]
			h = 27.0
		var r := Rect2(RIGHT.position.x + 8, y, w + 4, h)
		_nine("well", r)
		root.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), bar)
		if i == selected:
			root.draw_rect(r, FOCUS, false, 1.0)
		buttons["slot:%d" % i] = buttons.get("slot:%d" % i, r)
		buttons["row:%d" % i] = r
		_head(title, r.position + Vector2(8, 10), bar if id != "" else DIM)
		var ly := r.position.y + 22
		for l in lines:
			_body(l, Vector2(r.position.x + 8, ly), INK if id != "" else DIM)
			ly += 12
		y += h + 3
	root.draw_rect(Rect2(RIGHT.position.x + 8, bottom - 4, w + 4, 1), FAINT)
	_head("On the finisher", Vector2(RIGHT.position.x + 10, bottom + 6), AMBER)
	var sy := bottom + 19
	for l in summary_lines:
		_body(l, Vector2(RIGHT.position.x + 10, sy))
		sy += 13


## One plain line for everything that happens on the finisher, in order.
func _finisher_summary(effects: Array) -> String:
	var parts: Array = []
	for e in effects:
		if e["trigger"] != "finisher":
			continue
		var n: int = e["count"]
		var big := "big " if float(e["size"]) > 1.0 else ""
		match str(e["id"]):
			"shockwave":
				parts.append(("a %sshockwave rolls out" % big) if n == 1 else ("%s %sshockwaves roll out" % [SwingBuild._num(n), big]))
			"hook":
				parts.append(("a %shook yanks enemies in" % big) if n == 1 else ("%s %shooks yank enemies in" % [SwingBuild._num(n), big]))
	if parts.is_empty():
		return "Just the heavy hit. Add Shockwave or Hook to make it count."
	var s := ", then ".join(parts) + "."
	return s.substr(0, 1).to_upper() + s.substr(1)


func _draw_keys() -> void:
	var x := 22.0
	for pair in [["LMB", "place"], ["RMB", "take off"], ["W S", "slot up / down"], ["Q E", "tabs"], ["1 2", "test swords"], ["Tab", "leave"]]:
		var f := Art.font("Silkscreen-Regular")
		var kw := f.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8
		var kr := Rect2(x, 343, kw, 12)
		_nine("button", kr)
		_head(pair[0], kr.position + Vector2(0, 9), INK, 8, kw, HORIZONTAL_ALIGNMENT_CENTER)
		x += kw + 4
		_head(pair[1], Vector2(x, 352), DIM)
		x += f.get_string_size(pair[1].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 14
