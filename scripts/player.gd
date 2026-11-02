extends CharacterBody2D

const WeaponBuild := preload("res://scripts/weapon/weapon_build.gd")
## The player: movement, dodge, aiming, and running the combo the weapon build
## produced. Each combo step is one move (slash, stab, lunge, spin, overhead).
## Blade elements add effects on hit (fire, water, lightning, steam, electrified).

const Fx := preload("res://scripts/fx/fx.gd")
const Art := preload("res://scripts/art.gd")

const MOVE_SPEED := 250.0
const RADIUS := 16.0
const COMBO_WINDOW := 0.5      # stop attacking this long and the combo resets
const FINISHER_RECOVERY := 0.22  # extra pause after the hilt move

const DODGE_SPEED := 640.0
const DODGE_TIME := 0.12
const DODGE_MAX_CHARGES := 1
const DODGE_REFILL := 0.9      # seconds per charge

## The five sword moves. Times are at attack speed 1.0.
## windup: time before the hit lands. time: whole move. reach in pixels (times blade reach).
## arc: degrees for arcs. width: half-width for lines. power: damage multiplier.
const MOVES := {
	"slash": {"windup": 0.05, "time": 0.28, "shape": "arc", "arc": 120.0, "reach": 74.0, "power": 1.0, "knock": 230.0},
	"stab": {"windup": 0.06, "time": 0.25, "shape": "line", "width": 16.0, "reach": 115.0, "power": 1.15, "knock": 320.0},
	"lunge": {"windup": 0.15, "time": 0.38, "shape": "line", "width": 24.0, "reach": 85.0, "power": 1.3, "knock": 300.0, "dash": 170.0},
	"spin": {"windup": 0.07, "time": 0.44, "shape": "circle", "reach": 72.0, "power": 0.85, "knock": 260.0},
	"overhead": {"windup": 0.24, "time": 0.58, "shape": "arc", "arc": 70.0, "reach": 95.0, "power": 2.1, "knock": 460.0, "shake": 11.0},
}

var color := Color(0.35, 0.7, 1.0)
var max_hp := 100.0
var hp := 100.0
var spawn_point := Vector2.ZERO
var aim_dir := Vector2.RIGHT
var using_pad := false
var camera: Camera2D
var shake := 0.0

var weapon: Dictionary = {}
var step_index := 0        # next combo step
var current_step := -1     # step being played, -1 when idle
var step_timer := 0.0
var step_elapsed := 0.0
var hit_time := -1.0       # when the current move's hit lands (-1 once landed)
var step_duration := 0.0
var queued := false
var combo_timer := 0.0
var lunge_timer := 0.0
var lunge_dir := Vector2.RIGHT
var lunge_speed := 0.0
var dodge_timer := 0.0
var dodge_dir := Vector2.RIGHT
var dodge_charges := DODGE_MAX_CHARGES
var dodge_refill := 0.0
var invuln := 0.0
var anim_move := ""
var anim_dir := Vector2.RIGHT
var knocked_out_timer := 0.0
var facing := "down"       # nearest of 4 directions to the aim: up, down, left, right
var weapon_layer: Node2D
var weapon_group: CanvasGroup  # holds the sword so it gets one outline
var anim_time := 0.0

## Where the body sprite's feet sit, relative to the player's centre.
const FEET := Vector2(0, 14)
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.zoom = Vector2(0.5, 0.5)  # 640x360 screen, world keeps its old units
	add_child(camera)
	camera.make_current()
	spawn_point = global_position
	# The sword is its own layer so it can sit behind the body when facing up.
	# All sword parts and the hand go in one CanvasGroup so the outline shader
	# draws one outline round the assembled sword.
	weapon_group = CanvasGroup.new()
	weapon_group.name = "Weapon"
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	weapon_group.material = mat
	add_child(weapon_group)
	weapon_layer = Node2D.new()
	weapon_group.add_child(weapon_layer)
	weapon_layer.draw.connect(_draw_weapon)
	# A soft light that follows the player, so the sword's colours read in the dark.
	var light := PointLight2D.new()
	light.texture = Art.light_texture()
	light.texture_scale = 2.4
	light.energy = 0.6
	light.color = Color(0.95, 0.9, 1.0)
	add_child(light)


func set_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x) - 80
	camera.limit_top = int(rect.position.y) - 80
	camera.limit_right = int(rect.end.x) + 80
	camera.limit_bottom = int(rect.end.y) + 80


func set_weapon(stats: Dictionary) -> void:
	weapon = stats
	_reset_combo()


