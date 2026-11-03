extends Node2D
## Big, loud rune visuals. Kinds:
##   "wave"   Shockwave: a bright arc that rolls forward and hits everything it passes
##   "ring"   Hook's reach: a ring that snaps inwards
##   "chain"  Hook: a chain from the player to an enemy, following the enemy
##   "slash"  Cleave: a cross-slash on the enemy behind
##   "pulse"  Second Wind: a green ring bursting out from the player
##   "text"   floating label, like "+DODGE"

var kind := "wave"
var color := Color(1.0, 0.72, 0.25)
var dir := Vector2.RIGHT
var size := 1.0
var life := 0.5
var t := 0.0
var text := ""
# wave
var speed := 720.0
var half_width := 55.0
var damage := 10.0
var knock := 380.0
var _hit := {}
# chain
var from_node: Node2D
var to_node: Node2D


func _ready() -> void:
	z_index = 20
	if kind == "wave":
		rotation = dir.angle()


func _physics_process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	if kind == "wave":
		position += dir * speed * delta
		_wave_hits()
	elif kind == "text":
		position.y -= 60.0 * delta
	queue_redraw()


func _wave_hits() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or _hit.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - global_position
		var along := rel.dot(dir)
		var side := absf(rel.dot(dir.orthogonal()))
		if along > -30.0 - e.radius and along < 24.0 + e.radius and side < half_width * size + e.radius:
			_hit[e.get_instance_id()] = true
			e.take_hit(damage, dir, knock, false, color)


func _draw() -> void:
	var k := t / life
	var fade := 1.0 - k
	match kind:
		"wave":
			# A thick glowing crescent, white-hot at the front edge, with a trail.
			var w := half_width * size
			for i in 4:
				var back := float(i) * 14.0
				var c := color
				c.a = fade * (0.85 - i * 0.2)
				_crescent(-back, w * (1.0 - i * 0.08), 24.0 - i * 4.0, c)
			var hot := Color(1, 1, 0.9, fade)
			_crescent(6.0, w * 0.92, 8.0, hot)
		"ring":
			var r := lerpf(size, size * 0.2, ease(k, 0.5))
			var c := color
			c.a = fade
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, c, 6.0 * fade + 2.0)
			c.a = fade * 0.15
			draw_circle(Vector2.ZERO, r, c)
		"chain":
			if not is_instance_valid(from_node) or not is_instance_valid(to_node):
				return
			var a := from_node.global_position - global_position
			var b := to_node.global_position - global_position
			var n := int(a.distance_to(b) / 12.0) + 1
			var c := color
			c.a = fade
			draw_line(a, b, Color(0.2, 0.15, 0.1, fade), 6.0)
			for i in n + 1:
				var p := a.lerp(b, float(i) / n)
				draw_arc(p, 5.0, 0.0, TAU, 8, c, 2.5)
			draw_circle(b, 9.0 * fade + 3.0, c)
		"slash":
			var c := color
			c.a = fade
			var s := 30.0 * size * (0.6 + k * 0.4)
			draw_line(Vector2(-s, -s), Vector2(s, s), c, 7.0 * fade + 2.0)
			draw_line(Vector2(-s, s), Vector2(s, -s), c, 7.0 * fade + 2.0)
			draw_line(Vector2(-s, -s) * 0.7, Vector2(s, s) * 0.7, Color(1, 1, 1, fade), 2.0)
		"pulse":
			var c := color
			c.a = fade
			draw_arc(Vector2.ZERO, lerpf(20.0, 140.0 * size, k), 0.0, TAU, 48, c, 10.0 * fade + 2.0)
			c.a = fade * 0.25
			draw_circle(Vector2.ZERO, lerpf(20.0, 140.0 * size, k), c)
		"text":
			var font := ThemeDB.fallback_font
			var c := color
			c.a = fade
			draw_string_outline(font, Vector2(-80, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 160, 22, 6, Color(0, 0, 0, fade))
			draw_string(font, Vector2(-80, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 160, 22, c)


## A curved band facing +x (the node is rotated to the wave's direction).
func _crescent(x: float, w: float, thick: float, c: Color) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var y := lerpf(-w, w, float(i) / n)
		var bend := -pow(y / w, 2.0) * w * 0.35
		pts.append(Vector2(x + bend, y))
	draw_polyline(pts, c, thick)
