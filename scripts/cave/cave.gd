extends "res://scripts/game_base.gd"
## The tutorial cave from the Game Plan: four rooms, climbed from south to north.
##
##   Room 1  the wreck     find your weapon in the ship's crate, fight a few crawlers
##   Room 2  the burrows   learn to dodge against burrowers that lunge
##   Room 3  the nest      a mixed fight; clearing it gives your first rune
##   Room 4  the forge     fitting the rune wakes the guardian; beat it, free the
##                         smith, forge the tin sword, take the stairs up
##
## The map is a grid of rock and floor built in code (see _carve). The ground the
## players see is one painted image made from that same map (art/cave/cave_ground.png).
## One or two players; enemy numbers and the boss scale with the number of players.
##
## The art is drawn in flat, unlit colours. The mood comes from a dark tint over
## everything, the art's stepped lights, and "glow" layers that the tint skips.

const Crawler := preload("res://scripts/cave/crawler.gd")
const Burrower := preload("res://scripts/cave/burrower.gd")
const Guardian := preload("res://scripts/cave/guardian.gd")
const Hazard := preload("res://scripts/cave/hazard.gd")
const StripSprite := preload("res://scripts/cave/strip_sprite.gd")
const CaveUi := preload("res://scripts/cave/cave_ui.gd")

const COLS := 41
const ROWS := 73
## Rooms in the order you meet them (tiles). Halls join them; each hall has a gate
## at its south end.
const ROOMS := [Rect2i(9, 57, 23, 12), Rect2i(9, 41, 23, 12), Rect2i(8, 24, 25, 13), Rect2i(6, 4, 29, 16)]
const HALLS := [Rect2i(19, 53, 3, 4), Rect2i(19, 37, 3, 4), Rect2i(19, 20, 3, 4)]
## Rock that juts into the rooms, so the walls aren't ruler-straight.
const BUMPS := [
	Rect2i(9, 61, 1, 3), Rect2i(31, 62, 1, 3), Rect2i(12, 57, 4, 1), Rect2i(25, 57, 4, 1), Rect2i(9, 66, 2, 3), Rect2i(30, 67, 2, 2),
	Rect2i(9, 45, 1, 4), Rect2i(31, 44, 1, 3), Rect2i(13, 41, 3, 1), Rect2i(26, 41, 4, 1), Rect2i(11, 52, 4, 1), Rect2i(25, 52, 3, 1),
	Rect2i(8, 28, 1, 3), Rect2i(32, 30, 1, 4), Rect2i(11, 24, 4, 1), Rect2i(26, 24, 3, 1), Rect2i(10, 36, 5, 1), Rect2i(25, 36, 5, 1),
	Rect2i(6, 10, 1, 4), Rect2i(34, 13, 1, 4), Rect2i(8, 19, 6, 1), Rect2i(26, 19, 6, 1),
]
const CENTRE_X := 20.5          # the cave's centre line, in tiles
const SPAWN := Vector2(20.5, 64.6)
const FORGE_AT := Vector2(20.5, 6.88)     # the forge's feet, in tiles
const GUARDIAN_AT := Vector2(20.5, 12.62) # the casting circle he kneels on
## Light colours from the art notes.
const WARM := Color(1.0, 0.60, 0.28)
const DAY := Color(0.50, 0.78, 0.95)
const TEAL := Color(0.20, 0.85, 0.66)
const AMBIENT_LIFT := 1.15       # a touch brighter than the art's ambient, so the dark rooms stay readable

var cells := PackedByteArray()  # 1 = floor
var cave_data: Dictionary = {}
var floor_node: Node2D
var ui
var gates: Array = []           # [{sprite, body, open}]
var blocked: Array = []         # world rects props stand on (enemies don't spawn there)
var interactables: Array = []   # [{at, radius, text, lift, can: Callable(i), use: Callable(i)}]
var lights := {}                # name -> PointLight2D

var stage := "intro"
var owned: Array = []           # per player: the part ids they can use at the forge
var armed: Array = []           # per player: has taken a sword
var room_i := 0
var fighting := false
var fight_plan: Array = []      # the room's waves, kept so a wipe can restart it
var waves: Array = []
var wave_wait := 0.0
var timer := 0.0                # counts down inside timed stages
var run_time := 0.0
var knockouts := 0
var wiping := false
var was_busy := false

var crate: Node2D
var pedestal: Node2D
var forge_prop: Node2D
var forge_awake := false
var channels: Node2D            # the lit floor channels, once the forge wakes
var coal: Node2D
var braziers: Array = []
var stairs: Node2D
var cage_front: Node2D
var smith: Node2D
var guardian = null
var guardian_home := Vector2.ZERO


func _ready() -> void:
	randomize()
	if not Net.online():
		Sim.shuffle()
	cave_data = Art.json("cave/cave.json")
	_carve()
	_make_world()
	_make_floor()
	_make_walls()
	_make_props()
	_add_players(SPAWN * TILE)
	for i in players.size():
		players[i].auto_respawn = false
		players[i].face_dir = Vector2.UP
		owned.append(["wooden_blade", "wooden_grip", "plain_pommel"])
		armed.append(false)
	# The forge towers over the north wall, so the camera may look above the map.
	var ground: Dictionary = cave_data.get("ground", {})
	var top: float = float((ground.get("draw_at_map_px", [0, 0]) as Array)[1]) * Art.PIXEL
	rig.set_limits(Rect2(0, top, COLS * TILE, ROWS * TILE - top), 0.0)
	rig.snap()
	_make_ui()
	hud.mode = "cave"
	build_menu.hotkey = false
	build_menu.sandbox = false
	pause_menu.pad_start = true
	ui = CaveUi.new()
	add_child(ui)
	ui.cam = rig.camera
	# Dark cave, lit by what glows.
	var amb: Array = cave_data.get("lighting", {}).get("ambient", [0.31, 0.35, 0.53])
	var dark := CanvasModulate.new()
	dark.color = Color(amb[0], amb[1], amb[2]) * AMBIENT_LIFT
	dark.color.a = 1.0
	add_child(dark)
	_spawn_guardian()
	_begin()


