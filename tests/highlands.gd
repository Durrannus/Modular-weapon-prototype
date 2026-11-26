extends SceneTree
## The Greystone Highlands map (version 35 on): the generator's rules, the painter,
## the ore veins (version 38) and walking about on it. Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands.gd [-- seeds=30]
##
## With shots=/some/folder/ (needs a window, so leave out --headless) it also saves
## 640x360 screenshots of one world: the base, an ordinary screen, an open place, a
## dug tunnel, the two named places, tin and copper in a rock face. "seed=123456"
## picks the world.

const PlayerInput := preload("res://scripts/player_input.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const LandGrow := preload("res://scripts/highlands/land_grow.gd")
const Veins := preload("res://scripts/highlands/veins.gd")
const LandLight := preload("res://scripts/highlands/land_light.gd")
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


## Every ore cluster and every pixel of its seams, as one line of text.
func _seams(m: LandMap) -> String:
	var out := ""
	for v in m.veins:
		var sum := 0
		for p: Vector2i in v["px"]:
			sum += (p.x * 31 + p.y) * int(v["px"][p])
		out += "%d:%d:%d:%d;" % [int(v["kind"]), (v["cells"] as Array).size(), (v["px"] as Dictionary).size(), sum]
	return out


func _same(a: LandMap, b: LandMap) -> bool:
	return _seams(a) == _seams(b) and a.kinds == b.kinds and a.tones == b.tones and str(a.things) == str(b.things) and str(a.decals) == str(b.decals) and str(a.lamps) == str(b.lamps) and str(a.plants) == str(b.plants) and a.spawn == b.spawn


func _run() -> void:
	await physics_frame
	Painter.load_kit()
	if shot_dir != "":
		await _shots()
		quit()
		return
	_rules()
	_groves()
	_painting()
	_foliage()
	_veins()
	_light()
	await _walking()
	await _light_in_game()
	await _from_the_cave()
	_title()
	print("%s  the Highlands: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


# --- The generator ------------------------------------------------------------------

## Version 58. Darren, 25 November: "We need more trees also for wood because it seems a bit bare and they are a
## basic material". About twice the pines, in small groves, stood last with dice of their own: off the footpaths, the
## gaps and the ways through a place, clear of what stands there, and never in a named place.
func _groves() -> void:
	var was := WorldGen.GROVES
	_check(is_equal_approx(was, 2.5), "the lab's pine groves are at 2.5, about twice the pines there were (%s)" % str(was))
	var none := 0          # the inner ring's pines without the groves, and with them
	var with := 0
	var grove_pines := 0
	var in_company := 0
	var bad := {"spot": 0, "path": 0, "named": 0, "middle": 0, "way": 0, "crowd": 0, "moved": 0}
	for seed_value in [4242, 77, 1]:
		WorldGen.GROVES = 0.0
		var a := WorldGen.make(seed_value)
		WorldGen.GROVES = was
		var b := WorldGen.make(seed_value)
		# The groves move nothing else: the same rock, ore and ground, and every other thing where it was.
		if a.kinds != b.kinds or _seams(a) != _seams(b) or a.tones != b.tones or str(b.things.slice(0, a.things.size())) != str(a.things) or a.spawn != b.spawn:
			bad["moved"] += 1
		for pair in [[a, 0], [b, 1]]:
			for t in (pair[0] as LandMap).things:
				var n := str(t["n"])
				if n.begins_with("pine_") and Vector2(float(t["x"]) / 16.0 - LandMap.MID, float(t["y"]) / 16.0 - LandMap.MID).length() < WorldGen.RINGS[1]:
					if int(pair[1]) == 0:
						none += 1
					else:
						with += 1
		var joined := {}
		for link in b.links:
			for e in [[int(link["a"]), int(link["b"])], [int(link["b"]), int(link["a"])]]:
				if not joined.has(e[0]):
					joined[e[0]] = []
				joined[e[0]].append(b.pockets[e[1]]["at"])
		var added: Array = b.things.slice(a.things.size())
		for t in added:
			grove_pines += 1
			var foot := Vector2(float(t["x"]), float(t["y"])) / 16.0
			var tile := Vector2i(floori(foot.x), floori(foot.y))
			var here := Vector2(tile) + Vector2(0.5, 0.5)
			var gn := str(t["n"])
			if not (gn.begins_with("pine_") or gn.begins_with("rowan_") or gn.begins_with("juniper_")) or gn == "pine_stump":
				bad["spot"] += 1     # (a grove is pines, and since version 65 a rowan and junipers under them)
			var open := true
			for j in range(-1, 2):
				for i in range(-1, 2):
					var k := b.kind(tile.x + i, tile.y + j)
					if k != LandMap.GRASS and k != LandMap.SCRUB and k != LandMap.HEATH:
						open = false
			if not open:
				bad["spot"] += 1
			for j in range(-3, 2):
				for i in range(-1, 2):
					var k := b.kind(tile.x + i, tile.y + j)
					if k == LandMap.PATH or k == LandMap.YARD or k == LandMap.FLOOR or k == LandMap.WATER:
						open = false
			if not open:
				bad["path"] += 1
			# Its place: the one whose middle is nearest.
			var best := -1
			var best_d := INF
			for idx in b.pockets.size():
				var d := here.distance_to(b.pockets[idx]["at"])
				if d < best_d:
					best = idx
					best_d = d
			var p: Dictionary = b.pockets[best]
			if str(p["site"]) != "" or bool(p["gate"]):
				bad["named"] += 1
			if best_d < 2.0:
				bad["middle"] += 1
			for o: Vector2 in joined.get(best, []):
				if Geometry2D.get_closest_point_to_segment(here, p["at"], o).distance_to(here) < WorldGen.GROVE_WAY - 0.01:
					bad["way"] += 1
			for o in a.things:
				if here.distance_to(Vector2(float(o["x"]), float(o["y"])) / 16.0) < WorldGen.GROVE_ROOM - 0.01:
					bad["crowd"] += 1
			for o in added:
				if o != t and Vector2(o["x"], o["y"]).distance_to(Vector2(t["x"], t["y"])) / 16.0 <= WorldGen.GROVE_REACH + 1.5:
					in_company += 1
					break
	_check(bad["moved"] == 0, "the groves move nothing else on the land: rock, ore, ground and every other thing stay where they were")
	_check(float(with) >= float(none) * 1.7, "the inner ring has about twice the pines (%d, without the groves %d)" % [with, none])
	_check(grove_pines > 0 and in_company == grove_pines, "the new pines stand in groves, not one by one (%d of %d have another close by)" % [in_company, grove_pines])
	_check(bad["spot"] == 0, "every grove pine stands on grass with grass all round it (%d do not)" % bad["spot"])
	_check(bad["path"] == 0, "none stands on or right over a footpath, a track, a dug floor or water (%d do)" % bad["path"])
	_check(bad["named"] == 0, "none stands in a named place or in the ground before a pass (%d do)" % bad["named"])
	_check(bad["middle"] == 0, "none stands in the middle of its place, where a chest or a camp goes (%d do)" % bad["middle"])
	_check(bad["way"] == 0, "none stands in the way from its place's middle to a place it is joined to (%d do)" % bad["way"])
	_check(bad["crowd"] == 0, "none crowds what already stood there (%d do)" % bad["crowd"])
	WorldGen.GROVES = was

func _rules() -> void:
	var a := WorldGen.make(4242)
	var b := WorldGen.make(4242)
	var c := WorldGen.make(4243)
	_check(_same(a, b), "the same seed makes the same map")
	_check(not _same(a, c), "another seed makes another map")
	# The size Darren chose on 22 November: about 350 tiles from the cave to the edge, in rings.
	_check(WorldGen.RINGS == [24.0, 125.0, 240.0, 350.0], "the rings end 24, 125, 240 and 350 tiles from the cave")
	_check(LandMap.MID >= int(WorldGen.RINGS[3]) + 16 and LandMap.SIZE - LandMap.MID >= int(WorldGen.RINGS[3]) + 16, "the map has room for the whole Highlands, 350 tiles out and its edge")
	_check(WorldGen.REACH >= int(WorldGen.RINGS[3]) + 12 and a.region.size == Vector2i(WorldGen.REACH * 2, WorldGen.REACH * 2), "this version lays out the base and all three rings (version 49)")
	var slowest := 0
	var total_tries := 0
	var places := 0
	var lively := 0
	var far_places := 0
	var far_lively := 0
	var scree_worlds := 0
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
		_check(m.pockets.size() >= 60 and sealed >= 1 and sealed <= m.pockets.size() / 6, "%s: %d open places, %d of them sealed" % [who, m.pockets.size(), sealed])
		# Mostly rock: about two thirds, with the open land in small places.
		var share := m.open_share(28.0, WorldGen.RING_INNER - 4.0)
		_check(share >= 0.20 and share <= 0.42, "%s: open land is %d%% of the inner ring" % [who, int(share * 100.0)])
		# The land is the size Darren chose on 22 November (the Game Bible's "Highlands size": the inner ring ends about
		# 125 tiles from the cave, the outer about 350), and it is used right out to there. The inner ring's own places
		# stop at its edge.
		var furthest := 0.0
		for y in range(m.region.position.y, m.region.end.y):
			for x in range(m.region.position.x, m.region.end.x):
				if not m.is_rock(x, y):
					furthest = maxf(furthest, Vector2(x - LandMap.MID, y - LandMap.MID).length())
		var inner_far := 0.0
		for p in m.pockets:
			if int(p.get("ring", 1)) == 1:
				inner_far = maxf(inner_far, (p["at"] as Vector2).distance_to(Vector2(LandMap.MID, LandMap.MID)) + float(p.get("reach", p["rx"])))
		_check(furthest >= 330.0 and furthest <= float(WorldGen.REACH) and inner_far <= WorldGen.RINGS[1] + 8.0, "%s: open land reaches about 350 tiles from the cave (%d), the inner ring's places about 125 (%d)" % [who, int(furthest), int(inner_far)])
		# Three rings, each its own: a belt of rock between two, a few passes through it, and the named places
		# where the Game Bible puts them, far apart.
		var cave := Vector2(LandMap.MID, LandMap.MID)
		var per := {1: 0, 2: 0, 3: 0}
		var wrong_ring := 0
		for p in m.pockets:
			var r := int(p.get("ring", 0))
			per[r] = int(per.get(r, 0)) + 1
			var d := (p["at"] as Vector2).distance_to(cave)
			if r >= 2 and str(p["site"]) == "" and (d < WorldGen.RINGS[r - 1] or d > WorldGen.RINGS[r] + 6.0):
				wrong_ring += 1
		_check(per[1] >= 60 and per[2] >= 120 and per[3] >= 180 and wrong_ring == 0, "%s: open places in each ring (%d, %d, %d), each inside its own ring" % [who, per[1], per[2], per[3]])
		var cross := {}
		for l in m.links:
			var ra := int(m.pockets[int(l["a"])].get("ring", 0))
			var rb := int(m.pockets[int(l["b"])].get("ring", 0))
			if ra != rb:
				var key := mini(ra, rb) * 10 + maxi(ra, rb)
				cross[key] = int(cross.get(key, 0)) + 1
		_check(cross.get(12, 0) == WorldGen.PASSES[1] and cross.get(23, 0) == WorldGen.PASSES[2] and cross.size() == 2, "%s: %d passes from the inner ring to the middle, %d from the middle to the outer, none farther (%s)" % [who, WorldGen.PASSES[1], WorldGen.PASSES[2], str(cross)])
		var where := {"watchpost": 1, "quarry": 1, "roost": 2, "den": 2, "cairns": 2, "gorge": 2, "fault": 3, "scrapyard": 3}
		var placed := 0
		for name in where:
			if m.sites.has(name) and m.sites[name].get("at") != null:
				var d := Vector2(m.sites[name]["at"]).distance_to(cave)
				var r: int = where[name]
				if d >= WorldGen.RINGS[r - 1] - 2.0 and d <= WorldGen.RINGS[r] + 8.0:
					placed += 1
		var closest := INF
		var names: Array = where.keys()
		for i in names.size():
			for j in range(i + 1, names.size()):
				if m.sites.has(names[i]) and m.sites.has(names[j]):
					closest = minf(closest, Vector2(m.sites[names[i]]["at"]).distance_to(Vector2(m.sites[names[j]]["at"])))
		_check(placed == where.size() and closest >= 40.0, "%s: the Watchpost and the Quarry in the inner ring, the Roost, the Den, the cairns and the gorge in the middle, the Fault and the Scrapyard in the outer, each at least 40 tiles from the next (%d)" % [who, int(closest)])
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
		# The research's bands (40 to 85 and 55 to 85 of a ring 90 out), stretched to the ring Darren chose (125 out).
		_check(q.distance_to(mouth) >= 56.0 and q.distance_to(mouth) <= 118.0, "%s: the Old Quarry is 56 to 118 tiles out (%d)" % [who, int(q.distance_to(mouth))])
		_check(w.distance_to(mouth) >= 76.0 and w.distance_to(mouth) <= 118.0, "%s: the Watchpost is 76 to 118 tiles out (%d)" % [who, int(w.distance_to(mouth))])
		_check(q.distance_to(w) >= 40.0, "%s: the two places are at least 40 tiles apart (%d)" % [who, int(q.distance_to(w))])
		var west := (q - mouth).angle() - (m.turn + PI)
		_check(absf(angle_difference(0.0, west)) < 0.6, "%s: the Quarry is in the sector the seed turned 'west' to" % who)
		# Ore: clusters of tin and copper tiles, with seams drawn through each. In the hills round the base, at least
		# two of them in rock whose lit face you look at; never two clusters run together; some hidden for the pickaxe.
		var tin := 0
		var copper := 0
		for y in range(int(m.base.position.y) - 12, int(m.base.end.y) + 12):
			for x in range(int(m.base.position.x) - 12, int(m.base.end.x) + 12):
				if m.kind(x, y) == LandMap.TIN:
					tin += 1
				elif m.kind(x, y) == LandMap.COPPER:
					copper += 1
		_check(tin >= 4 and copper >= 4, "%s: tin and copper in the base's hills (%d and %d tiles)" % [who, tin, copper])
		var too_big := 0
		var run_together := 0
		var base_face := 0
		var hidden := 0
		for v in m.veins:
			var own := {}
			var lo := Vector2i(1 << 20, 1 << 20)
			var hi := Vector2i(-1, -1)
			for t: Vector2i in v["cells"]:
				own[t] = true
				lo = lo.min(t)
				hi = hi.max(t)
			if hi.x - lo.x + 1 > 6 or hi.y - lo.y + 1 > 4:
				too_big += 1
			var face := false
			var in_sight := false
			var other := false
			for t: Vector2i in v["cells"]:
				if m.walkable(t.x, t.y + 1):
					face = true
				if m.walkable(t.x, t.y + 1) or m.walkable(t.x, t.y - 1) or m.walkable(t.x - 1, t.y) or m.walkable(t.x + 1, t.y):
					in_sight = true
				for j in range(-2, 3):
					for i in range(-2, 3):
						var k := m.kind(t.x + i, t.y + j)
						if (k == LandMap.TIN or k == LandMap.COPPER) and not own.has(t + Vector2i(i, j)):
							other = true
			if other:
				run_together += 1
			if not in_sight:
				hidden += 1
			if face and m.base.grow(6.0).has_point(Vector2(lo + hi) / 2.0):
				base_face += 1
		_check(m.veins.size() >= 45, "%s: %d clusters of ore" % [who, m.veins.size()])
		_check(too_big == 0, "%s: no ore cluster is more than 6 tiles wide or 4 tall (%d are)" % [who, too_big])
		_check(run_together == 0, "%s: every ore cluster keeps clear of the next (%d do not)" % [who, run_together])
		_check(base_face >= 2, "%s: ore shows in a rock face of the base's hills (%d clusters)" % [who, base_face])
		_check(hidden >= 16, "%s: some ore lies hidden in the rock for the pickaxe (%d clusters)" % [who, hidden])
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
		# Heather and scrub: packed in a patch's middle (overlapping, but never two on one foot), single plants with
		# ground round them at its edge, each on its own patch (version 66, after the Overseer's review).
		var by_tile := {}
		var touching := 0
		var stacked := 0
		var astray := 0
		var packed_n := 0
		for pl in m.plants:
			var box: Rect2i = Painter.boxes[str(pl["n"])]
			var foot := Vector2i(int(pl["x"]), int(pl["y"]))
			var r := Rect2i(foot.x + box.position.x, foot.y + box.position.y, box.size.x, box.size.y)
			var key := Vector2i(foot.x >> 4, foot.y >> 4)
			var k := m.kind(key.x, key.y)
			if k != LandMap.HEATH and k != LandMap.SCRUB:
				astray += 1
			var same := 0
			for j in range(-1, 2):
				for i in range(-1, 2):
					if m.kind(key.x + i, key.y + j) == k:
						same += 1
			var packed := same >= WorldGen.PACKED_AT
			if packed:
				packed_n += 1
			for j in range(-2, 3):
				for i in range(-2, 3):
					for other: Array in by_tile.get(key + Vector2i(i, j), []):
						if packed and bool(other[2]):
							if absi(foot.x - other[1].x) < WorldGen.PACKED_GAP.x and absi(foot.y - other[1].y) < WorldGen.PACKED_GAP.y:
								stacked += 1
						elif r.intersects(other[0]):
							touching += 1
			if not by_tile.has(key):
				by_tile[key] = []
			by_tile[key].append([r, foot, packed])
		_check(touching == 0 and stacked == 0 and astray == 0 and packed_n > 0, "%s: %d heather and scrub plants, %d packed in a patch's middle with none on another's foot (%d are), none touching at the edges (%d do), all on their own patch (%d are not)" % [who, m.plants.size(), packed_n, stacked, touching, astray])
		# Scree lies against the rock, never out in the open.
		var scree := 0
		var loose := 0
		for y in range(m.region.position.y + 3, m.region.end.y - 3):
			for x in range(m.region.position.x + 3, m.region.end.x - 3):
				if m.kind(x, y) != LandMap.SCREE:
					continue
				scree += 1
				var by_rock := false
				for j in range(-2, 3):
					for i in range(-2, 3):
						if m.is_rock(x + i, y + j):
							by_rock = true
				if not by_rock:
					loose += 1
		_check(loose == 0, "%s: scree lies at the foot of the rock (%d tiles, %d of them out in the open)" % [who, scree, loose])
		if scree > 0:
			scree_worlds += 1
		# The map is not ruled: no way cuts straight across another, and the open places differ in size.
		var crossing := 0
		for i in m.links.size():
			for j in range(i + 1, m.links.size()):
				var la: Dictionary = m.links[i]
				var lb: Dictionary = m.links[j]
				if la["a"] == lb["a"] or la["a"] == lb["b"] or la["b"] == lb["a"] or la["b"] == lb["b"]:
					continue
				if Geometry2D.segment_intersects_segment(m.pockets[int(la["a"])]["at"], m.pockets[int(la["b"])]["at"], m.pockets[int(lb["a"])]["at"], m.pockets[int(lb["b"])]["at"]) != null:
					crossing += 1
		_check(crossing == 0, "%s: no two ways cross (%d do)" % [who, crossing])
		var small := 0
		var big := {1: 0, 2: 0, 3: 0}
		var over_big := 0
		for p in m.pockets:
			if str(p["site"]) != "" or bool(p["gate"]):
				continue
			var r := int(p.get("ring", 1))
			if float(p["rx"]) >= 8.0 or (bool(p["glen"]) and float(p["rx"]) > 3.4):
				big[r] += 1
			elif not bool(p["glen"]) and float(p["rx"]) < 4.3:
				small += 1
		for r in [1, 2, 3]:
			if int(big[r]) > int(WorldGen.RING[r]["big"]):
				over_big += 1
		_check(small >= 6 and over_big == 0 and int(big[1]) <= WorldGen.BIG_MOST, "%s: the open places differ in size (%d small; big ones in each ring %s, at most %d, %d and %d)" % [who, small, str(big.values()), WorldGen.RING[1]["big"], WorldGen.RING[2]["big"], WorldGen.RING[3]["big"]])
		# Life: how many places have an animal in them (counted over every world, below). The inner ring has the
		# most; farther out there are no cows and fewer hares (version 49).
		for p in m.pockets:
			if bool(p["gate"]) or str(p["site"]) != "":
				continue
			var ring := int(p.get("ring", 1))
			if ring == 1:
				places += 1
			else:
				far_places += 1
			for an in m.animals:
				if (Vector2(float(an["x"]), float(an["y"])) / 16.0).distance_to(p["at"]) < float(p.get("reach", p["rx"])) + 3.0:
					if ring == 1:
						lively += 1
					else:
						far_lively += 1
					break
	var life := float(lively) / float(maxi(places, 1))
	var far_life := float(far_lively) / float(maxi(far_places, 1))
	_check(life >= 0.22 and life <= 0.50, "an animal or two in about one open place in three in the inner ring (%d of %d, %d%%)" % [lively, places, int(life * 100.0)])
	_check(far_life >= 0.08 and far_life < life, "and fewer farther out, but some (%d of %d, %d%%)" % [far_lively, far_places, int(far_life * 100.0)])
	_check(scree_worlds >= n_seeds * 3 / 4, "most worlds have some scree (%d of %d)" % [scree_worlds, n_seeds])
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
	var kit_cols := {}
	for ramp in Painter.kit.get("palette", {}).values():
		for h in ramp:
			kit_cols[Color(str(h)).to_rgba32()] = true
	var colours := {}
	var off := 0
	for y in 256:
		for x in 256:
			var v := a.get_pixel(x, y).to_rgba32()
			colours[v] = true
			if not kit_cols.has(v):
				off += 1
	_check(off == 0 and colours.size() <= 96, "the picture uses only the kit's palette (%d colours, %d pixels off it)" % [colours.size(), off])
	# Deep rock is the dark top; the ground outside the cave is the yard or grass.
	var deep := Painter.paint(m, m.region.position.x / LandMap.CHUNK, m.region.position.y / LandMap.CHUNK)
	var dark := 0
	for y in range(0, 256, 8):
		for x in range(0, 256, 8):
			if deep.get_pixel(x, y).get_luminance() < 0.12:
				dark += 1
	_check(dark > 1000, "the heart of a hill is the dark rock top (%d of 1024 samples)" % dark)
	# Ore is never drawn as dots on the rock (Darren turned that down on 21 November): the kit holds no such sheets.
	_check(not Painter.sheets.has("ore_tin_nat") and not Painter.sheets.has("ore_copper_nat"), "no ore dots are drawn on the rock")
	# The ground answering what grows in it (concept v4, version 65): turf, texture, flower beds, plants and marks.
	LandGrow.off = true
	var plain := Painter.paint(m, cx, cy)
	LandGrow.off = false
	_check(LandGrow.ready and plain.get_data() != a.get_data(), "the ground pass (land_grow.gd) is ready and changes the picture")
	var mats := {}
	for y in range(0, 256, 2):
		for x in range(0, 256, 2):
			var cd: int = LandGrow.code_of.get(LandGrow.c32(a.get_pixel(x, y)), -1)
			if cd >= 0:
				mats[str(LandGrow.names[cd >> 4])] = true
	_check(mats.has("grass") and mats.has("earth"), "the base's chunk shows moor grass and the earth of its paths (%s)" % str(mats.keys()))
	print("      one chunk painted in %d ms" % ms)


# --- Foliage (version 66) ----------------------------------------------------------------

## Drifts of the Art builder's foliage drawn into the ground (step 2 of concept v4): on the moor's open ground round the
## base, against the wall of old tunnels (never on dug floor), the same every time, none with the lab's 0.
func _foliage() -> void:
	var m := WorldGen.make(1)
	var b := Vector2i(m.base_at / float(LandMap.CHUNK))
	LandGrow.note = true
	LandGrow.noted.clear()
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			Painter.paint(m, b.x + dx, b.y + dy)
	var moor: Array = LandGrow.noted.duplicate()
	var off := 0
	var kinds := {}
	for p in moor:
		kinds[str(p[2]).get_slice("_", 1)] = true
		if not LandGrow._turf_ground(m.kind(floori(float(p[0]) / LandGrow.T), floori(float(p[1]) / LandGrow.T))):
			off += 1
	_check(moor.size() >= 8 and kinds.size() >= 2, "foliage grows in drifts round the base (%d plants, kinds %s)" % [moor.size(), str(kinds.keys())])
	_check(off == 0, "every foliage plant stands on the moor's open ground, never on a path, water or rock (%d not)" % off)
	# The lab's 0: none.
	var fc := b if moor.is_empty() else Vector2i(int(moor[0][0]) / LandGrow.PX, int(moor[0][1]) / LandGrow.PX)
	LandGrow.FOLIAGE = 0.0
	LandGrow.noted.clear()
	var none := Painter.paint(m, fc.x, fc.y)
	var none_n := LandGrow.noted.size()
	LandGrow.FOLIAGE = 1.0
	_check(none_n == 0 and none.get_data() != Painter.paint(m, fc.x, fc.y).get_data(), "the lab's \"Drifts of foliage\" at 0 grows none")
	# Glowing fungi against the wall of old tunnels, never where somebody has dug.
	var dark: Array = []
	var dark_chunk := Vector2i(-99, -99)
	for l in m.links:
		if not bool(l["tunnel"]):
			continue
		var at: Vector2 = (m.pockets[int(l["a"])]["at"] + m.pockets[int(l["b"])]["at"]) * 0.5
		var ch := Vector2i(at / float(LandMap.CHUNK))
		LandGrow.noted.clear()
		Painter.paint(m, ch.x, ch.y)
		for p in LandGrow.noted:
			if str(p[2]).begins_with("fol_glow"):
				dark.append(p)
		if not dark.is_empty():
			dark_chunk = ch
			break
	var dark_off := 0
	for p in dark:
		if m.kind(floori(float(p[0]) / LandGrow.T), floori(float(p[1]) / LandGrow.T)) != LandMap.FLOOR:
			dark_off += 1
	_check(not dark.is_empty() and dark_off == 0, "glowing fungi grow on an old tunnel's floor (%d, %d not on floor)" % [dark.size(), dark_off])
	if dark_chunk.x > -99:
		var dug: Array = []
		for p in dark:
			var key := floori(float(p[1]) / LandGrow.T) * LandMap.SIZE + floori(float(p[0]) / LandGrow.T)
			if not m.dug.has(key):
				m.dug[key] = true
				dug.append(key)
		LandGrow.noted.clear()
		Painter.paint(m, dark_chunk.x, dark_chunk.y)
		var left := 0
		for p in LandGrow.noted:
			if m.dug.has(floori(float(p[1]) / LandGrow.T) * LandMap.SIZE + floori(float(p[0]) / LandGrow.T)):
				left += 1
		for key in dug:
			m.dug.erase(key)
		_check(left == 0, "nothing grows yet on floor that has been dug")
	LandGrow.note = false
	LandGrow.noted.clear()


# --- Ore veins ------------------------------------------------------------------------

## Ore is seams of metal through the rock (Darren, 21 and 22 November). The rules are the art thread's; these checks
## hold the game's copy of them to the art thread's own numbers, and then look at a painted world.
func _veins() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/highlands_vein_ref.json"))
	var bad := 0
	for r in ref["vmix"]:
		if Veins.vmix(int(r[0]), int(r[1]), int(r[2]), int(r[3])) != int(r[4]):
			bad += 1
	for r in ref["rng"]:
		var dice := Veins.Rng.new(int(r["key"]))
		for v in r["next"]:
			if dice.next() != int(v):
				bad += 1
		dice = Veins.Rng.new(int(r["key"]))
		for v in r["below_100"]:
			if dice.below(100) != int(v):
				bad += 1
		dice = Veins.Rng.new(int(r["key"]))
		for v in r["between_5_8"]:
			if dice.between(5, 8) != int(v):
				bad += 1
	_check(bad == 0, "the veins' hash and dice give the art thread's numbers (%d wrong)" % bad)
	bad = 0
	var pixels := 0
	for c in ref["clusters"]:
		var cells: Array = []
		for t in c["cells"]:
			cells.append(Vector2i(int(t[0]), int(t[1])))
		var out := Veins.paths(cells, Veins.TIN if c["kind"] == "tin" else Veins.COPPER, int(c["seed"]))
		var px: Dictionary = out["px"]
		var want := {}
		for p in c["pixels"]:
			want[Vector2i(int(p[0]), int(p[1]))] = int(p[2])
		pixels += want.size()
		for p in want:
			if int(px.get(p, 0)) != int(want[p]):
				bad += 1
		for p in px:
			if not want.has(p):
				bad += 1
		var pockets: Array = []
		for p in c["pockets"]:
			pockets.append(Vector2i(int(p[0]), int(p[1])))
		if pockets != out["pockets"]:
			bad += 1
		var again := Veins.paths(cells, Veins.TIN if c["kind"] == "tin" else Veins.COPPER, int(c["seed"]))
		if again["px"] != px:
			bad += 1
	_check(bad == 0 and pixels > 500, "every seam pixel of the art thread's four test clusters comes out the same (%d pixels, %d wrong)" % [pixels, bad])
	bad = 0
	var names := {"tin": Veins.M_METAL, "copper": Veins.M_METAL, "verd": Veins.M_VERD, "face": Veins.M_FACE, "cap": Veins.M_CAP}
	for s in ref["steps"]:
		var got := Veins.step(int(s[0]), Veins.TIN if s[1] == "tin" else Veins.COPPER, int(s[2]) != 0, int(s[3]), int(s[4]), int(s[5]))
		var want := -1 if s[6] == null else int(names[s[6]]) * 8 + int(s[7])
		if got != want:
			bad += 1
	_check(bad == 0 and (ref["steps"] as Array).size() > 200, "a seam pixel takes the colour the art thread gives it (%d cases, %d wrong)" % [(ref["steps"] as Array).size(), bad])
	# How far in from the edge of the rock's top: the quick way gives what the art thread's way of wearing the top away gives.
	var side := 96
	var top := PackedByteArray()
	top.resize(side * side)
	for y in side:
		for x in side:
			var open := Vector2(x - 14, y - 10).length() < 9.0 or Vector2(x - 84, y - 80).length() < 13.0 or (absi(x - 26 - (y - 62) / 3) < 2 and y > 62 and y < 86) or (x == 70 and y == 9)
			top[y * side + x] = 0 if open else 1
	var worn := top.duplicate()
	var deep := PackedByteArray()
	deep.resize(side * side)
	for round in 21:
		var next := worn.duplicate()
		for y in range(1, side - 1):
			for x in range(1, side - 1):
				var i := y * side + x
				if worn[i] == 0:
					continue
				var stays := worn[i - 1] == 1 and worn[i + 1] == 1 and worn[i - side] == 1 and worn[i + side] == 1
				if stays and round % 2 == 1:
					stays = worn[i - side - 1] == 1 and worn[i - side + 1] == 1 and worn[i + side - 1] == 1 and worn[i + side + 1] == 1
				if not stays:
					next[i] = 0
		worn = next
		for i in side * side:
			deep[i] += worn[i]
	bad = 0
	var measured := 0
	var deepest := 0
	for y in range(23, side - 23):
		for x in range(23, side - 23):
			if top[y * side + x] == 0:
				continue
			measured += 1
			deepest = maxi(deepest, deep[y * side + x])
			if Veins.depth(top, side, side, x, y) != deep[y * side + x]:
				bad += 1
			if Veins.depth(top, side, side, x, y, 12) != mini(deep[y * side + x], 12):
				bad += 1
	_check(bad == 0 and measured > 300 and deepest >= 15, "how far a seam pixel lies in from the edge of the rock's top is measured as the art does (%d pixels, %d wrong)" % [measured, bad])
	# The colours are the art's own ramps, from the kit.
	_check(Painter.vein_cols.has("tin") and Painter.vein_cols.has("copper") and (Painter.vein_cols["tin"] as Array).size() >= 5 and (Painter.vein_cols["copper"] as Array).size() >= 6, "the kit holds the ore's colours")
	var ore_colours := {}
	for name in Painter.vein_cols:
		for c: Color in Painter.vein_cols[name]:
			ore_colours[c.to_rgba32()] = true
	# In a world: a cluster in a rock face shows as a seam, in rock only, in the ore's colours, and down the face.
	var m := WorldGen.make(77)
	var shown := 0
	var stray := 0
	var odd := 0
	var off_rock := 0
	var on_face := 0
	var on_top := 0
	var unsteady := 0
	var looked := 0
	for v in m.veins:
		var face := false
		for t: Vector2i in v["cells"]:
			if m.walkable(t.x, t.y + 1):
				face = true
		if not face or looked >= 3:
			continue
		looked += 1
		var box: Rect2i = v["box"]
		for cy in range(box.position.y / 256, (box.end.y - 1) / 256 + 1):
			for cx in range(box.position.x / 256, (box.end.x - 1) / 256 + 1):
				var with := Painter.paint(m, cx, cy)
				if with.get_data() != Painter.paint(m, cx, cy).get_data():
					unsteady += 1
				var keep: Dictionary = m._lumps_by_chunk
				m._lumps_by_chunk = {}
				var without := Painter.paint(m, cx, cy)
				m._lumps_by_chunk = keep
				var parts := Painter.rock_parts(m, cx * 16, cy * 16, 16, 16)
				var on_seam := {}
				for o in m.veins_in(cx, cy):
					for p: Vector2i in o["px"]:
						on_seam[p] = true
				for y in 256:
					for x in 256:
						var c := with.get_pixel(x, y)
						if c == without.get_pixel(x, y):
							continue
						shown += 1
						if not on_seam.has(Vector2i(cx * 256 + x, cy * 256 + y)):
							stray += 1
						if not ore_colours.has(c.to_rgba32()):
							odd += 1
						var part := parts.get_pixel(x, y)
						if part.a < 0.5:
							off_rock += 1
						elif part.r > 0.5:
							on_face += 1
						else:
							on_top += 1
	_check(looked >= 1 and shown >= 30, "ore in a rock face shows as a seam (%d pixels of %d clusters)" % [shown, looked])
	_check(stray == 0 and off_rock == 0 and odd == 0, "a seam is drawn in rock only, on its own pixels, in the ore's own colours (%d astray, %d off the rock, %d in another colour)" % [stray, off_rock, odd])
	_check(on_face >= 8 and on_top >= 8, "a seam crosses the rock's top and runs down its lit face (%d and %d pixels)" % [on_top, on_face])
	_check(unsteady == 0, "painting a chunk with ore in it twice gives the same picture")
	# The heart of a hill is fog of war: ore with nothing but rock round it shows nothing at all.
	var buried := 0
	var seen := 0
	for v in m.veins:
		var sealed := true
		for t: Vector2i in v["cells"]:
			for j in range(-3, 5):
				for i in range(-3, 4):
					if not m.is_rock(t.x + i, t.y + j):
						sealed = false
		if not sealed or buried >= 3:
			continue
		buried += 1
		var box: Rect2i = v["box"]
		for cy in range(box.position.y / 256, (box.end.y - 1) / 256 + 1):
			for cx in range(box.position.x / 256, (box.end.x - 1) / 256 + 1):
				var with := Painter.paint(m, cx, cy)
				for p: Vector2i in v["px"]:
					var q := p - Vector2i(cx * 256, cy * 256)
					if q.x >= 0 and q.y >= 0 and q.x < 256 and q.y < 256 and with.get_pixel(q.x, q.y).get_luminance() > 0.14:
						seen += 1
	_check(buried >= 1 and seen == 0, "ore deep in a hill shows nothing until somebody digs near (%d clusters, %d pixels seen)" % [buried, seen])
	# Whichever patch of rock is asked for, a pixel is the same part of the rock: so a seam never changes at a chunk's edge.
	var at: Vector2i = m.mouth - Vector2i(5, 4)
	var one := Painter.rock_parts(m, at.x, at.y, 8, 8)
	var two := Painter.rock_parts(m, at.x + 3, at.y + 2, 8, 8)
	var differ := 0
	for y in range(0, 6 * 16):
		for x in range(0, 5 * 16):
			if one.get_pixel(x + 48, y + 32) != two.get_pixel(x, y):
				differ += 1
	_check(differ == 0, "the rock is the same rock whichever patch of it is asked for (%d pixels differ)" % differ)
	# Digging towards ore brings it out: open the ground under a buried cluster and its seam shows.
	for v in m.veins:
		var sealed := true
		var low := Vector2i(0, -1)
		for t: Vector2i in v["cells"]:
			if t.y > low.y:
				low = t
			for j in range(-3, 5):
				for i in range(-3, 4):
					if not m.is_rock(t.x + i, t.y + j):
						sealed = false
		if not sealed:
			continue
		var cx := (low.x * 16 + 8) / 256
		var cy := (low.y * 16 + 8) / 256
		var before := Painter.paint(m, cx, cy)
		for j in range(1, 3):
			for i in range(-1, 2):
				m.set_kind(low.x + i, low.y + j, LandMap.FLOOR)
		var after := Painter.paint(m, cx, cy)
		var lit := 0
		for p: Vector2i in v["px"]:
			var q := p - Vector2i(cx * 256, cy * 256)
			if q.x >= 0 and q.y >= 0 and q.x < 256 and q.y < 256 and ore_colours.has(after.get_pixel(q.x, q.y).to_rgba32()) and after.get_pixel(q.x, q.y) != before.get_pixel(q.x, q.y):
				lit += 1
		_check(lit >= 4, "digging in under hidden ore brings its seam out (%d pixels)" % lit)
		break


# --- The game -------------------------------------------------------------------------

func _game(seed_value: int, players := 1, carry := {}):
	var g = Highlands.new()
	var inputs: Array = []
	for i in players:
		inputs.append(PlayerInput.make("script"))
	g.inputs = inputs
	g.world_seed = seed_value
	g.with_foes = false
	g.carry = carry
	g.welcome = false
	root.add_child(g)
	return g


# --- The light (version 68) -----------------------------------------------------------------

## Step 3 of the new look (the Art builder's light concept): daylight in the open, dark under the hill in three steps,
## lamps lighting pools that the rock's top stops, a lab switch for day and night.
func _light() -> void:
	var m := WorldGen.make(1)
	m.index()
	# A tunnel deep under the hill: its middle is dark, the open land round the base is not.
	var deep := Vector2i(-1, -1)
	for l in m.links:
		if not bool(l["tunnel"]):
			continue
		var a: Vector2 = m.pockets[int(l["a"])]["at"]
		var b: Vector2 = m.pockets[int(l["b"])]["at"]
		for k in range(1, 40):
			var t := Vector2i(a.lerp(b, float(k) / 40.0))
			if m.kind(t.x, t.y) != LandMap.FLOOR:
				continue
			var near_open := false
			for dj in range(-5, 6):
				for di in range(-5, 6):
					var kk := m.kind(t.x + di, t.y + dj)
					near_open = near_open or (not LandMap.rocky(kk) and kk != LandMap.FLOOR)
			if not near_open:
				deep = t
				break
		if deep.x >= 0:
			break
	_check(deep.x >= 0, "a tunnel runs more than five tiles from open ground somewhere")
	var d := LandLight.make(m, floori(float(deep.x) / LandMap.CHUNK), floori(float(deep.y) / LandMap.CHUNK), [])
	var o: Vector2 = d["origin"]
	var t0 := (deep.y - floori(o.y / 16.0) + LandLight.PADT) * LandLight.W + deep.x - floori(o.x / 16.0) + LandLight.PADT
	_check(float(d["dark"][t0]) > 0.99, "the middle of a tunnel far from open ground is as dark as it gets (%.2f)" % float(d["dark"][t0]))
	var base := Vector2i(m.base_at)
	var bd := LandLight.make(m, floori(float(base.x) / LandMap.CHUNK), floori(float(base.y) / LandMap.CHUNK), [])
	var bo: Vector2 = bd["origin"]
	var bt := (base.y - floori(bo.y / 16.0) + LandLight.PADT) * LandLight.W + base.x - floori(bo.x / 16.0) + LandLight.PADT
	_check(float(bd["dark"][bt]) == 0.0, "the base's clearing is open land, not dark")
	# The light there: dark away from lamps, but never black; full by a lamp; daylight in the open.
	LandLight.night = 0.0
	var at := Vector2(deep) * 16.0 + Vector2(8, 8)
	var lamps := LandLight.lamps_now(d)
	var c := LandLight.sample(d, lamps, at)
	var lit_by_lamp := false
	for l in lamps:
		if l.z > 0.0 and Vector2(l.x, l.y).distance_to(at - o) < l.z:
			lit_by_lamp = true
	if not lit_by_lamp:
		_check(c.r < 0.5 and c.r >= 0.2, "a tunnel's floor away from its lamps is dark, not black (%.2f)" % c.r)
	var by_lamp := Color.BLACK
	var lamp_at := Vector2.ZERO
	for l in m.lamps:
		var lp := Vector2(float(l["x"]), float(l["y"]))
		if m.kind(int(lp.x) / 16, int(lp.y) / 16) == LandMap.FLOOR:
			var ld := LandLight.make(m, int(lp.x) / 256, int(lp.y) / 256, [])
			by_lamp = LandLight.sample(ld, LandLight.lamps_now(ld), lp + Vector2(0, 4))
			lamp_at = lp
			break
	_check(by_lamp.r > 0.95, "beside a lantern the floor is in full light (%.2f)" % by_lamp.r)
	var open := LandLight.sample(bd, LandLight.lamps_now(bd), Vector2(base) * 16.0 + Vector2(8, 8))
	_check(open.r > 0.99 and open.b > 0.99, "out in the open it is daylight, and the land looks as it is painted")
	# The rock's top stops a lamp's light: a wall of rock between a lamp and a point leaves it dark.
	var rock := PackedByteArray()
	rock.resize(LandLight.W * LandLight.W)
	for j in LandLight.W:
		rock[j * LandLight.W + 18] = 2
	var flat := PackedFloat32Array()
	flat.resize(LandLight.W * LandLight.W)
	flat.fill(1.0)
	var fake := {"origin": Vector2.ZERO, "dark": flat, "snow": PackedFloat32Array(flat).duplicate(), "rock": rock}
	(fake["snow"] as PackedFloat32Array).fill(0.0)
	var one := PackedVector4Array([Vector4(150, 100, 60, 1.0)])
	var near_side := LandLight.sample(fake, one, Vector2(160, 100))
	var far_side := LandLight.sample(fake, one, Vector2(185, 100))
	_check(near_side.r > 0.9 and far_side.r < 0.5, "the rock's top stops a lamp's light (this side %.2f, behind the rock %.2f)" % [near_side.r, far_side.r])
	# Nobody is ever drawn darker than ACTOR_MIN, however dark it is.
	var t := LandLight.actor_tint(Color(0.0, 0.0, 0.0))
	_check(t.r >= LandLight.ACTOR_MIN and t.g >= LandLight.ACTOR_MIN and t.b >= LandLight.ACTOR_MIN, "nobody is drawn darker than %.2f in the dark" % LandLight.ACTOR_MIN)
	# Ore on a lit face shines, and fungi glow: what glows is in the chunk's light.
	var glows := 0
	for l in m.links:
		if glows > 0:
			break
		if not bool(l["tunnel"]):
			continue
		var a: Vector2 = m.pockets[int(l["a"])]["at"]
		var b: Vector2 = m.pockets[int(l["b"])]["at"]
		for k in range(0, 20):
			var q := Vector2i(a.lerp(b, float(k) / 20.0))
			if not LandGrow.glow_spots(m, q.x - 8, q.y - 8, q.x + 8, q.y + 8).is_empty():
				var gd := LandLight.make(m, q.x / 16, q.y / 16, [])
				glows += 1 if gd["glow"] != null else 0
				break
	_check(glows > 0, "the glowing fungi of the old tunnels glow")
	var ore: Array = []
	var od := {}
	var tried := {}
	for v in m.veins:
		if not ore.is_empty():
			break
		for cell: Vector2i in v["cells"]:
			var ck := Vector2i(cell.x / 16, cell.y / 16)
			if not m.walkable(cell.x, cell.y + 1) or tried.has(ck):
				continue
			tried[ck] = true
			Painter.paint(m, ck.x, ck.y, ore)
			if not ore.is_empty():
				od = LandLight.make(m, ck.x, ck.y, ore)
				break
	var shine := 0
	if not od.is_empty() and od["glow"] != null:
		for e: Vector3i in ore:
			if (od["glow"] as Image).get_pixel(e.x, e.y).r > 0.99:
				shine += 1
	_check(not ore.is_empty() and shine == ore.size(), "ore on a lit face of rock shines in its own colour (%d of %d)" % [shine, ore.size()])
	# The Scrapyard's rooms are no darker than one step: its fights must read.
	var yard: Rect2i = m.sites["scrapyard"]["rect"]
	var yc := yard.get_center()
	var yd := LandLight.make(m, yc.x / 16, yc.y / 16, [])
	var worst := 0.0
	var yo: Vector2 = yd["origin"]
	for j in LandLight.W:
		for i in LandLight.W:
			var tile := Vector2i(floori(yo.x / 16.0) + i - LandLight.PADT, floori(yo.y / 16.0) + j - LandLight.PADT)
			if yard.has_point(tile):
				worst = maxf(worst, float(yd["dark"][j * LandLight.W + i]))
	_check(worst <= LandLight.YARD_DIM + 0.001, "the Scrapyard's rooms grow no darker than one step (%.2f)" % worst)
	# Day and night: always day unless the lab says so; then six tenths day, a tenth dusk, two night, a tenth dawn.
	_check(LandLight.CYCLE == 0, "day and night does not go round unless the lab says so")
	LandLight.night = 0.5
	LandLight.tick(1.0)
	_check(LandLight.night == 0.0, "with the lab's day and night off it is always day")
	_check(LandLight.night_at(0.3) == 0.0 and LandLight.night_at(0.8) == 1.0 and LandLight.night_at(0.65) == 0.5 and LandLight.night_at(0.95) == 0.5, "a day is day, dusk, night and dawn")
	LandLight.CYCLE = 1
	LandLight.clock = 0.0
	LandLight.tick(LandLight.DAY_MINUTES * 60.0 * 0.8)
	_check(LandLight.night == 1.0, "with the lab's day and night on, night falls (%.2f)" % LandLight.night)
	LandLight.CYCLE = 0
	LandLight.reset()


## In the game: the land is drawn through the light, things and everybody take it, and the boss and the HUD do not.
func _light_in_game() -> void:
	var g = _game(1, 1)
	await _frames(20)
	var shaded := 0
	var all := 0
	for key in g.land.chunks:
		var c: Dictionary = g.land.chunks[key]
		if c["sprite"] != null:
			all += 1
			if c["sprite"].material is ShaderMaterial and c.has("light"):
				shaded += 1
	_check(all > 0 and shaded == all, "every painted chunk is drawn through the light (%d of %d)" % [shaded, all])
	# Down a dark tunnel, the player is tinted but never darker than ACTOR_MIN.
	var m: LandMap = g.map
	var dark_at := Vector2.ZERO
	for l in m.links:
		if dark_at != Vector2.ZERO:
			break
		if not bool(l["tunnel"]):
			continue
		var a: Vector2 = m.pockets[int(l["a"])]["at"]
		var b: Vector2 = m.pockets[int(l["b"])]["at"]
		for k in range(1, 40):
			var t := Vector2i(a.lerp(b, float(k) / 40.0))
			if m.kind(t.x, t.y) != LandMap.FLOOR:
				continue
			var near_open := false
			for dj in range(-5, 6):
				for di in range(-5, 6):
					var kk := m.kind(t.x + di, t.y + dj)
					near_open = near_open or (not LandMap.rocky(kk) and kk != LandMap.FLOOR)
			for lamp in m.lamps:
				near_open = near_open or Vector2(float(lamp["x"]), float(lamp["y"])).distance_to(Vector2(t) * 16.0 + Vector2(8, 8)) < float(lamp["r"]) + 24.0
			if not near_open:
				dark_at = (Vector2(t) + Vector2(0.5, 0.5)) * 32.0
				break
	var p = g.players[0]
	p.global_position = dark_at
	g.rig.snap()
	await _frames(6)
	g.land.settle()
	await _frames(6)
	var sm: Color = p.self_modulate
	_check(sm.r < 0.999 and sm.r >= LandLight.ACTOR_MIN - 0.001 and sm.g >= LandLight.ACTOR_MIN - 0.001, "down a dark tunnel the player is a little darker, never under %.2f (%s)" % [LandLight.ACTOR_MIN, str(sm)])
	var lantern_ok := true
	for key in g.land.chunks:
		for s in g.land.chunks[key]["things"]:
			if str(s.get_meta("land", "")) == "lantern" and s.modulate.r < 0.999:
				lantern_ok = false
	_check(lantern_ok, "a lantern is a light itself and is never dimmed")
	var there: Color = g.land.light_at(dark_at + Vector2(0, 40))
	_check(there.r < 0.5, "what stands down there takes the dark (%.2f)" % there.r)
	# Night (held, as the lab's day and night would bring it): the open land and its things go blue-violet.
	p.global_position = (m.spawn + Vector2(0, 3.5)) * 32.0
	g.rig.snap()
	await _frames(6)
	g.land.settle()
	LandLight.fixed = 1.0
	await _frames(30)
	var bluish := 0
	var outdoors := 0
	for key in g.land.chunks:
		for s in g.land.chunks[key]["things"]:
			if str(s.get_meta("land", "")) != "lantern" and g.rig.view_rect().has_point(s.position):
				outdoors += 1
				if s.modulate.b > s.modulate.r + 0.1:
					bluish += 1
	_check(outdoors > 0 and bluish * 2 > outdoors, "at night the things on the open land take the night's blue-violet (%d of %d)" % [bluish, outdoors])
	var mat: ShaderMaterial = null
	for key in g.land.chunks:
		if g.land.chunks[key]["sprite"] != null:
			mat = g.land.chunks[key]["sprite"].material
			break
	_check(mat != null and float(mat.get_shader_parameter("night")) == 1.0, "the land's shader hears that it is night")
	_check(p.self_modulate.r >= LandLight.ACTOR_MIN - 0.001, "at night the player is still drawn at %.2f or brighter" % LandLight.ACTOR_MIN)
	LandLight.fixed = -1.0
	g.queue_free()
	await _frames(3)
	_check(LandLight.extra.is_empty() and LandLight.night == 0.0, "leaving the Highlands takes their lights with them")


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
	_check(g.hall.is_open and not g.build_menu.is_open, "using the cave mouth opens the forge's screen (version 45: levels and role trees)")
	g.hall.row = 2
	g.hall.confirm()
	_check(not g.hall.is_open and g.build_menu.is_open, "and WEAPONS AND RUNES there opens the weapon forge")
	g.build_menu.close()
	await _frames(3)
	_check(not paused, "(the game goes on after)")
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
	first.ui.card("The Greystone Highlands", first.welcome_text())
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
	# The middle and outer rings' named places (version 49).
	for site in ["roost", "den", "cairns", "gorge", "fault", "scrapyard"]:
		if m.sites.has(site) and m.sites[site].get("at") != null:
			views[site] = Vector2(m.sites[site]["at"])
	if m.sites.has("fault") and m.sites["fault"].has("line"):
		var line: Array = m.sites["fault"]["line"]
		views["fault_crack"] = (Vector2(line[0]) + Vector2(line[1])) * 0.5
	var n := 0
	for p in m.pockets:
		if bool(p["gate"]) or bool(p["sealed"]) or str(p["site"]) != "":
			continue
		var ring := int(p.get("ring", 1))
		if ring == 2 and not views.has("middle_ring") and float(p["rx"]) >= 5.0:
			views["middle_ring"] = p["at"]
		if ring == 3 and not views.has("outer_ring") and float(p["rx"]) >= 5.0:
			views["outer_ring"] = p["at"]
		if ring != 1:
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
	# Ore in a rock face, away from the base: one of tin and one of copper.
	for v in m.veins:
		var middle := Vector2((v["box"] as Rect2i).get_center()) / 16.0
		var face := false
		for t: Vector2i in v["cells"]:
			if m.walkable(t.x, t.y + 1):
				face = true
		var name := "tin" if int(v["kind"]) == Veins.TIN else "copper"
		if face and middle.distance_to(m.spawn) > 24.0 and not views.has(name):
			views[name] = middle + Vector2(-3.0, 5.0)
	# The light (version 68): a lantern-lit tunnel far from open ground, and ore on a face in the dark.
	for l in m.lamps:
		var lt := Vector2(float(l["x"]), float(l["y"])) / 16.0
		if lt.distance_to(m.spawn) > 30.0 and m.kind(int(lt.x), int(lt.y)) == LandMap.FLOOR:
			views["light_lantern_tunnel"] = lt + Vector2(0, 1)
			break
	for v in m.veins:
		if views.has("light_ore_in_the_dark"):
			break
		for t: Vector2i in v["cells"]:
			if m.kind(t.x, t.y + 1) != LandMap.FLOOR or Vector2(t).distance_to(m.spawn) < 24.0:
				continue
			var deep := true
			for dj in range(-3, 4):
				for di in range(-3, 4):
					var kk := m.kind(t.x + di, t.y + dj)
					deep = deep and (LandMap.rocky(kk) or kk == LandMap.FLOOR)
			if deep:
				views["light_ore_in_the_dark"] = Vector2(t) + Vector2(0.5, 2.5)
				break
	for name in views:
		await _shot(g, m, name, views[name])
	# And night, as the lab's day and night brings it.
	LandLight.fixed = 1.0
	for name in ["base", "roost", "den", "light_lantern_tunnel"]:
		if views.has(name):
			await _shot(g, m, "night_" + name, views[name])
	LandLight.fixed = -1.0


func _shot(g, m: LandMap, name: String, tile: Vector2) -> void:
	var at := _stand_near(m, tile)
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
