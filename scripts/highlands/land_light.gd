extends RefCounted
## The Highlands' light (version 68, step 3 of the new look: the Art builder's light concept v2 and v4, Darren's "Go"
## of 25 November).
##
## Out in the open it is daylight, and the land looks as it is painted. Under the hill it grows dark: a tunnel or a
## room somebody dug goes darker in three hard steps the further it is from open ground, and its lamps light pools in
## three hard steps (a one-pixel checker where two steps meet, never a smooth gradient, never bloom). The undug rock's
## top stops light and takes none; the cut face of a wall catches it. Ore on a lit face shines in its own colour with a
## small halo (copper warm, tin cool), and the glowing fungi of the old tunnels glow gold. The snow round the Hound Den
## is a little cooler. With the lab's day and night on, night falls on the open land too, and the Roost's fire and the
## cave mouth light their own pools.
##
## The land is drawn through shaders/highlands_light.gdshader, a chunk at a time, from what `make` works out for that
## chunk (on the painting thread). The things standing on the land and everybody on it take the same light as a tint
## (`sample`), and nobody is ever drawn darker than ACTOR_MIN. Danger marks, the HUD, hits and the boss stay unlit.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Snow := preload("res://scripts/highlands/snow.gd")
const LandGrow := preload("res://scripts/highlands/land_grow.gd")

const T := 16                       # a tile, in art pixels
const CH := LandMap.CHUNK
const PX := CH * T
const PADT := 8                     # tiles looked at round a chunk (a fire's pool reaches about seven)
const W := CH + PADT * 2            # the light's own picture of a chunk: W x W tiles
const SEE := 6                      # how far (tiles) the way out to open ground is looked for
const MAX_LAMPS := 24               # (the shader's own limit)
const GLOW_IN := 3                  # a shining pixel's halo: two steps, this far and ...
const GLOW_OUT := 7                 # ... this far (art pixels)
const PLANT_IN := 4                 # and a clump of glowing fungi's
const PLANT_OUT := 9
const FIRE_REACH := 118.0           # the Roost's fire lights this far at night (art pixels; the concept's camp fire)
const MOUTH_REACH := 60.0           # and the cave mouth, the forge's light spilling out of it
const PLAYER_REACH := 30.0          # everybody carries a small light where it is dark (two steps)
const PLAYER_LIGHT := 0.5           # (how much it lifts the dark, at its middle)
const ACTOR_MIN := 0.72             # nobody is drawn darker than this (readability first; the concept's 0.7)
const ACTOR_KEEP := 0.35            # and everybody keeps this much of their own colour whatever the light

## The light's colours (the concept's): what the open land takes at night (its dusk blue-violet), lamplight and a
## fire's warmer light, and the snow's cool.
const NIGHT := Vector3(0.46, 0.46, 0.72)
const LAMP_WARM := Vector3(1.0, 0.96, 0.88)
const FIRE_WARM := Vector3(1.10, 0.90, 0.70)
const SNOW_DAY := Vector3(0.90, 0.95, 1.0)
const SNOW_NIGHT := Vector3(1.3, 1.43, 1.19)      # (the snow at night is lighter than the moor: the concept's 0.60, 0.66, 0.86)
const YARD_DIM := 0.34              # the Scrapyard's rooms grow no darker than one step (its fights must read)

## The lab's numbers ("Light in the Highlands").
static var CYCLE := 0               # 1: day and night go round; 0: it is always day (the default)
static var DAY_MINUTES := 12.0      # one whole day and night, in minutes
static var DEEP := 0.7              # how dark the deepest tunnels get (0.7: 30% of the light is left)

static var clock := 0.0             # seconds into the day (it starts in the morning)
static var night := 0.0             # 0 day, 1 night (what is shown now)
static var fixed := -1.0            # a check or a picture can hold the night here (-1: by the clock)
static var on := true               # (a check can switch the light off, to compare)
static var extra: Array = []        # lights the map does not hold: [{x, y (art pixels), r, fire, night}]


## Moves the day on (the game calls it every frame in the Highlands).
static func tick(delta: float) -> void:
	if fixed >= 0.0:
		night = fixed
		return
	if CYCLE <= 0:
		night = 0.0
		return
	var day := maxf(DAY_MINUTES, 1.0) * 60.0
	clock = fmod(clock + delta, day)
	night = night_at(clock / day)


