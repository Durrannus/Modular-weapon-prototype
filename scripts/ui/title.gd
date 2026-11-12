extends CanvasLayer
## The intro screen: a slowly moving picture of the game's world and its crew,
## the game's name, and the buttons that start a game.
##
## THE PICTURE is described by art/title/title.json, a list of layers drawn back
## to front. Each layer is one picture that can loop through frames, drift and
## wrap round (clouds, sea), breathe (a lantern's light), sway (a boat) or add
## its light to what is under it. Embers are drawn here as rising sparks. The
## art can change completely without touching this file: see "The intro
## screen" in the README for every key.
##
## THE BUTTONS are a column of rows at `menu.at`. Today they are the tutorial,
## the arena, online play and quit; the column keeps room for MENU_ROOM rows so
## "New game" and "Continue" can go on top later.
##
## WHO IS PLAYING: each device joins by pressing its own button (Enter or a click
## for keyboard and mouse, A on a controller). The first one in is player one,
## the second is player two. Then anyone who has joined picks a row.

signal start(mode: String, inputs: Array)

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Music := preload("res://scripts/music.gd")
const PlayerInput := preload("res://scripts/player_input.gd")

const SCENE := "title/title.json"
const DIR := "title/"
const SCREEN := Vector2(640, 360)
const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const AMBER := Color("#ffc850")
const EMBER := Color("#f06a40")
const FAINT := Color("#5f8072")
const PLATE := Color("#19142a")
const SHADOW := Color(0.06, 0.04, 0.11, 0.9)
const PLAYER_COLORS := Art.PLAYER_COLORS
const ITEMS := [
	["cave", "Tutorial", "The four-room cave: find a sword, fight through, fit a rune, beat the guardian."],
	["arena", "Arena", "The sandbox: every part unlocked, endless enemies, the forge on Tab or Y."],
	["online", "Play online", "Two players over the internet, one on each computer. One hosts, the other joins."],
	["quit", "Quit", ""],
]
const MAX_PLAYERS := 2
const MENU_ROOM := 6          # rows the column keeps space for (New game and Continue come later)
const ROW_STEP := 24.0
const ROW_HEIGHT := 20.0
const STRIP := 28.0           # the band along the bottom edge: hints, who is playing, the version number
const FADE_IN := 0.6          # seconds the screen takes to come up out of black
const FADE_OUT := 0.3         # and to go back down to it once a row is chosen
const NAME := "MODULAR WEAPON"   # a working name: the game has none yet
const GLINT_EVERY := 7.0      # seconds between glints of light along the name
const GLINT_TIME := 0.9       # how long one takes to cross it
const GLINT_WIDTH := 8.0
const GLINT_COLOR := Color("#fff6d0")

var root: Control
var picture: Node2D
var glint: Control        # a narrow window that slides along the name and shows it lit
var name_at := Vector2.ZERO
var music: Node
var scene: Dictionary = {}
var art_scale := 1.0      # screen pixels per art pixel of the title pictures
var joined: Array = []     # [["kbm", 0] or ["pad", device], ...]
var cursor := 0
var hover := -1
var rects: Array = []
var t := 0.0
var stick_ready := {}     # controller id -> its stick has come back to the middle
var notice := ""          # one line of news from the last game ("Your friend left the game.")
var leaving: Array = []   # [mode, inputs] once a row is chosen; the screen fades, then starts it
var leave_t := 0.0


func _ready() -> void:
	layer = 20
	scene = Art.json(SCENE)
	art_scale = maxf(1.0, float(scene.get("scale", 1.0)))
	picture = Node2D.new()
	picture.scale = Vector2(art_scale, art_scale)
	add_child(picture)
	for l in scene.get("layers", []):
		if l is Dictionary:
			_add_layer(_draw_layer, l)
	if scene.get("embers") is Dictionary:
		_add_layer(_draw_embers, {"blend": "add", "embers": scene["embers"]})
	root = Control.new()
	root.size = SCREEN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.draw.connect(_draw_title)
	glint = Control.new()
	glint.clip_contents = true
	glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glint.size = Vector2(GLINT_WIDTH, 30)
	glint.visible = false
	glint.draw.connect(_draw_glint)
	root.add_child(glint)
	Input.set_custom_mouse_cursor(null)
	var track := str(scene.get("music", ""))
	if track != "":
		music = Music.new()
		add_child(music)
		music.play(track, 2.0)


