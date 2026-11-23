extends SceneTree
## The inventory, the Accessory Satchel, the accessories, the smoke over the Roost (version 47). Prints PASS / FAIL.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands_gear.gd
##
## With shots=/some/folder/ (needs a window, so leave out --headless) it saves 640x360 frames instead: the
## inventory's screen for one and two players, an accessory found, the compass, the smoke, Pip's portrait and his
## shop. "seed=123456" picks the world.

const PlayerInput := preload("res://scripts/player_input.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const FoePlan := preload("res://scripts/highlands/foe_plan.gd")
const LootPlan := preload("res://scripts/highlands/loot_plan.gd")
const Loot := preload("res://scripts/highlands/loot.gd")
const Folk := preload("res://scripts/highlands/folk.gd")
const Tools := preload("res://scripts/highlands/tools.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")
const Bag := preload("res://scripts/highlands/bag.gd")
const Gear := preload("res://scripts/highlands/gear.gd")
const Accessories := preload("res://scripts/highlands/accessories.gd")
const PackScreen := preload("res://scripts/ui/pack_screen.gd")
const Shop := preload("res://scripts/ui/shop.gd")
const SavePick := preload("res://scripts/ui/save_pick.gd")
const Make := preload("res://scripts/foes/make.gd")
const Save := preload("res://scripts/save.gd")
const Sim := preload("res://scripts/sim.gd")
const Art := preload("res://scripts/art.gd")
const Lab := preload("res://scripts/lab.gd")
const TILE := 32.0
const SWING_TICKS := 29
const ROOT := "user://test_gear_saves"
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
	_shapes()
	_bag()
	_plans()
	await _satchel()
	await _effects()
	await _two_effects()
	await _found()
	await _compass()
	await _screen()
	await _two_screens()
	await _lab()
	await _smoke()
	await _pips_ware()
	await _saved()
	print("%s  the inventory and the accessories: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func _game(seed_value: int, players := 1, foes := false, characters: Array = [], world := {}, kinds: Array = []):
	var g = Highlands.new()
	var inputs: Array = []
	for i in players:
		if i < kinds.size():
			inputs.append(PlayerInput.make(str(kinds[i]), 0))
		else:
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
	if g.packs != null:
		g.packs.close_all()
	if g.hall != null and g.hall.is_open:
		g.hall.close()
	if g.folk != null and g.folk.shop.is_open:
		g.folk.shop.close()
	paused = false
	Bag.LAB_PACK = 0
	Gear.LAB_SATCHEL = 0
	Gear.LAB_GIVE = 0
	g.queue_free()
	await _frames(3)


func _press(p, field: String) -> void:
	await physics_frame
	p.input.set(field, true)
	await physics_frame
	p.input.set(field, false)
	await physics_frame


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


func _button(button: int, device := 0) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	ev = InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = false
	Input.parse_input_event(ev)
	await _frames(2)


func _fresh_folder(path: String) -> void:
	for sub in ["characters", "worlds", "deleted"]:
		var dir := DirAccess.open("%s/%s" % [path, sub])
		if dir != null:
			for f in dir.get_files():
				dir.remove(f)
	Save.root = path


## Does a line of news end short of the quests' corner (it is centred on the screen)?
func _fits(g, line: String) -> bool:
	return 320.0 + (g.loot._head_width(line) + 12.0) * 0.5 <= g.folk.track_at().x - 2.0


func _kind(g, kind: String, skip := 0) -> int:
	for k in g.loot.chests.size():
		if str(g.loot.chests[k]["plan"]["kind"]) == kind:
			if skip == 0:
				return k
			skip -= 1
	return -1


func _as_set(cells: Array) -> Dictionary:
	var out := {}
	for c in cells:
		out[c] = true
	return out


## Everything player i has of one accessory: in the inventory and worn.
func _has(g, i: int, id: String) -> int:
	var n: int = g.tools.bag_of(i).count(id)
	for w in g.gear.kits[i].worn:
		if w["id"] == id:
			n += 1
	return n


# --- The pictures are there, and agree with the rules ------------------------------------------

func _art() -> void:
	var book: Dictionary = Art.json("accessories/accessories.json")
	var items: Dictionary = book.get("items", {})
	_check(Accessories.ORDER.size() == 12 and Accessories.ITEMS.size() == 12 and items.size() == 12, "the twelve accessories, in the rules and in the art's book")
	for id in Accessories.ORDER:
		var icon := Art.texture("accessories/%s_icon.png" % id)
		var pack := Art.texture("accessories/%s_pack.png" % id)
		var box := Accessories.box(id)
		_check(icon != null and icon.get_size() == Vector2(24, 24), "%s has its 24 by 24 picture for the inventory" % id)
		_check(pack != null and pack.get_size() == Vector2(box) * 24.0, "%s has its picture for the satchel, the size of its box (%s cells)" % [id, str(box)])
		var theirs: Array = []
		for c in items.get(id, {}).get("cells", []):
			theirs.append([int(c[0]), int(c[1])])
		var ours: Array = Accessories.ITEMS[id]["cells"]
		_check(str(theirs) == str(ours), "%s takes the cells its picture was drawn for (%s)" % [id, str(theirs)])
		_check(str(items.get(id, {}).get("name", "")) == Accessories.name_of(id) and Accessories.text_of(id) != "", "%s is called what the art's book calls it, and says what it does" % id)
	for name in ["cell", "cell_filled", "cell_ok", "cell_blocked"]:
		var tex := Art.texture("accessories/%s.png" % name)
		_check(tex != null and tex.get_size() == Vector2(24, 24), "the satchel's %s is in the game" % name)
	for name in ["slot", "slot_hover", "slot_cursor", "pack_hide", "satchel_hide"]:
		_check(ItemArt.size(name) == Vector2(24, 24), "the inventory art's %s is found (24 by 24)" % name)
	for item in Bag.ORDER:
		_check(ItemArt.size("item_" + item) == Vector2(16, 16) and Bag.name_of(item) != "" and Bag.text_of(item) != "", "%s has its picture, its name and a line about it" % item)
	_check(ItemArt.find("item_stone")[0] == Art.texture("tools/tools.png"), "(what was on the older sheets is still taken from them)")
	var smoke := Art.texture("smoke/smoke.png")
	var puff: Dictionary = Art.json("smoke/smoke.json").get("sprites", {}).get("smoke_puff", {})
	_check(smoke != null and int(puff.get("frames", 0)) == 4 and puff.get("frame") == [18.0, 14.0] or (smoke != null and int(puff.get("frames", 0)) == 4 and int(puff["frame"][0]) == 18 and int(puff["frame"][1]) == 14), "the smoke's four puffs are in the game")
	if smoke != null and puff.has("box"):
		_check(int(puff["box"][0]) + int(puff["box"][2]) <= smoke.get_width() and int(puff["box"][1]) + int(puff["box"][3]) <= smoke.get_height(), "(inside their sheet)")
	var face := Art.texture(Folk.FACE)
	_check(face != null and face.get_size() == Vector2(48, 48) and face.get_size() == Art.texture("cave/smith_portrait.png").get_size(), "Pip's portrait is in the game, the smith's size")


# --- Shapes and turning ---------------------------------------------------------------------

func _shapes() -> void:
	_check(str(Accessories.cells("bandolier", 0)) == str([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]) and Accessories.box("bandolier") == Vector2i(1, 3), "the Bandolier is one wide and three tall")
	_check(_as_set(Accessories.cells("bandolier", 1)) == _as_set([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]) and Accessories.box("bandolier", 1) == Vector2i(3, 1), "turned a quarter it is three wide and one tall")
	_check(_as_set(Accessories.cells("field_rations", 0)) == _as_set([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]), "Field Rations are an L")
	_check(_as_set(Accessories.cells("field_rations", 1)) == _as_set([Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1)]), "a quarter turn clockwise: the L's foot comes round to the top")
	_check(_as_set(Accessories.cells("field_rations", 2)) == _as_set([Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0)]), "half a turn")
	_check(_as_set(Accessories.cells("field_rations", 3)) == _as_set([Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]), "three quarters")
	for id in Accessories.ORDER:
		var n: int = (Accessories.ITEMS[id]["cells"] as Array).size()
		var ok := true
		for rot in 5:
			var cells := Accessories.cells(id, rot)
			var box := Accessories.box(id, rot)
			if cells.size() != n or _as_set(cells).size() != n:
				ok = false
			var touch_left := false
			var touch_top := false
			for c: Vector2i in cells:
				if c.x < 0 or c.y < 0 or c.x >= box.x or c.y >= box.y:
					ok = false
				touch_left = touch_left or c.x == 0
				touch_top = touch_top or c.y == 0
			if not touch_left or not touch_top:
				ok = false
		_check(ok and _as_set(Accessories.cells(id, 4)) == _as_set(Accessories.cells(id, 0)), "%s keeps its cells through every turn, inside its box and against its top left corner" % id)
		_check(Accessories.turns(id) == (n > 1), "%s %s" % [id, "can be turned" if n > 1 else "is one cell: it has no turn"])
	_check(Accessories.POOL.size() == 11 and not Accessories.POOL.has("dowsing_rod") and Accessories.POOL.all(func(id): return Accessories.has(id)), "every accessory but the Dowsing Rod can be found (there is nothing buried for it yet)")
	_check(not Accessories.has("stone") and not Accessories.has(3) and Accessories.name_of("mystery_thing") == "Mystery Thing", "(what is not an accessory is not taken for one)")


# --- The one inventory ------------------------------------------------------------------------

