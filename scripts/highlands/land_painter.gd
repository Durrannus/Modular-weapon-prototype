extends RefCounted
## Paints a piece of Highlands land as one picture, from the kit the art thread's
## own drawing code was cut into (art/highlands/, made by tools/highlands_kit/bake.py).
##
## The art draws every ground pixel as a material and a step on that material's
## ramp, and a shadow is the same material two steps darker. To keep that here,
## two pictures of the ground are laid out side by side, one lit and one in
## shadow; a mask says where shadow falls; and the rock goes on last.
##
## A picture covers one chunk of 16 x 16 tiles (256 art pixels). Everything is
## chosen from the tile's own place on the map, so two chunks always meet without
## a seam and the same map always paints the same. Painting touches nothing but
## its own pictures, so the view runs it on other threads.
##
## tools/highlands_kit/compose_check.py does the same thing in Python beside the
## art thread's own drawing, for comparing by eye.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Art := preload("res://scripts/art.gd")
const Veins := preload("res://scripts/highlands/veins.gd")

const T := 16                  # one tile, in art pixels
const CH := LandMap.CHUNK
const PX := CH * T             # a chunk's picture is 256 pixels a side
const PAD := 2                 # tiles looked at past the chunk's edge
const KW := CH + PAD * 2
const COLS := 32               # pieces per row of a sheet
const GM := 4                  # how far a ground piece reaches past its tile
const GW := 24
const RM_L := 4                # and a rock piece: left, top (the far sides hold its shadow)
const RM_T := 6
const RW := 32
const RH := 34
const KIT := "res://art/highlands/"
const AROUND := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]   # N NE E SE S SW W NW

const GRASS := LandMap.GRASS
const SCRUB := LandMap.SCRUB
const HEATH := LandMap.HEATH
const PATH := LandMap.PATH
const YARD := LandMap.YARD
const WATER := LandMap.WATER
const ROCK := LandMap.ROCK
const TIN := LandMap.TIN
const COPPER := LandMap.COPPER
const FLOOR := LandMap.FLOOR
const SCREE := LandMap.SCREE

## Tufts, from the art's own patterns (hl3.py): L two steps lighter than the
## ground they stand on, l one, d one darker.
const TUFTS := [["l.L", ".l.", ".dd"], ["L.", "ld"], ["l.", ".d"]]
const LONG := [["..L...l..", "l.l.L.l.l", ".llLlllL.", "..lllll..", "...dddddd"], ["l..L..l", ".lllLl.", ".lllll.", "..ddddd"]]
## Lamplight: hard rings, a hatched edge, warm (hl3.py, "image").
const LAMP_GAIN := [1.0, 1.32, 1.7, 2.15]
const LAMP_WARM := [Vector3(1, 1, 1), Vector3(1.10, 0.98, 0.84), Vector3(1.18, 0.98, 0.76), Vector3(1.26, 1.0, 0.72)]
const LAMP_ADD := [Vector3(0, 0, 0), Vector3(10, 4, 0), Vector3(22, 9, 0), Vector3(34, 16, 2)]

static var ready := false
static var kit := {}
static var things := {}            # name -> {rect, foot, shadow, shadow_at, solid, frames, ...}
static var boxes := {}             # heather and scrub bushes: name -> Rect2i of the bush itself, from its foot
static var sheets := {}            # file name without ".png" -> Image
static var variants := 4
static var grass: Array = []       # the grass ramp, dark to light
static var grass32: Array = []
static var floor_lit := Color()
static var floor_shade := Color()
static var flowers: Array = []     # [[lit, in shadow], ...]: pale, pink, yellow
static var tuft_lit: Image
static var tuft_shade: Image
static var tuft_size: Array = []   # per pattern: Vector2i
static var vein_cols := {}         # ore veins: "tin", "copper", "verd", "face", "cap" -> that ramp's colours, step 0 upward


