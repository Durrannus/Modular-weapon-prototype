extends CanvasLayer
## The screen between the title and the Highlands: who plays which character, and in which world.
##
## Darren, 21 November 2026: "It works like terraria, player is saved". A character is its own save and goes into
## any world; a world is its own save (scripts/save.gd). So there are two steps here:
##
##   1  WHO IS PLAYING   Every player who joined on the title screen picks a character from the list, or makes a
##                       new one, in their own column with their own controls. Nobody can pick a character that
##                       somebody else has picked.
##   2  WHICH WORLD      One list for everybody: anyone picks a world, or makes a new one.
##
## A save is deleted with Delete (X on a controller) and a second press to make sure. Deleted saves are moved to the
## saves/deleted folder, not destroyed.
##
## Nothing here is new art: it is words on the menu kit's plates, and the bag's own little pictures. The game gives
## the names ("Character 3", "World 2"); typing your own comes later.

signal chosen(characters: Array, world: Dictionary)
signal back

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Save := preload("res://scripts/save.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Bag := preload("res://scripts/highlands/bag.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")

const SCREEN := Vector2(640, 360)
const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const AMBER := Color("#ffc850")
const EMBER := Color("#f06a40")
const FAINT := Color("#5f8072")
const PLATE := Color("#19142a")
const SHADOW := Color(0.06, 0.04, 0.11, 0.9)
const PLAYER_COLORS := Art.PLAYER_COLORS
const ROW := 34.0             # how tall one save's row is
const ROW_STEP := 36.0
const LIST_TOP := 92.0
const ROWS := 6               # rows a list shows at once (it scrolls when there are more)
const FADE := 0.3

var inputs: Array = []        # the players' controls, from the title screen (empty: one player on every device)
var count := 1                # how many are playing
var step := 0                 # 0: who is playing, 1: which world
var characters: Array = []    # every saved character, the one played last first
var worlds: Array = []        # every saved world, the same
var cursor: Array = []        # per player: the row they are on in the character list (the last row is "New character")
var top: Array = []           # per player: the first row their column shows
var locked: Array = []         # per player: they have picked
var world_cursor := 0
var world_top := 0
var asking := {}              # the save somebody asked to delete: {kind, id, name}
var t := 0.0
var leaving: Array = []       # [characters, world] once everything is picked: the screen fades, then the game starts
var leave_t := 0.0
var stick_ready := {}
var rects: Array = []         # for the mouse: [[Rect2, player or -1 for the world list, row]]
var root: Control
var sheet: Texture2D          # the bag's pictures are on the tool art's sheet
var boxes := {}


func _ready() -> void:
	layer = 20
	count = clampi(inputs.size(), 1, 2)
	Input.set_custom_mouse_cursor(null)
	sheet = Art.texture("tools/tools.png")
	boxes = Art.json("tools/tools.json").get("sprites", {})
	root = Control.new()
	root.size = SCREEN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.draw.connect(_draw_screen)
	_read()
	for i in count:
		# Player one starts on the character played last, player two on the one before it.
		cursor.append(mini(i, characters.size()))
		top.append(0)
		locked.append(false)


## The lists, from the disk.
func _read() -> void:
	characters = Save.list(Save.CHARACTERS)
	worlds = Save.list(Save.WORLDS)


func _process(delta: float) -> void:
	t += delta
	if not leaving.is_empty():
		leave_t += delta
		if leave_t >= FADE:
			set_process(false)
			set_process_input(false)
			chosen.emit(leaving[0], leaving[1])
			return
	root.queue_redraw()


# --- Who pressed what -------------------------------------------------------------

## Which player an event belongs to (-1: nobody who is playing).
func player_of(event: InputEvent) -> int:
	if inputs.size() <= 1:
		return 0
	var pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	for i in count:
		var inp = inputs[i]
		if pad and inp.kind == "pad" and inp.device == event.device:
			return i
		if not pad and inp.kind == "kbm":
			return i
	return -1


func _input(event: InputEvent) -> void:
	if not leaving.is_empty():
		return
	var who := player_of(event)
	if who < 0:
		return
	if event is InputEventMouseMotion:
		var hit := _under_mouse()
		if not hit.is_empty() and asking.is_empty():
			if step == 1 and int(hit[1]) < 0:
				world_cursor = int(hit[2])
			elif step == 0 and int(hit[1]) == who and not locked[who]:
				cursor[who] = int(hit[2])
		return
	if event is InputEventJoypadMotion:
		# The left stick moves the choice: one step for each push.
		var jm := event as InputEventJoypadMotion
		if jm.axis != JOY_AXIS_LEFT_Y:
			return
		if absf(jm.axis_value) < 0.3:
			stick_ready[jm.device] = true
		elif absf(jm.axis_value) > 0.6 and stick_ready.get(jm.device, true):
			stick_ready[jm.device] = false
			move(who, 1 if jm.axis_value > 0.0 else -1)
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		match (event as InputEventKey).physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: confirm(who)
			KEY_BACKSPACE, KEY_ESCAPE: go_back(who)
			KEY_W, KEY_UP: move(who, -1)
			KEY_S, KEY_DOWN: move(who, 1)
			KEY_DELETE: ask_delete(who)
	elif event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A, JOY_BUTTON_START: confirm(who)
			JOY_BUTTON_B: go_back(who)
			JOY_BUTTON_DPAD_UP: move(who, -1)
			JOY_BUTTON_DPAD_DOWN: move(who, 1)
			JOY_BUTTON_X: ask_delete(who)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var hit := _under_mouse()
		if not asking.is_empty():
			return
		if not hit.is_empty() and ((step == 1 and int(hit[1]) < 0) or (step == 0 and int(hit[1]) == who and not locked[who])):
			confirm(who)
	get_viewport().set_input_as_handled()


func _under_mouse() -> Array:
	var m := root.get_local_mouse_position()
	for r in rects:
		if (r[0] as Rect2).has_point(m):
			return r
	return []


# --- What the presses do ----------------------------------------------------------

func move(who: int, dy: int) -> void:
	if not asking.is_empty():
		return
	if step == 0:
		if locked[who]:
			return
		cursor[who] = posmod(int(cursor[who]) + dy, characters.size() + 1)
	else:
		world_cursor = posmod(world_cursor + dy, worlds.size() + 1)
	Sfx.play(self, "click", -16.0)


## The other player who has already picked this row's character (-1: nobody).
func taken_by(row: int, who: int) -> int:
	if row >= characters.size():
		return -1
	for p in count:
		if p != who and locked[p] and int(cursor[p]) == row:
			return p
	return -1


func confirm(who: int) -> void:
	if not asking.is_empty():
		_delete_now()
		return
	if step == 0:
		if locked[who]:
			return
		var row := int(cursor[who])
		if row < characters.size() and (characters[row].get("newer", false) or taken_by(row, who) >= 0):
			Sfx.play(self, "click", -14.0, 0.7)
			return
		locked[who] = true
		Sfx.play(self, "pickup", -10.0, 1.2)
		if not (false in locked):
			step = 1
			world_cursor = _last_world()
		return
	if world_cursor < worlds.size() and worlds[world_cursor].get("newer", false):
		Sfx.play(self, "click", -14.0, 0.7)
		return
	Sfx.play(self, "click", -8.0)
	leaving = [picked_characters(), picked_world()]
	leave_t = 0.0


## The row of the world player one's character was in last (the top of the list if it is gone, or they are new).
func _last_world() -> int:
	var row := int(cursor[0])
	if row < characters.size():
		var was := str(characters[row].get("world", ""))
		for i in worlds.size():
			if str(worlds[i].get("id", "")) == was:
				return i
	return 0


## What everybody picked: a saved character each, or one that has just been given its name and is not written yet.
func picked_characters() -> Array:
	var out: Array = []
	var given: Array = []
	for p in count:
		if int(cursor[p]) < characters.size():
			out.append(characters[int(cursor[p])])
		else:
			var c := Save.fresh(Save.CHARACTERS, given)
			given.append(c["id"])
			out.append(c)
	return out


func picked_world() -> Dictionary:
	return worlds[world_cursor] if world_cursor < worlds.size() else Save.fresh(Save.WORLDS)


func go_back(who: int) -> void:
	Sfx.play(self, "click", -14.0, 0.7)
	if not asking.is_empty():
		asking = {}
	elif step == 1:
		step = 0
		for p in count:
			locked[p] = false
	elif locked[who]:
		locked[who] = false
	else:
		set_process_input(false)
		back.emit()


func ask_delete(who: int) -> void:
	if not asking.is_empty():
		return
	if step == 0:
		var row := int(cursor[who])
		if locked[who] or row >= characters.size() or taken_by(row, who) >= 0:
			return
		asking = {"kind": Save.CHARACTERS, "id": str(characters[row]["id"]), "name": str(characters[row]["name"])}
	elif world_cursor < worlds.size():
		asking = {"kind": Save.WORLDS, "id": str(worlds[world_cursor]["id"]), "name": str(worlds[world_cursor]["name"])}
	if not asking.is_empty():
		Sfx.play(self, "click", -12.0, 0.8)


func _delete_now() -> void:
	# Everybody stays on the character they were on, by its name: the rows move up when one goes.
	var on: Array = []
	for p in count:
		on.append(str(characters[int(cursor[p])]["id"]) if int(cursor[p]) < characters.size() else "")
	Save.remove(str(asking["kind"]), str(asking["id"]))
	asking = {}
	_read()
	for p in count:
		var row := mini(int(cursor[p]), characters.size())
		for i in characters.size():
			if str(characters[i]["id"]) == on[p]:
				row = i
		cursor[p] = row
	world_cursor = mini(world_cursor, worlds.size())
	Sfx.play(self, "click", -8.0, 0.6)


# --- What a row says --------------------------------------------------------------

## What a character has in its hands, in a word or two.
static func weapon_words(c: Dictionary) -> String:
	if bool(c.get("swap", false)):
		return "Four weapons"
	var w = c.get("weapons")
	if w is Dictionary and w.get("hand") is Array and (w["hand"] as Array).size() > 0 and w["hand"][0] is String:
		return str(SwingBuild.WEAPON_NAMES[SwingBuild.weapon_of(w["hand"][0])])
	return "Sword"


## What is in a character's materials bag: [[item, how many]], in the bag's own order.
static func bag_counts(c: Dictionary) -> Array:
	var bag := Bag.new()
	bag.set_data(c.get("bag"))
	var out: Array = []
	for item in Bag.ORDER:
		if bag.count(item) > 0:
			out.append([item, bag.count(item)])
	return out


## A world in a sentence: its number, and what has been done to it.
static func world_words(w: Dictionary) -> String:
	if w.get("newer", false):
		return "Saved by a newer version of the game: it cannot be opened here."
	if older_land(w):
		return "Older land: it will be laid out again, without what was dug."
	var dug: int = (w["dug"] as Array).size() if w.get("dug") is Array else 0
	var felled: int = (w["added"] as Array).size() if w.get("added") is Array else 0
	var words := "Number %d." % int(w.get("seed", 0))
	if squad_level(w) > 0:
		words += "  Squad level %d." % squad_level(w)
	if dug > 0:
		words += "  %d dug." % dug
	if felled > 0:
		words += "  %d felled." % felled
	if dug == 0 and felled == 0 and squad_level(w) == 0:
		words += "  Untouched."
	if w.get("restored", false):
		words += "  (From its backup.)"
	return words


## The squad's level in a saved world (0 in one from before there were levels).
static func squad_level(w: Dictionary) -> int:
	return maxi(int(w["level"]), 0) if (w.get("level") is int or w.get("level") is float) else 0


## How many perks a saved character has learnt, in words ("" for none).
static func perk_words(c: Dictionary) -> String:
	var n: int = (c["perks"] as Array).size() if c.get("perks") is Array else 0
	return "" if n == 0 else ("1 perk" if n == 1 else "%d perks" % n)


## Was this world saved on a land that this game makes differently now?
static func older_land(w: Dictionary) -> bool:
	return int(w.get("land", 0)) != WorldGen.GEN and not w.get("unsaved", false)


# --- Drawing ----------------------------------------------------------------------

func _words(f: Font, at: Vector2, text: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	root.draw_string(f, at + Vector2(1, 1), text, align, width, size, Color(SHADOW, SHADOW.a * col.a))
	root.draw_string(f, at, text, align, width, size, col)


func _width(f: Font, text: String, size: int) -> float:
	return ceilf(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)


## Keeps the row the cursor is on inside the rows a list shows.
static func window(first: int, on: int, rows: int, total: int) -> int:
	first = clampi(first, maxi(on - rows + 1, 0), on)
	return clampi(first, 0, maxi(total - rows, 0))


func _draw_screen() -> void:
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font(Art.TEXT)
	var backdrop := Art.texture("swing/ui/title_backdrop.png")
	if backdrop != null:
		root.draw_texture(backdrop, Vector2.ZERO)
	else:
		root.draw_rect(Rect2(Vector2.ZERO, SCREEN), PLATE)
	var plate := Rect2(16, 12, 608, 316)
	if not Art.draw_nine(root, "swing/ui/panel.png", plate, 8):
		root.draw_rect(plate, PLATE)
	rects = []

	_words(silk, Vector2(32, 38), "WHO IS PLAYING?" if step == 0 else "WHICH WORLD?", 16, AMBER)
	_words(silk, Vector2(32, 38), "STEP %d OF 2" % (step + 1), 8, DIM, 576.0, HORIZONTAL_ALIGNMENT_RIGHT)
	if step == 0:
		_words(pix, Vector2(32, 56), "A character keeps its weapons, runes, tools, bag, coins and perks, and can go into any world.", Art.TEXT_SIZE, INK)
		var width := 280.0 if count > 1 else 360.0
		for p in count:
			var x := 32.0 + float(p) * 296.0 if count > 1 else 140.0
			_draw_characters(p, x, width, silk, pix)
	else:
		var who: Array = []
		for p in count:
			var row := int(cursor[p])
			var name := str(characters[row]["name"]) if row < characters.size() else "a new character"
			who.append(("Player %d: %s" % [p + 1, name]) if count > 1 else "Playing %s" % name)
		_words(pix, Vector2(32, 56), ".   ".join(who) + ".   A world keeps its land and the squad's level.", Art.TEXT_SIZE, INK)
		_draw_worlds(120.0, 400.0, silk, pix)

	# The bottom band: what the buttons do.
	for band in 3:
		root.draw_rect(Rect2(0, SCREEN.y - 32 + 2 * band, SCREEN.x, 32 - 2 * band), Color(PLATE, 0.22))
	var hint := "W / S or stick: choose     Enter or A: pick     Delete or X: delete     Backspace or B: back"
	if not asking.is_empty():
		hint = "Enter or A: delete it     Backspace or B: keep it"
	root.draw_string(pix, Vector2(10, SCREEN.y - 16), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE, DIM)

	if not asking.is_empty():
		_draw_asking(silk, pix)

	# Up out of black when the screen opens, and back down to it when the game starts.
	var dark := maxf(1.0 - t / FADE, 0.0 if leaving.is_empty() else leave_t / FADE)
	if dark > 0.0:
		root.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.02, 0.02, 0.05, minf(dark, 1.0)))


