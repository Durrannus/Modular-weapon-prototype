extends CanvasLayer
## The cave's own screen furniture, drawn at 640x360 like the forge screen:
## the objective line, a hint under it, the boss bar, "press E" prompts over
## things you can use, the smith's speech box, message cards and fades.

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")

const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const AMBER := Color("#ffc850")
const PLATE := Color(0.098, 0.078, 0.165, 0.86)   # the menu kit's dark plum

var root: Control
var objective := ""
var hint := ""
var boss = null                 # the guardian, while its bar shows
var boss_shown := 1.0           # the pale "lost health" bar catches up to this
var prompts: Array = []         # [{at: world position, text, pad: bool}], rebuilt every tick
var cam: Camera2D

# Speech
var lines: Array = []
var line_i := 0
var speaker := ""
var portrait := ""
var typed := 0.0
var on_said: Callable

# Card (a message in the middle of the screen)
var card_title := ""
var card_body := ""
var card_time := 0.0
var card_age := 0.0
var card_blocks := true          # false: the game carries on behind it and it goes by itself
var card_picture := ""           # a 200x72 picture above the words (set before card(); cleared with it)
var on_card: Callable

# Cutscene (full-screen pictures with captions, like the storm before the cave)
var cut: Dictionary = {}         # its numbers, from the json beside its pictures; empty when none is playing
var cut_dir := ""                # the folder under art/ that holds it
var cut_time := 0.0              # seconds in. Counted in game ticks, so two computers online stay on the same picture
var cut_two := false             # two players: draw player two's patches on top
var cut_skip := 0.0              # after one press: seconds left to press again and skip
var on_cut: Callable
var _cut_frame := -1             # the picture the two textures below hold
var _cut_tex: ImageTexture
var _cut_tex2: ImageTexture      # player two's patch for this picture, when there is one
var _cut_cue := 0                # the next sound to play
var _cut_bed: AudioStreamPlayer  # wind and rain under the whole thing

# Fade
var fade := 0.0
var fade_to := 0.0
var fade_speed := 1.0
var fade_color := Color.BLACK

var t := 0.0
var _boxes := {}


func _ready() -> void:
	layer = 6
	root = Control.new()
	root.size = Vector2(640, 360)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.draw.connect(_draw_ui)


func busy() -> bool:
	return talking() or (card_title != "" and card_blocks) or cutting()


func cutting() -> bool:
	return not cut.is_empty()


## Plays the pictures in art/<dir>/ full screen, then calls `done`. The json
## beside them says how fast, what the captions are and when the sounds come.
## The first press shows "press again to skip"; a second press skips.
func cutscene(dir: String, two_players: bool, done: Callable) -> void:
	var info: Dictionary = Art.json(dir + "/intro.json")
	if int(info.get("frames", 0)) <= 0 or float(info.get("fps", 0)) <= 0.0:
		# No pictures in this copy of the game: carry straight on.
		if done.is_valid():
			done.call()
		return
	cut = info
	cut_dir = dir
	cut_two = two_players
	cut_time = 0.0
	cut_skip = 0.0
	on_cut = done
	_cut_frame = -1
	_cut_cue = 0
	# Make the sounds now, while the screen is still black, not in the middle of a shot.
	for c in cut.get("cues", []):
		if CUT_SOUNDS.has(str(c["sound"])):
			Sfx.stream(CUT_SOUNDS[str(c["sound"])][0])
	_cut_bed = AudioStreamPlayer.new()
	_cut_bed.stream = Sfx.stream("storm")
	_cut_bed.volume_db = CUT_BED_DB
	_cut_bed.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_cut_bed)
	_cut_bed.play()


## The json's sound names -> [our sound, loudness, pitch].
const CUT_SOUNDS := {
	"thunder_far": ["thunder", -13.0, 0.8],
	"thunder_near": ["thunder", -4.0, 1.0],
	"wave_crash": ["wave", -5.0, 1.0],
	"ship_strikes": ["crash", -2.0, 1.0],
	"rumble": ["rumble", -6.0, 1.0],
	"rockfall": ["rockfall", -3.0, 1.0],
}
const CUT_BED_DB := -17.0


