extends Node2D
## Big, loud rune visuals. Kinds:
##   "wave"   Shockwave: a bright arc that rolls forward and hits everything it passes
##   "ring"   a ring that snaps inwards
##   "chain"  Hook: a chain from the player to an enemy, following the enemy (or,
##            with nobody on it, out to to_at and back)
##   "spin"   Whirlwind: a blade arc that sweeps a full circle round from_node, hitting as it passes
##   "slash"  Cleave: a cross-slash on the enemy behind
##   "pulse"  Second Wind: a green ring bursting out from the player
##   "text"   floating label, like "+DODGE"
##   "crack"  Quake: a crack in the floor that runs out along dir for `reach` px

const Art := preload("res://scripts/art.gd")
const Words := preload("res://scripts/fx/words.gd")
const SwordArt := preload("res://scripts/weapon/sword_art.gd")

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
var from_offset := Vector2.ZERO
var to_node: Node2D
var to_at := Vector2.INF   # chain: where it flies to and comes back from, with no to_node
var spin_side := 1.0
var drawn := true     # false when a sprite strip draws the effect instead  # Whirlwind: +1 clockwise, -1 the other way
var reach := 240.0    # crack: how long it is
const CRACK_RUN := 0.1     # a crack runs out to its full length over this long
const CRACK_TAIL := 26.0   # the end piece runs out to a point about this far along (art pixels)


func _ready() -> void:
	# Effects place and move themselves every frame, so they skip the smoothing
	# the engine does between physics ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	z_index = 20
	if kind == "text":
		visible = false       # (until it has found its room among the other words)
	if kind == "wave":
		rotation = dir.angle()
	if kind in ["wave", "chain"]:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if kind == "wave" else CanvasItemMaterial.BLEND_MODE_MIX
		material = m


var placed := false   # "text": it has found its room among the other words (scripts/fx/words.gd)
var waited := 0.0


func _physics_process(delta: float) -> void:
	if kind == "text" and not placed:
		var at := Words.place(self, global_position)
		if at == Vector2.INF:
			visible = false
			waited += delta
			if waited >= Words.WAIT_MOST:
				queue_free()
			return
		global_position = at
		placed = true
		visible = true
	t += delta
	if t >= life:
		queue_free()
		return
	if kind == "wave":
		position += dir * speed * delta
		_wave_hits()
	elif kind == "spin":
		if is_instance_valid(from_node):
			global_position = from_node.global_position + from_offset
		_spin_hits()
	elif kind == "text":
		position.y -= Words.RISE * delta
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


