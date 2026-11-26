extends RefCounted
## The ground answering what grows in it (version 65): the Art builder's concept v4 and v4.1 for the Highlands, which
## Darren said go on (25 November 2026). Ports of the Art builder's own rules (hl_detail.py and hl_grow.py, in
## /mnt/project-files/art/highlands-light-concept-v4/code/), run on a chunk's two pictures (lit and in shadow) after
## the ground pieces are laid and before the shadows and the rock go on (land_painter.gd):
##
##   the trodden yard    the Scrapyard's yard trampled into the moor: no box, lobes of bare earth round the heaps,
##                       tongues of moor reaching in, grass surviving inside, the edge blending over 2 to 3 px
##                       (hl_grow.trample_yard)
##   turf                greener turf where the ground is damp: by water, in the hollows, in the lee under the rock;
##                       none on the paths; its edge breaking up into the moor grass (hl_detail.turf_rule, hl_grow.ragged)
##   texture             blades, tufts, specks, pebbles and soil crumbs in two or three close steps (hl_detail.detail)
##   flowers             drifts that are mostly specks in damp, greener turf, one or two clumps standing taller
##                       (hl_grow.flowerbed)
##   heather and sage    sprigs with no outline, drawn into the ground: the ground's own dark steps on their shaded
##                       side, a damp bed under them, blades over their foot (hl_grow.soften_plants)
##   marks               what each thing standing on the land leaves in the ground under it, cut from the Art builder's
##                       own seating code by tools/highlands_kit/bake.py: a tree's roots, canopy shadow and litter, a
##                       stone's damp bed, a heap's rust running downhill (hl_grow.tree, seat, bury)
##
## Every colour here is a step on one of the art's ramps, and a step in shadow is two darker, as everywhere in the land.
## Everything is chosen from the pixel's own place on the map, so chunks meet without a seam.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Snow := preload("res://scripts/highlands/snow.gd")
const FoePlan := preload("res://scripts/highlands/foe_plan.gd")

const T := 16
const CH := LandMap.CHUNK
const PX := CH * T
const FR := 8                    # tiles looked at past the chunk for the damp rule
const TURF_AT := 0.42            # the damp rule's line (hl_detail.turf_rule)
const STAMPS := 10               # texture stamps to a tile: one to about every 26 open pixels (hl_detail.detail)
## The ground's own blades and tufts (hl_detail): [dx, dy, steps up or down].
const BLADE := [[0, 0, 1], [0, -1, 1], [1, 0, -1]]
const VTUFT := [[0, 0, 1], [-1, -1, 1], [1, -1, 1], [0, 1, -1], [1, 1, -1]]
const LONGB := [[0, 0, 1], [0, -1, 1], [0, -2, 2], [1, 0, -1], [2, -1, 1], [2, 0, 1], [3, 0, -1]]
const SPECK := [[0, 0, -1]]
const SPECK_UP := [[0, 0, 1]]
const PRESSED := [[0, 0, 1], [1, 0, 1], [1, 1, -1]]
const CRUMB := [[0, 0, 1], [1, 0, 1]]
## The ground kinds a mark or a stamp may change, first to last (a colour two ramps share is the first one's).
const GROUND := ["grass", "turf", "earth", "mixg", "mixe", "rustsoil", "snow", "floor"]
const GREENS := ["grass", "turf", "mixg"]
const FLOWER_COLS := [["gold", "white", "pink"], ["gold", "blue"], ["white", "pink"]]   # (the concept's beds)
const BED_EVERY := 90            # a flower bed to about this many moor grass tiles

static var ready := false
static var ramps := {}           # ramp name -> PackedInt32Array, dark to light (colours as the pictures hold them)
static var by_id: Array = []     # the same, by ramp number
static var code_of := {}         # colour -> ramp number * 16 + step, for the ground ramps
static var names: Array = []     # ramp number -> name (the kit's "mats": a mark's material is its place in this list)
static var num := {}             # name -> ramp number
static var off := false          # (a check can switch the whole pass off, to compare)
static var DAMP_REACH := 1.0     # how far the damp rule reaches from water, hollows and rock (the lab; version 66)
static var FOLIAGE := 1.0        # how many drifts of foliage (the lab; 0 = none; version 66)
static var note := false         # (for the checks: while on, every foliage plant laid is noted in `noted`)
static var noted: Array = []     # [x, y (the land's pixels), picture's name, in the snow's picture]
static var G_GRASS := -1         # the numbers of the ramps used most
static var G_TURF := -1
static var G_MIXG := -1
static var G_EARTH := -1
static var G_MIXE := -1
static var G_FACE := -1
static var G_SNOW := -1
static var G_FLOOR := -1
static var open_ids := {}        # the open ground's ramps: texture goes on these


static func setup(kit: Dictionary) -> void:
	if ready:
		return
	var pal: Dictionary = kit.get("palette", {})
	names = kit.get("mats", [])
	for i in names.size():
		num[str(names[i])] = i
	for name in pal:
		var arr := PackedInt32Array()
		for h in pal[name]:
			arr.append(c32(Color(str(h))))
		ramps[str(name)] = arr
	by_id = []
	for i in names.size():
		by_id.append(ramps.get(str(names[i]), PackedInt32Array([0])))
	for name in GROUND:
		if not ramps.has(name) or not num.has(name):
			continue
		var arr: PackedInt32Array = ramps[name]
		for k in arr.size():
			if not code_of.has(arr[k]):
				code_of[arr[k]] = int(num[name]) * 16 + k
	G_GRASS = _rid("grass")
	G_TURF = _rid("turf")
	G_MIXG = _rid("mixg")
	G_EARTH = _rid("earth")
	G_MIXE = _rid("mixe")
	G_FACE = _rid("face")
	G_SNOW = _rid("snow")
	G_FLOOR = _rid("floor")
	for n in [G_GRASS, G_TURF, G_EARTH, G_MIXG, G_MIXE]:
		if n >= 0:
			open_ids[n] = true
	ready = not names.is_empty() and G_TURF >= 0 and G_EARTH >= 0 and G_MIXG >= 0 and G_MIXE >= 0


## A colour as the pictures' data holds it, read four bytes at a time (red lowest).
static func c32(c: Color) -> int:
	var v := c.r8 | (c.g8 << 8) | (c.b8 << 16) | (255 << 24)
	return v - 4294967296 if v >= 2147483648 else v


static func _rid(name: String) -> int:
	return int(num.get(name, -1))


