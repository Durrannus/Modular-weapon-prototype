extends CanvasLayer
## The inventory's screen (version 47): what you carry on the left, the Accessory Satchel on the right.
##
## Darren, 23 November 2026: "I want to be able to put accessories in normal inventory with everything else but have
## an accessories equip satchel and when they are put there they are in use. This is where the rows and size
## matters". So the left side is a plain grid of slots (bag.gd: everything lies there, an accessory one to a slot
## and doing nothing), and the right side is the satchel's shape grid (gear.gd), where an accessory takes its own
## cells, can be turned, and works from the moment it is put down.
##
## Tab opens and closes it, or a click of the left stick on a controller (Select is the tool belt's). Every player
## has their own: with two players each opens theirs on their own side of the screen, with their own controls.
## The game stands still while anybody's is open, as it does for the forge and Pip's shop (Claude's choice: a
## screen this size over a fight nobody can see through would not be fair to the other player).
##
## A CHEST'S INVENTORY (version 60). Darren, 25 November 2026: "Chests also need a small inventory so it doesn't
## just spew all over the floor". Opening a chest opens this screen with the chest's own small grid on the right in
## place of the satchel (open_chest()): what is in it for you, to take a stack at a time or all at once. Things are
## only taken out (loot.gd's take() and take_all()); what you leave stays in the chest. Emptied, it closes by
## itself after a moment.
##
## The rules are gear.gd's, bag.gd's and loot.gd's: this only moves a cursor and asks them. What is in your hand on this
## screen has not left where it was: it moves only when it is put down somewhere it fits, so nothing can be lost
## by closing the screen.

signal closed(i: int)

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")
const Accessories := preload("res://scripts/highlands/accessories.gd")
const Bag := preload("res://scripts/highlands/bag.gd")
const Gear := preload("res://scripts/highlands/gear.gd")

const SCREEN := Vector2(640, 360)
const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const FAINT := Color("#5f8072")
const AMBER := Color("#ffc850")
const PALE := Color("#7fe0c0")
const PLATE := Color("#19142a")
const SHADOW := Color(0.06, 0.04, 0.11, 0.9)
const SLOT := 24.0               # an inventory slot and a satchel cell are the same size (the art's)
const PAD := 12.0
const GAP := 16.0                # between the two grids
const WIDE := PAD + SLOT * 6.0 + GAP + SLOT * 5.0 + PAD      # room for the largest satchel
const TOP := 38.0                # under the health bars
const HEAD := 26.0               # the two titles
const FOOT := 82.0               # what the cursor is on, and what the buttons do
const MOST_ROWS := 10            # of slots drawn (eight is the largest backpack; more only when things lie past the last slot)
const CHEST_COLS := 4            # a chest's own small inventory (as loot.gd's)
const CHEST_ROWS := 2
const SHUT_AFTER := 0.35         # an emptied chest's screen closes this long after


## One player's screen.
class View:
	var open := false
	var side := 0                # 0: the cursor is in the inventory, 1: in the satchel
	var slot := 0                # which inventory slot it is on
	var cell := Vector2i.ZERO    # which satchel cell (with something in hand: the top left cell of its box)
	var held := {}               # what is in hand: {id, rot, from: "bag" or the piece's number in the satchel} ({}: nothing)
	var note := ""
	var note_until := -9.0
	var opened_at := 0.0
	var chest := -1              # the chest whose inventory is open beside yours (loot.gd's number), or -1: the satchel
	var cslot := 0               # which of its slots the cursor is on
	var shut_at := -1.0          # an emptied chest's screen closes by itself at this time


var game                         # the Highlands scene
var gear                         # scripts/highlands/gear.gd
var tools                        # scripts/highlands/tools.gd (the inventories)
var loot                         # scripts/highlands/loot.gd (the chests)
var players: Array = []
var allowed := true              # the game says whether one may be opened now (not in a dialogue, a journey, the forge)
var views: Array = []
var t := 0.0
var stick_ready := {}
var root: Control


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.size = SCREEN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)
	root.draw.connect(_draw_screen)
	for i in players.size():
		views.append(View.new())


func any_open() -> bool:
	for v in views:
		if (v as View).open:
			return true
	return false


func is_open(i: int) -> bool:
	return i >= 0 and i < views.size() and (views[i] as View).open


## May player i open theirs now? Not while anything else has the game stopped, or has the controls.
func can_open(i: int) -> bool:
	if i < 0 or i >= views.size() or not is_instance_valid(players[i]) or players[i].is_down:
		return false
	if any_open():
		return true
	return allowed and not get_tree().paused


