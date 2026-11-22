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
##   - Rings round the cave: the base hills to about 24 tiles, the inner ring to
##     about 90. This version builds those two; the rest is solid rock for now.
##   - Named places sit in their band and sector, and the seed turns the compass.
##     The Old Quarry and the Keeper's Watchpost get their ground kept here; what
##     is in them comes in later versions.
##   - Every open place can be walked to from the cave without digging, except a
##     few that are sealed on purpose for the pickaxe to find.
##   - Things are spread thin (Darren: "don't clutter it").
##
## The numbers are first guesses to tune in play, not decisions.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")

const MID := LandMap.MID
const REACH := 104             # this version works within this many tiles of the cave
const RING_INNER := 84.0       # how far out the inner ring's open places go (it wobbles a little)
const SPACING := 18.0          # tiles between the middles of two open places
const HILL_KEEP := 9.0         # nothing but the gaps comes this close to the clearing's edge

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

var m: LandMap
var rng := RandomNumberGenerator.new()
var ore := RandomNumberGenerator.new()    # the ore's own dice (see _ore)
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


func _build(seed_value: int, attempt: int) -> LandMap:
	m = LandMap.new()
	m.seed_value = seed_value
	m.region = Rect2i(MID - REACH, MID - REACH, REACH * 2, REACH * 2)
	rng.seed = _mix(seed_value & 0xffffffff, seed_value >> 32, 1000 + attempt)
	ore.seed = _mix(seed_value & 0xffffffff, seed_value >> 32, 2000 + attempt)
	ns = rng.randi() & 0xffff
	m.turn = rng.randf() * TAU
	var t := [Time.get_ticks_usec()]
	_base()
	_sites()
	_scatter_pockets()
	for p in m.pockets:
		_carve_pocket(p)
	t.append(Time.get_ticks_usec())
	_links()
	_site_ground()
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
	_cover_plants()
	t.append(Time.get_ticks_usec())
	if not _check():
		return null
	m.index()
	if OS.has_environment("HL_TIMES"):
		var out := []
		for i in range(1, t.size()):
			out.append((t[i] - t[i - 1]) / 1000)
		print("  carve, links, tidy, check, outcrops+water, tone, ore, dress (ms): ", out)
	return m


# --- Carving -------------------------------------------------------------------------

## Rock that must stay: the hill the cave mouth is set into, and the map's rim.
func _locked(x: int, y: int) -> bool:
	if absi(x - MID) > REACH - 3 or absi(y - MID) > REACH - 3:
		return true
	return absi(x - MID) <= 4 and y <= MID and y >= MID - 6


func _open(x: int, y: int, k := GRASS) -> void:
	if not _locked(x, y) and m.is_rock(x, y):
		m.set_kind(x, y, k)


func _blob(c: Vector2, rx: float, ry: float, wob: float, k := GRASS) -> void:
	for y in range(floori(c.y - ry - 2.0), ceili(c.y + ry + 2.0) + 1):
		for x in range(floori(c.x - rx - 2.0), ceili(c.x + rx + 2.0) + 1):
			var dx := (float(x) + 0.5 - c.x) / rx
			var dy := (float(y) + 0.5 - c.y) / ry
			if dx * dx + dy * dy <= 1.0 + (_noise(x, y, 3.5, 11) - 0.5) * wob:
				_open(x, y, k)


