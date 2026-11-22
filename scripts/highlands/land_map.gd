extends RefCounted
## One Greystone Highlands world, as tiles: what every tile is made of, and the
## things that stand on it. scripts/highlands/world_gen.gd makes one from a seed;
## land_painter.gd draws it; land_view.gd shows the part near the camera.
##
## Nothing in here is random. The same seed always gives the same map, and once
## saving is built the whole of this is what a world save holds.
##
## Places are in tiles (16 art pixels, 32 world units) from the map's top left
## corner, or in art pixels where it says so. The cave mouth stands at the middle.

const SIZE := 768            # tiles a side: room for the whole Highlands (about 350 tiles out, plus the edge)
const MID := 384             # the tile of the cave mouth
const CHUNK := 16            # tiles a side of one painted piece of land
const TILE_PX := 16
const Veins := preload("res://scripts/highlands/veins.gd")

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
var veins: Array = []

## What has changed since the map was made, for the world save: tiles that were dug or mined (tile index -> what it
## is now), things that were taken away (thing_key -> true) and things that were put there (a felled pine's stump).
var dug := {}
var gone := {}
var added: Array = []

var _things_by_chunk := {}
var _decals_by_chunk := {}
var _plants_by_chunk := {}
var _lamps_by_chunk := {}
var _veins_by_chunk := {}
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
	_plants_by_chunk.clear()
	_lamps_by_chunk.clear()
	for pair in [[things, _things_by_chunk], [decals, _decals_by_chunk], [lamps, _lamps_by_chunk], [plants, _plants_by_chunk]]:
		for it in pair[0]:
			var key := chunk_key(int(it["x"]) / (CHUNK * TILE_PX), int(it["y"]) / (CHUNK * TILE_PX))
			if not pair[1].has(key):
				pair[1][key] = []
			pair[1][key].append(it)
	index_veins()
	_indexed = true


## Finds every cluster of ore tiles and the seams that run through it. A cluster is tiles of one ore that touch,
## corners included; its seams come from the tiles and the seed alone (veins.gd), so they are the same every time.
func index_veins() -> void:
	var found: Array = []
	var by_chunk := {}
	var seen := {}
	for pair in [[TIN, Veins.TIN], [COPPER, Veins.COPPER]]:
		var k: int = pair[0]
		var i := kinds.find(k)
		while i >= 0:
			var start := Vector2i(i % SIZE, i / SIZE)
			if not seen.has(start) and start.x >= 1 and start.y >= 1:
				var cells: Array = []
				var stack: Array = [start]
				seen[start] = true
				while not stack.is_empty():
					var at: Vector2i = stack.pop_back()
					cells.append(at)
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							var to := at + Vector2i(dx, dy)
							if to.x >= 1 and to.y >= 1 and not seen.has(to) and kind(to.x, to.y) == k:
								seen[to] = true
								stack.append(to)
				var seams := Veins.paths(cells, int(pair[1]), seed_value)
				var px: Dictionary = seams["px"]
				if not px.is_empty():
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
					found.append({"kind": int(pair[1]), "cells": cells, "px": px, "pockets": seams["pockets"], "box": box, "set": cell_set, "own": own})
					var side := CHUNK * TILE_PX
					for cy in range(lo.y / side, hi.y / side + 1):
						for cx in range(lo.x / side, hi.x / side + 1):
							var key := chunk_key(cx, cy)
							if not by_chunk.has(key):
								by_chunk[key] = []
							by_chunk[key].append(found.size() - 1)
			i = kinds.find(k, i + 1)
	veins = found
	_veins_by_chunk = by_chunk


## The ore clusters with a seam pixel in chunk (cx, cy), tin before copper, each in reading order.
func veins_in(cx: int, cy: int) -> Array:
	var out: Array = []
	var all := veins
	for n: int in _veins_by_chunk.get(chunk_key(cx, cy), []):
		if n < all.size():
			out.append(all[n])
	return out


func things_in(cx: int, cy: int) -> Array:
	return _things_by_chunk.get(chunk_key(cx, cy), [])


func plants_in(cx: int, cy: int) -> Array:
	return _plants_by_chunk.get(chunk_key(cx, cy), [])


func decals_in(cx: int, cy: int) -> Array:
	return _decals_by_chunk.get(chunk_key(cx, cy), [])


func lamps_in(cx: int, cy: int) -> Array:
	return _lamps_by_chunk.get(chunk_key(cx, cy), [])


## Every tile somebody could walk to from `from` without digging, as a byte per
## tile of the region (1 = reached). Used by the generator's checks and the tests.
func reach(from: Vector2i) -> PackedByteArray:
	var w := region.size.x
	var h := region.size.y
	var seen := PackedByteArray()
	seen.resize(w * h)
	if not region.has_point(from) or not walkable(from.x, from.y):
		return seen
	var stack := PackedInt32Array([(from.y - region.position.y) * w + (from.x - region.position.x)])
	seen[stack[0]] = 1
	while not stack.is_empty():
		var at := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var x := at % w
		var y := at / w
		for d in 4:
			var nx := x + (1 if d == 0 else (-1 if d == 1 else 0))
			var ny := y + (1 if d == 2 else (-1 if d == 3 else 0))
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var n := ny * w + nx
			if seen[n] == 0 and walkable(nx + region.position.x, ny + region.position.y):
				seen[n] = 1
				stack.append(n)
	return seen


func reached(seen: PackedByteArray, x: int, y: int) -> bool:
	if not region.has_point(Vector2i(x, y)):
		return false
	return seen[(y - region.position.y) * region.size.x + (x - region.position.x)] == 1


## How much of the land between two distances from the cave is open, 0 to 1.
func open_share(r0: float, r1: float) -> float:
	var open := 0
	var all := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var d := Vector2(x - MID, y - MID).length()
			if d < r0 or d > r1:
				continue
			all += 1
			if not is_rock(x, y):
				open += 1
	return float(open) / float(maxi(all, 1))
