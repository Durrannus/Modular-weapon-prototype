extends SceneTree
## Pip, his cage, the quests, his shop and the keepers' waystone (version 46). Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands_folk.gd
##
## With shots=/some/folder/ (needs a window, so leave out --headless) it saves 640x360 frames instead: the quests'
## corner, the cage and its breaking, Pip at the Roost and at the cave mouth, his shop, the waystone broken, being
## mended and lit, a journey, and the forge's screen with its row to the Watchpost. "seed=123456" picks the world.

const PlayerInput := preload("res://scripts/player_input.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const FoePlan := preload("res://scripts/highlands/foe_plan.gd")
const LootPlan := preload("res://scripts/highlands/loot_plan.gd")
const FolkPlan := preload("res://scripts/highlands/folk_plan.gd")
const Folk := preload("res://scripts/highlands/folk.gd")
const Loot := preload("res://scripts/highlands/loot.gd")
const Bag := preload("res://scripts/highlands/bag.gd")
const Nav := preload("res://scripts/highlands/nav.gd")
const Shop := preload("res://scripts/ui/shop.gd")
const ForgeHall := preload("res://scripts/ui/forge_hall.gd")
const Save := preload("res://scripts/save.gd")
const Art := preload("res://scripts/art.gd")
const TILE := 32.0
const SWING_TICKS := 29
const ROOT := "user://test_folk_saves"
const SEEDS := [424242, 515151, 123456, 777777, 31337, 202611]

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
	_plans()
	await _cage()
	await _pip_and_shop()
	await _waystone()
	await _guarded()
	await _two_players()
	await _saved()
	print("%s  Pip and the waystone: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
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


## One swing of the tool in hand, the way the player looks.
func _work(p) -> void:
	p.input.work_held = true
	await _frames(16)
	p.input.work_held = false
	await _frames(SWING_TICKS + 2)


## Presses the use button until whoever is speaking has finished. How many presses it took.
func _hear_out(g, p) -> int:
	var n := 0
	while g.ui.talking() and n < 80:
		await _press(p, "interact_pressed")
		n += 1
	await _frames(3)
	return n


func _put(g, p, at: Vector2) -> void:
	p.global_position = at
	p.velocity = Vector2.ZERO
	p.input.move = Vector2.ZERO
	g.rig.snap()


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


func _text_font() -> Font:
	return Art.font(Art.TEXT)


func _quest(folk, id: String) -> Dictionary:
	for q in folk.quests():
		if str(q["id"]) == id:
			return q
	return {}


## Does a line of news end short of the quests' corner (it is centred on the screen)?
func _fits(g, line: String) -> bool:
	return 320.0 + (g.loot._head_width(line) + 12.0) * 0.5 <= g.folk.track_at().x - 2.0


func _prompt(g, text: String) -> bool:
	return (g.ui.prompts as Array).any(func(pr): return str(pr["text"]) == text)


# --- The pictures are there ---------------------------------------------------------------

func _art() -> void:
	var book: Dictionary = Art.json("folk/folk.json").get("actors", {})
	var sheet := Art.texture("folk/folk.png")
	_check(sheet != null and book.has("pip") and book.has("pip_cage"), "Pip's sheet and its book are in the game")
	if sheet == null:
		return
	for pair in [["pip", ["idle", "talk", "work", "cheer", "bare_idle"]], ["pip_cage", ["idle", "hit", "break", "empty"]]]:
		var strips: Dictionary = book.get(pair[0], {}).get("strips", {})
		var frame: Array = book.get(pair[0], {}).get("frame", [0, 0])
		for name in pair[1]:
			var s: Dictionary = strips.get(name, {})
			var box: Array = s.get("box", [0, 0, 0, 0])
			var n := int(s.get("frames", 0))
			_check(n >= 1 and int(box[2]) == n * int(frame[0]) and int(box[3]) == int(frame[1]) and int(box[0]) + int(box[2]) <= sheet.get_width() and int(box[1]) + int(box[3]) <= sheet.get_height(),
				"%s's strip \"%s\" lies inside the sheet, in whole frames" % [pair[0], name])
	var sbook: Dictionary = Art.json("waystone/waystone.json")
	var stone := Art.texture("waystone/waystone.png")
	_check(stone != null and sbook.has("sprites") and sbook.has("foot") and sbook.has("solid"), "the waystone's sheet and its book are in the game")
	if stone == null:
		return
	for name in ["waystone_broken", "waystone_repair", "waystone_lit"]:
		var s: Dictionary = sbook["sprites"].get(name, {})
		var box: Array = s.get("box", [0, 0, 0, 0])
		var n := int(s.get("frames", 0))
		_check(n >= 1 and int(box[2]) == n * 48 and int(box[0]) + int(box[2]) <= stone.get_width() and int(box[1]) + int(box[3]) <= stone.get_height(), "the waystone's \"%s\" lies inside the sheet, in whole frames" % name)


# --- Where they stand, on any land ----------------------------------------------------------

func _apart(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _open_round(map: LandMap, t: Vector2i) -> int:
	var n := 0
	for j in range(-1, 2):
		for i in range(-1, 2):
			if map.walkable(t.x + i, t.y + j):
				n += 1
	return n


func _plans() -> void:
	var elite_roosts := 0
	var stones := 0
	for seed_value in SEEDS:
		var map: LandMap = WorldGen.make(seed_value)
		var groups := FoePlan.make(map)
		var chests := LootPlan.make(map, groups)
		var plan := FolkPlan.make(map, groups, chests)
		var again := FolkPlan.make(map, FoePlan.make(map), LootPlan.make(map, groups))
		_check(str(plan) == str(again), "world %d: the same land gives the same plan twice" % seed_value)
		var cave := Vector2(LandMap.MID + 0.5, LandMap.MID + 0.5)
		# The Roost.
		var roost: Dictionary = plan["roost"]
		_check(not roost.is_empty(), "world %d: there is a place for Pip's cage" % seed_value)
		if not roost.is_empty():
			var t: Vector2i = roost["tile"]
			var pocket: Dictionary = map.pockets[int(roost["pocket"])]
			_check(_open_round(map, t) == 9 and map.walkable(t.x + 2, t.y), "world %d: the cage stands on open ground with room all round it, and under where it hangs" % seed_value)
			_check(not bool(pocket.get("sealed", false)) and str(pocket.get("site", "")) == "", "world %d: in an open place that is not a named one" % seed_value)
			_check(chests.all(func(c): return _apart(c["tile"], t) > 2), "world %d: clear of every chest" % seed_value)
			_check(Vector2(t).distance_to(pocket["at"]) <= maxf(float(pocket["rx"]), float(pocket["ry"])) + 3.0, "world %d: inside its place" % seed_value)
			_check(roost["foot"] == Vector2(t.x * 16 + 8, t.y * 16 + 12), "(its foot is on its tile)")
			var g := int(roost["group"])
			if g >= 0 and (groups[g]["members"] as Array).any(func(m): return str(m[0]) == "slinger" and bool(m[1])):
				elite_roosts += 1
				_check(int(groups[g]["pocket"]) == int(roost["pocket"]), "world %d: the Roost is the place the elite slinger's band holds" % seed_value)
			_check((pocket["at"] as Vector2).distance_to(cave) > FoePlan.SAFE, "world %d: and it is out beyond the safe hills (%d tiles)" % [seed_value, int((pocket["at"] as Vector2).distance_to(cave))])
		# The waystone.
		var stone: Dictionary = plan["stone"]
		if map.sites.has("watchpost"):
			_check(not stone.is_empty(), "world %d: the Watchpost has its waystone" % seed_value)
		if not stone.is_empty():
			stones += 1
			var t: Vector2i = stone["tile"]
			var pocket: Dictionary = map.pockets[int(stone["pocket"])]
			_check(int(stone["pocket"]) == int(map.sites["watchpost"]["pocket"]) and str(stone["id"]) == "watchpost", "world %d: the waystone is at the Keeper's Watchpost" % seed_value)
			_check(map.walkable(t.x, t.y) and _open_round(map, t) >= 4, "world %d: on open ground" % seed_value)
			_check(chests.all(func(c): return _apart(c["tile"], t) > 2) and (roost.is_empty() or _apart(roost["tile"], t) > 2), "world %d: clear of the chests and the cage" % seed_value)
			_check(Vector2(t).distance_to(cave) <= (pocket["at"] as Vector2).distance_to(cave) + 1.5, "world %d: on the side you come to the Watchpost from" % seed_value)
			var gs := int(stone["group"])
			_check(gs < 0 or int(groups[gs]["pocket"]) == int(stone["pocket"]), "world %d: (it knows who lives there)" % seed_value)
		# Pip's camp.
		var home: Vector2i = plan["pip"]["tile"]
		var mouth := Vector2(map.mouth.x + 0.5, map.mouth.y + 0.5)
		_check(map.walkable(home.x, home.y) and _open_round(map, home) >= 6, "world %d: Pip's camp is on open ground" % seed_value)
		_check((Vector2(home) + Vector2(0.5, 0.5)).distance_to(mouth) < 9.0 and absi(home.x - map.mouth.x) >= 2, "world %d: beside the cave mouth, clear of the way in (%s from %s)" % [seed_value, str(home), str(map.mouth)])
		_check(chests.all(func(c): return _apart(c["tile"], home) > 2), "world %d: clear of every chest" % seed_value)
		var nav := Nav.new()
		nav.setup(map)
		_check(nav.steps(map.spawn * TILE, Nav.middle_of(home + Vector2i(0, 1))) >= 0, "world %d: and can be walked to from where you arrive" % seed_value)
		if not roost.is_empty():
			var pocket: Dictionary = map.pockets[int(roost["pocket"])]
			var middle := Nav.middle_of(nav.nearest_free(Nav.tile_of((pocket["at"] as Vector2) * TILE), 6))
			_check(nav.steps(middle, Nav.middle_of((roost["tile"] as Vector2i) + Vector2i(1, 1))) >= 0, "world %d: the cage can be walked to from the middle of its place" % seed_value)
		if not stone.is_empty():
			var pocket: Dictionary = map.pockets[int(stone["pocket"])]
			var middle := Nav.middle_of(nav.nearest_free(Nav.tile_of((pocket["at"] as Vector2) * TILE), 6))
			_check(nav.steps(middle, Nav.middle_of((stone["tile"] as Vector2i) + Vector2i(0, 1))) >= 0, "world %d: the waystone can be walked to from the middle of the Watchpost" % seed_value)
	print("      (%d of %d lands hang the cage at the elite slinger's place; %d have a waystone)" % [elite_roosts, SEEDS.size(), stones])
	_check(elite_roosts >= SEEDS.size() - 1, "nearly every land's Roost is the elite slinger's place (%d of %d)" % [elite_roosts, SEEDS.size()])
	# The chests stand where they stood before there was a plan for Pip.
	var map: LandMap = WorldGen.make(424242)
	var spot := LootPlan._stand(map, map.spawn, map.spawn + Vector2(3, 3), 8.0)
	_check(spot == LootPlan._stand(map, map.spawn, map.spawn + Vector2(3, 3), 8.0, 9, [], 0.0), "(asking for a chest's place as before gives the place as before)")
	_check(_apart(LootPlan._stand(map, map.spawn, map.spawn + Vector2(3, 3), 8.0, 9, [spot], 0.0), spot) > 2, "(a spoken-for tile keeps others two tiles off)")


# --- The cage ---------------------------------------------------------------------------------

func _cage() -> void:
	var g = _game(424242, 1, true)
	await _frames(5)
	var folk = g.folk
	var foes = g.foes
	var p = g.players[0]
	p.unhurt = true
	_check(folk != null and folk.has_roost() and folk.pip == 0 and folk.cage != null and folk.cage.anim == "idle", "a new world: Pip is in his cage at the Roost")
	_check(not folk.pip_actor.visible, "(and nowhere else)")
	var q := _quest(folk, "smoke")
	_check(folk.quests().size() == 1 and str(q.get("name", "")) == "Smoke over the Canyon" and str(q.get("text", "")).begins_with("Follow the smoke to the stone-throwers' roost"), "the first quest is on the screen from the start: \"%s\"" % str(q.get("text", "")))
	_check(folk.track_at() == Vector2(640.0 - 10.0 - Folk.TRACK_W, 10.0), "in the top right corner")
	_check(not _prompt(g, "Talk to Pip"), "(nobody to talk to at the cave mouth yet)")
	_put(g, p, folk.pip_home() + Vector2(0, 30))
	await _frames(4)
	_check(not _prompt(g, "Talk to Pip"), "(even standing where he will camp)")
	# To the Roost. Somebody lives there.
	var group := int(folk.plan["roost"]["group"])
	_check(group >= 0, "(this land's Roost is held)")
	_put(g, p, folk.pip_landing() + Vector2(0, 20))
	await _wait(func(): return foes.packs.has(group), 180)
	_check(foes.packs.has(group), "(its band is on the land)")
	await _frames(3)
	_check(folk.found.has("roost") and str(_quest(folk, "smoke")["text"]) == "Clear the roost and break Pip's cage.", "coming to the Roost, the quest says what to do there")
	_check(not folk.roost_clear() and folk.cage_words() == "Pip's cage: clear the roost first", "while its band lives the cage says so")
	_check(_prompt(g, "Pip's cage: clear the roost first"), "(over the cage)")
	_check(not folk.strike_cage(0) and folk.cage_hits == 0 and folk.pip == 0, "and a blow does nothing")
	p.input.stick_aim = Vector2.UP
	await _work(p)
	_check(folk.cage_hits == 0, "nor a tool's")
	await _press(p, "interact_pressed")
	_check(folk.cage_hits == 0, "nor the use button")
	# All but one down: still not clear.
	var band: Array = foes.packs[group].members.duplicate()
	for k in band.size() - 1:
		band[k].take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(3)
	_check(not folk.roost_clear(), "with one of them left it is still not clear")
	band[band.size() - 1].take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(3)
	_check(folk.roost_clear() and folk.cage_words() == "Break the cage", "the band down, the cage can be broken")
	foes.packs[group].alert = false
	_put(g, p, folk.pip_landing() + Vector2(0, 20))
	await _frames(40)
	_check(_prompt(g, "Break the cage"), "(the prompt says so)")
	# Three blows: by hand, by the use button, by a tool.
	_check(folk.strike_cage(0) and folk.cage_hits == 1 and folk.cage.anim == "hit" and folk.pip == 0, "a blow shakes it")
	await _frames(20)
	_check(folk.cage.anim == "idle", "(and it hangs still again)")
	await _press(p, "interact_pressed")
	_check(folk.cage_hits == 2 and folk.pip == 0, "the use button is a blow")
	await _frames(20)
	p.input.stick_aim = Vector2.UP
	await _work(p)
	_check(folk.cage_hits == 3 and folk.pip == 1, "a tool's blow is one too, and the third breaks it (%d blows)" % folk.cage_hits)
	_check(str(_quest(folk, "smoke")["text"]).begins_with("Clear the roost"), "(the quest waits for him to say his piece)")
	_check(not folk.strike_cage(0) and folk.cage_hits == 3, "(a broken cage takes no more)")
	await _wait(func(): return folk.cage.anim == "empty", 60)
	_check(folk.cage.anim == "empty" and folk.pip_actor.visible and folk.pip_actor.anim == "cheer", "the cage hangs open and Pip is out, cheering")
	_check(folk.pip_actor.position.distance_to(folk.pip_landing() - Vector2(0, Folk.SORT_BIAS)) < 0.5, "under where the cage hung")
	_check(not _prompt(g, "Talk to Pip") and not g.ui.talking(), "(he cheers before he speaks)")
	await _wait(func(): return g.ui.talking(), 120)
	_check(g.ui.talking() and g.ui.speaker == "Pip" and g.ui.lines == Folk.FREED_LINES and folk.speaking, "then he says his piece")
	var presses := await _hear_out(g, p)
	_check(not g.ui.talking() and not folk.speaking and presses >= Folk.FREED_LINES.size(), "(heard out in %d presses)" % presses)
	_check(g.loot.said.contains("Pip is free") and _fits(g, g.loot.said), "the screen says he is free (\"%s\")" % g.loot.said)
	_check(folk.pip == 1 and str(_quest(folk, "smoke")["text"]).begins_with("Pip is on his way"), "the quest sends you home to meet him")
	await _frames(4)
	_check(_prompt(g, "Talk to Pip"), "he can be spoken to where he stands")
	await _press(p, "interact_pressed")
	_check(g.ui.talking() and g.ui.lines == [Folk.WAIT_LINE], "and tells you not to wait")
	await _hear_out(g, p)
	await _frames(30)
	_check(folk.pip == 1 and folk.pip_actor.anim == "bare_idle", "while somebody is near he stays where he dropped")
	# Nobody near: he is at the base.
	_put(g, p, folk.forge_spot())
	await _frames(4)
	_check(folk.pip == 2 and folk.pip_actor.position.distance_to(folk.pip_home() - Vector2(0, Folk.SORT_BIAS)) < 0.5 and folk.pip_shape != null, "once nobody is near he is at the cave mouth")
	_check(folk.pip_actor.anim in ["idle", "work"], "(with his pack on)")
	_check(folk.world_data() == {"folk": {"pip": 2, "stones": [], "found": ["roost"]}}, "what the world keeps of it: %s" % str(folk.world_data()))
	# A cage that needs fewer blows (the lab's page).
	await _leave(g)
	g = _game(424242)
	await _frames(5)
	folk = g.folk
	_check(folk.roost_clear(), "(with nobody on the land the Roost is clear)")
	var blows: int = Folk.CAGE_BLOWS
	Folk.CAGE_BLOWS = 1
	_check(folk.strike_cage(0) and folk.pip == 1, "the number of blows is the lab's to change")
	Folk.CAGE_BLOWS = blows
	await _leave(g)


# --- Pip at the base, and his shop -------------------------------------------------------------

func _pip_and_shop() -> void:
	var g = _game(424242)
	await _frames(5)
	var folk = g.folk
	var shop = folk.shop
	var p = g.players[0]
	var purse = g.loot.purses[0]
	var bag = g.tools.bag_of(0)
	folk.pip = 2
	folk._show()
	_put(g, p, folk.pip_home() + Vector2(0, 28))
	await _frames(4)
	_check(folk.pip_actor.visible and _prompt(g, "Talk to Pip"), "at the base, Pip can be spoken to")
	await _press(p, "interact_pressed")
	_check(g.ui.talking() and g.ui.lines == Folk.MET_LINES and not shop.is_open, "the first time he tells you of the horn")
	await _frames(3)
	_check(folk.pip_actor.anim == "talk", "(his mouth moves)")
	await _hear_out(g, p)
	_check(folk.pip == 3 and g.loot.said == "Quest done: Smoke over the Canyon" and _fits(g, g.loot.said), "then the quest is done, and the screen says so (\"%s\")" % g.loot.said)
	var q := _quest(folk, "crown")
	_check(folk.quests().size() == 1 and str(q.get("name", "")) == "The Scrap Crown" and str(q.get("text", "")).contains("0 of 3"), "and the next quest is his: \"%s\"" % str(q.get("text", "")))
	await _frames(6)
	# The shop.
	purse.coins = 20
	await _press(p, "interact_pressed")
	_check(shop.is_open and shop.who == 0 and paused and not g.ui.talking(), "speaking to him again opens his shop, and the game stands still")
	await _frames(2)
	_check(not folk.panel.visible, "(the quests' corner is put away while a screen is up)")
	_check(shop.row == 0 and shop.line == Folk.SHOP_LINE, "(on the first row, with a word from him)")
	_check(folk.price("tin_bar") == Folk.TIN_PRICE and folk.price("copper_bar") == Folk.COPPER_PRICE, "(his prices are the lab's)")
	await _frames(12)
	shop.confirm()
	_check(bag.count("tin_bar") == 1 and purse.coins == 20 - Folk.TIN_PRICE and shop.note == "Bought a tin bar for %d coins." % Folk.TIN_PRICE, "a tin bar for its price (\"%s\")" % shop.note)
	await _key(KEY_S)
	_check(shop.row == 1, "the keys move through the rows")
	await _key(KEY_ENTER)
	_check(bag.count("copper_bar") == 1 and purse.coins == 20 - Folk.TIN_PRICE - Folk.COPPER_PRICE, "Enter buys: a copper bar for its price")
	var left: int = purse.coins
	shop.confirm()
	_check(bag.count("copper_bar") == 1 and purse.coins == left and shop.note == "That is %d coins. You have %d." % [Folk.COPPER_PRICE, left], "too few coins: nothing, and why (\"%s\")" % shop.note)
	purse.coins = 50
	for k in Bag.SLOTS:
		bag.add("stone", Bag.STACK)
	bag.add("tin_bar", bag.room("tin_bar"))
	_check(bag.room("tin_bar") == 0, "(a full bag)")
	shop.row = 0
	shop.confirm()
	_check(purse.coins == 50 and shop.note == "Your inventory is full.", "a full inventory: nothing, and why (\"%s\")" % shop.note)
	# Asking about the horn.
	shop.row = shop.rows().find(Shop.ASK)
	shop.confirm()
	_check(shop.line.contains("quarry") and shop.line.contains("hound") and shop.line.contains("roost") and shop.note == "", "asked about the Scrap Crown he says where all three pieces are")
	purse.kept["horn_body"] = true
	shop.confirm()
	_check(not shop.line.contains("quarry") and shop.line.contains("hound") and shop.line.contains("roost"), "and only the ones you lack")
	_check(str(_quest(folk, "crown")["text"]).contains("1 of 3"), "the quest counts the pieces: \"%s\"" % str(_quest(folk, "crown")["text"]))
	purse.kept["horn_bell"] = true
	purse.kept["horn_mouthpiece"] = true
	shop.row = shop.rows().find(Shop.ASK)       # (with all three there is a row above it now: to mend the horn)
	shop.confirm()
	_check(shop.line.begins_with("That is all three"), "with all three he says so (\"%s\")" % shop.line)
	_check(_quest(folk, "crown").is_empty() and str(_quest(folk, "mend").get("name", "")) == "Mend the Horn", "and the quest is now to have him mend it (the rest is tests/highlands_crown.gd's)")
	# Words that fit.
	var pix := _text_font()
	var wide: float = Shop.BOX.size.x - 36.0 - 60.0
	for body in [false, true]:
		for bell in [false, true]:
			for mouth in [false, true]:
				purse.kept.clear()
				if body:
					purse.kept["horn_body"] = true
				if bell:
					purse.kept["horn_bell"] = true
				if mouth:
					purse.kept["horn_mouthpiece"] = true
				var n := Shop.lines_of(pix, "\"" + folk.crown_words(0) + "\"", Art.TEXT_SIZE, wide).size()
				_check(n <= 4, "what he says about the horn fits his plate (%d lines)" % n)
	purse.kept.clear()
	_check(Shop.lines_of(pix, "\"" + Folk.SHOP_LINE + "\"", Art.TEXT_SIZE, wide).size() <= 4, "(and his greeting)")
	for line in Folk.FREED_LINES + Folk.MET_LINES + [Folk.WAIT_LINE]:
		_check((g.ui._wrap(str(line), 470.0) as Array).size() <= 3, "his words fit the speech box (\"%s...\")" % str(line).substr(0, 24))
	# Leaving.
	await _key(KEY_ESCAPE)
	_check(not shop.is_open and not paused, "Escape leaves the shop, and the game goes on")
	await _frames(4)
	_check(folk.panel.visible, "(and the quests are back)")
	await _press(p, "interact_pressed")
	_check(shop.is_open, "(and it opens again)")
	await _frames(12)
	shop.row = shop.rows().find(Shop.LEAVE)
	shop.confirm()
	_check(not shop.is_open and not paused, "LEAVE leaves it too")
	await _frames(3)
	await _leave(g)


# --- The waystone -------------------------------------------------------------------------------

func _waystone() -> void:
	var g = _game(424242)
	await _frames(5)
	var folk = g.folk
	var p = g.players[0]
	var bag = g.tools.bag_of(0)
	_check(folk.has_stone() and folk.stone != null and folk.stone.anim == "waystone_broken" and not folk.lit("watchpost"), "the waystone at the Watchpost is found broken")
	_check(_quest(folk, "watch").is_empty(), "its quest is not on the screen before the stone has been seen")
	_check(g.hall.rows() == ForgeHall.ROWS, "(and the forge's screen has no row for it)")
	_check(not folk.go_to_stone(0) and not folk.travelling(), "(nobody travels to a stone that is not lit)")
	_put(g, p, folk.stone_spot())
	await _frames(4)
	var q := _quest(folk, "watch")
	_check(folk.found.has("watch") and str(q.get("name", "")) == "Light the Watch" and str(q.get("text", "")).contains("%d copper bars (you have 0)" % Folk.REPAIR_COPPER), "coming to it, the quest is: \"%s\"" % str(q.get("text", "")))
	_check(folk.stone_words(0) == "Mend the waystone: %d copper bars" % Folk.REPAIR_COPPER and _prompt(g, folk.stone_words(0)), "the stone says what it needs")
	await _press(p, "interact_pressed")
	_check(not folk.lit("watchpost") and g.loot.said == "The waystone needs %d copper bars. You have 0." % Folk.REPAIR_COPPER and _fits(g, g.loot.said), "without the copper nothing happens, and the screen says why (\"%s\")" % g.loot.said)
	bag.add("copper_bar", Folk.REPAIR_COPPER + 2)
	bag.add("tin_bar", 3)
	await _frames(2)
	_check(str(_quest(folk, "watch")["text"]).contains("(you have %d)" % (Folk.REPAIR_COPPER + 2)), "(the quest counts your copper)")
	await _press(p, "interact_pressed")
	_check(folk.lit("watchpost") and bag.count("copper_bar") == 2 and bag.count("tin_bar") == 3, "with it, the use button mends the stone for %d copper bars" % Folk.REPAIR_COPPER)
	_check(folk.mending and folk.stone.anim == "waystone_repair" and g.loot.said == "Quest done: Light the Watch" and _fits(g, g.loot.said), "the copper goes in, and the quest is done (\"%s\")" % g.loot.said)
	_check(_quest(folk, "watch").is_empty(), "(it leaves the screen)")
	await _frames(3)
	_check(not _prompt(g, "Travel to the forge") and not folk.travelling(), "(nothing more until it is lit)")
	await _wait(func(): return not folk.mending, 120)
	_check(not folk.mending and folk.stone.anim == "waystone_lit", "then it is lit")
	_check(not folk.mend(0) and bag.count("copper_bar") == 2, "(a lit stone takes no more copper)")
	await _frames(3)
	# To the forge.
	_check(folk.stone_words(0) == "Travel to the forge" and _prompt(g, "Travel to the forge"), "a lit stone offers the way to the forge")
	await _press(p, "interact_pressed")
	_check(folk.travelling() and p.global_position.distance_to(folk.stone_spot()) < 40.0, "the use button starts the journey")
	await _frames(3)
	_check(p.frozen, "(nobody moves on the way)")
	_check(not folk.go(folk.stone_spot(), 0), "(and no second journey starts)")
	await _wait(func(): return not folk.travelling(), 120)
	_check(not folk.travelling() and p.global_position.distance_to(folk.forge_spot()) < 4.0, "and it ends in front of the cave mouth")
	await _frames(3)
	_check(not p.frozen and g.ui.fade < 0.6, "(the screen comes back and you can move)")
	# And back, from the forge's screen.
	var rows: Array = g.hall.rows()
	_check(rows.size() == ForgeHall.ROWS.size() + 1 and rows[rows.size() - 2] == ForgeHall.TRAVEL_ROW and rows[rows.size() - 1] == "Leave", "the forge's screen has a row to the Watchpost, above LEAVE")
	await _wait(func(): return g.ui.fade <= 0.01, 60)
	g._use_forge(0)
	_check(g.hall.is_open and paused, "(the forge's screen)")
	await _frames(12)
	g.hall.row = rows.size() - 2
	g.hall.confirm()
	_check(not g.hall.is_open and not paused and folk.travelling(), "choosing it closes the screen and starts the journey")
	await _wait(func(): return not folk.travelling(), 120)
	_check(p.global_position.distance_to(folk.stone_spot()) < 4.0, "which ends in front of the waystone")
	await _frames(3)
	_check(folk.world_data() == {"folk": {"pip": 0, "stones": ["watchpost"], "found": ["watch"]}}, "what the world keeps of it: %s" % str(folk.world_data()))
	# The price is the lab's.
	folk.stones = {}
	var price: int = Folk.REPAIR_COPPER
	Folk.REPAIR_COPPER = 2
	_check(folk.mend(0) and bag.count("copper_bar") == 0, "(the price is the lab's to change)")
	Folk.REPAIR_COPPER = price
	await _leave(g)


# --- With somebody living at the Watchpost ---------------------------------------------------

func _guarded() -> void:
	var g = _game(424242, 1, true)
	await _frames(5)
	var folk = g.folk
	var foes = g.foes
	var p = g.players[0]
	p.unhurt = true
	var group := int(folk.plan["stone"]["group"])
	_check(group >= 0, "(somebody lives at this land's Watchpost)")
	if group < 0:
		await _leave(g)
		return
	g.tools.bag_of(0).add("copper_bar", Folk.REPAIR_COPPER)
	_put(g, p, folk.stone_spot())
	await _wait(func(): return foes.packs.has(group), 180)
	_check(foes.packs.has(group), "(they are on the land)")
	foes.packs[group].alert = true
	_check(folk.cannot_travel() == "Not while enemies are after you", "nobody travels while an enemy is after them")
	_check(folk.mend(0) and folk.lit("watchpost") and foes.quiet.has(group), "the stone can be mended all the same, and then it keeps its place")
	await _wait(func(): return not folk.mending, 120)
	foes.packs[group].alert = true
	_check(not folk.go(folk.forge_spot(), 0) and not folk.travelling(), "the lit stone will not take you while they are after you")
	_check(not folk.go_to_stone(0), "(nor the forge's row)")
	# The fight over, it does.
	for e in foes.packs[group].members.duplicate():
		e.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(3)
	foes.packs[group].alert = false
	for k in foes.packs:
		foes.packs[k].alert = false
	_check(folk.cannot_travel() == "" and folk.go(folk.forge_spot(), 0), "once it is over, it does")
	await _wait(func(): return not folk.travelling(), 120)
	_check(p.global_position.distance_to(folk.forge_spot()) < 4.0, "(to the forge)")
	# Nobody comes back to live at the Watchpost.
	await _wait(func(): return not foes.packs.has(group), 240)
	_check(not foes.packs.has(group), "(far away, the Watchpost's band is put away)")
	foes.fallen.erase(group)
	_check(folk.go_to_stone(0), "(back by the forge's row)")
	await _wait(func(): return not folk.travelling(), 120)
	await _frames(90)
	_check(not foes.packs.has(group), "back at the lit stone, nobody has come to live there again")
	await _leave(g)


# --- Two players ----------------------------------------------------------------------------------

func _two_players() -> void:
	var g = _game(424242, 2)
	await _frames(5)
	var folk = g.folk
	var a = g.players[0]
	var b = g.players[1]
	_check(folk.track_at().y > 70.0, "with two players the quests are listed under the second player's bars")
	g.tools.bag_of(0).add("copper_bar", 2)
	g.tools.bag_of(1).add("copper_bar", Folk.REPAIR_COPPER - 1)
	_check(folk.copper() == Folk.REPAIR_COPPER + 1, "the waystone counts the whole squad's copper")
	_put(g, a, folk.stone_spot() + Vector2(-20, 0))
	_put(g, b, folk.stone_spot() + Vector2(20, 0))
	await _frames(4)
	_check(str(_quest(folk, "watch").get("text", "")).contains("the squad has %d" % (Folk.REPAIR_COPPER + 1)), "(and so does the quest)")
	await _press(b, "interact_pressed")
	_check(folk.lit("watchpost") and g.tools.bag_of(1).count("copper_bar") == 0 and g.tools.bag_of(0).count("copper_bar") == 1, "player two mends it: their own bars first, the rest from player one")
	await _wait(func(): return not folk.mending, 120)
	await _frames(3)
	_put(g, a, folk.stone_spot() + Vector2(300, 0))
	await _press(b, "interact_pressed")
	_check(folk.travelling(), "(player two uses the stone)")
	await _wait(func(): return not folk.travelling(), 120)
	_check(a.global_position.distance_to(folk.forge_spot()) < 20.0 and b.global_position.distance_to(folk.forge_spot()) < 20.0 and absf(a.global_position.x - b.global_position.x) > 20.0, "the whole squad arrives at the forge, side by side")
	# The shop is the one's who spoke to Pip.
	folk.pip = 3
	folk._show()
	g.loot.purses[0].coins = 30
	g.loot.purses[1].coins = 30
	_put(g, b, folk.pip_home() + Vector2(0, 28))
	await _frames(6)
	await _press(b, "interact_pressed")
	var shop = folk.shop
	_check(shop.is_open and shop.who == 1, "the shop is the player's who spoke to Pip")
	shop.confirm()
	_check(g.tools.bag_of(1).count("tin_bar") == 1 and g.loot.purses[1].coins == 30 - Folk.TIN_PRICE and g.loot.purses[0].coins == 30, "and it is their coins and their bag")
	var key := InputEventKey.new()
	var pad := InputEventJoypadButton.new()
	pad.device = 0
	b.input.kind = "pad"
	b.input.device = 0
	a.input.kind = "kbm"
	_check(shop._mine(pad) and not shop._mine(key), "the other player's controls do nothing there")
	shop.close()
	await _leave(g)


# --- Saved ----------------------------------------------------------------------------------------

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
	var folk = g.folk
	var p = g.players[0]
	var id := str(where["id"])
	_check(Save.read(Save.WORLDS, id).get("folk") is Dictionary and int(Save.read(Save.WORLDS, id)["folk"].get("pip", -1)) == 0, "a new world's file says Pip is caged (%s)" % str(Save.read(Save.WORLDS, id).get("folk")))
	# Free him, and hear him out: saved.
	_put(g, p, folk.pip_landing() + Vector2(0, 20))
	await _frames(4)
	for k in Folk.CAGE_BLOWS:
		folk.strike_cage(0)
		await _frames(2)
	_check(folk.pip == 1, "(freed)")
	await _wait(func(): return g.ui.talking(), 240)
	var written: int = g.saves_written
	await _hear_out(g, p)
	_check(g.saves_written > written and int(Save.read(Save.WORLDS, id)["folk"]["pip"]) == 1 and Save.read(Save.WORLDS, id)["folk"]["found"] == ["roost"], "when he has said his piece the world is saved: he is free (%s)" % str(Save.read(Save.WORLDS, id).get("folk")))
	# Mend the stone: saved.
	g.tools.bag_of(0).add("copper_bar", Folk.REPAIR_COPPER)
	_put(g, p, folk.stone_spot())
	await _frames(4)
	written = g.saves_written
	await _press(p, "interact_pressed")
	var on_disk := Save.read(Save.WORLDS, id)
	_check(g.saves_written > written and on_disk["folk"]["stones"] == ["watchpost"] and on_disk["folk"]["found"] == ["roost", "watch"], "mending the waystone saves the world (%s)" % str(on_disk.get("folk")))
	_check(Save.read(Save.CHARACTERS, str(who["id"])).get("bag") is Array, "(and the character, whose copper it was)")
	await _wait(func(): return not folk.mending, 120)
	await _leave(g)
	# Played again: he has walked home, the stone is lit.
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, str(who["id"]))], Save.read(Save.WORLDS, id))
	await _frames(5)
	folk = g.folk
	p = g.players[0]
	_check(folk.pip == 2 and folk.pip_actor.visible and folk.pip_actor.position.distance_to(folk.pip_home() - Vector2(0, Folk.SORT_BIAS)) < 0.5 and folk.cage.anim == "empty", "played again: the cage is empty and Pip is at the cave mouth")
	_check(folk.lit("watchpost") and folk.stone.anim == "waystone_lit" and g.hall.rows().has(ForgeHall.TRAVEL_ROW), "the waystone is lit, and the forge's screen has its row")
	_check(folk.found.has("roost") and folk.found.has("watch") and _quest(folk, "watch").is_empty() and str(_quest(folk, "smoke").get("text", "")).begins_with("Pip is on his way"), "and the quests are where they were")
	_check(not folk.strike_cage(0), "(the cage cannot be broken twice)")
	written = g.saves_written
	g.save_now()
	_check(g.saves_written == written, "nothing is written again while nothing has changed")
	# Meet him: saved.
	_put(g, p, folk.pip_home() + Vector2(0, 28))
	await _frames(4)
	await _press(p, "interact_pressed")
	await _hear_out(g, p)
	_check(folk.pip == 3 and int(Save.read(Save.WORLDS, id)["folk"]["pip"]) == 3, "meeting him at the base saves the world: his shop is open")
	g.loot.purses[0].coins = 40
	await _frames(6)
	await _press(p, "interact_pressed")
	_check(folk.shop.is_open, "(the shop)")
	await _frames(12)
	folk.shop.confirm()
	written = g.saves_written
	folk.shop.close()
	await _frames(3)
	var me := Save.read(Save.CHARACTERS, str(who["id"]))
	_check(g.saves_written > written and int(me.get("coins", -1)) == 40 - Folk.TIN_PRICE, "leaving the shop saves what was bought (%s coins)" % str(me.get("coins")))
	await _leave(g)
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, str(who["id"]))], Save.read(Save.WORLDS, id))
	await _frames(5)
	folk = g.folk
	_check(folk.pip == 3 and not _quest(folk, "crown").is_empty() and g.tools.bag_of(0).count("tin_bar") == 1, "played again: the Scrap Crown is the quest, and the bar is in the bag")
	# What a save might hold that makes no sense is passed over.
	folk.set_world_data({"folk": "pip"})
	_check(folk.pip == 0 and folk.stones.is_empty() and folk.found.is_empty() and folk.cage.anim == "idle" and not folk.pip_actor.visible and folk.stone.anim == "waystone_broken", "a save that makes no sense is a world where nothing has happened yet")
	folk.set_world_data({"folk": {"pip": 99, "stones": "all", "found": [1, "roost", ["x"]]}})
	_check(folk.pip == 3 and folk.stones.is_empty() and folk.found.keys() == ["roost"], "it is read as far as it makes sense")
	folk.set_world_data({"folk": {"pip": "free", "stones": [3, "watchpost"], "found": {}}})
	_check(folk.pip == 0 and folk.lit("watchpost") and folk.found.is_empty() and folk.stone.anim == "waystone_lit", "(a stone's name is a name)")
	folk.set_world_data({"folk": {"pip": 1.0}})
	_check(folk.pip == 2, "a world left while Pip stood at the Roost finds him at the base")
	await _leave(g)             # (leaving saves: the file now holds that last one)
	# A world from before version 46.
	var old_world := Save.read(Save.WORLDS, id)
	old_world.erase("folk")
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, str(who["id"]))], old_world)
	await _frames(5)
	_check(g.folk.pip == 0 and g.folk.stones.is_empty() and not g.relaid and g.folk.quests().size() == 1, "a world saved before there was a Pip plays on, with him in his cage")
	await _leave(g)
	_check(Save.read(Save.WORLDS, id).get("folk") == {"pip": 0, "stones": [], "found": []} or int(Save.read(Save.WORLDS, id)["folk"]["pip"]) == 0, "(and from then on its file says so)")
	# A world whose land is laid out again keeps what happened in it.
	var old_land := Save.read(Save.WORLDS, id)
	old_land["land"] = WorldGen.GEN - 1
	old_land["folk"] = {"pip": 3, "stones": ["watchpost"], "found": ["roost", "watch"]}
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, str(who["id"]))], old_land)
	await _frames(5)
	_check(g.relaid and g.folk.pip == 3 and g.folk.lit("watchpost"), "a world laid out again keeps Pip free and its stone lit")
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
	var g = _game(shot_seed, 1, true)
	await _frames(10)
	var folk = g.folk
	var foes = g.foes
	var p = g.players[0]
	p.unhurt = true
	g.land.settle()
	await _frames(30)
	g.loot.give(0, "memory", 45, p.global_position)
	await _frames(90)
	await _snap("01_the_first_quest_and_the_memory_bar")
	# The Roost, held.
	var group := int(folk.plan["roost"]["group"])
	_put(g, p, folk.pip_landing() + Vector2(-70, 60))
	g.land.settle()
	await _wait(func(): return foes.packs.has(group), 180)
	await _frames(50)
	await _snap("02_the_roost_held")
	_put(g, p, folk.pip_landing() + Vector2(0, 22))
	await _frames(6)
	await _snap("03_clear_the_roost_first")
	if foes.packs.has(group):
		for e in foes.packs[group].members.duplicate():
			e.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
		foes.packs[group].alert = false
	await _frames(100)
	_put(g, p, folk.pip_landing() + Vector2(0, 22))
	await _frames(20)
	await _snap("04_break_the_cage")
	folk.strike_cage(0)
	await _frames(4)
	await _snap("05_a_blow")
	p.input.stick_aim = Vector2.UP          # (a tool swings where you were aiming as the swing began)
	await _frames(20)
	p.input.work_held = true
	await _frames(13)
	p.input.work_held = false
	await _snap("06_a_tool_strikes_it")
	await _frames(SWING_TICKS + 2)
	_put(g, p, folk.pip_landing() + Vector2(-44, 26))
	p.input.stick_aim = Vector2.RIGHT
	await _frames(4)
	while folk.pip == 0:
		folk.strike_cage(0)
	await _frames(10)
	await _snap("07_the_cage_breaks")
	await _wait(func(): return folk.cage.anim == "empty", 60)
	await _frames(14)
	await _snap("08_pip_is_out")
	await _wait(func(): return g.ui.talking(), 120)
	await _frames(100)
	await _snap("09_pip_speaks")
	await _hear_out(g, p)
	await _frames(20)
	await _snap("10_pip_is_free")
	await _frames(240)
	await _snap("11_pip_waits_at_the_roost")
	# At the base.
	_put(g, p, folk.forge_spot())
	g.land.settle()
	await _frames(30)
	await _snap("12_pip_at_the_cave_mouth")
	_put(g, p, folk.pip_home() + Vector2(40, 16))
	p.input.stick_aim = Vector2.LEFT
	await _frames(20)
	await _snap("13_talk_to_pip")
	await _press(p, "interact_pressed")
	await _frames(140)
	await _snap("14_pip_tells_of_the_horn")
	await _hear_out(g, p)
	await _frames(20)
	await _snap("15_the_scrap_crown")
	g.loot.purses[0].coins = 27
	await _frames(200)
	await _press(p, "interact_pressed")
	await _idle(20)
	await _snap("16_the_shop")
	folk.shop.confirm()
	await _idle(10)
	await _snap("17_a_bar_bought")
	folk.shop.move(1)
	folk.shop.confirm()
	folk.shop.confirm()
	folk.shop.confirm()
	await _idle(10)
	await _snap("18_too_few_coins")
	folk.shop.row = folk.shop.rows().find(Shop.ASK)
	folk.shop.confirm()
	await _idle(10)
	await _snap("19_asked_about_the_horn")
	folk.shop.close()
	await _frames(6)
	# The waystone.
	foes.on = false
	var bag = g.tools.bag_of(0)
	bag.take("copper_bar", bag.count("copper_bar"))
	bag.add("copper_bar", 2)
	_put(g, p, folk.stone_spot() + Vector2(-50, 40))
	g.land.settle()
	await _frames(40)
	for k in foes.packs.keys():
		foes._sleep(k)
	await _frames(10)
	await _snap("20_the_broken_waystone")
	_put(g, p, folk.stone_spot() + Vector2(-8, 2))
	await _frames(10)
	await _snap("21_what_it_needs")
	await _press(p, "interact_pressed")
	await _frames(20)
	await _snap("22_not_enough_copper")
	bag.add("copper_bar", 6)
	await _frames(200)
	await _press(p, "interact_pressed")
	await _frames(22)
	await _snap("23_the_copper_goes_in")
	await _frames(24)
	await _snap("24_mending")
	await _wait(func(): return not folk.mending, 120)
	await _frames(30)
	await _snap("25_the_waystone_lit")
	await _frames(220)
	await _snap("26_travel_to_the_forge")
	await _press(p, "interact_pressed")
	await _frames(10)
	await _snap("27_on_the_way")
	await _wait(func(): return not folk.travelling(), 120)
	g.land.settle()
	await _frames(40)
	await _snap("28_at_the_forge")
	g._use_forge(0)
	await _idle(20)
	g.hall.row = g.hall.rows().size() - 2
	await _idle(6)
	await _snap("29_the_forge_has_a_row_for_it")
	g.hall.close()
	await _frames(6)
	await _leave(g)
	# Two players.
	g = _game(shot_seed, 2)
	await _frames(10)
	folk = g.folk
	g.land.settle()
	folk.pip = 3
	folk.found["watch"] = true
	folk._show()
	g.loot.purses[1].coins = 14
	g.tools.bag_of(0).add("copper_bar", 2)
	g.tools.bag_of(1).add("copper_bar", 1)
	_put(g, g.players[0], folk.pip_home() + Vector2(84, 40))
	_put(g, g.players[1], folk.pip_home() + Vector2(42, 16))
	g.players[0].input.stick_aim = Vector2.LEFT
	g.players[1].input.stick_aim = Vector2.LEFT
	await _frames(40)
	await _snap("30_two_players_the_quests")
	await _press(g.players[1], "interact_pressed")
	await _idle(20)
	await _snap("31_two_players_the_shop")
	folk.shop.close()
	await _frames(4)
	_put(g, g.players[0], folk.stone_spot() + Vector2(-34, 10))
	_put(g, g.players[1], folk.stone_spot() + Vector2(20, 14))
	g.land.settle()
	await _frames(40)
	await _snap("32_two_players_the_waystone")
	await _leave(g)
