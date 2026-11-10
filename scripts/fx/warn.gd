extends RefCounted
## The danger marks painted on the floor: lanes (a lunge, a charge) and circles
## (a slam, a falling rock), from the art in art/fx. They are drawn at the art's
## own size so the hatching stays one pixel, on a node that the dark doesn't dim.
## Each returns false when its art is missing, so the caller can fall back.

const Art := preload("res://scripts/art.gd")

const HOT := Color("#ff5a3c")


## A lane from `from` along `dir`, `length` world units long. width "thin" is 18
## art pixels across (the pike worm, the horned crab), "wide" is 40 (the knight).
## It reads "aim" while it still follows you and "lock" once it can't turn.
## The chevrons march forward with `t` (seconds).
static func lane(ci: CanvasItem, width: String, locked: bool, from: Vector2, dir: Vector2, length: float, t: float) -> bool:
	var name := "warn_lane_%s_%s" % [width, "lock" if locked else "aim"]
	var info := Art.piece(name)
	var tile := Art.piece_texture(name)
	var cap := Art.piece_texture(name + "_cap")
	if tile == null or cap == null:
		return false
	var fs: Array = info.get("frame", [16, 18])
	var o: Array = info.get("origin", [0, 9])
	var frames := int(info.get("frames", 4))
	var frame := int(t * float(info.get("fps", 14))) % frames
	var cap_len := float(cap.get_width())
	var body := maxf(length / Art.PIXEL - cap_len, 0.0)   # art pixels of lane before the cap
	ci.draw_set_transform(from, dir.angle(), Vector2(Art.PIXEL, Art.PIXEL))
	var x := 0.0
	while x < body:
		var w := minf(float(fs[0]), body - x)
		ci.draw_texture_rect_region(tile, Rect2(x, -float(o[1]), w, float(fs[1])), Rect2(frame * float(fs[0]), 0, w, float(fs[1])))
		x += float(fs[0])
	ci.draw_texture(cap, Vector2(body, -float(o[1])))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


## A circle of `radius` world units that fills as k goes 0 to 1 and flashes at 1.
## The art has one for the knight's slam (92) and one for falling rocks (58); any
## other radius uses the nearer one, scaled.
static func circle(ci: CanvasItem, radius: float, k: float) -> bool:
	var native := 92.0 if absf(radius - 92.0) <= absf(radius - 58.0) else 58.0
	var name := "warn_circle_r%d" % int(native)
	if Art.piece_texture(name) == null:
		return false
	var frames := int(Art.piece(name).get("frames", 8))
	var frame := frames - 1 if k >= 1.0 else clampi(int(k * float(frames - 1)), 0, frames - 2)
	return Art.draw_piece(ci, name, frame, Vector2.ZERO, 0.0, false, Color.WHITE, Art.PIXEL * radius / native)
