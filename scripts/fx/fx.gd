extends Node2D
## Short-lived attack and hit visuals.
## kind: "arc", "line", "circle", "burst" or "chain".

var kind := "arc"
var dir := Vector2.RIGHT
var radius := 70.0
var arc := 120.0
var width := 16.0
var thick := false
var to := Vector2.ZERO
var color := Color.WHITE
var life := 0.16
var t := 0.0


func _ready() -> void:
	z_index = 5
	if thick:
		life = 0.26


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
	var line_w := (16.0 if thick else 10.0) * (1.0 - k) + 2.0
	match kind:
		"none":
			pass
		"line":
			draw_line(dir * 20.0, dir * radius, c, minf(width, 14.0) * (1.0 - k) + 2.0)
		"circle":
			draw_arc(Vector2.ZERO, radius * (0.8 + 0.2 * k), 0.0, TAU, 40, c, line_w)
		"burst":
			c.a *= 0.55
			draw_circle(Vector2.ZERO, radius * (0.4 + 0.6 * k), c)
		"chain":
			# a jagged lightning line
			var pts := PackedVector2Array()
			var n := 6
			for i in n + 1:
				var p := to * (float(i) / n)
				if i > 0 and i < n:
					p += to.orthogonal().normalized() * randf_range(-8.0, 8.0)
				pts.append(p)
			draw_polyline(pts, c, 3.0)
		_:
			var a := dir.angle()
			var half := deg_to_rad(arc * 0.5)
			draw_arc(Vector2.ZERO, radius * (0.85 + 0.15 * k), a - half, a + half, 24, c, line_w)