func open(i: int) -> bool:
	if is_open(i) or not can_open(i):
		return false
	var v: View = views[i]
	if not any_open():
		get_tree().paused = true
	v.open = true
	v.side = 0
	v.slot = clampi(v.slot, 0, maxi(_slots(i) - 1, 0))
	v.cell = Vector2i.ZERO
	v.held = {}
	v.note = ""
	v.opened_at = t
	v.chest = -1
	v.shut_at = -1.0
	root.visible = true
	Sfx.play(self, "click", -10.0, 0.8)
	return true


## Opens player i's screen on chest k's inventory: the chest's slots on the right, the cursor on the first.
func open_chest(i: int, k: int) -> bool:
	if loot == null or k < 0 or k >= loot.chests.size():
		return false
	if is_open(i):
		close(i)
	if not open(i):
		return false
	var v: View = views[i]
	v.chest = k
	v.side = 1
	v.cslot = 0
	return true


## Is player i's screen open on a chest?
func in_chest(i: int) -> bool:
	return is_open(i) and (views[i] as View).chest >= 0


func close(i: int) -> void:
	if not is_open(i):
		return
	var v: View = views[i]
	v.open = false
	v.held = {}
	v.chest = -1
	v.shut_at = -1.0
	Sfx.play(self, "click", -14.0, 0.7)
	if not any_open():
		root.visible = false
		get_tree().paused = false
	closed.emit(i)


func close_all() -> void:
	for i in views.size():
		close(i)


func _process(delta: float) -> void:
	t += delta
	for i in views.size():
		var v: View = views[i]
		if v.open and v.shut_at >= 0.0 and t >= v.shut_at:
			close(i)
	if root.visible:
		root.queue_redraw()


func say(i: int, text: String, seconds := 3.0) -> void:
	(views[i] as View).note = text
	(views[i] as View).note_until = t + seconds


# --- What a player's screen shows ----------------------------------------------------------

func _bag(i: int) -> Bag:
	return tools.bag_of(i)


## How many rows of slots player i's inventory is drawn with: what it holds, and a row more for anything that
## lies past its last slot (a backpack taken off in the lab).
func rows_of(i: int) -> int:
	var bag := _bag(i)
	return mini(ceili(float(maxi(bag.cap(), bag.slots.size())) / float(Bag.COLS)), MOST_ROWS)


func _slots(i: int) -> int:
	return rows_of(i) * Bag.COLS


## The whole plate of player i's screen.
func plate(i: int) -> Rect2:
	var right := float(CHEST_ROWS) if (views[i] as View).chest >= 0 else float(gear.size_of(i).y)
	var grid := maxf(float(rows_of(i)) * SLOT, right * SLOT + 14.0)
	var x := floorf((SCREEN.x - WIDE) * 0.5)
	if players.size() > 1:
		x = 8.0 if i % 2 == 0 else SCREEN.x - 8.0 - WIDE
	var tall := HEAD + grid + FOOT
	return Rect2(x, minf(TOP, SCREEN.y - 4.0 - tall), WIDE, tall)


## The name over player i's inventory: the backpack that makes it bigger, if they carry one; whose it is, with two.
func title_of(i: int) -> String:
	var bag := _bag(i)
	var title := "INVENTORY" if bag.pack_now() == 0 else str(Bag.PACKS[bag.pack_now()]["name"]).to_upper()
	return "P%d %s" % [i + 1, title] if players.size() > 1 else title


## Where inventory slot n of player i is drawn.
func slot_rect(i: int, n: int) -> Rect2:
	var r := plate(i)
	return Rect2(r.position.x + PAD + float(n % Bag.COLS) * SLOT, r.position.y + HEAD + float(n / Bag.COLS) * SLOT, SLOT, SLOT)


## Where the satchel cell at (column, row) of player i is drawn.
func cell_rect(i: int, c: Vector2i) -> Rect2:
	var r := plate(i)
	return Rect2(r.position.x + PAD + SLOT * 6.0 + GAP + float(c.x) * SLOT, r.position.y + HEAD + 14.0 + float(c.y) * SLOT, SLOT, SLOT)


## Where slot n of the open chest's inventory is drawn on player i's screen.
func chest_rect(i: int, n: int) -> Rect2:
	var r := plate(i)
	return Rect2(r.position.x + PAD + SLOT * 6.0 + GAP + float(n % CHEST_COLS) * SLOT, r.position.y + HEAD + 14.0 + float(n / CHEST_COLS) * SLOT, SLOT, SLOT)


