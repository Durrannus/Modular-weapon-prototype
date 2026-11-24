extends SceneTree
## Rattlecrown: his Scrapyard (its gate, rooms and barred doors), the Throne Room, the horn, the fight and what it
## gives (versions 48 and 49). Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands_crown.gd
##
## With shots=/some/folder/ (needs a window, so leave out --headless) it saves 640x360 frames instead.
## "seed=123456" picks the world. "only=plans" runs one part.

const PlayerInput := preload("res://scripts/player_input.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const CrownPlan := preload("res://scripts/highlands/crown_plan.gd")
const Crown := preload("res://scripts/highlands/crown.gd")
const Rattlecrown := preload("res://scripts/foes/rattlecrown.gd")
const Scrap := preload("res://scripts/foes/scrap.gd")
const Make := preload("res://scripts/foes/make.gd")
const Hound := preload("res://scripts/foes/hound.gd")
const Folk := preload("res://scripts/highlands/folk.gd")
const Loot := preload("res://scripts/highlands/loot.gd")
const Shop := preload("res://scripts/ui/shop.gd")
const Save := preload("res://scripts/save.gd")
const Nav := preload("res://scripts/highlands/nav.gd")
const Sim := preload("res://scripts/sim.gd")
const Art := preload("res://scripts/art.gd")
const TILE := 32.0
const ROOT := "user://test_crown_saves"
const SEEDS := [424242, 515151, 123456, 777777, 31337, 202611]

var fails := 0
var checks := 0
var shot_dir := ""
var shot_seed := 424242
var only := ""


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shot_dir = a.substr(6)
		elif a.begins_with("seed="):
			shot_seed = int(a.substr(5))
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


func _wait(until: Callable, most: int) -> int:
	for i in most:
		if until.call():
			return i
		await physics_frame
	return -1


func _run() -> void:
	await physics_frame
	Painter.load_kit()
	if shot_dir != "":
		await _shots()
		quit(0)
		return
	if only == "" or only == "art":
		_art()
	if only == "" or only == "plans":
		_plans()
	if only == "" or only == "gate":
		await _gate()
	if only == "" or only == "yard":
		await _yard()
	if only == "" or only == "fight":
		await _fight()
	if only == "" or only == "two":
		await _two_players()
	if only == "" or only == "saved":
		await _saved()
	print("%s  Rattlecrown: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func _game(seed_value: int, players := 1, foes := false, characters: Array = [], world := {}):
	var g = Highlands.new()
	var inputs: Array = []
	for i in players:
		inputs.append(PlayerInput.make("script"))
	g.inputs = inputs
	g.characters = characters
	g.world_save = world
	g.world_seed = seed_value
	g.with_foes = foes
	g.welcome = false
	root.add_child(g)
	return g


func _leave(g) -> void:
	if g.hall != null and g.hall.is_open:
		g.hall.close()
	if g.folk != null and g.folk.shop.is_open:
		g.folk.shop.close()
	paused = false
	g.queue_free()
	await _frames(3)


func _press(p, field: String) -> void:
	await physics_frame               # (so that the press lasts exactly one tick, wherever in a frame this is called)
	p.input.set(field, true)
	await physics_frame
	p.input.set(field, false)
	await physics_frame


func _put(g, p, at: Vector2) -> void:
	p.global_position = at
	p.velocity = Vector2.ZERO
	p.input.move = Vector2.ZERO
	g.rig.snap()


func _quest(folk, id: String) -> Dictionary:
	for q in folk.quests():
		if str(q["id"]) == id:
			return q
	return {}


func _prompt(g, text: String) -> bool:
	return (g.ui.prompts as Array).any(func(pr): return str(pr["text"]) == text)


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 640:
		img.resize(640, 360, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [shot_dir, name])
	print("saved %s/%s.png" % [shot_dir, name])


## Frames while the game stands still (a screen is up): the pictures still have to be drawn.
func _idle(n: int) -> void:
	for i in n:
		await process_frame


## Everybody of the three elites, and whatever came to the howl, falls.
func _fell_court(crown) -> void:
	for e in crown.court.members.duplicate() + crown.elites.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)


# --- Pictures ----------------------------------------------------------------------------------

func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var g = _game(shot_seed, 1, false)
	await _frames(10)
	var crown = g.crown
	var folk = g.folk
	var p = g.players[0]
	p.unhurt = true
	folk.pip = 3
	folk._show()
	g.land.settle()
	# The way in.
	_put(g, p, crown.mouth())
	g.land.settle()
	await _frames(40)
	await _snap("01_the_mouth_of_the_way_in")
	_put(g, p, crown.gate_feet() + Vector2(0, 150))
	g.land.settle()
	await _frames(40)
	await _snap("02_the_way_up_to_the_gate")
	_put(g, p, crown.gate_feet() + Vector2(0, 34))
	await _frames(20)
	await _snap("03_the_gate_shut")
	await _press(p, "interact_pressed")
	await _frames(10)
	await _snap("04_it_wants_the_horn")
	crown.horn = true
	await _frames(100)
	await _snap("05_with_the_horn")
	await _press(p, "interact_pressed")
	await _frames(12)
	await _snap("06_the_gate_opening")
	await _frames(60)
	await _snap("07_the_gate_open")
	_put(g, p, crown.gate_feet() + Vector2(0, -90))
	await _frames(20)
	await _snap("08_into_the_gatehouse")
	# The row of spike traps just inside it.
	var row: Vector2 = (Vector2(crown.plan["trap_row"]) + Vector2(0.5, 0.5)) * TILE
	_put(g, p, row + Vector2(0, 44))
	await _frames(20)
	await _snap("08a_spike_traps_inside_the_throne_room_door")
	_put(g, p, row + Vector2(0, -8))
	await _frames(22)
	await _snap("08b_a_trap_rattles")
	await _frames(22)
	await _snap("08c_the_spikes_come_up")
	# (Stepped off it, to see the spikes standing.)
	_put(g, p, row + Vector2(-40, 44))
	await _frames(8)
	await _snap("08d_the_spikes_standing")
	# The room.
	_put(g, p, crown.room_rect().get_center() + Vector2(0, 300))
	g.land.settle()
	await _frames(100)
	await _snap("09_the_throne_room_from_the_door")
	_put(g, p, crown.blow_spot() + Vector2(0, 110))
	g.land.settle()
	await _frames(40)
	await _snap("09a_the_throne_room")
	_put(g, p, crown.bars_feet() + Vector2(-40, 70))
	g.land.settle()
	await _frames(40)
	await _snap("09b_his_hoard_behind_bars")
	_put(g, p, crown.blow_spot() + Vector2(0, 10))
	p.input.stick_aim = Vector2.UP
	await _frames(240)
	await _snap("10_before_the_throne")
	await _press(p, "interact_pressed")
	await _frames(30)
	await _snap("11_he_points")
	await _wait(func(): return crown.stage == "elites", 200)
	await _frames(30)
	await _snap("12_the_three_elites")
	await _frames(120)
	await _snap("13_phase_one")
	_fell_court(crown)
	await _frames(12)
	await _snap("14_he_kicks_the_throne_apart")
	await _wait(func(): return crown.stage == "foot", 200)
	await _frames(20)
	await _snap("15_on_his_feet")
	var boss = crown.boss
	await _wait(func(): return boss.mode == "slam_windup", 600)
	await _frames(30)
	await _snap("16_club_slam_the_ring")
	await _wait(func(): return boss.mode == "slam", 200)
	await _frames(8)
	await _snap("17_club_slam_lands")
	_put(g, p, crown.blow_spot() + Vector2(-220, 90))
	await _wait(func(): return boss.mode == "toss_windup", 900)
	await _frames(20)
	await _snap("18_scrap_toss_the_ring")
	await _wait(func(): return boss.mode == "toss", 200)
	await _frames(22)
	await _snap("19_scrap_in_the_air")
	await _wait(func(): return boss.mode == "charge_windup", 900)
	await _frames(30)
	await _snap("20_charge_the_lane")
	await _wait(func(): return boss.mode == "charge", 200)
	await _frames(8)
	await _snap("21_charge")
	boss.hp = boss.max_hp * 0.45
	await _wait(func(): return boss.mode == "crown_on", 900)
	await _frames(24)
	await _snap("22_the_crown_goes_on")
	await _wait(func(): return boss.crowned and boss.mode == "toss_windup" and not boss.first_go, 2400)
	await _frames(14)
	await _snap("23_crowned_two_rings")
	await _wait(func(): return boss.mode == "slam_windup" and not boss.first_go, 2400)
	await _frames(20)
	await _snap("24_crowned_the_second_slam")
	boss.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(20)
	await _snap("25_he_falls")
	p.unhurt = false
	_put(g, p, crown.bars_feet() + Vector2(-40, 70))
	g.land.settle()
	await _frames(50)
	await _snap("26_the_bars_of_his_hoard_are_up")
	_put(g, p, crown.bars_feet() + Vector2(0, 12))
	p.input.stick_aim = Vector2.UP
	await _frames(20)
	await _snap("27_at_his_hoard")
	await _press(p, "interact_pressed")
	await _frames(24)
	await _snap("28_the_hoard_opened")
	await _wait(func(): return g.ui.busy(), 400)
	await _idle(20)
	await _frames(20)
	await _snap("29_what_it_held")
	await _leave(g)
	# The Scrapyard's rooms, with who lives in them (version 49).
	g = _game(shot_seed, 1, true)
	await _frames(10)
	crown = g.crown
	p = g.players[0]
	p.unhurt = true
	crown.gate_open = true
	crown._show(true)
	var foes = g.foes
	var groups := {}
	for i in foes.plan.size():
		if (foes.plan[i] as Dictionary).has("room"):
			groups[str(foes.plan[i]["room"])] = i
		elif str(foes.plan[i].get("site", "")) == "scrapyard":
			foes.quiet[i] = true
	_put(g, p, crown.mouth() + Vector2(0, 40))
	g.land.settle()
	await _frames(40)
	await _snap("30_the_ground_in_front_of_the_gate")
	var gh := _room_rect(crown, "gatehouse")
	_put(g, p, Vector2(gh.get_center().x, gh.end.y - 40.0))
	g.land.settle()
	await _frames(50)
	await _snap("31_the_gatehouse_its_hounds_and_handler")
	_put(g, p, Vector2(gh.get_center().x, gh.position.y + 70.0))
	await _frames(20)
	await _snap("32_its_far_door_barred")
	_beat(foes.packs[groups["gatehouse"]])
	await _frames(60)
	await _snap("33_beaten_the_bars_go_up")
	var la := _room_rect(crown, "link_a")
	_put(g, p, la.get_center())
	g.land.settle()
	await _frames(30)
	await _snap("34_a_linking_room_and_a_side_room")
	var sa := _room_rect(crown, "side_a")
	_put(g, p, sa.get_center())
	await _frames(30)
	await _snap("35_a_side_room_and_its_chest")
	var cy := _room_rect(crown, "crane")
	_put(g, p, Vector2(cy.get_center().x, cy.end.y - 40.0))
	g.land.settle()
	await _frames(50)
	await _snap("36_the_crane_yard_slingers_behind_scrap")
	_beat(foes.packs[groups["crane"]])
	var fu := _room_rect(crown, "furnace")
	_put(g, p, Vector2(fu.get_center().x, fu.end.y - 40.0))
	g.land.settle()
	await _frames(50)
	await _snap("37_the_furnace_two_shamans_ward_two_brutes")
	_beat(foes.packs[groups["furnace"]])
	await _frames(60)
	_put(g, p, Vector2(fu.get_center().x, fu.position.y + 60.0))
	await _frames(20)
	await _snap("38_up_to_the_throne_room")
	await _leave(g)


# --- The Throne Room, the way in and the gate, on many lands -----------------------------------

func _plans() -> void:
	var slowest := 0.0
	var ways := {}
	for k in 24:
		var seed_value: int = SEEDS[k] if k < SEEDS.size() else 9000 + k * 7919
		var map: LandMap = WorldGen.make(seed_value)
		var from := Vector2i(floori(map.spawn.x), floori(map.spawn.y))
		var before := map.reach(from)
		var t0 := Time.get_ticks_usec()
		var plan := CrownPlan.make(map)
		slowest = maxf(slowest, float(Time.get_ticks_usec() - t0) / 1000.0)
		_check(bool(plan.get("ok", false)), "seed %d: the land has its Scrapyard" % seed_value)
		if not bool(plan.get("ok", false)):
			continue
		var again := CrownPlan.make(map)
		_check(str(again) == str(plan), "seed %d: the same land gives the same plan" % seed_value)
		var yard: Rect2i = plan["yard"]
		var rooms: Dictionary = plan["rooms"]
		var room: Rect2i = plan["room"]
		var gate: Vector2i = plan["gate"]
		var door: Vector2i = plan["door"]
		var meet: Vector2i = plan["meet"]
		ways[str(plan["compass"])] = int(ways.get(str(plan["compass"]), 0)) + 1
		# Before anything is cut: the whole block is solid rock, in the outer ring, inside the land that is laid out.
		var solid := true
		for y in range(yard.position.y, yard.end.y):
			for x in range(yard.position.x, yard.end.x):
				if not LandMap.rocky(map.kind(x, y)):
					solid = false
		_check(solid, "seed %d: the Scrapyard's block is solid rock before it is cut" % seed_value)
		var cave := Vector2(LandMap.MID, LandMap.MID)
		var near := INF
		for c in [yard.position, Vector2i(yard.end.x, yard.position.y), Vector2i(yard.position.x, yard.end.y), yard.end]:
			near = minf(near, Vector2(c).distance_to(cave))
		var middle := Vector2(yard.get_center()).distance_to(cave)
		_check(near >= WorldGen.RINGS[2] and middle <= WorldGen.RINGS[3] and map.region.grow(-4).encloses(yard), "seed %d: in the outer ring (%.0f tiles from the cave at its nearest, %.0f to its middle)" % [seed_value, near, middle])
		# The rooms: inside the block, walls between them, the Throne Room at the top and the Gatehouse at the bottom.
		var inside := true
		var apart := true
		var names: Array = rooms.keys()
		for a in names.size():
			var ra: Rect2i = rooms[names[a]]
			inside = inside and yard.grow(-2).encloses(ra)
			for b in range(a + 1, names.size()):
				apart = apart and not ra.grow(CrownPlan.WALL - 1).intersects(rooms[names[b]])
		_check(names.size() == 9 and inside and apart, "seed %d: its nine rooms are inside the block, with rock between every two" % seed_value)
		_check(room == rooms["room"] and room.position.y < (rooms["furnace"] as Rect2i).position.y and (rooms["furnace"] as Rect2i).position.y < (rooms["crane"] as Rect2i).position.y and (rooms["crane"] as Rect2i).position.y < (rooms["gatehouse"] as Rect2i).position.y, "seed %d: from the gate up: the Gatehouse, the Crane Yard, the Furnace and the Throne Room" % seed_value)
		var sizes := [[rooms["gatehouse"], Vector2i(24, 12)], [rooms["crane"], Vector2i(28, 15)], [rooms["furnace"], Vector2i(22, 12)], [room, CrownPlan.ROOM]]
		_check(sizes.all(func(s): return (s[0] as Rect2i).size == s[1]), "seed %d: each the size of its still (the Gatehouse 24 by 12, the Crane Yard 28 by 15, the Furnace 22 by 12, the Throne Room %d by %d)" % [seed_value, CrownPlan.ROOM.x, CrownPlan.ROOM.y])
		_check(gate.y == (rooms["gatehouse"] as Rect2i).end.y and gate.x == door.x and door.y == room.end.y, "seed %d: the Scrapyard gate is in the block's bottom wall, under the Gatehouse; the Throne Room has its own gate in its door" % seed_value)
		_check(map.reached(before, meet.x, meet.y) and meet.y > yard.end.y and absi(meet.x - gate.x) <= 2, "seed %d: the ground in front of the gate can be walked to from the cave" % seed_value)
		# Cut it.
		var things_before := map.things.size()
		var cut := CrownPlan.stamp(map, plan)
		var room_tiles := 0
		for name in rooms:
			room_tiles += (rooms[name] as Rect2i).get_area()
		_check(cut >= room_tiles, "seed %d: the rooms and their doors are cut (%d tiles of rock)" % [seed_value, cut])
		_check(map.dug.is_empty() and map.added.is_empty() and map.gone.is_empty(), "seed %d: and none of it is a change a save would hold" % seed_value)
		_check(map.things.size() == things_before + (plan["lamps"] as Array).size(), "seed %d: the linking rooms' lanterns stand" % seed_value)
		var after := map.reach(from)
		var throne: Vector2 = plan["throne"]
		var tx := int(throne.x / 16.0)
		var ty := int(throne.y / 16.0) + 2
		var every := true
		for name in rooms:
			var c: Vector2i = (rooms[name] as Rect2i).get_center()
			every = every and map.reached(after, c.x, c.y)
		_check(every and map.reached(after, tx, ty) and map.reached(after, gate.x, yard.end.y), "seed %d: you can walk from the cave through the gate into every room, and to the foot of the throne" % seed_value)
		# Shut a door (its three tiles) and nobody gets past it: the gate, each barred door, the Throne Room's gate.
		var shut_ok := true
		var tests := [[gate, "gatehouse", ""]]
		for b in plan["bars"]:
			var above := ""
			for s in CrownPlan.STACK.size():
				if str(CrownPlan.STACK[s][0]) == str(b["room"]):
					above = str(CrownPlan.STACK[s - 1][0])
			tests.append([b["tile"], above, str(b["room"])])
		tests.append([door, "room", "furnace"])
		for t in tests:
			var at: Vector2i = t[0]
			for dx in [-1, 0, 1]:
				map.set_kind(at.x + dx, at.y, LandMap.ROCK)
			var shut := map.reach(from)
			var beyond: Vector2i = (rooms[str(t[1])] as Rect2i).get_center()
			if map.reached(shut, beyond.x, beyond.y):
				shut_ok = false
			if str(t[2]) != "":
				var here: Vector2i = (rooms[str(t[2])] as Rect2i).get_center()
				if not map.reached(shut, here.x, here.y):
					shut_ok = false
			for dx in [-1, 0, 1]:
				map.set_kind(at.x + dx, at.y, LandMap.FLOOR)
		_check(shut_ok and (plan["bars"] as Array).map(func(b): return str(b["room"])) == CrownPlan.BARRED, "seed %d: each door is the only way on: the gate, the Gatehouse's, the Crane Yard's and the Furnace's far doors, and the Throne Room's gate" % seed_value)
		# Who lives there, and the side rooms' chests.
		var groups: Array = plan["groups"]
		var homes := groups.all(func(g): return rooms.has(str(g["room"])) and (rooms[str(g["room"])] as Rect2i).has_point(Vector2i(g["home"])) and int(g["pocket"]) == -1)
		var handler := (groups[0]["members"] as Array).filter(func(m): return m.size() > 2 and str(m[2]) == "handler").size()
		var furnace: Array = groups.filter(func(g): return str(g["room"]) == "furnace")
		var kinds: Array = (furnace[0]["members"] as Array).map(func(m): return str(m[0])) if furnace.size() == 1 else []
		_check(groups.size() == 5 and homes and handler == 1 and kinds == ["shaman", "shaman", "scrap_brute", "scrap_brute"], "seed %d: a group in each of the five rooms that fight (the Gatehouse's with its handler, the Furnace's two Shamans and two Brutes)" % seed_value)
		var chests: Array = plan["chests"]
		var ids := {}
		var placed := true
		for c in chests:
			ids[int(c["id"])] = true
			var t: Vector2i = c["tile"]
			placed = placed and int(c["id"]) >= CrownPlan.CHEST_ID and ((rooms["side_a"] as Rect2i).has_point(t) or (rooms["side_b"] as Rect2i).has_point(t)) and map.reached(after, t.x, t.y)
		_check(chests.size() == 2 and ids.size() == 2 and placed, "seed %d: a chest at the back of each side room, each with its own number" % seed_value)
		# The traps lie on the room's floor, clear of where anything stands; the hoard's alcove is in the back wall.
		var traps: Array = plan["traps"]
		var stood := {}
		for spot in plan["spots"]:
			stood[spot] = true
		for d in plan["dress"]:
			for t in CrownPlan.tiles_under(d[1], d[2]):
				stood[t] = true
		for t in CrownPlan.tiles_under(plan["throne"], plan["throne_solid"]):
			stood[t] = true
		stood[Vector2i(int((plan["blow"] as Vector2).x / 16.0), int((plan["blow"] as Vector2).y / 16.0))] = true
		_check(traps.all(func(t): return room.has_point(t) and not stood.has(t)) and traps.has(plan["trap_row"]), "seed %d: the %d spike traps lie on the Throne Room's floor, clear of the throne, the braziers and where anyone is put" % [seed_value, traps.size()])
		var alcove: Rect2i = plan["alcove"]
		var hoard: Vector2 = plan["hoard"]
		# The scrap piles stand round the arena against its walls (the sides and the front: the back has the stand
		# since version 50), apart from each other, clear of the door, the hoard's mouth, the throne and where anyone
		# is put.
		var piled := {}
		var piles := 0
		var walls := {}
		var against := true
		var heaps_apart := true
		for d in plan["dress"]:
			if not str(d[0]).begins_with("scrap_"):
				continue
			var tiles: Array = CrownPlan.tiles_under(d[1], d[2])
			if not room.has_point(tiles[0]):
				continue                # (the other rooms' piles)
			piles += 1
			for t: Vector2i in tiles:
				if piled.has(t):
					heaps_apart = false
				piled[t] = true
				var gaps := [t.y - room.position.y, room.end.x - 1 - t.x, room.end.y - 1 - t.y, t.x - room.position.x]
				var least: int = gaps.min()
				walls[gaps.find(least)] = true
				if not room.has_point(t) or least > 2:
					against = false
		_check(piles >= 8 and walls.has(1) and walls.has(2) and walls.has(3) and against and heaps_apart, "seed %d: %d scrap piles stand round the arena, against both sides and the front, and apart from each other" % [seed_value, piles])
		var in_the_way := 0
		for dx in range(-3, 4):
			for dy in [1, 2, 3]:
				in_the_way += int(piled.has(Vector2i(door.x + dx, room.end.y - dy)))
		for x in range(alcove.position.x - 1, alcove.end.x + 1):
			for dy in [0, 1, 2]:
				in_the_way += int(piled.has(Vector2i(x, room.position.y + dy)))
		for spot in plan["spots"]:
			in_the_way += int(piled.has(spot))
		for t in CrownPlan.tiles_under(plan["throne"], plan["throne_solid"]):
			in_the_way += int(piled.has(t))
		for d in plan["dress"]:
			if str(d[0]) == "brazier":
				for t in CrownPlan.tiles_under(d[1], d[2]):
					in_the_way += int(piled.has(t))
		_check(in_the_way == 0, "seed %d: none of them in the door, before the hoard, on the throne, on a brazier or where an elite comes in" % seed_value)
		# The Crane Yard's piles stand out in the yard, clear of the way through it, for its slingers to hide behind.
		var crane: Rect2i = rooms["crane"]
		var yard_piles := 0
		var clear_way := true
		for c in plan["cover"]:
			var t := Vector2i(floori((c[0] as Vector2).x / 16.0), floori((c[0] as Vector2).y / 16.0))
			yard_piles += int(crane.has_point(t))
			clear_way = clear_way and absi(t.x - door.x) > 2
		_check(yard_piles >= 4 and clear_way, "seed %d: %d scrap piles out in the Crane Yard, clear of the way through it" % [seed_value, yard_piles])
		_check(alcove.end.y == room.position.y and alcove.position.x > tx + 4 and alcove.end.x < room.end.x - 2, "seed %d: the hoard's alcove is in the back wall, to the right of the throne" % seed_value)
		_check(alcove.has_point(Vector2i(floori(hoard.x / 16.0), floori((hoard.y - 1.0) / 16.0))) and map.kind(alcove.position.x, alcove.position.y) == LandMap.FLOOR and map.reached(after, alcove.position.x + 1, alcove.position.y), "seed %d: with the chest standing in it" % seed_value)
		# Since version 50: the goblins' stands round the arena, the crowd on them, and the room's floor painted in.
		var stands: Array = plan["stands"]
		var stands_ok := stands.size() == 4
		for r: Rect2i in stands:
			stands_ok = stands_ok and not r.intersects(room) and not r.intersects(alcove) and r.grow(1).intersects(room)
			for sy in range(r.position.y, r.end.y):
				for sx in range(r.position.x, r.end.x):
					stands_ok = stands_ok and map.kind(sx, sy) == LandMap.FLOOR
		_check(stands_ok, "seed %d: the goblins' stands run along the back and both sides of the arena, outside it and clear of the hoard's alcove" % seed_value)
		var crowd := 0
		var on_stands := true
		for d in plan["scenery"]:
			if str(d[0]).begins_with("goblin_"):
				crowd += 1
				var f: Vector2 = d[1]
				var ft := Vector2i(floori(f.x / 16.0), floori((f.y - 1.0) / 16.0))
				on_stands = on_stands and stands.any(func(r): return (r as Rect2i).has_point(ft))
		_check(crowd >= 24 and on_stands, "seed %d: %d goblins watch from the stands" % [seed_value, crowd])
		var pieces: Array = Art.json("scrapyard/throne_floor.json").get("pieces", [])
		var painted := Rect2i(room.position * 16, room.size * 16).grow(16 * 8)
		var decals_ok := pieces.size() > 0 and map.floor_decals.size() == pieces.size()
		for d in map.floor_decals:
			decals_ok = decals_ok and painted.has_point(Vector2i(int(d["x"]), int(d["y"]))) and int((d["rect"] as Array)[2]) <= LandMap.CHUNK * 16
		_check(decals_ok, "seed %d: the Throne Room's floor is painted into the land there, in %d pieces" % [seed_value, pieces.size()])
		if k == 0:
			# The painter really paints it: a trap's tile with the floor's pieces and without them.
			var trap: Vector2i = plan["trap_row"]
			var cx := floori(trap.x / float(LandMap.CHUNK))
			var cy := floori(trap.y / float(LandMap.CHUNK))
			var px := Vector2i(trap.x * 16 - cx * LandMap.CHUNK * 16 + 8, trap.y * 16 - cy * LandMap.CHUNK * 16 + 8)
			var with_it: Image = Painter.paint(map, cx, cy)
			var keep: Array = map.floor_decals
			map.floor_decals = []
			map.index()
			var without: Image = Painter.paint(map, cx, cy)
			map.floor_decals = keep
			map.index()
			var differ := 0
			for dy in range(-6, 7):
				for dx in range(-6, 7):
					differ += int(with_it.get_pixel(px.x + dx, px.y + dy) != without.get_pixel(px.x + dx, px.y + dy))
			_check(differ > 40, "and the painter paints it: a trap's sunk slab differs from the plain dug floor (%d of 169 pixels)" % differ)
		# Nothing sealed was opened.
		var opened := 0
		for p in map.pockets:
			if bool(p.get("sealed", false)):
				var at: Vector2 = p["at"]
				if map.reached(after, floori(at.x), floori(at.y)):
					opened += 1
		_check(opened == 0, "seed %d: no sealed place was opened by it" % seed_value)
		# The rock of the whole block can never be dug (nobody digs round a barred door); the rest of the land can.
		var soft := 0
		for y in range(yard.position.y, yard.end.y):
			for x in range(yard.position.x, yard.end.x):
				if LandMap.rocky(map.kind(x, y)) and not map.fixed(x, y):
					soft += 1
		_check(soft == 0, "seed %d: none of the Scrapyard's rock can be dug (%d tiles can)" % [seed_value, soft])
		_check(not map.fixed(meet.x, meet.y) and not map.fixed(LandMap.MID + 30, LandMap.MID + 30), "seed %d: the rest of the land still can" % seed_value)
	print("      24 lands: the Scrapyard lies %s; the slowest plan took %.1f ms" % [str(ways), slowest])
	_check(slowest < 250.0, "the plan is made quickly (%.0f ms at the slowest)" % slowest)


const ROOM_TILES := CrownPlan.ROOM.x * CrownPlan.ROOM.y


# --- The pictures are there -----------------------------------------------------------------------

func _art() -> void:
	var book: Dictionary = Art.json("foes/rattlecrown.json")
	_check(Art.texture("foes/rattlecrown.png") != null and not book.is_empty(), "his sheet and its book are in the game")
	var his: Dictionary = book.get("enemies", {})
	for who in ["rattlecrown", "rattlecrown_crowned"]:
		var strips: Dictionary = his.get(who, {}).get("strips", {})
		var lacks: Array = []
		for name in ["idle", "move", "slam_windup", "slam", "toss_windup", "toss", "charge_windup", "charge", "hit", "death"]:
			if Scrap.strip_tex(strips.get(name, {}).get("box")) == null or int(strips[name].get("frames", 0)) < 1:
				lacks.append(name)
		_check(lacks.is_empty(), "%s has every strip the fight plays (lacks %s)" % [who, str(lacks)])
	_check(Scrap.strip_tex(his.get("rattlecrown", {}).get("strips", {}).get("crown_on", {}).get("box")) != null, "and the one where the crown goes on")
	var seat: Dictionary = his.get("throne", {}).get("strips", {})
	_check(["idle", "point", "kick", "wreck"].all(func(n): return Scrap.strip_tex(seat.get(n, {}).get("box")) != null), "the throne has him sitting, pointing, kicking it apart, and its wreck")
	_check(int(Scrap.shot("slam_mark").get("frames", 0)) >= 4 and int(Scrap.shot("scrap_mark").get("frames", 0)) >= 4 and not Scrap.shot("scrap").is_empty(), "the two rings on the floor (three pictures closing in and the blow) and the lump of scrap are there")
	_check(Scrap.reach_of("slam_mark", Vector2.ZERO).x >= 40.0 and Scrap.reach_of("scrap_mark", Vector2.ZERO).x >= 24.0 and Scrap.reach_of("slam_mark", Vector2.ZERO).x > Scrap.reach_of("scrap_mark", Vector2.ZERO).x, "the rings reach as far as they are drawn (the slam's %s, the scrap's %s)" % [str(Scrap.reach_of("slam_mark", Vector2.ZERO)), str(Scrap.reach_of("scrap_mark", Vector2.ZERO))])
	var yard: Dictionary = Art.json("scrapyard/scrapyard.json").get("sprites", {})
	_check(Art.texture("scrapyard/scrapyard.png") != null and ["gate_front_shut", "gate_front_opening", "gate_front_open", "brazier", "scrap_heap_large", "scrap_heap_small"].all(func(n): return (yard.get(n, {}) as Dictionary).has("box")), "the Scrapyard gate (shut, opening, open), the brazier and the two scrap piles are there")
	_check(Make.knows("rattlecrown") and not Make.knows("rattlecrown_elite"), "the game can make him, and there is no elite of him")


# --- The gate, the horn, Pip's mending and the spike traps ---------------------------------------

func _text_font() -> Font:
	return Art.font(Art.TEXT)


func _fits(g, line: String) -> bool:
	return 320.0 + (g.loot._head_width(line) + 12.0) * 0.5 <= g.folk.track_at().x - 2.0


func _gate() -> void:
	var g = _game(424242)
	await _frames(5)
	var crown = g.crown
	var folk = g.folk
	var p = g.players[0]
	var purse = g.loot.purses[0]
	var bag = g.tools.bag_of(0)
	var nav = g.foes.nav
	_check(crown != null and crown.ok(), "the game has his Throne Room")
	_check(crown.gate.anim == "shut" and not crown.gate_shape.disabled and crown.throne.anim == "idle", "the gate is shut, and he sits on his throne")
	var gt: Vector2i = crown.plan["gate"]
	_check(not nav.is_free(gt) and not nav.is_free(gt + Vector2i(-1, 0)) and not nav.is_free(gt + Vector2i(1, 0)), "no enemy finds a way through the shut gate")
	var want := CrownPlan.TRAP_ROW_WIDE
	for r: Rect2i in CrownPlan.TRAPS:
		want += r.size.x * r.size.y
	_check(crown.traps.size() == want and crown.traps.all(func(tr): return tr.state == "down"), "its %d spike traps lie in the floor, down" % want)
	var rim := 0
	var corners_kerbed := 0
	for tr in crown.traps:
		rim += int(tr.edges != 0)
		corners_kerbed += int(tr.edges in [3, 6, 12, 9])
	_check(rim > 0 and rim < want and corners_kerbed == 16 and crown.traps.any(func(tr): return tr.edges == 5), "a kerb runs round each patch of them and along the row inside the gate (%d of %d are on a rim)" % [rim, want])
	_check(not crown.bars.up and not crown.bars_shape.disabled and crown.chest.texture == crown._chest_tex("chest", 0) and crown.hoard == "", "his hoard's chest stands behind its bars")
	folk.pip = 3
	folk._show()
	var q := _quest(folk, "crown")
	_check(str(q.get("name", "")) == "The Scrap Crown" and str(q.get("text", "")).contains("0 of 3"), "the quest is The Scrap Crown: \"%s\"" % str(q.get("text", "")))
	_check(crown.sign_target() == Vector2.INF, "(it has no mark at the screen's edge)")
	# At the gate without the horn.
	_put(g, p, crown.gate_feet() + Vector2(0, 40))
	await _frames(4)
	_check(_prompt(g, "The Scrapyard gate: only the Rusted Warhorn opens it"), "at the gate without the horn, it says what opens it")
	await _press(p, "interact_pressed")
	_check(not crown.gate_open and p.get_children().all(func(c): return not (c is Label)), "and stays shut, with nothing printed over the prompt")
	p.input.move = Vector2.UP
	await _frames(90)
	p.input.move = Vector2.ZERO
	_check(p.global_position.y > crown.gate_feet().y - 8.0, "nobody walks through it")
	# The pieces, and Pip's mending.
	purse.kept["horn_body"] = true
	_check(str(_quest(folk, "crown").get("text", "")).contains("1 of 3") and not crown.can_mend(), "a piece is counted")
	purse.kept["horn_bell"] = true
	purse.kept["horn_mouthpiece"] = true
	q = _quest(folk, "mend")
	_check(_quest(folk, "crown").is_empty() and str(q.get("name", "")) == "Mend the Horn" and str(q.get("text", "")).contains("%d tin bars and %d copper bars" % [Crown.MEND_TIN, Crown.MEND_COPPER]), "with all three the quest is Mend the Horn, and says what Pip wants: \"%s\"" % str(q.get("text", "")))
	_check(crown.can_mend() and folk.crown_words(0).contains("%d tin bars and %d copper bars" % [Crown.MEND_TIN, Crown.MEND_COPPER]), "(and so does Pip: \"%s\")" % folk.crown_words(0))
	_put(g, p, folk.pip_home() + Vector2(0, 28))
	await _frames(6)
	await _press(p, "interact_pressed")
	var shop = folk.shop
	_check(shop.is_open and shop.rows().has(Shop.MEND), "Pip's shop has a row to mend the horn")
	await _frames(12)
	shop.row = shop.rows().find(Shop.MEND)
	shop.confirm()
	_check(not crown.horn and purse.kept.size() == 3 and shop.note.begins_with("The bronze wants %d tin bars and %d copper bars." % [Crown.MEND_TIN, Crown.MEND_COPPER]), "without the bars: nothing, and why (\"%s\")" % shop.note)
	bag.add("tin_bar", Crown.MEND_TIN)
	bag.add("copper_bar", Crown.MEND_COPPER + 2)
	shop.confirm()
	_check(crown.horn and bag.count("tin_bar") == 0 and bag.count("copper_bar") == 2 and purse.kept.is_empty(), "with them: the horn is mended, for its bars and the three pieces")
	_check(shop.note == "The Rusted Warhorn is mended." and g.loot.said == "Quest done: Mend the Horn" and _fits(g, g.loot.said), "and the screen says so")
	_check(not shop.rows().has(Shop.MEND) and shop.line == folk.crown_words(0) and shop.line.contains("gate"), "the row is gone, and Pip says where to take it (\"%s\")" % shop.line)
	_check(crown.mend(0) != "" and bag.count("copper_bar") == 2, "(it cannot be mended twice)")
	# What Pip says of the horn fits his plate, whatever has happened.
	var pix := _text_font()
	var wide: float = Shop.BOX.size.x - 36.0 - 60.0
	var most := 0
	for state in [[true, false, 0], [true, true, 0], [false, true, 1]]:
		crown.horn = bool(state[0])
		crown.gate_open = bool(state[1])
		crown.beaten = int(state[2])
		for have in [[], ["horn_body"], ["horn_body", "horn_bell", "horn_mouthpiece"]]:
			purse.kept.clear()
			for name in have:
				purse.kept[name] = true
			most = maxi(most, Shop.lines_of(pix, "\"" + folk.crown_words(0) + "\"", Art.TEXT_SIZE, wide).size())
	_check(most <= 4, "what Pip says about the horn always fits his plate (%d lines at most)" % most)
	purse.kept.clear()
	crown.horn = true
	crown.gate_open = false
	crown.beaten = 0
	shop.close()
	await _frames(3)
	# Blow the Horn, and its mark at the screen's edge.
	q = _quest(folk, "horn")
	_check(str(q.get("name", "")) == "Blow the Horn" and str(q.get("text", "")).contains("Scrapyard gate") and str(q.get("text", "")).contains(crown.side_word()), "the quest is Blow the Horn, and says which way the gate lies: \"%s\"" % str(q.get("text", "")))
	crown.found = false
	_put(g, p, folk.pip_home() + Vector2(0, 60))
	await _frames(4)
	_check(crown.sign_target() == crown.mouth(), "its mark points to the mouth of the way in")
	var spot: Array = folk.edge_spot(crown.sign_target(), 0.0, Rect2(Vector2.ZERO, Folk.SIZE))
	var clear := not spot.is_empty()
	if clear:
		for r: Rect2 in folk.hud_corners():
			if Rect2((spot[0] as Vector2).x - 5.0, (spot[0] as Vector2).y, 10.0, 12.0).intersects(r):
				clear = false
	_check(clear, "and stands at the screen's edge, clear of the bars, the belt and the quests (%s)" % str(spot))
	_put(g, p, crown.mouth() + Vector2(0, 8))
	await _frames(4)
	_check(crown.found and crown.sign_target().distance_to(crown.gate_feet()) < 40.0, "once somebody has been to the mouth of the way it points to the gate")
	_check(folk.edge_spot(crown.mouth(), 0.0, Rect2(Vector2.ZERO, Folk.SIZE)).is_empty(), "(a place that is on the screen has no mark at the edge)")
	# At the gate with the horn.
	_put(g, p, crown.gate_feet() + Vector2(0, 40))
	await _frames(4)
	_check(_prompt(g, "Blow the Rusted Warhorn"), "at the gate with the horn: blow it")
	await _press(p, "interact_pressed")
	_check(crown.gate_open and crown.gate.anim == "opening" and g.loot.said == "The Scrapyard gate is open", "the gate opens to it, and the screen says so")
	await _wait(func(): return crown.gate.anim == "open", 120)
	_check(crown.gate.anim == "open" and crown.gate_shape.disabled, "(it swings open)")
	_check(nav.is_free(gt) and not nav.is_free(gt + Vector2i(-1, 0)) and not nav.is_free(gt + Vector2i(1, 0)), "the middle of the way is clear for the enemies' way-finding, its posts are not")
	await _frames(3)
	_check(not _prompt(g, "Blow the Rusted Warhorn") and not _prompt(g, "The Scrapyard gate: only the Rusted Warhorn opens it"), "the open gate asks nothing more")
	p.input.move = Vector2.UP
	await _frames(45)
	p.input.move = Vector2.ZERO
	_check(p.global_position.y < crown.gate_feet().y - 60.0 and _room_rect(crown, "gatehouse").has_point(p.global_position), "and you walk through it, into the Gatehouse")
	q = _quest(folk, "horn")
	_check(str(q.get("text", "")).contains("Throne Room") and crown.sign_target() == crown.blow_spot(), "now the quest, and its mark, send you to the throne: \"%s\"" % str(q.get("text", "")))
	_check(folk.crown_words(0).contains("throne"), "(and Pip: \"%s\")" % folk.crown_words(0))
	# The spike traps.
	var tile: Vector2i = crown.plan["trap_row"]
	var tr = crown.trap_at.get(tile)
	var mid: Vector2 = (Vector2(tile) + Vector2(0.5, 0.5)) * TILE
	_check(tr != null and tr.state == "down", "a row of spike traps lies just inside the gate")
	_put(g, p, mid + Vector2(0, 70))
	p.hp = p.max_hp
	await _frames(60)
	var hp0: float = p.hp
	p.input.move = Vector2.UP
	await _frames(36)
	p.input.move = Vector2.ZERO
	_check(tr.state != "down" and p.global_position.y < mid.y - 40.0, "stepping on a trap sets it rattling")
	await _wait(func(): return tr.state == "up", 120)
	_check(tr.state == "up" and (tr.z_index == 0 if tr.drawn() else (tr.z_index == -4 and tr.spikes != null and tr.spikes.z_index == 0)), "and its spikes come up, among whoever stands there, while its floor stays under them")
	await _wait(func(): return tr.state == "down" and tr.rest <= 0.0, 300)
	_check(p.hp == hp0, "walking straight across one does not hurt: you are off it before the spikes are up")
	_put(g, p, mid)
	var n: int = await _wait(func(): return tr.state == "warn", 10)
	_check(n >= 0 and p.hp == hp0, "standing on one: it rattles first, and does not hurt yet")
	n = await _wait(func(): return p.hp < hp0, 120)
	_check(n >= 0 and absf(float(n) / 60.0 - Crown.SPIKE_WARN) < 0.1 and absf(hp0 - p.hp - Crown.SPIKES) < 0.01, "after its warning the spikes come up and hurt whoever is on it (%.0f, after %.2f s)" % [hp0 - p.hp, float(n) / 60.0])
	var hp1: float = p.hp
	_put(g, p, mid)
	await _wait(func(): return tr.state == "lower", 200)
	_check(p.hp == hp1, "one rise hurts once, however long you stand in it")
	_put(g, p, mid)
	n = await _wait(func(): return p.hp < hp1, 200)
	_check(n >= 0, "stay, and it comes up again")
	# A dodge over raised spikes; walking onto them.
	_put(g, p, mid + Vector2(0, 30))
	await _wait(func(): return tr.state == "down" and tr.rest <= 0.0, 300)
	await _frames(60)
	hp1 = p.hp
	tr.hit = {}
	tr.go("up")
	p.input.move = Vector2.UP
	await _press(p, "dash_pressed")
	await _frames(14)
	p.input.move = Vector2.ZERO
	_check(p.hp == hp1 and p.global_position.y < mid.y - 30.0, "a dodge takes you over raised spikes unhurt")
	await _frames(30)
	tr.hit = {}
	tr.go("up")
	_put(g, p, mid)
	await _frames(3)
	_check(p.hp < hp1, "stepping onto raised spikes hurts")
	await _leave(g)


# --- The Scrapyard's rooms: who lives there, the barred doors, the Furnace's wards -----------------

func _room_rect(crown, name: String) -> Rect2:
	var r: Rect2i = crown.plan["rooms"][name]
	return Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)