# --- The map ------------------------------------------------------------------

func is_floor(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return false
	return cells[y * COLS + x] == 1


func _fill(r: Rect2i, v: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x >= 0 and y >= 0 and x < COLS and y < ROWS:
				cells[y * COLS + x] = v


func _carve() -> void:
	cells.resize(COLS * ROWS)
	cells.fill(0)
	for ri in ROOMS.size():
		var r: Rect2i = ROOMS[ri]
		_fill(r, 1)
		# Stepped corners (bigger in the forge room).
		var cut := 3 if ri == 3 else 2
		for corner in [[r.position.x, r.position.y, 1, 1], [r.end.x - 1, r.position.y, -1, 1], [r.position.x, r.end.y - 1, 1, -1], [r.end.x - 1, r.end.y - 1, -1, -1]]:
			for dx in cut:
				for dy in cut:
					if dx + dy < cut:
						_fill(Rect2i(corner[0] + corner[2] * dx, corner[1] + corner[3] * dy, 1, 1), 0)
	for b in BUMPS:
		_fill(b, 0)
	for h in HALLS:
		_fill(h, 1)


func _make_floor() -> void:
	floor_node = Node2D.new()
	floor_node.z_index = -10
	add_child(floor_node)
	floor_node.draw.connect(_draw_floor)


## The whole cave is one painted image, laid over the map it was made from.
func _draw_floor() -> void:
	var ground: Dictionary = cave_data.get("ground", {})
	var tex := Art.texture("cave/%s" % ground.get("file", "cave_ground.png"))
	floor_node.draw_rect(Rect2(-2000, -2000, COLS * TILE + 4000, ROWS * TILE + 4000), Color("#19142a"))
	if tex == null:
		# No art: flat colours.
		for y in ROWS:
			for x in COLS:
				if is_floor(x, y):
					floor_node.draw_rect(Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE)), Color(0.2, 0.22, 0.3))
		return
	var at: Array = ground.get("draw_at_map_px", [-64, -176])
	floor_node.draw_texture_rect(tex, Rect2(Vector2(at[0], at[1]) * Art.PIXEL, tex.get_size() * Art.PIXEL), false)