## What is in slot n of the chest open on player i's screen: [id, how many], or [] if it is empty.
func in_chest_slot(i: int, n: int) -> Array:
	var v: View = views[i]
	if loot == null or v.chest < 0:
		return []
	var share: Array = loot.left_in(v.chest, i)
	return share[n] if n >= 0 and n < share.size() else []


## What a thing is called on this screen (coins are not carried in the bag, but a chest holds them).
static func name_of(id: String) -> String:
	return "Coins" if id == "coins" else Bag.name_of(id)


static func text_of(id: String) -> String:
	return "Spent at Pip's shop. They go straight into your purse." if id == "coins" else Bag.text_of(id)


## What is in inventory slot n of player i: [id, how many], or [] if it is empty.
func in_slot(i: int, n: int) -> Array:
	var bag := _bag(i)
	return bag.slots[n] if n >= 0 and n < bag.slots.size() else []


## What the cursor of player i is on: {id, n, worn: is it in the satchel, k: which piece}, or {} for nothing.
func under_cursor(i: int) -> Dictionary:
	var v: View = views[i]
	if not v.held.is_empty():
		return {"id": str(v.held["id"]), "n": 1, "worn": str(v.held["from"]) != "bag", "held": true}
	if v.side == 0:
		var s := in_slot(i, v.slot)
		return {"id": str(s[0]), "n": int(s[1]), "worn": false} if not s.is_empty() else {}
	if v.chest >= 0:
		var c := in_chest_slot(i, v.cslot)
		return {"id": str(c[0]), "n": int(c[1]), "worn": false, "chest": true} if not c.is_empty() else {}
	var k: int = gear.piece_at(i, v.cell)
	return {"id": str(gear.kits[i].worn[k]["id"]), "n": 1, "worn": true, "k": k} if k >= 0 else {}


## With something in hand in the satchel, its box stays inside the grid.
func _keep_in(i: int) -> void:
	var v: View = views[i]
	var size: Vector2i = gear.size_of(i)
	var box := Vector2i.ONE
	if not v.held.is_empty():
		box = Accessories.box(str(v.held["id"]), int(v.held["rot"]))
	v.cell = Vector2i(clampi(v.cell.x, 0, maxi(size.x - box.x, 0)), clampi(v.cell.y, 0, maxi(size.y - box.y, 0)))
	v.slot = clampi(v.slot, 0, maxi(_slots(i) - 1, 0))
	v.cslot = clampi(v.cslot, 0, CHEST_COLS * CHEST_ROWS - 1)


# --- What the buttons do -------------------------------------------------------------------

## The cursor moves one step. Off the right edge of the inventory it goes into the satchel, and back.
func move(i: int, d: Vector2i) -> void:
	if not is_open(i):
		return
	var v: View = views[i]
	var rows := rows_of(i)
	var size: Vector2i = gear.size_of(i)
	if v.chest >= 0 and v.side == 1:
		var col := v.cslot % CHEST_COLS
		var row := v.cslot / CHEST_COLS
		if d.x < 0 and col == 0:
			v.side = 0
			v.slot = mini(row, rows - 1) * Bag.COLS + Bag.COLS - 1
		else:
			v.cslot = clampi(row + d.y, 0, CHEST_ROWS - 1) * CHEST_COLS + clampi(col + d.x, 0, CHEST_COLS - 1)
	elif v.side == 0:
		var col := v.slot % Bag.COLS
		var row := v.slot / Bag.COLS
		if d.x > 0 and col == Bag.COLS - 1:
			v.side = 1
			v.cell = Vector2i(0, mini(row, size.y - 1))
			v.cslot = mini(row, CHEST_ROWS - 1) * CHEST_COLS
		else:
			col = clampi(col + d.x, 0, Bag.COLS - 1)
			row = clampi(row + d.y, 0, rows - 1)
			v.slot = row * Bag.COLS + col
	else:
		if d.x < 0 and v.cell.x == 0:
			v.side = 0
			v.slot = mini(v.cell.y, rows - 1) * Bag.COLS + Bag.COLS - 1
		else:
			v.cell += d
	if not v.held.is_empty():
		v.note = ""              # ("It does not fit there" was about where it was)
	_keep_in(i)
	Sfx.play(self, "click", -18.0)


