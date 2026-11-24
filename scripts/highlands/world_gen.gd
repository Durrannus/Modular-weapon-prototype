extends RefCounted
## Makes a Greystone Highlands map from a seed (Darren, 21 November: "It's
## procedurally generated the map but with all the rules for where loot can
## spawn etc"). The same seed always makes the same map; nothing here asks for a
## random number from anywhere but its own generator.
##
## The rules it follows are the Game Bible's ("The Greystone Highlands plan" and
## "Highlands look") and the Highlands world and base research:
##   - Most of the land is rock you can dig, with small open places in it joined
##     by gaps, footpaths and old dug tunnels (Darren: "most areas to be mineable
##     and not big open areas"). About two thirds rock.
##   - The base: a clearing outside the cave mouth, ringed by hills 6 to 10 tiles
##     thick with two to four gaps through them, and tin and copper in the hills.
##   - Rings round the cave (the Game Bible's "Highlands size", decided by Darren
##     on 22 November after he played the land and found it "quite small": about
##     350 tiles from the cave to the edge): the base hills to about 24 tiles, the
##     inner ring to about 125, the middle ring to about 240, the outer ring to
##     about 350. All of them are laid out since version 49.
##   - A belt of rock about ten tiles thick stands between one ring and the next,
##     with a handful of passes through it, each with a footpath. (Anybody can dig
##     through it anywhere.)
##   - Each ring has its own feel, made from the same kit (the research: "the
##     three rings as ground strips ... not new art for each ring"): the inner
##     ring is gentle moor; the middle ring is canyon country, with long glens,
##     more bare rock, boulders and broken ground; the outer ring is barer and
##     tighter, with more places sealed in the rock, more old tunnels, goblin
##     litter, and the richest copper. See RING.
##   - Named places sit in their band and sector, and the seed turns the compass.
##     Inner: the Old Quarry (west) and the Keeper's Watchpost. Middle: the
##     Slinger Roost (east), the Hound Den (south), Cairn Field (north-west),
##     Echo Gorge (north-east). Outer: the Fault (south-east) and Rattlecrown's
##     Scrapyard (far east). The ground of each is made here; who lives there and
##     what is done there is the plans' and the later versions'.
##   - The Scrapyard is a block of rock that nothing here opens and nobody can
##     dig (its rooms are cut into it by crown_plan.gd each time a world is
##     opened), with the ground in front of its gate on its south side.
##   - Every open place can be walked to from the cave without digging, except a
##     few that are sealed on purpose for the pickaxe to find.
##   - Things are spread thin (Darren: "don't clutter it").
##
## The numbers are first guesses to tune in play, not decisions.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")

## Which making of the land this is. A world save holds its number and what was dug and felled, never the land, so
## it only fits the land this same code makes. RAISE THIS BY ONE whenever the same number would give a different
## land (tiles, or the things that stand on it): worlds saved before are then laid out again, without what was dug in
## them, in place of old holes cut into a land they do not fit. tests/saving.gd keeps a fingerprint of one land and
## fails if the land changes while this number does not.
const GEN := 2
const NEWS := "The land now goes out past the inner ring, through the middle ring to the outer one, where Rattlecrown's Scrapyard is."   # what this making of the land brought (the card of a world laid out again says it)

const MID := LandMap.MID
const RINGS := [24.0, 125.0, 240.0, 350.0]   # where the base hills, the inner, the middle and the outer ring end (tiles from the cave)
const REACH := 366             # the land is laid out within this many tiles of the cave each way: the outer ring's 350, and a rim
const BELT := 5.0              # no open place's edge comes nearer than this to the line between two rings: a belt of rock about ten tiles thick
const PASSES := [0, 5, 6]      # how many passes lead through the belt from the inner ring to the middle, and from the middle to the outer
const SCRAPYARD := Vector2i(52, 98)   # the block of rock Rattlecrown's Scrapyard is cut into, in tiles: wide and deep (its rooms stand one above the other: crown_plan.gd)
const SCRAPYARD_FROM := 246.0  # no part of that block is nearer the cave than this
const FORECOURT := 6           # the middle of the ground in front of the Scrapyard gate lies this many tiles below the block
const FAULT_AT := 290.0        # the Fault's two ends are this far from the cave ...
const FAULT_SPAN := 0.2        # ... and this far to either side of south-east (radians): a crack about 115 tiles long
const TELL := 34.0             # a named place shows in the open places this near it (bones near the Den, goblin litter near the Scrapyard)
const CELL := 40               # the open places are sorted into squares this many tiles a side, so that a new one is only measured against those near it

## What differs from ring to ring. Entry 0 is not used; 1 is the inner ring (exactly as it was when it was the whole
## land), 2 the middle ring, 3 the outer. "trials" is how many spots are tried for an open place at most, and "full"
## how many may fail one after another before the ring is taken to be full (lower leaves more rock); "nook" the share of
## small ones; "big" how many big ones at most; "glen" the share of long places between two walls, and "glen_len"
## half their length; "size" the least and most half-width of an ordinary place; "seal" the share sealed in the rock;
## "tunnel" how many ways are old dug tunnels; "outcrop", "tarn", "heath" and "scrub" how many places have one;
## "scree" how readily stones lie at the foot of a face and beside one (lower is more); then how many places have
## pines, boulders [chance, fewest, most], bushes and bracken; "rare" the odd single thing [chance up to, name, how
## many kinds]; "cow", "hare" and "crow" the chances of life, each up to its number; "vein" how many places have
## ore on their edge, "tin" how much of the ore is tin, "vein_size" [fewest tiles, spread]; "deep" the clusters
## buried in the rock.
const RING := [
	{},
	{"spacing": 18.0, "trials": 12000, "full": 12000, "nook": 0.26, "big": 6, "glen": 0.12, "glen_len": [8.0, 10.0], "size": [4.6, 7.0], "seal": 0.10, "tunnel": 0.15,
		"outcrop": 0.30, "tarn": 0.18, "heath": 0.40, "scrub": 0.34, "scree": [0.60, 0.68],
		"pine": 0.34, "boulder": [0.42, 1, 2], "bush": 0.28, "bracken": 0.55,
		"rare": [[0.07, "stone_%d", 2], [0.15, "cairn_%d", 2], [0.21, "stump", 0], [0.26, "bones", 0]],
		"cow": 0.12, "hare": 0.24, "crow": 0.40,
		"vein": 0.45, "tin": 0.55, "vein_size": [4, 4], "deep": 28, "deep_tin": 0.5},
	{"spacing": 19.0, "trials": 40000, "full": 1500, "nook": 0.22, "big": 9, "glen": 0.26, "glen_len": [9.0, 14.0], "size": [4.6, 7.0], "seal": 0.10, "tunnel": 0.15,
		"outcrop": 0.55, "tarn": 0.08, "heath": 0.24, "scrub": 0.46, "scree": [0.47, 0.56],
		"pine": 0.20, "boulder": [0.78, 2, 4], "bush": 0.18, "bracken": 0.40,
		"rare": [[0.08, "stone_%d", 2], [0.20, "cairn_%d", 2], [0.24, "stump", 0], [0.34, "bones", 0], [0.40, "rubble", 0]],
		"cow": 0.0, "hare": 0.10, "crow": 0.28,
		"vein": 0.50, "tin": 0.40, "vein_size": [4, 5], "deep": 80, "deep_tin": 0.4},
	{"spacing": 20.0, "trials": 50000, "full": 600, "nook": 0.38, "big": 6, "glen": 0.10, "glen_len": [8.0, 11.0], "size": [4.2, 6.2], "seal": 0.20, "tunnel": 0.22,
		"outcrop": 0.30, "tarn": 0.10, "heath": 0.14, "scrub": 0.30, "scree": [0.54, 0.62],
		"pine": 0.10, "boulder": [0.50, 1, 3], "bush": 0.10, "bracken": 0.28,
		"rare": [[0.05, "stone_%d", 2], [0.10, "cairn_%d", 2], [0.28, "bones", 0], [0.40, "rubble", 0], [0.47, "barrel", 0]],
		"cow": 0.0, "hare": 0.04, "crow": 0.32,
		"vein": 0.60, "tin": 0.25, "vein_size": [5, 5], "deep": 130, "deep_tin": 0.25},
]
const RING_INNER := 116.0      # how far out the middles of the inner ring's open places go (it wobbles a little); their edges stop at about RINGS[1]
const SPACING := 18.0          # tiles between the middles of two open places
const HILL_KEEP := 9.0         # nothing but the gaps comes this close to the clearing's edge
const BIG_MOST := 6            # never more big open places than this (Darren: "not big open areas")
const DEEP_ORE := 28           # clusters of ore buried in the rock, away from every open place

const GRASS := LandMap.GRASS
const SCRUB := LandMap.SCRUB
const HEATH := LandMap.HEATH
const PATH := LandMap.PATH
const YARD := LandMap.YARD
const WATER := LandMap.WATER
const ROCK := LandMap.ROCK
const TIN := LandMap.TIN
const COPPER := LandMap.COPPER
const FLOOR := LandMap.FLOOR
const SCREE := LandMap.SCREE

const S := LandMap.SIZE

var m: LandMap
var K := PackedByteArray()     # the map's own tiles (m.kinds: the same array, not a copy), for the loops that read millions of them
var lock_lo := 0               # the first and last tile, each way, that is not the map's rim
var lock_hi := 0
var laid := {}                 # every tile that was ever made footpath or yard track (tile index -> true)
var opened := PackedInt32Array()   # every tile that was ever opened (tile index), as it happened; in reading order once _tidy is done
var rng := RandomNumberGenerator.new()
var ore := RandomNumberGenerator.new()    # the ore's own dice (see _ore)
var far := RandomNumberGenerator.new()    # the middle and outer rings' own dice: nothing done out there moves the inner ring's
var far_ore := RandomNumberGenerator.new()
var inner_n := 0               # the open places before this number are the base's and the inner ring's
var rings := true              # are the middle and outer rings made? (Always, but for one of the tools.)
var yard := Rect2i()           # the Scrapyard's block of rock (tiles)
var yl_x0 := 0                 # that block and two tiles round it, which nothing here may open
var yl_x1 := 0
var yl_y0 := 0
var yl_y1 := 0
var fault: Array = []          # the two ends of the Fault's crack (Vector2, tiles)
var cells := {}                # square -> [the numbers of the open places in it] (see CELL)
var p_at := PackedVector2Array()          # for every open place so far: its middle ...
var p_reach := PackedFloat64Array()       # ... how far it reaches from it ...
var p_extra := PackedFloat64Array()       # ... and how much more room a named place asks
var line1 := PackedFloat64Array()         # where each ring ends, for 720 directions round the cave (see _line)
var line2 := PackedFloat64Array()
var line3 := PackedFloat64Array()
var edge_at := {}              # square -> [[a, b]]: the ways whose line passes through it (see _crosses_far)
var ns := 0                    # this map's own salt for the noise
var gap_starts: Array = []     # where each gap leaves the clearing (tiles)
var tunnels: Array = []        # the tiles down the middle of each old tunnel
var ways := 0                  # how many ways have been cut so far (each sways and widens to its own pattern)
var why := ""                  # why the last layout was thrown away


## The map for a seed. If a layout fails its checks the next one is tried, in a
## fixed order, so the answer is still the same every time.
static func make(seed_value: int) -> LandMap:
	var last: LandMap = null
	for attempt in 12:
		var g = new()
		var out: LandMap = g._build(seed_value, attempt)
		last = g.m
		if out == null and OS.has_environment("HL_TIMES"):
			print("  layout %d thrown away: %s" % [attempt + 1, g.why])
		if out != null:
			out.tries = attempt + 1
			return out
	push_error("Highlands seed %d: no layout passed the checks" % seed_value)
	last.tries = 0
	return last