func _near_floor(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if is_floor(x + dx, y + dy):
				return true
	return false


## One solid box per run of rock cells that touch the floor.
func _make_walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	world.add_child(body)
	for y in ROWS:
		var x := 0
		while x < COLS:
			if is_floor(x, y) or not _near_floor(x, y):
				x += 1
				continue
			var x0 := x
			while x < COLS and not is_floor(x, y) and _near_floor(x, y):
				x += 1
			var shape := CollisionShape2D.new()
			var box := RectangleShape2D.new()
			box.size = Vector2((x - x0) * TILE, TILE)
			shape.shape = box
			shape.position = Vector2((x0 + x) * 0.5 * TILE, (y + 0.5) * TILE)
			body.add_child(shape)


func _solid(center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	blocked.append(Rect2(center - size * 0.5, size).grow(26.0))
	return body


## A prop from cave.json, with its feet at `tile` (in tiles). solid = the size of
## the box that blocks walking (zero = walk over it). flat = it lies on the floor,
## so everyone is drawn on top of it.
func _prop(name: String, tile: Vector2, solid := Vector2.ZERO, flat := false) -> Node2D:
	var info: Dictionary = cave_data.get("props", {}).get(name, {})
	var s := StripSprite.new()
	var o: Array = info.get("origin_feet", [0, 0])
	s.origin = Vector2(o[0], o[1])
	s.show_strip("cave/%s.png" % name, int(info.get("frames", 1)), float(info.get("fps", 6)))
	var feet := tile * TILE
	s.position = feet - Vector2(0, StripSprite.SORT_BIAS)
	if flat:
		s.z_index = -1
	world.add_child(s)
	if solid != Vector2.ZERO:
		_solid(feet - Vector2(0, solid.y * 0.5), solid)
	return s


## Swaps a prop for another of its images (lit for unlit, open for closed).
func _show(prop: Node2D, name: String) -> void:
	var info: Dictionary = cave_data.get("props", {}).get(name, {})
	prop.show_strip("cave/%s.png" % name, int(info.get("frames", 1)), float(info.get("fps", 6)))


## One of the art's stepped, hatched lights. `at` is in map pixels (art pixels
## from the map's top left) and `radius` picks the file: 48, 64, 96, 128 or 240.
## They are drawn at the same scale as the sprites and no other, or the hatching blurs.
func _lamp(at: Vector2, radius: int, col: Color, energy: float, key := "") -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = Art.stepped_light(radius)
	light.texture_scale = Art.PIXEL
	if light.texture == null:
		light.texture = Art.light_texture()
		light.texture_scale = float(radius) / 50.0
	light.color = col
	light.energy = energy
	light.position = at.round() * Art.PIXEL
	add_child(light)
	if key != "":
		lights[key] = light
	return light


## A light on a prop, at the spot the art marks on it (a flame, a rune).
func _prop_lamp(name: String, tile: Vector2, radius: int, col: Color, energy: float, key := "") -> PointLight2D:
	var info: Dictionary = cave_data.get("props", {}).get(name, {})
	var o: Array = info.get("origin_feet", [0, 0])
	var l: Array = info.get("light_px", o)
	return _lamp(tile * 16.0 + Vector2(l[0], l[1]) - Vector2(o[0], o[1]), radius, col, energy, key)


func _mushrooms(tile: Vector2) -> void:
	var name := "mushrooms_%d" % (int(tile.x * 7.0 + tile.y * 3.0) % 2)
	_prop(name, tile, Vector2.ZERO, true)
	_prop_lamp(name, tile, 48, TEAL, 0.55)


func _make_props() -> void:
	# Room 1: the wreck. The way in has come down behind you.
	_prop("collapse", Vector2(CENTRE_X, 69.06), Vector2(570, 70))
	crate = _prop("crate_closed", Vector2(14.5, 61.62), Vector2(62, 22))
	_prop("lantern", Vector2(16.12, 61.5))
	_prop_lamp("lantern", Vector2(16.12, 61.5), 96, Color(1.0, 0.8, 0.5), 0.95)
	# Cold daylight falls through the crack the giant blade made in the roof.
	_lamp(Vector2(380, 968), 128, DAY, 0.7, "crack")
	_prop("giant_blade", Vector2(24.75, 62.75), Vector2(44, 18))
	_prop("sail", Vector2(12.31, 64.38), Vector2.ZERO, true)
	_prop("planks", Vector2(16.62, 65.62), Vector2.ZERO, true)
	_prop("planks", Vector2(25.5, 63.38), Vector2.ZERO, true)
	_prop("barrel", Vector2(11.62, 60.38), Vector2(24, 14))
	_prop("barrel", Vector2(27.38, 66.31), Vector2(24, 14))
	_prop("rubble_0", Vector2(17.38, 66.4), Vector2.ZERO, true)
	_prop("rubble_1", Vector2(24.38, 66.2), Vector2.ZERO, true)
	_prop("stalagmite_small", Vector2(29.5, 59.62), Vector2(20, 12))
	_prop("bones_0", Vector2(22.62, 59.38), Vector2.ZERO, true)
	_mushrooms(Vector2(30.19, 61.19))
	_mushrooms(Vector2(10.62, 58.81))
	# Room 2: the burrows.
	_prop("stalagmite_large", Vector2(12.5, 44.8), Vector2(30, 16))
	_prop("stalagmite_large", Vector2(28.5, 44.2), Vector2(30, 16))
	_prop("stalagmite_small", Vector2(27.5, 50.4), Vector2(20, 12))
	_prop("stalagmite_small", Vector2(15.5, 50.6), Vector2(20, 12))
	_prop("bones_1", Vector2(18.5, 46.6), Vector2.ZERO, true)
	_prop("bones_0", Vector2(24.5, 49.6), Vector2.ZERO, true)
	for m in [Vector2(10.6, 49.6), Vector2(30.3, 47.6), Vector2(22.4, 42.4)]:
		_mushrooms(m)
	# Room 3: the nest, with the rune on its pedestal.
	pedestal = _prop("pedestal_rune", Vector2(CENTRE_X, 29.81), Vector2(28, 16))
	_prop_lamp("pedestal_rune", Vector2(CENTRE_X, 29.81), 64, WARM, 0.7, "rune")
	_prop("stalagmite_large", Vector2(11.5, 27.8), Vector2(30, 16))
	_prop("stalagmite_large", Vector2(30.0, 27.2), Vector2(30, 16))
	_prop("stalagmite_small", Vector2(29.5, 34.4), Vector2(20, 12))
	_prop("stalagmite_small", Vector2(12.5, 34.6), Vector2(20, 12))
	_prop("bones_0", Vector2(23.5, 33.2), Vector2.ZERO, true)
	_prop("bones_1", Vector2(15.0, 30.2), Vector2.ZERO, true)
	for m in [Vector2(9.6, 32.6), Vector2(31.2, 29.4), Vector2(16.5, 25.4), Vector2(24.2, 35.6)]:
		_mushrooms(m)
	# Room 4: the sword forge in the north wall, its sleeping guardian, the caged
	# smith and the stairs up.
	# Its step, the bellows and the coal beside it block one wide strip of the wall.
	forge_prop = _prop("forge_dormant", FORGE_AT, Vector2(326, 92))
	_prop_lamp("forge_awake", FORGE_AT, 240, WARM, 0.0, "forge")
	_lamp(GUARDIAN_AT * 16.0 - Vector2(0, 6), 64, WARM, 0.0, "circle")
	_lamp(GUARDIAN_AT * 16.0 - Vector2(0, 30), 64, DAY, 0.75, "guardian")
	# On the forge's step, a hair in front of the forge so they aren't drawn behind it.
	_prop("bellows", Vector2(17.12, 6.9))
	coal = _prop("coal_heap", Vector2(24.5, 6.9))
	# (The trough and anvil stand a little further from the braziers than the art's
	# layout has them, so nobody gets wedged in the gap between.)
	_prop("trough", Vector2(18.1, 9.6), Vector2(38, 14))
	_prop("anvil", Vector2(22.9, 9.5), Vector2(34, 14))
	_prop("ingots", Vector2(23.9, 10.0), Vector2.ZERO, true)
	_prop("quillon_piece", Vector2(12.25, 8.0), Vector2(64, 16))
	_prop("barrel", Vector2(13.5, 5.5), Vector2(24, 14))
	_prop("barrel", Vector2(12.62, 6.0), Vector2(24, 14))
	# Two braziers by the forge burn from the start; the two by the stairs light
	# when the way out opens.
	for b in [Vector2(15.75, 8.19), Vector2(25.25, 8.19), Vector2(26.38, 5.31), Vector2(30.62, 5.31)]:
		var k := braziers.size()
		braziers.append(_prop("brazier_unlit", b, Vector2(22, 14)))
		_lamp(b * 16.0 - Vector2(0, 28), 96 if k < 2 else 64, WARM, 0.0, "brazier%d" % k)
	_set_brazier(0, true)
	_set_brazier(1, true)
	# The gap between the forge's step and each of its braziers is too narrow to
	# walk through, so it is closed off: the forge front is one open bay.
	for side in [-1.0, 1.0]:
		_solid((FORGE_AT + Vector2(side * 4.75, 0.42)) * TILE, Vector2(26, 30))
	stairs = _prop("stairs_up", Vector2(28.5, 4.0))
	stairs.tint = Color(0.45, 0.45, 0.55)
	stairs.glow_on = false
	stairs.refresh()
	_prop_lamp("stairs_up", Vector2(28.5, 4.0), 128, DAY, 0.0, "stairs")
	var cage_at := Vector2(31.0, 11.62)
	var cage := Node2D.new()
	cage.position = cage_at * TILE - Vector2(0, StripSprite.SORT_BIAS)
	world.add_child(cage)
	_solid(cage_at * TILE - Vector2(0, 12), Vector2(60, 26))
	var cinfo: Dictionary = cave_data.get("props", {}).get("cage", {})
	var co: Array = cinfo.get("origin_feet", [18, 49])
	var so: Array = cave_data.get("props", {}).get("smith", {}).get("origin_feet", [28, 52])
	for layer_name in ["cage_back", "smith", "cage_front"]:
		var s := StripSprite.new()
		cage.add_child(s)
		if layer_name == "smith":
			s.origin = Vector2(so[0], so[1])
			s.show_strip("cave/smith_caged.png", 4, 4.0)
			smith = s
		else:
			s.origin = Vector2(co[0], co[1])
			s.show_strip("cave/%s.png" % layer_name)
			if layer_name == "cage_front":
				cage_front = s
	# An older guardian, long empty, kneels in the dark corner.
	var ginfo: Dictionary = cave_data.get("enemies", {}).get("guardian", {})
	var death: Dictionary = ginfo.get("strips", {}).get("death", {})
	if Art.texture("cave/guardian_death.png") != null and not death.is_empty():
		var ruin := StripSprite.new()
		var go: Array = ginfo.get("origin_feet", [64, 136])
		ruin.origin = Vector2(go[0], go[1])
		ruin.fixed_frame = int(death["frames"]) - 1
		ruin.show_strip("cave/guardian_death.png", int(death["frames"]), 1.0)
		ruin.glow_on = false
		ruin.playing = false
		ruin.refresh()
		ruin.position = Vector2(9.38, 18.25) * TILE - Vector2(0, StripSprite.SORT_BIAS)
		world.add_child(ruin)
		_solid(Vector2(9.38, 18.25) * TILE - Vector2(0, 12), Vector2(70, 24))
	_prop("stalagmite_large", Vector2(8.62, 17.38), Vector2(30, 16))
	_prop("stalagmite_small", Vector2(32.5, 17.81), Vector2(20, 12))
	_prop("bones_1", Vector2(24.0, 16.19), Vector2.ZERO, true)
	_mushrooms(Vector2(7.62, 13.62))
	_mushrooms(Vector2(33.19, 8.62))

	# Gates: one at the south end of each hall, shut until the room below is cleared.
	var gate_o: Array = cave_data.get("props", {}).get("gate_closed", {}).get("origin_feet", [28, 47])
	for h in HALLS:
		var bottom := float(h.end.y)
		var g := StripSprite.new()
		g.origin = Vector2(gate_o[0], gate_o[1])
		g.show_strip("cave/gate_closed.png")
		g.position = Vector2(CENTRE_X, bottom) * TILE - Vector2(0, StripSprite.SORT_BIAS)
		world.add_child(g)
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		body.position = Vector2(CENTRE_X, bottom - 0.5) * TILE
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(3 * TILE, TILE * 0.9)
		shape.shape = box
		body.add_child(shape)
		world.add_child(body)
		gates.append({"sprite": g, "body": body, "shape": shape, "open": false})

	# Things you can walk up to and use.
	interactables = [
		{"at": Vector2(14.5, 61.5) * TILE, "radius": 70.0, "lift": 62.0, "text": "Search the crate",
			"can": func(i): return not armed[i] and stage in ["crate", "fight1"], "use": _take_sword},
		{"at": Vector2(CENTRE_X, 29.6) * TILE, "radius": 60.0, "lift": 96.0, "text": "Take the rune",
			"can": func(_i): return stage == "rune", "use": _take_rune},
		{"at": (FORGE_AT + Vector2(0, 0.3)) * TILE, "radius": 110.0, "lift": 120.0, "text": "Use the forge",
			"can": func(_i): return stage in ["forge", "tin", "stairs"], "use": _use_forge},
		{"at": Vector2(31.0, 13.2) * TILE, "radius": 60.0, "lift": 74.0, "text": "Talk",
			"can": func(_i): return stage in ["smith", "tin", "stairs"], "use": _talk_smith},
	]


func _open_gate(i: int) -> void:
	var g: Dictionary = gates[i]
	if g["open"]:
		return
	g["open"] = true
	(g["shape"] as CollisionShape2D).set_deferred("disabled", true)
	var s: Node2D = g["sprite"]
	s.show_strip("cave/gate_opening.png", 4, 10.0, false)
	# Open, it is a flat threshold: everyone walks over it.
	s.finished.connect(func():
		s.show_strip("cave/gate_open.png")
		s.z_index = -1, CONNECT_ONE_SHOT)
	Sfx.play(self, "gate", -3.0)
	rig.add_shake(5.0)


func _close_gate(i: int) -> void:
	var g: Dictionary = gates[i]
	if not g["open"]:
		return
	g["open"] = false
	(g["shape"] as CollisionShape2D).set_deferred("disabled", false)
	# It comes back up the way it went down: the opening strip, backwards.
	var s: Node2D = g["sprite"]
	s.z_index = 0
	s.show_strip("cave/gate_opening.png", 4, 12.0, false)
	s.reverse = true
	s.refresh()
	s.finished.connect(func(): s.show_strip("cave/gate_closed.png"), CONNECT_ONE_SHOT)
	Sfx.play(self, "gate", -3.0, 1.3)
	rig.add_shake(6.0)


func _room_rect(i: int) -> Rect2:
	var r: Rect2i = ROOMS[i]
	return Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)


## Where you stand when a room starts over: just inside its south door.
func _room_entry(i: int) -> Vector2:
	if i == 0:
		return SPAWN * TILE
	return Vector2(CENTRE_X, float(ROOMS[i].end.y) - 1.6) * TILE


# --- The run ------------------------------------------------------------------

func _begin() -> void:
	stage = "intro"
	# The storm and the wreck (art/cutscene/intro), then the cave fades in from its last, black picture.
	hud.visible = false
	ui.cutscene("cutscene/intro", players.size() > 1, func():
		hud.visible = true
		ui.fade = 1.0
		ui.fade_in(1.4)
		ui.card_picture = "cave/ui/card_intro.png"
		ui.card("Shipwrecked", "The only way out is forward.", 0.0, func():
			stage = "crate"
			ui.objective = "Search the ship's crate"
			ui.hint = _keys("Move with WASD.", "Move with [stick_l].")))


## The same hint for keyboard and controller players.
func _keys(kbm: String, pad: String) -> String:
	var any_kbm := false
	var any_pad := false
	# Online each player reads their own screen, so only their own device counts.
	for p in ([players[Net.me()]] if Net.online() else players):
		if p.input.on_pad():
			any_pad = true
		else:
			any_kbm = true
	if any_kbm and any_pad:
		return kbm + "  (Controller: " + pad + ")"
	return pad if any_pad else kbm


func _physics_process(delta: float) -> void:
	var pressed := false
	for p in players:
		var inp = p.input
		if inp.attack_pressed or inp.interact_pressed or (inp.using_pad and inp.dash_pressed):
			pressed = true
	ui.advance(pressed, delta)
	_tick_players()
	_run_later(delta)
	var busy: bool = ui.busy() or wiping or stage in ["intro", "end", "boss_wake"]
	for i in players.size():
		var p = players[i]
		p.frozen = (busy and stage != "boss_wake") or is_forging(i)
		if was_busy and not busy:
			p.need_release = true
	was_busy = busy
	pause_menu.locked = stage == "end"
	ui.prompts = []
	for p in players:
		p.interact_ready = false
	# In the forge room the camera looks a little north, to keep the forge in view.
	var in_forge_room := false
	for p in ([players[Net.me()]] if Net.online() else living_players()):
		if p.global_position.y < float(ROOMS[3].end.y) * TILE:
			in_forge_room = true
	rig.bias = rig.bias.move_toward(Vector2(0, -70.0) if in_forge_room else Vector2.ZERO, 120.0 * delta)
	if stage not in ["intro", "end"]:
		run_time += delta
	if busy and stage != "boss_wake":
		return
	_update_interactions()
	_update_stage(delta)
	if fighting:
		_update_fight(delta)


## Things due in a moment, counted in game ticks (not a timer or a tween), so
## they happen on the same tick on every computer.
var later: Array = []   # [[seconds left, what to do]]

func _after(seconds: float, what: Callable) -> void:
	later.append([seconds, what])


func _run_later(delta: float) -> void:
	for item in later.duplicate():
		item[0] = float(item[0]) - delta
		if float(item[0]) <= 0.0:
			later.erase(item)
			(item[1] as Callable).call()


func net_state() -> Array:
	return super.net_state() + [stage, room_i, fighting, waves.size(), wave_wait, timer, run_time, knockouts, wiping, armed, at_forge, ui.busy()]


func _update_interactions() -> void:
	var shown := {}
	for i in players.size():
		var p = players[i]
		if p.is_down:
			continue
		var best := -1
		var best_d := INF
		for k in interactables.size():
			var it: Dictionary = interactables[k]
			var d: float = p.global_position.distance_to(it["at"])
			if d < float(it["radius"]) and d < best_d and it["can"].call(i):
				best = k
				best_d = d
		if best < 0:
			continue
		var it: Dictionary = interactables[best]
		p.interact_ready = true
		var pad: bool = p.input.using_pad
		# (Online the prompt is for this computer's player, with their own button.)
		if not shown.has(best) and (not Net.online() or i == Net.me()):
			shown[best] = true
			ui.prompts.append({"at": it["at"] - Vector2(0, float(it["lift"])), "text": it["text"], "pad": pad})
		if p.input.interact_pressed or (pad and p.input.dash_pressed):
			it["use"].call(i)
			return


func _in_room(i: int) -> bool:
	# True once anyone still standing is a couple of tiles inside room i.
	var line := (float(ROOMS[i].end.y) - 2.2) * TILE
	for p in living_players():
		if p.global_position.y < line:
			return true
	return false


func _update_stage(delta: float) -> void:
	match stage:
		"crate":
			var all_armed := true
			for i in players.size():
				if not armed[i] and not players[i].is_down:
					all_armed = false
			if all_armed:
				stage = "fight1"
				ui.objective = "Fight off the crawlers"
				ui.hint = _keys("Hold [mouse_left] to keep swinging. The third swing is the finisher.", "Hold [pad_x] to keep swinging. The third swing is the finisher.")
				_start_fight(0, [{"crawler": 3}, {"crawler": 4}])
		"walk2":
			if _in_room(1):
				stage = "fight2"
				ui.objective = "Burrowers!"
				ui.hint = _keys("They flash red, then lunge. Dodge aside with [space], then hit them while they're stunned.", "They flash red, then lunge. Dodge aside with [pad_a], then hit them while they're stunned.")
				_start_fight(1, [{"burrower": 1}, {"burrower": 2}])
		"walk3":
			if _in_room(2):
				stage = "fight3"
				ui.objective = "Clear the nest"
				ui.hint = ""
				_start_fight(2, [{"crawler": 3, "burrower": 1}, {"crawler": 3, "burrower": 2}])
		"rune":
			var l: PointLight2D = lights.get("rune")
			if l != null:
				l.energy = 0.9 + 0.3 * sin(run_time * 5.0)
		"walk4":
			if _in_room(3):
				stage = "forge"
				_forge_objective()
		"boss_wake":
			timer -= delta
			if timer <= 0.0:
				stage = "boss"
		"boss_dead":
			timer -= delta
			if timer <= 0.0:
				_free_smith()
		"stairs":
			var out := 0
			var zone := Rect2(Vector2(26.8, 4.0) * TILE, Vector2(3.4, 1.7) * TILE)
			for p in living_players():
				if zone.has_point(p.global_position):
					out += 1
			if out > 0 and out == living_players().size():
				_finish()


# --- Fights -------------------------------------------------------------------

func _scaled(n: int) -> int:
	return roundi(float(n) * (1.0 + 0.6 * float(players.size() - 1)))


func _start_fight(room: int, plan: Array) -> void:
	room_i = room
	fight_plan = plan
	waves = plan.duplicate(true)
	fighting = true
	wave_wait = 0.9


func _foes() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(e) and not e.dead and e.kind != "guardian" and not e.is_queued_for_deletion():
			n += 1
	return n


func _update_fight(delta: float) -> void:
	if _foes() > 0:
		return
	wave_wait -= delta
	if wave_wait > 0.0:
		return
	if waves.is_empty():
		fighting = false
		_room_cleared()
		return
	var wave: Dictionary = waves.pop_front()
	for kind in wave:
		for n in _scaled(int(wave[kind])):
			_spawn(kind, room_i)
	wave_wait = 0.7


func _spawn(kind: String, room: int) -> void:
	var rect := _room_rect(room).grow(-TILE * 1.2)
	var best := rect.get_center()
	var best_score := -INF
	for tries in 24:
		var pos := Vector2(Sim.between(rect.position.x, rect.end.x), Sim.between(rect.position.y, rect.end.y))
		if not is_floor(int(pos.x / TILE), int(pos.y / TILE)):
			continue
		var bad := false
		for b in blocked:
			if (b as Rect2).has_point(pos):
				bad = true
		if bad:
			continue
		var nearest := INF
		for p in living_players():
			nearest = minf(nearest, pos.distance_to(p.global_position))
		for e in get_tree().get_nodes_in_group("foes"):
			nearest = minf(nearest, pos.distance_to(e.global_position) * 3.0)
		var score := minf(nearest, 420.0) + Sim.chance() * 20.0
		if score > best_score:
			best_score = score
			best = pos
	var e = (Crawler if kind == "crawler" else Burrower).new()
	e.position = best
	world.add_child(e)
	e.died.connect(_on_enemy_died)
	_dust_at(best + Vector2(0, 8))


func _dust_at(pos: Vector2) -> void:
	var tex := Art.texture("cave/dust_puff.png")
	if tex == null:
		return
	var n := preload("res://scripts/fx/sprite_once.gd").new()
	n.texture = tex
	n.frames = 4
	n.fps = 10.0
	n.origin = Vector2(8, 10)
	n.size = 1.4
	world.add_child(n)
	n.z_index = 0
	n.global_position = pos


func _on_enemy_died(enemy) -> void:
	var best = player
	for p in players:
		if p.global_position.distance_to(enemy.global_position) < best.global_position.distance_to(enemy.global_position):
			best = p
	best.on_kill(enemy.global_position)


## The room is clear: everyone is patched up and the way on opens.
func _room_cleared() -> void:
	for p in players:
		if p.is_down:
			p.get_up(Vector2.INF, 1.0)
		p.hp = p.max_hp
	match stage:
		"fight1":
			_open_gate(0)
			stage = "walk2"
			ui.objective = "The gate is open: head north"
			ui.hint = ""
		"fight2":
			_open_gate(1)
			stage = "walk3"
			ui.objective = "Head north"
			ui.hint = ""
		"fight3":
			stage = "rune"
			ui.objective = "Take the rune from the pedestal"
			ui.hint = ""
			Sfx.play(self, "pickup", -8.0, 0.8)


# --- Room 1: the crate ----------------------------------------------------------

func _take_sword(i: int) -> void:
	armed[i] = true
	crate.show_strip("cave/crate_open.png")
	var b: SwingBuild = builds[i]
	b.blade = "wooden_blade"
	b.grip = "wooden_grip"
	b.pommel = "plain_pommel"
	b.line = [""]
	b.changed.emit()
	Sfx.play(self, "pickup", -4.0)
	_given(players[i])
	var first := true
	for k in armed.size():
		if k != i and armed[k]:
			first = false
	if first:
		ui.card("Wooden sword", "A training sword from the ship's crate. (The bow, staff and hammer beside it aren't playable yet, so everyone takes a sword.)\n" + _keys("[mouse_left] swings where you point.", "[pad_x] swings the way you face, or aim with [stick_r]."))


## A small burst on a player who has just been given something.
func _given(p: Node2D) -> void:
	Art.play_piece(p, "pickup_burst", p.global_position + Vector2(0, -16))


# --- Room 3: the rune -----------------------------------------------------------

func _take_rune(_i: int) -> void:
	for o in owned:
		if not ("shockwave" in o):
			o.append("shockwave")
	pedestal.show_strip("cave/pedestal_empty.png")
	# The rune brightens, lifts off the pedestal and is gone.
	Art.play_piece(self, "rune_pickup", Vector2(CENTRE_X, 29.81) * TILE)
	for p in players:
		_given(p)
	var l: PointLight2D = lights.get("rune")
	if l != null:
		l.energy = 0.0
	Sfx.play(self, "pickup", -3.0)
	stage = "rune_card"
	ui.objective = ""
	ui.card("Shockwave rune", "A rune gives your swing a new trick. This one hums in your hand, but your sword can't wake it.\nYou need a forge.", 0.0, func():
		_open_gate(2)
		stage = "walk4"
		ui.objective = "Find a forge")


# --- Room 4: forge, guardian, smith ----------------------------------------------

func _spawn_guardian() -> void:
	guardian = Guardian.new()
	guardian_home = GUARDIAN_AT * TILE - guardian._feet()
	guardian.position = guardian_home
	world.add_child(guardian)
	guardian.team = players.size()
	# 255: the fight is as many chains long as it was at 300 health, before the
	# broadsword's finisher went from 2.1 hits to the Game Bible's 1.5 (11 November).
	guardian.max_hp = 255.0 * (1.0 + 0.7 * float(players.size() - 1))
	guardian.hp = guardian.max_hp
	guardian.room = _room_rect(3)
	guardian.defeated.connect(_on_guardian_defeated)
	guardian.attack_started.connect(_on_guardian_attack)


## As each of the guardian's attacks starts, the line under its health bar says
## what it is and what to do about it.
func _on_guardian_attack(kind: String) -> void:
	if stage != "boss":
		return
	match kind:
		"slam":
			ui.hint = "Slam: get out of the red circle."
		"charge":
			ui.hint = _keys("Charge: dodge aside with [space] so it hits a wall, then strike.", "Charge: dodge aside with [pad_a] so it hits a wall, then strike.")
		"quake":
			ui.hint = "Quake: stand between the cracks."
		"rocks":
			ui.hint = "Rockfall: keep moving. Strike while it stands still."


## The forge wakes: the hearth lights, molten metal runs down the floor channels
## to the casting circle, and the coals catch.
func _set_forge(lit: bool) -> void:
	if lit == forge_awake:
		return
	forge_awake = lit
	_show(forge_prop, "forge_awake" if lit else "forge_dormant")
	_show(coal, "coal_heap_lit" if lit else "coal_heap")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lights["forge"], "energy", 1.25 if lit else 0.0, 0.5)
	tw.tween_property(lights["circle"], "energy", 0.45 if lit else 0.0, 0.9)
	tw.tween_property(lights["guardian"], "energy", 0.0 if lit else 0.75, 0.9)
	if lit:
		_light_channels()
		tw.tween_property(channels, "modulate:a", 1.0, 0.9)
	elif is_instance_valid(channels):
		tw.tween_property(channels, "modulate:a", 0.0, 0.5)


