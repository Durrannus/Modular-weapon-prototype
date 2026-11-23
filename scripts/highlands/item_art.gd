extends RefCounted
## Where the picture of something you carry is. The bag's 16 by 16 pictures ("item_<name>") and the small ones that
## lie on the ground ("drop_<name>") are on two sheets: the tool art's (tools-v1: stone, wood and the two ores) and
## the loot art's (highlands-loot-v1: bars, coins, the Warhorn's pieces, the Memory mote, the screen's coin). The
## tool art's is looked in first.

const Art := preload("res://scripts/art.gd")

const BOOKS := [["tools/tools.png", "tools/tools.json"], ["loot/loot.png", "loot/loot.json"]]


## [the sheet, what its book says about the picture], or [] if neither sheet has it.
static func find(name: String) -> Array:
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
