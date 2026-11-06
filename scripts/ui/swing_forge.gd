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

const TABS := ["blades", "grips", "runes", "bands", "rare"]
const LEFT := Rect2(10, 32, 195, 296)
const RIGHT := Rect2(436, 32, 194, 296)
const CENTRE_X := 322.0
const SWORD_BOTTOM := 298.0  # the pommel sits just above the anvil
var sword_bottom := SWORD_BOTTOM

var build: SwingBuild
var root: Control
var is_open := false
var selected := 0          # slot index, 0 = bottom of the grip
var tab := 2               # runes
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
var sword_size := Vector2.ZERO
var heat_mask: Control     # draws the sword; its child is clipped to the sword's pixels
var heat_fill: Control
var fx_top: Control
var banner: Control


func _ready() -> void:
	layer = 10
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
	build = b
	build.changed.connect(_on_changed)


## Every change is a hammer blow: the metal heats up, sparks fly, the anvil rings.
func _on_changed() -> void:
	if not is_open:
		return
	dirty = true
	heat = 1.0
	strike_t = 0.0
	var i := clampi(selected, 0, build.slot_count() - 1)
	strike_at = sword_top + SwordArt.slot_center(build.blade, build.grip, "forge", i)
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
	get_tree().paused = true


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
	get_tree().paused = false


# --- Input ------------------------------------------------------------------

func _process(delta: float) -> void:
	if is_open:
		_update_fx(delta)
	if Input.is_action_just_pressed("build"):
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
				if SwingBuild.FITTINGS[id]["kind"] == "rune" and not SwingBuild.FITTINGS[id].get("parked", false):
					out.append({"id": id, "name": SwingBuild.FITTINGS[id]["name"], "locked": false})
			out.append({"id": "lunge", "name": "Lunge", "locked": true})
		"bands":
			for id in SwingBuild.FITTING_ORDER:
				if SwingBuild.FITTINGS[id]["kind"] == "band":
					out.append({"id": id, "name": SwingBuild.FITTINGS[id]["name"], "locked": false})
		"rare":
			for id in SwingBuild.FITTING_ORDER:
				if SwingBuild.FITTINGS[id]["kind"] == "bender" and not SwingBuild.FITTINGS[id].get("parked", false):
					out.append({"id": id, "name": SwingBuild.FITTINGS[id]["name"], "locked": false})
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
	# One rule-bender per sword: fitting a new one takes the old one off.
	if SwingBuild.FITTINGS[id]["kind"] == "bender":
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


func _icon(kind: String, id: String, center: Vector2) -> void:
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
		var pitch := (LEFT.size.x - 12.0) / TABS.size()
		var r := Rect2(LEFT.position.x + 6 + i * pitch, LEFT.position.y + 26, pitch - 2.0, 14)
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
	if f["kind"] == "bender":
		return "Rule-bender, 1 per sword"
	return "Rune, " + {"finisher": "on the finisher", "hit": "every hit", "kill": "on a kill", "dodge_attack": "after a dodge"}[f["trigger"]]


func _desc(id: String) -> String:
	if SwingBuild.BLADES.has(id):
		return SwingBuild.BLADES[id]["desc"]
	if SwingBuild.GRIPS.has(id):
		return SwingBuild.GRIPS[id]["desc"]
	return SwingBuild.FITTINGS[id]["desc"]


func _boost_text(band: String, rune: String) -> String:
	match band:
		"twice":
			return {"shockwave": "two waves", "hook": "hooks twice", "shards": "two chains", "second_wind": "two dodges", "leap": "two jumps", "whirlwind": "two spins"}.get(rune, "twice")
		"wider":
			return {"shockwave": "a bigger wave", "hook": "reaches further", "shards": "jumps further", "second_wind": "pushes enemies away", "leap": "jumps further", "whirlwind": "a bigger circle"}.get(rune, "bigger")
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
			return "%s happens on every hit, at half strength." % rn
		"saved_up":
			return "%s happens every third time, three times as strong." % rn
		"on_dodge":
			return "%s also happens when you dodge." % rn
	return ""


