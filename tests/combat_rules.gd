extends SceneTree
## Checks for the combat rules of 19 November (version 33), run in the real arena
## with a scripted player:
##   - the "toughest enemy" rule: most health left, and an elite always first;
##   - Shards: a cone of shards straight out of the back of the enemy you hit;
##   - Hook: one chain, one enemy, and a boss drags you to it instead.
## (Bulwark, which only blocks now and bursts when enemies break it, is checked
## with the hammer's other runes in hammer_runes.gd.)
##   godot --headless --path . --fixed-fps 60 -s tests/combat_rules.gd

const EnemyScript := preload("res://scripts/enemy.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Player := preload("res://scripts/player.gd")
const RuneFx := preload("res://scripts/fx/rune_fx.gd")

const SWING := 30.8          # one swing of the iron maul (18.7 until version 34 made the hammer slow and heavy)
const HOME := Vector2(900, 560)   # the middle of the room, far from every wall

var m
var p
var fails := 0
var made: Array = []
var sword_data: Array = []


func _init() -> void:
	m = load("res://scripts/main.gd").new()
	root.add_child(m)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _near(a: float, b: float, slack := 0.01) -> bool:
	return absf(a - b) <= slack


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## An enemy that stands where it's put and can't be killed. resist: how much of a
## shove it takes (0: nothing moves it, which makes it "too heavy" for Hook).
func _enemy(offset: Vector2, resist := 0.0, kind := "slime"):
	var e = EnemyScript.new()
	e.kind = kind
	e.position = p.global_position + offset
	m.world.add_child(e)
	e.max_hp = 500000.0
	e.hp = 500000.0
	e.speed = 0.0
	e.contact_damage = 0.0
	e.knock_resist = resist
	made.append(e)
	return e


func _clear() -> void:
	for e in made:
		if is_instance_valid(e):
			e.queue_free()
	made.clear()
	await _frames(2)


func _lost(e) -> float:
	return e.max_hp - e.hp


func _far(e) -> float:
	return e.global_position.distance_to(p.global_position)


func _still(frames := 40) -> void:
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.input.dash_pressed = false
	p.input.ability_held = [false, false, false]
	p.input.ability_pressed = [false, false, false]
	p.input.stick_aim = Vector2.RIGHT
	p._reset_combo()
	await _frames(frames)
	p._reset_combo()
	p.weapon["crit"] = 0.0   # no luck in the sums


## Puts this weapon in the hand, with these fittings bottom to top, and stands
## the player at `at`.
func _weapon(data: Array, line: Array, at: Vector2) -> void:
	await _clear()
	while line.size() < 4:
		line.append("")
	var d: Array = data.duplicate(true)
	d[3] = line
	m.build.set_data(d)
	m.build.changed.emit()
	await _still()
	p.global_position = at
	p.reset_physics_interpolation()
	p.dodge_charges = 1
	p.ability_charge = [1.0, 1.0, 1.0]
	p.ability_wait = [0.0, 0.0, 0.0]
	p.hp = p.max_hp
	p.invuln = 0.0
	await _frames(2)
	p.weapon["crit"] = 0.0


func _sword(line: Array, at := HOME) -> void:
	await _weapon(sword_data, line, at)


func _hammer(line: Array, at := HOME) -> void:
	await _weapon(["iron_maul", "bound_haft", "plain_weight", []], line, at)


## The first swing of the chain, once, aimed along `dir`, and time for what it
## sets off to land.
func _swing(dir := Vector2.RIGHT) -> void:
	p._reset_combo()
	p.input.stick_aim = dir
	await _frames(2)
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	await _frames(28)
	p._reset_combo()
	await _frames(24)


## Presses ability button `b`.
func _press(b: int) -> void:
	var on := [false, false, false]
	on[b] = true
	p.input.ability_pressed = on.duplicate()
	p.input.ability_held = on.duplicate()
	await _frames(1)
	p.input.ability_pressed = [false, false, false]
	p.input.ability_held = [false, false, false]
	await _frames(1)


## The chains on screen right now that have nobody on them.
func _empty_chains() -> int:
	var n := 0
	for c in p._fx_root().get_children():
		if c is RuneFx and c.kind == "chain" and c.to_node == null:
			n += 1
	return n


func _said(text: String) -> bool:
	for c in p._fx_root().get_children():
		if c is RuneFx and c.kind == "text" and str(c.text) == text:
			return true
	return false


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
	p.global_position = HOME
	p.reset_physics_interpolation()
	await _frames(2)
	sword_data = m.build.get_data()
	_check(m.build.weapon() == "sword" and m.build.slot_count() >= 3, "the arena starts with a sword that has room for a rune and two threads")

	await _toughest()
	await _shards()
	await _hook()

	print("RESULT: " + ("all passed" if fails == 0 else "%d failed" % fails))
	quit(1 if fails > 0 else 0)


# --- The "toughest enemy" rule ------------------------------------------------------

func _pick(reach := 300.0, skip := {}):
	return EnemyScript.toughest(get_nodes_in_group("enemies"), p.global_position, reach, skip)


func _toughest() -> void:
	await _sword([])
	_check(_pick() == null, "toughest: with nobody near, nobody is picked")
	var a = _enemy(Vector2(60, 0))
	var b = _enemy(Vector2(0, 120))
	var c = _enemy(Vector2(-200, 0))
	await _frames(2)
	a.hp = 100.0
	b.hp = 300.0
	c.hp = 200.0
	_check(_pick() == b, "toughest: the enemy with the most health left")
	b.max_hp = 900.0
	b.hp = 150.0
	_check(_pick() == c, "health left, not how much it started with: hurt it and the next one is the toughest")
	b.hp = 300.0

	# An elite always counts as the toughest, whatever its health.
	_check(not a.elite and not b.elite, "no enemy is an elite unless it is made one")
	a.elite = true
	_check(_pick() == a, "an elite in reach is the toughest, even with the least health left")
	c.elite = true
	_check(_pick() == c, "two elites: the one with more health left")
	a.elite = false
	c.elite = false

	# Only who is in reach (measured to their edge).
	_check(_pick(107.0) == b, "reach is to an enemy's edge, not its middle (120 away, 14 wide, reach 107)")
	_check(_pick(105.0) == a, "an enemy out of reach is not picked, however tough")
	c.elite = true
	_check(_pick(150.0) == b, "an elite out of reach doesn't count")
	c.elite = false

	# Two alike: the nearer.
	a.hp = 300.0
	_check(_pick() == a, "two with the same health left: the nearer one")
	a.hp = 100.0

	# Never one that can't be hurt, is dead, or was asked to be left out.
	b.immune = true
	_check(_pick() == c, "an enemy that can't be hurt right now is never picked")
	b.immune = false
	b.dead = true
	_check(_pick() == c, "nor a dead one")
	b.dead = false
	_check(_pick(300.0, {b.get_instance_id(): true}) == c, "nor one it was told to leave out")
	_check(_pick(300.0, {a.get_instance_id(): true, b.get_instance_id(): true, c.get_instance_id(): true}) == null, "all left out: nobody")
	await _clear()


# --- Shards ----------------------------------------------------------------------------

func _shards() -> void:
	await _sword(["shards"])
	var dmg := float(p.weapon["damage"])
	_check(p._hit_reach() < 130.0, "(the sword's own swing doesn't reach the enemies standing behind in these checks: %.0f)" % p._hit_reach())
	_check(_near(Player.SHARD_DAMAGE, 0.6) and Player.SHARD_COUNT == 3 and _near(Player.SHARD_RANGE, 130.0) and _near(Player.SHARD_CONE, 44.0), "Shards: three in a burst, 44 degrees wide, 130 far, 0.6 of a blade hit each")

	# Out of the back of the enemy you hit: who stands behind it is cut, who stands
	# beside it is not, and nothing comes back at you or curves.
	var near = _enemy(Vector2(50, 0))
	var behind = _enemy(Vector2(150, 0))
	var beside = _enemy(Vector2(50, 130))
	var off_line = _enemy(Vector2(150, 70))
	await _frames(2)
	await _swing()
	_check(_near(_lost(near), dmg), "the swing hits the enemy in front of you (%.2f)" % _lost(near))
	_check(_near(_lost(behind), dmg * 0.6), "its shards cut the enemy standing behind it, once (%.2f, want %.2f)" % [_lost(behind), dmg * 0.6])
	_check(_lost(beside) == 0.0, "an enemy beside it is untouched: the shards leave by its back")
	_check(_lost(off_line) == 0.0, "an enemy between two shards' lines is missed: they fly straight and don't curve")

	# From the back, wherever the enemy stands: aimed up, they fly up.
	await _sword(["shards"])
	near = _enemy(Vector2(0, -50))
	behind = _enemy(Vector2(0, -150))
	beside = _enemy(Vector2(100, -50))
	await _frames(2)
	await _swing(Vector2.UP)
	_check(_near(_lost(near), dmg) and _near(_lost(behind), dmg * 0.6) and _lost(beside) == 0.0, "an enemy above you: the shards fly on upwards (%.2f behind, %.2f beside)" % [_lost(behind), _lost(beside)])

	# One cut for each enemy from one burst, and the other shards fly on: a wide
	# enemy all three are lined up on is cut once, and the outer two go on to
	# whoever is behind it on their lines.
	await _sword(["shards"])
	near = _enemy(Vector2(50, 0))
	var wide = _enemy(Vector2(125, 0), 0.0, "brute")
	var line := Vector2.RIGHT.rotated(deg_to_rad(-22.0))
	var outer = _enemy(Vector2(64, 0) + line * 130.0)
	await _frames(2)
	await _swing()
	_check(_near(_lost(wide), dmg * 0.6), "a wide enemy in the way of all three shards is cut only once (%.2f)" % _lost(wide))
	_check(_near(_lost(outer), dmg * 0.6), "and an outer shard flies on to the enemy behind it (%.2f)" % _lost(outer))

	# How far: 130 from the enemy's back. Wider: further.
	await _sword(["shards"])
	near = _enemy(Vector2(50, 0))
	var edge = _enemy(Vector2(64 + 155, 0))     # its nearest edge is 135 from where the shards leave
	await _frames(2)
	await _swing()
	_check(_lost(edge) == 0.0, "a shard flies 130 and no further")
	await _sword(["wider", "shards"])
	near = _enemy(Vector2(50, 0))
	edge = _enemy(Vector2(64 + 155, 0))
	await _frames(2)
	await _swing()
	_check(_near(_lost(edge), dmg * 0.6), "Wider: the shards fly further (%.2f)" % _lost(edge))

	# A wall stops them.
	var wall_x: float = m.ARENA.end.x
	await _sword(["shards"], Vector2(wall_x - 95.0, 560))
	near = _enemy(Vector2(50, 0))
	var outside = _enemy(Vector2(160, 0))       # the other side of the east wall
	await _frames(2)
	await _swing()
	_check(_near(_lost(near), dmg) and _lost(outside) == 0.0, "a wall stops a shard (%.2f through it)" % _lost(outside))

	# Every Hit: twice as many, at half strength.
	await _sword(["every_hit", "shards"])
	_check(p.weapon["effects"][0].get("splinter", false), "Every Hit on Shards: twice as many shards")
	near = _enemy(Vector2(50, 0))
	behind = _enemy(Vector2(150, 0))
	await _frames(2)
	await _swing()
	_check(_near(_lost(behind), dmg * 0.3), "each at half strength, and still one cut for an enemy (%.2f, want %.2f)" % [_lost(behind), dmg * 0.3])

	# Twice: two bursts.
	await _sword(["twice", "shards"])
	near = _enemy(Vector2(50, 0))
	behind = _enemy(Vector2(150, 0))
	await _frames(2)
	await _swing()
	_check(_near(_lost(behind), dmg * 1.2), "Twice: a second burst follows the first (%.2f, want %.2f)" % [_lost(behind), dmg * 1.2])

	# Saved Up: every third hit, three times as strong.
	await _sword(["saved_up", "shards"])
	near = _enemy(Vector2(50, 0))
	behind = _enemy(Vector2(150, 0))
	await _frames(2)
	await _swing()
	await _swing()
	var before := _lost(behind)
	await _swing()
	_check(before == 0.0 and _near(_lost(behind), dmg * 1.8), "Saved Up: nothing on two hits, then one burst three times as strong (%.2f, then %.2f)" % [before, _lost(behind)])

	# On Dodge: no enemy was hit, so the burst leaves you, the way you aim.
	await _sword(["on_dodge", "shards"])
	behind = _enemy(Vector2(100, 0))
	beside = _enemy(Vector2(0, 100))
	await _frames(2)
	p.input.move = Vector2.LEFT
	p.input.dash_pressed = true
	await _frames(1)
	p.input.dash_pressed = false
	await _frames(20)
	p.input.move = Vector2.ZERO
	_check(_near(_lost(behind), dmg * 0.6) and _lost(beside) == 0.0, "On Dodge: a dodge sends a burst from you, the way you aim (%.2f ahead, %.2f to the side)" % [_lost(behind), _lost(beside)])
	await _clear()


# --- Hook ----------------------------------------------------------------------------

func _hook() -> void:
	_check(_near(Player.HOOK_REACH, 260.0) and _near(Player.HOOK_DAMAGE, 0.3) and _near(Player.HOOK_TUG, 60.0), "Hook: takes hold from 260 away, bites for 0.3 of a swing, and a boss pulls you 60")

	# One chain, one enemy: the one you aim at. Nobody else is touched.
	await _hammer(["hook"])
	var aimed = _enemy(Vector2(200, 0), 1.0)
	var side = _enemy(Vector2(100, 100), 1.0)     # nearer, but off to the side
	var back = _enemy(Vector2(-80, 0), 1.0)       # nearest of all, but behind you
	await _frames(2)
	var side_at: Vector2 = side.global_position
	var back_at: Vector2 = back.global_position
	await _press(0)
	_check(aimed.stun_time > 0.4 and aimed.stun_time <= 0.5, "the enemy on the chain can't act while it is dragged (%.2f s)" % aimed.stun_time)
	await _frames(40)
	_check(_far(aimed) < 60.0, "Hook drags the enemy you aim at all the way to you (200 -> %.0f)" % _far(aimed))
	_check(_near(_lost(aimed), SWING * 0.3), "and bites it for three tenths of a swing (%.3f)" % _lost(aimed))
	_check(_lost(side) == 0.0 and _lost(back) == 0.0 and side.global_position.distance_to(side_at) < 0.5 and back.global_position.distance_to(back_at) < 0.5, "one chain, one enemy: a nearer one to the side and one behind you are left alone")
	_check(float(p.ability_charge[0]) < 0.2 and _near(float(p.weapon["abilities"][0]["recharge"]), 4.0), "four seconds to recharge")

	# However heavy (short of a boss), it comes all the way.
	await _hammer(["hook"])
	var brute = _enemy(Vector2(230, 0), 0.3, "brute")
	await _frames(2)
	await _press(0)
	await _frames(45)
	_check(_far(brute) < 26.0 + 45.0, "a brute, hard to shove, is dragged all the way too (230 -> %.0f)" % _far(brute))

	# Nobody in reach: the chain flies out empty, and the press is spent.
	await _hammer(["hook"])
	var out_there = _enemy(Vector2(300, 0), 1.0)
	await _frames(2)
	await _press(0)
	_check(_empty_chains() == 1, "nobody in reach: the chain flies out the way you aim and comes back empty")
	await _frames(30)
	_check(_lost(out_there) == 0.0 and _near(_far(out_there), 300.0, 0.5) and float(p.ability_charge[0]) < 0.2, "an enemy out of reach isn't touched, and the press is spent")

	# Wider: it reaches further.
	await _hammer(["wider", "hook"])
	out_there = _enemy(Vector2(400, 0), 1.0)
	await _frames(2)
	await _press(0)
	await _frames(50)
	_check(_far(out_there) < 60.0, "Wider: the chain reaches an enemy 400 away (-> %.0f)" % _far(out_there))

	# Too heavy: what can't be moved pulls you to it instead, a little way, and
	# never right up against it.
	await _hammer(["hook"])
	var post = _enemy(Vector2(200, 0))
	await _frames(2)
	var from: Vector2 = p.global_position
	await _press(0)
	_check(_said("TOO HEAVY!"), "an enemy too heavy to drag says so")
	await _frames(20)
	var went: Vector2 = p.global_position - from
	_check(_near(went.x, 60.0, 1.5) and absf(went.y) < 0.5 and _near(_far(post), 140.0, 1.5), "and the chain pulls you 60 towards it instead (%.1f)" % went.x)
	_check(_near(_lost(post), SWING * 0.3) and post.global_position.distance_to(from + Vector2(200, 0)) < 0.5, "it is bitten, but doesn't move")
	await _hammer(["hook"])
	post = _enemy(Vector2(80, 0))
	await _frames(2)
	await _press(0)
	await _frames(20)
	_check(_near(_far(post), 14.0 + 34.0, 1.5), "up close you are pulled only as far as arm's length (80 -> %.1f)" % _far(post))

	# A boss: the forge guardian.
	await _hammer(["hook"])
	var g = m.spawn_enemies("guardian")[0]
	made.append(g)
	g.global_position = HOME + Vector2(250, 0)
	var small = _enemy(Vector2(0, 400), 1.0)
	_check(g.is_boss() and not small.is_boss(), "the forge guardian is a boss; a slime is not")
	for i in 200:
		await _frames(1)
		if not g.immune:
			break
	await _frames(2)
	p.global_position = g.global_position - Vector2(250, 0)
	p.reset_physics_interpolation()
	p.input.stick_aim = Vector2.RIGHT
	await _frames(1)
	from = p.global_position
	var g_at: Vector2 = g.global_position
	var g_hp: float = g.hp
	await _press(0)
	var g_knock: float = g.knock.length()
	await _frames(12)
	went = p.global_position - from
	_check(_near(went.x, 60.0, 2.0) and absf(went.y) < 2.0, "Hook on a boss tugs you a little way towards it (%.1f)" % went.x)
	_check(g_knock < 0.5 and _near(g_hp - g.hp, SWING * 0.3), "the boss isn't dragged, only bitten (%.2f)" % (g_hp - g.hp))
	_check(g.global_position.distance_to(g_at) < 40.0, "(it stays where it was, give or take its own steps: %.1f)" % g.global_position.distance_to(g_at))
	await _clear()

	# Twice: a second chain straight after, at another enemy. Never the same one.
	await _hammer(["twice", "hook"])
	aimed = _enemy(Vector2(200, 0), 1.0)
	side = _enemy(Vector2(190, 80), 1.0)
	await _frames(2)
	await _press(0)
	await _frames(50)
	_check(_far(aimed) < 60.0 and _far(side) < 60.0 and _near(_lost(aimed), SWING * 0.3) and _near(_lost(side), SWING * 0.3), "Twice: a second chain takes another enemy (%.0f and %.0f away now)" % [_far(aimed), _far(side)])
	await _hammer(["twice", "hook"])
	aimed = _enemy(Vector2(200, 0), 1.0)
	await _frames(2)
	await _press(0)
	await _frames(50)
	_check(_near(_lost(aimed), SWING * 0.3), "with only one enemy about, the second chain does nothing: it is never bitten twice (%.3f)" % _lost(aimed))

	# Saved Up: a longer wait, and the enemy arrives stunned.
	await _hammer(["saved_up", "hook"])
	aimed = _enemy(Vector2(200, 0), 1.0)
	await _frames(2)
	await _press(0)
	_check(aimed.stun_time > 2.4 and aimed.stun_time <= 2.5, "Saved Up: the enemy it drags in is stunned for 2 seconds more (%.2f)" % aimed.stun_time)
	_check(_near(_lost(aimed), SWING * 0.3), "its bite is no harder (%.3f)" % _lost(aimed))
	_check(_near(float(p.weapon["abilities"][0]["recharge"]), 12.0), "and it takes 12 seconds to recharge")

	# Every Hit: each swing that lands takes half a second off the wait.
	await _hammer(["every_hit", "hook"])
	_check(_near(float(p.weapon["abilities"][0].get("refund", 0.0)), 0.5), "Every Hit: a landed swing takes half a second off Hook's wait")

	# On Dodge: a quick chain as the dodge ends, at the nearest enemy, at half
	# strength, and the button's own charge isn't touched.
	await _hammer(["on_dodge", "hook"])
	var close = _enemy(Vector2(0, 200), 1.0)      # nearest once you have dodged towards it
	aimed = _enemy(Vector2(200, 0), 1.0)          # the one you are pointing at
	await _frames(2)
	p.input.move = Vector2.DOWN
	p.input.dash_pressed = true
	await _frames(1)
	p.input.dash_pressed = false
	await _frames(5)
	var early := _lost(close) + _lost(aimed)
	await _frames(10)
	p.input.move = Vector2.ZERO
	_check(early == 0.0 and _near(_lost(close), SWING * 0.15), "On Dodge: a quick chain goes out as the dodge ends, at half strength (%.3f)" % _lost(close))
	await _frames(30)
	_check(_far(close) < 60.0 and _lost(aimed) == 0.0, "it takes the nearest enemy, not the one you point at")
	_check(float(p.ability_charge[0]) >= 1.0, "and the button's own charge is left full")
	await _clear()