## One player's column: their name, and the characters to pick from.
func _draw_characters(p: int, x: float, width: float, silk: Font, pix: Font) -> void:
	var total := characters.size() + 1
	top[p] = window(int(top[p]), int(cursor[p]), ROWS, total)
	var head := LIST_TOP - 8.0
	if count > 1:
		var device := "Keyboard + mouse"
		if inputs[p].kind == "pad":
			device = "Controller %d" % (int(inputs[p].device) + 1)
		_words(silk, Vector2(x, head), "PLAYER %d" % (p + 1), 8, PLAYER_COLORS[p])
		_words(pix, Vector2(x + 62.0, head), device, Art.TEXT_SIZE, DIM)
	if locked[p]:
		_words(silk, Vector2(x, head), "READY", 8, AMBER, width, HORIZONTAL_ALIGNMENT_RIGHT)
	elif total > ROWS:
		_words(silk, Vector2(x, head), "%d TO %d OF %d" % [int(top[p]) + 1, mini(int(top[p]) + ROWS, total), total], 8, FAINT, width, HORIZONTAL_ALIGNMENT_RIGHT)
	for n in mini(ROWS, total - int(top[p])):
		var row := int(top[p]) + n
		var r := Rect2(x, LIST_TOP + float(n) * ROW_STEP, width, ROW)
		var on := row == int(cursor[p])
		var faded: bool = locked[p] and not on
		if not locked[p]:
			rects.append([r, p, row])
		if row >= characters.size():
			_draw_row(r, on, faded, "+ New character", "", DIM, ["Four test weapons and the basic tools."], "", silk, pix)
			continue
		var c: Dictionary = characters[row]
		var other := taken_by(row, p)
		var parts: Array = [weapon_words(c)]
		if c.get("newer", false):
			parts = ["Saved by a newer version of the game: it cannot be played here."]
		elif c.get("restored", false):
			parts = [weapon_words(c), "(from its backup)"]
		if not c.get("newer", false):
			if perk_words(c) != "":
				parts[0] = "%s, %s" % [parts[0], perk_words(c)]
			if (c.get("coins") is int or c.get("coins") is float) and int(c["coins"]) > 0:
				parts.append(["coins", int(c["coins"])])
			# The bag from its dearest thing to its cheapest, so what is left off a full row is the stone.
			var held := bag_counts(c)
			held.reverse()
			parts.append_array(held)
		var right := Save.when(float(c.get("played", 0.0)))
		var right_col := DIM
		if other >= 0:
			right = "PLAYER %d" % (other + 1)
			right_col = PLAYER_COLORS[other]
		_draw_row(r, on, faded or other >= 0 or c.get("newer", false), str(c["name"]), right, right_col, parts, Save.how_long(float(c.get("seconds", 0.0))) + " played", silk, pix)


