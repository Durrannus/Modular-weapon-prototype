extends SceneTree
## Chests, what enemies leave, coins and Memory (version 44). Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands_loot.gd
##
## "seeds=20" looks at more lands' chests (12 otherwise). With shots=/some/folder/ (needs a window, so leave out
## --headless) it saves 640x360 frames instead: a chest opened step by step, the purse on the screen, an elite's
## loot, a full bag, and a thrown rock's shadow. "seed=123456" picks the world.

const PlayerInput := preload("res://scripts/player_input.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const FoePlan := preload("res://scripts/highlands/foe_plan.gd")
const LootPlan := preload("res://scripts/highlands/loot_plan.gd")
const Loot := preload("res://scripts/highlands/loot.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")
const Bag := preload("res://scripts/highlands/bag.gd")
const Nav := preload("res://scripts/highlands/nav.gd")
const Make := preload("res://scripts/foes/make.gd")
const Rock := preload("res://scripts/foes/rock.gd")
const Save := preload("res://scripts/save.gd")
const Sim := preload("res://scripts/sim.gd")
const SavePick := preload("res://scripts/ui/save_pick.gd")
const TILE := 32.0
const SWING_TICKS := 29
const ROOT := "user://test_loot_saves"

var fails := 0
var checks := 0
var shot_dir := ""
var shot_seed := 424242
var seeds := 12


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shot_dir = a.substr(6)
		elif a.begins_with("seed="):
			shot_seed = int(a.substr(5))
		elif a.begins_with("seeds="):
			seeds = int(a.substr(6))
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
		quit()
		return
	_art()
	_plans()
	await _chest()
	await _two_players()
	await _bag_full()
	await _work()
	await _drops()
	await _saved()
	await _blanks()
	print("%s  chests and loot: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
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
	g.queue_free()
	await _frames(3)


func _press(p, field: String) -> void:
	await physics_frame
	p.input.set(field, true)
	await physics_frame
	p.input.set(field, false)
	await physics_frame


## Stands a player in front of a chest (just south of it), looking at it.
func _before(g, p, k: int, aside := 0.0) -> void:
	var foot: Vector2 = g.loot.chests[k]["plan"]["foot"]
	p.global_position = foot * 2.0 + Vector2(aside, 20.0)
	p.input.stick_aim = Vector2.UP
	p.input.move = Vector2.ZERO
	g.rig.snap()
	await _frames(4)
	g.land.settle()


func _kind(g, kind: String, skip := 0) -> int:
	for k in g.loot.chests.size():
		if str(g.loot.chests[k]["plan"]["kind"]) == kind:
			if skip == 0:
				return k
			skip -= 1
	return -1


# --- The pictures are there ---------------------------------------------------------------

func _art() -> void:
	for item in Bag.ORDER:
		_check(ItemArt.size("item_" + str(item)) == Vector2(16, 16), "the bag has a picture of %s" % item)
		_check(ItemArt.size("drop_" + str(item)) != Vector2.ZERO, "and one of it lying on the ground")
		_check(Bag.NAMES.has(item), "and a name for it")
	for name in ["drop_coins", "item_coins", "memory_mote", "hud_coin", "chest", "chest_empty", "item_horn_body", "item_horn_bell", "item_horn_mouthpiece", "drop_horn_body", "drop_horn_bell", "drop_horn_mouthpiece"]:
		_check(ItemArt.size(name) != Vector2.ZERO, "the loot art has %s" % name)
	_check(ItemArt.size("chest") == Vector2(18, 20) and ItemArt.size("memory_mote") == Vector2(7, 7) and ItemArt.size("drop_coins") == Vector2(12, 12), "one frame of a strip is measured, not the whole strip")
	_check(ItemArt.size("item_nothing") == Vector2.ZERO, "a picture nobody drew has no size")
	for piece in Loot.HORN.values():
		_check(piece in Loot.KEPT and Loot.KEPT_NAMES.has(piece), "%s is a kept thing with a name" % piece)


# --- Where the chests stand ----------------------------------------------------------------

func _plans() -> void:
	var total := 0
	var tight := 0
	var kinds := {}
	var slowest := 0.0
	for n in seeds:
		var seed_value := 424242 if n == 0 else 1000 + n * 7919
		var m := WorldGen.make(seed_value)
		var groups := FoePlan.make(m)
		var t0 := Time.get_ticks_usec()
		var plan := LootPlan.make(m, groups)
		slowest = maxf(slowest, float(Time.get_ticks_usec() - t0) / 1000.0)
		_check(str(plan) == str(LootPlan.make(m, groups)) and str(plan) == str(LootPlan.make(WorldGen.make(seed_value), groups)), "world %d: the same land gives the same chests" % seed_value)
		total += plan.size()
		var seen := m.reach(Vector2i(m.spawn))
		var cave := Vector2(LandMap.MID + 0.5, LandMap.MID + 0.5)
		var lived := {}
		for g in groups:
			lived[int(g["pocket"])] = true
		var by_pocket := {}
		var firsts := 0
		var ok_ground := true
		var ok_reach := true
		var ok_clear := true
		var ok_holds := true
		var ok_far := true
		for c in plan:
			kinds[str(c["kind"])] = int(kinds.get(str(c["kind"]), 0)) + 1
			by_pocket[int(c["pocket"])] = c
			var t: Vector2i = c["tile"]
			var p: Dictionary = m.pockets[int(c["pocket"])]
			var open := 0
			for j in range(-1, 2):
				for i in range(-1, 2):
					if m.walkable(t.x + i, t.y + j):
						open += 1
			if not m.walkable(t.x, t.y) or (open < 9 and not bool(p.get("sealed", false))) or open < 4:
				ok_ground = false
			if open < 9:
				tight += 1
			if m.reached(seen, t.x, t.y) == bool(p.get("sealed", false)):
				ok_reach = false
			var foot: Vector2 = c["foot"]
			if foot != Vector2(t.x * 16 + 8, t.y * 16 + 12) or int(c["id"]) != int(c["pocket"]):
				ok_ground = false
			for th in m.things:
				if Painter.things.get(str(th["n"]), {}).has("solid") and absf(float(th["x"]) - foot.x) < 12.0 and absf(float(th["y"]) - foot.y) < 6.0:
					ok_clear = false
			if int(c["coins"]) < 1 or int(c["memory"]) < 1 or (c["items"] as Array).is_empty():
				ok_holds = false
			for it in c["items"]:
				if not (str(it[0]) in ["tin_bar", "copper_bar"]) or int(it[1]) < 1 or int(it[1]) > 6:
					ok_holds = false
			var d := (p["at"] as Vector2).distance_to(cave)
			match str(c["kind"]):
				"first":
					firsts += 1
					if d < LootPlan.FIRST_FROM or d >= FoePlan.SAFE or lived.has(int(c["pocket"])):
						ok_far = false
				"guarded":
					if not lived.has(int(c["pocket"])):
						ok_far = false
				"plain":
					if lived.has(int(c["pocket"])) or d < FoePlan.SAFE:
						ok_far = false
				"sealed":
					if not bool(p.get("sealed", false)):
						ok_far = false
		_check(ok_ground, "world %d: every chest stands on open ground with open ground all round it (a sealed place's may have less)" % seed_value)
		_check(ok_reach, "world %d: every chest can be walked to from the cave, but for the sealed places', which cannot" % seed_value)
		_check(ok_clear, "world %d: no chest stands in something" % seed_value)
		_check(ok_holds, "world %d: every chest holds coins, Memory and a few bars" % seed_value)
		_check(ok_far and firsts == 1, "world %d: one first chest in the safe hills, the guarded ones where somebody lives, the plain ones where nobody does" % seed_value)
		var sealed := 0
		var sealed_with := 0
		for i in m.pockets.size():
			if bool(m.pockets[i].get("sealed", false)):
				sealed += 1
				if by_pocket.has(i):
					sealed_with += 1
		_check(sealed_with > 0 and sealed_with < sealed, "world %d: some of the sealed places have a chest, not all (%d of %d; since version 55)" % [seed_value, sealed_with, sealed])
		for site in ["watchpost", "quarry"]:
			var pocket := int(m.sites[site]["pocket"])
			_check(by_pocket.has(pocket) and str(by_pocket[pocket]["kind"]) == "site", "world %d: the %s has its chest" % [seed_value, site])
			if by_pocket.has(pocket):
				var plain_most := roundi(float(LootPlan.COINS_MAX) * 1.3)
				_check(int(by_pocket[pocket]["coins"]) >= roundi(float(LootPlan.COINS_MIN) * LootPlan.RICH) and (by_pocket[pocket]["items"] as Array).size() == 2 and int(by_pocket[pocket]["memory"]) > roundi(float(LootPlan.MEMORY) * 1.3) and plain_most > 0,
					"world %d: and it is a richer one (%s)" % [seed_value, str(by_pocket[pocket])])
		var inner := plan.filter(func(c): return int(m.pockets[int(c["pocket"])].get("ring", 1)) == 1).size()
		_check(inner >= 6 and inner <= 30 and plan.size() >= 40 and plan.size() <= 100, "world %d: a sensible number of chests (%d in the inner ring, %d in all, for %d open places)" % [seed_value, inner, plan.size(), m.pockets.size()])
	print("      %d lands: %.1f chests a land (%s), %d of them in a tight spot; the slowest plan took %.1f ms" % [seeds, float(total) / float(seeds), str(kinds), tight, slowest])
	var mean := float(total) / float(seeds)
	_check(mean >= 60.0 and mean <= 80.0, "Darren, 24 November: about 60 to 80 chests in the whole Highlands (%.1f a land)" % mean)
	_check(slowest < 300.0, "the chests of a land are worked out quickly (%.1f ms at most, while the land is forged)" % slowest)


# --- A chest ---------------------------------------------------------------------------------

func _chest() -> void:
	var g = _game(424242)
	await _frames(5)
	var loot = g.loot
	var p = g.players[0]
	_check(loot.chests.size() == g.chest_plan.size() and loot.chests.size() > 5, "the land's chests stand on it (%d)" % loot.chests.size())
	var planned := LootPlan.make(WorldGen.make(424242), FoePlan.make(g.map))
	planned.append_array(g.crown_plan.get("chests", []))
	_check(str(g.chest_plan) == str(planned), "and they are the plan's (with the Scrapyard's two side rooms')")
	var purse = loot.purses[0]
	_check(purse.coins == 0 and purse.memory == 0 and purse.kept.is_empty(), "somebody new has no coins, no Memory and none of the Warhorn")
	var k := _kind(g, "first")
	var c: Dictionary = loot.chests[k]["plan"]
	var tile: Vector2i = c["tile"]
	_check(not g.foes.nav.is_free(tile), "the enemies' way-finding knows a chest stands there")
	g.foes.nav.things_changed(c["foot"])
	_check(not g.foes.nav.is_free(tile), "and still does after something near it is broken")
	_check(g.foes.nav.steps(Nav.middle_of(tile + Vector2i(-1, 0)), Nav.middle_of(tile + Vector2i(1, 0))) > 0, "and there is a way round it")
	# Far from it nothing is offered.
	await _frames(3)
	_check(not g.ui.prompts.any(func(pr): return str(pr["text"]) == "Open the chest"), "far from any chest there is nothing to open")
	await _before(g, p, k)
	await _frames(2)
	_check(p.interact_ready and g.ui.prompts.size() == 1 and str(g.ui.prompts[0]["text"]) == "Open the chest", "standing at a chest, it can be opened (%s)" % str(g.ui.prompts))
	# It stops you: walking up into it gets nowhere.
	var foot_y: float = (c["foot"] as Vector2).y * 2.0
	p.input.move = Vector2.UP
	await _frames(50)
	p.input.move = Vector2.ZERO
	_check(p.global_position.y > foot_y - 4.0, "a chest stops you (you are at %.0f, its foot is at %.0f)" % [p.global_position.y, foot_y])
	await _before(g, p, k)
	var bag: Bag = g.tools.bag_of(0)
	await _press(p, "interact_pressed")
	_check(int(loot.chests[k]["state"]) == 1 and loot.opened.has(int(c["id"])), "the interact button opens it")
	_check(purse.coins == int(c["coins"]) and purse.memory == int(c["memory"]), "its coins and Memory are yours at once (%d, %d)" % [purse.coins, purse.memory])
	var ok := true
	for it in c["items"]:
		if bag.count(str(it[0])) != int(it[1]):
			ok = false
	_check(ok, "and its bars are in the bag (%s)" % str(bag.data()))
	_check(not loot.flies.is_empty(), "what was in it is seen to come out")
	await _frames(3)
	_check(not p.interact_ready and g.ui.prompts.is_empty(), "an open chest is not offered again")
	_check(not loot.open(k, 0) and purse.coins == int(c["coins"]), "and cannot be opened twice")
	await _frames(20)
	_check((loot.chests[k]["sprite"] as Sprite2D).texture == loot._frame("chest", 3), "the lid is seen to open, a picture at a time")
	await _frames(120)
	_check(int(loot.chests[k]["state"]) == 2 and (loot.chests[k]["sprite"] as Sprite2D).texture == loot._frame("chest_empty") and loot.flies.is_empty(), "then it stands open and empty, and everything has flown to you")
	_check(g._world_now().get("chests") == [int(c["id"])], "the world knows which chest was opened")
	_check(g._character_now(0).get("coins") == purse.coins and g._character_now(0).get("memory") == purse.memory, "the character knows its coins and Memory")
	# The purse on the screen.
	var r: Rect2 = loot.purse_rect(0)
	_check(Rect2(0, 0, 640, 360).encloses(r.grow(4)) and r.position.x > 10.0 + 92.0, "the purse is drawn beside the health bar (%s)" % str(r))
	_check(not r.grow(4).intersects(g.tools.belt_rect(0).grow(4)), "clear of the tool belt")
	# A richer chest.
	var s := _kind(g, "site")
	var before: int = purse.coins
	_check(loot.open(s, 0) and purse.coins - before == int(loot.chests[s]["plan"]["coins"]) and bag.count("tin_bar") > 0 and bag.count("copper_bar") > 0, "a named place's chest holds both kinds of bar")
	_check(g._world_now().get("chests").size() == 2, "(two chests opened now)")
	await _leave(g)


func _two_players() -> void:
	var g = _game(424242, 2)
	await _frames(5)
	var loot = g.loot
	var k := _kind(g, "first")
	var c: Dictionary = loot.chests[k]["plan"]
	await _before(g, g.players[1], k)
	await _press(g.players[1], "interact_pressed")
	_check(int(loot.chests[k]["state"]) == 1, "the second player opens a chest")
	for i in 2:
		_check(loot.purses[i].coins == int(c["coins"]) and loot.purses[i].memory == int(c["memory"]) and g.tools.bag_of(i).count(str(c["items"][0][0])) == int(c["items"][0][1]), "player %d has their own full share of it" % (i + 1))
	var a: Rect2 = loot.purse_rect(0)
	var b: Rect2 = loot.purse_rect(1)
	_check(Rect2(0, 0, 640, 360).encloses(a.grow(4)) and Rect2(0, 0, 640, 360).encloses(b.grow(4)) and not a.grow(4).intersects(b.grow(4)) and b.position.x > 320.0, "each has a purse on their side of the screen (%s, %s)" % [str(a), str(b)])
	loot.give(1, "horn_bell", 1, g.players[1].global_position)
	loot.give(1, "horn_body", 1, g.players[1].global_position)
	loot.give(1, "horn_mouthpiece", 1, g.players[1].global_position)
	b = loot.purse_rect(1)
	_check(Rect2(0, 0, 640, 360).encloses(b.grow(4)) and not a.grow(4).intersects(b.grow(4)) and b.end.x <= 640.0 - 10.0 - 26.0 - 92.0, "with the whole Warhorn in it too (%s)" % str(b))
	await _leave(g)


func _bag_full() -> void:
	var g = _game(424242)
	await _frames(5)
	var loot = g.loot
	var p = g.players[0]
	var bag: Bag = g.tools.bag_of(0)
	_check(bag.add("stone", Bag.SLOTS * Bag.STACK) == Bag.SLOTS * Bag.STACK and bag.room("tin_bar") == 0, "(a bag full of stone)")
	var k := _kind(g, "site")
	var c: Dictionary = loot.chests[k]["plan"]
	var bars := 0
	for it in c["items"]:
		bars += int(it[1])
	await _before(g, p, k)
	await _press(p, "interact_pressed")
	_check(loot.purses[0].coins == int(c["coins"]) and loot.purses[0].memory == int(c["memory"]), "with a full bag, a chest's coins and Memory are still yours")
	var bars_lying := func(): return loot.lying.filter(func(l): return str(l["item"]).ends_with("_bar")).size()
	_check(int(bars_lying.call()) == bars and bag.count("tin_bar") == 0 and bag.count("copper_bar") == 0, "and its bars lie on the ground (%d of %d; %d things in all, with an accessory or a blank stone)" % [int(bars_lying.call()), bars, loot.lying.size()])
	var spread := true
	for l in loot.lying:
		for o in loot.lying:
			if l != o and (l["at"] as Vector2).distance_to(o["at"]) < 4.0:
				spread = false
		if (l["at"] as Vector2).distance_to(loot.mouth_of(k)) > 60.0:
			spread = false
	_check(spread, "each in a place of its own, near the chest")
	await _frames(90)
	_check(int(bars_lying.call()) == bars, "they stay there while there is no room")
	_check(bag.take("stone", Bag.STACK * 2), "(room is made)")
	# Walk over each of them.
	for l in loot.lying.duplicate():
		p.global_position = (l["at"] as Vector2) + Vector2(0, 6)
		await _frames(6)
	await _frames(40)
	_check(int(bars_lying.call()) == 0 and bag.count("tin_bar") + bag.count("copper_bar") == bars, "and are picked up by walking over them once there is (%s)" % str(bag.data().slice(18)))
	await _leave(g)


# --- Memory for work -------------------------------------------------------------------------

func _clear(m: LandMap, at: Vector2) -> bool:
	for t in m.things:
		if Painter.things.get(str(t["n"]), {}).has("solid") and (Vector2(float(t["x"]), float(t["y"])) * 2.0).distance_to(at) < 56.0:
			return false
	return true


func _face(m: LandMap, kind: int) -> Array:
	for r in range(6, 130):
		for j in range(-r, r + 1):
			for i in range(-r, r + 1):
				if maxi(absi(i), absi(j)) != r:
					continue
				var t := Vector2i(m.mouth.x + i, m.mouth.y + j)
				if m.kind(t.x, t.y) != kind or m.fixed(t.x, t.y):
					continue
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]:
					var s := t + d
					if m.walkable(s.x, s.y) and m.kind(s.x, s.y) != LandMap.WATER and _clear(m, (Vector2(s) + Vector2(0.5, 0.5)) * TILE):
						return [t, Vector2(-d)]
	return []


func _dig(g, p, kind: int, swings: int) -> void:
	var at: Array = _face(g.map, kind)
	p.global_position = (Vector2(at[0]) + Vector2(0.5, 0.5) - at[1]) * TILE
	p.input.stick_aim = at[1]
	p.input.move = Vector2.ZERO
	g.rig.snap()
	await _frames(4)
	g.land.settle()
	p.input.work_held = true
	await _frames((swings - 1) * SWING_TICKS + 16)
	p.input.work_held = false
	await _frames(SWING_TICKS + 2)


func _work() -> void:
	var g = _game(424242)
	await _frames(5)
	var p = g.players[0]
	var purse = g.loot.purses[0]
	await _dig(g, p, LandMap.ROCK, 3)
	_check(g.tools.bag_of(0).count("stone") == 1 and purse.memory == 0, "digging plain rock gives stone and no Memory")
	await _dig(g, p, LandMap.TIN, 4)
	_check(g.tools.bag_of(0).count("tin_ore") == 2 and purse.memory == int(Loot.WORK_MEMORY["tin_ore"]), "mining ore gives a little Memory (%d)" % purse.memory)
	await _dig(g, p, LandMap.COPPER, 4)
	_check(purse.memory == int(Loot.WORK_MEMORY["tin_ore"]) + int(Loot.WORK_MEMORY["copper_ore"]), "and so does copper (%d)" % purse.memory)
	await _leave(g)


# --- What enemies leave ----------------------------------------------------------------------

## Wakes the group whose leader is an elite of this kind and returns [the elite, an ordinary one of its group].
func _wake(g, kind: String) -> Array:
	var foes = g.foes
	var p = g.players[0]
	for i in foes.plan.size():
		var gr: Dictionary = foes.plan[i]
		if not (gr["members"] as Array).any(func(m): return str(m[0]) == kind and bool(m[1])):
			continue
		var home: Vector2 = Nav.middle_of(foes.nav.nearest_free(Nav.tile_of((gr["home"] as Vector2) * TILE), 6))
		p.global_position = home + Vector2(0, 24)
		g.rig.snap()
		await _wait(func(): return foes.packs.has(i), 120)
		if not foes.packs.has(i):
			return []
		var elite = null
		var other = null
		for e in foes.packs[i].members:
			if e.kind == kind and e.elite:
				elite = e
			elif not e.elite and other == null:
				other = e
		return [elite, other]
	return []


func _drops() -> void:
	var g = _game(424242, 1, true)
	await _frames(5)
	var loot = g.loot
	var p = g.players[0]
	var purse = loot.purses[0]
	p.unhurt = true
	Sim.seed_with(7)
	var pieces := 0
	var gift_coins := int(Loot.GIFT_COINS)
	Loot.GIFT_COINS = 0               # (an accessory the dice give twice would be coins too; that is tested in highlands_gear.gd)
	for kind in ["hound", "slinger", "scrap_brute"]:
		var pair: Array = await _wake(g, kind)
		_check(pair.size() == 2 and pair[0] != null and pair[1] != null, "(the elite %s and its group are on the land)" % kind)
		if pair.size() < 2 or pair[0] == null or pair[1] == null:
			continue
		var memory: int = purse.memory
		var coins: int = purse.coins
		var bars: int = g.tools.bag_of(0).count("tin_bar") + g.tools.bag_of(0).count("copper_bar")
		var other = pair[1]
		var other_kind := str(other.kind)
		other.take_hit(9999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
		await _frames(2)
		_check(purse.memory - memory == int(Loot.MEMORY_FOR[other_kind]) and purse.coins == coins, "a fallen %s leaves its Memory (%d) and nothing else" % [other_kind, purse.memory - memory])
		memory = purse.memory
		var piece := str(Loot.HORN[kind])
		_check(not purse.kept.has(piece), "(no %s yet)" % piece)
		pair[0].take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
		await _frames(2)
		pieces += 1
		_check(purse.memory - memory == int(Loot.ELITE_MEMORY), "the elite %s leaves an elite's Memory (%d)" % [kind, purse.memory - memory])
		var lo: int = g.gear.coins(0, int(Loot.ELITE_COINS_MIN)) if g.gear != null else int(Loot.ELITE_COINS_MIN)
		var hi: int = g.gear.coins(0, int(Loot.ELITE_COINS_MAX)) if g.gear != null else int(Loot.ELITE_COINS_MAX)
		var got_coins: int = purse.coins - coins
		_check(got_coins >= lo and got_coins <= hi, "coins as a chest would (%d; %d to %d, with a Lucky Copper worn or not)" % [got_coins, lo, hi])
		var got: int = g.tools.bag_of(0).count("tin_bar") + g.tools.bag_of(0).count("copper_bar") - bars
		_check(got >= int(Loot.ELITE_BARS_MIN) and got <= int(Loot.ELITE_BARS_MAX), "a few bars (%d)" % got)
		_check(purse.kept.has(piece) and purse.kept.size() == pieces, "and its piece of the Warhorn: %s" % piece)
		_check(loot.clock < loot.said_until and loot.said.contains("(%d of 3)" % pieces), "and the screen says so (\"%s\")" % loot.said)
		_check(g._character_now(0).get("kept").size() == pieces, "the character keeps it")
	Loot.GIFT_COINS = gift_coins
	# The same elite again (it comes back in time): no second piece. One that was called in: nothing at all.
	var again = Make.make("hound", true)
	again.set_meta("horn", true)
	g.world.add_child(again)
	again.global_position = p.global_position + Vector2(40, 0)
	var memory: int = purse.memory
	var said: float = loot.said_until
	loot.foe_died(again)
	_check(purse.kept.size() == pieces and purse.memory - memory == int(Loot.ELITE_MEMORY) and is_equal_approx(said, loot.said_until), "an elite that falls again gives no second piece")
	again.summoned = true
	memory = purse.memory
	var coins: int = purse.coins
	loot.foe_died(again)
	_check(purse.memory == memory and purse.coins == coins, "one that was called into the fight leaves nothing")
	again.queue_free()
	# The elite shaman carries no piece.
	var shaman = Make.make("shaman", true)
	g.world.add_child(shaman)
	coins = purse.coins
	loot.foe_died(shaman)
	_check(purse.kept.size() == pieces and purse.coins > coins, "the elite shaman leaves loot but no piece")
	shaman.queue_free()
	# Darren, 24 November: only the three world elites carry the pieces. Any other elite hound, slinger or brute
	# (the Scrapyard's, one made in the arena) leaves elite loot and no piece, even to somebody who lacks it.
	purse.kept.clear()
	for kind in ["hound", "slinger", "scrap_brute"]:
		var other = Make.make(kind, true)
		g.world.add_child(other)
		other.global_position = p.global_position + Vector2(40, 0)
		coins = purse.coins
		loot.foe_died(other)
		_check(purse.kept.is_empty() and purse.coins > coins, "an elite %s that is not the world's leaves loot and no piece" % kind)
		other.queue_free()
	# While the squad holds the mended horn, not even the world's three drop one; once it cracks, they do again.
	_check(g.crown != null, "(the land has Rattlecrown's crown)")
	if g.crown != null:
		var marked = Make.make("scrap_brute", true)
		marked.set_meta("horn", true)
		g.world.add_child(marked)
		marked.global_position = p.global_position + Vector2(40, 0)
		g.crown.horn = true
		loot.foe_died(marked)
		_check(purse.kept.is_empty(), "with the horn mended, the Quarry's brute drops no body")
		g.crown.horn = false
		loot.foe_died(marked)
		_check(purse.kept.has("horn_body"), "once it has cracked (he fell), the body drops again for a rematch")
		marked.queue_free()
	await _leave(g)


# --- Saved -----------------------------------------------------------------------------------

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
	var loot = g.loot
	var k := _kind(g, "first")
	var s := _kind(g, "site")
	var id := int(loot.chests[k]["plan"]["id"])
	loot.open(k, 0)
	loot.give(0, "horn_bell", 1, g.players[0].global_position)
	var coins: int = loot.purses[0].coins
	var memory: int = loot.purses[0].memory
	var bag_text := str(g.tools.bag_of(0).data())
	_check(g.save_now(), "(saved)")
	var on_disk := Save.read(Save.WORLDS, str(where["id"]))
	var me := Save.read(Save.CHARACTERS, str(who["id"]))
	_check(on_disk.get("chests") is Array and (on_disk["chests"] as Array).size() == 1 and int(on_disk["chests"][0]) == id, "the world's file holds the chest that was opened (%s)" % str(on_disk.get("chests")))
	_check(int(me.get("coins", -1)) == coins and int(me.get("memory", -1)) == memory and me.get("kept") == ["horn_bell"], "the character's file holds its coins, Memory and kept things (%s, %s, %s)" % [str(me.get("coins")), str(me.get("memory")), str(me.get("kept"))])
	await _leave(g)
	# Played again: the chest is open, the purse is as it was.
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, str(who["id"]))], Save.read(Save.WORLDS, str(where["id"])))
	await _frames(5)
	loot = g.loot
	_check(int(loot.chests[k]["state"]) == 2 and (loot.chests[k]["sprite"] as Sprite2D).texture == loot._frame("chest_empty") and not loot.open(k, 0), "played again, the opened chest stands open and empty")
	_check(int(loot.chests[s]["state"]) == 0, "and the others are shut")
	_check(loot.purses[0].coins == coins and loot.purses[0].memory == memory and loot.purses[0].kept.has("horn_bell") and loot.purses[0].kept.size() == 1 and str(g.tools.bag_of(0).data()) == bag_text, "the character has its coins, Memory, bars and the Warhorn's bell")
	var written: int = g.saves_written
	g.save_now()
	_check(g.saves_written == written, "nothing is written again while nothing has changed")
	# What a save might hold that makes no sense is passed over.
	loot.set_opened(["x", 99999, -3, null])
	_check(loot.opened.size() == 1, "chest numbers this land does not have are passed over")
	loot.set_purse_data(0, {"coins": "many", "memory": -5, "kept": ["crown", 3, "horn_body"]})
	_check(loot.purses[0].coins == coins and loot.purses[0].memory == 0 and loot.purses[0].kept.keys() == ["horn_body"], "and a purse that makes no sense is read as far as it does")
	await _leave(g)
	# A character from before version 44 (no purse in its file), and a world from before it (no chests).
	var old_me := Save.read(Save.CHARACTERS, str(who["id"]))
	for key in ["coins", "memory", "kept"]:
		old_me.erase(key)
	var old_world := Save.read(Save.WORLDS, str(where["id"]))
	old_world.erase("chests")
	g = _game(0, 1, false, [old_me], old_world)
	await _frames(5)
	_check(g.loot.purses[0].coins == 0 and g.loot.purses[0].memory == 0 and g.loot.opened.is_empty() and int(g.loot.chests[k]["state"]) == 0, "a character and a world saved before there were chests play on: no coins, every chest shut")
	_check(not g.relaid, "and the land is not laid out again for it")
	await _leave(g)
	# The pick screen shows a character's coins.
	var with_coins := Save.read(Save.CHARACTERS, str(who["id"]))
	_check(SavePick.bag_counts(with_coins).any(func(part): return str(part[0]) == "tin_bar"), "the pick screen lists the bars in a character's bag")
	Save.root = old_root


