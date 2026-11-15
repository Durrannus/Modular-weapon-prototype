extends SceneTree
## Checks for the staff (15 November), run in the real arena with a scripted
## player: its parts, swapping to it, the apprentice's bolt, bolt, burst and what
## each hits, mana (what a cast costs, how it comes back, the weak sparks you cast
## without it), the storm head's sprays and orb, and that a staff does less damage
## a second than the sword it stands beside.
##   godot --headless --path . --fixed-fps 60 -s tests/staff.gd

const EnemyScript := preload("res://scripts/enemy.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const SwordArt := preload("res://scripts/weapon/sword_art.gd")
const BowArt := preload("res://scripts/weapon/bow_art.gd")
const Player := preload("res://scripts/player.gd")
const Art := preload("res://scripts/art.gd")

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


## A slime that stands where it's put and can't be killed.
func _slime(offset: Vector2):
	var e = EnemyScript.new()
	e.kind = "slime"
	e.position = p.global_position + offset
	m.world.add_child(e)
	e.max_hp = 500000.0
	e.hp = 500000.0
	e.speed = 0.0
	e.contact_damage = 0.0
	e.knock_resist = 0.0
	return e


func _lost(e) -> float:
	return e.max_hp - e.hp


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _has_art(rel: String) -> bool:
	return Art.texture(rel) != null


func _bolts() -> Array:
	var out: Array = []
	for a in get_nodes_in_group("arrows"):
		if is_instance_valid(a) and not a.is_queued_for_deletion():
			out.append(a)
	return out


## Stands still with a full staff until every bolt has landed.
func _still() -> void:
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.input.stick_aim = Vector2.RIGHT
	p._reset_combo()
	await _frames(100)     # long enough for an orb to cross its whole range
	p._reset_combo()
	p.mana = SwingBuild.MANA
	p.weapon["crit"] = 0.0   # no luck in the sums


## Casts the first `count` moves of the chain and waits for the last to end and
## its bolt to land.
func _casts(count: int) -> void:
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
	await _frames(70)
	p._reset_combo()


## One press of the button, then waits for the first thing to leave the staff.
func _first_bolt():
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	for i in 80:
		await _frames(1)
		if not _bolts().is_empty():
			return _bolts()[0]
	return null


## Damage a second of whole chains against a post at `offset`.
func _dps(offset: Vector2) -> float:
	var post = _slime(offset)
	await _frames(2)
	p._reset_combo()
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
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
				if chains >= 6:
					break
		prev = p.current_step
	p.input.attack_held = false
	post.queue_free()
	await _still()
	return (d1 - d0) / (float(t1 - t0) / 60.0)


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
	var home := Vector2(900, 560)      # the middle of the room, far from every wall
	p.global_position = home
	p.reset_physics_interpolation()
	await _frames(2)

	# --- The parts: what counts as a staff ---------------------------------------------
	var test_staff: Array = SwingBuild.TEST_STAFF
	_check(SwingBuild.valid_data(test_staff), "the arena's test staff is a whole weapon (head, shaft, cap, slots, crystal)")
	_check(SwingBuild.valid_data(SwingBuild.STARTERS["staff"]), "and so is the plain wooden staff everyone starts from")
	_check(not SwingBuild.valid_data(["iron_apprentice", "bound_haft", "plain_cap", ["", "", "", ""], "iron_crystal"]), "a staff can't take a hammer's haft")
	_check(not SwingBuild.valid_data(["iron_apprentice", "carved_shaft", "plain_weight", ["", "", "", ""], "iron_crystal"]), "nor a counterweight for a cap")
	_check(not SwingBuild.valid_data(["iron_apprentice", "carved_shaft", "plain_cap", ["", "", "", ""]]), "a staff with no crystal isn't one")
	_check(not SwingBuild.valid_data(["iron_apprentice", "carved_shaft", "plain_cap", ["", "", "", ""], "iron_arrows"]), "and arrows are no crystal")
	_check(not SwingBuild.valid_data(["iron_shortbow", "wrapped_bow_grip", "plain_string", ["", "", "", ""], "iron_crystal"]), "a bow doesn't shoot crystals either")
	_check(not SwingBuild.valid_data(["iron_apprentice", "carved_shaft", "plain_cap", ["", ""], "iron_crystal"]), "the slots must fit the head and shaft (iron apprentice 2 + carved shaft 2)")
	_check(SwingBuild.weapon_of("iron_apprentice") == "staff" and SwingBuild.weapon_of("iron_storm") == "staff" and SwingBuild.ranged("staff"), "an apprentice and a storm head are staffs, and a staff fights from range")
	for id in SwingBuild.STAFF_HEADS:
		_check(_has_art("swing/staff/heads/%s_hand.png" % id), "%s has its picture" % SwingBuild.STAFF_HEADS[id]["name"])
	for id in SwingBuild.SHAFTS:
		_check(_has_art("swing/staff/shafts/%s_hand.png" % id), "%s has its picture" % SwingBuild.SHAFTS[id]["name"])
	for id in SwingBuild.CAPS:
		_check(_has_art("swing/staff/caps/%s_hand.png" % id), "%s has its picture" % SwingBuild.CAPS[id]["name"])
	for id in SwingBuild.CRYSTALS:
		_check(_has_art("swing/staff/crystals/%s_hand.png" % id), "%s has its picture" % SwingBuild.CRYSTALS[id]["name"])
		_check(SwordArt.crystal_color(id) == SwingBuild.CRYSTALS[id]["color"], "and the game tints its bolts the colour the art gives it")
	for name in ["bolt_fly", "bolt_trail", "bolt_hit", "burst_fly", "burst_hit", "spark_fly", "orb_fly", "orb_hit", "cast_flash"]:
		_check(BowArt.fx_texture(name) != null and not BowArt.fx(name).is_empty(), "the %s effect has its picture and its numbers" % name)

	# --- Swapping to it -----------------------------------------------------------------
	var sword: Array = m.build.get_data()
	m.swap_weapon(0)
	m.swap_weapon(0)
	m.swap_weapon(0)
	await _frames(2)
	_check(m.build.weapon() == "staff" and m.build.get_data() == test_staff, "three swaps from the sword (past the bow and the hammer) put the iron staff in your hand")
	_check(p.weapon.get("weapon") == "staff" and p._is_staff() and p._ranged(), "and the player knows it is a staff")
	_check(m.build.stowed.get("sword") == sword and m.build.stowed.has("bow") and m.build.stowed.has("hammer"), "the other three wait")
	_check(m.hud.swap_button.text == "SWAP TO SWORD (B)", "the button now offers the sword again")
	_check(m.hud._holds(p, "staff"), "the mana bar belongs to whoever holds a staff")
	_check(_near(float(p.weapon["damage"]), 11.0 * SwingBuild.STAFF_DAMAGE) and _near(float(p.weapon["damage"]), 8.8), "a bolt from an iron crystal does 8.8: four fifths of an iron sword's 11, like an arrow")
	_check(_near(float(p.weapon["range"]), 400.0) and _near(float(p.weapon["flight"]), 760.0), "it flies 400 px at 760 a second (an arrow: 520 at 1300)")
	_check(p.weapon.get("hit_color") == Color("#c090ff"), "in the iron crystal's violet")
	var chain: Array = []
	for st in p.weapon["steps"]:
		chain.append(st["move"])
	_check(chain == ["bolt", "bolt", "burst"], "apprentice head: bolt, bolt, burst")
	_check(p.weapon.get("arrows") == "iron_crystal", "with the iron crystal")
	var fresh = SwingBuild.new()
	fresh.set_data(SwingBuild.STARTERS["sword"])
	fresh.take("staff")
	_check(fresh.get_data() == SwingBuild.STARTERS["staff"] and fresh.compute()["weapon"] == "staff", "someone who never had a staff gets the wooden one")
	_check(_near(float(fresh.compute()["damage"]), 4.0), "whose sea glass does 4: a chain of 4 + 4 + 6 is one crawler's 14")
	await _still()

	# --- The forge doesn't know it yet ----------------------------------------------------
	m.open_forge(0)
	await _frames(2)
	_check(not m.build_menu.is_open, "the forge screen stays shut for a staff for now")
	_check(str(m.hud.said).contains("can't change a staff yet"), "and the game says why")

	# --- A chain at one enemy: 8.8, 8.8, 13.2 ---------------------------------------------
	var post = _slime(Vector2(200, 0))
	await _frames(2)
	await _casts(1)
	_check(_near(_lost(post), 8.8), "a bolt hits an enemy 200 px away for 8.8 (%.3f)" % _lost(post))
	post.hp = post.max_hp
	await _casts(3)
	_check(_near(_lost(post), 8.8 + 8.8 + 13.2), "the whole chain: 8.8 + 8.8 + a burst's 13.2 = 30.8 (%.3f)" % _lost(post))
	_check(_bolts().is_empty(), "a bolt that hits is gone")
	_check(is_equal_approx(p.global_position.x, home.x) and is_equal_approx(p.global_position.y, home.y), "casting doesn't move you")
	post.queue_free()
	await _still()

	# --- A bolt stops in the first enemy; the burst hurts everything near where it lands -----
	var near = _slime(Vector2(150, 0))
	var far = _slime(Vector2(300, 0))
	var beside = _slime(Vector2(200, 50))
	await _frames(2)
	await _casts(1)
	_check(_lost(near) > 0.0 and _lost(far) == 0.0, "a bolt stops in the first enemy it meets")
	_check(_lost(beside) == 0.0, "and it is narrow: one standing 50 px off its line is missed")
	for e in [near, far, beside]:
		e.queue_free()
	await _still()
	var target = _slime(Vector2(200, 0))
	var neighbour = _slime(Vector2(200, 45))
	var apart = _slime(Vector2(200, 120))
	await _frames(2)
	await _casts(3)
	_check(_near(_lost(target), 30.8), "the enemy the burst lands on takes it once (30.8 for the chain, %.2f)" % _lost(target))
	_check(_near(_lost(neighbour), 13.2), "one standing 45 px from it is caught by the burst alone: 13.2 (%.2f)" % _lost(neighbour))
	_check(_lost(apart) == 0.0, "one 120 px away is not (the burst reaches 56)")
	for e in [target, neighbour, apart]:
		e.queue_free()
	await _still()

	# --- Range: 400 px, and a bolt is gone there ---------------------------------------------
	var edge: float = 400.0 + 14.0 + SwingBuild.BOLT_WIDTH
	var inside = _slime(Vector2(edge - 5.0, 0))
	await _frames(2)
	await _casts(1)
	_check(_lost(inside) > 0.0, "an enemy whose edge is just inside 400 px is hit")
	inside.global_position = p.global_position + Vector2(edge + 8.0, 0)
	inside.hp = inside.max_hp
	await _frames(2)
	var bolt = await _first_bolt()
	_check(bolt != null and bolt.bolt == "bolt", "a bolt leaves the staff")
	var last_x := 0.0
	for i in 80:
		if not is_instance_valid(bolt) or bolt.is_queued_for_deletion():
			break
		last_x = bolt.global_position.x
		await _frames(1)
	_check(_lost(inside) == 0.0, "one just past it is not")
	_check(_bolts().is_empty() and last_x <= home.x + 400.0 + 0.5, "and the bolt is gone 400 px out: nothing is left lying there")
	inside.queue_free()
	await _still()
	# A burst that reaches the end of its flight goes off there.
	var at_end = _slime(Vector2(400.0 + 50.0, 0))
	await _frames(2)
	await _casts(3)
	_check(_near(_lost(at_end), 13.2), "a burst that hits nothing goes off where it stops: an enemy 50 px past that is caught (%.2f)" % _lost(at_end))
	at_end.queue_free()
	await _still()

	# --- A wall stops it -------------------------------------------------------------------
	var wall_x: float = m.ARENA.end.x
	p.global_position = Vector2(wall_x - 150.0, 560)
	p.reset_physics_interpolation()
	var behind_wall = _slime(Vector2(190, 0))      # outside the room
	await _frames(2)
	bolt = await _first_bolt()
	last_x = 0.0
	for i in 80:
		if not is_instance_valid(bolt) or bolt.is_queued_for_deletion():
			break
		last_x = bolt.global_position.x
		await _frames(1)
	_check(_bolts().is_empty() and last_x <= wall_x + 0.5, "a bolt stops at the wall it meets (150 px away)")
	_check(_lost(behind_wall) == 0.0, "and never reaches an enemy on the other side")
	behind_wall.queue_free()
	p.global_position = home
	p.reset_physics_interpolation()
	await _still()

	# --- You aim while you gather: the bolt goes where you point as it leaves ----------------
	var above = _slime(Vector2(0, -200))
	var right = _slime(Vector2(200, 0))
	await _frames(2)
	p.input.stick_aim = Vector2.RIGHT
	p._reset_combo()
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(3)
	_check(_bolts().is_empty() and p.current_step == 0, "the staff gathers first: nothing leaves for a moment")
	p.input.stick_aim = Vector2.UP
	await _frames(60)
	_check(_lost(above) > 0.0 and _lost(right) == 0.0, "turning while it gathers turns the bolt (began aiming right, cast up)")
	above.queue_free()
	right.queue_free()
	await _still()

	# --- You can walk while you cast, a little slower -------------------------------------
	p.input.move = Vector2.LEFT
	p.input.attack_held = true
	await _frames(40)
	var v_cast: float = p.walk_vel.length()
	p.input.attack_held = false
	p.input.move = Vector2.ZERO
	_check(absf(v_cast - Player.MOVE_SPEED * SwingBuild.STAFF_MOVE) < 1.0, "you walk at 80%% speed while casting (%d of %d)" % [roundi(v_cast), roundi(Player.MOVE_SPEED)])
	p.global_position = home
	p.reset_physics_interpolation()
	await _still()

	# --- Mana: what a cast costs -------------------------------------------------------------
	_check(_near(p.mana, 100.0), "a rested staff has 100 mana")
	bolt = await _first_bolt()
	_check(absf(p.mana - 94.0) < 0.5, "a bolt costs 6 (%.1f left)" % p.mana)
	await _still()
	_check(m.net_state().has(p.mana) and m.net_state().has(p.cast_weak), "(mana is part of what two computers compare online)")
	p._reset_combo()
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	var before_burst := 0.0
	var after_burst := 0.0
	var seen := 0
	for i in 600:
		var had := _bolts().size()
		var mana_was: float = p.mana
		await _frames(1)
		if _bolts().size() > had:
			seen += 1
			if seen == 3:
				before_burst = mana_was
				after_burst = p.mana
				break
	p.input.attack_held = false
	_check(absf(before_burst - after_burst - 10.0) < 0.5, "the burst costs 10 (%.1f to %.1f)" % [before_burst, after_burst])
	await _still()

	# --- ...how it comes back -----------------------------------------------------------------
	p.mana = 20.0
	p.mana_rest = 0.0
	await _frames(30)
	_check(absf(p.mana - 25.0) < 0.2, "it trickles back at 10 a second (20 to %.1f in half a second)" % p.mana)
	await _frames(60)
	_check(absf(p.mana - (20.0 + 15.0 + 0.8 * 45.0)) < 1.0, "and after 0.7 s without a cast it pours back, 45 a second more (%.1f after a second and a half)" % p.mana)
	await _frames(60)
	_check(_near(p.mana, 100.0), "to 100 and no further")

	# --- ...and what you cast without it --------------------------------------------------------
	post = _slime(Vector2(200, 0))
	await _frames(2)
	p.mana = 2.0
	p.mana_rest = 0.0
	bolt = await _first_bolt()
	_check(bolt != null and bolt.bolt == "spark", "with too little mana for a bolt the staff casts a spark")
	_check(p.cast_weak and _near(p._speed(), 0.75), "three quarters as fast")
	_check(p.mana >= 2.0, "which costs nothing (%.1f)" % p.mana)
	await _frames(40)
	_check(_near(_lost(post), 4.4), "and hits for half: 4.4 (%.2f)" % _lost(post))
	post.queue_free()
	await _still()
	_check(not p.cast_weak and _near(p._speed(), 1.0), "the staff is itself again once it has rested")
	# Held down from full, it runs dry in about a quarter of a minute.
	post = _slime(Vector2(200, 0))
	await _frames(2)
	p._reset_combo()
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	var dry := -1
	for i in 60 * 30:
		await _frames(1)
		if p.cast_weak:
			dry = i
			break
	_check(dry > 60 * 10 and dry < 60 * 17, "casting without a rest, the mana lasts %.1f seconds" % (dry / 60.0))
	p.input.attack_held = false
	post.queue_free()
	await _frames(180)
	_check(_near(p.mana, 100.0), "three seconds' rest fills it again")
	await _still()

	# --- The storm head: spray, spray, orb ----------------------------------------------------
	m.build.set_blade("iron_storm")
	await _still()
	chain = []
	for st in p.weapon["steps"]:
		chain.append(st["move"])
	_check(chain == ["spray", "spray", "orb"], "storm head: spray, spray, orb")
	_check(_near(float(p.weapon["damage"]), 7.92) and _near(float(p.weapon["range"]), 280.0) and _near(float(p.weapon["size"]), 1.25), "its bolt is a tenth lighter (7.92), it reaches 280 px and its spells are a quarter bigger")
	var close = _slime(Vector2(50, 0))
	await _frames(2)
	await _casts(1)
	_check(_near(_lost(close), 3.0 * 0.4 * 7.92), "a spray is three sparks: from 50 px all three hit, 9.5 together (%.3f)" % _lost(close))
	close.global_position = p.global_position + Vector2(220, 0)
	close.hp = close.max_hp
	await _frames(2)
	await _casts(1)
	_check(_near(_lost(close), 0.4 * 7.92), "from 220 px only the middle one does: 3.2 (%.3f)" % _lost(close))
	close.queue_free()
	await _still()
	target = _slime(Vector2(150, 0))
	neighbour = _slime(Vector2(150, 80))
	apart = _slime(Vector2(150, 115))
	await _frames(2)
	p._reset_combo()
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	for i in 600:
		await _frames(1)
		if p.current_step == 2:
			break
	p.input.attack_held = false
	for e in [target, neighbour, apart]:
		e.hp = e.max_hp
	var orb = null
	for i in 60:
		await _frames(1)
		for b in _bolts():
			if b.bolt == "orb":
				orb = b
		if orb != null:
			break
	_check(orb != null and _near(orb.speed, 760.0 * 0.4), "the orb is slow: 304 px a second")
	await _frames(90)
	_check(_near(_lost(target), 11.88) and _near(_lost(neighbour), 11.88), "it bursts wide: the enemy it lands on and one 80 px from it take 11.88 each (%.2f, %.2f)" % [_lost(target), _lost(neighbour)])
	_check(_lost(apart) == 0.0, "one 115 px away does not (the orb's burst reaches 88)")
	for e in [target, neighbour, apart]:
		e.queue_free()
	await _still()
	var storm_dps: float = await _dps(Vector2(50, 0))
	m.build.set_blade("iron_apprentice")
	await _still()
	var staff_dps: float = await _dps(Vector2(200, 0))
	_check(absf(storm_dps / staff_dps - 1.0) < 0.1, "storm head up close %.1f damage a second, apprentice %.1f: within a tenth (%.2f)" % [storm_dps, staff_dps, storm_dps / staff_dps])

	# --- Ranged must not beat melee: the staff does less a second than the sword ---------------
	m.swap_weapon(0, "sword")
	await _frames(2)
	for i in m.build.line.size():
		m.build.line[i] = ""
	m.build.changed.emit()
	await _still()
	var sword_dps: float = await _dps(Vector2(34, 0))
	m.swap_weapon(0, "bow")
	await _frames(2)
	for i in m.build.line.size():
		m.build.line[i] = ""
	m.build.changed.emit()
	await _still()
	var bow_dps: float = await _dps(Vector2(200, 0))
	var ratio := staff_dps / sword_dps
	_check(ratio > 0.6 and ratio < 0.9, "the iron staff does %.1f a second at one enemy, the iron broadsword %.1f: less (%.2f)" % [staff_dps, sword_dps, ratio])
	_check(absf(staff_dps / bow_dps - 1.0) < 0.1, "and about what the iron shortbow does (%.1f): the staff reaches less far and its burst spreads" % bow_dps)
	m.swap_weapon(0, "staff")
	await _frames(2)
	_check(m.build.get_data() == test_staff, "back on the staff it is as it was")

	print("RESULT: %s (%d failed)" % ["all passed" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