## Pick up what the cursor is on, or put down what is in hand.
func press(i: int) -> void:
	if not is_open(i):
		return
	var v: View = views[i]
	if v.chest >= 0:
		_take(i)
		return
	if v.held.is_empty():
		var u := under_cursor(i)
		if u.is_empty():
			return
		if not Accessories.has(u["id"]):
			say(i, "Only accessories go in the satchel.")
			Sfx.play(self, "click", -14.0, 0.7)
			return
		if v.side == 0:
			# Out of the inventory: it is shown where it would first fit, ready to be put down.
			v.held = {"id": str(u["id"]), "rot": 0, "from": "bag"}
			var fit: Array = gear.first_fit(i, str(u["id"]))
			v.side = 1
			v.cell = Vector2i(int(fit[0]), int(fit[1])) if not fit.is_empty() else Vector2i.ZERO
			if not fit.is_empty():
				v.held["rot"] = int(fit[2])
		else:
			var w: Dictionary = gear.kits[i].worn[int(u["k"])]
			v.held = {"id": str(w["id"]), "rot": int(w["rot"]), "from": int(u["k"])}
			v.cell = Vector2i(int(w["x"]), int(w["y"]))
		v.note = ""
		_keep_in(i)
		Sfx.play(self, "click", -9.0, 1.2)
		return
	var id := str(v.held["id"])
	var from_bag := str(v.held["from"]) == "bag"
	if v.side == 1:
		var ok: bool = gear.wear(i, id, v.cell.x, v.cell.y, int(v.held["rot"])) if from_bag else gear.shift(i, int(v.held["from"]), v.cell.x, v.cell.y, int(v.held["rot"]))
		if not ok:
			say(i, "It does not fit there.")
			Sfx.play(self, "click", -14.0, 0.7)
			return
		if from_bag:
			say(i, "%s is in use." % Accessories.name_of(id))
		Sfx.play(self, "pickup", -9.0, 1.1)
	elif not from_bag:
		if not gear.stow(i, int(v.held["from"])):
			say(i, "Your inventory is full.")
			Sfx.play(self, "click", -14.0, 0.7)
			return
		say(i, "%s is no longer in use." % Accessories.name_of(id))
		Sfx.play(self, "click", -9.0, 0.9)
	v.held = {}
	_keep_in(i)


## A quarter turn: of what is in hand, or of the piece the cursor is on if it has room to turn where it lies.
func turn(i: int) -> void:
	if not is_open(i) or (views[i] as View).chest >= 0:
		return
	var v: View = views[i]
	if not v.held.is_empty():
		if Accessories.turns(str(v.held["id"])):
			v.held["rot"] = posmod(int(v.held["rot"]) + 1, 4)
			v.note = ""
			_keep_in(i)
			Sfx.play(self, "click", -12.0, 1.4)
		return
	var u := under_cursor(i)
	if u.is_empty() or not bool(u["worn"]) or not Accessories.turns(str(u["id"])):
		return
	var w: Dictionary = gear.kits[i].worn[int(u["k"])]
	if gear.shift(i, int(u["k"]), int(w["x"]), int(w["y"]), int(w["rot"]) + 1):
		Sfx.play(self, "click", -12.0, 1.4)
	else:
		say(i, "No room to turn it there. Pick it up first.")
		Sfx.play(self, "click", -14.0, 0.7)


## The quick way: an accessory in the inventory goes to the first place it fits in the satchel; a piece in the
## satchel goes back into the inventory.
func quick(i: int) -> void:
	if not is_open(i):
		return
	var v: View = views[i]
	if v.chest >= 0:
		_take_all(i)
		return
	if not v.held.is_empty():
		return
	var u := under_cursor(i)
	if u.is_empty():
		return
	var id := str(u["id"])
	if not Accessories.has(id):
		say(i, "Only accessories go in the satchel.")
		Sfx.play(self, "click", -14.0, 0.7)
	elif bool(u["worn"]):
		if gear.stow(i, int(u["k"])):
			say(i, "%s is no longer in use." % Accessories.name_of(id))
			Sfx.play(self, "click", -9.0, 0.9)
		else:
			say(i, "Your inventory is full.")
			Sfx.play(self, "click", -14.0, 0.7)
	else:
		var fit: Array = gear.first_fit(i, id)
		if not fit.is_empty() and gear.wear(i, id, int(fit[0]), int(fit[1]), int(fit[2])):
			say(i, "%s is in use." % Accessories.name_of(id))
			Sfx.play(self, "pickup", -9.0, 1.1)
		else:
			say(i, "No room in the satchel. Move or turn something.")
			Sfx.play(self, "click", -14.0, 0.7)
	_keep_in(i)