func _reset_combo() -> void:
	step_index = 0
	current_step = -1
	hit_time = -1.0
	queued = false
	combo_timer = 0.0
	lunge_timer = 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		using_pad = false
	elif event is InputEventJoypadButton:
		using_pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4:
		using_pad = true


func _physics_process(delta: float) -> void:
	invuln = maxf(invuln - delta, 0.0)

	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_aim(move)
	_update_dodge(delta, move)

	var speed := MOVE_SPEED * (1.0 + float(weapon.get("move_speed", 0.0)))
	var vel := move * speed
	if current_step >= 0:
		vel *= 0.55  # you slow down while swinging
	if dodge_timer > 0.0:
		dodge_timer -= delta
		vel = dodge_dir * DODGE_SPEED
	elif lunge_timer > 0.0:
		lunge_timer -= delta
		vel = lunge_dir * lunge_speed
	velocity = vel
	move_and_slide()

	_update_combat(delta)


func _update_aim(move: Vector2) -> void:
	if using_pad:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.3:
			aim_dir = stick.normalized()
		elif move.length() > 0.2:
			aim_dir = move.normalized()
	else:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 4.0:
			aim_dir = to_mouse.normalized()


# --- Dodge ------------------------------------------------------------------
# Everyone has a short step. One charge that refills. Cancels the swing and
# resets the combo.

func _update_dodge(delta: float, move: Vector2) -> void:
	if dodge_charges < DODGE_MAX_CHARGES:
		dodge_refill += delta
		if dodge_refill >= DODGE_REFILL:
			dodge_refill = 0.0
			dodge_charges += 1
	if Input.is_action_just_pressed("dash") and dodge_charges > 0 and dodge_timer <= 0.0:
		dodge_charges -= 1
		dodge_dir = move.normalized() if move.length() > 0.1 else aim_dir
		dodge_timer = DODGE_TIME
		invuln = maxf(invuln, DODGE_TIME + 0.06)
		_reset_combo()


# --- Combo ------------------------------------------------------------------

func _steps() -> Array:
	return weapon.get("steps", [])


func _speed() -> float:
	return maxf(float(weapon.get("speed", 1.0)), 0.2)


func _update_combat(delta: float) -> void:
	if Input.is_action_just_pressed("attack") and dodge_timer <= 0.0:
		if current_step < 0:
			_start_step()
		else:
			queued = true

	if current_step >= 0:
		step_elapsed += delta
		if hit_time >= 0.0 and step_elapsed >= hit_time:
			hit_time = -1.0
			_do_move(_steps()[current_step]["move"])
		if step_elapsed >= step_duration:
			_end_step()
	elif combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			step_index = 0


func _start_step() -> void:
	var steps := _steps()
	if steps.is_empty():
		return
	if step_index >= steps.size():
		step_index = 0
	current_step = step_index
	var move: String = steps[current_step]["move"]
	var info: Dictionary = MOVES.get(move, MOVES["slash"])
	var speed := _speed()
	step_elapsed = 0.0
	hit_time = float(info["windup"]) / speed
	step_duration = float(info["time"]) / speed
	if current_step == steps.size() - 1 and steps.size() > 1:
		step_duration += FINISHER_RECOVERY / speed
	queued = false
	anim_move = move
	anim_dir = aim_dir
	if info.has("dash"):
		lunge_dir = aim_dir
		lunge_timer = hit_time
		lunge_speed = float(info["dash"]) / maxf(hit_time, 0.01)


func _end_step() -> void:
	var steps := _steps()
	var was_last := current_step >= steps.size() - 1
	step_index = 0 if was_last else current_step + 1
	current_step = -1
	if queued:
		queued = false
		_start_step()
	else:
		combo_timer = COMBO_WINDOW


