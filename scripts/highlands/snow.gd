extends Node2D
## The snowy section round the Hound Den (version 62).
##
## Darren, 25 November 2026: "let's have a snowy section for the wolfs to spawn in and near. The snowy section is to be
## pretty much the same but with a snow effect to the screen and snow on things in the area with the wolf den."
## ("Wolfs" read as the Cliff Hounds: Claude's reading.)
##
## The land is the same land: nothing here changes a tile or what stands on it, so no world is laid out again. What
## changes is how it looks round the Den, and who lives there:
##   - Snow lies on the land within REACH tiles of the Den's middle, thinning out over EDGE tiles at its edge, in
##     patches, so the section never stops at a hard line. `depth()` says how far into the snow a point is; the painter
##     (land_painter.gd) paints the snow kit there (art/highlands/snow/, baked from the Art builder's hl3_snow.py by
##     tools/highlands_kit/bake.py --snow), and the view stands the snowy picture of every thing whose foot is in it.
##   - The Den's mouth stands against the rock at the north side of the Den, with the ground trodden to slush in front
##     of it and paw prints leading off (`stamp`, every time the world is opened, like the Scrapyard: no save holds it).
##   - Snow falls while the camera is over the snow (this node): the Art builder's two layers, drawn over the land and
##     under everything that stands on it, so it can never hide a player, an enemy or a mark.
##   - Every open place in the snow, and near it (HOUNDS_NEAR), is hound ground (foe_plan.gd).
##
## The numbers are first guesses (Claude's), and the lab has them.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Art := preload("res://scripts/art.gd")

static var REACH := 70.0        # tiles from the middle of the Hound Den that lie under snow
static var EDGE := 6.0          # how many tiles the snow takes to thin out to nothing at its edge
static var FALL := 1            # how thick the falling snow is: 1 as the Art builder drew it, 2 twice that, 0 none
static var HOUNDS_NEAR := 20.0  # every open place within this many tiles of the snow's edge is hound ground (foe_plan.gd)
const WOBBLE := 3.0             # how far the edge wanders in and out, in EDGEs (big, slow bends)
const PATCHES := 2.0            # and how patchy it is there, in EDGEs (patches about four tiles across) ...
const FRINGE := 0.8             # ... with ragged edges of their own (bumps a tile or two across)
const FADE := 1.0               # seconds for the falling snow to come and go
## The two layers of falling snow (the Art builder's README): art pixels a second down and sideways, and the sway.
const LAYERS := [["far", Vector2(4.0, 14.0), 2.0, 5.0], ["near", Vector2(8.0, 30.0), 3.0, 4.0]]
const UNIT := Art.PIXEL
const TILE := 16.0 * UNIT

var map: LandMap
var rig                          # the camera rig: where the view is
var shown := 0.0                 # how much the falling snow shows now (0 to 1)
var clock := 0.0
var _tex := {}                   # "far" / "near" -> Texture2D


## The middle of the snow, in tiles (INF if there is none: the lab turned it off, or a land made without the Den).
static func centre(m: LandMap) -> Vector2:
	if REACH <= 0.0 or m == null or not m.sites.has("den"):
		return Vector2.INF
	return m.sites["den"]["at"]


## How far into the snow a point of the land is, in EDGEs: above 0 is snow. x and y are in tiles (a pixel is 1/16).
static func depth(m: LandMap, x: float, y: float) -> float:
	var c := centre(m)
	if c == Vector2.INF:
		return -100.0
	var d := Vector2(x, y).distance_to(c)
	var s := (REACH - d) / maxf(EDGE, 0.5)
	if absf(s) > (WOBBLE + PATCHES + FRINGE) * 0.5 + 1.0:
		return s
	var salt := int(m.seed_value & 0xffff)
	return s + WOBBLE * (_noise(x, y, 24.0, salt + 11) - 0.5) + PATCHES * (_noise(x, y, 4.0, salt + 23) - 0.5) \
			+ FRINGE * (_noise(x, y, 1.5, salt + 37) - 0.5)


## Is this point (art pixels on the map) under snow?
static func snowy_px(m: LandMap, at: Vector2) -> bool:
	return depth(m, at.x / 16.0, at.y / 16.0) > 0.0


## How much of chunk (cx, cy) is under snow: 0 none of it, 2 all of it, 1 some.
static func chunk(m: LandMap, cx: int, cy: int) -> int:
	var c := centre(m)
	if c == Vector2.INF:
		return 0
	var r := Rect2(cx * LandMap.CHUNK, cy * LandMap.CHUNK, LandMap.CHUNK, LandMap.CHUNK)
	var near := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y)).distance_to(c)
	var far := 0.0
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		far = maxf(far, (corner as Vector2).distance_to(c))
	var spread := (WOBBLE + PATCHES + FRINGE) * 0.5 + 0.1      # (and the painter's pixel jitter)
	if (REACH - far) / maxf(EDGE, 0.5) - spread > 0.0:
		return 2
	if (REACH - near) / maxf(EDGE, 0.5) + spread < 0.0:
		return 0
	return 1


## Smooth noise from 0 to 1, `period` tiles from one bump to the next, at any point (not only whole tiles).
static func _noise(x: float, y: float, period: float, salt: int) -> float:
	var fx := x / period
	var fy := y / period
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _h(ix, iy, salt)
	var b := _h(ix + 1, iy, salt)
	var c := _h(ix, iy + 1, salt)
	var d := _h(ix + 1, iy + 1, salt)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func _h(x: int, y: int, s: int) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	n = (n ^ (n >> 15)) * 2246822519
	n = (n ^ (n >> 13)) * 3266489917
	return float(((n ^ (n >> 16)) & 0x7fffffff) & 0xffff) / 65535.0


