extends Node2D
## Floating damage number.

const Art := preload("res://scripts/art.gd")
const Words := preload("res://scripts/fx/words.gd")
const LIFE := 0.7

var text := ""
var color := Color.WHITE
var crit := false     # a crit is written bigger and bold
var t := 0.0
var drift := Vector2.ZERO
var word := false     # a word (CHALLENGED, BLOCKED), not a number: it rises straight up and keeps clear of other words
var placed := false   # (a word: it has found its room; until then it waits unseen, scripts/fx/words.gd)
var waited := 0.0


func _ready() -> void:
	# Effects place and move themselves every frame, so they skip the smoothing
	# the engine does between physics ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	z_index = 50
	material = Art.unshaded()   # numbers stay bright in the dark
	drift = Vector2(randf_range(-25.0, 25.0), -70.0)
	word = text != "" and not (text.substr(0, 1).is_valid_int())
	if word:
		drift = Vector2(0.0, -Words.RISE)
		visible = false


func _process(delta: float) -> void:
	if word and not placed:
		var at := Words.place(self, global_position)
		if at == Vector2.INF:
			waited += delta
			if waited >= Words.WAIT_MOST:
				queue_free()
			return
		global_position = at
		placed = true
		visible = true
	t += delta
	position += drift * delta
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _font() -> Font:
	return Art.font(Art.TEXT_BOLD if crit else Art.TEXT_SMALL)


func _size() -> int:
	return (Art.TEXT_BOLD_SIZE if crit else Art.TEXT_SMALL_SIZE) * 2


## How wide the words are written: at least 80, and as wide as the words, so a long word over an enemy
## (CHALLENGED) is never cut short.
func width() -> float:
	return maxf(80.0, ceilf(_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size()).x) + 8.0)


## The room the word's letters take, in the world (scripts/fx/words.gd).
func word_box() -> Rect2:
	return word_box_at(global_position)


func word_box_at(at: Vector2) -> Rect2:
	return Words.box(_font(), _size(), text, at)


func _draw() -> void:
	var c := color
	c.a = 1.0 - pow(t / LIFE, 2.0)
	var font := _font()
	var font_size := _size()
	var w := width()
	var pos := Vector2(-w * 0.5, 0.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, 8, Color(0.06, 0.04, 0.09, c.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, c)
