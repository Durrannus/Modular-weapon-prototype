extends CanvasLayer
## Pip's shop (version 46): one screen on the menu kit's plates, in the forge's screen's manner.
##
## The Game Bible: Pip "buys spare parts for coins, sells tin and copper bars and one rotating tier 1 accessory".
## There are no spare parts to sell him yet, so he sells bars and, since version 47 (the Accessory Satchel), the
## one accessory he has that day (folk.ware()), and tells you where the Warhorn's pieces are ("gives the odd hint
## about places").
##
## The player who spoke to him has the screen; with two players the other one's controls do nothing here. The game
## stands still while it is open. The rules (what a bar costs, whether you can buy one) are folk.gd's.

signal closed(i: int)

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")
const Bag := preload("res://scripts/highlands/bag.gd")
const Accessories := preload("res://scripts/highlands/accessories.gd")

const SCREEN := Vector2(640, 360)
const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const FAINT := Color("#5f8072")
const AMBER := Color("#ffc850")
const PLATE := Color("#19142a")
const SHADOW := Color(0.06, 0.04, 0.11, 0.9)
const BOX := Rect2(140, 38, 360, 284)
const BARS := ["tin_bar", "copper_bar"]
const ASK := "Ask about the Scrap Crown"
const LEAVE := "Leave"

var folk                      # scripts/highlands/folk.gd
var who := 0                  # the player who has the screen
var is_open := false
var row := 0
var line := ""                # what Pip is saying
var note := ""                # a line of news (what a press did, or why it did nothing)
var note_until := -9.0
var t := 0.0
var opened_at := 0.0
var stick_ready := {}
var rects: Array = []         # for the mouse: [[Rect2, row]]
var root: Control


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.size = SCREEN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)
	root.draw.connect(_draw_screen)


## What he sells, top row first: the bars, then his accessory if he has one.
func items() -> Array:
	var out: Array = BARS.duplicate()
	var ware: String = folk.ware() if folk != null else ""
	if ware != "":
		out.append(ware)
	return out


## The rows, top first: what he sells, then the question, then the way out.
func rows() -> Array:
	var out: Array = []
	for item in items():
		out.append(Bag.name_of(str(item)))
	out.append(ASK)
	out.append(LEAVE)
	return out


func open(i: int) -> void:
	if is_open or folk == null:
		return
	who = i
	is_open = true
	row = 0
	note = ""
	line = folk.SHOP_LINE
	opened_at = t
	root.visible = true
	get_tree().paused = true
	Sfx.play(self, "click", -10.0, 0.8)


func close() -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	get_tree().paused = false
	closed.emit(who)


func _process(delta: float) -> void:
	t += delta
	if is_open:
		root.queue_redraw()


func say(text: String, seconds := 4.0) -> void:
	note = text
	note_until = t + seconds


## Does this press belong to the player who has the screen? (One player has every device.)
func _mine(event: InputEvent) -> bool:
	var players: Array = folk.players
	if players.size() <= 1 or who >= players.size() or not is_instance_valid(players[who]):
		return true
	var inp = players[who].input
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return inp.kind == "pad" and inp.device == event.device
	return inp.kind == "kbm"


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
	if not _mine(event):
		return
	if event is InputEventMouseMotion:
		var hit := _under_mouse()
		if hit >= 0:
			row = hit
		return
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if jm.axis != JOY_AXIS_LEFT_Y:
			return
		var key := "%d:%d" % [jm.device, jm.axis]
		if absf(jm.axis_value) < 0.3:
			stick_ready[key] = true
		elif absf(jm.axis_value) > 0.6 and stick_ready.get(key, true):
			stick_ready[key] = false
			move(1 if jm.axis_value > 0.0 else -1)
		return
	if not event.is_pressed() or event.is_echo() or t - opened_at < 0.15:
		return
	if event is InputEventKey:
		match (event as InputEventKey).physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E: confirm()
			KEY_BACKSPACE, KEY_ESCAPE: close_by_hand()
			KEY_W, KEY_UP: move(-1)
			KEY_S, KEY_DOWN: move(1)
	elif event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A, JOY_BUTTON_START: confirm()
			JOY_BUTTON_B: close_by_hand()
			JOY_BUTTON_DPAD_UP: move(-1)
			JOY_BUTTON_DPAD_DOWN: move(1)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _under_mouse() >= 0:
			confirm()


