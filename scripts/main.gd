extends "res://scripts/game_base.gd"

const WeaponBuild := preload("res://scripts/weapon/weapon_build.gd")
const PartLibrary := preload("res://scripts/parts/part_library.gd")
## The test arena: one big room, a training dummy, endless enemies, and a forge
## you can open anywhere (Tab / Y) with every part unlocked.
## Everything is built in code so there are few scene files to merge.

const ARENA := Rect2(0, 0, 1792, 1088)  # 56 x 34 tiles
const WALL := 32.0  # one wall tile (16 art pixels)
## The paved forge corner, in tiles from the arena's top-left.
const FORGE_TILES := Rect2i(2, 2, 7, 5)
const MAX_ENEMIES := 7
const SPAWN_EVERY := 1.6

var parts: Array = []
var spawn_timer := 1.0
var spawning := true
var kills := 0


func _ready() -> void:
	randomize()
	_make_world()
	_make_walls()
	_make_props()
	_add_players(ARENA.get_center())
	rig.set_limits(ARENA)

	var dummy = EnemyScript.new()
	dummy.kind = "dummy"
	dummy.position = ARENA.get_center() + Vector2(220, -40)
	world.add_child(dummy)

	# Weapons: everyone starts with test sword A from the swing path notes.
	for b in builds:
		b.load_test("A")

	_make_ui()
	hud.mode = "arena"
	hud.pause_pressed.connect(func(): spawning = not spawning)
	build_menu.hotkey = false  # handled below, so each player opens their own sword
	build_menu.try_at_dummy.connect(_on_try_at_dummy)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("build") and not build_menu.is_open:
		open_forge(_forge_hotkey_player())
	if Input.is_action_just_pressed("toggle_spawning"):
		spawning = not spawning
	hud.spawning = spawning
	hud.kills = kills
	if not spawning:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = SPAWN_EVERY
		if _enemy_count() < MAX_ENEMIES + (players.size() - 1) * 4:
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
		var clear := true
		for p in players:
			if pos.distance_to(p.global_position) < 380.0:
				clear = false
		if clear:
			break
	var e = EnemyScript.new()
	e.kind = kind
	e.position = pos
	world.add_child(e)
	e.died.connect(_on_enemy_died)


## "Try at the dummy" in the forge: stand next to the dummy, facing it.
func _on_try_at_dummy() -> void:
	var who = players[maxi(forging, 0)] if forging < players.size() else player
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "dummy":
			who.global_position = e.global_position + Vector2(-110, 0)
			who.aim_dir = Vector2.RIGHT
			who.face_dir = Vector2.RIGHT
			who.reset_physics_interpolation()
			rig.snap()


func _on_enemy_died(enemy) -> void:
	kills += 1
	# Kill runes go to whoever is closest (the one who most likely struck it).
	var best = player
	for p in players:
		if p.global_position.distance_to(enemy.global_position) < best.global_position.distance_to(enemy.global_position):
			best = p
	best.on_kill(enemy.global_position)


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