# --- Blank rune stones (version 55) ----------------------------------------------------------

func _blanks() -> void:
	var g = _game(424242, 2)
	await _frames(5)
	var loot = g.loot
	var hall = g.hall
	_check(loot.blank_cap() == 16, "the passive blanks a world gives: 12 solo and 4 more for a second player (%d)" % loot.blank_cap())
	var k := _kind(g, "first")
	var c: Dictionary = loot.chests[k]["plan"]
	c["blank"] = true
	_check(loot.open(k, 1), "(player two opens a chest with a passive blank in it)")
	_check(g.tools.bag_of(1).count("passive_blank") == 1 and g.tools.bag_of(0).count("passive_blank") == 0, "ONE stone, for whoever opened it (Claude's: it is meant to be handed round)")
	_check(loot.blanks_found == 1 and loot.said.contains("passive blank stone"), "the world counts it, and the screen says so (\"%s\")" % loot.said)
	_check(g._world_now().get("blanks") == 1, "(the world save keeps the count)")
	# Past the cap a chest's blank is simply not there.
	loot.blanks_found = loot.blank_cap()
	var k2 := _kind(g, "plain") if _kind(g, "plain") >= 0 else _kind(g, "site")
	loot.chests[k2]["plan"]["blank"] = true
	loot.open(k2, 0)
	_check(g.tools.bag_of(0).count("passive_blank") == 0 and loot.blanks_found == loot.blank_cap(), "once the world has given its share, no more")
	loot.blanks_found = 1
	# What a stone can become.
	_check(loot.infusions(1, "passive_blank").is_empty(), "somebody who can fit every rune already (a pick-screen character) has nothing to infuse")
	g.owned[1] = ["iron_broadsword", "wrapped_grip", "plain_pommel", "whirlwind", "leap", "ghostwield", "weak_point"]
	_check(g.builds[1].weapon() == "sword" and loot.infusions(1, "passive_blank") == ["shockwave", "shards"], "a passive stone: the sword's passives they cannot fit yet (%s)" % str(loot.infusions(1, "passive_blank")))
	_check(loot.infusions(1, "active_blank").is_empty(), "(they have all three of its actives)")
	_check(loot.infuse(1, "passive_blank", "leap") != "" and loot.infuse(1, "passive_blank", "pierce") != "", "it cannot become an active rune, or another weapon's")
	# At the forge.
	g.builds[1].changed.emit()
	loot.purses[1].memory = 0
	hall.open(1)
	var list: Array = hall.rows()
	_check(hall.BLANK_ROW in list and list.find(hall.BLANK_ROW) == list.find("Weapons and runes") - 1, "the forge has a row for blank stones while you carry one (%s)" % str(list))
	_check(str(list[hall.row]) == hall.BLANK_ROW, "and the screen opens on it when there is no Memory to give or point to spend")
	hall.confirm()
	_check(hall.view == "blanks", "it opens the blank stones")
	var rows: Array = hall.blank_rows()
	_check(rows.size() == 4 and str(rows[0]["rune"]) == "shockwave" and str(rows[2]["do"]) == "break" and str(rows[3]["do"]) == "give", "a row for each rune it could become, one to break it down, one to hand it over (%s)" % str(rows.map(func(r): return r["text"])))
	hall.blank_row = 1
	hall.confirm()
	_check((g.owned[1] as Array).has("shards") and g.tools.bag_of(1).count("passive_blank") == 0, "infused: Shards is theirs to fit, and the stone is gone")
	_check(hall.view == "hall" and not (hall.BLANK_ROW in hall.rows()), "with no stone left, back to the forge's rows, and the row is gone")
	hall.close()
	# Breaking one down.
	g.tools.bag_of(0).add("passive_blank", 1)
	g.tools.bag_of(0).add("active_blank", 1)
	var m0: int = loot.purses[0].memory
	_check(loot.break_down(0, "passive_blank") == Loot.BLANK_MEMORY and loot.purses[0].memory == m0 + Loot.BLANK_MEMORY, "a stone broken down: %d Memory to give" % Loot.BLANK_MEMORY)
	_check(loot.break_down(0, "passive_blank") == 0, "(one stone, once)")
	# Handing one over.
	_check(loot.hand_over(0, 1, "active_blank") == "" and g.tools.bag_of(0).count("active_blank") == 0 and g.tools.bag_of(1).count("active_blank") == 1, "a stone handed to a teammate is in their inventory")
	_check(loot.hand_over(0, 1, "active_blank") != "" and loot.hand_over(1, 1, "active_blank") != "", "(nothing to hand, or nobody to hand it to)")
	_check(loot.infusions(1, "active_blank").is_empty(), "(an active stone, for somebody with every active rune of their weapon: nothing to infuse)")
	hall.open(1)
	hall.row = hall.rows().find(hall.BLANK_ROW)
	hall.confirm()
	rows = hall.blank_rows()
	_check(rows.size() == 2 and str(rows[0]["do"]) == "break", "then only breaking down or handing over (%s)" % str(rows.map(func(r): return r["text"])))
	hall.blank_row = 1
	hall.confirm()
	_check(g.tools.bag_of(0).count("active_blank") == 1 and g.tools.bag_of(1).count("active_blank") == 0, "handed back from the forge's screen")
	hall.close()
	_check(g.forge_words(0) == "Go down to the forge: a blank stone to infuse" or g.levels.share(0) >= 1.0 or g.levels.points(0) > 0, "the cave mouth says there is a stone to infuse (\"%s\")" % g.forge_words(0))
	# The world save.
	var w: Dictionary = g._world_now()
	await _leave(g)
	var g2 = _game(424242, 2, false, [], w)
	await _frames(5)
	_check(g2.loot.blanks_found == 1, "a world played again remembers how many stones it has given")
	await _leave(g2)


