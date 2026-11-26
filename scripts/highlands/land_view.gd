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
const LandLight := preload("res://scripts/highlands/land_light.gd")
const LIGHT_SHADER := preload("res://shaders/highlands_light.gdshader")

const UNIT := Art.PIXEL                 # world units per art pixel
const TILE := 16.0 * UNIT
const CHUNK := LandMap.CHUNK * TILE
const SORT_BIAS := 14.0                 # as the cave's props: players sort by their middle, things by their feet
const TALL := 44                        # things at least this tall (art pixels) fade when somebody walks behind them
const GIVE := 4.0                       # how far rock and water stand back from open ground (world units: two art pixels)
const UNLIT := ["lantern"]              # things that are lights themselves: never dimmed (version 68)
const SKIP_GROUPS := ["unlit", "hazards", "crown_shots"]   # what stands in the world and is never dimmed: danger marks, the boss
const RELIGHT_EVERY := 12               # frames between two tints of somebody who is not a player or a foe (chests, folk)

var map: LandMap
var world: Node2D                       # the y-sorted layer the players are in
var rig                                 # the camera rig
var players: Array = []
var chunks := {}                        # key -> {sprite, body, things: [nodes], at: Vector2i}
var tall: Array = []                    # [sprite, Rect2 in world units, feet y]
var ground: Node2D
var _atlas := {}
var _things_tex: Texture2D
var _snow_tex: Texture2D                # the snow kit's things (version 62): what stands in the snow round the Hound Den
var _tools_tex: Texture2D
var _mutex := Mutex.new()
var _painted: Array = []                # [[key, Image]], filled by the painting threads
var _asked := {}                        # key -> task id
var _dirty := {}                        # key -> true: the map changed there, paint it again
var _closing := false
var _frame := 0
var _night_shown := 0.0                 # the night the chunks' things were last tinted for
var _no_glow: ImageTexture              # (a chunk with nothing glowing)


func _ready() -> void:
	Painter.load_kit()
	ground = Node2D.new()
	ground.name = "Ground"
	ground.z_index = -10
	add_child(ground)
	_things_tex = ImageTexture.create_from_image(Painter.sheets["things"])
	if Painter.snow_ready:
		_snow_tex = ImageTexture.create_from_image(Painter.sheets["snow/things"])
	_tools_tex = Art.texture("tools/tools.png")     # the stump a felled pine leaves is on the tool art's sheet
	_no_glow = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RG8))


func _exit_tree() -> void:
	# Let any painting still under way finish before the pictures it reads go away.
	_closing = true
	for key in _asked:
		WorkerThreadPool.wait_for_task_completion(_asked[key])
	_asked.clear()


## The picture of one thing from the kit's sheet (or the snow kit's: its snowy picture).
func thing_texture(name: String, frame := 0, snow := false) -> AtlasTexture:
	var key := "%s#%d%s" % [name, frame, "@snow" if snow else ""]
	if not _atlas.has(key):
		var info: Dictionary = Painter.snow_things[name] if snow else Painter.things[name]
		var r: Array = info["rect"]
		var w := int(info.get("frame_w", r[2]))
		var t := AtlasTexture.new()
		t.atlas = _snow_tex if snow else (_tools_tex if str(info.get("sheet", "")) == "tools" else _things_tex)
		t.region = Rect2(int(r[0]) + frame * w, r[1], w, r[3])
		_atlas[key] = t
	return _atlas[key]


## A thing standing on the land, with its feet at `foot` (art pixels on the map). `snow`: its snowy picture.
func stand(name: String, foot: Vector2, flip := false, snow := false) -> Sprite2D:
	var info: Dictionary = Painter.snow_things[name] if snow else Painter.things[name]
	var f: Array = info["foot"]
	var s := Sprite2D.new()
	s.texture = thing_texture(name, 0, snow)
	if snow:
		s.set_meta("snow", true)
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
	_light(delta)


func _ensure(cx: int, cy: int) -> void:
	var key := LandMap.chunk_key(cx, cy)
	if chunks.has(key):
		return
	var c := {"at": Vector2i(cx, cy), "sprite": null, "things": [], "by_thing": {}}
	c["body"] = _make_body(cx, cy)
	_stand_things(c)
	chunks[key] = c
	if not _asked.has(key):       # (a picture asked for before the chunk was let go is still on its way)
		_asked[key] = WorkerThreadPool.add_task(_paint.bind(key, cx, cy))


