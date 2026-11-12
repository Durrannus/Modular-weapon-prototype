extends RefCounted
## Loads sprites from res://art/ by name, and returns null when one doesn't
## exist yet, so the game falls back to simple shapes until the art lands.
##
## The art folder has a .gdignore file, so the editor doesn't import it and the
## game also runs from a fresh copy that the editor never opened (Steam Deck).
## Before making an exported build, remove .gdignore and switch to load().
##
## Naming:
##   art/parts/<part id>_hand.png   the part as it looks in hand (5 px per grid cell)
##   art/parts/<part id>_grid.png   the part on the forge grid (18 px per grid cell)
##   art/enemies/<kind>.png         slime, charger, brute, dummy
##   art/tiles/floor.png, art/tiles/wall.png    16x16
##   art/props/forge_bench.png

const ART_DIR := "res://art/"

## Sprites are drawn at this many world units per art pixel. The camera is
## zoomed to 0.5 so one art pixel = one screen pixel at 640x360.
const PIXEL := 2.0

static var _cache := {}


static func texture(rel_path: String) -> Texture2D:
	if _cache.has(rel_path):
		return _cache[rel_path]
	var tex: Texture2D = null
	var path := ART_DIR + rel_path
	var img := image(path)
	if img != null:
		tex = ImageTexture.create_from_image(img)
	_cache[rel_path] = tex
	return tex


## A PNG from the game's files, or null. It is read through the game's own file
## system, not straight off the disk, so it also works when the whole game is
## packed into one file (tools/make_windows_exe.gd).
static func image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return img


static func part_hand(id: String) -> Texture2D:
	return texture("parts/%s_hand.png" % id)


static func part_grid(id: String) -> Texture2D:
	return texture("parts/%s_grid.png" % id)


