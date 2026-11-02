extends CanvasLayer

const PartData := preload("res://scripts/parts/part_data.gd")
const WeaponBuild := preload("res://scripts/weapon/weapon_build.gd")
const Art := preload("res://scripts/art.gd")
## The crafting table: fit parts onto the weapon's grid.
## Free to swap. Pauses the game while open.

const CELL := 72.0  # 36 screen pixels: grid sprites are 18 px per cell, drawn at 2x
const GRID_POS := Vector2(150, 118)
const INV_POS := Vector2(430, 124)
const INV_ROW := 44.0
const INV_W := 360.0
const INFO_POS := Vector2(850, 120)
const INFO_W := 400.0

var build: WeaponBuild
var all_parts: Array = []
var root: Control
var is_open := false
var held: PartData = null
var held_rot := 0
var cursor := Vector2i(1, 3)
var hover_inv := -1
var message := ""


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	# Laid out at 1280x720 and drawn at half scale on the 640x360 screen.
	scale = Vector2(0.5, 0.5)
	root.size = Vector2(1280, 720)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)
	root.draw.connect(_draw_menu)


func setup(b: WeaponBuild, parts: Array) -> void:
	build = b
	all_parts = parts


func inventory() -> Array:
	var out: Array = []
	for p in all_parts:
		if p == held or build.has_part(p):
			continue
		out.append(p)
	return out


func open() -> void:
	is_open = true
	root.visible = true
	message = ""
	get_tree().paused = true


func close() -> void:
	held = null  # anything in hand goes back to the parts list
	is_open = false
	root.visible = false
	get_tree().paused = false


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
		if held != null:
			held = null
		else:
			close()
			return

	var mv := Vector2i.ZERO
	if Input.is_action_just_pressed("move_left"):
		mv.x -= 1
	if Input.is_action_just_pressed("move_right"):
		mv.x += 1
	if Input.is_action_just_pressed("move_up"):
		mv.y -= 1
	if Input.is_action_just_pressed("move_down"):
		mv.y += 1
	if mv != Vector2i.ZERO:
		cursor = Vector2i(clampi(cursor.x + mv.x, 0, WeaponBuild.GRID_W - 1), clampi(cursor.y + mv.y, 0, WeaponBuild.GRID_H - 1))

	if Input.is_action_just_pressed("menu_place"):
		_act_on_cursor()
	if Input.is_action_just_pressed("menu_rotate"):
		_rotate()
	if Input.is_action_just_pressed("menu_next"):
		_cycle(1)
	if Input.is_action_just_pressed("menu_prev"):
		_cycle(-1)
	root.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		var m := root.get_local_mouse_position()
		var c := _cell_at(m)
		if c.x >= 0:
			cursor = c
		hover_inv = _inv_at(m)
		root.queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		var m := root.get_local_mouse_position()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var inv := inventory()
			var i := _inv_at(m)
			var c := _cell_at(m)
			if i >= 0 and i < inv.size():
				held = inv[i]
				held_rot = 0
				message = ""
			elif c.x >= 0:
				cursor = c
				_act_on_cursor()
			else:
				held = null
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_rotate()
		get_viewport().set_input_as_handled()
		root.queue_redraw()


func _act_on_cursor() -> void:
	if held != null:
		var problem := build.place_problem(held, cursor, held_rot)
		if problem == "" and build.place(held, cursor, held_rot):
			held = null
			message = ""
		else:
			message = problem
	else:
		var pl := build.remove_at(cursor)
		if not pl.is_empty():
			held = pl["part"]
			held_rot = pl["rotation"]
			message = ""


func _rotate() -> void:
	if held != null:
		held_rot = (held_rot + 1) % 4


func _cycle(step: int) -> void:
	var options: Array = []
	for p in all_parts:
		if not build.has_part(p):
			options.append(p)
	if options.is_empty():
		return
	var idx := options.find(held)
	if idx < 0:
		idx = 0 if step > 0 else options.size() - 1
	else:
		idx = posmod(idx + step, options.size())
	held = options[idx]
	held_rot = 0


func _cell_at(m: Vector2) -> Vector2i:
	var local := (m - GRID_POS) / CELL
	if local.x < 0 or local.y < 0 or local.x >= WeaponBuild.GRID_W or local.y >= WeaponBuild.GRID_H:
		return Vector2i(-1, -1)
	return Vector2i(int(local.x), int(local.y))


func _inv_at(m: Vector2) -> int:
	if m.x < INV_POS.x or m.x > INV_POS.x + INV_W or m.y < INV_POS.y:
		return -1
	var i := int((m.y - INV_POS.y) / INV_ROW)
	if i >= inventory().size():
		return -1
	return i


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(GRID_POS + Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-3.0)


# --- Drawing ----------------------------------------------------------------