## How much it is night a share `t` of the way through a day: six tenths of day, a tenth of dusk, two of night, a
## tenth of dawn (dusk and dawn in three steps, so the light changes now and then, not all the time).
static func night_at(t: float) -> float:
	var n := 0.0
	if t < 0.6:
		n = 0.0
	elif t < 0.7:
		n = (t - 0.6) / 0.1
	elif t < 0.9:
		n = 1.0
	else:
		n = 1.0 - (t - 0.9) / 0.1
	return roundf(n * 4.0) / 4.0


## The colour the deepest dark takes.
static func deep_col() -> Vector3:
	var d := clampf(DEEP, 0.0, 0.95)
	return Vector3(1.0 - d, 1.0 - d, 1.0 - d * 0.8)


## Starts the light for a new game: morning, and no lights of the last one.
static func reset() -> void:
	clock = 0.0
	night = 0.0
	extra = []


## What the light of chunk (cx, cy) needs (worked out on the painting thread, beside the picture):
##   tiles: W x W tiles round the chunk (an Image): r how dark (by the way out to open ground), g the rock (0 open,
##     128 rock with open ground south of it: its lower part is the lit face; 255 the rock's top all through), b snow;
##   dark, snow (floats) and rock (bytes) for each of those tiles, for `sample`;
##   lamps: the map's lamps that reach the chunk, as [x, y (art pixels on the map), reach, fire?];
##   glow: the shining ore and fungi (a PX x PX Image: r 255 shines in its own colour, 170 and 85 its halo; g which
##     glow: 0 copper, 128 tin, 255 fungi), or null.
## `ore` is what the painter found: [x, y (the chunk's own pixels), copper?] for each pixel of ore on a lit face.
static func make(m: LandMap, cx: int, cy: int, ore: Array) -> Dictionary:
	var x0 := cx * CH - PADT
	var y0 := cy * CH - PADT
	# How far each tile is from open ground (out under the sky: not rock, not dug floor), up to SEE tiles: a chamfer
	# distance over a window SEE tiles wider each side.
	var n := W + SEE * 2
	var far := PackedFloat32Array()
	far.resize(n * n)
	for j in n:
		for i in n:
			var k := m.kind(x0 - SEE + i, y0 - SEE + j)
			far[j * n + i] = 0.0 if (not LandMap.rocky(k) and k != LandMap.FLOOR) else 99.0
	var D := 1.4142
	for j in n:
		for i in n:
			var v := far[j * n + i]
			if v == 0.0:
				continue
			if i > 0:
				v = minf(v, far[j * n + i - 1] + 1.0)
			if j > 0:
				v = minf(v, far[(j - 1) * n + i] + 1.0)
				if i > 0:
					v = minf(v, far[(j - 1) * n + i - 1] + D)
				if i < n - 1:
					v = minf(v, far[(j - 1) * n + i + 1] + D)
			far[j * n + i] = v
	for j in range(n - 1, -1, -1):
		for i in range(n - 1, -1, -1):
			var v := far[j * n + i]
			if v == 0.0:
				continue
			if i < n - 1:
				v = minf(v, far[j * n + i + 1] + 1.0)
			if j < n - 1:
				v = minf(v, far[(j + 1) * n + i] + 1.0)
				if i < n - 1:
					v = minf(v, far[(j + 1) * n + i + 1] + D)
				if i > 0:
					v = minf(v, far[(j + 1) * n + i - 1] + D)
			far[j * n + i] = v
	var yard := Rect2i()
	if m.sites.has("scrapyard") and m.sites["scrapyard"].has("rect"):
		yard = m.sites["scrapyard"]["rect"]
	var snowy := false
	for dj in range(-1, 2):
		for di in range(-1, 2):
			snowy = snowy or Snow.chunk(m, cx + di, cy + dj) > 0
	var dark := PackedFloat32Array()
	var snow := PackedFloat32Array()
	var rock := PackedByteArray()
	dark.resize(W * W)
	snow.resize(W * W)
	rock.resize(W * W)
	var img := Image.create_empty(W, W, false, Image.FORMAT_RGBA8)
	var data := PackedByteArray()
	data.resize(W * W * 4)
	for j in W:
		for i in W:
			var x := x0 + i
			var y := y0 + j
			var t := j * W + i
			var dk := clampf((far[(j + SEE) * n + i + SEE] - 1.0) / 4.0, 0.0, 1.0)
			if yard.size.x > 0 and yard.has_point(Vector2i(x, y)):
				dk = minf(dk, YARD_DIM)
			var r := 0
			if LandMap.rocky(m.kind(x, y)):
				r = 1 if not LandMap.rocky(m.kind(x, y + 1)) else 2
			var s := 0.0
			if snowy:
				s = clampf(Snow.depth(m, float(x) + 0.5, float(y) + 0.5) * 0.5 + 0.5, 0.0, 1.0)
			dark[t] = dk
			snow[t] = s
			rock[t] = r
			data[t * 4] = int(round(dk * 255.0))
			data[t * 4 + 1] = [0, 128, 255][r]
			data[t * 4 + 2] = int(round(s * 255.0))
			data[t * 4 + 3] = 255
	img.set_data(W, W, false, Image.FORMAT_RGBA8, data)
	# The map's lamps that reach this chunk.
	var lamps: Array = []
	var box := Rect2(cx * PX, cy * PX, PX, PX)
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for l in m.lamps_in(cx + di, cy + dj):
				var at := Vector2(float(l["x"]), float(l["y"]))
				var r := float(l["r"])
				if box.grow_individual(r * 1.05, r * 0.82, r * 1.05, r * 0.82).has_point(at):
					lamps.append([at.x, at.y, r, false])
	# What glows: the ore on the lit faces, and the fungi of the old tunnels (their halos reach a little past the chunk).
	var plants := LandGrow.glow_spots(m, cx * CH - 1, cy * CH - 1, cx * CH + CH + 1, cy * CH + CH + 1)
	var glow: Image = null
	if not ore.is_empty() or not plants.is_empty():
		var lv := PackedByteArray()
		lv.resize(PX * PX * 2)
		for o: Vector3i in ore:
			var hue := 0 if o.z == 1 else 128
			if (o.x + o.y) % 2 == 0:
				_halo(lv, o.x, o.y, GLOW_OUT, 85, hue)
				_halo(lv, o.x, o.y, GLOW_IN, 170, hue)
		for o: Vector3i in ore:
			if o.x >= 0 and o.y >= 0 and o.x < PX and o.y < PX:
				lv[(o.y * PX + o.x) * 2] = 255
				lv[(o.y * PX + o.x) * 2 + 1] = 0 if o.z == 1 else 128
		for p: Vector2 in plants:
			var px := int(p.x) - cx * PX
			var py := int(p.y) - cy * PX
			_halo(lv, px, py, PLANT_OUT, 85, 255)
			_halo(lv, px, py, PLANT_IN, 170, 255)
		glow = Image.create_from_data(PX, PX, false, Image.FORMAT_RG8, lv)
	return {"at": Vector2i(cx, cy), "origin": Vector2(cx * PX, cy * PX), "tiles": img, "dark": dark, "snow": snow,
			"rock": rock, "lamps": lamps, "glow": glow}