func _bag() -> void:
	var b := Bag.new()
	_check(Bag.SLOTS == 24 and Bag.COLS == 6 and Bag.STACK == 99 and b.cap() == 24, "the inventory: 24 slots in rows of six, 99 to a stack")
	_check(b.add("stone", 150) == 150 and b.slots.size() == 2, "materials lie in stacks")
	_check(b.add("thorn_charm", 1) == 1 and b.add("thorn_charm", 1) == 1 and b.slots.size() == 4 and b.count("thorn_charm") == 2, "an accessory has a slot to itself")
	_check(b.add("bandolier", 1) == 1 and b.slots.size() == 5, "whatever its shape: the three-cell Bandolier takes one slot")
	_check(Bag.stack_of("stone") == 99 and Bag.stack_of("bandolier") == 1, "(99 to a stack, one to a slot)")
	_check(b.room("stone") == (24 - 5) * 99 + 48 and b.room("lucky_copper") == 24 - 5, "room: an accessory needs an empty slot")
	_check(Bag.name_of("bandolier") == "Bandolier" and Bag.name_of("tin_bar") == "Tin bar" and Bag.text_of("bandolier").contains("runes"), "it knows what everything is called and does")
	_check(b.take("thorn_charm", 1) and b.slots.size() == 4 and str(b.slots[2]) == str(["thorn_charm", 1]) and str(b.slots[3]) == str(["bandolier", 1]), "a slot that empties closes up, and the rest keep their order")
	_check(not b.take("lucky_copper", 1) and b.slots.size() == 4, "(taking what is not there takes nothing)")
	# Backpacks.
	_check(Bag.PACKS.size() == 4 and str(Bag.PACKS[1]["name"]) == "Hide Pack", "the backpacks: none, the Hide Pack and two after it")
	var sizes: Array = []
	for k in Bag.PACKS.size():
		b.pack = k
		sizes.append(b.cap())
	_check(sizes == [24, 30, 36, 48], "a backpack adds rows of six: %s slots" % str(sizes))
	b.pack = 0
	Bag.LAB_PACK = 2
	_check(b.cap() == 36 and b.pack_now() == 2, "until they can be made the lab says which one everybody carries")
	b.pack = 3
	_check(b.cap() == 48, "(the character's own counts if it is larger)")
	b.pack = 0
	Bag.LAB_PACK = 0
	# Made smaller: nothing is lost.
	var big := Bag.new()
	big.pack = 1
	for n in 30:
		big.add("lucky_copper", 1)
	_check(big.slots.size() == 30 and big.room("stone") == 0, "(a Hide Pack, full: 30 accessories)")
	big.pack = 0
	_check(big.cap() == 24 and big.slots.size() == 30 and big.count("lucky_copper") == 30, "the backpack taken off: everything that was in it is still there")
	_check(big.add("stone", 5) == 0 and big.room("stone") == 0 and big.room("lucky_copper") == 0, "and nothing new goes in")
	_check(big.take("lucky_copper", 7) and big.slots.size() == 23 and big.add("stone", 5) == 5, "until room has been made")
	var full := Bag.new()
	full.add("stone", 24 * 99)
	full.put_back("iron_bracer")
	_check(full.slots.size() == 25 and full.count("iron_bracer") == 1, "something that must not be lost lies past the last slot of a full inventory")
	# What a save holds.
	var old: Array = []
	for n in 20:
		old.append(["stone" if n < 12 else "tin_ore", 99.0])
	var read := Bag.new()
	read.set_data(old)
	_check(read.slots.size() == 20 and read.count("stone") == 12 * 99 and read.count("tin_ore") == 8 * 99 and read.room("wood") == 4 * 99, "a full materials bag from before version 47 is read as it is: its 20 stacks, and four slots free")
	var copy := Bag.new()
	copy.set_data(b.data())
	_check(str(copy.data()) == str(b.data()), "the inventory is saved and read back as it was")
	read.set_data([["stone", 500], ["bandolier", 5], ["wood", -2], "x", ["wood"], [3, 3], ["wood", "many"], null, ["tin_bar", 7]])
	_check(str(read.data()) == str([["stone", 99], ["bandolier", 1], ["tin_bar", 7]]), "a save that makes no sense is read as far as it does (%s)" % str(read.data()))
	read.set_data("nothing")
	_check(read.slots.is_empty(), "(and one that is no list at all is an empty inventory)")
	var many: Array = []
	for n in 200:
		many.append(["stone", 99])
	read.set_data(many)
	_check(read.slots.size() == Bag.MOST, "(a save holds 96 slots at the very most)")


# --- Which chests hold an accessory, on any land ------------------------------------------------

func _plans() -> void:
	var holds := {"plain": 0, "rich": 0}
	var of := {"plain": 0, "rich": 0}
	for seed_value in SEEDS:
		var map: LandMap = WorldGen.make(seed_value)
		var groups := FoePlan.make(map)
		var chests := LootPlan.make(map, groups)
		var again := LootPlan.make(map, FoePlan.make(map))
		_check(str(chests) == str(again), "world %d: the same land's chests hold the same things twice" % seed_value)
		var was := float(LootPlan.GIFT)
		var rich_was := float(LootPlan.RICH_GIFT)
		LootPlan.GIFT = 0.0
		LootPlan.RICH_GIFT = 0.0
		var bare := LootPlan.make(map, groups)
		LootPlan.GIFT = was
		LootPlan.RICH_GIFT = rich_was
		var same := bare.size() == chests.size()
		for k in mini(bare.size(), chests.size()):
			var a: Dictionary = (chests[k] as Dictionary).duplicate()
			var b: Dictionary = (bare[k] as Dictionary).duplicate()
			a.erase("gift")
			b.erase("gift")
			if str(a) != str(b):
				same = false
		_check(same, "world %d: an accessory is on top of what a chest held before: its coins, bars, Memory and place are as they were" % seed_value)
		for c in chests:
			var gift := str(c.get("gift", ""))
			_check(gift == "" or Accessories.POOL.has(gift), "(a chest's accessory is one that can be found)")
			match str(c["kind"]):
				"first":
					_check(gift != "", "world %d: the first chest, by the cave, always holds an accessory (%s)" % [seed_value, gift])
				"sealed", "site":
					of["rich"] += 1
					holds["rich"] += 1 if gift != "" else 0
				_:
					of["plain"] += 1
					holds["plain"] += 1 if gift != "" else 0
	var plain := float(holds["plain"]) / maxf(float(of["plain"]), 1.0)
	var rich := float(holds["rich"]) / maxf(float(of["rich"]), 1.0)
	print("      (%d of %d ordinary chests hold an accessory, %d of %d sealed or named ones)" % [holds["plain"], of["plain"], holds["rich"], of["rich"]])
	_check(absf(plain - float(LootPlan.GIFT)) < 0.07, "about %d%% of ordinary chests hold one (%d%%)" % [roundi(float(LootPlan.GIFT) * 100.0), roundi(plain * 100.0)])
	_check(absf(rich - float(LootPlan.RICH_GIFT)) < 0.12, "about %d%% of sealed and named places' chests (%d%%)" % [roundi(float(LootPlan.RICH_GIFT) * 100.0), roundi(rich * 100.0)])


# --- The satchel ------------------------------------------------------------------------------

func _satchel() -> void:
	var g = _game(424242)
	await _frames(5)
	var gear = g.gear
	var bag: Bag = g.tools.bag_of(0)
	var p = g.players[0]
	_check(gear != null and g.packs != null and gear.kits.size() == 1 and p.gear == gear, "the Highlands has the satchel and the inventory's screen")
	_check(gear.size_of(0) == Vector2i(3, 3) and gear.satchel_now(0) == 0, "the first satchel is three by three")
	_check(not gear.wear(0, "tinkers_thimble", 0, 0, 0), "what you have not got cannot be worn")
	for id in ["tinkers_thimble", "tinkers_thimble", "bandolier", "field_rations", "iron_bracer"]:
		bag.add(id, 1)
	bag.add("stone", 40)
	_check(not gear.has(0, "tinkers_thimble") and gear.dodge_speed(p) == 1.0, "in the inventory an accessory does nothing")
	_check(gear.wear(0, "tinkers_thimble", 0, 0, 0) and bag.count("tinkers_thimble") == 1 and gear.has(0, "tinkers_thimble"), "worn: it leaves the inventory for the satchel")
	_check(is_equal_approx(gear.dodge_speed(p), float(Accessories.THIMBLE_DODGE)), "and works from that moment")
	_check(not gear.wear(0, "iron_bracer", 0, 0, 0) and bag.count("iron_bracer") == 1, "a taken cell takes nothing more")
	_check(not gear.wear(0, "stone", 1, 1, 0) and bag.count("stone") == 40, "only accessories go in the satchel")
	_check(gear.wear(0, "bandolier", 1, 0, 0) and gear.taken(0).size() == 4, "the Bandolier down the middle column takes three cells")
	_check(not gear.fits(0, "bandolier", 2, 1, 0) and not gear.fits(0, "bandolier", -1, 0, 0) and not gear.fits(0, "bandolier", 0, 3, 1), "nothing hangs over the edge")
	_check(not gear.fits(0, "field_rations", 0, 1, 0) and gear.first_fit(0, "field_rations").is_empty(), "the L of the Field Rations has nowhere to go now, whichever way it is turned")
	_check(gear.piece_at(0, Vector2i(1, 2)) == 1 and gear.piece_at(0, Vector2i(2, 2)) == -1, "(it knows which piece lies on a cell)")
	_check(gear.shift(0, 1, 0, 2, 1) and _as_set(gear.taken(0).keys()) == _as_set([Vector2i(0, 0), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]), "the Bandolier turned and laid along the bottom row")
	_check(not gear.shift(0, 1, 0, 0, 1) and int(gear.kits[0].worn[1]["y"]) == 2, "(a move that does not fit leaves the piece where it was)")
	var fit: Array = gear.first_fit(0, "field_rations")
	_check(fit.size() == 3 and gear.fits(0, "field_rations", fit[0], fit[1], fit[2]), "and now the Field Rations fit (%s)" % str(fit))
	var hp_was: float = p.max_hp
	_check(gear.wear(0, "field_rations", fit[0], fit[1], fit[2]) and is_equal_approx(p.max_hp, hp_was * float(Accessories.RATIONS_HEALTH)), "worn, they are more health at once (%d)" % int(p.max_hp))
	_check(gear.wear(0, "tinkers_thimble", 2, 0, 0) or gear.wear(0, "tinkers_thimble", 2, 1, 0) or gear.wear(0, "tinkers_thimble", 1, 0, 0), "(a second Thimble can be worn)")
	_check(is_equal_approx(gear.dodge_speed(p), float(Accessories.THIMBLE_DODGE)), "two of the same do no more than one")
	# Taking off.
	var k: int = gear.piece_at(0, Vector2i(0, 0))
	_check(gear.stow(0, k) and bag.count("tinkers_thimble") == 1, "taken off: back into the inventory")
	_check(gear.has(0, "tinkers_thimble"), "(the other Thimble is still worn)")
	var rations := -1
	for n in gear.kits[0].worn.size():
		if gear.kits[0].worn[n]["id"] == "field_rations":
			rations = n
	p.hp = p.max_hp * 0.5
	_check(gear.stow(0, rations) and is_equal_approx(p.max_hp, hp_was) and is_equal_approx(p.hp, hp_was * 0.5), "the Field Rations off: the health they gave goes, and you keep the same share")
	var held: int = bag.slots.size()
	bag.add("wood", bag.room("wood"))
	_check(bag.room("iron_bracer") == 0 and not gear.stow(0, 0) and gear.kits[0].worn.size() == 2, "with a full inventory a piece stays in the satchel")
	bag.take("wood", bag.count("wood"))
	_check(bag.slots.size() == held, "(room again)")
	# Deep Pockets.
	g.levels.level = 5
	g.levels.perks[0] = ["deep_pockets"]
	_check(gear.size_of(0) == Vector2i(3, 4), "the Delver's Deep Pockets: one more row")
	_check(gear.wear(0, "iron_bracer", 1, 3, 0), "(something on the new row)")
	g.levels.perks[0] = []
	await _frames(2)
	_check(gear.size_of(0) == Vector2i(3, 3) and not gear.has(0, "iron_bracer") and bag.count("iron_bracer") == 1, "the perk forgotten: what was on that row is back in the inventory, not lost")
	# The lab's satchels.
	var sizes: Array = []
	for n in Gear.SATCHELS.size():
		Gear.LAB_SATCHEL = n
		sizes.append(gear.size_of(0))
	_check(sizes == [Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 5)], "the satchels: %s" % str(sizes))
	_check(gear.wear(0, "iron_bracer", 4, 4, 0), "(the Large Satchel: something in its far corner)")
	bag.add("stone", bag.room("stone"))
	bag.add("wood", bag.room("wood"))
	Gear.LAB_SATCHEL = 0
	await _frames(2)
	_check(not gear.has(0, "iron_bracer") and bag.count("iron_bracer") == 1 and bag.slots.size() == bag.cap() + 1, "the satchel made smaller with a full inventory: the piece lies past the last slot, not lost")
	await _leave(g)