## A way through the rock from a to b, bending as it goes. `width` is how many
## tiles wide it is at its narrowest. A natural gap (`spread` above 0) opens out
## to as much as `width + spread` here and there and never keeps one width for
## long, and it sways from side to side by up to `sway` tiles, so no two ways
## look alike and none is a ruled line. Returns the tiles down its middle, each
## one beside the last (never corner to corner), for a footpath or a yard track.
func _corridor(a: Vector2, b: Vector2, width: int, wander: float, k := GRASS, spread := 0, sway := 0.0) -> Array:
	ways += 1
	var d := b - a
	var length := maxf(d.length(), 1.0)
	var side := Vector2(-d.y, d.x) / length
	var c1 := a + d * 0.33 + side * rng.randf_range(-1.0, 1.0) * length * wander
	var c2 := a + d * 0.66 + side * rng.randf_range(-1.0, 1.0) * length * wander
	var middle: Array = []
	var last := Vector2i(-99999, 0)
	var steps := int(ceil(length * 3.0))
	var row := float(ways) * 13.7
	sway = minf(sway, length * 0.16)
	for s in steps + 1:
		var t := float(s) / float(steps)
		var p := a.bezier_interpolate(c1, c2, b, t)
		var u := t * length
		if sway > 0.0:
			# Long bends and short ones together; it comes back to its line at each end.
			var ends := minf(1.0, minf(u, length - u) / 3.5)
			p += side * ends * ((_noise(u, row, 6.5, 61) - 0.5) * 2.0 * sway + (_noise(u, row, 2.8, 62) - 0.5) * 1.5)
		var w := width
		if spread > 0:
			w = clampi(width + int(round((_noise(u, row, 5.5, 63) - 0.38) * float(spread) * 1.9)), width, width + spread)
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
		for i in width:
			if width >= 4 and (float(i) - c) * (float(i) - c) + (float(j) - c) * (float(j) - c) > r2:
				continue
			_open(at.x + lo + i, at.y + lo + j, k)


## Lays a footpath (or a yard track) down the middle of a way, on grass only.
func _lay(middle: Array, k: int) -> void:
	for at in middle:
		if m.kind(at.x, at.y) == GRASS:
			m.set_kind(at.x, at.y, k)


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
		else:
			_lay(middle, PATH)


# --- Places kept for later versions ------------------------------------------------

func _sites() -> void:
	var centre := Vector2(MID + 0.5, MID + 0.5)
	# The Old Quarry is "west" in the plan, 40 to 85 tiles out. The seed turns the compass.
	var qa := m.turn + PI + rng.randf_range(-0.3, 0.3)
	var q := centre + Vector2(cos(qa), sin(qa)) * rng.randf_range(52.0, 72.0)
	# The Keeper's Watchpost is 55 to 85 out, at the ring's edge if it can be, and never on a screen with the Quarry.
	var w := q
	for t in 60:
		var wa := rng.randf() * TAU
		w = centre + Vector2(cos(wa), sin(wa)) * rng.randf_range(64.0, 78.0)
		if w.distance_to(q) >= 46.0 and w.distance_to(m.base_at) >= 40.0:
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
	return RING_INNER + (_noise(cos(a) * 30.0 + 100.0, sin(a) * 30.0 + 100.0, 12.0, 31) - 0.5) * 10.0


func _scatter_pockets() -> void:
	var centre := Vector2(MID + 0.5, MID + 0.5)
	for t in 5000:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf() * (RING_INNER * RING_INNER - 32.0 * 32.0) + 32.0 * 32.0)
		var glen := rng.randf() < 0.12
		var rx := rng.randf_range(4.6, 7.0)
		var ry := rng.randf_range(3.4, 5.2)
		# Sizes differ a good deal: about a quarter are small nooks, and a few (never more than four) are big, 16 to 20 tiles across.
		var size := rng.randf()
		var u1 := rng.randf()
		var u2 := rng.randf()
		var big := 0
		for p in m.pockets:
			if float(p["rx"]) >= 8.0 or (bool(p["glen"]) and float(p["rx"]) > 3.4):
				big += 1
		if size < 0.26:
			rx = lerpf(3.0, 4.2, u1)
			ry = lerpf(2.5, 3.3, u2)
		elif size > 0.86 and big < 4:
			rx = lerpf(8.0, 10.0, u1)
			ry = lerpf(5.4, 7.0, u2)
		var lobes: Array = []
		for i in rng.randi() % 3:
			var la := rng.randf() * TAU
			lobes.append([Vector2(cos(la) * rx * 0.75, sin(la) * ry * 0.75), rng.randf_range(2.2, 3.4), rng.randf_range(1.8, 2.6)])
		var glen_a := rng.randf() * PI
		var glen_len := rng.randf_range(8.0, 10.0)
		var glen_bend := rng.randf_range(-3.5, 3.5)
		var glen_wide := size > 0.6 and big < 4      # a few glens are broad: 16 to 20 tiles long and 8 or so across
		var reach := maxf(rx, ry) if not glen else glen_len * 0.8 + 2.0
		if r > _ring_limit(a) - 7.0:
			continue
		var at := centre + Vector2(cos(a), sin(a)) * r
		if at.distance_to(m.base_at) < 31.0:
			continue
		var ok := true
		for p in m.pockets:
			# Far enough apart that rock always stands between two places, however big they are.
			if at.distance_to(p["at"]) < maxf(SPACING + 5.0 if str(p["site"]) != "" else SPACING, reach + float(p.get("reach", p["rx"])) + 4.5):
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