static func _mix(x: int, y: int, s: int) -> int:
	var n := (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	n = (n ^ (n >> 15)) * 2246822519
	n = (n ^ (n >> 13)) * 3266489917
	return (n ^ (n >> 16)) & 0x7fffffff


## Smooth noise from 0 to 1, the same for the same place on the same map.
func _noise(x: float, y: float, scale: float, salt: int) -> float:
	var fx := x / scale
	var fy := y / scale
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - float(ix)
	var ty := fy - float(iy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var s := salt + ns
	var a := float(_mix(ix, iy, s) & 0xffff) / 65535.0
	var b := float(_mix(ix + 1, iy, s) & 0xffff) / 65535.0
	var c := float(_mix(ix, iy + 1, s) & 0xffff) / 65535.0
	var d := float(_mix(ix + 1, iy + 1, s) & 0xffff) / 65535.0
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## The same noise for one tile after another along a row, for less work: the four corners of the square a tile lies
## in are worked out once and kept while the next tiles lie in the same square. at(x) on row(y) is exactly
## _noise(x, y, scale, salt).
class RowNoise:
	var scale := 1.0
	var s := 0
	var iy := 0
	var ty := 0.0
	var cx := -(1 << 30)
	var a := 0.0
	var b := 0.0
	var c := 0.0
	var d := 0.0

	func _init(scale_: float, salt_and_map: int) -> void:
		scale = scale_
		s = salt_and_map

	static func mix(x: int, y: int, salt: int) -> int:
		var n := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
		n = (n ^ (n >> 15)) * 2246822519
		n = (n ^ (n >> 13)) * 3266489917
		return (n ^ (n >> 16)) & 0x7fffffff

	func row(y: int) -> void:
		var fy := float(y) / scale
		iy = floori(fy)
		ty = fy - float(iy)
		ty = ty * ty * (3.0 - 2.0 * ty)
		cx = -(1 << 30)

	func at(x: int) -> float:
		var fx := float(x) / scale
		var ix := floori(fx)
		if ix != cx:
			if ix == cx + 1:
				a = b
				c = d
			else:
				a = float(mix(ix, iy, s) & 0xffff) / 65535.0
				c = float(mix(ix, iy + 1, s) & 0xffff) / 65535.0
			b = float(mix(ix + 1, iy, s) & 0xffff) / 65535.0
			d = float(mix(ix + 1, iy + 1, s) & 0xffff) / 65535.0
			cx = ix
		var tx := fx - float(ix)
		tx = tx * tx * (3.0 - 2.0 * tx)
		return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## And the same noise along a line across the tiles (y stays, x is any number): at(x) is exactly _noise(x, y, scale, salt).
class LineNoise:
	var scale := 1.0
	var s := 0
	var iy := 0
	var ty := 0.0
	var cx := -(1 << 30)
	var a := 0.0
	var b := 0.0
	var c := 0.0
	var d := 0.0

	func _init(scale_: float, salt_and_map: int, y: float) -> void:
		scale = scale_
		s = salt_and_map
		var fy := y / scale
		iy = floori(fy)
		ty = fy - float(iy)
		ty = ty * ty * (3.0 - 2.0 * ty)

	func at(x: float) -> float:
		var fx := x / scale
		var ix := floori(fx)
		if ix != cx:
			a = float(RowNoise.mix(ix, iy, s) & 0xffff) / 65535.0
			b = float(RowNoise.mix(ix + 1, iy, s) & 0xffff) / 65535.0
			c = float(RowNoise.mix(ix, iy + 1, s) & 0xffff) / 65535.0
			d = float(RowNoise.mix(ix + 1, iy + 1, s) & 0xffff) / 65535.0
			cx = ix
		var tx := fx - float(ix)
		tx = tx * tx * (3.0 - 2.0 * tx)
		return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


func _build(seed_value: int, attempt: int) -> LandMap:
	m = LandMap.new()
	K = m.kinds
	lock_lo = MID - (REACH - 3)
	lock_hi = MID + (REACH - 3)
	m.seed_value = seed_value
	m.region = Rect2i(MID - REACH, MID - REACH, REACH * 2, REACH * 2)
	rng.seed = _mix(seed_value & 0xffffffff, seed_value >> 32, 1000 + attempt)
	ore.seed = _mix(seed_value & 0xffffffff, seed_value >> 32, 2000 + attempt)
	far.seed = _mix(seed_value & 0xffffffff, seed_value >> 32, 5000 + attempt)
	far_ore.seed = _mix(seed_value & 0xffffffff, seed_value >> 32, 6000 + attempt)
	ns = rng.randi() & 0xffff
	m.turn = rng.randf() * TAU
	rings = not OS.has_environment("HL_INNER_ONLY")      # (for checking that the rings beyond did not move the inner one: tools/land_mark.gd)
	var t := [Time.get_ticks_usec()]
	_base()
	_sites()
	_scatter_pockets()
	inner_n = m.pockets.size()
	for p in m.pockets:
		p["ring"] = 1
	if rings:
		_far_sites()
		_scatter_far(2)
		_scatter_far(3)
	t.append(Time.get_ticks_usec())
	for p in m.pockets:
		_carve_pocket(p)
	t.append(Time.get_ticks_usec())
	_links()
	if rings:
		_far_links()
	_site_ground()
	if rings:
		_far_site_ground()
	t.append(Time.get_ticks_usec())
	_tidy()
	_thin_paths()
	_tunnel_lamps()
	t.append(Time.get_ticks_usec())
	if not _check():
		return null
	t.append(Time.get_ticks_usec())
	_outcrops()
	_water()
	t.append(Time.get_ticks_usec())
	_tone_and_cover()
	_scree()
	t.append(Time.get_ticks_usec())
	_ore()
	t.append(Time.get_ticks_usec())
	_dress()
	t.append(Time.get_ticks_usec())
	_cover_plants()
	t.append(Time.get_ticks_usec())
	# (No second check: a lump of rock or a tarn only ever stands with open ground all round it, so neither can
	# shut a way that was open when the land was checked.)
	t.append(Time.get_ticks_usec())
	m.index()
	t.append(Time.get_ticks_usec())
	if OS.has_environment("HL_TIMES"):
		var out := []
		for i in range(1, t.size()):
			out.append((t[i] - t[i - 1]) / 1000)
		print("  scatter, carve, links, tidy, check, outcrops+water, tone, ore, dress, plants, check, index (ms): ", out)
	return m


# --- Carving -------------------------------------------------------------------------

## Rock that must stay: the hill the cave mouth is set into, and the map's rim.
func _locked(x: int, y: int) -> bool:
	if x < lock_lo or x > lock_hi or y < lock_lo or y > lock_hi:
		return true
	if x >= yl_x0 and x < yl_x1 and y >= yl_y0 and y < yl_y1:
		return true
	return x >= MID - 4 and x <= MID + 4 and y <= MID and y >= MID - 6


func _open(x: int, y: int, k := GRASS) -> void:
	if x < lock_lo or x > lock_hi or y < lock_lo or y > lock_hi or (x >= MID - 4 and x <= MID + 4 and y <= MID and y >= MID - 6):
		return
	if x >= yl_x0 and x < yl_x1 and y >= yl_y0 and y < yl_y1:
		return
	var i := y * S + x
	var was := K[i]
	if was == ROCK or was == TIN or was == COPPER:
		K[i] = k
		opened.append(i)


## An open patch with a ragged edge. The noise that makes the edge ragged is only asked for where it can matter: in
## the band round the edge, and only for a tile that is still rock.
func _blob(c: Vector2, rx: float, ry: float, wob: float, k := GRASS) -> void:
	var sure := 1.0 + (0.0 - 0.5) * wob         # nearer the middle than this, a tile is always inside
	var never := 1.0 + (1.0 - 0.5) * wob        # farther out than this, never
	var edge := RowNoise.new(3.5, 11 + ns)
	for y in range(floori(c.y - ry - 2.0), ceili(c.y + ry + 2.0) + 1):
		if y < lock_lo or y > lock_hi:
			continue
		var dy := (float(y) + 0.5 - c.y) / ry
		var row := y * S
		var fresh := true
		for x in range(floori(c.x - rx - 2.0), ceili(c.x + rx + 2.0) + 1):
			var dx := (float(x) + 0.5 - c.x) / rx
			var d2 := dx * dx + dy * dy
			if d2 > never or x < lock_lo or x > lock_hi:
				continue
			var was := K[row + x]
			if was != ROCK and was != TIN and was != COPPER:
				continue
			if d2 > sure:
				if fresh:
					edge.row(y)
					fresh = false
				if d2 > 1.0 + (edge.at(x) - 0.5) * wob:
					continue
			if x >= MID - 4 and x <= MID + 4 and y <= MID and y >= MID - 6:
				continue
			if x >= yl_x0 and x < yl_x1 and y >= yl_y0 and y < yl_y1:
				continue
			K[row + x] = k
			opened.append(row + x)


## A way through the rock from a to b, bending as it goes. `width` is how many
## tiles wide it is at its narrowest. A natural gap (`spread` above 0) opens out
## to as much as `width + spread` here and there and never keeps one width for
## long, and it sways from side to side by up to `sway` tiles, so no two ways
## look alike and none is a ruled line. Returns the tiles down its middle, each
## one beside the last (never corner to corner), for a footpath or a yard track.
func _corridor(a: Vector2, b: Vector2, width: int, wander: float, k := GRASS, spread := 0, sway := 0.0, dice: RandomNumberGenerator = null) -> Array:
	if dice == null:
		dice = rng
	ways += 1
	var d := b - a
	var length := maxf(d.length(), 1.0)
	var side := Vector2(-d.y, d.x) / length
	var c1 := a + d * 0.33 + side * dice.randf_range(-1.0, 1.0) * length * wander
	var c2 := a + d * 0.66 + side * dice.randf_range(-1.0, 1.0) * length * wander
	var middle: Array = []
	var last := Vector2i(-99999, 0)
	var steps := int(ceil(length * 3.0))
	var row := float(ways) * 13.7
	sway = minf(sway, length * 0.16)
	var long_bend := LineNoise.new(6.5, 61 + ns, row)
	var short_bend := LineNoise.new(2.8, 62 + ns, row)
	var swell := LineNoise.new(5.5, 63 + ns, row)
	for s in steps + 1:
		var t := float(s) / float(steps)
		var p := a.bezier_interpolate(c1, c2, b, t)
		var u := t * length
		if sway > 0.0:
			# Long bends and short ones together; it comes back to its line at each end.
			var ends := minf(1.0, minf(u, length - u) / 3.5)
			p += side * ends * ((long_bend.at(u) - 0.5) * 2.0 * sway + (short_bend.at(u) - 0.5) * 1.5)
		var w := width
		if spread > 0:
			w = clampi(width + int(round((swell.at(u) - 0.38) * float(spread) * 1.9)), width, width + spread)
		var at := Vector2i(floori(p.x), floori(p.y))
		if at == last:
			continue
		if last.x != -99999 and at.x != last.x and at.y != last.y:
			var corner := Vector2i(at.x, last.y)
			_corridor_tile(corner, w, k)
			middle.append(corner)
		_corridor_tile(at, w, k)
		middle.append(at)
		last = at
	return middle


## Opens a round patch `width` tiles across (a square for the narrow ones).
func _corridor_tile(at: Vector2i, width: int, k: int) -> void:
	var lo := -((width - 1) / 2)
	var c := float(width - 1) * 0.5
	var r2 := float(width * width) * 0.25 + 0.3
	for j in width:
		var y := at.y + lo + j
		if y < lock_lo or y > lock_hi:
			continue
		var row := y * S
		for i in width:
			if width >= 4 and (float(i) - c) * (float(i) - c) + (float(j) - c) * (float(j) - c) > r2:
				continue
			var x := at.x + lo + i
			if x < lock_lo or x > lock_hi or (x >= MID - 4 and x <= MID + 4 and y <= MID and y >= MID - 6):
				continue
			if x >= yl_x0 and x < yl_x1 and y >= yl_y0 and y < yl_y1:
				continue
			var was := K[row + x]
			if was == ROCK or was == TIN or was == COPPER:
				K[row + x] = k
				opened.append(row + x)


## Lays a footpath (or a yard track) down the middle of a way, on grass only.
func _lay(middle: Array, k: int) -> void:
	for at in middle:
		if m.kind(at.x, at.y) == GRASS:
			m.set_kind(at.x, at.y, k)
			laid[at.y * S + at.x] = true


# --- The base ------------------------------------------------------------------------

func _base() -> void:
	var rx := rng.randf_range(10.4, 12.0)
	var ry := rng.randf_range(6.0, 7.0)
	var c := Vector2(MID + 0.5, MID + 1.0 + ry)
	m.base_at = c
	m.base_r = Vector2(rx, ry)
	m.base = Rect2(c - m.base_r, m.base_r * 2.0)
	m.mouth = Vector2i(MID, MID)
	m.spawn = Vector2(MID + 0.5, MID + 2.4)
	_blob(c, rx, ry, 0.30)
	# One or two bays in its edge, so it is never a plain oval.
	for i in 1 + rng.randi() % 2:
		var a := rng.randf_range(0.15, PI - 0.15) if i == 0 else rng.randf_range(-0.2, PI + 0.2)
		_blob(c + Vector2(cos(a) * rx * 0.86, sin(a) * ry * 0.86), rng.randf_range(3.0, 4.4), rng.randf_range(2.0, 2.7), 0.3)
	# The ground right outside the cave mouth is always open.
	for y in range(MID + 1, MID + 4):
		for x in range(MID - 2, MID + 3):
			_open(x, y)
	# Gaps through the hills: one roughly south (the front door), then one to three more.
	var angles: Array = [PI * 0.5 + rng.randf_range(-0.3, 0.3)]
	var want := 2 + rng.randi() % 3
	for t in 60:
		if angles.size() >= want:
			break
		var a := rng.randf_range(-0.45, PI + 0.45)
		var ok := true
		for b in angles:
			if absf(angle_difference(a, b)) < 1.15:
				ok = false
		if ok:
			angles.append(a)
	for i in angles.size():
		var a: float = angles[i]
		var u := Vector2(cos(a), sin(a))
		var edge := c + Vector2(u.x * rx, u.y * ry)
		var thick := rng.randf_range(6.0, 10.0)
		var prx := rng.randf_range(5.0, 6.2)
		var pry := rng.randf_range(3.6, 4.6)
		var gate := edge + u * (thick + (prx if absf(u.x) > absf(u.y) else pry))
		var p := {"at": gate, "rx": prx, "ry": pry, "sealed": false, "gate": true, "site": "", "glen": false, "lobes": []}
		m.pockets.append(p)
		_carve_pocket(p)
		var inside := c + Vector2(u.x * (rx - 2.5), u.y * (ry - 2.5))
		gap_starts.append(edge)
		var middle := _corridor(inside, gate, 3, 0.10, GRASS, 1 + rng.randi() % 2, 1.2)
		if i == 0:
			# The front door: a trodden track from the cave mouth out through the gap.
			var track := _corridor(Vector2(MID + 0.5, MID + 1.5), inside, 1, 0.12)
			_lay(track, YARD)
			_lay(middle, YARD)
			for x in range(MID - 1, MID + 2):
				if m.kind(x, MID + 1) == GRASS:
					m.set_kind(x, MID + 1, YARD)
					laid[(MID + 1) * S + x] = true
		else:
			_lay(middle, PATH)


# --- Places kept for later versions ------------------------------------------------

func _sites() -> void:
	var centre := Vector2(MID + 0.5, MID + 0.5)
	# The Old Quarry is "west" in the plan, in the middle of the inner ring. The seed turns the compass.
	var qa := m.turn + PI + rng.randf_range(-0.3, 0.3)
	var q := centre + Vector2(cos(qa), sin(qa)) * rng.randf_range(72.0, 100.0)
	# The Keeper's Watchpost is towards the ring's edge, and never near the Quarry (named places keep at least 40 tiles apart).
	var w := q
	for t in 60:
		var wa := rng.randf() * TAU
		w = centre + Vector2(cos(wa), sin(wa)) * rng.randf_range(90.0, 108.0)
		if w.distance_to(q) >= 60.0 and w.distance_to(m.base_at) >= 56.0:
			break
	for pair in [["quarry", q], ["watchpost", w]]:
		var p := {"at": pair[1], "rx": rng.randf_range(6.4, 7.4), "ry": rng.randf_range(4.4, 5.2), "sealed": false, "gate": false, "site": pair[0], "glen": false, "lobes": []}
		m.sites[pair[0]] = {"at": pair[1], "pocket": m.pockets.size()}
		m.pockets.append(p)


## What marks the two places for now: an old cut into the rock beside the Quarry's
## ground, and a scrap of the keepers' road across the Watchpost's.
func _site_ground() -> void:
	var q: Dictionary = m.pockets[int(m.sites["quarry"]["pocket"])]
	var at: Vector2 = q["at"]
	var away := (at - Vector2(MID, MID)).normalized()
	var cut: Rect2i
	if absf(away.x) > absf(away.y):
		var sx := 1 if away.x > 0.0 else -1
		var x0 := int(at.x) + sx * int(float(q["rx"]) + 2.0)
		cut = Rect2i(mini(x0, x0 + sx * 6), int(at.y) - 2, 7, 4)
		for x in range(mini(int(at.x), x0), maxi(int(at.x), x0) + 1):
			for y in [int(at.y) - 1, int(at.y)]:
				_open(x, y, FLOOR)
	else:
		var sy := 1 if away.y > 0.0 else -1
		var y0 := int(at.y) + sy * int(float(q["ry"]) + 2.0)
		cut = Rect2i(int(at.x) - 3, mini(y0, y0 + sy * 4), 7, 5)
		for y in range(mini(int(at.y), y0), maxi(int(at.y), y0) + 1):
			for x in [int(at.x) - 1, int(at.x)]:
				_open(x, y, FLOOR)
	for y in range(cut.position.y, cut.end.y):
		for x in range(cut.position.x, cut.end.x):
			_open(x, y, FLOOR)
	m.sites["quarry"]["cut"] = cut


# --- The open places of the inner ring --------------------------------------------

func _ring_limit(a: float) -> float:
	return RING_INNER + (_noise(cos(a) * 30.0 + 100.0, sin(a) * 30.0 + 100.0, 12.0, 31) - 0.5) * 12.0


func _scatter_pockets() -> void:
	var centre := Vector2(MID + 0.5, MID + 0.5)
	# What every place so far asks of a new one, kept in plain lists (the same sums as before, looked up faster).
	var s_at := PackedVector2Array()
	var s_need := PackedFloat64Array()
	var s_reach := PackedFloat64Array()
	var big := 0
	for p in m.pockets:
		s_at.append(p["at"])
		s_need.append(SPACING + 5.0 if str(p["site"]) != "" else SPACING)
		s_reach.append(float(p.get("reach", p["rx"])))
		if float(p["rx"]) >= 8.0 or (bool(p["glen"]) and float(p["rx"]) > 3.4):
			big += 1
	for t in 12000:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf() * (RING_INNER * RING_INNER - 32.0 * 32.0) + 32.0 * 32.0)
		var glen := rng.randf() < 0.12
		var rx := rng.randf_range(4.6, 7.0)
		var ry := rng.randf_range(3.4, 5.2)
		# Sizes differ a good deal: about a quarter are small nooks, and a few (never more than six) are big, 16 to 20 tiles across.
		var size := rng.randf()
		var u1 := rng.randf()
		var u2 := rng.randf()
		if size < 0.26:
			rx = lerpf(3.0, 4.2, u1)
			ry = lerpf(2.5, 3.3, u2)
		elif size > 0.86 and big < BIG_MOST:
			rx = lerpf(8.0, 10.0, u1)
			ry = lerpf(5.4, 7.0, u2)
		var lobes: Array = []
		for i in rng.randi() % 3:
			var la := rng.randf() * TAU
			lobes.append([Vector2(cos(la) * rx * 0.75, sin(la) * ry * 0.75), rng.randf_range(2.2, 3.4), rng.randf_range(1.8, 2.6)])
		var glen_a := rng.randf() * PI
		var glen_len := rng.randf_range(8.0, 10.0)
		var glen_bend := rng.randf_range(-3.5, 3.5)
		var glen_wide := size > 0.6 and big < BIG_MOST      # a few glens are broad: 16 to 20 tiles long and 8 or so across
		var reach := maxf(rx, ry) if not glen else glen_len * 0.8 + 2.0
		if r > _ring_limit(a) - 7.0:
			continue
		var at := centre + Vector2(cos(a), sin(a)) * r
		if at.distance_to(m.base_at) < 31.0:
			continue
		var ok := true
		for k in s_at.size():
			# Far enough apart that rock always stands between two places, however big they are.
			if at.distance_to(s_at[k]) < maxf(s_need[k], reach + s_reach[k] + 4.5):
				ok = false
				break
		if not ok:
			continue
		var p := {"at": at, "rx": rx, "ry": ry, "sealed": false, "gate": false, "site": "", "glen": glen, "lobes": lobes, "reach": reach}
		if glen:
			p["glen_dir"] = Vector2(cos(glen_a), sin(glen_a)) * glen_len
			p["glen_bend"] = glen_bend
			p["rx"] = 4.0 if glen_wide else 3.0
			p["ry"] = 3.4 if glen_wide else 2.6
		m.pockets.append(p)
		s_at.append(at)
		s_need.append(SPACING)
		s_reach.append(reach)
		if float(p["rx"]) >= 8.0 or (glen and float(p["rx"]) > 3.4):
			big += 1


func _carve_pocket(p: Dictionary) -> void:
	var at: Vector2 = p["at"]
	if bool(p["glen"]):
		# A glen: a long place between two walls, bent a little, wider in some stretches than others.
		var d: Vector2 = p["glen_dir"]
		var across := Vector2(-d.y, d.x).normalized()
		var steps := int(d.length() * 2.0)
		for s in range(-steps, steps + 1):
			var t := float(s) / float(steps)
			var q := at + d * t + across * (float(p["glen_bend"]) * (t * t - 0.35) + sin(float(s) * 0.21) * 1.0)
			var fat := 0.75 + _noise(q.x, q.y, 6.0, 37) * 0.5
			_blob(q, (float(p["rx"]) - 0.1) * fat, (float(p["ry"]) - 0.1) * fat, 0.25)
		return
	_blob(at, float(p["rx"]), float(p["ry"]), 0.5)
	for lobe in p["lobes"]:
		_blob(at + lobe[0], float(lobe[1]), float(lobe[2]), 0.4)
	if p.has("arms"):
		# A hollow in a canyon (the Slinger Roost): the canyon runs out from it both ways, as a glen does.
		var arms: Dictionary = p["arms"]
		var d: Vector2 = arms["dir"]
		var across := Vector2(-d.y, d.x).normalized()
		var steps := int(d.length() * 2.0)
		for s in range(-steps, steps + 1):
			var t := float(s) / float(steps)
			var q := at + d * t + across * (float(arms["bend"]) * (t * t - 0.35) + sin(float(s) * 0.21) * 1.0)
			var fat := 0.75 + _noise(q.x, q.y, 6.0, 37) * 0.5
			_blob(q, float(arms["rx"]) * fat, float(arms["ry"]) * fat, 0.25)


## True if a straight way from a to b keeps clear of the base's hills.
func _clear_of_base(a: Vector2, b: Vector2) -> bool:
	var near := Geometry2D.get_closest_point_to_segment(m.base_at, a, b)
	return near.distance_to(m.base_at) >= m.base_r.x + HILL_KEEP


func _links() -> void:
	var n := inner_n               # the base's and the inner ring's places: the rings beyond have their own ways (_far_links)
	var at := PackedVector2Array()
	var in_tree := PackedByteArray()
	var best := PackedFloat64Array()
	var from := PackedInt32Array()
	var degree := PackedInt32Array()
	for i in n:
		var gate := bool(m.pockets[i]["gate"])
		at.append(m.pockets[i]["at"])
		in_tree.append(1 if gate else 0)
		best.append(INF)
		from.append(-1)
		degree.append(1 if gate else 0)
	var edges: Array = []
	for i in n:
		if in_tree[i] == 1:
			_relax(i, n, at, in_tree, best, from)
	# Join every place to the nearest one already joined, so all of them hang together.
	while true:
		var pick := -1
		for j in n:
			if in_tree[j] == 0 and best[j] < INF and (pick < 0 or best[j] < best[pick]):
				pick = j
		if pick < 0:
			break
		in_tree[pick] = 1
		edges.append([from[pick], pick])
		degree[from[pick]] += 1
		degree[pick] += 1
		_relax(pick, n, at, in_tree, best, from)
	# About one in ten is sealed off: a dead end loses its way in, for the pickaxe to find.
	var leaves: Array = []
	for e in edges:
		var j: int = e[1]
		if degree[j] == 1 and str(m.pockets[j]["site"]) == "":
			leaves.append(e)
	var seal := mini(int(round(float(n) * 0.10)), leaves.size())
	for s in seal:
		var k := rng.randi() % leaves.size()
		var e: Array = leaves[k]
		leaves.remove_at(k)
		edges.erase(e)
		m.pockets[int(e[1])]["sealed"] = true
	for i in n:
		if in_tree[i] == 0:
			m.pockets[i]["sealed"] = true
	# A few more ways between near neighbours, so the map has loops and not only dead ends.
	var sealed := PackedByteArray()
	for i in n:
		sealed.append(1 if bool(m.pockets[i]["sealed"]) else 0)
	var joined := {}
	for e in edges:
		joined[int(e[0]) * 4096 + int(e[1])] = true
		joined[int(e[1]) * 4096 + int(e[0])] = true
	for i in n:
		if sealed[i] == 1:
			continue
		var a := at[i]
		for j in range(i + 1, n):
			if sealed[j] == 1:
				continue
			var b := at[j]
			if a.distance_to(b) >= SPACING * 1.45 or joined.has(i * 4096 + j):
				continue
			if _clear_of_base(a, b) and rng.randf() < 0.30 and not _crosses(i, j, edges):
				edges.append([i, j])
				joined[i * 4096 + j] = true
				joined[j * 4096 + i] = true
	for e in edges:
		_cut_way(int(e[0]), int(e[1]), rng)


## A place has joined the others: every place still outside looks whether it is now nearer to them.
func _relax(i: int, n: int, at: PackedVector2Array, in_tree: PackedByteArray, best: PackedFloat64Array, from: PackedInt32Array) -> void:
	var a := at[i]
	for j in n:
		if in_tree[j] == 1:
			continue
		var b := at[j]
		var d := a.distance_to(b)
		if d < best[j] and _clear_of_base(a, b):
			best[j] = d
			from[j] = i


## Cuts the way between two places that are joined: a natural gap that sways and widens, or now and then an old
## dug tunnel. `through` is a pass through the belt of rock between two rings.
func _cut_way(i: int, j: int, dice: RandomNumberGenerator, tunnel_share := 0.15, through := false, road := false) -> void:
	var pa: Dictionary = m.pockets[i]
	var pb: Dictionary = m.pockets[j]
	var a: Vector2 = pa["at"]
	var b: Vector2 = pb["at"]
	var plain := str(pa["site"]) == "" and str(pb["site"]) == "" and not through
	var tunnel := plain and a.distance_to(b) < 34.0 and dice.randf() < tunnel_share
	var width := 2 if dice.randf() < 0.6 else 3
	var footpath := dice.randf() < 0.65
	var sway := dice.randf_range(2.0, 4.2)
	if tunnel:
		# An old dug tunnel: two wide and nearly straight (it was cut on purpose), with a floor of cut rock and lanterns along it.
		tunnels.append(_corridor(a, b, 2, 0.05, FLOOR, 0, 0.8, dice))
	else:
		# A natural gap: it sways, and is anything from two to six tiles wide along its length.
		var middle := _corridor(a, b, width, 0.24, GRASS, 6 - width, sway, dice)
		for at in middle:
			if dice.randf() < 0.06:
				_blob(Vector2(at) + Vector2(dice.randf_range(-0.5, 1.5), dice.randf_range(-0.5, 1.5)), dice.randf_range(1.5, 2.5), dice.randf_range(1.3, 2.0), 0.4)
		if road:
			_lay(middle, YARD)          # the one road in to the Scrapyard: a trodden track
		elif footpath or through:
			_lay(middle, PATH)          # (a pass through the belt between two rings always has its footpath)
	var link := {"a": i, "b": j, "tunnel": tunnel}
	if through:
		link["pass"] = true
	m.links.append(link)


## True if a straight line between places i and j would cut across a way that is already there.
func _crosses(i: int, j: int, edges: Array) -> bool:
	var a: Vector2 = m.pockets[i]["at"]
	var b: Vector2 = m.pockets[j]["at"]
	var lo := a.min(b)
	var hi := a.max(b)
	for e in edges:
		var p: int = e[0]
		var q: int = e[1]
		if p == i or p == j or q == i or q == j:
			continue
		var c: Vector2 = m.pockets[p]["at"]
		var d: Vector2 = m.pockets[q]["at"]
		# (Two lines whose boxes do not touch cannot cross.)
		if maxf(c.x, d.x) < lo.x or minf(c.x, d.x) > hi.x or maxf(c.y, d.y) < lo.y or minf(c.y, d.y) > hi.y:
			continue
		if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
			return true
	return false


## No wall of rock is left one tile thick, and no single tile of rock stands alone:
## rock is in lumps you can dig into.
##
## A tile of rock is opened if open ground lies on both sides of it. The land is gone over in reading order, up to six
## times; but only the tiles that could change are ever looked at. The first time those are the rock tiles with an
## opened tile on one side and open ground on the other (found from the list of everything that was opened). Opening
## a tile can only matter to the four tiles beside it: the two that come later in reading order are looked at in the
## same going-over, the two that come earlier in the next. (This gives the very land that looking at every tile of it
## six times gave.)
func _tidy() -> void:
	var x0 := maxi(m.region.position.x + 2, lock_lo)
	var x1 := mini(m.region.end.x - 2, lock_hi + 1)
	var y0 := maxi(m.region.position.y + 2, lock_lo)
	var y1 := mini(m.region.end.y - 2, lock_hi + 1)
	var next := {}                 # row -> [x]: the tiles to look at in the next going-over
	for i in opened:
		var k := K[i]
		if k == ROCK or k == TIN or k == COPPER:
			continue               # (opened, and then buried again under a fall of rock)
		var r := K[i + 1]
		if r == ROCK or r == TIN or r == COPPER:
			var rr := K[i + 2]
			if rr != ROCK and rr != TIN and rr != COPPER:
				_tidy_later(next, i % S + 1, i / S)
		var d := K[i + S]
		if d == ROCK or d == TIN or d == COPPER:
			var dd := K[i + S + S]
			if dd != ROCK and dd != TIN and dd != COPPER:
				_tidy_later(next, i % S, i / S + 1)
	var changed := 1
	for pass_i in 6:
		if changed == 0:
			break
		changed = 0
		var now := next
		next = {}
		for y in range(y0, y1):
			if not now.has(y):
				continue
			var xs: Array = now[y]
			xs.sort()
			var n := 0
			while n < xs.size():
				var x: int = xs[n]
				n += 1
				if x < x0 or x >= x1:
					continue
				var i := y * S + x
				var k := K[i]
				if (k != ROCK and k != TIN and k != COPPER) or _locked(x, y):
					continue
				if _tidy_tile(x, y, i):
					changed += 1
					_tidy_later(next, x - 1, y)
					_tidy_later(next, x, y - 1)
					if y + 1 < y1:
						_tidy_later(now, x, y + 1)
					if n >= xs.size() or int(xs[n]) != x + 1:
						xs.insert(n, x + 1)
	# Everything that is open is open now: the list of it goes into reading order, each tile once.
	opened.sort()
	var once := PackedInt32Array()
	var last := -1
	for i in opened:
		if i != last:
			once.append(i)
			last = i
	opened = once


func _tidy_later(rows: Dictionary, x: int, y: int) -> void:
	if not rows.has(y):
		rows[y] = []
	(rows[y] as Array).append(x)


## Opens this tile of rock (not locked; i is its index) if open ground lies on both sides of it. True if it did.
func _tidy_tile(x: int, y: int, i: int) -> bool:
	if x >= MID - 4 and x <= MID + 4 and y <= MID and y >= MID - 6:
		return false
	if x >= yl_x0 and x < yl_x1 and y >= yl_y0 and y < yl_y1:
		return false
	var up := K[i - S]
	var down := K[i + S]
	var left := K[i - 1]
	var right := K[i + 1]
	var ns_open := up != ROCK and up != TIN and up != COPPER and down != ROCK and down != TIN and down != COPPER
	var ew_open := left != ROCK and left != TIN and left != COPPER and right != ROCK and right != TIN and right != COPPER
	if not (ns_open or ew_open):
		return false
	K[i] = FLOOR if (up == FLOOR or down == FLOOR or left == FLOOR or right == FLOOR) else GRASS
	opened.append(i)
	return true


## Lanterns along the old tunnels, about every nine tiles, each standing at the
## foot of a wall (the one above it if there is one, else the one to its left).
func _tunnel_lamps() -> void:
	for middle in tunnels:
		var since := 4
		for at in middle:
			since += 1
			if since < 9 or m.kind(at.x, at.y) != FLOOR:
				continue
			var foot := Vector2i(-1, -1)
			if m.is_rock(at.x, at.y - 1):
				foot = Vector2i(at.x * 16 + 8, at.y * 16 + 8)
			elif m.is_rock(at.x - 1, at.y):
				foot = Vector2i(at.x * 16 + 5, at.y * 16 + 13)
			if foot.x < 0:
				continue
			since = 0
			m.lamps.append({"x": foot.x, "y": foot.y - 6, "r": 46})
			m.things.append({"n": "lantern", "x": foot.x, "y": foot.y, "f": false})


## A footpath is one tile wide. Where two of them ran side by side and made a
## block, the tile that nothing else hangs on goes back to grass. (Only the tiles that were ever laid as a track are
## looked at, in reading order.)
func _thin_paths() -> void:
	var tiles: Array = laid.keys()
	tiles.sort()
	var x0 := m.region.position.x + 2
	var x1 := m.region.end.x - 2
	var y0 := m.region.position.y + 2
	var y1 := m.region.end.y - 2
	for pass_i in 3:
		var changed := 0
		for i: int in tiles:
			var k := K[i]
			if (k != PATH and k != YARD) or K[i + 1] != k or K[i + S] != k or K[i + S + 1] != k:
				continue
			var x := i % S
			var y := i / S
			if x < x0 or x >= x1 or y < y0 or y >= y1:
				continue
			# One of the four has no neighbour of its kind outside the block: that one is spare.
			for c in [Vector2i(x + 1, y + 1), Vector2i(x, y + 1), Vector2i(x + 1, y), Vector2i(x, y)]:
				var outside := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = c + d
					if (q.x < x or q.x > x + 1 or q.y < y or q.y > y + 1) and m.kind(q.x, q.y) == k:
						outside += 1
				if outside == 0:
					m.set_kind(c.x, c.y, GRASS)
					changed += 1
					break
		if changed == 0:
			break


# --- Checks ---------------------------------------------------------------------------

## Every open place that is not sealed can be walked to from the cave mouth, the
## sealed ones cannot, and the share of open land is about a third. Beyond the inner ring a plain place that the
## ways missed is no fault: it is one more for the pickaxe to find. A named place must always be reached.
func _check() -> bool:
	var seen := m.reach(Vector2i(floori(m.spawn.x), floori(m.spawn.y)))
	for idx in m.pockets.size():
		var p: Dictionary = m.pockets[idx]
		var at := Vector2i(floori(p["at"].x), floori(p["at"].y))
		var got := m.reached(seen, at.x, at.y)
		if not got and m.walkable(at.x, at.y) == false and not bool(p["sealed"]):
			# Its very middle is taken (a rock, a tarn): look at the tiles round it.
			for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				if m.reached(seen, at.x + d.x, at.y + d.y):
					got = true
		if bool(p["sealed"]) and got:
			if p.has("cavern"):
				why = "the Fault's cavern is not hidden"
				return false
			p["sealed"] = false        # another way happened to pass through it
		elif not bool(p["sealed"]) and not got:
			if idx >= inner_n and str(p["site"]) == "":
				p["sealed"] = true
				continue
			why = "a place cannot be reached"
			return false
	for name in m.sites:
		if bool(m.pockets[int(m.sites[name]["pocket"])]["sealed"]):
			why = "a named place is sealed"
			return false
	var share := m.open_share(28.0, RING_INNER - 4.0)
	if share < 0.22 or share > 0.42:
		why = "open land is %d%% of the inner ring" % int(share * 100.0)
		return false
	if m.pockets.size() < 20:
		why = "too few open places"
		return false
	return true


# --- What the open places hold ------------------------------------------------------

## Grass with nothing on or beside it but more grass: somewhere a solid thing can
## stand without ever narrowing a way through.
func _roomy(x: int, y: int) -> bool:
	if x < 1 or y < 1 or x >= S - 1 or y >= S - 1:
		return false
	var i := y * S + x
	for j in [-S, 0, S]:
		for d in [-1, 0, 1]:
			var k := K[i + j + d]
			if k != GRASS and k != SCRUB and k != HEATH:
				return false
	return true


func _grassy(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= S or y >= S:
		return false
	var k := K[y * S + x]
	return k == GRASS or k == SCRUB or k == HEATH


## The tiles of one open place, sorted into kinds of spot. Always in the same order.
func _spots(p: Dictionary) -> Dictionary:
	var roomy: Array = []
	var foot: Array = []
	var bank: Array = []
	var rim: Array = []
	var wide: Array = []
	var at: Vector2 = p["at"]
	var grow := 12.0 if bool(p["glen"]) else (14.0 if p.has("arms") else 4.0)
	var ex := float(p["rx"]) + grow
	var ey := float(p["ry"]) + grow
	var x0 := maxi(floori(at.x - ex), 4)
	var x1 := mini(ceili(at.x + ex), S - 5)
	var y0 := maxi(floori(at.y - ey), 4)
	var y1 := mini(ceili(at.y + ey), S - 5)
	# Which tiles are grass, and which of those have grass all round them, worked out once for the whole place
	# (and three tiles past it, which is as far as "wide" looks).
	var gx := x0 - 3
	var gy := y0 - 3
	var gw := x1 - x0 + 7
	var gh := y1 - y0 + 7
	if gw < 7 or gh < 7:
		return {"roomy": roomy, "foot": foot, "bank": bank, "rim": rim, "wide": wide}
	var grass := PackedByteArray()
	grass.resize(gw * gh)
	for j in gh:
		var row := (gy + j) * S + gx
		var to := j * gw
		for i in gw:
			var k := K[row + i]
			if k == GRASS or k == SCRUB or k == HEATH:
				grass[to + i] = 1
	var room := PackedByteArray()
	room.resize(gw * gh)
	for j in range(1, gh - 1):
		for i in range(1, gw - 1):
			var c := j * gw + i
			if grass[c] == 1 and grass[c - 1] == 1 and grass[c + 1] == 1 and grass[c - gw] == 1 and grass[c + gw] == 1 \
					and grass[c - gw - 1] == 1 and grass[c - gw + 1] == 1 and grass[c + gw - 1] == 1 and grass[c + gw + 1] == 1:
				room[c] = 1
	for y in range(y0, y1 + 1):
		var row := y * S
		var to := (y - gy) * gw - gx
		for x in range(x0, x1 + 1):
			var i := row + x
			var k := K[i]
			var up := K[i - S]
			if k == ROCK or k == TIN or k == COPPER:
				if k == ROCK and not _locked(x, y):
					var down := K[i + S]
					var left := K[i - 1]
					var right := K[i + 1]
					if (down != ROCK and down != TIN and down != COPPER and down != WATER) or (up != ROCK and up != TIN and up != COPPER and up != WATER) \
							or (left != ROCK and left != TIN and left != COPPER and left != WATER) or (right != ROCK and right != TIN and right != COPPER and right != WATER):
						rim.append(Vector2i(x, y))
				continue
			var c := to + x
			if grass[c] == 0:
				continue
			if room[c] == 1:
				roomy.append(Vector2i(x, y))
				if room[c + 2] == 1 and room[c - 2] == 1 and room[c + 2 * gw] == 1 and room[c - 2 * gw] == 1 \
						and room[c + 2 * gw + 2] == 1 and room[c + 2 * gw - 2] == 1 and room[c - 2 * gw + 2] == 1 and room[c - 2 * gw - 2] == 1:
					wide.append(Vector2i(x, y))
			if k == GRASS and (up == ROCK or up == TIN or up == COPPER):
				foot.append(Vector2i(x, y))
			if up == WATER or K[i - 1] == WATER or K[i + 1] == WATER:
				bank.append(Vector2i(x, y))
	return {"roomy": roomy, "foot": foot, "bank": bank, "rim": rim, "wide": wide}


func _take(list: Array, taken: Array, apart: float, dice: RandomNumberGenerator = null) -> Vector2i:
	if dice == null:
		dice = rng
	for t in 12:
		if list.is_empty():
			break
		var at: Vector2i = list[dice.randi() % list.size()]
		var ok := true
		for o in taken:
			if Vector2(at).distance_to(Vector2(o)) < apart:
				ok = false
		if ok:
			taken.append(at)
			return at
	return Vector2i(-1, -1)


## Things are never mirrored: the light comes from the upper left on every one of them.
func _thing(name: String, tile: Vector2i, dx := 8, dy := 11, _flip := false) -> void:
	m.things.append({"n": name, "x": tile.x * 16 + dx, "y": tile.y * 16 + dy, "f": false})


## An animal is a thing too (it throws a shadow, and a cow stops you), and is listed in `animals` as well.
func _animal(kind: String, x: int, y: int, flip: bool) -> void:
	m.things.append({"n": kind, "x": x, "y": y, "f": flip})
	m.animals.append({"kind": kind, "x": x, "y": y, "f": flip})


## A lump of rock standing in a few of the bigger places, two tiles thick at least.
func _outcrops() -> void:
	for idx in m.pockets.size():
		var p: Dictionary = m.pockets[idx]
		var dice := rng if idx < inner_n else far
		if bool(p["gate"]) or bool(p["glen"]) or str(p["site"]) != "" or float(p["rx"]) < 5.4 or dice.randf() > float(RING[int(p["ring"])]["outcrop"]):
			continue
		var spots := _spots(p)
		if spots["wide"].is_empty():
			continue
		var at: Vector2i = spots["wide"][dice.randi() % spots["wide"].size()]
		var w := 2 + dice.randi() % 2
		for j in 2:
			for i in w:
				if _roomy(at.x + i, at.y + j) or m.is_rock(at.x + i - 1, at.y + j) or m.is_rock(at.x + i, at.y + j - 1):
					m.set_kind(at.x + i, at.y + j, ROCK)
		# Put back anything that would leave a way one tile wide.
		for j in range(-1, 3):
			for i in range(-1, w + 1):
				var x := at.x + i
				var y := at.y + j
				if m.is_rock(x, y):
					continue
				if (m.is_rock(x - 1, y) and m.is_rock(x + 1, y)) or (m.is_rock(x, y - 1) and m.is_rock(x, y + 1)):
					for jj in 2:
						for ii in w:
							m.set_kind(at.x + ii, at.y + jj, GRASS)


## A tarn in some places: small, off the path, with grass all the way round it so
## it never blocks a way.
func _water() -> void:
	for idx in m.pockets.size():
		var p: Dictionary = m.pockets[idx]
		var dice := rng if idx < inner_n else far
		if bool(p["gate"]) or bool(p["glen"]) or str(p["site"]) != "" or float(p["rx"]) < 5.0 or dice.randf() > float(RING[int(p["ring"])]["tarn"]):
			continue
		var spots := _spots(p)
		if spots["wide"].is_empty():
			continue
		var at: Vector2i = spots["wide"][dice.randi() % spots["wide"].size()]
		var pool: Array = [at, at + Vector2i(1, 0)]
		if _roomy(at.x + 2, at.y) and dice.randf() < 0.6:
			pool.append(at + Vector2i(2, 0))
		for c in pool.duplicate():
			if dice.randf() < 0.7:
				pool.append(c + Vector2i(0, 1))
		var ok := true
		for c in pool:
			if not _roomy(c.x, c.y):
				ok = false
		if not ok:
			continue
		for c in pool:
			m.set_kind(c.x, c.y, WATER)
		p["tarn"] = true


func _tone_and_cover() -> void:
	# Hollows and rises: the grass a step darker or lighter in broad patches.
	var tones := m.tones
	var broad := RowNoise.new(8.0, 41 + ns)
	var fine := RowNoise.new(2.6, 43 + ns)
	var round_it := PackedInt32Array([-S - 1, -S, -S + 1, -1, 0, 1, S - 1, S, S + 1])
	var row_y := -1
	for i in opened:
		var here := K[i]
		if here == ROCK or here == TIN or here == COPPER:
			continue
		var y := i / S
		var x := i - y * S
		if y != row_y:
			broad.row(y)
			fine.row(y)
			row_y = y
		# (Two sizes of noise together, so a patch has a ragged outline and never a square one.)
		var t := broad.at(x) * 0.62 + fine.at(x) * 0.38
		var tone := 0 if t < 0.40 else (2 if t > 0.58 else 1)
		if tone == 0:
			# A track must stay easy to see: no dark hollow on it or beside it.
			for off in round_it:
				var k := K[i + off]
				if k == YARD or k == PATH:
					tone = 1
					break
		if K[i + 1] == WATER or K[i - 1] == WATER or K[i + S] == WATER or K[i - S] == WATER:
			tone = 0
		tones[i] = tone
	# Heather and sage scrub, each in one patch at least three tiles across, in under half the places.
	for idx in m.pockets.size():
		var p: Dictionary = m.pockets[idx]
		var dice := rng if idx < inner_n else far
		var rule: Dictionary = RING[int(p["ring"])]
		if (bool(p["gate"]) and dice.randf() < 0.5) or str(p["site"]) != "":
			continue
		for pair in [[HEATH, rule["heath"]], [SCRUB, rule["scrub"]]]:
			if dice.randf() > float(pair[1]):
				continue
			var at: Vector2 = p["at"]
			var a := dice.randf() * TAU
			var c := at + Vector2(cos(a) * float(p["rx"]) * 0.55, sin(a) * float(p["ry"]) * 0.55)
			var r := dice.randf_range(1.7, 2.7)
			for y in range(floori(c.y - r - 1.0), ceili(c.y + r + 1.0)):
				for x in range(floori(c.x - r - 1.0), ceili(c.x + r + 1.0)):
					var d := Vector2(float(x) + 0.5 - c.x, (float(y) + 0.5 - c.y) * 1.25).length()
					if d <= r + (_noise(x, y, 2.5, 57) - 0.5) * 1.2 and m.kind(x, y) == GRASS:
						m.set_kind(x, y, int(pair[0]))


## Scree: small stones lying at the foot of the rock in some stretches, never out
## in the open and never on a track. (Detail goes where there is a reason for it.)
func _scree() -> void:
	var keep_clear := m.base.grow(3.0)
	var broad := RowNoise.new(6.0, 71 + ns)
	var fine := RowNoise.new(2.4, 72 + ns)
	# How readily, by ring (the inner ring's edge wobbles out to 131 tiles, so its rule holds that far).
	var out1 := 131 * 131
	var out2 := int(RINGS[2]) * int(RINGS[2])
	var under1 := float(RING[1]["scree"][0])
	var beside1 := float(RING[1]["scree"][1])
	var under2 := float(RING[2]["scree"][0])
	var beside2 := float(RING[2]["scree"][1])
	var under3 := float(RING[3]["scree"][0])
	var beside3 := float(RING[3]["scree"][1])
	var beside_it := PackedInt32Array([-1, 1, -S - S, -S - 1, -S + 1])
	var row_y := -1
	var dy2 := 0
	for i in opened:
		if K[i] != GRASS:
			continue
		var up := K[i - S]
		var under := up == ROCK or up == TIN or up == COPPER                           # right under a face
		var beside := false
		for off in beside_it:
			var k := K[i + off]
			if k == ROCK or k == TIN or k == COPPER:
				beside = true
				break
		if not (under or beside):
			continue
		var y := i / S
		var x := i - y * S
		if keep_clear.has_point(Vector2(x, y)):
			continue
		if y != row_y:
			broad.row(y)
			fine.row(y)
			row_y = y
			dy2 = (y - MID) * (y - MID)
		var n := broad.at(x) * 0.7 + fine.at(x) * 0.3
		var d2 := dy2 + (x - MID) * (x - MID)
		var t_under := under1
		var t_beside := beside1
		if d2 > out2:
			t_under = under3
			t_beside = beside3
		elif d2 > out1:
			t_under = under2
			t_beside = beside2
		if (under and n > t_under) or (beside and n > t_beside):
			K[i] = SCREE


## Heather and scrub are plants, not paint: every bush stands on its own with
## ground showing all round it, thick in the middle of a patch and thinning to
## single plants at its edge. This is the art's own way of placing them (hl3.py,
## "scatter"): try a spot, and keep the plant only if it touches no other.
func _cover_plants() -> void:
	Painter.load_kit()
	var feet := {}                         # tile index -> [feet of the things standing there]
	for t in m.things:
		var key := (int(t["y"]) >> 4) * S + (int(t["x"]) >> 4)
		if not feet.has(key):
			feet[key] = []
		feet[key].append(Vector2i(int(t["x"]), int(t["y"])))
	var placed := {}                       # tile index -> [Rect2i of each plant whose foot is there]
	var names := {HEATH: [], SCRUB: []}
	var boxes := {HEATH: [], SCRUB: []}
	for n in 12:
		for pair in [[HEATH, "heath_%d"], [SCRUB, "scrub_%d"]]:
			var name: String = str(pair[1]) % n
			names[pair[0]].append(name)
			boxes[pair[0]].append(Painter.boxes[name])
	var inner2 := 131 * 131
	for at_i in opened:
		if true:
			var k := K[at_i]
			if k != HEATH and k != SCRUB:
				continue
			var y := at_i / S
			var x := at_i - y * S
			var row := y * S
			var dy2 := (y - MID) * (y - MID)
			var dice := rng if dy2 + (x - MID) * (x - MID) <= inner2 else far
			var same := 0
			for j in [-S, 0, S]:
				for i in [-1, 0, 1]:
					if K[row + x + j + i] == k:
						same += 1
			var chance := clampf((float(same) / 9.0 - 0.28) / 0.36, 0.04, 1.0)
			var its_names: Array = names[k]
			var its_boxes: Array = boxes[k]
			for t in (26 if k == HEATH else 9):
				var px := x * 16 + dice.randi() % 16
				var py := y * 16 + dice.randi() % 16
				var which := dice.randi() % 12
				if dice.randf() > chance:
					continue
				var box: Rect2i = its_boxes[which]
				var r := Rect2i(px + box.position.x, py + box.position.y, box.size.x, box.size.y)
				# All of it on grass, with room to spare: never against rock, water, a track or scree.
				var wide := r.grow(4)
				if not (_grassy(wide.position.x >> 4, wide.position.y >> 4) and _grassy(wide.end.x >> 4, wide.position.y >> 4) and _grassy(wide.position.x >> 4, wide.end.y >> 4) \
						and _grassy(wide.end.x >> 4, wide.end.y >> 4) and _grassy(px >> 4, py >> 4)):
					continue
				# Never touching another plant (a pixel of ground between them at least), nor under a thing's feet.
				var mine := r.grow(1)
				var ok := true
				for j in range(-2, 3):
					for i in range(-2, 3):
						var key := (y + j) * S + x + i
						if placed.has(key):
							for other in placed[key]:
								if mine.intersects(other):
									ok = false
						if feet.has(key):
							for f in feet[key]:
								if absi(f.x - px) < 14 and f.y - py > -12 and f.y - py < 10:
									ok = false
				if not ok:
					continue
				var home := row + x
				if not placed.has(home):
					placed[home] = []
				placed[home].append(r)
				m.plants.append({"n": its_names[which], "x": px, "y": py})


## Ore: a cluster of ore tiles that starts in rock you can see from open ground and runs into the hill. What shows
## of it is drawn as seams through the whole cluster (veins.gd): they come in at its top and run down, about one
## for every two and a half tiles of its width. So a cluster is wider than it is tall, at most 6 tiles by 4, and it
## keeps clear of any other cluster.
func _vein(start: Vector2i, n: int, k: int, dice: RandomNumberGenerator = null) -> int:
	if dice == null:
		dice = ore
	if m.kind(start.x, start.y) != ROCK or _locked(start.x, start.y) or _ore_near(start, {}):
		return 0
	var lump: Array = [start]
	var own := {start: true}
	var box := Rect2i(start, Vector2i.ONE)
	m.set_kind(start.x, start.y, k)
	for t in n * 10:
		if lump.size() >= n:
			break
		var from: Vector2i = lump[dice.randi() % lump.size()]
		var d: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, -1), Vector2i(0, 1)][dice.randi() % 7]
		var at := from + d
		var grown := box.merge(Rect2i(at, Vector2i.ONE))
		if grown.size.x > 6 or grown.size.y > 4:
			continue
		if m.kind(at.x, at.y) == ROCK and not _locked(at.x, at.y) and not _ore_near(at, own):
			m.set_kind(at.x, at.y, k)
			lump.append(at)
			own[at] = true
			box = grown
	return lump.size()


