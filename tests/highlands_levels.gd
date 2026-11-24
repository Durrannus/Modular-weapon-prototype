extends SceneTree
## Memory, the forge's levels, the role trees and what falling costs (version 45). Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands_levels.gd
##
## With shots=/some/folder/ (needs a window, so leave out --headless) it saves 640x360 frames instead: the Memory
## bar, the forge's screen, a level gained, the role trees, the four signature perks at work, and a fall.
## "seed=123456" picks the world.

const PlayerInput := preload("res://scripts/player_input.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const Levels := preload("res://scripts/highlands/levels.gd")
const MemoryCount := preload("res://tools/memory_count.gd")
const Perks := preload("res://scripts/highlands/perks.gd")
const Loot := preload("res://scripts/highlands/loot.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")
const Make := preload("res://scripts/foes/make.gd")
const Rock := preload("res://scripts/foes/rock.gd")
const Hound := preload("res://scripts/foes/hound.gd")
const ScrapBrute := preload("res://scripts/foes/scrap_brute.gd")
const Slinger := preload("res://scripts/foes/slinger.gd")
const Guardian := preload("res://scripts/cave/guardian.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Save := preload("res://scripts/save.gd")
const Sim := preload("res://scripts/sim.gd")
const SavePick := preload("res://scripts/ui/save_pick.gd")
const TILE := 32.0
const ROOT := "user://test_levels_saves"

var fails := 0
var checks := 0
var shot_dir := ""
var shot_seed := 424242


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shot_dir = a.substr(6)
		elif a.begins_with("seed="):
			shot_seed = int(a.substr(5))
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
	_the_trees()
	await _forge()
	await _two_players()
	await _learning()
	await _falling()
	await _challenge()
	await _punish()
	await _kindle()
	await _ore_sense()
	await _screens()
	await _saved()
	print("%s  levelling: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
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
	paused = false
	g.queue_free()
	await _frames(3)


## An enemy of this kind standing still beside a player, with health to spare.
func _foe(g, kind: String, at: Vector2, elite := false):
	var e = Make.make(kind, elite)
	e.position = at
	g.world.add_child(e)
	e.max_hp = 99999.0
	e.hp = 99999.0
	return e


func _still(p) -> void:
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.hp = p.max_hp
	p.invuln = 0.0
	p.unhurt = false
	p.hurt_vel = Vector2.ZERO


## Holds the attack button, aimed at an enemy, until `until` says so (a whole chain, to its finisher, takes about
## a second and a half).
func _fight(p, e, until: Callable, most := 360) -> int:
	p.input.stick_aim = (e.global_position - p.global_position).normalized()
	p.input.attack_held = true
	var n := await _wait(until, most)
	p.input.attack_held = false
	await _frames(2)
	return n


# --- The pictures are there ---------------------------------------------------------------

func _art() -> void:
	for name in ["memory_frame", "memory_fill", "memory_empty", "level_badge", "memory_marker", "memory_marker_take", "level_up",
			"challenged", "open", "spark", "spark_fade", "spark_take", "shimmer_tin", "shimmer_copper", "shimmer_chest",
			"emblem_warden", "emblem_striker", "emblem_mender", "emblem_delver"]:
		_check(not ItemArt.find(name).is_empty(), "the art has \"%s\"" % name)
	_check(ItemArt.size("memory_frame") == Vector2(92, 9) and ItemArt.size("memory_fill") == Vector2(80, 4) and Levels.BAR_DROP == 8.0 and ItemArt.size("level_badge") == Vector2(15, 13), "the Memory bar and the roundel are the sizes the screen is laid out for")
	_check(ItemArt.size("memory_marker") == Vector2(16, 34) and ItemArt.origin("memory_marker") == Vector2(8, 31), "the marker stands on its origin")
	_check(ItemArt.size("challenged") == Vector2(24, 12) and ItemArt.origin("challenged") == Vector2(12, 11) and ItemArt.size("open") == Vector2(19, 18), "the marks over an enemy's head are measured a frame at a time")
	_check(ItemArt.size("no_such_thing") == Vector2.ZERO and ItemArt.origin("no_such_thing") == Vector2.ZERO, "a picture there is not has no size")
	# Still what stood in the bag and the purse before.
	_check(ItemArt.size("memory_mote") == Vector2(7, 7) and not ItemArt.find("item_tin_ore").is_empty(), "the older sheets are still read")


# --- The trees, as the Bible has them -----------------------------------------------------

func _the_trees() -> void:
	_check(Perks.TREES == ["warden", "striker", "mender", "delver"], "four trees: Warden, Striker, Mender, Delver")
	var all := {}
	for tree in Perks.TREES:
		var list: Array = Perks.TREE[tree]
		_check(list.size() == 8, "the %s tree has eight perks" % tree)
		for k in list.size():
			var id := str(list[k])
			_check(Perks.known(id) and Perks.name_of(id) != id and Perks.text_of(id).length() > 20 and not all.has(id), "%s has a name and its words" % id)
			_check(Perks.tree_of(id) == tree and Perks.row_of(id) == int(Perks.ROWS[k]), "%s is in its tree, in row %d" % [id, int(Perks.ROWS[k])])
			all[id] = true
	_check(all.size() == 32 and Perks.PERKS.size() == 32, "32 perks in all")
	_check(Perks.BUILT == ["challenge", "punish", "kindle", "ore_sense"], "the four signature perks are built")
	for id in Perks.BUILT:
		_check(Perks.row_of(str(id)) == 0, "%s is its tree's signature" % id)
	_check(Perks.row_of("forge_prophet") == Perks.CAPSTONE and Perks.row_of("unbroken") == Perks.CAPSTONE and Perks.row_of("execution") == Perks.CAPSTONE and Perks.row_of("rekindle") == Perks.CAPSTONE, "each tree ends in its capstone")
	_check(Perks.text_of("forge_prophet").begins_with("Darren's idea."), "the Delver's capstone is Darren's own")
	# What can be learnt, and why not.
	_check(Perks.why_not("challenge", [], 1) == "", "a signature perk can be learnt with a point")
	_check(Perks.why_not("challenge", [], 0).begins_with("No point"), "not without one")
	_check(Perks.why_not("challenge", ["challenge"], 3) == "You have learnt this.", "not twice")
	_check(Perks.why_not("nothing", [], 3) == "There is no such perk." and not Perks.known(7) and not Perks.known(null), "not a perk there is not")
	_check(Perks.why_not("unmoved", ["challenge"], 3).begins_with("Not built yet") and Perks.why_not("unbroken", [], 9).begins_with("Not built yet"), "a perk that is not built yet says so, and cannot be bought")
	# The shape of a tree, which holds for the perks still to come (tried as if every perk were built).
	_check(Perks.why_not("unmoved", [], 3, true) == "Needs Challenge first.", "row 2 needs the signature")
	_check(Perks.why_not("unmoved", ["challenge"], 3, true) == "", "and opens with it")
	_check(Perks.why_not("payback", ["challenge"], 3, true) == "Needs one perk from the row above first." and Perks.why_not("payback", ["challenge", "bodyguard"], 3, true) == "", "a row opens once you own one perk from the row above")
	_check(Perks.why_not("payback", ["challenge", "close_call", "punish"], 3, true) != "", "a perk of another tree does not open it")
	var five := ["challenge", "unmoved", "bodyguard", "payback", "plate"]
	_check(Perks.why_not("unbroken", five, 3, true) == "Needs 6 points in this tree first (you have 5).", "the capstone needs 6 points in its tree")
	var six := five + ["tempered"]
	_check(Perks.why_not("unbroken", six, 3, true) == "", "and can be learnt with them")
	_check(Perks.why_not("execution", six + ["unbroken", "punish", "close_call", "flank", "keep_the_chain", "sharp", "kill_rush"], 3, true) == "Only one capstone is yours, and you have Unbroken.", "one capstone per character")
	_check(Perks.why_not("unbroken", six, 0, true).begins_with("No point"), "and every perk costs a point")
	_check(Perks.clean(["punish", "punish", 3, "nothing", null, "kindle"]) == ["punish", "kindle"] and Perks.clean("x") == [], "a saved list keeps the perks there are, each once, in order")
	_check(Perks.awake(["punish", "kindle", "ore_sense"], 2) == ["punish", "kindle"] and Perks.awake(["punish"], 0) == [] and Perks.awake(["punish"], 9) == ["punish"], "the first so many perks are awake as the forge has levels")
	_check(Perks.in_tree(["punish", "kindle", "flank"], "striker") == 2 and Perks.capstone_in(["punish", "rekindle"]) == "rekindle" and Perks.capstone_in(["punish"]) == "", "points in a tree and the capstone are counted")


# --- The forge's levels -------------------------------------------------------------------

func _forge() -> void:
	_check(is_equal_approx(Levels.need(0), 100.0) and is_equal_approx(Levels.need(1), 400.0) and is_equal_approx(Levels.need(4), 1300.0), "level 1 needs 100 Memory, and each level 300 more")
	_check(Levels.need(Levels.LEVEL_CAP) == 0.0 and Levels.LEVEL_CAP == 20, "level 20 is the last")
	var to_five := 0.0
	for n in 5:
		to_five += Levels.need(n)
	_check(is_equal_approx(to_five, 3500.0), "level 5 takes 3500 Memory in all")
	# The curve against the land (version 51): what lies on the way to Rattlecrown (tools/memory_count.gd).
	for w in [424242, 432161]:
		var sums: Dictionary = MemoryCount.world(w)
		var usual := MemoryCount.level_of(float(sums["usual"]))
		var straight := MemoryCount.level_of(float(sums["straight"]))
		_check(usual >= 4 and usual <= 6, "land %d: a usual run to Rattlecrown comes to about level 5 (%d Memory, level %d)" % [w, roundi(float(sums["usual"])), usual])
		_check(straight >= 3 and straight < usual, "land %d: going straight there comes to less (%d Memory, level %d)" % [w, roundi(float(sums["straight"])), straight])
		_check(MemoryCount.level_of(float(sums["all"])) < Levels.LEVEL_CAP - 5, "land %d: clearing the whole land once leaves levels for later zones (level %d)" % [w, MemoryCount.level_of(float(sums["all"]))])
	var g = _game(424242)
	await _frames(5)
	var lv = g.levels
	var purse = g.loot.purses[0]
	var p = g.players[0]
	_check(lv.level == 0 and lv.banked == 0.0 and lv.points(0) == 0 and (lv.perks[0] as Array).is_empty(), "a new world's squad is level 0, with nothing learnt")
	_check(p.roles == lv, "the player's perks hook into it")
	_check(lv.share(0) == 0.0 and lv.carried(0) == 0, "nothing carried: an empty bar")
	g.loot.give(0, "memory", 60, p.global_position)
	_check(lv.carried(0) == 60 and is_equal_approx(lv.share(0), 0.6), "60 of the 100 it needs: the bar is six tenths full")
	_check(lv.meter() == [0, 100], "the forge's meter reads 0 of 100")
	var got: Dictionary = lv.pour(0)
	_check(int(got["poured"]) == 60 and int(got["levels"]) == 0 and purse.memory == 0 and is_equal_approx(lv.banked, 60.0) and lv.level == 0, "poured in: the forge holds it, and you carry none")
	_check(lv.meter() == [60, 100] and is_equal_approx(lv.each_still(), 40.0), "the meter reads 60 of 100: 40 more")
	g.loot.give(0, "memory", 20, p.global_position)
	_check(is_equal_approx(lv.share(0), 0.5), "your bar is measured against what the forge still needs (20 of 40)")
	await _frames(2)
	_check(not bool(lv.was_full[0]), "(not full yet)")
	g.loot.give(0, "memory", 30, p.global_position)
	await _frames(2)
	_check(lv.share(0) == 1.0 and bool(lv.was_full[0]), "carrying enough for the level fills the bar")
	_check(g.forge_words(0).contains("enough for a level"), "and the cave mouth says so (\"%s\")" % g.forge_words(0))
	got = lv.pour(0)
	_check(int(got["levels"]) == 1 and int(got["from"]) == 0 and lv.level == 1 and is_equal_approx(lv.banked, 10.0) and purse.memory == 0, "the meter fills: the squad is level 1, and what was over is kept towards level 2")
	_check(lv.points(0) == 1 and lv.meter() == [10, 400], "a point to spend, and the meter reads 10 of 400")
	_check(g.loot.clock < g.loot.said_until and g.loot.said.contains("level 1"), "the screen says so (\"%s\")" % g.loot.said)
	_check(lv.rises.size() == 1, "and the level is seen to land on the player")
	_check(g.forge_words(0).contains("1 point to spend"), "the cave mouth says there is a point to spend (\"%s\")" % g.forge_words(0))
	_check(Levels.line_for(1) == Levels.FORGE_LINES[0] and Levels.line_for(6) == Levels.FORGE_LINES[5] and Levels.line_for(7) == Levels.FORGE_LINE_LATER and Levels.line_for(0) == Levels.FORGE_LINE_LATER, "the forge has a line for each of its first levels")
	# One pour can be worth several levels.
	g.loot.give(0, "memory", 390 + 700 + 50, p.global_position)
	got = lv.pour(0)
	_check(int(got["levels"]) == 2 and lv.level == 3 and is_equal_approx(lv.banked, 50.0) and lv.points(0) == 3, "a big pour is worth every level it fills (level %d, %.0f over)" % [lv.level, lv.banked])
	_check(lv.pour(0) == {"poured": 0, "levels": 0, "from": 3, "was": 50.0 / 1000.0}, "pouring nothing does nothing")
	# The last level: nothing more is taken.
	lv.level = Levels.LEVEL_CAP - 1
	lv.banked = 0.0
	g.loot.give(0, "memory", int(Levels.need(lv.level)) + 77, p.global_position)
	got = lv.pour(0)
	_check(lv.level == Levels.LEVEL_CAP and lv.banked == 0.0 and purse.memory == 77 and int(got["poured"]) == int(Levels.need(Levels.LEVEL_CAP - 1)), "at the last level, what is over comes back to you (%d)" % purse.memory)
	_check(int(lv.pour(0)["poured"]) == 0 and purse.memory == 77 and lv.share(0) == 0.0 and lv.meter() == [0, 0], "and the forge takes no more")
	# The bar on the screen.
	_check(is_equal_approx(g.hud.under_bar, Levels.BAR_DROP), "the health bar's neighbours make room for the Memory bar")
	var bar := Rect2(lv.bar_at(0), Vector2(92, 8))
	_check(bar.position.x == 10.0 and bar.position.y >= 7.0 + 11.0 and not bar.intersects(g.loot.purse_rect(0)), "the Memory bar is under the health bar, clear of the purse")
	_check(not Rect2(313, 4, 15, 13).intersects(Rect2(0, Highlands.NOTE_Y, 640, 14)), "the word \"Saved\" is under the squad's level, not on it")
	await _leave(g)


func _two_players() -> void:
	var g = _game(424242, 2)
	await _frames(5)
	var lv = g.levels
	_check(lv.squad() == 2 and lv.meter() == [0, 200], "with two players the forge needs twice as much: each one's share")
	g.loot.give(0, "memory", 100, g.players[0].global_position)
	g.loot.give(1, "memory", 40, g.players[1].global_position)
	_check(lv.share(0) == 1.0 and is_equal_approx(lv.share(1), 0.4), "each bar is measured against that player's own share")
	var got: Dictionary = lv.pour(0)
	_check(int(got["levels"]) == 0 and lv.level == 0 and lv.meter() == [100, 200], "one player's whole share fills half the meter")
	_check(is_equal_approx(lv.each_still(), 50.0) and is_equal_approx(lv.share(1), 0.8), "what is still needed is shared out again (50 from each)")
	g.loot.give(1, "memory", 60, g.players[1].global_position)
	got = lv.pour(1)
	_check(int(got["levels"]) == 1 and lv.level == 1 and lv.banked == 0.0, "the second player's share reaches the level")
	_check(lv.points(0) == 1 and lv.points(1) == 1, "everybody levels up at the same time: a point each")
	_check(lv.rises.size() == 2, "and it lands on both of them")
	_check(lv.bar_at(1).x == 640.0 - 10.0 - 92.0 and lv.bar_at(0).x == 36.0, "each bar is under its own health bar")
	_check(not Rect2(lv.bar_at(0), Vector2(92, 8)).intersects(g.loot.purse_rect(0)) and not Rect2(lv.bar_at(1), Vector2(92, 8)).intersects(g.loot.purse_rect(1)), "clear of both purses")
	await _leave(g)


# --- Points and perks ---------------------------------------------------------------------

func _learning() -> void:
	var g = _game(424242)
	await _frames(5)
	var lv = g.levels
	var purse = g.loot.purses[0]
	_check(lv.learn(0, "challenge").begins_with("No point"), "level 0: nothing can be learnt")
	lv.level = 2
	_check(lv.points(0) == 2 and lv.learn(0, "punish") == "" and lv.perks[0] == ["punish"] and lv.points(0) == 1, "a point buys a signature perk")
	_check(lv.has(0, "punish") and lv.has_p(g.players[0], "punish") and lv.any_has("punish") and not lv.has(0, "kindle"), "and it is awake")
	_check(lv.learn(0, "punish") == "You have learnt this." and lv.learn(0, "close_call").begins_with("Not built yet") and lv.points(0) == 1, "what cannot be learnt costs nothing")
	_check(lv.learn(0, "kindle") == "" and lv.points(0) == 0 and lv.learn(0, "ore_sense").begins_with("No point"), "you can take the signatures of two trees, a point each, until the points are spent")
	_check(g._character_now(0).get("perks") == ["punish", "kindle"], "the character knows its perks")
	# Forgetting costs Memory you carry.
	_check(lv.forget_cost(0) == 2 * int(Levels.FORGET_COST), "forgetting two perks costs twice the price of one (%d)" % lv.forget_cost(0))
	_check(not lv.forget(0) and (lv.perks[0] as Array).size() == 2, "without the Memory, nothing is forgotten")
	lv.banked = 150.0
	g.loot.give(0, "memory", 39, g.players[0].global_position)
	_check(not lv.forget(0) and is_equal_approx(lv.banked, 150.0), "what the forge holds does not pay for it")
	g.loot.give(0, "memory", 11, g.players[0].global_position)
	_check(lv.forget(0) and (lv.perks[0] as Array).is_empty() and purse.memory == 10 and lv.points(0) == 2, "with it, every perk is forgotten and the points are yours again (%d Memory left)" % purse.memory)
	_check(not lv.forget(0) and purse.memory == 10, "with nothing learnt there is nothing to forget")
	# A character who has learnt more than this world's forge has levels: the first so many are awake.
	lv.perks[0] = ["ore_sense", "punish", "kindle"]
	lv.level = 1
	_check(lv.awake(0) == ["ore_sense"] and lv.has(0, "ore_sense") and not lv.has(0, "punish") and lv.points(0) == 0, "in a world of a lower level the first perks you learnt are awake, and the rest sleep")
	lv.level = 3
	_check(lv.has(0, "punish") and lv.has(0, "kindle"), "and wake as that world's forge gains levels")
	_check(not lv.has(5, "punish") and lv.points(-1) == 0 and lv.learn(9, "punish") != "", "(nobody is nobody)")
	await _leave(g)


# --- Falling ------------------------------------------------------------------------------

func _falling() -> void:
	var g = _game(424242)
	await _frames(5)
	var lv = g.levels
	var p = g.players[0]
	var purse = g.loot.purses[0]
	var home: Vector2 = p.spawn_point
	# With nothing to lose, nothing is lost and nothing is said.
	_still(p)
	p.global_position = home + Vector2(120, 40)
	await _frames(2)
	p.take_damage(9999.0)
	await _frames(2)
	_check(lv.markers.is_empty() and purse.coins == 0 and purse.memory == 0 and g.loot.clock >= g.loot.said_until, "falling with nothing costs nothing")
	_check(p.global_position.distance_to(home) < 4.0 and p.hp == p.max_hp, "you wake at the cave mouth")
	# With Memory and coins.
	_still(p)
	g.loot.give(0, "memory", 81, p.global_position)
	g.loot.give(0, "coins", 37, p.global_position)
	p.global_position = home + Vector2(150, 60)
	await _frames(2)
	_still(p)
	var there: Vector2 = p.global_position
	p.take_damage(9999.0)
	await _frames(2)
	_check(purse.memory == 41 and purse.coins == 34, "falling: half your carried Memory stays behind (40 of 81), and a tenth of your coins is gone (3 of 37)")
	_check(lv.markers.size() == 1 and int(lv.markers[0]["memory"]) == 40 and (lv.markers[0]["at"] as Vector2).distance_to(there) < 6.0, "the Memory waits where you fell")
	_check(g.loot.clock < g.loot.said_until and g.loot.said.contains("40 Memory") and g.loot.said.contains("3 coins"), "the screen says what it cost (\"%s\")" % g.loot.said)
	_check(g._world_now().get("markers") == [[roundi(there.x), roundi(there.y), 40]], "the world keeps the marker")
	# Banked Memory is safe.
	lv.banked = 55.0
	_still(p)
	p.global_position = home + Vector2(-140, 50)
	await _frames(2)
	_still(p)
	p.take_damage(9999.0)
	await _frames(2)
	_check(is_equal_approx(lv.banked, 55.0) and purse.memory == 21 and lv.markers.size() == 2 and int(lv.markers[1]["memory"]) == 20, "what the forge holds is never lost; a second fall leaves a second marker")
	# Walk over it: it is yours again.
	_still(p)
	await _frames(int(Levels.MARKER_ARMS * 60.0))
	p.global_position = there + Vector2(0, -6)
	await _frames(3)
	_check(lv.markers.size() == 1 and purse.memory == 61, "walking over a marker gives its Memory back (%d)" % purse.memory)
	_check(lv.takes.size() == 1, "(and it is seen to go)")
	_check(g.loot.said.contains("40 Memory back"), "and the screen says so (\"%s\")" % g.loot.said)
	# A marker that has just been left cannot be taken at once.
	lv._marker(p.global_position, 5)
	await _frames(30)
	_check(lv.markers.size() == 2, "a marker cannot be taken in its first moments")
	await _frames(int(Levels.MARKER_ARMS * 60.0) - 20)
	_check(lv.markers.size() == 1 and purse.memory == 66, "and can after them")
	await _leave(g)
	# Anybody may take it.
	g = _game(424242, 2)
	await _frames(5)
	lv = g.levels
	var a = g.players[0]
	var b = g.players[1]
	g.loot.give(1, "memory", 30, b.global_position)
	_still(b)
	b.global_position = b.spawn_point + Vector2(160, 70)
	await _frames(2)
	_still(b)
	var fell_at: Vector2 = b.global_position
	b.take_damage(9999.0)
	await _frames(2)
	_check(lv.markers.size() == 1 and g.loot.purses[1].memory == 15 and g.loot.purses[0].memory == 0 and g.loot.said.begins_with("Player 2 fell"), "player 2 falls: their Memory waits (\"%s\")" % g.loot.said)
	await _frames(int(Levels.MARKER_ARMS * 60.0))
	a.global_position = fell_at
	await _frames(3)
	_check(lv.markers.is_empty() and g.loot.purses[0].memory == 15 and g.loot.purses[1].memory == 15, "a teammate can collect it")
	await _leave(g)


# --- Challenge (Warden) -------------------------------------------------------------------

func _challenge() -> void:
	var g = _game(424242, 2)
	await _frames(5)
	var lv = g.levels
	var a = g.players[0]
	var b = g.players[1]
	a.unhurt = true
	b.unhurt = true
	var home: Vector2 = a.spawn_point
	a.global_position = home + Vector2(-80, 50)
	b.global_position = home + Vector2(120, 50)
	var e = _foe(g, "hound", a.global_position + Vector2(44, 0))
	e.stun_time = 99.0
	e.knock_resist = 0.0
	await _frames(3)
	# Without the perk, a finisher is only a finisher.
	var n := await _fight(a, e, func(): return e.hp < 99999.0 - 1.0 and a.current_step == a._steps().size() - 1, 240)
	await _frames(40)
	_check(n >= 0 and e.challenge_left == 0.0 and e.challenged_by == null, "without Challenge, a finisher Challenges nobody")
	lv.level = 1
	lv.perks[0] = ["challenge"]
	a._reset_combo()
	await _frames(30)
	n = await _fight(a, e, func(): return e.challenge_left > 0.0, 300)
	_check(n >= 0 and e.challenged_by == a, "the Warden's finisher Challenges the enemy it hits")
	_check(e.challenge_left > Levels.CHALLENGE_TIME - 0.2 and e.challenge_left <= Levels.CHALLENGE_TIME, "for 5 s (%.2f)" % e.challenge_left)
	# It turns on the Warden, whoever is nearer.
	e.stun_time = 0.0
	e.rest = 99.0
	e.global_position = b.global_position + Vector2(50, 0)
	await _frames(3)
	_check(e.target == a, "a Challenged enemy is after the player who Challenged it, though another is nearer")
	# Its hits on the Warden do a quarter less.
	a.unhurt = false
	b.unhurt = false
	_still(a)
	_still(b)
	a.take_damage(20.0, Vector2.INF, e)
	b.take_damage(20.0, Vector2.INF, e)
	_check(is_equal_approx(a.max_hp - a.hp, 15.0) and is_equal_approx(b.max_hp - b.hp, 20.0), "its hits on the challenger do a quarter less (15), on anybody else what they did (20)")
	var other = _foe(g, "hound", b.global_position + Vector2(300, 0))
	other.stun_time = 99.0
	_still(a)
	a.take_damage(20.0, Vector2.INF, other)
	_check(is_equal_approx(a.max_hp - a.hp, 20.0), "an enemy that is not Challenged does the Warden what it always did")
	a.unhurt = true
	b.unhurt = true
	# It wears off.
	e.challenge_left = 0.05
	await _frames(6)
	_check(e.challenge_left == 0.0 and e.target == b, "when it wears off, the enemy goes back to whoever is nearest")
	_still(a)
	a.unhurt = false
	a.take_damage(20.0, Vector2.INF, e)
	_check(is_equal_approx(a.max_hp - a.hp, 20.0), "and hits as hard as ever")
	a.unhurt = true
	# A fallen challenger is no target.
	e.challenge(a, 5.0)
	a.is_down = true
	await _frames(3)
	_check(e.challenge_left == 0.0 and e.target == b, "the Challenge ends if the challenger is down")
	a.is_down = false
	# A boss turns for 3 s, then cannot be Challenged again for 10 s.
	var boss = Guardian.new()
	boss.team = 2
	boss.position = home + Vector2(0, 260)
	g.world.add_child(boss)
	await _frames(2)
	_check(boss.is_boss() and not e.is_boss(), "(the forge guardian is a boss)")
	lv.finisher(a, [boss])
	_check(boss.challenged_by == a and is_equal_approx(boss.challenge_left, Levels.CHALLENGE_BOSS_TIME), "a boss turns for 3 s")
	_check(is_equal_approx(boss.challenge_rest, Levels.CHALLENGE_BOSS_TIME + Levels.CHALLENGE_BOSS_REST), "(and then rests)")
	boss.challenge_left = 0.0
	boss.challenged_by = null
	lv.finisher(a, [boss])
	_check(boss.challenge_left == 0.0 and boss.challenged_by == null, "and then cannot be Challenged again for 10 s")
	boss.challenge_rest = 0.0
	lv.finisher(a, [boss])
	_check(boss.challenge_left > 0.0, "after that it can")
	boss.queue_free()
	# A sleeping perk does nothing.
	lv.level = 0
	e.challenge_left = 0.0
	e.challenged_by = null
	lv.finisher(a, [e])
	_check(e.challenge_left == 0.0, "a perk that is asleep in this world does nothing")
	await _leave(g)


# --- Punish (Striker) ---------------------------------------------------------------------

func _punish() -> void:
	var g = _game(424242)
	await _frames(5)
	var lv = g.levels
	var p = g.players[0]
	var home: Vector2 = p.spawn_point
	p.global_position = home + Vector2(0, 60)
	p.unhurt = true
	await _frames(3)
	_check(not Enemy.show_open, "nobody has Punish: enemies do not show that they are Open")
	# What Open is: recovering from an attack that hit nobody, stunned, or reeling.
	var h = _foe(g, "hound", p.global_position + Vector2(260, 0))
	h.rest = 99.0
	await _frames(2)
	_check(not h.is_open(), "an enemy going about its business is not Open")
	h.facing = Vector2.DOWN
	h._set_mode("crouch", 0.05)
	await _wait(func(): return h.mode == "recover", 120)
	_check(h.mode == "recover" and h.is_open() and is_equal_approx(h.open_left, Hound.RECOVER_TIME), "a hound whose lunge bit nobody is Open while it gathers itself (%.2f s)" % h.open_left)
	await _wait(func(): return h.mode != "recover", 90)
	await _frames(2)
	_check(not h.is_open(), "and not after")
	# A lunge that bites is no opening.
	p.unhurt = false
	_still(p)
	h.global_position = p.global_position + Vector2(60, 0)
	h.rest = 0.0
	await _wait(func(): return h.mode == "lunge", 240)
	await _wait(func(): return h.mode == "recover", 120)
	_check(p.hp < p.max_hp and not h.is_open(), "a lunge that bit somebody leaves it no more Open than before")
	p.unhurt = true
	h.queue_free()
	# A slinger whose pebble lands on nobody.
	var s = _foe(g, "slinger", p.global_position + Vector2(300, 0))
	s.stun_time = 0.0
	var r := Rock.new()
	r.from = s.global_position
	r.to = p.global_position + Vector2(0, 200)
	r.flight = 0.1
	r.by = s
	g.world.add_child(r)
	await _frames(10)
	_check(s.is_open() and s.open_left > Slinger.MISS_OPEN - 0.2, "a slinger whose pebble landed on nobody is Open for a moment (%.2f s)" % s.open_left)
	s.open_left = 0.0
	p.unhurt = false
	_still(p)
	r = Rock.new()
	r.from = s.global_position
	r.to = p.global_position
	r.flight = 0.1
	r.by = s
	g.world.add_child(r)
	await _frames(10)
	_check(p.hp < p.max_hp and not s.is_open(), "one that hit is not")
	p.unhurt = true
	s.queue_free()
	# A stunned enemy is Open too.
	var e = _foe(g, "hound", p.global_position + Vector2(44, 0))
	e.rest = 99.0
	e.stun_time = 99.0
	e.knock_resist = 0.0
	await _frames(2)
	_check(e.is_open(), "a stunned enemy is Open")
	# Without Punish, a hit on it is a hit like any other. With it, your hit on an Open enemy always crits.
	var crit_times := float(p.weapon.get("crit_damage", 1.5))
	var plain := []
	var sharp := []
	for round in 2:
		lv.level = round
		lv.perks[0] = ["punish"]
		await _frames(2)
		for n in 6:
			_still(p)
			p.unhurt = true
			p._reset_combo()
			await _frames(30)
			e.hp = 99999.0
			Sim.seed_with(100 + n)
			await _fight(p, e, func(): return e.hp < 99999.0, 120)
			(sharp if round == 1 else plain).append(99999.0 - e.hp)
			await _frames(20)
	var base: float = plain.min()
	_check(base > 0.0 and plain.count(base) >= 4, "(without Punish, most first hits are plain ones: %s)" % str(plain))
	_check(sharp.all(func(v): return is_equal_approx(v, base * crit_times)), "with Punish, every hit on an Open enemy crits (%s against %.1f)" % [str(sharp), base])
	_check(Enemy.show_open, "and enemies show that they are Open")
	_check(lv.punishes(p, e), "(Punish answers for it)")
	e.stun_time = 0.0
	await _frames(2)
	_check(not lv.punishes(p, e), "an enemy that is not Open is hit as ever")
	e.queue_free()
	await _leave(g)
	await _frames(2)


# --- Kindle (Mender) ----------------------------------------------------------------------

func _kindle() -> void:
	var g = _game(424242)
	await _frames(5)
	var lv = g.levels
	var p = g.players[0]
	var home: Vector2 = p.spawn_point
	p.global_position = home + Vector2(-60, 60)
	p.unhurt = true
	var e = _foe(g, "hound", p.global_position + Vector2(44, 0))
	e.stun_time = 999.0
	e.rest = 999.0
	e.knock_resist = 0.0
	await _frames(3)
	lv.finisher(p, [e])
	_check(lv.sparks.is_empty(), "without Kindle, a finisher knocks out no Spark")
	lv.level = 1
	lv.perks[0] = ["kindle"]
	var n := await _fight(p, e, func(): return not lv.sparks.is_empty(), 300)
	_check(n >= 0 and lv.sparks.size() == 1, "the Mender's finisher knocks a Spark out of the enemy it hits")
	if lv.sparks.is_empty():
		await _leave(g)
		return
	var at: Vector2 = lv.sparks[0]["at"]
	_check(at.x > e.global_position.x and at.distance_to(e.global_position) < 40.0 and g.map.walkable(int(at.x / TILE), int(at.y / TILE)), "it lies on the ground beyond the enemy")
	_check(is_equal_approx(float(lv.spark_wait[0]), Levels.SPARK_EVERY) or float(lv.spark_wait[0]) > Levels.SPARK_EVERY - 0.2, "(and the next has to wait)")
	lv.finisher(p, [e])
	_check(lv.sparks.size() == 1, "one Spark every 4 s at most")
	lv.spark_wait[0] = 0.0
	lv.finisher(p, [e])
	_check(lv.sparks.size() == 2, "after 4 s, another")
	lv.sparks.remove_at(1)
	# Somebody at full health walks over it: it stays. Somebody hurt: it heals a tenth of their health.
	e.global_position += Vector2(400, 0)
	p.global_position = at
	await _frames(3)
	_check(lv.sparks.size() == 1 and p.hp == p.max_hp, "at full health a Spark is left lying")
	p.hp = p.max_hp * 0.5
	await _frames(2)
	_check(lv.sparks.is_empty() and is_equal_approx(p.hp, p.max_hp * 0.6), "walking over a Spark heals 10%% of your health (%.0f of %.0f)" % [p.hp, p.max_hp])
	_check(lv.spark_takes.size() == 1, "(and is seen to be taken)")
	# It never heals past full.
	lv.sparks.append({"at": p.global_position, "left": 5.0, "by": 0})
	p.hp = p.max_hp - 1.0
	await _frames(2)
	_check(p.hp == p.max_hp and lv.sparks.is_empty(), "never past full health")
	# Sparks last 10 s.
	lv.sparks.append({"at": p.global_position + Vector2(300, 0), "left": Levels.SPARK_LIFE, "by": 0})
	await _frames(int(Levels.SPARK_LIFE * 60.0) - 30)
	_check(lv.sparks.size() == 1, "a Spark lies for 10 s")
	await _frames(40)
	_check(lv.sparks.is_empty(), "and is gone after")
	e.queue_free()
	await _leave(g)


# --- Ore Sense (Delver) -------------------------------------------------------------------

func _ore_tiles_near(map: LandMap, at: Vector2, far: float) -> int:
	var n := 0
	var c := Vector2i(int(floorf(at.x)), int(floorf(at.y)))
	var r := int(ceilf(far))
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			var k := map.kind(x, y)
			if (k == LandMap.TIN or k == LandMap.COPPER) and Vector2(x + 0.5, y + 0.5).distance_to(at) <= far:
				n += 1
	return n


func _ore_sense() -> void:
	var g = _game(424242)
	await _frames(5)
	var lv = g.levels
	var p = g.players[0]
	var map: LandMap = g.map
	# The nearest ore to the cave.
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in range(map.region.position.y, map.region.end.y):
		for x in range(map.region.position.x, map.region.end.x):
			var k := map.kind(x, y)
			if (k == LandMap.TIN or k == LandMap.COPPER) and Vector2(x, y).distance_to(Vector2(map.spawn)) < best_d:
				best_d = Vector2(x, y).distance_to(Vector2(map.spawn))
				best = Vector2i(x, y)
	_check(best.x >= 0, "(there is ore on this land)")
	p.global_position = (Vector2(best) + Vector2(0.5, 3.5)) * TILE
	await _frames(2)
	lv._sense()
	_check(lv.sensed.is_empty(), "without Ore Sense, nothing shimmers")
	lv.level = 1
	lv.perks[0] = ["ore_sense"]
	lv._sense()
	var want := _ore_tiles_near(map, p.global_position / TILE, Levels.ORE_SENSE_TILES)
	var ores: Array = lv.sensed
	_check(want > 0 and ores.size() == want, "with it, every ore tile near you shimmers through the rock (%d of %d)" % [ores.size(), want])
	_check(ores.all(func(s): return (map.kind(s[0].x, s[0].y) == LandMap.TIN) == (str(s[1]) == "tin") and Vector2(Vector2(s[0]) + Vector2(0.5, 0.5)).distance_to(p.global_position / TILE) <= Levels.ORE_SENSE_TILES), "tin as tin and copper as copper, and nothing farther than it sees")
	# The whole squad sees it: it is on the land, not on one player's screen. And it is looks only.
	var before := Sim.rng.state
	lv._sense()
	lv._process(0.6)
	_check(Sim.rng.state == before, "looking for ore rolls none of the game's dice")
	lv.level = 0
	lv._sense()
	_check(lv.sensed.is_empty(), "asleep, it shows nothing")
	await _leave(g)


# --- The forge's screens ------------------------------------------------------------------

func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	ev = InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = false
	Input.parse_input_event(ev)
	await _frames(2)


func _screens() -> void:
	var g = _game(424242)
	await _frames(5)
	var lv = g.levels
	var hall = g.hall
	var p = g.players[0]
	_check(g.forge_words(0) == "Go down to the forge", "the cave mouth's prompt, with nothing to do there")
	var mouth: Array = g.interactables.filter(func(it): return str(it["text"]) == "Go down to the forge")
	_check(mouth.size() == 1 and mouth[0].has("words") and mouth[0]["words"].call(0) == g.forge_words(0), "(the cave mouth's words are asked for each player)")
	# Using the cave mouth opens the forge's screen, on the weapons while there is nothing else to do.
	g._use_forge(0)
	_check(hall.is_open and hall.view == "hall" and hall.who == 0 and paused and not g.build_menu.is_open, "the cave mouth opens the forge's screen, and the game stands still")
	_check(hall.row == 2, "with no Memory and no points it starts on the weapons")
	await _frames(12)
	hall.move(0, -2)
	hall.confirm()
	_check(lv.level == 0 and hall.note.contains("no Memory"), "giving nothing says so (\"%s\")" % hall.note)
	hall.go_back()
	_check(not hall.is_open and not paused, "back closes it, and the game goes on")
	await _frames(3)
	# With Memory: it starts on giving. Give: the level, the news, and on to the trees.
	g.loot.give(0, "memory", 130, p.global_position)
	var written: int = g.saves_written
	g._use_forge(0)
	_check(hall.row == 0, "carrying Memory, it starts on GIVE YOUR MEMORY")
	await _frames(12)
	await _key(KEY_S)
	_check(hall.row == 1, "the keys move through its rows")
	await _key(KEY_W)
	_check(hall.row == 0, "both ways")
	await _key(KEY_ENTER)
	_check(lv.level == 1 and g.loot.purses[0].memory == 0 and is_equal_approx(lv.banked, 30.0), "Enter on GIVE YOUR MEMORY pours it all in")
	_check(hall.note.contains("level 1") and not hall.pour.is_empty() and hall.row == 1, "the screen says the squad is level 1, and moves on to the trees (\"%s\")" % hall.note)
	await _frames(80)
	_check(hall.pour.is_empty(), "(the meter has run up)")
	hall.confirm()
	_check(hall.view == "trees" and hall.is_open, "ROLE TREES opens the trees")
	_check(hall.perk_on() == "challenge", "on the Warden's signature")
	await _key(KEY_D)
	_check(hall.tree == 1 and hall.perk_on() == "punish", "right is the next tree")
	await _key(KEY_S)
	_check(hall.place == 1 and hall.perk_on() == "close_call", "down is the next perk of it")
	hall.confirm()
	_check((lv.perks[0] as Array).is_empty() and hall.note.begins_with("Not built yet"), "a perk that is not built cannot be bought (\"%s\")" % hall.note)
	hall.move(0, -1)
	hall.confirm()
	_check(lv.perks[0] == ["punish"] and lv.points(0) == 0 and hall.note == "Punish learnt.", "Enter learns the perk the cursor is on")
	hall.move(1, 0)
	hall.confirm()
	_check(lv.perks[0] == ["punish"] and hall.note.begins_with("No point"), "with no point left it says why not (\"%s\")" % hall.note)
	hall.move(-9, 0)
	_check(hall.tree >= 0 and hall.tree < 4 and hall.place == 0, "(the cursor stays on the trees)")
	hall.move(0, 99)
	_check(hall.place == 7, "(and on a tree)")
	# Forgetting: asked first, and only with the Memory.
	hall.ask_forget()
	_check(not hall.asking and hall.note.contains("costs 20 Memory"), "forgetting without the Memory says what it costs (\"%s\")" % hall.note)
	g.loot.give(0, "memory", 25, p.global_position)
	await _key(KEY_R)
	_check(hall.asking, "R asks before forgetting")
	hall.go_back()
	_check(not hall.asking and lv.perks[0] == ["punish"] and hall.view == "trees", "back keeps them")
	hall.ask_forget()
	hall.confirm()
	_check(not hall.asking and (lv.perks[0] as Array).is_empty() and g.loot.purses[0].memory == 5 and lv.points(0) == 1, "Enter forgets them, for the Memory")
	hall.go_back()
	_check(hall.view == "hall" and hall.is_open, "back from the trees is the forge")
	hall.ask_forget()
	_check(not hall.asking, "(R does nothing there)")
	# Leaving saves... (this game is not a saved one: nothing is written, and nothing breaks)
	hall.row = 3
	hall.confirm()
	_check(not hall.is_open and not paused and g.saves_written == written, "LEAVE closes it")
	await _frames(3)
	# Weapons and runes: the forge screen there has always been.
	g._use_forge(0)
	hall.row = 2
	hall.confirm()
	_check(not hall.is_open and g.build_menu.is_open and g.forging == 0, "WEAPONS AND RUNES opens the weapon forge")
	g._use_forge(0)
	_check(not hall.is_open, "(the cave mouth does not open one screen over the other)")
	g.build_menu.close()
	await _frames(3)
	_check(not g.build_menu.is_open and not paused, "and that closes as it always did")
	# Words that fit.
	var pix := _text_font()
	for id in Perks.PERKS.keys():
		var lines: Array = hall.lines_of(pix, Perks.text_of(str(id)), 16, hall.INFO.size.x - 20.0)
		_check(lines.size() <= 5, "the words of %s fit their box (%d lines)" % [id, lines.size()])
	for n in range(1, Levels.FORGE_LINES.size() + 1):
		_check(hall.lines_of(pix, "\"" + Levels.line_for(n) + "\"", 16, hall.HALL.size.x - 36.0).size() <= 3, "the forge's line for level %d fits" % n)
	await _leave(g)
	# Two players: the one who used the cave mouth has the screen.
	g = _game(424242, 2)
	await _frames(5)
	g._use_forge(1)
	_check(g.hall.is_open and g.hall.who == 1, "with two players, the screen is the one's who used the cave mouth")
	var key := InputEventKey.new()
	var pad := InputEventJoypadButton.new()
	pad.device = 3
	_check(g.hall._mine(key) == (g.players[1].input.kind == "kbm") or g.players[1].input.kind == "script", "(their own controls drive it)")
	g.players[1].input.kind = "pad"
	g.players[1].input.device = 0
	_check(not g.hall._mine(key) and not g.hall._mine(pad), "another player's controls do not")
	pad.device = 0
	_check(g.hall._mine(pad), "(their controller does)")
	await _leave(g)


func _text_font() -> Font:
	return load("res://scripts/art.gd").font(load("res://scripts/art.gd").TEXT)


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
	var lv = g.levels
	var p = g.players[0]
	_check(lv.level == 0 and (lv.perks[0] as Array).is_empty(), "(a new character in a new world)")
	g.loot.give(0, "memory", 100 + 400 + 700 + 45, p.global_position)
	var written: int = g.saves_written
	g._use_forge(0)
	await _frames(12)
	g.hall.confirm()
	_check(lv.level == 3 and is_equal_approx(lv.banked, 45.0), "(three levels and 45 over)")
	g.hall.row = 1
	g.hall.confirm()
	g.hall.confirm()
	g.hall.move(3, 0)
	g.hall.confirm()
	_check(lv.perks[0] == ["challenge", "ore_sense"], "(two perks learnt)")
	g.hall.go_back()
	g.hall.go_back()
	await _frames(3)
	_check(g.saves_written == written + 2, "leaving the forge saves the world and the character")
	# A fall leaves a marker, which the world keeps.
	g.loot.give(0, "memory", 60, p.global_position)
	p.global_position = p.spawn_point + Vector2(140, 66)
	await _frames(2)
	_still(p)
	var there: Vector2 = p.global_position
	p.take_damage(9999.0)
	await _frames(2)
	_check(g.save_now(), "(saved)")
	var on_disk := Save.read(Save.WORLDS, str(where["id"]))
	var me := Save.read(Save.CHARACTERS, str(who["id"]))
	_check(int(on_disk.get("level", -1)) == 3 and is_equal_approx(float(on_disk.get("banked", -1.0)), 45.0), "the world's file holds the squad's level and what the forge holds (%s, %s)" % [str(on_disk.get("level")), str(on_disk.get("banked"))])
	_check(on_disk.get("markers") is Array and (on_disk["markers"] as Array).size() == 1 and int(on_disk["markers"][0][2]) == 30, "and the Memory that waits where somebody fell (%s)" % str(on_disk.get("markers")))
	_check(me.get("perks") == ["challenge", "ore_sense"] and int(me.get("memory", -1)) == 30, "the character's file holds its perks and what it carries (%s, %s)" % [str(me.get("perks")), str(me.get("memory"))])
	await _leave(g)
	# The pick screen says so.
	_check(SavePick.world_words(on_disk).contains("Squad level 3") and SavePick.squad_level(on_disk) == 3 and SavePick.squad_level({"level": "x"}) == 0, "the pick screen shows a world's level (\"%s\")" % SavePick.world_words(on_disk))
	_check(SavePick.perk_words(me) == "2 perks" and SavePick.perk_words({"perks": ["punish"]}) == "1 perk" and SavePick.perk_words({}) == "", "and how many perks a character has")
	# Played again.
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, str(who["id"]))], Save.read(Save.WORLDS, str(where["id"])))
	await _frames(5)
	lv = g.levels
	_check(lv.level == 3 and is_equal_approx(lv.banked, 45.0) and lv.perks[0] == ["challenge", "ore_sense"] and lv.points(0) == 1, "played again: level 3, 45 in the forge, both perks, one point left")
	_check(lv.markers.size() == 1 and int(lv.markers[0]["memory"]) == 30 and (lv.markers[0]["at"] as Vector2).distance_to(there) < 6.0, "and the marker stands where it was left")
	written = g.saves_written
	g.save_now()
	_check(g.saves_written == written, "nothing is written again while nothing has changed")
	g.players[0].global_position = there
	await _frames(3)
	_check(lv.markers.is_empty() and g.loot.purses[0].memory == 60, "it can be taken straight away, in a later game")
	g.save_now()
	_check((Save.read(Save.WORLDS, str(where["id"])).get("markers") as Array).is_empty(), "and then the world's file has none")
	# What a save might hold that makes no sense is passed over.
	lv.set_world_data({"level": "high", "banked": [], "markers": "many"})
	_check(lv.level == 3 and is_equal_approx(lv.banked, 45.0), "a level that makes no sense is passed over")
	lv.set_world_data({"level": 99, "banked": 1.0e9, "markers": [[1, 2], "x", [3, 4, -5], [100.0, 200.0, 7]]})
	_check(lv.level == Levels.LEVEL_CAP and lv.banked == 0.0 and lv.markers.size() == 1 and int(lv.markers[0]["memory"]) == 7, "one that is too high is the last level; markers are read as far as they make sense")
	lv.set_world_data({"level": 2, "banked": 5000.0, "markers": []})
	_check(lv.level == 2 and lv.banked < Levels.need(2), "the forge never holds a whole level without having gained it")
	lv.set_perks_data(0, {"perks": ["kindle", "kindle", "crown", 4]})
	_check(lv.perks[0] == ["kindle"], "perks this game does not know are left out")
	lv.set_perks_data(0, {"perks": "all"})
	_check(lv.perks[0] == ["kindle"], "a perk list that makes no sense is passed over")
	lv.set_world_data({"level": 3, "banked": 45.0, "markers": []})
	lv.perks[0] = ["challenge", "ore_sense"]
	await _leave(g)
	# The same character in a new world: its perks go with it, but that world's forge is level 0.
	var other := Save.fresh(Save.WORLDS)
	other["seed"] = 515151
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, str(who["id"]))], other)
	await _frames(5)
	lv = g.levels
	_check(lv.level == 0 and lv.perks[0] == ["challenge", "ore_sense"] and lv.awake(0).is_empty() and lv.points(0) == 0, "in a new world the character keeps its perks, asleep: the world's forge decides what is awake")
	g.loot.purses[0].memory = 0
	g.loot.give(0, "memory", 100, g.players[0].global_position)
	lv.pour(0)
	_check(lv.has(0, "challenge") and not lv.has(0, "ore_sense") and lv.points(0) == 0, "as that forge gains a level, the first perk wakes")
	await _leave(g)
	# A world whose land is made differently now: laid out again, but its level is kept. Its markers are not.
	var old_land := Save.read(Save.WORLDS, str(where["id"]))
	old_land["land"] = WorldGen.GEN - 1
	old_land["markers"] = [[100, 100, 9]]
	old_land["level"] = 3
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, str(who["id"]))], old_land)
	await _frames(5)
	_check(g.relaid and g.levels.level == 3 and g.levels.markers.is_empty(), "a world laid out again keeps its level, and loses the Memory that lay on its old land")
	await _leave(g)
	# A character and a world from before version 45.
	var old_me := Save.read(Save.CHARACTERS, str(who["id"]))
	old_me.erase("perks")
	var old_world := Save.read(Save.WORLDS, str(where["id"]))
	for key in ["level", "banked", "markers"]:
		old_world.erase(key)
	g = _game(0, 1, false, [old_me], old_world)
	await _frames(5)
	_check(g.levels.level == 0 and g.levels.banked == 0.0 and (g.levels.perks[0] as Array).is_empty() and g.levels.markers.is_empty() and not g.relaid, "a character and a world saved before there were levels play on: level 0, nothing learnt")
	await _leave(g)
	Save.root = old_root


