extends Node2D

const WeaponBuild := preload("res://scripts/weapon/weapon_build.gd")
const PartLibrary := preload("res://scripts/parts/part_library.gd")
## Sets up the arena, the player, enemies, the HUD and the crafting table.
## Everything is built in code so there are few scene files to merge.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const BuildMenuScript := preload("res://scripts/ui/build_menu.gd")
const Art := preload("res://scripts/art.gd")

const ARENA := Rect2(0, 0, 1800, 1100)
const WALL := 40.0
const MAX_ENEMIES := 7
const SPAWN_EVERY := 1.6

var world: Node2D
var player
var hud
var build_menu
var build: WeaponBuild
var parts: Array = []
var spawn_timer := 1.0
var spawning := true
var kills := 0


func _ready() -> void:
	randomize()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_make_walls()

	player = PlayerScript.new()
	player.position = ARENA.get_center()
	world.add_child(player)
	player.set_camera_limits(ARENA)

	var dummy = EnemyScript.new()
	dummy.kind = "dummy"
	dummy.position = ARENA.get_center() + Vector2(220, -40)
	world.add_child(dummy)

	# Weapon: starts as the plain wooden sword (slash, slash, slash).
	parts = PartLibrary.load_all()
	build = WeaponBuild.new()
	for start in [["wooden_blade", Vector2i(1, 0)], ["wooden_hilt", Vector2i(0, 3)],
			["wooden_handle", Vector2i(1, 4)], ["wooden_pommel", Vector2i(1, 6)]]:
		var part := PartLibrary.find(parts, start[0])
		if part != null:
			build.place(part, start[1], 0)
	build.changed.connect(_on_build_changed)
	_on_build_changed()

	hud = HudScript.new()
	add_child(hud)
	hud.player = player

	build_menu = BuildMenuScript.new()
	add_child(build_menu)
	build_menu.setup(build, parts)


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


func _on_enemy_died(_enemy) -> void:
	kills += 1


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


func _draw() -> void:
	var floor_tex := Art.texture("tiles/floor.png")
	var wall_tex := Art.texture("tiles/wall.png")
	if floor_tex != null or wall_tex != null:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		# Tiles are 16 art pixels, drawn at Art.PIXEL world units each.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(Art.PIXEL, Art.PIXEL))
		var outer := Rect2(ARENA.grow(WALL).position / Art.PIXEL, ARENA.grow(WALL).size / Art.PIXEL)
		var inner := Rect2(ARENA.position / Art.PIXEL, ARENA.size / Art.PIXEL)
		if wall_tex != null:
			draw_texture_rect(wall_tex, outer, true)
		else:
			draw_rect(outer, Color(0.1, 0.09, 0.12))
		if floor_tex != null:
			draw_texture_rect(floor_tex, inner, true)
		else:
			draw_rect(inner, Color(0.2, 0.24, 0.2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
