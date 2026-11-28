extends RefCounted
## Where the picture of something you carry is. The bag's 16 by 16 pictures ("item_<name>") and the small ones that
## lie on the ground ("drop_<name>") are on two sheets: the tool art's (tools-v1: stone, wood and the two ores) and
## the loot art's (highlands-loot-v1: bars, coins, the Warhorn's pieces, the Memory mote, the screen's coin). The
## tool art's is looked in first. The levelling art's sheet (highlands-levelling-v1: the Memory bar, the level's
## roundel, the marker left where somebody fell, the level-up) and the role trees' (highlands-roles-v1: the marks
## for Challenged and Open, the Spark, the shimmer, the four trees' emblems) are in the same form and are found
## the same way. So is the inventory art's (version 47: the inventory's slot, its cursor, the Hide Pack and the Hide
## Satchel), looked in last.

const Art := preload("res://scripts/art.gd")

## Things that share a picture: both kinds of blank rune stone are the loot art's one smooth stone (version 55).
const SAME := {"passive_blank": "blank_rune", "active_blank": "blank_rune"}

const BOOKS := [["tools/tools.png", "tools/tools.json"], ["loot/loot.png", "loot/loot.json"], ["levelling/levelling.png", "levelling/levelling.json"],
	["roles/roles.png", "roles/roles.json"], ["inventory/inventory.png", "inventory/inventory.json"]]


## [the sheet, what its book says about the picture], or [] if neither sheet has it.
static func find(name: String) -> Array:
	for id in SAME:
		if name.ends_with("_" + str(id)):
			name = name.trim_suffix(str(id)) + str(SAME[id])
	for pair in BOOKS:
		var info: Dictionary = Art.json(pair[1]).get("sprites", {}).get(name, {})
		if info.has("box") and Art.texture(pair[0]) != null:
			return [Art.texture(pair[0]), info]
	return []


## How big one frame of it is, in art pixels (zero if there is no such picture).
static func size(name: String) -> Vector2:
	var got := find(name)
	if got.is_empty():
		return Vector2.ZERO
	var info: Dictionary = got[1]
	var box: Array = info["box"]
	if info.has("frames") and info.has("frame"):
		return Vector2(float(info["frame"][0]), float(info["frame"][1]))
	return Vector2(float(box[2]), float(box[3]))


## The point of it that stands on the place it is drawn at, in art pixels from its top left corner (zero if its
## book names none).
static func origin(name: String) -> Vector2:
	var got := find(name)
	if got.is_empty():
		return Vector2.ZERO
	var o = (got[1] as Dictionary).get("origin", [0, 0])
	return Vector2(float(o[0]), float(o[1])) if o is Array and o.size() == 2 else Vector2.ZERO


## Draws one frame of it with its top left corner at `at`. `px` is the size of one art pixel there. Returns its size
## in art pixels (zero if there is no such picture).
static func draw(ci: CanvasItem, name: String, at: Vector2, px := 1.0, tint := Color.WHITE, frame := 0) -> Vector2:
	var got := find(name)
	if got.is_empty():
		return Vector2.ZERO
	var info: Dictionary = got[1]
	var box: Array = info["box"]
	var one := size(name)
	var n := int(info.get("frames", 1))
	ci.draw_texture_rect_region(got[0], Rect2(at, one * px), Rect2(float(box[0]) + one.x * float(posmod(frame, maxi(n, 1))), float(box[1]), one.x, one.y), tint)
	return one


## The 24 by 24 icon of something you carry that has its own icon (version 70: the Art builder's equipment icons,
## art/items/<name>_icon.png, the healing potion first), or null.
static func icon(name: String) -> Texture2D:
	return Art.texture("items/%s_icon.png" % name)


static var _used := {}


## The part of an icon that is drawn on (its picture without the empty edge), in its pixels.
static func icon_used(name: String) -> Rect2:
	if _used.has(name):
		return _used[name]
	var tex := icon(name)
	var got := Rect2()
	if tex != null:
		var img := tex.get_image()
		got = Rect2(img.get_used_rect()) if img != null else Rect2(Vector2.ZERO, tex.get_size())
	_used[name] = got
	return got


## Draws something you carry, as big as it fits, in the middle of `rect` (the hotbar's slots, version 70): its own
## icon's drawn part when it has one, else its 16 by 16 bag picture. One art pixel is one pixel of `ci`.
static func draw_small(ci: CanvasItem, name: String, rect: Rect2, tint := Color.WHITE) -> void:
	var tex := icon(name)
	if tex != null:
		var used := icon_used(name)
		var at := (rect.position + (rect.size - used.size) * 0.5).floor()
		ci.draw_texture_rect_region(tex, Rect2(at, used.size), used, tint)
		return
	var one := size("item_" + name)
	if one != Vector2.ZERO:
		draw(ci, "item_" + name, (rect.position + (rect.size - one) * 0.5).floor(), 1.0, tint)