func _draw_worlds(x: float, width: float, silk: Font, pix: Font) -> void:
	var total := worlds.size() + 1
	world_top = window(world_top, world_cursor, ROWS, total)
	if total > ROWS:
		_words(silk, Vector2(x, LIST_TOP - 8.0), "%d TO %d OF %d" % [world_top + 1, mini(world_top + ROWS, total), total], 8, FAINT, width, HORIZONTAL_ALIGNMENT_RIGHT)
	for n in mini(ROWS, total - world_top):
		var row := world_top + n
		var r := Rect2(x, LIST_TOP + float(n) * ROW_STEP, width, ROW)
		var on := row == world_cursor
		rects.append([r, -1, row])
		if row >= worlds.size():
			_draw_row(r, on, false, "+ New world", "", DIM, ["A land nobody has seen, laid out from a new number."], "", silk, pix)
			continue
		var w: Dictionary = worlds[row]
		_draw_row(r, on, w.get("newer", false), str(w["name"]), Save.when(float(w.get("played", 0.0))), DIM, [world_words(w)],
			Save.how_long(float(w.get("seconds", 0.0))) + " played", silk, pix)


## One row: its name and when it was last played on the first line; what it holds and how long it has been played
## on the second. `parts` are the second line's pieces: words, or [item, how many] for something in the bag.
func _draw_row(r: Rect2, on: bool, faded: bool, title: String, right: String, right_col: Color, parts: Array, right2: String, silk: Font, pix: Font) -> void:
	var a := 0.45 if faded else 1.0
	if not Art.draw_nine(root, "swing/ui/well_selected.png" if on else "swing/ui/well.png", r, 3, Color(1, 1, 1, a)):
		root.draw_rect(r, Color(AMBER if on else FAINT, a), false, 1.0)
	var x := r.position.x + 8.0
	if on:
		var arrow := Art.texture("swing/ui/cursor.png")
		if arrow != null:
			root.draw_texture(arrow, Vector2(x + (1.0 if fmod(t, 0.8) < 0.4 and not faded else 0.0), r.position.y + 4.0))
		x += 12.0
	var inner := r.size.x - 16.0
	_words(silk, Vector2(x, r.position.y + 13.0), title.to_upper(), 8, Color(AMBER if on else INK, a))
	if right != "":
		_words(pix, Vector2(r.position.x + 8.0, r.position.y + 13.0), right, Art.TEXT_SIZE, Color(right_col, a), inner, HORIZONTAL_ALIGNMENT_RIGHT)
	if right2 != "":
		_words(pix, Vector2(r.position.x + 8.0, r.position.y + 28.0), right2, Art.TEXT_SIZE, Color(FAINT, a), inner, HORIZONTAL_ALIGNMENT_RIGHT)
	# What it holds stops short of the words at the right: what does not fit is counted ("+3 more").
	var limit := r.position.x + 8.0 + inner - (_width(pix, right2, Art.TEXT_SIZE) + 12.0 if right2 != "" else 0.0)
	for k in parts.size():
		var part = parts[k]
		var more := "+%d more" % (parts.size() - k)
		var room := limit - (_width(pix, more, Art.TEXT_SIZE) + 4.0 if k < parts.size() - 1 else 0.0)
		if part is String:
			if x + _width(pix, part, Art.TEXT_SIZE) > room and k > 0:
				_words(pix, Vector2(x, r.position.y + 28.0), more, Art.TEXT_SIZE, Color(DIM, a))
				break
			_words(pix, Vector2(x, r.position.y + 28.0), part, Art.TEXT_SIZE, Color(DIM, a))
			x += _width(pix, part, Art.TEXT_SIZE) + 10.0
		elif part is Array and ItemArt.size("item_" + str(part[0])) != Vector2.ZERO:
			var n := str(int(part[1]))
			if x + ItemArt.size("item_" + str(part[0])).x + 1.0 + _width(silk, n, 8) > room:
				_words(pix, Vector2(x, r.position.y + 28.0), more, Art.TEXT_SIZE, Color(DIM, a))
				break
			x += ItemArt.draw(root, "item_" + str(part[0]), Vector2(x, r.position.y + 16.0), 1.0, Color(1, 1, 1, a)).x + 1.0
			_words(silk, Vector2(x, r.position.y + 28.0), n, 8, Color(INK, a))
			x += _width(silk, n, 8) + 6.0


## "Delete Character 3?", over everything else.
func _draw_asking(silk: Font, pix: Font) -> void:
	root.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.06, 0.04, 0.09, 0.6))
	var r := Rect2(150, 126, 340, 92)
	if not Art.draw_nine(root, "swing/ui/panel.png", r, 8):
		root.draw_rect(r, PLATE)
	_words(silk, Vector2(r.position.x, r.position.y + 26.0), "DELETE %s?" % str(asking["name"]).to_upper(), 16, AMBER, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_words(pix, Vector2(r.position.x, r.position.y + 46.0), "It leaves the lists and is moved to the game's", Art.TEXT_SIZE, INK, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_words(pix, Vector2(r.position.x, r.position.y + 59.0), "saves/deleted folder, where it can still be put back by hand.", Art.TEXT_SIZE, INK, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_words(pix, Vector2(r.position.x, r.position.y + 79.0), "Enter or A: delete it        Backspace or B: keep it", Art.TEXT_SIZE, DIM, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