## With a chest open: the stack under the cursor goes into your inventory (coins into your purse), as much as fits.
## On your own inventory's side nothing happens: things cannot be put in a chest.
func _take(i: int) -> void:
	var v: View = views[i]
	if v.side == 0:
		say(i, "Nothing can be put in a chest yet.")
		Sfx.play(self, "click", -14.0, 0.7)
		return
	var c := in_chest_slot(i, v.cslot)
	if c.is_empty():
		return
	var got: int = loot.take(v.chest, i, v.cslot)
	if got <= 0:
		say(i, "Your inventory is full.")
		Sfx.play(self, "click", -14.0, 0.7)
		return
	if got < int(c[1]):
		say(i, "Your inventory is full: the rest stays in the chest.")
	Sfx.play(self, "pickup", -9.0, 1.1)
	_emptied(i)


## With a chest open: everything in it that fits.
func _take_all(i: int) -> void:
	var v: View = views[i]
	if not loot.has_left(v.chest, i):
		return
	var before := _held_in(i)
	if not loot.take_all(v.chest, i):
		var moved := _held_in(i) < before
		say(i, "Your inventory is full: the rest stays in the chest." if moved else "Your inventory is full.")
		Sfx.play(self, "pickup" if moved else "click", -9.0 if moved else -14.0, 1.1 if moved else 0.7)
		return
	Sfx.play(self, "pickup", -9.0, 1.1)
	_emptied(i)


## How many things the chest open on player i's screen still holds for them.
func _held_in(i: int) -> int:
	var n := 0
	for slot in loot.left_in((views[i] as View).chest, i):
		n += int(slot[1])
	return n


## An emptied chest's screen closes by itself a moment later.
func _emptied(i: int) -> void:
	var v: View = views[i]
	if v.chest >= 0 and not loot.has_left(v.chest, i):
		v.shut_at = t + SHUT_AFTER


## Back: lets go of what is in hand (it stays where it was), or closes the screen.
func back(i: int) -> void:
	if not is_open(i):
		return
	var v: View = views[i]
	if v.held.is_empty():
		close(i)
		return
	if str(v.held["from"]) == "bag":
		v.side = 0
	v.held = {}
	_keep_in(i)
	Sfx.play(self, "click", -14.0, 0.7)


# --- The controls ---------------------------------------------------------------------------

## Whose press is this? The player on that device (one player alone has every device). -1: nobody's.
func _whose(event: InputEvent) -> int:
	for i in players.size():
		if is_instance_valid(players[i]) and players[i].input != null and players[i].input.owns(event):
			return i
	return -1


func _input(event: InputEvent) -> void:
	if game == null or views.is_empty():
		return
	var i := _whose(event)
	var opens: bool = (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_TAB) \
		or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_STICK)
	if opens:
		if event.is_pressed() and not event.is_echo() and i >= 0:
			if is_open(i):
				close(i)
				get_viewport().set_input_as_handled()
			elif open(i):
				get_viewport().set_input_as_handled()
		return
	if not any_open():
		return
	# While anybody's is open the game is stopped, and no press goes on to anything behind (the pause menu).
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
	if not is_open(i):
		return
	var v: View = views[i]
	if event is InputEventMouseMotion:
		_point(i, root.get_local_mouse_position())
		return
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if jm.axis != JOY_AXIS_LEFT_X and jm.axis != JOY_AXIS_LEFT_Y:
			return
		var key := "%d:%d" % [jm.device, jm.axis]
		if absf(jm.axis_value) < 0.3:
			stick_ready[key] = true
		elif absf(jm.axis_value) > 0.6 and stick_ready.get(key, true):
			stick_ready[key] = false
			var step := 1 if jm.axis_value > 0.0 else -1
			move(i, Vector2i(step, 0) if jm.axis == JOY_AXIS_LEFT_X else Vector2i(0, step))
		return
	if not event.is_pressed() or t - v.opened_at < 0.12:
		return
	if event is InputEventKey:
		var code := (event as InputEventKey).physical_keycode
		match code:
			KEY_A, KEY_LEFT: move(i, Vector2i(-1, 0))
			KEY_D, KEY_RIGHT: move(i, Vector2i(1, 0))
			KEY_W, KEY_UP: move(i, Vector2i(0, -1))
			KEY_S, KEY_DOWN: move(i, Vector2i(0, 1))
		if event.is_echo():
			return
		match code:
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: press(i)
			KEY_R: turn(i)
			KEY_Q: quick(i)
			KEY_ESCAPE, KEY_BACKSPACE: back(i)
	elif event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_LEFT: move(i, Vector2i(-1, 0))
			JOY_BUTTON_DPAD_RIGHT: move(i, Vector2i(1, 0))
			JOY_BUTTON_DPAD_UP: move(i, Vector2i(0, -1))
			JOY_BUTTON_DPAD_DOWN: move(i, Vector2i(0, 1))
			JOY_BUTTON_A: press(i)
			JOY_BUTTON_X: turn(i)
			JOY_BUTTON_Y: quick(i)
			JOY_BUTTON_B: back(i)
			JOY_BUTTON_START: close(i)
	elif event is InputEventMouseButton:
		var b := (event as InputEventMouseButton).button_index
		if not _point(i, root.get_local_mouse_position()):
			return
		if b == MOUSE_BUTTON_LEFT:
			press(i)
		elif b == MOUSE_BUTTON_RIGHT:
			if v.held.is_empty():
				quick(i)
			else:
				turn(i)