func _under_mouse() -> int:
	var m := root.get_local_mouse_position()
	for r in rects:
		if (r[0] as Rect2).has_point(m):
			return int(r[1])
	return -1


func move(dy: int) -> void:
	row = posmod(row + dy, rows().size())
	Sfx.play(self, "click", -16.0)


func close_by_hand() -> void:
	Sfx.play(self, "click", -14.0, 0.7)
	close()


func confirm() -> void:
	var sold := items()
	var all := rows()
	row = clampi(row, 0, all.size() - 1)
	if row < sold.size():
		var item := str(sold[row])
		var cost := int(folk.price(item))
		var why: String = folk.buy(who, item)
		if why == "":
			Sfx.play(self, "pickup", -8.0, 1.1)
			if Accessories.has(item):
				say("Bought the %s for %d coins." % [Bag.name_of(item), cost], 3.5)
			else:
				say("Bought a %s for %d coins." % [Bag.name_of(item).to_lower(), cost], 2.5)
		else:
			Sfx.play(self, "click", -14.0, 0.7)
			say(why, 2.5)
	elif str(all[row]) == ASK:
		line = folk.crown_words(who)
		note = ""
		Sfx.play(self, "talk", -10.0, 0.9)
	else:
		close_by_hand()


# --- Drawing ------------------------------------------------------------------------------