## One piece of the picture: its own node, so a layer of light can add itself
## to the ones under it.
func _add_layer(draw: Callable, l: Dictionary) -> void:
	var n := Node2D.new()
	if str(l.get("blend", "")) == "add":
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = m
	n.draw.connect(draw.bind(n, l))
	picture.add_child(n)


func set_joined(inputs: Array) -> void:
	joined = []
	for inp in inputs:
		if inp.kind == "pad":
			joined.append(["pad", inp.device])
		elif inp.kind == "kbm" or inp.kind == "any":
			joined.append(["kbm", 0])


func _process(delta: float) -> void:
	t += delta
	if not leaving.is_empty():
		leave_t += delta
		if leave_t >= FADE_OUT:
			set_process(false)
			set_process_input(false)
			start.emit(leaving[0], leaving[1])
			return
	root.queue_redraw()
	for n in picture.get_children():
		n.queue_redraw()
	_move_glint()


func _who(event: InputEvent) -> Array:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return ["pad", event.device]
	return ["kbm", 0]


func _input(event: InputEvent) -> void:
	if not leaving.is_empty():
		return
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
	if mode == "online":
		# Online, each computer has one player, on any device.
		_leave(mode, inputs)
		return
	if joined.size() <= 1:
		# On your own every device works, so you can swap between mouse and controller.
		inputs.append(PlayerInput.make("any"))
		if not joined.is_empty() and joined[0][0] == "pad":
			inputs[0].using_pad = true
	else:
		for j in joined:
			inputs.append(PlayerInput.make(j[0], int(j[1])))
	_leave(mode, inputs)


## The row is chosen: the screen and its music fade, then the game starts.
func _leave(mode: String, inputs: Array) -> void:
	leaving = [mode, inputs]
	leave_t = 0.0
	if music != null:
		music.stop(FADE_OUT)


# --- The picture ------------------------------------------------------------------

static func _pair(v, fallback: Vector2) -> Vector2:
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback


## 0 to 1 and back to 0, once every `seconds`.
func _breath(seconds: float) -> float:
	return 0.5 - 0.5 * cos(TAU * t / maxf(0.1, seconds))


func _draw_layer(n: Node2D, l: Dictionary) -> void:
	var tex := Art.texture(DIR + str(l.get("file", "")))
	if tex == null:
		return
	# Frames sit side by side, or in rows of `cols` when one row would be too wide a picture.
	var frames := maxi(1, int(l.get("frames", 1)))
	var cols := clampi(int(l.get("cols", frames)), 1, frames)
	var rows := ceili(float(frames) / float(cols))
	var size := Vector2(float(tex.get_width() / cols), float(tex.get_height() / rows))
	var frame := int(t * float(l.get("fps", 0.0))) % frames
	var src := Rect2(Vector2((frame % cols) * size.x, (frame / cols) * size.y), size)
	var at := _pair(l.get("at"), Vector2.ZERO)
	var bob = l.get("bob")
	if bob is Array and bob.size() >= 3:
		at += (_pair(bob, Vector2.ZERO) * _breath(float(bob[2]))).round()
	var alpha := float(l.get("alpha", 1.0))
	var pulse = l.get("pulse")
	if pulse is Array and pulse.size() >= 3:
		alpha *= lerpf(float(pulse[0]), float(pulse[1]), _breath(float(pulse[2])))
	var tint := Color(1, 1, 1, alpha)
	var scroll := _pair(l.get("scroll"), Vector2.ZERO)
	if scroll == Vector2.ZERO:
		n.draw_texture_rect_region(tex, Rect2(at, size), src, tint)
		return
	# A drifting layer repeats in the direction it moves, a whole pixel at a time.
	var view := SCREEN / art_scale
	var shift := (scroll * t).floor()
	var xs: Array = [at.x]
	var ys: Array = [at.y]
	if scroll.x != 0.0:
		xs = _repeats(at.x + shift.x, size.x, view.x)
	if scroll.y != 0.0:
		ys = _repeats(at.y + shift.y, size.y, view.y)
	for y in ys:
		for x in xs:
			n.draw_texture_rect_region(tex, Rect2(Vector2(x, y), size), src, tint)


