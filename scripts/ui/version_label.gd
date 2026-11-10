extends CanvasLayer
## The version number, small, in the bottom-left corner of every screen: the
## title, the arena, the cave and the menus. It is there so you can
## tell which copy of the game you are running, and so two people can check
## they have the same one before they play together.
##
## The number itself lives in scripts/version.gd. This also checks, a few files
## a frame so nothing stutters, that the game's files are still the ones that
## number was given to. If they aren't, it says "+ changes".
##
## A screen that fills that corner itself (the forge) joins the group
## "covers_version"; the number steps aside while such a screen is open.
##
## It only draws: it never touches the game, so it is safe for online play.

const Version := preload("res://scripts/version.gd")
const Art := preload("res://scripts/art.gd")
const DIM := Color("#8ba688")
const EMBER := Color("#f06a40")
const SHADE := Color(0.098, 0.078, 0.165, 0.5)
const AT := Vector2(10, 357)       # where the words start (their baseline)
const BUDGET_MSEC := 2             # how long the file check may take each frame

var changed := false
var checked := false               # true once every file has been looked at
var _panel: Control
var _left: Array = []
var _ctx: HashingContext


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.size = Vector2(640, 360)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_label)
	add_child(_panel)
	_left = Version.files()
	_ctx = Version.begin()


func _process(_delta: float) -> void:
	var covered := false
	for n in get_tree().get_nodes_in_group("covers_version"):
		if n.get("is_open") == true:
			covered = true
	visible = not covered
	if checked:
		return
	var until := Time.get_ticks_msec() + BUDGET_MSEC
	while not _left.is_empty() and Time.get_ticks_msec() < until:
		Version.add(_ctx, _left.pop_front())
	if _left.is_empty():
		changed = Version.finish(_ctx) != Version.FILES
		checked = true
		_ctx = null
		if changed:
			_panel.queue_redraw()


func _draw_label() -> void:
	var f := Art.font("Silkscreen-Regular")
	var text := Version.label(changed).to_upper()
	var w := ceilf(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	_panel.draw_rect(Rect2(AT.x - 3, AT.y - 7, w + 6, 9), SHADE)
	_panel.draw_string(f, AT, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, EMBER if changed else DIM)
