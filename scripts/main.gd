extends "res://scripts/game_base.gd"

const WeaponBuild := preload("res://scripts/weapon/weapon_build.gd")
const PartLibrary := preload("res://scripts/parts/part_library.gd")
const Crawler := preload("res://scripts/cave/crawler.gd")
const Burrower := preload("res://scripts/cave/burrower.gd")
const Guardian := preload("res://scripts/cave/guardian.gd")
## The test arena: one big room, a training dummy, endless enemies, and a forge
## you can open anywhere (Tab / Y) with every part unlocked. It is a room for
## trying weapons out, so nobody can be hurt in it unless they ask to be (H / Select
## switches "Invincible"), P / Start stops the enemies where they stand, and
## B / a click of the right stick swaps your sword for your bow and back.
## L / a click of the left stick opens the lab: the game's numbers, and a page
## that puts any enemy in the room (15 November).
## Everything is built in code so there are few scene files to merge.

const ARENA := Rect2(0, 0, 1792, 1088)  # 56 x 34 tiles
const WALL := 32.0  # one wall tile (16 art pixels)
## The paved forge corner, in tiles from the arena's top-left.
const FORGE_TILES := Rect2i(2, 2, 7, 5)
static var MAX_ENEMIES := 7
const WARM := Color(1.0, 0.60, 0.28)
static var SPAWN_EVERY := 1.6

var parts: Array = []
var spawn_timer := 1.0
var spawning := true         # new enemies keep arriving (tests switch this off)
var enemies_paused := false  # "Pause enemies": none arrive, and the ones here stand still and hurt nobody
var invincible := true       # nobody can be hurt
var kills := 0

## Every enemy in the game, for the lab's Spawn page: [kind, its name, a few words].
const SPAWNABLE := [
	["slime", "Small crab", "Walks at you"],
	["charger", "Horned crab", "Winds up, then charges"],
	["brute", "Big crab", "Slow and tough"],
	["crawler", "Cave crawler", "Rears up, then bites"],
	["burrower", "Cave burrower", "Digs under, comes up and lunges"],
	["guardian", "Forge guardian", "The tutorial cave's boss"],
	["dummy", "Training dummy", "Never moves, shows your damage"],
]
var home_dummy = null        # the dummy the room starts with ("Remove every enemy" leaves it)
var suits: Array = []        # guardians beaten here: [the empty suit, seconds until it is cleared away]


func _ready() -> void:
	randomize()
	if not Net.online():
		Sim.shuffle()
	var floor_node := Node2D.new()
	floor_node.z_index = -10
	floor_node.draw.connect(func(): _draw_floor(floor_node))
	add_child(floor_node)
	_make_world()
	_make_walls()
	_make_props()
	_add_players(ARENA.get_center())
	rig.set_limits(ARENA)

	var dummy = EnemyScript.new()
	dummy.kind = "dummy"
	dummy.position = ARENA.get_center() + Vector2(220, -40)
	world.add_child(dummy)
	home_dummy = dummy

	# Weapons: everyone starts with test sword D: the sword's active runes, one on
	# each button, and the passive ones beside them. A and B are the 3 November
	# test swords, C is two actives and Shockwave; keys 1 to 4 at the forge load
	# A to D.
	# Everyone also carries a test bow, hammer and staff (B swaps round the four):
	# an iron shortbow with iron arrows, an iron maul and an iron apprentice staff
	# with an iron-bound crystal, the iron sword's matches.
	can_swap = true
	for b in builds:
		b.load_test("D")
		b.stowed["bow"] = SwingBuild.TEST_BOW.duplicate(true)
		b.stowed["hammer"] = SwingBuild.TEST_HAMMER.duplicate(true)
		b.stowed["staff"] = SwingBuild.TEST_STAFF.duplicate(true)

	_make_ui()
	hud.mode = "arena"
	hud.show_weapon = true
	hud.pause_pressed.connect(_toggle_paused)
	hud.invincible_pressed.connect(_toggle_invincible)
	hud.swap_pressed.connect(func(): _swap_weapon(mini(Net.me(), players.size() - 1)))
	hud.lab_pressed.connect(open_lab)
	hud.has_lab = lab_screen != null
	build_menu.hotkey = false  # handled below, so each player opens their own sword
	build_menu.try_at_dummy.connect(_on_try_at_dummy)


