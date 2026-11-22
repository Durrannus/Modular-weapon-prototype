extends RefCounted
## Ore veins: where the metal runs through the rock, and the colour of each pixel of it.
##
## Darren (21 and 22 November): "I want it like veins through the rock", "Make it so that it doesn't show all the
## way through the dark, and fades into fog of war", then "Ok on veins look". So ore is never a thing stuck on a
## tile: it is a seam two pixels wide that crosses the dark top of the rock, goes over the edge and runs down the lit
## face to the ground. It is bright on a face, plain near the edge of the top, and it thins, breaks up and is gone
## about a tile into the dark, so the heart of a hill shows nothing until somebody digs near it.
##
## This is a port, number for number, of the art thread's hl3.vein_paths() and hl3.vein_step()
## (/mnt/project-files/art/highlands-concept/v3/code/, notes in VEINS.md there). tests/highlands.gd checks it against
## the art thread's own numbers (tests/highlands_vein_ref.json), so the game shows the veins the art thread drew.
##
## Nothing in here is random beyond the world's seed: the same cluster of ore tiles always gives the same pixels,
## whichever chunk asks and however often. Whole numbers only (all below 2^32, every product below 2^63).

const T := 16
const M32 := 0xFFFFFFFF

## What a vein pixel is. A higher metal number wins over a lower one; cracks and stains only lie where there is no metal.
enum { NONE, FORK, EDGE, BODY, POCKET, CRACK, STAIN, STAIN2 }
## The two ores, by the art code's own numbers.
const TIN := 1
const COPPER := 2
## What a pixel is painted with: the ore's own ramp, the green that weeps from copper, or the rock's own crack colour.
enum { M_METAL, M_VERD, M_FACE, M_CAP }

const LEAN := [[50, 70, 80], [30, 56, 82], [12, 42, 87]]   # per seam: chances out of 100 of steep, diagonal, flat (else a kink)
const FORK_LEAN := [12, 48, 92]
## The tables since 22 November 2026, when Darren asked for the ore to "shine a little more": a step brighter than
## before, and with glints.
const FACE_STEP := {                                        # the step on the metal's ramp: [low on the face, high on the face]
	TIN: {FORK: [1, 2], EDGE: [2, 2], BODY: [2, 3], POCKET: [3, 3]},
	COPPER: {FORK: [1, 2], EDGE: [2, 2], BODY: [3, 3], POCKET: [4, 4]},
}
const TOP_STEP := {                                         # on the rock's top: [under 6 px from its edge, 6 to 9 px in]
	TIN: {FORK: [1, 1], EDGE: [2, 1], BODY: [3, 2], POCKET: [3, 3]},
	COPPER: {FORK: [1, 1], EDGE: [2, 1], BODY: [3, 2], POCKET: [4, 3]},
}
const GLINT := {TIN: 4, COPPER: 5}                          # the shine: single pixels of the ramp's last step
const GLINT_ODDS := {POCKET: 25, BODY: 5}                   # the chance out of 100 that a pixel of that class is a glint
const GONE := 21                                            # this many pixels in from the edge of the top, nothing shows


## A small hash of four whole numbers, 0 to 2^32 - 1.
static func vmix(a: int, b: int, c: int, d: int) -> int:
	var h := 0x9E3779B1
	for v in [a, b, c, d]:
		h = (h ^ (v & M32)) & M32
		h = (h * 16777619) & M32
		h ^= h >> 15
		h = (h * 739982445) & M32
		h ^= h >> 12
	return h


## xorshift32. below(n) is 0 to n - 1; between(lo, hi) includes both ends.
class Rng:
	var s := 1

	func _init(key: int) -> void:
		s = key & 0xFFFFFFFF
		if s == 0:
			s = 1

	func next() -> int:
		var x := s
		x ^= (x << 13) & 0xFFFFFFFF
		x ^= x >> 17
		x ^= (x << 5) & 0xFFFFFFFF
		s = x
		return x

	func below(n: int) -> int:
		return (next() >> 8) % n

	func between(lo: int, hi: int) -> int:
		return lo + below(hi - lo + 1)


