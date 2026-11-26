extends SceneTree
## Pictures of a generated Highlands world drawn the way the game draws it (the
## land painter, then the things standing on it), without running the game.
## For checking the look quickly; real screenshots come from tests/highlands_shots.gd.
##
##   godot --headless --path . -s tools/highlands_shots.gd -- seed=1 out=/tmp/shots views=base,pocket,tunnel,quarry,watchpost
##   ... at=280,300 size=40x23      (a picture centred on that tile)

const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")


func _init() -> void:
	var out := "/tmp/highlands_shots"
	var seed_value := 1
	var views: Array = ["base"]
	var size := Vector2i(40, 23)
	var at := Vector2(-1, -1)
	var scale := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("seed="):
			seed_value = int(a.substr(5))
		elif a.begins_with("views="):
			views = Array(a.substr(6).split(","))
		elif a.begins_with("size="):
			size = Vector2i(int(a.substr(5).split("x")[0]), int(a.substr(5).split("x")[1]))
		elif a.begins_with("at="):
			at = Vector2(float(a.substr(3).split(",")[0]), float(a.substr(3).split(",")[1]))
			views = ["at"]
		elif a.begins_with("scale="):
			scale = int(a.substr(6))
	DirAccess.make_dir_recursive_absolute(out)
	var m: LandMap = WorldGen.make(seed_value)
	var t0 := Time.get_ticks_msec()
	var n := 0
	for v in views:
		var c := at
		match str(v):
			"base":
				c = m.base_at
			"quarry":
				c = m.sites["quarry"]["at"]
			"watchpost":
				c = m.sites["watchpost"]["at"]
			"tunnel":
				for l in m.links:
					if bool(l["tunnel"]):
						c = (m.pockets[int(l["a"])]["at"] + m.pockets[int(l["b"])]["at"]) * 0.5
						break
			"pocket", "pocket2", "pocket3":
				var want := 6 if v == "pocket" else (12 if v == "pocket2" else 20)
				c = m.pockets[mini(want, m.pockets.size() - 1)]["at"]
			"tarn":
				for p in m.pockets:
					if p.has("tarn"):
						c = p["at"]
						break
			"sealed":
				for p in m.pockets:
					if bool(p["sealed"]):
						c = p["at"]
						break
		var img := picture(m, c, size)
		n += 1
		if scale > 1:
			img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/seed%d_%s.png" % [out, seed_value, str(v)])
	print("%d pictures in %d ms" % [n, Time.get_ticks_msec() - t0])
	quit()


## The land round tile `c`, `size` tiles across, with everything that stands on it.
static func picture(m: LandMap, c: Vector2, size: Vector2i) -> Image:
	Painter.load_kit()
	var px0 := int(c.x * 16.0) - size.x * 8
	var py0 := int(c.y * 16.0) - size.y * 8
	var w := size.x * 16
	var h := size.y * 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c0 := Vector2i(floori(px0 / 256.0), floori(py0 / 256.0))
	var c1 := Vector2i(floori((px0 + w - 1) / 256.0), floori((py0 + h - 1) / 256.0))
	var stand: Array = []
	for cy in range(c0.y - 1, c1.y + 2):
		for cx in range(c0.x - 1, c1.x + 2):
			if cx >= c0.x and cx <= c1.x and cy >= c0.y and cy <= c1.y:
				img.blit_rect(Painter.paint(m, cx, cy), Rect2i(0, 0, 256, 256), Vector2i(cx * 256 - px0, cy * 256 - py0))
			for t in m.things_in(cx, cy):
				stand.append([int(t["y"]), int(t["x"]), str(t["n"]), 0])
	stand.append([(m.mouth.y + 1) * 16, m.mouth.x * 16 + 8, "cave_mouth", 0])
	for a in m.animals:
		stand.append([int(a["y"]), int(a["x"]), str(a["kind"]), 1])
	stand.sort()
	var th: Image = Painter.sheets["things"]
	for s in stand:
		var info: Dictionary = Painter.things[s[2]]
		if not info.has("rect"):
			continue
		var r: Array = info["rect"]
		var foot: Array = info["foot"]
		var src := Rect2i(r[0], r[1], int(info.get("frame_w", r[2])), r[3])
		img.blend_rect(th, src, Vector2i(int(s[1]) - int(foot[0]) - px0, int(s[0]) - int(foot[1]) - py0))
	return img
