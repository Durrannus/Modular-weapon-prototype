extends Node2D
## What the test arena and the tutorial cave share: the world, the players and
## their swords, the shared camera, the HUD, the forge screen and the pause menu.
##
## Two players share one screen. `inputs` says who is on which device; leave it
## empty for one player on every device.

signal exit_to_title     # the game is over (the end of the cave)
signal quit_to_title     # this player chose "Back to title" in the pause menu

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
const Sim := preload("res://scripts/sim.gd")
const Net := preload("res://scripts/net/net.gd")

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
var last_forging := 0   # who had it open last (for "try at the dummy")
## Online each player has their own forge screen, so both can be at the forge at
## once. at_forge says who is; draft is the sword as this computer's screen shows
## it, a copy that is sent to both computers every time it changes.
var at_forge: Array = []
var draft: SwingBuild
var min_hp := 0.0       # tests: nobody's health drops below this
var test_commands := false   # tests: allow the "test_ko" command (knocks everyone out)


func _make_world() -> void:
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true  # things lower on screen draw in front
	add_child(world)
	# Rune effects draw on this layer, which follows the camera but isn't darkened.
	fx_layer = CanvasLayer.new()
	fx_layer.layer = 1
	fx_layer.follow_viewport_enabled = true
	fx_layer.add_to_group("fx_root")
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
		at_forge.append(false)
	player = players[0]
	build = builds[0]
	if Net.online():
		# One screen each: the camera follows this computer's player (and watches
		# their partner while they are down), and nobody is leashed to anybody.
		var me = players[mini(Net.me(), n - 1)]
		rig.targets = [me]
		rig.others = players.filter(func(q): return q != me)
		rig.leashed = false
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
	build_menu.pauses = not Net.online()
	add_child(build_menu)
	build_menu.setup(build)
	build_menu.closed.connect(_on_forge_closed)
	pause_menu = PauseMenuScript.new()
	pause_menu.pauses = not Net.online()
	pause_menu.build_menu = build_menu
	add_child(pause_menu)
	pause_menu.to_title.connect(func(): quit_to_title.emit())
	pause_menu.resumed.connect(_swallow_presses)
	draft = SwingBuild.new()
	draft.changed.connect(_on_draft_changed)
	_set_cursor()


## Puts player i's sword on the anvil and opens the forge screen.
func open_forge(i: int) -> void:
	if Net.online():
		# This runs on both computers on the same tick. Only player i's own
		# computer shows the screen; the other just knows they are at the forge.
		if at_forge[i]:
			return
		at_forge[i] = true
		if i == Net.me():
			_drafting = false
			draft.set_data(builds[i].get_data())
			_drafting = true
			forging = i
			build_menu.set_build(draft)
			build_menu.whose = ""
			build_menu.open()
		return
	if build_menu.is_open:
		return
	forging = i
	build_menu.set_build(builds[i])
	build_menu.whose = "Player %d" % (i + 1) if players.size() > 1 else ""
	build_menu.open()


var _drafting := false

## Online: the forge screen changed its copy of the sword. Send the whole sword
## to both computers; it becomes the real one on the tick it arrives.
func _on_draft_changed() -> void:
	if _drafting and Net.online():
		Net.command(["build", draft.get_data()])


## The forge screen on this computer closed.
func _on_forge_closed() -> void:
	if Net.online():
		_drafting = false
		forging = -1
		Net.command(["forge_close"])
		return
	_swallow_presses()
	last_forging = maxi(forging, 0)
	forging = -1
	_forge_done(last_forging)


## Player i has finished at the forge. The cave checks its objectives here.
func _forge_done(_i: int) -> void:
	pass


## True while player i's forge screen is open on their own computer (online).
func is_forging(i: int) -> bool:
	return Net.online() and i < at_forge.size() and at_forge[i]


## Call every tick: someone working at the forge can't be hurt (online the game
## doesn't stop for them), and the test hook for health.
func _tick_players() -> void:
	for i in players.size():
		players[i].note = "AT THE FORGE" if is_forging(i) and i != Net.me() else ""
		if is_forging(i):
			players[i].invuln = maxf(players[i].invuln, 0.2)
		if min_hp > 0.0:
			players[i].hp = maxf(players[i].hp, min_hp)


## Online: something player i chose in a menu, arriving on both computers on the
## same tick (sent with Net.command). Returns true if it was understood.
func net_command(i: int, cmd: Array) -> bool:
	if i < 0 or i >= players.size():
		return false
	match str(cmd[0]):
		"build":
			if cmd.size() == 2 and SwingBuild.valid_data(cmd[1]):
				builds[i].set_data(cmd[1])
				builds[i].changed.emit()
			return true
		"forge_close":
			if at_forge[i]:
				at_forge[i] = false
				_forge_done(i)
			return true
		"test_ko":
			if test_commands:
				for p in players:
					p.invuln = 0.0
					p.take_damage(9999.0)
			return true
	return false


## Online: the numbers that must be the same on both computers. They are
## compared every so often to catch the two games drifting apart.
func net_state() -> Array:
	var out: Array = [Sim.rng.state]
	for p in players:
		out.append_array([p.global_position, p.hp, p.is_down, p.current_step, p.step_index, p.dodge_charges, p.invuln, p.walk_vel, p.aim_dir, p.frozen])
	for b in builds:
		out.append(b.get_data())
	for e in get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			out.append_array([e.kind, e.global_position, e.hp, e.dead, e.knock])
	return out


## The click or button that closed a menu shouldn't also swing or dodge.
## (Online the session does this for this computer's own controls.)
func _swallow_presses() -> void:
	if Net.online():
		return
	for p in players:
		p.need_release = true
		p.input.clear()


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
	if Net.online():
		return Net.me()
	for i in players.size():
		var inp = players[i].input
		if inp.kind == "pad" and Input.is_joy_button_pressed(inp.device, JOY_BUTTON_Y):
			return i
		if inp.kind == "kbm" and Input.is_physical_key_pressed(KEY_TAB):
			return i
	return 0


## A light from the art's stepped set. radius is in art pixels: 48, 64, 96, 128 or 240.
func _add_light(pos: Vector2, col: Color, energy: float, radius: int) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = Art.stepped_light(radius)
	light.texture_scale = Art.PIXEL
	if light.texture == null:
		light.texture = Art.light_texture()
		light.texture_scale = float(radius) / 50.0
	light.color = col
	light.energy = energy
	light.position = pos
	add_child(light)
	return light


## A cheap repeatable "random" number per tile, so the floor looks the same every run.
static func _tile_hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(posmod(h, 1000)) / 1000.0


## A small pixel crosshair as the mouse cursor, scaled to match the pixel art.
func _set_cursor() -> void:
	var px := 9
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var ink := Color("#fff0b4")
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
