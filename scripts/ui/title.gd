extends CanvasLayer
## The title screen: who is playing, and what to play.
##
## Each device joins by pressing its own button (Enter or a click for keyboard
## and mouse, A on a controller). The first one in is player one, the second is
## player two. Then anyone who has joined picks a mode.

signal start(mode: String, inputs: Array)

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const PlayerInput := preload("res://scripts/player_input.gd")

const INK := Color("#e6dccb")
const DIM := Color("#8e877b")
const AMBER := Color("#ffb24a")
const PLAYER_COLORS := [Color("#5fb8ff"), Color("#ff9a4a")]
const ITEMS := [
	["cave", "Tutorial cave", "The four-room cave from the Game Plan: find a sword, fight through, fit a rune, beat the guardian."],
	["arena", "Test arena", "The sandbox: every part unlocked, endless enemies, forge on Tab or Y."],
	["quit", "Quit", ""],
]
const MAX_PLAYERS := 2

var root: Control
var joined: Array = []     # [["kbm", 0] or ["pad", device], ...]
var cursor := 0
var hover := -1
var rects: Array = []
var t := 0.0
var stick_ready := {}     # controller id -> its stick has come back to the middle


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.size = Vector2(640, 360)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.draw.connect(_draw_title)
	Input.set_custom_mouse_cursor(null)


func set_joined(inputs: Array) -> void:
	joined = []
	for inp in inputs:
		if inp.kind == "pad":
			joined.append(["pad", inp.device])
		elif inp.kind == "kbm" or inp.kind == "any":
			joined.append(["kbm", 0])


func _process(delta: float) -> void:
	t += delta
	root.queue_redraw()


func _who(event: InputEvent) -> Array:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return ["pad", event.device]
	return ["kbm", 0]


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var m := root.get_local_mouse_position()
		hover = -1
		for i in rects.size():
			if (rects[i] as Rect2).has_point(m):
				hover = i
				cursor = i
		return
	var dy := 0
	if event is InputEventJoypadMotion:
		# The left stick moves the choice too: one step per push.
		var jm := event as InputEventJoypadMotion
		if jm.axis != JOY_AXIS_LEFT_Y:
			return
		if absf(jm.axis_value) < 0.3:
			stick_ready[jm.device] = true
		elif absf(jm.axis_value) > 0.6 and stick_ready.get(jm.device, true):
			stick_ready[jm.device] = false
			cursor = posmod(cursor + (1 if jm.axis_value > 0.0 else -1), ITEMS.size())
			Sfx.play(self, "click", -16.0)
		return
	if not event.is_pressed() or event.is_echo():
		return
	var who := _who(event)
	var confirm := false
	var back := false
	if event is InputEventKey:
		match (event as InputEventKey).physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: confirm = true
			KEY_BACKSPACE: back = true
			KEY_W, KEY_UP: dy = -1
			KEY_S, KEY_DOWN: dy = 1
	elif event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A, JOY_BUTTON_START: confirm = true
			JOY_BUTTON_B: back = true
			JOY_BUTTON_DPAD_UP: dy = -1
			JOY_BUTTON_DPAD_DOWN: dy = 1
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if hover >= 0:
			cursor = hover
			if joined.is_empty():
				joined.append(who)
			_choose()
		elif not (who in joined) and joined.size() < MAX_PLAYERS:
			_join(who)
		return
	if dy != 0:
		cursor = posmod(cursor + dy, ITEMS.size())
		Sfx.play(self, "click", -16.0)
	if back and who in joined:
		joined.erase(who)
		Sfx.play(self, "click", -14.0, 0.7)
	if confirm:
		if not (who in joined):
			if joined.size() < MAX_PLAYERS:
				_join(who)
		else:
			_choose()


func _join(who: Array) -> void:
	joined.append(who)
	Sfx.play(self, "pickup", -10.0, 1.2)


