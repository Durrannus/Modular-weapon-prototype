extends SceneTree
## Saving (version 42): saved characters, saved worlds, the screen that picks them, and the Highlands saving by
## themselves. Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/saving.gd
##
## Everything it writes goes into its own folders (user://test_saves...), never the player's saves.
##
## With shots=/some/folder/ (needs a window, so leave out --headless) it saves 640x360 pictures instead: the pick
## screens, the word "Saved", and a dug world before leaving and after coming back.
## With "ref" it writes the fingerprint of the land again (only after raising WorldGen.GEN: see _land_made_the_same).

const PlayerInput := preload("res://scripts/player_input.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const Tools := preload("res://scripts/highlands/tools.gd")
const Bag := preload("res://scripts/highlands/bag.gd")
const Save := preload("res://scripts/save.gd")
const SavePick := preload("res://scripts/ui/save_pick.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Boot := preload("res://scripts/boot.gd")
const Arena := preload("res://scripts/main.gd")
const TILE := 32.0
const SWING_TICKS := 29
const ROOT := "user://test_saves"
const REF := "res://tests/saving_land_ref.json"
const REF_SEED := 424242
const C := Save.CHARACTERS
const W := Save.WORLDS

var fails := 0
var checks := 0
var shot_dir := ""
var phase := ""
var write_ref := false


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shot_dir = a.substr(6)
		elif a.begins_with("phase="):
			phase = a.substr(6)
		elif a == "ref":
			write_ref = true
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
	if phase != "":
		await _quit_phase()
		return
	if shot_dir != "":
		await _shots()
		quit()
		return
	_fresh_folder(ROOT)
	_files()
	_words()
	_weapons()
	_land()
	_land_made_the_same()
	await _play()
	await _other_ways_to_save()
	await _old_and_broken()
	await _two_players()
	await _pick_screen()
	await _front_door()
	_closing_the_game()
	print("%s  saving: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


# --- Helpers -------------------------------------------------------------------------------

## Empties one of this test's own save folders and makes it the place saves go.
func _fresh_folder(path: String) -> void:
	for sub in ["characters", "worlds", "deleted"]:
		var dir := DirAccess.open("%s/%s" % [path, sub])
		if dir != null:
			for f in dir.get_files():
				dir.remove(f)
	Save.root = path


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _spoil(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ \"kind\": \"character\", \"id\": ")      # cut off in the middle, as a crash would leave it
	f.close()


func _game(characters: Array, world: Dictionary, carry := {}, seed_value := 0):
	var g = Highlands.new()
	var inputs: Array = []
	for i in maxi(characters.size(), 1):
		inputs.append(PlayerInput.make("script"))
	g.inputs = inputs
	g.characters = characters
	g.world_save = world
	g.carry = carry
	g.world_seed = seed_value
	g.with_foes = false
	g.welcome = shot_dir != "" and false
	root.add_child(g)
	return g


func _leave(g) -> void:
	g.queue_free()
	await _frames(3)


## Nothing that stops you stands within a tile and a half of this place (world units)?
func _clear(m: LandMap, at: Vector2) -> bool:
	for t in m.things:
		if Painter.things.get(str(t["n"]), {}).has("solid") and (Vector2(float(t["x"]), float(t["y"])) * 2.0).distance_to(at) < 56.0:
			return false
	return true


## A tile of this kind that can be dug, with open ground beside it to stand on: [the tile, the way to face it].
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


## A pine with room to stand west of it.
func _pine(m: LandMap) -> Dictionary:
	for t in m.things:
		if Tools.thing_class(t) != "pine":
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
			return t
	return {}


func _beside(t: Dictionary) -> Vector2:
	var solid: Array = Painter.things[str(t["n"])]["solid"]
	return Vector2(float(t["x"]), float(t["y"])) * 2.0 + Vector2(-float(solid[0]) - 19.0, -5.0)


func _stand(g, p, tile: Vector2i, dir: Vector2) -> void:
	p.global_position = (Vector2(tile) + Vector2(0.5, 0.5) - dir) * TILE
	p.input.stick_aim = dir
	p.input.move = Vector2.ZERO
	g.rig.snap()
	await _frames(4)
	g.land.settle()


func _work(p, swings: int) -> void:
	p.input.work_held = true
	await _frames((swings - 1) * SWING_TICKS + 16)
	p.input.work_held = false
	await _frames(SWING_TICKS + 2)


func _press(p, field: String) -> void:
	await physics_frame
	p.input.set(field, true)
	await physics_frame
	p.input.set(field, false)
	await physics_frame


## Everything a save must bring back, as text that can be compared.
func _state(g, i := 0) -> Dictionary:
	return {
		"things": str(g.map.things),
		"changes": JSON.stringify(g.map.changes()),
		"bag": JSON.stringify(g.tools.hands[i].bag.data()),
		"belt": JSON.stringify(g.tools.hands[i].belt),
		"tool": int(g.tools.hands[i].tool),
		"hotbar": JSON.stringify(g.tools.hands[i].items),
		"weapons": JSON.stringify(g.builds[i].to_save()),
		"weapon": JSON.stringify(g.builds[i].get_data()),
		"owned": JSON.stringify(g.owned[i]),
	}


## The painted ground of the chunk a tile is in, as bytes.
func _painted(m: LandMap, tile: Vector2i) -> PackedByteArray:
	return Painter.paint(m, tile.x / LandMap.CHUNK, tile.y / LandMap.CHUNK).get_data()


# --- The files -----------------------------------------------------------------------------

func _files() -> void:
	_check(Save.good_id(C, "character_12") and not Save.good_id(C, "world_12") and not Save.good_id(C, "character_0") and not Save.good_id(C, "character_x")
		and not Save.good_id(C, "../character_1") and not Save.good_id(C, "character_1/../../x") and not Save.good_id("elsewhere", "character_1"),
		"only a save's own name is ever made into a file name")
	_check(Save.ids(C).is_empty() and Save.list(C).is_empty() and Save.read(C, "character_1").is_empty(), "with no saves there is nothing to list or read")
	var a := Save.fresh(C)
	_check(a["id"] == "character_1" and a["name"] == "Character 1" and a["kind"] == "character" and a.get("unsaved", false), "the first new character is Character 1, and is not written yet")
	_check(not FileAccess.file_exists(Save.path(C, "character_1")), "making one writes nothing")
	a["bag"] = [["stone", 3]]
	_check(Save.write(C, a) and FileAccess.file_exists(Save.path(C, "character_1")) and not a.has("unsaved"), "writing it puts its file on the disk")
	_check(not FileAccess.file_exists(Save.path(C, "character_1") + ".bak") and not FileAccess.file_exists(Save.path(C, "character_1") + ".tmp"), "the first write leaves no backup and no half-written file")
	var back := Save.read(C, "character_1")
	_check(back.get("name") == "Character 1" and JSON.stringify(back.get("bag")) == JSON.stringify([["stone", 3.0]]) and not back.has("restored") and not back.has("newer"),
		"and it reads back as it was written")
	var first := _text(Save.path(C, "character_1"))
	a["bag"] = [["stone", 9]]
	_check(Save.write(C, a) and _text(Save.path(C, "character_1") + ".bak") == first and _text(Save.path(C, "character_1")) != first, "a second write keeps the save before it as the backup")
	var second := _text(Save.path(C, "character_1"))

	# A save that cannot be read: the backup is used, and is not pushed out by the damaged file.
	_spoil(Save.path(C, "character_1"))
	back = Save.read(C, "character_1")
	_check(back.get("restored", false) and int(back["bag"][0][1]) == 3, "a damaged save is read from its backup, and says so")
	_check(Save.list(C).size() == 1 and Save.list(C)[0].get("restored", false), "and is still on the list")
	back["bag"] = [["stone", 4]]
	_check(Save.write(C, back) and _text(Save.path(C, "character_1") + ".bak") == first, "writing over a damaged save leaves the good backup where it is")
	_check(not Save.read(C, "character_1").has("restored") and not _text(Save.path(C, "character_1")).contains("restored"), "and the save is whole again (the mark is not written into it)")
	DirAccess.remove_absolute(Save.path(C, "character_1"))
	_check(Save.ids(C) == ["character_1"] and Save.read(C, "character_1").get("restored", false), "a save with only its backup left is still found")
	_check(Save.write(C, back), "(written again)")

	# A leftover half-written file from a crash is nobody's save.
	_spoil(Save.path(C, "character_1") + ".tmp")
	_check(Save.ids(C) == ["character_1"] and int(Save.read(C, "character_1")["bag"][0][1]) == 4, "a half-written file left by a crash changes nothing")
	a = Save.read(C, "character_1")
	a["bag"] = [["stone", 5]]
	_check(Save.write(C, a) and not FileAccess.file_exists(Save.path(C, "character_1") + ".tmp") and int(Save.read(C, "character_1")["bag"][0][1]) == 5, "and the next write clears it away")

	# Names, the order of the list, and deleting.
	var b := Save.fresh(C)
	var c := Save.fresh(C, [b["id"]])
	_check(b["id"] == "character_2" and c["id"] == "character_3", "two new characters made on the same screen get different names (%s, %s)" % [b["id"], c["id"]])
	b["played"] = 2000.0
	c["played"] = 3000.0
	a["played"] = 1000.0
	_check(Save.write(C, a) and Save.write(C, b) and Save.write(C, c), "(three characters)")
	var order: Array = Save.list(C).map(func(d): return d["id"])
	_check(order == ["character_3", "character_2", "character_1"], "the list has the one played last first (%s)" % str(order))
	_check(Save.remove(C, "character_3") and Save.ids(C).size() == 2 and FileAccess.file_exists(ROOT + "/deleted/character_3.json"), "a deleted save leaves the list and is moved to saves/deleted")
	_check(Save.fresh(C)["id"] == "character_4", "and its name is never given again (%s)" % Save.fresh(C)["id"])
	_check(not Save.remove(C, "character_3") and not Save.remove(C, "../worlds/world_1"), "deleting what is not there does nothing")

	# Kinds do not mix, and a newer game's save is left alone.
	var w := Save.fresh(W)
	w["seed"] = 123456
	_check(w["id"] == "world_1" and w["name"] == "World 1" and Save.write(W, w) and Save.list(W).size() == 1 and Save.list(C).size() == 2, "worlds are their own list")
	DirAccess.copy_absolute(Save.path(W, "world_1"), Save.path(C, "character_9"))
	_check(Save.read(C, "character_9").is_empty() and Save.list(C).size() == 2, "a world's file under a character's name is not a character")
	DirAccess.remove_absolute(Save.path(C, "character_9"))
	var newer := Save.fresh(W)
	_check(Save.write(W, newer), "(a second world)")
	var raw: Dictionary = JSON.parse_string(_text(Save.path(W, str(newer["id"]))))
	raw["format"] = Save.FORMAT + 1
	var f := FileAccess.open(Save.path(W, str(newer["id"])), FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	var kept := _text(Save.path(W, str(newer["id"])))
	var seen := Save.read(W, str(newer["id"]))
	_check(seen.get("newer", false) and not Save.write(W, seen) and _text(Save.path(W, str(newer["id"]))) == kept, "a save written by a newer game is marked, and is never written over")
	_check(not Save.write(C, {"id": "character_1/../x", "kind": "character"}) and not Save.write(C, {}), "a save without a proper name is not written")
	Save.remove(W, str(newer["id"]))
	Save.remove(W, "world_1")
	Save.remove(C, "character_1")
	Save.remove(C, "character_2")
	second = second     # (kept for reading the test)


func _words() -> void:
	var noon := 1795000000.0 - fmod(1795000000.0, 86400.0) + 43200.0 - float(int(Time.get_time_zone_from_system().get("bias", 0))) * 60.0
	_check(Save.when(0.0) == "never", "a save never played says so")
	_check(Save.when(noon - 3600.0, noon) == "today 11:00", "today's saves give the time (%s)" % Save.when(noon - 3600.0, noon))
	_check(Save.when(noon - 86400.0 + 300.0, noon) == "yesterday 12:05", "yesterday's too (%s)" % Save.when(noon - 86400.0 + 300.0, noon))
	_check(not Save.when(noon - 5.0 * 86400.0, noon).contains(":") and Save.when(noon - 5.0 * 86400.0, noon).length() <= 6, "older ones give the day (%s)" % Save.when(noon - 5.0 * 86400.0, noon))
	_check(Save.when(noon - 500.0 * 86400.0, noon).length() >= 10, "and the year when it is another year (%s)" % Save.when(noon - 500.0 * 86400.0, noon))
	_check(Save.how_long(20.0) == "under a minute" and Save.how_long(12.0 * 60.0 + 5.0) == "12 min" and Save.how_long(3.0 * 3600.0 + 5.0 * 60.0) == "3 h 05", "time played reads in minutes, then hours")


# --- The weapons a character carries ---------------------------------------------------------

func _weapons() -> void:
	var b := SwingBuild.new()
	b.load_test("D")
	b.stowed["bow"] = SwingBuild.TEST_BOW.duplicate(true)
	b.stowed["hammer"] = SwingBuild.TEST_HAMMER.duplicate(true)
	b.preset_names[0] = "Bossing"
	b.use_preset(1)
	b.set_slot(3, "")
	b.preset_names[1] = "Running"
	b.take("bow")                     # the sword and its presets are put away, the bow is in the hand
	b.use_preset(2)
	b.preset_names[2] = "Far"
	var saved := JSON.stringify(b.to_save())
	var c := SwingBuild.new()
	var problems := c.from_save(JSON.parse_string(saved))
	_check(problems.is_empty() and JSON.stringify(c.to_save()) == saved, "a character's weapons, presets and their names come back from a save exactly")
	_check(c.weapon() == "bow" and c.preset == 2 and c.preset_names[2] == "Far" and c.stowed.has("sword") and c.stowed.has("hammer"), "the bow is in the hand on its third preset, the sword and hammer are put away")
	c.take("sword")
	b.take("sword")
	_check(c.preset == 1 and c.preset_names == ["Bossing", "Running", ""] and c.line[3] == "" and c.preset_sword(0) != null and c.get_data() == b.get_data() and c.preset_sword(0) == b.preset_sword(0),
		"and the sword still has its own presets when it is taken up again")

	# What this game does not know is left out, never put in anybody's hand.
	var odd: Dictionary = JSON.parse_string(saved)
	odd["hand"][0] = "bow_from_a_later_version"
	odd["stowed"]["hammer"][3] = ["quake"]
	var d := SwingBuild.new()
	problems = d.from_save(odd)
	_check(problems.size() == 2 and d.weapon() == "sword" and d.blade == "iron_broadsword" and d.preset == 1 and d.preset_names[0] == "Bossing" and d.stowed.is_empty() and SwingBuild.valid_data(d.get_data()),
		"a weapon with a part this game does not have, and one whose line is the wrong length, are left out and said; the sword that was put away is taken up (%s)" % str(problems))
	odd = JSON.parse_string(saved)
	odd["preset_data"][0] = ["nonsense"]
	odd["preset_names"] = ["A name that is far too long for a preset", 7]
	problems = d.from_save(odd)
	_check(problems.size() == 1 and d.weapon() == "bow" and d.preset_data[0] == null and d.preset_names == ["A name that ", "", ""] and d.stowed.size() == 2, "a broken preset is left empty, and said (%s)" % str(problems))
	var e := SwingBuild.new()
	_check(e.from_save("rubbish").size() == 1 and e.get_data() == SwingBuild.STARTERS["sword"] and e.from_save({}).size() == 1 and e.stowed.is_empty(), "and rubbish in place of the weapons gives the plain wooden sword")


# --- What was done to the land ---------------------------------------------------------------

func _land() -> void:
	var m := WorldGen.make(77)
	_check(m.changes() == {"dug": [], "gone": [], "added": []}, "a land nobody has touched has no changes")
	var rock: Array = _face(m, LandMap.ROCK)
	var tin: Array = _face(m, LandMap.TIN)
	var copper: Array = _face(m, LandMap.COPPER)
	var pine := _pine(m)
	_check(not rock.is_empty() and not tin.is_empty() and not copper.is_empty() and not pine.is_empty(), "(world 77 has rock, tin, copper and a pine to work on)")
	var before_seam := m.veins.size()
	for t: Vector2i in [rock[0], tin[0], copper[0], rock[0] + Vector2i(1, 0)]:
		m.dig(t.x, t.y)
	m.remove_thing(pine)
	m.add_thing({"n": "pine_stump", "x": int(pine["x"]), "y": int(pine["y"]), "f": false})
	var boulder := {}
	for t in m.things:
		if Tools.thing_class(t) == "boulder":
			boulder = t
			break
	if not boulder.is_empty():
		m.remove_thing(boulder)
	var ch := m.changes()
	_check((ch["dug"] as Array).size() >= 3 and (ch["gone"] as Array).size() == (2 if not boulder.is_empty() else 1) and (ch["added"] as Array).size() == 1, "digging, felling and breaking are all remembered (%s)" % str(ch).left(160))
	var text := JSON.stringify(ch)
	var n := WorldGen.make(77)
	var odd := n.apply_changes(JSON.parse_string(text))
	_check(odd == 0 and n.kinds == m.kinds and str(n.things) == str(m.things) and JSON.stringify(n.changes()) == text, "the same land with the same changes done to it again is the same land, tile for tile and thing for thing")
	_check(n.veins.size() == before_seam and n.veins.size() == m.veins.size(), "the seams are still the ones the land was made with")
	var same := true
	for i in n.veins.size():
		for p: Vector2i in (n.veins[i]["px"] as Dictionary):
			if n.vein_shows(n.veins[i], p) != m.vein_shows(m.veins[i], p):
				same = false
	_check(same, "and every pixel of ore that was left shows, and every pixel that was mined does not")
	for t: Vector2i in [rock[0], tin[0], copper[0]]:
		_check(_painted(n, t) == _painted(m, t), "the ground at %s is painted the same, pixel for pixel" % str(t))
	var s := n.thing_key(pine)
	_check(n.things.any(func(t): return str(t["n"]) == "pine_stump" and LandMap.thing_key(t) == s) and not n.things.any(func(t): return Tools.thing_class(t) == "pine" and LandMap.thing_key(t) == s),
		"the felled pine is a stump again")
	_check(str(n.things_in(int(pine["x"]) / 256, int(pine["y"]) / 256)) == str(m.things_in(int(pine["x"]) / 256, int(pine["y"]) / 256)), "in the same order, so it is drawn the same")

	# Changes that do not fit are passed over, whatever they are.
	var o := WorldGen.make(77)
	var grass := Vector2i(int(o.spawn.x), int(o.spawn.y))
	var kinds := o.kinds.duplicate()
	var things := str(o.things)
	odd = o.apply_changes({"dug": [grass.y * LandMap.SIZE + grass.x, -5, 99999999, "x", o.mouth.y * LandMap.SIZE + o.mouth.x], "gone": [12345, "y"],
		"added": [{"n": "giant_relic", "x": 100, "y": 100}, {"n": "pine_stump", "x": -50000, "y": 3}, "z", {"n": "pine_stump"}]})
	_check(odd == 11 and o.kinds == kinds and str(o.things) == things, "changes that do not fit the land (open ground, the cave's own hill, things that are not there or cannot be put) change nothing (%d passed over)" % odd)
	_check(o.apply_changes("rubbish") == 0 and o.apply_changes({"dug": "x"}) == 0 and o.kinds == kinds, "and rubbish in place of the changes does nothing")


## The land a number gives must stay the same while WorldGen.GEN stays the same: a world save holds only what was
## changed, so if the land moved under it the old holes would be cut into the wrong places. If this fails because the
## generator was changed on purpose: raise WorldGen.GEN by one, then run this test once with "-- ref".
func _land_made_the_same() -> void:
	var m := WorldGen.make(REF_SEED)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(m.kinds)
	ctx.update(str(m.things).to_utf8_buffer())
	ctx.update(str([m.region, m.mouth, m.spawn]).to_utf8_buffer())
	var mark := ctx.finish().hex_encode().left(16)
	if write_ref:
		var f := FileAccess.open(REF, FileAccess.WRITE)
		f.store_string(JSON.stringify({"gen": WorldGen.GEN, "seed": REF_SEED, "land": mark}, "\t") + "\n")
		f.close()
		print("wrote %s: land %s for GEN %d" % [REF, mark, WorldGen.GEN])
	var ref = JSON.parse_string(_text(REF))
	_check(ref is Dictionary and int(ref.get("seed", 0)) == REF_SEED, "the land's fingerprint is on file (tests/saving_land_ref.json; write it with \"-- ref\")")
	if not (ref is Dictionary):
		return
	_check(int(ref.get("gen", 0)) == WorldGen.GEN, "the fingerprint on file is this making of the land (GEN %d; after raising WorldGen.GEN run this test with \"-- ref\")" % WorldGen.GEN)
	_check(str(ref.get("land", "")) == mark or int(ref.get("gen", 0)) != WorldGen.GEN,
		"world %d is still made as it was when GEN became %d. If the generator was changed on purpose, RAISE WorldGen.GEN (old worlds are then laid out again) and run with \"-- ref\"" % [REF_SEED, WorldGen.GEN])


# --- Playing, leaving and coming back --------------------------------------------------------

func _play() -> void:
	_fresh_folder(ROOT)
	var who := Save.fresh(C)
	var where := Save.fresh(W)
	where["seed"] = 77
	var g = _game([who], where)
	await _frames(5)
	_check(g.new_world and not g.relaid and g.world_seed == 77, "a new world is laid out from its number")
	_check(FileAccess.file_exists(Save.path(C, "character_1")) and FileAccess.file_exists(Save.path(W, "world_1")) and g.saves_written == 2,
		"a new character and a new world are on the disk as soon as the game starts (%d files written)" % g.saves_written)
	var on_disk := Save.read(W, "world_1")
	_check(int(on_disk.get("seed", 0)) == 77 and int(on_disk.get("land", 0)) == WorldGen.GEN and (on_disk.get("dug") as Array).is_empty(), "the world's file holds its number, which making of the land it is, and no changes yet")
	_check(g.swaps == [true] and g.can_swap and g.builds[0].stowed.size() == 3 and g.owned[0] == null, "a new character carries the four test weapons")
	var p = g.players[0]
	var m: LandMap = g.map
	_check(p.global_position.distance_to(m.spawn * TILE) < 80.0, "and stands outside the cave mouth")

	# Dig rock, mine tin, fell a pine, with the tools themselves.
	var rock: Array = _face(m, LandMap.ROCK)
	await _stand(g, p, rock[0], rock[1])
	await _work(p, 3)
	var tin: Array = _face(m, LandMap.TIN)
	await _stand(g, p, tin[0], tin[1])
	await _work(p, 4)
	var pine := _pine(m)
	var pine_key := LandMap.thing_key(pine)
	await _press(p, "tool_next_pressed")
	p.global_position = _beside(pine)
	p.input.stick_aim = Vector2.RIGHT
	g.rig.snap()
	await _frames(4)
	g.land.settle()
	await _work(p, 5)
	await _frames(90)
	var bag: Bag = g.tools.hands[0].bag
	_check(m.kind(rock[0].x, rock[0].y) == LandMap.FLOOR and m.kind(tin[0].x, tin[0].y) == LandMap.FLOOR and bag.count("stone") == 1 and bag.count("tin_ore") == 2 and bag.count("wood") == 3 and g.tools.hands[0].tool == 1,
		"(dug a rock, mined tin, felled a pine: %s, the axe in hand)" % str(bag.data()))
	g.swap_weapon(0, "hammer")
	g.builds[0].preset_names[0] = "Mine"
	await _frames(2)
	_check(g.builds[0].weapon() == "hammer", "(and took up the hammer)")

	# Saving.
	var before: int = g.saves_written
	_check(g.save_now() and g.saves_written == before + 2 and g.save_note > 0.0 and g.save_word == "Saved", "saving writes the world and the character, and the screen says \"Saved\"")
	_check(g.save_now() and g.saves_written == before + 2, "saving again with nothing changed writes nothing (the backup is not pushed out by a copy)")
	bag.add("stone", 1)
	_check(g.save_now() and g.saves_written == before + 3 and _text(Save.path(W, "world_1") + ".bak") != "" and _text(Save.path(C, "character_1") + ".bak") != "", "after picking up one stone only the character is written; both have a backup now")
	bag.add("potion", 2)
	await _frames(2)
	_check(g.tools.put_on(0, "potion", 5) == 5 and g.save_now(), "(two potions, on the hotbar's slot 6)")
	var state := _state(g)
	var kinds: PackedByteArray = m.kinds.duplicate()
	var ground: Array = [_painted(m, rock[0]), _painted(m, tin[0])]
	var seconds := float(g.world_save.get("seconds", 0.0))
	_check(seconds > 1.0 and float(g.characters[0].get("seconds", 0.0)) > 1.0, "the time played is counted (%.1f s)" % seconds)
	await _leave(g)
	_check(not is_instance_valid(g), "(left the world)")

	# Coming back: the same character in the same world.
	var c := Save.read(C, "character_1")
	var w := Save.read(W, "world_1")
	_check(not c.has("restored") and not w.has("restored") and str(c.get("world", "")) == "world_1" and (w["dug"] as Array).size() == 2 and (w["gone"] as Array).size() == 1 and (w["added"] as Array).size() == 1,
		"the files hold two dug tiles, a pine gone and a stump put there, and the world the character was last in")
	g = _game([c], w)
	await _frames(5)
	_check(not g.new_world and not g.relaid and g.world_seed == 77 and g.map.kinds == kinds, "the world comes back tile for tile")
	var again := _state(g)
	for key in state:
		_check(again[key] == state[key], "and so does %s (%s)" % [{"things": "everything that stands on it", "changes": "what was changed", "bag": "the bag", "belt": "the tool belt",
			"tool": "the tool that was picked", "hotbar": "the hotbar", "weapons": "every weapon and preset", "weapon": "the weapon in the hand", "owned": "what can be used at the forge"}[key], str(again[key]).left(60)])
	_check(_painted(g.map, rock[0]) == ground[0] and _painted(g.map, tin[0]) == ground[1], "the dug ground is painted the same, pixel for pixel")
	_check(not g.map.things.any(func(t): return Tools.thing_class(t) == "pine" and LandMap.thing_key(t) == pine_key) and g.map.things.any(func(t): return str(t["n"]) == "pine_stump" and LandMap.thing_key(t) == pine_key),
		"the felled pine is still a stump")
	_check(g.players[0].global_position.distance_to(g.map.spawn * TILE) < 80.0, "you arrive at the cave mouth")
	_check(g.builds[0].weapon() == "hammer" and g.swaps == [true] and g.builds[0].preset_names[0] == "Mine", "with the hammer in your hand, and its preset's name")
	_check(g.saves_written == 0, "reading a save does not write it again")
	_check(g.tools.hands[0].bag.count("stone") == 2, "(two stone in the bag)")
	_check(float(g.world_save.get("seconds", 0.0)) >= seconds - 1.0, "and the time played goes on from where it was")
	await _leave(g)
	_check(float(Save.read(W, "world_1").get("played", 0.0)) > 0.0, "(left again)")

	# The same character in a second world, and back in the first.
	c = Save.read(C, "character_1")
	var other := Save.fresh(W)
	other["seed"] = 78
	g = _game([c], other)
	await _frames(5)
	_check(str(other["id"]) == "world_2" and g.map.changes() == {"dug": [], "gone": [], "added": []} and g.map.kinds != kinds, "a second world is another land, untouched")
	_check(_state(g)["bag"] == again["bag"] and _state(g)["weapons"] == again["weapons"] and _state(g)["belt"] == again["belt"] and g.tools.hands[0].tool == 1,
		"the character walks into it with the same bag, weapons and tools")
	var there: Array = _face(g.map, LandMap.COPPER)
	g.tools.hands[0].tool = 0
	await _stand(g, g.players[0], there[0], there[1])
	await _work(g.players[0], 4)
	await _frames(70)
	_check(g.tools.hands[0].bag.count("copper_ore") == 2, "(mined copper there)")
	await _leave(g)
	_check((Save.read(W, "world_2")["dug"] as Array).size() == 1 and _text(Save.path(W, "world_1")).contains("\"dug\"") and (Save.read(W, "world_1")["dug"] as Array).size() == 2, "each world keeps its own changes")
	c = Save.read(C, "character_1")
	_check(str(c.get("world", "")) == "world_2", "the character remembers the world it was last in")
	g = _game([c], Save.read(W, "world_1"))
	await _frames(5)
	_check(g.map.kinds == kinds and g.tools.hands[0].bag.count("copper_ore") == 2 and g.tools.hands[0].bag.count("stone") == 2, "back in the first world, it is as it was left, and the copper from the second is in the bag")
	await _leave(g)


func _other_ways_to_save() -> void:
	var g = _game([Save.read(C, "character_1")], Save.read(W, "world_1"))
	await _frames(5)
	var bag: Bag = g.tools.hands[0].bag
	var n: int = g.saves_written

	# By itself, every so often.
	bag.add("wood", 1)
	g.save_clock = Highlands.AUTOSAVE - 0.2
	await _frames(30)
	await process_frame
	_check(g.saves_written == n + 1 and g.save_clock < 1.0 and g.note_panel.visible, "the game saves by itself every %d seconds, and says so" % int(Highlands.AUTOSAVE))
	g.save_clock = Highlands.AUTOSAVE - 0.2
	await _frames(30)
	_check(g.saves_written == n + 1, "and writes nothing when nothing has changed")
	_check(Highlands.AUTOSAVE >= 60.0 and Highlands.AUTOSAVE <= 300.0, "(every few minutes: %d s)" % int(Highlands.AUTOSAVE))

	# When the pause menu opens.
	bag.add("wood", 1)
	g.pause_menu.open()
	_check(g.saves_written == n + 2 and paused, "opening the pause menu saves")
	g.pause_menu.resume()
	await _frames(2)

	# When the forge screen closes.
	g.builds[0].preset_names[1] = "Forge"
	g._forge_done(0)
	_check(g.saves_written == n + 3 and Save.read(C, "character_1")["weapons"]["preset_names"][1] == "Forge", "closing the forge saves what was changed there")

	# Leaving writes the clock too (how long it has been played), unless the save was written a moment ago.
	var id := "world_1"
	var was := float(Save.read(W, id).get("seconds", 0.0))
	_check(g.save_now(true) and g.saves_written == n + 4 and float(Save.read(W, id).get("seconds", 0.0)) > was, "leaving writes how long the world has been played, though nothing in it changed")
	_check(g.save_now(true) and g.saves_written == n + 4, "leaving a moment after a save writes nothing more")
	g._saved_at[id] = Time.get_unix_time_from_system() - Highlands.SAVE_APART - 1.0
	_check(g.save_now(true) and g.saves_written == n + 5, "and later it does again")

	# "Quit game" in the pause menu, and the window being closed.
	bag.add("wood", 1)
	g.pause_menu.quitting.emit()
	_check(g.saves_written == n + 6, "\"Quit game\" saves before the game closes")
	bag.add("wood", 1)
	g.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(g.saves_written == n + 7, "closing the window saves")
	await _leave(g)

	# Somebody who is not saved (the tests, and "-- highlands") writes nothing at all.
	var files := Save.ids(C).size() + Save.ids(W).size()
	g = _game([], {}, {}, 77)
	await _frames(5)
	var t: Array = _face(g.map, LandMap.ROCK)
	g.map.dig(t[0].x, t[0].y)
	_check(g.save_now() and g.save_now(true) and g.saves_written == 0, "a game started without saves saves nothing")
	g.save_clock = Highlands.AUTOSAVE + 1.0
	await _frames(5)
	await _leave(g)
	_check(Save.ids(C).size() + Save.ids(W).size() == files, "and leaves no files")

	# A disk that will not take the save: the old one is kept, and the screen says so.
	g = _game([Save.read(C, "character_1")], Save.read(W, "world_1"))
	await _frames(5)
	var good := _text(Save.path(C, "character_1"))
	g.tools.hands[0].bag.add("stone", 1)
	DirAccess.make_dir_recursive_absolute(Save.path(C, "character_1") + ".tmp")      # something in the way of the new file
	var ok: bool = g.save_now()
	DirAccess.remove_absolute(Save.path(C, "character_1") + ".tmp")
	_check(not ok and g.save_failed and g.save_note > 0.0 and _text(Save.path(C, "character_1")) == good, "when a save cannot be written the screen says so, and the save that was there is untouched (\"%s\")" % g.save_word)
	_check(g.save_now() and not g.save_failed and _text(Save.path(C, "character_1")) != good, "and the next save that works writes it")
	await _leave(g)


func _old_and_broken() -> void:
	# A damaged world file: its backup is played.
	var whole := Save.read(W, "world_1")
	_spoil(Save.path(W, "world_1"))
	var w := Save.read(W, "world_1")
	_check(w.get("restored", false) and (w["dug"] as Array).size() == 2, "a damaged world is read from its backup")
	var g = _game([Save.read(C, "character_1")], w)
	await _frames(5)
	_check(not g.relaid and (g.map.changes()["dug"] as Array).size() == 2, "and can be played")
	await _leave(g)
	_check(not Save.read(W, "world_1").has("restored") and (Save.read(W, "world_1")["dug"] as Array).size() == 2, "after which its save is whole again")
	whole = whole

	# A world saved on a land that is made differently now.
	var old := Save.read(W, "world_1")
	old["land"] = WorldGen.GEN - 1
	_check(SavePick.older_land(old) and SavePick.world_words(old).contains("laid out again") and not SavePick.older_land(Save.read(W, "world_2")), "a world from an older making of the land says so on the pick screen")
	g = _game([Save.read(C, "character_1")], old)
	await _frames(5)
	_check(g.relaid and not g.new_world and g.map.changes() == {"dug": [], "gone": [], "added": []} and g.world_seed == 77, "it is laid out again from its number, without the old changes")
	_check(g.tools.hands[0].bag.count("copper_ore") == 2, "and the character has kept everything")
	await _leave(g)
	var now := Save.read(W, "world_1")
	_check(int(now["land"]) == WorldGen.GEN and (now["dug"] as Array).is_empty() and not _text(Save.path(W, "world_1")).contains("relaid"), "its save is this making of the land from then on")

	# A character with a weapon this game does not have.
	var c := Save.read(C, "character_1")
	c["weapons"]["hand"][0] = "maul_from_a_later_version"
	g = _game([c], Save.read(W, "world_2"))
	await _frames(5)
	_check(g.unreadable.size() == 1 and g.builds[0].weapon() == "sword" and SwingBuild.valid_data(g.builds[0].get_data()) and g.save_note > 0.0 and g.save_failed,
		"a weapon that cannot be read is left out, the next one is in the hand, and the screen says so (\"%s\")" % g.save_word)
	_check(not g.builds[0].stowed.has("sword") and not g.builds[0].stowed.has("hammer") and g.builds[0].stowed.has("bow") and g.builds[0].stowed.has("staff"), "the weapons that can be read are still there")
	await _leave(g)

	# Tools this game does not have, and a bag that is too full.
	c = Save.read(C, "character_1")
	c["belt"] = {"pickaxe": "starmetal", "axe": "", "mallet": "basic"}
	c["tool"] = 1
	c["bag"] = [["stone", 5000], ["wood", -2], "rubbish"]
	g = _game([c], Save.read(W, "world_2"))
	await _frames(5)
	var h = g.tools.hands[0]
	_check(h.belt == {"pickaxe": "basic", "axe": "", "mallet": "basic"} and h.tool == 0 and h.bag.count("stone") == 99 and h.bag.slots.size() == 1, "a make of tool this game does not have is the basic one, a tool that is not on the belt is not picked, and the bag cannot be overfilled")
	await _leave(g)


func _two_players() -> void:
	_fresh_folder(ROOT)
	# Player one came up from the cave with the hammer they built; player two is new.
	var a := Save.fresh(C)
	var b := Save.fresh(C, [a["id"]])
	var w := Save.fresh(W)
	w["seed"] = 77
	var built := ["wooden_maul", "wooden_haft", "plain_weight", ["quake"]]
	var carry := {"builds": [built], "owned": [["wooden_maul", "wooden_haft", "plain_weight", "quake"]], "spirit": [true]}
	var g = _game([a, b], w, carry)
	await _frames(5)
	_check(g.players.size() == 2 and g.swaps == [false, true] and g.can_swap, "two players: the one from the cave has what they built, the new one the four test weapons")
	_check(g.builds[0].get_data() == built and g.owned[0] == carry["owned"][0] and g.owned[1] == null, "(the cave's hammer and its parts)")
	g.swap_weapon(0)
	g.swap_weapon(1, "staff")
	_check(g.builds[0].weapon() == "hammer" and g.builds[1].weapon() == "staff", "only the one with four weapons swaps between them")
	g.tools.hands[0].bag.add("stone", 4)
	g.tools.hands[1].bag.add("wood", 6)
	g.tools.hands[1].tool = 2
	await _leave(g)
	var ca := Save.read(C, "character_1")
	var cb := Save.read(C, "character_2")
	_check(ca["weapons"]["hand"] == built and ca["swap"] == false and ca["owned"] == carry["owned"][0] and JSON.stringify(ca["bag"]).contains("stone") and not JSON.stringify(ca["bag"]).contains("wood"),
		"each player's character is its own file: player one's has the hammer, its parts and the stone")
	_check(cb["swap"] == true and cb["owned"] == null and JSON.stringify(cb["bag"]).contains("wood") and int(cb["tool"]) == 2 and SwingBuild.weapon_of(cb["weapons"]["hand"][0]) == "staff",
		"player two's has the four weapons, the wood and the mallet picked")
	# The other way round next time: whoever picks a character plays it.
	g = _game([cb, ca], Save.read(W, "world_1"))
	await _frames(5)
	_check(g.swaps == [true, false] and g.builds[1].get_data() == built and g.owned[1] == carry["owned"][0] and g.tools.hands[0].bag.count("wood") == 6 and g.tools.hands[1].bag.count("stone") == 4 and g.tools.hands[0].tool == 2,
		"the characters can change hands: each brings its own weapons, parts, tools and bag")
	_check(g.players[1].with_spirit, "(and its forge spirit)")
	await _leave(g)

	# One saved player and one who is not (it cannot happen from the screens, but must not break).
	g = _game([Save.read(C, "character_1"), {}], Save.read(W, "world_1"))
	await _frames(5)
	g.tools.hands[1].bag.add("tin_ore", 3)
	_check(g.save_now(true) and g.swaps == [false, true] and Save.ids(C).size() == 2, "a player without a save plays, and nothing is written for them")
	await _leave(g)


# --- The pick screen -------------------------------------------------------------------------

func _pick(inputs: Array) -> SavePick:
	var s := SavePick.new()
	s.inputs = inputs
	root.add_child(s)
	return s


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _button(device: int, index: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = index
	e.pressed = true
	return e


func _pick_screen() -> void:
	_fresh_folder(ROOT)
	var got: Array = []
	var backs := [0]

	# The first time: nothing to pick but "new".
	var s := _pick([PlayerInput.make("any")])
	s.chosen.connect(func(cs: Array, w: Dictionary): got.append([cs, w]))
	s.back.connect(func(): backs[0] += 1)
	await _frames(2)
	_check(s.count == 1 and s.step == 0 and s.characters.is_empty() and s.cursor == [0], "with no saves the screen offers a new character")
	s._input(_key(KEY_ENTER))
	_check(s.step == 1 and s.world_cursor == 0, "Enter makes one and goes on to the worlds")
	s._input(_button(0, JOY_BUTTON_A))
	await _frames(30)
	_check(got.size() == 1 and got[0][0].size() == 1 and got[0][0][0]["id"] == "character_1" and got[0][0][0].get("unsaved", false) and got[0][1]["id"] == "world_1" and got[0][1].get("unsaved", false),
		"A makes a new world: the game starts with Character 1 in World 1")
	_check(Save.ids(C).is_empty() and Save.ids(W).is_empty(), "the screen itself writes nothing")
	s.queue_free()

	# With saves.
	for i in 3:
		var c := Save.fresh(C)
		c["played"] = 1000.0 * float(i + 1)
		c["world"] = "world_1"
		c["bag"] = [["stone", 5 + i]]
		Save.write(C, c)
	for i in 3:
		var w := Save.fresh(W)
		w["played"] = 1000.0 * float(3 - i)
		w["seed"] = 500000 + i
		w["land"] = WorldGen.GEN
		w["dug"] = [1, 2, 3]
		w["added"] = []
		Save.write(W, w)
	s = _pick([PlayerInput.make("kbm"), PlayerInput.make("pad", 1)])
	s.chosen.connect(func(cs: Array, w: Dictionary): got.append([cs, w]))
	s.back.connect(func(): backs[0] += 1)
	await _frames(2)
	_check(s.count == 2 and s.characters.map(func(c): return c["id"]) == ["character_3", "character_2", "character_1"] and s.cursor == [0, 1], "the characters are listed newest first; player one starts on the newest, player two on the next")
	_check(s.player_of(_key(KEY_S)) == 0 and s.player_of(_button(1, JOY_BUTTON_A)) == 1 and s.player_of(_button(0, JOY_BUTTON_A)) == -1, "each player has their own controls, and a controller that did not join does nothing")
	_check(SavePick.bag_counts(s.characters[0]) == [["stone", 7]] and SavePick.weapon_words(s.characters[0]) == "Sword" and SavePick.world_words(s.worlds[0]).contains("3 dug"), "a row says what the save holds")
	s._input(_button(0, JOY_BUTTON_A))
	_check(s.locked == [false, false], "(a controller that did not join picks nothing)")
	s._input(_key(KEY_ENTER))
	_check(s.locked == [true, false] and s.step == 0, "player one picks; the screen waits for player two")
	s._input(_key(KEY_S))
	_check(s.cursor[0] == 0, "(a player who has picked does not move)")
	s._input(_button(1, JOY_BUTTON_DPAD_UP))
	_check(s.cursor[1] == 0 and s.taken_by(0, 1) == 0, "player two moves onto the character player one picked")
	s._input(_button(1, JOY_BUTTON_A))
	_check(s.locked == [true, false], "and cannot pick it")
	s._input(_button(1, JOY_BUTTON_X))
	_check(s.asking.is_empty(), "nor delete it")
	s._input(_key(KEY_BACKSPACE))
	_check(s.locked == [false, false] and backs[0] == 0, "Backspace takes a pick back")
	s._input(_key(KEY_ENTER))
	s._input(_button(1, JOY_BUTTON_DPAD_UP))
	s._input(_button(1, JOY_BUTTON_A))
	_check(s.cursor[1] == 3 and s.step == 1, "player two makes a new character; both have picked, on to the worlds")
	_check(s.worlds.map(func(w): return w["id"]) == ["world_1", "world_2", "world_3"] and s.world_cursor == 0, "the worlds are listed newest first, starting on the one player one's character was last in")
	s._input(_button(1, JOY_BUTTON_DPAD_DOWN))
	s._input(_key(KEY_S))
	_check(s.world_cursor == 2, "anybody moves through the worlds")
	s._input(_button(1, JOY_BUTTON_B))
	_check(s.step == 0 and s.locked == [false, false], "B goes back to the characters")
	s._input(_key(KEY_ENTER))
	s._input(_button(1, JOY_BUTTON_A))
	s._input(_key(KEY_W))
	s._input(_key(KEY_W))
	_check(s.step == 1 and s.world_cursor == 2, "(up from the first world goes round to \"New world\", and on to the last)")
	s._input(_key(KEY_ENTER))
	await _frames(30)
	_check(got.size() == 2 and got[1][0][0]["id"] == "character_3" and got[1][0][1]["id"] == "character_4" and got[1][0][1].get("unsaved", false) and got[1][1]["id"] == "world_3",
		"the game starts with what was picked: Character 3, a new Character 4, World 3")
	s.queue_free()

	# Two new characters at once, deleting, and leaving.
	s = _pick([PlayerInput.make("kbm"), PlayerInput.make("pad", 0)])
	s.back.connect(func(): backs[0] += 1)
	await _frames(2)
	s.cursor = [3, 3]
	var two := s.picked_characters()
	_check(two[0]["id"] == "character_4" and two[1]["id"] == "character_5", "two players who both make a new character get one each (%s, %s)" % [two[0]["id"], two[1]["id"]])
	s.cursor = [1, 2]
	s._input(_key(KEY_DELETE))
	_check(s.asking.get("id") == "character_2", "Delete asks first")
	s._input(_key(KEY_S))
	_check(s.cursor[0] == 1, "(nothing else moves while it asks)")
	s._input(_key(KEY_BACKSPACE))
	_check(s.asking.is_empty() and Save.ids(C).size() == 3 and backs[0] == 0, "Backspace keeps the save")
	s._input(_key(KEY_DELETE))
	s._input(_key(KEY_ENTER))
	_check(s.asking.is_empty() and s.characters.map(func(c): return c["id"]) == ["character_3", "character_1"] and FileAccess.file_exists(ROOT + "/deleted/character_2.json"),
		"Enter deletes it: it leaves the list and is moved to saves/deleted")
	_check(s.cursor == [1, 1] and s.characters[s.cursor[1]]["id"] == "character_1", "player two is still on the character they were on")
	s.locked = [true, true]
	s.step = 1
	s.world_cursor = 1
	s._input(_button(0, JOY_BUTTON_X))
	s._input(_button(0, JOY_BUTTON_A))
	_check(s.worlds.map(func(w): return w["id"]) == ["world_1", "world_3"] and FileAccess.file_exists(ROOT + "/deleted/world_2.json") and s.world_cursor == 1, "a world is deleted the same way")
	_check(Save.fresh(W)["id"] == "world_4" and Save.fresh(C)["id"] == "character_4", "and the names of deleted saves are not given again")
	s.step = 0
	s.locked = [false, false]
	s._input(_key(KEY_ESCAPE))
	_check(backs[0] == 1, "Backspace or Escape with nothing picked goes back to the title")
	s.queue_free()

	# A save from a newer game cannot be picked.
	var raw: Dictionary = JSON.parse_string(_text(Save.path(W, "world_1")))
	raw["format"] = Save.FORMAT + 1
	var f := FileAccess.open(Save.path(W, "world_1"), FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	s = _pick([])
	s.chosen.connect(func(cs: Array, w: Dictionary): got.append([cs, w]))
	await _frames(2)
	s.confirm(0)
	_check(s.step == 1 and s.worlds[s.world_cursor].get("newer", false), "(on a world saved by a newer game)")
	s.confirm(0)
	await _frames(30)
	_check(got.size() == 2 and s.leaving.is_empty() and SavePick.world_words(s.worlds[s.world_cursor]).contains("newer"), "a world saved by a newer game cannot be opened, and its row says why")
	_check(SavePick.window(0, 9, 6, 12) == 4 and SavePick.window(4, 2, 6, 12) == 2 and SavePick.window(3, 3, 6, 4) == 0, "a long list scrolls to keep the row you are on in sight")
	s.queue_free()
	await _frames(2)


# --- From the title screen and from the cave -------------------------------------------------

func _front_door() -> void:
	_fresh_folder(ROOT)
	var boot = Boot.new()
	root.add_child(boot)
	await _frames(3)
	_check(is_instance_valid(boot.title) and boot.game == null, "(the title screen)")
	var row := ""
	for item in boot.title.ITEMS:
		if item[0] == "highlands":
			row = str(item[2])
	_check(row.contains("character") and row.contains("world") and row.contains("saved"), "the title's Highlands row says a character and a world are picked and saved (\"%s\")" % row)
	boot._chosen("highlands", [PlayerInput.make("any")])
	await _frames(3)
	_check(is_instance_valid(boot.pick) and not is_instance_valid(boot.title) and boot.game == null, "Highlands on the title screen opens the pick screen")
	boot.pick.go_back(0)
	await _frames(3)
	_check(is_instance_valid(boot.title) and not is_instance_valid(boot.pick), "going back from it returns to the title")
	boot._chosen("highlands", [PlayerInput.make("any")])
	await _frames(3)
	boot.pick.confirm(0)
	boot.pick.confirm(0)
	await _frames(40)
	_check(boot.game is Highlands and not is_instance_valid(boot.pick) and boot.game.world_save.get("id") == "world_1" and boot.game.characters.size() == 1 and FileAccess.file_exists(Save.path(C, "character_1")) and FileAccess.file_exists(Save.path(W, "world_1")),
		"picking a new character and a new world starts the Highlands with both saved")
	boot.game.tools.hands[0].bag.add("stone", 2)
	boot._show_title()
	await _frames(4)
	_check(is_instance_valid(boot.title) and JSON.stringify(Save.read(C, "character_1")["bag"]).contains("stone"), "going back to the title saves")

	# Up the cave's stairs.
	var built := ["wooden_shortbow", "wooden_bow_grip", "plain_string", ["volley"], "wooden_arrows"]
	boot.last_inputs = [PlayerInput.make("script")]
	boot._out_of_cave({"builds": [built], "owned": [["wooden_shortbow", "wooden_bow_grip", "plain_string", "wooden_arrows", "volley"]], "spirit": [true]})
	await _frames(40)
	_check(boot.game is Highlands and boot.game.characters[0].get("id") == "character_2" and boot.game.world_save.get("id") == "world_2" and boot.game.builds[0].get_data() == built and boot.game.swaps == [false],
		"climbing out of the cave makes a new character with the bow that was built there, in a new world")
	var c := Save.read(C, "character_2")
	_check(c.get("weapons", {}).get("hand") == built and (c.get("owned") as Array).has("volley") and c.get("world") == "world_2" and int(Save.read(W, "world_2").get("seed", 0)) == boot.game.world_seed,
		"and both are saved at once")
	boot._chosen("arena", [PlayerInput.make("script")])
	await _frames(5)
	_check(boot.game is Arena and Save.ids(C).size() == 2, "the arena is as it was, and saves nothing")
	boot.queue_free()
	await _frames(3)
	paused = false


# --- The game closing ------------------------------------------------------------------------

## The real thing: another copy of the game digs a tile and then closes, and this one reads what it left.
func _closing_the_game() -> void:
	for way in ["quit_menu", "plain_quit"]:
		var folder: String = "user://test_saves_closing_" + str(way)
		_fresh_folder(folder)
		Save.root = ROOT
		var out: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--fixed-fps", "60", "-s", "tests/saving.gd", "--", "phase=" + way], out, true)
		Save.root = folder
		var c := Save.read(C, "character_1")
		var w := Save.read(W, "world_1")
		var words := "\"Quit game\" in the pause menu" if way == "quit_menu" else "the game simply closing"
		_check(code == 0 and not w.is_empty() and w.get("dug") is Array and (w["dug"] as Array).size() == 1 and JSON.stringify(c.get("bag")).contains("stone"),
			"%s: what was dug a moment before, and the stone from it, are in the saves (%s)" % [words, str(w.get("dug", "no world save")).left(40)])
		Save.root = ROOT


func _quit_phase() -> void:
	Save.root = "user://test_saves_closing_" + phase
	var c := Save.fresh(C)
	var w := Save.fresh(W)
	w["seed"] = 77
	var g = _game([c], w)
	await _frames(5)
	if phase == "quit_menu":
		g.pause_menu.open()
	var t: Array = _face(g.map, LandMap.ROCK)
	g.map.dig(t[0].x, t[0].y)
	g.tools.hands[0].bag.add("stone", 1)
	if phase == "quit_menu":
		g.pause_menu._quit()
	else:
		quit()


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
	_fresh_folder("user://test_saves_shots")

	# The first time anybody plays.
	var s := _pick([PlayerInput.make("any")])
	await _frames(30)
	await _snap("pick_1_first_time")
	s.confirm(0)
	await _frames(4)
	await _snap("pick_2_first_world")
	s.queue_free()
	await _frames(2)

	# Play: a new character in a new world; dig a tunnel along a seam, fell a pine; the word "Saved".
	var who := Save.fresh(C)
	var where := Save.fresh(W)
	where["seed"] = 1
	var g = _game([who], where)
	g.ui.card("The Greystone Highlands", g.welcome_text())
	await _frames(40)
	await _snap("play_1_arrival_card")
	g.ui.advance(true, 0.1)
	await _frames(30)
	g.ui.advance(true, 0.1)
	await _frames(30)
	var p = g.players[0]
	var m: LandMap = g.map
	var spot: Array = []
	for skip in 60:
		var f: Array = _face(m, LandMap.TIN, skip)
		if not f.is_empty() and f[1] == Vector2.RIGHT and m.is_rock(f[0].x + 1, f[0].y) and m.is_rock(f[0].x + 2, f[0].y) and m.is_rock(f[0].x + 3, f[0].y):
			spot = f
			break
	if spot.is_empty():
		spot = _face(m, LandMap.TIN)
	var step := Vector2i(int(spot[1].x), int(spot[1].y))
	var next: Vector2i = spot[0]
	for n in 4:
		if m.is_rock(next.x, next.y) and not m.fixed(next.x, next.y):
			await _stand(g, p, next, spot[1])
			await _work(p, 4)
		next += step
	await _frames(60)
	# Stand back out of the tunnel, so it can be seen.
	var view: Vector2 = (Vector2(spot[0]) + Vector2(0.5, 0.5) - spot[1] * 1.6) * TILE
	p.global_position = view
	p.input.stick_aim = spot[1]
	g.rig.snap()
	await _frames(10)
	g.land.settle()
	g.tools.hands[0].bag.add("stone", 1)
	g.save_now()
	await _frames(12)
	await _snap("play_2_saved_word")
	await _frames(150)
	await _snap("play_3_tunnel_before_leaving")
	var pine := _pine(m)
	var pine_view := Vector2.ZERO
	if not pine.is_empty():
		await _press(p, "tool_next_pressed")
		pine_view = _beside(pine)
		p.global_position = pine_view
		p.input.stick_aim = Vector2.RIGHT
		g.rig.snap()
		await _frames(6)
		g.land.settle()
		await _snap("play_3a_pine_standing")
		await _work(p, 5)
		await _frames(150)
		await _snap("play_3b_pine_felled_before_leaving")
	g.world_save["seconds"] = 1560.0
	g.characters[0]["seconds"] = 1560.0
	g._saved_at.clear()
	await _leave(g)

	# Coming back.
	g = _game([Save.read(C, "character_1")], Save.read(W, "world_1"))
	await _frames(20)
	await _snap("play_4_back_at_the_cave_mouth")
	p = g.players[0]
	p.global_position = view
	p.input.stick_aim = spot[1]
	g.rig.snap()
	await _frames(20)
	g.land.settle()
	await _frames(10)
	await _snap("play_5_tunnel_after_coming_back")
	if not pine.is_empty():
		p.global_position = pine_view
		p.input.stick_aim = Vector2.RIGHT
		g.rig.snap()
		await _frames(20)
		g.land.settle()
		await _frames(10)
		await _snap("play_5b_pine_after_coming_back")
	await _leave(g)

	# The same character in a second world.
	var second := Save.fresh(W)
	second["seed"] = 2
	g = _game([Save.read(C, "character_1")], second)
	g.ui.card("The Greystone Highlands", g.welcome_text())
	await _frames(40)
	g.ui.advance(true, 0.1)
	await _frames(30)
	g.ui.advance(true, 0.1)
	await _frames(40)
	await _snap("play_6_same_character_second_world")
	g.world_save["seconds"] = 200.0
	g._saved_at.clear()
	await _leave(g)

	# More saves, so the lists have something in them: a character from the cave, a world from an older land.
	var cave := Save.fresh(C)
	var b := SwingBuild.new()
	b.set_data(["wooden_shortbow", "wooden_bow_grip", "plain_string", ["volley"], "wooden_arrows"])
	cave["weapons"] = b.to_save()
	cave["swap"] = false
	cave["owned"] = ["wooden_shortbow", "wooden_bow_grip", "plain_string", "wooden_arrows", "volley"]
	cave["bag"] = [["stone", 41], ["wood", 12]]
	cave["played"] = Time.get_unix_time_from_system() - 86400.0 * 1.0 - 3000.0
	cave["seconds"] = 4000.0
	Save.write(C, cave)
	var old := Save.fresh(W)
	old["seed"] = 345678
	old["land"] = WorldGen.GEN - 1
	old["dug"] = [5, 6, 7]
	old["played"] = Time.get_unix_time_from_system() - 86400.0 * 9.0
	old["seconds"] = 7000.0
	Save.write(W, old)

	s = _pick([PlayerInput.make("any")])
	await _frames(30)
	await _snap("pick_3_characters")
	s.confirm(0)
	await _frames(4)
	await _snap("pick_4_worlds")
	s.move(0, 1)
	s.move(0, 1)
	await _frames(4)
	await _snap("pick_5_world_from_an_older_land")
	s.move(0, -1)
	s.ask_delete(0)
	await _frames(4)
	await _snap("pick_6_delete_asks_first")
	s.queue_free()
	await _frames(2)

	s = _pick([PlayerInput.make("kbm"), PlayerInput.make("pad", 0)])
	await _frames(30)
	await _snap("pick_7_two_players")
	s.confirm(0)
	s.move(1, -1)
	await _frames(4)
	await _snap("pick_8_two_players_one_ready")
	s.queue_free()
	await _frames(2)

	# The whole way in, with real key presses: the title, the Highlands row, a character, a world, the land.
	var boot = Boot.new()
	root.add_child(boot)
	await _frames(60)
	await _tap(KEY_ENTER)
	await _tap(KEY_S)
	await _tap(KEY_S)
	await _frames(20)
	await _snap("way_in_1_title")
	await _tap(KEY_ENTER)
	await _frames(50)
	await _snap("way_in_2_characters")
	await _tap(KEY_ENTER)
	await _frames(10)
	await _snap("way_in_3_worlds")
	await _tap(KEY_S)
	await _tap(KEY_ENTER)
	await _frames(150)
	await _snap("way_in_4_the_land")
	print("the way in: %s, world %s, character %s" % ["the Highlands" if boot.game is Highlands else "NOT the Highlands", str(boot.game.world_save.get("id")) if boot.game is Highlands else "",
		str(boot.game.characters[0].get("id")) if boot.game is Highlands else ""])
	boot.queue_free()
	await _frames(3)


func _tap(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(3)
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(3)