## The mouse is at `m`: the cursor of player i goes to the slot or the cell under it. False if it is over neither.
func _point(i: int, m: Vector2) -> bool:
	var v: View = views[i]
	for n in _slots(i):
		if slot_rect(i, n).has_point(m):
			v.side = 0
			v.slot = n
			return true
	if v.chest >= 0:
		for n in CHEST_COLS * CHEST_ROWS:
			if chest_rect(i, n).has_point(m):
				v.side = 1
				v.cslot = n
				return true
		return false
	var size: Vector2i = gear.size_of(i)
	for y in size.y:
		for x in size.x:
			if cell_rect(i, Vector2i(x, y)).has_point(m):
				v.side = 1
				v.cell = Vector2i(x, y)
				_keep_in(i)
				return true
	return false


# --- Drawing ----------------------------------------------------------------------------------

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


## An accessory's picture in the satchel, turned by quarter turns, the top left of its box at `at`.
func _draw_piece(id: String, rot: int, at: Vector2, tint := Color.WHITE) -> void:
	var tex := Art.texture("accessories/%s_pack.png" % id)
	if tex == null:
		return
	var s := tex.get_size()
	match posmod(rot, 4):
		0: root.draw_set_transform(at, 0.0, Vector2.ONE)
		1: root.draw_set_transform(at + Vector2(s.y, 0), PI * 0.5, Vector2.ONE)
		2: root.draw_set_transform(at + Vector2(s.x, s.y), PI, Vector2.ONE)
		3: root.draw_set_transform(at + Vector2(0, s.x), -PI * 0.5, Vector2.ONE)
	root.draw_texture(tex, Vector2.ZERO, tint)
	root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cell(name: String, at: Vector2, tint := Color.WHITE) -> void:
	var tex := Art.texture("accessories/%s.png" % name)
	if tex != null:
		root.draw_texture(tex, at, tint)
	else:
		root.draw_rect(Rect2(at, Vector2(SLOT, SLOT)), FAINT, false, 1.0)


## The cursor's brackets over a slot or a cell: pale for one player, in their own colour with two.
func _draw_cursor(i: int, at: Vector2) -> void:
	var col: Color = Art.PLAYER_COLORS[i % Art.PLAYER_COLORS.size()] if players.size() > 1 else INK
	if ItemArt.draw(root, "slot_cursor", at, 1.0, col) == Vector2.ZERO:
		root.draw_rect(Rect2(at + Vector2(0.5, 0.5), Vector2(SLOT - 1.0, SLOT - 1.0)), col, false, 1.0)


func _draw_screen() -> void:
	if not any_open() or gear == null:
		return
	root.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.06, 0.04, 0.09, 0.6))
	for i in views.size():
		if (views[i] as View).open:
			_draw_view(i)


func _draw_view(i: int) -> void:
	var v: View = views[i]
	var silk := Art.font("Silkscreen-Regular")
	var bag := _bag(i)
	var r := plate(i)
	if not Art.draw_nine(root, "swing/ui/panel.png", r, 8):
		root.draw_rect(r, PLATE)
	var x := r.position.x + PAD
	var y := r.position.y
	var sx := x + SLOT * 6.0 + GAP

	# The inventory: its name, the backpack that makes it bigger, and how full it is.
	_words(silk, Vector2(x, y + 19.0), title_of(i), 8, Art.PLAYER_COLORS[i % Art.PLAYER_COLORS.size()] if players.size() > 1 else AMBER)
	_words(silk, Vector2(x, y + 19.0), "%d / %d" % [bag.slots.size(), bag.cap()], 8, DIM if bag.slots.size() < bag.cap() else AMBER, SLOT * 6.0, HORIZONTAL_ALIGNMENT_RIGHT)
	for n in _slots(i):
		var at := slot_rect(i, n).position
		var over := n >= bag.cap()
		if over:
			_draw_cell("cell_blocked", at)      # past the last slot: it is kept, and nothing new goes in until there is room
		elif ItemArt.draw(root, "slot", at) == Vector2.ZERO:
			Art.draw_nine(root, "swing/ui/well.png", Rect2(at, Vector2(SLOT, SLOT)), 3)
		var s := in_slot(i, n)
		if s.is_empty():
			continue
		var id := str(s[0])
		var lifted: bool = not v.held.is_empty() and str(v.held["from"]) == "bag" and v.held["id"] == id and n == _first_slot_of(i, id)
		if Accessories.has(id):
			var icon := Art.texture("accessories/%s_icon.png" % id)
			if icon != null:
				root.draw_texture(icon, at, Color(1, 1, 1, 0.3) if lifted else Color.WHITE)
		else:
			ItemArt.draw(root, "item_" + id, at + Vector2(4, 4))
			var count := str(int(s[1]))
			_words(silk, Vector2(at.x, at.y + SLOT - 2.0), count, 8, INK, SLOT - 2.0, HORIZONTAL_ALIGNMENT_RIGHT)

	if v.chest >= 0:
		_draw_chest(i, sx, y)
	else:
		_draw_satchel(i, sx, y)

	# The cursor.
	if v.chest >= 0 and v.side == 1:
		_draw_cursor(i, chest_rect(i, v.cslot).position)
	elif v.chest >= 0:
		_draw_cursor(i, slot_rect(i, v.slot).position)
	_draw_foot(i)


