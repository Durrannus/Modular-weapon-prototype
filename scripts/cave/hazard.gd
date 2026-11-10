extends Node2D
## A warning on the ground that turns into a hit: a circle (the guardian's slam,
## falling rocks) or a lane (its charge). It fills up over `delay`, then hurts
## every player inside. Lanes only warn; the charge itself does the damage.

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const SpriteOnce := preload("res://scripts/fx/sprite_once.gd")

var shape := "circle"      # "circle" or "lane"
var radius := 80.0
var delay := 0.7
var damage := 20.0
var length := 400.0        # lane
var width := 70.0          # lane
var dir := Vector2.RIGHT   # lane
var impact := "slam"       # what plays when it lands: "slam", "rock" or ""
var follow: Node2D = null  # a lane follows the guardian while it aims
var t := 0.0
var done := false


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	z_index = -5
	# A warning has to read at a glance, so the cave's darkness doesn't dim it.
	material = Art.unshaded()
	add_to_group("hazards")


func _physics_process(delta: float) -> void:
	t += delta
	if is_instance_valid(follow):
		global_position = follow.global_position
	if not done and t >= delay:
		done = true
		_land()
	if t >= delay + 0.12:
		queue_free()
	queue_redraw()


func _land() -> void:
	if shape != "circle" or damage <= 0.0:
		return
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.is_down and p.global_position.distance_to(global_position) <= radius + 10.0:
			p.take_damage(damage, global_position)
	if impact == "":
		return
	Sfx.play(self, "slam", -3.0 if impact == "slam" else -8.0, 1.0 if impact == "slam" else 1.5)
	var tex := Art.texture("cave/slam_impact.png")
	if tex != null:
		# The art's hit circle is 28 px in radius, so radius / 56 scales it to ours.
		var info: Dictionary = Art.json("cave/cave.json").get("fx", {}).get("slam_impact", {})
		var o: Array = info.get("origin", [48, 48])
		var n := SpriteOnce.new()
		n.texture = tex
		n.glow_texture = Art.glow_texture("cave/slam_impact.png")
		n.frames = int(info.get("frames", 6))
		n.fps = float(info.get("fps", 14))
		n.origin = Vector2(o[0], o[1])
		n.size = radius / 56.0
		get_parent().add_child(n)
		n.z_index = -4
		n.global_position = global_position
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.rig != null:
			p.rig.add_shake(9.0 if impact == "slam" else 4.0)
			break


func _draw() -> void:
	var k := clampf(t / delay, 0.0, 1.0)
	var hot := Color("#ff5a3c")
	var pulse := 0.75 + 0.25 * sin(t * 26.0)
	if shape == "circle":
		draw_circle(Vector2.ZERO, radius, Color(hot.r, hot.g, hot.b, 0.16))
		draw_circle(Vector2.ZERO, radius * k, Color(hot.r, hot.g, hot.b, 0.3))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(hot.r, hot.g, hot.b, 0.9 * pulse), 3.0)
	else:
		var n := dir.orthogonal() * width * 0.5
		var a := Vector2.ZERO
		var b := dir * length
		draw_colored_polygon(PackedVector2Array([a - n, b - n, b + n, a + n]), Color(hot.r, hot.g, hot.b, 0.14 + 0.18 * k))
		draw_line(a - n, b - n, Color(hot.r, hot.g, hot.b, 0.85 * pulse), 3.0)
		draw_line(a + n, b + n, Color(hot.r, hot.g, hot.b, 0.85 * pulse), 3.0)
		# Chevrons marching along the lane show which way it's coming.
		var step := 64.0
		var off := fmod(t * 220.0, step)
		var x := off
		while x < length - 16.0:
			var c := dir * x
			draw_polyline(PackedVector2Array([c - n * 0.5 - dir * 12.0, c, c + n * 0.5 - dir * 12.0]), Color(hot.r, hot.g, hot.b, 0.55), 3.0)
			x += step