## The two switches. Online a switch is sent to both computers and flips on the
## same tick there (see net_command below).
func _toggle_paused() -> void:
	if Net.online():
		Net.command(["pause_enemies"])
	else:
		_set_paused(not enemies_paused)


func _toggle_invincible() -> void:
	if Net.online():
		Net.command(["invincible"])
	else:
		_set_invincible(not invincible)


## The next weapon. Online it is sent to both computers, like the switches.
func _swap_weapon(i: int) -> void:
	if Net.online():
		Net.command(["weapon"])
	else:
		swap_weapon(i)


## Whose swap key went down: the keyboard's player or that controller's.
func _swap_key_player() -> int:
	for i in players.size():
		var inp = players[i].input
		if inp.kind == "pad" and Input.is_joy_button_pressed(inp.device, JOY_BUTTON_RIGHT_STICK):
			return i
		if inp.kind == "kbm" and Input.is_physical_key_pressed(KEY_B):
			return i
	return 0


func _set_paused(on: bool) -> void:
	enemies_paused = on
	_hold_enemies()


## Everyone here now stands still (or wakes up again). Called every tick too, so
## an enemy that arrives some other way while they are paused is held as well.
func _hold_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.held = enemies_paused and e.kind != "dummy"   # the dummy never does anything anyway


## Switching it on also tops everyone's health back up.
func _set_invincible(on: bool) -> void:
	invincible = on
	for p in players:
		p.unhurt = on
		if on:
			p.hp = p.max_hp


## Online, the forge key and the two switches' keys are sent to both computers.
func _input(event: InputEvent) -> void:
	if not Net.online():
		return
	if event.is_action_pressed("build") and not build_menu.is_open and not pause_menu.is_open():
		Net.command(["forge_open"])
	elif event.is_action_pressed("toggle_spawning"):
		Net.command(["pause_enemies"])
	elif event.is_action_pressed("toggle_invincible") and not build_menu.is_open:   # Select means "next preset" at the forge
		Net.command(["invincible"])
	elif event.is_action_pressed("swap_weapon") and not build_menu.is_open and not pause_menu.is_open():
		Net.command(["weapon"])


func net_command(i: int, cmd: Array) -> bool:
	if super.net_command(i, cmd):
		return true
	match str(cmd[0]):
		"forge_open":
			open_forge(i)
		"pause_enemies":
			_set_paused(not enemies_paused)
		"invincible":
			_set_invincible(not invincible)
		"try_dummy":
			_stand_at_dummy(i)
		_:
			return false
	return true


func net_state() -> Array:
	return super.net_state() + [kills, spawning, enemies_paused, invincible, spawn_timer]


func _physics_process(delta: float) -> void:
	_tick_players()
	if not Net.online():
		if Input.is_action_just_pressed("build") and not build_menu.is_open:
			open_forge(_forge_hotkey_player())
		if Input.is_action_just_pressed("toggle_spawning"):
			_set_paused(not enemies_paused)
		if Input.is_action_just_pressed("toggle_invincible"):
			_set_invincible(not invincible)
		if Input.is_action_just_pressed("swap_weapon"):
			swap_weapon(_swap_key_player())
		if Input.is_action_just_pressed("lab") and lab_screen != null and not lab_screen.just_closed():
			open_lab()
	_hold_enemies()
	for p in players:
		p.unhurt = invincible
	hud.enemies_paused = enemies_paused
	hud.invincible = invincible
	hud.kills = kills
	hud.spawning = spawning
	_tick_suits(delta)
	if not spawning or enemies_paused:
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
	var roll := Sim.chance()
	var kind := "slime"
	if roll > 0.85:
		kind = "brute"
	elif roll > 0.6:
		kind = "charger"
	var pos := Vector2.ZERO
	for i in 12:
		pos = Vector2(
			Sim.between(ARENA.position.x + 60.0, ARENA.end.x - 60.0),
			Sim.between(ARENA.position.y + 60.0, ARENA.end.y - 60.0))
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