# --- What each accessory does -----------------------------------------------------------------

## Wears it at the first place it fits (it is put in the inventory first).
func _wear(g, i: int, id: String) -> bool:
	g.tools.bag_of(i).add(id, 1)
	var fit: Array = g.gear.first_fit(i, id)
	return not fit.is_empty() and g.gear.wear(i, id, fit[0], fit[1], fit[2])


func _strip(g, i: int) -> void:
	while not g.gear.kits[i].worn.is_empty():
		g.gear.stow(i, 0)
	var bag: Bag = g.tools.bag_of(i)
	for id in Accessories.ORDER:
		bag.take(id, bag.count(id))


func _clear(m: LandMap, at: Vector2) -> bool:
	for t in m.things:
		if Painter.things.get(str(t["n"]), {}).has("solid") and (Vector2(float(t["x"]), float(t["y"])) * 2.0).distance_to(at) < 56.0:
			return false
	return true


## A tile of this kind with open ground beside it to stand on, away from the base: [the tile, the way to face it].
func _face(m: LandMap, kind: int, skip := 0) -> Array:
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
						if skip > 0:
							skip -= 1
							continue
						return [t, Vector2(-d)]
	return []


## Mines the nearest tile of tin ore. How much ore it gave.
func _mine(g, p, skip := 0) -> int:
	var ore := _face(g.map, LandMap.TIN, skip)
	if ore.is_empty():
		return -1
	var before: int = g.tools.bag_of(0).count("tin_ore")
	p.global_position = (Vector2(ore[0]) + Vector2(0.5, 0.5) - ore[1]) * TILE
	p.input.stick_aim = ore[1]
	p.input.move = Vector2.ZERO
	g.rig.snap()
	await _frames(4)
	g.land.settle()
	p.input.work_held = true
	await _wait(func(): return g.map.kind(ore[0].x, ore[0].y) != LandMap.TIN, SWING_TICKS * 12)
	p.input.work_held = false
	await _frames(SWING_TICKS + 2)
	return g.tools.bag_of(0).count("tin_ore") - before


func _effects() -> void:
	var g = _game(424242)
	await _frames(5)
	var gear = g.gear
	var p = g.players[0]
	var bag: Bag = g.tools.bag_of(0)
	var purse = g.loot.purses[0]
	# Tinker's Thimble.
	p.dodge_charges = 0
	p.dodge_refill = 0.0
	var plain := await _wait(func(): return p.dodge_charges >= 1, 200)
	_check(_wear(g, 0, "tinkers_thimble"), "(the Thimble on)")
	p.dodge_charges = 0
	p.dodge_refill = 0.0
	var quick := await _wait(func(): return p.dodge_charges >= 1, 200)
	_check(plain > 0 and quick > 0 and absf(float(plain) / float(quick) - float(Accessories.THIMBLE_DODGE)) < 0.06, "Tinker's Thimble: the dodge is back in %d ticks, not %d" % [quick, plain])
	_strip(g, 0)
	# Bandolier.
	_check(gear.rune_speed(p) == 1.0, "(no Bandolier: runes come back as ever)")
	if p.ability_charge.size() > 0:
		p.ability_charge[0] = 0.0
		await _frames(30)
		var slow := float(p.ability_charge[0])
		_check(_wear(g, 0, "bandolier"), "(the Bandolier on)")
		p.ability_charge[0] = 0.0
		await _frames(30)
		var fast := float(p.ability_charge[0])
		_check(slow > 0.0 and absf(fast / slow - float(Accessories.BANDOLIER_RUNES)) < 0.02, "Bandolier: an active rune recharges %d%% as fast" % roundi(fast / maxf(slow, 0.0001) * 100.0))
	else:
		_check(_wear(g, 0, "bandolier") and is_equal_approx(gear.rune_speed(p), float(Accessories.BANDOLIER_RUNES)), "Bandolier: active runes come back faster")
	_strip(g, 0)
	# Field Rations (and the lab changing everybody's health under them).
	var base: float = p.MAX_HP
	_check(_wear(g, 0, "field_rations") and is_equal_approx(p.max_hp, base * float(Accessories.RATIONS_HEALTH)), "Field Rations: 15%% more health (%d)" % int(p.max_hp))
	p.MAX_HP = 200.0
	g.lab_changed()
	_check(is_equal_approx(p.max_hp, 200.0 * float(Accessories.RATIONS_HEALTH)), "(the lab changes everyone's health: the Rations are on top of the new number)")
	p.MAX_HP = base
	g.lab_changed()
	_strip(g, 0)
	_check(is_equal_approx(p.max_hp, base), "(and off again)")
	# Hearthstone Pebble.
	p.hp = 50.0
	await _frames(300)
	_check(is_equal_approx(p.hp, 50.0), "(without the Pebble nothing heals you)")
	_check(_wear(g, 0, "hearthstone_pebble"), "(the Pebble on)")
	gear.kits[0].calm = 0.0
	await _frames(int(float(Accessories.PEBBLE_WAIT) * 60.0) - 6)
	_check(is_equal_approx(p.hp, 50.0), "Hearthstone Pebble: nothing for the first four seconds")
	await _frames(66)
	_check(absf(p.hp - (50.0 + p.max_hp * float(Accessories.PEBBLE_HEAL))) < 0.3, "then about 2%% of your health a second (%.1f after one)" % p.hp)
	var was: float = p.hp
	p.take_damage(5.0)
	await _frames(60)
	_check(is_equal_approx(p.hp, was - 5.0), "a hit puts it out again")
	p.invuln = 0.0
	gear.kits[0].calm = 10.0
	gear.dealt(p)
	_check(gear.kits[0].calm == 0.0, "and so does a hit of your own")
	p.hp = p.max_hp - 0.5
	gear.kits[0].calm = 10.0
	await _frames(120)
	_check(is_equal_approx(p.hp, p.max_hp), "(it never heals past full)")
	_strip(g, 0)
	# Ashen Locket.
	purse.memory = 100
	g.levels.fell(0, p.global_position)
	_check(purse.memory == 100 - roundi(100.0 * float(g.levels.FALL_MEMORY)), "(falling leaves half your Memory behind)")
	_check(_wear(g, 0, "ashen_locket"), "(the Locket on)")
	purse.memory = 100
	g.levels.fell(0, p.global_position + Vector2(40, 0))
	_check(purse.memory == 100 - roundi(100.0 * float(Accessories.LOCKET_SHARE)), "Ashen Locket: falling leaves a quarter behind (%d kept)" % purse.memory)
	_strip(g, 0)
	# Lucky Copper.
	_check(gear.coins(0, 10) == 10, "(no Lucky Copper: 10 coins are 10)")
	_check(_wear(g, 0, "lucky_copper") and gear.coins(0, 10) == 12 and gear.coins(0, 0) == 0, "Lucky Copper: 10 coins are 12")
	var k := _kind(g, "site")
	var c: Dictionary = g.loot.chests[k]["plan"]
	purse.coins = 0
	g.loot.open(k, 0)
	_check(purse.coins - (int(Loot.GIFT_COINS) if str(c.get("gift", "")) != "" and false else 0) == roundi(float(int(c["coins"])) * float(Accessories.LUCKY_COINS)), "a chest's coins come to a fifth more (%d for %d)" % [purse.coins, int(c["coins"])])
	_strip(g, 0)
	# Banner Pin (alone).
	p.hp = p.max_hp
	p.invuln = 0.0
	p.take_damage(20.0)
	_check(is_equal_approx(p.hp, p.max_hp - 20.0), "(no Banner Pin: a hit of 20 is 20)")
	_check(_wear(g, 0, "banner_pin"), "(the Pin on)")
	p.hp = p.max_hp
	p.invuln = 0.0
	p.take_damage(20.0)
	_check(is_equal_approx(p.hp, p.max_hp - 20.0 * (1.0 - float(Accessories.PIN_SOFTEN))), "Banner Pin: you take 5%% less (%.1f)" % (p.max_hp - p.hp))
	_strip(g, 0)
	# Iron Bracer.
	p.hp = p.max_hp
	p.invuln = 0.0
	p.take_damage(1.0, p.global_position + Vector2(50, 0))
	var thrown: float = p.hurt_vel.length()
	_check(_wear(g, 0, "iron_bracer"), "(the Bracer on)")
	p.invuln = 0.0
	p.hurt_vel = Vector2.ZERO
	p.take_damage(1.0, p.global_position + Vector2(50, 0))
	_check(thrown > 10.0 and absf(p.hurt_vel.length() / thrown - float(Accessories.BRACER_KNOCK)) < 0.01, "Iron Bracer: a hit throws you half as far")
	_strip(g, 0)
	# Thorn Charm.
	var near = Make.make("hound")
	g.world.add_child(near)
	near.global_position = p.global_position + Vector2(40, 0)
	var far = Make.make("hound")
	g.world.add_child(far)
	far.global_position = p.global_position + Vector2(float(Accessories.THORN_REACH) + 60.0, 0)
	await _frames(2)
	p.invuln = 0.0
	p.unhurt = false
	var near_hp: float = near.hp
	p.take_damage(1.0, near.global_position, near)
	_check(is_equal_approx(near.hp, near_hp), "(no Thorn Charm: an enemy that hits you takes nothing)")
	_check(_wear(g, 0, "thorn_charm"), "(the Charm on)")
	p.invuln = 0.0
	p.take_damage(1.0, near.global_position, near)
	_check(is_equal_approx(near.hp, near_hp - float(Accessories.THORN_DAMAGE)), "Thorn Charm: an enemy that hits you up close takes a small hit back (%.1f)" % (near_hp - near.hp))
	var far_hp: float = far.hp
	p.invuln = 0.0
	p.take_damage(1.0, far.global_position, far)
	_check(is_equal_approx(far.hp, far_hp), "one that hits you from farther off takes nothing")
	p.invuln = 0.0
	p.take_damage(1.0)
	p.invuln = 0.0
	p.take_damage(1.0, near.global_position)
	_check(is_equal_approx(near.hp, near_hp - float(Accessories.THORN_DAMAGE)), "(and a hit that is nobody's hurts nobody back)")
	near.queue_free()
	far.queue_free()
	_strip(g, 0)
	p.unhurt = true
	p.hp = p.max_hp
	# Prospector's Sieve.
	var gives := int(Tools.TILE_GIVES[LandMap.TIN][1])
	Sim.seed_with(3)
	_check(gear.extra_ore(0, "tin_ore") == 0, "(no Sieve: no more ore)")
	_check(_wear(g, 0, "prospectors_sieve"), "(the Sieve on)")
	var more := 0
	for n in 400:
		more += gear.extra_ore(0, "copper_ore")
	_check(absi(more - 100) < 30, "Prospector's Sieve: about one ore in four gives one more (%d of 400)" % more)
	_check(gear.extra_ore(0, "stone") == 0 and gear.extra_ore(0, "wood") == 0, "(only ore)")
	var chance_was := float(Accessories.SIEVE_CHANCE)
	Accessories.SIEVE_CHANCE = 1.0
	var got := await _mine(g, p)
	_check(got == gives + 1, "mined with the Sieve when the dice say so: one more ore (%d, not %d)" % [got, gives])
	Accessories.SIEVE_CHANCE = 0.0
	got = await _mine(g, p)
	_check(got == gives, "and when they do not: the usual (%d)" % got)
	Accessories.SIEVE_CHANCE = chance_was
	_strip(g, 0)
	# The Dowsing Rod is listed, can be worn, and does nothing yet.
	_check(_wear(g, 0, "dowsing_rod") and Accessories.text_of("dowsing_rod").contains("none to find yet"), "the Dowsing Rod can be worn, and says there is nothing for it to find yet")
	await _leave(g)


