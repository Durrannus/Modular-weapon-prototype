extends SceneTree
## Checks for the intro screen: its picture is all there and its numbers make
## sense, the buttons sit clear of the bottom band with room for the ones to
## come, and joining and choosing start the right game.
##   godot --headless --path . --fixed-fps 60 -s tests/title_screen.gd

const Title := preload("res://scripts/ui/title.gd")
const Art := preload("res://scripts/art.gd")

var fails := 0
var started: Array = []


func _init() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(title, code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	title._input(e)


func _pad(title, button: JoyButton, device := 0) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = device
	e.pressed = true
	title._input(e)


func _open():
	started = []
	var title = Title.new()
	root.add_child(title)
	title.start.connect(func(mode: String, inputs: Array): started = [mode, inputs])
	return title


func _run() -> void:
	await process_frame
	# The game opens on it.
	var boot = load("res://scenes/boot.tscn").instantiate()
	root.add_child(boot)
	await _frames(3)
	_check(boot.title != null and boot.game == null, "the game opens on the intro screen")
	boot.queue_free()
	await _frames(2)

	# The picture.
	var scene: Dictionary = Art.json(Title.SCENE)
	var layers: Array = scene.get("layers", [])
	_check(not layers.is_empty(), "the picture has layers (art/title/title.json)")
	var scale := float(scene.get("scale", 1.0))
	var moving := 0
	for l in layers:
		var file := str(l.get("file", ""))
		var tex := Art.texture(Title.DIR + file)
		_check(tex != null, "layer picture %s is there" % file)
		if tex == null:
			continue
		var frames := int(l.get("frames", 1))
		var cols := clampi(int(l.get("cols", frames)), 1, maxi(1, frames))
		var rows := ceili(float(frames) / float(cols))
		_check(frames >= 1 and tex.get_width() % cols == 0 and tex.get_height() % rows == 0,
				"%s splits evenly into its %d frames (%d across, %d down)" % [file, frames, cols, rows])
		if l.has("frame"):
			_check(Vector2(float(l["frame"][0]), float(l["frame"][1])) == Vector2(tex.get_width() / cols, tex.get_height() / rows),
					"%s: each frame is the size the art says" % file)
		if frames > 1:
			_check(float(l.get("fps", 0.0)) > 0.0, "%s has frames, so it has a speed" % file)
		if l.has("scroll") or l.has("pulse") or l.has("bob") or frames > 1:
			moving += 1
		for key in ["pulse", "bob"]:
			if l.has(key):
				_check(l[key] is Array and l[key].size() == 3 and float(l[key][2]) > 0.0, "%s: %s is two amounts and a time" % [file, key])
		if l.has("scroll"):
			var s: Array = l["scroll"]
			_check(maxf(absf(float(s[0])), absf(float(s[1]))) * scale <= 16.0, "%s drifts slowly (at most 16 screen pixels a second)" % file)
	_check(moving >= 1 or scene.has("embers"), "something in the picture moves")
	if layers.size() > 0:
		var back := Art.texture(Title.DIR + str(layers[0].get("file", "")))
		_check(back != null and back.get_size() * scale == Title.SCREEN, "the back layer fills the screen")
	var logo: Dictionary = scene.get("logo", {})
	if str(logo.get("file", "")) != "":
		_check(Art.texture(Title.DIR + str(logo["file"])) != null, "the logo picture is there")

	# The buttons.
	var title = _open()
	await _frames(3)
	_check(Title.ITEMS[0][0] == "cave" and Title.ITEMS[1][0] == "arena", "the tutorial and the arena are the first two rows")
	_check(Title.MENU_ROOM >= Title.ITEMS.size() + 2, "the column keeps room for New game and Continue")
	_check(title.rects.size() == Title.ITEMS.size(), "every row is drawn (%d of %d)" % [title.rects.size(), Title.ITEMS.size()])
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font("PixelifySans-Regular")
	if title.rects.size() == Title.ITEMS.size():
		var first: Rect2 = title.rects[0]
		var room_end := first.position.y + Title.MENU_ROOM * Title.ROW_STEP
		var most_lines := 0
		for i in Title.ITEMS.size():
			var r: Rect2 = title.rects[i]
			_check(Rect2(Vector2.ZERO, Title.SCREEN).encloses(r), "row %s is on the screen" % Title.ITEMS[i][1])
			if i > 0:
				_check(not r.intersects(title.rects[i - 1]), "row %s does not overlap the one above" % Title.ITEMS[i][1])
			most_lines = maxi(most_lines, title._wrap(str(Title.ITEMS[i][2]), r.size.x - 8.0, pix).size())
		for label in ["New game", "Continue"] + Title.ITEMS.map(func(it): return it[1]):
			var w := silk.get_string_size(str(label).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_check(w + 26.0 <= first.size.x, "\"%s\" fits a row (%d of %d)" % [label, int(w) + 26, int(first.size.x)])
		_check(most_lines <= 3, "what a row does is told in three lines or fewer (%d)" % most_lines)
		_check(room_end + 10.0 + 13.0 * most_lines <= Title.SCREEN.y - Title.STRIP,
				"six rows and their words stay above the bottom band (%d of %d)" % [int(room_end + 10.0 + 13.0 * most_lines), int(Title.SCREEN.y - Title.STRIP)])

	# Joining and choosing.
	_check(title.joined.is_empty(), "nobody has joined at first")
	_key(title, KEY_ENTER)
	_check(title.joined == [["kbm", 0]] and started.is_empty(), "Enter joins the keyboard player and starts nothing yet")
	_key(title, KEY_ENTER)
	_check(started.is_empty() and not title.leaving.is_empty(), "Enter again chooses the row: the screen fades first")
	_key(title, KEY_S)
	_check(title.cursor == 0, "the choice is locked while it fades")
	await _frames(int(Title.FADE_OUT * 60.0) + 4)
	_check(started.size() == 2 and started[0] == "cave" and started[1].size() == 1 and started[1][0].kind == "any",
			"then the tutorial starts for one player on any device")
	title.queue_free()

	title = _open()
	await _frames(2)
	_key(title, KEY_ENTER)
	_pad(title, JOY_BUTTON_A, 0)
	_check(title.joined == [["kbm", 0], ["pad", 0]], "a controller's A joins as player two")
	_pad(title, JOY_BUTTON_DPAD_DOWN, 0)
	_check(title.cursor == 1, "either player can move the choice")
	_pad(title, JOY_BUTTON_A, 0)
	await _frames(int(Title.FADE_OUT * 60.0) + 4)
	_check(started.size() == 2 and started[0] == "arena" and started[1].size() == 2
			and started[1][0].kind == "kbm" and started[1][1].kind == "pad", "the arena starts with a device each")
	title.queue_free()

	title = _open()
	await _frames(2)
	_key(title, KEY_ENTER)
	_key(title, KEY_BACKSPACE)
	_check(title.joined.is_empty(), "Backspace leaves again")
	_key(title, KEY_W)
	_check(title.cursor == Title.ITEMS.size() - 1, "up from the top row wraps to the bottom one")
	title.queue_free()

	# The picture's helpers.
	var cover: Array = Title._repeats(-37.0, 100.0, 640.0)
	_check(cover.front() <= 0.0 and cover.back() + 100.0 >= 640.0, "a drifting layer always covers the screen")
	var same := true
	for i in 20:
		var c := Title._chance(i, 3)
		if c < 0.0 or c >= 1.0 or c != Title._chance(i, 3):
			same = false
	_check(same, "the sparks are the same every time (no dice)")

	print("RESULT: %s" % ("all passed" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
