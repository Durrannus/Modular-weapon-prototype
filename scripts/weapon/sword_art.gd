extends RefCounted
## Draws a swing path sword from the art in art/swing/ (see art/swing/swing_path.md).
## Everything is in art pixels of the chosen scale ("hand" 1x, "forge" 5x); the
## caller sets the transform. The sword frame is 15*k wide, tip at the top:
## blade at (4k, 0), grip below it at (0, blade height).

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Art := preload("res://scripts/art.gd")

const DIR := "swing/"


static func data() -> Dictionary:
	return Art.json("swing/swing_path.json")


static func _k(scale: String) -> float:
	return 1.0 if scale == "hand" else 5.0


static func _part(kind: String, id: String, scale: String) -> Dictionary:
	return data().get(kind, {}).get(id, {}).get(scale, {})


static func blade_size(blade: String, scale: String) -> Vector2:
	var s: Array = _part("blades", blade, scale).get("size", [7.0 * _k(scale), 19.0 * _k(scale)])
	return Vector2(s[0], s[1])


static func grip_origin(blade: String, scale: String) -> Vector2:
	return Vector2(0, blade_size(blade, scale).y)


static func frame_size(blade: String, grip: String, scale: String) -> Vector2:
	var g: Array = _part("grips", grip, scale).get("size", [15.0 * _k(scale), 19.0 * _k(scale)])
	return Vector2(15.0 * _k(scale), blade_size(blade, scale).y + float(g[1]))


# The grip art runs guard, socket collar, hold, pommel (top to bottom). That put
# the hand at the far end, under the runes, so the sword looked held by its end.
# We draw it as guard, hold, socket collar, pommel instead: the hand sits right
# under the guard and the grip's runes sit below the fist, near the pommel.
const GUARD_ROWS := 3.0
const HOLD_ROWS := 5.0
const POMMEL_ROWS := 3.0


static func _grip_height(grip: String, scale: String) -> float:
	var g: Array = _part("grips", grip, scale).get("size", [15.0 * _k(scale), 19.0 * _k(scale)])
	return float(g[1])


## Where the hand holds the sword, in frame pixels: the middle of the hold.
static func pivot(blade: String, grip: String, scale: String) -> Vector2:
	var k := _k(scale)
	return grip_origin(blade, scale) + Vector2(7.5 * k, (GUARD_ROWS + HOLD_ROWS * 0.5) * k)


## Draws the grip with its hold moved up under the guard (see above).
static func _draw_grip(ci: CanvasItem, tex: Texture2D, pos: Vector2, scale: String, tint: Color) -> void:
	var k := _k(scale)
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var guard := GUARD_ROWS * k
	var hold := HOLD_ROWS * k
	var pommel := POMMEL_ROWS * k
	var collar := h - guard - hold - pommel
	if collar < 0.0:
		ci.draw_texture(tex, pos, tint)
		return
	# [source y, height, destination y]
	for seg in [[0.0, guard, 0.0], [guard + collar, hold, guard], [guard, collar, guard + hold], [h - pommel, pommel, h - pommel]]:
		ci.draw_texture_rect_region(tex, Rect2(pos + Vector2(0, seg[2]), Vector2(w, seg[1])), Rect2(0, seg[0], w, seg[1]), tint)


## Slot i's rect (0 = bottom of the grip), in frame pixels.
static func slot_rect(blade: String, grip: String, scale: String, i: int) -> Rect2:
	var grects: Array = _part("grips", grip, scale).get("slot_rects", [])
	var brects: Array = _part("blades", blade, scale).get("slot_rects", [])
	var r: Array
	var off: Vector2
	if i < grects.size():
		r = grects[i]
		# grip sockets sit in the collar, which is drawn below the hold
		off = grip_origin(blade, scale) + Vector2(0, HOLD_ROWS * _k(scale))
	elif i - grects.size() < brects.size():
		r = brects[i - grects.size()]
		off = Vector2(4.0 * _k(scale), 0)
	else:
		return Rect2(Vector2(7, 0) * _k(scale), Vector2(3, 3) * _k(scale))
	return Rect2(off + Vector2(r[0], r[1]), Vector2(r[2], r[3]))


static func slot_center(blade: String, grip: String, scale: String, i: int) -> Vector2:
	return slot_rect(blade, grip, scale, i).get_center()


## lit: slot index -> 0..1. A slot above 0.4 swaps to its _lit image.
static func draw(ci: CanvasItem, blade: String, grip: String, line: Array, scale: String,
		lit: Dictionary, origin := Vector2.ZERO, tint := Color.WHITE) -> void:
	var gs := int(SwingBuild.GRIPS[grip]["slots"])
	var blade_tex := Art.texture(DIR + "blades/%s_%s.png" % [blade, scale])
	var grip_tex := Art.texture(DIR + "grips/%s_%s.png" % [grip, scale])
	if blade_tex != null:
		ci.draw_texture(blade_tex, origin + Vector2(4.0 * _k(scale), 0), tint)
	if grip_tex != null:
		_draw_grip(ci, grip_tex, origin + grip_origin(blade, scale), scale, tint)
	for i in line.size():
		var id: String = line[i]
		if id == "":
			continue
		var r := slot_rect(blade, grip, scale, i)
		var on := float(lit.get(i, 0.0)) > 0.4
		var suffix := "_lit" if on else ""
		var f: Dictionary = SwingBuild.FITTINGS[id]
		if f["kind"] == "rune":
			var tex := Art.texture(DIR + "runes/%s_%s%s.png" % [id, scale, suffix])
			if tex != null:
				ci.draw_texture(tex, origin + r.position, tint)
			else:
				ci.draw_rect(Rect2(origin + r.position, r.size), f["color"])
		else:
			var host := "grip" if i < gs else "blade"
			var tex := Art.texture(DIR + "bands/%s_%s_%s%s.png" % [id, host, scale, suffix])
			if tex != null:
				var pos := Vector2(r.get_center().x - tex.get_width() * 0.5, r.position.y)
				ci.draw_texture(tex, origin + pos.round(), tint)
			else:
				ci.draw_rect(Rect2(origin + r.position - Vector2(2, 0) * _k(scale) / 1.0, r.size + Vector2(4, 0)), f["color"])
