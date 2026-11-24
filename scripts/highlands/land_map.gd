extends RefCounted
## One Greystone Highlands world, as tiles: what every tile is made of, and the
## things that stand on it. scripts/highlands/world_gen.gd makes one from a seed;
## land_painter.gd draws it; land_view.gd shows the part near the camera.
##
## Nothing in here is random. The same seed always gives the same map, so a world
## save holds the seed and what was changed since (changes(), apply_changes()),
## never the land itself.
##
## Places are in tiles (16 art pixels, 32 world units) from the map's top left
## corner, or in art pixels where it says so. The cave mouth stands at the middle.

const SIZE := 768            # tiles a side: room for the whole Highlands (about 350 tiles out, plus the edge)
const MID := 384             # the tile of the cave mouth
const CHUNK := 16            # tiles a side of one painted piece of land
const TILE_PX := 16
const Veins := preload("res://scripts/highlands/veins.gd")
const ADDABLE := ["pine_stump"]   # what can be put on the land after it is made (a world save may hold nothing else)

## What a tile is made of.
enum { GRASS, SCRUB, HEATH, PATH, YARD, WATER, ROCK, TIN, COPPER, FLOOR, SCREE }
const NAMES := ["grass", "scrub", "heather", "footpath", "yard", "water", "rock", "tin", "copper", "dug floor", "scree"]

var seed_value := 0
var tries := 1                   # how many layouts the generator went through before one passed its checks
var kinds := PackedByteArray()   # SIZE x SIZE
var tones := PackedByteArray()   # 0 = a hollow (darker, long grass), 1 = plain, 2 = a rise (lighter, grazed short)
var things: Array = []           # what stands on the land: [{n: name in the kit, x, y: its foot in art pixels, f: flipped}]
var plants: Array = []           # the heather and scrub bushes, each one its own plant that never overlaps another: [{n, x, y}] (foot, art pixels)
var decals: Array = []           # flat pieces painted into the ground (scraps of the keepers' road): [{n, x, y}]
var floor_decals: Array = []     # pictures painted into dug floor (the Throne Room's paving, version 50): [{sheet, rect, shade, x, y}] (x, y: the top left, art pixels; no wider or deeper than a chunk)
var lamps: Array = []            # lantern light on dug floor: [{x, y, r}] in art pixels
var animals: Array = []          # [{kind, x, y, f}]
var pockets: Array = []          # the open places: [{at: Vector2 (tiles), rx, ry, sealed, gate, site, glen}]
var links: Array = []            # the ways between them: [{a, b, tunnel}]
var sites := {}                  # named places kept for later versions: name -> {at: Vector2 (tiles), pocket}
var base := Rect2()              # the clearing outside the cave, in tiles
var base_at := Vector2.ZERO      # its middle
var base_r := Vector2.ZERO       # its half width and half height
var mouth := Vector2i(MID, MID)  # the rock tile the cave mouth is set into; its feet are at this tile's bottom edge
var spawn := Vector2.ZERO        # where players first stand, in tiles
var turn := 0.0                  # how far the seed turned the compass (radians)
var region := Rect2i()           # the part of the map that has anything but solid rock in it
## Ore, as the seams that run through the rock: one entry for every cluster of tin or copper tiles that touch (corners
## included): {kind: Veins.TIN or Veins.COPPER, cells: [Vector2i tiles], px: {Vector2i art pixel -> what it is},
## pockets: [Vector2i], box: Rect2i in art pixels, set: {tile -> true}, own: {art pixel outside the cluster's own
## tiles -> the tile of the cluster it belongs to}}. Worked out by index() from the ore tiles the map was MADE with
## and the seed, and never again: mining a tile takes that tile's own part of the seam away and leaves the rest of
## the seam exactly where it was (vein_shows()). A save holds the tiles that changed, never this.
##
## The clusters are found when the map is made (index_veins()), but the seams of one are only worked out when they
## are first asked for: by the painter, for the clusters near a piece of land it paints (veins_in()), or all of them
## at once by whoever reads this list. They come out the same either way, whenever it is done: a cluster's seams come
## from its tiles as the land was made, and the seed.
var veins: Array:
	get:
		if not _veins_whole:
			_veins_done = []
			for lump: Dictionary in _lumps:
				if not bool(lump["done"]):
					_lump_finish(lump)
				if lump["v"] != null:
					_veins_done.append(lump["v"])
			_veins_whole = true
		return _veins_done