## Is there ore within two tiles that is not part of this cluster?
func _ore_near(at: Vector2i, own: Dictionary) -> bool:
	if at.x < 2 or at.y < 2 or at.x >= S - 2 or at.y >= S - 2:
		return false
	var c := at.y * S + at.x
	for j in range(-2, 3):
		for i in range(-2, 3):
			var k := K[c + j * S + i]
			if (k == TIN or k == COPPER) and not own.has(at + Vector2i(i, j)):
				return true
	return false


## Where the ore is. It has its own dice, so a change to the ore never moves the plants and stones.
func _ore() -> void:
	# In the hills round the base, so the first dig is also the first ore: two clusters of tin and two of copper
	# (the Game Bible: "tin and copper veins in the hill above the forge"). First choice is rock with open ground
	# to its south: its lit face is what you look at from the clearing, and a seam shows brightest there.
	var rim: Array = []
	var faces: Array = []
	for y in range(floori(m.base.position.y) - 4, ceili(m.base.end.y) + 5):
		for x in range(floori(m.base.position.x) - 4, ceili(m.base.end.x) + 5):
			if m.kind(x, y) != ROCK or _locked(x, y) or (absi(x - MID) <= 6 and y <= MID + 1):
				continue
			if not (m.walkable(x, y + 1) or m.walkable(x, y - 1) or m.walkable(x - 1, y) or m.walkable(x + 1, y)):
				continue
			var ok := true
			for g in gap_starts:
				if Vector2(x, y).distance_to(g) < 5.0:
					ok = false
			if ok:
				rim.append(Vector2i(x, y))
				if m.walkable(x, y + 1):
					faces.append(Vector2i(x, y))
	var taken: Array = []
	for i in 4:
		for go in 5:
			var at := _take(faces, taken, 7.0 if go < 2 else 5.0, ore)
			if at.x < 0:
				at = _take(rim, taken, 7.0 if go < 2 else 5.0, ore)
			if at.x >= 0 and _vein(at, 6 + ore.randi() % 3, TIN if i % 2 == 0 else COPPER) > 0:
				break
	# In the rings: on the edge of about half the open places (more of them farther out, and more of it copper),
	# always in a sealed one, and clusters deep in the rock.
	for idx in m.pockets.size():
		var p: Dictionary = m.pockets[idx]
		if bool(p["gate"]):
			continue
		var dice := ore if idx < inner_n else far_ore
		var rule: Dictionary = RING[int(p["ring"])]
		var veins := 2 if bool(p["sealed"]) else (1 if dice.randf() < float(rule["vein"]) else 0)
		if veins == 0 or str(p["site"]) == "scrapyard":
			continue
		var spots := _spots(p)
		var south: Array = spots["rim"].filter(func(at): return m.walkable(at.x, at.y + 1))
		var used: Array = []
		var size: Array = rule["vein_size"]
		for v in veins:
			var at := Vector2i(-1, -1)
			if dice.randf() < 0.65:
				at = _take(south, used, 5.0, dice)
			if at.x < 0:
				at = _take(spots["rim"], used, 5.0, dice)
			if at.x >= 0:
				_vein(at, int(size[0]) + dice.randi() % int(size[1]), TIN if dice.randf() < float(rule["tin"]) else COPPER, dice)
	var deep := 0
	for t in 800:
		if deep >= DEEP_ORE:
			break
		var a := ore.randf() * TAU
		var r := ore.randf_range(30.0, RING_INNER)
		var at := Vector2i(MID + int(cos(a) * r), MID + int(sin(a) * r))
		var buried := true
		for j in range(-2, 3):
			for i in range(-2, 3):
				if K[(at.y + j) * S + at.x + i] != ROCK:
					buried = false
		if buried and _vein(at, 5 + ore.randi() % 4, TIN if ore.randf() < 0.5 else COPPER) > 0:
			deep += 1
	for ring in range(2, 4 if rings else 2):
		var rule: Dictionary = RING[ring]
		var want := int(rule["deep"])
		var r0 := float(RINGS[ring - 1]) + 4.0
		var r1 := float(RINGS[ring]) - 2.0
		deep = 0
		for t in want * 30:
			if deep >= want:
				break
			var a := far_ore.randf() * TAU
			var r := sqrt(far_ore.randf() * (r1 * r1 - r0 * r0) + r0 * r0)
			var at := Vector2i(MID + int(cos(a) * r), MID + int(sin(a) * r))
			var buried := true
			for j in range(-2, 3):
				for i in range(-2, 3):
					if K[(at.y + j) * S + at.x + i] != ROCK:
						buried = false
			if buried and _vein(at, 5 + far_ore.randi() % (3 + ring), TIN if far_ore.randf() < float(rule["deep_tin"]) else COPPER, far_ore) > 0:
				deep += 1