## Whirlwind: everything the sweeping arc has passed over (inside the circle) gets hit once.
func _spin_hits() -> void:
	var swept := TAU * minf(t / life * 1.15, 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or _hit.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - global_position
		if rel.length() > size + e.radius:
			continue
		if fposmod((rel.angle() - dir.angle()) * spin_side, TAU) > swept:
			continue
		_hit[e.get_instance_id()] = true
		var away := rel.normalized() if rel.length() > 1.0 else dir
		e.take_hit(damage, away, knock, false, color)


func _draw() -> void:
	var k := t / life
	var fade := 1.0 - k
	match kind:
		"wave" when Art.texture("swing/fx/shockwave_wave.png") != null:
			# The strip fades itself out (a hatch dissolve drawn into the frames), so it plays at full strength.
			var tex := Art.texture("swing/fx/shockwave_wave.png")
			var info: Dictionary = SwordArt.data().get("fx", {}).get("shockwave_wave", {})
			var n := int(info.get("frames", 6))
			var o: Array = info.get("origin", [50, 44])
			Art.draw_strip(self, tex, n, mini(int(k * n), n - 1), Vector2.ZERO, Vector2(o[0], o[1]), false, Color.WHITE, Art.PIXEL * size)
		"chain" when Art.texture("swing/fx/chain_link.png") != null:
			var empty := to_node == null and to_at != Vector2.INF
			if not is_instance_valid(from_node) or (not empty and not is_instance_valid(to_node)):
				return
			var a := from_node.global_position + from_offset - global_position
			var b := (to_at if empty else to_node.global_position) - global_position
			# The chain shoots out over the first 0.08 s, then holds as the enemy is yanked in.
			# (With nobody on it, it comes straight back.)
			var reach := clampf(t / 0.08, 0.0, 1.0)
			if empty:
				reach = minf(reach, clampf((life - t) / maxf(life - 0.12, 0.01), 0.0, 1.0))
			var end := a.lerp(b, reach)
			var link := Art.texture("swing/fx/chain_link.png")
			var step := 5.0 * Art.PIXEL
			var n := int(a.distance_to(end) / step)
			var ang := (b - a).angle()
			for i in n + 1:
				var p := a + (end - a).normalized() * step * i
				Art.draw_strip(self, link, 2, i % 2, p, Vector2(3, 2), false, Color(1, 1, 1, fade * 1.5), Art.PIXEL, ang)
			var head := Art.texture("swing/fx/hook_head_bite.png" if reach >= 1.0 and not empty else "swing/fx/hook_head.png")
			if head != null:
				# (The claw is drawn about the chain's line, its eye at the left middle.)
				Art.draw_strip(self, head, 1, 0, end, Vector2(2, 8), false, Color(1, 1, 1, fade * 1.5), Art.PIXEL, ang)
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
		"spin" when not drawn:
			pass
		"spin":
			# The leading edge sweeps once round; a fading trail follows it.
			var lead := dir.angle() + spin_side * TAU * minf(k * 1.15, 1.0)
			var trail := 2.4
			for i in 6:
				var a0 := lead - spin_side * trail * (float(i) / 6.0)
				var a1 := lead - spin_side * trail * (float(i + 1) / 6.0)
				var c := color
				c.a = fade * (0.9 - i * 0.14)
				draw_arc(Vector2.ZERO, size * 0.82, minf(a0, a1), maxf(a0, a1), 10, c, size * 0.32 * (1.0 - i * 0.1))
			draw_arc(Vector2.ZERO, size, lead - spin_side * 0.5 if spin_side > 0 else lead, lead if spin_side > 0 else lead + 0.5, 6, Color(1, 1, 0.92, fade), 3.0)
		"ring":
			var r := lerpf(size, size * 0.2, ease(k, 0.5))
			var c := color
			c.a = fade
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, c, 6.0 * fade + 2.0)
			c.a = fade * 0.06
			draw_circle(Vector2.ZERO, r, c)
		"chain":
			var empty := to_node == null and to_at != Vector2.INF
			if not is_instance_valid(from_node) or (not empty and not is_instance_valid(to_node)):
				return
			var a := from_node.global_position - global_position
			var b := (to_at if empty else to_node.global_position) - global_position
			if empty:
				b = a.lerp(b, minf(clampf(t / 0.08, 0.0, 1.0), clampf((life - t) / maxf(life - 0.12, 0.01), 0.0, 1.0)))
			var n := int(a.distance_to(b) / 12.0) + 1
			var c := color
			c.a = fade
			draw_line(a, b, Color(0.2, 0.15, 0.1, fade), 6.0)
			for i in n + 1:
				var p := a.lerp(b, float(i) / n)
				draw_arc(p, 5.0, 0.0, TAU, 8, c, 2.5)
			draw_circle(b, 9.0 * fade + 3.0, c)
		"crack" when Art.texture("fx/quake_crack.png") != null:
			# The art's pieces laid end to end along the aim, then the piece that runs
			# out to a point. Whole pieces only (their ends join on the middle row),
			# stretched a little so the crack is exactly as long as what it hits.
			var tex := Art.texture("fx/quake_crack.png")
			var tip := Art.texture("fx/quake_crack_end.png")
			var n := 6
			var frame := mini(int(k * n), n - 1)
			var fw := float(tex.get_width()) / n
			var fh := float(tex.get_height())
			var art_len := reach * clampf(t / CRACK_RUN, 0.05, 1.0) / Art.PIXEL
			var tail := CRACK_TAIL if tip != null else 0.0
			var pieces := maxi(roundi((art_len - tail) / fw), 0)
			var stretch := art_len / maxf(float(pieces) * fw + tail, 1.0)
			draw_set_transform(Vector2.ZERO, dir.angle(), Vector2(Art.PIXEL * stretch, Art.PIXEL * maxf(size, 1.0)))
			for i in pieces:
				draw_texture_rect_region(tex, Rect2(float(i) * fw, -fh * 0.5, fw, fh), Rect2(frame * fw, 0, fw, fh))
			if tip != null:
				draw_texture_rect_region(tip, Rect2(float(pieces) * fw, -fh * 0.5, fw, fh), Rect2(frame * fw, 0, fw, fh))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"crack":
			# (No picture: a dark split with ember light in it.)
			var far := dir * reach * clampf(t / CRACK_RUN, 0.05, 1.0)
			draw_line(Vector2.ZERO, far, Color(0.1, 0.08, 0.16, fade), 7.0 * size)
			draw_line(Vector2.ZERO, far, Color(color.r, color.g, color.b, fade * fade), 2.5 * size)
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
			var font := Art.font(Art.TEXT_BOLD)
			var c := color
			c.a = fade
			draw_string_outline(font, Vector2(-140, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 280, Art.TEXT_BOLD_SIZE * 2, 8, Color(0.06, 0.04, 0.09, fade))
			draw_string(font, Vector2(-140, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 280, Art.TEXT_BOLD_SIZE * 2, c)


## "text": the room its letters take, in the world (scripts/fx/words.gd).
func word_box() -> Rect2:
	return word_box_at(global_position)


func word_box_at(at: Vector2) -> Rect2:
	return Words.box(Art.font(Art.TEXT_BOLD), Art.TEXT_BOLD_SIZE * 2, text, at)


## A curved band facing +x (the node is rotated to the wave's direction).
func _crescent(x: float, w: float, thick: float, c: Color) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var y := lerpf(-w, w, float(i) / n)
		var bend := -pow(y / w, 2.0) * w * 0.35
		pts.append(Vector2(x + bend, y))
	draw_polyline(pts, c, thick)
