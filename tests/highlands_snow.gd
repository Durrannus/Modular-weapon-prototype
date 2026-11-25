extends SceneTree
## The snowy section round the Hound Den (version 62). Darren, 25 November 2026: "let's have a snowy section for the
## wolfs to spawn in and near. The snowy section is to be pretty much the same but with a snow effect to the screen and
## snow on things in the area with the wolf den." Checks the snow kit, where the snow lies, the painting, the Den's
## mouth, the hounds' ground, the falling snow, the maps and the lab. Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands_snow.gd
##
## With shots=/some/folder/ (needs a window, so leave out --headless) it saves pictures instead.

const PlayerInput := preload("res://scripts/player_input.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const FoePlan := preload("res://scripts/highlands/foe_plan.gd")
const Charts := preload("res://scripts/highlands/charts.gd")
const Snow := preload("res://scripts/highlands/snow.gd")
const Lab := preload("res://scripts/lab.gd")
const TILE := 32.0
const SEEDS := [424242, 77, 1234, 99999, 555, 31337]

var fails := 0
var checks := 0
var shot_dir := ""


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shot_dir = a.substr(6)
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
	_kit()
	var maps: Array = []
	for sd in SEEDS:
		maps.append(WorldGen.make(sd))
	_where(maps)
	_paint(maps[0])
	_mouth(maps)
	_hounds(maps)
	await _game()
	_lab_and_off(maps[0])
	print("%s  the snowy section round the Hound Den: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func _game_of(seed_value: int, foes := true):
	var g = Highlands.new()
	g.inputs = [PlayerInput.make("script")]
	g.world_seed = seed_value
	g.with_foes = foes
	g.welcome = false
	root.add_child(g)
	return g


## The Art builder's snow, baked into a kit beside the plain one (tools/highlands_kit/bake.py --snow).
func _kit() -> void:
	_check(Painter.snow_ready, "the snow kit is there (art/highlands/snow/, baked from the Art builder's hl3_snow.py)")
	var missing: Array = []
	for name in Painter.things:
		if not Painter.snow_things.has(name) and not str(name).begins_with("pine_stump"):
			missing.append(name)
	_check(missing.is_empty(), "every thing on the land has its snowy picture (missing: %s)" % str(missing))
	for name in ["den", "trample", "tracks_e", "tracks_se", "tracks_ne"]:
		_check(Painter.snow_things.has(name) and not Painter.things.has(name), "the Den's %s is in the snow kit only" % name)
	_check(Painter.snow_things.get("den", {}).has("solid"), "the Den's mouth stops you")
	# Snow on the pines: their snowy picture has snow colours, the plain one none.
	var sheet: Image = Painter.sheets["snow/things"]
	var r: Array = Painter.snow_things["pine_0"]["rect"]
	var snow_px := 0
	for y in int(r[3]):
		for x in int(r[2]):
			if Painter.snow32.has(sheet.get_pixel(int(r[0]) + x, int(r[1]) + y).to_rgba32()):
				snow_px += 1
	_check(snow_px > 100, "a pine in the snow has snow on it (%d pixels of snow)" % snow_px)
	# The animals are never snowed on (they play the plain kit's frames).
	_check(not Painter.snowy_thing(null, {"n": "cow", "x": 0, "y": 0}), "an animal keeps its own picture")
	for layer in ["far", "near"]:
		_check(Art_tex("highlands/snow/snow_%s.png" % layer) != null, "the falling snow's %s layer is there" % layer)


func Art_tex(path: String) -> Texture2D:
	return load("res://scripts/art.gd").texture(path)


## Where the snow lies: round the Den, as far as REACH with a ragged edge, and nowhere near the cave.
func _where(maps: Array) -> void:
	for m: LandMap in maps:
		var c := Snow.centre(m)
		_check(c == m.sites["den"]["at"], "world %d: the snow is round the Hound Den" % m.seed_value)
		var inside := true
		var outside := true
		for a in 72:
			var dir := Vector2.from_angle(TAU * a / 72.0)
			var p_in := c + dir * (Snow.REACH - Snow.EDGE * 3.0)
			var p_out := c + dir * (Snow.REACH + Snow.EDGE * 3.0)
			if Snow.depth(m, p_in.x, p_in.y) <= 0.0:
				inside = false
			if Snow.depth(m, p_out.x, p_out.y) > 0.0:
				outside = false
		_check(inside and outside, "world %d: snow all round within %d tiles of the Den, none past %d" % [m.seed_value, int(Snow.REACH - Snow.EDGE * 3.0), int(Snow.REACH + Snow.EDGE * 3.0)])
		var cave := Vector2(LandMap.MID + 0.5, LandMap.MID + 0.5)
		_check(Snow.depth(m, cave.x, cave.y) <= 0.0, "world %d: no snow at the cave" % m.seed_value)
		# A chunk said to be all snow or none is so at every point of it (so the painter can paint it one way).
		var ok := true
		var kinds := [0, 0, 0]
		var rng := RandomNumberGenerator.new()
		rng.seed = m.seed_value
		var c0 := Vector2i(c / LandMap.CHUNK)
		for cy in range(c0.y - 7, c0.y + 8):
			for cx in range(c0.x - 7, c0.x + 8):
				var k := Snow.chunk(m, cx, cy)
				kinds[k] += 1
				if k == 1:
					continue
				for n in 24:
					var x := (cx + rng.randf()) * LandMap.CHUNK
					var y := (cy + rng.randf()) * LandMap.CHUNK
					if (Snow.depth(m, x, y) > 0.0) != (k == 2):
						ok = false
		_check(ok and kinds[0] > 0 and kinds[1] > 0 and kinds[2] > 0, "world %d: a chunk all under snow or clear of it is so all over (%s)" % [m.seed_value, str(kinds)])
	# The snow is only paint: the land itself is made as before (no world is laid out again).
	var m2 := WorldGen.make(SEEDS[0])
	_check(m2.kinds == (maps[0] as LandMap).kinds and str(m2.things.size()) != "", "the land under the snow is the same land")


## The painting: the snow kit where the snow lies, the plain kit away from it, both at its edge.
func _paint(m: LandMap) -> void:
	var c := Snow.centre(m)
	var full := Vector2i(-1, -1)
	var edges: Array = []
	var plain := Vector2i(-1, -1)
	for r in range(0, 12):
		for a in 48:
			var at := Vector2i((c + Vector2.from_angle(TAU * a / 48.0) * float(r) * LandMap.CHUNK) / LandMap.CHUNK)
			var k := Snow.chunk(m, at.x, at.y)
			if _open_share(m, at) < 0.3:
				continue
			if k == 2 and full.x < 0:
				full = at
			elif k == 1 and not edges.has(at):
				edges.append(at)
			elif k == 0 and plain.x < 0:
				plain = at
	_check(full.x >= 0 and not edges.is_empty() and plain.x >= 0, "there are open chunks under snow, at its edge and clear of it")
	if full.x < 0 or edges.is_empty() or plain.x < 0:
		return
	var t := Time.get_ticks_usec()
	var s_full := _shares(Painter.paint(m, full.x, full.y))
	var ms_full := (Time.get_ticks_usec() - t) / 1000.0
	# (Of the chunks the edge crosses, the one where it shows most: in some, what lies past it is rock.)
	var edge: Vector2i = edges[0]
	var s_edge := [0.0, 0.0]
	var ms_edge := 0.0
	for e in edges.slice(0, 10):
		t = Time.get_ticks_usec()
		var sh := _shares(Painter.paint(m, e.x, e.y))
		ms_edge = maxf(ms_edge, (Time.get_ticks_usec() - t) / 1000.0)
		if minf(sh[0], sh[1]) > minf(s_edge[0], s_edge[1]):
			s_edge = sh
			edge = e
	var s_plain := _shares(Painter.paint(m, plain.x, plain.y))
	print("      painted: under snow %s in %.0f ms, at the edge %s in %.0f ms, clear %s (snow, grass)" % [str(s_full), ms_full, str(s_edge), ms_edge, str(s_plain)])
	_check(s_full[0] > 0.4 and s_full[1] < 0.12, "a chunk under snow is painted snowy (%.0f%% snow, %.0f%% grass: dry heads and trodden paths)" % [s_full[0] * 100.0, s_full[1] * 100.0])
	_check(s_plain[0] < 0.02 and s_plain[1] > 0.2, "a chunk clear of it is painted as before (%.0f%% snow)" % [s_plain[0] * 100.0])
	_check(s_edge[0] > 0.02 and s_edge[1] > 0.02, "a chunk at its edge has both (%.0f%% snow, %.0f%% grass)" % [s_edge[0] * 100.0, s_edge[1] * 100.0])
	_check(ms_edge < 400.0, "a chunk at the edge, painted twice, is still quick (at most %.0f ms, on another thread)" % ms_edge)
	# The same chunk always paints the same (two chunks meet without a seam).
	_check(Painter.paint(m, edge.x, edge.y).get_data() == Painter.paint(m, edge.x, edge.y).get_data(), "the edge paints the same every time")


func _open_share(m: LandMap, chunk: Vector2i) -> float:
	var n := 0
	for y in LandMap.CHUNK:
		for x in LandMap.CHUNK:
			if m.walkable(chunk.x * LandMap.CHUNK + x, chunk.y * LandMap.CHUNK + y):
				n += 1
	return float(n) / float(LandMap.CHUNK * LandMap.CHUNK)


## The share of a picture's pixels in the snow's colours and in the grass's.
func _shares(img: Image) -> Array:
	var snow := 0
	var grass := 0
	var green := {}
	for col in Painter.grass32:
		green[col] = true
	var data := img.get_data()
	for i in range(0, data.size(), 4):
		var c := (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | data[i + 3]
		if Painter.snow32.has(c):
			snow += 1
		elif green.has(c):
			grass += 1
	var all := float(data.size() / 4)
	return [snapped(snow / all, 0.01), snapped(grass / all, 0.01)]


## The Den's mouth: against the rock at the north of the Den, never on or by a path, in every world.
func _mouth(maps: Array) -> void:
	for m: LandMap in maps:
		var before := m.things.size()
		var foot := Snow.stamp(m, [])
		_check(foot != Vector2.INF, "world %d: the Den's mouth has a place" % m.seed_value)
		if foot == Vector2.INF:
			continue
		var tile := Vector2i(foot / 16.0)
		var at: Vector2 = m.sites["den"]["at"]
		_check((Vector2(tile) + Vector2(0.5, 0.5)).distance_to(at) < 16.0, "world %d: it is at the Den (%d tiles from its middle)" % [m.seed_value, int(Vector2(tile).distance_to(at))])
		_check(LandMap.rocky(m.kind(tile.x, tile.y - 2)) or LandMap.rocky(m.kind(tile.x - 1, tile.y - 2)), "world %d: it stands against the rock" % m.seed_value)
		var path := false
		for dy in range(-1, 3):
			for dx in range(-3, 4):
				if m.kind(tile.x + dx, tile.y + dy) == LandMap.PATH:
					path = true
		_check(not path, "world %d: no footpath under it or beside it" % m.seed_value)
		_check(m.things.size() == before + 1 and m.things.any(func(t): return str(t["n"]) == "den"), "world %d: it stands on the land as one thing" % m.seed_value)
		var names: Array = m.decals.map(func(d): return str(d["n"]))
		_check(names.has("trample") and names.has("tracks_e") and names.has("tracks_ne"), "world %d: trodden snow in front of it and paw prints leading off" % m.seed_value)
		_check(m.changes()["added"].is_empty(), "world %d: and no save holds any of it" % m.seed_value)


## Who lives there: every open place in the snow and near it holds hounds, none is empty, and no goblins.
func _hounds(maps: Array) -> void:
	var near_all := 0
	var hounds_all := 0
	var before_hounds := 0
	for m: LandMap in maps:
		var plan := FoePlan.make(m)
		var c := Snow.centre(m)
		var yard: Vector2 = m.sites["scrapyard"]["at"] if m.sites.has("scrapyard") else Vector2.INF
		var by_pocket := {}
		for g in plan:
			by_pocket[int(g["pocket"])] = g
		var ok := true
		var cave := Vector2(LandMap.MID + 0.5, LandMap.MID + 0.5)
		for i in m.pockets.size():
			var p: Dictionary = m.pockets[i]
			var at: Vector2 = p["at"]
			if at.distance_to(c) >= Snow.REACH + Snow.HOUNDS_NEAR or bool(p.get("sealed", false)) or at.distance_to(cave) < FoePlan.SAFE:
				continue
			if str(p.get("site", "")) in ["watchpost", "quarry", "roost", "scrapyard"] or at.distance_to(yard) < FoePlan.SCRAP_REACH:
				continue
			near_all += 1
			var g: Dictionary = by_pocket.get(i, {})
			if g.is_empty() or str(g["what"]) != "hounds":
				ok = false
			else:
				hounds_all += (g["members"] as Array).size()
		_check(ok, "world %d: every open place in and near the snow has hounds in it" % m.seed_value)
		var keep := Snow.REACH
		Snow.REACH = 0.0
		for g in FoePlan.make(m):
			if (g["home"] as Vector2).distance_to(c) < keep + Snow.HOUNDS_NEAR and str(g["what"]) == "hounds":
				before_hounds += (g["members"] as Array).size()
		Snow.REACH = keep
	print("      in and near the snow in six worlds: %d places, %d hounds (%d without the snow)" % [near_all, hounds_all, before_hounds])
	_check(hounds_all > before_hounds, "more hounds live round the Den than before (%d, was %d)" % [hounds_all, before_hounds])


## In the game: the mouth stands with its snowy picture, things in the snow are snowy, snow falls over the snow only
## and under everybody, and the maps show where it lies.
func _game() -> void:
	var g = _game_of(SEEDS[0])
	await _frames(3)
	var m: LandMap = g.map
	var foot: Vector2 = m.sites["den"].get("den_foot", Vector2.INF)
	_check(foot != Vector2.INF, "the game puts the Den's mouth on the land")
	_check(g.foes.nav.steps(g.player.global_position, (m.sites["den"]["at"] as Vector2) * TILE) >= 0, "the Den can still be walked to")
	var q = g.player
	q.global_position = foot * 2.0 + Vector2(0, 90)
	q.reset_physics_interpolation()
	g.rig.snap()
	await _frames(4)
	g.land.settle()
	var den_thing: Dictionary = {}
	for t in m.things:
		if str(t["n"]) == "den":
			den_thing = t
	var s: Sprite2D = g.land.sprite_of(den_thing)
	_check(s != null and bool(s.get_meta("snow", false)), "the mouth stands there in its snowy picture")
	var snowy := 0
	var plain := 0
	for key in g.land.chunks:
		for sp in g.land.chunks[key]["things"]:
			if bool((sp as Sprite2D).get_meta("snow", false)):
				snowy += 1
			else:
				plain += 1
	_check(snowy > 3, "the things round it stand in their snowy pictures (%d snowy, %d not)" % [snowy, plain])
	var fall = g.snowfall
	_check(fall.wanted(), "snow falls at the Den")
	await _frames(int(Snow.FADE * 60.0) + 10)
	_check(is_equal_approx(fall.shown, 1.0) and fall.visible, "and has faded in after about a second")
	_check(fall.z_index > g.land.ground.z_index and fall.z_index < 0 and fall.z_index < -5, "it is drawn over the land and under everybody and every mark on the floor (z %d)" % fall.z_index)
	_check(fall.get_index() < g.tools.get_index(), "and under the tool's mark on the land")
	q.global_position = m.spawn * TILE
	q.reset_physics_interpolation()
	g.rig.snap()
	await _frames(2)
	_check(not fall.wanted(), "no snow falls at the cave")
	await _frames(int(Snow.FADE * 60.0) + 10)
	_check(fall.shown == 0.0 and not fall.visible, "and it fades out")
	# The maps.
	var img: Image = Charts.snow_image(m)
	var den := Vector2i(m.sites["den"]["at"])
	_check(img.get_pixel(den.x, den.y).r > 0.5 and img.get_pixel(LandMap.MID, LandMap.MID).r < 0.5, "the small map and the whole map show the snow at the Den and not at the cave")
	g.queue_free()
	await _frames(3)


## The lab has its numbers, and with no snow nothing is snowy.
func _lab_and_off(m: LandMap) -> void:
	_check(Lab.SCRIPTS.has("snow") and Lab.SCRIPTS["snow"] == "res://scripts/highlands/snow.gd", "the lab knows the snow's numbers")
	var keep := Snow.REACH
	Snow.REACH = 0.0
	var c := Vector2i(m.sites["den"]["at"] / LandMap.CHUNK)
	_check(Snow.chunk(m, c.x, c.y) == 0 and Snow.depth(m, m.sites["den"]["at"].x, m.sites["den"]["at"].y) <= 0.0, "with the lab's reach at 0 there is no snow")
	var m2 := WorldGen.make(SEEDS[1])
	_check(Snow.stamp(m2, []) == Vector2.INF, "and no mouth is put on the land")
	Snow.REACH = keep


# --- Pictures -----------------------------------------------------------------------------------------------------

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png("%s/%s.png" % [shot_dir, name])
	print("saved %s/%s.png" % [shot_dir, name])


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var g = _game_of(SEEDS[0], true)
	await _frames(3)
	var m: LandMap = g.map
	for p in g.players:
		p.max_hp = 99999.0
		p.hp = 99999.0
	var c := Snow.centre(m)
	var foot: Vector2 = m.sites["den"].get("den_foot", c * 16.0)
	var q = g.player
	var spots := [["01_the_den", foot * 2.0 + Vector2(0, 120)]]
	for row in [["02_in_the_snow", Vector2(-25, 10)], ["03_the_edge", Vector2(Snow.REACH - 6.0, 0)], ["04_the_edge_2", Vector2(-Snow.REACH + 4.0, 8)]]:
		var want: Vector2i = Vector2i(c + row[1])
		var best := want
		var bd := 1e9
		for j in range(-24, 25):
			for i in range(-24, 25):
				if m.walkable(want.x + i, want.y + j) and Vector2(i, j).length() < bd:
					bd = Vector2(i, j).length()
					best = want + Vector2i(i, j)
		spots.append([row[0], (Vector2(best) + Vector2(0.5, 0.5)) * TILE])
	for s in spots:
		q.global_position = s[1]
		q.reset_physics_interpolation()
		g.rig.snap()
		await _frames(4)
		g.land.settle()
		await _frames(80)
		await _snap(str(s[0]))
	g.charts.explored.fill(255)
	g.charts._seen_dirty = true
	g.charts.open()
	await _frames(20)
	await _snap("05_the_whole_map")
	g.charts.close()
	g.queue_free()
	await _frames(3)
