extends RefCounted
## The words that float up over heads (CHALLENGED, BLOCKED, PAYBACK, MARKED, CLOSE CALL ...) never sit on top of
## each other, over one player or over a group of enemies (the project's review of version 54: "nothing in it can
## be read"). Every word rises straight up at the same speed, so two words placed apart stay apart. A new word that
## would land on another goes just above it; where MOST words already stand one above the other it waits its turn
## (it shows when the bottom one has risen out of the way), and a word that has waited WAIT_MOST is dropped.
## The damage numbers are not words: they scatter, and are not placed here.
##
## A word is a node with `placed` (bool) and `word_box()` (the Rect2 its letters and outline cover, in the world).

const RISE := 60.0         # how fast every word rises (world pixels a second)
const GAP := 2.0           # at least this much room between two words
const MOST := 2            # words stacked in one spot at a time; one more waits
const WAIT_MOST := 0.8     # seconds a word may wait for room before it is dropped (a word is about 0.55 s rising clear)
const OUTLINE := 4.0       # the dark outline round the letters (8 wide, half outside)

static var live: Array = []


## Where word `n` goes when it would start at `at` (where its baseline's middle is): `at`, or higher up out of the way
## of the words already there. Vector2.INF if there is no room yet. `n` must not be placed yet.
static func place(n, at: Vector2) -> Vector2:
	live = live.filter(func(o): return is_instance_valid(o) and o.is_inside_tree() and not o.is_queued_for_deletion())
	var spot := at
	for row in MOST:
		var mine: Rect2 = n.word_box_at(spot)
		var top := INF
		for o in live:
			var b: Rect2 = o.word_box().grow(GAP)
			if b.intersects(mine):
				top = minf(top, b.position.y)
		if top == INF:
			live.append(n)
			return spot
		spot.y -= mine.end.y - top
	return Vector2.INF


## The box of `text` written in `font` at `size` with its baseline's middle at `at`.
static func box(font: Font, size: int, text: String, at: Vector2) -> Rect2:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var up := font.get_ascent(size)
	var down := font.get_descent(size)
	return Rect2(at + Vector2(-w * 0.5, -up), Vector2(w, up + down)).grow(OUTLINE)


## Any two words on the screen that overlap, for the checks: [[a, b], ...].
static func overlaps() -> Array:
	live = live.filter(func(o): return is_instance_valid(o) and o.is_inside_tree() and not o.is_queued_for_deletion())
	var out: Array = []
	for i in live.size():
		for k in range(i + 1, live.size()):
			if live[i].word_box().intersects(live[k].word_box()):
				out.append([live[i], live[k]])
	return out