## Things on the land, a few to a place and well apart (Darren: "don't clutter it").
func _dress() -> void:
	# The clearing outside the cave: natural and nearly empty, nothing built.
	var base := {"at": m.base_at, "rx": m.base_r.x, "ry": m.base_r.y, "glen": false}
	var spots := _spots(base)
	var edge: Array = []
	for at in spots["roomy"]:
		var d := Vector2((float(at.x) + 0.5 - m.base_at.x) / m.base_r.x, (float(at.y) + 0.5 - m.base_at.y) / m.base_r.y).length()
		if d > 0.62 and Vector2(at).distance_to(Vector2(MID, MID + 2)) > 5.0:
			edge.append(at)
	var taken: Array = []
	for name in ["boulder_%d" % (rng.randi() % 3), "boulder_%d" % (3 + rng.randi() % 3), "bush_%d" % (rng.randi() % 4), "bush_%d" % (rng.randi() % 4), "pine_%d" % (4 + rng.randi() % 2)]:
		var at := _take(edge, taken, 5.0)
		if at.x >= 0:
			_thing(name, at, 4 + rng.randi() % 9, 9 + rng.randi() % 5, rng.randf() < 0.5)
	var feet: Array = spots["foot"].filter(func(at): return absi(at.x - MID) > 4)
	for i in 3:
		var at := _take(feet, taken, 4.0)
		if at.x >= 0:
			_thing("bracken_%d" % (rng.randi() % 4), at, 3 + rng.randi() % 10, 5 + rng.randi() % 3)
	var hare := _take(edge, taken, 4.0)
	if hare.x >= 0:
		_animal("hare", hare.x * 16 + 8, hare.y * 16 + 10, rng.randf() < 0.5)
	var crow := _take(edge, taken, 4.0)
	if crow.x >= 0:
		_animal("crow", crow.x * 16 + 5, crow.y * 16 + 9, false)
		_animal("crow", crow.x * 16 + 19, crow.y * 16 + 14, true)
	# The open places.
	var marks: Array = []          # [name, where] for every named place beyond the inner ring (the Scrapyard twice)
	for name in ["roost", "den", "cairns", "gorge", "fault", "scrapyard"]:
		if m.sites.has(name):
			marks.append([name, m.sites[name]["at"]])
	if yard.size.x > 0:
		marks.append(["scrapyard", Vector2(yard.get_center())])
	for idx in m.pockets.size():
		var p: Dictionary = m.pockets[idx]
		var dice := rng if idx < inner_n else far
		var rule: Dictionary = RING[int(p["ring"])]
		spots = _spots(p)
		taken = []
		var site := str(p["site"])
		match site:
			"watchpost":
				_dress_watchpost(p, spots, taken)
			"quarry":
				_dress_quarry(p, spots, taken)
			"roost":
				_dress_roost(p, spots, taken)
			"den":
				_dress_den(p, spots, taken)
			"cairns":
				_dress_cairns(p, spots, taken)
			"gorge":
				_dress_gorge(p, spots, taken)
			"fault":
				_dress_fault(p, spots, taken)
			"scrapyard":
				_dress_forecourt(p, spots, taken)
		if site != "":
			continue              # a named place holds its own few things and no more
		if dice.randf() < float(rule["pine"]):
			var back: Array = spots["roomy"].filter(func(at): return float(at.y) <= p["at"].y)
			for i in 1 + dice.randi() % 3:
				var at := _take(back, taken, 2.6, dice)
				if at.x >= 0:
					_thing("pine_%d" % (dice.randi() % 6), at, 4 + dice.randi() % 9, 9 + dice.randi() % 5, dice.randf() < 0.5)
		var boulders: Array = rule["boulder"]
		if dice.randf() < float(boulders[0]):
			for i in int(boulders[1]) + dice.randi() % (int(boulders[2]) - int(boulders[1]) + 1):
				var at := _take(spots["roomy"], taken, 3.2, dice)
				if at.x >= 0:
					_thing("boulder_%d" % (dice.randi() % 6), at, 4 + dice.randi() % 9, 9 + dice.randi() % 5, dice.randf() < 0.5)
		if dice.randf() < float(rule["bush"]):
			for i in 1 + dice.randi() % 2:
				var at := _take(spots["roomy"], taken, 3.2, dice)
				if at.x >= 0:
					_thing("bush_%d" % (dice.randi() % 4), at, 4 + dice.randi() % 9, 9 + dice.randi() % 5, dice.randf() < 0.5)
		if dice.randf() < float(rule["bracken"]):
			for i in 2 + dice.randi() % 3:
				var at := _take(spots["foot"], taken, 2.0, dice)
				if at.x >= 0:
					_thing("bracken_%d" % (dice.randi() % 4), at, 3 + dice.randi() % 10, 5 + dice.randi() % 3)
		var rare := dice.randf()
		var one := ""
		for row in rule["rare"]:
			if rare < float(row[0]):
				one = str(row[1])
				if int(row[2]) > 0:
					one = one % (dice.randi() % int(row[2]))
				break
		if one != "":
			var at := _take(spots["roomy"], taken, 3.2, dice)
			if at.x >= 0:
				_thing(one, at, 8, 11)
		if p.has("tarn"):
			var wet: Array = []
			for i in 2 + dice.randi() % 3:
				var at := _take(spots["bank"], wet, 1.0, dice)
				if at.x >= 0:
					_thing("reeds_%d" % (dice.randi() % 4), at, 3 + dice.randi() % 10, 2 + dice.randi() % 3)
			for i in 1 + dice.randi() % 2:
				var at := _take(spots["bank"], wet, 1.0, dice)
				if at.x >= 0:
					_thing("cotton_%d" % (dice.randi() % 3), at, 3 + dice.randi() % 10, 8 + dice.randi() % 5)
		# Near a named place the land says so (the research: a halo of changed ground): bones on the way to the Den,
		# goblin litter round the Scrapyard, a cairn or two towards Cairn Field.
		if idx >= inner_n and not bool(p["sealed"]):
			_tell(p, spots, taken, marks)
		# Life, in a few places only: cattle grazing, a hare, a pair of crows.
		if not bool(p["gate"]):
			var life := dice.randf()
			if life < float(rule["cow"]) and float(p["rx"]) >= 5.2:
				for i in 1 + dice.randi() % 3:
					var at := _take(spots["roomy"], taken, 2.4, dice)
					if at.x >= 0:
						_animal("cow", at.x * 16 + 8, at.y * 16 + 11, dice.randf() < 0.5)
			elif life < float(rule["hare"]):
				var at := _take(spots["roomy"], taken, 3.0, dice)
				if at.x >= 0:
					_animal("hare", at.x * 16 + 8, at.y * 16 + 10, dice.randf() < 0.5)
			elif life < float(rule["crow"]):
				var at := _take(spots["roomy"], taken, 3.0, dice)
				if at.x >= 0:
					_animal("crow", at.x * 16 + 5, at.y * 16 + 9, false)
					_animal("crow", at.x * 16 + 19, at.y * 16 + 14, true)
					if dice.randf() < 0.4 and _roomy(at.x + 2, at.y):
						_animal("crow", at.x * 16 + 36, at.y * 16 + 8, false)