## True if a straight way from a to b keeps clear of the base's hills.
func _clear_of_base(a: Vector2, b: Vector2) -> bool:
	var near := Geometry2D.get_closest_point_to_segment(m.base_at, a, b)
	return near.distance_to(m.base_at) >= m.base_r.x + HILL_KEEP


func _links() -> void:
	var n := m.pockets.size()
	var in_tree: Array = []
	var best: Array = []
	var from: Array = []
	var degree: Array = []
	for i in n:
		in_tree.append(bool(m.pockets[i]["gate"]))
		best.append(INF)
		from.append(-1)
		degree.append(1 if bool(m.pockets[i]["gate"]) else 0)
	var edges: Array = []
	var relax := func(i: int) -> void:
		for j in n:
			if in_tree[j]:
				continue
			var a: Vector2 = m.pockets[i]["at"]
			var b: Vector2 = m.pockets[j]["at"]
			var d := a.distance_to(b)
			if d < float(best[j]) and _clear_of_base(a, b):
				best[j] = d
				from[j] = i
	for i in n:
		if in_tree[i]:
			relax.call(i)
	# Join every place to the nearest one already joined, so all of them hang together.
	while true:
		var pick := -1
		for j in n:
			if not in_tree[j] and float(best[j]) < INF and (pick < 0 or float(best[j]) < float(best[pick])):
				pick = j
		if pick < 0:
			break
		in_tree[pick] = true
		edges.append([int(from[pick]), pick])
		degree[int(from[pick])] += 1
		degree[pick] += 1
		relax.call(pick)
	# About one in ten is sealed off: a dead end loses its way in, for the pickaxe to find.
	var leaves: Array = []
	for e in edges:
		var j: int = e[1]
		if int(degree[j]) == 1 and str(m.pockets[j]["site"]) == "":
			leaves.append(e)
	var seal := mini(int(round(float(n) * 0.10)), leaves.size())
	for s in seal:
		var k := rng.randi() % leaves.size()
		var e: Array = leaves[k]
		leaves.remove_at(k)
		edges.erase(e)
		m.pockets[int(e[1])]["sealed"] = true
	for i in n:
		if not in_tree[i]:
			m.pockets[i]["sealed"] = true
	# A few more ways between near neighbours, so the map has loops and not only dead ends.
	for i in n:
		for j in range(i + 1, n):
			if bool(m.pockets[i]["sealed"]) or bool(m.pockets[j]["sealed"]) or edges.has([i, j]) or edges.has([j, i]):
				continue
			var a: Vector2 = m.pockets[i]["at"]
			var b: Vector2 = m.pockets[j]["at"]
			if a.distance_to(b) < SPACING * 1.45 and _clear_of_base(a, b) and rng.randf() < 0.30 and not _crosses(i, j, edges):
				edges.append([i, j])
	for e in edges:
		var pa: Dictionary = m.pockets[int(e[0])]
		var pb: Dictionary = m.pockets[int(e[1])]
		var a: Vector2 = pa["at"]
		var b: Vector2 = pb["at"]
		var plain := str(pa["site"]) == "" and str(pb["site"]) == ""
		var tunnel := plain and a.distance_to(b) < 34.0 and rng.randf() < 0.15
		var width := 2 if rng.randf() < 0.6 else 3
		var footpath := rng.randf() < 0.65
		var sway := rng.randf_range(2.0, 4.2)
		if tunnel:
			# An old dug tunnel: two wide and nearly straight (it was cut on purpose), with a floor of cut rock and lanterns along it.
			tunnels.append(_corridor(a, b, 2, 0.05, FLOOR, 0, 0.8))
		else:
			# A natural gap: it sways, and is anything from two to six tiles wide along its length.
			var middle := _corridor(a, b, width, 0.24, GRASS, 6 - width, sway)
			for at in middle:
				if rng.randf() < 0.06:
					_blob(Vector2(at) + Vector2(rng.randf_range(-0.5, 1.5), rng.randf_range(-0.5, 1.5)), rng.randf_range(1.5, 2.5), rng.randf_range(1.3, 2.0), 0.4)
			if footpath:
				_lay(middle, PATH)
		m.links.append({"a": int(e[0]), "b": int(e[1]), "tunnel": tunnel})


