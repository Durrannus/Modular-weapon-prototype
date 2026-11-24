extends SceneTree
## Draws the whole map of generated Highlands worlds, one picture a seed, and
## prints what each holds. For checking the generator by eye.
##
##   godot --headless --path . -s tools/highlands_overview.gd -- out=/tmp/maps seeds=1,2,3 scale=4
##
## Rock is dark (lighter where it meets open ground), grass ochre, footpaths pale,
## dug floor slate, water teal, tin white, copper orange. Dots are things: green a
## tree, grey a boulder or stone, brown an animal, yellow a lantern. A red ring
## marks a place that is sealed, a white ring a named place. Dashed blue circles are
## where the rings end, yellow lines the passes through the belts of rock between
## them, and the white box is the Scrapyard's block.

const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")


func _init() -> void:
	var out := "/tmp/highlands_maps"
	var seeds: Array = [1, 2, 3]
	var scale := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("seeds="):
			seeds = []
			for s in a.substr(6).split(","):
				seeds.append(int(s))
		elif a.begins_with("scale="):
			scale = int(a.substr(6))
	DirAccess.make_dir_recursive_absolute(out)
	for s in seeds:
		var t0 := Time.get_ticks_msec()
		var m: LandMap = WorldGen.make(int(s))
		var ms := Time.get_ticks_msec() - t0
		var sealed := 0
		for p in m.pockets:
			if bool(p["sealed"]):
				sealed += 1
		var tunnels := 0
		for l in m.links:
			if bool(l["tunnel"]):
				tunnels += 1
		print("seed %d: %d ms, layout %d, %d open places (%d sealed), %d ways (%d tunnels), open land %d%%, %d things, %d animals, %d lamps" % [
			int(s), ms, m.tries, m.pockets.size(), sealed, m.links.size(), tunnels, int(round(m.open_share(28.0, WorldGen.RING_INNER - 4.0) * 100.0)), m.things.size(), m.animals.size(), m.lamps.size()])
		# Ring by ring: how many places, how many of them sealed, long ones (glens), how much of the ring is open, and its ore.
		for ring in [1, 2, 3]:
			var n := 0
			var shut := 0
			var glens := 0
			for p in m.pockets:
				if int(p.get("ring", 1)) == ring:
					n += 1
					shut += 1 if bool(p["sealed"]) else 0
					glens += 1 if bool(p["glen"]) else 0
			var r0: float = WorldGen.RINGS[ring - 1] + 4.0
			var r1: float = WorldGen.RINGS[ring] - 4.0
			var tin := 0
			var copper := 0
			for v in m.veins:
				var c: Vector2i = v["cells"][0]
				var d := Vector2(c.x - LandMap.MID, c.y - LandMap.MID).length()
				if d >= WorldGen.RINGS[ring - 1] and d < WorldGen.RINGS[ring]:
					if int(v["kind"]) == LandMap.Veins.TIN:
						tin += 1
					else:
						copper += 1
			var passes := 0
			for l in m.links:
				if l.has("pass") and maxi(int(m.pockets[int(l["a"])]["ring"]), int(m.pockets[int(l["b"])]["ring"])) == ring:
					passes += 1
			print("   ring %d: %d places (%d sealed, %d long), %d%% open, %d tin and %d copper clusters, %d ways in through the belt" % [ring, n, shut, glens,
				int(round(m.open_share(r0, r1) * 100.0)), tin, copper, passes])
		var names := []
		for name in m.sites:
			var at: Vector2 = m.sites[name]["at"]
			names.append("%s %d" % [name, int(at.distance_to(Vector2(LandMap.MID, LandMap.MID)))])
		print("   named places, and how far from the cave: ", ", ".join(names))
		picture(m, scale).save_png("%s/map_%d.png" % [out, int(s)])
	quit()


