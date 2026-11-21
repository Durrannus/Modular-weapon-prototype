extends Node2D
## Shows the Highlands near the camera: the painted land in chunks, the rock and
## water that stop you, and the things standing on the land.
##
## A chunk is 16 x 16 tiles (one picture of 256 art pixels, 512 world units). The
## chunks on screen and one ring beyond are kept ready; the rest are let go. The
## pictures are painted on other threads (scripts/highlands/land_painter.gd), so
## walking never waits for one; what stops you is made at once, before the picture.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Art := preload("res://scripts/art.gd")
const Animal := preload("res://scripts/highlands/animal.gd")

const UNIT := Art.PIXEL                 # world units per art pixel
const TILE := 16.0 * UNIT
const CHUNK := LandMap.CHUNK * TILE
const SORT_BIAS := 14.0                 # as the cave's props: players sort by their middle, things by their feet
const TALL := 44                        # things at least this tall (art pixels) fade when somebody walks behind them

var map: LandMap
var world: Node2D                       # the y-sorted layer the players are in
var rig                                 # the camera rig
var players: Array = []
var chunks := {}                        # key -> {sprite, body, things: [nodes], at: Vector2i}
var tall: Array = []                    # [sprite, Rect2 in world units, feet y]
var ground: Node2D
var _atlas := {}
var _things_tex: Texture2D
var _mutex := Mutex.new()
var _painted: Array = []                # [[key, Image]], filled by the painting threads
var _asked := {}                        # key -> task id
var _dirty := {}                        # key -> true: the map changed there, paint it again
var _closing := false


func _ready() -> void:
	Painter.load_kit()
	ground = Node2D.new()
	ground.name = "Ground"
	ground.z_index = -10
	add_child(ground)
	_things_tex = ImageTexture.create_from_image(Painter.sheets["things"])


func _exit_tree() -> void:
	# Let any painting still under way finish before the pictures it reads go away.
	_closing = true
	for key in _asked:
		WorkerThreadPool.wait_for_task_completion(_asked[key])
	_asked.clear()


## The picture of one thing from the kit's sheet.
func thing_texture(name: String, frame := 0) -> AtlasTexture:
	var key := "%s#%d" % [name, frame]
	if not _atlas.has(key):
		var info: Dictionary = Painter.things[name]
		var r: Array = info["rect"]
		var w := int(info.get("frame_w", r[2]))
		var t := AtlasTexture.new()
		t.atlas = _things_tex
		t.region = Rect2(int(r[0]) + frame * w, r[1], w, r[3])
		_atlas[key] = t
	return _atlas[key]


## A thing standing on the land, with its feet at `foot` (art pixels on the map).
func stand(name: String, foot: Vector2, flip := false) -> Sprite2D:
	var info: Dictionary = Painter.things[name]
	var f: Array = info["foot"]
	var s := Sprite2D.new()
	s.texture = thing_texture(name)
	s.centered = false
	s.flip_h = flip
	var fx := float(f[0])
	if flip:
		fx = float(s.texture.region.size.x) - 1.0 - fx
	s.offset = Vector2(-fx, -float(f[1]) + SORT_BIAS / UNIT)
	s.scale = Vector2(UNIT, UNIT)
	s.position = foot * UNIT - Vector2(0, SORT_BIAS)
	world.add_child(s)
	return s


## The chunks that must be ready now: what the camera sees, and one ring more.
func _wanted() -> Rect2i:
	var view: Rect2 = rig.view_rect().grow(CHUNK * 0.6)
	var c0 := Vector2i(floori(view.position.x / CHUNK), floori(view.position.y / CHUNK))
	var c1 := Vector2i(floori(view.end.x / CHUNK), floori(view.end.y / CHUNK))
	return Rect2i(c0, c1 - c0 + Vector2i.ONE)


## Makes everything round the camera ready before the first frame is shown.
func prime() -> void:
	var want := _wanted()
	for cy in range(want.position.y, want.end.y):
		for cx in range(want.position.x, want.end.x):
			_ensure(cx, cy)
	settle()


## Waits for every picture that is on its way, and shows them. (The game never
## calls this while you play; the start does, and the tests.)
func settle() -> void:
	if not _dirty.is_empty():
		_renew()
	for key in _asked.keys():
		WorkerThreadPool.wait_for_task_completion(_asked[key])
	_asked.clear()
	_take_painted()


func _process(delta: float) -> void:
	if map == null or rig == null:
		return
	var want := _wanted()
	for cy in range(want.position.y, want.end.y):
		for cx in range(want.position.x, want.end.x):
			_ensure(cx, cy)
	_take_painted()
	if not _dirty.is_empty():
		_renew()
	var keep := want.grow(2)
	for key in chunks.keys():
		if not keep.has_point(chunks[key]["at"]):
			_drop(key)
	# Tall things fade while somebody stands behind them.
	for t in tall:
		var s: Sprite2D = t[0]
		var hidden := false
		for p in players:
			if is_instance_valid(p) and (t[1] as Rect2).has_point(p.global_position) and p.global_position.y < float(t[2]) - SORT_BIAS - 6.0:
				hidden = true
		s.modulate.a = move_toward(s.modulate.a, 0.4 if hidden else 1.0, delta * 4.0)


