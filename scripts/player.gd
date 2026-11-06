extends CharacterBody2D

const WeaponBuild := preload("res://scripts/weapon/weapon_build.gd")
## The player: movement, dodge, aiming, and running the combo the weapon build
## produced. Each combo step is one move (slash, stab, lunge, spin, overhead).
## Blade elements add effects on hit (fire, water, lightning, steam, electrified).

const Fx := preload("res://scripts/fx/fx.gd")
const Art := preload("res://scripts/art.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const SwordArt := preload("res://scripts/weapon/sword_art.gd")
const RuneFx := preload("res://scripts/fx/rune_fx.gd")
const Sfx := preload("res://scripts/sfx.gd")
const SpriteOnce := preload("res://scripts/fx/sprite_once.gd")

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

# Swing animation. The sword rests lowered at the side and only swings out on attack.
# The hand orbits the shoulder, so the whole arm and sword sweep round the body.
const SHOULDER := Vector2(0, -18)   # relative to the player's centre
const ARM := 15.0                   # shoulder to hand while swinging
var swing_side := 1.0               # +1 / -1: slashes alternate direction
var pose_angle := PI * 0.4          # what's drawn, smoothed toward the target pose
var pose_hand := Vector2(10, -14)
var pose_from_angle := 0.0          # where the current swing started from
var trail: Array = []               # [hand, angle, time] samples while sweeping
var trail_layer: Node2D
var squash := Vector2.ONE           # body squash and stretch
var lean := 0.0                     # body lean in radians
var stepped := false                # has this swing's step forward happened
var trail_te := -1.0                # step time of the last trail sample

# Swing path runes
const REPEAT_GAP := 0.16      # Twice: the second go comes this long after the first
const MAX_DODGES_WIND := 2    # Second Wind can top dodges up past the normal 1
var game_time := 0.0
var rune_queue: Array = []    # [{at, effect, size, power, hits}]
var slot_flash := {}          # slot index -> game_time it last fired
var last_kill_pos := Vector2.ZERO
var sweep_flash := {}         # slot index -> game_time the swing passes it
const LEAP_WINDOW := 0.35     # Leap: an attack this soon after a dodge ends counts
const LEAP_RANGE := 170.0
var dodge_started := -9.0     # game_time the last dodge began
var attack_buffered := false  # attack pressed mid-dodge, swung as the dodge ends
var rune_counts := {}         # effect index -> triggers seen (Saved Up fires every third)
var dodge_partial := 0.0      # Second Wind at half strength fills half a dodge
var leap_targets: Array = []  # enemies already leapt to in this burst

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
	trail_layer = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail_layer.material = add
	add_child(trail_layer)
	trail_layer.draw.connect(_draw_trail)
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
	rune_queue.clear()
	slot_flash.clear()
	sweep_flash.clear()
	rune_counts.clear()
	dodge_partial = 0.0
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
	game_time += delta
	_run_rune_queue()

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
		dodge_refill = 0.0
		dodge_dir = move.normalized() if move.length() > 0.1 else aim_dir
		dodge_timer = DODGE_TIME
		invuln = maxf(invuln, DODGE_TIME + 0.06)
		_reset_combo()
		dodge_started = game_time
		_trigger("dodge", [])


# --- Combo ------------------------------------------------------------------

func _steps() -> Array:
	return weapon.get("steps", [])


func _speed() -> float:
	return maxf(float(weapon.get("speed", 1.0)), 0.2)


func _update_combat(delta: float) -> void:
	if Input.is_action_just_pressed("attack") and dodge_timer > 0.0:
		attack_buffered = true
	elif (Input.is_action_just_pressed("attack") or attack_buffered) and dodge_timer <= 0.0:
		attack_buffered = false
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
	swing_side = 1.0 if current_step % 2 == 0 else -1.0
	pose_from_angle = wrapf(pose_angle - anim_dir.angle(), -PI, PI)
	stepped = false
	trail_te = 0.0
	# The swing travels up the sword: each slot lights for a moment, grip to tip.
	for i in weapon.get("line", []).size():
		sweep_flash[i] = game_time + float(i) * 0.04
	# Leap: the first swing straight after a dodge.
	if game_time - dodge_started <= DODGE_TIME + LEAP_WINDOW:
		dodge_started = -9.0
		leap_targets.clear()
		_trigger("dodge_attack", [])
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
	var dir := anim_dir
	var hits := 0
	var hit_list: Array = []

	# Hits follow the drawn sword: every enemy the blade passes over during the
	# sweep is hit, so reach is the blade's real length.
	var segs := _blade_sweep()
	if not segs.is_empty():
		var tip_len: float = (segs[0][1] - segs[0][0]).length()
		reach = tip_len + ARM
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - global_position
		var r: float = e.radius + BLADE_HALF_WIDTH
		var hit := false
		for sg in segs:
			var closest := Geometry2D.get_closest_point_to_segment(e.global_position, sg[0], sg[1])
			if closest.distance_to(e.global_position) <= r:
				hit = true
				break
		var kdir := rel.normalized() if rel.length() > 0.01 else dir
		if str(info["shape"]) == "line":
			kdir = dir
		if hit:
			_hit_enemy(e, dmg, kdir, knock)
			hits += 1
			hit_list.append(e)

	var fx := Fx.new()
	fx.kind = str(info["shape"])
	if fx.kind == "arc":
		fx.kind = "none"  # the sword's own trail shows the slash
	fx.dir = dir
	fx.radius = reach
	fx.arc = float(info.get("arc", 120.0))
	fx.width = float(info.get("width", 16.0)) * area
	fx.color = weapon.get("hit_color", Color.WHITE)
	fx.thick = move == "overhead"
	_fx_root().add_child(fx)
	fx.global_position = global_position

	Sfx.play(self, "swing", -14.0)
	var finisher := current_step == _steps().size() - 1 and _steps().size() > 1
	if finisher:
		# The finisher always lands loud: a freeze-frame, screen shake and a thump.
		shake = maxf(shake, 12.0)
		Sfx.play(self, "finisher", -4.0)
		_hitstop(0.09)
		_trigger("finisher", hit_list)
	elif hits > 0:
		shake = maxf(shake, float(info.get("shake", 4.0)) + hits)
		_hitstop(0.07 if move == "overhead" else 0.035)
	if hits > 0:
		_trigger("hit", hit_list)


func _hit_enemy(e, dmg: float, kdir: Vector2, knock: float) -> void:
	var crit := randf() < float(weapon.get("crit", 0.05))
	var final := dmg * (float(weapon.get("crit_damage", 1.5)) if crit else 1.0)
	e.take_hit(final, kdir, knock, crit, weapon.get("hit_color", Color.WHITE))
	_apply_elements(e, final)


# --- Swing path runes -----------------------------------------------------------
# A rune fires on its trigger (finisher, hit, kill). Twice queues repeats a beat
# apart. Identical runes firing at the same moment merge into one bigger effect.

func _trigger(trigger: String, hits: Array) -> void:
	var effects: Array = weapon.get("effects", [])
	for i in effects.size():
		var e: Dictionary = effects[i]
		if e["trigger"] != trigger and not (trigger in e.get("also", [])):
			continue
		# Saved Up: count the triggers and only fire on every third one.
		var every := int(e.get("every", 1))
		if every > 1:
			rune_counts[i] = int(rune_counts.get(i, 0)) + 1
			if int(rune_counts[i]) % every != 0:
				continue
		var where := last_kill_pos if trigger == "kill" or hits.is_empty() or not is_instance_valid(hits[0]) else (hits[0] as Node2D).global_position
		for n in int(e["count"]):
			_queue_rune(i, game_time + n * REPEAT_GAP, float(e["size"]), hits, float(e.get("power", 1.0)), where)


func _queue_rune(effect: int, at: float, size: float, hits: Array, power := 1.0, where := Vector2.ZERO) -> void:
	var id: String = weapon["effects"][effect]["id"]
	for q in rune_queue:
		if id == "shatter" and (q["pos"] as Vector2).distance_to(where) > 8.0:
			continue  # bursts in different places stay separate
		if q["effect"] != effect and weapon["effects"][q["effect"]]["id"] == id and absf(float(q["at"]) - at) < 0.03:
			q["size"] = minf(maxf(float(q["size"]), size) * 1.3, SwingBuild.MAX_SIZE)
			q["power"] = float(q["power"]) + power
			q["merged"].append(effect)
			return
	rune_queue.append({"at": at, "effect": effect, "size": size, "power": power, "hits": hits.duplicate(), "merged": [], "pos": where})


func _run_rune_queue() -> void:
	var due: Array = []
	for q in rune_queue:
		if float(q["at"]) <= game_time:
			due.append(q)
	for q in due:
		rune_queue.erase(q)
		_fire_rune(q)


## Called by main whenever an enemy dies.
func on_kill(where: Vector2 = Vector2.INF) -> void:
	last_kill_pos = where if where != Vector2.INF else global_position
	_trigger("kill", [])


func _flash_effect(effect: int) -> void:
	var e: Dictionary = weapon["effects"][effect]
	slot_flash[int(e["slot"])] = game_time
	for s in e["band_slots"] + e.get("relayed", []):
		slot_flash[int(s)] = game_time
		var spark := _strip("band_spark", _slot_world(int(s)))
		if spark != null:
			spark.follow = self
			spark.follow_offset = spark.global_position - global_position


func _fire_rune(q: Dictionary) -> void:
	var effect: int = q["effect"]
	if effect >= weapon.get("effects", []).size():
		return
	_flash_effect(effect)
	for m in q["merged"]:
		_flash_effect(m)
	var id: String = weapon["effects"][effect]["id"]
	var size: float = q["size"]
	var power: float = q["power"]
	var col: Color = SwingBuild.FITTINGS[id]["color"]
	var dmg := float(weapon.get("damage", 8.0))
	match id:
		"shockwave":
			var w := RuneFx.new()
			w.kind = "wave"
			w.dir = aim_dir
			w.size = size
			w.color = col
			w.damage = dmg * 1.1 * power
			w.knock = 380.0 * size
			_fx_root().add_child(w)
			w.global_position = global_position + aim_dir * 30.0
			_strip("shockwave_burst", global_position + aim_dir * 40.0, 0.0, size)
			shake = maxf(shake, 9.0 * size)
			Sfx.play(self, "shockwave", -2.0, 1.0 / sqrt(size))
		"hook":
			var reach := 260.0 * size
			var ring := RuneFx.new()
			ring.kind = "ring"
			ring.size = reach
			ring.color = col
			ring.life = 0.3
			_fx_root().add_child(ring)
			ring.global_position = global_position
			var tip := _tip_world()
			for e in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(e) or e.dead:
					continue
				var rel: Vector2 = global_position - e.global_position
				var d := rel.length()
				if d > reach + e.radius or d < 40.0:
					continue
				var pull := sqrt(2.0 * 1300.0 * maxf(d - 45.0, 0.0))
				e.take_hit(dmg * 0.3 * power, rel / d, 0.0, false, col)
				e.knock = rel / d * pull * e.knock_resist
				e.apply_stun(0.35)
				var chain := RuneFx.new()
				chain.kind = "chain"
				chain.from_node = self
				chain.from_offset = tip - global_position
				chain.to_node = e
				chain.color = col
				chain.life = 0.4
				_fx_root().add_child(chain)
				_strip("hook_snag", e.global_position)
				var yank := _strip("hook_yank", e.global_position, (rel / d).angle())
				if yank != null:
					yank.follow = e
					yank.life = 0.35
			Sfx.play(self, "hook", -4.0)
		"cleave":
			var hits: Array = q["hits"]
			_strip("cleave_arc", global_position + aim_dir * 12.0, aim_dir.angle(), size)
			for h in hits:
				if not is_instance_valid(h):
					continue
				var away: Vector2 = (h.global_position - global_position).normalized()
				var best = null
				var best_d := 140.0 * size
				for e in get_tree().get_nodes_in_group("enemies"):
					if not is_instance_valid(e) or e.dead or e == h or e in hits:
						continue
					var rel: Vector2 = e.global_position - h.global_position
					if rel.dot(away) < -10.0:
						continue  # only enemies behind the target
					if rel.length() < best_d:
						best_d = rel.length()
						best = e
				if best == null:
					continue
				best.take_hit(dmg * 0.8 * power, away, 220.0, false, col)
				_strip("cleave_echo", best.global_position, 0.0, size)
			Sfx.play(self, "cleave", -6.0)
		"second_wind":
			dodge_partial += power
			var add := int(floor(dodge_partial + 0.001))
			dodge_partial -= add
			if add > 0:
				dodge_charges = mini(dodge_charges + add, MAX_DODGES_WIND)
			var wisp := _strip("wind_wisp", last_kill_pos)
			if wisp != null:
				wisp.life = 0.35
				wisp.velocity = (global_position - last_kill_pos) / 0.35
			var swirl := _strip("wind_swirl", global_position + FEET, 0.0, size)
			if swirl != null:
				swirl.follow = self
				swirl.follow_offset = FEET
			_label("+DODGE", col)
			if size > 1.0:
				for e in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) < 150.0 * size:
						e.knock = (e.global_position - global_position).normalized() * 420.0 * e.knock_resist
			Sfx.play(self, "second_wind", -4.0)
		"leap":
			_leap(size, power, dmg, col)
		"shatter":
			_shatter(q["pos"], size, power, dmg, col)
	# Name what fired above the player, so it's obvious which rune did what.
	if id != "second_wind":
		_label(str(SwingBuild.FITTINGS[id]["name"]).to_upper() + ("!" if power <= 1.0 else " x%s!" % str(snappedf(power, 0.5)).trim_suffix(".0")), col)