# --- The lab's spawner ------------------------------------------------------------
# Darren, 15 November: "allow me to spawn any enemy to the arena I want so I can
# test". The lab's Spawn page calls these. (The lab is not there online.)

## Puts `count` of one kind of enemy in the room, near player one. The cave's
## enemies and its boss work here as they do there: the guardian is awake at
## once, keeps to this room, and shows a health bar over his head.
func spawn_enemies(kind: String, count := 1) -> Array:
	var out: Array = []
	for n in count:
		var e
		match kind:
			"crawler":
				e = Crawler.new()
			"burrower":
				e = Burrower.new()
			"guardian":
				e = Guardian.new()
				e.team = players.size()
			_:
				e = EnemyScript.new()
				e.kind = kind
		e.position = _spot_near_player(280.0 if kind == "guardian" else 200.0)
		world.add_child(e)
		if kind == "guardian":
			e.room = ARENA
			e.show_bar = true
			e.wake()
		if kind != "dummy":
			e.died.connect(_on_enemy_died)
		out.append(e)
	_hold_enemies()
	return out


## Somewhere inside the walls, at least `far` from everyone.
func _spot_near_player(far: float) -> Vector2:
	var inside := ARENA.grow(-70.0)
	var centre: Vector2 = player.global_position
	var pos := centre
	for tries in 16:
		pos = centre + Vector2.from_angle(Sim.between(0.0, TAU)) * Sim.between(far, far + 120.0)
		var ok := inside.has_point(pos)
		for p in players:
			if pos.distance_to(p.global_position) < far - 1.0:
				ok = false
		if ok:
			return pos
	return Vector2(clampf(pos.x, inside.position.x, inside.end.x), clampf(pos.y, inside.position.y, inside.end.y))


## Empties the room: every enemy but the dummy it started with, whatever the
## guardian has left on the floor, and any empty suits.
func clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("foes"):
		if e != home_dummy:
			e.remove_from_group("enemies")
			e.remove_from_group("foes")
			e.queue_free()
	for h in get_tree().get_nodes_in_group("hazards"):
		h.queue_free()
	for s in suits:
		if is_instance_valid(s[0]):
			s[0].queue_free()
	suits = []


## How many enemies are in the room (the dummies don't count).
func enemy_total() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("foes"):
		if e.kind != "dummy" and not e.dead and not e.is_queued_for_deletion():
			n += 1
	return n


## A guardian beaten here leaves his empty suit for a few seconds, then it goes.
func _tick_suits(delta: float) -> void:
	for s in suits:
		s[1] = float(s[1]) - delta
	for s in suits.duplicate():
		if float(s[1]) <= 0.0:
			if is_instance_valid(s[0]):
				s[0].queue_free()
			suits.erase(s)


## "Try at the dummy" in the forge: stand next to the dummy, facing it.
func _on_try_at_dummy() -> void:
	if Net.online():
		Net.command(["try_dummy"])
	else:
		_stand_at_dummy(last_forging)


func _stand_at_dummy(i: int) -> void:
	var who = players[i] if i < players.size() else player
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "dummy":
			who.global_position = e.global_position + Vector2(-110, 0)
			who.aim_dir = Vector2.RIGHT
			who.face_dir = Vector2.RIGHT
			who.reset_physics_interpolation()
			if who in rig.targets:
				rig.snap()


