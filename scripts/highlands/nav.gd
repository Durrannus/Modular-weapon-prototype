extends RefCounted
## The way round the rock, for the Highlands' enemies (version 43).
##
## The land is mostly rock with open places joined by narrow ways, so an enemy that walked straight at a player
## would stand against a wall. This keeps one grid of the whole land (a tile is either free or it is not) and
## answers three questions: the tiles to walk from here to there, whether a straight line between two places is
## free to walk, and whether one place can be seen from another (rock hides, water and boulders do not).
##
## A tile is not free if it is rock or water, or if something broad stands on it (a boulder, a bush, a cairn; and
## since version 44 a chest, which the loot tells it about with block()).
## When a tile is dug or a thing is broken the grid is told (tile_changed, thing_changed), and `stamp` goes up so
## that anybody walking an old way asks again.
##
## It asks for no random numbers and changes nothing: the same land gives the same answers.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")

const TILE := 32.0
const BROAD := 9                 # a thing at least this many art pixels across fills its tile

var map: LandMap
var grid := AStarGrid2D.new()
var region := Rect2i()
var stamp := 0
var made_ms := 0.0               # how long the grid took to make (the tests print it)
var covered := {}                # tile index -> how many broad things stand on it
var blocked := {}                # tile index -> true: something that is not one of the map's things stands there (a chest)


func setup(map_: LandMap) -> void:
	var t0 := Time.get_ticks_usec()
	map = map_
	region = map.region.grow(2).intersection(Rect2i(0, 0, LandMap.SIZE, LandMap.SIZE))
	grid.region = region
	grid.cell_size = Vector2(TILE, TILE)
	grid.offset = Vector2(TILE, TILE) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	# Runs of tiles that stop you, a row at a time (far fewer calls than one for every tile).
	var kinds := map.kinds
	for y in range(region.position.y, region.end.y):
		var x := region.position.x
		var row := y * LandMap.SIZE
		while x < region.end.x:
			var k := kinds[row + x]
			if k != LandMap.ROCK and k != LandMap.TIN and k != LandMap.COPPER and k != LandMap.WATER:
				x += 1
				continue
			var from := x
			while x < region.end.x:
				k = kinds[row + x]
				if k != LandMap.ROCK and k != LandMap.TIN and k != LandMap.COPPER and k != LandMap.WATER:
					break
				x += 1
			grid.fill_solid_region(Rect2i(from, y, x - from, 1), true)
	for t in map.things:
		_cover(t, 1)
	made_ms = float(Time.get_ticks_usec() - t0) / 1000.0


static func _broad(t: Dictionary) -> bool:
	var info: Dictionary = Painter.things.get(str(t.get("n", "")), {})
	return info.has("solid") and int(info["solid"][0]) >= BROAD


static func _tile_of_thing(t: Dictionary) -> Vector2i:
	return Vector2i(floori(float(t["x"]) / 16.0), floori((float(t["y"]) - 2.0) / 16.0))


func _cover(t: Dictionary, by: int) -> void:
	if not _broad(t):
		return
	var at := _tile_of_thing(t)
	if not region.has_point(at):
		return
	var key := at.y * LandMap.SIZE + at.x
	covered[key] = int(covered.get(key, 0)) + by
	if int(covered[key]) <= 0:
		covered.erase(key)
	grid.set_point_solid(at, covered.has(key) or blocked.has(key) or not map.walkable(at.x, at.y))


## Something that is not one of the map's things stands on this tile from now on (a chest): nobody walks through it.
func block(tile: Vector2i) -> void:
	if not region.has_point(tile):
		return
	blocked[tile.y * LandMap.SIZE + tile.x] = true
	grid.set_point_solid(tile, true)
	stamp += 1


## A tile was dug (or otherwise changed).
func tile_changed(tile: Vector2i) -> void:
	if not region.has_point(tile):
		return
	var key := tile.y * LandMap.SIZE + tile.x
	grid.set_point_solid(tile, covered.has(key) or blocked.has(key) or not map.walkable(tile.x, tile.y))
	stamp += 1


## The things on the land changed (a pine felled, a boulder broken): what stands where is counted again round there.
func things_changed(foot_px: Vector2) -> void:
	var c := Vector2i(floori(foot_px.x / 16.0), floori(foot_px.y / 16.0))
	for j in range(-2, 3):
		for i in range(-2, 3):
			var at := c + Vector2i(i, j)
			if region.has_point(at):
				covered.erase(at.y * LandMap.SIZE + at.x)
	var cx := floori(float(c.x) / LandMap.CHUNK)
	var cy := floori(float(c.y) / LandMap.CHUNK)
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for t in map.things_in(cx + di, cy + dj):
				var at := _tile_of_thing(t)
				if _broad(t) and absi(at.x - c.x) <= 2 and absi(at.y - c.y) <= 2 and region.has_point(at):
					var key := at.y * LandMap.SIZE + at.x
					covered[key] = int(covered.get(key, 0)) + 1
	for j in range(-2, 3):
		for i in range(-2, 3):
			var at := c + Vector2i(i, j)
			if region.has_point(at):
				var key := at.y * LandMap.SIZE + at.x
				grid.set_point_solid(at, covered.has(key) or blocked.has(key) or not map.walkable(at.x, at.y))
	stamp += 1


static func tile_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.y / TILE))


static func middle_of(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TILE


## Can somebody stand on this tile?
func is_free(tile: Vector2i) -> bool:
	return region.has_point(tile) and not grid.is_point_solid(tile)


## The free tile nearest to this one (itself, if it is free), looking a few tiles round. (-1, -1) if there is none.
func nearest_free(tile: Vector2i, far := 4) -> Vector2i:
	if is_free(tile):
		return tile
	for r in range(1, far + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for j in range(-r, r + 1):
			for i in range(-r, r + 1):
				if maxi(absi(i), absi(j)) != r:
					continue
				var at := tile + Vector2i(i, j)
				if is_free(at):
					var d := float(i * i + j * j)
					if d < best_d:
						best_d = d
						best = at
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## The way from one place to another, as the middles of the tiles to walk through (world units), the first being
## the tile you stand on. Empty if there is no way. If the far end cannot be stood on, the way goes as near as it can.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_free(tile_of(from))
	var b := nearest_free(tile_of(to))
	if a.x < 0 or b.x < 0:
		return PackedVector2Array()
	return grid.get_point_path(a, b, true)


## How many tiles the way from one place to another is (-1 if there is none).
func steps(from: Vector2, to: Vector2) -> int:
	var a := nearest_free(tile_of(from))
	var b := nearest_free(tile_of(to))
	if a.x < 0 or b.x < 0:
		return -1
	var p := grid.get_id_path(a, b, false)
	return p.size() - 1 if not p.is_empty() else -1


## Is the straight line between two places free to walk, for somebody about a tile wide?
func clear(from: Vector2, to: Vector2) -> bool:
	var d := to - from
	var n := maxi(ceili(d.length() / 12.0), 1)
	var side := d.normalized().orthogonal() * 9.0
	for i in range(1, n + 1):
		var at := from + d * (float(i) / float(n))
		if not is_free(tile_of(at)) or not is_free(tile_of(at + side)) or not is_free(tile_of(at - side)):
			return false
	return true


## Can one place be seen from the other? Rock hides; water, boulders and bushes do not.
func sees(from: Vector2, to: Vector2) -> bool:
	var d := to - from
	var n := maxi(ceili(d.length() / 14.0), 1)
	for i in range(1, n):
		var at := tile_of(from + d * (float(i) / float(n)))
		if map.is_rock(at.x, at.y):
			return false
	return true