## One step of a halo: every pixel within `r` of (x, y) (the chunk's own pixels) glows at least `level`.
static func _halo(lv: PackedByteArray, x: int, y: int, r: int, level: int, hue: int) -> void:
	for j in range(maxi(y - r, 0), mini(y + r + 1, PX)):
		var dy := j - y
		for i in range(maxi(x - r, 0), mini(x + r + 1, PX)):
			var dx := i - x
			if dx * dx + dy * dy > r * r:
				continue
			var o := (j * PX + i) * 2
			if lv[o] < level:
				lv[o] = level
				lv[o + 1] = hue


## Every light that reaches chunk data `d` now: the map's own lamps and the game's own (`extra`), as the shader's
## [x, y (the chunk's own pixels), reach, strength (+2 for a fire's warmer light)], nearest first, at most MAX_LAMPS.
static func lamps_now(d: Dictionary) -> PackedVector4Array:
	var o: Vector2 = d["origin"]
	var box := Rect2(o, Vector2(PX, PX))
	var all: Array = []
	for l in d["lamps"]:
		all.append(Vector4(float(l[0]) - o.x, float(l[1]) - o.y, float(l[2]), 1.0))
	for e in extra:
		var at := Vector2(float(e["x"]), float(e["y"]))
		var r := float(e["r"])
		var s := float(e.get("strength", 1.0)) * (night if bool(e.get("night", false)) else 1.0)
		if s <= 0.0 or not box.grow_individual(r * 1.05, r * 0.82, r * 1.05, r * 0.82).has_point(at):
			continue
		all.append(Vector4(at.x - o.x, at.y - o.y, r, s + (2.0 if bool(e.get("fire", false)) else 0.0)))
	if all.size() > MAX_LAMPS:
		var mid := Vector2(PX, PX) * 0.5
		all.sort_custom(func(a: Vector4, b: Vector4): return Vector2(a.x, a.y).distance_to(mid) - a.z < Vector2(b.x, b.y).distance_to(mid) - b.z)
		all.resize(MAX_LAMPS)
	var out := PackedVector4Array()
	out.resize(MAX_LAMPS)
	for i in all.size():
		out[i] = all[i]
	return out