## The open chest's inventory, at the right of player i's screen: its name, how full it is, and what is in it for
## them. (Its slots are the inventory's slot art: it is a small inventory.)
func _draw_chest(i: int, sx: float, y: float) -> void:
	var silk := Art.font("Silkscreen-Regular")
	var v: View = views[i]
	var share: Array = loot.left_in(v.chest, i)
	_words(silk, Vector2(sx, y + 19.0), "CHEST", 8, AMBER)
	_words(silk, Vector2(sx, y + 32.0), "TAKE WHAT YOU WANT" if not share.is_empty() else "EMPTY", 8, PALE if not share.is_empty() else DIM)
	_words(silk, Vector2(sx, y + 19.0), "%d / %d" % [share.size(), CHEST_COLS * CHEST_ROWS], 8, DIM, SLOT * 5.0, HORIZONTAL_ALIGNMENT_RIGHT)
	for n in CHEST_COLS * CHEST_ROWS:
		var at := chest_rect(i, n).position
		if ItemArt.draw(root, "slot", at) == Vector2.ZERO:
			Art.draw_nine(root, "swing/ui/well.png", Rect2(at, Vector2(SLOT, SLOT)), 3)
		if n >= share.size():
			continue
		_draw_thing(str(share[n][0]), int(share[n][1]), at)


## One stack in a slot, its top left at `at`: its picture, and how many under it (not for an accessory, alone in its
## slot).
func _draw_thing(id: String, n: int, at: Vector2) -> void:
	var silk := Art.font("Silkscreen-Regular")
	if Accessories.has(id):
		var icon := Art.texture("accessories/%s_icon.png" % id)
		if icon != null:
			root.draw_texture(icon, at)
		return
	ItemArt.draw(root, "item_" + id, at + Vector2(4, 4))
	_words(silk, Vector2(at.x, at.y + SLOT - 2.0), str(n), 8, INK, SLOT - 2.0, HORIZONTAL_ALIGNMENT_RIGHT)