## Stands a chunk's things on it, with the boxes of those that stop you.
func _stand_things(c: Dictionary) -> void:
	var at: Vector2i = c["at"]
	for t in map.things_in(at.x, at.y):
		var name := str(t["n"])
		var snow := Painter.snowy_thing(map, t)
		var info: Dictionary = Painter.snow_things.get(name, {}) if snow else Painter.things.get(name, {})
		if info.is_empty() or not info.has("rect"):
			continue              # (a small plant drawn into the ground has no picture of its own: land_grow.gd)
		var foot := Vector2(float(t["x"]), float(t["y"]))
		var s := stand(name, foot, bool(t.get("f", false)), snow)
		s.set_meta("land", name)
		c["things"].append(s)
		c["by_thing"][LandMap.thing_key(t)] = s
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


## The picture of a thing that stands on the land now (null if its chunk is not shown).
func sprite_of(t: Dictionary) -> Sprite2D:
	var key := LandMap.chunk_key(int(t["x"]) / (LandMap.CHUNK * LandMap.TILE_PX), int(t["y"]) / (LandMap.CHUNK * LandMap.TILE_PX))
	if not chunks.has(key):
		return null
	return chunks[key]["by_thing"].get(LandMap.thing_key(t), null)


## A thing was taken off the land or put on it (a pine felled, its stump left): the things of its chunk are stood
## again, and what stops you there is made again. Nothing is painted.
func things_changed(foot: Vector2) -> void:
	var key := LandMap.chunk_key(int(foot.x) / (LandMap.CHUNK * LandMap.TILE_PX), int(foot.y) / (LandMap.CHUNK * LandMap.TILE_PX))
	if not chunks.has(key):
		return
	var c: Dictionary = chunks[key]
	var faded := {}
	for k in c["by_thing"]:
		faded[k] = (c["by_thing"][k] as Sprite2D).modulate.a
	for s in c["things"]:
		tall = tall.filter(func(t): return t[0] != s)
		s.queue_free()
	c["things"] = []
	c["by_thing"] = {}
	c["body"].queue_free()
	c["body"] = _make_body(c["at"].x, c["at"].y)
	_stand_things(c)
	_tint_things(c)
	for k in c["by_thing"]:
		if faded.has(k):
			(c["by_thing"][k] as Sprite2D).modulate.a = faded[k]


## Runs on another thread.
func _paint(key: int, cx: int, cy: int) -> void:
	if _closing:
		return
	var ore: Array = []
	var img := Painter.paint(map, cx, cy, ore)
	var light := LandLight.make(map, cx, cy, ore)
	_mutex.lock()
	_painted.append([key, img, light])
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
		_lit(c, pair[2])


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
## open ground beside it. (Rock deep inside a hill needs none.) Where a box has
## open ground at a side, that side stands back by GIVE: somebody is as wide as a
## tile, and a tunnel dug one tile wide must be wide enough to walk.
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
			var up := map.walkable(x, y - 1)
			var down := map.walkable(x, y + 1)
			while x < x0 + LandMap.CHUNK and _edge(x, y) and map.walkable(x, y - 1) == up and map.walkable(x, y + 1) == down:
				x += 1
			var left := float(from) * TILE + (GIVE if map.walkable(from - 1, y) else 0.0)
			var right := float(x) * TILE - (GIVE if map.walkable(x, y) else 0.0)
			var top := float(y) * TILE + (GIVE if up else 0.0)
			var bottom := float(y + 1) * TILE - (GIVE if down else 0.0)
			_box(body, Vector2((left + right) * 0.5, (top + bottom) * 0.5), Vector2(right - left, bottom - top))
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
			var info: Dictionary = Painter.thing_info(str(t["n"]))
			if info.has("solid"):
				var size := Vector2(float(info["solid"][0]), float(info["solid"][1])) * UNIT
				_box(c["body"], Vector2(float(t["x"]), float(t["y"])) * UNIT - Vector2(0, size.y * 0.5), size)
		_asked[key] = WorkerThreadPool.add_task(_paint.bind(key, at.x, at.y))


# --- The light (version 68: land_light.gd) ------------------------------------------------------------------------


## A chunk's light has come with its picture: the land is drawn through the light's shader, and its things tinted.
func _lit(c: Dictionary, light: Dictionary) -> void:
	c["light"] = light
	var s: Sprite2D = c["sprite"]
	var mat: ShaderMaterial = s.material
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = LIGHT_SHADER
		s.material = mat
	mat.set_shader_parameter("tiles", ImageTexture.create_from_image(light["tiles"]))
	var glow: Image = light["glow"]
	mat.set_shader_parameter("glow", ImageTexture.create_from_image(glow) if glow != null else _no_glow)
	mat.set_shader_parameter("has_glow", glow != null)
	mat.set_shader_parameter("origin", light["origin"])
	mat.set_shader_parameter("night_col", LandLight.NIGHT)
	mat.set_shader_parameter("snow_day", LandLight.SNOW_DAY)
	mat.set_shader_parameter("snow_night", LandLight.SNOW_NIGHT)
	mat.set_shader_parameter("lamp_warm", LandLight.LAMP_WARM)
	mat.set_shader_parameter("fire_warm", LandLight.FIRE_WARM)
	mat.set_shader_parameter("player_reach", LandLight.PLAYER_REACH)
	mat.set_shader_parameter("player_light", LandLight.PLAYER_LIGHT)
	_lamps_of(c)
	_shared(mat)
	_tint_things(c)