func _do_move(move: String) -> void:
	var info: Dictionary = MOVES.get(move, MOVES["slash"])
	var area := 1.0 + float(weapon.get("area", 0.0))
	var reach: float = float(info["reach"]) * float(weapon.get("reach", 1.0)) * area
	var dmg: float = float(weapon.get("damage", 4.0)) * float(info["power"])
	var knock: float = info["knock"]
	var dir := aim_dir
	var hits := 0

	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - global_position
		var r: float = e.radius
		var hit := false
		var kdir := rel.normalized() if rel.length() > 0.01 else dir
		match str(info["shape"]):
			"line":
				var along := rel.dot(dir)
				var side := absf(rel.dot(dir.orthogonal()))
				hit = along > -r and along <= reach + r and side <= float(info["width"]) * area + r
				kdir = dir
			"circle":
				hit = rel.length() <= reach + r
			_:
				var half_arc := deg_to_rad(float(info["arc"]) * 0.5 * (1.0 + (area - 1.0) * 0.5))
				hit = rel.length() <= reach + r and (rel.length() < r + RADIUS or absf(dir.angle_to(rel)) <= half_arc)
		if hit:
			_hit_enemy(e, dmg, kdir, knock)
			hits += 1

	var fx := Fx.new()
	fx.kind = str(info["shape"])
	fx.dir = dir
	fx.radius = reach
	fx.arc = float(info.get("arc", 120.0))
	fx.width = float(info.get("width", 16.0)) * area
	fx.color = weapon.get("hit_color", Color.WHITE)
	fx.thick = move == "overhead"
	add_child(fx)

	if hits > 0:
		shake = maxf(shake, float(info.get("shake", 4.0)) + hits)
		_hitstop(0.07 if move == "overhead" else 0.035)


func _hit_enemy(e, dmg: float, kdir: Vector2, knock: float) -> void:
	var crit := randf() < float(weapon.get("crit", 0.05))
	var final := dmg * (float(weapon.get("crit_damage", 1.5)) if crit else 1.0)
	e.take_hit(final, kdir, knock, crit, weapon.get("hit_color", Color.WHITE))
	_apply_elements(e, final)


# --- Elements ---------------------------------------------------------------

func _apply_elements(target, dmg: float) -> void:
	var elements: Array = weapon.get("elements", [])
	var combos: Array = weapon.get("combos", [])
	if "fire" in elements:
		target.apply_burn(maxf(1.0, dmg * 0.12), 2.5)
	if "water" in elements:
		target.apply_slow(0.45, 2.0)
	if "lightning" in elements:
		var electrified := "electrified" in combos
		_chain(target, dmg * 0.5, 3 if electrified else 1, electrified)
	if "steam" in combos:
		_steam(target, dmg * 0.4)


## Lightning jumps to the nearest enemy nearby. Electrified jumps further and stuns.
func _chain(from_enemy, dmg: float, jumps: int, stun: bool) -> void:
	var color_key := "electrified" if stun else "lightning"
	var col: Color = WeaponBuild.ELEMENT_COLORS[color_key]
	var hit_ids := {from_enemy.get_instance_id(): true}
	var current = from_enemy
	if stun and is_instance_valid(current) and not current.dead:
		current.apply_stun(0.35)
	for i in jumps:
		var best = null
		var best_d := 150.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead or hit_ids.has(e.get_instance_id()):
				continue
			var d: float = e.global_position.distance_to(current.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			return
		hit_ids[best.get_instance_id()] = true
		var line := Fx.new()
		line.kind = "chain"
		line.to = best.global_position - current.global_position
		line.color = col
		line.life = 0.18
		get_parent().add_child(line)
		line.global_position = current.global_position
		var dir: Vector2 = (best.global_position - current.global_position).normalized()
		best.take_hit(dmg, dir, 60.0, false, col)
		if stun:
			best.apply_stun(0.5)
		current = best


## Steam bursts around the target and scalds enemies next to it.
func _steam(target, dmg: float) -> void:
	var col: Color = WeaponBuild.ELEMENT_COLORS["steam"]
	var radius := 64.0 * (1.0 + float(weapon.get("area", 0.0)))
	var burst := Fx.new()
	burst.kind = "burst"
	burst.radius = radius
	burst.color = col
	burst.life = 0.3
	get_parent().add_child(burst)
	burst.global_position = target.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e == target:
			continue
		if e.global_position.distance_to(target.global_position) <= radius + e.radius:
			var dir: Vector2 = (e.global_position - target.global_position).normalized()
			e.take_hit(dmg, dir, 140.0, false, col)


func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


# --- Taking damage ------------------------------------------------------------

func take_damage(amount: float) -> void:
	if invuln > 0.0:
		return
	hp -= amount
	invuln = 0.7
	shake = maxf(shake, 9.0)
	if hp <= 0.0:
		hp = max_hp
		global_position = spawn_point
		knocked_out_timer = 2.0
		invuln = 2.0
		_reset_combo()


func _process(delta: float) -> void:
	knocked_out_timer = maxf(knocked_out_timer - delta, 0.0)
	shake = move_toward(shake, 0.0, 40.0 * delta)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	facing = _facing_of(aim_dir if current_step < 0 else anim_dir)
	weapon_group.show_behind_parent = facing == "up"
	anim_time += delta
	# The outline is one game pixel: as many screen pixels as the window's scale.
	var scale_px := maxf(floorf(float(get_window().size.y) / 360.0), 1.0)
	(weapon_group.material as ShaderMaterial).set_shader_parameter("px", scale_px)
	queue_redraw()
	weapon_layer.queue_redraw()


static func _facing_of(d: Vector2) -> String:
	if absf(d.x) > absf(d.y):
		return "right" if d.x > 0.0 else "left"
	return "down" if d.y > 0.0 else "up"


# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	var blink := invuln > 0.0 and dodge_timer <= 0.0 and int(invuln * 20.0) % 2 == 0
	draw_set_transform(FEET, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.3))  # shadow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var strip := _body_strip()
	var tex := Art.texture("body/ivy_%s.png" % strip[0])
	if tex != null:
		var tint := Color(2.0, 2.0, 2.0) if blink else Color.WHITE
		Art.draw_strip(self, tex, strip[1], strip[2], FEET, _body_origin(), false, tint)
		return
	# Stand-in body: a circle with eyes showing which way it faces.
	var body := Color(1, 1, 1) if blink else color
	if dodge_timer > 0.0:
		body = color.lightened(0.4)
		body.a = 0.6
	draw_circle(Vector2.ZERO, RADIUS, body)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 28, color.darkened(0.45), 2.5)
	if facing != "up":
		var eye := Color(0.08, 0.1, 0.16)
		if facing == "down":
			draw_rect(Rect2(Vector2(-6, 2), Vector2(3, 5)), eye)
			draw_rect(Rect2(Vector2(3, 2), Vector2(3, 5)), eye)
		else:
			var x := 7.0 if facing == "right" else -10.0
			draw_rect(Rect2(Vector2(x, -3), Vector2(3, 5)), eye)