## The lit channels are an animated image laid over the ground and left bright.
func _light_channels() -> void:
	if is_instance_valid(channels):
		return
	var info: Dictionary = cave_data.get("ground", {}).get("awake", {})
	if Art.texture("cave/%s" % info.get("file", "")) == null:
		channels = Node2D.new()
		add_child(channels)
		return
	var at: Array = info.get("draw_at_map_px", [96, -110])
	var s := StripSprite.new()
	s.show_strip("cave/%s" % info["file"], int(info.get("frames", 8)), float(info.get("fps", 8)))
	s.position = Vector2(at[0], at[1]) * Art.PIXEL - Vector2(0, StripSprite.SORT_BIAS)
	s.z_index = -9
	s.material = Art.unshaded()
	s.modulate.a = 0.0
	add_child(s)
	channels = s


func _set_brazier(k: int, lit: bool) -> void:
	_show(braziers[k], "brazier_lit" if lit else "brazier_unlit")
	(lights["brazier%d" % k] as PointLight2D).energy = 0.7 if lit else 0.0


func _fitted(i: int) -> bool:
	return "shockwave" in builds[i].line


func _tin_done(i: int) -> bool:
	return builds[i].blade == "tin_blade" and _fitted(i)


func _waiting_on(check: Callable) -> String:
	var who: Array = []
	for i in players.size():
		if not check.call(i):
			who.append("P%d" % (i + 1))
	if players.size() < 2 or who.is_empty():
		return ""
	return "  (waiting for %s)" % " and ".join(who)


