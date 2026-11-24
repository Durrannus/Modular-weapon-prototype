extends Node
## The squad's map of the Highlands: a small one in the top right corner, and the whole of it on M (version 56).
##
## Darren, 24 November 2026, after playing version 55: "need a small map top right so can see what fog of war has
## been cleared. and a full map using M button."
##
## Claude's choices, until Darren says otherwise (they are listed in the README and the Game Bible):
##   - What has been seen is what has been on the screen: an oval a little wider than the screen around its middle
##     (REVEAL), worked out four times a second. It is the world's, saved with it, and shared by the whole squad.
##   - The small map is one screen pixel to a tile, 80 tiles a side (two screens wide), around the middle of the
##     screen; the quests' list moves down under it.
##   - Its colours are the land's own (the Highlands kit's palette): ochre ground, pale footpaths, blue-grey rock,
##     lighter dug floor, dark water. Ore is drawn as the rock it is in, so the map stays plain. Land nobody has
##     seen is the dark of the screens' plates.
##   - Marks: each player as a dot in their colour, the cave mouth as a small pale arch. The whole map adds the
##     names of the places somebody has seen.
##   - The whole map stops the game, like the inventory. It opens and closes on M (or a click of the right stick,
##     when that is not the test setup's weapon swap); Esc, B and Start close it too.
##   - Online (on hold) has no map yet.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")

const SCREEN := Vector2(640, 360)
const MARGIN := 10.0
const VIEW := 80                   # the small map: tiles a side, one screen pixel each
const REVEAL := Vector2(22.0, 13.5)   # half the width and height of what is seen, in tiles (the screen is 40 by 22.5)
const LOOK := 0.25                 # seconds between looks
const TILE := 32.0                 # world units in a tile
const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const FAINT := Color("#5f8072")
const AMBER := Color("#ffc850")
const PLATE := Color("#19142a")
const SHADOW := Color(0.06, 0.04, 0.09, 0.9)
const FOG := 15                    # the palette's entry for land nobody has seen

## Each kind of land's colour on the map, from the Highlands kit's palette (art/highlands/kit.json).
const COLOURS := {
	LandMap.GRASS: "a68e52", LandMap.SCRUB: "8a7448", LandMap.HEATH: "8a7448", LandMap.PATH: "dcc888",
	LandMap.YARD: "6a5642", LandMap.WATER: "1a5654", LandMap.ROCK: "2b3247", LandMap.TIN: "2b3247",
	LandMap.COPPER: "2b3247", LandMap.FLOOR: "446264", LandMap.SCREE: "6e6a7c",
}
## What the named places are called on the whole map.
const PLACE_NAMES := {
	"quarry": "Old Quarry", "watchpost": "Keeper's Watchpost", "roost": "Slinger Roost", "den": "Hound Den",
	"cairns": "Cairn Field", "gorge": "Echo Gorge", "fault": "The Fault", "scrapyard": "Rattlecrown's Scrapyard",
}

const SHADER := """
shader_type canvas_item;
uniform sampler2D seen : filter_nearest;
uniform sampler2D palette : filter_nearest;
void fragment() {
	int k = int(texture(TEXTURE, UV).r * 255.0 + 0.5);
	float s = texture(seen, UV).r;
	COLOR = texelFetch(palette, ivec2(s > 0.5 ? k : 15, 0), 0);
}
"""

var game                           # the Highlands (highlands.gd)
var map: LandMap
var players: Array = []
var rig                            # the camera (camera_rig.gd)
var allowed := true                # the game says whether the whole map may be opened now
var can_swap := false              # the test setup's weapon swap has the right stick's click