## True if a straight line between places i and j would cut across a way that is already there.
func _crosses(i: int, j: int, edges: Array) -> bool:
	var a: Vector2 = m.pockets[i]["at"]
	var b: Vector2 = m.pockets[j]["at"]
	for e in edges:
		var p: int = e[0]
		var q: int = e[1]
		if p == i or p == j or q == i or q == j:
			continue
		if Geometry2D.segment_intersects_segment(a, b, m.pockets[p]["at"], m.pockets[q]["at"]) != null:
			return true
	return false


## No wall of rock is left one tile thick, and no single tile of rock stands alone:
## rock is in lumps you can dig into.
func _tidy() -> void:
	for pass_i in 6:
		var changed := 0
		for y in range(m.region.position.y + 2, m.region.end.y - 2):
			for x in range(m.region.position.x + 2, m.region.end.x - 2):
				if not m.is_rock(x, y) or _locked(x, y):
					continue
				var ns_open := not m.is_rock(x, y - 1) and not m.is_rock(x, y + 1)
				var ew_open := not m.is_rock(x - 1, y) and not m.is_rock(x + 1, y)
				if ns_open or ew_open:
					var k := GRASS
					for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						if m.kind(x + d.x, y + d.y) == FLOOR:
							k = FLOOR
					m.set_kind(x, y, k)
					changed += 1
		if changed == 0:
			break


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
## block, the tile that nothing else hangs on goes back to grass.
func _thin_paths() -> void:
	for pass_i in 3:
		var changed := 0
		for y in range(m.region.position.y + 2, m.region.end.y - 2):
			for x in range(m.region.position.x + 2, m.region.end.x - 2):
				var k := m.kind(x, y)
				if (k != PATH and k != YARD) or m.kind(x + 1, y) != k or m.kind(x, y + 1) != k or m.kind(x + 1, y + 1) != k:
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
## sealed ones cannot, and the share of open land is about a third.
func _check() -> bool:
	var seen := m.reach(Vector2i(floori(m.spawn.x), floori(m.spawn.y)))
	for p in m.pockets:
		var at := Vector2i(floori(p["at"].x), floori(p["at"].y))
		var got := m.reached(seen, at.x, at.y)
		if not got and m.walkable(at.x, at.y) == false and not bool(p["sealed"]):
			# Its very middle is taken (a rock, a tarn): look at the tiles round it.
			for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				if m.reached(seen, at.x + d.x, at.y + d.y):
					got = true
		if bool(p["sealed"]) and got:
			p["sealed"] = false        # another way happened to pass through it
		elif not bool(p["sealed"]) and not got:
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
	for j in range(-1, 2):
		for i in range(-1, 2):
			var k := m.kind(x + i, y + j)
			if k != GRASS and k != SCRUB and k != HEATH:
				return false
	return true


