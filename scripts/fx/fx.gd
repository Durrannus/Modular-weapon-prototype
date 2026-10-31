extends Node2D
## Short-lived attack and hit visuals.

var kind := "slash"
var dir := Vector2.RIGHT
var radius := 70.0
var color := Color.WHITE
var life := 0.16
var t := 0.0


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := t / life
	var c := color
	c.a = 1.0 - k
	var width := 10.0 * (1.0 - k) + 2.0
	match kind:
		"stab":
			draw_line(dir * 20.0, dir * radius, c, width)
		"spin":
			draw_arc(Vector2.ZERO, radius * (0.8 + 0.2 * k), 0.0, TAU, 40, c, width)
		"burst":
			c.a *= 0.7
			draw_circle(Vector2.ZERO, radius * (0.4 + k), c)
		_:
			var a := dir.angle()
			draw_arc(Vector2.ZERO, radius * (0.85 + 0.15 * k), a - deg_to_rad(68.0), a + deg_to_rad(68.0), 24, c, width)