static func load_kit() -> void:
	if ready:
		return
	kit = Art.json("highlands/kit.json")
	things = kit.get("things", {})
	# What a felled pine leaves (scripts/highlands/tools.gd). Its picture is on the tool art's sheet, not the kit's
	# ("sheet": "tools"); its shadow and what stops you are the kit stump's, which is the same size at the root.
	var stump_box: Array = Art.json("tools/tools.json").get("sprites", {}).get("pine_stump", {}).get("box", [])
	if stump_box.size() == 4:
		var old: Dictionary = things.get("stump", {})
		var stump := {"rect": stump_box, "foot": [6, 10], "solid": old.get("solid", [6, 3]), "sheet": "tools"}
		if old.has("shadow"):
			stump["shadow"] = old["shadow"]
			stump["shadow_at"] = old["shadow_at"]
		things["pine_stump"] = stump
	variants = int(kit.get("variants", 4))
	for group in kit.get("sheets", {}).values():
		for file in group:
			sheets[str(file).get_basename()] = _rgba(Art.image(KIT + str(file)))
	sheets["things"] = _rgba(Art.image(KIT + "things.png"))
	# The Throne Room's floor, painted into the dug floor where the map says (version 50; tools/rattlecrown_kit).
	var floor_art: Image = Art.image(Art.ART_DIR + "scrapyard/throne_floor.png")
	if floor_art != null:
		sheets["throne_floor"] = _rgba(floor_art)
	# How big each heather and scrub bush really is (its picture has room round it), for standing them apart.
	for name in things:
		if not (str(name).begins_with("heath_") or str(name).begins_with("scrub_")) or str(name).ends_with("~"):
			continue
		var r: Array = things[name]["rect"]
		var foot: Array = things[name]["foot"]
		var used: Rect2i = (sheets["things"] as Image).get_region(Rect2i(r[0], r[1], r[2], r[3])).get_used_rect()
		boxes[name] = Rect2i(used.position.x - int(foot[0]), used.position.y - int(foot[1]), used.size.x, used.size.y)
	var pal: Dictionary = kit.get("palette", {})
	for h in pal.get("grass", []):
		grass.append(Color(str(h)))
		grass32.append(Color(str(h)).to_rgba32())
	floor_lit = Color(str(pal["floor"][1]))
	# Dug floor in shadow is one step darker and never the black of the undug rock's top (the art's rule of 22 November:
	# a tunnel one tile wide must show its floor and whoever stands in it). Its plain fill is step 1 already.
	floor_shade = Color(str(pal["floor"][1]))
	flowers = [[Color(str(pal["flag"][5])), Color(str(pal["flag"][3]))], [Color(str(pal["heath"][3])), Color(str(pal["heath"][1]))], [Color(str(pal["gold"][2])), Color(str(pal["gold"][0]))]]
	for name in kit.get("vein", {}):
		var ramp: Array = []
		for h in kit["vein"][name]:
			ramp.append(Color(str(h)))
		vein_cols[name] = ramp
	# The tufts, drawn once for each grass they can stand on (a hollow, plain, a rise).
	var pats: Array = TUFTS + LONG
	tuft_lit = Image.create(pats.size() * 10, 18, false, Image.FORMAT_RGBA8)
	tuft_shade = Image.create(pats.size() * 10, 18, false, Image.FORMAT_RGBA8)
	for p in pats.size():
		var pat: Array = pats[p]
		tuft_size.append(Vector2i(str(pat[0]).length(), pat.size()))
		for b in 3:
			for j in pat.size():
				for i in str(pat[j]).length():
					var ch := str(pat[j])[i]
					if ch == ".":
						continue
					var step := clampi(b + 2 + (2 if ch == "L" else (1 if ch == "l" else -1)), 0, 5)
					tuft_lit.set_pixel(p * 10 + i, b * 6 + j, grass[step])
					tuft_shade.set_pixel(p * 10 + i, b * 6 + j, grass[maxi(step - 2, 0)])
	ready = true


static func _rgba(img: Image) -> Image:
	if img != null and img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## The same "random" number for the same tile, every time.