func _advance_cut(pressed: bool, delta: float) -> void:
	cut_time += delta
	cut_skip = maxf(cut_skip - delta, 0.0)
	var frame := int(cut_time * float(cut["fps"]))
	var cues: Array = cut.get("cues", [])
	while _cut_cue < cues.size() and frame >= int(cues[_cut_cue]["frame"]):
		var snd: Array = CUT_SOUNDS.get(str(cues[_cut_cue]["sound"]), [])
		if not snd.is_empty():
			Sfx.play(self, snd[0], snd[1], snd[2])
		_cut_cue += 1
	var skip := false
	if pressed and cut_time > 0.6:
		if cut_skip > 0.0:
			skip = true
		else:
			cut_skip = 3.0
	if skip or frame >= int(cut["frames"]):
		cut = {}
		_cut_tex = null
		_cut_tex2 = null
		if is_instance_valid(_cut_bed):
			# Let the storm die away rather than cut off.
			var bed := _cut_bed
			_cut_bed = null
			var quiet := create_tween()
			quiet.tween_property(bed, "volume_db", -60.0, 1.2)
			quiet.tween_callback(bed.queue_free)
		if on_cut.is_valid():
			on_cut.call()


func _cut_picture(file: String) -> ImageTexture:
	var img := Art.image(Art.ART_DIR + cut_dir + "/" + file)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


func _draw_cut() -> void:
	var silk := Art.font("Silkscreen-Regular")
	var frame := clampi(int(cut_time * float(cut["fps"])), 0, int(cut["frames"]) - 1)
	# One picture at a time is read from disk: all of them at once would be a lot of memory.
	if frame != _cut_frame:
		_cut_frame = frame
		_cut_tex = _cut_picture(str(cut.get("pattern", "f_%03d.png")) % frame)
		_cut_tex2 = _cut_picture(str(cut["p2_pattern"]) % frame) if cut_two and cut.has("p2_pattern") else null
	var screen := Rect2(0, 0, 640, 360)
	root.draw_rect(screen, Color.BLACK)
	if _cut_tex != null:
		root.draw_texture_rect(_cut_tex, screen, false)
	if _cut_tex2 != null:
		root.draw_texture_rect(_cut_tex2, screen, false)
	# The caption, on a plate at the bottom. It fades in and out over a few pictures.
	for c in cut.get("captions", []):
		var from := int(c["from"])
		var to := int(c["to"])
		if frame < from or frame > to:
			continue
		var a := clampf(minf(float(frame - from + 1), float(to - frame + 1)) / 3.0, 0.0, 1.0)
		var rows := _wrap(str(c["text"]), 440.0)
		var widest := 0.0
		for l in rows:
			widest = maxf(widest, _line_w(l))
		var top := 326.0 - rows.size() * 14.0
		var back := Rect2(roundf(320.0 - widest * 0.5) - 10, top - 4, widest + 20, rows.size() * 14.0 + 9)
		if not Art.draw_nine(root, "cave/ui/hint_plate.png", back, 4, Color(1, 1, 1, a)):
			root.draw_rect(back, Color(PLATE.r, PLATE.g, PLATE.b, 0.8 * a))
		for i in rows.size():
			_rich(rows[i], Vector2(roundf(320.0 - _line_w(rows[i]) * 0.5), top + 11 + i * 14.0), Color(INK.r, INK.g, INK.b, a))
	if cut_skip > 0.0:
		var text := "Press again to skip"
		var w := silk.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var back := Rect2(640.0 - w - 22, 8, w + 14, 15)
		if not Art.draw_nine(root, "cave/ui/hint_plate.png", back, 4):
			root.draw_rect(back, PLATE)
		_head(text, Vector2(back.position.x + 7, back.position.y + 11), AMBER)


func talking() -> bool:
	return not lines.is_empty()


## The smith speaks. `text` is an array of lines; `done` runs after the last one.
func say(who: String, face: String, text: Array, done: Callable = Callable()) -> void:
	speaker = who
	portrait = face
	lines = text
	line_i = 0
	typed = 0.0
	on_said = done