## [animation name, frame count, current frame] for the body sprite.
func _body_strip() -> Array:
	var anim := "idle"
	var frame := 0
	var frames := 4
	if dodge_timer > 0.0:
		anim = "dodge"
		frames = 3
		frame = clampi(int((1.0 - dodge_timer / DODGE_TIME) * 3.0), 0, 2)
	elif velocity.length() > 20.0:
		anim = "walk"
		frames = 6
		frame = int(anim_time * 10.0) % frames
	else:
		frame = int(anim_time * 6.0) % frames
	return ["%s_%s" % [anim, facing], frames, frame]


func _body_origin() -> Vector2:
	var o: Array = Art.anchors().get("body", {}).get("origin_feet", [28, 52])
	return Vector2(o[0], o[1])


## Where the hand is (the sword's pivot), relative to the player's centre.
func _hand_point() -> Vector2:
	var strip := _body_strip()
	var strips: Dictionary = Art.anchors().get("body", {}).get("strips", {})
	var info: Dictionary = strips.get(strip[0], {})
	var hands: Array = info.get("hand", [])
	if hands.is_empty():
		return FEET + Vector2(0, -12)
	var h: Array = hands[posmod(int(strip[2]), hands.size())]
	return FEET + (Vector2(h[0], h[1]) - _body_origin()) * Art.PIXEL


# --- Weapon layer --------------------------------------------------------------
# The sword is assembled from the parts on the grid: each part is drawn on its
# own grid cells (5 art pixels per cell), the whole thing is rotated to point at
# the aim and held at the hand. The grid's top row is the tip.

const HAND_CELL := 5.0                      # art pixels per grid cell in hand
const HAND_GRIP := Vector2(1.5, 5.0)        # where the hand holds it, in grid cells

func _sword_pose() -> Array:
	var angle := aim_dir.angle()
	var extend := 0.0
	if current_step >= 0:
		angle = anim_dir.angle()
		# Before the hit lands the sword is held back; after, it swings through (~0.14s).
		var after := 0.0
		if hit_time < 0.0:
			var info: Dictionary = MOVES.get(anim_move, MOVES["slash"])
			after = clampf((step_elapsed - float(info["windup"]) / _speed()) / 0.14, 0.0, 1.0)
		match anim_move:
			"stab", "lunge":
				extend = (sin(after * PI) * 26.0) if hit_time < 0.0 else -6.0
			"spin":
				angle += after * TAU
			"overhead":
				angle += -2.2 if hit_time >= 0.0 else lerpf(-2.2, 0.3, minf(after * 2.0, 1.0))
				extend = 0.0 if hit_time >= 0.0 else 6.0
			_:
				angle += -1.2 if hit_time >= 0.0 else lerpf(-1.2, 1.2, after)
	return [angle, extend]