## The Watchpost's ground for now: a scrap of the keepers' road, two of their
## posts and a cairn. The waystone, the journal and the thread come later.
func _dress_watchpost(p: Dictionary, spots: Dictionary, taken: Array) -> void:
	var at: Vector2 = p["at"]
	var k := rng.randi() % 12
	for i in 3:
		m.decals.append({"n": "road_%d" % ((k + i * 5) % 12), "x": int((at.x + float(i - 1) * 4.2) * 16.0), "y": int((at.y + 1.2 + float(i % 2) * 0.6) * 16.0)})
	for side in [-1, 1]:
		var post := Vector2i(int(at.x) + side * 3, int(at.y) - 1)
		if _roomy(post.x, post.y):
			_thing("post", post, 8, 11)
			taken.append(post)
	var cairn := Vector2i(int(at.x), int(at.y) - 2)
	if _roomy(cairn.x, cairn.y):
		_thing("cairn_0", cairn, 8, 11)
		taken.append(cairn)


## The Old Quarry's ground for now: the old cut with a lantern, a barrel and
## fallen stone. The elite, the tongs and the cave-in come later.
func _dress_quarry(_p: Dictionary, _spots: Dictionary, _taken: Array) -> void:
	var cut: Rect2i = m.sites["quarry"]["cut"]
	var floors: Array = []
	for y in range(cut.position.y, cut.end.y):
		for x in range(cut.position.x, cut.end.x):
			if m.kind(x, y) == FLOOR:
				floors.append(Vector2i(x, y))
	if floors.size() < 6:
		return
	var used: Array = []
	var lamp := _take(floors, used, 2.0)
	m.lamps.append({"x": lamp.x * 16 + 8, "y": lamp.y * 16 + 6, "r": 46})
	_thing("lantern", lamp, 8, 12)
	var barrel := _take(floors, used, 2.0)
	if barrel.x >= 0:
		_thing("barrel", barrel, 8, 12)
	for i in 2:
		var at := _take(floors, used, 2.0)
		if at.x >= 0:
			_thing("rubble", at, 8, 12)


