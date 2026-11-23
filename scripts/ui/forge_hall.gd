extends CanvasLayer
## The forge, as you find it down the cave mouth in the Highlands (version 45).
##
## Two screens, on the menu kit's plates:
##
##   THE FORGE     The squad's level, the forge's meter and how much more Memory it needs ("The forge shows how
##                 much more Memory the team needs for the next level", the Game Bible). Under them, what is done
##                 here: GIVE YOUR MEMORY pours everything you carry into the meter; ROLE TREES opens the trees;
##                 WEAPONS AND RUNES opens the forge screen there has always been (scripts/ui/swing_forge.gd).
##                 When a level is reached the forge says its line.
##   ROLE TREES    The four trees side by side, a tree a column: the signature perk on top, three rows of two, the
##                 capstone at the bottom. The words of the perk you are on are underneath, with what a press would
##                 do or why it cannot be learnt yet. R (Y on a controller) forgets every perk for Memory.
##
## The player who used the cave mouth has the screen; with two players the other one's controls do nothing here.
## The game stands still while it is open, as it does for the forge screen. It is words on the menu kit's plates,
## with the Art builder's roundel, a meter in the Memory bar's own colours, and the four trees' emblems (art/roles/).
##
## The rules are scripts/highlands/levels.gd's and perks.gd's; this only shows them and asks for them.

signal closed(i: int)         # the screen has closed; player i had it
signal weapons(i: int)        # player i chose "Weapons and runes": the game opens the forge screen for them

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Perks := preload("res://scripts/highlands/perks.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")

const SCREEN := Vector2(640, 360)
const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const FAINT := Color("#5f8072")
const AMBER := Color("#ffc850")
const EMBER := Color("#f06a40")
const PLATE := Color("#19142a")
const SHADOW := Color(0.06, 0.04, 0.11, 0.9)
const METER := [Color("#f0c070"), Color("#cf8a48"), Color("#a05a34")]    # the Memory bar's own bronze, light to dark
const METER_EMPTY := Color("#24121e")
const METER_MARK := Color("#3e1c28")
const POUR_TIME := 0.9
const HALL := Rect2(140, 34, 360, 286)
const ROWS := ["Give your Memory", "Role trees", "Weapons and runes", "Leave"]
const FIRST_WORDS := "Everything you kill, mine and chop gives Memory. Bring it here and the forge remembers: the whole squad gains a level."
## Under the trees' name. While only the signature perks are built, it says so (and not how rows open: none can yet).
const TREES_WORDS := "One point for every level of the squad. In this version only the top perk of each tree is built."
const TREES_WORDS_LATER := "One point for every level of the squad. A row opens once you own a perk from the row above."

const TREE_X := 32.0
const TREE_STEP := 146.0
const TREE_W := 138.0
const HEAD_Y := 62.0
const PERK_Y := [90.0, 109.0, 125.0, 144.0, 160.0, 179.0, 195.0, 214.0]
const PERK_H := 16.0
const INFO := Rect2(32, 236, 576, 86)

var levels                    # scripts/highlands/levels.gd
var players: Array = []
var who := 0                  # the player who has the screen
var is_open := false
var view := "hall"            # "hall" or "trees"
var row := 0                  # the hall: the row you are on
var tree := 0                 # the trees: the column ...
var place := 0                # ... and the place in it, 0 (the signature) to 7 (the capstone)
var asking := false           # "Forget your perks?" is up
var note := ""                # a line of news (what a press did, or why it did nothing)
var note_until := -9.0
var pour := {}                # the meter running up after a pour: {from, to, t, levels}
var t := 0.0
var opened_at := 0.0
var stick_ready := {}
var rects: Array = []         # for the mouse: [[Rect2, "row" | "perk", a, b]]
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


## Player i comes to the forge.
func open(i: int) -> void:
	if is_open:
		return
	who = i
	is_open = true
	view = "hall"
	asking = false
	note = ""
	pour = {}
	opened_at = t
	# On what there is to do: Memory to give, else points to spend, else the weapons.
	row = 0 if levels.carried(who) > 0 and levels.need(levels.level) > 0.0 else (1 if levels.points(who) > 0 else 2)
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
	if not is_open:
		return
	if not pour.is_empty():
		var before: float = pour["t"]
		pour["t"] = before + delta
		# The meter runs through a whole level: the forge rings as each one is reached.
		var was := _poured(before)
		var now := _poured(float(pour["t"]))
		if floorf(now) > floorf(was) and floorf(now) <= float(pour["to_level"]):
			Sfx.play(self, "anvil", -7.0, 1.4)
		if float(pour["t"]) >= POUR_TIME + 0.2:
			pour = {}
	root.queue_redraw()