func _forge_objective() -> void:
	if stage == "forge":
		ui.objective = "Fit the rune to your sword at the forge" + _waiting_on(_fitted)
		ui.hint = "The forge is the great sword in the north wall. Drag the rune onto the slot in the grip."
	elif stage == "tin":
		ui.objective = "Forge your tin sword at the forge" + _waiting_on(_tin_done)
		ui.hint = "Sword tab: pick the tin blade and the tin grip. Keep the rune in a slot."


func _use_forge(i: int) -> void:
	if not Net.online() or i == Net.me():
		build_menu.owned = owned[i]
	open_forge(i)


## Someone has finished at the forge: has everyone done what the story is waiting for?
func _forge_done(_i: int) -> void:
	# Online, wait until nobody is still at the forge before the story moves on.
	for k in players.size():
		if is_forging(k):
			_forge_objective()
			return
	if stage == "forge":
		var all := true
		for i in players.size():
			if not _fitted(i):
				all = false
		if all:
			_wake_guardian()
		else:
			_forge_objective()
	elif stage == "tin":
		var all := true
		for i in players.size():
			if not _tin_done(i):
				all = false
		if all:
			_open_stairs()
		else:
			_forge_objective()


## The rune is fitted: the forge wakes, metal runs to the casting circle, and the
## knight kneeling on it stirs.
func _wake_guardian() -> void:
	stage = "boss_wake"
	timer = Guardian.WAKE_TIME
	room_i = 3
	_set_forge(true)
	Sfx.play(self, "forged", -6.0)
	_close_gate(2)
	# Nobody gets left outside the door.
	var n := 0
	for p in players:
		if p.global_position.y > (float(ROOMS[3].end.y) - 0.6) * TILE:
			p.global_position = _room_entry(3) + Vector2((n - 0.5) * 60.0, 0)
			p.reset_physics_interpolation()
			n += 1
	guardian.wake()
	ui.boss = guardian
	ui.boss_shown = 1.0
	ui.objective = "Defeat the forge guardian"
	ui.hint = "Every attack shows on the floor first. Watch the red marks."


