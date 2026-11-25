extends SceneTree
## The moor's creatures (version 63): the boar, the badger and the capercaillie. Darren, 25 November 2026: "The rest
## of the zone should be new simple neutral enemies so that the zone feels like it has different sections as it
## feels very samsey atm." Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands_creatures.gd
##
## Their pictures, each one alone in the test arena, then on the land: where they live, that walking past wakes
## nothing, that a blow wakes the group, that they settle again, and what a kill (or a badger that gets away) leaves.
##
## With shots=/some/folder/ (needs a window, so leave out --headless) it saves 640x360 pictures instead.

const PlayerInput := preload("res://scripts/player_input.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const FoePlan := preload("res://scripts/highlands/foe_plan.gd")
const Foes := preload("res://scripts/highlands/foes.gd")
const Nav := preload("res://scripts/highlands/nav.gd")
const Snow := preload("res://scripts/highlands/snow.gd")
const Loot := preload("res://scripts/highlands/loot.gd")
const Make := preload("res://scripts/foes/make.gd")
const Creature := preload("res://scripts/foes/creature.gd")
const Boar := preload("res://scripts/foes/boar.gd")
const Badger := preload("res://scripts/foes/badger.gd")
const Caper := preload("res://scripts/foes/capercaillie.gd")
const Art := preload("res://scripts/art.gd")
const Sim := preload("res://scripts/sim.gd")
const TILE := 32.0
const HOME := Vector2(900, 560)        # the middle of the arena, far from every wall
const SEEDS := [424242, 1, 7, 123456, 987654, 55]

var fails := 0
var checks := 0
var shot_dir := ""
var only := ""                         # "-- only=dogs" with shots=: just the goblins' war dogs (version 64)
var m                                  # the arena
var p                                  # its player


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shot_dir = a.substr(6)
		elif a.begins_with("only="):
			only = a.substr(5)
	_run()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL  " + what)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await physics_frame
	Painter.load_kit()
	if shot_dir != "":
		await _shots()
		quit()
		return
	_art()
	_where()
	await _arena_open()
	await _boar()
	await _badger()
	await _caper()
	await _arena_close()
	await _land()
	print("%s  the moor's creatures: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


# --- The art ---------------------------------------------------------------------------------

## The Art builder's moor sheet: every strip each creature asks for, with a box on the sheet, the right size.
func _art() -> void:
	var sheet := Art.texture(Creature.MOOR_SHEET)
	_check(sheet != null, "the moor sheet is in the game (art/foes/moor.png)")
	var book: Dictionary = Art.json(Creature.MOOR_BOOK).get("actors", {})
	var want := {"boar": ["idle", "move", "hit", "charge_windup", "charge", "death"],
		"badger": ["idle", "move", "hit", "bite", "dig", "death"],
		"capercaillie": ["idle", "move", "display", "hit", "flee", "death"]}
	for kind in want:
		var info: Dictionary = book.get(kind, {})
		_check(not info.is_empty() and info.has("origin_feet"), "the book has the %s, with its feet" % kind)
		for strip in want[kind]:
			var s: Dictionary = info.get("strips", {}).get(strip, {})
			var box: Array = s.get("box", [])
			var ok := box.size() == 4 and int(s.get("frames", 0)) >= 1 and int(box[2]) == int(info["frame"][0]) * int(s["frames"]) and int(box[3]) == int(info["frame"][1])
			if ok and sheet != null:
				ok = float(box[0]) + float(box[2]) <= float(sheet.get_width()) and float(box[1]) + float(box[3]) <= float(sheet.get_height())
			_check(ok and Creature.strip_tex(box, Creature.MOOR_SHEET) != null, "the %s's %s strip lies on the sheet" % [kind, strip])
	for kind in Make.CREATURES:
		_check(Make.knows(kind) and not Make.knows(kind + "_elite"), "a %s can be made, and has no elite" % kind)
	# No marks on the floor (Darren, 23 November: only bosses).
	for f in ["creature", "boar", "badger", "capercaillie"]:
		var src: String = (load("res://scripts/foes/%s.gd" % f) as GDScript).source_code
		_check(not src.contains("Warn.") and not src.contains("func _draw_ground"), "%s.gd draws no warning mark" % f)


# --- Where they live -------------------------------------------------------------------------

func _where() -> void:
	var cave := Vector2(LandMap.MID + 0.5, LandMap.MID + 0.5)
	var totals := {}
	var hostile_inner := 0
	var creature_places := 0
	var kinds_seen := {}
	for sv in SEEDS:
		var map: LandMap = WorldGen.make(sv)
		var plan := FoePlan.make(map)
		var yard: Vector2 = map.sites["scrapyard"]["at"]
		var snow := Snow.centre(map)
		var mixed := false
		var wrong := 0
		for g in plan:
			var at: Vector2 = g["home"]
			var grounds := at.distance_to(yard) < FoePlan.SCRAP_REACH or (snow != Vector2.INF and at.distance_to(snow) < Snow.REACH + Snow.HOUNDS_NEAR)
			var named := str(g["site"]) in ["roost", "den", "scrapyard", "watchpost", "quarry"]
			if str(g["what"]) == "creatures":
				creature_places += 1
				kinds_seen[str(g["members"][0][0])] = true
				if grounds or named:
					wrong += 1
				if (g["members"] as Array).any(func(mm): return str(mm[0]) != str(g["members"][0][0])):
					mixed = true
			elif not grounds and not named and not (g["members"] as Array).any(func(mm): return bool(mm[1])):
				wrong += 1
			if str(g["what"]) != "creatures" and int(map.pockets[int(g["pocket"])].get("ring", 1)) <= 1:
				hostile_inner += 1
		_check(wrong == 0, "seed %d: the moor's creatures live outside the goblins' and the hounds' ground and the named places, and nothing else does (%d wrong)" % [sv, wrong])
		_check(not mixed, "seed %d: one kind of creature to a place" % sv)
		var c := FoePlan.count(plan)
		for k in c:
			totals[k] = int(totals.get(k, 0)) + int(c[k])
	_check(kinds_seen.size() == 3, "all three creatures live on the land (%s)" % str(kinds_seen.keys()))
	print("      over %d lands: %d places of moor creatures; hostile groups in the inner ring: %d (the Watchpost, the Quarry and the hound ground's edge); %s" % [SEEDS.size(), creature_places, hostile_inner, str(totals)])


# --- Each alone, in the arena (where there is no group, so it wakes at once) ----------------

func _arena_open() -> void:
	m = load("res://scripts/main.gd").new()
	m.inputs = [PlayerInput.make("script")]
	root.add_child(m)
	await _frames(3)
	m.spawning = false
	m._set_invincible(false)
	m.clear_enemies()
	if is_instance_valid(m.home_dummy):
		m.home_dummy.queue_free()
	p = m.player
	await _frames(2)


func _arena_close() -> void:
	m.queue_free()
	await _frames(3)


func _reset(at := HOME) -> void:
	for e in get_nodes_in_group("foes"):
		e.queue_free()
	p.input.move = Vector2.ZERO
	p.global_position = at
	p.reset_physics_interpolation()
	p.hp = p.max_hp
	p.invuln = 0.0
	p.unhurt = false
	p.hurt_vel = Vector2.ZERO
	await _frames(3)
	p.hp = p.max_hp
	p.invuln = 0.0


func _put(kind: String, offset: Vector2):
	var e = Make.make(kind)
	e.position = p.global_position + offset
	m.world.add_child(e)
	e.died.connect(m._on_enemy_died)       # (as the lab's Spawn page does)
	return e


func _wait(until: Callable, most: int) -> int:
	for i in most:
		if until.call():
			return i
		await physics_frame
	return -1


func _boar() -> void:
	await _reset()
	var b = _put("boar", Vector2(300, 0))
	await _frames(2)
	_check(b.max_hp == Boar.HP and not b._sprite().is_empty(), "a boar has a boar's health and is drawn from its pictures")
	var t := await _wait(func(): return b.mode == "windup", 400)
	_check(t >= 0, "a boar comes for you and paws the ground")
	_check(str(b._sprite().get("anim", "")) == "charge_windup", "pawing, it shows its pawing strip (the warning)")
	var hp0: float = p.hp
	var paw := await _wait(func(): return b.mode != "windup", 120)
	_check(absf(float(paw) / 60.0 - Boar.WINDUP) < 0.1, "it paws for %.2f s before it goes (%.2f s)" % [Boar.WINDUP, float(paw) / 60.0])
	_check(p.hp == hp0, "pawing hurts nobody")
	_check(b.mode == "charge" and str(b._sprite().get("anim", "")) == "charge", "then it charges")
	t = await _wait(func(): return p.hp < hp0, 60)
	_check(t >= 0, "the charge hurts whoever it meets")
	_check(p.hurt_vel.length() > 300.0 or t < 0, "and throws them")
	await _wait(func(): return b.mode in ["recover", "dazed", "trot"], 90)
	# Out of the way: it misses, and stands Open a moment.
	await _reset()
	b = _put("boar", Vector2(240, 0))
	await _wait(func(): return b.mode == "charge", 400)
	p.global_position += Vector2(0, 140)
	p.reset_physics_interpolation()
	t = await _wait(func(): return b.mode in ["recover", "dazed"], 120)
	_check(t >= 0 and b.is_open(), "a boar that misses stands Open a moment")
	# It does not stop for blows while it paws.
	await _reset()
	b = _put("boar", Vector2(200, 0))
	await _wait(func(): return b.mode == "windup", 400)
	b.take_hit(1.0, Vector2.LEFT, 0.0, false, Color.WHITE)
	await _frames(int(Boar.WINDUP * 60.0) + 6)
	_check(b.mode == "charge" or b.mode == "recover", "a blow while it paws does not stop the charge")


func _badger() -> void:
	await _reset()
	var d = _put("badger", Vector2(200, 0))
	await _frames(2)
	_check(d.max_hp == Badger.HP and not d._sprite().is_empty(), "a badger has a badger's health and is drawn from its pictures")
	var hp0: float = p.hp
	var t := await _wait(func(): return d.mode == "jaw", 400)
	_check(t >= 0, "a badger comes at you and opens its jaw")
	_check(str(d._sprite().get("anim", "")) == "bite" and int(d._sprite().get("frame", -1)) == 0, "its open jaw is the bite strip's first frame (the warning)")
	_check(p.hp == hp0, "an open jaw hurts nobody yet")
	t = await _wait(func(): return p.hp < hp0, 60)
	_check(t >= 0 and absf(float(t) / 60.0 - Badger.BITE_WINDUP) < 0.1, "then it bites (after %.2f s)" % (float(t) / 60.0))
	# Hurt, it digs in and is gone: no kill.
	await _reset()
	d = _put("badger", Vector2(120, 0))
	await _frames(2)
	var kills: int = m.kills
	d.take_hit(d.max_hp * (1.0 - Badger.DIG_AT) + 0.5, Vector2.RIGHT, 0.0, false, Color.WHITE)
	t = await _wait(func(): return d.mode == "dig", 30)
	_check(t >= 0 and str(d._sprite().get("anim", "")) == "dig", "hurt to %d%% of its health a badger digs in" % roundi(Badger.DIG_AT * 100.0))
	var dug := [false, false]                # [it went, it got away]
	d.died.connect(func(e): dug[0] = true; dug[1] = e.fled)
	t = await _wait(func(): return dug[0], 90)
	await _frames(2)
	_check(t >= 0 and dug[1] and not is_instance_valid(d), "and is gone, got away")
	_check(m.kills == kills, "a badger that got away is nobody's kill")
	var heap := false
	for n in m.world.get_children():
		if n is Node2D and n.get_script() != null and str(n.get_script().resource_path).ends_with("sprite_once.gd"):
			heap = true
	_check(heap, "a heap of soil is left where it went down")
	# Finished while it digs, it is a kill.
	await _reset()
	d = _put("badger", Vector2(120, 0))
	await _frames(2)
	kills = m.kills
	d.take_hit(d.max_hp * (1.0 - Badger.DIG_AT) + 0.5, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _wait(func(): return d.mode == "dig", 30)
	d.take_hit(999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(3)
	_check(m.kills == kills + 1, "a badger finished while it digs is a kill")


func _caper() -> void:
	await _reset()
	var c = _put("capercaillie", Vector2(90, 0))
	await _frames(2)
	_check(c.max_hp == Caper.HP and c.timid and not c._sprite().is_empty(), "a capercaillie has its health, is timid, and is drawn from its pictures")
	var hp0: float = p.hp
	var t := await _wait(func(): return c.global_position.distance_to(p.global_position) >= Caper.SAFE - 4.0, 400)
	_check(t >= 0, "a capercaillie runs off until nobody is near (%.1f s)" % (float(t) / 60.0))
	_check(str(c._sprite().get("anim", "")) in ["flee", "idle", "hit"], "running, it flaps")
	# Chase it about: it never fights.
	for f in 300:
		p.input.move = (c.global_position - p.global_position).normalized()
		await physics_frame
	p.input.move = Vector2.ZERO
	_check(p.hp == hp0, "chased about for five seconds it never hurts you")
	_check(c.mode in ["flee", "wary"], "it keeps running")


# --- On the land -----------------------------------------------------------------------------

func _game(seed_value: int):
	var g = Highlands.new()
	g.inputs = [PlayerInput.make("script")]
	g.world_seed = seed_value
	g.welcome = false
	root.add_child(g)
	return g


## The nearest group of one kind of creature to a place.
func _nearest(foes, from: Vector2, kind: String) -> Dictionary:
	var best := {}
	var best_d := INF
	for gr in foes.plan:
		if str(gr["what"]) != "creatures" or str(gr["members"][0][0]) != kind:
			continue
		var d: float = ((gr["home"] as Vector2) * TILE).distance_to(from)
		if d < best_d:
			best_d = d
			best = gr
	return best


func _go_to(g, at: Vector2) -> void:
	var tile: Vector2i = g.foes.nav.nearest_free(Nav.tile_of(at), 8)
	g.player.global_position = Nav.middle_of(tile) if tile.x >= 0 else at
	g.player.reset_physics_interpolation()
	g.rig.snap()


func _land() -> void:
	var g = _game(424242)
	await _frames(3)
	var q = g.player
	q.unhurt = true
	var foes = g.foes
	for kind in Make.CREATURES:
		var gr := _nearest(foes, q.global_position, kind)
		_check(not gr.is_empty(), "there are %ss on the land" % kind)
		if gr.is_empty():
			continue
		var home: Vector2 = (gr["home"] as Vector2) * TILE
		_go_to(g, home + Vector2(0, 600))
		await _wait(func(): return foes.packs.has(int(gr["id"])), 600)
		await _frames(10)
		var pack = foes.packs.get(int(gr["id"]))
		_check(pack != null and pack.neutral, "a group of %ss is on the land as you come, neutral" % kind)
		if pack == null:
			continue
		# Walk right up to them: nothing.
		_go_to(g, pack.members[0].global_position + Vector2(40, 0))
		var at0: Array = pack.members.map(func(e): return e.global_position)
		await _frames(300)
		_check(not pack.alert, "%s: standing right beside them, nothing wakes" % kind)
		var moved := false
		var near_home := true
		for k in pack.members.size():
			var e = pack.members[k]
			if e.global_position.distance_to(at0[k]) > 8.0:
				moved = true
			if e.global_position.distance_to(e.home) > Creature.WANDER * TILE + 48.0:
				near_home = false
		_check(moved, "%s: calm, they amble about" % kind)
		_check(near_home, "%s: and keep near home" % kind)
		# A blow wakes the whole group.
		var hit = pack.members[0]
		hit.take_hit(1.0, (hit.global_position - q.global_position).normalized(), 0.0, false, Color.WHITE)
		_check(pack.alert, "%s: a blow wakes the group" % kind)
		await _frames(20)
		_check(pack.living().all(func(e): return not (e.mode in ["idle", "amble", "display"])), "%s: and all of them answer it" % kind)
		# Travel: a running flock does not stop a waystone; a boar after you does.
		if kind == "capercaillie":
			_check(not pack.hunting() and not g.folk.cannot_travel().contains("enemies"), "running capercaillies are not after you: a waystone still works")
		elif kind == "boar":
			_check(pack.hunting() and g.folk.cannot_travel().contains("enemies"), "a boar is after you: no waystone while it is")
		# Leave them alone, out of reach: they settle, and are whole again.
		_go_to(g, home + Vector2(0, 700))
		var t := await _wait(func(): return not pack.alert, int((Creature.SETTLE + 6.0) * 60.0))
		_check(t >= 0, "%s: left alone a while, they settle (%.1f s)" % [kind, float(t) / 60.0])
		await _frames(120)
		_check(not is_instance_valid(hit) or hit.hp == hit.max_hp, "%s: and are whole again" % kind)
	# What a kill leaves: the creature's Memory.
	var gr := _nearest(foes, q.global_position, "boar")
	if not gr.is_empty():
		var pack = foes.packs.get(int(gr["id"]))
		if pack != null and not pack.living().is_empty():
			_go_to(g, pack.living()[0].global_position + Vector2(60, 0))
			await _frames(5)
			var before: int = g.loot.purses[0].memory
			pack.living()[0].take_hit(9999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
			await _frames(5)
			_check(g.loot.purses[0].memory - before == int(Loot.MEMORY_FOR["boar"]), "a boar is worth %d Memory (%d)" % [int(Loot.MEMORY_FOR["boar"]), g.loot.purses[0].memory - before])
	gr = _nearest(foes, q.global_position, "badger")
	if not gr.is_empty():
		_go_to(g, (gr["home"] as Vector2) * TILE + Vector2(0, 500))
		await _wait(func(): return foes.packs.has(int(gr["id"])), 600)
		await _frames(10)
		var pack = foes.packs.get(int(gr["id"]))
		if pack != null and not pack.living().is_empty():
			var d = pack.living()[0]
			_go_to(g, d.global_position + Vector2(60, 0))
			await _frames(5)
			var before: int = g.loot.purses[0].memory
			var went := [false]
			d.died.connect(func(_e): went[0] = true)
			d.take_hit(d.max_hp * (1.0 - Badger.DIG_AT) + 0.5, Vector2.RIGHT, 0.0, false, Color.WHITE)
			await _wait(func(): return went[0], 120)
			await _frames(5)
			_check(g.loot.purses[0].memory == before and foes.fallen.has(int(gr["id"])), "a badger that digs away leaves no Memory, and is back later like the rest")
	# A long scrap with every kind awake: nobody ends up in the rock, and the game keeps its pace.
	var in_rock := 0
	var ticks := 0
	var t0 := Time.get_ticks_usec()
	for kind in Make.CREATURES:
		var g2 := _nearest(foes, q.global_position, kind)
		if g2.is_empty():
			continue
		_go_to(g, (g2["home"] as Vector2) * TILE + Vector2(0, 120))
		await _wait(func(): return foes.packs.has(int(g2["id"])), 600)
		await _frames(10)
		var pack = foes.packs.get(int(g2["id"]))
		if pack == null or pack.living().is_empty():
			continue
		pack.living()[0].take_hit(1.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
		var walks := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
		for f in 480:
			q.input.move = walks[(f / 60) % 4] if (f / 60) % 3 != 2 else Vector2.ZERO
			await physics_frame
			ticks += 1
			if f % 20 == 0:
				for e in pack.living():
					if not foes.nav.map.walkable(Nav.tile_of(e.global_position).x, Nav.tile_of(e.global_position).y):
						in_rock += 1
		q.input.move = Vector2.ZERO
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(maxi(ticks, 1))
	_check(in_rock == 0, "in long scraps no creature ends up in the rock (%d times)" % in_rock)
	print("      long scraps with the creatures: %.2f ms a tick" % ms)
	g.queue_free()
	await _frames(3)


# --- Pictures --------------------------------------------------------------------------------

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png("%s/%s.png" % [shot_dir, name])
	print("saved %s/%s.png" % [shot_dir, name])


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var g = _game(424242)
	await _frames(3)
	var q = g.player
	q.unhurt = true
	var foes = g.foes
	if only == "dogs":
		await _dog_shots(g)
		g.queue_free()
		await _frames(3)
		return
	var n := 1
	for kind in Make.CREATURES:
		var gr := _nearest(foes, q.global_position, kind)
		if gr.is_empty():
			continue
		var home: Vector2 = (gr["home"] as Vector2) * TILE
		_go_to(g, home + Vector2(0, 400))
		await _wait(func(): return foes.packs.has(int(gr["id"])), 600)
		await _frames(10)
		var pack = foes.packs.get(int(gr["id"]))
		if pack == null or pack.living().is_empty():
			continue
		_go_to(g, pack.living()[0].global_position + Vector2(-190, 24))
		await _frames(4)
		g.land.settle()
		await _frames(150)
		await _snap("%02d_%s_calm" % [n, kind])
		n += 1
		var e = pack.living()[0]
		e.take_hit(1.0, (e.global_position - q.global_position).normalized(), 0.0, false, Color.WHITE)
		match kind:
			"boar":
				_go_to(g, e.global_position + Vector2(180, 10))      # (out in the open, beside it)
				await _wait(func(): return e.mode == "windup", 300)
				await _frames(12)
				await _snap("%02d_boar_paws_the_ground" % n)
			"badger":
				await _wait(func(): return e.mode == "jaw", 300)
				await _frames(4)
				await _snap("%02d_badger_opens_its_jaw" % n)
				n += 1
				e.take_hit(e.max_hp * (1.0 - Badger.DIG_AT) + 0.5, Vector2.RIGHT, 0.0, false, Color.WHITE)
				await _frames(int(Badger.DIG_TIME * 60.0) + 8)
				await _snap("%02d_badger_dug_in" % n)
			_:
				await _frames(40)
				await _snap("%02d_capercaillies_run_off" % n)
		n += 1
		_go_to(g, home + Vector2(0, 900))
		await _frames(30)
	# The whole map, the Roost seen, with its smoke.
	g.charts.explored.fill(255)
	g.charts._seen_dirty = true
	g.charts.open()
	await _frames(20)
	await _snap("%02d_the_whole_map_roost_seen" % n)
	g.charts.close()
	g.queue_free()
	await _frames(3)


## The goblins' war dogs (version 64): a goblin group round the Scrapyard that keeps them, and the wild hounds' look
## beside theirs.
func _dog_shots(g) -> void:
	var foes = g.foes
	var q = g.player
	var best := {}
	var bd := INF
	for gr in foes.plan:
		var dogs: int = (gr["members"] as Array).filter(func(mm): return str(mm[0]) == "scrap_hound").size()
		if dogs < 1 or str(gr["site"]) != "":
			continue
		var d: float = ((gr["home"] as Vector2) * TILE).distance_to(q.global_position) - float(dogs) * 400.0
		if d < bd:
			bd = d
			best = gr
	if best.is_empty():
		return
	var home: Vector2 = (best["home"] as Vector2) * TILE
	foes.on = true
	_go_to(g, home + Vector2(0, 300))
	await _wait(func(): return foes.packs.has(int(best["id"])), 600)
	var pack = foes.packs.get(int(best["id"]))
	if pack == null:
		return
	_go_to(g, pack.members[0].global_position + Vector2(-260, 40))
	await _frames(4)
	g.land.settle()
	await _frames(24)
	await _snap("01_goblins_with_their_war_dogs")
	await _frames(70)
	await _snap("02_the_war_dogs_come_round")