## Where the running meter is `at` seconds into a pour: the level, and how full the meter is, as one number.
func _poured(at: float) -> float:
	var k := clampf(at / POUR_TIME, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	return lerpf(float(pour["from"]), float(pour["to"]), k)


func say(text: String, seconds := 4.0) -> void:
	note = text
	note_until = t + seconds


# --- Who pressed what ---------------------------------------------------------------------

## Does this press belong to the player who has the screen? (One player has every device.)
func _mine(event: InputEvent) -> bool:
	if players.size() <= 1 or who >= players.size() or not is_instance_valid(players[who]):
		return true
	var inp = players[who].input
	var pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if pad:
		return inp.kind == "pad" and inp.device == event.device
	return inp.kind == "kbm"


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	# Everything is swallowed while the screen is up: the other player's presses too.
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
	if not _mine(event):
		return
	if event is InputEventMouseMotion:
		var hit := _under_mouse()
		if not hit.is_empty() and not asking:
			if str(hit[1]) == "row":
				row = int(hit[2])
			else:
				tree = int(hit[2])
				place = int(hit[3])
		return
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if jm.axis != JOY_AXIS_LEFT_Y and jm.axis != JOY_AXIS_LEFT_X:
			return
		var key := "%d:%d" % [jm.device, jm.axis]
		if absf(jm.axis_value) < 0.3:
			stick_ready[key] = true
		elif absf(jm.axis_value) > 0.6 and stick_ready.get(key, true):
			stick_ready[key] = false
			var step := 1 if jm.axis_value > 0.0 else -1
			move(step if jm.axis == JOY_AXIS_LEFT_X else 0, step if jm.axis == JOY_AXIS_LEFT_Y else 0)
		return
	if not event.is_pressed() or event.is_echo() or t - opened_at < 0.15:
		return
	if event is InputEventKey:
		match (event as InputEventKey).physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E: confirm()
			KEY_BACKSPACE, KEY_ESCAPE: go_back()
			KEY_W, KEY_UP: move(0, -1)
			KEY_S, KEY_DOWN: move(0, 1)
			KEY_A, KEY_LEFT: move(-1, 0)
			KEY_D, KEY_RIGHT: move(1, 0)
			KEY_R: ask_forget()
	elif event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A, JOY_BUTTON_START: confirm()
			JOY_BUTTON_B: go_back()
			JOY_BUTTON_DPAD_UP: move(0, -1)
			JOY_BUTTON_DPAD_DOWN: move(0, 1)
			JOY_BUTTON_DPAD_LEFT: move(-1, 0)
			JOY_BUTTON_DPAD_RIGHT: move(1, 0)
			JOY_BUTTON_Y: ask_forget()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not asking and not _under_mouse().is_empty():
			confirm()


func _under_mouse() -> Array:
	var m := root.get_local_mouse_position()
	for r in rects:
		if (r[0] as Rect2).has_point(m):
			return r
	return []


# --- What the presses do ------------------------------------------------------------------

func move(dx: int, dy: int) -> void:
	if asking:
		return
	if view == "hall":
		if dy != 0:
			row = posmod(row + dy, ROWS.size())
			Sfx.play(self, "click", -16.0)
		return
	tree = posmod(tree + dx, Perks.TREES.size())
	place = clampi(place + dy, 0, 7)
	if dx != 0 or dy != 0:
		Sfx.play(self, "click", -16.0)


## The perk the trees' cursor is on.
func perk_on() -> String:
	return str(Perks.TREE[Perks.TREES[tree]][place])


func confirm() -> void:
	if asking:
		asking = false
		var had: int = (levels.perks[who] as Array).size()
		var cost: int = levels.forget_cost(who)
		if levels.forget(who):
			Sfx.play(self, "anvil", -8.0, 0.7)
			say("Forgotten: %d %s to spend again, for %d Memory." % [had, "point" if had == 1 else "points", cost])
		return
	if view == "trees":
		var id := perk_on()
		var why: String = levels.learn(who, id)
		if why == "":
			Sfx.play(self, "pickup", -8.0, 1.2)
			say("%s learnt." % Perks.name_of(id))
		else:
			Sfx.play(self, "click", -14.0, 0.7)
			say(why, 2.5)
		return
	match row:
		0:
			_give()
		1:
			view = "trees"
			note = ""
			Sfx.play(self, "click", -8.0)
		2:
			var i := who
			close()
			weapons.emit(i)
		3:
			Sfx.play(self, "click", -14.0, 0.7)
			close()


## GIVE YOUR MEMORY: everything you carry goes into the forge.
func _give() -> void:
	if levels.need(levels.level) <= 0.0:
		Sfx.play(self, "click", -14.0, 0.7)
		say("The forge remembers all it can for now.")
		return
	if levels.carried(who) <= 0:
		Sfx.play(self, "click", -14.0, 0.7)
		say("You carry no Memory. Everything you kill, mine and chop gives some.")
		return
	var got: Dictionary = levels.pour(who)
	var to: float = float(levels.level) + (levels.banked / levels.need(levels.level) if levels.need(levels.level) > 0.0 else 0.0)
	pour = {"from": float(got["from"]) + float(got["was"]), "to": to, "to_level": levels.level, "t": 0.0, "levels": int(got["levels"])}
	Sfx.play(self, "pickup", -8.0, 0.9)
	if int(got["levels"]) > 0:
		say("The squad is level %d. Everyone has %s to spend." % [levels.level, "a point" if int(got["levels"]) == 1 else "%d points" % int(got["levels"])], 8.0)
		if levels.points(who) > 0:
			row = 1
	else:
		say("You gave %d Memory." % int(got["poured"]))


func go_back() -> void:
	Sfx.play(self, "click", -14.0, 0.7)
	if asking:
		asking = false
	elif view == "trees":
		view = "hall"
		note = ""
	else:
		close()


## R (Y on a controller), on the trees: forget every perk, for Memory you carry.
func ask_forget() -> void:
	if view != "trees" or asking:
		return
	var had: int = (levels.perks[who] as Array).size()
	if had == 0:
		say("You have no perks to forget.", 2.5)
	elif levels.carried(who) < levels.forget_cost(who):
		say("Forgetting your %s costs %d Memory. You carry %d." % ["perk" if had == 1 else "%d perks" % had, levels.forget_cost(who), levels.carried(who)])
	else:
		asking = true
	Sfx.play(self, "click", -12.0, 0.8)


# --- Drawing ------------------------------------------------------------------------------

func _words(f: Font, at: Vector2, text: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	root.draw_string(f, at + Vector2(1, 1), text, align, width, size, Color(SHADOW, SHADOW.a * col.a))
	root.draw_string(f, at, text, align, width, size, col)


func _width(f: Font, text: String, size: int) -> float:
	return ceilf(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)


## Words broken into lines no wider than `width`.
static func lines_of(f: Font, text: String, size: int, width: float) -> Array:
	var lines: Array = []
	var line := ""
	for word in text.split(" ", false):
		var longer := word if line == "" else line + " " + word
		if line != "" and f.get_string_size(longer, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			lines.append(line)
			line = word
		else:
			line = longer
	if line != "":
		lines.append(line)
	return lines


func _draw_screen() -> void:
	if not is_open or levels == null:
		return
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font(Art.TEXT)
	rects = []
	root.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.06, 0.04, 0.09, 0.72))
	if view == "hall":
		_draw_hall(silk, pix)
	else:
		_draw_trees(silk, pix)
	# The bottom band: what the buttons do.
	for band in 3:
		root.draw_rect(Rect2(0, SCREEN.y - 32 + 2 * band, SCREEN.x, 32 - 2 * band), Color(PLATE, 0.5))
	var hint := "W / S or stick: choose     Enter or A: do it     Backspace or B: leave"
	if asking:
		hint = "Enter or A: forget them     Backspace or B: keep them"
	elif view == "trees":
		hint = "W A S D or stick: choose     Enter or A: learn     R or Y: forget them all     Backspace or B: back"
	root.draw_string(pix, Vector2(10, SCREEN.y - 16), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE, DIM)
	if asking:
		_draw_asking(silk, pix)


## The squad's level in its roundel, with its top left corner at `at`.
func _badge(at: Vector2, level: int, silk: Font) -> void:
	if ItemArt.draw(root, "level_badge", at) == Vector2.ZERO:
		root.draw_rect(Rect2(at, Vector2(15, 13)), PLATE)
	var words := str(level)
	root.draw_string(silk, at + Vector2(3.0 + floorf((9.0 - _width(silk, words, 8)) * 0.5) + 1.0, 10.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, AMBER)


func _draw_hall(silk: Font, pix: Font) -> void:
	var r := HALL
	if not Art.draw_nine(root, "swing/ui/panel.png", r, 8):
		root.draw_rect(r, PLATE)
	var x := r.position.x + 18.0
	var w := r.size.x - 36.0
	var y := r.position.y
	_words(silk, Vector2(x, y + 28.0), "THE FORGE", 16, AMBER)
	if players.size() > 1:
		_words(silk, Vector2(x, y + 28.0), "PLAYER %d" % (who + 1), 8, Art.PLAYER_COLORS[who % Art.PLAYER_COLORS.size()], w, HORIZONTAL_ALIGNMENT_RIGHT)

	# The level and the meter. While a pour runs, they are where the pour has got to.
	var level: int = levels.level
	var need: float = levels.need(level)
	var frac: float = levels.banked / need if need > 0.0 else 0.0
	var ring := 0.0
	if not pour.is_empty():
		var at := _poured(float(pour["t"]))
		if at < float(pour["to"]) - 0.0005:
			level = int(floorf(at))
			frac = at - floorf(at)
			need = levels.need(level)
		# A level has just been reached: the meter flashes.
		for n in range(int(floorf(float(pour["from"]))) + 1, int(pour["to_level"]) + 1):
			var span := maxf(float(pour["to"]) - float(pour["from"]), 0.001)
			var when := (1.0 - sqrt(clampf(1.0 - (float(n) - float(pour["from"])) / span, 0.0, 1.0))) * POUR_TIME
			ring = maxf(ring, clampf(1.0 - (float(pour["t"]) - when) / 0.35, 0.0, 1.0) if float(pour["t"]) >= when else 0.0)
	_badge(Vector2(x, y + 40.0), level, silk)
	_words(silk, Vector2(x + 21.0, y + 50.0), "SQUAD LEVEL %d" % level, 8, INK)
	var bar := Rect2(x, y + 60.0, w, 13.0)
	root.draw_rect(bar, Color("#0f0b18"))
	root.draw_rect(bar.grow(-1.0), Color("#1a0e16"))
	var inner := bar.grow(-2.0)
	root.draw_rect(inner, METER_EMPTY)
	var fw := roundf(inner.size.x * clampf(frac, 0.0, 1.0))
	if fw > 0.0:
		root.draw_rect(Rect2(inner.position, Vector2(fw, 2)), METER[0])
		root.draw_rect(Rect2(inner.position + Vector2(0, 2), Vector2(fw, inner.size.y - 4.0)), METER[1])
		root.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 2.0), Vector2(fw, 2)), METER[2])
	for q in [0.25, 0.5, 0.75]:
		root.draw_rect(Rect2(inner.position.x + roundf(inner.size.x * q), inner.position.y, 1, inner.size.y), METER_MARK)
	if ring > 0.0:
		root.draw_rect(inner, Color(1.0, 0.94, 0.7, 0.6 * ring))
	# The same in words, for the whole squad (while a pour runs, where the pour has got to).
	var said := "The forge remembers all it can for now."
	if need > 0.0:
		var n := float(levels.squad())
		var holds := roundi(frac * need * n)
		var needs := roundi(need * n)
		said = "%d of %d Memory. It needs %d more for level %d" % [holds, needs, maxi(needs - holds, 0), level + 1]
		said += ": %d from each of you." % ceili(need * (1.0 - frac)) if players.size() > 1 else "."
	var told := lines_of(pix, said, Art.TEXT_SIZE, w)
	for n in mini(told.size(), 2):
		_words(pix, Vector2(x, y + 88.0 + 13.0 * float(n)), str(told[n]), Art.TEXT_SIZE, INK)

	# What is done here.
	var carried: int = levels.carried(who)
	var points: int = levels.points(who)
	var rights := ["You carry %d" % carried if carried > 0 else "You carry none",
		"1 point to spend" if points == 1 else ("%d points to spend" % points if points > 1 else "No points to spend"), "", ""]
	for k in ROWS.size():
		var rr := Rect2(x, y + 112.0 + float(k) * 24.0, w, 21.0)
		var on := k == row
		rects.append([rr, "row", k, 0])
		if not Art.draw_nine(root, "swing/ui/well_selected.png" if on else "swing/ui/well.png", rr, 3):
			root.draw_rect(rr, AMBER if on else FAINT, false, 1.0)
		var tx := rr.position.x + 8.0
		if on:
			var arrow := Art.texture("swing/ui/cursor.png")
			if arrow != null:
				root.draw_texture(arrow, Vector2(tx + (1.0 if fmod(t, 0.8) < 0.4 else 0.0), rr.position.y + 5.0))
			tx += 12.0
		_words(silk, Vector2(tx, rr.position.y + 14.0), str(ROWS[k]).to_upper(), 8, AMBER if on else INK)
		if rights[k] != "":
			var lit: bool = (k == 0 and carried > 0 and levels.need(levels.level) > 0.0) or (k == 1 and points > 0)
			_words(pix, Vector2(rr.position.x + 8.0, rr.position.y + 14.0), rights[k], Art.TEXT_SIZE, AMBER if lit else DIM, rr.size.x - 16.0, HORIZONTAL_ALIGNMENT_RIGHT)

	# The forge's own words: the line of the level the squad has reached. And the news.
	var ly := y + 218.0
	if level >= 1:
		_words(silk, Vector2(x, ly), "THE FORGE", 8, DIM)
		var lines := lines_of(pix, "\"" + levels.line_for(level) + "\"", Art.TEXT_SIZE, w)
		for n in mini(lines.size(), 3):
			_words(pix, Vector2(x, ly + 14.0 + 13.0 * float(n)), str(lines[n]), Art.TEXT_SIZE, INK)
	else:
		var lines := lines_of(pix, FIRST_WORDS, Art.TEXT_SIZE, w)
		for n in mini(lines.size(), 3):
			_words(pix, Vector2(x, ly + 4.0 + 13.0 * float(n)), str(lines[n]), Art.TEXT_SIZE, DIM)
	if t < note_until and note != "":
		_words(pix, Vector2(x, y + r.size.y - 12.0), note, Art.TEXT_SIZE, AMBER)