## Shatter: a burst where the enemy died (or was hit) that hurts everyone nearby.
## Enemies it kills burst too, so a crowd can chain.
func _shatter(where: Vector2, size: float, power: float, dmg: float, col: Color) -> void:
	var radius := 64.0 * size
	var ring := RuneFx.new()
	ring.kind = "ring"
	ring.size = radius
	ring.color = col
	ring.life = 0.22
	_fx_root().add_child(ring)
	ring.global_position = where
	_strip("shockwave_burst", where, 0.0, size * 0.8)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - where
		if rel.length() > radius + float(e.radius):
			continue
		var away := rel.normalized() if rel.length() > 1.0 else aim_dir
		e.take_hit(dmg * 0.7 * power, away, 300.0 * size, false, col)
	shake = maxf(shake, 6.0 * size)
	Sfx.play(self, "shockwave", -6.0, 1.4)


## Leap: jump to the nearest enemy (not one already leapt to in this burst),
## landing just short of it with a small hit, so the swing lands.
func _leap(size: float, power: float, dmg: float, col: Color) -> void:
	var best = null
	var best_d := LEAP_RANGE * size
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e in leap_targets:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	leap_targets.append(best)
	var rel: Vector2 = best.global_position - global_position
	var dir := rel.normalized()
	var travel := maxf(rel.length() - (float(best.radius) + 14.0), 0.0)
	dodge_timer = 0.0  # a Leap on a dodge takes over the dodge
	lunge_dir = dir
	lunge_timer = 0.14
	lunge_speed = travel / 0.14
	aim_dir = dir
	invuln = maxf(invuln, 0.2)
	best.take_hit(dmg * 0.4 * power, dir, 120.0, false, col)
	best.apply_stun(0.25)
	var ring := RuneFx.new()
	ring.kind = "ring"
	ring.size = 34.0 * size
	ring.color = col
	ring.life = 0.25
	_fx_root().add_child(ring)
	ring.global_position = best.global_position
	shake = maxf(shake, 5.0)
	Sfx.play(self, "cleave", -6.0, 1.3)


