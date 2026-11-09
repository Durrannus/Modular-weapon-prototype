extends Node2D
## What the test arena and the tutorial cave share: the world, the players and
## their swords, the shared camera, the HUD, the forge screen and the pause menu.
##
## Two players share one screen. `inputs` says who is on which device; leave it
## empty for one player on every device.

signal exit_to_title

const PlayerScript := preload("res://scripts/player.gd")
const PlayerInput := preload("res://scripts/player_input.gd")
const CameraRig := preload("res://scripts/camera_rig.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const BuildMenuScript := preload("res://scripts/ui/swing_forge.gd")
const PauseMenuScript := preload("res://scripts/ui/pause_menu.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")

const TILE := 32.0  # world units per 16 px tile
const CHARACTERS := ["crew_a", "crew_b"]

var inputs: Array = []
var world: Node2D
var fx_layer: CanvasLayer
var rig
var players: Array = []
var builds: Array = []
var player              # player one
var build: SwingBuild   # player one's sword
var hud
var build_menu
var pause_menu
var forging := -1       # which player has the forge open (-1 = nobody)


func _make_world() -> void:
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true  # things lower on screen draw in front
	add_child(world)
	# Rune effects draw on this layer, which follows the camera but isn't darkened.
	fx_layer = CanvasLayer.new()
	fx_layer.layer = 1
	fx_layer.follow_viewport_enabled = true
	add_child(fx_layer)
	rig = CameraRig.new()
	add_child(rig)


func _add_players(at: Vector2) -> void:
	if inputs.is_empty():
		inputs = [PlayerInput.new()]
	var n := inputs.size()
	for i in n:
		var p = PlayerScript.new()
		p.input = inputs[i]
		p.index = i
		p.character = CHARACTERS[i % CHARACTERS.size()]
		p.fx_parent = fx_layer
		p.rig = rig
		p.show_marker = n > 1
		p.position = at + Vector2((float(i) - float(n - 1) * 0.5) * 60.0, 0.0)
		world.add_child(p)
		p.knocked_out.connect(_on_player_down)
		players.append(p)
		rig.targets.append(p)
		var b := SwingBuild.new()
		b.changed.connect(_on_build_changed.bind(i))
		builds.append(b)
	player = players[0]
	build = builds[0]
	rig.global_position = at
	rig.snap()


func _on_build_changed(i: int) -> void:
	players[i].set_weapon(builds[i].compute())


func _make_ui() -> void:
	hud = HudScript.new()
	add_child(hud)
	hud.players = players
	hud.player = player
	build_menu = BuildMenuScript.new()
	add_child(build_menu)
	build_menu.setup(build)
	build_menu.closed.connect(_on_forge_closed)
	pause_menu = PauseMenuScript.new()
	pause_menu.build_menu = build_menu
	add_child(pause_menu)
	pause_menu.to_title.connect(func(): exit_to_title.emit())
	_set_cursor()


## Puts player i's sword on the anvil and opens the forge screen.
func open_forge(i: int) -> void:
	if build_menu.is_open:
		return
	forging = i
	build_menu.set_build(builds[i])
	build_menu.whose = "Player %d" % (i + 1) if players.size() > 1 else ""
	build_menu.open()


func _on_forge_closed() -> void:
	# The click or key that closed the forge shouldn't also swing or dodge.
	for p in players:
		p.need_release = true
		p.input.clear()
	forging = -1


## A player's health reached zero.
func _on_player_down(_p) -> void:
	pass


func living_players() -> Array:
	var out: Array = []
	for p in players:
		if not p.is_down:
			out.append(p)
	return out


## Lets the forge hotkey (Tab / Y) open the right player's sword.
func _forge_hotkey_player() -> int:
	for i in players.size():
		var inp = players[i].input
		if inp.kind == "pad" and Input.is_joy_button_pressed(inp.device, JOY_BUTTON_Y):
			return i
		if inp.kind == "kbm" and Input.is_physical_key_pressed(KEY_TAB):
			return i
	return 0


func _add_light(pos: Vector2, col: Color, energy: float, size: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = Art.light_texture()
	light.texture_scale = size
	light.color = col
	light.energy = energy
	light.position = pos
	add_child(light)
	return light


## A cheap repeatable "random" number per tile, so the floor looks the same every run.
static func _tile_hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(posmod(h, 1000)) / 1000.0


## F11 or Alt+Enter switches between fullscreen (the default) and a window.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()


## A small pixel crosshair as the mouse cursor, scaled to match the pixel art.
func _set_cursor() -> void:
	var px := 9
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var ink := Color("#fff3c4")
	var edge := Color(0.05, 0.04, 0.06)
	for i in px:
		for j in px:
			var on := (i == 4 and (j <= 2 or j >= 6)) or (j == 4 and (i <= 2 or i >= 6))
			var dot := i == 4 and j == 4
			if on or dot:
				img.set_pixel(i, j, ink)
	# A dark outline so it reads on any floor.
	var out := img.duplicate()
	for i in px:
		for j in px:
			if img.get_pixel(i, j).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(i, j) + o
				if q.x >= 0 and q.y >= 0 and q.x < px and q.y < px and img.get_pixelv(q).a > 0.0:
					out.set_pixel(i, j, edge)
	var scale := maxi(int(DisplayServer.screen_get_size().y / 360), 1)
	out.resize(px * scale, px * scale, Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(out), Input.CURSOR_ARROW, Vector2(px * scale / 2, px * scale / 2))