# --- Pictures --------------------------------------------------------------------------------

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 640:
		img.resize(640, 360, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [shot_dir, name])
	print("saved %s/%s.png" % [shot_dir, name])


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var g = _game(shot_seed, 1, true)
	await _frames(10)
	var loot = g.loot
	var p = g.players[0]
	p.unhurt = true
	# A chest, opened a step at a time.
	var k := _kind(g, "first")
	await _before(g, p, k, -40.0)
	await _frames(30)
	await _snap("01_chest_shut")
	await _press(p, "interact_pressed")
	var marks := {3: "02_unlatched", 12: "03_lifting", 20: "04_thrown_open", 28: "05_loot_out", 42: "06_lying", 56: "07_flying", 64: "08_flying", 78: "09_arrived", 130: "10_empty"}
	for n in 131:
		await physics_frame
		if marks.has(n):
			await _snap(marks[n])
	# A richer chest (the Watchpost's or the Quarry's).
	var s := _kind(g, "site")
	g.foes.on = false
	await _before(g, p, s, 40.0)
	await _frames(30)
	await _snap("11_site_chest")
	await _press(p, "interact_pressed")
	for n in 60:
		await physics_frame
		if n == 30 or n == 48:
			await _snap("12_site_chest_loot_%d" % n)
	# A full bag: the bars lie there.
	var s2 := _kind(g, "site", 1)
	var full: Array = []
	for n in Bag.SLOTS:
		full.append(["stone", Bag.STACK])
	g.tools.bag_of(0).set_data(full)
	await _before(g, p, s2, -44.0)
	loot.open(s2, 0)
	await _frames(100)
	await _snap("13_bag_full_bars_lie")
	g.tools.bag_of(0).set_data([["stone", 12], ["wood", 6], ["tin_bar", 3], ["copper_bar", 2]])
	loot.lying.clear()
	# An elite falls.
	g.foes.on = true
	var pair: Array = await _wake(g, "hound")
	if pair.size() == 2 and pair[0] != null:
		for e in g.foes.all():
			e.stun_time = 99.0
		p.global_position = pair[0].global_position + Vector2(-60, 10)
		g.rig.snap()
		await _frames(20)
		g.land.settle()
		await _snap("14_elite_hound")
		pair[0].take_hit(pair[0].hp, Vector2.RIGHT, 0.0, false, Color.WHITE)
		for n in 70:
			await physics_frame
			if n == 16 or n == 30 or n == 44 or n == 69:
				await _snap("15_elite_falls_%d" % n)
	# The whole Warhorn in the purse.
	loot.give(0, "horn_body", 1, p.global_position)
	loot.give(0, "horn_mouthpiece", 1, p.global_position)
	await _frames(80)
	await _snap("16_whole_warhorn")
	# A thrown pebble and the elite's rock, over their shadows.
	g.foes.on = false
	for e in g.foes.all():
		e.queue_free()
	p.global_position = g.map.spawn * TILE + Vector2(0, 60)
	g.rig.snap()
	await _frames(20)
	g.land.settle()
	for kind in ["pebble", "rock"]:
		var r := Rock.new()
		r.kind = kind
		r.from = p.global_position + Vector2(-190, -30)
		r.to = p.global_position + Vector2(40, 6)
		r.flight = 1.0
		r.damage = 0.0
		g.world.add_child(r)
		for n in 58:
			await physics_frame
			if n == 8 or n == 28 or n == 44 or n == 56:
				await _snap("17_%s_shadow_%02d" % [kind, n])
		await _frames(30)
	# Two players, each with their purse.
	await _leave(g)
	g = _game(shot_seed, 2)
	await _frames(10)
	k = _kind(g, "first")
	await _before(g, g.players[0], k, -40.0)
	g.players[1].global_position = g.players[0].global_position + Vector2(80, 6)
	g.loot.open(k, 0)
	g.loot.give(1, "horn_bell", 1, g.players[1].global_position)
	await _frames(26)
	await _snap("18_two_players_loot_out")
	await _frames(100)
	await _snap("19_two_players_purses")
	await _leave(g)
