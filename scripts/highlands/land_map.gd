extends RefCounted
## One Greystone Highlands world, as tiles: what every tile is made of, and the
## things that stand on it. scripts/highlands/world_gen.gd makes one from a seed;
## land_painter.gd draws it; land_view.gd shows the part near the camera.
##
## Nothing in here is random. The same seed always gives the same map, and from
## version 36 the whole of this is what a world save holds.
##
## Places are in tiles (16 art pixels, 32 world units) from the map's top left
## corner, or in art pixels where it says so. The cave mouth stands at the middle.

const SIZE := 544            # tiles a side: room for the whole Highlands (about 250 tiles out, plus the edge)
const MID := 272             # the tile of the cave mouth
const CHUNK := 16            # tiles a side of one painted piece of land
const TILE_PX := 16

## What a tile is made of.
enum { GRASS, SCRUB, HEATH, PATH, YARD, WATER, ROCK, TIN, COPPER, FLOOR }
const NAMES := ["grass", "scrub", "heather", "footpath", "yard", "water", "rock", "tin", "copper", "dug floor"]

var seed_value := 0
var tries := 1                   # how many layouts the generator went through before one passed its checks
var kinds := PackedByteArray()   # SIZE x SIZE
var tones := PackedByteArray()   # 0 = a hollow (darker, long grass), 1 = plain, 2 = a rise (lighter, grazed short)
var things: Array = []           # what stands on the land: [{n: name in the kit, x, y: its foot in art pixels, f: flipped}]
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

var _things_by_chunk := {}
var _decals_by_chunk := {}
var _lamps_by_chunk := {}


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
	_lamps_by_chunk.clear()
	for pair in [[things, _things_by_chunk], [decals, _decals_by_chunk], [lamps, _lamps_by_chunk]]:
		for it in pair[0]:
			var key := chunk_key(int(it["x"]) / (CHUNK * TILE_PX), int(it["y"]) / (CHUNK * TILE_PX))
			if not pair[1].has(key):
				pair[1][key] = []
			pair[1][key].append(it)


func things_in(cx: int, cy: int) -> Array:
	return _things_by_chunk.get(chunk_key(cx, cy), [])


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