static func _h(x: int, y: int, s: int) -> int:
	var n := (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	n = (n ^ (n >> 15)) * 2246822519
	n = (n ^ (n >> 13)) * 3266489917
	return (n ^ (n >> 16)) & 0x7fffffff


static func _f(x: int, y: int, s: int) -> float:
	return float(_h(x, y, s) & 0xffff) / 65536.0


## Smooth noise from 0 to 1, `period` pixels from one bump to the next (the same values as LNoise below).
static func _smooth(x: float, y: float, period: float, salt: int) -> float:
	var ix := floori(x / period)
	var iy := floori(y / period)
	var tx := x / period - float(ix)
	var ty := y / period - float(iy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	return lerpf(lerpf(_f(ix, iy, salt), _f(ix + 1, iy, salt), tx), lerpf(_f(ix, iy + 1, salt), _f(ix + 1, iy + 1, salt), tx), ty)


## Smooth noise over one chunk, its lattice worked out once (the same values as _smooth, so chunks meet).
class LNoise:
	var p := 1.0
	var ix0 := 0
	var iy0 := 0
	var nw := 0
	var v := PackedFloat32Array()

	func _init(period: float, lattice: PackedFloat32Array, i0: int, j0: int, w: int) -> void:
		p = period
		v = lattice
		ix0 = i0
		iy0 = j0
		nw = w

	func at(x: float, y: float) -> float:
		var u := x / p
		var w := y / p
		var i := floori(u)
		var j := floori(w)
		var tx := u - i
		var ty := w - j
		tx = tx * tx * (3.0 - 2.0 * tx)
		ty = ty * ty * (3.0 - 2.0 * ty)
		var k := (j - iy0) * nw + (i - ix0)
		return lerpf(lerpf(v[k], v[k + 1], tx), lerpf(v[k + nw], v[k + nw + 1], tx), ty)


static func _noise(period: float, salt: int, ox: int, oy: int) -> LNoise:
	var i0 := floori(ox / period) - 1
	var j0 := floori(oy / period) - 1
	var w := floori((ox + PX) / period) + 3 - i0
	var h := floori((oy + PX) / period) + 3 - j0
	var lat := PackedFloat32Array()
	lat.resize(w * h)
	for j in h:
		for i in w:
			lat[j * w + i] = _f(i0 + i, j0 + j, salt)
	return LNoise.new(period, lat, i0, j0, w)


## What a chunk's passes share: the tiles round it (FR past its edge), and which of its own tiles can show ground.
class Ctx:
	var kinds := PackedByteArray()  # (CH + 2 FR)^2 tile kinds
	var tones := PackedByteArray()
	var live := PackedByteArray()   # CH^2: 1 where the tile or one round it is open (an inner tile of a hill shows none)
	var ox := 0
	var oy := 0
	var x0 := 0
	var y0 := 0


static func _ctx(m: LandMap, cx: int, cy: int) -> Ctx:
	var c := Ctx.new()
	c.x0 = cx * CH
	c.y0 = cy * CH
	c.ox = cx * PX
	c.oy = cy * PX
	var n := CH + FR * 2
	c.kinds.resize(n * n)
	c.tones.resize(n * n)
	for j in n:
		for i in n:
			var k := m.kind(c.x0 + i - FR, c.y0 + j - FR)
			c.kinds[j * n + i] = k
			if not LandMap.rocky(k):
				c.tones[j * n + i] = m.tone(c.x0 + i - FR, c.y0 + j - FR)
	c.live.resize(CH * CH)
	for lj in CH:
		for li in CH:
			var open := false
			for dj in range(-1, 2):
				for di in range(-1, 2):
					if not LandMap.rocky(c.kinds[(lj + FR + dj) * n + li + FR + di]):
						open = true
			c.live[lj * CH + li] = 1 if open else 0
	return c


## Runs every pass on chunk (cx, cy). The painter calls it with its pictures, before the shadows and the rock.
## `things` are the kit's things for the chunk (the snow kit's in the snow), `th` their sheet, `mk` their marks.
static func grow(lit_img: Image, shade_img: Image, m: LandMap, cx: int, cy: int, snow: bool, things: Dictionary, th: Image, mk: Image, world: int) -> void:
	if not ready or off:
		return
	var lit := lit_img.get_data().to_int32_array()
	var shade := shade_img.get_data().to_int32_array()
	var t := Time.get_ticks_usec()
	var c := _ctx(m, cx, cy)
	t = _tick("ctx", t)
	if not snow:
		_turf(lit, shade, c)
		t = _tick("turf", t)
		_stamps(lit, shade, c)
		t = _tick("stamps", t)
		_trample(lit, shade, m, c)
		t = _tick("trample", t)
		_flowers(lit, shade, c, world, things, th)
		t = _tick("flowers", t)
	_plants(lit, shade, m, cx, cy, things, th, snow)
	t = _tick("plants", t)
	_foliage(lit, shade, m, c, things, th, snow, world)
	t = _tick("foliage", t)
	_marks(lit, shade, m, cx, cy, things, mk)
	t = _tick("marks", t)
	lit_img.set_data(PX, PX, false, Image.FORMAT_RGBA8, lit.to_byte_array())
	shade_img.set_data(PX, PX, false, Image.FORMAT_RGBA8, shade.to_byte_array())


static var prof: Dictionary = {}   # (a check can read how long each pass took, in microseconds)

static func _tick(k: String, t: int) -> int:
	var now := Time.get_ticks_usec()
	prof[k] = int(prof.get(k, 0)) + now - t
	return now


# --- reading and writing a pixel as a step on a ramp ---------------------------------------------------------------

static func _code(a: PackedInt32Array, q: int) -> int:
	return code_of.get(a[q], -1)


## Pixel q becomes step `st` of ramp `r` (by number), and its shadow two steps darker.
static func _put(lit: PackedInt32Array, shade: PackedInt32Array, q: int, r: int, st: int) -> void:
	var ramp: PackedInt32Array = by_id[r]
	st = clampi(st, 0, ramp.size() - 1)
	lit[q] = ramp[st]
	shade[q] = ramp[maxi(st - 2, 0)]


## A stamp of the ground's own blades: each pixel a step or two up or down on the open ground's ramp it is on.
static func _stamp(lit: PackedInt32Array, shade: PackedInt32Array, x: int, y: int, pat: Array) -> void:
	for p in pat:
		var X: int = x + int(p[0])
		var Y: int = y + int(p[1])
		if X < 0 or Y < 0 or X >= PX or Y >= PX:
			continue
		var q := Y * PX + X
		var c: int = code_of.get(lit[q], -1)
		if c < 0 or not open_ids.has(c >> 4):
			continue
		_put(lit, shade, q, c >> 4, (c & 15) + int(p[2]))


# --- the trodden yard ----------------------------------------------------------------------------------------------

## The Scrapyard's yard trodden into the moor (hl_grow.trample_yard, v4.1): no box, lobes of bare earth where feet go
## (under the gate, round each heap, in the middle), joined by worn lanes; tongues of moor reaching in from the edge,
## patches of grass surviving inside, the edge blending into the grass through a mixed band, grass blades reaching onto
## the earth. Lobes and lanes in the chunk's own pixels: [x, y, rx, ry] and [ax, ay, bx, by, width].
static func _yard_shape(m: LandMap, c: Ctx) -> Array:
	var site: Dictionary = m.sites.get("scrapyard", {})
	if site.is_empty() or not site.has("gate"):
		return []
	var gate: Vector2i = site["gate"]
	var at: Vector2 = site["at"]
	var g := Vector2((gate.x + 0.5) * T - c.ox, (gate.y + 1) * T + 6 - c.oy)
	var mid := Vector2(at.x * T - c.ox, at.y * T - c.oy)
	var lo := minf(g.x, mid.x) - 200.0
	var hi := maxf(g.x, mid.x) + 200.0
	if hi < -8 or lo > PX + 8 or maxf(g.y, mid.y) + 120.0 < -8 or minf(g.y, mid.y) - 40.0 > PX + 8:
		return []
	var lobes: Array = [[g.x, g.y, 74.0, 20.0], [mid.x, mid.y, 72.0, 34.0]]
	var lanes: Array = [[g.x, g.y, mid.x, mid.y, 14.0], [mid.x, mid.y, mid.x, mid.y + 44.0, 7.0]]
	var ccx := floori(float(c.ox) / PX)
	var ccy := floori(float(c.oy) / PX)
	for dj in range(-2, 3):
		for di in range(-2, 3):
			for t in m.things_in(ccx + di, ccy + dj):
				var name := str(t["n"])
				if not name.begins_with("heap_"):
					continue
				var w := 66.0 - 10.0 * int(name.substr(5))           # (heap_0 is the biggest)
				var hp := Vector2(float(t["x"]) - c.ox, float(t["y"]) - c.oy - 4.0)
				lobes.append([hp.x, hp.y, w * 0.85, w * 0.4])
				lanes.append([hp.x, hp.y, mid.x, mid.y, 13.0])
	return [lobes, lanes]


static func _trample(lit: PackedInt32Array, shade: PackedInt32Array, m: LandMap, c: Ctx) -> void:
	var shape := _yard_shape(m, c)
	if shape.is_empty():
		return
	var lobes: Array = shape[0]
	var lanes: Array = shape[1]
	# only the part of the chunk the lobes and lanes can reach
	var x0 := PX
	var y0 := PX
	var x1 := 0
	var y1 := 0
	for l in lobes:
		x0 = mini(x0, floori(l[0] - l[2] * 1.5))
		x1 = maxi(x1, ceili(l[0] + l[2] * 1.5))
		y0 = mini(y0, floori(l[1] - l[3] * 1.5))
		y1 = maxi(y1, ceili(l[1] + l[3] * 1.5))
	x0 = maxi(x0, 0)
	y0 = maxi(y0, 0)
	x1 = mini(x1, PX)
	y1 = mini(y1, PX)
	if x0 >= x1 or y0 >= y1:
		return
	var ox := c.ox
	var oy := c.oy
	var n8 := _noise(8.0, 78, ox, oy)
	var n3 := _noise(3.0, 79, ox, oy)
	var n22 := _noise(22.0, 75, ox, oy)
	var n11 := _noise(11.0, 76, ox, oy)
	for py in range(y0, y1):
		var Y := oy + py
		for px in range(x0, x1):
			var q := py * PX + px
			var cd: int = code_of.get(lit[q], -1)
			if cd < 0:
				continue
			var g := cd >> 4
			if g != G_GRASS and g != G_TURF and g != G_MIXG:
				continue
			var f := 0.0
			for l in lobes:
				var dx: float = (px - l[0]) / l[2]
				var dy: float = (py - l[1]) / l[3]
				f = maxf(f, 1.0 - sqrt(dx * dx + dy * dy))
			for l in lanes:
				var vx: float = l[2] - l[0]
				var vy: float = l[3] - l[1]
				var t := clampf(((px - l[0]) * vx + (py - l[1]) * vy) / maxf(vx * vx + vy * vy, 1.0), 0.0, 1.0)
				var ex: float = px - l[0] - t * vx
				var ey: float = (py - l[1] - t * vy) * 1.5
				f = maxf(f, 1.0 - sqrt(ex * ex + ey * ey) / l[4])
			if f < 0.0:
				continue
			var X := ox + px
			f += 0.6 * (n8.at(float(X), float(Y)) - 0.5) + 0.3 * (n3.at(float(X), float(Y)) - 0.5)
			if f < 0.22:
				continue
			# tongues of moor reaching in along winding lines, near the edge only; grass surviving deep inside
			var ridge := absf(n22.at(float(X), float(Y)) - 0.5) * 2.0
			f -= 0.45 * maxf(0.0, 1.0 - ridge * 16.0) * clampf((0.9 - f) * 2.0, 0.0, 1.0)
			if f > 0.75 and n11.at(float(X), float(Y)) > 0.8 + (_f(X, Y, 77) - 0.5) * 0.06:
				continue
			var r := _f(X, Y, 80)
			if f > 0.32:
				if f < 0.355 and r < 0.5 - (f - 0.32) * 8.0:
					_put(lit, shade, q, G_MIXE, cd & 15)            # the mixed band, inside
				elif f < 0.37 and r > 0.75:
					_put(lit, shade, q, G_GRASS, 3 + (1 if _f(X, Y, 81) < 0.5 else 0))    # a grass blade reaching onto the earth
				else:
					var h := _h(X, Y, 82)
					_put(lit, shade, q, G_EARTH, 1 + (1 if (h & 1023) < 512 else 0) + (1 if ((h >> 10) & 1023) < 205 else 0))
			elif f > 0.24 and r < 0.6 * (f - 0.24) / 0.08:
				_put(lit, shade, q, G_MIXE, cd & 15)                # and outside


# --- turf by the damp rule -----------------------------------------------------------------------------------------

## The damp rule's value at each tile centre round the chunk (hl_detail.turf_rule): near water, in the hollows, in the
## lee under the rock; less on the paths and the yard.
static func _damp(c: Ctx) -> PackedFloat32Array:
	var n := CH + FR * 2
	var wet := PackedFloat32Array()
	var hol := PackedFloat32Array()
	var lee := PackedFloat32Array()
	var walk := PackedFloat32Array()
	for a in [wet, hol, lee, walk]:
		a.resize(n * n)
	for q in n * n:
		var k := c.kinds[q]
		if k == LandMap.WATER:
			wet[q] = 1.0
		elif LandMap.rocky(k):
			lee[q] = 1.0
		elif k == LandMap.PATH or k == LandMap.YARD:
			walk[q] = 1.0
		elif (k == LandMap.GRASS or k == LandMap.HEATH or k == LandMap.SCRUB) and c.tones[q] == 0:
			hol[q] = 1.0
	var out := PackedFloat32Array()
	out.resize(n * n)
	var bw := _blur(wet, n, 22.0 / T * DAMP_REACH)
	var bh := _blur(hol, n, 14.0 / T * DAMP_REACH)
	var bl := _blur(lee, n, 10.0 / T * DAMP_REACH)
	var bk := _blur(walk, n, 7.0 / T)
	for q in n * n:
		out[q] = bw[q] * 3.2 + bh[q] * 0.45 + bl[q] * 0.75 - bk[q] * 2.4
	return out


static func _blur(a: PackedFloat32Array, n: int, sigma: float) -> PackedFloat32Array:
	var r := mini(FR - 1, ceili(sigma * 3.0))
	var w := PackedFloat32Array()
	var sum := 0.0
	for d in range(-r, r + 1):
		var v := exp(-0.5 * (float(d) / sigma) * (float(d) / sigma))
		w.append(v)
		sum += v
	for i in w.size():
		w[i] /= sum
	var b := PackedFloat32Array()
	b.resize(n * n)
	for j in n:
		for i in n:
			var s := 0.0
			for d in range(-r, r + 1):
				s += a[j * n + clampi(i + d, 0, n - 1)] * w[d + r]
			b[j * n + i] = s
	var out := PackedFloat32Array()
	out.resize(n * n)
	for j in n:
		for i in n:
			var s := 0.0
			for d in range(-r, r + 1):
				s += b[clampi(j + d, 0, n - 1) * n + i] * w[d + r]
			out[j * n + i] = s
	return out


## The damp rule's value at pixel (px, py) of the chunk (it may be a little outside): the tile-centre values blended,
## with the rule's own noise (hl_detail.turf_rule: 0.22 of a rough noise and 0.12 of a slow wave). Only on the moor's
## own ground (grass, heather, sage): never on paths, water or rock.
static func _turf_f(c: Ctx, F: PackedFloat32Array, px: int, py: int) -> float:
	var n := CH + FR * 2
	var u := (float(px) + 0.5) / T - 0.5 + FR
	var v := (float(py) + 0.5) / T - 0.5 + FR
	var i0 := floori(u)
	var j0 := floori(v)
	var fx := u - i0
	var fy := v - j0
	var k := j0 * n + i0
	var f := lerpf(lerpf(F[k], F[k + 1], fx), lerpf(F[k + n], F[k + n + 1], fx), fy)
	var X := c.ox + px
	var Y := c.oy + py
	return f + 0.22 * (float(_h(floori(X / 3.0), floori(Y / 3.0), 51) & 1023) / 1023.0 - 0.5) + 0.12 * sin(X / 13.0 + sin(Y / 9.0) * 2.0)


static func _turf_ground(k: int) -> bool:
	return k == LandMap.GRASS or k == LandMap.HEATH or k == LandMap.SCRUB


## Turf where the rule says, on the moor grass; its edge blended into the grass over 2 to 3 px (a band of the mixed ramp,
## single pixels of each reaching into the other: hl_grow.ragged), a fringe of turf blades reaching out over the grass,
## and blades reaching up from its top edge (hl_detail.detail, hl_grow.land_pass).
static func _turf(lit: PackedInt32Array, shade: PackedInt32Array, c: Ctx) -> void:
	var F := _damp(c)
	var n := CH + FR * 2
	var ox := c.ox
	var oy := c.oy
	var is_turf := PackedByteArray()
	is_turf.resize(PX * PX)
	var has_turf := PackedByteArray()
	has_turf.resize(CH * CH)
	var nr := _noise(3.0, 56, ox, oy)
	const WN := T + 6                       # a tile and the 3 px round it
	const OUT_P := [0.0, 0.75, 0.45, 0.18]  # the chance a grass pixel 1, 2, 3 px out goes to the mixed band
	var mask := PackedByteArray()
	mask.resize(WN * WN)
	var rin := PackedByteArray()            # along each row: how far to the nearest pixel out of the turf (at most 3)
	var rout := PackedByteArray()           # and to the nearest turf pixel (at most 4)
	rin.resize(WN * WN)
	rout.resize(WN * WN)
	for lj in CH:
		for li in CH:
			if c.live[lj * CH + li] == 0:
				continue
			# the rule's value anywhere within 3 px of this tile lies between the 5x5 tile centres' round it (and the
			# noise moves it 0.23 at most)
			var fmin := 99.0
			var fmax := -99.0
			var all_ground := true
			for dj in range(-2, 3):
				for di in range(-2, 3):
					var fv := F[(lj + FR + dj) * n + li + FR + di]
					fmin = minf(fmin, fv)
					fmax = maxf(fmax, fv)
					if absi(di) < 2 and absi(dj) < 2 and not _turf_ground(c.kinds[(lj + FR + dj) * n + li + FR + di]):
						all_ground = false
			if fmax + 0.23 <= TURF_AT:
				continue                           # nowhere near damp enough
			has_turf[lj * CH + li] = 1
			if all_ground and fmin - 0.23 > TURF_AT:
				for y in T:                        # all of it turf
					var q0 := (lj * T + y) * PX + li * T
					for q in range(q0, q0 + T):
						var cd: int = code_of.get(lit[q], -1)
						if cd >= 0 and (cd >> 4) == G_GRASS:
							_put(lit, shade, q, G_TURF, cd & 15)
							is_turf[q] = 1
				continue
			# where the turf is, on this tile and 3 px round it
			var ok := PackedByteArray()
			ok.resize(9)
			for dj in range(-1, 2):
				for di in range(-1, 2):
					ok[(dj + 1) * 3 + di + 1] = 1 if _turf_ground(c.kinds[(lj + FR + dj) * n + li + FR + di]) else 0
			var any := false
			for wy in WN:
				var py := lj * T - 3 + wy
				var tj := 0 if wy < 3 else (2 if wy >= T + 3 else 1)
				for wx in WN:
					var ti := 0 if wx < 3 else (2 if wx >= T + 3 else 1)
					var on := ok[tj * 3 + ti] == 1 and _turf_f(c, F, li * T - 3 + wx, py) > TURF_AT
					mask[wy * WN + wx] = 1 if on else 0
					any = any or on
			if not any:
				continue
			for wy in WN:
				var row := wy * WN
				var dI := 3
				var dO := 4
				for wx in WN:
					if mask[row + wx] == 1:
						dI = mini(dI + 1, 3)
						dO = 0
					else:
						dI = 0
						dO = mini(dO + 1, 4)
					rin[row + wx] = dI
					rout[row + wx] = dO
				dI = 3
				dO = 4
				for wx in range(WN - 1, -1, -1):
					if mask[row + wx] == 1:
						dI = mini(dI + 1, 3)
						dO = 0
					else:
						dI = 0
						dO = mini(dO + 1, 4)
					rin[row + wx] = mini(rin[row + wx], dI)
					rout[row + wx] = mini(rout[row + wx], dO)
			for y in T:
				var wy := y + 3
				var py := lj * T + y
				var Y := oy + py
				for x in T:
					var wx := x + 3
					var px := li * T + x
					var q := py * PX + px
					var cd: int = code_of.get(lit[q], -1)
					if cd < 0 or (cd >> 4) != G_GRASS:
						continue
					var X := ox + px
					var r := 0.55 * _f(X, Y, 55) + 0.32 * (nr.at(float(X), float(Y)) - 0.5) + 0.05
					var st := cd & 15
					if mask[wy * WN + wx] == 1:
						var d := 3
						for dj in range(-2, 3):
							d = mini(d, maxi(absi(dj), rin[(wy + dj) * WN + wx]))
						if (d == 1 and r < 0.40) or (d == 2 and r < 0.15):
							_put(lit, shade, q, G_MIXG, st)          # the turf thinning into the grass, inside its edge
						else:
							_put(lit, shade, q, G_TURF, st)
							is_turf[q] = 1
					else:
						var d := 4
						for dj in range(-3, 4):
							d = mini(d, maxi(absi(dj), rout[(wy + dj) * WN + wx]))
						if d > 3:
							continue
						if _h(X, Y, 53) % 6 == 0:
							for p in [[0, 0, 3], [0, -1, 4], [1, 0, 2]]:    # a blade of turf reaching out over the grass
								var XX: int = px + int(p[0])
								var YY: int = py + int(p[1])
								if XX < PX and YY >= 0:
									var qq := YY * PX + XX
									var cc: int = code_of.get(lit[qq], -1)
									if cc >= 0 and (cc >> 4) == G_GRASS:
										_put(lit, shade, qq, G_TURF, int(p[2]))
						elif r < OUT_P[d]:
							_put(lit, shade, q, G_MIXG, st)              # and outside it
	# Turf blades reaching up into the grass above its top edge (hl_grow.land_pass).
	for lj in CH:
		for li in CH:
			if has_turf[lj * CH + li] == 0:
				continue
			for y in T:
				var py := lj * T + y
				if py < 2:
					continue
				for x in T:
					var px := li * T + x
					var q := py * PX + px
					if is_turf[q] == 0:
						continue
					var up: int = code_of.get(lit[q - PX], -1)
					if up < 0 or (up >> 4) != G_GRASS:
						continue
					var h := _h(ox + px, oy + py, 54)
					if h % 3 != 0:
						continue
					var st: int = code_of.get(lit[q], 0) & 15
					_put(lit, shade, q - PX, G_TURF, st + 1)
					var up2: int = code_of.get(lit[q - PX * 2], -1)
					if up2 >= 0 and ((up2 >> 4) == G_GRASS or (up2 >> 4) == G_MIXG) and (h >> 8) % 2 == 0:
						_put(lit, shade, q - PX * 2, G_TURF, st + 2)


# --- texture -------------------------------------------------------------------------------------------------------

## Blades, tufts, specks, pebbles and crumbs on all the open ground, STAMPS to a tile, the kind of
## stamp by what the ground is (hl_detail.detail): trodden earth has specks, pressed stones and pebbles; turf has tufts,
## long blades and the odd flower; the moor grass blades, tufts, specks, pebbles and soil crumbs.
static func _stamps(lit: PackedInt32Array, shade: PackedInt32Array, c: Ctx) -> void:
	var gold := _rid("gold")
	var heath := _rid("heath")
	var flag := _rid("flag")
	var ox := c.ox
	var oy := c.oy
	for lj in CH:
		for li in CH:
			if c.live[lj * CH + li] == 0:
				continue
			for k in STAMPS:
				var h := _h(c.x0 + li, c.y0 + lj, 61 + k * 13)
				var px := li * T + (h & 15)
				var py := lj * T + ((h >> 4) & 15)
				var q := py * PX + px
				var cd: int = code_of.get(lit[q], -1)
				if cd < 0 or not open_ids.has(cd >> 4):
					continue
				var r := float((h >> 8) & 0xffff) / 65536.0
				var g := cd >> 4
				if g == G_EARTH:
					if r < 0.5:
						_stamp(lit, shade, px, py, SPECK)
					elif r < 0.8:
						_stamp(lit, shade, px, py, PRESSED)
					else:
						_put(lit, shade, q, G_FACE, 4)
						if px + 1 < PX:
							_put(lit, shade, q + 1, G_FACE, 3)
						if py + 1 < PX:
							_stamp(lit, shade, px, py + 1, SPECK)
				elif g == G_TURF:
					if r < 0.40:
						_stamp(lit, shade, px, py, VTUFT)
					elif r < 0.62:
						_stamp(lit, shade, px, py, LONGB)
					elif r < 0.80:
						_stamp(lit, shade, px, py, SPECK)
					elif r < 0.94:
						var kf := (h >> 24) % 3
						if kf == 0:
							_put(lit, shade, q, gold, 2)
						elif kf == 1:
							_put(lit, shade, q, heath, 4)
						else:
							_put(lit, shade, q, flag, 6)
						if py + 1 < PX:
							_stamp(lit, shade, px, py + 1, SPECK)
					else:
						_stamp(lit, shade, px, py, BLADE)
				else:
					if r < 0.34:
						_stamp(lit, shade, px, py, BLADE)
					elif r < 0.52:
						_stamp(lit, shade, px, py, VTUFT)
					elif r < 0.78:
						_stamp(lit, shade, px, py, SPECK)
					elif r < 0.84:
						_put(lit, shade, q, G_FACE, 5 if r < 0.85 else 4)
						if py + 1 < PX:
							_stamp(lit, shade, px, py + 1, [[0, 0, -2]])
					else:
						_stamp(lit, shade, px, py, CRUMB)


# --- the ground under what grows in it -----------------------------------------------------------------------------

## The ground under a plant or a drift (hl_grow.bed): damper and darker toward the middle, greener where it was moor
## grass; the edge breaks up into single pixels, never a line. (cx, cy, rx, ry in the chunk's own pixels.)
static func _bed(lit: PackedInt32Array, shade: PackedInt32Array, ox: int, oy: int, cx: float, cy: float, rx: float, ry: float, green: bool, deep: int, edge: float, core := true, only: Array = []) -> void:
	for y in range(maxi(0, floori(cy - ry - 2)), mini(PX, ceili(cy + ry + 3))):
		for x in range(maxi(0, floori(cx - rx - 2)), mini(PX, ceili(cx + rx + 3))):
			var q := y * PX + x
			var cd: int = code_of.get(lit[q], -1)
			if cd < 0 or (not only.is_empty() and not only.has(cd >> 4)):
				continue
			var X := ox + x
			var Y := oy + y
			var ddx := (x - cx) / maxf(rx, 1.0)
			var ddy := (y - cy) / maxf(ry, 1.0)
			var d := ddx * ddx + ddy * ddy + (_f(X, Y, 91) - 0.5) * edge
			var g := cd >> 4
			var st := cd & 15
			if green and (g == G_GRASS or g == G_MIXG):
				if d < 0.55 or (g == G_MIXG and d < 0.4):
					g = G_TURF
				elif d < 1.0 and g == G_GRASS:
					g = G_MIXG
			if d < 0.75 or (d < 1.05 and (X + Y) % 2 == 0):
				st -= deep
				if deep > 0 and core and d < 0.3 and (X + 2 * Y) % 3 != 0:
					st -= 1
			if g != (cd >> 4) or st != (cd & 15):
				_put(lit, shade, q, g, st)


# --- flowers -------------------------------------------------------------------------------------------------------

## Flowers in beds here and there in the moor grass (hl_grow.flowerbed): a drift that is mostly specks in the turf,
## thick in the middle, single specks at the edge, a damper greener ground under it, and one or two clumps standing
## taller. Each bed's colours are those of the part of the map it is in (the map's own drift fields).
static func _flowers(lit: PackedInt32Array, shade: PackedInt32Array, c: Ctx, world: int, things: Dictionary, th: Image) -> void:
	var stem := _rid("f_stem")
	var ox := c.ox
	var oy := c.oy
	var n := CH + FR * 2
	var beds: Array = []
	for tj in range(-3, CH + 3):
		for ti in range(-3, CH + 3):
			var i := (tj + FR) * n + ti + FR
			if c.kinds[i] != LandMap.GRASS or c.tones[i] == 0:
				continue
			var h := _h(c.x0 + ti, c.y0 + tj, 301 + world)
			if h % BED_EVERY != 0:
				continue
			var kind := 0
			var best := -1.0
			for k in 3:
				var v := _drift(float(c.x0 + ti), float(c.y0 + tj), k, world)
				if v > best:
					best = v
					kind = k
			beds.append([tj * T + 2 + (h >> 8) % 12, ti * T + 2 + (h >> 12) % 12, 16 + (h >> 16) % 11, 7 + (h >> 20) % 4, kind, h])
	if beds.is_empty():
		return
	beds.sort()
	var tall: Array = []
	for b in beds:
		var cy: int = b[0]
		var cx: int = b[1]
		var rx: float = b[2]
		var ry: float = b[3]
		if cx + rx * 1.6 < 0 or cx - rx * 1.6 >= PX or cy + ry * 1.6 < 0 or cy - ry * 1.6 >= PX:
			continue
		var cols: Array = FLOWER_COLS[int(b[4])]
		var ids: Array = []
		for col in cols:
			ids.append(_rid("f_" + str(col)))
		if ids.has(-1):
			continue
		_bed(lit, shade, ox, oy, cx, cy, rx * 1.15, ry * 1.15, true, 1, 0.6)
		for y in range(maxi(1, floori(cy - ry * 1.4)), mini(PX - 2, ceili(cy + ry * 1.4))):
			var Y := oy + y
			for x in range(maxi(0, floori(cx - rx * 1.4)), mini(PX, ceili(cx + rx * 1.4))):
				var q := y * PX + x
				var cd: int = code_of.get(lit[q], -1)
				if cd < 0:
					continue
				var g := cd >> 4
				if g != G_GRASS and g != G_TURF and g != G_MIXG:
					continue
				var X := ox + x
				var ddx := (x - cx) / rx
				var ddy := (y - cy) / ry
				var d := ddx * ddx + ddy * ddy
				var p := 0.10 * pow(maxf(0.0, 1.0 - d), 1.3) + (0.012 if d < 1.9 else 0.0)
				var r := _f(X, Y, 93)
				if r < p:
					# a speck: one or two pixels of colour, a step darker under it, sometimes a stem (hl_grow.speck)
					var h2 := _h(X, Y, 94)
					var fid: int = ids[(h2 & 1023) % ids.size()] if (h2 >> 10) % 5 != 0 else ids[0]
					_put(lit, shade, q, fid, 2 if ((h2 >> 13) & 1023) < 717 else 1)
					if x + 1 < PX and ((h2 >> 23) & 255) < 90 and code_of.has(lit[q + 1]):
						_put(lit, shade, q + 1, fid, 1)
					var below := q + PX
					if stem >= 0 and (_h(X, Y, 97) & 1023) < 460:
						_put(lit, shade, below, stem, 1)
						below += PX
					var cb: int = code_of.get(lit[below], -1)
					if cb >= 0:
						_put(lit, shade, below, cb >> 4, (cb & 15) - 1)
				elif _f(X, Y, 95) < p * 0.8:
					_stamp(lit, shade, x, y, BLADE if (_h(X, Y, 96) & 1) == 0 else LONGB)
		var hb: int = b[5]
		for k in 2:
			var hh := _h(hb, k, 100)
			tall.append([cy + int((float(hh & 255) / 255.0 - 0.5) * ry * 0.8), cx + int((float((hh >> 8) & 255) / 255.0 - 0.5) * rx), "flower_%d" % ((hh >> 16) % 6)])
	tall.sort()
	for t in tall:
		_soft(lit, shade, ox, oy, things, th, str(t[2]), int(t[1]), int(t[0]), [[1, 0, 2], [0, 1, 2], [1, 1, 1], [-1, 0, 1]], true)


static func _drift(x: float, y: float, k: int, world: int) -> float:
	return _smooth(x, y, 6.0, 310 + k * 7 + world)


# --- heather and sage ----------------------------------------------------------------------------------------------

## The map's heather and sage plants round the chunk, drawn into the ground in order down the picture.
static func _plants(lit: PackedInt32Array, shade: PackedInt32Array, m: LandMap, cx: int, cy: int, things: Dictionary, th: Image, snow: bool) -> void:
	var ox := cx * PX
	var oy := cy * PX
	var list: Array = []
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for pl in m.plants_in(cx + di, cy + dj):
				list.append([int(pl["y"]) - oy, int(pl["x"]) - ox, str(pl["n"])])
	list.sort()
	for p in list:
		var name: String = p[2]
		var heath := name.begins_with("heath_")
		var sides := [[1, 0, 2], [0, 1, 2], [1, 1, 1], [-1, 0, 1]] if heath else [[0, 1, 1], [1, 1, 1]]
		_soft(lit, shade, ox, oy, things, th, name, int(p[1]), int(p[0]), sides, not snow, not heath)


static var _px_cache := {}       # a plant's picture's pixels: name -> [[x, y, lit, shade], ...] from its top left

static func _pixels(things: Dictionary, th: Image, name: String) -> Array:
	var key := "%s@%d" % [name, th.get_instance_id()]
	if _px_cache.has(key):
		return _px_cache[key]
	var out: Array = []
	var info: Dictionary = things.get(name, {})
	var info2: Dictionary = things.get(name + "~", {})
	if not info.is_empty() and not info2.is_empty():
		var r: Array = info["rect"]
		var r2: Array = info2["rect"]
		for j in int(r[3]):
			for i in int(r[2]):
				var a := th.get_pixel(int(r[0]) + i, int(r[1]) + j)
				if a.a8 > 0:
					out.append([i, j, c32(a), c32(th.get_pixel(int(r2[0]) + i, int(r2[1]) + j))])
	_px_cache[key] = out
	return out


## One small plant drawn into the ground with its foot at (x, y) in the chunk's pixels: a damp bed under it, the
## ground's own dark steps on its shaded side (no outline), its own pixels (lit, and its "~" picture in shadow), and
## the ground's blades over its foot (hl_grow.plant and soften_plants). `thin`: sage, whose shade is broken.
static func _soft(lit: PackedInt32Array, shade: PackedInt32Array, ox: int, oy: int, things: Dictionary, th: Image, name: String, x: int, y: int, sides: Array, green: bool, thin := false, hide := 0, flip := false) -> void:
	var info: Dictionary = things.get(name, {})
	if info.is_empty() or th == null:
		return
	var r: Array = info["rect"]
	var foot: Array = info["foot"]
	var w := int(r[2])
	var cut := int(foot[1]) - hide        # its rows from here down are lost in the turf (hl_grow.plant's hide)
	var hgt := mini(int(r[3]), cut)
	var left := x - (w - 1 - int(foot[0]) if flip else int(foot[0]))
	var top := y - int(foot[1]) + hide
	if hgt <= 0 or left + w < -2 or top + hgt < -2 or left > PX + 2 or top > PX + 4:
		return
	var pix := _pixels(things, th, name)
	if hide > 0:
		pix = pix.filter(func(p): return int(p[1]) < cut)
	if flip:                              # (mirrored: one more shape from the same picture)
		pix = pix.map(func(p): return [w - 1 - int(p[0]), p[1], p[2], p[3]])
	if pix.is_empty():
		return
	_bed(lit, shade, ox, oy, left + w * 0.5, top + hgt + 0.5, w * 0.5 + 2.5, 2.0, green, 1, 0.5)
	var mine := {}
	for p in pix:
		mine[Vector2i(left + int(p[0]), top + int(p[1]))] = true
	# the shaded side takes the ground's own dark steps
	var drop := {}
	for at: Vector2i in mine:
		for s in sides:
			if thin and _h(ox + at.x, oy + at.y, 111 + int(s[0]) * 3 + int(s[1])) % 10 < 4:
				continue
			var nb := at + Vector2i(int(s[0]), int(s[1]))
			if not mine.has(nb):
				drop[nb] = maxi(int(drop.get(nb, 0)), int(s[2]))
	for at: Vector2i in drop:
		if at.x < 0 or at.y < 0 or at.x >= PX or at.y >= PX:
			continue
		var q := at.y * PX + at.x
		var cd: int = code_of.get(lit[q], -1)
		if cd >= 0:
			_put(lit, shade, q, cd >> 4, (cd & 15) - int(drop[at]))
	var bottom := top + hgt - 1
	for p in pix:
		var X: int = left + int(p[0])
		var Y: int = top + int(p[1])
		if X < 0 or Y < 0 or X >= PX or Y >= PX:
			continue
		var q := Y * PX + X
		# blades over the foot: some of its bottom row is the ground below it, a step lit
		if Y == bottom and Y + 1 < PX and _h(ox + X, oy + Y, 112) % 10 < 4:
			var cb: int = code_of.get(lit[q + PX], -1)
			if cb >= 0:
				_put(lit, shade, q, cb >> 4, (cb & 15) + 1)
				continue
		lit[q] = int(p[2])
		shade[q] = int(p[3])


# --- foliage -------------------------------------------------------------------------------------------------------

## Walk-through foliage for each section (Darren, 25 November: "Add some foliage also for each zone ... like core keeper
## does"; the Art builder's hl_foliage.SETS, concept v4): kinds by the ground they grow on.
const FOLIAGE_SETS := {
	"lee": ["bracken", "bracken_rust", "fern"],         # in the lee under the rock
	"wet": ["cotton_grass", "tall_grass"],              # by water
	"heath": ["bilberry", "fern"],                      # among the heather and sage
	"open": ["tall_grass", "fern", "bracken"],          # out on the moor
	"stone": ["moss_stone"],                            # near the rock, now and then
	"scrap": ["nettles", "thistle", "dock", "rust_weeds"],   # the goblin ground round the Scrapyard
	"snow": ["frosted_heather", "frozen_grass", "snowdrops", "lichen_stone"],
	"dark": ["glow_fungi", "glowbell"],                 # old tunnels' floors, against the wall
}
## A drift starts on about one tile in this many (moor, goblin ground, snow; a tunnel's floor by the wall).
const DRIFT_EVERY := {"moor": 34.0, "scrap": 26.0, "snow": 40.0, "dark": 7.0}
const FOL_VARIANTS := 8          # pictures of each kind in the kit (bake.py), each its own shape


## The drifts whose plants can reach chunk c: [centre x, centre y (the chunk's own pixels), set, seed]. Each one comes
## from its own tile (with the world's own number), so every chunk finds the same drifts.
static func _drift_list(m: LandMap, c: Ctx, snow: bool, world: int) -> Array:
	var out: Array = []
	if FOLIAGE <= 0.0:
		return out
	var n := CH + FR * 2
	var site: Dictionary = m.sites.get("scrapyard", {})
	var yard: Vector2 = site.get("at", Vector2.INF)
	var snow_near := false            # (this chunk or one beside it: a drift's plants reach three tiles over)
	for dj in range(-1, 2):
		for di in range(-1, 2):
			snow_near = snow_near or Snow.chunk(m, floori(float(c.ox) / PX) + di, floori(float(c.oy) / PX) + dj) > 0
	for tj in range(-3, CH + 3):
		for ti in range(-3, CH + 3):
			var i := (tj + FR) * n + ti + FR
			var k := c.kinds[i]
			var X := c.x0 + ti
			var Y := c.y0 + tj
			var h := _h(X, Y, 401 + world)
			var r := float(h & 0xffff) / 65536.0
			var sec := ""
			if k == LandMap.FLOOR:
				if m.dug.has(Y * LandMap.SIZE + X):
					continue                 # (only the old tunnels: nothing grows yet where you have just dug)
				var wall := false
				for d in [-1, 1, -n, n]:
					if LandMap.rocky(c.kinds[i + d]):
						wall = true
				if not wall or r >= FOLIAGE / float(DRIFT_EVERY["dark"]):
					continue
				sec = "dark"
			elif _turf_ground(k):
				if r >= FOLIAGE / 26.0:
					continue
				sec = "moor"
			else:
				continue
			var cx := ti * T + 2 + (h >> 16) % 12
			var cy := tj * T + 2 + (h >> 20) % 12
			var snowy := snow_near and Snow.snowy_px(m, Vector2(c.ox + cx, c.oy + cy))
			if snowy != snow:
				continue                     # (the other picture of this chunk draws it)
			if sec == "moor":
				var near_yard := yard != Vector2.INF and Vector2(X, Y).distance_to(yard) < FoePlan.SCRAP_REACH
				sec = "snow" if snowy else ("scrap" if near_yard and (h >> 24) % 10 < 7 else "moor")
				if r >= FOLIAGE / float(DRIFT_EVERY[sec]):
					continue
				if sec == "moor":
					# which moor kinds: by the ground round it (hl_light_concept4: bracken in the lee, cotton grass by
					# water, bilberry among the heather)
					var rock := false
					var water := false
					for dj in range(-2, 3):
						for di in range(-2, 3):
							var kk := c.kinds[i + dj * n + di]
							rock = rock or LandMap.rocky(kk)
							water = water or kk == LandMap.WATER
					if water:
						sec = "wet"
					elif rock:
						sec = "stone" if (h >> 8) % 6 == 0 else "lee"
					elif k == LandMap.HEATH or k == LandMap.SCRUB:
						sec = "heath"
					else:
						sec = "open"
			out.append([cx, cy, sec, h])
	return out


## Lays the drifts (hl_grow.drift): a damp greener bed, three to seven plants packed in the middle and half hidden
## further out, and the drift thinning into single blades with no edge. Never on a path, in water or on rock, never
## under a thing standing on the land or on top of a heather or sage plant.
static func _foliage(lit: PackedInt32Array, shade: PackedInt32Array, m: LandMap, c: Ctx, things: Dictionary, th: Image, snow: bool, world: int) -> void:
	var drifts := _drift_list(m, c, snow, world)
	if drifts.is_empty():
		return
	var ox := c.ox
	var oy := c.oy
	var ccx := floori(float(ox) / PX)
	var ccy := floori(float(oy) / PX)
	var keep_off: Array = []         # [x, y, how far] in the chunk's pixels
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for t in m.things_in(ccx + di, ccy + dj):
				keep_off.append(Vector3(float(t["x"]) - ox, float(t["y"]) - oy, 8.0))
			for pl in m.plants_in(ccx + di, ccy + dj):
				keep_off.append(Vector3(float(pl["x"]) - ox, float(pl["y"]) - oy, 5.0))
	var n := CH + FR * 2
	var spread := 10.0
	for d in drifts:
		var cx: int = d[0]
		var cy: int = d[1]
		var sec: String = d[2]
		var h: int = d[3]
		if cx < -60 or cy < -40 or cx > PX + 60 or cy > PX + 40:
			continue
		var kinds: Array = FOLIAGE_SETS[sec]
		var dark := sec == "dark"
		var green := not snow and not dark
		var k1: String = kinds[_h(h, 1, 402) % kinds.size()]
		var k2: String = kinds[_h(h, 2, 402) % kinds.size()]
		var per := (3 + _h(h, 3, 402) % 3) if dark else (4 + _h(h, 3, 402) % 5)
		var sp := 5.0 if dark else spread
		# one or two knots in the drift, the plants crowding round them (never a ring, never a step)
		var knots: Array = [Vector2(cx, cy)]
		if not dark and _h(h, 4, 402) % 3 != 0:
			var ka := float(_h(h, 5, 402) & 1023) / 1023.0 * TAU
			knots.append(Vector2(cx + cos(ka) * sp * 0.9, cy + sin(ka) * sp * 0.45))
		var placed: Array = []
		for j in per * 2:
			if placed.size() >= per:
				break
			var hj := _h(h, j + 10, 403)
			var hk := _h(h, j + 10, 405)
			var knot: Vector2 = knots[j % knots.size()]
			# mostly near the knot, a few further out: the sum of two dice, folded
			var u := absf(float(hk & 1023) / 1023.0 + float((hk >> 10) & 1023) / 1023.0 - 1.0)
			var r := sp * 1.3 * u
			var a := float(hj & 1023) / 1023.0 * TAU
			var x := int(knot.x + cos(a) * r * 1.4) + ((hk >> 20) % 3) - 1
			var y := int(knot.y + sin(a) * r * 0.8)
			# its foot must be on the ground it grows on
			var ti := floori(float(x) / T) + FR
			var tj := floori(float(y) / T) + FR
			if ti < 1 or tj < 1 or ti >= n - 1 or tj >= n - 1:
				continue
			var kk := c.kinds[tj * n + ti]
			if dark:
				if kk != LandMap.FLOOR or m.dug.has((c.y0 + tj - FR) * LandMap.SIZE + c.x0 + ti - FR):
					continue
			elif not _turf_ground(kk):
				continue
			var ok := true
			for o: Vector3 in keep_off:
				if absf(o.x - x) < o.z and absf(o.y - y) < o.z * 0.6:
					ok = false
					break
			# packed: plants touch and hide parts of each other, but each keeps its own foot and some of its shape
			for q: Array in placed:
				if absi(int(q[0]) - x) < 5 and absi(int(q[1]) - y) < 3:
					ok = false
			if not ok:
				continue
			var name := "fol_%s_%d" % [k1 if (hj >> 10) % 10 < 7 else k2, (hj >> 14) % FOL_VARIANTS]
			if not things.has(name):
				continue
			# further out, lower in the turf (and now and then a young one anywhere)
			var hide := 0 if r < sp * 0.4 else 1 + (hj >> 18) % 3
			if (hj >> 20) % 10 < 3:
				hide = maxi(hide, 1 + (hj >> 22) % 3)
			if dark:
				hide = 0
			placed.append([x, y, name, hide, (hj >> 26) & 1 == 1])
		if placed.is_empty():
			continue
		for kn: Vector2 in knots:
			if dark:
				_bed(lit, shade, ox, oy, kn.x, kn.y + 1, 7.0, 3.0, false, 1, 0.7, true, [G_FLOOR])
			else:     # (the bed stays on the grass or the snow: never on a path or on the rock's foot)
				# (damp: a step darker, but the moor's own colour, so green plants keep their shapes against it)
				_bed(lit, shade, ox, oy, kn.x, kn.y + 1, spread * 1.4, spread * 0.75, false, 1, 0.8, false, [G_SNOW] if snow else [G_GRASS, G_TURF, G_MIXG])
		placed.sort_custom(func(p, q): return int(p[1]) < int(q[1]))
		for p in placed:
			# (one step of the ground's dark on the shaded side, not two: packed plants would sink into a dark mass)
			_soft(lit, shade, ox, oy, things, th, str(p[2]), int(p[0]), int(p[1]), [[1, 0, 1], [0, 1, 1], [1, 1, 1]], green, false, int(p[3]), bool(p[4]))
			if note:
				noted.append([ox + int(p[0]), oy + int(p[1]), str(p[2]), snow])
		if not dark:
			# the drift thinning out unevenly into single blades and specks: further in some directions than others
			var lobes := 2 + _h(h, 6, 404) % 2
			var phase := float(_h(h, 7, 404) & 1023) / 1023.0 * TAU
			for b in per * 6:
				var hb := _h(h, b + 40, 404)
				var knot: Vector2 = knots[b % knots.size()]
				var aa := float((hb >> 8) & 1023) / 1023.0 * TAU
				var reach := 0.7 + 0.55 * sin(aa * lobes + phase)
				var rr := spread * (0.5 + pow(float(hb & 255) / 255.0, 0.7) * 1.6) * reach
				var bx := int(knot.x + cos(aa) * rr * 1.5)
				var by := int(knot.y + 1 + sin(aa) * rr * 0.8)
				if bx >= 0 and by >= 2 and bx < PX - 4 and by < PX:
					_stamp(lit, shade, bx, by, [BLADE, VTUFT, LONGB, SPECK, SPECK_UP][(hb >> 18) % 5])


# --- marks ---------------------------------------------------------------------------------------------------------

static var _mark_cache := {}     # a thing's mark: name -> [[x, y, material, step, relative], ...] from its top left

static func _mark_px(things: Dictionary, mk: Image, name: String) -> Array:
	var key := "%s@%d" % [name, mk.get_instance_id()]
	if _mark_cache.has(key):
		return _mark_cache[key]
	var out: Array = []
	var info: Dictionary = things.get(name, {})
	if info.has("mark"):
		var r: Array = info["mark"]
		for j in int(r[3]):
			for i in int(r[2]):
				var v := mk.get_pixel(int(r[0]) + i, int(r[1]) + j)
				if v.a8 > 0 and v.r8 < names.size():
					out.append([i, j, v.r8, v.g8 - 128 if v.b8 == 1 else v.g8, v.b8 == 1])
	_mark_cache[key] = out
	return out


## What each thing standing on the land round the chunk leaves in the ground under it (its "mark" in the kit, cut from
## the Art builder's seating code): per pixel a material and a step, or a number of steps up or down from whatever
## ground lies there. A green mark (turf, the mixed band) greens only moor grass; on earth or snow it keeps that ground.
static func _marks(lit: PackedInt32Array, shade: PackedInt32Array, m: LandMap, cx: int, cy: int, things: Dictionary, mk: Image) -> void:
	if mk == null:
		return
	var ox := cx * PX
	var oy := cy * PX
	var list: Array = []
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for t in m.things_in(cx + di, cy + dj):
				list.append([int(t["y"]), int(t["x"]), str(t["n"])])
	list.sort()
	for t in list:
		var info: Dictionary = things.get(t[2], {})
		if not info.has("mark"):
			continue
		var r: Array = info["mark"]
		var at: Array = info["mark_at"]
		var left: int = int(t[1]) + int(at[0]) - ox
		var top: int = int(t[0]) + int(at[1]) - oy
		if left + int(r[2]) <= 0 or top + int(r[3]) <= 0 or left >= PX or top >= PX:
			continue
		for p in _mark_px(things, mk, t[2]):
			var x: int = left + int(p[0])
			var y: int = top + int(p[1])
			if x < 0 or y < 0 or x >= PX or y >= PX:
				continue
			var q := y * PX + x
			var cd: int = code_of.get(lit[q], -1)
			if cd < 0:
				continue            # not ground (rock, water, a dug floor's edge): the mark stops there
			var mat: int = p[2]
			if p[4]:
				var g := mat
				if (mat == G_GRASS or mat == G_TURF or mat == G_MIXG) and not ((cd >> 4) == G_GRASS or (cd >> 4) == G_TURF or (cd >> 4) == G_MIXG):
					g = cd >> 4
				_put(lit, shade, q, g, (cd & 15) + int(p[3]))
			else:
				_put(lit, shade, q, mat, int(p[3]))