func _draw_sword(stats: Dictionary) -> void:
	var blade := build.blade
	var grip := build.grip
	var size := SwordArt.frame_size(blade, grip, "forge")
	sword_bottom = maxf(SWORD_BOTTOM, size.y + 4.0)  # the longest swords push down a little
	var top := Vector2(CENTRE_X - size.x * 0.5, sword_bottom - size.y).round()
	sword_top = top
	sword_size = size
	# Backdrop: a plain, calm panel so the sword reads clearly. No fire.
	root.draw_rect(Rect2(244, 30, 156, 262), Color(0.07, 0.075, 0.095))
	root.draw_rect(Rect2(244, 30, 156, 262), Color(0.16, 0.17, 0.21), false, 1.0)
	var anvil := Art.texture("swing/ui/anvil.png")
	if anvil != null:
		root.draw_texture(anvil, Vector2(CENTRE_X - 47, sword_bottom - 2).round())
	SwordArt.draw(root, blade, grip, build.line, "forge", {}, top)
	# Grip-to-tip arrow up the left.
	var ax := 262.0
	for y in range(int(sword_bottom - 12), int(top.y + 14), -4):
		root.draw_rect(Rect2(ax, y, 1, 2), AMBER.darkened(0.3))
	root.draw_colored_polygon(PackedVector2Array([Vector2(ax + 0.5, top.y + 6), Vector2(ax - 3.5, top.y + 12), Vector2(ax + 4.5, top.y + 12)]), AMBER)
	_head("Tip", Vector2(ax - 10, top.y + 2), AMBER, 8, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_head("Grip", Vector2(ax - 12, sword_bottom - 4), AMBER, 8, 26, HORIZONTAL_ALIGNMENT_CENTER)
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
			tags.append("fires x%d%s" % [int(e["count"]), " max" if int(e["count"]) >= SwingBuild.MAX_COUNT else ""])
		if float(e["size"]) > 1.0:
			tags.append("max size" if float(e["size"]) >= SwingBuild.MAX_SIZE else "bigger")
		if e.get("ruby", false):
			tags.append("ruby x2")
		if int(e.get("every", 1)) > 1:
			tags.append("every 3rd")
		elif float(e.get("power", 1.0)) < 1.0:
			tags.append("every hit")
		if "dodge" in e.get("also", []):
			tags.append("+ dodge")
		for ti in tags.size():
			_head(tags[ti], Vector2(bx + 4, (y0 + y1) * 0.5 + 3 + (ti - (tags.size() - 1) * 0.5) * 10), TEAL)
	# Labels beside the sword, test swords left of the anvil, the dummy right of it.
	var g: Dictionary = SwingBuild.GRIPS[grip]
	var bl: Dictionary = SwingBuild.BLADES[blade]
	var lx := top.x + size.x + 6
	if finishing < 0.0:  # the "Forged!" banner sits here while it plays
		_head(bl["name"], Vector2(lx, top.y + 6), INK)
		_head("%d slot%s" % [bl["slots"], "" if bl["slots"] == 1 else "s"], Vector2(lx, top.y + 17), DIM)
		var bspd := float(bl["speed"])
		var bspd_word := "fast" if bspd >= 1.15 else ("slow" if bspd <= 0.85 else "normal speed")
		_head("damage %d" % int(bl["damage"]), Vector2(lx, top.y + 28), DIM)
		_head(bspd_word, Vector2(lx, top.y + 39), DIM)
	var gy := top.y + SwordArt.grip_origin(blade, "forge").y
	_head(g["name"], Vector2(lx, gy + 8), INK)
	var spd := float(stats["speed"])
	var spd_word := "quick" if spd >= 1.03 else ("steady" if spd >= 0.94 else "slow")
	_head("%d slot%s" % [g["slots"], "" if g["slots"] == 1 else "s"], Vector2(lx, gy + 19), DIM)
	_head("Test", Vector2(214, 311), DIM, 8, 56, HORIZONTAL_ALIGNMENT_CENTER)
	for k in ["A", "B"]:
		var tt: Dictionary = SwingBuild.TEST_SWORDS[k]
		var r := Rect2(214 + (0 if k == "A" else 30), 313, 26, 14)
		buttons["test:" + k] = r
		var active: bool = blade == tt["blade"] and grip == tt["grip"] and build.line == tt["line"]
		if active:
			root.draw_rect(r, AMBER.darkened(0.25))
		else:
			_nine("button_hot" if hover == "test:" + k else "button", r)
		_head(k, r.position + Vector2(0, 10), Color(0.1, 0.07, 0.03) if active else INK, 8, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_head("Dummy", Vector2(372, 310), DIM, 8, 56, HORIZONTAL_ALIGNMENT_CENTER)
	var tr := Rect2(372, 313, 56, 14)
	buttons["try"] = tr
	_nine("button_hot" if hover == "try" else "button", tr)
	_head("T  Try", tr.position + Vector2(0, 10), INK, 8, tr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


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
		SwordArt.draw(heat_mask, build.blade, build.grip, build.line, "forge", {}, sword_top)


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
		var blade_pos := sword_top + Vector2(4.0 * 3.0, 0)
		var bsize := SwordArt.blade_size(build.blade, "forge")
		# Heat cools from white-hot to steel, then a glint sweeps up the blade.
		var heat_k := (finishing - 0.1) * 10.0
		if finishing >= 0.1 and heat_k < 8.0:
			var hf := mini(int(heat_k), 7)
			banner.draw_texture_rect_region(heat_tex, Rect2(blade_pos, bsize), Rect2(hf * bsize.x, 0, bsize.x, bsize.y))
		var shine_tex := Art.texture("swing/forge-fx/shine_%s.png" % build.blade)
		var shine_k := (finishing - 0.9) * 16.0
		if shine_tex != null and finishing >= 0.9 and shine_k < 8.0:
			banner.draw_texture_rect_region(shine_tex, Rect2(blade_pos, bsize), Rect2(mini(int(shine_k), 7) * bsize.x, 0, bsize.x, bsize.y))
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
			var kind: String = SwingBuild.FITTINGS[id]["kind"]
			if si.has("unused"):
				text = str(si.get("why", "It does nothing here."))
				bar = FAINT
			elif id == "mirror":
				bar = SwingBuild.FITTINGS["mirror"]["color"]
				if si.has("rune"):
					text = "Copies %s: " % SwingBuild.FITTINGS[effects[int(si["rune"])]["id"]]["name"] + SwingBuild.sentence(effects[int(si["rune"])]).substr(0, 1).to_lower() + SwingBuild.sentence(effects[int(si["rune"])]).substr(1)
				elif si.has("band"):
					var e: Dictionary = effects[int(si["band"])]
					text = "Copies the band below. " + _band_line(str(e["bands"][-1]), e["id"])
			elif id == "relay":
				bar = SwingBuild.FITTINGS["relay"]["color"]
				var e: Dictionary = effects[int(si["band"])]
				text = "Hands the bands below on to %s too." % SwingBuild.FITTINGS[e["id"]]["name"]
			elif kind == "band":
				bar = TEAL
				var e: Dictionary = effects[int(si["band"])]
				text = _band_line(id, e["id"])
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
