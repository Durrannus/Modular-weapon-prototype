extends Node2D

const WeaponBuild := preload("res://scripts/weapon/weapon_build.gd")
const PartLibrary := preload("res://scripts/parts/part_library.gd")
## Sets up the arena, the player, enemies, the HUD and the crafting table.
## Everything is built in code so there are few scene files to merge.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const BuildMenuScript := preload("res://scripts/ui/swing_forge.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Art := preload("res://scripts/art.gd")

const ARENA := Rect2(0, 0, 1792, 1088)  # 56 x 34 tiles
const WALL := 32.0  # one wall tile (16 art pixels)
const TILE := 32.0  # world units per 16 px tile
## The paved forge corner, in tiles from the arena's top-left.
const FORGE_TILES := Rect2i(2, 2, 7, 5)
const MAX_ENEMIES := 7
const SPAWN_EVERY := 1.6

var world: Node2D
var player
var hud
var build_menu
var pause_menu
var build: SwingBuild
var parts: Array = []
var spawn_timer := 1.0
var spawning := true
var kills := 0


func _ready() -> void:
	randomize()
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true  # things lower on screen draw in front
	add_child(world)
	_make_walls()
	_make_props()

	# Rune effects draw on this layer, which follows the camera but isn't darkened.
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 1
	fx_layer.follow_viewport_enabled = true
	add_child(fx_layer)

	player = PlayerScript.new()
	player.fx_parent = fx_layer
	player.position = ARENA.get_center()
	world.add_child(player)
	player.set_camera_limits(ARENA)

	var dummy = EnemyScript.new()
	dummy.kind = "dummy"
	dummy.position = ARENA.get_center() + Vector2(220, -40)
	world.add_child(dummy)

	# Weapon: starts as test sword A from the swing path notes.
	build = SwingBuild.new()
	build.load_test("A")
	build.changed.connect(_on_build_changed)
	_on_build_changed()

	hud = HudScript.new()
	add_child(hud)
	hud.player = player
	hud.pause_pressed.connect(func(): spawning = not spawning)

	build_menu = BuildMenuScript.new()
	add_child(build_menu)
	pause_menu = preload("res://scripts/ui/pause_menu.gd").new()
	pause_menu.build_menu = build_menu
	add_child(pause_menu)
	build_menu.setup(build)
	build_menu.try_at_dummy.connect(_on_try_at_dummy)


func _on_build_changed() -> void:
	player.set_weapon(build.compute())


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_spawning"):
		spawning = not spawning
	hud.spawning = spawning
	hud.kills = kills
	if not spawning:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = SPAWN_EVERY
		if _enemy_count() < MAX_ENEMIES:
			_spawn_enemy()


func _enemy_count() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind != "dummy" and not e.dead:
			n += 1
	return n


func _spawn_enemy() -> void:
	var roll := randf()
	var kind := "slime"
	if roll > 0.85:
		kind = "brute"
	elif roll > 0.6:
		kind = "charger"
	var pos := Vector2.ZERO
	for i in 12:
		pos = Vector2(
			randf_range(ARENA.position.x + 60.0, ARENA.end.x - 60.0),
			randf_range(ARENA.position.y + 60.0, ARENA.end.y - 60.0))
		if pos.distance_to(player.global_position) > 380.0:
			break
	var e = EnemyScript.new()
	e.kind = kind
	e.position = pos
	world.add_child(e)
	e.died.connect(_on_enemy_died)


## "Try at the dummy" in the forge: stand next to the dummy, facing it.
func _on_try_at_dummy() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "dummy":
			player.global_position = e.global_position + Vector2(-110, 0)
			player.aim_dir = Vector2.RIGHT
			player.camera.reset_smoothing()


func _on_enemy_died(enemy) -> void:
	kills += 1
	player.on_kill(enemy.global_position)


func _make_walls() -> void:
	var r := ARENA
	var rects := [
		Rect2(r.position.x - WALL, r.position.y - WALL, r.size.x + WALL * 2.0, WALL),
		Rect2(r.position.x - WALL, r.end.y, r.size.x + WALL * 2.0, WALL),
		Rect2(r.position.x - WALL, r.position.y, WALL, r.size.y),
		Rect2(r.end.x, r.position.y, WALL, r.size.y),
	]
	for rect in rects:
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		world.add_child(body)


