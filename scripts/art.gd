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
