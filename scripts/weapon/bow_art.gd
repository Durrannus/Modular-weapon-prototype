extends RefCounted
## Draws a bow from the art in art/swing/bow/ (numbers in art/swing/bow/bow.json).
##
## In the hand every picture has the bow standing upright with the string side on
## the left: the arrow leaves to the RIGHT (+x). Everything here is drawn in "bow
## space": art pixels, the origin on the grip where the hand holds it, +x along
## the arrow. The caller sets the transform (where the hand is, the aim's angle,
## Art.PIXEL), and flips y when aiming to the left so the grip's slots stay
## towards the ground.
##
## The limbs' picture is a strip of three frames: at rest, half drawn, fully
## drawn. It has no string: that is drawn here, in the string's colour, from the
## top tip through the hand that draws it to the bottom tip.

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Art := preload("res://scripts/art.gd")

const DIR := "swing/bow/"


static func data() -> Dictionary:
	return Art.json(DIR + "bow.json")


static func _part(kind: String, id: String, scale: String) -> Dictionary:
	return data().get(kind, {}).get(id, {}).get(scale, {})


## An effect strip's numbers ({frames, frame, fps, origin}): the bow's own
## (bow.json "fx"), else the sword's (swing_path.json "fx"). The pictures are
## all in art/swing/fx/.
static func fx(name: String) -> Dictionary:
	var own: Dictionary = data().get("fx", {}).get(name, {})
	return own if not own.is_empty() else Art.json("swing/swing_path.json").get("fx", {}).get(name, {})


## Which of the limbs' three frames shows a string drawn this far (0..1).
static func frame_for(draw: float) -> int:
	return 0 if draw < 0.3 else (1 if draw < 0.75 else 2)


static func _grip_at(limbs: String) -> Vector2:
	var g: Array = _part("limbs", limbs, "hand").get("grip_at", [8, 11])
	return Vector2(g[0], g[1])


## Where the string ties on, in bow space: [top, bottom] for this much draw.
static func tips(limbs: String, draw: float) -> Array:
	var all: Array = _part("limbs", limbs, "hand").get("tips", [])
	var f := frame_for(draw)
	if f >= all.size():
		return [Vector2(-5, -11), Vector2(-5, 11)]
	var g := _grip_at(limbs)
	return [Vector2(all[f][0][0], all[f][0][1]) - g, Vector2(all[f][1][0], all[f][1][1]) - g]


## Where the arrow's tail sits on the string (and the hand that draws it), in
## bow space, for this much draw.
static func nock(limbs: String, draw: float) -> Vector2:
	var t := tips(limbs, 0.0)
	var pull := float(_part("limbs", limbs, "hand").get("pull", 6))
	return Vector2((t[0] as Vector2).x - pull * clampf(draw, 0.0, 1.0), 0.0)


## Slot i's place in bow space (0 = the lowest slot on the grip). Grip slots sit
## under the hand, the limb's above it.
static func slot_at(limbs: String, grip: String, i: int) -> Vector2:
	var gs: Array = _part("grips", grip, "hand").get("slots", [])
	if i < gs.size():
		return Vector2(gs[i][0], gs[i][1])
	var ls: Array = _part("limbs", limbs, "hand").get("slots", [])
	var j := i - gs.size()
	if j < ls.size():
		return Vector2(ls[j][0], ls[j][1]) - _grip_at(limbs)
	# No place written down: a column going up the limb.
	return Vector2(-1.0 - float(j), -5.0 - 2.0 * float(j))


static func string_color(string: String) -> Color:
	var c: String = data().get("strings", {}).get(string, {}).get("colour", "")
	if c != "":
		return Color(c)
	return SwingBuild.STRINGS.get(string, {}).get("color", Color("#dcd6b0"))


