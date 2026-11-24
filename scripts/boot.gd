extends Node
## The game's front door: shows the title screen, then runs the mode you pick
## (the tutorial cave, the Highlands or the test arena) and comes back here when it
## ends. The cave's stairs lead out onto the Highlands.
## The Highlands are played with a saved character in a saved world (scripts/save.gd):
## the title's Highlands row goes to the screen where both are picked
## (scripts/ui/save_pick.gd) first, and the cave's stairs make a new character
## for each player, with what they built, and a new world.
## "Play online" goes to the host / join screen first; the online session
## (scripts/net/session.gd) then tells both computers when to start the game.
##
## To skip the title while testing, add a mode after "--":
##   godot --path . -- cave        (or: arena, or: highlands seed=123456)

const Title := preload("res://scripts/ui/title.gd")
const Cave := preload("res://scripts/cave/cave.gd")
const Arena := preload("res://scripts/main.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const OnlineMenu := preload("res://scripts/ui/online_menu.gd")
const Session := preload("res://scripts/net/session.gd")
const Net := preload("res://scripts/net/net.gd")
const PlayerInput := preload("res://scripts/player_input.gd")
const Lab := preload("res://scripts/lab.gd")
const SavePick := preload("res://scripts/ui/save_pick.gd")
const Save := preload("res://scripts/save.gd")
const Forging := preload("res://scripts/ui/forging.gd")

var title
var game
var online_menu
var pick           # the screen where a character and a world are picked
var forging        # "Forging the land...", while a Highlands world is made
var opening := 0   # raised whenever the screen changes: a world still waiting to be made is not made after all
var last_inputs: Array = []
var notice := ""   # shown once on the title screen ("Your friend left the game.")


func _ready() -> void:
	# The lab's numbers (scripts/lab.gd), if this computer has changed any.
	Lab.start()
	var args := OS.get_cmdline_user_args()
	if "cave" in args:
		_start("cave", [])
	elif "arena" in args:
		_start("arena", [])
	elif "highlands" in args:
		_start("highlands", [])
	else:
		_show_title()


func _clear() -> void:
	opening += 1
	for n in [title, game, online_menu, pick, forging]:
		if is_instance_valid(n):
			n.queue_free()
	title = null
	game = null
	online_menu = null
	pick = null
	forging = null


func _show_title() -> void:
	get_tree().paused = false
	Lab.set_in_force(true)
	_clear()
	title = Title.new()
	title.notice = notice
	notice = ""
	add_child(title)
	title.set_joined(last_inputs)
	title.start.connect(_chosen)


## A row of the title screen was picked.
func _chosen(mode: String, inputs: Array) -> void:
	if mode == "highlands":
		_show_pick(inputs)
	else:
		_start(mode, inputs)


## Before the Highlands: who plays which character, and in which world.
func _show_pick(inputs: Array) -> void:
	last_inputs = inputs
	_clear()
	pick = SavePick.new()
	pick.inputs = inputs
	pick.back.connect(_show_title, CONNECT_DEFERRED)
	pick.chosen.connect(func(characters: Array, world: Dictionary):
		_start("highlands", last_inputs, {}, {"characters": characters, "world": world}), CONNECT_DEFERRED)
	add_child(pick)


## Up the cave's stairs: each player becomes a new saved character, with what they built down there, in a new world.
func _out_of_cave(what: Dictionary) -> void:
	var characters: Array = []
	var given: Array = []
	for i in maxi((what.get("builds", []) as Array).size(), 1):
		var c := Save.fresh(Save.CHARACTERS, given)
		given.append(c["id"])
		characters.append(c)
	_start("highlands", last_inputs, what, {"characters": characters, "world": Save.fresh(Save.WORLDS)})


## `saves` (the Highlands): {characters: [a saved character for each player], world: the saved world}. Without it
## nothing is saved (`-- highlands` on the command line).
func _start(mode: String, inputs: Array, carry := {}, saves := {}) -> void:
	if mode == "online":
		_show_online()
		return
	last_inputs = inputs
	_clear()
	if mode == "highlands":
		# Making the land takes a few seconds, all at once: "Forging the land..." is on the screen meanwhile.
		var ticket := opening
		var w: Dictionary = saves.get("world", {})
		forging = Forging.new()
		forging.world_name = str(w.get("name", "")) if not w.get("unsaved", false) else ""
		forging.older = not w.is_empty() and SavePick.older_land(w)
		add_child(forging)
		await get_tree().process_frame
		await get_tree().process_frame
		if ticket != opening:
			return
	game = {"cave": Cave, "highlands": Highlands}.get(mode, Arena).new()
	game.inputs = inputs
	if mode == "cave":
		# The stairs at the end of the cave lead out onto the Highlands, with what you built.
		game.leads_outside = true
		game.go_outside.connect(_out_of_cave, CONNECT_DEFERRED)
	elif mode == "highlands":
		game.carry = carry
		game.characters = saves.get("characters", [])
		game.world_save = saves.get("world", {})
	game.exit_to_title.connect(_show_title, CONNECT_DEFERRED)
	game.quit_to_title.connect(_show_title, CONNECT_DEFERRED)
	add_child(game)
	if is_instance_valid(forging):
		forging.queue_free()
		forging = null


# --- Online -----------------------------------------------------------------------

func _show_online() -> void:
	get_tree().paused = false
	# Online, both computers play with the game's own numbers, never the lab's.
	Lab.set_in_force(false)
	_clear()
	if not is_instance_valid(Net.session):
		var s := Session.new()
		get_tree().root.add_child(s)
		Net.session = s
		s.start_game.connect(_start_online)
		s.ended.connect(_on_session_ended)
	online_menu = OnlineMenu.new()
	online_menu.session = Net.session
	online_menu.back.connect(_leave_online)
	add_child(online_menu)


## Both computers get this at the same moment in the game's time: make the same
## game, with both players' controls coming from the session.
func _start_online(mode: String) -> void:
	Lab.set_in_force(false)
	_clear()
	game = (Cave if mode == "cave" else Arena).new()
	game.inputs = [PlayerInput.make("net"), PlayerInput.make("net")]
	game.exit_to_title.connect(_online_game_over, CONNECT_DEFERRED)
	game.quit_to_title.connect(_leave_online, CONNECT_DEFERRED)
	add_child(game)
	Net.session.attach(game)


## The game ended for both players (the end of the cave): back to the lobby,
## still connected.
func _online_game_over() -> void:
	if is_instance_valid(Net.session):
		Net.session.stop_game()
		_show_online()
	else:
		_show_title()


## This player backed out: the session ends, and the other player is told.
func _leave_online() -> void:
	if is_instance_valid(Net.session):
		Net.session.leave("")
	else:
		_show_title()


func _on_session_ended(reason: String) -> void:
	notice = reason
	_show_title()
