extends Node
## The game's front door: shows the title screen, then runs the mode you pick
## (the tutorial cave or the test arena) and comes back here when it ends.
## "Play online" goes to the host / join screen first; the online session
## (scripts/net/session.gd) then tells both computers when to start the game.
##
## To skip the title while testing, add a mode after "--":
##   godot --path . -- cave        (or: arena)

const Title := preload("res://scripts/ui/title.gd")
const Cave := preload("res://scripts/cave/cave.gd")
const Arena := preload("res://scripts/main.gd")
const OnlineMenu := preload("res://scripts/ui/online_menu.gd")
const Session := preload("res://scripts/net/session.gd")
const Net := preload("res://scripts/net/net.gd")
const PlayerInput := preload("res://scripts/player_input.gd")

var title
var game
var online_menu
var last_inputs: Array = []
var notice := ""   # shown once on the title screen ("Your friend left the game.")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "cave" in args:
		_start("cave", [])
	elif "arena" in args:
		_start("arena", [])
	else:
		_show_title()


func _clear() -> void:
	for n in [title, game, online_menu]:
		if is_instance_valid(n):
			n.queue_free()
	title = null
	game = null
	online_menu = null


func _show_title() -> void:
	get_tree().paused = false
	_clear()
	title = Title.new()
	title.notice = notice
	notice = ""
	add_child(title)
	title.set_joined(last_inputs)
	title.start.connect(_start)


func _start(mode: String, inputs: Array) -> void:
	if mode == "online":
		_show_online()
		return
	last_inputs = inputs
	_clear()
	game = (Cave if mode == "cave" else Arena).new()
	game.inputs = inputs
	game.exit_to_title.connect(_show_title, CONNECT_DEFERRED)
	game.quit_to_title.connect(_show_title, CONNECT_DEFERRED)
	add_child(game)


# --- Online -----------------------------------------------------------------------

func _show_online() -> void:
	get_tree().paused = false
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