# --- Pictures --------------------------------------------------------------------------------

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


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var g = _game(shot_seed)
	await _frames(10)
	var lv = g.levels
	var hall = g.hall
	var p = g.players[0]
	p.unhurt = true
	var home: Vector2 = p.spawn_point
	g.land.settle()
	# The Memory bar: empty, part full, full.
	await _frames(20)
	await _snap("01_bar_empty_level_0")
	g.loot.give(0, "memory", 45, p.global_position + Vector2(60, 20))
	await _frames(70)
	await _snap("02_bar_part_full")
	g.loot.give(0, "coins", 23, p.global_position + Vector2(-60, 20))
	g.loot.give(0, "memory", 60, p.global_position + Vector2(60, 20))
	await _frames(8)
	await _snap("03_enough_for_a_level")
	await _frames(70)
	p.global_position = home + Vector2(60, 50)
	await _frames(90)
	await _snap("04_bar_full")
	p.global_position = home
	await _frames(20)
	await _snap("04_cave_mouth_says_so")
	# The forge's screen.
	g._use_forge(0)
	await _idle(20)
	await _snap("05_forge_before_giving")
	hall.confirm()
	await _idle(14)
	await _snap("06_forge_pouring")
	await _idle(60)
	await _snap("07_forge_level_1")
	hall.confirm()
	await _idle(10)
	await _snap("08_trees_a_point_to_spend")
	hall.move(1, 0)
	hall.confirm()
	await _idle(10)
	await _snap("09_trees_punish_learnt")
	hall.move(0, 3)
	await _idle(300)
	await _snap("10_trees_not_built_yet")
	hall.move(2, 4)
	await _idle(10)
	await _snap("11_trees_delver_capstone")
	g.loot.give(0, "memory", 64, p.global_position)
	hall.ask_forget()
	await _idle(10)
	await _snap("12_forget_asked")
	hall.go_back()
	hall.go_back()
	await _idle(10)
	await _snap("13_forge_after")
	hall.go_back()
	await _frames(4)
	# The level lands on the player.
	lv.perks[0] = []
	lv.level = 0
	lv.banked = 0.0
	g.loot.purses[0].memory = 100
	p.global_position = home + Vector2(0, 70)
	await _frames(20)
	lv.pour(0)
	for n in 50:
		await physics_frame
		if n in [6, 18, 26, 34, 44]:
			await _snap("14_level_up_%02d" % n)
	await _frames(240)
	# Challenge: the ring, in the challenger's colour.
	lv.level = 4
	lv.perks[0] = ["challenge", "punish", "kindle", "ore_sense"]
	var foes: Array = []
	for pair in [["hound", Vector2(70, -10)], ["slinger", Vector2(120, 30)], ["scrap_brute", Vector2(-80, 10)], ["shaman", Vector2(-130, -30)]]:
		var e = _foe(g, str(pair[0]), p.global_position + (pair[1] as Vector2))
		e.hp = e.max_hp
		e.set_physics_process(false)       # it stands still for its picture
		foes.append(e)
	await _frames(20)
	g.land.settle()
	await _snap("15_enemies_plain")
	lv.finisher(p, foes)
	await _frames(40)
	await _snap("16_challenged")
	for e in foes:
		e.open_for(9.0)
	await _frames(20)
	await _snap("17_challenged_and_open")
	for e in foes:
		e.challenge_left = 0.0
	await _frames(13)
	await _snap("18_open")
	foes[0].open_left = 0.0
	foes[0].stun_time = 5.0
	foes[1].open_left = 0.0
	foes[1].challenge(p, 5.0)
	await _frames(30)
	await _snap("19_stunned_is_open_and_one_challenged")
	# Sparks.
	for e in foes:
		e.open_left = 0.0
		e.stun_time = 0.0
		e.challenge_left = 0.0
	lv.sparks.clear()
	for k in 3:
		lv.sparks.append({"at": p.global_position + Vector2(-50 + 50 * k, 44), "left": [9.0, 6.0, 1.6][k], "by": 0})
	g.loot.give(0, "memory", 12, p.global_position + Vector2(90, 50))
	await _frames(8)
	await _snap("20_sparks_and_memory_motes")
	p.unhurt = false
	p.hp = p.max_hp * 0.4
	p.unhurt = true
	p.global_position = lv.sparks[0]["at"] + Vector2(-4, -2)
	await _frames(4)
	await _snap("21_spark_taken")
	await _frames(40)
	for e in foes:
		e.queue_free()
	# A real fight: a hound lunges past, and is Open.
	lv.sparks.clear()
	p.hp = p.max_hp
	var h = _foe(g, "hound", p.global_position + Vector2(Hound.RING, 0))
	h.rest = 0.0
	await _wait(func(): return h.mode == "crouch" and h.mode_t < Hound.LOCK_TIME, 300)
	await _snap("22_hound_crouches")
	p.global_position += Vector2(0, 70)
	p.reset_physics_interpolation()
	await _wait(func(): return h.mode == "recover", 200)
	await _frames(8)
	await _snap("22_hound_missed_open")
	h.queue_free()
	# Ore Sense.
	var map: LandMap = g.map
	var best := Vector2i(-1, -1)
	var best_n := 0
	for y in range(map.region.position.y + 6, map.region.end.y - 6, 3):
		for x in range(map.region.position.x + 6, map.region.end.x - 6, 3):
			if map.walkable(x, y) and Vector2(x, y).distance_to(Vector2(map.spawn)) < 60.0:
				var n := _ore_tiles_near(map, Vector2(x + 0.5, y + 0.5), 7.0)
				if n > best_n:
					best_n = n
					best = Vector2i(x, y)
	if best.x >= 0:
		p.global_position = (Vector2(best) + Vector2(0.5, 0.5)) * TILE
		g.rig.snap()
		lv.level = 0
		await _frames(40)
		g.land.settle()
		await _frames(5)
		await _snap("23_ore_without_ore_sense")
		lv.level = 4
		for n in 4:
			await _frames(31)
			await _snap("24_ore_sense_%d" % n)
	# Copper too.
	best = Vector2i(-1, -1)
	var best_d := INF
	for y in range(map.region.position.y + 6, map.region.end.y - 6):
		for x in range(map.region.position.x + 6, map.region.end.x - 6):
			if map.kind(x, y) == LandMap.COPPER:
				for step in [Vector2i(0, 3), Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, -3), Vector2i(0, 5), Vector2i(5, 0), Vector2i(-5, 0)]:
					var t: Vector2i = Vector2i(x, y) + step
					if map.walkable(t.x, t.y) and Vector2(t).distance_to(Vector2(map.spawn)) < best_d:
						best_d = Vector2(t).distance_to(Vector2(map.spawn))
						best = t
	if best.x >= 0:
		p.global_position = (Vector2(best) + Vector2(0.5, 0.5)) * TILE
		g.rig.snap()
		await _frames(60)
		g.land.settle()
		await _frames(20)
		await _snap("25_ore_sense_copper")
	# A fall.
	lv.level = 1
	lv.banked = 30.0
	g.loot.purses[0].memory = 90
	g.loot.purses[0].coins = 40
	var there := home + Vector2(120, 150)
	p.global_position = there
	g.rig.snap()
	await _frames(30)
	g.land.settle()
	await _snap("26_before_the_fall")
	p.unhurt = false
	p.invuln = 0.0
	p.take_damage(9999.0)
	await _frames(40)
	await _snap("27_fell_woke_at_the_cave")
	p.unhurt = true
	p.global_position = there + Vector2(-70, 10)
	g.rig.snap()
	await _frames(100)
	g.land.settle()
	await _snap("28_the_marker")
	await _frames(13)
	await _snap("29_the_marker_later")
	p.global_position = there + Vector2(-8, 0)
	await _frames(4)
	await _snap("30_marker_taken")
	await _frames(14)
	await _snap("31_memory_flying_back")
	await _frames(60)
	await _snap("32_after")
	await _leave(g)
	# Two players.
	g = _game(shot_seed, 2)
	await _frames(10)
	g.land.settle()
	g.loot.give(0, "memory", 70, g.players[0].global_position)
	g.loot.give(1, "memory", 100, g.players[1].global_position)
	g.loot.give(1, "coins", 112, g.players[1].global_position)
	g.loot.give(1, "horn_bell", 1, g.players[1].global_position)
	g.levels.level = 2
	g.levels.banked = 40.0
	g.levels.perks[1] = ["kindle"]
	await _frames(120)
	await _snap("33_two_players")
	g._use_forge(1)
	await _idle(20)
	await _snap("34_two_players_forge")
	g.hall.row = 1
	g.hall.confirm()
	g.hall.move(2, 0)
	await _idle(10)
	await _snap("35_two_players_trees")
	await _leave(g)