## The lights reaching chunk c now (the night changes which of them are lit), into its shader.
func _lamps_of(c: Dictionary) -> void:
	var lamps := LandLight.lamps_now(c["light"])
	c["lamps"] = lamps
	if c["sprite"] != null and c["sprite"].material != null:
		var mat: ShaderMaterial = c["sprite"].material
		mat.set_shader_parameter("lamps", lamps)
		mat.set_shader_parameter("lamp_n", LandLight.lamp_count(lamps))


## What every chunk's shader shares: the night, how dark the deep is, where everybody carries their small light.
func _shared(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("night", LandLight.night if LandLight.on else 0.0)
	var deep := LandLight.deep_col() if LandLight.on else Vector3.ONE
	mat.set_shader_parameter("deep_col", deep)
	var carried := PackedVector4Array()
	carried.resize(4)
	var k := 0
	for p in players:
		if k < 4 and is_instance_valid(p) and p.visible:
			var at: Vector2 = p.global_position / UNIT
			carried[k] = Vector4(at.x, at.y, 0, 0)
			k += 1
	mat.set_shader_parameter("players", carried)
	mat.set_shader_parameter("player_n", k if LandLight.on else 0)


## The light at a point (world units) as a tint; `carried`: count everybody's small light too.
func light_at(at: Vector2, carried := false) -> Color:
	var art := at / UNIT
	var key := LandMap.chunk_key(floori(art.x / Painter.PX), floori(art.y / Painter.PX))
	var c: Dictionary = chunks.get(key, {})
	var lights: Array = []
	if carried:
		for p in players:
			if is_instance_valid(p) and p.visible:
				lights.append(p.global_position / UNIT)
	if c.is_empty() or not c.has("light"):
		return LandLight.sample(null, PackedVector4Array(), art, lights)
	return LandLight.sample(c["light"], c["lamps"], art, lights)


## Tints chunk c's things for the light they stand in (a lantern is a light itself: never).
func _tint_things(c: Dictionary) -> void:
	c["night"] = LandLight.night
	if not c.has("light"):
		return
	for s: Sprite2D in c["things"]:
		if not is_instance_valid(s):
			continue
		var tint := Color.WHITE if UNLIT.has(str(s.get_meta("land", ""))) else light_at(s.position + Vector2(0, SORT_BIAS))
		s.modulate = Color(tint.r, tint.g, tint.b, s.modulate.a)


## Every frame: the day moves on, the shaders hear where everybody is, and those who move take the light they are in.
## (Others standing in the world, such as chests and Pip, every RELIGHT_EVERY frames; the land's own things when the
## night changes.)
func _light(delta: float) -> void:
	LandLight.tick(delta)
	_frame += 1
	var night_moved := absf(LandLight.night - _night_shown) > 0.001
	_night_shown = LandLight.night
	var redo := 0
	for key in chunks:
		var c: Dictionary = chunks[key]
		if c["sprite"] == null or c["sprite"].material == null:
			continue
		if night_moved:
			_lamps_of(c)
		_shared(c["sprite"].material)
		if redo < 2 and absf(float(c.get("night", 0.0)) - LandLight.night) > 0.001:
			_tint_things(c)
			redo += 1
	if world == null:
		return
	var view: Rect2 = rig.view_rect().grow(96.0) if rig != null else Rect2()
	var i := 0
	for n in world.get_children():
		i += 1
		if not (n is CanvasItem) or n.has_meta("land"):
			continue
		var mover: bool = n is CharacterBody2D
		if not mover and (i + _frame) % RELIGHT_EVERY != 0:
			continue
		var ci := n as CanvasItem
		var skip := false
		for g in SKIP_GROUPS:
			if ci.is_in_group(g):
				skip = true
				break
		if skip:
			ci.self_modulate = Color(1, 1, 1, ci.self_modulate.a)
			continue
		var at: Vector2 = (ci as Node2D).global_position if ci is Node2D else Vector2.ZERO
		if rig != null and not view.has_point(at):
			continue
		var tint := LandLight.actor_tint(light_at(at, true)) if LandLight.on else Color.WHITE
		ci.self_modulate = Color(tint.r, tint.g, tint.b, ci.self_modulate.a)
