extends Node
## The game's front door: shows the title screen, then runs the mode you pick
## (the tutorial cave or the test arena) and comes back here when it ends.
##
## To skip the title while testing, add a mode after "--":
##   godot --path . -- cave        (or: arena)

const Title := preload("res://scripts/ui/title.gd")
const Cave := preload("res://scripts/cave/cave.gd")
const Arena := preload("res://scripts/main.gd")

var title
var game
var last_inputs: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "cave" in args:
		_start("cave", [])
	elif "arena" in args:
		_start("arena", [])
	else:
		_show_title()


func _show_title() -> void:
	get_tree().paused = false
	if is_instance_valid(game):
		game.queue_free()
		game = null
	title = Title.new()
	add_child(title)
	title.set_joined(last_inputs)
	title.start.connect(_start)


func _start(mode: String, inputs: Array) -> void:
	last_inputs = inputs
	if is_instance_valid(title):
		title.queue_free()
		title = null
	game = (Cave if mode == "cave" else Arena).new()
	game.inputs = inputs
	game.exit_to_title.connect(_show_title, CONNECT_DEFERRED)
	add_child(game)