var explored := PackedByteArray()  # SIZE x SIZE: 255 where somebody has seen the land, 0 where nobody has
var is_open := false
var clock := 0.0
var _look := 0.0
var _seen_dirty := true
var _dug := -1
var seen_img: Image
var seen_tex: ImageTexture
var kinds_img: Image
var kinds_tex: ImageTexture
var mat: ShaderMaterial
var corner: Control                # the small map's frame
var corner_land: Control           # its land (drawn by the shader)
var corner_marks: Control          # and the marks over it
var screen: Control
var _opened_at := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if explored.size() != LandMap.SIZE * LandMap.SIZE:
		explored = PackedByteArray()
		explored.resize(LandMap.SIZE * LandMap.SIZE)
	var pal := Image.create(16, 1, false, Image.FORMAT_RGBA8)
	pal.fill(Color(PLATE, 0.86))
	for k in COLOURS:
		pal.set_pixel(int(k), 0, Color(str(COLOURS[k])))
	pal.set_pixel(FOG, 0, Color(PLATE, 0.86))
	seen_img = Image.create_from_data(LandMap.SIZE, LandMap.SIZE, false, Image.FORMAT_R8, explored)
	seen_tex = ImageTexture.create_from_image(seen_img)
	kinds_img = Image.create_from_data(LandMap.SIZE, LandMap.SIZE, false, Image.FORMAT_R8, map.kinds)
	kinds_tex = ImageTexture.create_from_image(kinds_img)
	_dug = map.dug.size()
	var shader := Shader.new()
	shader.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("seen", seen_tex)
	mat.set_shader_parameter("palette", ImageTexture.create_from_image(pal))
	# The small map, with the HUD.
	var low := CanvasLayer.new()
	low.layer = 5
	add_child(low)
	corner = Control.new()
	corner.size = SCREEN
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	low.add_child(corner)
	corner.draw.connect(_draw_corner)
	corner_land = Control.new()
	corner_land.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner_land.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	corner_land.material = mat
	corner.add_child(corner_land)
	corner_land.draw.connect(_draw_corner_land)
	corner_marks = Control.new()
	corner_marks.size = SCREEN
	corner_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_child(corner_marks)
	corner_marks.draw.connect(_draw_corner_marks)
	# The whole map, over everything but the pause menu.
	var high := CanvasLayer.new()
	high.layer = 11
	add_child(high)
	screen = Control.new()
	screen.size = SCREEN
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.visible = false
	high.add_child(screen)
	screen.draw.connect(_draw_screen)


# --- What has been seen -----------------------------------------------------------------------

## Called on the game's physics tick: look around four times a second.
func tick(delta: float) -> void:
	_look -= delta
	if _look > 0.0:
		return
	_look = LOOK
	reveal(_middle())


## The middle of what is on the screen (world units).
func _middle() -> Vector2:
	if rig != null and is_instance_valid(rig) and rig.camera != null and rig.camera.is_inside_tree():
		return rig.view_rect().get_center()
	var sum := Vector2.ZERO
	var n := 0
	for p in players:
		if is_instance_valid(p):
			sum += p.global_position
			n += 1
	return sum / float(n) if n > 0 else Vector2(LandMap.MID, LandMap.MID) * TILE


## Mark as seen the oval of land around `at` (world units).
func reveal(at: Vector2) -> void:
	var c := at / TILE
	var x0 := maxi(floori(c.x - REVEAL.x), 0)
	var x1 := mini(ceili(c.x + REVEAL.x), LandMap.SIZE - 1)
	var y0 := maxi(floori(c.y - REVEAL.y), 0)
	var y1 := mini(ceili(c.y + REVEAL.y), LandMap.SIZE - 1)
	for y in range(y0, y1 + 1):
		var dy := (float(y) + 0.5 - c.y) / REVEAL.y
		if dy * dy > 1.0:
			continue
		var half := REVEAL.x * sqrt(1.0 - dy * dy)
		var a := maxi(floori(c.x - half + 0.5), x0)
		var b := mini(floori(c.x + half - 0.5), x1)
		var row := y * LandMap.SIZE
		for x in range(a, b + 1):
			if explored[row + x] == 0:
				explored[row + x] = 255
				_seen_dirty = true


## Has somebody seen tile (x, y)?
func seen(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < LandMap.SIZE and y < LandMap.SIZE and explored[y * LandMap.SIZE + x] != 0


## How many tiles have been seen (for the checks).
func seen_count() -> int:
	return explored.count(255)


## Bring the pictures up to date with what has been seen and dug.
func _refresh() -> void:
	if _seen_dirty:
		_seen_dirty = false
		seen_img.set_data(LandMap.SIZE, LandMap.SIZE, false, Image.FORMAT_R8, explored)
		seen_tex.update(seen_img)
	if map.dug.size() != _dug:
		_dug = map.dug.size()
		kinds_img.set_data(LandMap.SIZE, LandMap.SIZE, false, Image.FORMAT_R8, map.kinds)
		kinds_tex.update(kinds_img)


# --- The whole map, on M ------------------------------------------------------------------------

func can_open() -> bool:
	return allowed and not get_tree().paused


func open() -> bool:
	if is_open or not can_open():
		return false
	is_open = true
	_opened_at = clock
	get_tree().paused = true
	_refresh()
	screen.visible = true
	screen.queue_redraw()
	Sfx.play(self, "click", -10.0, 0.8)
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	screen.visible = false
	get_tree().paused = false
	Sfx.play(self, "click", -14.0, 0.7)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton) or not event.is_pressed() or event.is_echo():
		return
	var toggles: bool = (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_M) \
		or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_STICK and not can_swap)
	if is_open:
		get_viewport().set_input_as_handled()
		if clock - _opened_at < 0.12:
			return
		var shuts := toggles
		if event is InputEventKey:
			shuts = shuts or (event as InputEventKey).physical_keycode in [KEY_ESCAPE, KEY_BACKSPACE]
		else:
			shuts = shuts or (event as InputEventJoypadButton).button_index in [JOY_BUTTON_B, JOY_BUTTON_START]
		if shuts:
			close()
	elif toggles and open():
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	clock += delta
	var shown := _corner_shown()
	corner.visible = shown
	if shown:
		_refresh()
		corner.queue_redraw()
		corner_land.queue_redraw()
		corner_marks.queue_redraw()
	if is_open:
		screen.queue_redraw()


