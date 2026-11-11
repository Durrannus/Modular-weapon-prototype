extends RefCounted
## Draws a swing path sword from the art in art/swing/ (see art/swing/swing_path.md).
## Everything is in art pixels of the chosen scale ("hand" 1x, "forge" 3x); the
## caller sets the transform. The sword frame is 9 wide in the hand and 45 on the
## forge screen, tip at the top: the blade centred on the frame's middle column,
## the grip below it at (0, blade height).

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Art := preload("res://scripts/art.gd")

const DIR := "swing/"


static func data() -> Dictionary:
	return Art.json("swing/swing_path.json")


static func _k(scale: String) -> float:
	return 1.0 if scale == "hand" else 3.0  # forge art is 3x (fits the long blade + long grip)


## Frame layout. Hand art has its own smaller layout (swing_path.json "hand_frame"):
## 9 px wide, blade at x 2, pommel 2 px tall. Forge art is 15*k wide, blade at x 4k.
static func frame_w(scale: String) -> float:
	if scale == "hand":
		return float(data().get("hand_frame", {}).get("frame_w", 9))
	return 15.0 * _k(scale)


## Blades are centred on the sword's centre line, whatever their width (a dagger
## is 3 wide in the hand, a greatsword 7), so widths are odd numbers.
static func blade_x(blade: String, scale: String) -> float:
	return roundf((frame_w(scale) - blade_size(blade, scale).x) * 0.5)


## A sabre or a falchion has one cutting edge, drawn on the left of its picture.
static func one_edged(blade: String) -> bool:
	return SwingBuild.BLADES.get(blade, {}).get("shape", "") in ["sabre", "falchion"]


static func _pommel_h(scale: String) -> float:
	return 2.0 if scale == "hand" else 4.0 * _k(scale)


static func _part(kind: String, id: String, scale: String) -> Dictionary:
	return data().get(kind, {}).get(id, {}).get(scale, {})


static func blade_size(blade: String, scale: String) -> Vector2:
	var s: Array = _part("blades", blade, scale).get("size", [7.0 * _k(scale), 19.0 * _k(scale)])
	return Vector2(s[0], s[1])


static func grip_origin(blade: String, scale: String) -> Vector2:
	return Vector2(0, blade_size(blade, scale).y)


static func frame_size(blade: String, grip: String, scale: String) -> Vector2:
	var g: Array = _part("grips", grip, scale).get("size", [frame_w(scale), 19.0 * _k(scale)])
	# The pommel hangs a little below the grip (more on the Ringed grip).
	var pa: Array = _part("grips", grip, scale).get("pommel_at", [0, g[1]])
	var ph := _pommel_h(scale)
	var below := maxf(float(pa[1]) + ph - float(g[1]), 0.0)
	return Vector2(frame_w(scale), blade_size(blade, scale).y + float(g[1]) + below)


## Where the hand holds the sword, in frame pixels: the middle of the grip's hold,
## which sits right under the guard (grip art runs guard, hold, socket collar, pommel).
static func pivot(blade: String, grip: String, scale: String) -> Vector2:
	var p: Array = _part("grips", grip, scale).get("pivot", [frame_w(scale) * 0.5, 3.5])
	return grip_origin(blade, scale) + Vector2(p[0], p[1])


## Slot i's rect (0 = bottom of the grip), in frame pixels.
static func slot_rect(blade: String, grip: String, scale: String, i: int) -> Rect2:
	var grects: Array = _part("grips", grip, scale).get("slot_rects", [])
	var brects: Array = _part("blades", blade, scale).get("slot_rects", [])
	var r: Array
	var off: Vector2
	if i < grects.size():
		r = grects[i]
		off = grip_origin(blade, scale)
	elif i - grects.size() < brects.size():
		r = brects[i - grects.size()]
		off = Vector2(blade_x(blade, scale), 0)
	else:
		return Rect2(Vector2(frame_w(scale) * 0.5 - 1.0, 0), Vector2(1, 1) * (1.0 if scale == "hand" else 3.0 * _k(scale)))
	return Rect2(off + Vector2(r[0], r[1]), Vector2(r[2], r[3]))


static func slot_center(blade: String, grip: String, scale: String, i: int) -> Vector2:
	return slot_rect(blade, grip, scale, i).get_center()


## lit: slot index -> 0..1. A slot above 0.4 swaps to its _lit image.
## flip_blade: the blade's picture mirrored left to right, so a one-edged blade
## can cut the other way (its sockets sit on the centre line and stay put).
static func draw(ci: CanvasItem, blade: String, grip: String, line: Array, scale: String,
		lit: Dictionary, origin := Vector2.ZERO, tint := Color.WHITE, pommel := "plain_pommel", flip_blade := false) -> void:
	var gs := int(SwingBuild.GRIPS[grip]["slots"])
	var blade_tex := Art.texture(DIR + "blades/%s_%s.png" % [blade, scale])
	var grip_tex := Art.texture(DIR + "grips/%s_%s.png" % [grip, scale])
	if blade_tex != null:
		var at := origin + Vector2(blade_x(blade, scale), 0)
		if flip_blade:
			ci.draw_texture_rect(blade_tex, Rect2(at + Vector2(blade_tex.get_width(), 0), Vector2(-blade_tex.get_width(), blade_tex.get_height())), false, tint)
		else:
			ci.draw_texture(blade_tex, at, tint)
	if grip_tex != null:
		ci.draw_texture(grip_tex, origin + grip_origin(blade, scale), tint)
	var pommel_tex := Art.texture(DIR + "pommels/%s_%s.png" % [pommel, scale])
	var pa: Array = _part("grips", grip, scale).get("pommel_at", [])
	if pommel_tex != null and not pa.is_empty():
		ci.draw_texture(pommel_tex, origin + grip_origin(blade, scale) + Vector2(pa[0], pa[1]), tint)
	for i in line.size():
		var id: String = line[i]
		if id == "":
			continue
		var r := slot_rect(blade, grip, scale, i)
		var on := float(lit.get(i, 0.0)) > 0.4
		var suffix := "_lit" if on else ""
		var f: Dictionary = SwingBuild.FITTINGS[id]
		if f["kind"] == "rune" or f["kind"] == "bender":
			var tex := Art.texture(DIR + ("runes/" if f["kind"] == "rune" else "rare/") + "%s_%s%s.png" % [id, scale, suffix])
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