## How many of `lamps_now`'s entries are lights.
static func lamp_count(v: PackedVector4Array) -> int:
	var k := 0
	for l in v:
		if l.z > 0.0:
			k += 1
	return k


## The light at a point (art pixels on the map) as a tint, from chunk data `d` (null: out in the open) and the
## lights `lamps` (lamps_now of that chunk): as the shader works it out, without its checker and its greying.
## `carried`: the points where somebody carries their small light (art pixels on the map).
static func sample(d, lamps: PackedVector4Array, at: Vector2, carried: Array = []) -> Color:
	var away := Vector3.ONE.lerp(NIGHT, night)
	if d == null or not on:
		return Color(away.x, away.y, away.z)
	var o: Vector2 = d["origin"]
	var p := at - o
	var q := p / float(T) - Vector2(0.5, 0.5) + Vector2(PADT, PADT)
	var dk := _bilinear(d["dark"], q)
	var sn := _bilinear(d["snow"], q)
	var steps := clampf(floorf(dk * 3.0 + 0.09) / 3.0, 0.0, 1.0)
	away = away.lerp(deep_col(), steps)
	var cool := SNOW_DAY.lerp(SNOW_NIGHT, night)
	sn = sn * sn * (3.0 - 2.0 * sn)
	away *= Vector3.ONE.lerp(cool, sn)
	var L := 0.0
	var warm := LAMP_WARM
	var rock: PackedByteArray = d["rock"]
	for l in lamps:
		if l.z <= 0.0:
			continue
		var s := l.w
		var wc := LAMP_WARM
		if s >= 2.0:
			s -= 2.0
			wc = FIRE_WARM
		var dd := Vector2(p.x - l.x, (p.y - l.y) * 1.3).length() / l.z
		if dd >= 1.0 or s <= 0.0:
			continue
		var ring := 3 if dd < 0.42 else (2 if dd < 0.72 else 1)
		var lv := float(ring) / 3.0 * s
		if lv <= L:
			continue
		var blocked := false
		for k in range(1, 12):
			if _top(rock, Vector2(l.x, l.y).lerp(p, float(k) / 12.0)):
				blocked = true
				break
		if not blocked:
			L = lv
			warm = wc
	for c: Vector2 in carried:
		var dd := Vector2(at.x - c.x, (at.y - c.y) * 1.3).length() / PLAYER_REACH
		if dd < 1.0:
			var lv := (1.0 if dd < 0.55 else 0.5) * PLAYER_LIGHT
			if lv > L:
				L = lv
				warm = LAMP_WARM
	var col := away.lerp(warm, L)
	return Color(col.x, col.y, col.z)


## The tint for somebody standing in light `c`: they keep some of their own colour, and never go darker than
## ACTOR_MIN.
static func actor_tint(c: Color) -> Color:
	var k := 1.0 - ACTOR_KEEP
	return Color(maxf(lerpf(1.0, c.r, k), ACTOR_MIN), maxf(lerpf(1.0, c.g, k), ACTOR_MIN), maxf(lerpf(1.0, c.b, k), ACTOR_MIN))


static func _bilinear(a: PackedFloat32Array, q: Vector2) -> float:
	var i0 := clampi(floori(q.x), 0, W - 1)
	var j0 := clampi(floori(q.y), 0, W - 1)
	var i1 := clampi(floori(q.x) + 1, 0, W - 1)
	var j1 := clampi(floori(q.y) + 1, 0, W - 1)
	var fx := clampf(q.x - floorf(q.x), 0.0, 1.0)
	var fy := clampf(q.y - floorf(q.y), 0.0, 1.0)
	return lerpf(lerpf(a[j0 * W + i0], a[j0 * W + i1], fx), lerpf(a[j1 * W + i0], a[j1 * W + i1], fx), fy)


## Is this point (the chunk's own pixels) on the rock's dark top?
static func _top(rock: PackedByteArray, p: Vector2) -> bool:
	var i := clampi(floori(p.x / T) + PADT, 0, W - 1)
	var j := clampi(floori(p.y / T) + PADT, 0, W - 1)
	var r := rock[j * W + i]
	return r == 2 or (r == 1 and fposmod(p.y, T) < 6.0)
