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
## Since version 49 the land is six times as big, and looking for a way to somewhere that cannot be reached would go
## over every open tile of it (a sixtieth of a second, for every enemy that asks). So the grid also knows which
## stretch of free ground every tile belongs to (`label`): two tiles in different stretches have no way between
## them, and that is answered at once. The stretches are worked out once (labels()) and kept right as tiles are dug
## and things are put down: ground that opens joins its neighbours' stretches; where ground is shut, the stretch is
## looked over nearby to see whether it has come apart.
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
var label := PackedInt32Array()  # for every tile of the region: the stretch of free ground it is part of (0 for none)
var parent := PackedInt32Array() # stretches that have grown together: each points at an older one it is joined to, or at itself
var labels_ok := false           # false: not worked out yet, or no longer to be trusted (they are worked out again when next asked for)
var labelled_ms := 0.0
const LOOK := 6000               # when ground is shut, how many tiles are looked over to see whether a stretch came apart


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
	var info: Dictionary = Painter.thing_info(str(t.get("n", "")))
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
	_shut(at, covered.has(key) or blocked.has(key) or not map.walkable(at.x, at.y))


## Something that is not one of the map's things stands on this tile from now on (a chest): nobody walks through it.
func block(tile: Vector2i) -> void:
	if not region.has_point(tile):
		return
	blocked[tile.y * LandMap.SIZE + tile.x] = true
	_shut(tile, true)
	stamp += 1


## And it stands there no longer (the Scrapyard gate, opened).
func unblock(tile: Vector2i) -> void:
	if not region.has_point(tile):
		return
	var key := tile.y * LandMap.SIZE + tile.x
	blocked.erase(key)
	_shut(tile, covered.has(key) or not map.walkable(tile.x, tile.y))
	stamp += 1


## A tile was dug (or otherwise changed).
func tile_changed(tile: Vector2i) -> void:
	if not region.has_point(tile):
		return
	var key := tile.y * LandMap.SIZE + tile.x
	_shut(tile, covered.has(key) or blocked.has(key) or not map.walkable(tile.x, tile.y))
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
				_shut(at, covered.has(key) or blocked.has(key) or not map.walkable(at.x, at.y))
	stamp += 1


# --- Which stretch of free ground a tile is part of ---------------------------------------

## Shuts or frees one tile of the grid, and keeps the stretches right.
func _shut(at: Vector2i, solid: bool) -> void:
	if grid.is_point_solid(at) == solid:
		return
	grid.set_point_solid(at, solid)
	if not labels_ok:
		return
	if solid:
		_part(at)
	else:
		_join(at)


func _find(l: int) -> int:
	var root := l
	while parent[root] != root:
		root = parent[root]
	while parent[l] != root:
		var up := parent[l]
		parent[l] = root
		l = up
	return root


## Works out the stretches of free ground for the whole land, a row at a time: a free tile takes the stretch of the
## free tile to its left or above it, and where those two differ they are one stretch from now on. (What stands on
## the land is left out here: a boulder never closes a way. What was put down since, a chest or a shut gate, is
## shut afterwards, one tile at a time.)
func labels() -> void:
	var t0 := Time.get_ticks_usec()
	var w := region.size.x
	var h := region.size.y
	label = PackedInt32Array()
	label.resize(w * h)
	parent = PackedInt32Array([0])
	var kinds := map.kinds
	for y in h:
		var row_k := (y + region.position.y) * LandMap.SIZE + region.position.x
		var row_l := y * w
		var left := 0
		for x in w:
			var k := kinds[row_k + x]
			if k >= LandMap.WATER and k <= LandMap.COPPER:      # water, rock, tin and copper stop you
				left = 0
				continue
			var up := label[row_l - w + x] if y > 0 else 0
			if left == 0:
				if up != 0:
					left = up
				else:
					left = parent.size()
					parent.append(left)
			elif up != 0 and up != left:
				var a := _find(left)
				var b := _find(up)
				if a != b:
					parent[maxi(a, b)] = mini(a, b)
			label[row_l + x] = left
	labels_ok = true
	for key: int in blocked:
		var at := Vector2i(key % LandMap.SIZE, key / LandMap.SIZE)
		if region.has_point(at) and labels_ok:
			_part(at)
	labelled_ms = float(Time.get_ticks_usec() - t0) / 1000.0