func _ensure(cx: int, cy: int) -> void:
	var key := LandMap.chunk_key(cx, cy)
	if chunks.has(key):
		return
	var c := {"at": Vector2i(cx, cy), "sprite": null, "things": []}
	c["body"] = _make_body(cx, cy)
	for t in map.things_in(cx, cy):
		var name := str(t["n"])
		var info: Dictionary = Painter.things.get(name, {})
		if info.is_empty():
			continue
		var foot := Vector2(float(t["x"]), float(t["y"]))
		var s := stand(name, foot, bool(t.get("f", false)))
		c["things"].append(s)
		if info.has("frames"):
			# An animal: it plays its few frames, each at its own time.
			var life := Animal.new()
			s.add_child(life)
			life.start(self, s, name, float(Painter.hsh(int(foot.x), int(foot.y), 9) % 300) / 100.0)
		if info.has("solid"):
			var size := Vector2(float(info["solid"][0]), float(info["solid"][1])) * UNIT
			_box(c["body"], foot * UNIT - Vector2(0, size.y * 0.5), size)
		var r: Array = info["rect"]
		if int(r[3]) >= TALL:
			var f: Array = info["foot"]
			tall.append([s, Rect2((foot - Vector2(float(f[0]), float(f[1])) + Vector2(4, 0)) * UNIT, Vector2(float(r[2]) - 8.0, float(r[3]) - 10.0) * UNIT), foot.y * UNIT])
	chunks[key] = c
	if not _asked.has(key):       # (a picture asked for before the chunk was let go is still on its way)
		_asked[key] = WorkerThreadPool.add_task(_paint.bind(key, cx, cy))


## Runs on another thread.
func _paint(key: int, cx: int, cy: int) -> void:
	if _closing:
		return
	var img := Painter.paint(map, cx, cy)
	_mutex.lock()
	_painted.append([key, img])
	_mutex.unlock()


func _take_painted() -> void:
	_mutex.lock()
	var got := _painted
	_painted = []
	_mutex.unlock()
	for pair in got:
		var key: int = pair[0]
		if _asked.has(key):
			WorkerThreadPool.wait_for_task_completion(_asked[key])
			_asked.erase(key)
		if not chunks.has(key):
			continue
		var c: Dictionary = chunks[key]
		if c["sprite"] == null:
			var s := Sprite2D.new()
			s.centered = false
			s.scale = Vector2(UNIT, UNIT)
			s.position = Vector2(c["at"]) * CHUNK
			ground.add_child(s)
			c["sprite"] = s
		(c["sprite"] as Sprite2D).texture = ImageTexture.create_from_image(pair[1])


func _drop(key: int) -> void:
	var c: Dictionary = chunks[key]
	if c["sprite"] != null:
		c["sprite"].queue_free()
	c["body"].queue_free()
	for s in c["things"]:
		tall = tall.filter(func(t): return t[0] != s)
		s.queue_free()
	chunks.erase(key)


## What stops you in one chunk: a box for every run of rock or water that has
## open ground beside it. (Rock deep inside a hill needs none.)
func _make_body(cx: int, cy: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)
	var x0 := cx * LandMap.CHUNK
	var y0 := cy * LandMap.CHUNK
	for y in range(y0, y0 + LandMap.CHUNK):
		var x := x0
		while x < x0 + LandMap.CHUNK:
			if not _edge(x, y):
				x += 1
				continue
			var from := x
			while x < x0 + LandMap.CHUNK and _edge(x, y):
				x += 1
			_box(body, Vector2(float(from + x) * 0.5 * TILE, (float(y) + 0.5) * TILE), Vector2(float(x - from) * TILE, TILE))
	return body


func _edge(x: int, y: int) -> bool:
	if map.walkable(x, y):
		return false
	for j in range(-1, 2):
		for i in range(-1, 2):
			if map.walkable(x + i, y + j):
				return true
	return false


func _box(body: StaticBody2D, centre: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	body.add_child(shape)


## Something on the map changed (a tile was dug): that chunk is painted again,
## and its neighbours if the tile is near their edge, and what stops you there is
## made again.
func changed(tile: Vector2i) -> void:
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var cx := floori(float(tile.x + di * 3) / LandMap.CHUNK)
			var cy := floori(float(tile.y + dj * 3) / LandMap.CHUNK)
			_dirty[LandMap.chunk_key(cx, cy)] = true


func _renew() -> void:
	for key in _dirty.keys():
		if _asked.has(key):
			continue              # wait for the picture on its way, then paint again
		_dirty.erase(key)
		if not chunks.has(key):
			continue
		var c: Dictionary = chunks[key]
		var at: Vector2i = c["at"]
		c["body"].queue_free()
		c["body"] = _make_body(at.x, at.y)
		for t in map.things_in(at.x, at.y):
			var info: Dictionary = Painter.things.get(str(t["n"]), {})
			if info.has("solid"):
				var size := Vector2(float(info["solid"][0]), float(info["solid"][1])) * UNIT
				_box(c["body"], Vector2(float(t["x"]), float(t["y"])) * UNIT - Vector2(0, size.y * 0.5), size)
		_asked[key] = WorkerThreadPool.add_task(_paint.bind(key, at.x, at.y))
