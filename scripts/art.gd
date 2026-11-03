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
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(path)) == OK:
			tex = ImageTexture.create_from_image(img)
	_cache[rel_path] = tex
	return tex


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


static var _fonts := {}

## Pixel fonts from art/fonts (loaded at runtime so no import is needed).
static func font(name: String) -> Font:
	if _fonts.has(name):
		return _fonts[name]
	var f: Font = ThemeDB.fallback_font
	var path := ART_DIR + "fonts/%s.ttf" % name
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(ProjectSettings.globalize_path(path)) == OK:
			ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			ff.hinting = TextServer.HINTING_NONE
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			var ts := TextServerManager.get_primary_interface()
			ff.opentype_feature_overrides = {ts.name_to_tag("liga"): 0, ts.name_to_tag("calt"): 0}
			f = ff
	_fonts[name] = f
	return f