func _grassy(x: int, y: int) -> bool:
	var k := m.kind(x, y)
	return k == GRASS or k == SCRUB or k == HEATH


## The tiles of one open place, sorted into kinds of spot. Always in the same order.
func _spots(p: Dictionary) -> Dictionary:
	var out := {"roomy": [], "foot": [], "bank": [], "rim": [], "wide": []}
	var at: Vector2 = p["at"]
	var ex := float(p["rx"]) + (12.0 if bool(p["glen"]) else 4.0)
	var ey := float(p["ry"]) + (12.0 if bool(p["glen"]) else 4.0)
	for y in range(floori(at.y - ey), ceili(at.y + ey) + 1):
		for x in range(floori(at.x - ex), ceili(at.x + ex) + 1):
			if m.is_rock(x, y):
				if not _locked(x, y) and m.kind(x, y) == ROCK and (m.walkable(x, y + 1) or m.walkable(x, y - 1) or m.walkable(x - 1, y) or m.walkable(x + 1, y)):
					out["rim"].append(Vector2i(x, y))
				continue
			if not _grassy(x, y):
				continue
			if _roomy(x, y):
				out["roomy"].append(Vector2i(x, y))
				var wide := true
				for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2)]:
					if not _roomy(x + d.x, y + d.y):
						wide = false
				if wide:
					out["wide"].append(Vector2i(x, y))
			if m.is_rock(x, y - 1) and m.kind(x, y) == GRASS:
				out["foot"].append(Vector2i(x, y))
			if m.kind(x, y - 1) == WATER or m.kind(x - 1, y) == WATER or m.kind(x + 1, y) == WATER:
				out["bank"].append(Vector2i(x, y))
	return out


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
	for p in m.pockets:
		if bool(p["gate"]) or bool(p["glen"]) or str(p["site"]) != "" or float(p["rx"]) < 5.4 or rng.randf() > 0.30:
			continue
		var spots := _spots(p)
		if spots["wide"].is_empty():
			continue
		var at: Vector2i = spots["wide"][rng.randi() % spots["wide"].size()]
		var w := 2 + rng.randi() % 2
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
	for p in m.pockets:
		if bool(p["gate"]) or bool(p["glen"]) or str(p["site"]) != "" or float(p["rx"]) < 5.0 or rng.randf() > 0.18:
			continue
		var spots := _spots(p)
		if spots["wide"].is_empty():
			continue
		var at: Vector2i = spots["wide"][rng.randi() % spots["wide"].size()]
		var cells: Array = [at, at + Vector2i(1, 0)]
		if _roomy(at.x + 2, at.y) and rng.randf() < 0.6:
			cells.append(at + Vector2i(2, 0))
		for c in cells.duplicate():
			if rng.randf() < 0.7:
				cells.append(c + Vector2i(0, 1))
		var ok := true
		for c in cells:
			if not _roomy(c.x, c.y):
				ok = false
		if not ok:
			continue
		for c in cells:
			m.set_kind(c.x, c.y, WATER)
		p["tarn"] = true