func _on_guardian_defeated(_g) -> void:
	stage = "boss_dead"
	timer = 1.8
	ui.hint = ""
	ui.objective = ""
	for h in get_tree().get_nodes_in_group("hazards"):
		h.queue_free()
	for p in players:
		if p.is_down:
			p.get_up(Vector2.INF, 1.0)
		p.hp = p.max_hp


func _free_smith() -> void:
	stage = "smith"
	# The lock flares and the bars are thrown out.
	var broke: Dictionary = Art.piece("cage_break")
	if Art.piece_texture("cage_break") != null:
		cage_front.show_strip("cave/cage_break.png", int(broke.get("frames", 4)), float(broke.get("fps", 12)), false)
		cage_front.finished.connect(func(): cage_front.show_strip("cave/cage_broken.png"), CONNECT_ONE_SHOT)
	else:
		cage_front.show_strip("cave/cage_broken.png")
	Sfx.play(self, "gate", -2.0, 1.5)
	rig.add_shake(5.0)
	_set_forge(true)
	# He steps out in front of the cage.
	var from := smith.global_position
	smith.get_parent().remove_child(smith)
	world.add_child(smith)
	smith.global_position = from
	var walk: Dictionary = Art.piece("smith_walk_down")
	if Art.piece_texture("smith_walk_down") != null:
		smith.show_strip("cave/smith_walk_down.png", int(walk.get("frames", 6)), float(walk.get("fps", 8)))
	else:
		smith.show_strip("cave/smith_idle.png", 4, 6.0)
	var tw := create_tween()
	tw.tween_property(smith, "global_position", Vector2(31.0, 13.2) * TILE - Vector2(0, StripSprite.SORT_BIAS), 0.9)
	tw.tween_callback(func():
		if not ui.talking():
			smith.show_strip("cave/smith_idle.png", 4, 6.0))
	ui.objective = "Talk to the smith"


