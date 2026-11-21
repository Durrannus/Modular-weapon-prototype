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


static func load_kit() -> void:
	if ready:
		return
	kit = Art.json("highlands/kit.json")
	things = kit.get("things", {})
	variants = int(kit.get("variants", 4))
	for group in kit.get("sheets", {}).values():
		for file in group:
			sheets[str(file).get_basename()] = _rgba(Art.image(KIT + str(file)))
	sheets["things"] = _rgba(Art.image(KIT + "things.png"))
	var pal: Dictionary = kit.get("palette", {})
	for h in pal.get("grass", []):
		grass.append(Color(str(h)))
		grass32.append(Color(str(h)).to_rgba32())
	floor_lit = Color(str(pal["floor"][1]))
	floor_shade = Color(str(pal["floor"][0]))
	flowers = [[Color(str(pal["flag"][5])), Color(str(pal["flag"][3]))], [Color(str(pal["heath"][3])), Color(str(pal["heath"][1]))], [Color(str(pal["gold"][2])), Color(str(pal["gold"][0]))]]
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
	# 2. Tufts in the grass: long grass in clumps in the hollows and against the rock, the rises grazed short with a few flowers.
	for lj in range(1, KW - 1):
		for li in range(1, KW - 1):
			var i := lj * KW + li
			if not _grassy(K[i]):
				continue
			var wx := x0 + li - PAD
			var wy := y0 + lj - PAD
			var h := hsh(wx, wy, 5)
			var tone := int(TN[i])
			var hollow := tone == 0 or _near(R, i, 1)
			var rise := tone == 2 and not hollow
			var n := 3 if hollow else (0 if rise and h % 100 < 60 else (1 if (h >> 7) % 100 < 55 else 0))
			var mx := 3 + (h >> 14) % 7
			var my := 3 + (h >> 17) % 8
			for q in n:
				var hq := hsh(wx * 4 + q, wy, 6)
				var tx := (mx + hq % 9 - 4) if hollow else hq % 12
				var ty := (my + (hq >> 4) % 7 - 3) if hollow else (hq >> 4) % 13
				var p := (3 + (hq >> 8) % 2) if (hollow and q < 2) else (hq >> 8) % 3
				var size: Vector2i = tuft_size[p]
				var px := (li - PAD) * T + tx
				var py := (lj - PAD) * T + ty
				if not _tuft_fits(K, R, px, py, size):
					continue
				var src := Rect2i(p * 10, tone * 6, size.x, size.y)
				lit.blend_rect(tuft_lit, src, Vector2i(px, py))
				shade.blend_rect(tuft_shade, src, Vector2i(px, py))
			var f := (h >> 21) % 100
			if (rise and f < 30) or (not rise and not hollow and f < 5):
				var kind: Array = flowers[0 if f % 10 < 3 else (1 if f % 10 < 6 else 2)]
				var fx := (li - PAD) * T + 2 + (h >> 3) % 9
				var fy := (lj - PAD) * T + 3 + (h >> 9) % 8
				for q in 4 + h % 5:
					var hq := hsh(wx * 8 + q, wy, 8)
					var px := fx + hq % 9 - 4
					var py := fy + (hq >> 4) % 7 - 3
					if px < 0 or py < 0 or px >= PX or py + 1 >= PX:
						continue
					var g := grass32.find(lit.get_pixel(px, py).to_rgba32())
					if g < 2 or g > 4 or lit.get_pixel(px, py + 1).to_rgba32() != grass32[g]:
						continue
					lit.set_pixel(px, py, kind[0])
					shade.set_pixel(px, py, kind[1])
					lit.set_pixel(px, py + 1, grass[g - 1])
					shade.set_pixel(px, py + 1, grass[maxi(g - 3, 0)])
	# 3. Heather and sage: separate bushes standing on the grass, thick in the middle of a patch and thin at its edge.
	var plants: Array = []
	for lj in range(1, KW - 1):
		for li in range(1, KW - 1):
			var i := lj * KW + li
			var k := K[i]
			if k != HEATH and k != SCRUB:
				continue
			var wx := x0 + li - PAD
			var wy := y0 + lj - PAD
			var inside := K[i - 1] == k and K[i + 1] == k and K[i - KW] == k and K[i + KW] == k
			for s in (4 if k == HEATH else 2):
				var h := hsh(wx * 4 + s, wy, 7)
				if h % 100 >= (86 if inside else 48) - (0 if k == HEATH else 20):
					continue
				var px := (li - PAD) * T + ((s % 2) * 8 + 2 + (h >> 8) % 5 if k == HEATH else 3 + (h >> 8) % 10)
				var py := (lj - PAD) * T + ((s / 2) * 8 + 5 + (h >> 12) % 4 if k == HEATH else 6 + s * 5 + (h >> 12) % 4)
				plants.append([py, px, ("heath_%d" if k == HEATH else "scrub_%d") % ((h >> 16) % 12)])
	plants.sort()
	for p in plants:
		var info: Dictionary = things[p[2]]
		var r: Array = info["rect"]
		var foot: Array = info["foot"]
		var px := int(p[1])
		var py := int(p[0])
		# Never against rock or water, and never on a path: only where the ground round it is grass.
		var ok := true
		for c in [Vector2i(px - int(foot[0]) + 5, py - int(r[3]) + 12), Vector2i(px + int(r[2]) - int(foot[0]) - 5, py - int(r[3]) + 12), Vector2i(px - int(foot[0]) + 5, py + 3), Vector2i(px + int(r[2]) - int(foot[0]) - 5, py + 3)]:
			var ci := (floori(float(c.y) / T) + PAD) * KW + floori(float(c.x) / T) + PAD
			if ci < 0 or ci >= KW * KW or not _grassy(K[ci]):
				ok = false
		if not ok:
			continue
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
	# 5. The rock: the stones at its foot, then the rock itself from the top row down, with any ore showing in it.
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
		if K[i] == TIN:
			lit.blend_rect(sheets["ore_tin_dug" if r[2] else "ore_tin_nat"], src, dst)
		elif K[i] == COPPER:
			lit.blend_rect(sheets["ore_copper_dug" if r[2] else "ore_copper_nat"], src, dst)
	# 6. Lamplight on dug floor and the cut rock beside it.
	if floored != null:
		_light(lit, floored, lamps, K, ox, oy)
	return lit


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