## Where copies of a picture `size` wide must start to cover 0..`view`.
static func _repeats(from: float, size: float, view: float) -> Array:
	var out: Array = []
	var x := fposmod(from, size) - size
	while x < view:
		out.append(x)
		x += size
	return out


## The same number between 0 and 1 every time for the same spark and slot.
static func _chance(i: int, slot: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(slot) * 78.233) * 43758.5453, 1.0)


## Sparks that rise slowly inside `area`, sway, and wink out near the top.
func _draw_embers(n: Node2D, l: Dictionary) -> void:
	var e: Dictionary = l["embers"]
	var area = e.get("area")
	if not (area is Array and area.size() >= 4):
		return
	var corner := Vector2(float(area[0]), float(area[1]))
	var size := Vector2(float(area[2]), float(area[3])) - corner
	var rise := maxf(1.0, float(e.get("rise", 12.0)))
	var sway := float(e.get("sway", 10.0))
	var colors: Array = e.get("colors", ["#ffc850", "#f06a40"])
	if size.x <= 0.0 or size.y <= 0.0 or colors.is_empty():
		return
	for i in int(e.get("count", 24)):
		var life := size.y / (rise * (0.6 + 0.8 * _chance(i, 1)))
		var clock := t / life + _chance(i, 0)
		var lap := int(clock)                 # each trip up starts somewhere new
		var age := clock - float(lap)
		var x := corner.x + size.x * _chance(i + lap * 131, 2) \
				+ sin(t * (0.4 + 0.6 * _chance(i, 3)) + TAU * _chance(i, 4)) * sway * age
		var y := corner.y + size.y * (1.0 - age)
		var alpha := 1.0
		if age < 0.08:
			alpha = 0.4
		elif age > 0.85:
			alpha = 0.25
		elif age > 0.6:
			alpha = 0.6
		if fmod(t * (1.5 + 2.0 * _chance(i, 5)) + _chance(i, 6), 1.0) < 0.2:
			alpha *= 0.5      # a flicker
		var dot := 2.0 if _chance(i, 7) > 0.7 and age < 0.5 else 1.0
		var col := Color(str(colors[i % colors.size()]))
		n.draw_rect(Rect2(floorf(x), floorf(y), dot, dot), Color(col, alpha))


# --- The words and buttons --------------------------------------------------------