func _tone_and_cover() -> void:
	# Hollows and rises: the grass a step darker or lighter in broad patches.
	for y in range(m.region.position.y, m.region.end.y):
		for x in range(m.region.position.x, m.region.end.x):
			if m.is_rock(x, y):
				continue
			# (Two sizes of noise together, so a patch has a ragged outline and never a square one.)
			var t := _noise(x, y, 8.0, 41) * 0.62 + _noise(x, y, 2.6, 43) * 0.38
			var tone := 0 if t < 0.40 else (2 if t > 0.58 else 1)
			if tone == 0:
				# A track must stay easy to see: no dark hollow on it or beside it.
				for j in range(-1, 2):
					for i in range(-1, 2):
						var k := m.kind(x + i, y + j)
						if k == YARD or k == PATH:
							tone = 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if m.kind(x + d.x, y + d.y) == WATER:
					tone = 0
			m.tones[y * LandMap.SIZE + x] = tone
	# Heather and sage scrub, each in one patch at least three tiles across, in under half the places.
	for p in m.pockets:
		if (bool(p["gate"]) and rng.randf() < 0.5) or str(p["site"]) != "":
			continue
		for pair in [[HEATH, 0.40], [SCRUB, 0.34]]:
			if rng.randf() > float(pair[1]):
				continue
			var at: Vector2 = p["at"]
			var a := rng.randf() * TAU
			var c := at + Vector2(cos(a) * float(p["rx"]) * 0.55, sin(a) * float(p["ry"]) * 0.55)
			var r := rng.randf_range(1.7, 2.7)
			for y in range(floori(c.y - r - 1.0), ceili(c.y + r + 1.0)):
				for x in range(floori(c.x - r - 1.0), ceili(c.x + r + 1.0)):
					var d := Vector2(float(x) + 0.5 - c.x, (float(y) + 0.5 - c.y) * 1.25).length()
					if d <= r + (_noise(x, y, 2.5, 57) - 0.5) * 1.2 and m.kind(x, y) == GRASS:
						m.set_kind(x, y, int(pair[0]))


## Scree: small stones lying at the foot of the rock in some stretches, never out
## in the open and never on a track. (Detail goes where there is a reason for it.)
func _scree() -> void:
	var keep_clear := m.base.grow(3.0)
	for y in range(m.region.position.y + 1, m.region.end.y - 1):
		for x in range(m.region.position.x + 1, m.region.end.x - 1):
			if m.kind(x, y) != GRASS or keep_clear.has_point(Vector2(x, y)):
				continue
			var n := _noise(x, y, 6.0, 71) * 0.7 + _noise(x, y, 2.4, 72) * 0.3
			var under := m.is_rock(x, y - 1)                                                # right under a face
			var beside := m.is_rock(x - 1, y) or m.is_rock(x + 1, y) or m.is_rock(x, y - 2) or m.is_rock(x - 1, y - 1) or m.is_rock(x + 1, y - 1)
			if (under and n > 0.60) or (beside and n > 0.68):
				m.set_kind(x, y, SCREE)


## Heather and scrub are plants, not paint: every bush stands on its own with
## ground showing all round it, thick in the middle of a patch and thinning to
## single plants at its edge. This is the art's own way of placing them (hl3.py,
## "scatter"): try a spot, and keep the plant only if it touches no other.
func _cover_plants() -> void:
	Painter.load_kit()
	var feet := {}                         # tile -> [feet of the things standing there]
	for t in m.things:
		var key := Vector2i(int(t["x"]) >> 4, int(t["y"]) >> 4)
		if not feet.has(key):
			feet[key] = []
		feet[key].append(Vector2i(int(t["x"]), int(t["y"])))
	var placed := {}                       # tile -> [Rect2i of each plant whose foot is there]
	for y in range(m.region.position.y + 1, m.region.end.y - 1):
		for x in range(m.region.position.x + 1, m.region.end.x - 1):
			var k := m.kind(x, y)
			if k != HEATH and k != SCRUB:
				continue
			var same := 0
			for j in range(-1, 2):
				for i in range(-1, 2):
					if m.kind(x + i, y + j) == k:
						same += 1
			var chance := clampf((float(same) / 9.0 - 0.28) / 0.36, 0.04, 1.0)
			for t in (26 if k == HEATH else 9):
				var px := x * 16 + rng.randi() % 16
				var py := y * 16 + rng.randi() % 16
				var name := ("heath_%d" if k == HEATH else "scrub_%d") % (rng.randi() % 12)
				if rng.randf() > chance:
					continue
				var box: Rect2i = Painter.boxes[name]
				var r := Rect2i(px + box.position.x, py + box.position.y, box.size.x, box.size.y)
				# All of it on grass, with room to spare: never against rock, water, a track or scree.
				var wide := r.grow(4)
				var ok := true
				for c in [wide.position, Vector2i(wide.end.x, wide.position.y), Vector2i(wide.position.x, wide.end.y), wide.end, Vector2i(px, py)]:
					if not _grassy(c.x >> 4, c.y >> 4):
						ok = false
				if not ok:
					continue
				# Never touching another plant (a pixel of ground between them at least), nor under a thing's feet.
				var mine := r.grow(1)
				for j in range(-2, 3):
					for i in range(-2, 3):
						var key := Vector2i(x + i, y + j)
						for other in placed.get(key, []):
							if mine.intersects(other):
								ok = false
						for f in feet.get(key, []):
							if absi(f.x - px) < 14 and f.y - py > -12 and f.y - py < 10:
								ok = false
				if not ok:
					continue
				var home := Vector2i(x, y)
				if not placed.has(home):
					placed[home] = []
				placed[home].append(r)
				m.plants.append({"n": name, "x": px, "y": py})