func _draw_trees(silk: Font, pix: Font) -> void:
	var plate := Rect2(16, 12, 608, 316)
	if not Art.draw_nine(root, "swing/ui/panel.png", plate, 8):
		root.draw_rect(plate, PLATE)
	var mine: Array = levels.perks[who]
	var awake: Array = levels.awake(who)
	var points: int = levels.points(who)
	_words(silk, Vector2(32, 38), "ROLE TREES", 16, AMBER)
	var head := "SQUAD LEVEL %d     %s" % [levels.level, "1 POINT TO SPEND" if points == 1 else "%d POINTS TO SPEND" % points]
	_words(silk, Vector2(32, 38), head, 8, AMBER if points > 0 else DIM, 576.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_words(pix, Vector2(32, 54), TREES_WORDS if Perks.BUILT.size() <= Perks.TREES.size() else TREES_WORDS_LATER, Art.TEXT_SIZE, INK)
	if players.size() > 1:
		_words(silk, Vector2(32, 26), "PLAYER %d" % (who + 1), 8, Art.PLAYER_COLORS[who % Art.PLAYER_COLORS.size()], 576.0, HORIZONTAL_ALIGNMENT_RIGHT)

	for c in Perks.TREES.size():
		var tree_id := str(Perks.TREES[c])
		var x := TREE_X + float(c) * TREE_STEP
		# The column's head: the tree's emblem, its name, and what it is for.
		var lead := 20.0 if ItemArt.draw(root, "emblem_" + tree_id, Vector2(x, HEAD_Y)) != Vector2.ZERO else 0.0
		_words(silk, Vector2(x + lead, HEAD_Y + 8.0), str(Perks.TREE_NAMES[tree_id]).to_upper(), 8, AMBER if c == tree else INK)
		_words(pix, Vector2(x + lead, HEAD_Y + 19.0), str(Perks.TREE_DOES[tree_id]), Art.TEXT_SIZE, DIM)
		for k in 8:
			var id := str(Perks.TREE[tree_id][k])
			var rr := Rect2(x, PERK_Y[k], TREE_W, PERK_H)
			var on := c == tree and k == place
			rects.append([rr, "perk", c, k])
			var have := id in mine
			var up := id in awake
			var can := Perks.why_not(id, mine, points) == ""
			var built := Perks.built(id)
			var a := 1.0 if (have or can) else (0.8 if built else 0.5)
			if not Art.draw_nine(root, "swing/ui/well_selected.png" if on else "swing/ui/well.png", rr, 3, Color(1, 1, 1, maxf(a, 0.75) if not on else 1.0)):
				root.draw_rect(rr, Color(AMBER if on else FAINT, a), false, 1.0)
			# A pip: full for a perk that is yours and awake, an open one for a perk that is yours and asleep here or
			# that a press would learn, none for the rest.
			var pip := Rect2(rr.position.x + 6.0, rr.position.y + 5.0, 6, 6)
			if up:
				root.draw_rect(pip, PLATE)
				root.draw_rect(pip.grow(-1.0), AMBER)
			elif have or can:
				root.draw_rect(pip, PLATE)
				root.draw_rect(pip.grow(-1.0), DIM if have else AMBER, false, 1.0)
			var col := AMBER if up else (DIM if have else (INK if can else (DIM if built else FAINT)))
			_words(silk, Vector2(rr.position.x + 17.0, rr.position.y + 11.0), Perks.name_of(id).to_upper(), 8, Color(col, a))

	# The perk the cursor is on, in words.
	if not Art.draw_nine(root, "swing/ui/well.png", INFO, 3):
		root.draw_rect(INFO, FAINT, false, 1.0)
	var on_id := perk_on()
	var on_tree := str(Perks.TREES[tree])
	var ix := INFO.position.x + 10.0
	var iy := INFO.position.y
	_words(silk, Vector2(ix, iy + 14.0), Perks.name_of(on_id).to_upper(), 8, AMBER)
	var where := "%s, %s" % [str(Perks.TREE_NAMES[on_tree]), str(Perks.ROW_NAMES[Perks.ROWS[place]]).to_lower()]
	_words(pix, Vector2(ix + _width(silk, Perks.name_of(on_id).to_upper(), 8) + 10.0, iy + 14.0), where, Art.TEXT_SIZE, DIM)
	var state := ""
	var state_col := DIM
	if on_id in awake:
		state = "Yours."
		state_col = AMBER
	elif on_id in mine:
		state = "Yours, but asleep: this world's forge is only level %d." % levels.level
	else:
		var why := Perks.why_not(on_id, mine, points)
		state = "Enter or A: learn it for 1 point." if why == "" else why
		state_col = AMBER if why == "" else DIM
	if t < note_until and note != "":
		state = note
		state_col = AMBER
	_words(pix, Vector2(ix, iy + 14.0), state, Art.TEXT_SIZE, state_col, INFO.size.x - 20.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var lines := lines_of(pix, Perks.text_of(on_id), Art.TEXT_SIZE, INFO.size.x - 20.0)
	for n in mini(lines.size(), 5):
		_words(pix, Vector2(ix, iy + 30.0 + 12.0 * float(n)), str(lines[n]), Art.TEXT_SIZE, INK)


## "Forget your perks?", over everything else.
func _draw_asking(silk: Font, pix: Font) -> void:
	root.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.06, 0.04, 0.09, 0.6))
	var r := Rect2(140, 126, 360, 92)
	if not Art.draw_nine(root, "swing/ui/panel.png", r, 8):
		root.draw_rect(r, PLATE)
	var had: int = (levels.perks[who] as Array).size()
	_words(silk, Vector2(r.position.x, r.position.y + 26.0), "FORGET YOUR %s?" % ("PERK" if had == 1 else "%d PERKS" % had), 16, AMBER, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_words(pix, Vector2(r.position.x, r.position.y + 46.0), "It costs %d of the %d Memory you carry." % [levels.forget_cost(who), levels.carried(who)], Art.TEXT_SIZE, INK, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_words(pix, Vector2(r.position.x, r.position.y + 59.0), "You get %s back to spend again." % ("your point" if had == 1 else "all %d points" % had), Art.TEXT_SIZE, INK, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_words(pix, Vector2(r.position.x, r.position.y + 79.0), "Enter or A: forget them        Backspace or B: keep them", Art.TEXT_SIZE, DIM, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