## What has changed since the map was made, for the world save: tiles that were dug or mined (tile index -> what it
## is now), things that were taken away (thing_key -> true) and things that were put there (a felled pine's stump).
var dug := {}
var gone := {}
var added: Array = []

## Rock that is locked for good by something cut into the land after it was made (the Throne Room's walls,
## version 48): tiles inside any of these can never be dug. Rect2i, in tiles. Never saved: it is set again on
## every opening of the world.
var keeps: Array = []

var _things_by_chunk := {}
var _decals_by_chunk := {}
var _floor_decals_by_chunk := {}
var _plants_by_chunk := {}
var _lamps_by_chunk := {}
var _lumps: Array = []           # every cluster of ore tiles, tin before copper, each in reading order: {kind, cells, v: its entry in `veins` (null until worked out, or if it has no seam), done}
var _lumps_by_chunk := {}        # chunk -> [the numbers of the clusters whose seams could reach into it]
var _veins_done: Array = []
var _veins_whole := false
var _indexed := false


func _init() -> void:
	kinds.resize(SIZE * SIZE)
	kinds.fill(ROCK)
	tones.resize(SIZE * SIZE)
	tones.fill(1)


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < SIZE and y < SIZE


## Past the map's edge it is all rock.
func kind(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return ROCK
	return kinds[y * SIZE + x]


func set_kind(x: int, y: int, k: int) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		kinds[y * SIZE + x] = k


func tone(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return 1
	return tones[y * SIZE + x]


static func rocky(k: int) -> bool:
	return k == ROCK or k == TIN or k == COPPER


## Rock, or ore in it, is dug out: the tile becomes dug floor. Returns what it was (ROCK, TIN or COPPER), or -1 if
## there was nothing to dig. The change is remembered for the world save.
func dig(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return -1
	var was := kinds[y * SIZE + x]
	if not rocky(was):
		return -1
	kinds[y * SIZE + x] = FLOOR
	dug[y * SIZE + x] = FLOOR
	return was


## Rock that can never be dug: the hill the cave mouth is set into (the way down to the forge must stay), and the
## rim of the land that has been laid out so far (beyond it the next ring is not made yet).
func fixed(x: int, y: int) -> bool:
	if absi(x - mouth.x) <= 4 and y <= mouth.y and y >= mouth.y - 6:
		return true
	for k in keeps:
		if (k as Rect2i).has_point(Vector2i(x, y)):
			return true
	return x < region.position.x + 3 or y < region.position.y + 3 or x >= region.end.x - 3 or y >= region.end.y - 3


## One number for a thing, from where its foot is (no two things share a foot).
static func thing_key(t: Dictionary) -> int:
	return int(t["y"]) * 16384 + int(t["x"])


## A thing is taken off the land (a pine is felled, a boulder broken up).
func remove_thing(t: Dictionary) -> void:
	things.erase(t)
	var key := chunk_key(int(t["x"]) / (CHUNK * TILE_PX), int(t["y"]) / (CHUNK * TILE_PX))
	if _things_by_chunk.has(key):
		(_things_by_chunk[key] as Array).erase(t)
	if added.has(t):
		added.erase(t)
	else:
		gone[thing_key(t)] = true


## A thing is put on the land after the map was made (a stump where a pine stood).
func add_thing(t: Dictionary) -> void:
	things.append(t)
	added.append(t)
	var key := chunk_key(int(t["x"]) / (CHUNK * TILE_PX), int(t["y"]) / (CHUNK * TILE_PX))
	if not _things_by_chunk.has(key):
		_things_by_chunk[key] = []
	(_things_by_chunk[key] as Array).append(t)


## A thing that belongs to the land but is put there after it is made, on every opening of the world (the Throne
## Room's lanterns): it is not a change, so no save holds it.
func stamp_thing(t: Dictionary) -> void:
	things.append(t)
	var key := chunk_key(int(t["x"]) / (CHUNK * TILE_PX), int(t["y"]) / (CHUNK * TILE_PX))
	if not _things_by_chunk.has(key):
		_things_by_chunk[key] = []
	(_things_by_chunk[key] as Array).append(t)


## Lantern light put there the same way.
func stamp_lamp(l: Dictionary) -> void:
	lamps.append(l)
	var key := chunk_key(int(l["x"]) / (CHUNK * TILE_PX), int(l["y"]) / (CHUNK * TILE_PX))
	if not _lamps_by_chunk.has(key):
		_lamps_by_chunk[key] = []
	(_lamps_by_chunk[key] as Array).append(l)


## A picture painted into dug floor, put there the same way (CrownPlan.stamp).
func stamp_floor_decal(d: Dictionary) -> void:
	floor_decals.append(d)
	var key := chunk_key(int(d["x"]) / (CHUNK * TILE_PX), int(d["y"]) / (CHUNK * TILE_PX))
	if not _floor_decals_by_chunk.has(key):
		_floor_decals_by_chunk[key] = []
	(_floor_decals_by_chunk[key] as Array).append(d)


## What has changed on this land since it was made, as plain values for the world save: the tiles that were dug or
## mined, the things that were taken away and the things that were put there. Always in the same order, so the same
## land gives the same save.
func changes() -> Dictionary:
	var tiles: Array = dug.keys()
	tiles.sort()
	var taken: Array = gone.keys()
	taken.sort()
	var put: Array = []
	for t in added:
		put.append({"n": str(t["n"]), "x": int(t["x"]), "y": int(t["y"]), "f": bool(t.get("f", false))})
	return {"dug": tiles, "gone": taken, "added": put}


## Does to a newly made map what was done to it when it was saved. Call it once, after the map is made (the seams
## are already worked out from the ore the land was made with, so mined ore leaves the rest of its seam where it
## was). What does not fit this land (a tile that is not rock, a thing that is not there) is passed over; returns
## how many changes were passed over, which is 0 for a save of this same land.
func apply_changes(d) -> int:
	var odd := 0
	if not (d is Dictionary):
		return 0
	if d.get("dug") is Array:
		for v in d["dug"]:
			var i := int(v)
			if (v is int or v is float) and i >= 0 and i < SIZE * SIZE and rocky(kinds[i]) and not fixed(i % SIZE, i / SIZE):
				kinds[i] = FLOOR
				dug[i] = FLOOR
			else:
				odd += 1
	if d.get("gone") is Array and not (d["gone"] as Array).is_empty():
		var by_key := {}
		for t in things:
			by_key[thing_key(t)] = t
		for v in d["gone"]:
			if (v is int or v is float) and by_key.has(int(v)):
				remove_thing(by_key[int(v)])
			else:
				odd += 1
	if d.get("added") is Array:
		for t in d["added"]:
			if t is Dictionary and t.get("n") is String and str(t["n"]) in ADDABLE and (t.get("x") is int or t.get("x") is float) and (t.get("y") is int or t.get("y") is float) \
					and inside(int(t["x"]) / TILE_PX, int(t["y"]) / TILE_PX):
				add_thing({"n": str(t["n"]), "x": int(t["x"]), "y": int(t["y"]), "f": bool(t.get("f", false))})
			else:
				odd += 1
	return odd


## Is this pixel of a seam still there? It is while the ore tile it belongs to has not been mined: its own tile if
## that is one of the cluster's, else the cluster's tile nearest to it (a seam strays a few pixels into plain rock).
func vein_shows(v: Dictionary, p: Vector2i) -> bool:
	var t := Vector2i(p.x >> 4, p.y >> 4)
	if not (v["set"] as Dictionary).has(t):
		t = (v["own"] as Dictionary).get(p, t)
	var k := kind(t.x, t.y)
	return k == TIN or k == COPPER


func is_rock(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return true
	var k := kinds[y * SIZE + x]
	return k == ROCK or k == TIN or k == COPPER


## Can somebody stand here? Rock and water stop you.
func walkable(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return false
	var k := kinds[y * SIZE + x]
	return k != ROCK and k != TIN and k != COPPER and k != WATER


static func chunk_key(cx: int, cy: int) -> int:
	return cy * 1024 + cx


## Sorts everything that stands on the land by the chunk its foot is in, so the
## painter and the view can ask for one chunk's worth.
func index() -> void:
	_things_by_chunk.clear()
	_decals_by_chunk.clear()
	_floor_decals_by_chunk.clear()
	_plants_by_chunk.clear()
	_lamps_by_chunk.clear()
	for pair in [[things, _things_by_chunk], [decals, _decals_by_chunk], [floor_decals, _floor_decals_by_chunk], [lamps, _lamps_by_chunk], [plants, _plants_by_chunk]]:
		for it in pair[0]:
			var key := chunk_key(int(it["x"]) / (CHUNK * TILE_PX), int(it["y"]) / (CHUNK * TILE_PX))
			if not pair[1].has(key):
				pair[1][key] = []
			pair[1][key].append(it)
	index_veins()
	_indexed = true


## Finds every cluster of ore tiles. A cluster is tiles of one ore that touch, corners included. Its seams come from
## the tiles and the seed alone (veins.gd), so they are the same every time; they are worked out when first asked for
## (_lump_finish()). No pixel of a seam lies more than 12 pixels outside its cluster's own tiles (veins.gd), which is
## how a cluster knows which pieces of land its seams could reach.
const SEAM_STRAY := 12

func index_veins() -> void:
	_lumps = []
	_lumps_by_chunk = {}
	_veins_done = []
	_veins_whole = false
	var seen := {}
	var side := CHUNK * TILE_PX
	for pair in [[TIN, Veins.TIN], [COPPER, Veins.COPPER]]:
		var k: int = pair[0]
		var i := kinds.find(k)
		while i >= 0:
			var start := Vector2i(i % SIZE, i / SIZE)
			if not seen.has(start) and start.x >= 1 and start.y >= 1:
				var cells: Array = []
				var stack: Array = [start]
				seen[start] = true
				var lo := start
				var hi := start
				while not stack.is_empty():
					var at: Vector2i = stack.pop_back()
					cells.append(at)
					lo = lo.min(at)
					hi = hi.max(at)
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							var to := at + Vector2i(dx, dy)
							if to.x >= 1 and to.y >= 1 and not seen.has(to) and kind(to.x, to.y) == k:
								seen[to] = true
								stack.append(to)
				_lumps.append({"kind": int(pair[1]), "cells": cells, "v": null, "done": false})
				for cy in range(maxi(lo.y * TILE_PX - SEAM_STRAY, 0) / side, (hi.y * TILE_PX + TILE_PX - 1 + SEAM_STRAY) / side + 1):
					for cx in range(maxi(lo.x * TILE_PX - SEAM_STRAY, 0) / side, (hi.x * TILE_PX + TILE_PX - 1 + SEAM_STRAY) / side + 1):
						var key := chunk_key(cx, cy)
						if not _lumps_by_chunk.has(key):
							_lumps_by_chunk[key] = []
						_lumps_by_chunk[key].append(_lumps.size() - 1)
			i = kinds.find(k, i + 1)


## Works out one cluster's seams: where its metal is, pixel by pixel.
func _lump_finish(lump: Dictionary) -> void:
	lump["done"] = true
	var cells: Array = lump["cells"]
	var seams := Veins.paths(cells, int(lump["kind"]), seed_value)
	var px: Dictionary = seams["px"]
	if px.is_empty():
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-1, -1)
	for p: Vector2i in px:
		lo = lo.min(p)
		hi = hi.max(p)
	var box := Rect2i(lo, hi - lo + Vector2i.ONE)
	# Which of the cluster's tiles each pixel belongs to: its own, or for a pixel that strays into plain
	# rock, the nearest (the first of them in the cluster's order, if two are as near).
	var cell_set := {}
	for c: Vector2i in cells:
		cell_set[c] = true
	var own := {}
	for p: Vector2i in px:
		if cell_set.has(Vector2i(p.x >> 4, p.y >> 4)):
			continue
		var best := Vector2i.ZERO
		var best_d := 1 << 30
		for c: Vector2i in cells:
			var ddx := maxi(maxi(c.x * TILE_PX - p.x, p.x - (c.x * TILE_PX + TILE_PX - 1)), 0)
			var ddy := maxi(maxi(c.y * TILE_PX - p.y, p.y - (c.y * TILE_PX + TILE_PX - 1)), 0)
			if ddx * ddx + ddy * ddy < best_d:
				best_d = ddx * ddx + ddy * ddy
				best = c
		own[p] = best
	lump["v"] = {"kind": int(lump["kind"]), "cells": cells, "px": px, "pockets": seams["pockets"], "box": box, "set": cell_set, "own": own}


## The ore clusters with a seam pixel in chunk (cx, cy), tin before copper, each in reading order.
func veins_in(cx: int, cy: int) -> Array:
	var out: Array = []
	var side := CHUNK * TILE_PX
	for n: int in _lumps_by_chunk.get(chunk_key(cx, cy), []):
		var lump: Dictionary = _lumps[n]
		if not bool(lump["done"]):
			_lump_finish(lump)
		if lump["v"] == null:
			continue
		var box: Rect2i = lump["v"]["box"]
		if cx >= box.position.x / side and cx <= (box.end.x - 1) / side and cy >= box.position.y / side and cy <= (box.end.y - 1) / side:
			out.append(lump["v"])
	return out


func things_in(cx: int, cy: int) -> Array:
	return _things_by_chunk.get(chunk_key(cx, cy), [])


func plants_in(cx: int, cy: int) -> Array:
	return _plants_by_chunk.get(chunk_key(cx, cy), [])


func decals_in(cx: int, cy: int) -> Array:
	return _decals_by_chunk.get(chunk_key(cx, cy), [])


func floor_decals_in(cx: int, cy: int) -> Array:
	return _floor_decals_by_chunk.get(chunk_key(cx, cy), [])


func lamps_in(cx: int, cy: int) -> Array:
	return _lamps_by_chunk.get(chunk_key(cx, cy), [])


## Every tile somebody could walk to from `from` without digging, as a byte per
## tile of the region (1 = reached). Used by the generator's checks and the tests.
##
## It goes a run of tiles at a time: from a tile it marks the whole stretch of walkable ground to its left and right,
## then looks along the rows above and below that stretch for ground it has not been to.
func reach(from: Vector2i) -> PackedByteArray:
	var w := region.size.x
	var h := region.size.y
	var seen := PackedByteArray()
	seen.resize(w * h)
	if not region.has_point(from) or not walkable(from.x, from.y):
		return seen
	var k := kinds
	var x0 := region.position.x
	var y0 := region.position.y
	var stack := PackedInt32Array([(from.y - y0) * w + (from.x - x0)])
	var top := 1
	while top > 0:
		top -= 1
		var at := stack[top]
		if seen[at] == 1:
			continue
		var y := at / w
		var x := at - y * w
		var row_s := y * w
		var row_k := (y + y0) * SIZE + x0
		var l := x
		while l > 0:
			var kk := k[row_k + l - 1]
			if (kk >= WATER and kk <= COPPER) or seen[row_s + l - 1] == 1:
				break
			l -= 1
		var r := x
		while r < w - 1:
			var kk := k[row_k + r + 1]
			if (kk >= WATER and kk <= COPPER) or seen[row_s + r + 1] == 1:
				break
			r += 1
		for i in range(row_s + l, row_s + r + 1):
			seen[i] = 1
		for dy in [-1, 1]:
			var ny: int = y + dy
			if ny < 0 or ny >= h:
				continue
			var n_s := ny * w
			var n_k := (ny + y0) * SIZE + x0
			var in_run := false
			for i in range(l, r + 1):
				var kk := k[n_k + i]
				if (kk >= WATER and kk <= COPPER) or seen[n_s + i] == 1:
					in_run = false
				elif not in_run:
					in_run = true
					if top < stack.size():
						stack[top] = n_s + i
					else:
						stack.append(n_s + i)
					top += 1
	return seen


func reached(seen: PackedByteArray, x: int, y: int) -> bool:
	if not region.has_point(Vector2i(x, y)):
		return false
	return seen[(y - region.position.y) * region.size.x + (x - region.position.x)] == 1


## How much of the land between two distances from the cave is open, 0 to 1.
func open_share(r0: float, r1: float) -> float:
	var open := 0
	var all := 0
	var lo := r0 * r0
	var hi := r1 * r1
	var far := ceili(r1)
	var k := kinds
	for y in range(maxi(region.position.y, maxi(MID - far, 0)), mini(region.end.y, mini(MID + far + 1, SIZE))):
		var dy := (y - MID) * (y - MID)
		var row := y * SIZE
		for x in range(maxi(region.position.x, maxi(MID - far, 0)), mini(region.end.x, mini(MID + far + 1, SIZE))):
			var d2 := float((x - MID) * (x - MID) + dy)
			if d2 < lo or d2 > hi:
				continue
			all += 1
			var kk := k[row + x]
			if kk != ROCK and kk != TIN and kk != COPPER:
				open += 1
	return float(open) / float(maxi(all, 1))