## Draws frame `frame` of a horizontal strip with its feet origin at `feet`.
## Sprites face right (or are already drawn per direction); flip mirrors them.
static func draw_strip(ci: CanvasItem, tex: Texture2D, frames: int, frame: int, feet: Vector2,
		origin: Vector2, flip := false, tint := Color.WHITE, px := PIXEL, angle := 0.0) -> void:
	var fw := tex.get_width() / maxi(frames, 1)
	var src := Rect2(float(posmod(frame, frames) * fw), 0.0, float(fw), float(tex.get_height()))
	ci.draw_set_transform(feet, angle, Vector2(-px if flip else px, px))
	ci.draw_texture_rect_region(tex, Rect2(-origin, src.size), src, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The image holding a sprite's glowing pixels ("cave/brazier_lit.png" ->
## "cave/brazier_lit_glow.png"), or null when it has none.
static func glow_texture(rel_path: String) -> Texture2D:
	return texture(rel_path.trim_suffix(".png") + "_glow.png")


static var _unshaded: CanvasItemMaterial = null

## For things that must stay bright in the dark: lights and the dark tint skip them.
static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


static var _anchors: Dictionary = {}

## The numbers from art/anchors.json (frame sizes, origins, hand points).
static func anchors() -> Dictionary:
	if _anchors.is_empty():
		var f := FileAccess.open(ART_DIR + "anchors.json", FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_anchors = parsed
		if _anchors.is_empty():
			_anchors = {"missing": true}
	return _anchors


## Light texture: a soft round falloff, made in code.
## Who is who: player one madder red, player two sea blue (their scarves), then two spares.
const PLAYER_COLORS := [Color("#f06a40"), Color("#78c0cc"), Color("#86d4a4"), Color("#a878d0")]

static var _boxes := {}

## Draws a nine-patch image from art/ (a plate, a well, a button, a chip) stretched
## over rect. margins: one number, or [left, top, right, bottom], in the image's pixels.
## Returns false when the image is missing, so the caller can draw a plain box instead.
static func draw_nine(ci: CanvasItem, rel_path: String, rect: Rect2, margins = 4, tint := Color.WHITE) -> bool:
	var sb := nine(rel_path, margins)
	if sb == null:
		return false
	sb.modulate_color = tint
	ci.draw_style_box(sb, rect)
	return true


## The same nine-patch as a style box, for buttons and panels.
static func nine(rel_path: String, margins = 4) -> StyleBoxTexture:
	var key := "%s|%s" % [rel_path, margins]
	if not _boxes.has(key):
		var tex := texture(rel_path)
		if tex == null:
			_boxes[key] = null
		else:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			var m: Array = margins if margins is Array else [margins, margins, margins, margins]
			sb.texture_margin_left = m[0]
			sb.texture_margin_top = m[1]
			sb.texture_margin_right = m[2]
			sb.texture_margin_bottom = m[3]
			_boxes[key] = sb
	return _boxes[key]


const LIGHT_STEPS := {48: 2, 64: 3, 96: 3, 128: 4, 240: 5}   # light radius -> its file's step count

## One of the art's stepped, hatched lights, by radius in art pixels (null if the
## art is missing). Use it at texture_scale PIXEL and no other, or the hatch blurs.
static func stepped_light(radius: int) -> Texture2D:
	return texture("lights/light_r%d_s%d.png" % [radius, LIGHT_STEPS.get(radius, 3)])


static var _light_tex: Texture2D = null

static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_light_tex = t
	return _light_tex


static var _json_cache := {}

## Any JSON file under art/, parsed once.
static func json(rel_path: String) -> Dictionary:
	if not _json_cache.has(rel_path):
		var out := {}
		var f := FileAccess.open(ART_DIR + rel_path, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				out = parsed
		_json_cache[rel_path] = out
	return _json_cache[rel_path]


## One entry of art/gaps.json: the single effects and pieces drawn on 10 November
## (warnings, sparks, shadows, icons). {file, frame, frames, fps, origin, glow, note}.
static func piece(name: String) -> Dictionary:
	return json("gaps.json").get("files", {}).get(name, {})


static func piece_texture(name: String) -> Texture2D:
	var info := piece(name)
	return texture(str(info["file"])) if info.has("file") else null


## Draws frame `frame` of a piece with its origin at `at` (false if the art is missing).
static func draw_piece(ci: CanvasItem, name: String, frame: int, at: Vector2, angle := 0.0,
		flip := false, tint := Color.WHITE, px := PIXEL) -> bool:
	var info := piece(name)
	var tex := piece_texture(name)
	if tex == null:
		return false
	var o: Array = info.get("origin", [0, 0])
	draw_strip(ci, tex, int(info.get("frames", 1)), frame, at, Vector2(o[0], o[1]), flip, tint, px, angle)
	return true


## Where bright effects go: the layer above the lighting when the game has one
## (game_base.gd), otherwise beside the node that asked.
static func fx_root(from: Node) -> Node:
	var layer: Node = null
	if from.is_inside_tree():
		layer = from.get_tree().get_first_node_in_group("fx_root")
	return layer if layer != null else from.get_parent()


## Plays a piece once at a world position and returns it (null if the art is missing).
## Pieces marked ADDITIVE in the art's notes are blended that way and go on the
## bright layer; the rest go beside `from`, lit like everything else.
static func play_piece(from: Node, name: String, where: Vector2, angle := 0.0, size := 1.0) -> Node2D:
	var info := piece(name)
	var tex := piece_texture(name)
	if tex == null:
		return null
	var n: Node2D = load("res://scripts/fx/sprite_once.gd").new()
	n.texture = tex
	n.frames = int(info.get("frames", 1))
	n.fps = float(info.get("fps", 12))
	var o: Array = info.get("origin", [0, 0])
	n.origin = Vector2(o[0], o[1])
	n.angle = angle
	n.size = size
	n.additive = str(info.get("note", "")).contains("ADDITIVE")
	if info.get("glow", false):
		n.glow_texture = glow_texture(str(info["file"]))
	var parent := fx_root(from) if n.additive else from.get_parent()
	parent.add_child(n)
	n.global_position = where
	return n


static var _fonts := {}

## Pixel fonts from art/fonts (loaded at runtime so no import is needed).
static func font(name: String) -> Font:
	if _fonts.has(name):
		return _fonts[name]
	var f: Font = ThemeDB.fallback_font
	var path := ART_DIR + "fonts/%s.ttf" % name
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(path)   # not off the disk: see image()
		if not ff.data.is_empty():
			ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			ff.hinting = TextServer.HINTING_NONE
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			var ts := TextServerManager.get_primary_interface()
			ff.opentype_feature_overrides = {ts.name_to_tag("liga"): 0, ts.name_to_tag("calt"): 0}
			f = ff
	_fonts[name] = f
	return f