static func hsh(x: int, y: int, salt: int) -> int:
	return ((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0x7fffffff


## Smooth noise from 0 to 1 over the tiles, `period` tiles from one bump to the
## next: where the long grass grows and where each colour of flower drifts.
static func _field(x: int, y: int, period: int, salt: int) -> float:
	var ix := floori(float(x) / float(period))
	var iy := floori(float(y) / float(period))
	var tx := float(x - ix * period) / float(period)
	var ty := float(y - iy * period) / float(period)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := float(_mix(ix, iy, salt) & 0xffff) / 65535.0
	var b := float(_mix(ix + 1, iy, salt) & 0xffff) / 65535.0
	var c := float(_mix(ix, iy + 1, salt) & 0xffff) / 65535.0
	var d := float(_mix(ix + 1, iy + 1, salt) & 0xffff) / 65535.0
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func _mix(x: int, y: int, s: int) -> int:
	var n := (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	n = (n ^ (n >> 15)) * 2246822519
	n = (n ^ (n >> 13)) * 3266489917
	return (n ^ (n >> 16)) & 0x7fffffff


## Which of a tile's eight neighbours are of kind k: bits N NE E SE S SW W NW.
static func _bits(a: PackedByteArray, i: int, k: int) -> int:
	var c := 0
	if a[i - KW] == k: c |= 1
	if a[i - KW + 1] == k: c |= 2
	if a[i + 1] == k: c |= 4
	if a[i + KW + 1] == k: c |= 8
	if a[i + KW] == k: c |= 16
	if a[i + KW - 1] == k: c |= 32
	if a[i - 1] == k: c |= 64
	if a[i - KW - 1] == k: c |= 128
	return c


static func _near(a: PackedByteArray, i: int, k: int) -> bool:
	return a[i - KW] == k or a[i - KW + 1] == k or a[i + 1] == k or a[i + KW + 1] == k or a[i + KW] == k or a[i + KW - 1] == k or a[i - 1] == k or a[i - KW - 1] == k


static func _grassy(k: int) -> bool:
	return k == GRASS or k == SCRUB or k == HEATH


## One kind of ground, laid over the grass: each tile's piece is picked by which
## neighbours are the same kind.
static func _lay(lit: Image, shade: Image, name: String, a: PackedByteArray, k: int, x0: int, y0: int) -> void:
	var sa: Image = sheets[name]
	var sb: Image = sheets[name + "_shade"]
	for lj in range(1, KW - 1):
		for li in range(1, KW - 1):
			var i := lj * KW + li
			if a[i] != k:
				continue
			var n := (hsh(x0 + li - PAD, y0 + lj - PAD, 1) % variants) * 256 + _bits(a, i, k)
			var src := Rect2i((n % COLS) * GW, (n / COLS) * GW, GW, GW)
			var dst := Vector2i((li - PAD) * T - GM, (lj - PAD) * T - GM)
			lit.blend_rect(sa, src, dst)
			if shade != null:
				shade.blend_rect(sb, src, dst)


## The picture of chunk (cx, cy) of the map: PX x PX, with the chunk's top left
## tile at its top left.
static func paint(m: LandMap, cx: int, cy: int) -> Image:
	load_kit()
	var x0 := cx * CH
	var y0 := cy * CH
	var ox := x0 * T
	var oy := y0 * T
	# The tiles in and just round the chunk, with rock, tin and copper all as "rock" in R.
	var K := PackedByteArray()
	var R := PackedByteArray()
	var TN := PackedByteArray()
	K.resize(KW * KW)
	R.resize(KW * KW)
	TN.resize(KW * KW)
	var any_open := false
	for lj in KW:
		for li in KW:
			var k := m.kind(x0 + li - PAD, y0 + lj - PAD)
			K[lj * KW + li] = k
			R[lj * KW + li] = 1 if LandMap.rocky(k) else 0
			TN[lj * KW + li] = m.tone(x0 + li - PAD, y0 + lj - PAD) if not LandMap.rocky(k) else 1
			if not LandMap.rocky(k):
				any_open = true
	var lit := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	var core: Image = sheets["rock_core"]
	if not any_open:
		# The heart of a hill: nothing but the dark rock top.
		for j in CH:
			for i in CH:
				var n := hsh(x0 + i, y0 + j, 3) % 32
				lit.blit_rect(core, Rect2i((n % 8) * T, (n / 8) * T, T, T), Vector2i(i * T, j * T))
		_veins(lit, m, cx, cy)        # (a seam can still reach in from a rock face just past the tiles looked at)
		return lit
	lit.fill(grass[3])
	var shade := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	shade.fill(grass[1])
	var mask := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	var th: Image = sheets["things"]
	# 1. The ground: hollows and rises in the grass, then what lies on it.
	_lay(lit, shade, "hollow", TN, 0, x0, y0)
	_lay(lit, shade, "rise", TN, 2, x0, y0)
	_lay(lit, shade, "path", K, PATH, x0, y0)
	_lay(lit, shade, "yard", K, YARD, x0, y0)
	_lay(lit, shade, "scree", K, SCREE, x0, y0)
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for d in m.decals_in(cx + di, cy + dj):
				var info: Dictionary = things.get(str(d["n"]), {})
				if info.is_empty():
					continue
				var r: Array = info["rect"]
				var at: Array = info.get("at", [0, 0])
				var dst := Vector2i(int(d["x"]) + int(at[0]) - ox, int(d["y"]) + int(at[1]) - oy)
				lit.blend_rect(th, Rect2i(r[0], r[1], r[2], r[3]), dst)
				var r2: Array = things[str(d["n"]) + "~"]["rect"]
				shade.blend_rect(th, Rect2i(r2[0], r2[1], r2[2], r2[3]), dst)
	_lay(lit, shade, "water", K, WATER, x0, y0)
	# Lamps near this chunk. Where there are any, `floored` remembers which pixels are dug floor,
	# so the light falls on the floor and not on the grass at its ragged edge.
	var lamps: Array = []
	for dj in range(-1, 2):
		for di in range(-1, 2):
			lamps.append_array(m.lamps_in(cx + di, cy + dj))
	var floored: Image = null
	if not lamps.is_empty():
		floored = Image.create_empty(PX, PX, false, Image.FORMAT_RGBA8)
	# Dug floor: a flat bed first, so no grass shows between a floor and the rock beside it.
	for lj in range(1, KW - 1):
		for li in range(1, KW - 1):
			var i := lj * KW + li
			var px := (li - PAD) * T
			var py := (lj - PAD) * T
			if K[i] == FLOOR:
				var b := Rect2i(px, py, T, T)
				if R[i - 1] == 0 and K[i - 1] != FLOOR:
					b.position.x += 5
					b.size.x -= 5
				if R[i + 1] == 0 and K[i + 1] != FLOOR:
					b.size.x -= 5
				if R[i - KW] == 0 and K[i - KW] != FLOOR:
					b.position.y += 5
					b.size.y -= 5
				if R[i + KW] == 0 and K[i + KW] != FLOOR:
					b.size.y -= 5
				lit.fill_rect(b, floor_lit)
				shade.fill_rect(b, floor_shade)
				if floored != null:
					floored.fill_rect(b, Color.WHITE)
			elif R[i] == 1 and _near(K, i, FLOOR):
				for q in [[-KW, 0, 0, T, 6], [KW, 0, T - 6, T, 6], [-1, 0, 0, 6, T], [1, T - 6, 0, 6, T], [-KW - 1, 0, 0, 6, 6], [-KW + 1, T - 6, 0, 6, 6], [KW - 1, 0, T - 6, 6, 6], [KW + 1, T - 6, T - 6, 6, 6]]:
					if K[i + int(q[0])] == FLOOR:
						var b := Rect2i(px + int(q[1]), py + int(q[2]), int(q[3]), int(q[4]))
						lit.fill_rect(b, floor_lit)
						shade.fill_rect(b, floor_shade)
	_lay(lit, shade, "floor", K, FLOOR, x0, y0)
	if floored != null:
		_lay(floored, null, "floor", K, FLOOR, x0, y0)
	# Pictures painted into the dug floor (the Throne Room's paving, sunk traps and stands, version 50), so the rock's
	# shadow and the lamplight fall on them as on the floor itself.
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for d in m.floor_decals_in(cx + di, cy + dj):
				var art: Image = sheets.get(str(d["sheet"]))
				if art == null:
					continue
				var r: Array = d["rect"]
				var r2: Array = d["shade"]
				var dst := Vector2i(int(d["x"]) - ox, int(d["y"]) - oy)
				lit.blend_rect(art, Rect2i(r[0], r[1], r[2], r[3]), dst)
				shade.blend_rect(art, Rect2i(r2[0], r2[1], r2[2], r2[3]), dst)
	# 2. Tufts in the grass. Nearly every tile has one; long grass stands in clumps in the hollows, against the rock and
	# in patches of its own; the rises are grazed short; and flowers grow in drifts, each drift one colour.
	var world := int(m.seed_value & 0xffff) * 31
	for lj in range(1, KW - 1):
		for li in range(1, KW - 1):
			var i := lj * KW + li
			if not _grassy(K[i]):
				continue
			var wx := x0 + li - PAD
			var wy := y0 + lj - PAD
			var h := _mix(wx, wy, 5)
			var tone := int(TN[i])
			var cover := K[i] != GRASS                                       # heather or scrub stands here: tufts only, the bushes are the show
			var hollow := tone == 0 or _near(R, i, 1)
			var rank := not hollow and not cover and tone == 1 and _field(wx, wy, 5, 300 + world) > 0.70     # a patch of long grass out in the open
			var rise := tone == 2 and not hollow
			var n := 2 if cover else (3 if hollow or rank else ((1 if h % 100 < 55 else 0) + (1 if (h >> 7) % 100 < 15 else 0) if rise else (1 if h % 100 < 90 else 0) + (1 if (h >> 7) % 100 < 40 else 0)))
			var mx := 3 + (h >> 14) % 7
			var my := 3 + (h >> 17) % 8
			for q in n:
				var hq := _mix(wx * 4 + q, wy, 6)
				var clump := (hollow or rank) and not cover
				var tx := (mx + hq % 9 - 4) if clump else hq % 12
				var ty := (my + (hq >> 4) % 7 - 3) if clump else (hq >> 4) % 13
				var p := (3 + (hq >> 8) % 2) if (clump and q < 2) else (hq >> 8) % 3
				var size: Vector2i = tuft_size[p]
				var px := (li - PAD) * T + tx
				var py := (lj - PAD) * T + ty
				if not _tuft_fits(K, R, px, py, size):
					continue
				var src := Rect2i(p * 10, tone * 6, size.x, size.y)
				lit.blend_rect(tuft_lit, src, Vector2i(px, py))
				shade.blend_rect(tuft_shade, src, Vector2i(px, py))
			if cover or tone == 0:
				continue
			# Flowers: three kinds, each in drifts of its own a few tiles across, and a stray clump here and there on the rises.
			var kind := -1
			var clumps := 1
			for c in 3:
				var f := _field(wx, wy, 6, 310 + c * 7 + world)
				if f > 0.76:
					kind = c
					clumps = 2 if f > 0.86 else 1
			var stray := (h >> 21) % 100
			if kind < 0 and ((rise and stray < 10) or (not rise and stray < 2)):
				kind = stray % 3
			if kind < 0:
				continue
			for g2 in clumps:
				var hc := _mix(wx * 2 + g2, wy, 9)
				var fx := (li - PAD) * T + 2 + hc % 11
				var fy := (lj - PAD) * T + 2 + (hc >> 5) % 10
				for q in 4 + (hc >> 10) % 5:
					var hq := _mix(wx * 16 + q + g2 * 8, wy, 8)
					var px := fx + hq % 9 - 4
					var py := fy + (hq >> 4) % 7 - 3
					if px < 0 or py < 0 or px >= PX or py + 1 >= PX:
						continue
					var g := grass32.find(lit.get_pixel(px, py).to_rgba32())
					if g < 2 or g > 4 or lit.get_pixel(px, py + 1).to_rgba32() != grass32[g]:
						continue
					lit.set_pixel(px, py, flowers[kind][0])
					shade.set_pixel(px, py, flowers[kind][1])
					lit.set_pixel(px, py + 1, grass[g - 1])
					shade.set_pixel(px, py + 1, grass[maxi(g - 3, 0)])
	# 3. Heather and sage: separate bushes standing on the grass, each one a plant of the map's own (the map made
	# sure no two touch). The ones further up the picture go down first, so a nearer bush stands in front.
	var plants: Array = []
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for pl in m.plants_in(cx + di, cy + dj):
				plants.append([int(pl["y"]) - oy, int(pl["x"]) - ox, str(pl["n"])])
	plants.sort()
	for p in plants:
		var info: Dictionary = things[p[2]]
		var r: Array = info["rect"]
		var foot: Array = info["foot"]
		var px := int(p[1])
		var py := int(p[0])
		var dst := Vector2i(px - int(foot[0]), py - int(foot[1]))
		lit.blend_rect(th, Rect2i(r[0], r[1], r[2], r[3]), dst)
		var r2: Array = things[str(p[2]) + "~"]["rect"]
		shade.blend_rect(th, Rect2i(r2[0], r2[1], r2[2], r2[3]), dst)
		var s: Array = info["shadow"]
		var sat: Array = info["shadow_at"]
		mask.blend_rect(th, Rect2i(s[0], s[1], s[2], s[3]), Vector2i(px + int(sat[0]), py + int(sat[1])))
	# 4. Shadows: what stands on the land throws one down and to the right, and so does the rock.
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for t in m.things_in(cx + di, cy + dj):
				var info: Dictionary = things.get(str(t["n"]), {})
				if not info.has("shadow"):
					continue
				var s: Array = info["shadow"]
				var sat: Array = info["shadow_at"]
				mask.blend_rect(th, Rect2i(s[0], s[1], s[2], s[3]), Vector2i(int(t["x"]) + int(sat[0]) - ox, int(t["y"]) + int(sat[1]) - oy))
	var rock_shadow: Image = sheets["rock_shadow"]
	var rocks: Array = []       # [local index, piece number, dug]
	for lj in range(1, KW - 1):
		for li in range(1, KW - 1):
			var i := lj * KW + li
			if R[i] == 0:
				continue
			var cfg := _bits(R, i, 1)
			if cfg == 255:
				rocks.append([i, -1, false])
				continue
			var n := (hsh(x0 + li - PAD, y0 + lj - PAD, 2) % variants) * 256 + cfg
			rocks.append([i, n, _near(K, i, FLOOR)])
			mask.blend_rect(rock_shadow, Rect2i((n % COLS) * RW, (n / COLS) * RH, RW, RH), Vector2i((li - PAD) * T - RM_L, (lj - PAD) * T - RM_T))
	lit.blit_rect_mask(shade, mask, Rect2i(0, 0, PX, PX), Vector2i.ZERO)
	# 5. The rock: the stones at its foot, then the rock itself from the top row down, then the ore that runs through it.
	for r in rocks:
		if int(r[1]) < 0:
			continue
		var i: int = r[0]
		var n: int = r[1]
		lit.blend_rect(sheets["rock_dug_foot" if r[2] else "rock_nat_foot"], Rect2i((n % COLS) * RW, (n / COLS) * RH, RW, RH), Vector2i((i % KW - PAD) * T - RM_L, (i / KW - PAD) * T - RM_T))
	for r in rocks:
		var i: int = r[0]
		var n: int = r[1]
		var px := (i % KW - PAD) * T
		var py := (i / KW - PAD) * T
		if n < 0:
			var c := hsh(x0 + i % KW - PAD, y0 + i / KW - PAD, 3) % 32
			lit.blit_rect(core, Rect2i((c % 8) * T, (c / 8) * T, T, T), Vector2i(px, py))
			continue
		var src := Rect2i((n % COLS) * RW, (n / COLS) * RH, RW, RH)
		var dst := Vector2i(px - RM_L, py - RM_T)
		lit.blend_rect(sheets["rock_dug" if r[2] else "rock_nat"], src, dst)
	_veins(lit, m, cx, cy)
	# 6. Lamplight on dug floor and the cut rock beside it.
	if floored != null:
		_light(lit, floored, lamps, K, ox, oy)
	return lit


## Ore, as seams of metal through the rock (Darren, 21 and 22 November: "I want it like veins through the rock",
## "fades into fog of war", "Ok on veins look"). Where the metal is comes from the map (every cluster of ore tiles has
## its seams, the same whichever chunk asks); what colour a pixel of it takes comes from the rock it lies in: bright
## on the lit face, plain near the edge of the dark top, thinner and broken further in, and gone 21 pixels in. So a
## seam shows where rock meets open ground, and the heart of a hill shows nothing until somebody digs towards it.
## Both rules are the art thread's own (veins.gd).
static func _veins(lit: Image, m: LandMap, cx: int, cy: int) -> void:
	var seams: Array = m.veins_in(cx, cy)
	if seams.is_empty() or vein_cols.is_empty() or not sheets.has("rock_nat_part"):
		return
	var ox := cx * PX
	var oy := cy * PX
	var deep := {}                      # tile -> is every tile round it rock (then no edge is near, and nothing shows)
	for v: Dictionary in seams:
		# This cluster's seam pixels that fall in this chunk.
		var px: Dictionary = v["px"]
		var kind := int(v["kind"])
		var found: Array = []           # Vector2i
		var lo := Vector2i(1 << 30, 1 << 30)
		var hi := Vector2i(-1, -1)
		for p: Vector2i in px:
			if p.x < ox or p.y < oy or p.x >= ox + PX or p.y >= oy + PX:
				continue
			if not m.vein_shows(v, p):
				continue                # the ore tile this bit of the seam belongs to has been mined
			var tile := Vector2i(p.x >> 4, p.y >> 4)
			if not deep.has(tile):
				var all_rock := true
				for dy in range(-2, 4):
					for dx in range(-2, 3):
						if not m.is_rock(tile.x + dx, tile.y + dy):
							all_rock = false
				deep[tile] = all_rock
			if deep[tile]:
				continue
			found.append(p)
			lo = lo.min(p)
			hi = hi.max(p)
		if found.is_empty():
			continue
		# The rock round them, pixel by pixel: where it is, and which of it is lit face and which dark top. A pixel's
		# colour depends on rock up to 21 pixels away, so the patch reaches a little further than the seams.
		var reach := Veins.GONE + 1
		var tx0 := floori(float(lo.x - reach) / T)
		var ty0 := floori(float(lo.y - reach) / T)
		var w := (floori(float(hi.x + reach) / T) - tx0 + 1) * T
		var h := (floori(float(hi.y + reach) / T) - ty0 + 1) * T
		var data := rock_parts(m, tx0, ty0, w / T, h / T).get_data()
		var top := PackedByteArray()    # 1 = the rock's dark top
		top.resize(w * h)
		for i in w * h:
			if data[i * 4 + 3] != 0 and data[i * 4] == 0:
				top[i] = 1
		var metal: Array = vein_cols["tin" if kind == Veins.TIN else "copper"]
		for p: Vector2i in found:
			var x := p.x - tx0 * T
			var y := p.y - ty0 * T
			var i := y * w + x
			if data[i * 4 + 3] == 0:
				continue                # not rock: the seam ends where the rock does
			var cls := int(px[p])
			var on_face := data[i * 4] != 0
			var hgt := 0
			var depth := 0
			if on_face:
				while hgt < 8 and y + 1 + hgt < h and data[((y + 1 + hgt) * w + x) * 4 + 3] != 0:
					hgt += 1
			else:
				# (Only the thin edge of a seam is followed past 12 pixels in; the rest has gone by then.)
				depth = Veins.depth(top, w, h, x, y, Veins.GONE if cls == Veins.FORK or cls == Veins.EDGE else 12)
			var code := Veins.step(cls, kind, on_face, hgt, depth, Veins.vmix(p.x, p.y, m.seed_value, 7) % 100)
			if code < 0:
				continue
			var ramp: Array = metal
			match code / 8:
				Veins.M_VERD: ramp = vein_cols["verd"]
				Veins.M_FACE: ramp = vein_cols["face"]
				Veins.M_CAP: ramp = vein_cols["cap"]
			lit.set_pixel(p.x - ox, p.y - oy, ramp[mini(code % 8, ramp.size() - 1)])


## The rock of tw x th tiles from tile (tx0, ty0), as a picture: clear where there is no rock, black where it is the
## rock's dark top, red where it is its lit face. Laid out from the same pieces, in the same order, as the rock itself.
static func rock_parts(m: LandMap, tx0: int, ty0: int, tw: int, th: int) -> Image:
	load_kit()
	var out := Image.create_empty(tw * T, th * T, false, Image.FORMAT_RGBA8)
	for ty in range(ty0 - 1, ty0 + th + 1):
		for tx in range(tx0 - 1, tx0 + tw + 1):
			if not m.is_rock(tx, ty):
				continue
			var cfg := 0
			var dug := false
			for b in 8:
				var d: Vector2i = AROUND[b]
				var k := m.kind(tx + d.x, ty + d.y)
				if LandMap.rocky(k):
					cfg |= 1 << b
				elif k == FLOOR:
					dug = true
			var px := (tx - tx0) * T
			var py := (ty - ty0) * T
			if cfg == 255:
				out.fill_rect(Rect2i(px, py, T, T), Color(0, 0, 0, 1))
				continue
			var n := (hsh(tx, ty, 2) % variants) * 256 + cfg
			out.blend_rect(sheets["rock_dug_part" if dug else "rock_nat_part"], Rect2i((n % COLS) * RW, (n / COLS) * RH, RW, RH), Vector2i(px - RM_L, py - RM_T))
	return out


## A tuft may stand on grass only: none of it on a path, the yard, water or a dug
## floor, though rock may cover a little of it (long grass grows against rock).
static func _tuft_fits(K: PackedByteArray, R: PackedByteArray, px: int, py: int, size: Vector2i) -> bool:
	for c in [Vector2i(px, py), Vector2i(px + size.x - 1, py), Vector2i(px, py + size.y - 1), Vector2i(px + size.x - 1, py + size.y - 1)]:
		var i := (floori(float(c.y) / T) + PAD) * KW + floori(float(c.x) / T) + PAD
		if not _grassy(K[i]):
			return false
	for c in [Vector2i(px - 4, py - 4), Vector2i(px + size.x + 3, py - 4), Vector2i(px - 4, py + size.y + 3), Vector2i(px + size.x + 3, py + size.y + 3)]:
		var i := (floori(float(c.y) / T) + PAD) * KW + floori(float(c.x) / T) + PAD
		if not _grassy(K[i]) and R[i] == 0:
			return false
	return true


static func _light(lit: Image, floored: Image, lamps: Array, K: PackedByteArray, ox: int, oy: int) -> void:
	var level := PackedByteArray()
	level.resize(PX * PX)
	var any := false
	for l in lamps:
		var lx := int(l["x"]) - ox
		var ly := int(l["y"]) - oy
		var r := float(l["r"])
		var ry := int(r / 1.3) + 1
		for y in range(maxi(ly - ry, 0), mini(ly + ry + 1, PX)):
			for x in range(maxi(lx - int(r), 0), mini(lx + int(r) + 1, PX)):
				var dd := Vector2(x - lx, float(y - ly) * 1.3).length() / r
				if dd >= 1.05:
					continue
				var ring := 3 if dd < 0.42 else (2 if dd < 0.72 else (1 if dd < 1.0 else 0))
				var edge := absf(dd - 0.42) < 0.05 or absf(dd - 0.72) < 0.05 or absf(dd - 1.0) < 0.05
				if edge and (x + ox + y + oy) % 4 < 2 and ring > 0:
					ring -= 1
				if ring > level[y * PX + x]:
					level[y * PX + x] = ring
					any = true
	if not any:
		return
	for y in PX:
		for x in PX:
			var lv := level[y * PX + x]
			if lv == 0:
				continue
			var i := (y / T + PAD) * KW + x / T + PAD
			var soft := false
			if K[i] != FLOOR:
				# The cut face of the rock north of a floor takes a softer light; its dark top takes none.
				if not (LandMap.rocky(K[i]) and K[i + KW] == FLOOR and y % T >= 6):
					continue
				soft = true
			elif floored.get_pixel(x, y).a < 0.5:
				continue              # grass showing at the floor's ragged edge
			var c := lit.get_pixel(x, y)
			var gain: float = LAMP_GAIN[lv]
			var warm: Vector3 = LAMP_WARM[lv]
			var add: Vector3 = LAMP_ADD[lv] / 255.0
			if soft:
				gain = 1.0 + (gain - 1.0) * 0.42
				warm = Vector3.ONE + (warm - Vector3.ONE) * 0.5
				add *= 0.4
			lit.set_pixel(x, y, Color(minf(c.r * gain * warm.x + add.x, 1.0), minf(c.g * gain * warm.y + add.y, 1.0), minf(c.b * gain * warm.z + add.z, 1.0)))
