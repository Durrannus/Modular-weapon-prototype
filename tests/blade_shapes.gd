extends SceneTree
## Checks for the six blade shapes (Game Bible, 11 November), run in the real arena
## with a scripted player: each shape's reach, what its moves hit, its lean, and
## that every shape's damage a second stays within a tenth of the broadsword's.
##   godot --headless --path . --fixed-fps 60 -s tests/blade_shapes.gd

const EnemyScript := preload("res://scripts/enemy.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Player := preload("res://scripts/player.gd")

var m
var p
var fails := 0


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


func _blade(id: String) -> void:
	m.build.set_blade(id)
	m.build.line = ["", "", "", ""]
	m.build.changed.emit()
	p.weapon["crit"] = 0.0   # no luck in the sums
	p._reset_combo()


## A slime that stands where it's put and can't be killed.
func _slime(offset: Vector2, pinned := true):
	var e = EnemyScript.new()
	e.kind = "slime"
	e.position = p.global_position + offset
	m.world.add_child(e)
	e.max_hp = 500000.0
	e.hp = 500000.0
	e.speed = 0.0
	e.contact_damage = 0.0
	if pinned:
		e.knock_resist = 0.0
	return e


func _still() -> void:
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.input.stick_aim = Vector2.RIGHT
	p._reset_combo()
	await _frames(30)
	p._reset_combo()


## Swings the first `count` moves of the chain and waits for the last to end.
func _swings(count: int) -> void:
	p._reset_combo()
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	for i in 600:
		await _frames(1)
		if p.current_step == count - 1:
			break
	p.input.attack_held = false
	for i in 300:
		await _frames(1)
		if p.current_step < 0:
			break
	await _frames(3)
	p._reset_combo()


func _lost(e) -> float:
	return e.max_hp - e.hp


func _run() -> void:
	await process_frame
	await _frames(5)
	p = m.player
	p.input.kind = "script"
	m.spawning = false
	m.min_hp = 100.0
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(5)
	p.auto_respawn = true
	var home: Vector2 = p.global_position

	# --- Reach: each shape hits at its share of the broadsword's distance ---------
	var broad_reach := 0.0
	for id in SwingBuild.BLADE_ORDER:
		_blade(id)
		await _still()
		var info := SwingBuild.blade_info(id)
		var reach: float = p._hit_reach()
		if id == "iron_broadsword":
			broad_reach = reach
		_check(is_equal_approx(reach, 91.0 * float(info["reach"])), "%s: hits out to %d px (%.1f x the broadsword's 91)" % [info["shape_name"], roundi(reach), float(info["reach"])])
		var inside = _slime(Vector2(reach + 12.0 - 3.0, 0))      # its edge is just inside the reach
		var outside = _slime(Vector2(reach + 12.0 + 6.0, 60))
		outside.position = p.global_position + Vector2(reach + 12.0 + 6.0, 0)
		inside.position = p.global_position + Vector2(reach + 12.0 - 3.0, 0)
		await _frames(2)
		# One at a time, so a thrust that stops at the first enemy can't hide the second.
		outside.position = p.global_position + Vector2(0, -400)
		await _swings(1)
		_check(_lost(inside) > 0.0, "%s: the first move reaches an enemy at the end of its reach" % info["shape_name"])
		inside.position = p.global_position + Vector2(0, -400)
		outside.position = p.global_position + Vector2(reach + float(outside.radius) + 6.0, 0)
		await _frames(2)
		await _swings(1)
		_check(_lost(outside) == 0.0, "%s: and misses one just past it" % info["shape_name"])
		inside.queue_free()
		outside.queue_free()
		await _frames(3)

	# --- Dagger: stabs stay in the first enemy; full speed while attacking -----------
	_blade("iron_dagger")
	await _still()
	var a = _slime(Vector2(34, 0))
	var b = _slime(Vector2(52, 0))
	await _frames(2)
	await _swings(1)
	_check(_lost(a) > 0.0 and _lost(b) == 0.0, "Dagger: a stab hits the first enemy in line and stops there")
	a.queue_free()
	b.queue_free()
	await _frames(2)
	p.global_position = home
	p.input.move = Vector2.LEFT
	p.input.attack_held = true
	await _frames(40)
	var v_dagger: float = p.walk_vel.length()
	p.input.attack_held = false
	p.input.move = Vector2.ZERO
	_check(absf(v_dagger - Player.MOVE_SPEED) < 1.0, "Dagger: you walk at full speed while attacking (%d)" % roundi(v_dagger))

	# --- Greatsword: 70% speed while swinging ---------------------------------------
	_blade("iron_greatsword")
	await _still()
	p.global_position = home
	p.input.move = Vector2.RIGHT
	p.input.attack_held = true
	await _frames(40)
	var v_great: float = p.walk_vel.length()
	p.input.attack_held = false
	p.input.move = Vector2.ZERO
	_check(absf(v_great - Player.MOVE_SPEED * 0.7) < 1.0, "Greatsword: you walk at 70%% speed while swinging (%d of %d)" % [roundi(v_great), roundi(Player.MOVE_SPEED)])
	await _still()
	p.global_position = home
	# A sweep is half a circle: it hits enemies straight out to each side.
	var up = _slime(Vector2(6, -90))
	var down = _slime(Vector2(6, 90))
	var behind = _slime(Vector2(-90, 0))
	await _frames(2)
	await _swings(1)
	_check(_lost(up) > 0.0 and _lost(down) > 0.0, "Greatsword: the sweep hits enemies out to both sides")
	_check(_lost(behind) == 0.0, "Greatsword: but not one behind you")
	for e in [up, down, behind]:
		e.queue_free()
	await _frames(2)

	# --- Broadsword against the same side enemies: a 120 degree slash misses them ----
	_blade("iron_broadsword")
	await _still()
	p.global_position = home
	up = _slime(Vector2(0, -70))
	await _frames(2)
	await _swings(1)
	_check(_lost(up) == 0.0, "Broadsword: a slash doesn't reach an enemy straight out to the side")
	up.queue_free()

	# --- Rapier: a thrust goes through to a second enemy, and no further --------------
	_blade("iron_rapier")
	await _still()
	p.global_position = home
	var r1 = _slime(Vector2(50, 0))
	var r2 = _slime(Vector2(80, 0))
	var r3 = _slime(Vector2(110, 0))
	var off = _slime(Vector2(70, 44))
	await _frames(2)
	await _swings(1)
	_check(_lost(r1) > 0.0 and _lost(r2) > 0.0, "Rapier: a thrust hits the first enemy and goes through to the second")
	_check(_lost(r3) == 0.0, "Rapier: it stops there (a third in line is untouched)")
	_check(_lost(off) == 0.0, "Rapier: a straight line (an enemy off to the side is missed)")
	for e in [r1, r2, r3, off]:
		e.queue_free()
	await _frames(2)
	# The lunge reaches a quarter further than the thrusts, and doesn't move you.
	var far = _slime(Vector2(p._hit_reach() * 1.25 + 12.0 - 4.0, 0))
	await _frames(2)
	var before: Vector2 = p.global_position
	await _swings(2)
	var two: float = _lost(far)
	await _swings(3)
	_check(two == 0.0 and _lost(far) > 0.0, "Rapier: only the lunge reaches an enemy a quarter further out")
	_check(p.global_position.distance_to(before) < 1.0, "Rapier: the lunge doesn't carry you forward")
	far.queue_free()
	await _frames(2)

	# --- Falchion: big knockback, and the cleave staggers ---------------------------
	var shoves := {}
	for id in ["iron_broadsword", "iron_falchion"]:
		_blade(id)
		await _still()
		p.global_position = home
		var loose = _slime(Vector2(50, 0), false)
		await _frames(2)
		var x0: float = loose.global_position.x
		p._reset_combo()
		p.input.attack_pressed = true
		await _frames(1)
		p.input.attack_pressed = false
		await _frames(50)
		shoves[id] = loose.global_position.x - x0
		loose.queue_free()
		await _frames(20)
	_check(float(shoves["iron_falchion"]) > float(shoves["iron_broadsword"]) * 1.5, "Falchion: a chop shoves an enemy much further than a slash (%d px against %d)" % [roundi(shoves["iron_falchion"]), roundi(shoves["iron_broadsword"])])
	_blade("iron_falchion")
	await _still()
	p.global_position = home
	var stag = _slime(Vector2(50, 0))
	stag.knock_resist = 1.0
	stag.speed = 0.0
	await _frames(2)
	p._reset_combo()
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	var stun_seen := 0.0
	for i in 400:
		await _frames(1)
		stag.global_position = p.global_position + Vector2(50, 0)
		if p.current_step == 2:
			p.input.attack_held = false
		stun_seen = maxf(stun_seen, stag.hit_stun)
		if p.current_step < 0 and not p.input.attack_held:
			break
	_check(stun_seen >= 0.6, "Falchion: the cleave staggers what it hits (%.2f s)" % stun_seen)
	stag.queue_free()
	await _frames(2)

	# --- Sabre: +10% crit chance, wide cuts ----------------------------------------
	m.build.set_blade("iron_sabre")
	m.build.changed.emit()
	_check(is_equal_approx(float(p.weapon["crit"]), SwingBuild.BASE_CRIT + 0.1), "Sabre: 10%% more crit chance (%d%%)" % roundi(float(p.weapon["crit"]) * 100.0))
	_blade("iron_sabre")
	await _still()
	p.global_position = home
	var wide = _slime(Vector2.RIGHT.rotated(deg_to_rad(74.0)) * 60.0)
	await _frames(2)
	await _swings(1)
	_check(_lost(wide) > 0.0, "Sabre: a slash hits an enemy 74 degrees off the aim")
	wide.queue_free()
	await _frames(2)

	# --- Damage a second: every shape within a tenth of the broadsword --------------
	var dps := {}
	for id in SwingBuild.BLADE_ORDER:
		_blade(id)
		await _still()
		p.global_position = home
		var post = _slime(Vector2(34, 0))
		await _frames(2)
		p._reset_combo()
		p.input.attack_held = true
		p.input.attack_pressed = true
		await _frames(1)
		p.input.attack_pressed = false
		# Whole chains only: start counting at the first finisher's end, stop at a later one's.
		var chains := 0
		var t0 := -1
		var d0 := 0.0
		var t1 := 0
		var d1 := 0.0
		var prev := 0
		for i in 60 * 40:
			await _frames(1)
			if prev == 2 and p.current_step != 2:
				if t0 < 0:
					t0 = i
					d0 = _lost(post)
				else:
					chains += 1
					t1 = i
					d1 = _lost(post)
					if chains >= 8:
						break
			prev = p.current_step
		p.input.attack_held = false
		dps[id] = (d1 - d0) / (float(t1 - t0) / 60.0)
		post.queue_free()
		await _still()
	var base: float = dps["iron_broadsword"]
	for id in SwingBuild.BLADE_ORDER:
		var info := SwingBuild.blade_info(id)
		var ratio: float = float(dps[id]) / base
		var want: float = float(info["damage"]) * float(info["speed"]) / 11.0
		_check(ratio >= 0.9 and ratio <= 1.1, "%s: %.1f damage a second, %.2f of the broadsword's (within a tenth)" % [info["shape_name"], float(dps[id]), ratio])
		_check(absf(ratio - want) < 0.03, "%s: which is its damage times its speed (%.2f)" % [info["shape_name"], want])

	print("RESULT: " + ("all passed" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