func _on_enemy_died(enemy) -> void:
	kills += 1
	if enemy.kind == "guardian":
		suits.append([enemy, 6.0])
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
	# The same look as the cave, but brighter (this is the test room): a cool dark
	# tint, then warm stepped lights on the torches and the bench.
	if Art.texture("tiles/floor.png") != null:
		var dark := CanvasModulate.new()
		dark.color = Color(0.68, 0.71, 0.90)
		add_child(dark)
	var bench_pos := ARENA.position + (Vector2(FORGE_TILES.get_center()) + Vector2(0, 0.5)) * TILE
	_add_prop("props/forge_bench.png", bench_pos, Vector2(23, 30))
	_add_light(bench_pos + Vector2(0, -20), WARM, 0.8, 96)
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
		_add_light(torch_pos + Vector2(0, -56), WARM, 1.0, 128)
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
	# Flames and embers stay bright whatever the lighting.
	var glow_tex := Art.glow_texture(path)
	if glow_tex != null:
		var glow := Sprite2D.new()
		glow.texture = glow_tex
		glow.centered = false
		glow.offset = -origin
		glow.material = Art.unshaded()
		sprite.add_child(glow)


## The floor is drawn on its own node under everything, so warnings painted on
## the ground (z -5) show on top of it.
func _draw_floor(ci: CanvasItem) -> void:
	# One painted picture of the whole room (floor, walls, the forge corner's
	# flagstones and a sparring ring), like the cave's ground.
	var ground := Art.piece_texture("arena_ground")
	if ground != null:
		var o: Array = Art.piece("arena_ground").get("origin", [16, 48])
		ci.draw_rect(ARENA.grow(400.0), Color("#19142a"))
		ci.draw_texture_rect(ground, Rect2(ARENA.position - Vector2(o[0], o[1]) * Art.PIXEL, ground.get_size() * Art.PIXEL), false)
		return
	var floor_tex := Art.texture("tiles/floor.png")
	if floor_tex != null:
		_draw_tiles(ci)
		return
	ci.draw_rect(ARENA.grow(WALL), Color(0.1, 0.09, 0.12))
	ci.draw_rect(ARENA, Color(0.2, 0.24, 0.2))
	var step := 100.0
	var x := ARENA.position.x
	while x <= ARENA.end.x:
		ci.draw_line(Vector2(x, ARENA.position.y), Vector2(x, ARENA.end.y), Color(1, 1, 1, 0.04), 1.0)
		x += step
	var y := ARENA.position.y
	while y <= ARENA.end.y:
		ci.draw_line(Vector2(ARENA.position.x, y), Vector2(ARENA.end.x, y), Color(1, 1, 1, 0.04), 1.0)
		y += step


func _draw_tiles(ci: CanvasItem) -> void:
	var size := Vector2(TILE, TILE)
	ci.draw_rect(ARENA.grow(200.0), Color(0.03, 0.03, 0.05))
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
			ci.draw_texture_rect(tex, Rect2(ARENA.position + Vector2(tx, ty) * TILE, size), false)
	# Walls: one tile thick all round, plus capstones above the north wall.
	var wall := Art.texture("tiles/wall.png")
	var top := Art.texture("tiles/wall_top.png")
	if wall == null:
		return
	for tx in range(-1, cols + 1):
		var px := ARENA.position.x + tx * TILE
		if top != null:
			ci.draw_texture_rect(top, Rect2(Vector2(px, ARENA.position.y - TILE * 2.0), size), false)
		ci.draw_texture_rect(wall, Rect2(Vector2(px, ARENA.position.y - TILE), size), false)
		ci.draw_texture_rect(wall, Rect2(Vector2(px, ARENA.end.y), size), false)
	for ty in rows:
		var py := ARENA.position.y + ty * TILE
		ci.draw_texture_rect(wall, Rect2(Vector2(ARENA.position.x - TILE, py), size), false)
		ci.draw_texture_rect(wall, Rect2(Vector2(ARENA.end.x, py), size), false)