func _door_of(crown, room: String) -> Dictionary:
	for d in crown.doors:
		if str(d["room"]) == room:
			return d
	return {}


func _beat(pack) -> void:
	for e in pack.living():
		e.warded = 0.0
		e.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)


func _yard() -> void:
	var g = _game(424242, 1, true)
	await _frames(5)
	var crown = g.crown
	var foes = g.foes
	var p = g.players[0]
	var purse = g.loot.purses[0]
	p.unhurt = true
	var groups := {}
	for i in foes.plan.size():
		if (foes.plan[i] as Dictionary).has("room"):
			groups[str(foes.plan[i]["room"])] = i
		elif str(foes.plan[i].get("site", "")) == "scrapyard":
			foes.quiet[i] = true          # (the goblins in front of the gate would knock you about)
	_check(groups.size() == 5 and ["gatehouse", "crane", "furnace", "side_a", "side_b"].all(func(n): return groups.has(n)), "the five rooms' groups are on the enemies' plan")
	_check(crown.doors.size() == 3 and crown.doors.all(func(d): return not bool(d["open"]) and not (d["shape"] as CollisionShape2D).disabled and not foes.nav.is_free(d["tile"])), "the far doors of the Gatehouse, the Crane Yard and the Furnace are barred")
	var ids: Array = g.loot.chests.map(func(c): return int(c["plan"]["id"]))
	_check(ids.has(CrownPlan.CHEST_ID) and ids.has(CrownPlan.CHEST_ID + 1), "the side rooms' chests stand with the land's")
	crown.gate_open = true
	crown._show(true)
	_put(g, p, crown.gate_feet() + Vector2(0, 48))
	await _frames(40)
	_check(not foes.packs.has(groups["gatehouse"]) and not foes.inside_yard(), "at the gate, outside the walls, nobody in the Gatehouse is up")
	# Into the Gatehouse.
	var gh := _room_rect(crown, "gatehouse")
	_put(g, p, Vector2(gh.get_center().x, gh.end.y - 48.0))
	await _wait(func(): return foes.packs.has(groups["gatehouse"]), 60)
	var pack = foes.packs.get(groups["gatehouse"])
	var handler = null
	if pack != null:
		for e in pack.living():
			if e.has_meta("stands_for"):
				handler = e
	_check(pack != null and pack.living().size() == 5 and handler != null and handler.elite and str(handler.kind) == "slinger", "inside the walls the Gatehouse's four hounds and their handler (an elite) are there")
	await _wait(func(): return foes.packs.has(groups["crane"]), 60)
	_check(foes.packs.has(groups["crane"]) and (foes.packs[groups["crane"]] as Object).living().size() == 4, "and the Crane Yard's four slingers, behind the Gatehouse's barred door")
	var d := _door_of(crown, "gatehouse")
	var bar_y: float = (float((d["tile"] as Vector2i).y) + 1.0) * TILE
	_put(g, p, Vector2(gh.get_center().x, bar_y + 40.0))
	p.input.move = Vector2.UP
	await _frames(50)
	p.input.move = Vector2.ZERO
	_check(p.global_position.y > bar_y - 4.0, "nobody walks through the bars while the room is not beaten")
	# Beat the Gatehouse.
	_beat(pack)
	await _frames(70)
	_check(bool(d["open"]) and (d["shape"] as CollisionShape2D).disabled and foes.nav.is_free(d["tile"]), "everybody in it beaten: its far door's bars go up")
	_check(purse.kept.is_empty(), "the handler leaves elite loot, but no piece of the horn")
	p.input.move = Vector2.UP
	await _frames(60)
	p.input.move = Vector2.ZERO
	_check(p.global_position.y < bar_y - 40.0, "and you walk on through it")
	# The Furnace: each Shaman keeps a Brute warded.
	var fu := _room_rect(crown, "furnace")
	_put(g, p, Vector2(fu.get_center().x, fu.end.y - 48.0))
	await _wait(func(): return foes.packs.has(groups["furnace"]), 90)
	await _frames(10)
	var fp = foes.packs.get(groups["furnace"])
	var by := {}
	if fp != null:
		for e in fp.living():
			by[int(e.get_meta("member", -1))] = e
	_check(by.size() == 4 and by[2].warded > 0.0 and by[3].warded > 0.0, "in the Furnace, both Brutes are warded while the Shamans stand")
	if by.size() == 4:
		by[0].take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
		await _frames(50)
		_check(by[2].warded <= 0.0 and by[3].warded > 0.0, "one Shaman down: its Brute can be hurt, the other's cannot")
		var hp0: float = by[3].hp
		by[3].take_hit(5.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
		_check(by[3].hp == hp0, "(a warded Brute takes no harm)")
	# Out of the walls and far away, and the rooms fill again: the Gatehouse's door is barred once more.
	for k in foes.fallen.get(groups["gatehouse"], {}):
		foes.fallen[groups["gatehouse"]][k] = 0.0
	await _frames(30)
	_check(bool(d["open"]), "while somebody is inside the walls, nobody comes back")
	_put(g, p, g.map.spawn * TILE)
	await _frames(40)
	_check(not foes.fallen.has(groups["gatehouse"]) and not bool(d["open"]) and not (d["shape"] as CollisionShape2D).disabled, "once nobody is, the rooms fill again, and their doors are barred")
	await _leave(g)


# --- The fight ------------------------------------------------------------------------------------

## What he does next, whatever the dice would say (it must be asked while he rests).
func _next(boss, what: String) -> void:
	boss.done = {}
	for k in Rattlecrown.FIRST:
		if k != what:
			boss.done[k] = true
	if boss.mode == "idle":
		boss.next = what


## The horn is blown and the three fall: he is on his feet.
func _to_his_feet(g) -> void:
	var crown = g.crown
	crown.start()
	await _wait(func(): return crown.stage == "elites", 200)
	_fell_court(crown)
	await _wait(func(): return crown.stage == "foot", 300)


func _fight() -> void:
	var g = _game(424242)
	await _frames(5)
	var crown = g.crown
	var folk = g.folk
	var p = g.players[0]
	var purse = g.loot.purses[0]
	var bag = g.tools.bag_of(0)
	var room: Rect2 = crown.room_rect()
	var open_floor: Vector2 = room.position + Vector2(room.size.x * 0.5, 9.5 * TILE)      # clear of the throne, the traps and the braziers
	folk.pip = 3
	folk._show()
	p.unhurt = true
	g.owned[0] = ["shockwave"]
	# In front of the throne.
	_put(g, p, crown.blow_spot() + Vector2(0, 10))
	await _frames(4)
	_check(not _prompt(g, "Blow the Rusted Warhorn"), "in front of the throne without the horn, nothing is offered")
	crown.horn = true
	crown.gate_open = true
	crown._show(true)
	await _frames(3)
	_check(_prompt(g, "Blow the Rusted Warhorn"), "with the horn, and the gate open: blow it")
	# The hoard's bars keep everybody out.
	_put(g, p, crown.bars_feet() + Vector2(0, 30))
	await _frames(3)
	_check(not _prompt(g, "Open Rattlecrown's hoard"), "his hoard is not to be had yet")
	p.input.move = Vector2.UP
	await _frames(40)
	p.input.move = Vector2.ZERO
	_check(p.global_position.y > crown.bars_feet().y - 4.0, "and nobody walks through its bars")
	_put(g, p, crown.blow_spot() + Vector2(0, 10))
	await _frames(4)
	var coins0: int = purse.coins
	var memory0: int = purse.memory
	await _press(p, "interact_pressed")
	_check(crown.stage == "call" and crown.fighting() and crown.phase() == 1 and crown.throne.anim == "point", "the horn is blown: he points")
	_check(crown.shut_in and crown.inner.anim == "shut" and g.ui.hint == Crown.SAYS["shut"] and g.loot.said != Crown.SAYS["shut"], "the gate shuts behind you, and the tip line says so (one line at a time: nothing else is printed)")
	_check(crown.tip_next == Crown.SAYS["call"] and g.loot.said_y == Crown.NEWS_Y, "what is coming waits its turn in the same line, and the line of news moves down out of its way")
	await _frames(3)
	_check(not crown.inner_shape.disabled and not g.foes.nav.is_free(crown.plan["inner"]) and crown.gate.anim == "open", "(nobody passes it now; the Scrapyard gate stays open)")
	_check(str(_quest(folk, "horn").get("text", "")) == "Beat Rattlecrown, the Scrap King." and crown.sign_target() == Vector2.INF and not _prompt(g, "Blow the Rusted Warhorn"), "the quest is to beat him; the horn is not offered twice")
	await _wait(func(): return crown.stage == "elites", 120)
	var kinds: Array = crown.elites.map(func(e): return str(e.kind))
	_check(kinds == Crown.ELITES and crown.elites.all(func(e): return e.elite and e.summoned and room.has_point(e.global_position)), "his three elite champions come in, all at once (%s)" % str(kinds))
	_check(crown.court.howls == Hound.HOWL_MOST - 1, "(the white hound has one howl in here)")
	_check(crown.boss == null and crown.throne.anim == "idle" and get_nodes_in_group("crown_shots").is_empty(), "he watches from his throne and does not attack")
	await _frames(240)
	_check(crown.stage == "elites" and crown.boss == null and get_nodes_in_group("crown_shots").is_empty() and not is_instance_valid(g.ui.boss), "(four seconds on, still)")
	_check(g.ui.hint == Crown.SAYS["call"] and crown.tip_next == "", "by now the tip line says what is coming")
	# His champions do not set the traps off.
	var patch: Vector2i = (crown.plan["room"] as Rect2i).position + (CrownPlan.TRAPS[1] as Rect2i).position
	var its_trap = crown.trap_at.get(patch)
	crown.elites[0].global_position = (Vector2(patch) + Vector2(0.5, 0.3)) * TILE
	await _frames(20)
	_check(its_trap != null and its_trap.state == "down", "his champions do not set the spike traps off")
	# Something answers the white hound's howl.
	var came = g.call_foe(crown.elites[1], "hound")
	_check(came != null and crown.court.members.has(came), "(a hound answers the howl)")
	crown.elites[0].take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(20)
	_check(crown.stage == "elites", "one champion down: he still watches")
	for e in crown.elites:
		if is_instance_valid(e) and not e.dead:
			e.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(3)
	_check(crown.stage == "kick" and crown.throne.anim == "kick" and g.ui.hint == Crown.SAYS["kick"], "all three down: he kicks his throne apart")
	_check(not is_instance_valid(came) or came.is_queued_for_deletion(), "what answered the howl runs")
	await _frames(20)
	_check(purse.kept.is_empty() and purse.coins == coins0 and purse.memory == memory0 and g.loot.lying.is_empty(), "the champions leave nothing: no piece of the horn, no loot")
	await _wait(func(): return crown.stage == "foot", 200)
	var boss = crown.boss
	_check(boss != null and crown.phase() == 2 and crown.throne.anim == "wreck" and g.ui.hint == Crown.SAYS["foot"], "he is on his feet, in front of the wreck of the throne")
	_check(is_equal_approx(boss.max_hp, Rattlecrown.HP) and boss.hp == boss.max_hp, "with his full health for one player (%.0f)" % boss.max_hp)
	_check(g.ui.boss == boss and not boss.show_bar and boss.knock_resist == 0.0, "his health is the bar at the top of the screen, and nothing knocks him back")
	# Club Slam.
	p.unhurt = false
	p.hp = p.max_hp
	var hp0: float = p.hp
	var n: int = await _wait(func(): return boss.mode == "slam_windup", 600)
	_check(n >= 0 and g.ui.hint == Crown.TIPS["slam"] and p.hp == hp0, "his first attack is the Club Slam, and the tip line names it")
	n = await _wait(func(): return p.hp < hp0, 200)
	_check(n >= 0 and absf(float(n) / 60.0 - (Rattlecrown.SLAM_WINDUP + Rattlecrown.SLAM_AT)) < 0.12, "its ring is on the floor for the whole warning before the club lands (%.2f s)" % (float(n) / 60.0))
	_check(absf(hp0 - p.hp - Rattlecrown.SLAM) < 0.01 and not boss.is_open(), "whoever stands in the ring is hurt (%.0f)" % (hp0 - p.hp))
	# Scrap Toss.
	await _wait(func(): return boss.mode == "rest", 100)
	p.hp = p.max_hp
	hp0 = p.hp
	n = await _wait(func(): return boss.mode == "toss_windup", 600)
	var shots: Array = get_nodes_in_group("crown_shots")
	_check(n >= 0 and g.ui.hint == Crown.TIPS["toss"] and shots.size() == 1, "then the Scrap Toss, named, with its ring on the floor at once")
	if shots.size() == 1:
		_check(shots[0].to.distance_to(p.global_position) < 6.0 and absf(shots[0].wait - Rattlecrown.TOSS_WINDUP) < 0.03 and not shots[0].thrown, "the ring is where you stand, while the lump is still in his hand")
	n = await _wait(func(): return p.hp < hp0, 200)
	_check(n >= 0 and absf(float(n) / 60.0 - (Rattlecrown.TOSS_WINDUP + Rattlecrown.TOSS_FLIGHT)) < 0.12 and absf(hp0 - p.hp - Rattlecrown.TOSS) < 0.01, "it lands after its warning and its flight, on whoever stands on the ring (%.0f, after %.2f s)" % [hp0 - p.hp, float(n) / 60.0])
	# Charge.
	await _wait(func(): return boss.mode == "rest", 200)
	p.hp = p.max_hp
	hp0 = p.hp
	n = await _wait(func(): return boss.mode == "charge_windup", 600)
	_check(n >= 0 and g.ui.hint == Crown.TIPS["charge"], "then the Charge, named")
	n = await _wait(func(): return boss.mode == "charge", 200)
	_check(n >= 0 and absf(float(n) / 60.0 - Rattlecrown.CHARGE_WINDUP) < 0.12 and p.hp == hp0, "its lane lies on the floor for the whole warning before he runs (%.2f s)" % (float(n) / 60.0))
	n = await _wait(func(): return p.hp < hp0, 60)
	_check(n >= 0 and absf(hp0 - p.hp - Rattlecrown.CHARGE) < 0.01, "and whoever is in the lane is hurt (%.0f)" % (hp0 - p.hp))
	_check(boss.done.size() == 3 and boss.attacks == 3, "his first three attacks are one of each")
	# Out of the way in time: nothing hurts, and he is Open.
	await _wait(func(): return boss.mode == "rest", 200)
	_next(boss, "slam")
	_put(g, p, open_floor)
	p.hp = p.max_hp
	hp0 = p.hp
	n = await _wait(func(): return boss.mode == "slam_windup", 900)
	await _frames(int(Rattlecrown.SLAM_WINDUP * 60.0) - 18)
	_put(g, p, p.global_position + (p.global_position - boss.global_position).normalized() * 180.0)
	await _wait(func(): return boss.mode == "rest", 120)
	_check(n >= 0 and p.hp == hp0 and boss.is_open(), "step out of the ring in time and the slam hurts nobody: he is Open while he gets his breath")
	_next(boss, "toss")
	n = await _wait(func(): return boss.mode == "toss_windup", 900)
	await _frames(20)
	_put(g, p, p.global_position + Vector2(140, 0) * (1.0 if p.global_position.x < room.get_center().x else -1.0))
	await _wait(func(): return get_nodes_in_group("crown_shots").is_empty(), 200)
	_check(n >= 0 and p.hp == hp0 and boss.is_open(), "step off the scrap's ring and it lands on nobody: he is Open for the rest of his breath")
	# A charge that ends against the rock.
	await _wait(func(): return boss.mode == "rest", 200)
	_next(boss, "charge")
	var by_wall := Vector2(room.end.x - 48.0, open_floor.y)
	boss.global_position = by_wall + Vector2(-208, 0)
	_put(g, p, by_wall)
	n = await _wait(func(): return boss.mode == "charge_windup", 600)
	await _wait(func(): return boss.mode_t <= Rattlecrown.LOCK - 0.05, 200)
	_put(g, p, by_wall + Vector2(0, 110))
	await _wait(func(): return boss.mode == "rest", 200)
	_check(n >= 0 and p.hp == hp0 and boss.mode_t > Rattlecrown.REST and boss.is_open(), "step out of the lane and a charge that ends against the rock leaves him dazed, and Open for longer")
	# The crown.
	_put(g, p, open_floor)
	boss.hp = boss.max_hp * Rattlecrown.CROWN_AT
	n = await _wait(func(): return boss.mode == "crown_on", 400)
	_check(n >= 0 and boss.immune and not boss.crowned, "at half his health he stops to put on his crown")
	var before: float = boss.hp
	boss.take_hit(50.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	_check(boss.hp == before, "(nothing hurts him while he does)")
	n = await _wait(func(): return boss.crowned, 120)
	_check(n >= 0 and crown.stage == "crown" and crown.phase() == 3 and boss.art_name() == "rattlecrown_crowned" and not boss.immune and g.ui.hint == Crown.SAYS["crown"], "the crown is on: phase three, and the tip line says what it means")
	# Crowned: the Club Slam, twice.
	p.unhurt = true
	_next(boss, "slam")
	n = await _wait(func(): return boss.mode == "slam_windup", 900)
	_check(n >= 0 and g.ui.hint == Crown.TIPS_TWICE["slam"] and boss.goes == 2 and boss.first_go and absf(boss.windup - Rattlecrown.SLAM_WINDUP) < 0.03, "crowned, the Club Slam is named as coming twice")
	await _wait(func(): return boss.blow_t < 0.03, 200)
	var gap: int = await _wait(func(): return boss.mode == "slam_windup", 200)
	_check(gap >= 0 and not boss.first_go and absf(boss.windup - Rattlecrown.SLAM_WINDUP * Rattlecrown.SECOND) < 0.03, "the second ring has a warning of its own, three quarters as long")
	_check(float(gap) / 60.0 >= Rattlecrown.AGAIN and float(gap) / 60.0 > Rattlecrown.BLOW_SHOW, "and is only on the floor once the first has landed and gone (%.2f s later)" % (float(gap) / 60.0))
	await _wait(func(): return boss.mode == "slam", 200)
	await _wait(func(): return boss.mode == "rest", 200)
	_check(boss.mode == "rest" and boss.goes == 1, "after the second he rests")
	# Crowned: the Scrap Toss, twice.
	_next(boss, "toss")
	_put(g, p, open_floor)
	n = await _wait(func(): return boss.mode == "toss_windup" and not boss.first_go, 900)
	shots = get_nodes_in_group("crown_shots")
	_check(n >= 0 and g.ui.hint == Crown.TIPS_TWICE["toss"] and shots.size() == 2, "crowned, the Scrap Toss is two lumps: both rings are on the floor together")
	if shots.size() == 2:
		var apart: float = shots[0].to.distance_to(shots[1].to)
		var one := Rect2(shots[0].to - shots[0].reach, shots[0].reach * 2.0)
		var two := Rect2(shots[1].to - shots[1].reach, shots[1].reach * 2.0)
		_check(apart >= Rattlecrown.TOSS_APART - 1.0 and not one.intersects(two), "and the second is never laid on the first: they do not touch (%.0f apart)" % apart)
	# (Against the walls too.)
	var tight := true
	for corner in [room.position, Vector2(room.end.x, room.position.y), Vector2(room.position.x, room.end.y), room.end, Vector2(room.get_center().x, room.end.y)]:
		boss.first_mark = boss._in_room(corner)
		var second: Vector2 = boss._apart(corner)
		if second.distance_to(boss.first_mark) < Rattlecrown.TOSS_APART - 1.0 or not room.grow(8.0).has_point(second):
			tight = false
	_check(tight, "even in a corner of the room the two rings are apart, and on its floor")
	# Crowned: the Charge, twice.
	await _wait(func(): return boss.mode == "rest", 300)
	_next(boss, "charge")
	boss.global_position = open_floor + Vector2(-300, 0)
	_put(g, p, open_floor + Vector2(-100, 0))
	n = await _wait(func(): return boss.mode == "charge_windup", 600)
	_check(n >= 0 and g.ui.hint == Crown.TIPS_TWICE["charge"] and boss.first_go, "crowned, the Charge is named as coming twice")
	await _wait(func(): return boss.mode == "charge", 200)
	await _wait(func(): return boss.mode != "charge", 200)
	_check(boss.mode == "again", "the first ends in the open floor")
	gap = await _wait(func(): return boss.mode == "charge_windup", 200)
	_check(gap >= 0 and not boss.first_go and absf(boss.windup - Rattlecrown.CHARGE_WINDUP * Rattlecrown.SECOND) < 0.03 and boss.aim.dot((p.global_position - boss.global_position).normalized()) > 0.9, "he turns, and the second lane is laid toward you, with a warning of its own")
	await _wait(func(): return boss.mode == "rest", 300)
	# Everybody falls: the fight is called off.
	p.unhurt = false
	p.invuln = 0.0
	p.take_damage(99999.0, boss.global_position, boss)
	await _frames(3)
	_check(not room.has_point(p.global_position) and crown.standing_in_room() == 0, "(you fall, and wake where you set out from)")
	n = await _wait(func(): return crown.stage == "wait", int(Crown.RESET_AFTER * 60.0) + 60)
	_check(n >= int(Crown.RESET_AFTER * 60.0) - 20, "nobody on their feet in the room for %.0f seconds: the fight is called off" % Crown.RESET_AFTER)
	await _frames(3)
	_check(crown.boss == null and (not is_instance_valid(boss) or boss.is_queued_for_deletion()) and crown.horn and crown.throne.anim == "idle" and g.ui.boss == null and g.ui.hint == "", "he sits back down, and the horn is still good")
	_check(g.loot.said == "Rattlecrown sits back down" and g.loot.said_y == 42.0 and get_nodes_in_group("crown_shots").is_empty(), "the screen says so")
	_check(not crown.shut_in and crown.inner.anim in ["opening", "open"] and crown.inner_shape.disabled, "and the gate opens again")
	# Again, and he falls.
	p.unhurt = true
	p.hp = p.max_hp
	_put(g, p, crown.blow_spot() + Vector2(0, 10))
	await _frames(100)
	await _press(p, "interact_pressed")
	_check(crown.stage == "call", "the horn calls him again")
	await _wait(func(): return crown.stage == "elites", 200)
	_fell_court(crown)
	await _wait(func(): return crown.stage == "foot", 300)
	boss = crown.boss
	_check(boss != null and is_equal_approx(boss.hp, boss.max_hp) and not boss.crowned, "with all his health, and no crown on")
	coins0 = purse.coins
	memory0 = purse.memory
	var tin0: int = bag.count("tin_bar")
	var copper0: int = bag.count("copper_bar")
	boss.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(3)
	_check(crown.stage == "won" and crown.beaten == 1 and not crown.horn and crown.hoard == "first", "he falls: the horn cracks, and his hoard is the squad's")
	_check(g.loot.said == "Quest done: Blow the Horn" and g.ui.boss == null and g.ui.hint == Crown.HOARD_TIP, "the screen says the quest is done, and where his hoard is")
	_check(not crown.shut_in and crown.inner.anim in ["opening", "open"] and crown.bars.up, "the gate opens, and the bars of his hoard go up")
	_check(purse.coins == coins0 and purse.memory == memory0 and bag.count("tin_bar") == tin0, "(nothing is thrown on the floor: it is all in the chest)")
	var q := _quest(folk, "hoard")
	_check(str(q.get("name", "")) == "The King's Hoard" and crown.sign_target().distance_to(crown.hoard_feet()) < 40.0, "the quest sends you to it: \"%s\"" % str(q.get("text", "")))
	await _wait(func(): return crown.stage == "wait", 300)
	_check(crown.stage == "wait" and crown.throne.anim == "wreck" and crown.bars_shape.disabled, "(the wreck of the throne stands empty)")
	# His hoard.
	_put(g, p, crown.bars_feet() + Vector2(0, 12))
	await _frames(4)
	_check(_prompt(g, "Open Rattlecrown's hoard"), "at the alcove: open his hoard")
	await _press(p, "interact_pressed")
	_check(crown.hoard == "" and purse.coins == coins0 + Crown.FIRST_COINS and purse.memory == memory0 + Crown.FIRST_MEMORY and bag.count("tin_bar") == tin0 + Crown.FIRST_BARS and bag.count("copper_bar") == copper0 + Crown.FIRST_BARS, "the first hoard: %d Memory, %d coins, %d bars of each" % [Crown.FIRST_MEMORY, Crown.FIRST_COINS, Crown.FIRST_BARS])
	_check((g.owned[0] as Array).has("twice"), "and the Twice thread, to use at the forge")
	_check(g.ui.hint == "" and _quest(folk, "hoard").is_empty() and _quest(folk, "horn").is_empty() and _quest(folk, "crown").is_empty(), "the horn's quests are done")
	n = await _wait(func(): return g.ui.busy(), int(Crown.HOARD_CARD * 60.0) + 60)
	_check(n >= 0 and g.ui.card_title == "Rattlecrown's hoard" and g.ui.card_body == crown.won_text(), "a card says what it held")
	await _frames(30)
	await _press(p, "interact_pressed")
	await _frames(3)
	_check(not g.ui.busy() and crown.chest.texture == crown._chest_tex("chest_empty"), "(a press puts the card away; the chest stands empty)")
	_check(not _prompt(g, "Open Rattlecrown's hoard") and not crown.open_hoard(0), "an empty hoard gives nothing more")
	_check(folk.crown_words(0).begins_with("The horn cracked"), "Pip knows the horn has cracked (\"%s\")" % folk.crown_words(0))
	# Another fight wants the three pieces, and Pip, again.
	_put(g, p, crown.blow_spot() + Vector2(0, 10))
	await _frames(4)
	_check(not _prompt(g, "Blow the Rusted Warhorn") and crown.gate_open, "without a mended horn he cannot be called; the gate stays open")
	for name in Loot.KEPT:
		purse.kept[name] = true
	_check(str(_quest(folk, "mend").get("name", "")) == "Mend the Horn", "with three pieces again, Mend the Horn is back")
	_check(crown.mend(0) == "" and crown.horn and crown.throne.anim == "idle" and crown.chest.texture == crown._chest_tex("chest", 0), "Pip mends it again: he is back on his throne, and his chest is full")
	_check(str(_quest(folk, "horn").get("text", "")).contains("Throne Room"), "(and the quest sends you straight to the throne)")
	# Whoever is in with the hoard when the horn is blown is put out before the bars come down.
	_put(g, p, crown.hoard_feet() + Vector2(-30, 6))
	await _frames(3)
	crown.start()
	_check(not crown.alcove_rect().has_point(p.global_position) and room.has_point(p.global_position) and not crown.bars.up, "nobody is shut in with the hoard when the bars come down")
	await _wait(func(): return crown.stage == "elites", 200)
	_fell_court(crown)
	await _wait(func(): return crown.stage == "foot", 300)
	coins0 = purse.coins
	memory0 = purse.memory
	tin0 = bag.count("tin_bar")
	crown.boss.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(3)
	_check(crown.beaten == 2 and crown.hoard == "again" and g.loot.said == "Rattlecrown is beaten again", "beaten again")
	_check(crown.open_hoard(0) and purse.coins == coins0 + Crown.AGAIN_COINS and purse.memory == memory0 + Crown.AGAIN_MEMORY and bag.count("tin_bar") == tin0 + Crown.AGAIN_BARS, "a later hoard: %d Memory, %d coins, %d bars of each" % [Crown.AGAIN_MEMORY, Crown.AGAIN_COINS, Crown.AGAIN_BARS])
	await _frames(int(Crown.HOARD_CARD * 60.0) + 40)
	_check(not g.ui.busy(), "(and no card)")
	# In the test arena he fights on his own.
	var lone = Make.make("rattlecrown")
	lone.position = open_floor + Vector2(200, 0)
	g.world.add_child(lone)
	_put(g, p, open_floor)
	n = await _wait(func(): return lone.mode == "slam_windup", 900)
	_check(n >= 0 and lone.show_bar and is_equal_approx(lone.max_hp, Rattlecrown.HP), "put down anywhere without a room (the test arena), he fights whoever is there")
	lone.queue_free()
	await _leave(g)


# --- Two players --------------------------------------------------------------------------------------

func _two_players() -> void:
	var g = _game(424242, 2)
	await _frames(5)
	var crown = g.crown
	var folk = g.folk
	var a = g.players[0]
	var b = g.players[1]
	var purses: Array = g.loot.purses
	folk.pip = 3
	folk._show()
	a.unhurt = true
	b.unhurt = true
	# The pieces are the squad's, and so are the bars.
	purses[0].kept["horn_body"] = true
	for name in Loot.KEPT:
		purses[1].kept[name] = true
	g.tools.bag_of(0).add("tin_bar", 1)
	g.tools.bag_of(1).add("tin_bar", 5)
	g.tools.bag_of(0).add("copper_bar", Crown.MEND_COPPER)
	g.tools.bag_of(1).add("copper_bar", 1)
	_check(folk.pieces() == 3 and crown.squad("tin_bar") == 6 and crown.can_mend(), "the squad has the three pieces between them")
	_check(crown.mend(0) == "" and g.tools.bag_of(0).count("tin_bar") == 0 and g.tools.bag_of(1).count("tin_bar") == 5 - (Crown.MEND_TIN - 1) and g.tools.bag_of(0).count("copper_bar") == 0 and g.tools.bag_of(1).count("copper_bar") == 1, "player one has it mended: their own bars first, the rest from player two")
	_check(purses[0].kept.is_empty() and purses[1].kept.is_empty() and crown.horn, "the pieces are in the horn now, everybody's")
	crown.gate_open = true
	crown._show(true)
	_put(g, a, crown.blow_spot() + Vector2(-24, 10))
	_put(g, b, crown.blow_spot() + Vector2(24, 10))
	await _frames(4)
	await _press(b, "interact_pressed")
	_check(crown.stage == "call", "either player blows the horn")
	await _wait(func(): return crown.stage == "elites", 200)
	_fell_court(crown)
	await _wait(func(): return crown.stage == "foot", 300)
	var boss = crown.boss
	_check(boss != null and is_equal_approx(boss.max_hp, Rattlecrown.HP * (1.0 + Rattlecrown.HP_PER_PLAYER)) and is_equal_approx(Rattlecrown.HP_PER_PLAYER, 0.7), "for two players he has 1.7 times the health (%.0f)" % boss.max_hp)
	# The top middle of the screen is his bar's and the tip's: clear of both players' bars and of the quests.
	_check(folk.track_at().y > 70.0 and not folk.quests().is_empty(), "(with two players the quests are listed under player two's bars)")
	var corners: Array = folk.hud_corners()
	var bar := Rect2(240, 24, 160, 12)
	_check(corners.all(func(r): return not (r as Rect2).intersects(bar)), "the boss's bar is clear of both players' bars, the belts and the quests")
	var tips: Array = Crown.SAYS.values() + Crown.TIPS.values() + Crown.TIPS_TWICE.values() + [Crown.HOARD_TIP]
	var worst := 0
	var widest := 0.0
	var covered := 0
	for tip in tips:
		var lines: Array = g.ui._wrap(str(tip), g.ui.hint_w)
		var pitch: float = g.ui._pitch(lines)
		var w := 0.0
		for l in lines:
			w = maxf(w, g.ui._line_w(l))
		worst = maxi(worst, lines.size())
		widest = maxf(widest, w)
		var back := Rect2(roundf(320.0 - w * 0.5) - 7.0, 50.0 - 5.0 - pitch * 0.5, w + 14.0, float(lines.size()) * pitch + 2.0)
		if corners.any(func(r): return (r as Rect2).intersects(back)) or back.end.y > Crown.NEWS_Y:
			covered += 1
	_check(g.ui.hint_w == Crown.TIP_W and worst <= 2 and widest <= Crown.TIP_W and covered == 0, "every tip of the fight fits under the bar in two lines at most, clear of the corners and of the line of news (%d lines, %.0f wide)" % [worst, widest])
	for line in ["Rattlecrown sits back down", "Quest done: Blow the Horn", "Rattlecrown is beaten again", "Quest done: Mend the Horn", "The Scrapyard gate is open"]:
		var w: float = g.loot._head_width(line) + 12.0
		var at_bar := Rect2(320.0 - w * 0.5, 42.0, w, 14.0)
		var low := Rect2(320.0 - w * 0.5, Crown.NEWS_Y, w, 14.0)
		_check(corners.all(func(r): return not (r as Rect2).intersects(at_bar) and not (r as Rect2).intersects(low)), "the line \"%s\" is clear of the corners" % line)
	# The spike traps hurt each of them once.
	a.unhurt = false
	b.unhurt = false
	a.hp = a.max_hp
	b.hp = b.max_hp
	var tile: Vector2i = (crown.plan["room"] as Rect2i).position + (CrownPlan.TRAPS[0] as Rect2i).position + Vector2i(1, 1)
	var mid: Vector2 = (Vector2(tile) + Vector2(0.5, 0.5)) * TILE
	var tr = crown.trap_at[tile]
	_put(g, a, mid + Vector2(-6, -8))
	_put(g, b, mid + Vector2(6, -8))
	await _wait(func(): return tr.state == "up", 120)
	await _frames(4)
	_check(absf(a.max_hp - a.hp - Crown.SPIKES) < 0.01 and absf(b.max_hp - b.hp - Crown.SPIKES) < 0.01, "a trap hurts everybody who is on it, once each")
	a.unhurt = true
	b.unhurt = true
	_put(g, a, crown.blow_spot() + Vector2(-24, 60))
	_put(g, b, crown.blow_spot() + Vector2(24, 60))
	# He falls: the hoard is everybody's.
	var before: Array = [purses[0].coins, purses[1].coins, purses[0].memory, purses[1].memory]
	g.owned[0] = ["shockwave"]
	g.owned[1] = ["shockwave", "twice"]
	boss.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(3)
	_check(crown.hoard == "first" and crown.open_hoard(1), "he falls, and player two opens his hoard")
	_check(purses[0].coins == before[0] + Crown.FIRST_COINS and purses[1].coins == before[1] + Crown.FIRST_COINS and purses[0].memory == before[2] + Crown.FIRST_MEMORY and purses[1].memory == before[3] + Crown.FIRST_MEMORY, "everybody gets their own full share")
	_check((g.owned[0] as Array).has("twice") and (g.owned[1] as Array).count("twice") == 1, "and the Twice thread, once each")
	await _leave(g)


# --- Saved ------------------------------------------------------------------------------------------

func _fresh_folder(path: String) -> void:
	for sub in ["characters", "worlds", "deleted"]:
		var dir := DirAccess.open("%s/%s" % [path, sub])
		if dir != null:
			for f in dir.get_files():
				dir.remove(f)
	Save.root = path


func _saved() -> void:
	var old_root := Save.root
	_fresh_folder(ROOT)
	var who := Save.fresh(Save.CHARACTERS)
	var where := Save.fresh(Save.WORLDS)
	where["seed"] = 424242
	var g = _game(0, 1, false, [who], where)
	await _frames(5)
	var crown = g.crown
	var folk = g.folk
	var p = g.players[0]
	var id := str(where["id"])
	var me := str(who["id"])
	var kept = Save.read(Save.WORLDS, id).get("crown")
	_check(kept is Dictionary and kept.get("horn") == false and kept.get("gate") == false and int(kept.get("beaten", -1)) == 0 and str(kept.get("hoard", "x")) == "", "a new world's file says the horn is not mended and the gate is shut (%s)" % str(kept))
	folk.pip = 3
	folk._show()
	p.unhurt = true
	# Mending saves.
	for name in Loot.KEPT:
		g.loot.purses[0].kept[name] = true
	g.tools.bag_of(0).add("tin_bar", Crown.MEND_TIN)
	g.tools.bag_of(0).add("copper_bar", Crown.MEND_COPPER)
	var written: int = g.saves_written
	_check(crown.mend(0) == "" and g.saves_written > written and Save.read(Save.WORLDS, id)["crown"]["horn"] == true, "mending the horn saves the world")
	var mine := Save.read(Save.CHARACTERS, me)
	_check(str(mine.get("kept", [])) == "[]" or not str(mine).contains("horn_body"), "(and the character, whose pieces and bars went into it)")
	# Opening the gate saves.
	_put(g, p, crown.gate_feet() + Vector2(0, 40))
	await _frames(4)
	written = g.saves_written
	await _press(p, "interact_pressed")
	_check(crown.gate_open and g.saves_written > written and Save.read(Save.WORLDS, id)["crown"]["gate"] == true, "opening the gate saves the world")
	await _leave(g)
	# Played again.
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, me)], Save.read(Save.WORLDS, id))
	await _frames(5)
	crown = g.crown
	folk = g.folk
	p = g.players[0]
	p.unhurt = true
	_check(crown.horn and crown.gate_open and crown.gate.anim == "open" and crown.throne.anim == "idle" and crown.beaten == 0, "played again: the horn is mended and the gate stands open")
	await _frames(3)
	_check(crown.gate_shape.disabled and str(_quest(folk, "horn").get("text", "")).contains("Throne Room"), "(and the quest is to blow it at the throne)")
	# A fight that is under way is not saved as won, or as anything: leave in the middle of it and he sits there again.
	g.owned[0] = ["shockwave"]
	_put(g, p, crown.blow_spot() + Vector2(0, 10))
	await _frames(4)
	await _to_his_feet(g)
	_check(crown.stage == "foot", "(the fight)")
	await _leave(g)
	kept = Save.read(Save.WORLDS, id)["crown"]
	_check(kept["horn"] == true and int(kept["beaten"]) == 0 and str(kept["hoard"]) == "", "leave in the middle of the fight: the world's file has the horn still good and him unbeaten")
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, me)], Save.read(Save.WORLDS, id))
	await _frames(5)
	crown = g.crown
	folk = g.folk
	p = g.players[0]
	p.unhurt = true
	_check(crown.stage == "wait" and crown.horn and not crown.shut_in and crown.throne.anim == "idle", "played again: he sits on his throne, and the gate is open")
	# He falls: saved, with the hoard unopened.
	g.owned[0] = ["shockwave"]
	_put(g, p, crown.blow_spot() + Vector2(0, 10))
	await _frames(4)
	await _to_his_feet(g)
	written = g.saves_written
	crown.boss.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(3)
	kept = Save.read(Save.WORLDS, id)["crown"]
	_check(g.saves_written > written and kept["horn"] == false and int(kept["beaten"]) == 1 and str(kept["hoard"]) == "first", "beating him saves the world: beaten once, the horn cracked, his hoard waiting (%s)" % str(kept))
	await _leave(g)
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, me)], Save.read(Save.WORLDS, id))
	await _frames(5)
	crown = g.crown
	folk = g.folk
	p = g.players[0]
	_check(crown.beaten == 1 and crown.hoard == "first" and crown.bars.up and crown.bars.k == 1.0 and crown.throne.anim == "wreck" and not _quest(folk, "hoard").is_empty(), "played again: the hoard still waits, its bars up, and the quest says so")
	g.owned[0] = ["shockwave"]
	var coins0: int = g.loot.purses[0].coins
	_put(g, p, crown.bars_feet() + Vector2(0, 12))
	await _frames(4)
	written = g.saves_written
	await _press(p, "interact_pressed")
	_check(crown.hoard == "" and g.loot.purses[0].coins == coins0 + Crown.FIRST_COINS and (g.owned[0] as Array).has("twice"), "(opened)")
	mine = Save.read(Save.CHARACTERS, me)
	_check(g.saves_written > written and str(Save.read(Save.WORLDS, id)["crown"]["hoard"]) == "" and mine.get("owned") is Array and (mine["owned"] as Array).has("twice") and int(mine.get("coins", -1)) == coins0 + Crown.FIRST_COINS, "opening the hoard saves the world and the character: the Twice thread and the coins are theirs")
	await _wait(func(): return g.ui.busy(), 200)
	await _frames(30)
	await _press(p, "interact_pressed")
	await _leave(g)
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, me)], Save.read(Save.WORLDS, id))
	await _frames(5)
	crown = g.crown
	_check(crown.beaten == 1 and crown.hoard == "" and not crown.horn and crown.gate_open and crown.chest.texture == crown._chest_tex("chest_empty") and (g.owned[0] as Array).has("twice"), "played again: he is beaten, the chest is empty, and the character still has Twice")
	_check(_quest(g.folk, "crown").is_empty() and _quest(g.folk, "horn").is_empty() and _quest(g.folk, "hoard").is_empty(), "(and the horn has no quest until its pieces are found again)")
	# What a save might hold that makes no sense is passed over.
	crown.set_world_data({"crown": "king"})
	_check(not crown.horn and not crown.gate_open and crown.beaten == 0 and crown.hoard == "" and crown.gate.anim == "shut" and crown.throne.anim == "idle" and not crown.bars.up, "a save that makes no sense is a world where nothing has happened yet")
	crown.set_world_data({"crown": {"horn": 1, "gate": true, "beaten": -4, "found": "yes", "hoard": "all of it"}})
	_check(not crown.horn and crown.gate_open and crown.beaten == 0 and not crown.found and crown.hoard == "", "it is read as far as it makes sense")
	crown.set_world_data({"crown": {"horn": true, "gate": true, "beaten": 2.0, "found": true, "hoard": "again"}})
	_check(crown.horn and crown.beaten == 2 and crown.found and crown.hoard == "again" and crown.bars.up, "(numbers that come back from a file as fractions are still numbers)")
	await _leave(g)
	# A world from before version 48.
	var old_world := Save.read(Save.WORLDS, id)
	old_world.erase("crown")
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, me)], old_world)
	await _frames(5)
	_check(g.crown.ok() and not g.crown.horn and not g.crown.gate_open and g.crown.beaten == 0 and not g.relaid, "a world saved before there was a Rattlecrown plays on, with his gate shut (and its land is not laid out again)")
	await _leave(g)
	Save.root = old_root