# --- What the named places beyond the inner ring hold ---------------------------------
#
# Their ground only: who lives there is the enemies' plan (foe_plan.gd), and what is done there comes with the
# quests. All of it is the kit's own boulders, rubble, cairns and bones: no new art.

## The tiles of `list` whose distance from the place's middle, counted in the place's own half-widths, lies between
## `from` and `to` (1.0 is its edge).
func _band(list: Array, p: Dictionary, from: float, to: float) -> Array:
	var at: Vector2 = p["at"]
	var out: Array = []
	for t: Vector2i in list:
		var d := Vector2((float(t.x) + 0.5 - at.x) / float(p["rx"]), (float(t.y) + 0.5 - at.y) / float(p["ry"])).length()
		if d >= from and d <= to:
			out.append(t)
	return out


func _strew(names: Array, n: int, list: Array, taken: Array, apart: float) -> void:
	for i in n:
		var t := _take(list, taken, apart, far)
		if t.x < 0:
			continue
		var name := str(names[far.randi() % names.size()])
		if name.begins_with("boulder") or name.begins_with("barrel"):
			_thing(name, t, 4 + far.randi() % 9, 9 + far.randi() % 5)
		else:
			_thing(name, t, 8, 11)


## The Slinger Roost (the Game Bible: "Goblin camp in a rocky hollow; slingers throw from behind boulders and rubble
## barricades"): boulders and rubble round the hollow, its middle left clear (Pip's cage hangs there), and a few
## more down the canyon either side.
func _dress_roost(p: Dictionary, spots: Dictionary, taken: Array) -> void:
	var hollow := _band(spots["roomy"], p, 0.5, 1.05)
	var canyon := _band(spots["roomy"], p, 1.3, 9.0)
	_strew(["boulder_0", "boulder_1", "boulder_2", "boulder_3", "boulder_4", "boulder_5"], 5, hollow, taken, 2.6)
	_strew(["rubble"], 3, hollow, taken, 2.2)
	_strew(["barrel"], 1, hollow, taken, 2.2)
	_strew(["bones"], 1, hollow, taken, 2.2)
	_strew(["boulder_0", "boulder_1", "boulder_2", "boulder_3", "boulder_4", "boulder_5"], 4, canyon, taken, 4.0)
	_strew(["rubble"], 2, canyon, taken, 3.0)


## The Hound Den ("a hollow ringed by rock"): gnawed bones all over it and a couple of boulders at its edge.
func _dress_den(p: Dictionary, spots: Dictionary, taken: Array) -> void:
	_strew(["boulder_0", "boulder_2", "boulder_4"], 2, _band(spots["roomy"], p, 0.6, 1.2), taken, 3.2)
	_strew(["bones"], 6, spots["roomy"], taken, 2.4)


## Cairn Field ("open, flat ground" with cairns across it): eight cairns and two of the keepers' standing stones.
func _dress_cairns(p: Dictionary, spots: Dictionary, taken: Array) -> void:
	_strew(["cairn_0", "cairn_1"], 8, _band(spots["roomy"], p, 0.0, 0.95), taken, 3.4)
	_strew(["stone_0", "stone_1"], 2, _band(spots["roomy"], p, 0.5, 1.1), taken, 3.4)