func _two_effects() -> void:
	var g = _game(424242, 2)
	await _frames(5)
	var gear = g.gear
	var a = g.players[0]
	var b = g.players[1]
	_check(gear.kits.size() == 2 and b.gear == gear, "two players: each has a satchel of their own")
	_check(_wear(g, 1, "banner_pin") and not gear.has(0, "banner_pin"), "(the second player wears the Banner Pin)")
	_put(g, a, b.global_position + Vector2(float(Accessories.PIN_REACH) - 20.0, 0))
	a.hp = a.max_hp
	a.invuln = 0.0
	a.take_damage(20.0)
	_check(is_equal_approx(a.hp, a.max_hp - 19.0), "Banner Pin: a teammate near the wearer takes 5% less too")
	_put(g, a, b.global_position + Vector2(float(Accessories.PIN_REACH) + 30.0, 0))
	a.hp = a.max_hp
	a.invuln = 0.0
	a.take_damage(20.0)
	_check(is_equal_approx(a.hp, a.max_hp - 20.0), "one farther off does not")
	_check(_wear(g, 0, "banner_pin"), "(both wear one)")
	_put(g, a, b.global_position + Vector2(40, 0))
	a.hp = a.max_hp
	a.invuln = 0.0
	a.take_damage(20.0)
	_check(is_equal_approx(a.hp, a.max_hp - 19.0), "two pins do no more than one")
	# What one wears is theirs alone.
	_check(_wear(g, 0, "tinkers_thimble") and gear.dodge_speed(a) > 1.0 and gear.dodge_speed(b) == 1.0, "what one player wears does nothing for the other")
	_check(_wear(g, 1, "field_rations") and b.max_hp > a.max_hp, "(nor does their health)")
	await _leave(g)


# --- Found in chests, and left by elites -----------------------------------------------------

func _found() -> void:
	var g = _game(424242)
	await _frames(5)
	var gear = g.gear
	var loot = g.loot
	var p = g.players[0]
	var bag: Bag = g.tools.bag_of(0)
	var purse = loot.purses[0]
	var k := _kind(g, "first")
	var gift := str(loot.chests[k]["plan"].get("gift", ""))
	_check(Accessories.POOL.has(gift), "(the first chest holds the %s)" % gift)
	loot.open(k, 0)
	_check(bag.count(gift) == 1 and not gear.has(0, gift), "opened: the accessory is in your inventory, not in use")
	_check(loot.said == "Found: %s" % Accessories.name_of(gift) and _fits(g, loot.said), "and the screen says so (\"%s\")" % loot.said)
	_check(is_equal_approx(gear.kits[0].nudged, gear.clock), "(and for a few seconds which button opens the inventory)")
	_check(Gear.key_words(false) == "Tab" and Gear.key_words(true) == "Click the left stick", "(Tab, or a click of the left stick)")
	# One you have already: coins in its place.
	var coins: int = purse.coins
	loot.gift(gift, p.global_position)
	_check(bag.count(gift) == 1 and purse.coins == coins + int(Loot.GIFT_COINS), "the same one again: %d coins in its place" % int(Loot.GIFT_COINS))
	_check(loot.said == "%s again: %d coins instead" % [Accessories.name_of(gift), int(Loot.GIFT_COINS)] and _fits(g, loot.said), "and the screen says so (\"%s\")" % loot.said)
	var fit: Array = gear.first_fit(0, gift)
	gear.wear(0, gift, fit[0], fit[1], fit[2])
	coins = purse.coins
	loot.gift(gift, p.global_position)
	_check(bag.count(gift) == 0 and purse.coins == coins + int(Loot.GIFT_COINS), "(one you are wearing is one you have)")
	loot.gift("", p.global_position)
	loot.gift("stone", p.global_position)
	_check(purse.coins == coins + int(Loot.GIFT_COINS) and bag.count("stone") == 0, "(a chest with no accessory gives none)")
	for id in Accessories.POOL:
		_check(_fits(g, "Found: %s" % Accessories.name_of(id)) and _fits(g, "%s again: %d coins instead" % [Accessories.name_of(id), int(Loot.GIFT_COINS)]), "the lines for the %s end short of the quests" % Accessories.name_of(id))
	# A full inventory: it lies on the ground until there is room.
	var other := "iron_bracer" if gift != "iron_bracer" else "thorn_charm"
	bag.add("stone", bag.room("stone"))
	bag.add("wood", bag.room("wood"))
	loot.gift(other, p.global_position + Vector2(60, 0))
	_check(bag.count(other) == 0 and loot.lying.size() == 1 and str(loot.lying[0]["item"]) == other, "with a full inventory the accessory lies where it fell")
	await _frames(60)
	_check(loot.lying.size() == 1, "(it stays there while there is no room)")
	bag.take("stone", 99)
	p.global_position = (loot.lying[0]["at"] as Vector2) + Vector2(0, 6)
	await _frames(8)
	_check(bag.count(other) == 1 and loot.lying.is_empty(), "and is picked up once there is room")
	bag.take("stone", bag.count("stone"))
	# Elites.
	var was := float(Loot.ELITE_GIFT)
	Loot.ELITE_GIFT = 1.0
	Sim.seed_with(11)
	var elite = Make.make("shaman", true)
	g.world.add_child(elite)
	elite.global_position = p.global_position + Vector2(40, 0)
	var before := 0
	for id in Accessories.ORDER:
		before += _has(g, 0, id)
	coins = purse.coins
	loot.foe_died(elite)
	var after := 0
	for id in Accessories.ORDER:
		after += _has(g, 0, id)
	_check(after == before + 1 or (after == before and loot.said.contains("again")), "an elite leaves an accessory when the dice say so (\"%s\")" % loot.said)
	_check(bag.count("dowsing_rod") == 0, "(never the Dowsing Rod)")
	Loot.ELITE_GIFT = 0.0
	before = after
	loot.foe_died(elite)
	after = 0
	for id in Accessories.ORDER:
		after += _has(g, 0, id)
	_check(after == before, "and none when they do not")
	# With its piece of the Warhorn, the piece's line is the one that stays up.
	Loot.ELITE_GIFT = 1.0
	var hound = Make.make("hound", true)
	g.world.add_child(hound)
	hound.global_position = p.global_position + Vector2(40, 0)
	loot.foe_died(hound)
	_check(loot.said.contains("Warhorn") and purse.kept.size() == 1, "an elite's piece of the Warhorn keeps the screen's line (\"%s\")" % loot.said)
	Loot.ELITE_GIFT = was
	elite.queue_free()
	hound.queue_free()
	await _leave(g)
	# Two players: each their own.
	g = _game(424242, 2)
	await _frames(5)
	loot = g.loot
	g.tools.bag_of(1).add(gift, 1)
	coins = loot.purses[1].coins
	loot.open(_kind(g, "first"), 0)
	_check(g.tools.bag_of(0).count(gift) == 1 and g.tools.bag_of(1).count(gift) == 1, "two players: everybody gets the accessory, each their own")
	_check(loot.said == "Found: %s" % Accessories.name_of(gift), "(the screen says it was found, as it is new to one of them)")
	_check(g.gear.kits[0].nudged > 0.0 and g.gear.kits[1].nudged < 0.0, "(the button is shown to the one it is new to)")
	await _leave(g)


# --- The Wayfinder's Compass ------------------------------------------------------------------

func _compass() -> void:
	var g = _game(424242)
	await _frames(40)
	var gear = g.gear
	var p = g.players[0]
	var map: LandMap = g.map
	p.unhurt = true
	_check(gear.visited.is_empty(), "(nowhere has been explored yet: the clearing by the cave is not one of the land's places)")
	_check(gear.kits[0].points == Vector2.INF and gear.arrow_for(0).is_empty(), "without the compass nothing points anywhere")
	_check(_wear(g, 0, "wayfinders_compass"), "(the compass on)")
	await _frames(40)
	var to: Vector2 = gear.kits[0].points
	_check(to != Vector2.INF, "Wayfinder's Compass: it points somewhere")
	var best := -1
	var best_d := INF
	for k in map.pockets.size():
		var pk: Dictionary = map.pockets[k]
		if gear.visited.has(k) or bool(pk.get("sealed", false)):
			continue
		var d: float = (p.global_position as Vector2).distance_to((pk["at"] as Vector2) * TILE)
		if d < best_d:
			best_d = d
			best = k
	_check(best >= 0 and to.is_equal_approx((map.pockets[best]["at"] as Vector2) * TILE), "at the nearest open place nobody has walked into")
	_check(not bool(map.pockets[best].get("sealed", false)), "(never at a place sealed in the rock)")
	var arrow: Array = gear.arrow_for(0)
	if best_d > 500.0:
		_check(arrow.size() == 2 and Rect2(26, 46, 588, 238).grow(1.0).has_point(arrow[0]) and (arrow[1] as Vector2).dot((to - p.global_position).normalized()) > 0.9, "its arrow is at the edge of the screen, on that side")
	# Walk into it: it is explored, and the compass points on.
	_put(g, p, to)
	await _frames(40)
	_check(gear.visited.has(best), "walked into, the place is explored")
	_check(gear.kits[0].points != to, "and the compass points at the next one")
	_check(gear.arrow_for(0).is_empty() or (gear.arrow_for(0)[0] as Vector2) != Vector2.ZERO, "(the arrow goes while the place it points at is in sight)")
	var seen: int = gear.visited.size()
	var data: Dictionary = gear.world_data()
	_check(data.has("visited") and (data["visited"] as Array).size() == seen, "where the squad has been is the world's to save")
	gear.set_world_data({"visited": [best, "x", -4, 999999]})
	_check(gear.visited.size() == 1 and gear.visited.has(best), "(and is read back, as far as it makes sense)")
	p.is_down = true
	_check(gear.arrow_for(0).is_empty(), "(no arrow for somebody who is down)")
	p.is_down = false
	await _leave(g)


