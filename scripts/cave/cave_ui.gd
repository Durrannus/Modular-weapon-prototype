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
var on_card: Callable

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
	return talking() or (card_title != "" and card_blocks)


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
	if talking():
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


func _wrap(text: String, width: float) -> Array:
	var f := Art.font("PixelifySans-Regular")
	var out: Array = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > width and line != "":
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
	var silk := Art.font("Silkscreen-Regular")
	# Prompts over things you can use.
	for pr in prompts:
		var at := _to_screen(pr["at"])
		var text: String = pr["text"]
		var w := silk.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var x := at.x - (w + 22.0) * 0.5
		var bob := 1.0 if fmod(t, 0.8) < 0.4 else 0.0
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
		var f := Art.font("PixelifySans-Regular")
		var lines_h := _wrap(hint, 360.0)   # narrow enough to clear the health bars in the corners
		for i in lines_h.size():
			var lw := f.get_string_size(lines_h[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			root.draw_rect(Rect2(320.0 - lw * 0.5 - 6, hint_y - 10 + i * 14, lw + 12, 14), Color(PLATE.r, PLATE.g, PLATE.b, 0.66))
			_body(lines_h[i], Vector2(320.0 - lw * 0.5, hint_y + i * 14), Color("#e8e4bc"))

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
		var h := 54.0 + body_lines.size() * 14.0 + (16.0 if card_time <= 0.0 else 0.0)
		var r := Rect2(140, 180.0 - h * 0.5 - 10.0, 360, h)
		root.draw_style_box(_box("dialogue_box", 8), r)
		_head(card_title, Vector2(r.position.x, r.position.y + 30), AMBER, 16, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var y := r.position.y + 50.0
		for l in body_lines:
			_body(l, Vector2(r.position.x + 15, y), INK, r.size.x - 30, HORIZONTAL_ALIGNMENT_CENTER)
			y += 14.0
		if card_time <= 0.0 and card_age > 0.35:
			_head("Click, E or A to go on", Vector2(r.position.x, r.end.y - 9), DIM, 8, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