# --- What is saved (with the world) ---------------------------------------------------------

func world_data() -> Dictionary:
	return {"seen": Marshalls.raw_to_base64(explored.compress(FileAccess.COMPRESSION_DEFLATE))}


## And back. A save from before version 56, or one that does not read, leaves the land unseen.
func set_world_data(d: Dictionary) -> void:
	if not d.get("seen") is String:
		return
	var text := str(d["seen"])
	if text.length() % 4 != 0 or not RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}$").search(text):
		return
	var raw := Marshalls.base64_to_raw(text)
	if raw.is_empty():
		return
	var back := raw.decompress(LandMap.SIZE * LandMap.SIZE, FileAccess.COMPRESSION_DEFLATE)
	if back.size() != LandMap.SIZE * LandMap.SIZE:
		return
	explored = back
	_seen_dirty = true
	if seen_img != null:
		_refresh()


# --- Looks only ---------------------------------------------------------------------------------

func _corner_shown() -> bool:
	if get_tree().paused or is_open:
		return false
	if game != null and game.ui != null and (game.ui.busy() or game.ui.fade > 0.5):
		return false
	return true


## Where the small map is on the screen: the top right corner, or under the second player's bars.
func rect() -> Rect2:
	var y := 10.0 if players.size() < 2 else 78.0
	return Rect2(SCREEN.x - MARGIN - float(VIEW), y, float(VIEW), float(VIEW))


## The tile at the small map's top left corner: it is kept on the middle of the screen.
func corner_from() -> Vector2:
	return (_middle() / TILE - Vector2(VIEW, VIEW) * 0.5).floor()


func _draw_corner() -> void:
	var r := rect()
	if not Art.draw_nine(corner, "swing/ui/well.png", r.grow(3.0), 3):
		corner.draw_rect(r.grow(3.0), PLATE)


func _draw_corner_land() -> void:
	var r := rect()
	corner_land.position = r.position
	corner_land.size = r.size
	corner_land.draw_texture_rect_region(kinds_tex, Rect2(Vector2.ZERO, r.size), Rect2(corner_from(), Vector2(VIEW, VIEW)))


func _draw_corner_marks() -> void:
	_draw_marks(corner_marks, rect(), corner_from(), 1.0)


## The cave mouth and the players, over land drawn at `scale` screen pixels a tile from `top_left` (tiles) in `r`.
## Marks past the edge are kept just inside it.
func _draw_marks(ci: CanvasItem, r: Rect2, top_left: Vector2, scale: float) -> void:
	var inside := r.grow(-2.0)
	var cave := r.position + (Vector2(map.mouth) + Vector2(0.5, 1.0) - top_left) * scale
	if inside.has_point(cave):
		# A small pale arch: the way down to the forge.
		var c := cave.round()
		ci.draw_rect(Rect2(c + Vector2(-3, -4), Vector2(7, 5)), PLATE)
		ci.draw_rect(Rect2(c + Vector2(-2, -3), Vector2(5, 4)), INK)
		ci.draw_rect(Rect2(c + Vector2(-1, -2), Vector2(3, 3)), PLATE)
	for i in players.size():
		var p = players[i]
		if not is_instance_valid(p):
			continue
		var at: Vector2 = r.position + (p.global_position / TILE - top_left) * scale
		at = Vector2(clampf(at.x, inside.position.x, inside.end.x), clampf(at.y, inside.position.y, inside.end.y)).round()
		var col: Color = Art.PLAYER_COLORS[i % Art.PLAYER_COLORS.size()]
		if p.is_down:
			col = Color(col, 0.5)
		ci.draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), PLATE)
		ci.draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), col)


## The whole map: the land somebody has seen, as big as it fits.
func area() -> Rect2:
	return Rect2(24.0, 34.0, 592.0, 294.0)