# --- The inventory's screen --------------------------------------------------------------------

func _in(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(0.5).encloses(inner)


func _screen() -> void:
	var g = _game(424242, 1, false, [], {}, ["kbm"])
	await _frames(10)
	var gear = g.gear
	var packs = g.packs
	var bag: Bag = g.tools.bag_of(0)
	var p = g.players[0]
	bag.add("stone", 130)
	bag.add("tin_bar", 3)
	for id in ["tinkers_thimble", "bandolier", "field_rations", "iron_bracer"]:
		bag.add(id, 1)
	_check(not packs.any_open() and not paused, "(the inventory is shut)")
	await _key(KEY_TAB)
	_check(packs.is_open(0) and paused and packs.root.visible, "Tab opens the inventory, and the game stands still")
	var v = packs.views[0]
	_check(v.side == 0 and v.slot == 0 and v.held.is_empty(), "(the cursor is on the first slot)")
	_check(str(packs.under_cursor(0).get("id", "")) == "stone" and int(packs.under_cursor(0)["n"]) == 99, "which holds a stack of stone")
	await _frames(10)
	await _key(KEY_E)
	_check(v.held.is_empty() and v.note == "Only accessories go in the satchel.", "stone cannot be picked up for the satchel (\"%s\")" % v.note)
	await _key(KEY_D)
	await _key(KEY_D)
	_check(v.slot == 2 and str(packs.under_cursor(0)["id"]) == "tin_bar", "D moves the cursor along the row")
	await _key(KEY_S)
	_check(v.slot == 8, "S moves it down a row")
	await _key(KEY_W)
	await _key(KEY_W)
	_check(v.slot == 2, "(W back up, and no farther than the top)")
	await _key(KEY_D)
	_check(v.slot == 3 and str(packs.under_cursor(0)["id"]) == "tinkers_thimble" and not bool(packs.under_cursor(0)["worn"]), "the Thimble lies in a slot, not in use")
	# Pick up, put down.
	await _key(KEY_E)
	_check(str(v.held.get("id", "")) == "tinkers_thimble" and v.side == 1 and v.cell == Vector2i(0, 0), "E picks it up: it is shown over the first cell of the satchel it fits")
	_check(bag.count("tinkers_thimble") == 1 and not gear.has(0, "tinkers_thimble"), "(in hand it has not left the inventory yet)")
	await _key(KEY_D)
	await _key(KEY_S)
	_check(v.cell == Vector2i(1, 1), "the keys move it over the satchel")
	await _key(KEY_E)
	_check(v.held.is_empty() and gear.has(0, "tinkers_thimble") and bag.count("tinkers_thimble") == 0 and gear.piece_at(0, Vector2i(1, 1)) == 0, "E puts it down: it is worn")
	_check(v.note == "Tinker's Thimble is in use." and bool(packs.under_cursor(0)["worn"]), "and the screen says it is in use")
	# Back to the inventory side, and the quick way.
	await _key(KEY_A)
	await _key(KEY_A)
	_check(v.side == 0 and v.slot % Bag.COLS == Bag.COLS - 1, "A off the satchel's left edge goes back to the inventory")
	v.slot = 3
	_check(str(packs.under_cursor(0)["id"]) == "bandolier", "(the slot the Thimble left has closed up: the Bandolier is there now)")
	await _key(KEY_Q)
	_check(gear.has(0, "bandolier") and bag.count("bandolier") == 0 and v.note == "Bandolier is in use.", "Q wears it at the first place it fits")
	var band: Dictionary = gear.kits[0].worn[1]
	_check(int(band["x"]) == 0 and int(band["y"]) == 0 and int(band["rot"]) == 0, "(down the first column)")
	# Something in hand that does not fit; turning it.
	_check(str(packs.under_cursor(0)["id"]) == "field_rations", "(the Field Rations next)")
	await _key(KEY_E)
	_check(str(v.held.get("id", "")) == "field_rations" and v.side == 1, "(picked up)")
	v.cell = Vector2i(0, 1)
	v.held["rot"] = 0
	await _key(KEY_E)
	_check(not v.held.is_empty() and not gear.has(0, "field_rations") and v.note == "It does not fit there.", "put down on taken cells: it stays in hand (\"%s\")" % v.note)
	await _key(KEY_R)
	_check(int(v.held["rot"]) == 1, "R turns what is in hand a quarter")
	v.held["rot"] = 0
	var box := Accessories.box("field_rations", 0)
	for n in 6:
		await _key(KEY_D)
	_check(v.cell.x == 3 - box.x and v.side == 1, "(in hand a piece stops at the satchel's edge)")
	await _key(KEY_ESCAPE)
	_check(v.held.is_empty() and v.side == 0 and packs.is_open(0) and bag.count("field_rations") == 1, "Escape lets go of it: it is where it was, and the screen stays open")
	# Turning a worn piece where it lies; picking a worn piece up and moving it.
	bag.add("thorn_charm", 1)
	gear.wear(0, "thorn_charm", 1, 0, 0)
	v.side = 1
	v.cell = Vector2i(0, 2)
	_check(str(packs.under_cursor(0)["id"]) == "bandolier" and int(packs.under_cursor(0)["k"]) == 1, "(the cursor on the Bandolier in the satchel, with a Thorn Charm beside its top)")
	await _key(KEY_R)
	_check(int(gear.kits[0].worn[1]["rot"]) == 0 and v.note.begins_with("No room to turn it there"), "R on a worn piece with no room to turn says so (\"%s\")" % v.note)
	await _key(KEY_E)
	_check(v.held.get("from") is int and int(v.held["from"]) == 1 and v.cell == Vector2i(0, 0), "E picks a worn piece up")
	await _key(KEY_R)
	v.cell = Vector2i(0, 2)
	await _key(KEY_E)
	band = gear.kits[0].worn[1]
	_check(v.held.is_empty() and int(band["y"]) == 2 and int(band["rot"]) == 1 and gear.has(0, "bandolier"), "turned and put down along the bottom row: it was worn all the while")
	# Taking off.
	v.cell = Vector2i(1, 1)
	await _key(KEY_Q)
	_check(not gear.has(0, "tinkers_thimble") and bag.count("tinkers_thimble") == 1 and v.note == "Tinker's Thimble is no longer in use.", "Q on a worn piece takes it off (\"%s\")" % v.note)
	v.cell = Vector2i(1, 2)
	await _key(KEY_E)
	await _key(KEY_A)
	await _key(KEY_A)
	_check(v.side == 0 and not v.held.is_empty(), "(a worn piece carried over to the inventory)")
	await _key(KEY_E)
	_check(not gear.has(0, "bandolier") and bag.count("bandolier") == 1 and v.note == "Bandolier is no longer in use.", "put down there: it is taken off")
	# A full satchel, a full inventory.
	for cy in 3:
		for cx in 3:
			bag.add("lucky_copper", 1)
			gear.wear(0, "lucky_copper", cx, cy, 0)
	v.side = 0
	v.slot = packs._first_slot_of(0, "iron_bracer")
	await _key(KEY_Q)
	_check(not gear.has(0, "iron_bracer") and v.note == "No room in the satchel. Move or turn something.", "a full satchel takes no more (\"%s\")" % v.note)
	bag.add("wood", bag.room("wood"))
	v.side = 1
	v.cell = Vector2i(2, 2)
	await _key(KEY_Q)
	_check(gear.kits[0].worn.size() == 9 and v.note == "Your inventory is full.", "with a full inventory nothing comes off (\"%s\")" % v.note)
	bag.take("wood", bag.count("wood"))
	# Closing with something in hand loses nothing.
	var all := 0
	for id in Accessories.ORDER:
		all += _has(g, 0, id)
	await _key(KEY_E)
	_check(not v.held.is_empty(), "(a piece in hand)")
	await _key(KEY_TAB)
	var now := 0
	for id in Accessories.ORDER:
		now += _has(g, 0, id)
	_check(not packs.is_open(0) and not paused and now == all and gear.kits[0].worn.size() == 9, "Tab closes it, the game goes on, and what was in hand is where it was")
	# Escape closes it too, and does not open the pause menu behind it.
	await _frames(4)
	await _key(KEY_TAB)
	await _frames(10)
	await _key(KEY_ESCAPE)
	_check(not packs.is_open(0) and not paused, "Escape closes it, and nothing opens behind it")
	# Not while something else has the game.
	g.ui.say("Somebody", "", ["A word."], Callable())
	await _frames(3)
	await _key(KEY_TAB)
	_check(not packs.is_open(0), "it does not open while somebody is speaking")
	while g.ui.talking():
		await _press(p, "interact_pressed")
	await _frames(4)
	g.hall.open(0)
	await _frames(2)
	await _key(KEY_TAB)
	_check(not packs.is_open(0) and g.hall.is_open, "nor over the forge's screen")
	g.hall.close()
	await _frames(4)
	p.is_down = true
	await _key(KEY_TAB)
	_check(not packs.is_open(0), "nor for somebody who is down")
	p.is_down = false
	# The mouse.
	await _key(KEY_TAB)
	await _frames(10)
	packs._point(0, packs.slot_rect(0, 7).get_center())
	_check(v.side == 0 and v.slot == 7, "the mouse puts the cursor on the slot under it")
	packs._point(0, packs.cell_rect(0, Vector2i(2, 1)).get_center())
	_check(v.side == 1 and v.cell == Vector2i(2, 1), "or on the satchel's cell")
	_check(not packs._point(0, Vector2(2, 2)), "(and nowhere else)")
	await _key(KEY_TAB)
	# Everything has its place on the screen, whatever the sizes.
	var pix := Art.font(Art.TEXT)
	var whole := Rect2(0, 0, 640, 360)
	for pack in Bag.PACKS.size():
		for satchel in Gear.SATCHELS.size():
			Bag.LAB_PACK = pack
			Gear.LAB_SATCHEL = satchel
			var plate: Rect2 = packs.plate(0)
			var ok := _in(whole, plate) and plate.position.y >= 36.0
			var size: Vector2i = gear.size_of(0)
			for n in bag.cap():
				ok = ok and _in(plate, packs.slot_rect(0, n))
			for cy in size.y:
				for cx in size.x:
					var cr: Rect2 = packs.cell_rect(0, Vector2i(cx, cy))
					ok = ok and _in(plate, cr) and cr.position.x >= packs.slot_rect(0, Bag.COLS - 1).end.x + 8.0
			ok = ok and packs.slot_rect(0, bag.cap() - 1).end.y <= plate.end.y - PackScreen.FOOT + 1.0
			ok = ok and packs.cell_rect(0, Vector2i(0, size.y - 1)).end.y <= plate.end.y - PackScreen.FOOT + 1.0
			_check(ok, "%s and %s: every slot and cell is on the plate, clear of each other and of the words below" % [Bag.PACKS[pack]["name"], Gear.SATCHELS[satchel]["name"]])
	Bag.LAB_PACK = 0
	Gear.LAB_SATCHEL = 0
	var wide := PackScreen.WIDE - PackScreen.PAD * 2.0
	for id in Accessories.ORDER + Bag.ORDER:
		_check(PackScreen.lines_of(pix, Bag.text_of(id), Art.TEXT_SIZE, wide).size() <= 2, "what the %s does fits its two lines" % Bag.name_of(id))
		for note in ["%s is in use." % Bag.name_of(id), "%s is no longer in use." % Bag.name_of(id)]:
			_check(pix.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE).x <= wide, "(\"%s\" fits)" % note)
	for line in ["Only accessories go in the satchel.", "It does not fit there.", "Your inventory is full.", "No room in the satchel. Move or turn something.", "No room to turn it there. Pick it up first.",
			"An accessory works only while it is in the satchel.", "E: put down     R: turn", "Q: wear or take off     Tab: close", "Y: wear or take off     B: close", "A: pick up     X: turn"]:
		_check(pix.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE).x <= wide, "\"%s\" fits the plate" % line)
	# Past the last slot: a row more is drawn for it.
	Bag.LAB_PACK = 1
	bag.add("stone", bag.room("stone"))
	Bag.LAB_PACK = 0
	_check(bag.slots.size() == 30 and packs.rows_of(0) == 5 and _in(packs.plate(0), packs.slot_rect(0, 29)), "an inventory holding more than its slots (a backpack taken off) shows all of it")
	_check(packs.title_of(0) == "INVENTORY", "(with no backpack it is called the inventory)")
	Bag.LAB_PACK = 3
	bag.add("stone", bag.room("stone"))
	for n in 12:
		bag.put_back("lucky_copper")
	Bag.LAB_PACK = 0
	_check(bag.slots.size() == 60 and packs.rows_of(0) == 10 and _in(Rect2(0, 0, 640, 360), packs.plate(0)) and _in(packs.plate(0), packs.slot_rect(0, 59)), "even sixty things in it are all on the screen")
	await _leave(g)