## Echo Gorge ("a gorge with rims on both sides"): the keepers marked it. A post at each end and a cairn in between.
func _dress_gorge(p: Dictionary, spots: Dictionary, taken: Array) -> void:
	var at: Vector2 = p["at"]
	var d: Vector2 = p["glen_dir"]
	for end in [-0.8, 0.8]:
		var want: Vector2 = at + d * float(end)
		var best := Vector2i(-1, -1)
		var best_d := 6.0
		for t: Vector2i in spots["roomy"]:
			var far_off := (Vector2(t) + Vector2(0.5, 0.5)).distance_to(want)
			if far_off < best_d:
				best_d = far_off
				best = t
		if best.x >= 0:
			_thing("post", best, 8, 11)
			taken.append(best)
	_strew(["cairn_0", "cairn_1"], 1, _band(spots["roomy"], p, 0.0, 2.0), taken, 3.0)
	_strew(["rubble"], 2, spots["roomy"], taken, 4.0)


## The Fault's mouth: fallen stone where the crack leaves the open ground.
func _dress_fault(_p: Dictionary, spots: Dictionary, taken: Array) -> void:
	_strew(["rubble"], 3, spots["roomy"], taken, 2.2)
	_strew(["bones"], 1, spots["roomy"], taken, 2.2)
	_strew(["boulder_1", "boulder_3"], 1, spots["roomy"], taken, 3.0)


## The ground in front of the Scrapyard gate: goblin litter to either side, and the way to the gate left clear.
func _dress_forecourt(p: Dictionary, spots: Dictionary, taken: Array) -> void:
	var gate_x := int(m.sites["scrapyard"]["gate"].x)
	var sides: Array = []
	for t: Vector2i in spots["roomy"]:
		if absi(t.x - gate_x) >= 3 and absf(float(t.y) + 0.5 - p["at"].y) < float(p["ry"]) + 1.0:
			sides.append(t)
	_strew(["barrel"], 2, sides, taken, 2.6)
	_strew(["rubble"], 3, sides, taken, 2.2)
	_strew(["bones"], 2, sides, taken, 2.2)


## What an open place shows of the named place it is near: one or two things, in most of them.
func _tell(p: Dictionary, spots: Dictionary, taken: Array, marks: Array) -> void:
	var at: Vector2 = p["at"]
	var near := ""
	var near_d := TELL
	for mark in marks:
		var d := at.distance_to(mark[1])
		if str(mark[0]) == "scrapyard" and yard.size.x > 0:
			# (The Scrapyard is a block, not a spot: what counts is how near its walls are.)
			var wall := Vector2(clampf(at.x, yard.position.x, yard.end.x), clampf(at.y, yard.position.y, yard.end.y))
			d = minf(d, at.distance_to(wall) + 6.0)
		if d < near_d:
			near_d = d
			near = str(mark[0])
	if near == "" or far.randf() > 0.7:
		return
	var what: Array = {"roost": ["rubble", "bones", "barrel"], "den": ["bones"], "cairns": ["cairn_0", "cairn_1"], "gorge": ["post", "cairn_0"],
		"fault": ["rubble"], "scrapyard": ["rubble", "barrel", "bones"]}[near]
	_strew(what, 1 + far.randi() % 2, spots["roomy"], taken, 3.0)


# --- The middle and outer rings ---------------------------------------------------------
#
# Everything from here on rolls the far dice (`far`), never the inner ring's (`rng`).

## Where a ring ends in the direction a, in tiles from the cave. The line wobbles in and out, so a belt of rock is
## never a ruled circle.
func _line(ring: int, a: float) -> float:
	var s := int(fposmod(a, TAU) / TAU * 720.0) % 720
	if ring == 1:
		return line1[s]
	if ring == 2:
		return line2[s]
	if ring == 3:
		return line3[s]
	return 0.0


func _lines_make() -> void:
	for s in 720:
		var a := float(s) * TAU / 720.0
		var x := cos(a) * 30.0 + 100.0
		var y := sin(a) * 30.0 + 100.0
		line1.append(_ring_limit(a) + 9.0)
		line2.append(float(RINGS[2]) + (_noise(x, y, 12.0, 32) - 0.5) * 12.0)
		line3.append(float(RINGS[3]) - 6.0 + (_noise(x, y, 12.0, 33) - 0.5) * 8.0)


## Notes a place in the squares, so that the next ones can be measured against it quickly. Its number in the lists is
## its number among the open places: every place is noted, in order.
func _register(at: Vector2, reach: float, extra: float) -> void:
	var key := floori(at.y / CELL) * 64 + floori(at.x / CELL)
	if not cells.has(key):
		cells[key] = []
	(cells[key] as Array).append(p_at.size())
	p_at.append(at)
	p_reach.append(reach)
	p_extra.append(extra)


func _add_place(p: Dictionary, ring: int, extra := 0.0) -> int:
	for pair in [["sealed", false], ["gate", false], ["site", ""], ["glen", false], ["lobes", []]]:
		if not p.has(pair[0]):
			p[pair[0]] = pair[1]
	p["ring"] = ring
	if not p.has("reach"):
		p["reach"] = maxf(float(p["rx"]), float(p["ry"]))
	m.pockets.append(p)
	_register(p["at"], float(p["reach"]), extra)
	return m.pockets.size() - 1


func _add_site(name: String, p: Dictionary, ring: int) -> void:
	p["site"] = name
	var idx := _add_place(p, ring, 6.0)
	m.sites[name] = {"at": p["at"], "pocket": idx}


## Is a place that reaches `reach` tiles from `at` too near one that is already there? Far enough apart that rock
## always stands between two places, however big they are.
func _crowded(at: Vector2, reach: float, spacing: float) -> bool:
	var cx := floori(at.x / CELL)
	var cy := floori(at.y / CELL)
	for j in range(cy - 1, cy + 2):
		for i in range(cx - 1, cx + 2):
			var key := j * 64 + i
			if not cells.has(key):
				continue
			for k: int in cells[key]:
				if at.distance_to(p_at[k]) < maxf(spacing + p_extra[k], reach + p_reach[k] + 4.5):
					return true
	return false


## Is it too near the Scrapyard's block, or the Fault's crack?
func _near_keep(at: Vector2, reach: float) -> bool:
	if yard.size.x > 0:
		var wall := Vector2(clampf(at.x, yard.position.x, yard.end.x), clampf(at.y, yard.position.y, yard.end.y))
		if at.distance_to(wall) < reach + 8.0:
			return true
	if fault.size() == 2:
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, fault[0], fault[1])) < reach + 12.0:
			return true
	return false


func _hits_box(a: Vector2, b: Vector2, box: Rect2) -> bool:
	if box.has_point(a) or box.has_point(b):
		return true
	var c0 := box.position
	var c1 := Vector2(box.end.x, box.position.y)
	var c2 := box.end
	var c3 := Vector2(box.position.x, box.end.y)
	return Geometry2D.segment_intersects_segment(a, b, c0, c1) != null or Geometry2D.segment_intersects_segment(a, b, c1, c2) != null \
			or Geometry2D.segment_intersects_segment(a, b, c2, c3) != null or Geometry2D.segment_intersects_segment(a, b, c3, c0) != null


## True if a straight way from a to b keeps clear of the Scrapyard's block (which is come to from below, and from
## nowhere else) and does not cut across the Fault or open its cavern.
func _clear_of_keeps(a: Vector2, b: Vector2) -> bool:
	if yard.size.x > 0:
		if _hits_box(a, b, Rect2(yard.position.x - 8.0, yard.position.y - 8.0, yard.size.x + 16.0, yard.size.y + 9.0)):
			return false
	if fault.size() == 2:
		var f0: Vector2 = fault[0]
		var f1: Vector2 = fault[1]
		var along := (f1 - f0).normalized()
		var c0 := f0 + along * 8.0
		var c1 := f1 + along * 10.0
		if Geometry2D.segment_intersects_segment(a, b, c0, c1) != null:
			return false
		# A way bends and sways as it goes, by a third of its length at the very most: it must stay that far off the
		# crack all along (but for the ways that leave the Fault's own mouth).
		if a.distance_to(f0) > 1.0 and b.distance_to(f0) > 1.0:
			var room := 6.0 + a.distance_to(b) * 0.2
			if Geometry2D.get_closest_point_to_segment(a, c0, c1).distance_to(a) < room or Geometry2D.get_closest_point_to_segment(b, c0, c1).distance_to(b) < room \
					or Geometry2D.get_closest_point_to_segment(c0, a, b).distance_to(c0) < room or Geometry2D.get_closest_point_to_segment(c1, a, b).distance_to(c1) < room:
				return false
		if Geometry2D.get_closest_point_to_segment(f1, a, b).distance_to(f1) < 14.0:
			return false
	return true


## The named places of the middle and outer rings, each in its band and sector (the seed turns the compass, as it
## does for the Quarry).
func _far_sites() -> void:
	var centre := Vector2(MID + 0.5, MID + 0.5)
	_lines_make()
	for p in m.pockets:
		_register(p["at"], float(p.get("reach", p["rx"])), 5.0 if str(p["site"]) != "" else 0.0)
	# Rattlecrown's Scrapyard, far to the east: a block of rock that nothing here opens, with the ground in front of
	# its gate below it (the gate is in its south wall, and its rooms stand one above the other behind it). It goes
	# as near to 300 tiles out as the block allows: the whole block must be in the outer ring and on the map.
	var sa := m.turn + far.randf_range(-0.10, 0.10)
	var u := Vector2(cos(sa), sin(sa))
	var out := -1.0
	var most := MID + REACH - 4
	var least := MID - (REACH - 4)
	for step in 70:
		var rf := 236.0 + float(step) * 2.0
		var f := centre + u * rf
		var block := Rect2i(floori(f.x) - SCRAPYARD.x / 2, floori(f.y) - FORECOURT - SCRAPYARD.y, SCRAPYARD.x, SCRAPYARD.y)
		if block.position.x < least or block.end.x > most or block.position.y < least or floori(f.y) + 9 > most:
			continue
		var wall := Vector2(clampf(centre.x, block.position.x, block.end.x), clampf(centre.y, block.position.y, block.end.y))
		if wall.distance_to(centre) < SCRAPYARD_FROM:
			continue
		if out < 0.0 or absf(rf - 300.0) < absf(out - 300.0):
			out = rf
	if out < 0.0:
		out = 300.0             # (there is always room; this is for form)
	var front := centre + u * out
	var fx := floori(front.x)
	var fy := floori(front.y)
	yard = Rect2i(fx - SCRAPYARD.x / 2, fy - FORECOURT - SCRAPYARD.y, SCRAPYARD.x, SCRAPYARD.y)
	yl_x0 = yard.position.x - 2
	yl_x1 = yard.end.x + 2
	yl_y0 = yard.position.y - 2
	yl_y1 = yard.end.y + 2
	m.keeps.append(yard)
	_add_site("scrapyard", {"at": Vector2(fx + 0.5, fy + 0.5), "rx": 7.6, "ry": 4.6, "reach": 8.5}, 3)
	m.sites["scrapyard"]["rect"] = yard
	m.sites["scrapyard"]["gate"] = Vector2i(fx, yard.end.y - 1)
	# The middle ring's four.
	for row in [["roost", 0.0], ["den", PI * 0.5], ["cairns", -PI * 0.75], ["gorge", -PI * 0.25]]:
		var name := str(row[0])
		var p := {}
		match name:
			"roost":
				# A hollow in a canyon (the research: "a canyon at least 6 tiles wide and 30 long"), lying across the screen.
				var ca := far.randf_range(-0.55, 0.55)
				p = {"rx": 6.8, "ry": 5.0, "reach": 16.0,
					"arms": {"dir": Vector2(cos(ca), sin(ca)) * 15.0, "bend": far.randf_range(-3.0, 3.0), "rx": 3.3, "ry": 2.9}}
			"den":
				# A hollow ringed by rock, with a couple of bays.
				var lobes: Array = []
				for i in 2:
					var la := far.randf() * TAU
					lobes.append([Vector2(cos(la) * 6.0, sin(la) * 4.5), far.randf_range(2.6, 3.4), far.randf_range(2.0, 2.6)])
				p = {"rx": 8.0, "ry": 6.0, "reach": 9.5, "lobes": lobes}
			"cairns":
				p = {"rx": 10.0, "ry": 7.6, "reach": 10.5}
			"gorge":
				# A long gorge, running up the screen more than across it.
				var ga := PI * 0.5 + far.randf_range(-0.4, 0.4)
				p = {"rx": 3.4, "ry": 3.0, "reach": 15.6, "glen": true, "glen_dir": Vector2(cos(ga), sin(ga)) * 17.0, "glen_bend": far.randf_range(-4.0, 4.0)}
		var reach := float(p["reach"])
		var at := centre
		for t in 40:
			var a := m.turn + float(row[1]) + far.randf_range(-0.22, 0.22)
			var r := far.randf_range(165.0, 200.0)
			at = centre + Vector2(cos(a), sin(a)) * r
			if r - reach >= _line(1, a) + BELT and r + reach <= _line(2, a) - BELT and not _crowded(at, reach, 40.0) and not _near_keep(at, reach):
				break
		p["at"] = at
		_add_site(name, p, 2)
	# The Fault, in the outer ring to the south-east: its mouth, and the cavern at its far end, which starts sealed.
	var a0 := m.turn + PI * 0.25 - FAULT_SPAN
	var a1 := m.turn + PI * 0.25 + FAULT_SPAN
	if far.randf() < 0.5:
		var swap := a0
		a0 = a1
		a1 = swap
	var mouth := centre + Vector2(cos(a0), sin(a0)) * FAULT_AT
	var cavern := centre + Vector2(cos(a1), sin(a1)) * FAULT_AT
	_add_site("fault", {"at": mouth, "rx": 4.6, "ry": 3.6, "reach": 5.5}, 3)
	var end := _add_place({"at": cavern, "rx": 6.0, "ry": 4.4, "reach": 7.0, "sealed": true, "cavern": true}, 3, 6.0)
	m.sites["fault"]["end"] = end
	m.sites["fault"]["line"] = [mouth, cavern]
	fault = [mouth, cavern]


