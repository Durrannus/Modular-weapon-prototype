extends SceneTree
## The Greystone Highlands map (version 35): the generator's rules, the painter
## and walking about on it. Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands.gd [-- seeds=30]
##
## With shots=/some/folder/ (needs a window, so leave out --headless) it also saves
## 640x360 screenshots of one world: the base, an ordinary screen, an open place, a
## dug tunnel, the two named places. "seed=123456" picks the world.

const PlayerInput := preload("res://scripts/player_input.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const Title := preload("res://scripts/ui/title.gd")
const TILE := 32.0

var fails := 0
var checks := 0
var n_seeds := 30
var shot_dir := ""
var shot_seed := 1


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			n_seeds = int(a.substr(6))
		elif a.begins_with("shots="):
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


func _same(a: LandMap, b: LandMap) -> bool:
	return a.kinds == b.kinds and a.tones == b.tones and str(a.things) == str(b.things) and str(a.decals) == str(b.decals) and str(a.lamps) == str(b.lamps) and a.spawn == b.spawn


func _run() -> void:
	await physics_frame
	Painter.load_kit()
	if shot_dir != "":
		await _shots()
		quit()
		return
	_rules()
	_painting()
	await _walking()
	await _from_the_cave()
	_title()
	print("%s  the Highlands: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


# --- The generator ------------------------------------------------------------------

func _rules() -> void:
	var a := WorldGen.make(4242)
	var b := WorldGen.make(4242)
	var c := WorldGen.make(4243)
	_check(_same(a, b), "the same seed makes the same map")
	_check(not _same(a, c), "another seed makes another map")
	var slowest := 0
	var total_tries := 0
	for s in n_seeds:
		var seed_value := 1000 + s * 7919
		var t0 := Time.get_ticks_msec()
		var m := WorldGen.make(seed_value)
		slowest = maxi(slowest, Time.get_ticks_msec() - t0)
		var who := "seed %d" % seed_value
		_check(m.tries >= 1, "%s: a layout passed the generator's own checks" % who)
		total_tries += maxi(m.tries, 1)
		# The cave mouth and the ground in front of it.
		_check(m.is_rock(m.mouth.x, m.mouth.y) and m.is_rock(m.mouth.x, m.mouth.y - 1) and m.is_rock(m.mouth.x - 1, m.mouth.y) and m.is_rock(m.mouth.x + 1, m.mouth.y), "%s: the cave mouth is set in rock" % who)
		_check(m.walkable(m.mouth.x, m.mouth.y + 1) and m.walkable(floori(m.spawn.x), floori(m.spawn.y)), "%s: the ground outside the cave mouth is open" % who)
		# The base: a clearing that fits on one screen, two to four gaps through its hills.
		_check(m.base_r.x >= 10.0 and m.base_r.x <= 14.0 and m.base_r.x * 2.0 <= 40.0 and m.base_r.y * 2.0 <= 22.0, "%s: the clearing is 10 to 14 tiles out and fits on one screen" % who)
		var gates := 0
		var sealed := 0
		for p in m.pockets:
			if bool(p["gate"]):
				gates += 1
			if bool(p["sealed"]):
				sealed += 1
		_check(gates >= 2 and gates <= 4, "%s: two to four gaps lead out of the base (%d)" % [who, gates])
		# Everything that is not sealed can be walked to; what is sealed cannot. Things that stop you count as walls here.
		var blocked := m.kinds.duplicate()
		for t in m.things:
			if Painter.things.get(str(t["n"]), {}).has("solid"):
				blocked[(int(t["y"]) / 16) * LandMap.SIZE + int(t["x"]) / 16] = LandMap.ROCK
		var keep := m.kinds
		m.kinds = blocked
		var seen := m.reach(Vector2i(floori(m.spawn.x), floori(m.spawn.y)))
		m.kinds = keep
		var lost := 0
		var leaked := 0
		for p in m.pockets:
			var at := Vector2i(floori(p["at"].x), floori(p["at"].y))
			var got := false
			for j in range(-2, 3):
				for i in range(-2, 3):
					if m.reached(seen, at.x + i, at.y + j):
						got = true
			if bool(p["sealed"]) and got:
				leaked += 1
			elif not bool(p["sealed"]) and not got:
				lost += 1
		_check(lost == 0, "%s: every open place that is not sealed can be walked to (%d cannot)" % [who, lost])
		_check(leaked == 0, "%s: no sealed place can be walked into (%d can)" % [who, leaked])
		_check(m.pockets.size() >= 28 and sealed >= 1 and sealed <= m.pockets.size() / 6, "%s: %d open places, %d of them sealed" % [who, m.pockets.size(), sealed])
		# Mostly rock: about two thirds, with the open land in small places.
		var share := m.open_share(28.0, 80.0)
		_check(share >= 0.20 and share <= 0.42, "%s: open land is %d%% of the inner ring" % [who, int(share * 100.0)])
		# No wall one tile thick: rock is in lumps you can dig into.
		var thin := 0
		for y in range(m.region.position.y + 3, m.region.end.y - 3):
			for x in range(m.region.position.x + 3, m.region.end.x - 3):
				if m.is_rock(x, y) and ((not m.is_rock(x, y - 1) and not m.is_rock(x, y + 1)) or (not m.is_rock(x - 1, y) and not m.is_rock(x + 1, y))):
					thin += 1
		_check(thin == 0, "%s: no rock is one tile thick (%d tiles are)" % [who, thin])
		# The named places: in their bands, never on one screen together, and reachable.
		var mouth := Vector2(m.mouth) + Vector2(0.5, 0.5)
		var q: Vector2 = m.sites["quarry"]["at"]
		var w: Vector2 = m.sites["watchpost"]["at"]
		_check(q.distance_to(mouth) >= 40.0 and q.distance_to(mouth) <= 85.0, "%s: the Old Quarry is 40 to 85 tiles out (%d)" % [who, int(q.distance_to(mouth))])
		_check(w.distance_to(mouth) >= 55.0 and w.distance_to(mouth) <= 85.0, "%s: the Watchpost is 55 to 85 tiles out (%d)" % [who, int(w.distance_to(mouth))])
		_check(q.distance_to(w) >= 40.0, "%s: the two places are at least 40 tiles apart (%d)" % [who, int(q.distance_to(w))])
		var west := (q - mouth).angle() - (m.turn + PI)
		_check(absf(angle_difference(0.0, west)) < 0.6, "%s: the Quarry is in the sector the seed turned 'west' to" % who)
		# Ore: tin and copper in the hills round the base.
		var tin := 0
		var copper := 0
		for y in range(int(m.base.position.y) - 12, int(m.base.end.y) + 12):
			for x in range(int(m.base.position.x) - 12, int(m.base.end.x) + 12):
				if m.kind(x, y) == LandMap.TIN:
					tin += 1
				elif m.kind(x, y) == LandMap.COPPER:
					copper += 1
		_check(tin >= 4 and copper >= 4, "%s: tin and copper in the base's hills (%d and %d tiles)" % [who, tin, copper])
		# Not cluttered: a handful of things to an open place, and the clearing nearly empty.
		var in_base := 0
		for t in m.things:
			var at := Vector2(float(t["x"]), float(t["y"])) / 16.0
			if Vector2((at.x - m.base_at.x) / m.base_r.x, (at.y - m.base_at.y) / m.base_r.y).length() < 1.1:
				in_base += 1
		_check(in_base <= 12, "%s: the clearing holds few things (%d)" % [who, in_base])
		_check(float(m.things.size()) / float(m.pockets.size()) <= 6.0, "%s: about %.1f things to an open place" % [who, float(m.things.size()) / float(m.pockets.size())])
		# Everything named is in the kit.
		for t in m.things + m.decals:
			if not Painter.things.has(str(t["n"])):
				_check(false, "%s: the kit has no '%s'" % [who, str(t["n"])])
				break
	print("      %d worlds made, the slowest in %d ms, %.2f layouts tried a world" % [n_seeds, slowest, float(total_tries) / float(n_seeds)])


# --- The painter ----------------------------------------------------------------------

func _painting() -> void:
	Painter.load_kit()
	var m := WorldGen.make(77)
	var cx := LandMap.MID / LandMap.CHUNK
	var cy := (LandMap.MID + 2) / LandMap.CHUNK
	var t0 := Time.get_ticks_msec()
	var a := Painter.paint(m, cx, cy)
	var ms := Time.get_ticks_msec() - t0
	var b := Painter.paint(m, cx, cy)
	_check(a.get_size() == Vector2i(256, 256), "a chunk's picture is 256 pixels a side")
	_check(a.get_data() == b.get_data(), "painting a chunk twice gives the same picture")
	# Only the kit's colours: nothing blended, nothing soft. (Lamplight is the one thing that makes new colours; this chunk has none.)
	var colours := {}
	for y in 256:
		for x in 256:
			colours[a.get_pixel(x, y).to_rgba32()] = true
	_check(colours.size() <= 64, "the picture uses a small palette (%d colours)" % colours.size())
	# Deep rock is the dark top; the ground outside the cave is the yard or grass.
	var deep := Painter.paint(m, m.region.position.x / LandMap.CHUNK, m.region.position.y / LandMap.CHUNK)
	var dark := 0
	for y in range(0, 256, 8):
		for x in range(0, 256, 8):
			if deep.get_pixel(x, y).get_luminance() < 0.12:
				dark += 1
	_check(dark > 1000, "the heart of a hill is the dark rock top (%d of 1024 samples)" % dark)
	print("      one chunk painted in %d ms" % ms)


# --- The game -------------------------------------------------------------------------

func _game(seed_value: int, players := 1, carry := {}):
	var g = Highlands.new()
	var inputs: Array = []
	for i in players:
		inputs.append(PlayerInput.make("script"))
	g.inputs = inputs
	g.world_seed = seed_value
	g.carry = carry
	g.welcome = false
	root.add_child(g)
	return g


func _walking() -> void:
	var g = _game(77, 2)
	await _frames(5)
	_check(g.players.size() == 2 and g.map != null and g.map.seed_value == 77, "the Highlands start with both players on the map asked for")
	_check(g.can_swap and g.players[0].armed(), "from the title screen everyone carries the arena's test weapons")
	var p = g.players[0]
	var start: Vector2 = p.global_position
	_check(g.map.walkable(floori(start.x / TILE), floori(start.y / TILE)), "players start on open ground")
	_check(g.land.chunks.size() >= 6, "the land round the camera is ready (%d chunks)" % g.land.chunks.size())
	var painted := 0
	for key in g.land.chunks:
		if g.land.chunks[key]["sprite"] != null:
			painted += 1
	_check(painted == g.land.chunks.size(), "every chunk in view has its picture before the first frame (%d of %d)" % [painted, g.land.chunks.size()])
	# North is the hill the cave mouth is set in: you cannot walk into it.
	for q in g.players:
		q.input.move = Vector2.UP
	await _frames(90)
	_check(p.global_position.y > float(g.map.mouth.y + 1) * TILE, "the rock stops you (walking north from the cave mouth)")
	# South is the clearing: you can walk.
	for q in g.players:
		q.input.move = Vector2.DOWN
	await _frames(60)
	_check(p.global_position.y > start.y + 100.0, "you can walk out across the clearing")
	for q in g.players:
		q.input.move = Vector2.ZERO
	# Nobody ever stands in rock or water, wherever they walk: a long wander.
	var bad := 0
	var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2(1, 1).normalized(), Vector2.UP, Vector2(-1, 1).normalized(), Vector2.DOWN, Vector2.RIGHT]
	for d in dirs:
		for q in g.players:
			q.input.move = d
		for f in 120:
			await physics_frame
			for q in g.players:
				if not g.map.walkable(floori(q.global_position.x / TILE), floori(q.global_position.y / TILE)):
					bad += 1
	_check(bad == 0, "nobody is ever inside rock or water (%d frames)" % bad)
	for q in g.players:
		q.input.move = Vector2.ZERO
	# The cave mouth is the way to the forge.
	p.global_position = Vector2(g.map.spawn.x * TILE, (float(g.map.mouth.y) + 1.8) * TILE)
	await _frames(3)
	_check(g.ui.prompts.size() == 1 and str(g.ui.prompts[0]["text"]).to_lower().contains("forge"), "standing at the cave mouth offers the forge")
	p.input.interact_pressed = true
	await _frames(2)
	p.input.interact_pressed = false
	await _frames(2)
	_check(g.build_menu.is_open, "using the cave mouth opens the forge screen")
	g.build_menu.close()
	await _frames(3)
	# Walking far brings new land in and lets the old go; pictures arrive without the game waiting.
	var far: Vector2 = g.map.pockets[g.map.pockets.size() - 1]["at"] * TILE
	for q in g.players:
		q.global_position = far
	g.rig.snap()
	await _frames(10)
	g.land.settle()
	var here := LandMap.chunk_key(floori(far.x / 512.0), floori(far.y / 512.0))
	_check(g.land.chunks.has(here) and g.land.chunks[here]["sprite"] != null, "the land is painted where you walk to")
	_check(g.land.chunks.size() <= 40, "land far behind is let go (%d chunks kept)" % g.land.chunks.size())
	# A dug tile repaints its chunk and stops stopping you (the map can change; digging itself comes later).
	var tile := Vector2i(floori(far.x / TILE), floori(far.y / TILE))
	var rock := tile
	for r in range(1, 20):
		if g.map.is_rock(tile.x + r, tile.y):
			rock = Vector2i(tile.x + r, tile.y)
			break
	var before: Image = (g.land.chunks[LandMap.chunk_key(floori(rock.x / 16.0), floori(rock.y / 16.0))]["sprite"] as Sprite2D).texture.get_image()
	g.map.set_kind(rock.x, rock.y, LandMap.FLOOR)
	g.land.changed(rock)
	await _frames(3)
	g.land.settle()
	var px := Vector2(rock.x, rock.y) * TILE + Vector2(16, 16)
	for q in g.players:
		q.global_position = px
	await _frames(3)
	_check(g.players[0].global_position.distance_to(px) < 4.0, "and no longer stops you")
	var after: Image = (g.land.chunks[LandMap.chunk_key(floori(rock.x / 16.0), floori(rock.y / 16.0))]["sprite"] as Sprite2D).texture.get_image()
	_check(before.get_data() != after.get_data(), "a tile that changes is painted again")
	g.queue_free()
	await _frames(3)


## The stairs at the end of the cave lead out here, with what you built.
func _from_the_cave() -> void:
	var cave = load("res://scripts/cave/cave.gd").new()
	cave.inputs = [PlayerInput.make("script")]
	cave.leads_outside = true
	root.add_child(cave)
	await _frames(3)
	var got: Array = []
	cave.go_outside.connect(func(what: Dictionary): got.append(what))
	cave._take_weapon(0, "bow") if cave.has_method("_take_weapon") and cave._can_take(0, "bow") else cave.builds[0].take("bow")
	cave.builds[0].changed.emit()
	cave.ui.cut = {}            # (not the opening pictures: straight to the end)
	cave.ui.card_title = ""
	cave.hud.visible = true
	cave._finish()
	for f in 400:
		await physics_frame
		if f > 140 and f % 20 == 0:
			cave.players[0].input.attack_pressed = true
		elif f > 140 and f % 20 == 2:
			cave.players[0].input.attack_pressed = false
		if not got.is_empty():
			break
	_check(got.size() == 1, "climbing the cave's stairs leads outside")
	cave.queue_free()
	await _frames(3)
	if got.is_empty():
		return
	var g = _game(5, 1, got[0])
	await _frames(5)
	_check(g.builds[0].weapon() == "bow" and g.players[0].armed() and not g.can_swap, "the weapon built in the cave comes out with you (%s)" % g.builds[0].weapon())
	g.queue_free()
	await _frames(3)


func _title() -> void:
	var rows: Array = Title.ITEMS.map(func(it): return it[0])
	_check(rows.has("highlands") and rows.find("highlands") > rows.find("arena"), "the title screen has a Highlands row, after the tutorial and the arena")


# --- Screenshots ----------------------------------------------------------------------

func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	# The card you arrive to.
	var first = _game(shot_seed, 1)
	first.welcome = true
	first.ui.card("The Greystone Highlands", "A new land, laid out differently every time.\nThis version is the land alone: nothing to fight, dig or take yet. The cave mouth leads back to your forge.\n\nWorld number %d" % shot_seed)
	await _frames(40)
	await RenderingServer.frame_post_draw
	var card: Image = root.get_texture().get_image()
	if card.get_width() != 640:
		card.resize(640, 360, Image.INTERPOLATE_NEAREST)
	card.save_png("%s/seed%d_arrival.png" % [shot_dir, shot_seed])
	first.queue_free()
	await _frames(3)
	var g = _game(shot_seed, 2)
	await _frames(10)
	var m: LandMap = g.map
	var views := {"base": m.spawn + Vector2(0, 3.5)}
	views["quarry"] = m.sites["quarry"]["at"]
	views["watchpost"] = m.sites["watchpost"]["at"]
	var n := 0
	for p in m.pockets:
		if bool(p["gate"]) or bool(p["sealed"]) or str(p["site"]) != "":
			continue
		n += 1
		if n == 3:
			views["open_place"] = p["at"]
		elif n == 9:
			views["open_place_2"] = p["at"]
		if p.has("tarn") and not views.has("tarn"):
			views["tarn"] = p["at"]
	for l in m.links:
		var mid: Vector2 = (m.pockets[int(l["a"])]["at"] + m.pockets[int(l["b"])]["at"]) * 0.5
		if bool(l["tunnel"]) and not views.has("tunnel"):
			views["tunnel"] = mid
		elif not bool(l["tunnel"]) and not views.has("ordinary"):
			views["ordinary"] = mid
	for name in views:
		var at := _stand_near(m, views[name])
		g.players[0].global_position = at
		g.players[1].global_position = _stand_near(m, at / TILE + Vector2(1.6, 0.4))
		for q in g.players:
			q.face_dir = Vector2.DOWN
		g.rig.snap()
		await _frames(8)
		g.land.settle()
		await _frames(40)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		if img.get_width() != 640:
			img.resize(640, 360, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/seed%d_%s.png" % [shot_dir, shot_seed, name])
		print("saved %s/seed%d_%s.png" % [shot_dir, shot_seed, name])


## The middle of the nearest tile to `tile` that somebody could stand on, in world units.
func _stand_near(m: LandMap, tile: Vector2) -> Vector2:
	for r in 12:
		for j in range(-r, r + 1):
			for i in range(-r, r + 1):
				var x := floori(tile.x) + i
				var y := floori(tile.y) + j
				if m.walkable(x, y) and m.walkable(x - 1, y) and m.walkable(x + 1, y) and m.walkable(x, y - 1) and m.walkable(x, y + 1):
					return Vector2(float(x) + 0.5, float(y) + 0.5) * TILE
	return tile * TILE