func _two_screens() -> void:
	var g = _game(424242, 2, false, [], {}, ["kbm", "pad"])
	await _frames(10)
	var gear = g.gear
	var packs = g.packs
	g.tools.bag_of(0).add("thorn_charm", 1)
	g.tools.bag_of(1).add("iron_bracer", 1)
	await _button(JOY_BUTTON_LEFT_STICK)
	_check(packs.is_open(1) and not packs.is_open(0) and paused, "two players: a click of the left stick opens the second player's own inventory")
	_check(packs.plate(1).position.x > 320.0 and packs.plate(0).end.x < 320.0, "each on their own side of the screen")
	var silk := Art.font("Silkscreen-Regular")
	for pack in Bag.PACKS.size():
		Bag.LAB_PACK = pack
		for i in 2:
			var wide_now: float = silk.get_string_size(packs.title_of(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + silk.get_string_size("96 / 48", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			_check(packs.title_of(i).begins_with("P%d " % (i + 1)) and wide_now + 6.0 <= PackScreen.SLOT * 6.0, "\"%s\" and its count fit over the slots" % packs.title_of(i))
	Bag.LAB_PACK = 0
	_check(not packs.plate(0).intersects(packs.plate(1)), "(side by side, not over each other)")
	await _frames(10)
	await _key(KEY_D)
	_check(packs.views[1].slot == 0 and packs.views[0].slot == 0, "the first player's keys do nothing to the second player's screen")
	await _key(KEY_TAB)
	_check(packs.is_open(0) and packs.is_open(1) and paused, "the first player opens theirs beside it")
	await _frames(10)
	await _button(JOY_BUTTON_Y)
	_check(gear.has(1, "iron_bracer") and not gear.has(0, "iron_bracer"), "Y wears what the second player's cursor is on, in their own satchel")
	await _key(KEY_Q)
	_check(gear.has(0, "thorn_charm") and not gear.has(1, "thorn_charm"), "Q does the same for the first player")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	_check(packs.views[1].slot == 1 and packs.views[0].slot == 0, "the pad's cross moves its own cursor only")
	await _button(JOY_BUTTON_B)
	_check(not packs.is_open(1) and packs.is_open(0) and paused, "B closes the second player's: the game still stands while the first is open")
	await _key(KEY_TAB)
	_check(not packs.any_open() and not paused, "and goes on when the last one closes")
	# The left stick's click is the inventory's here, not the lab's.
	await _frames(6)
	await _button(JOY_BUTTON_LEFT_STICK)
	_check(packs.is_open(1), "(the stick's click again: open)")
	await _frames(10)
	await _button(JOY_BUTTON_LEFT_STICK)
	await _frames(6)
	_check(not packs.any_open() and not paused and g.lab_screen != null and not g.lab_screen.is_open, "the stick's click closes it, and does not open the lab behind it")
	var hints := ["A: pick up     X: turn", "Y: wear or take off     B: close", "B: let go", "A: put down     X: turn"]
	var pix := Art.font(Art.TEXT)
	for line in hints:
		_check(pix.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE).x <= PackScreen.WIDE - PackScreen.PAD * 2.0, "(\"%s\" fits)" % line)
	await _leave(g)


# --- The lab ---------------------------------------------------------------------------------

func _lab() -> void:
	Lab.setup()
	for id in ["bag:LAB_PACK", "gear:LAB_SATCHEL", "gear:LAB_GIVE", "loot_plan:GIFT", "loot_plan:RICH_GIFT", "loot:ELITE_GIFT", "loot:GIFT_COINS", "folk:ACCESSORY_PRICE", "folk:SMOKE_SIGN",
			"accessories:THIMBLE_DODGE", "accessories:PEBBLE_WAIT", "accessories:PEBBLE_HEAL", "accessories:LOCKET_SHARE", "accessories:LUCKY_COINS", "accessories:PIN_SOFTEN", "accessories:PIN_REACH",
			"accessories:THORN_DAMAGE", "accessories:THORN_REACH", "accessories:BRACER_KNOCK", "accessories:SIEVE_CHANCE", "accessories:BANDOLIER_RUNES", "accessories:RATIONS_HEALTH"]:
		_check(Lab.by_id.has(id), "the lab has %s" % id)
	_check(Lab.PAGES.has("Inventory and accessories") and Lab.PAGE_NOTES.has("Inventory and accessories"), "on a page of its own")
	var g = _game(424242, 2)
	await _frames(5)
	var gear = g.gear
	Bag.LAB_PACK = 1
	Gear.LAB_SATCHEL = 1
	g.lab_changed()
	_check(g.tools.bag_of(0).cap() == 30 and g.tools.bag_of(1).cap() == 30, "the lab's backpack: everybody carries the Hide Pack (30 slots)")
	_check(gear.size_of(0) == Vector2i(3, 4) and gear.size_of(1) == Vector2i(3, 4), "the lab's satchel: everybody wears the Hide Satchel (3 by 4)")
	_check(int(g.tools.bag_of(0).pack) == 0 and int(gear.kits[0].satchel) == 0, "(the characters own none: nothing of the lab's is written into them)")
	Gear.LAB_GIVE = 1
	await _frames(40)
	var all := true
	for i in 2:
		for id in Accessories.ORDER:
			if _has(g, i, id) != 1:
				all = false
	_check(all, "the lab's switch: everybody has one of every accessory")
	await _frames(80)
	all = true
	for i in 2:
		for id in Accessories.ORDER:
			if _has(g, i, id) != 1:
				all = false
	_check(all, "(and no second ones while it stays on)")
	Gear.LAB_GIVE = 0
	await _leave(g)


# --- The smoke over the Roost, and Pip's portrait --------------------------------------------

func _smoke() -> void:
	var g = _game(424242, 1, true)
	await _frames(10)
	var folk = g.folk
	var p = g.players[0]
	p.unhurt = true
	_check(folk.has_roost() and folk.pip == 0 and folk.smoke != null and folk.smoking() and folk.smoke.visible, "while Pip is caged, smoke stands over the Roost")
	_check(folk.smoke.z_index > 40 and folk.smoke.position == folk.smoke_feet(), "(over everything on the land, rising from beside the cage)")
	var list: Array = folk.puffs(100.0, Folk.SMOKE_LIFE)
	_check(list.size() == int(Folk.SMOKE_LIFE), "a puff a second: %d in the plume" % list.size())
	var ordered := true
	var whole := true
	var top := 0.0
	for n in list.size():
		var at: Vector2 = list[n][0]
		if at != at.round():
			whole = false
		top = minf(top, at.y)
		if n > 0 and (list[n][0] as Vector2).y < (list[n - 1][0] as Vector2).y:
			ordered = false
		if n > 0 and int(list[n][1]) > int(list[n - 1][1]):
			ordered = false
		if n > 0 and bool(list[n][2]) == bool(list[n - 1][2]):
			ordered = false
	_check(ordered, "the oldest and highest first, the newest and lowest drawn last, every other one mirrored")
	_check(whole, "always on whole pixels")
	_check(top < -140.0 and top > -160.0, "the plume stands about half a screen tall (%d pixels)" % int(-top))
	_check(int(list[0][1]) == 3 and int(list[list.size() - 1][1]) == 0, "a puff opens out as it ages: fresh at the foot, breaking up at the top")
	var slow := true
	for step in 120:
		var a: Array = folk.puffs(50.0 + float(step) / 60.0, Folk.SMOKE_LIFE)
		var b: Array = folk.puffs(50.0 + float(step + 1) / 60.0, Folk.SMOKE_LIFE)
		if a.size() == b.size() and str(a[a.size() - 1][2]) == str(b[b.size() - 1][2]):
			for n in a.size():
				var d: Vector2 = (b[n][0] as Vector2) - (a[n][0] as Vector2)
				if absf(d.x) > 2.0 or absf(d.y) > 1.0:
					slow = false
	_check(slow, "small, slow movement: from one tick to the next no puff moves more than a pixel up")
	# The far-off plume at the screen's edge.
	var sign: Array = folk.smoke_sign()
	var to: Vector2 = folk.smoke_feet() - p.global_position
	_check(to.length() > 1500.0, "(the Roost is a long way from where you start: %d tiles)" % int(to.length() / TILE))
	_check(sign.size() == 1 and Rect2(18, 40, 604, 300).grow(1.0).has_point(sign[0]), "far from the Roost a small plume stands at the edge of the screen")
	if sign.size() == 1:
		var at: Vector2 = sign[0]
		_check(at.x < 20.0 or at.x > 620.0 or at.y < 50.0 or at.y > 336.0, "right at the edge (%s)" % str(at))
		_check((at - Vector2(320, 180)).normalized().dot(to.normalized()) > 0.7, "on the Roost's side")
		_check(folk.hud_corners().all(func(r): return not Rect2(at.x - 9.0, at.y - folk.sign_height() + 4.0, 18.0, folk.sign_height() + 12.0).intersects(r)), "clear of the bars, the quests and the belts")
	_check(folk.puffs(folk.clock, float(int(Folk.SMOKE_SIGN))).size() == int(Folk.SMOKE_SIGN), "(%d puffs tall)" % int(Folk.SMOKE_SIGN))
	_check(str(folk.quests()[0]["text"]).begins_with("Follow the smoke"), "and the quest says to follow the smoke")
	var was := int(Folk.SMOKE_SIGN)
	Folk.SMOKE_SIGN = 0
	_check(folk.smoke_sign().is_empty() and str(folk.quests()[0]["text"]).begins_with("Find the"), "the lab can turn the far-off plume off (the quest's words follow)")
	Folk.SMOKE_SIGN = was
	# At the Roost the real smoke is in sight: no far-off plume.
	g.foes.on = false
	_put(g, p, folk.pip_landing() + Vector2(0, 60))
	await _frames(6)
	_check(folk.smoke_sign().is_empty(), "with the Roost on the screen there is only its own smoke")
	_put(g, p, folk.smoke_feet() - Vector2(0, 360.0 + 160.0))
	await _frames(6)
	_check(folk.smoke_sign().is_empty(), "(nor from above it, while the top of the plume is still on the screen)")
	_put(g, p, folk.smoke_feet() + Vector2(0, 360.0 + 160.0))
	await _frames(6)
	_check(folk.smoke_sign().size() == 1 and (folk.smoke_sign()[0] as Vector2).y < 60.0, "from below, with the Roost just off the top of the screen, the far-off plume is at the top")
	# Wherever the Roost lies from the squad, the plume is clear of what sits in the corners.
	var clear := true
	for turn in 72:
		_put(g, p, folk.smoke_feet() + Vector2.from_angle(float(turn) * TAU / 72.0) * 3000.0)
		var where: Array = folk.smoke_sign()
		if where.size() != 1:
			clear = false
			continue
		var w: Vector2 = where[0]
		if not Rect2(8, 8, 624, 344).has_point(w) or not Rect2(8, 8, 624, 344).has_point(w - Vector2(0, folk.sign_height() - 8.0)):
			clear = false
		for r: Rect2 in folk.hud_corners():
			if Rect2(w.x - 9.0, w.y - folk.sign_height() + 4.0, 18.0, folk.sign_height() + 12.0).intersects(r):
				clear = false
	_check(clear, "from every side the far-off plume is on the screen and clear of the bars, the quests and the belts")
	_put(g, p, folk.pip_landing() + Vector2(0, 22))
	await _frames(6)
	# The cage broken: the fire dies.
	for n in int(Folk.CAGE_BLOWS):
		folk.strike_cage(0)
	_check(folk.pip == 1 and is_equal_approx(folk.smoke_until, folk.clock), "the cage broken: no new smoke")
	_check(folk.smoking() and folk.puffs(folk.clock + 5.0, Folk.SMOKE_LIFE, folk.smoke_until).size() == int(Folk.SMOKE_LIFE) - 5, "what is in the air drifts up and away")
	_check(folk.puffs(folk.clock + Folk.SMOKE_LIFE + 1.0, Folk.SMOKE_LIFE, folk.smoke_until).is_empty(), "and then there is none")
	_check(folk.smoke_sign().is_empty(), "(and no far-off plume: Pip is out)")
	# Pip speaks with his face beside his words.
	await _wait(func(): return g.ui.talking(), 400)
	_check(g.ui.talking() and str(g.ui.portrait) == Folk.FACE, "Pip speaks with his portrait in the speech box")
	while g.ui.talking():
		await _press(p, "interact_pressed")
	folk.clock += Folk.SMOKE_LIFE + 1.0
	await _frames(3)
	_check(not folk.smoking() and not folk.smoke.visible, "(the smoke has gone)")
	var world: Dictionary = g._world_now()
	await _leave(g)
	# A world where he was freed before: no smoke at all.
	g = _game(424242, 1, false, [], world)
	await _frames(5)
	_check(g.folk.pip >= 2 and not g.folk.smoking() and g.folk.smoke_sign().is_empty() and (g.folk.smoke == null or not g.folk.smoke.visible), "a world where Pip is free already has no smoke")
	await _leave(g)


# --- Pip's accessory ---------------------------------------------------------------------------

func _pips_ware() -> void:
	var g = _game(424242)
	await _frames(5)
	var folk = g.folk
	var shop = folk.shop
	var bag: Bag = g.tools.bag_of(0)
	var purse = g.loot.purses[0]
	var ware: String = folk.ware()
	_check(Accessories.POOL.has(ware), "Pip has one accessory for sale (%s)" % ware)
	_check(folk.ware() == ware, "(the same one each time you look)")
	g.levels.level += 1
	var next: String = folk.ware()
	_check(next != ware and Accessories.POOL.has(next), "it changes when the forge's level rises (%s)" % next)
	g.levels.level -= 1
	_check(shop.rows() == ["Tin bar", "Copper bar", Accessories.name_of(ware), Shop.ASK, Shop.LEAVE] and shop.items() == ["tin_bar", "copper_bar", ware], "his shop has a row for it, under the bars")
	_check(folk.price(ware) == int(Folk.ACCESSORY_PRICE) and folk.price("tin_bar") == int(Folk.TIN_PRICE), "(its price is the lab's)")
	folk.pip = 3
	folk._show()
	purse.coins = int(Folk.ACCESSORY_PRICE) - 1
	shop.open(0)
	shop.row = 2
	shop.confirm()
	_check(bag.count(ware) == 0 and shop.note == "That is %d coins. You have %d." % [int(Folk.ACCESSORY_PRICE), int(Folk.ACCESSORY_PRICE) - 1], "too few coins: nothing (\"%s\")" % shop.note)
	purse.coins = int(Folk.ACCESSORY_PRICE) + 5
	shop.confirm()
	_check(bag.count(ware) == 1 and purse.coins == 5 and shop.note.begins_with("Bought the %s for %d coins." % [Accessories.name_of(ware), int(Folk.ACCESSORY_PRICE)]), "bought: it is in your inventory (\"%s\")" % shop.note)
	_check(is_equal_approx(g.gear.kits[0].nudged, g.gear.clock), "(and the screen will say which button opens it)")
	purse.coins = 100
	shop.confirm()
	_check(bag.count(ware) == 1 and purse.coins == 100 and shop.note == "You have one. A second would do nothing more.", "he will not sell you a second (\"%s\")" % shop.note)
	var pix := Art.font(Art.TEXT)
	for id in Accessories.POOL:
		_check(pix.get_string_size("Bought the %s for %d coins." % [Accessories.name_of(id), 9999], HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE).x <= Shop.BOX.size.x - 36.0, "(the line for the %s fits his plate)" % Accessories.name_of(id))
		_check(Shop.lines_of(pix, Accessories.text_of(id), Art.TEXT_SIZE, Shop.BOX.size.x - 36.0 - 30.0).size() <= 2, "(and what it does fits under his rows)")
	_check(Shop.BOX.position.y + 122.0 + 5.0 * 24.0 + 30.0 <= Shop.BOX.end.y and Shop.BOX.end.y <= 360.0 - 32.0, "(five rows and the line under them are on his plate, above the band of buttons)")
	shop.close()
	await _leave(g)


# --- Saved -----------------------------------------------------------------------------------

func _saved() -> void:
	var old_root := Save.root
	_fresh_folder(ROOT)
	var who := Save.fresh(Save.CHARACTERS)
	var where := Save.fresh(Save.WORLDS)
	where["seed"] = 424242
	var g = _game(0, 1, false, [who], where)
	await _frames(5)
	var gear = g.gear
	var bag: Bag = g.tools.bag_of(0)
	g.players[0].unhurt = true
	_put(g, g.players[0], gear.unexplored_from(g.players[0].global_position))
	await _frames(40)
	_put(g, g.players[0], g.map.spawn * TILE)
	bag.add("stone", 120)
	bag.add("thorn_charm", 1)
	bag.add("bandolier", 1)
	bag.add("iron_bracer", 1)
	_check(gear.wear(0, "bandolier", 0, 2, 1) and gear.wear(0, "iron_bracer", 1, 1, 0), "(two worn, one in the inventory)")
	bag.pack = 1
	gear.kits[0].satchel = 1
	var bag_text := str(bag.data())
	var kit_text := str(gear.kit_data(0))
	var seen: int = gear.visited.size()
	var written: int = g.saves_written
	g.packs.open(0)
	await _idle(3)
	g.packs.close(0)
	_check(g.saves_written > written, "closing the inventory saves the character")
	var me := Save.read(Save.CHARACTERS, str(who["id"]))
	var on_disk := Save.read(Save.WORLDS, str(where["id"]))
	_check(me.get("bag") is Array and int(me.get("pack", -1)) == 1 and int(me.get("satchel", -1)) == 1 and me.get("worn") is Array and (me["worn"] as Array).size() == 2, "the character's file holds its inventory, its backpack, its satchel and what is worn (%s)" % str(me.get("worn")))
	_check(on_disk.get("visited") is Array and (on_disk["visited"] as Array).size() == seen and seen > 0, "the world's file holds where the squad has been")
	_check(SavePick.accessory_count(me) == 3 and SavePick.bag_counts(me).any(func(part): return str(part[0]) == "stone" and int(part[1]) == 120), "the pick screen counts its accessories (3) beside its materials")
	await _leave(g)
	g = _game(0, 1, false, [Save.read(Save.CHARACTERS, str(who["id"]))], Save.read(Save.WORLDS, str(where["id"])))
	await _frames(5)
	gear = g.gear
	bag = g.tools.bag_of(0)
	_check(str(bag.data()) == bag_text and int(bag.pack) == 1 and bag.cap() == 30, "played again: the inventory and the backpack are as they were")
	_check(str(gear.kit_data(0)) == kit_text and gear.size_of(0) == Vector2i(3, 4) and gear.has(0, "bandolier") and gear.has(0, "iron_bracer"), "and so are the satchel and what is worn in it, working")
	_check(gear.visited.size() >= seen and not g.relaid, "and where the squad has been (the land is not laid out again)")
	written = g.saves_written
	g.save_now()
	_check(g.saves_written == written, "nothing is written again while nothing has changed")
	await _leave(g)
	# A character from before version 47: a materials bag of 20 stacks and nothing else.
	var old_me := Save.read(Save.CHARACTERS, str(who["id"]))
	for key in ["pack", "satchel", "worn"]:
		old_me.erase(key)
	var stacks: Array = []
	for n in 20:
		stacks.append([Bag.ORDER[n % Bag.ORDER.size()], 99])
	old_me["bag"] = stacks
	var old_world := Save.read(Save.WORLDS, str(where["id"]))
	old_world.erase("visited")
	g = _game(0, 1, false, [old_me], old_world)
	await _frames(5)
	bag = g.tools.bag_of(0)
	_check(bag.slots.size() == 20 and bag.count("stone") == 99 * 4 and bag.cap() == 24 and bag.room("thorn_charm") == 4, "a character saved before version 47 keeps its whole materials bag, with four slots to spare")
	_check(int(bag.pack) == 0 and g.gear.size_of(0) == Vector2i(3, 3) and g.gear.kits[0].worn.is_empty() and not g.relaid, "and starts with no backpack and an empty first satchel (the land is not laid out again)")
	await _leave(g)
	# A save that holds what cannot be.
	var odd := Save.read(Save.CHARACTERS, str(who["id"]))
	odd["bag"] = [["stone", 10]]
	odd["pack"] = 99
	odd["satchel"] = -3
	odd["worn"] = [["bandolier", 0, 0, 0], ["iron_bracer", 0, 1, 0], ["field_rations", 2, 2, 0], ["crown_of_kings", 1, 0, 0], ["thorn_charm", 1, 0], "x", ["tinkers_thimble", 2, 0, 7]]
	g = _game(0, 1, false, [odd], Save.read(Save.WORLDS, str(where["id"])))
	await _frames(5)
	gear = g.gear
	bag = g.tools.bag_of(0)
	_check(int(bag.pack) == Bag.PACKS.size() - 1 and int(gear.kits[0].satchel) == 0, "a save that makes no sense: the backpack and satchel are ones there are")
	_check(gear.has(0, "bandolier") and gear.has(0, "tinkers_thimble") and gear.kits[0].worn.size() == 2 and int(gear.kits[0].worn[1]["rot"]) == 0, "what fits where the save says is worn")
	_check(bag.count("iron_bracer") == 1 and bag.count("field_rations") == 1, "what lies on another piece or over the edge is in the inventory, not lost")
	_check(bag.count("crown_of_kings") == 0 and bag.count("thorn_charm") == 0, "(and what this game does not know, or cannot read, is left out)")
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
	var gear = g.gear
	var packs = g.packs
	var folk = g.folk
	var loot = g.loot
	var p = g.players[0]
	var bag: Bag = g.tools.bag_of(0)
	p.unhurt = true
	g.land.settle()
	await _frames(60)
	# The far-off smoke, and the quest that says to follow it.
	await _snap("01_far_off_smoke_shows_the_way")
	# The first chest: an accessory.
	var k := _kind(g, "first")
	var chest: Dictionary = loot.chests[k]["plan"]
	_put(g, p, (chest["foot"] as Vector2) * 2.0 + Vector2(-40, 26))
	g.land.settle()
	await _frames(20)
	loot.open(k, 0)
	await _frames(70)
	await _snap("02_an_accessory_found")
	await _frames(60)
	await _snap("03_which_button_opens_the_inventory")
	# The inventory.
	bag.add("stone", 130)
	bag.add("wood", 40)
	bag.add("tin_ore", 12)
	bag.add("copper_ore", 7)
	bag.add("copper_bar", 2)
	for id in ["tinkers_thimble", "bandolier", "field_rations", "prospectors_sieve", "wayfinders_compass"]:
		if bag.count(id) == 0:
			bag.add(id, 1)
	await _frames(500)
	packs.open(0)
	await _idle(20)
	await _snap("04_the_inventory")
	var v = packs.views[0]
	v.slot = packs._first_slot_of(0, "bandolier")
	await _idle(6)
	await _snap("05_an_accessory_in_the_inventory_does_nothing")
	packs.press(0)
	await _idle(6)
	await _snap("06_picked_up_over_the_satchel")
	packs.press(0)
	await _idle(6)
	await _snap("07_worn_and_in_use")
	v.side = 0
	v.slot = packs._first_slot_of(0, "field_rations")
	packs.press(0)
	v.cell = Vector2i(0, 1)
	v.held["rot"] = 0
	await _idle(6)
	await _snap("08_it_does_not_fit_there")
	packs.press(0)
	await _idle(6)
	await _snap("09_it_does_not_fit_there_said")
	packs.turn(0)
	v.cell = Vector2i(1, 0)
	await _idle(6)
	await _snap("10_turned_it_fits")
	packs.press(0)
	v.side = 0
	v.slot = packs._first_slot_of(0, "wayfinders_compass")
	packs.quick(0)
	v.slot = packs._first_slot_of(0, "tinkers_thimble")
	packs.quick(0)
	v.side = 1
	v.cell = Vector2i(0, 2)
	packs.press(0)
	packs.turn(0)
	v.cell = Vector2i(0, 2)
	await _idle(6)
	await _snap("11_a_worn_piece_picked_up_and_turned")
	packs.back(0)
	v.side = 0
	v.slot = 0
	await _idle(6)
	await _snap("12_materials_cannot_be_worn")
	packs.press(0)
	await _idle(6)
	await _snap("13_materials_cannot_be_worn_said")
	packs.close(0)
	await _frames(30)
	# The compass's arrow.
	await _frames(40)
	await _snap("14_the_compass_points_to_somewhere_new")
	# Bigger: the Hide Pack and Hide Satchel; the largest of both.
	Bag.LAB_PACK = 1
	Gear.LAB_SATCHEL = 1
	packs.open(0)
	await _idle(12)
	await _snap("15_hide_pack_and_hide_satchel")
	Bag.LAB_PACK = 3
	Gear.LAB_SATCHEL = 3
	Gear.LAB_GIVE = 1
	packs.close(0)
	await _frames(40)
	Gear.LAB_GIVE = 0
	for id in ["dowsing_rod", "banner_pin", "iron_bracer", "thorn_charm", "lucky_copper"]:
		var fit: Array = gear.first_fit(0, id)
		if not fit.is_empty():
			gear.wear(0, id, fit[0], fit[1], fit[2])
	packs.open(0)
	v.side = 1
	v.cell = Vector2i(3, 3)
	await _idle(12)
	await _snap("16_the_largest_pack_and_satchel")
	# Taken off again: what no longer fits is kept past the last slot.
	bag.add("stone", bag.room("stone"))
	Bag.LAB_PACK = 0
	Gear.LAB_SATCHEL = 0
	packs.close(0)
	await _frames(4)
	packs.open(0)
	v.side = 0
	v.slot = 26
	await _idle(12)
	await _snap("17_made_smaller_nothing_is_lost")
	packs.close(0)
	bag.take("stone", bag.count("stone"))
	await _frames(10)
	# The smoke over the Roost.
	var group := int(folk.plan["roost"]["group"])
	_put(g, p, folk.pip_landing() + Vector2(-60, 120))
	g.land.settle()
	await _frames(120)
	await _snap("18_smoke_over_the_roost")
	_put(g, p, folk.pip_landing() + Vector2(-60, 330))
	g.land.settle()
	await _frames(60)
	await _snap("19_the_top_of_the_plume_from_below")
	_put(g, p, folk.pip_landing() + Vector2(700, 500))
	g.land.settle()
	await _frames(60)
	await _snap("20_just_out_of_sight_the_far_off_smoke")
	if g.foes.packs.has(group):
		for e in g.foes.packs[group].members.duplicate():
			e.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
		g.foes.packs[group].alert = false
	g.foes.on = false
	_put(g, p, folk.pip_landing() + Vector2(0, 22))
	await _frames(100)
	for n in int(Folk.CAGE_BLOWS):
		folk.strike_cage(0)
		await _frames(20)
	await _wait(func(): return g.ui.talking(), 400)
	await _frames(30)
	await _snap("21_pip_speaks_with_his_portrait")
	while g.ui.talking():
		await _press(p, "interact_pressed")
	await _frames(240)
	await _snap("22_the_smoke_thins_once_he_is_free")
	# Pip's shop, with his accessory.
	folk.pip = 3
	folk._show()
	_put(g, p, folk.pip_home() + Vector2(0, 28))
	g.land.settle()
	await _frames(30)
	loot.purses[0].coins = 55
	bag.take(folk.ware(), bag.count(folk.ware()))
	for n in gear.kits[0].worn.size():
		if gear.kits[0].worn[n]["id"] == folk.ware():
			gear.stow(0, n)
			bag.take(folk.ware(), 1)
			break
	folk.shop.open(0)
	folk.shop.row = 2
	await _idle(12)
	await _snap("23_pips_accessory")
	folk.shop.confirm()
	await _idle(8)
	await _snap("24_bought")
	folk.shop.confirm()
	await _idle(8)
	await _snap("25_he_will_not_sell_a_second")
	folk.shop.close()
	await _leave(g)
	# Two players.
	g = _game(shot_seed, 2)
	await _frames(20)
	g.land.settle()
	for i in 2:
		g.tools.bag_of(i).add("stone", 60 + 80 * i)
		g.tools.bag_of(i).add("tin_bar", 4)
		for id in (["bandolier", "lucky_copper", "thorn_charm"] if i == 0 else ["field_rations", "iron_bracer", "banner_pin", "hearthstone_pebble"]):
			g.tools.bag_of(i).add(id, 1)
	_wear(g, 0, "thorn_charm")
	_wear(g, 1, "field_rations")
	_wear(g, 1, "banner_pin")
	g.tools.bag_of(0).take("thorn_charm", 1)
	g.tools.bag_of(1).take("field_rations", 1)
	g.tools.bag_of(1).take("banner_pin", 1)
	g.gear.nudge(0)
	g.gear.nudge(1)
	await _frames(30)
	await _snap("26_two_players_the_button_for_each")
	g.packs.open(0)
	await _idle(10)
	await _snap("27_two_players_one_inventory_open")
	g.packs.open(1)
	g.packs.views[1].slot = 2
	g.packs.press(1)
	g.packs.views[0].side = 1
	g.packs.views[0].cell = Vector2i(0, 0)
	await _idle(10)
	await _snap("28_two_players_both_open")
	g.packs.close_all()
	await _leave(g)