static func picture(m: LandMap, scale: int) -> Image:
	var r := m.region
	var img := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGB8)
	var cols := {LandMap.GRASS: Color("a68e52"), LandMap.SCRUB: Color("6f8f84"), LandMap.HEATH: Color("8a5272"), LandMap.PATH: Color("dcc888"),
		LandMap.YARD: Color("6a5642"), LandMap.WATER: Color("2f7d86"), LandMap.TIN: Color("f6f0d4"), LandMap.COPPER: Color("e0803c"), LandMap.FLOOR: Color("3c5262"), LandMap.SCREE: Color("8f8a6a")}
	for y in r.size.y:
		for x in r.size.x:
			var wx := x + r.position.x
			var wy := y + r.position.y
			var k := m.kind(wx, wy)
			var c: Color
			if k == LandMap.ROCK:
				var edge := not m.is_rock(wx, wy + 1) or not m.is_rock(wx, wy - 1) or not m.is_rock(wx - 1, wy) or not m.is_rock(wx + 1, wy)
				c = Color("5a6c78") if edge else Color("201b34")
			else:
				c = cols[k]
				if k == LandMap.GRASS:
					c = [Color("8a7448"), Color("a68e52"), Color("c2aa64")][m.tone(wx, wy)]
			img.set_pixel(x, y, c)
	img.resize(r.size.x * scale, r.size.y * scale, Image.INTERPOLATE_NEAREST)
	var dot := func(px: Vector2, c: Color, rad: int) -> void:
		for j in range(-rad, rad + 1):
			for i in range(-rad, rad + 1):
				var q := Vector2i(int(px.x) + i, int(px.y) + j)
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixelv(q, c)
	var ring := func(px: Vector2, rad: float, c: Color) -> void:
		for a in 180:
			var q := Vector2i(px + Vector2(cos(a * TAU / 180.0), sin(a * TAU / 180.0)) * rad)
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
				img.set_pixelv(q, c)
	var to_px := func(tile: Vector2) -> Vector2:
		return (tile - Vector2(r.position)) * float(scale)
	for t in m.things:
		var n := str(t["n"])
		var c := Color("2f6a4a") if n.begins_with("pine") or n.begins_with("bush") or n.begins_with("bracken") or n.begins_with("reeds") or n.begins_with("cotton") else Color("c8c8c8")
		if n == "lantern":
			c = Color("ffd24a")
		dot.call(to_px.call(Vector2(float(t["x"]), float(t["y"])) / 16.0), c, 1 if scale >= 4 else 0)
	for a in m.animals:
		dot.call(to_px.call(Vector2(float(a["x"]), float(a["y"])) / 16.0), Color("7a3a1a"), 1 if scale >= 4 else 0)
	for d in m.decals:
		dot.call(to_px.call(Vector2(float(d["x"]), float(d["y"])) / 16.0), Color("9fb0b0"), 1 if scale >= 4 else 0)
	for p in m.pockets:
		if bool(p["sealed"]):
			ring.call(to_px.call(p["at"]), 5.0 * scale, Color("ff3030"))
		if str(p["site"]) != "":
			ring.call(to_px.call(p["at"]), 9.0 * scale, Color.WHITE)
			ring.call(to_px.call(p["at"]), 9.0 * scale + 1.0, Color.WHITE)
	# Where the rings end (faint), the passes through the belts (yellow), the Scrapyard's block (white).
	var mid := Vector2(LandMap.MID + 0.5, LandMap.MID + 0.5)
	for k in range(1, WorldGen.RINGS.size()):
		for a in 1440:
			var q := Vector2i(to_px.call(mid + Vector2(cos(a * TAU / 1440.0), sin(a * TAU / 1440.0)) * float(WorldGen.RINGS[k])))
			if a % 4 < 2 and q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
				img.set_pixelv(q, Color("4a6a9a"))
	for l in m.links:
		if l.has("pass"):
			var a: Vector2 = to_px.call(m.pockets[int(l["a"])]["at"])
			var b: Vector2 = to_px.call(m.pockets[int(l["b"])]["at"])
			for t in 60:
				dot.call(a.lerp(b, float(t) / 59.0), Color("ffe040"), 0)
	if m.sites.has("scrapyard"):
		var block: Rect2i = m.sites["scrapyard"]["rect"]
		for x in range(block.position.x, block.end.x):
			dot.call(to_px.call(Vector2(x, block.position.y)), Color.WHITE, 0)
			dot.call(to_px.call(Vector2(x, block.end.y - 1)), Color.WHITE, 0)
		for y in range(block.position.y, block.end.y):
			dot.call(to_px.call(Vector2(block.position.x, y)), Color.WHITE, 0)
			dot.call(to_px.call(Vector2(block.end.x - 1, y)), Color.WHITE, 0)
	dot.call(to_px.call(m.spawn), Color("ff40ff"), 2)
	return img
