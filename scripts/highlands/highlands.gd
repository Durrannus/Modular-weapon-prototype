extends "res://scripts/game_base.gd"
## The Greystone Highlands: the land outside the cave (milestone 8).
##
## Version 35 is the land and nothing else: a map made from a seed
## (scripts/highlands/world_gen.gd), painted from the approved Highlands art
## (land_painter.gd, land_view.gd), which you walk out onto from the cave mouth.
## The base clearing and the inner ring are there. There are no enemies, no
## digging, no ore to take, no chests and no saving yet: those are the next
## versions, one at a time.
##
## You get here by climbing the stairs at the end of the tutorial cave (the weapon
## you built comes with you), or straight from the title screen (then you carry
## the arena's four test weapons and B swaps between them, as there).
##
## To see one map again, give its number:   godot --path . -- highlands seed=123456

const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const LandView := preload("res://scripts/highlands/land_view.gd")
const CaveUi := preload("res://scripts/cave/cave_ui.gd")
const Music := preload("res://scripts/music.gd")

var world_seed := 0             # 0 = a new one every time
var carry := {}                 # from the cave: {builds: [a weapon each], owned: [part ids each], spirit: [bool each]}
var map: LandMap
var land
var ui
var owned: Array = []           # per player: the part ids they can use at the forge (null = all of them)
var interactables: Array = []   # [{at, radius, text, lift, can: Callable(i), use: Callable(i)}]
var was_busy := false
var welcome := true             # show the arrival card (tests switch it off)
var music                       # the calm cave tune, standing in until the Highlands have one of their own


func _ready() -> void:
	randomize()
	if not Net.online():
		Sim.shuffle()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			world_seed = int(a.substr(5))
	if world_seed <= 0:
		world_seed = 100000 + randi() % 900000     # six figures: easy to read out
	map = WorldGen.make(world_seed)
	_make_world()
	land = LandView.new()
	land.map = map
	land.world = world
	land.rig = rig
	add_child(land)
	_add_players(map.spawn * TILE)
	land.players = players
	for i in players.size():
		players[i].face_dir = Vector2.DOWN
		players[i].auto_respawn = true
		players[i].spawn_point = players[i].position
		players[i].light.enabled = false      # the small light everyone carries in the cave: it is daylight out here
	_arm()
	rig.set_limits(Rect2(Vector2(map.region.position) * TILE, Vector2(map.region.size) * TILE), 0.0)
	rig.snap()
	land.prime()
	# The cave mouth, set into the hill north of the clearing.
	var mouth_feet := Vector2(map.mouth.x * 16 + 8, (map.mouth.y + 1) * 16)
	land.stand("cave_mouth", mouth_feet)
	interactables.append({"at": mouth_feet * Art.PIXEL + Vector2(0, 26), "radius": 74.0, "lift": 86.0, "text": "Go down to the forge",
		"can": func(_i): return true, "use": func(i): _use_forge(i)})
	_make_ui()
	hud.mode = "highlands"
	music = Music.new()
	add_child(music)
	music.play("cave_calm", 4.0)
	hud.show_weapon = can_swap
	build_menu.hotkey = false
	build_menu.sandbox = false
	pause_menu.pad_start = true
	ui = CaveUi.new()
	add_child(ui)
	ui.cam = rig.camera
	if welcome:
		ui.fade = 1.0
		ui.fade_color = Color(1.0, 0.98, 0.9)
		ui.fade_in(1.2)
		ui.card("The Greystone Highlands", "A new land, laid out differently every time.\nThis version is the land alone: nothing to fight, dig or take yet. The cave mouth leads back to your forge.\n\nWorld number %d" % world_seed)


## What everyone holds. From the cave: the weapon they built there. From the title
## screen: the arena's test weapons, all four.
func _arm() -> void:
	var got: Array = carry.get("builds", [])
	for i in players.size():
		if i < got.size() and SwingBuild.valid_data(got[i]):
			builds[i].set_data(got[i])
			builds[i].changed.emit()
			owned.append((carry.get("owned", []) as Array)[i] if i < (carry.get("owned", []) as Array).size() else null)
			players[i].with_spirit = bool((carry.get("spirit", []) as Array)[i]) if i < (carry.get("spirit", []) as Array).size() else true
		else:
			can_swap = true
			builds[i].load_test("D")
			builds[i].stowed["bow"] = SwingBuild.TEST_BOW.duplicate(true)
			builds[i].stowed["hammer"] = SwingBuild.TEST_HAMMER.duplicate(true)
			builds[i].stowed["staff"] = SwingBuild.TEST_STAFF.duplicate(true)
			owned.append(null)


## The forge is down the stairs. Until the base is built, using the cave mouth
## opens the forge screen where you stand.
func _use_forge(i: int) -> void:
	if not Net.online() or i == Net.me():
		build_menu.owned = owned[i]
	players[i].with_spirit = true
	open_forge(i)


func _swap_key_player() -> int:
	for i in players.size():
		var inp = players[i].input
		if inp.kind == "pad" and Input.is_joy_button_pressed(inp.device, JOY_BUTTON_RIGHT_STICK):
			return i
		if inp.kind == "kbm" and Input.is_physical_key_pressed(KEY_B):
			return i
	return 0


func _physics_process(delta: float) -> void:
	var pressed := false
	for p in players:
		var inp = p.input
		if inp.attack_pressed or inp.interact_pressed or (inp.using_pad and inp.dash_pressed):
			pressed = true
	ui.advance(pressed, delta)
	_tick_players()
	var busy: bool = ui.busy()
	for i in players.size():
		var p = players[i]
		p.frozen = busy or is_forging(i)
		if was_busy and not busy:
			p.need_release = true
	was_busy = busy
	ui.prompts = []
	for p in players:
		p.interact_ready = false
	if busy:
		return
	if not Net.online():
		if can_swap and Input.is_action_just_pressed("swap_weapon"):
			swap_weapon(_swap_key_player())
		if Input.is_action_just_pressed("lab") and lab_screen != null and not lab_screen.just_closed():
			open_lab()
	_update_interactions()


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
		if not shown.has(best) and (not Net.online() or i == Net.me()):
			shown[best] = true
			ui.prompts.append({"at": it["at"] - Vector2(0, float(it.get("lift", 0.0))), "text": it["text"], "pad": pad, "side": 0})
		if p.input.interact_pressed or (pad and p.input.dash_pressed):
			it["use"].call(i)
			return


func net_state() -> Array:
	return super.net_state() + [world_seed, ui.busy()]