## The part of the land the whole map shows (tiles): everything that has been seen, with a little room around it.
func shown_tiles() -> Rect2:
	var lo := Vector2i(LandMap.SIZE, LandMap.SIZE)
	var hi := Vector2i(-1, -1)
	var region: Rect2i = map.region
	for y in range(region.position.y, region.end.y):
		var row := explored.slice(y * LandMap.SIZE + region.position.x, y * LandMap.SIZE + region.end.x)
		var first := row.find(255)
		if first < 0:
			continue
		var last := row.rfind(255)
		lo = Vector2i(mini(lo.x, region.position.x + first), mini(lo.y, y))
		hi = Vector2i(maxi(hi.x, region.position.x + last), maxi(hi.y, y))
	if hi.x < 0:
		lo = map.mouth - Vector2i(20, 12)
		hi = map.mouth + Vector2i(20, 12)
	var r := Rect2(Vector2(lo), Vector2(hi - lo) + Vector2.ONE).grow(6.0)
	# Never closer than three screen pixels a tile.
	var a := area()
	var least := a.size / 3.0
	if r.size.x < least.x:
		r = r.grow_individual((least.x - r.size.x) * 0.5, 0.0, (least.x - r.size.x) * 0.5, 0.0)
	if r.size.y < least.y:
		r = r.grow_individual(0.0, (least.y - r.size.y) * 0.5, 0.0, (least.y - r.size.y) * 0.5)
	return r


func _draw_screen() -> void:
	if not is_open:
		return
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font(Art.TEXT)
	screen.material = null
	screen.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.06, 0.04, 0.09, 0.6))
	var plate := Rect2(12.0, 10.0, 616.0, 340.0)
	if not Art.draw_nine(screen, "swing/ui/panel.png", plate, 8):
		screen.draw_rect(plate, PLATE)
	_words(screen, silk, Vector2(24, 26), "MAP OF THE HIGHLANDS", 8, AMBER)
	_words(screen, pix, Vector2(24, 26), "M: close", Art.TEXT_SIZE, FAINT, 592.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var a := area()
	var src := shown_tiles()
	# Whole pixels a tile once there is room for two or more; between one and two it fills the space, so the map is
	# not drawn needlessly small.
	var scale := minf(a.size.x / src.size.x, a.size.y / src.size.y)
	if scale >= 2.0:
		scale = floorf(scale)
	var size := src.size * scale
	var dest := Rect2((a.position + (a.size - size) * 0.5).round(), size)
	# The land, drawn by a child so the plate and the words keep their own looks.
	var land := screen.get_node_or_null("Land") as Control
	if land == null:
		land = Control.new()
		land.name = "Land"
		land.mouse_filter = Control.MOUSE_FILTER_IGNORE
		land.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		land.material = mat
		land.draw.connect(func(): land.draw_texture_rect_region(kinds_tex, Rect2(Vector2.ZERO, land.size), land.get_meta("src")))
		screen.add_child(land)
	land.position = dest.position
	land.size = dest.size
	land.set_meta("src", src)
	land.queue_redraw()
	# The marks and the names go over it, on a child drawn after it.
	var over := screen.get_node_or_null("Over") as Control
	if over == null:
		over = Control.new()
		over.name = "Over"
		over.size = SCREEN
		over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		over.draw.connect(_draw_over)
		screen.add_child(over)
	over.set_meta("dest", dest)
	over.set_meta("src", src)
	over.set_meta("scale", scale)
	over.queue_redraw()


func _draw_over() -> void:
	var over := screen.get_node("Over") as Control
	var dest: Rect2 = over.get_meta("dest")
	var src: Rect2 = over.get_meta("src")
	var scale: float = over.get_meta("scale")
	var pix := Art.font(Art.TEXT)
	for name in PLACE_NAMES:
		if not map.sites.has(name):
			continue
		var at: Vector2 = map.sites[name]["at"]
		if not seen(int(at.x), int(at.y)):
			continue
		var p := dest.position + (at - src.position) * scale
		if dest.has_point(p):
			_words(over, pix, (p + Vector2(-60, 4)).round(), str(PLACE_NAMES[name]), Art.TEXT_SIZE, INK, 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	var cave := dest.position + (Vector2(map.mouth) + Vector2(0.5, 1.0) - src.position) * scale
	if dest.has_point(cave):
		_words(over, pix, (cave + Vector2(-60, -8)).round(), "Your cave", Art.TEXT_SIZE, DIM, 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_marks(over, dest, src.position, scale)


func _words(ci: CanvasItem, f: Font, at: Vector2, text: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string(f, at + Vector2(1, 1), text, align, width, size, Color(SHADOW, SHADOW.a * col.a))
	ci.draw_string(f, at, text, align, width, size, col)
