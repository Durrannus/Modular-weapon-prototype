extends Node2D
## Floating damage number.

const Art := preload("res://scripts/art.gd")
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
	material = Art.unshaded()   # numbers stay bright in the dark
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
	var font := Art.font("Silkscreen-Regular")
	var pos := Vector2(-40.0, 0.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, font_size, 8, Color(0.06, 0.04, 0.09, c.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, font_size, c)
