extends RefCounted
## Draws a swing path sword from part sprites, in "cells" (5 px each in hand,
## 18 px each on the forge). Layout, top to bottom, 3 cells wide:
##   rows 0-2   blade (blade slots sit on its lower cells, bottom slot first)
##   row 3      hilt
##   rows 4..   grip, one cell per grip slot (bottom slot lowest)
##   last row   pommel
## Fittings show as sockets: runes are gems, bands are metal rings round the sword.

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Art := preload("res://scripts/art.gd")


static func rows(grip: String) -> int:
	return 5 + int(SwingBuild.GRIPS[grip]["slots"])


## Where the hand holds it, in cells: the middle of the grip.
static func pivot(grip: String) -> Vector2:
	return Vector2(1.5, 4.0 + float(SwingBuild.GRIPS[grip]["slots"]) * 0.5)


## Centre of slot i (0 = bottom of the line), in cells.
static func slot_center(blade: String, grip: String, i: int) -> Vector2:
	var gs := int(SwingBuild.GRIPS[grip]["slots"])
	if i < gs:
		return Vector2(1.5, 4.0 + float(gs - 1 - i) + 0.5)
	return Vector2(1.5, 2.0 - float(i - gs) + 0.5)


## lit: slot index -> 0..1 glow. grid: use the forge sprites instead of the in-hand ones.
static func draw(ci: CanvasItem, blade: String, grip: String, line: Array, slot_info: Dictionary,
		cell: float, grid: bool, lit: Dictionary, origin := Vector2.ZERO) -> void:
	var g: Dictionary = SwingBuild.GRIPS[grip]
	var b: Dictionary = SwingBuild.BLADES[blade]
	var gs := int(g["slots"])
	var sfx := "_grid" if grid else "_hand"
	var px := cell / (18.0 if grid else 5.0)  # screen units per art pixel
	# Pommel
	_part(ci, str(g["pommel"]) + sfx, origin + Vector2(1, 4 + gs) * cell, Vector2(cell, cell), Color(0.5, 0.35, 0.2))
	# Grip: the handle sprite is 2 cells tall; repeat its cells down the grip.
	var handle := Art.texture("parts/%s%s.png" % [g["sprite"], sfx])
	for r in gs:
		var dest := Rect2(origin + Vector2(1, 4 + r) * cell, Vector2(cell, cell))
		if handle != null:
			var hc := handle.get_height() / 2.0
			ci.draw_texture_rect_region(handle, dest, Rect2(0, float(r % 2) * hc, handle.get_width(), hc))
		else:
			ci.draw_rect(dest.grow_individual(-cell * 0.25, 0, -cell * 0.25, 0), Color(0.45, 0.3, 0.18))
	# Blade
	var bw := int(b["cells"])
	var bx := 1.5 - bw * 0.5
	_part(ci, blade + sfx, origin + Vector2(bx, 0) * cell, Vector2(bw, 3) * cell, SwingBuild.ELEMENT_COLORS.get(b["element"], Color(0.8, 0.8, 0.85)))
	# Hilt
	_part(ci, str(g["hilt"]) + sfx, origin + Vector2(0, 3) * cell, Vector2(3, 1) * cell, Color(0.55, 0.38, 0.22))
	# Sockets
	for i in line.size():
		var id: String = line[i]
		var c := origin + slot_center(blade, grip, i) * cell
		var glow := float(lit.get(i, 0.0))
		if id == "":
			if grid:
				ci.draw_arc(c, cell * 0.22, 0.0, TAU, 16, Color(0, 0, 0, 0.55), maxf(px, 1.0))
			else:
				ci.draw_rect(Rect2(c - Vector2(1, 1) * px, Vector2(2, 2) * px), Color(0.1, 0.08, 0.06, 0.8))
			continue
		var f: Dictionary = SwingBuild.FITTINGS[id]
		var col: Color = f["color"]
		var unused: bool = slot_info.get(i, {}).has("unused")
		if unused:
			col = col.darkened(0.55)
		col = col.lerp(Color.WHITE, glow * 0.7)
		if glow > 0.0:
			var halo := col
			halo.a = 0.55 * glow
			ci.draw_circle(c, cell * (0.55 + glow * 0.5), halo)
		if f["kind"] == "band":
			# A ring round the sword: a bright bar across the full width.
			var w := cell * (0.95 if grid else 1.0)
			ci.draw_rect(Rect2(c - Vector2(w * 0.5, cell * 0.17), Vector2(w, cell * 0.34)), Color(0.06, 0.07, 0.1))
			ci.draw_rect(Rect2(c - Vector2(w * 0.5 - px, cell * 0.17 - px), Vector2(w - 2 * px, cell * 0.34 - 2 * px)), col)
		else:
			# A gem.
			var r := cell * 0.3
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
			var outline := PackedVector2Array([c + Vector2(0, -r - px), c + Vector2(r + px, 0), c + Vector2(0, r + px), c + Vector2(-r - px, 0)])
			ci.draw_colored_polygon(outline, Color(0.06, 0.07, 0.1))
			ci.draw_colored_polygon(pts, col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.35, -r * 0.55), Vector2(px, px)), Color(1, 1, 1, 0.85))


static func _part(ci: CanvasItem, sprite: String, pos: Vector2, size: Vector2, fallback: Color) -> void:
	var tex := Art.texture("parts/%s.png" % sprite)
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(pos, size), false)
	else:
		ci.draw_rect(Rect2(pos, size).grow(-size.x * 0.1), fallback)