## One cluster's seams being walked.
class Walk:
	var cells := {}             # Vector2i tile -> true
	var kind := 1
	var rng: Rng
	var metal := {}             # Vector2i pixel -> class
	var owner := {}             # Vector2i pixel -> which seam laid it
	var cracks: Array = []      # Vector2i
	var pockets: Array = []     # Vector2i
	var stains: Array = []      # [x, y, class]

	## Within 3 px of one of the cluster's own tiles.
	func inarea(x: int, y: int) -> bool:
		for dy in [-3, 0, 3]:
			for dx in [-3, 0, 3]:
				if cells.has(Vector2i((x + dx) / 16, (y + dy) / 16)):
					return true
		return false

	func put(x: int, y: int, v: int, sid: int) -> void:
		var p := Vector2i(x, y)
		if v > int(metal.get(p, 0)):
			metal[p] = v
			owner[p] = sid

	func walk(x: int, y: int, sg: int, n: int, main: bool, sid: int, lean: int) -> void:
		var seg := 0
		var mode := 1
		var c := 0
		var forks := 0
		var pocket := rng.between(5, 8)
		var fork := rng.between(4, 8)
		for i in n:
			if seg == 0:
				var r := rng.below(100)
				var t: Array = LEAN[lean] if main else FORK_LEAN
				mode = 0 if r < int(t[0]) else (1 if r < int(t[1]) else (2 if r < int(t[2]) else 3))   # 0 steep, 1 diagonal, 2 flat, 3 kink
				seg = rng.between(2, 3) if mode == 3 else rng.between(2, 5)
				c = 0
			seg -= 1
			c += 1
			if mode == 0:
				y += 1
				if c % 3 == 0:
					x += sg
			elif mode == 1:
				y += 1
				x += sg
			elif mode == 2:
				x += sg
				if c % 2 == 0:
					y += 1
			else:
				y += 1
				x -= sg
			if not inarea(x, y) or (not main and i == n - 1):
				# The metal runs out; the crack carries on a little.
				var m := rng.between(3, 5)
				for j in m:
					if not metal.has(Vector2i(x, y)):
						cracks.append(Vector2i(x, y))
					y += 1
					if j % 2 == 1:
						x += sg
				return
			var near := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1, 2]:
					var o := int(owner.get(Vector2i(x + dx, y + dy), 0))
					if o != 0 and o != sid:
						near = true
			if main:
				put(x, y, EDGE, sid)
				if i > 1:
					if mode == 2:
						put(x, y + 1, BODY, sid)
					else:
						put(x + 1, y, BODY, sid)
			else:
				put(x, y, FORK, sid)
			cracks.append(Vector2i(x, y - 1) if mode == 2 else Vector2i(x - 1, y))
			if near:
				return              # ran into another seam: they join
			pocket -= 1
			fork -= 1
			if main and pocket <= 0:
				pocket = rng.between(7, 12)
				pockets.append(Vector2i(x, y))
				var wide := rng.below(100) < 60
				var high := rng.below(100) < 50
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					put(x + d.x, y + d.y, POCKET, sid)
				if wide:
					put(x + 2, y, POCKET, sid)
				if high:
					put(x + 1, y - 1, POCKET, sid)
				put(x - 1, y + 1, EDGE, sid)
				if kind == COPPER and rng.below(100) < 70:
					var m := rng.between(1, 3)
					for j in m:
						stains.append([x, y + 2 + j, STAIN if j == 0 else STAIN2])
			if main and fork <= 0 and forks < 4:
				fork = rng.between(8, 13)
				forks += 1
				var d := -sg if rng.below(100) < 75 else sg
				var m := rng.between(5, 10)
				walk(x, y, d, m, false, sid, 0)


## The first tile of a cluster in reading order (smallest y, then smallest x): its seed.
static func first_tile(cells: Array) -> Vector2i:
	var best: Vector2i = cells[0]
	for c: Vector2i in cells:
		if c.y < best.y or (c.y == best.y and c.x < best.x):
			best = c
	return best