func _draw_weapon() -> void:
	var layout: Array = weapon.get("layout", [])
	if layout.is_empty():
		return
	var pose := _sword_pose()
	var angle: float = pose[0]
	var d := Vector2.RIGHT.rotated(angle)
	var hand := _hand_point() + d * float(pose[1])
	# Art space: x right, y down, tip at the top. Rotate so "up" points along d.
	weapon_layer.draw_set_transform(hand, angle + PI * 0.5, Vector2(Art.PIXEL, Art.PIXEL))
	var c := HAND_CELL
	var grip := HAND_GRIP * c
	# Draw handle end first so the blade and guard sit on top.
	var order := layout.duplicate()
	order.sort_custom(func(a, b): return _layer_rank(a["type"]) < _layer_rank(b["type"]))
	for item in order:
		var cells: Array = item["cells"]
		var tex := Art.part_hand(item["id"])
		if tex != null and int(item.get("rotation", 0)) == 0:
			var top_left := Vector2(cells[0])
			for cell in cells:
				top_left = top_left.min(Vector2(cell))
			weapon_layer.draw_texture(tex, top_left * c - grip)
			continue
		_draw_part_shape(item, cells, c, grip)
	# The fist goes on the grip, on top of the sword.
	var fist := Art.texture("body/hand.png")
	if fist != null:
		weapon_layer.draw_texture(fist, -fist.get_size() * 0.5)
	weapon_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _layer_rank(t: int) -> int:
	# pommel, handle, charm, blade, hilt (guard over the blade's base)
	return [0, 1, 4, 3, 2][t]


## Stand-in for a part sprite: pixel blocks per cell, pointed tip on blades.
func _draw_part_shape(item: Dictionary, cells: Array, c: float, grip: Vector2) -> void:
	var col: Color = item["color"]
	var dark := col.darkened(0.45)
	var t: int = item["type"]
	for cell in cells:
		var o := Vector2(cell) * c - grip
		var above := cells.has(cell + Vector2i(0, -1))
		match t:
			3:  # blade
				if not above:
					weapon_layer.draw_colored_polygon(PackedVector2Array([o + Vector2(c * 0.5, 0), o + Vector2(c - 1, c * 0.6), o + Vector2(c - 1, c), o + Vector2(1, c), o + Vector2(1, c * 0.6)]), dark)
					weapon_layer.draw_colored_polygon(PackedVector2Array([o + Vector2(c * 0.5, 1), o + Vector2(c - 2, c * 0.65), o + Vector2(c - 2, c), o + Vector2(2, c), o + Vector2(2, c * 0.65)]), col)
				else:
					weapon_layer.draw_rect(Rect2(o + Vector2(1, 0), Vector2(c - 2, c)), dark)
					weapon_layer.draw_rect(Rect2(o + Vector2(2, 0), Vector2(c - 4, c)), col)
				weapon_layer.draw_rect(Rect2(o + Vector2(c * 0.5 - 0.5, 1.5), Vector2(1, c - 1.5)), col.lightened(0.35))
			2:  # hilt / guard
				weapon_layer.draw_rect(Rect2(o + Vector2(0, 1), Vector2(c, c - 2)), dark)
				weapon_layer.draw_rect(Rect2(o + Vector2(0, 2), Vector2(c, c - 4)), col)
			1:  # handle / grip
				weapon_layer.draw_rect(Rect2(o + Vector2(1.5, 0), Vector2(c - 3, c)), dark)
				weapon_layer.draw_rect(Rect2(o + Vector2(2, 0), Vector2(c - 4, c)), col)
				weapon_layer.draw_rect(Rect2(o + Vector2(1.5, c * 0.5), Vector2(c - 3, 1)), dark)
			0:  # pommel
				weapon_layer.draw_circle(o + Vector2(c * 0.5, c * 0.4), c * 0.4, dark)
				weapon_layer.draw_circle(o + Vector2(c * 0.5, c * 0.4), c * 0.28, col)
			_:  # charm: a small gem beside the grip
				weapon_layer.draw_colored_polygon(PackedVector2Array([o + Vector2(c * 0.5, 0.5), o + Vector2(c - 1, c * 0.5), o + Vector2(c * 0.5, c - 0.5), o + Vector2(1, c * 0.5)]), col)