func _draw_menu() -> void:
	var font := ThemeDB.fallback_font
	var white := Color.WHITE
	var dim := Color(0.72, 0.75, 0.82)
	root.draw_rect(Rect2(Vector2.ZERO, root.size), Color(0.05, 0.06, 0.09, 0.93))
	root.draw_string(font, Vector2(60, 60), "Forge: your sword", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, white)
	root.draw_string(font, Vector2(60, 88), "Each part has its own spot. Combo: pommel move, then handle move, then hilt move. Several small blades can share the blade area.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, dim)

	# Grid
	root.draw_string(font, GRID_POS + Vector2(0, -10), "TIP", HORIZONTAL_ALIGNMENT_CENTER, CELL * WeaponBuild.GRID_W, 14, dim)
	root.draw_string(font, GRID_POS + Vector2(0, CELL * WeaponBuild.GRID_H + 20), "POMMEL", HORIZONTAL_ALIGNMENT_CENTER, CELL * WeaponBuild.GRID_W, 14, dim)
	var zone_tint := {"blade": Color(0.24, 0.3, 0.42), "hilt": Color(0.4, 0.3, 0.2), "handle": Color(0.34, 0.24, 0.32), "charm": Color(0.2, 0.34, 0.28), "pommel": Color(0.38, 0.26, 0.2)}
	var held_zone := WeaponBuild.zone_for(held) if held != null else ""
	for y in WeaponBuild.GRID_H:
		for x in WeaponBuild.GRID_W:
			var zone := WeaponBuild.zone_at(Vector2i(x, y))
			if zone == "":
				continue  # not part of the sword
			var tint: Color = zone_tint[zone]
			if held != null and held_zone != "" and held_zone != zone:
				tint = tint.darkened(0.65)  # the part in hand can't go here
			var cr := _cell_rect(Vector2i(x, y))
			root.draw_rect(cr, tint)
			root.draw_rect(cr, tint.lightened(0.25), false, 1.0)
			if build.placement_at(Vector2i(x, y)).is_empty():
				root.draw_string(font, cr.position + Vector2(0, cr.size.y * 0.5 + 4), zone, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 10, tint.lightened(0.45))

	# Placed parts. Pommel, handle and hilt get their combo number (1, 2, 3).
	var combo_number := {PartData.PartType.POMMEL: 1, PartData.PartType.HANDLE: 2, PartData.PartType.HILT: 3}
	for pl in build.placements:
		var part: PartData = pl["part"]
		var tex := Art.part_grid(part.id)
		if tex != null and pl["rotation"] == 0:
			root.draw_texture_rect(tex, _cells_rect(pl["cells"]), false)
		else:
			for c in pl["cells"]:
				_draw_part_cell(part, Rect2(GRID_POS + Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-1.0), pl["cells"], c)
		if combo_number.has(part.part_type):
			var key: Vector2i = WeaponBuild._order_key(pl["cells"])
			var kr := _cell_rect(key)
			root.draw_circle(kr.position + Vector2(13, 13), 10.0, Color(0, 0, 0, 0.65))
			root.draw_string(font, kr.position + Vector2(3, 18), str(combo_number[part.part_type]), HORIZONTAL_ALIGNMENT_CENTER, 20, 14, white)

	# Held part ghost
	if held != null:
		var ok := build.can_place(held, cursor, held_rot)
		var edge := Color(0.4, 1.0, 0.5) if ok else Color(1.0, 0.3, 0.3)
		for c in build.cells_for(held, cursor, held_rot):
			var gr := _cell_rect(c)
			var fill := held.color
			fill.a = 0.6
			root.draw_rect(gr, fill)
			root.draw_rect(gr, edge, false, 3.0)
	root.draw_rect(_cell_rect(cursor).grow(2.0), Color(1, 1, 1, 0.9), false, 3.0)

	if message != "":
		root.draw_multiline_string(font, Vector2(INFO_POS.x, 600), message, HORIZONTAL_ALIGNMENT_LEFT, INFO_W, 15, -1, Color(1, 0.6, 0.5))

	# Parts list
	root.draw_string(font, INV_POS + Vector2(0, -12), "Parts (click or Q/E, LB/RB)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, dim)
	var inv := inventory()
	for i in inv.size():
		var part: PartData = inv[i]
		var row := Rect2(INV_POS + Vector2(0, i * INV_ROW), Vector2(INV_W, INV_ROW - 6))
		root.draw_rect(row, Color(0.2, 0.22, 0.29) if i == hover_inv else Color(0.12, 0.13, 0.18))
		_draw_mini_shape(part, row.position + Vector2(8, 5), 0, 9.0)
		root.draw_string(font, row.position + Vector2(50, 16), "%s   %s" % [part.display_name, _kind_text(part)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, white)
		root.draw_string(font, row.position + Vector2(50, 32), part.description, HORIZONTAL_ALIGNMENT_LEFT, INV_W - 56, 12, dim)
	if inv.is_empty():
		root.draw_string(font, INV_POS + Vector2(0, 20), "Everything is on the sword.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, dim)

	_draw_info(font, white, dim)

	# Controls
	var help := "Mouse: click a part, click the grid to place it, right-click to rotate, click a placed part to pick it up.\nKeys / pad: arrows or d-pad move, Q/E or LB/RB choose a part, Enter or A place / pick up, R or X rotate, Esc or B put back.   Tab or Y: back to the fight."
	root.draw_multiline_string(font, Vector2(60, root.size.y - 46), help, HORIZONTAL_ALIGNMENT_LEFT, root.size.x - 120, 13, -1, dim)


func _kind_text(part: PartData) -> String:
	if part.material == "":
		return part.type_name()
	return "%s, %s" % [part.type_name(), part.material]


func _draw_mini_shape(part: PartData, pos: Vector2, rot: int, s: float = 12.0) -> void:
	var cells := WeaponBuild.rotated_shape(part.shape, rot)
	var tex := Art.part_grid(part.id)
	if tex != null and rot == 0:
		root.draw_texture_rect(tex, _cells_rect(cells, pos, s), false)
		return
	for c in cells:
		var v: Vector2i = c
		_draw_part_cell(part, Rect2(pos + Vector2(v) * s, Vector2(s, s)), cells, v)


## Bounding box of some cells, in grid-screen space or at pos with cell size s.
func _cells_rect(cells: Array, pos: Vector2 = GRID_POS, s: float = CELL) -> Rect2:
	var lo := Vector2i(999, 999)
	var hi := Vector2i(-999, -999)
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Rect2(pos + Vector2(lo) * s, Vector2(hi - lo + Vector2i.ONE) * s)


## Stand-in for a part sprite: one bevelled block per cell, joined to the
## part's other cells so a part reads as one piece.
func _draw_part_cell(part: PartData, r: Rect2, cells: Array, c: Vector2i) -> void:
	var g := maxf(r.size.x * 0.06, 1.0)
	var inner := r
	var face := r
	for side in [[SIDE_LEFT, Vector2i(-1, 0)], [SIDE_RIGHT, Vector2i(1, 0)], [SIDE_TOP, Vector2i(0, -1)], [SIDE_BOTTOM, Vector2i(0, 1)]]:
		if not cells.has(c + side[1]):
			inner = inner.grow_side(side[0], -g)
			face = face.grow_side(side[0], -g * 2.0)
	root.draw_rect(inner, part.color.darkened(0.35))
	root.draw_rect(face, part.color)
	if not cells.has(c + Vector2i(0, -1)):
		root.draw_rect(Rect2(face.position, Vector2(face.size.x, g)), part.color.lightened(0.3))


func _draw_info(font: Font, white: Color, dim: Color) -> void:
	var stats := build.compute()
	var p := INFO_POS
	var gold := Color(1, 0.85, 0.45)
	root.draw_string(font, p, "Your combo", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, white)
	p.y += 28
	var steps: Array = stats["steps"]
	for i in steps.size():
		var finisher := "   (finisher)" if i == steps.size() - 1 and steps.size() > 1 else ""
		root.draw_string(font, p, "%d.  %s  %s%s" % [i + 1, steps[i]["from"], steps[i]["move"], finisher], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, gold)
		p.y += 24
	p.y += 8
	var lines := [
		"Damage %.1f     Attack speed x%.2f     Reach x%.2f" % [stats["damage"], stats["speed"], stats["reach"]],
		"Crit %d%%     Crit damage x%.2f     Area +%d%%     Move +%d%%" % [roundi(stats["crit"] * 100.0), stats["crit_damage"], roundi(stats["area"] * 100.0), roundi(stats["move_speed"] * 100.0)],
	]
	for l in lines:
		root.draw_string(font, p, l, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, white)
		p.y += 22
	p.y += 4
	var elements: Array = stats["elements"]
	root.draw_string(font, p, "Elements:", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, white)
	var ex := p.x + 78
	if elements.is_empty():
		root.draw_string(font, Vector2(ex, p.y), "none", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, dim)
	for e in elements:
		root.draw_string(font, Vector2(ex, p.y), e, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, WeaponBuild.ELEMENT_COLORS[e])
		ex += font.get_string_size(e, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12
	p.y += 22
	for c in stats["combos"]:
		root.draw_string(font, p, "Combo! " + c.capitalize() + ": " + ELEMENT_COMBO_TEXT.get(c, ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, WeaponBuild.ELEMENT_COLORS[c])
		p.y += 22

	if held != null:
		p.y += 12
		root.draw_rect(Rect2(p + Vector2(-10, -22), Vector2(INFO_W + 10, 90)), Color(0.14, 0.16, 0.22))
		root.draw_string(font, p, "In hand: %s (%s)" % [held.display_name, _kind_text(held)], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, white)
		_draw_mini_shape(held, p + Vector2(0, 12), held_rot)
		root.draw_multiline_string(font, p + Vector2(64, 24), held.description, HORIZONTAL_ALIGNMENT_LEFT, INFO_W - 70, 13, 3, dim)


const ELEMENT_COMBO_TEXT := {
	"steam": "hits burst and scald enemies nearby",
	"electrified": "lightning jumps further and stuns",
}