func _talk_smith(_i: int) -> void:
	smith.show_strip("cave/smith_talk.png", 2, 6.0)
	var done := func(): smith.show_strip("cave/smith_idle.png", 4, 6.0)
	if stage == "smith":
		ui.say("Old smith", "cave/smith_portrait.png", [
			"You woke the forge. I'd stopped hoping anyone would. That thing has kept me in here since the roof came down.",
			"That stone in your sword is a rune. A rune gives your swing a new trick: yours throws a shockwave off the last hit of the chain.",
			"Bands are the other half. A band does nothing alone. It changes the next rune above it on the sword: twice, wider, and stranger things.",
			"So read a sword from the bottom of the grip up to the tip. A band boosts the rune above it. You'll find bands out there soon enough.",
			"That stick won't last on the surface. Here, take these.",
			"Tin. Soft, but it's real metal, and the blade has a slot of its own. Forge it, set your rune, and take the stairs. I'll follow when I've banked the fire.",
		], func():
			done.call()
			for o in owned:
				for part in ["tin_blade", "tin_grip"]:
					if not (part in o):
						o.append(part)
			Sfx.play(self, "pickup", -3.0)
			for p in players:
				_given(p)
			stage = "tin_card"
			ui.card("Tin blade and tin grip", "Real metal, with a slot of its own. Take them to the forge.", 0.0, func():
				stage = "tin"
				_forge_objective()))
	elif stage == "tin":
		ui.say("Old smith", "cave/smith_portrait.png", ["Blade and grip first, on the Sword tab. Then the rune. Read it from the grip up to the tip."], done)
	else:
		ui.say("Old smith", "cave/smith_portrait.png", ["Go on, up the stairs. Mind your eyes: it's bright out there."], done)