## Words with a dark edge under them, so they read on any picture.
func _words(f: Font, at: Vector2, text: String, size: int, col: Color) -> void:
	root.draw_string(f, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SHADOW)
	root.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_title() -> void:
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font("PixelifySans-Regular")
	if scene.get("layers", []).is_empty():
		root.draw_rect(Rect2(Vector2.ZERO, SCREEN), PLATE)

	# The name. A drawn logo if the art has one, the words if not.
	var logo: Dictionary = scene.get("logo", {})
	var logo_at := _pair(logo.get("at"), Vector2(40, 40)) * art_scale
	var logo_tex := Art.texture(DIR + str(logo.get("file", "")))
	if logo_tex != null:
		root.draw_texture_rect(logo_tex, Rect2(logo_at, logo_tex.get_size() * art_scale), false)
	else:
		name_at = logo_at + Vector2(0, 22)
		_words(silk, name_at, NAME, 24, AMBER)
		_words(silk, logo_at + Vector2(0, 40), "PROTOTYPE", 16, INK)

	# The buttons.
	var menu: Dictionary = scene.get("menu", {})
	var corner := _pair(menu.get("at"), Vector2(40, 130)) * art_scale
	var width := float(menu.get("width", 200.0)) * art_scale
	var shade := float(menu.get("plate", 0.0))
	if shade > 0.0:
		var plate := Rect2(corner - Vector2(8, 8), Vector2(width + 16, MENU_ROOM * ROW_STEP + 44))
		for step in 3:      # a stepped edge, like the game's banded light
			root.draw_rect(plate.grow(4.0 - 2.0 * step), Color(PLATE, shade / 3.0))
	rects = []
	var y := corner.y
	for i in ITEMS.size():
		var r := Rect2(corner.x, y, width, ROW_HEIGHT)
		rects.append(r)
		var on := i == cursor
		var x := corner.x + 8.0
		if on:
			if not Art.draw_nine(root, "swing/ui/well_selected.png", r, 3):
				root.draw_rect(r, AMBER, false, 1.0)
			var arrow := Art.texture("swing/ui/cursor.png")
			var nudge := 1.0 if fmod(t, 0.8) < 0.4 else 0.0
			if arrow != null:
				root.draw_texture(arrow, Vector2(x + nudge, y + 4))
			x += 14.0
		_words(silk, Vector2(x, y + 15), str(ITEMS[i][1]).to_upper(), 16, AMBER if on else INK)
		y += ROW_STEP
	var ny := y + 10.0
	for l in _wrap(str(ITEMS[cursor][2]), width - 8.0, pix):
		_words(pix, Vector2(corner.x + 8, ny), l, 11, INK)
		ny += 13.0

	# News from the last game, top middle.
	if notice != "":
		var nw := pix.get_string_size(notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var nx := floorf((SCREEN.x - nw) * 0.5)
		root.draw_rect(Rect2(nx - 8, 6, nw + 16, 18), Color(PLATE, 0.85))
		root.draw_string(pix, Vector2(nx, 19), notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, EMBER)

	# The bottom band: what the buttons do, and who is playing.
	for step in 3:
		root.draw_rect(Rect2(0, SCREEN.y - STRIP - 4 + 2 * step, SCREEN.x, STRIP + 4 - 2 * step), Color(PLATE, 0.22))
	var base := SCREEN.y - STRIP + 12.0
	var hint := "Press Enter or A to join"
	if not joined.is_empty():
		hint = "W / S or stick: choose     Enter or A: select     Backspace or B: leave"
	root.draw_string(pix, Vector2(10, base), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
	var right := SCREEN.x - 10.0
	for i in range(MAX_PLAYERS - 1, -1, -1):
		var here := i < joined.size()
		var text := "Enter or A to join"
		var col := FAINT
		if here:
			text = "Keyboard + mouse" if joined[i][0] == "kbm" else "Controller %d" % (int(joined[i][1]) + 1)
			col = INK
		elif i == joined.size():
			col = DIM if fmod(t, 1.0) < 0.6 else FAINT
		var tw := ceilf(pix.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
		right -= tw
		root.draw_string(pix, Vector2(right, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		right -= 22.0
		root.draw_string(silk, Vector2(right, base), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, PLAYER_COLORS[i] if here else FAINT)
		var tag := Art.texture("hud/tag_%s.png" % ("a" if i == 0 else "b"))
		if here and tag != null:
			right -= 9.0
			root.draw_texture(tag, Vector2(right, base - 10))
		right -= 16.0

	# Up out of black when the screen opens, and back down to it when a game starts.
	var dark := maxf(1.0 - t / FADE_IN, 0.0 if leaving.is_empty() else leave_t / FADE_OUT)
	if dark > 0.0:
		root.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.02, 0.02, 0.05, minf(dark, 1.0)))


## Every few seconds a glint of light runs along the name, left to right.
func _move_glint() -> void:
	var k := fmod(t, GLINT_EVERY) / GLINT_TIME
	glint.visible = k < 1.0 and name_at != Vector2.ZERO and t > GLINT_EVERY * 0.5
	if not glint.visible:
		return
	var silk := Art.font("Silkscreen-Regular")
	var w := silk.get_string_size(NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	glint.position = Vector2(floorf(name_at.x - GLINT_WIDTH + k * (w + GLINT_WIDTH)), name_at.y - 24.0)
	glint.queue_redraw()


func _draw_glint() -> void:
	glint.draw_string(Art.font("Silkscreen-Regular"), name_at - glint.position, NAME,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GLINT_COLOR)


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