## Plays one of the art's effect strips (art/swing/fx/) at a world position.
func _strip(name: String, where: Vector2, angle := 0.0, size := 1.0) -> Node2D:
	var info: Dictionary = SwordArt.data().get("fx", {}).get(name, {})
	var tex := Art.texture("swing/fx/%s.png" % name)
	if tex == null or info.is_empty():
		return null
	var n := SpriteOnce.new()
	n.texture = tex
	n.frames = int(info.get("frames", 1))
	n.fps = float(info.get("fps", 12))
	var o: Array = info.get("origin", [0, 0])
	n.origin = Vector2(o[0], o[1])
	n.angle = angle
	n.size = size
	n.additive = true
	_fx_root().add_child(n)
	n.global_position = where
	return n


## Rune effects go on their own layer above the lighting, so they stay bright.
var fx_parent: Node = null

func _fx_root() -> Node:
	return fx_parent if is_instance_valid(fx_parent) else get_parent()


func _label(text: String, col: Color) -> void:
	var l := RuneFx.new()
	l.kind = "text"
	l.text = text
	l.color = col
	l.life = 0.7
	_fx_root().add_child(l)
	l.global_position = global_position + Vector2(randf_range(-20, 20), -70)


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
	_update_pose(delta)
	trail_layer.queue_redraw()
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
		var fw := tex.get_width() / maxi(int(strip[1]), 1)
		var src := Rect2(float(posmod(int(strip[2]), int(strip[1])) * fw), 0.0, float(fw), float(tex.get_height()))
		draw_set_transform(FEET, lean, Vector2(Art.PIXEL * squash.x, Art.PIXEL * squash.y))
		draw_texture_rect_region(tex, Rect2(-_body_origin(), src.size), src, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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

## The sword's pose: [angle, hand position relative to the player's centre].
func _sword_pose() -> Array:
	return [pose_angle, pose_hand]


const BLADE_HALF_WIDTH := 6.0   # a little forgiveness either side of the blade


## The blade's positions over the whole sweep, as world segments [hand end, tip].
func _blade_sweep() -> Array:
	var out: Array = []
	if not weapon.has("blade"):
		return out
	var blade: String = weapon["blade"]
	var grip: String = weapon["grip"]
	var length_px := SwordArt.pivot(blade, grip, "hand").y * Art.PIXEL
	var guard_px := (SwordArt.pivot(blade, grip, "hand").y - SwordArt.blade_size(blade, "hand").y) * Art.PIXEL
	var info: Dictionary = MOVES.get(anim_move, MOVES["slash"])
	var hit_at := float(info["windup"]) / _speed()
	var now := step_elapsed
	var te := maxf(hit_at - 0.035, 0.0)
	while te <= hit_at + 0.065:
		step_elapsed = te
		var p := _attack_pose()
		var d := Vector2.RIGHT.rotated(float(p[0]))
		var hand: Vector2 = global_position + p[1]
		out.append([hand + d * guard_px * 0.5, hand + d * length_px])
		te += 0.005
	step_elapsed = now
	return out


## The swing curve for each move, as angles relative to the swing direction.
## [start, end, arm at start, arm at end]. Slashes are mirrored on every other step.
const SWING_CURVES := {
	"slash": [-1.75, 1.5, 12.0, 16.0],
	"overhead": [-2.7, 0.6, 8.0, 18.0],
	"stab": [0.0, 0.0, 4.0, 26.0],
	"lunge": [0.0, 0.0, 4.0, 26.0],
	"spin": [0.0, TAU, 14.0, 14.0],
}


## Where the sword should be right now, during a swing. Returns [angle, hand, sweeping].
func _attack_pose() -> Array:
	var info: Dictionary = MOVES.get(anim_move, MOVES["slash"])
	var curve: Array = SWING_CURVES.get(anim_move, SWING_CURVES["slash"])
	var side := swing_side if anim_move == "slash" else 1.0
	var hit_at := float(info["windup"]) / _speed()
	var sweep_start := maxf(hit_at - 0.035, 0.0)
	var sweep_end := hit_at + 0.065
	var start_a: float = float(curve[0]) * side
	var end_a: float = float(curve[1]) * side
	var rel := 0.0
	var arm := 0.0
	var sweeping := false
	var te := step_elapsed
	if te < sweep_start:
		# Wind up: pull back from wherever the sword was to the start of the swing.
		var k := ease(clampf(te / maxf(sweep_start, 0.001), 0.0, 1.0), 0.4)
		rel = lerp_angle(pose_from_angle, start_a, k)
		arm = lerpf(14.0, float(curve[2]), k)
	elif te < sweep_end:
		# The swing itself: fast out, slowing at the end.
		var k := clampf((te - sweep_start) / (sweep_end - sweep_start), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		rel = lerpf(start_a, end_a, e)
		arm = lerpf(float(curve[2]), float(curve[3]), e)
		sweeping = true
	else:
		# Follow through: a small overshoot that settles.
		var k := te - sweep_end
		rel = end_a + side * 0.18 * sin(minf(k / 0.12, 1.0) * PI) * (1.0 if anim_move != "stab" and anim_move != "lunge" else 0.0)
		arm = lerpf(float(curve[3]), 14.0, clampf(k / 0.2, 0.0, 1.0))
	var angle := anim_dir.angle() + rel
	return [angle, SHOULDER + Vector2.RIGHT.rotated(angle) * arm, sweeping]


## Resting pose: the sword lowered at the side, by the hand on the body sprite.
func _rest_pose() -> Array:
	var a := 0.95
	match facing:
		"left":
			a = PI - 0.95
		"down":
			a = 2.2
		"up":
			a = 0.95
	return [a, _hand_point()]


func _update_pose(delta: float) -> void:
	if current_step >= 0:
		var p := _attack_pose()
		pose_angle = p[0]
		pose_hand = p[1]
		if p[2] or (trail_te >= 0.0 and trail_te < step_elapsed):
			# Fill the trail at small time steps so it stays a smooth arc at any frame rate.
			var now := step_elapsed
			var te := trail_te if trail_te >= 0.0 else now
			while te < now:
				step_elapsed = te
				var q := _attack_pose()
				if q[2]:
					trail.append([q[1], q[0], game_time - (now - te)])
				te += 0.006
			step_elapsed = now
			trail.append([pose_hand, pose_angle, game_time])
			trail_te = now if p[2] else -1.0
			if not stepped:
				# No step forward: swinging never moves you (it pushed you into enemies).
				stepped = true
				squash = Vector2(0.9, 1.1) if anim_move == "overhead" else Vector2(0.95, 1.06)
		elif step_elapsed < float(MOVES.get(anim_move, MOVES["slash"])["windup"]) / _speed():
			# Wind up: crouch into it.
			squash = squash.lerp(Vector2(1.1, 0.9) if anim_move == "overhead" else Vector2(1.04, 0.96), 1.0 - exp(-30.0 * delta))
	else:
		var r := _rest_pose()
		var k := 1.0 - exp(-14.0 * delta)
		pose_angle = lerp_angle(pose_angle, r[0], k)
		pose_hand = pose_hand.lerp(r[1], k)
		lean = lerpf(lean, 0.0, 1.0 - exp(-12.0 * delta))
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-12.0 * delta))
	while not trail.is_empty() and game_time - float(trail[0][2]) > 0.12:
		trail.pop_front()