## A message card. seconds <= 0 waits for a button.
func card(title: String, body: String, seconds := 0.0, done: Callable = Callable()) -> void:
	card_title = title
	card_body = body
	card_time = seconds
	card_age = 0.0
	card_blocks = true
	on_card = done


func fade_out(time := 0.6, color := Color.BLACK) -> void:
	fade_color = color
	fade_to = 1.0
	fade_speed = 1.0 / maxf(time, 0.01)


func fade_in(time := 0.6) -> void:
	fade_to = 0.0
	fade_speed = 1.0 / maxf(time, 0.01)


## Call every tick with "someone pressed attack or interact".
func advance(pressed: bool, delta: float) -> void:
	t += delta
	fade = move_toward(fade, fade_to, fade_speed * delta)
	if cutting():
		_advance_cut(pressed, delta)
	elif talking():
		var full := float((lines[line_i] as String).length())
		var before := int(typed)
		typed = minf(typed + delta * 46.0, full)
		if int(typed) != before and int(typed) % 3 == 0 and typed < full:
			Sfx.play(self, "talk", -14.0, 0.9)
		if pressed:
			if typed < full:
				typed = full
			else:
				line_i += 1
				typed = 0.0
				if line_i >= lines.size():
					lines = []
					if on_said.is_valid():
						on_said.call()
	elif card_title != "":
		card_age += delta
		var timed_out := card_time > 0.0 and card_age >= card_time
		if timed_out or (pressed and card_age > 0.35 and card_blocks):
			card_title = ""
			card_picture = ""
			if on_card.is_valid():
				on_card.call()
	root.queue_redraw()


# --- Drawing ------------------------------------------------------------------

## A nine-patch box from art/cave/ui. `margin` is one number, or [left, top, right, bottom].
func _box(name: String, margin) -> StyleBox:
	if not _boxes.has(name):
		var tex := Art.texture("cave/ui/%s.png" % name)
		if tex == null:
			var flat := StyleBoxFlat.new()
			flat.bg_color = Color(PLATE.r, PLATE.g, PLATE.b, 0.95)
			flat.border_color = Color("#5f8072")
			flat.set_border_width_all(1)
			_boxes[name] = flat
		else:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			if margin is Array:
				sb.texture_margin_left = margin[0]
				sb.texture_margin_top = margin[1]
				sb.texture_margin_right = margin[2]
				sb.texture_margin_bottom = margin[3]
			else:
				sb.set_texture_margin_all(margin)
			_boxes[name] = sb
	return _boxes[name]