static func arrow_texture(arrows: String, what := "fly") -> Texture2D:
	var tex := Art.texture(DIR + "arrows/%s_%s.png" % [arrows, what])
	if tex == null:
		tex = Art.texture(DIR + "arrows/wooden_arrows_%s.png" % what)
	return tex


## The bow in the hand. draw: how far the string is drawn, 0..1. nocked: an
## arrow is on the string. lit: slot index -> 0..1, as for the sword.
static func draw_hand(ci: CanvasItem, limbs: String, grip: String, string: String, arrows: String, line: Array,
		lit: Dictionary, draw := 0.0, nocked := false, tint := Color.WHITE) -> void:
	var info := _part("limbs", limbs, "hand")
	var g := _grip_at(limbs)
	var limb_tex := Art.texture(DIR + "limbs/%s_hand.png" % limbs)
	var t := tips(limbs, draw)
	var n := nock(limbs, draw)
	var cord := string_color(string)
	cord = Color(cord.r * tint.r, cord.g * tint.g, cord.b * tint.b, cord.a * tint.a)
	# The string first, so the stave and the arrow lie over it.
	var top: Vector2 = t[0] + Vector2(0.5, 0.5)
	var bottom: Vector2 = t[1] + Vector2(0.5, 0.5)
	var held := n + Vector2(0.5, 0.5)
	if draw > 0.02:
		ci.draw_line(top, held, cord, 1.0)
		ci.draw_line(held, bottom, cord, 1.0)
	else:
		ci.draw_line(top, bottom, cord, 1.0)
	if limb_tex != null:
		var frames := maxi(int(info.get("frames", 3)), 1)
		var fw := float(limb_tex.get_width()) / frames
		var f := mini(frame_for(draw), frames - 1)
		ci.draw_texture_rect_region(limb_tex, Rect2(-g, Vector2(fw, limb_tex.get_height())), Rect2(f * fw, 0, fw, limb_tex.get_height()), tint)
	else:
		# No picture: a plain curved stave.
		var pts := PackedVector2Array()
		for k in 9:
			var y := lerpf((t[0] as Vector2).y, (t[1] as Vector2).y, k / 8.0)
			var bend := 1.0 - pow(absf(y) / maxf(absf((t[0] as Vector2).y), 1.0), 1.7)
			pts.append(Vector2((t[0] as Vector2).x + ((0.0 - (t[0] as Vector2).x)) * bend, y))
		ci.draw_polyline(pts, Color("#dca25c") * tint, 1.5)
	var grip_tex := Art.texture(DIR + "grips/%s_hand.png" % grip)
	if grip_tex != null:
		# Centred on the hold (grips with more slots are longer, above and below it).
		ci.draw_texture(grip_tex, -Vector2(floorf(grip_tex.get_width() * 0.5), floorf(grip_tex.get_height() * 0.5)), tint)
	# What is in the slots: a dot for a rune, a short bar across the stave for a band.
	for i in line.size():
		var id: String = line[i]
		if id == "" or not SwingBuild.FITTINGS.has(id):
			continue
		var at := slot_at(limbs, grip, i)
		var on := float(lit.get(i, 0.0)) > 0.4
		var f: Dictionary = SwingBuild.FITTINGS[id]
		var col: Color = f["color"]
		if f["kind"] == "band":
			ci.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), (Color.WHITE if on else col) * tint)
		else:
			var tex := Art.texture("swing/%s/%s_hand%s.png" % ["runes" if f["kind"] == "rune" else "rare", id, "_lit" if on else ""])
			if tex != null:
				ci.draw_texture(tex, at, tint)
			else:
				ci.draw_rect(Rect2(at, Vector2(1, 1)), (Color.WHITE if on else col) * tint)
	if nocked:
		var arrow_tex := arrow_texture(arrows)
		if arrow_tex != null:
			var nk: Array = _part("arrows", arrows, "fly").get("nock", [0, 1])
			ci.draw_texture(arrow_tex, n - Vector2(nk[0], nk[1]), tint)
