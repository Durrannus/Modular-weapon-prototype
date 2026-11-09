extends SceneTree
## Feel checks for movement and the sword swing, run in the real arena with a
## scripted player. Prints PASS / FAIL lines.
##   godot --headless --path . --fixed-fps 60 -s tests/feel_check.gd

const EnemyScript := preload("res://scripts/enemy.gd")

var m
var p
var f := 0
var fails := 0
var swings := 0
var last_step := -1
var script_done := false
var slowest_scale := 1.0


func _init() -> void:
	m = load("res://scripts/main.gd").new()
	root.add_child(m)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		_watch()


func _watch() -> void:
	slowest_scale = minf(slowest_scale, Engine.time_scale)
	if p.current_step != last_step:
		if p.current_step >= 0:
			swings += 1
		last_step = p.current_step


func _tap_attack(frames: int) -> void:
	p.input.attack_pressed = true
	p.input.attack_held = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(frames - 1)
	p.input.attack_held = false


func _idle() -> void:
	p.input.move = Vector2.ZERO
	p.input.stick_aim = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	await _frames(70)
	swings = 0


func _run() -> void:
	await process_frame
	await process_frame
	p = m.player
	p.input.kind = "script"
	m.spawning = false
	for e in get_nodes_in_group("enemies"):
		if e.kind != "dummy":
			e.queue_free()
	await _frames(5)

	# --- Swings ---
	await _idle()
	await _tap_attack(5)     # an 80 ms click
	await _frames(90)
	_check(swings == 1, "one short click = one swing (got %d)" % swings)

	await _idle()
	await _tap_attack(4)
	await _frames(6)
	await _tap_attack(4)     # a second click during the first swing
	await _frames(120)
	_check(swings == 2, "a click during a swing queues exactly one more (got %d)" % swings)

	await _idle()
	p.input.attack_pressed = true
	p.input.attack_held = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(89)        # held for 1.5 s
	p.input.attack_held = false
	var held_swings := swings
	await _frames(90)
	_check(held_swings >= 3, "holding attack keeps swinging (%d swings in 1.5 s)" % held_swings)
	_check(swings <= held_swings + 0, "letting go stops the chain (%d after release)" % (swings - held_swings))

	# --- Movement ---
	await _idle()
	p.input.move = Vector2.RIGHT
	var xs: Array = []
	for i in 60:
		await _frames(1)
		xs.append(p.global_position.x)
	var top: float = (xs[59] - xs[49]) * 6.0
	var ramp := 0
	for i in range(1, 60):
		if (xs[i] - xs[i - 1]) * 60.0 >= top * 0.98:
			ramp = i
			break
	_check(absf(top - p.MOVE_SPEED) < 6.0, "top speed is %.0f (wanted %.0f)" % [top, p.MOVE_SPEED])
	_check(ramp >= 2 and ramp <= 6, "full speed after %d frames (2 to 6 wanted)" % ramp)
	_check(p.facing == "right", "walking right faces right (%s)" % p.facing)
	p.input.move = Vector2.ZERO
	var stop := 0
	for i in 12:
		await _frames(1)
		if p.velocity.length() < 1.0:
			stop = i + 1
			break
	_check(stop >= 1 and stop <= 5, "stops in %d frames (1 to 5 wanted)" % stop)

	# --- Facing: walk one way, attack another ---
	await _idle()
	p.input.move = Vector2.RIGHT
	await _frames(10)
	p.input.stick_aim = Vector2.UP
	await _tap_attack(3)
	_check(p.facing == "up", "attacking turns the body to the aim (%s)" % p.facing)
	p.input.stick_aim = Vector2.ZERO
	await _frames(60)
	_check(p.facing == "right", "then it turns back to the walk direction (%s)" % p.facing)

	# Diagonal release: let go of the two keys a frame apart and stay diagonal.
	await _idle()
	p.input.move = Vector2(1, 1).normalized()
	await _frames(20)
	p.input.move = Vector2.RIGHT
	await _frames(2)
	p.input.move = Vector2.ZERO
	await _frames(10)
	_check(p.facing8 == "down_right", "releasing a diagonal a frame apart stays diagonal (%s)" % p.facing8)

	# --- Dodge goes the way you face ---
	await _idle()
	p.input.move = Vector2.LEFT
	await _frames(12)
	p.input.move = Vector2.ZERO
	await _frames(20)
	var x0: float = p.global_position.x
	p.input.dash_pressed = true
	await _frames(1)
	p.input.dash_pressed = false
	await _frames(20)
	_check(p.global_position.x < x0 - 60.0, "a standing dodge goes the way you face (moved %.0f)" % (p.global_position.x - x0))

	# --- Hits: nothing freezes the whole game ---
	await _idle()
	var slime = EnemyScript.new()
	slime.kind = "slime"
	slime.position = p.global_position + Vector2(52, 0)
	m.world.add_child(slime)
	slime.max_hp = 500.0
	slime.hp = 500.0
	slime.speed = 0.0
	slime.contact_damage = 0.0
	p.input.stick_aim = Vector2.RIGHT
	slowest_scale = 1.0
	var sx: float = slime.global_position.x
	await _tap_attack(3)
	await _frames(10)
	var stunned: bool = slime.hit_stun > 0.0 or slime.freeze > 0.0
	await _frames(20)
	_check(slime.hp < 500.0, "a slash hits the enemy in front")
	_check(stunned, "the enemy reels from the hit")
	_check(slime.global_position.x > sx + 10.0, "and is knocked back (%.0f)" % (slime.global_position.x - sx))
	# Finish the chain on it: the finisher plants the player, the game clock never changes.
	slime.global_position = p.global_position + Vector2(52, 0)
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	var planted := false
	for i in 110:
		await _frames(1)
		if is_instance_valid(slime):
			slime.global_position = p.global_position + Vector2(52, 0)
		if p.hit_pause > 0.0:
			planted = true
	p.input.attack_held = false
	_check(planted, "a finisher that connects plants the player for a moment")
	_check(slowest_scale >= 1.0, "the game clock never slows (lowest %.2f)" % slowest_scale)
	if is_instance_valid(slime):
		slime.queue_free()

	# A finisher that misses doesn't plant you.
	await _idle()
	p.global_position = m.ARENA.get_center() + Vector2(-300, 200)
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	planted = false
	for i in 100:
		await _frames(1)
		if p.hit_pause > 0.0:
			planted = true
	p.input.attack_held = false
	_check(not planted, "a finisher that misses doesn't stop you")

	print("RESULT: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(1 if fails > 0 else 0)
