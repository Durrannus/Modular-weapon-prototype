extends CharacterBody2D
## The player: movement, dash, aiming, and running the combo the weapon build
## produced. Moves are small building blocks (slash, stab, spin) that parts
## switch on; effects (wave, burn, lunge, split) modify them.

const Fx := preload("res://scripts/fx/fx.gd")
const Projectile := preload("res://scripts/projectile.gd")

const MOVE_SPEED := 260.0
const DASH_SPEED := 760.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.5
const LUNGE_SPEED := 700.0
const LUNGE_TIME := 0.14
const RADIUS := 16.0
const BASE_STEP_TIME := 0.30   # time per combo step at speed 1.0
const MERGE_GAP := 0.10        # gap between the parts of a merged move
const LAST_STEP_RECOVERY := 0.14
const COMBO_WINDOW := 0.55     # how long you can wait before the combo resets
const SWING_ANIM := 0.12

## Damage multiplier, knockback and hit shape for each move.
const MOVES := {
	"slash": {"mult": 1.0, "knock": 230.0},
	"stab": {"mult": 1.35, "knock": 330.0},
	"spin": {"mult": 0.8, "knock": 260.0},
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
var queued := false
var combo_timer := 0.0
var pending: Array = []    # [{"t": float, "move": String}]
var lunge_timer := 0.0
var lunge_dir := Vector2.RIGHT
var dash_timer := 0.0
var dash_cooldown := 0.0
var dash_dir := Vector2.RIGHT
var invuln := 0.0
var swing_kind := ""
var swing_t := 1.0
var swing_dir := Vector2.RIGHT
var knocked_out_timer := 0.0


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
	add_child(camera)
	camera.make_current()
	spawn_point = global_position


func set_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x) - 80
	camera.limit_top = int(rect.position.y) - 80
	camera.limit_right = int(rect.end.x) + 80
	camera.limit_bottom = int(rect.end.y) + 80


func set_weapon(stats: Dictionary) -> void:
	weapon = stats
	step_index = 0
	current_step = -1
	pending.clear()
	queued = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		using_pad = false
	elif event is InputEventJoypadButton:
		using_pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4:
		using_pad = true


func _physics_process(delta: float) -> void:
	invuln = maxf(invuln - delta, 0.0)
	dash_cooldown -= delta
	swing_t = minf(swing_t + delta / SWING_ANIM, 1.0)

	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_aim(move)

	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and can_dodge():
		dash_dir = move.normalized() if move.length() > 0.1 else aim_dir
		dash_timer = DASH_TIME
		dash_cooldown = DASH_COOLDOWN
		invuln = maxf(invuln, DASH_TIME + 0.05)

	var vel := move * MOVE_SPEED
	if current_step >= 0:
		vel *= 0.55  # you slow down while swinging
	if dash_timer > 0.0:
		dash_timer -= delta
		vel = dash_dir * DASH_SPEED
	elif lunge_timer > 0.0:
		lunge_timer -= delta
		vel = lunge_dir * LUNGE_SPEED
	velocity = vel
	move_and_slide()

	_update_combat(delta)


## There's no base dodge: it comes from parts (see Feather Charm).
func can_dodge() -> bool:
	return "dodge" in weapon.get("effects", [])


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


# --- Combo ------------------------------------------------------------------