## The swing's smear: a fading band between the hand end and the tip.
func _draw_trail() -> void:
	if trail.size() < 2 or not weapon.has("blade"):
		return
	var length_px := SwordArt.pivot(weapon["blade"], weapon["grip"], "hand").y * Art.PIXEL
	var col: Color = weapon.get("hit_color", Color.WHITE).lerp(Color(0.75, 0.88, 1.0), 0.5)
	for i in range(1, trail.size()):
		var a: Array = trail[i - 1]
		var b: Array = trail[i]
		var age := (game_time - float(b[2])) / 0.12
		var alpha := clampf(1.0 - age, 0.0, 1.0) * 0.55
		var da := Vector2.RIGHT.rotated(float(a[1]))
		var db := Vector2.RIGHT.rotated(float(b[1]))
		var pts := PackedVector2Array([a[0] + da * length_px * 0.45, a[0] + da * length_px, b[0] + db * length_px, b[0] + db * length_px * 0.45])
		draw_colored_polygon_on(trail_layer, pts, Color(col.r, col.g, col.b, alpha))


func draw_colored_polygon_on(ci: CanvasItem, pts: PackedVector2Array, c: Color) -> void:
	# Long sweeps can make the quad cross itself; split it into two triangles.
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2]]), c)
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[2], pts[3]]), c)