func _words(f: Font, at: Vector2, text: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	root.draw_string(f, at + Vector2(1, 1), text, align, width, size, Color(SHADOW, SHADOW.a * col.a))
	root.draw_string(f, at, text, align, width, size, col)


## Words broken into lines no wider than `width`.
static func lines_of(f: Font, text: String, size: int, width: float) -> Array:
	var lines: Array = []
	var now := ""
	for word in text.split(" ", false):
		var longer := word if now == "" else now + " " + word
		if now != "" and f.get_string_size(longer, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			lines.append(now)
			now = word
		else:
			now = longer
	if now != "":
		lines.append(now)
	return lines


func _draw_screen() -> void:
	if not is_open or folk == null:
		return
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font(Art.TEXT)
	rects = []
	root.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.06, 0.04, 0.09, 0.72))
	var r := BOX
	if not Art.draw_nine(root, "swing/ui/panel.png", r, 8):
		root.draw_rect(r, PLATE)
	var x := r.position.x + 18.0
	var w := r.size.x - 36.0
	var y := r.position.y
	_words(silk, Vector2(x, y + 28.0), "PIP", 16, AMBER)
	_words(silk, Vector2(x + 46.0, y + 28.0), "THE TINKER", 8, DIM)
	if folk.players.size() > 1:
		_words(silk, Vector2(x, y + 16.0), "PLAYER %d" % (who + 1), 8, Art.PLAYER_COLORS[who % Art.PLAYER_COLORS.size()], w, HORIZONTAL_ALIGNMENT_RIGHT)

	# Pip himself, twice the size he is on the land, talking; and what he says.
	var face := 0.0
	var actor = folk.pip_actor
	if actor != null and actor.sheet != null and (actor.strips as Dictionary).has("talk"):
		var s: Dictionary = actor.strips["talk"]
		var box: Array = s["box"]
		var n := maxi(int(s.get("frames", 1)), 1)
		var fw := float(box[2]) / float(n)
		var k := int(t * float(s.get("fps", 5))) % n
		root.draw_texture_rect_region(actor.sheet, Rect2(x - 6.0, y + 34.0, fw * 2.0, float(box[3]) * 2.0), Rect2(float(box[0]) + fw * float(k), float(box[1]), fw, float(box[3])))
		face = fw * 2.0 - 4.0
	var said := lines_of(pix, "\"" + line + "\"", Art.TEXT_SIZE, w - face)
	for n in mini(said.size(), 4):
		_words(pix, Vector2(x + face, y + 52.0 + 13.0 * float(n)), str(said[n]), Art.TEXT_SIZE, INK)

	# What you have.
	var purse = folk.loot.purses[who]
	var bag = folk.tools.bag_of(who)
	var hy := y + 110.0
	var hx := x
	ItemArt.draw(root, "hud_coin", Vector2(hx, hy - 9.0))
	_words(pix, Vector2(hx + 15.0, hy), "%d coins" % int(purse.coins), Art.TEXT_SIZE, AMBER)
	hx += 110.0
	for item in BARS:
		ItemArt.draw(root, "item_" + str(item), Vector2(hx, hy - 12.0))
		_words(pix, Vector2(hx + 20.0, hy), "%d" % int(bag.count(item)), Art.TEXT_SIZE, INK)
		hx += 60.0

	var sold := items()
	var all := rows()
	row = clampi(row, 0, all.size() - 1)
	for k in all.size():
		var rr := Rect2(x, y + 122.0 + float(k) * 24.0, w, 21.0)
		var on := k == row
		rects.append([rr, k])
		if not Art.draw_nine(root, "swing/ui/well_selected.png" if on else "swing/ui/well.png", rr, 3):
			root.draw_rect(rr, AMBER if on else FAINT, false, 1.0)
		var tx := rr.position.x + 8.0
		if on:
			var arrow := Art.texture("swing/ui/cursor.png")
			if arrow != null:
				root.draw_texture(arrow, Vector2(tx + (1.0 if fmod(t, 0.8) < 0.4 else 0.0), rr.position.y + 5.0))
			tx += 12.0
		if k < sold.size():
			var item := str(sold[k])
			if not Accessories.has(item):
				ItemArt.draw(root, "item_" + item, Vector2(tx, rr.position.y + 2.0))
				tx += 20.0
			var cost: int = folk.price(item)
			var have: bool = Accessories.has(item) and folk.loot.owns(who, item)
			_words(pix, Vector2(rr.position.x + 8.0, rr.position.y + 14.0), "you have it" if have else "%d coins" % cost, Art.TEXT_SIZE, AMBER if int(purse.coins) >= cost and not have else DIM, rr.size.x - 16.0, HORIZONTAL_ALIGNMENT_RIGHT)
		_words(silk, Vector2(tx, rr.position.y + 14.0), str(all[k]).to_upper(), 8, AMBER if on else INK)

	# Under the rows: news of the last press, or what the accessory under the cursor does (its picture beside it).
	var foot := y + 122.0 + float(all.size()) * 24.0
	if t < note_until and note != "":
		_words(pix, Vector2(x, foot + 17.0), note, Art.TEXT_SIZE, AMBER)
	elif row < sold.size() and Accessories.has(sold[row]):
		var icon := Art.texture("accessories/%s_icon.png" % str(sold[row]))
		if icon != null:
			root.draw_texture(icon, Vector2(x, foot + 1.0))
		var does := lines_of(pix, Accessories.text_of(str(sold[row])), Art.TEXT_SIZE, w - 30.0)
		for n in mini(does.size(), 2):
			_words(pix, Vector2(x + 30.0, foot + 11.0 + 12.0 * float(n)), str(does[n]), Art.TEXT_SIZE, DIM)

	# The bottom band: what the buttons do.
	for band in 3:
		root.draw_rect(Rect2(0, SCREEN.y - 32 + 2 * band, SCREEN.x, 32 - 2 * band), Color(PLATE, 0.5))
	root.draw_string(pix, Vector2(10, SCREEN.y - 16), "W / S or stick: choose     Enter or A: do it     Backspace or B: leave", HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE, DIM)