## cells: the tiles (Vector2i, all at 1 or more) of ONE cluster of ore, tiles of the same kind that touch, corners
## included. Returns {"px": {Vector2i map pixel -> class}, "pockets": [Vector2i]}. No pixel lies more than 12 px outside
## the cluster's own tiles. A seam enters at the top of the cluster and wanders down in short straight runs, two
## pixels wide (EDGE on its left or upper side, BODY beside it), swelling into POCKETs and throwing off one-pixel
## FORKs; a CRACK runs along its upper left side and on past where the metal gives out; under a copper pocket a
## green STAIN weeps.
static func paths(cells: Array, kind: int, seed_value: int) -> Dictionary:
	var w := Walk.new()
	w.kind = kind
	var lo := 1 << 30
	var hi := -1
	for c: Vector2i in cells:
		w.cells[c] = true
		lo = mini(lo, c.x)
		hi = maxi(hi, c.x)
	var first := first_tile(cells)
	w.rng = Rng.new(vmix(seed_value, kind, first.x, first.y))
	var x0 := lo * T - 3
	var x1 := hi * T + T + 2
	var sg := 1 if w.rng.below(2) != 0 else -1
	var span := x1 - x0
	var n := maxi(1, (span + 20) / 40)          # about one seam for every two and a half tiles of width
	for i in n:
		var x := x0 + (i * span) / n + (span * (25 + w.rng.below(50))) / (100 * n) - sg * 8
		x = mini(x1, maxi(x0, x))
		var top := 1 << 30
		for c: Vector2i in cells:
			if c.x * T - 3 <= x and x <= c.x * T + T + 2:
				top = mini(top, c.y * T - 3)
		var off := w.rng.between(0, 5)
		if top < (1 << 30):
			w.walk(x, top + off, sg, 400, true, i + 1, (i + first.x) % 3)
	var out: Dictionary = w.metal.duplicate()
	for p: Vector2i in w.cracks:
		if not w.metal.has(p):
			out[p] = CRACK
	for s: Array in w.stains:
		var p := Vector2i(int(s[0]), int(s[1]))
		if not w.metal.has(p):
			out[p] = int(s[2])
	return {"px": out, "pockets": w.pockets}


## The colour of one vein pixel that lies in rock: material * 8 + step on its ramp, or -1 for "draw nothing".
## on_face: the pixel is on the rock's lit south face (else on its top). hgt: how many rock pixels lie under it before
## the ground (0 = the face's bottom row). depth: pixels in from the edge of the rock's top. ph: the pixel's own dice,
## vmix(x, y, seed, 7) % 100.
static func step(cls: int, kind: int, on_face: bool, hgt: int, depth: int, ph: int) -> int:
	if cls == CRACK:
		if on_face:
			return M_FACE * 8 + 1 if hgt > 0 else -1
		return M_CAP * 8 + 1 if depth < 12 else -1
	if cls == STAIN or cls == STAIN2:
		if on_face and hgt > 0:
			return M_VERD * 8 + (2 if cls == STAIN else 1)
		return -1
	var odds: int = GLINT_ODDS.get(cls, 0)
	if on_face:
		if hgt > 0 and ph < odds:
			return M_METAL * 8 + int(GLINT[kind])
		var st: int = FACE_STEP[kind][cls][1 if hgt >= 8 else 0]
		return M_METAL * 8 + (st - 1 if hgt == 0 and st > 0 else st)
	if depth >= GONE:
		return -1
	if depth >= 12 and (cls == BODY or cls == POCKET):
		return -1
	if depth >= 18 and ph < 60:
		return -1
	if depth >= 15 and ph < 30:
		return -1
	if depth >= 18 or (depth >= 15 and ph >= 70):
		return M_CAP * 8 + 1                    # the last of it: one step off black
	if depth >= 10:
		return M_METAL * 8 + (1 if cls == POCKET else 0)
	if ph < odds:
		return M_METAL * 8 + int(GLINT[kind])
	return M_METAL * 8 + int(TOP_STEP[kind][cls][0 if depth < 6 else 1])


## How far in from the edge of the rock's top a pixel lies, the art code's way: rounds of wearing the top away, a
## pixel going when one of its four neighbours has gone and, every second round, one of its diagonal ones too. That
## is the same as the nearest pixel that is not top, measured as max(a, ceil(2 (a + b) / 3)) for an offset of a and
## b pixels (a the larger), less one. `top` holds 1 for a pixel of rock top, row by row, w wide; past its edge
## counts as more top. Never more than `most`: ask for no more than is needed, a deep pixel costs the most to measure.
static func depth(top: PackedByteArray, w: int, h: int, x: int, y: int, most := GONE) -> int:
	var best := most + 1
	for r in range(1, most + 1):
		if best <= r:
			break
		var ya := y - r
		var yb := y + r
		var xa := x - r
		var xb := x + r
		for i in range(-r, r + 1):
			# The four sides of the ring r pixels out: the offset is (i, r) one way or the other.
			var d := maxi(r, (2 * (r + absi(i)) + 2) / 3)
			if d >= best:
				continue
			var px := x + i
			var py := y + i
			if (px >= 0 and px < w and ((ya >= 0 and top[ya * w + px] == 0) or (yb < h and top[yb * w + px] == 0))) or (py >= 0 and py < h and ((xa >= 0 and top[py * w + xa] == 0) or (xb < w and top[py * w + xb] == 0))):
				best = d
	return mini(best - 1, most)