## Ore: a cluster of ore tiles that starts in rock you can see from open ground and runs into the hill. What shows
## of it is drawn as seams through the whole cluster (veins.gd): they come in at its top and run down, about one
## for every two and a half tiles of its width. So a cluster is wider than it is tall, at most 6 tiles by 4, and it
## keeps clear of any other cluster.
func _vein(start: Vector2i, n: int, k: int) -> int:
	if m.kind(start.x, start.y) != ROCK or _locked(start.x, start.y) or _ore_near(start, {}):
		return 0
	var cells: Array = [start]
	var own := {start: true}
	var box := Rect2i(start, Vector2i.ONE)
	m.set_kind(start.x, start.y, k)
	for t in n * 10:
		if cells.size() >= n:
			break
		var from: Vector2i = cells[ore.randi() % cells.size()]
		var d: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, -1), Vector2i(0, 1)][ore.randi() % 7]
		var at := from + d
		var grown := box.merge(Rect2i(at, Vector2i.ONE))
		if grown.size.x > 6 or grown.size.y > 4:
			continue
		if m.kind(at.x, at.y) == ROCK and not _locked(at.x, at.y) and not _ore_near(at, own):
			m.set_kind(at.x, at.y, k)
			cells.append(at)
			own[at] = true
			box = grown
	return cells.size()