## The open places of one ring: spots are tried one after another, and one is kept if it lies wholly in the ring's
## band, clear of the belts of rock on either side of it, and far enough from every place there already.
func _scatter_far(ring: int) -> void:
	var centre := Vector2(MID + 0.5, MID + 0.5)
	var rule: Dictionary = RING[ring]
	var spacing := float(rule["spacing"])
	var r0 := float(RINGS[ring - 1]) + 2.0
	var r1 := float(RINGS[ring]) + 6.0
	var rim := BELT if ring < 3 else 0.0
	var size: Array = rule["size"]
	var glen_len: Array = rule["glen_len"]
	var big := 0
	var misses := 0
	for t in int(rule["trials"]):
		misses += 1
		if misses > int(rule["full"]):
			break
		var a := far.randf() * TAU
		var r := sqrt(far.randf() * (r1 * r1 - r0 * r0) + r0 * r0)
		var lo := _line(ring - 1, a) + BELT
		var hi := _line(ring, a) - rim
		if r - 3.0 < lo or r + 3.0 > hi:
			continue
		var at := centre + Vector2(cos(a), sin(a)) * r
		if _crowded(at, 3.0, spacing):
			continue
		var kind := far.randf()
		var rx := far.randf_range(float(size[0]), float(size[1]))
		var ry := far.randf_range(float(size[0]) - 1.2, float(size[1]) - 1.8)
		if kind < float(rule["nook"]):
			rx = far.randf_range(3.0, 4.2)
			ry = far.randf_range(2.5, 3.3)
		elif kind > 0.86 and big < int(rule["big"]):
			rx = far.randf_range(8.0, 10.0)
			ry = far.randf_range(5.4, 7.0)
		var p := {"at": at, "rx": rx, "ry": ry, "reach": maxf(rx, ry)}
		var glen := far.randf() < float(rule["glen"])
		if glen:
			var length := far.randf_range(float(glen_len[0]), float(glen_len[1]))
			var ga := far.randf() * PI
			var broad := kind > 0.6 and big < int(rule["big"])      # a few glens are broad
			p["glen"] = true
			p["glen_dir"] = Vector2(cos(ga), sin(ga)) * length
			p["glen_bend"] = far.randf_range(-0.36, 0.36) * length
			p["rx"] = 4.0 if broad else 3.0
			p["ry"] = 3.4 if broad else 2.6
			p["reach"] = length * 0.8 + 2.0
		else:
			var lobes: Array = []
			for i in far.randi() % 3:
				var la := far.randf() * TAU
				lobes.append([Vector2(cos(la) * rx * 0.75, sin(la) * ry * 0.75), far.randf_range(2.2, 3.4), far.randf_range(1.8, 2.6)])
			p["lobes"] = lobes
		var reach := float(p["reach"])
		if r - reach < lo or r + reach > hi or _crowded(at, reach, spacing) or _near_keep(at, reach):
			continue
		_add_place(p, ring)
		misses = 0
		if float(p["rx"]) >= 8.0 or (glen and float(p["rx"]) > 3.4):
			big += 1


## Notes a way in every square its line passes through.
func _edge_note(a: int, b: int) -> void:
	var p := p_at[a]
	var q := p_at[b]
	for j in range(floori(minf(p.y, q.y) / CELL), floori(maxf(p.y, q.y) / CELL) + 1):
		for i in range(floori(minf(p.x, q.x) / CELL), floori(maxf(p.x, q.x) / CELL) + 1):
			var key := j * 64 + i
			if not edge_at.has(key):
				edge_at[key] = []
			(edge_at[key] as Array).append([a, b])


## True if a straight line between places i and j would cut across a way that is already there.
func _crosses_far(i: int, j: int) -> bool:
	var a := p_at[i]
	var b := p_at[j]
	for cy in range(floori(minf(a.y, b.y) / CELL), floori(maxf(a.y, b.y) / CELL) + 1):
		for cx in range(floori(minf(a.x, b.x) / CELL), floori(maxf(a.x, b.x) / CELL) + 1):
			var key := cy * 64 + cx
			if not edge_at.has(key):
				continue
			for e: Array in edge_at[key]:
				var p: int = e[0]
				var q: int = e[1]
				if p == i or p == j or q == i or q == j:
					continue
				if Geometry2D.segment_intersects_segment(a, b, p_at[p], p_at[q]) != null:
					return true
	return false


## A place has joined the others: every place near it that is still outside looks whether it is now nearer to them.
## A way from one ring into the next counts three times its length, so the rings are joined in few places.
func _far_relax(i: int, state: PackedByteArray, ring: PackedByteArray, best: PackedFloat64Array, from: PackedInt32Array, front: Array) -> void:
	var a := p_at[i]
	var cx := floori(a.x / CELL)
	var cy := floori(a.y / CELL)
	for j in range(cy - 2, cy + 3):
		for ii in range(cx - 2, cx + 3):
			var key := j * 64 + ii
			if not cells.has(key):
				continue
			for k: int in cells[key]:
				if state[k] != 0 or absi(ring[k] - ring[i]) > 1:
					continue
				var b := p_at[k]
				var d := a.distance_to(b) * (3.0 if ring[k] != ring[i] else 1.0)
				if d < best[k] and _clear_of_keeps(a, b):
					if best[k] == INF:
						front.append(k)
					best[k] = d
					from[k] = i


## The ways of the middle and outer rings. Every place is joined to the nearest one already joined, starting from
## the inner ring; then some dead ends are sealed for the pickaxe; then each belt of rock gets its passes, spread
## round the cave; then a few more ways make loops.
func _far_links() -> void:
	var n := m.pockets.size()
	var state := PackedByteArray()       # 0 waiting, 1 joined, 2 never joined (sealed, or the Fault's cavern)
	var ring := PackedByteArray()
	var best := PackedFloat64Array()
	var from := PackedInt32Array()
	var degree := PackedInt32Array()
	for i in n:
		var p: Dictionary = m.pockets[i]
		ring.append(int(p["ring"]))
		best.append(INF)
		from.append(-1)
		degree.append(0)
		if i < inner_n:
			state.append(2 if bool(p["sealed"]) else 1)
		else:
			state.append(2 if p.has("cavern") else 0)
	var joined := {}
	for l in m.links:
		_edge_note(int(l["a"]), int(l["b"]))
		joined[int(l["a"]) * 4096 + int(l["b"])] = true
		joined[int(l["b"]) * 4096 + int(l["a"])] = true
	var front: Array = []
	for i in inner_n:
		if state[i] == 1:
			_far_relax(i, state, ring, best, from, front)
	var edges: Array = []
	while not front.is_empty():
		var at := 0
		for f in range(1, front.size()):
			if best[front[f]] < best[front[at]]:
				at = f
		var pick: int = front[at]
		front[at] = front[front.size() - 1]
		front.pop_back()
		state[pick] = 1
		edges.append([from[pick], pick])
		degree[from[pick]] += 1
		degree[pick] += 1
		_far_relax(pick, state, ring, best, from, front)
	# The ground in front of the Scrapyard gate must be joined whatever lies round it: to the nearest place a clear
	# line can be drawn to.
	var court := int(m.sites["scrapyard"]["pocket"])
	if state[court] == 0:
		var near := -1
		for k in n:
			if state[k] == 1 and ring[k] >= 2 and _clear_of_keeps(p_at[court], p_at[k]):
				if near < 0 or p_at[court].distance_to(p_at[k]) < p_at[court].distance_to(p_at[near]):
					near = k
		if near >= 0:
			state[court] = 1
			edges.append([near, court])
			degree[near] += 1
			degree[court] += 1
	var dbg := [edges.size(), 0, 0]
	# Dead ends lose their way in, more of them farther out. A place nothing could be joined to is sealed as well.
	for r in [2, 3]:
		var leaves: Array = []
		var count := 0
		for i in range(inner_n, n):
			if ring[i] == r:
				count += 1
		for e in edges:
			var j: int = e[1]
			if ring[j] == r and degree[j] == 1 and str(m.pockets[j]["site"]) == "":
				leaves.append(e)
		for s in mini(int(round(float(count) * float(RING[r]["seal"]))), leaves.size()):
			var k := far.randi() % leaves.size()
			var e: Array = leaves[k]
			leaves.remove_at(k)
			edges.erase(e)
			degree[int(e[0])] -= 1
			degree[int(e[1])] -= 1
			state[int(e[1])] = 2
			m.pockets[int(e[1])]["sealed"] = true
			dbg[1] += 1
	for i in range(inner_n, n):
		if state[i] == 0:
			state[i] = 2
			m.pockets[i]["sealed"] = true
	for e in edges:
		_edge_note(int(e[0]), int(e[1]))
		joined[int(e[0]) * 4096 + int(e[1])] = true
		joined[int(e[1]) * 4096 + int(e[0])] = true
	# The passes: each belt is cut into as many slices as it has passes, and a slice with no way through it yet gets
	# one, between the two places nearest each other across the belt.
	var centre := Vector2(MID + 0.5, MID + 0.5)
	for belt in [1, 2]:
		var slices := int(PASSES[belt])
		var turn := far.randf() * TAU
		var has: Array = []
		var near_d: Array = []
		var near_e: Array = []
		for s in slices:
			has.append(false)
			near_d.append(INF)
			near_e.append([])
		for e in edges:
			var a: int = e[0]
			var b: int = e[1]
			if mini(ring[a], ring[b]) == belt and maxi(ring[a], ring[b]) == belt + 1:
				var mid := (p_at[a] + p_at[b]) * 0.5 - centre
				has[int(fposmod(mid.angle() - turn, TAU) / TAU * float(slices)) % slices] = true
		for j in range(inner_n, n):
			if ring[j] != belt + 1 or state[j] != 1 or j == court:
				continue
			var b := p_at[j]
			var cx := floori(b.x / CELL)
			var cy := floori(b.y / CELL)
			for yy in range(cy - 2, cy + 3):
				for xx in range(cx - 2, cx + 3):
					var key := yy * 64 + xx
					if not cells.has(key):
						continue
					for i: int in cells[key]:
						if ring[i] != belt or state[i] != 1:
							continue
						var a := p_at[i]
						var d := a.distance_to(b)
						var mid := (a + b) * 0.5 - centre
						var s := int(fposmod(mid.angle() - turn, TAU) / TAU * float(slices)) % slices
						if has[s] or d >= float(near_d[s]):
							continue
						if not _clear_of_keeps(a, b) or (i < inner_n and not _clear_of_base(a, b)) or _crosses_far(i, j):
							continue
						near_d[s] = d
						near_e[s] = [i, j]
		for s in slices:
			if not has[s] and not (near_e[s] as Array).is_empty():
				var e: Array = near_e[s]
				if _crosses_far(int(e[0]), int(e[1])):
					continue        # (a pass cut a moment ago lies across it)
				edges.append(e)
				dbg[2] += 1
				_edge_note(int(e[0]), int(e[1]))
				joined[int(e[0]) * 4096 + int(e[1])] = true
				joined[int(e[1]) * 4096 + int(e[0])] = true
	# A few more ways between near neighbours of the same ring, so the land has loops and not only dead ends.
	for i in range(inner_n, n):
		if state[i] != 1 or i == court:
			continue
		var a := p_at[i]
		var reach := float(RING[ring[i]]["spacing"]) * 1.45
		var cx := floori(a.x / CELL)
		var cy := floori(a.y / CELL)
		for yy in range(cy - 1, cy + 2):
			for xx in range(cx - 1, cx + 2):
				var key := yy * 64 + xx
				if not cells.has(key):
					continue
				for j: int in cells[key]:
					if j <= i or state[j] != 1 or ring[j] != ring[i] or j == court or joined.has(i * 4096 + j):
						continue
					var b := p_at[j]
					if a.distance_to(b) >= reach:
						continue
					if far.randf() < 0.30 and _clear_of_keeps(a, b) and not _crosses_far(i, j):
						edges.append([i, j])
						_edge_note(i, j)
						joined[i * 4096 + j] = true
						joined[j * 4096 + i] = true
	if OS.has_environment("HL_TIMES"):
		print("  far ways: %d in the tree, %d sealed, %d passes, %d loops" % [dbg[0], dbg[1], dbg[2], edges.size() - dbg[0] + dbg[1] - dbg[2]])
	for e in edges:
		var a: int = e[0]
		var b: int = e[1]
		_cut_way(a, b, far, float(RING[maxi(ring[a], ring[b])]["tunnel"]), ring[a] != ring[b], a == court or b == court)


## The ground of the Fault and of the Scrapyard's front.
func _far_site_ground() -> void:
	# The Fault: a crack two tiles wide and nearly straight from its mouth to the cavern, its floor all broken stone,
	# with two falls of rock lying across it. The first shuts the crack; the second shuts the cavern. Both are plain
	# rock, for the pickaxe.
	var middle := _corridor(fault[0], fault[1], 2, 0.03, SCREE, 0, 1.4, far)
	var falls: Array = []
	for share in [0.4, 0.9]:
		var c: Vector2i = middle[int(float(middle.size() - 1) * float(share))]
		falls.append(c)
		for j in range(-3, 4):
			for i in range(-3, 4):
				if i * i + j * j <= 6 and not _locked(c.x + i, c.y + j):
					K[(c.y + j) * S + c.x + i] = ROCK
	m.sites["fault"]["falls"] = falls
	# The Scrapyard: a trodden track from the foot of its wall, under the gate, to the middle of the ground in front.
	var gate: Vector2i = m.sites["scrapyard"]["gate"]
	for y in range(yard.end.y, floori(m.sites["scrapyard"]["at"].y) + 1):
		var i := y * S + gate.x
		if K[i] == GRASS:
			K[i] = YARD
			laid[i] = true