func _head(text: String, pos: Vector2, col := INK, size := 8, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	root.draw_string(Art.font("Silkscreen-Regular"), pos, text.to_upper(), align, width, size, col)


func _body(text: String, pos: Vector2, col := INK, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	root.draw_string(Art.font("PixelifySans-Regular"), pos, text, align, width, 11, col)


## Body text can show a key or button as a picture: write it as a word in square
## brackets, like [space], [mouse_left], [pad_x] or [stick_l] (the images are
## art/cave/ui/prompt_<name>.png). A word whose image is missing is drawn as text.
func _key_in(word: String) -> Array:
	if not word.begins_with("["):
		return []
	var close := word.find("]")
	if close < 2:
		return []
	var tex := Art.texture("cave/ui/prompt_%s.png" % word.substr(1, close - 1))
	if tex == null:
		return []
	return [tex, word.substr(close + 1)]   # the image, then any comma or full stop after it


func _word_w(word: String) -> float:
	var f := Art.font("PixelifySans-Regular")
	var key := _key_in(word)
	if key.is_empty():
		return f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	return float((key[0] as Texture2D).get_width()) + 1.0 + f.get_string_size(str(key[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x


func _line_w(line: String) -> float:
	var space := Art.font("PixelifySans-Regular").get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var w := 0.0
	var words := line.split(" ")
	for i in words.size():
		w += _word_w(words[i]) + (space if i < words.size() - 1 else 0.0)
	return w


## One line of body text with its key pictures, starting at pos (the text baseline).
func _rich(line: String, pos: Vector2, col := INK) -> void:
	var f := Art.font("PixelifySans-Regular")
	var space := f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var x := pos.x
	for word in line.split(" "):
		var key := _key_in(word)
		if key.is_empty():
			root.draw_string(f, Vector2(x, pos.y), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		else:
			var tex: Texture2D = key[0]
			root.draw_texture(tex, Vector2(x, pos.y - 12.0).round())
			if str(key[1]) != "":
				root.draw_string(f, Vector2(x + tex.get_width() + 1.0, pos.y), str(key[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		x += _word_w(word) + space


## Lines are 14 apart, or 18 when any of them holds a key picture (those are 16 tall).
func _pitch(lines: Array) -> float:
	for l in lines:
		for word in (l as String).split(" "):
			if not _key_in(word).is_empty():
				return 18.0
	return 14.0


func _wrap(text: String, width: float) -> Array:
	var out: Array = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if _line_w(trial) > width and line != "":
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return out


func _to_screen(world: Vector2) -> Vector2:
	if cam == null:
		return Vector2(320, 180)
	return ((world - cam.get_screen_center_position()) * cam.zoom.x + Vector2(320, 180)).round()


func _draw_ui() -> void:
	if cutting():
		_draw_cut()
		return
	var silk := Art.font("Silkscreen-Regular")
	# Prompts over things you can use.
	for pr in prompts:
		var at := _to_screen(pr["at"])
		var text: String = pr["text"]
		var w := silk.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var x := at.x - (w + 22.0) * 0.5
		var bob := 1.0 if fmod(t, 0.8) < 0.4 else 0.0
		if not Art.draw_nine(root, "cave/ui/prompt_plate.png", Rect2(x - 3, at.y - 10 - bob, w + 28, 18), 4):
			root.draw_rect(Rect2(x - 3, at.y - 10 - bob, w + 28, 18), PLATE)
		var down := fmod(t, 0.8) > 0.6
		var icon := Art.texture("cave/ui/%s%s.png" % ["prompt_pad_a" if pr["pad"] else "prompt_e", "_down" if down else ""])
		if icon != null:
			root.draw_texture(icon, Vector2(x, at.y - 9 - bob))
		else:
			_head("A" if pr["pad"] else "E", Vector2(x + 4, at.y + 3 - bob), AMBER)
		_head(text, Vector2(x + 20, at.y + 2 - bob), INK)

	# Objective and hint, top centre.
	if objective != "" and not busy():
		var w := silk.get_string_size(objective.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var x := 320.0 - w * 0.5
		if not Art.draw_nine(root, "swing/ui/well.png", Rect2(x - 17, 4, w + 28, 17), 3):
			root.draw_rect(Rect2(x - 16, 5, w + 26, 15), PLATE)
		var mark := Art.texture("hud/objective_mark.png")
		if mark != null:
			root.draw_texture(mark, Vector2(x - 11, 9))
		else:
			root.draw_colored_polygon(PackedVector2Array([Vector2(x - 10, 12.5), Vector2(x - 7, 9.5), Vector2(x - 4, 12.5), Vector2(x - 7, 15.5)]), AMBER)
		_head(objective, Vector2(x, 16), INK)
	var hint_y := 34.0
	if is_instance_valid(boss) and not boss.dead and boss.mode != "dormant" and not busy():
		var frame := Art.texture("cave/ui/boss_bar_frame.png")
		var fill := Art.texture("cave/ui/boss_bar_fill.png")
		var lost := Art.texture("cave/ui/boss_bar_lost.png")
		var frac := clampf(boss.hp / boss.max_hp, 0.0, 1.0)
		boss_shown = maxf(move_toward(boss_shown, frac, 0.004), frac)
		var bx := 240.0
		var by := 24.0
		if frame != null and fill != null:
			root.draw_texture(frame, Vector2(bx, by))
			if lost != null:
				root.draw_texture_rect_region(lost, Rect2(bx + 8, by + 3, 144.0 * boss_shown, 6), Rect2(0, 0, 144.0 * boss_shown, 6))
			root.draw_texture_rect_region(fill, Rect2(bx + 8, by + 3, 144.0 * frac, 6), Rect2(0, 0, 144.0 * frac, 6))
		else:
			root.draw_rect(Rect2(bx, by, 160, 10), Color(0, 0, 0, 0.7))
			root.draw_rect(Rect2(bx + 2, by + 2, 156.0 * frac, 6), Color("#d9483b"))
		hint_y = 50.0
	if hint != "" and not busy():
		var lines_h := _wrap(hint, 360.0)   # narrow enough to clear the health bars in the corners
		var pitch := _pitch(lines_h)
		var widest := 0.0
		for l in lines_h:
			widest = maxf(widest, _line_w(l))
		# One soft plate behind the whole hint.
		var back := Rect2(roundf(320.0 - widest * 0.5) - 7, hint_y - 5 - pitch * 0.5, widest + 14, lines_h.size() * pitch + 2)
		if not Art.draw_nine(root, "cave/ui/hint_plate.png", back, 4):
			root.draw_rect(back, Color(PLATE.r, PLATE.g, PLATE.b, 0.66))
		for i in lines_h.size():
			_rich(lines_h[i], Vector2(roundf(320.0 - _line_w(lines_h[i]) * 0.5), hint_y + i * pitch))

	# Fade (under the speech box and cards, over the game).
	if fade > 0.0:
		root.draw_rect(Rect2(0, 0, 640, 360), Color(fade_color.r, fade_color.g, fade_color.b, fade))

	if talking():
		var r := Rect2(70, 264, 500, 84)
		root.draw_style_box(_box("dialogue_box", 8), r)
		var face := Art.texture(portrait)
		var tx := r.position.x + 14.0
		if face != null:
			root.draw_texture(face, r.position + Vector2(12, 18))
			tx += 58.0
		if speaker != "":
			var nw := silk.get_string_size(speaker.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			root.draw_style_box(_box("dialogue_name", [4, 2, 2, 3]), Rect2(r.position.x + 10, r.position.y - 9, nw + 14, 14))
			_head(speaker, Vector2(r.position.x + 16, r.position.y + 1), AMBER)
		var shown: String = (lines[line_i] as String).substr(0, int(typed))
		var y := r.position.y + 30.0
		for l in _wrap(shown, r.size.x - (tx - r.position.x) - 16.0):
			_body(l, Vector2(tx, y))
			y += 14.0
		if typed >= float((lines[line_i] as String).length()):
			var more := Art.texture("cave/ui/dialogue_more.png")
			var frame := int(t * 3.0) % 2
			if more != null:
				root.draw_texture_rect_region(more, Rect2(r.end.x - 20, r.end.y - 18, 8, 8), Rect2(frame * 8, 0, 8, 8))
			else:
				_head("v", Vector2(r.end.x - 20, r.end.y - 10 + frame), AMBER)
	elif card_title != "":
		var body_lines := _wrap(card_body, 330.0)
		var pitch := _pitch(body_lines)
		var picture := Art.texture(card_picture) if card_picture != "" else null
		var pic_h := float(picture.get_height()) + 6.0 if picture != null else 0.0
		var h := 54.0 + pic_h + body_lines.size() * pitch + (16.0 if card_time <= 0.0 else 0.0)
		var r := Rect2(140, 180.0 - h * 0.5 - 10.0, 360, h)
		root.draw_style_box(_box("dialogue_box", 8), r)
		if picture != null:
			root.draw_texture(picture, Vector2(roundf(r.get_center().x - picture.get_width() * 0.5), r.position.y + 12))
		_head(card_title, Vector2(r.position.x, r.position.y + 30 + pic_h), AMBER, 16, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var y := r.position.y + 50.0 + pic_h
		for l in body_lines:
			_rich(l, Vector2(roundf(r.get_center().x - _line_w(l) * 0.5), y))
			y += pitch
		if card_time <= 0.0 and card_age > 0.35:
			_head("Click, E or A to go on", Vector2(r.position.x, r.end.y - 9), DIM, 8, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
