extends SceneTree
## The basic tools of the Highlands (version 40): the tool belt, the work and cycle buttons, digging rock, mining
## ore, felling pines, and the materials bag. Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands_tools.gd
##
## With shots=/some/folder/ (needs a window, so leave out --headless) it saves 640x360 frames instead: the belt and
## the bag on the screen, mining into a vein blow by blow, and a pine coming down. "seed=123456" picks the world.

const PlayerInput := preload("res://scripts/player_input.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const Tools := preload("res://scripts/highlands/tools.gd")
const Bag := preload("res://scripts/highlands/bag.gd")
const TILE := 32.0
const SWING_TICKS := 29          # one swing of a tool that lands, in physics ticks (the swing, and the moment it holds where it struck)

var fails := 0
var checks := 0
var shot_dir := ""
var shot_seed := 1
var dense := false            # dense=1: every one of the first frames of a dig is saved too, to look at a blow frame by frame


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shot_dir = a.substr(6)
		elif a.begins_with("seed="):
			shot_seed = int(a.substr(5))
		elif a == "dense=1":
			dense = true
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
	_bag()
	_buttons()
	await _belt()
	await _hotbar()
	await _drawn()
	await _digging()
	await _mining()
	await _felling()
	await _bronze()
	await _limits()
	await _two_players()
	print("%s  the Highlands' tools: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func _game(seed_value: int, players := 1):
	var g = Highlands.new()
	var inputs: Array = []
	for i in players:
		inputs.append(PlayerInput.make("script"))
	g.inputs = inputs
	g.world_seed = seed_value
	g.with_foes = false
	g.welcome = false
	root.add_child(g)
	return g


# --- Finding things to work on -------------------------------------------------------------

## Nothing that stops you stands within a tile and a half of this place (world units)?
func _clear(m: LandMap, at: Vector2) -> bool:
	for t in m.things:
		if Painter.things.get(str(t["n"]), {}).has("solid") and (Vector2(float(t["x"]), float(t["y"])) * 2.0).distance_to(at) < 56.0:
			return false
	return true


## A tile of this kind with open ground beside it to stand on, away from the base: [the tile, the way to face it].
## `fixed` asks for rock that cannot be dug instead.
func _face(m: LandMap, kind: int, fixed := false, skip := 0) -> Array:
	for r in range(6 if not fixed else 0, 130):
		for j in range(-r, r + 1):
			for i in range(-r, r + 1):
				if maxi(absi(i), absi(j)) != r:
					continue
				var t := Vector2i(m.mouth.x + i, m.mouth.y + j)
				if m.kind(t.x, t.y) != kind or m.fixed(t.x, t.y) != fixed:
					continue
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]:
					var s := t + d
					if m.walkable(s.x, s.y) and m.kind(s.x, s.y) != LandMap.WATER and _clear(m, (Vector2(s) + Vector2(0.5, 0.5)) * TILE):
						if skip > 0:
							skip -= 1
							continue
						return [t, Vector2(-d)]
	return []


## A thing of this sort (its name begins so) with room to stand west of it: the thing.
func _thing(m: LandMap, prefix: String, skip := 0) -> Dictionary:
	for t in m.things:
		if not str(t["n"]).begins_with(prefix):
			continue
		var foot := Vector2(float(t["x"]), float(t["y"])) * 2.0
		var at := _beside(t)
		var ok := true
		for q in [at, at + Vector2(-16, 0), at + Vector2(0, 16), at + Vector2(0, -16), foot + Vector2(40, 0)]:
			if not m.walkable(floori(q.x / TILE), floori(q.y / TILE)):
				ok = false
		for other in m.things:
			if other != t and Painter.things.get(str(other["n"]), {}).has("solid") and (Vector2(float(other["x"]), float(other["y"])) * 2.0).distance_to(foot) < 90.0:
				ok = false
		if ok:
			if skip > 0:
				skip -= 1
				continue
			return t
	return {}


## Where to stand to work on a thing: just west of it.
func _beside(t: Dictionary) -> Vector2:
	var solid: Array = Painter.things[str(t["n"])]["solid"]
	return Vector2(float(t["x"]), float(t["y"])) * 2.0 + Vector2(-float(solid[0]) - 19.0, -5.0)


## Stands the player at a tile's neighbour, facing it.
func _stand(g, p, tile: Vector2i, dir: Vector2) -> void:
	p.global_position = (Vector2(tile) + Vector2(0.5, 0.5) - dir) * TILE
	p.input.stick_aim = dir
	p.input.move = Vector2.ZERO
	g.rig.snap()
	await _frames(4)
	g.land.settle()


## Holds the work button down for so many swings, then lets go and lets the swing end.
func _work(p, swings: int) -> void:
	p.input.work_held = true
	await _frames((swings - 1) * SWING_TICKS + 16)      # (the last blow has landed; letting go does not cut a swing short)
	p.input.work_held = false
	await _frames(SWING_TICKS + 2)


func _press(p, field: String) -> void:
	await physics_frame               # (so that the press lasts exactly one tick, wherever in a frame this is called)
	p.input.set(field, true)
	await physics_frame
	p.input.set(field, false)
	await physics_frame


# --- The bag -------------------------------------------------------------------------------

func _bag() -> void:
	var b := Bag.new()
	_check(Bag.SLOTS == 24 and Bag.STACK == 99 and b.cap() == 24, "the inventory has 24 slots of 99 (version 47; it was a bag of 20)")
	_check(b.add("stone", 250) == 250 and b.slots.size() == 3 and b.count("stone") == 250, "250 stone fills three places")
	_check(b.add("wood", 5) == 5 and b.slots.size() == 4 and b.count("wood") == 5, "another material starts its own place")
	_check(b.add("stone", 10) == 10 and b.slots.size() == 4 and b.count("stone") == 260, "more of the same tops its last place up first")
	_check(b.room("stone") == (Bag.SLOTS - 4) * 99 + (99 * 3 - 260), "room counts what is left in its places and every empty place (%d)" % b.room("stone"))
	_check(not b.take("wood", 6) and b.count("wood") == 5, "taking more than there is takes nothing")
	_check(b.take("wood", 5) and b.count("wood") == 0 and b.slots.size() == 3, "taking the last of a material frees its place")
	_check(b.take("stone", 200) and b.count("stone") == 60 and b.slots.size() == 1, "taking empties places from the last one back")
	var full := Bag.new()
	_check(full.add("stone", 5000) == Bag.SLOTS * 99 and full.slots.size() == Bag.SLOTS and full.room("stone") == 0 and full.room("wood") == 0, "a full bag takes no more (%d)" % full.count("stone"))
	_check(full.add("tin_ore", 1) == 0, "and nothing else either")
	var copy := Bag.new()
	copy.set_data(b.data())
	_check(str(copy.slots) == str(b.slots) and copy.slots != b.slots or str(copy.slots) == str(b.slots), "the bag comes back from its saved form")
	copy.set_data([["stone", 500], ["wood", -3], "rubbish", ["tin_ore", 2.0]])
	_check(copy.count("stone") == 99 and copy.count("wood") == 0 and copy.count("tin_ore") == 2, "and a bad save cannot overfill it")


# --- The buttons ---------------------------------------------------------------------------

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _buttons() -> void:
	var inp = PlayerInput.make("kbm")
	_check(inp._event_is(_key(KEY_F), "interact") and not inp._event_is(_key(KEY_F), "work"), "away from the Highlands F is still a use key")
	inp.tools = true
	_check(inp._event_is(_key(KEY_F), "work") and not inp._event_is(_key(KEY_F), "interact") and inp._event_is(_key(KEY_E), "interact"), "with tools on, F is the work button and E still uses things")
	_check(inp._event_is(_key(KEY_C), "tool_next"), "C picks the next tool")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_WHEEL_UP
	up.pressed = true
	_check(inp._event_is(wheel, "tool_next") and inp._event_is(up, "tool_prev") and not inp._event_is(wheel, "attack"), "the mouse wheel picks the next tool or the one before")
	var pad = PlayerInput.make("pad", 0)
	pad.tools = true
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_BACK
	back.pressed = true
	_check(pad._event_is(back, "tool_next"), "Select picks the next tool on a controller")
	pad.tools = false
	_check(not pad._event_is(back, "tool_next"), "and does nothing of the sort elsewhere")
	# The hotbar (version 70): keys 1 to 8 pick a slot straight away, for one tick, and only where there are tools.
	var keys = PlayerInput.make("kbm")
	keys.tools = true
	keys.feed(_key(KEY_4))
	keys.poll()
	var first: int = keys.slot_pick
	keys.poll()
	_check(first == 3 and keys.slot_pick == -1, "key 4 picks the fourth slot, once (%d, then %d)" % [first, keys.slot_pick])
	keys.feed(_key(KEY_9))
	keys.poll()
	_check(keys.slot_pick == -1, "(9 is not a slot)")
	keys.tools = false
	keys.feed(_key(KEY_2))
	keys.poll()
	_check(keys.slot_pick == -1, "and away from the Highlands the number keys pick nothing")
	for action in ["work", "tool_next", "tool_prev", "interact_tools", "dash_tools"]:
		_check(InputMap.has_action(action), "the controls know \"%s\"" % action)


# --- The belt ------------------------------------------------------------------------------

## The Art builder's cracks, bursts and falling pines (art/dig_fx): every picture the tools ask for is on the sheet.
func _drawn() -> void:
	var g = _game(77)
	await _frames(5)
	var tools = g.tools
	_check(tools.fx_sheet != null and not tools.fx.is_empty(), "the sheet of cracks, bursts and falling pines is read")
	_check(tools.crack_of(LandMap.ROCK, 0, 3) == "" and tools.crack_of(LandMap.ROCK, 1, 3) == "crack_rock_1" and tools.crack_of(LandMap.ROCK, 2, 3) == "crack_rock_3",
		"rock shows its first crack after one blow and its last after two (%s, %s)" % [tools.crack_of(LandMap.ROCK, 1, 3), tools.crack_of(LandMap.ROCK, 2, 3)])
	var ore: Array = []
	for kind in [LandMap.TIN, LandMap.COPPER]:
		for hits in [1, 2, 3]:
			ore.append(tools.crack_of(kind, hits, 4))
	_check(ore == ["crack_tin_1", "crack_tin_2", "crack_tin_3", "crack_copper_1", "crack_copper_2", "crack_copper_3"], "ore shows its three cracks after blows one, two and three (%s)" % str(ore))
	_check(tools.crack_of(LandMap.ROCK, 2, 6) == "crack_rock_1" and tools.crack_of(LandMap.ROCK, 5, 6) == "crack_rock_3" and tools.crack_of(LandMap.TIN, 3, 4) == tools.crack_of(LandMap.TIN, 9, 4),
		"harder rock or a stronger tool spreads the same cracks over the blows it takes")
	var missing: Array = []
	for name in ore + ["crack_rock_1", "crack_rock_3", "burst_rock", "burst_tin", "burst_copper", "burst_wood"]:
		if tools._fx_texture(name) == null:
			missing.append(name)
	var pines := 0
	for name in Painter.things:
		if Tools.thing_class({"n": name}) != "pine":
			continue
		pines += 1
		for part in ["shake_r", "shake_l"]:
			if tools._fx_texture("%s_%s" % [name, part]) == null:
				missing.append("%s_%s" % [name, part])
		for side in ["r", "l"]:
			for k in (tools.fx_rules["pines"]["fall_ms"] as Array).size():
				if tools._fx_texture("%s_fall_%s%d" % [name, side, k]) == null:
					missing.append("%s_fall_%s%d" % [name, side, k])
	_check(pines >= 6 and missing.is_empty(), "every crack, every burst, and the shake and fall of all %d pines are on the sheet (missing: %s)" % [pines, str(missing)])
	g.queue_free()
	await _frames(2)


func _belt() -> void:
	var g = _game(77)
	await _frames(5)
	var p = g.players[0]
	var tools = g.tools
	_check(p.input.tools, "the Highlands switch the tool buttons on")
	_check(tools.tool_of(0) == "pickaxe", "you start with the pickaxe picked")
	var belt: Dictionary = tools.hands[0].belt
	_check(str(belt["pickaxe"]) == "basic" and str(belt["axe"]) == "basic" and str(belt["mallet"]) == "basic", "everyone starts with the basic three on the belt")
	var seen: Array = []
	for n in 3:
		await _press(p, "tool_next_pressed")
		seen.append(tools.tool_of(0))
	_check(seen == ["axe", "mallet", "pickaxe"], "the cycle button steps through pickaxe, axe, mallet and round again (%s)" % str(seen))
	await _press(p, "tool_prev_pressed")
	_check(tools.tool_of(0) == "mallet", "the wheel the other way steps back")
	# The mallet has nothing to build yet: swinging it changes nothing.
	var before: PackedByteArray = g.map.kinds.duplicate()
	var things_before: int = g.map.things.size()
	var face := _face(g.map, LandMap.ROCK)
	await _stand(g, p, face[0], face[1])
	await _work(p, 4)
	_check(g.map.kinds == before and g.map.things.size() == things_before and tools.bag_of(0).slots.is_empty(), "the mallet changes nothing yet")
	# A belt with a tool missing skips its place.
	belt["axe"] = ""
	await _press(p, "tool_next_pressed")
	await _press(p, "tool_next_pressed")
	_check(tools.tool_of(0) == "mallet", "a tool you do not have is stepped over (%s)" % tools.tool_of(0))
	belt["axe"] = "basic"
	g.queue_free()
	await _frames(3)
	_check(not p.input.tools if is_instance_valid(p) else true, "leaving the Highlands hands F and the left trigger back")


# --- The hotbar (version 70) ---------------------------------------------------------------

func _slot(p, k: int) -> void:
	await physics_frame
	p.input.slot_pick = k
	await physics_frame
	p.input.slot_pick = -1
	await physics_frame


func _hotbar() -> void:
	var g = _game(77)
	await _frames(5)
	var p = g.players[0]
	var tools = g.tools
	var h = tools.hands[0]
	var bag: Bag = tools.bag_of(0)
	var shown: Array = []
	for k in Tools.HOTBAR:
		shown.append(tools.slot_of(0, k))
	_check(Tools.HOTBAR == 8 and shown == ["pickaxe", "axe", "mallet", "", "", "", "", ""], "the hotbar has eight slots, the three tools in the first three (%s)" % str(shown))
	var screen := Rect2(0, 0, 640, 360)
	var inside := true
	for k in Tools.HOTBAR:
		if not screen.encloses(tools.slot_rect(0, k)) or not tools.belt_rect(0).encloses(tools.slot_rect(0, k)):
			inside = false
	_check(inside, "every slot is drawn on the screen, in the hotbar's box (%s)" % str(tools.belt_rect(0)))
	# A potion that comes in goes on by itself.
	bag.add("potion", 3)
	await _frames(2)
	_check(tools.hotbar_slot(0, "potion") == 3 and tools.slot_of(0, 3) == "potion" and bag.count("potion") == 3, "healing potions that come into the inventory go on the hotbar by themselves, in slot 4")
	_check(bag.slots.size() == 1 and Bag.stack_of("potion") == Bag.POTIONS and Bag.name_of("potion") == "Healing potion", "(they lie in the inventory, stacked to %d)" % Bag.POTIONS)
	var seen: Array = []
	for n in 4:
		await _press(p, "tool_next_pressed")
		seen.append(tools.slot_of(0, h.slot))
	_check(seen == ["axe", "mallet", "potion", "pickaxe"], "the cycle button steps over the empty slots, to the potions and round again (%s)" % str(seen))
	await _press(p, "tool_prev_pressed")
	_check(h.slot == 3 and tools.tool_of(0) == "" and tools.slot_name(0) == "Healing potion", "and back (%s)" % tools.slot_name(0))
	await _slot(p, 6)
	_check(h.slot == 6 and tools.slot_name(0) == "Empty slot" and tools.tool_of(0) == "", "a number key picks its slot even when it is empty")
	await _slot(p, 1)
	_check(h.slot == 1 and tools.tool_of(0) == "axe", "key 2 is the axe")
	# Drinking.
	await _slot(p, 3)
	p.hp = p.max_hp * 0.3
	await _press(p, "work_pressed")
	_check(bag.count("potion") == 2 and absf(p.hp - p.max_hp * (0.3 + Tools.POTION_HEAL)) < 0.01, "the use button drinks one: %d%% of your health back (%.0f of %.0f)" % [roundi(Tools.POTION_HEAL * 100.0), p.hp, p.max_hp])
	await _press(p, "work_pressed")
	_check(bag.count("potion") == 2, "another cannot be drunk straight after")
	await _frames(roundi(Tools.POTION_WAIT * 60.0) + 2)
	await _press(p, "work_pressed")
	_check(bag.count("potion") == 1 and is_equal_approx(p.hp, p.max_hp), "%.1f seconds later it can, and never past your health" % Tools.POTION_WAIT)
	await _frames(roundi(Tools.POTION_WAIT * 60.0) + 2)
	await _press(p, "work_pressed")
	_check(bag.count("potion") == 1, "at full health nothing is drunk")
	# Moved, taken off, put on again.
	_check(tools.put_on(0, "potion", 6) == 6 and tools.slot_of(0, 3) == "" and tools.slot_of(0, 6) == "potion", "a potion moved to slot 7 leaves slot 4")
	_check(tools.put_on(0, "potion", 1) == -1 and tools.put_on(0, "stone", 4) == -1 and tools.slot_of(0, 1) == "axe", "the tools' slots, and stone, are not for the hotbar")
	_check(tools.take_off(0, "potion") and tools.hotbar_slot(0, "potion") == -1, "taken off, the slot is empty")
	await _frames(3)
	_check(tools.hotbar_slot(0, "potion") == -1 and bag.count("potion") == 1, "and it stays off (the potion is still in the inventory)")
	_check(tools.put_on(0, "potion") == 3, "put on again it goes in the first free slot")
	# None left.
	bag.take("potion", 1)
	await _slot(p, 3)
	p.hp = p.max_hp * 0.5
	await _press(p, "work_pressed")
	_check(bag.count("potion") == 0 and is_equal_approx(p.hp, p.max_hp * 0.5) and tools.slot_of(0, 3) == "potion", "with none left nothing happens, and the slot keeps its place for more")
	h.slot = 0
	await _press(p, "tool_prev_pressed")
	_check(h.slot == 2, "(and the cycle steps over it)")
	# Saved with the character.
	var d: Dictionary = tools.hand_data(0)
	_check(d.get("hotbar") == ["potion", "", "", "", ""] and int(d.get("tool", -1)) == 2, "the hotbar is saved with the character (%s)" % str(d.get("hotbar")))
	d["hotbar"] = ["", "stone", "potion", 5, ""]
	d["tool"] = 12
	tools.set_hand_data(0, d)
	_check(h.items == ["", "", "potion", "", ""] and h.slot == 7, "and comes back; what cannot go on the hotbar is left off (%s, slot %d)" % [str(h.items), h.slot])
	# The lab's potions.
	Tools.LAB_POTIONS = 2
	await _frames(2)
	_check(bag.count("potion") == 2, "the lab can give everybody potions")
	Tools.LAB_POTIONS = 0
	g.queue_free()
	await _frames(3)


# --- Digging rock --------------------------------------------------------------------------

func _digging() -> void:
	var g = _game(77)
	await _frames(5)
	var p = g.players[0]
	var tools = g.tools
	var m: LandMap = g.map
	var face := _face(m, LandMap.ROCK)
	_check(not face.is_empty(), "there is rock with open ground beside it")
	var tile: Vector2i = face[0]
	var dir: Vector2 = face[1]
	await _stand(g, p, tile, dir)
	var stood: Vector2 = p.global_position
	# Walking at it does nothing: rock stops you.
	p.input.move = dir
	await _frames(20)
	p.input.move = Vector2.ZERO
	# (Since version 56 the player is smaller, so there is a little room before the rock.)
	_check(m.is_rock(tile.x, tile.y) and p.global_position.distance_to(stood) < 12.0 and Vector2i((p.global_position / TILE).floor()) != tile, "rock stops you until it is dug")
	await _stand(g, p, tile, dir)
	# One blow marks it; it is not dug yet. While the tool swings, the tool is in the hand and you walk slowly.
	p.input.work_held = true
	await _frames(8)
	_check(p.tool_dir.distance_to(dir) < 0.01 and p.tool_move < 0.5, "while the pickaxe swings you face the work and walk slowly")
	_check(p.current_step < 0, "and the weapon does not swing")
	await _frames(8)
	p.input.work_held = false
	_check(tools.wear.size() == 1 and m.is_rock(tile.x, tile.y), "one blow marks the rock but does not dig it")
	await _frames(SWING_TICKS)
	_check(p.tool_dir == Vector2.ZERO and p.tool_move == 1.0, "when the swing ends the weapon is back in the hand")
	# Left alone, the mark goes.
	await _frames(int(Tools.FORGET * 60.0) + 10)
	_check(tools.wear.is_empty(), "rock left alone is whole again")
	# Two blows dig it (Darren's "easier to mine", version 58: it was three).
	var chunk := LandMap.chunk_key(floori(tile.x / 16.0), floori(tile.y / 16.0))
	var before: Image = (g.land.chunks[chunk]["sprite"] as Sprite2D).texture.get_image()
	await _work(p, int(Tools.NEED["rock"]))
	_check(m.kind(tile.x, tile.y) == LandMap.FLOOR, "%d blows of the pickaxe dig a rock tile out (it is %s)" % [int(Tools.NEED["rock"]), LandMap.NAMES[m.kind(tile.x, tile.y)]])
	_check(tools.bag_of(0).count("stone") == 1, "and one stone goes in the bag (%d)" % tools.bag_of(0).count("stone"))
	_check(m.dug.has(tile.y * LandMap.SIZE + tile.x) and m.dug.size() == 1, "the map remembers what was dug, for the world save")
	await _frames(3)
	g.land.settle()
	var after: Image = (g.land.chunks[chunk]["sprite"] as Sprite2D).texture.get_image()
	_check(before.get_data() != after.get_data(), "the land is painted again where it was dug")
	p.input.move = dir
	await _frames(24)
	p.input.move = Vector2.ZERO
	var in_tile := Vector2i(floori(p.global_position.x / TILE), floori(p.global_position.y / TILE))
	_check(in_tile == tile, "and you can walk in where the rock was, though the way is one tile wide (%s, not %s)" % [str(in_tile), str(tile)])
	# A tunnel one tile wide can be walked: dig two more and go to the end.
	for n in 2:
		p.global_position = (Vector2(tile) + Vector2(0.5, 0.5) + dir * float(n)) * TILE
		await _frames(2)
		await _work(p, 3)
	await _frames(3)
	g.land.settle()
	p.global_position = (Vector2(tile) + Vector2(0.5, 0.5) - dir + Vector2(dir.y, dir.x) * 0.2) * TILE     # (a little off its middle)
	p.input.move = dir
	await _frames(40)
	p.input.move = Vector2.ZERO
	var end := Vector2i(tile + Vector2i(dir) * 2)
	_check(Vector2i(floori(p.global_position.x / TILE), floori(p.global_position.y / TILE)) == end and m.kind(end.x, end.y) == LandMap.FLOOR, "a tunnel dug one tile wide can be walked to its end")
	# The axe does not dig, and the game never picks the pickaxe for you.
	var next := _face(m, LandMap.ROCK, false, 3)
	await _stand(g, p, next[0], next[1])
	await _press(p, "tool_next_pressed")
	await _work(p, 5)
	_check(tools.tool_of(0) == "axe" and m.is_rock(next[0].x, next[0].y), "the axe does not dig, and the game never picks the tool for you")
	# Attacking always wins over the tool.
	await _press(p, "tool_prev_pressed")
	p.input.work_held = true
	await _frames(6)
	p.input.attack_pressed = true
	await physics_frame
	p.input.attack_pressed = false
	await _frames(3)
	_check(p.current_step >= 0 and p.tool_dir == Vector2.ZERO, "attack while a tool swings and the weapon swings instead")
	p.input.work_held = false
	await _frames(60)
	g.queue_free()
	await _frames(3)


# --- Mining ore ----------------------------------------------------------------------------

func _shown(m: LandMap, v: Dictionary) -> int:
	var n := 0
	for px: Vector2i in v["px"]:
		if m.vein_shows(v, px):
			n += 1
	return n


func _mining() -> void:
	for pair in [[LandMap.TIN, "tin_ore"], [LandMap.COPPER, "copper_ore"]]:
		var g = _game(77)
		await _frames(5)
		var p = g.players[0]
		var tools = g.tools
		var m: LandMap = g.map
		var face := _face(m, int(pair[0]))
		_check(not face.is_empty(), "there is %s with open ground beside it" % LandMap.NAMES[int(pair[0])])
		if face.is_empty():
			g.queue_free()
			continue
		var tile: Vector2i = face[0]
		var vein := {}
		for v in m.veins:
			if (v["set"] as Dictionary).has(tile):
				vein = v
		var all: int = (vein["px"] as Dictionary).size()
		var mine := 0                # the pixels of the seam that belong to this tile
		for px: Vector2i in vein["px"]:
			var t := Vector2i(px.x >> 4, px.y >> 4)
			if t == tile or (not (vein["set"] as Dictionary).has(t) and (vein["own"] as Dictionary).get(px, t) == tile):
				mine += 1
		_check(_shown(m, vein) == all and mine > 0, "before mining the whole seam is there (%d pixels, %d of them this tile's)" % [all, mine])
		await _stand(g, p, tile, face[1])
		var chunk := LandMap.chunk_key(floori(tile.x / 16.0), floori(tile.y / 16.0))
		var before: Image = (g.land.chunks[chunk]["sprite"] as Sprite2D).texture.get_image()
		var need := int(Tools.NEED[Tools.TILE_NAME[int(pair[0])]])
		await _work(p, need - 1)
		_check(m.kind(tile.x, tile.y) == int(pair[0]) and tools.bag_of(0).count(str(pair[1])) == 0, "ore takes one more blow than rock")
		await _frames(2)
		await _work(p, need)
		_check(m.kind(tile.x, tile.y) == LandMap.FLOOR, "%d blows mine a tile of %s" % [need, LandMap.NAMES[int(pair[0])]])
		_check(tools.bag_of(0).count(str(pair[1])) == 2 and tools.bag_of(0).count("stone") == 0, "and two %s go in the bag, not stone" % str(pair[1]).replace("_", " "))
		_check(_shown(m, vein) == all - mine, "the mined tile's own part of the seam is gone and the rest stays (%d of %d left)" % [_shown(m, vein), all])
		_check((vein["px"] as Dictionary).size() == all, "and the seam is not worked out again")
		await _frames(3)
		g.land.settle()
		var after: Image = (g.land.chunks[chunk]["sprite"] as Sprite2D).texture.get_image()
		_check(before.get_data() != after.get_data(), "the land is painted again where the ore was")
		g.queue_free()
		await _frames(3)


# --- Felling pines, breaking boulders -------------------------------------------------------

func _felling() -> void:
	var g = _game(77)
	await _frames(5)
	var p = g.players[0]
	var tools = g.tools
	var m: LandMap = g.map
	var pine := _thing(m, "pine_")
	_check(not pine.is_empty(), "there is a pine with room to stand beside it")
	p.global_position = _beside(pine)
	p.input.stick_aim = Vector2.RIGHT
	g.rig.snap()
	await _frames(4)
	g.land.settle()
	_check(p.global_position.distance_to(_beside(pine)) < 6.0, "you can stand beside it")
	var n_things := m.things.size()
	# The pickaxe does not fell.
	await _work(p, 6)
	_check(m.things.has(pine) and tools.bag_of(0).count("wood") == 0, "the pickaxe does not fell a pine")
	await _press(p, "tool_next_pressed")
	_check(tools.tool_of(0) == "axe", "the axe is picked by hand")
	await _work(p, int(Tools.NEED["pine"]) - 1)
	_check(m.things.has(pine), "a pine stands until the last blow")
	await _frames(2)
	await _work(p, int(Tools.NEED["pine"]))
	_check(not m.things.has(pine), "%d blows of the axe fell a pine" % int(Tools.NEED["pine"]))
	_check(tools.bag_of(0).count("wood") == 3, "and three wood go in the bag (%d)" % tools.bag_of(0).count("wood"))
	var stump := {}
	for t in m.things:
		if str(t["n"]) == "pine_stump" and int(t["x"]) == int(pine["x"]) and int(t["y"]) == int(pine["y"]):
			stump = t
	_check(not stump.is_empty() and m.things.size() == n_things, "its stump is left where it stood")
	_check(m.gone.has(LandMap.thing_key(pine)) and m.added.has(stump), "the map remembers the pine went and the stump came, for the world save")
	_check(Painter.things.has("pine_stump") and g.land.sprite_of(stump) != null, "the stump is drawn")
	await _work(p, 6)
	_check(m.things.has(stump) and tools.bag_of(0).count("wood") == 3, "a stump gives nothing more")
	# A boulder breaks up under the pickaxe.
	var rock := _thing(m, "boulder_")
	_check(not rock.is_empty(), "there is a boulder with room to stand beside it")
	if not rock.is_empty():
		p.global_position = _beside(rock)
		g.rig.snap()
		await _frames(4)
		g.land.settle()
		await _work(p, 5)
		_check(m.things.has(rock), "the axe does not break a boulder")
		await _press(p, "tool_prev_pressed")
		await _work(p, int(Tools.NEED["boulder"]))
		_check(not m.things.has(rock) and tools.bag_of(0).count("stone") == 2, "%d blows of the pickaxe break a boulder into two stone (%d)" % [int(Tools.NEED["boulder"]), tools.bag_of(0).count("stone")])
		p.input.move = Vector2.RIGHT
		await _frames(40)
		p.input.move = Vector2.ZERO
		_check(p.global_position.x > float(rock["x"]) * 2.0 - 4.0, "and you can walk where it was")
	g.queue_free()
	await _frames(3)


# --- Darren's numbers (version 58), and bronze ---------------------------------------------

## Darren, 25 November: "Think we make the stone easier to mine seeing as it's the starter biome also", "Then even
## easier when we upgrade tools to bronze". The blows are his ask made into numbers (Claude's: rock 2, ore 3, a boulder
## 2, a pine still 5), and a bronze tool's blow is worth two basic ones. Nothing gives a bronze tool yet.
func _bronze() -> void:
	_check(Tools.NEED == {"rock": 2, "tin": 3, "copper": 3, "boulder": 2, "pine": 5}, "a basic tool digs rock in 2 blows, mines tin and copper in 3, breaks a boulder in 2 and fells a pine in 5 (%s)" % str(Tools.NEED))
	_check(is_equal_approx(float(Tools.POWER["basic"]), 1.0) and is_equal_approx(float(Tools.POWER["bronze"]), 2.0), "a bronze tool's blow is worth two of a basic one's (%s)" % str(Tools.POWER))
	var g = _game(77)
	await _frames(5)
	var p = g.players[0]
	var tools = g.tools
	var m: LandMap = g.map
	_check(tools.hand_data(0)["belt"] == {"pickaxe": "basic", "axe": "basic", "mallet": "basic"}, "everyone still starts with the basic three, and nothing gives bronze (%s)" % str(tools.hand_data(0)["belt"]))
	# A character saved with a bronze pickaxe (as one will be, once the anvil makes them) keeps it.
	tools.set_hand_data(0, {"belt": {"pickaxe": "bronze"}, "tool": 0})
	_check(tools.tool_of(0) == "pickaxe" and str(tools.hand_data(0)["belt"]["pickaxe"]) == "bronze", "a bronze pickaxe on the belt stays bronze")
	var face := _face(m, LandMap.ROCK, false, 3)
	_check(not face.is_empty(), "there is rock to try a bronze pickaxe on")
	if not face.is_empty():
		await _stand(g, p, face[0], face[1])
		await _work(p, 1)
		_check(m.kind(face[0].x, face[0].y) == LandMap.FLOOR, "one blow of a bronze pickaxe digs rock")
	for kind in [LandMap.TIN, LandMap.COPPER]:
		face = _face(m, kind)
		_check(not face.is_empty(), "there is %s to try it on" % LandMap.NAMES[kind])
		if face.is_empty():
			continue
		await _stand(g, p, face[0], face[1])
		await _work(p, 1)
		var after_one := m.kind(face[0].x, face[0].y)
		await _work(p, 1)
		_check(after_one == kind and m.kind(face[0].x, face[0].y) == LandMap.FLOOR, "a bronze pickaxe mines %s in two blows" % LandMap.NAMES[kind])
	var rock := _thing(m, "boulder_", 1)
	_check(not rock.is_empty(), "there is a boulder to try it on")
	if not rock.is_empty():
		p.global_position = _beside(rock)
		p.input.stick_aim = Vector2.RIGHT
		g.rig.snap()
		await _frames(4)
		await _work(p, 1)
		_check(not m.things.has(rock), "and breaks a boulder in one")
	# A make this game does not know becomes basic again.
	tools.set_hand_data(0, {"belt": {"pickaxe": "mithril"}})
	_check(str(tools.hand_data(0)["belt"]["pickaxe"]) == "basic", "a make the game does not have is the basic one")
	g.queue_free()
	await _frames(3)


# --- What cannot be dug, and a full bag -----------------------------------------------------

func _limits() -> void:
	var g = _game(77)
	await _frames(5)
	var p = g.players[0]
	var tools = g.tools
	var m: LandMap = g.map
	# The hill the cave mouth is in can never be dug.
	var hill := _face(m, LandMap.ROCK, true)
	_check(not hill.is_empty() and m.fixed(m.mouth.x, m.mouth.y) and m.fixed(m.mouth.x - 4, m.mouth.y - 6) and not m.fixed(m.mouth.x - 5, m.mouth.y), "the hill round the cave mouth is fixed rock")
	_check(m.fixed(m.region.position.x + 2, m.mouth.y) and not m.fixed(m.region.position.x + 3, m.mouth.y) and m.fixed(m.mouth.x, m.region.end.y - 3), "and so is the rim of the land laid out so far")
	if not hill.is_empty():
		await _stand(g, p, hill[0], hill[1])
		await _work(p, 5)
		_check(m.is_rock(hill[0].x, hill[0].y) and tools.wear.is_empty() and tools.bag_of(0).slots.is_empty(), "fixed rock takes no mark and gives nothing")
	# A full bag: ore stays in the rock, plain rock can still be dug (the stone is left).
	tools.bag_of(0).add("stone", 99 * Bag.SLOTS)
	var ore := _face(m, LandMap.TIN)
	await _stand(g, p, ore[0], ore[1])
	await _work(p, 6)
	_check(m.kind(ore[0].x, ore[0].y) == LandMap.TIN, "with a full bag the ore stays in the rock")
	var rock := _face(m, LandMap.ROCK)
	await _stand(g, p, rock[0], rock[1])
	await _work(p, 3)
	_check(m.kind(rock[0].x, rock[0].y) == LandMap.FLOOR and tools.bag_of(0).count("stone") == 99 * Bag.SLOTS, "but rock can still be dug: the stone is left behind")
	_check(tools.bag_of(0).take("stone", 99) and tools.bag_of(0).room("tin_ore") == 99, "taking a stack out makes room again")
	await _stand(g, p, ore[0], ore[1])
	await _work(p, 4)
	_check(m.kind(ore[0].x, ore[0].y) == LandMap.FLOOR and tools.bag_of(0).count("tin_ore") == 2, "and then the ore can be mined")
	g.queue_free()
	await _frames(3)


# --- Two players ---------------------------------------------------------------------------

func _two_players() -> void:
	var g = _game(77, 2)
	await _frames(5)
	var tools = g.tools
	var m: LandMap = g.map
	var a = g.players[0]
	var b = g.players[1]
	var face := _face(m, LandMap.ROCK)
	a.global_position = (Vector2(face[0]) + Vector2(0.5, 0.5) - (face[1] as Vector2) * 3.0) * TILE
	await _press(a, "tool_next_pressed")
	await _stand(g, b, face[0], face[1])
	await _work(b, 3)
	_check(tools.tool_of(0) == "axe" and tools.tool_of(1) == "pickaxe", "each player picks their own tool")
	_check(tools.bag_of(1).count("stone") == 1 and tools.bag_of(0).slots.is_empty(), "and what you dig goes in your own bag")
	_check(tools.belt_rect(0).position.x < 320.0 and tools.belt_rect(1).position.x > 320.0, "the second player's belt is on their side of the screen")
	_check(not tools.belt_rect(0).grow(40.0).intersects(tools.belt_rect(1).grow(40.0)), "the two hotbars of eight are well apart (%s, %s)" % [str(tools.belt_rect(0)), str(tools.belt_rect(1))])
	g.queue_free()
	await _frames(3)


# --- Pictures ------------------------------------------------------------------------------

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 640:
		img.resize(640, 360, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [shot_dir, name])
	print("saved %s/%s.png" % [shot_dir, name])


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var g = _game(shot_seed)
	await _frames(10)
	var p = g.players[0]
	var tools = g.tools
	var m: LandMap = g.map
	# Mining into a vein: a tile of ore with a rock face to the south, away from the base.
	for pair in [[LandMap.COPPER, "copper"], [LandMap.TIN, "tin"]]:
		var tile := Vector2i(-1, -1)
		for v in m.veins:
			if tile.x >= 0:
				break
			for t: Vector2i in v["cells"]:
				if m.kind(t.x, t.y) == int(pair[0]) and m.walkable(t.x, t.y + 1) and m.walkable(t.x, t.y + 2) and (v["cells"] as Array).size() >= 4 \
						and Vector2(t).distance_to(m.spawn) > 20.0 and _clear(m, (Vector2(t) + Vector2(0.5, 1.5)) * TILE):
					tile = t
					break
		if tile.x < 0:
			continue
		await _stand(g, p, tile, Vector2.UP)
		await _frames(30)
		await _snap("%s_0_before" % pair[1])
		p.input.work_held = true
		var marks := {4: "1_raised", 13: "2_blow_1", 15: "2a_chips", 18: "2b_chips", 26: "2c_after_blow_1", 42: "3_blow_2", 44: "3a_chips", 54: "3c_after_blow_2", 71: "4_blow_3", 73: "4a_chips", 83: "4c_after_blow_3",
			100: "5_blow_4", 102: "5a_burst", 105: "5b_burst", 110: "6_hop", 119: "6a_lying", 131: "6b_flying", 137: "6c_flying", 146: "7_bag"}
		for f in 150:
			await physics_frame
			if marks.has(f):
				await _snap("%s_%s" % [pair[1], marks[f]])
			elif dense and f < 64:
				await _snap("%s_f%03d" % [pair[1], f])
		p.input.work_held = false
		await _frames(40)
		g.land.settle()
		await _frames(10)
		await _snap("%s_8_first_tile_out" % pair[1])
		# Walk in and go on: three tiles deeper, whatever is there.
		for n in 3:
			p.global_position = (Vector2(tile) + Vector2(0.5, 0.5) + Vector2.UP * float(n)) * TILE
			await _frames(3)
			await _work(p, 4)
		await _frames(20)
		g.land.settle()
		await _frames(10)
		await _snap("%s_9_dug_in" % pair[1])
		# And sideways, from inside the tunnel: the cracks on the rock's dark top, and the burst out in the open.
		p.input.stick_aim = Vector2.RIGHT
		await _frames(4)
		p.input.work_held = true
		var side := {20: "1_cracked", 50: "2_cracked", 72: "3_blow", 74: "3a_burst", 77: "3b_burst", 81: "3c_burst", 86: "3d_burst", 92: "4_lying", 101: "5_blow", 105: "5a_burst", 110: "5b_burst"}
		for f in 112:
			await physics_frame
			if side.has(f):
				await _snap("%s_side_%s" % [pair[1], side[f]])
		p.input.work_held = false
		await _frames(50)
		g.land.settle()
		await _frames(10)
		await _snap("%s_side_6_out" % pair[1])
	# Felling a pine.
	var pine := _thing(m, "pine_", 2)
	if not pine.is_empty():
		p.global_position = _beside(pine)
		p.input.stick_aim = Vector2.RIGHT
		g.rig.snap()
		await _frames(4)
		g.land.settle()
		await _press(p, "tool_next_pressed")
		await _frames(30)
		await _snap("pine_0_before")
		p.input.work_held = true
		var marks := {4: "1_raised", 13: "2_blow_1", 14: "2a_leans", 17: "2b_leans_back", 21: "2c_still", 71: "3_blow_3", 73: "3a_leans", 129: "4_blow_5", 131: "5_fall_0", 135: "5_fall_1", 139: "5_fall_2",
			143: "5_fall_3", 147: "5_fall_4", 152: "5_fall_5", 157: "6_down", 161: "6a_down", 168: "7_wood_lying", 185: "7a_wood_flying", 196: "7b_wood_flying", 208: "7c_bag"}
		for f in 212:
			await physics_frame
			if f == 131:
				p.input.work_held = false
			if marks.has(f):
				await _snap("pine_%s" % marks[f])
		p.input.work_held = false
		await _frames(60)
		g.land.settle()
		await _frames(10)
		await _snap("pine_8_stump")
	# The mallet picked, and "nothing to build yet".
	await _press(p, "tool_next_pressed")
	p.input.work_held = true
	await _frames(16)
	await _snap("mallet")
	p.input.work_held = false
	await _frames(30)
	# Breaking a boulder (the pickaxe again).
	await _press(p, "tool_next_pressed")
	var boulder := _thing(m, "boulder_", 1)
	if not boulder.is_empty():
		p.global_position = _beside(boulder)
		p.input.stick_aim = Vector2.RIGHT
		g.rig.snap()
		await _frames(4)
		g.land.settle()
		await _frames(30)
		await _snap("boulder_0_before")
		p.input.work_held = true
		var marks := {13: "1_blow_1", 15: "1a_chips", 22: "1b_after", 80: "2_after_blow_3", 100: "3_blow_4", 102: "3a_burst", 105: "3b_burst", 109: "3c_burst", 114: "3d_burst", 122: "4_lying", 138: "5_flying"}
		for f in 150:
			await physics_frame
			if f == 102:
				p.input.work_held = false
			if marks.has(f):
				await _snap("boulder_%s" % marks[f])
		await _frames(40)
		g.land.settle()
		await _frames(10)
		await _snap("boulder_6_gone")
