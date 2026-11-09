extends Node2D
## Floating damage number.

const LIFE := 0.7

var text := ""
var color := Color.WHITE
var font_size := 16
var t := 0.0
var drift := Vector2.ZERO


func _ready() -> void:
	# Effects place and move themselves every frame, so they skip the smoothing
	# the engine does between physics ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	z_index = 50
	drift = Vector2(randf_range(-25.0, 25.0), -70.0)


func _process(delta: float) -> void:
	t += delta
	position += drift * delta
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var c := color
	c.a = 1.0 - pow(t / LIFE, 2.0)
	var font := ThemeDB.fallback_font
	var pos := Vector2(-30.0, 0.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 60.0, font_size, 4, Color(0, 0, 0, c.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 60.0, font_size, c)