func _open_stairs() -> void:
	stage = "stairs"
	stairs.tint = Color.WHITE
	stairs.glow_on = true
	stairs.refresh()
	create_tween().tween_property(lights["stairs"], "energy", 0.8, 0.6)
	_set_brazier(2, true)
	_set_brazier(3, true)
	Sfx.play(self, "pickup", -4.0, 0.7)
	rig.add_shake(4.0)
	ui.objective = "Climb the stairs to the surface"
	ui.hint = "The stairs are in the north wall, to the right of the forge."


func _finish() -> void:
	stage = "end"
	ui.objective = ""
	ui.hint = ""
	ui.fade_out(1.6, Color(1.0, 0.98, 0.9))
	var secs := int(run_time)
	_after(1.9, func():
		ui.card_picture = "cave/ui/card_daylight.png"
		ui.card("Daylight", "You climb out into a land you have never seen.\n\nEnd of the tutorial cave.\nTime %d:%02d      Knock-outs %d" % [secs / 60, secs % 60, knockouts], 0.0, func():
			exit_to_title.emit()))


# --- Knock-outs -----------------------------------------------------------------

func _on_player_down(_p) -> void:
	knockouts += 1
	if living_players().is_empty() and not wiping and stage != "end":
		_wipe()


## Everyone is down: the room (or the boss) starts over.
func _wipe() -> void:
	wiping = true
	ui.fade_out(0.6)
	_after(1.0, _restart_room)


func _restart_room() -> void:
	for e in get_tree().get_nodes_in_group("foes"):
		if e.kind != "guardian":
			e.queue_free()
	for h in get_tree().get_nodes_in_group("hazards"):
		h.queue_free()
	var at := _room_entry(room_i)
	for i in players.size():
		players[i].get_up(at + Vector2((float(i) - float(players.size() - 1) * 0.5) * 60.0, 0), 1.0)
		players[i].hp = players[i].max_hp
		players[i].face_dir = Vector2.UP
	rig.snap()
	if stage == "boss" or stage == "boss_wake":
		guardian.queue_free()
		_spawn_guardian()
		guardian.wake()
		ui.boss = guardian
		ui.boss_shown = 1.0
		stage = "boss_wake"
		timer = Guardian.WAKE_TIME
	elif fighting:
		_start_fight(room_i, fight_plan)
	ui.fade_in(0.5)
	wiping = false
	ui.card("Knocked out", "You come round at the door. Try again.", 1.8)
	ui.card_blocks = false