## The Den's mouth, the trodden ground in front of it and the paw prints, put on the land every time it is opened
## (they are the land's, not changes: no save holds them). The mouth stands against the rock at the north side of the
## Den, its whole width against rock, on open grass clear of anything else and of the chests (`keep_clear`: tiles).
## Returns where its feet are (art pixels), or Vector2.INF if there was no room for it (then the snow still lies).
static func stamp(m: LandMap, keep_clear: Array = []) -> Vector2:
	if centre(m) == Vector2.INF or not m.sites.has("den"):
		return Vector2.INF
	var site: Dictionary = m.sites["den"]
	var p: Dictionary = m.pockets[int(site["pocket"])] if site.has("pocket") and int(site["pocket"]) < m.pockets.size() else {}
	var at: Vector2 = site["at"]
	var rx := float(p.get("rx", 8.0))
	var ry := float(p.get("ry", 6.0))
	var want := Vector2(at.x, at.y - ry)            # the middle of the Den's north side
	var best := Vector2i(-1, -1)
	var best_d := 1e9
	for ty in range(int(at.y - ry - 6.0), int(at.y + 2.0)):
		for tx in range(int(at.x - rx - 2.0), int(at.x + rx + 3.0)):
			var d := Vector2(tx + 0.5, ty + 0.5).distance_to(want)
			if d >= best_d or not _den_fits(m, tx, ty, keep_clear):
				continue
			best = Vector2i(tx, ty)
			best_d = d
	if best.x < 0:
		return Vector2.INF
	var foot := Vector2(best.x * 16 + 8, best.y * 16 + 12)
	m.stamp_thing({"n": "den", "x": int(foot.x), "y": int(foot.y), "f": false})
	# The trodden ground in front of the mouth, and three lines of paw prints leading off from it (the Art builder's
	# own preview lays them like this).
	m.stamp_decal({"n": "trample", "x": int(foot.x) - 5, "y": int(foot.y) + 7})
	m.stamp_decal({"n": "tracks_e", "x": int(foot.x) + 26, "y": int(foot.y) + 12})
	m.stamp_decal({"n": "tracks_se", "x": int(foot.x) + 16, "y": int(foot.y) + 18})
	m.stamp_decal({"n": "tracks_ne", "x": int(foot.x) - 76, "y": int(foot.y) + 4})
	site["den_foot"] = foot
	return foot


## The mouth stands on grass or the stones at the rock's foot, three tiles wide, with rock or those stones all along
## the row above it and rock behind that (against the hillside); open ground in front of it for the trodden snow; no
## footpath under it or beside it (it must never block a way); nothing standing near it and no chest within three tiles.
static func _den_fits(m: LandMap, tx: int, ty: int, keep_clear: Array) -> bool:
	var behind := 0
	for dx in range(-1, 2):
		var k := m.kind(tx + dx, ty)
		if k != LandMap.GRASS and k != LandMap.SCREE:
			return false
		var up := m.kind(tx + dx, ty - 1)
		if not (LandMap.rocky(up) or up == LandMap.SCREE):
			return false
		if LandMap.rocky(m.kind(tx + dx, ty - 2)):
			behind += 1
		for dy in range(1, 3):
			if not m.walkable(tx + dx, ty + dy):
				return false
	if behind < 2:
		return false
	for dy in range(-1, 3):
		for dx in range(-3, 4):
			if m.kind(tx + dx, ty + dy) == LandMap.PATH:
				return false
	var foot := Vector2(tx * 16 + 8, ty * 16 + 12)
	var cx := floori(foot.x / (LandMap.CHUNK * 16))
	var cy := floori(foot.y / (LandMap.CHUNK * 16))
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for t in m.things_in(cx + di, cy + dj) + m.plants_in(cx + di, cy + dj):
				var tf := Vector2(float(t["x"]), float(t["y"]))
				if absf(tf.x - foot.x) < 44.0 and absf(tf.y - foot.y) < 36.0:
					return false
	for k in keep_clear:
		if (k as Vector2i).distance_to(Vector2i(tx, ty)) < 3.5:
			return false
	return true


# --- The falling snow ---------------------------------------------------------------------------------------------

func _ready() -> void:
	z_index = -9                 # over the land (-10), under everything that stands on it, every mark and the HUD
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for layer in LAYERS:
		var tex: Texture2D = Art.texture("highlands/snow/snow_%s.png" % layer[0])
		if tex != null:
			_tex[layer[0]] = tex


## Is the falling snow wanted where the camera is now?
func wanted() -> bool:
	if FALL <= 0 or rig == null or map == null:
		return false
	var c: Vector2 = rig.view_rect().get_center() / TILE
	return depth(map, c.x, c.y) > 0.0


func _process(delta: float) -> void:
	clock += delta
	shown = move_toward(shown, 1.0 if wanted() else 0.0, delta / FADE)
	visible = shown > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	if rig == null or shown <= 0.0:
		return
	var view: Rect2 = rig.view_rect()
	# In screen space: the flakes move with the screen, whatever the camera does, so they are drawn from where the
	# view is with their own drift as the texture's offset.
	draw_set_transform(view.position, 0.0, Vector2(UNIT, UNIT))
	var size := view.size / UNIT
	for k in clampi(FALL, 0, 2):
		for layer in LAYERS:
			var tex: Texture2D = _tex.get(layer[0])
			if tex == null:
				continue
			var v: Vector2 = layer[1]
			var off := Vector2(clock * v.x + float(layer[2]) * sin(clock * TAU / float(layer[3]) + k * 2.0), clock * v.y).floor()
			off += Vector2(53, 71) * k            # (thick: the same flakes again, half a sheet over)
			draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), Rect2(-off, size), Color(1, 1, 1, shown))