func _draw_weapon() -> void:
	if not weapon.has("blade"):
		return
	var pose := _sword_pose()
	var angle: float = pose[0]
	var hand: Vector2 = pose[1]
	# Art space: x right, y down, tip at the top. Rotate so "up" points along d.
	weapon_layer.draw_set_transform(hand, angle + PI * 0.5, Vector2(Art.PIXEL, Art.PIXEL))
	var blade: String = weapon["blade"]
	var grip: String = weapon["grip"]
	SwordArt.draw(weapon_layer, blade, grip, weapon["line"], "hand", _slot_glow(), -SwordArt.pivot(blade, grip, "hand"))
	# The fist goes on the grip, on top of the sword.
	var fist := Art.texture("body/hand.png")
	if fist != null:
		weapon_layer.draw_texture(fist, -fist.get_size() * 0.5)
	weapon_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## How lit each slot is: a rune firing (and its bands), or the swing passing up the sword.
func _slot_glow() -> Dictionary:
	var lit := {}
	for s in slot_flash:
		var since := game_time - float(slot_flash[s])
		if since >= 0.0 and since < 0.45:
			lit[s] = 1.0 - since / 0.45
	for s in sweep_flash:
		var since := game_time - float(sweep_flash[s])
		if since >= 0.0 and since < 0.1:
			lit[s] = maxf(float(lit.get(s, 0.0)), 1.0)
	return lit


## A slot's position in the world, following the sword in hand.
func _slot_world(i: int) -> Vector2:
	var pose := _sword_pose()
	var angle: float = pose[0]
	var hand: Vector2 = pose[1]
	var blade: String = weapon["blade"]
	var grip: String = weapon["grip"]
	var local := (SwordArt.slot_center(blade, grip, "hand", i) - SwordArt.pivot(blade, grip, "hand")) * Art.PIXEL
	return global_position + hand + local.rotated(angle + PI * 0.5)


## The sword's tip in the world.
func _tip_world() -> Vector2:
	var pose := _sword_pose()
	var d := Vector2.RIGHT.rotated(float(pose[0]))
	var blade: String = weapon.get("blade", "iron_blade")
	var grip: String = weapon.get("grip", "wooden_grip")
	var length_px := SwordArt.pivot(blade, grip, "hand").y * Art.PIXEL
	return global_position + pose[1] + d * length_px


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