func _choose() -> void:
	var mode: String = ITEMS[cursor][0]
	if mode == "quit":
		get_tree().quit()
		return
	Sfx.play(self, "click", -8.0)
	var inputs: Array = []
	if joined.size() <= 1:
		# On your own every device works, so you can swap between mouse and controller.
		inputs.append(PlayerInput.make("any"))
		if not joined.is_empty() and joined[0][0] == "pad":
			inputs[0].using_pad = true
	else:
		for j in joined:
			inputs.append(PlayerInput.make(j[0], int(j[1])))
	start.emit(mode, inputs)


func _draw_title() -> void:
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font("PixelifySans-Regular")
	root.draw_rect(Rect2(0, 0, 640, 360), Color("#0b0d16"))
	# A strip of cave floor and the smith's forge glow, so it isn't a bare menu.
	var wall := Art.texture("cave/wall_face_0.png")
	var floor_tex := Art.texture("cave/floor_0.png")
	if wall != null and floor_tex != null:
		for x in 40:
			root.draw_texture(wall, Vector2(x * 16, 292), Color(0.55, 0.57, 0.75))
			for y in 4:
				root.draw_texture(floor_tex, Vector2(x * 16, 308 + y * 16), Color(0.5, 0.52, 0.7))
	var forge := Art.texture("cave/forge_awake.png")
	if forge != null:
		root.draw_texture(forge, Vector2(498, 246))
	root.draw_string(silk, Vector2(40, 62), "MODULAR WEAPON", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, AMBER)
	root.draw_string(silk, Vector2(40, 80), "PROTOTYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)

	rects = []
	var y := 122.0
	for i in ITEMS.size():
		var r := Rect2(36, y - 13, 250, 20)
		rects.append(r)
		var on := i == cursor
		if on:
			root.draw_rect(r, Color(1, 0.7, 0.3, 0.12))
			root.draw_colored_polygon(PackedVector2Array([Vector2(40, y - 8), Vector2(46, y - 3), Vector2(40, y + 2)]), AMBER)
		root.draw_string(silk, Vector2(54, y + 1), str(ITEMS[i][1]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK if on else DIM)
		y += 26.0
	var note: String = ITEMS[cursor][2]
	var ny := y + 6.0
	for l in _wrap(note, 290.0, pix):
		root.draw_string(pix, Vector2(40, ny), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
		ny += 13.0

	# Who is playing.
	var px := 372.0
	root.draw_string(silk, Vector2(px, 110), "PLAYERS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, DIM)
	for i in MAX_PLAYERS:
		var row := Rect2(px, 118 + i * 34, 232, 28)
		root.draw_rect(row, Color(0.06, 0.07, 0.1, 0.9))
		root.draw_rect(Rect2(row.position, Vector2(3, row.size.y)), PLAYER_COLORS[i] if i < joined.size() else Color("#3a3f4c"))
		root.draw_string(silk, row.position + Vector2(10, 18), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PLAYER_COLORS[i] if i < joined.size() else Color("#4a4f5c"))
		var text := ""
		var col := INK
		if i < joined.size():
			text = "Keyboard + mouse" if joined[i][0] == "kbm" else "Controller %d" % (int(joined[i][1]) + 1)
		elif i == joined.size():
			col = DIM if fmod(t, 1.0) < 0.6 else Color("#5a5650")
			text = "Press Enter or A to join"
		else:
			col = Color("#4a4f5c")
			text = "Second player: Enter or A"
		root.draw_string(pix, row.position + Vector2(46, 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
	var help := "One player can use any device. Two players share the screen: each presses their own button."
	var hy := 200.0
	for l in _wrap(help, 232.0, pix):
		root.draw_string(pix, Vector2(px, hy), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
		hy += 13.0
	root.draw_string(pix, Vector2(40, 280), "W / S or stick: choose      Enter or A: select      Backspace or B: leave", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#5a5650"))


func _wrap(text: String, width: float, f: Font) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var trial := word if line == "" else line + " " + word
		if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	out.append(line)
	return out
