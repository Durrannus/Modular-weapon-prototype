extends SceneTree
## The test arena's two switches, run in the real arena with a scripted player:
## "Invincible" (on to begin with: it is a room for trying swords out) and "Pause
## enemies" (nobody new arrives, and the ones here stand still and hurt nobody,
## but can still be hit). Prints PASS / FAIL lines.
##   godot --headless --path . --fixed-fps 60 -s tests/arena_switches.gd

const EnemyScript := preload("res://scripts/enemy.gd")

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


func _enemy(kind: String, offset: Vector2):
	var e = EnemyScript.new()
	e.kind = kind
	e.position = p.global_position + offset
	m.world.add_child(e)
	e.died.connect(m._on_enemy_died)
	return e


func _lines() -> String:
	var out := ""
	for l in m.hud.arena_lines():
		out += str(l[0]) + "\n"
	return out


## A real key press, the way the keyboard sends it.
func _key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.pressed = down
		ev.keycode = code
		ev.physical_keycode = code
		Input.parse_input_event(ev)
		await _frames(3)


func _run() -> void:
	await process_frame
	await process_frame
	p = m.player
	p.input.kind = "script"
	m.spawning = false     # the test brings its own enemies, until it tests arrivals
	await _frames(5)
	var dummy = null
	for e in get_nodes_in_group("enemies"):
		if e.kind == "dummy":
			dummy = e

	# --- Invincible: on to begin with -------------------------------------------
	_check(m.invincible and p.unhurt, "the arena starts with Invincible on")
	_check(_lines().contains("Invincible") and m.hud.invincible_button.text == "INVINCIBLE: ON (H)", "and the screen says so, in words and on its button")
	var slime = _enemy("slime", Vector2(8, 0))
	var brute = _enemy("brute", Vector2(-10, 6))
	await _frames(180)
	_check(p.hp == p.max_hp and p.knocked_out_timer <= 0.0, "three seconds under a slime and a brute: not a scratch (%d)" % roundi(p.hp))
	m._toggle_invincible()
	await _frames(100)
	_check(not m.invincible and p.hp < p.max_hp, "switched off, they hurt (%d left)" % roundi(p.hp))
	_check(m.hud.invincible_button.text == "INVINCIBLE: OFF (H)", "and the button says it is off")
	m._toggle_invincible()
	await _frames(2)
	_check(p.hp == p.max_hp, "switching it back on tops the health up again")
	await _frames(120)
	_check(p.hp == p.max_hp, "and it stays there")

	# --- Pause enemies: they stand still and hurt nobody ------------------------
	m._toggle_invincible()      # off, so a paused enemy that still hurt would show
	await _frames(50)           # (the last hit's moment of safety runs out)
	m._toggle_paused()
	await _frames(2)
	p.hp = p.max_hp
	p.invuln = 0.0
	var charger = _enemy("charger", Vector2(200, 0))
	var far = _enemy("slime", Vector2(-300, 120))
	await _frames(2)
	var spots := {}
	for e in [slime, brute, charger, far]:
		spots[e] = e.global_position
	_check(slime.held and brute.held and charger.held and far.held, "Pause enemies holds everyone in the room, and anyone who turns up later")
	_check(dummy != null and not dummy.held, "(not the training dummy: it never did anything)")
	await _frames(180)
	var moved := 0.0
	for e in spots:
		moved = maxf(moved, e.global_position.distance_to(spots[e]))
	_check(moved < 0.01, "three seconds on, nobody has moved (%.2f)" % moved)
	_check(charger.state == "chase", "the charger never starts its dash")
	_check(p.hp == p.max_hp, "and standing in the middle of them costs no health (%d)" % roundi(p.hp))
	_check(_lines().contains("Enemies paused") and m.hud.pause_button.text == "RESUME ENEMIES (P)", "the screen says the enemies are paused")
	# Nobody new arrives.
	m.spawning = true
	m.spawn_timer = 0.1
	var count: int = m._enemy_count()
	await _frames(300)
	_check(m._enemy_count() == count, "five seconds paused: nobody new arrives (%d enemies)" % count)
	# They can still be hit, and killed.
	slime.global_position = p.global_position + Vector2(52, 0)
	brute.global_position = p.global_position + Vector2(0, -300)
	slime.max_hp = 500.0
	slime.hp = 500.0
	p.input.stick_aim = Vector2.RIGHT
	p.input.attack_pressed = true
	p.input.attack_held = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(30)
	p.input.attack_held = false
	_check(slime.hp < 500.0, "a paused enemy can still be hit (%d damage)" % roundi(500.0 - slime.hp))
	var kills: int = m.kills
	slime.hp = 1.0
	slime.global_position = p.global_position + Vector2(52, 0)
	await _frames(40)
	p.input.attack_pressed = true
	p.input.attack_held = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(30)
	p.input.attack_held = false
	_check(m.kills == kills + 1, "and killed")

	# --- Resume: they come at you again, and more arrive ------------------------
	p.input.stick_aim = Vector2.ZERO
	var gap: float = far.global_position.distance_to(p.global_position)
	m._toggle_paused()
	await _frames(60)
	_check(not far.held and far.global_position.distance_to(p.global_position) < gap - 30.0, "Resume enemies: they come at you again")
	count = m._enemy_count()
	await _frames(240)
	_check(m._enemy_count() > count, "and new ones arrive again")
	_check(not _lines().contains("paused") and m.hud.pause_button.text == "PAUSE ENEMIES (P)", "the screen stops saying paused")

	# --- The keys and the buttons do the same -----------------------------------
	m._toggle_invincible()      # back on
	await _key(KEY_P)
	_check(m.enemies_paused, "P pauses the enemies")
	await _key(KEY_P)
	_check(not m.enemies_paused, "P again lets them go")
	await _key(KEY_H)
	_check(not m.invincible, "H switches Invincible off")
	await _key(KEY_H)
	_check(m.invincible, "H again switches it back on")
	m.hud.pause_button.pressed.emit()
	m.hud.invincible_button.pressed.emit()
	await _frames(2)
	_check(m.enemies_paused and not m.invincible, "the two buttons at the top right do the same")
	# Two players have no room for the buttons: the words under the kills show both switches.
	m.hud.players = [p, p]
	_check(_lines().contains("Invincible is off") and _lines().contains("Enemies paused"), "with two players the words alone show both switches")
	m.hud.players = [p]

	print("RESULT: %s" % ("all passed" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