func _make_props() -> void:
	# Forge-lit look: darken everything, then warm lights on torches and the bench.
	if Art.texture("tiles/floor.png") != null:
		var dark := CanvasModulate.new()
		dark.color = Color(0.78, 0.79, 0.92)
		add_child(dark)
	var bench_pos := ARENA.position + (Vector2(FORGE_TILES.get_center()) + Vector2(0, 0.5)) * TILE
	_add_prop("props/forge_bench.png", bench_pos, Vector2(23, 30))
	_add_light(bench_pos + Vector2(0, -20), Color(1.0, 0.62, 0.3), 1.0, 2.2)
	var bench_body := StaticBody2D.new()
	bench_body.collision_layer = 4
	bench_body.position = bench_pos + Vector2(0, -10)
	var bench_shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(80, 24)
	bench_shape.shape = box
	bench_body.add_child(bench_shape)
	world.add_child(bench_body)
	var x := ARENA.position.x + 360.0
	while x < ARENA.end.x - 100.0:
		var torch_pos := Vector2(x, ARENA.position.y + 6.0)
		_add_prop("props/torch.png", torch_pos, Vector2(4, 34))
		_add_light(torch_pos + Vector2(0, -60), Color(1.0, 0.7, 0.4), 1.1, 2.6)
		x += 520.0


func _add_prop(path: String, feet: Vector2, origin: Vector2) -> void:
	var tex := Art.texture(path)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = -origin
	sprite.scale = Vector2(Art.PIXEL, Art.PIXEL)
	sprite.position = feet
	world.add_child(sprite)


func _add_light(pos: Vector2, col: Color, energy: float, size: float) -> void:
	var light := PointLight2D.new()
	light.texture = Art.light_texture()
	light.texture_scale = size
	light.color = col
	light.energy = energy
	light.position = pos
	add_child(light)


## A cheap repeatable "random" number per tile, so the floor looks the same every run.
static func _tile_hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(posmod(h, 1000)) / 1000.0


func _draw() -> void:
	var floor_tex := Art.texture("tiles/floor.png")
	if floor_tex != null:
		_draw_tiles()
		return
	draw_rect(ARENA.grow(WALL), Color(0.1, 0.09, 0.12))
	draw_rect(ARENA, Color(0.2, 0.24, 0.2))
	var step := 100.0
	var x := ARENA.position.x
	while x <= ARENA.end.x:
		draw_line(Vector2(x, ARENA.position.y), Vector2(x, ARENA.end.y), Color(1, 1, 1, 0.04), 1.0)
		x += step
	var y := ARENA.position.y
	while y <= ARENA.end.y:
		draw_line(Vector2(ARENA.position.x, y), Vector2(ARENA.end.x, y), Color(1, 1, 1, 0.04), 1.0)
		y += step


func _draw_tiles() -> void:
	var size := Vector2(TILE, TILE)
	draw_rect(ARENA.grow(200.0), Color(0.03, 0.03, 0.05))
	var cols := int(ARENA.size.x / TILE)
	var rows := int(ARENA.size.y / TILE)
	var variants := [Art.texture("tiles/floor.png"), Art.texture("tiles/floor_1.png"), Art.texture("tiles/floor_2.png")]
	var flag := Art.texture("tiles/floor_3.png")
	for ty in rows:
		for tx in cols:
			var tex: Texture2D = variants[0]
			var r := _tile_hash(tx, ty)
			if FORGE_TILES.has_point(Vector2i(tx, ty)) and flag != null:
				tex = flag
			elif r < 0.06 and variants[1] != null:
				tex = variants[1]
			elif r < 0.12 and variants[2] != null:
				tex = variants[2]
			draw_texture_rect(tex, Rect2(ARENA.position + Vector2(tx, ty) * TILE, size), false)
	# Walls: one tile thick all round, plus capstones above the north wall.
	var wall := Art.texture("tiles/wall.png")
	var top := Art.texture("tiles/wall_top.png")
	if wall == null:
		return
	for tx in range(-1, cols + 1):
		var px := ARENA.position.x + tx * TILE
		if top != null:
			draw_texture_rect(top, Rect2(Vector2(px, ARENA.position.y - TILE * 2.0), size), false)
		draw_texture_rect(wall, Rect2(Vector2(px, ARENA.position.y - TILE), size), false)
		draw_texture_rect(wall, Rect2(Vector2(px, ARENA.end.y), size), false)
	for ty in rows:
		var py := ARENA.position.y + ty * TILE
		draw_texture_rect(wall, Rect2(Vector2(ARENA.position.x - TILE, py), size), false)
		draw_texture_rect(wall, Rect2(Vector2(ARENA.end.x, py), size), false)


## F11 or Alt+Enter switches between fullscreen (the default) and a window.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