func _update_combat(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		if current_step < 0:
			_start_step()
		else:
			queued = true

	if current_step >= 0:
		step_timer -= delta
		var still: Array = []
		for p in pending:
			p["t"] -= delta
			if p["t"] <= 0.0:
				_do_move(p["move"])
			else:
				still.append(p)
		pending = still
		if step_timer <= 0.0 and pending.is_empty():
			_end_step()
	elif combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			step_index = 0


func _steps() -> Array:
	return weapon.get("steps", [])


func _start_step() -> void:
	var steps := _steps()
	if steps.is_empty():
		return
	if step_index >= steps.size():
		step_index = 0
	current_step = step_index
	var moves: Array = steps[current_step]
	var speed: float = weapon.get("speed", 1.0)
	pending.clear()
	for i in moves.size():
		pending.append({"t": i * MERGE_GAP / speed, "move": moves[i]})
	step_timer = (BASE_STEP_TIME + (moves.size() - 1) * MERGE_GAP) / speed
	queued = false
	var is_last := current_step == steps.size() - 1
	if is_last:
		step_timer += LAST_STEP_RECOVERY / speed
		if "lunge" in weapon.get("effects", []):
			lunge_timer = LUNGE_TIME
			lunge_dir = aim_dir


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
	var reach: float = weapon.get("reach", 1.0)
	var dmg: float = float(weapon.get("damage", 6.0)) * float(info["mult"])
	var knock: float = info["knock"]
	var dir := aim_dir
	var effects: Array = weapon.get("effects", [])
	var radius := 0.0
	var hits := 0

	match move:
		"stab":
			radius = 112.0 * reach
		"spin":
			radius = 70.0 * reach
		_:
			radius = 74.0 * reach

	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - global_position
		var r: float = e.radius
		var hit := false
		var kdir := rel.normalized() if rel.length() > 0.01 else dir
		match move:
			"stab":
				var along := rel.dot(dir)
				var side := absf(rel.dot(dir.orthogonal()))
				hit = along > -r and along <= radius + r and side <= 16.0 + r
				kdir = dir
			"spin":
				hit = rel.length() <= radius + r
			_:
				hit = rel.length() <= radius + r and (rel.length() < r + RADIUS or absf(dir.angle_to(rel)) <= deg_to_rad(68.0))
		if hit:
			_hit_enemy(e, dmg, kdir, knock)
			hits += 1

	# Visuals
	var fx := Fx.new()
	fx.kind = move
	fx.dir = dir
	fx.radius = radius
	fx.color = weapon.get("blade_color", Color.WHITE)
	add_child(fx)
	swing_kind = move
	swing_dir = dir
	swing_t = 0.0

	# Wave blade: every move sends out waves.
	if "wave" in effects:
		var dirs: Array = [dir]
		if move == "spin":
			dirs = [dir, dir.rotated(PI * 0.5), dir.rotated(PI), dir.rotated(PI * 1.5)]
		var all_dirs: Array = []
		for d in dirs:
			all_dirs.append(d)
			if "split" in effects:
				all_dirs.append(d.rotated(0.32))
				all_dirs.append(d.rotated(-0.32))
		for d in all_dirs:
			_fire_wave(d, dmg * 0.6)

	if hits > 0:
		shake = maxf(shake, 4.0 + hits)
		_hitstop(0.035 if move != "stab" else 0.06)


func _hit_enemy(e, dmg: float, kdir: Vector2, knock: float) -> void:
	var crit := randf() < float(weapon.get("crit", 0.05))
	var burn := "burn" in weapon.get("effects", [])
	e.take_hit(dmg * (2.0 if crit else 1.0), kdir, knock, crit, burn)


func _fire_wave(d: Vector2, dmg: float) -> void:
	var p := Projectile.new()
	p.velocity = d * 540.0
	p.damage = dmg
	p.crit_chance = float(weapon.get("crit", 0.05))
	p.burn = "burn" in weapon.get("effects", [])
	p.color = weapon.get("blade_color", Color.WHITE)
	get_parent().add_child(p)
	p.global_position = global_position + d * 24.0


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


func _process(delta: float) -> void:
	knocked_out_timer = maxf(knocked_out_timer - delta, 0.0)
	shake = move_toward(shake, 0.0, 40.0 * delta)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	queue_redraw()


func _draw() -> void:
	var blink := invuln > 0.0 and int(invuln * 20.0) % 2 == 0
	draw_circle(Vector2.ZERO, RADIUS, Color(1, 1, 1) if blink else color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 28, color.darkened(0.45), 2.5)

	# The sword, drawn from the build's colours so swapping parts shows up.
	var base_angle := aim_dir.angle()
	var extend := 0.0
	if swing_t < 1.0:
		var k := swing_t
		base_angle = swing_dir.angle()
		match swing_kind:
			"stab":
				extend = sin(k * PI) * 26.0
			"spin":
				base_angle += k * TAU
			_:
				base_angle += lerpf(-1.2, 1.2, k)
	var d := Vector2.RIGHT.rotated(base_angle)
	var side := d.orthogonal()
	var reach: float = weapon.get("reach", 1.0)
	var start := d * (RADIUS + 2.0 + extend)
	var guard := start + d * 10.0
	var tip := guard + d * (34.0 * reach)
	draw_line(start, guard, weapon.get("handle_color", Color(0.45, 0.3, 0.18)), 5.0)
	draw_line(guard - side * 9.0, guard + side * 9.0, weapon.get("hilt_color", Color(0.55, 0.38, 0.22)), 4.0)
	draw_line(guard, tip, weapon.get("blade_color", Color(0.7, 0.55, 0.35)), 6.0)