func _at(tile: Vector2i) -> int:
	return (tile.y - region.position.y) * region.size.x + (tile.x - region.position.x)


## A tile was freed: it is part of whatever free ground lies beside it, and joins those stretches into one.
func _join(tile: Vector2i) -> void:
	var mine := parent.size()
	parent.append(mine)
	label[_at(tile)] = mine
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = tile + step
		if not region.has_point(n) or grid.is_point_solid(n):
			continue
		var other := label[_at(n)]
		if other == 0:
			labels_ok = false          # (free ground with no stretch: something was missed; work them all out again)
			return
		var a := _find(mine)
		var b := _find(other)
		if a != b:
			parent[maxi(a, b)] = mini(a, b)


## A tile was shut: if the free ground beside it no longer hangs together, the part that was cut off becomes a
## stretch of its own. Only so many tiles are looked over; if that is not enough to tell, the stretches are no
## longer trusted, and are all worked out again when next asked for.
func _part(tile: Vector2i) -> void:
	label[_at(tile)] = 0
	var sides: Array = []
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = tile + step
		if region.has_point(n) and not grid.is_point_solid(n):
			sides.append(n)
	var big := 0
	while sides.size() > 1:
		var from: Vector2i = sides.pop_front()
		var seen := {from: true}
		var queue: Array = [from]
		var at := 0
		var left := sides.size()
		while at < queue.size() and left > 0 and queue.size() < LOOK:
			var c: Vector2i = queue[at]
			at += 1
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + step
				if seen.has(n) or not region.has_point(n) or grid.is_point_solid(n):
					continue
				seen[n] = true
				queue.append(n)
				if sides.has(n):
					left -= 1
		if left == 0:
			return                     # everything beside the tile still hangs together
		if at >= queue.size():
			# All of this side was looked over, and it does not reach every other side: it is a stretch of its own now.
			var mine := parent.size()
			parent.append(mine)
			for c: Vector2i in queue:
				label[_at(c)] = mine
			sides = sides.filter(func(n): return not seen.has(n))
		else:
			big += 1                   # too big to look over
			if big >= 2:
				labels_ok = false
				return
			sides.append(from)         # (look at it again last: the others may be small)
			if sides.size() == 1 + big - 1:
				break


## Is there a way between these two free tiles at all?
func joined(a: Vector2i, b: Vector2i) -> bool:
	if not labels_ok:
		labels()
	var la := label[_at(a)]
	var lb := label[_at(b)]
	if la == 0 or lb == 0:
		return true                    # (not known: let the grid look)
	return _find(la) == _find(lb)


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
## the tile you stand on. If the far end cannot be stood on, or cannot be got to, the way goes to the nearest tile
## round it that can (within ten tiles); empty if there is none.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_free(tile_of(from))
	var b := nearest_free(tile_of(to))
	if a.x < 0 or b.x < 0:
		return PackedVector2Array()
	if not joined(a, b):
		# No way there: the way goes to the nearest tile round it that can be got to, if one is near.
		b = _nearest_joined(a, b, 10)
		if b.x < 0:
			return PackedVector2Array()
	return grid.get_point_path(a, b, true)


## The free tile nearest to `to`, within `far` tiles of it, that can be walked to from `from`. (-1, -1) if none.
func _nearest_joined(from: Vector2i, to: Vector2i, far: int) -> Vector2i:
	for r in range(1, far + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for j in range(-r, r + 1):
			for i in range(-r, r + 1):
				if maxi(absi(i), absi(j)) != r:
					continue
				var at := to + Vector2i(i, j)
				if is_free(at) and float(i * i + j * j) < best_d and joined(from, at):
					best_d = float(i * i + j * j)
					best = at
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## How many tiles the way from one place to another is (-1 if there is none).
func steps(from: Vector2, to: Vector2) -> int:
	var a := nearest_free(tile_of(from))
	var b := nearest_free(tile_of(to))
	if a.x < 0 or b.x < 0 or not joined(a, b):
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
