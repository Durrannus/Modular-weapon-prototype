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
	# (A warhammer has a striking face on one side and a beak on the other.)
	return SwingBuild.BLADES.get(blade, {}).get("shape", "") in ["sabre", "falchion"] \
		or SwingBuild.HEADS.get(blade, {}).get("shape", "") == "warhammer"


static func _pommel_h(scale: String) -> float:
	return 2.0 if scale == "hand" else 4.0 * _k(scale)


## A hammer and a staff (15 November) are put together exactly like a sword, so
## this file draws them too: a head stands where a blade does, a haft or a shaft
## where a grip does, a counterweight or a cap where a pommel does. Their pictures
## and numbers are in their own folders, under their own names.
const BOOKS := {
	"hammer": {"file": "swing/hammer/hammer.json", "dir": "swing/hammer/", "blades": "heads", "grips": "hafts", "pommels": "weights"},
	"staff": {"file": "swing/staff/staff.json", "dir": "swing/staff/", "blades": "heads", "grips": "shafts", "pommels": "caps"},
}


## Whose part this is: "sword", "hammer" or "staff". `kind` is the sword's word
## for its place ("blades", "grips" or "pommels").
static func _weapon(kind: String, id: String) -> String:
	for w in ["hammer", "staff"]:
		var parts: Dictionary
		match kind:
			"blades": parts = SwingBuild.heads_of(w)
			"grips": parts = SwingBuild.grips_of(w)
			_: parts = SwingBuild.butts_of(w)
		if parts.has(id):
			return w
	return "sword"


static func _entry(kind: String, id: String) -> Dictionary:
	var w := _weapon(kind, id)
	if w == "sword":
		return data().get(kind, {}).get(id, {})
	return Art.json(BOOKS[w]["file"]).get(BOOKS[w][kind], {}).get(id, {})


static func _part(kind: String, id: String, scale: String) -> Dictionary:
	return _entry(kind, id).get(scale, {})


## A part's picture: "hand", "forge" or "icon".
static func part_texture(kind: String, id: String, what: String) -> Texture2D:
	var w := _weapon(kind, id)
	if w == "sword":
		return Art.texture(DIR + "%s/%s_%s.png" % [kind, id, what])
	return Art.texture(BOOKS[w]["dir"] + "%s/%s_%s.png" % [BOOKS[w][kind], id, what])


## A staff's crystal: its picture, and where it sits on the head (in the head's
## own picture). The bolts leave from there.
static func crystal_texture(crystal: String, scale: String) -> Texture2D:
	return Art.texture(BOOKS["staff"]["dir"] + "crystals/%s_%s.png" % [crystal, scale])


static func crystal_at(head: String, scale: String) -> Vector2:
	var size := blade_size(head, scale)
	var c: Array = _part("blades", head, scale).get("crystal_at", [size.x * 0.5, size.x * 0.5])
	return Vector2(c[0], c[1])


## What a crystal's bolts are tinted with (staff.json, else the game's own colour).
static func crystal_color(crystal: String) -> Color:
	var c = Art.json(BOOKS["staff"]["file"]).get("crystals", {}).get(crystal, {}).get("colour", null)
	if c is String:
		return Color(c)
	return SwingBuild.CRYSTALS.get(crystal, {}).get("color", Color.WHITE)


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
		lit: Dictionary, origin := Vector2.ZERO, tint := Color.WHITE, pommel := "plain_pommel", flip_blade := false, crystal := "") -> void:
	var gs := int(SwingBuild.grip_part(grip)["slots"])
	var blade_tex := part_texture("blades", blade, scale)
	var grip_tex := part_texture("grips", grip, scale)
	# On a hammer's or a staff's neck a band is the narrow one drawn for a bow's limb.
	var head_host := "blade" if _weapon("blades", blade) == "sword" else "limb"
	if blade_tex != null:
		var at := origin + Vector2(blade_x(blade, scale), 0)
		if flip_blade:
			ci.draw_texture_rect(blade_tex, Rect2(at + Vector2(blade_tex.get_width(), 0), Vector2(-blade_tex.get_width(), blade_tex.get_height())), false, tint)
		else:
			ci.draw_texture(blade_tex, at, tint)
	if crystal != "":
		var crystal_tex := crystal_texture(crystal, scale)
		if crystal_tex != null:
			var seat := origin + Vector2(blade_x(blade, scale), 0) + crystal_at(blade, scale)
			ci.draw_texture(crystal_tex, (seat - crystal_tex.get_size() * 0.5).round(), tint)
	if grip_tex != null:
		ci.draw_texture(grip_tex, origin + grip_origin(blade, scale), tint)
	var pommel_tex := part_texture("pommels", pommel, scale)
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
			var host := "grip" if i < gs else head_host
			var tex := Art.texture(DIR + "bands/%s_%s_%s%s.png" % [id, host, scale, suffix])
			if tex != null:
				var pos := Vector2(r.get_center().x - tex.get_width() * 0.5, r.position.y)
				ci.draw_texture(tex, origin + pos.round(), tint)
			else:
				ci.draw_rect(Rect2(origin + r.position - Vector2(2, 0) * _k(scale) / 1.0, r.size + Vector2(4, 0)), f["color"])