## Is there ore within two tiles that is not part of this cluster?
func _ore_near(at: Vector2i, own: Dictionary) -> bool:
	for j in range(-2, 3):
		for i in range(-2, 3):
			var k := m.kind(at.x + i, at.y + j)
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
	# In the inner ring: on the edge of under half the open places, always in a sealed one, and a few deep in the rock.
	for p in m.pockets:
		if bool(p["gate"]):
			continue
		var veins := 2 if bool(p["sealed"]) else (1 if ore.randf() < 0.45 else 0)
		if veins == 0:
			continue
		var spots := _spots(p)
		var south: Array = spots["rim"].filter(func(at): return m.walkable(at.x, at.y + 1))
		var used: Array = []
		for v in veins:
			var at := Vector2i(-1, -1)
			if ore.randf() < 0.65:
				at = _take(south, used, 5.0, ore)
			if at.x < 0:
				at = _take(spots["rim"], used, 5.0, ore)
			if at.x >= 0:
				_vein(at, 4 + ore.randi() % 4, TIN if ore.randf() < 0.55 else COPPER)
	var deep := 0
	for t in 400:
		if deep >= 14:
			break
		var a := ore.randf() * TAU
		var r := ore.randf_range(30.0, RING_INNER)
		var at := Vector2i(MID + int(cos(a) * r), MID + int(sin(a) * r))
		var buried := true
		for j in range(-2, 3):
			for i in range(-2, 3):
				if m.kind(at.x + i, at.y + j) != ROCK:
					buried = false
		if buried and _vein(at, 5 + ore.randi() % 4, TIN if ore.randf() < 0.5 else COPPER) > 0:
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
	# The open places of the inner ring.
	for p in m.pockets:
		spots = _spots(p)
		taken = []
		var site := str(p["site"])
		if site == "watchpost":
			_dress_watchpost(p, spots, taken)
		elif site == "quarry":
			_dress_quarry(p, spots, taken)
		if site != "":
			continue              # a named place holds its own few things and no more
		if rng.randf() < 0.34:
			var back: Array = spots["roomy"].filter(func(at): return float(at.y) <= p["at"].y)
			for i in 1 + rng.randi() % 3:
				var at := _take(back, taken, 2.6)
				if at.x >= 0:
					_thing("pine_%d" % (rng.randi() % 6), at, 4 + rng.randi() % 9, 9 + rng.randi() % 5, rng.randf() < 0.5)
		if rng.randf() < 0.42:
			for i in 1 + rng.randi() % 2:
				var at := _take(spots["roomy"], taken, 3.2)
				if at.x >= 0:
					_thing("boulder_%d" % (rng.randi() % 6), at, 4 + rng.randi() % 9, 9 + rng.randi() % 5, rng.randf() < 0.5)
		if rng.randf() < 0.28:
			for i in 1 + rng.randi() % 2:
				var at := _take(spots["roomy"], taken, 3.2)
				if at.x >= 0:
					_thing("bush_%d" % (rng.randi() % 4), at, 4 + rng.randi() % 9, 9 + rng.randi() % 5, rng.randf() < 0.5)
		if rng.randf() < 0.55:
			for i in 2 + rng.randi() % 3:
				var at := _take(spots["foot"], taken, 2.0)
				if at.x >= 0:
					_thing("bracken_%d" % (rng.randi() % 4), at, 3 + rng.randi() % 10, 5 + rng.randi() % 3)
		var rare := rng.randf()
		var one := ""
		if rare < 0.07:
			one = "stone_%d" % (rng.randi() % 2)
		elif rare < 0.15:
			one = "cairn_%d" % (rng.randi() % 2)
		elif rare < 0.21:
			one = "stump"
		elif rare < 0.26:
			one = "bones"
		if one != "" and site == "":
			var at := _take(spots["roomy"], taken, 3.2)
			if at.x >= 0:
				_thing(one, at, 8, 11)
		if p.has("tarn"):
			var wet: Array = []
			for i in 2 + rng.randi() % 3:
				var at := _take(spots["bank"], wet, 1.0)
				if at.x >= 0:
					_thing("reeds_%d" % (rng.randi() % 4), at, 3 + rng.randi() % 10, 2 + rng.randi() % 3)
			for i in 1 + rng.randi() % 2:
				var at := _take(spots["bank"], wet, 1.0)
				if at.x >= 0:
					_thing("cotton_%d" % (rng.randi() % 3), at, 3 + rng.randi() % 10, 8 + rng.randi() % 5)
		# Life, in a few places only: cattle grazing, a hare, a pair of crows.
		if site == "" and not bool(p["gate"]):
			var life := rng.randf()
			if life < 0.12 and float(p["rx"]) >= 5.2:
				for i in 1 + rng.randi() % 3:
					var at := _take(spots["roomy"], taken, 2.4)
					if at.x >= 0:
						_animal("cow", at.x * 16 + 8, at.y * 16 + 11, rng.randf() < 0.5)
			elif life < 0.24:
				var at := _take(spots["roomy"], taken, 3.0)
				if at.x >= 0:
					_animal("hare", at.x * 16 + 8, at.y * 16 + 10, rng.randf() < 0.5)
			elif life < 0.40:
				var at := _take(spots["roomy"], taken, 3.0)
				if at.x >= 0:
					_animal("crow", at.x * 16 + 5, at.y * 16 + 9, false)
					_animal("crow", at.x * 16 + 19, at.y * 16 + 14, true)
					if rng.randf() < 0.4 and _roomy(at.x + 2, at.y):
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