## The satchel: its name and size, its cells, and what is worn in them; what is in hand, and the cursor.
func _draw_satchel(i: int, sx: float, y: float) -> void:
	var silk := Art.font("Silkscreen-Regular")
	var v: View = views[i]
	var size: Vector2i = gear.size_of(i)
	_words(silk, Vector2(sx, y + 19.0), str(Gear.SATCHELS[gear.satchel_now(i)]["name"]).to_upper(), 8, AMBER)
	_words(silk, Vector2(sx, y + 32.0), "WORN: IN USE", 8, PALE)
	_words(silk, Vector2(sx, y + 32.0), "%d X %d" % [size.x, size.y], 8, DIM, SLOT * 5.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var worn: Array = gear.kits[i].worn
	var held_k := int(v.held["from"]) if not v.held.is_empty() and str(v.held["from"]) != "bag" else -1
	var full_cells: Dictionary = gear.taken(i, held_k)
	for cy in size.y:
		for cx in size.x:
			var c := Vector2i(cx, cy)
			_draw_cell("cell_filled" if full_cells.has(c) else "cell", cell_rect(i, c).position)
	for k in worn.size():
		var piece: Dictionary = worn[k]
		_draw_piece(str(piece["id"]), int(piece["rot"]), cell_rect(i, Vector2i(int(piece["x"]), int(piece["y"]))).position, Color(1, 1, 1, 0.3) if k == held_k else Color.WHITE)

	# What is in hand, and the cursor.
	if not v.held.is_empty():
		var id := str(v.held["id"])
		var rot := int(v.held["rot"])
		if v.side == 1:
			var fits: bool = gear.fits(i, id, v.cell.x, v.cell.y, rot, held_k)
			for c in Accessories.cells(id, rot):
				_draw_cell("cell_blocked" if full_cells.has(v.cell + c) else "cell_ok", cell_rect(i, v.cell + c).position)
			_draw_piece(id, rot, cell_rect(i, v.cell).position + Vector2(0, -2.0 if fmod(t, 0.8) < 0.4 else -1.0), Color(1, 1, 1, 0.95 if fits else 0.6))
			for c in Accessories.cells(id, rot):
				_draw_cursor(i, cell_rect(i, v.cell + c).position)
		else:
			var at := slot_rect(i, v.slot).position
			var icon := Art.texture("accessories/%s_icon.png" % id)
			if icon != null:
				root.draw_texture(icon, at + Vector2(0, -2.0 if fmod(t, 0.8) < 0.4 else -1.0))
			_draw_cursor(i, at)
	elif v.side == 0:
		_draw_cursor(i, slot_rect(i, v.slot).position)
	else:
		_draw_cursor(i, cell_rect(i, v.cell).position)


## Under the grids: what the cursor is on, a note, and what the buttons do.
func _draw_foot(i: int) -> void:
	var v: View = views[i]
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font(Art.TEXT)
	var r := plate(i)
	var x := r.position.x + PAD
	var fy := r.end.y - FOOT + 8.0
	var w := r.size.x - PAD * 2.0
	root.draw_rect(Rect2(x, fy - 1.0, w, 1.0), Color(FAINT, 0.6))
	var u := under_cursor(i)
	if not u.is_empty():
		var id := str(u["id"])
		var name := name_of(id)
		if int(u["n"]) > 1:
			name = "%s  x %d" % [name, int(u["n"])]
		_words(silk, Vector2(x, fy + 12.0), name.to_upper(), 8, AMBER)
		if u.has("chest"):
			_words(silk, Vector2(x, fy + 12.0), "IN THE CHEST", 8, DIM, w, HORIZONTAL_ALIGNMENT_RIGHT)
		elif Accessories.has(id):
			_words(silk, Vector2(x, fy + 12.0), "IN USE" if bool(u["worn"]) else "NOT IN USE", 8, PALE if bool(u["worn"]) else DIM, w, HORIZONTAL_ALIGNMENT_RIGHT)
		var said := lines_of(pix, text_of(id), Art.TEXT_SIZE, w)
		for n in mini(said.size(), 2):
			_words(pix, Vector2(x, fy + 25.0 + 11.0 * float(n)), str(said[n]), Art.TEXT_SIZE, INK)
	elif v.chest >= 0:
		_words(pix, Vector2(x, fy + 25.0), "Take what you want. What you leave stays in the chest." if loot.has_left(v.chest, i) else "The chest is empty.", Art.TEXT_SIZE, DIM)
	else:
		_words(pix, Vector2(x, fy + 25.0), "An accessory works only while it is in the satchel.", Art.TEXT_SIZE, DIM)
	if t < v.note_until and v.note != "":
		root.draw_rect(Rect2(x - 2.0, fy + 2.0, w + 4.0, 13.0), PLATE)
		_words(pix, Vector2(x, fy + 12.0), v.note, Art.TEXT_SIZE, AMBER)

	# What the buttons do, for the device this player is on.
	var pad: bool = players[i].input.on_pad()
	var hold := not v.held.is_empty()
	var line1 := ("A: %s     X: turn" if pad else "E: %s     R: turn") % ("put down" if hold else "pick up")
	var line2 := ("B: let go" if hold else "Y: wear or take off     B: close") if pad else ("Esc: let go" if hold else "Q: wear or take off     Tab: close")
	if v.chest >= 0:
		line1 = "A: take     Y: take everything" if pad else "E: take     Q: take everything"
		line2 = "B: close" if pad else "Tab: close"
	_words(pix, Vector2(x, r.end.y - 21.0), line1, Art.TEXT_SIZE, DIM)
	_words(pix, Vector2(x, r.end.y - 10.0), line2, Art.TEXT_SIZE, DIM)


## The first slot that holds this thing (what is lifted out of the inventory is shown faint there).
func _first_slot_of(i: int, id: String) -> int:
	var bag := _bag(i)
	for n in bag.slots.size():
		if bag.slots[n][0] == id:
			return n
	return -1
