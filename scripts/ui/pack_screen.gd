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
## THE HOTBAR (version 70). A healing potion (and anything else that is used up from the hotbar: tools.gd's USABLE)
## goes onto the hotbar from here: E (A on a controller, or a click) puts it in the first free slot or takes it off
## again, and a key from 1 to 8 puts it in that slot (4 to 8: the first three hold the tools). Only which kind is in
## which slot is kept there: the potions themselves stay in the inventory.
##
## THE EQUIPMENT PAGE (version 71). Darren, 28 November 2026: "i want an equipment screen to be visible from inventory
## too, so you can unequip armour and wepons etc, and see your stats". The right side of the screen has two pages,
## the satchel and the equipment, turned with C (LB or RB on a controller) or a click on their names. The equipment
## page shows the weapon in hand (E takes it off and puts it back: highlands.gd's empty hands), the armour worn on
## head, body and feet (armour.gd, gear.gd: E on a piece in the inventory wears it, E on a worn piece takes it off),
## and the player's numbers. Claude's choices: the weapon taken off stays on this page, faint, and is not an
## inventory item (its picture is wider than a slot); wearing a piece from the inventory turns to this page.
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
const Armour := preload("res://scripts/highlands/armour.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const SwordArt := preload("res://scripts/weapon/sword_art.gd")

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
const PAGES := ["SATCHEL", "EQUIPMENT"]     # the right side's two pages (version 71)
const EQ_ROW := 6.0              # between the weapon and the armour on the equipment page
const EQ_STATS := 27.0           # from the foot of the armour to the first line of numbers
const EQ_LINE := 12.0            # one line of numbers
const EQ_LINES := 7
const EQ_TALL := 14.0 + SLOT + EQ_ROW + SLOT + EQ_STATS + EQ_LINE * float(EQ_LINES - 1) + 8.0      # the equipment page under its names


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
	var page := 0                # the right side: 0 the satchel, 1 the equipment (version 71); kept between openings
	var eq := 0                  # on the equipment page: 0 the weapon, 1 to 3 the head, body and feet


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
	var v: View = views[i]
	var right := float(CHEST_ROWS) * SLOT + 14.0 if v.chest >= 0 else float(gear.size_of(i).y) * SLOT + 14.0
	if v.chest < 0 and v.page == 1:
		right = EQ_TALL
	var grid := maxf(float(rows_of(i)) * SLOT, right)
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


## On the equipment page: where spot n is drawn (0 the weapon, as wide as the page; 1 to 3 the head, body and feet,
## in a row under it).
func eq_rect(i: int, n: int) -> Rect2:
	var r := plate(i)
	var sx := r.position.x + PAD + SLOT * 6.0 + GAP
	var top := r.position.y + HEAD + 14.0
	if n <= 0:
		return Rect2(sx, top, SLOT * 5.0, SLOT)
	return Rect2(sx + float(n - 1) * SLOT * 2.0, top + SLOT + EQ_ROW, SLOT, SLOT)


## The names of the right side's two pages, over it: where page n's name is (a click on it turns to it).
func tab_rect(i: int, n: int) -> Rect2:
	var r := plate(i)
	var sx := r.position.x + PAD + SLOT * 6.0 + GAP
	var silk := Art.font("Silkscreen-Regular")
	var w: float = silk.get_string_size(PAGES[n], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4.0
	return Rect2(sx - 2.0 if n == 0 else sx + SLOT * 5.0 - w + 2.0, r.position.y + 9.0, w, 13.0)


## The armour place of equipment spot n ("head", "body", "feet"; "" for the weapon).
static func eq_slot(n: int) -> String:
	return str(Armour.SLOTS[n - 1]) if n >= 1 and n <= Armour.SLOTS.size() else ""


## Is the cursor of player i on the equipment page?
func on_equipment(i: int) -> bool:
	var v: View = views[i]
	return is_open(i) and v.chest < 0 and v.page == 1 and v.side == 1


## Player i's numbers on the equipment page: [[name, value], ...], top first.
func stats_of(i: int) -> Array:
	var p = players[i]
	var w: Dictionary = p.weapon
	var bare: bool = not p.armed()
	var defence: int = gear.defence(i)
	var pace: float = 1.0 + float(w.get("move_speed", 0.0))      # (of the Highlands' own walking pace: 100% as you are)
	var out: Array = []
	out.append(["Health", "%d / %d" % [ceili(p.hp), roundi(p.max_hp)]])
	out.append(["Damage", "none" if bare else _plain(float(w.get("damage", 0.0)))])
	out.append(["Attack speed", "none" if bare else "%d%%" % roundi(float(w.get("speed", 1.0)) * 100.0)])
	out.append(["Move speed", "%d%%" % roundi(pace * 100.0)])
	out.append(["Defence", "%d, %d%% less" % [defence, Armour.less(defence)] if defence > 0 else "0"])
	out.append(["Accessories", "%d in use" % (gear.kits[i].worn as Array).size()])
	var levels = game.get("levels") if game != null else null
	if levels != null:
		var learnt: int = (levels.perks[i] as Array).size() if i < levels.perks.size() else 0
		out.append(["Level", "%d, %d perk%s" % [int(levels.level), learnt, "" if learnt == 1 else "s"]])
	return out


static func _plain(n: float) -> String:
	return ("%d" % roundi(n)) if is_equal_approx(n, roundf(n)) else ("%.1f" % (roundf(n * 10.0) / 10.0))


## The weapon player i holds (or has taken off): its head's picture, and its name.
func _weapon_icon(i: int) -> Texture2D:
	var b = game.builds[i] if game != null and i < game.builds.size() else null
	if b == null:
		return null
	if b.weapon() == "bow":
		return Art.texture("swing/bow/limbs/%s_icon.png" % b.blade)
	return SwordArt.part_texture("blades", b.blade, "icon")


func _weapon_name(i: int) -> String:
	var b = game.builds[i] if game != null and i < game.builds.size() else null
	return str(SwingBuild.head_part(b.blade).get("name", "Weapon")) if b != null else "Weapon"


func _hands_empty(i: int) -> bool:
	return game != null and game.has_method("hands_empty") and game.hands_empty(i)


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
	if v.chest < 0 and v.page == 1:
		if v.eq == 0:
			return {"id": "", "n": 1, "worn": not _hands_empty(i), "weapon": true}
		return {"id": gear.worn_in(i, eq_slot(v.eq)), "n": 1, "worn": true, "armour": eq_slot(v.eq)}
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
	v.eq = clampi(v.eq, 0, Armour.SLOTS.size())


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
	elif v.side == 1 and v.page == 1 and v.chest < 0:
		# The equipment page: the weapon over the head, body and feet. Off its left edge, back to the inventory
		# (beside the weapon: the second row; beside the armour: the third).
		if d.x < 0 and v.eq <= 1:
			v.side = 0
			v.slot = mini(1 if v.eq == 0 else 2, rows - 1) * Bag.COLS + Bag.COLS - 1
		elif v.eq == 0:
			if d.y > 0:
				v.eq = 1
		elif d.y < 0:
			v.eq = 0
		else:
			v.eq = clampi(v.eq + d.x, 1, Armour.SLOTS.size())
	elif v.side == 0:
		var col := v.slot % Bag.COLS
		var row := v.slot / Bag.COLS
		if d.x > 0 and col == Bag.COLS - 1:
			v.side = 1
			v.cell = Vector2i(0, mini(row, size.y - 1))
			v.cslot = mini(row, CHEST_ROWS - 1) * CHEST_COLS
			v.eq = 0 if row < 2 else 1
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
	if v.held.is_empty() and on_equipment(i):
		_equip(i)
		return
	if v.held.is_empty():
		var u := under_cursor(i)
		if u.is_empty():
			return
		if _for_hotbar(str(u["id"])) and not bool(u["worn"]):
			_hotbar(i, str(u["id"]))
			return
		if Armour.has(u["id"]) and not bool(u["worn"]):
			_wear(i, str(u["id"]))
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
			v.page = 0           # (an accessory goes in the satchel: its page)
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
	if not is_open(i) or (views[i] as View).chest >= 0 or on_equipment(i):
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
	if on_equipment(i):
		_equip(i)
		return
	var u := under_cursor(i)
	if u.is_empty():
		return
	var id := str(u["id"])
	if _for_hotbar(id):
		_hotbar(i, id)
		return
	if Armour.has(id):
		_wear(i, id)
		return
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


## A piece of armour from the inventory is worn in its place (what was worn there goes back into the inventory), and
## the right side turns to the equipment page to show it.
func _wear(i: int, id: String) -> void:
	if not gear.put_on(i, id):
		return
	(views[i] as View).page = 1
	say(i, "You wear the %s: defence %d." % [Armour.name_of(id).to_lower(), gear.defence(i)])
	Sfx.play(self, "pickup", -9.0, 1.1)
	_keep_in(i)


## E (A, Q, Y or a click) on the equipment page: the weapon comes off or goes back into the hand; a worn piece of
## armour goes into the inventory.
func _equip(i: int) -> void:
	var v: View = views[i]
	if v.eq == 0:
		if game == null or not game.has_method("set_hands_empty"):
			return
		var empty := not _hands_empty(i)
		game.set_hands_empty(i, empty)
		say(i, "Your weapon is off. Your hands are empty." if empty else "Your weapon is back in your hand.")
		Sfx.play(self, "click" if empty else "pickup", -9.0, 0.9 if empty else 1.1)
		return
	var slot := eq_slot(v.eq)
	var id: String = gear.worn_in(i, slot)
	if id == "":
		say(i, "Nothing is worn on your %s." % slot)
		Sfx.play(self, "click", -14.0, 0.7)
		return
	if not gear.take_off(i, slot):
		say(i, "Your inventory is full.")
		Sfx.play(self, "click", -14.0, 0.7)
		return
	say(i, "The %s is in your inventory." % Armour.name_of(id).to_lower())
	Sfx.play(self, "click", -9.0, 0.9)


## The right side turns to its other page, the satchel or the equipment (C, LB or RB, or a click on a page's name);
## to page `to` if it says which. Not with a chest open or an accessory in hand.
func flip(i: int, to := -1) -> void:
	if not is_open(i):
		return
	var v: View = views[i]
	if v.chest >= 0 or not v.held.is_empty():
		return
	var next := (1 - v.page) if to < 0 else clampi(to, 0, 1)
	if next == v.page:
		return
	v.page = next
	if v.side == 1:
		v.cell = Vector2i.ZERO
		v.eq = 0
	_keep_in(i)
	Sfx.play(self, "click", -12.0, 1.2)


## Is it something that goes on the hotbar?
func _for_hotbar(id: String) -> bool:
	return tools != null and id in tools.USABLE


## On the hotbar, or off it: E, A, Q, Y or a click on it. Into slot k (0 to 7) when a number key says which.
func _hotbar(i: int, id: String, k := -1) -> void:
	var name := Bag.name_of(id)
	if k < 0 and tools.hotbar_slot(i, id) >= 0:
		tools.take_off(i, id)
		say(i, "%s is off the hotbar." % name)
		Sfx.play(self, "click", -9.0, 0.9)
		return
	if k >= 0 and k < tools.TOOLS.size():
		say(i, "Slots 1 to 3 hold the tools.")
		Sfx.play(self, "click", -14.0, 0.7)
		return
	var got: int = tools.put_on(i, id, k)
	if got < 0:
		say(i, "The hotbar is full. Take something off first.")
		Sfx.play(self, "click", -14.0, 0.7)
		return
	say(i, "%s is on the hotbar, in slot %d." % [name, got + 1])
	Sfx.play(self, "pickup", -9.0, 1.1)


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
		if code >= KEY_1 and code <= KEY_8 and v.chest < 0 and v.held.is_empty():
			var u := under_cursor(i)
			if not u.is_empty() and _for_hotbar(str(u["id"])):
				_hotbar(i, str(u["id"]), code - KEY_1)
			return
		match code:
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: press(i)
			KEY_R: turn(i)
			KEY_Q: quick(i)
			KEY_C: flip(i)
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
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER: flip(i)
			JOY_BUTTON_START: close(i)
	elif event is InputEventMouseButton:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_LEFT and v.chest < 0:
			for n in PAGES.size():
				if tab_rect(i, n).has_point(root.get_local_mouse_position()):
					flip(i, n)
					return
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
	if v.page == 1:
		for n in Armour.SLOTS.size() + 1:
			if eq_rect(i, n).has_point(m):
				v.side = 1
				v.eq = n
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
			_draw_thing(id, int(s[1]), at)
			var on: int = tools.hotbar_slot(i, id) if _for_hotbar(id) else -1
			if on >= 0:
				_words(silk, Vector2(at.x + 2.0, at.y + 8.0), str(on + 1), 8, AMBER)      # which hotbar slot it is in

	if v.chest >= 0:
		_draw_chest(i, sx, y)
	elif v.page == 1:
		_draw_tabs(i)
		_draw_equipment(i, sx, y)
	else:
		_draw_tabs(i)
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
	var icon := ItemArt.icon(id)
	if icon != null:
		root.draw_texture(icon, at)      # its own 24 by 24 icon (version 70: the healing potion)
	else:
		ItemArt.draw(root, "item_" + id, at + Vector2(4, 4))
	if Bag.stack_of(id) > 1 or n > 1:      # (a piece of armour lies alone in its slot, like an accessory)
		_words(silk, Vector2(at.x, at.y + SLOT - 2.0), str(n), 8, INK, SLOT - 2.0, HORIZONTAL_ALIGNMENT_RIGHT)


## The satchel: its name and size, its cells, and what is worn in them; what is in hand, and the cursor.
func _draw_satchel(i: int, sx: float, y: float) -> void:
	var silk := Art.font("Silkscreen-Regular")
	var v: View = views[i]
	var size: Vector2i = gear.size_of(i)
	var sat: int = gear.satchel_now(i)
	# (Its name was over it until version 71, where the two pages' names went; a bigger one's name is here now.)
	_words(silk, Vector2(sx, y + 32.0), "WORN: IN USE" if sat == 0 else str(Gear.SATCHELS[sat]["name"]).to_upper(), 8, PALE)
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


## The right side's two pages, named over it: the one shown in amber.
func _draw_tabs(i: int) -> void:
	var silk := Art.font("Silkscreen-Regular")
	var v: View = views[i]
	for n in PAGES.size():
		var r := tab_rect(i, n)
		_words(silk, Vector2(r.position.x + 2.0, r.position.y + 10.0), PAGES[n], 8, AMBER if n == v.page else FAINT)


## The equipment page (version 71): the weapon in hand, the armour worn, and the player's numbers.
func _draw_equipment(i: int, sx: float, y: float) -> void:
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font(Art.TEXT)
	var v: View = views[i]
	var bare := _hands_empty(i)
	_words(silk, Vector2(sx, y + 32.0), "WEAPON", 8, DIM)
	_words(silk, Vector2(sx, y + 32.0), "TAKEN OFF" if bare else "IN HAND", 8, DIM if bare else PALE, SLOT * 5.0, HORIZONTAL_ALIGNMENT_RIGHT)

	# The weapon: its head's picture in a long well (faint when it is taken off).
	var wr := eq_rect(i, 0)
	if not Art.draw_nine(root, "swing/ui/well.png", wr, 3):
		root.draw_rect(wr, Color(PLATE, 0.8))
	var icon := _weapon_icon(i)
	if icon != null:
		root.draw_texture(icon, (wr.get_center() - icon.get_size() * 0.5).round(), Color(1, 1, 1, 0.3) if bare else Color.WHITE)

	# The armour: head, body and feet, each with its place's name under it.
	for n in range(1, Armour.SLOTS.size() + 1):
		var at := eq_rect(i, n).position
		if ItemArt.draw(root, "slot", at) == Vector2.ZERO:
			Art.draw_nine(root, "swing/ui/well.png", Rect2(at, Vector2(SLOT, SLOT)), 3)
		var slot := eq_slot(n)
		var id: String = gear.worn_in(i, slot)
		var tex := ItemArt.icon(id) if id != "" else Art.texture("items/slot_%s.png" % slot)
		if tex != null:
			root.draw_texture(tex, at)
		_words(silk, Vector2(at.x - SLOT, at.y + SLOT + 10.0), str(Armour.SLOT_NAMES[slot]).to_upper(), 8, PALE if id != "" else FAINT, SLOT * 3.0, HORIZONTAL_ALIGNMENT_CENTER)

	# The numbers.
	var top := y + HEAD + 14.0 + SLOT + EQ_ROW + SLOT
	root.draw_rect(Rect2(sx, top + 15.0, SLOT * 5.0, 1.0), Color(FAINT, 0.6))
	var lines := stats_of(i)
	for n in lines.size():
		var at := Vector2(sx, top + EQ_STATS + EQ_LINE * float(n))
		_words(pix, at, str(lines[n][0]), Art.TEXT_SIZE, DIM)
		_words(pix, at, str(lines[n][1]), Art.TEXT_SIZE, INK, SLOT * 5.0, HORIZONTAL_ALIGNMENT_RIGHT)

	if v.side == 1:
		if v.eq == 0:
			_draw_wide_cursor(i, wr)
		else:
			_draw_cursor(i, eq_rect(i, v.eq).position)
	else:
		_draw_cursor(i, slot_rect(i, v.slot).position)


## The cursor's brackets round the weapon's long well: the slot cursor's left half at its left end, the right half
## at its right end.
func _draw_wide_cursor(i: int, r: Rect2) -> void:
	var col: Color = Art.PLAYER_COLORS[i % Art.PLAYER_COLORS.size()] if players.size() > 1 else INK
	var got := ItemArt.find("slot_cursor")
	if got.is_empty():
		root.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), col, false, 1.0)
		return
	var box: Array = (got[1] as Dictionary)["box"]
	var half := floorf(float(box[2]) * 0.5)
	var h := float(box[3])
	root.draw_texture_rect_region(got[0], Rect2(r.position, Vector2(half, h)), Rect2(float(box[0]), float(box[1]), half, h), col)
	root.draw_texture_rect_region(got[0], Rect2(Vector2(r.end.x - half, r.position.y), Vector2(half, h)), Rect2(float(box[0]) + float(box[2]) - half, float(box[1]), half, h), col)


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
	var said_of := ""
	if u.has("weapon") or u.has("armour"):
		# The equipment page's weapon, or one of its armour places.
		var id := str(u["id"])
		var name := _weapon_name(i) if u.has("weapon") else (Armour.name_of(id) if id != "" else str(Armour.SLOT_NAMES[str(u["armour"])]))
		var state := ("IN HAND" if bool(u["worn"]) else "TAKEN OFF") if u.has("weapon") else ("+%d DEFENCE" % Armour.defence_of(id) if id != "" else "EMPTY")
		_words(silk, Vector2(x, fy + 12.0), name.to_upper(), 8, AMBER)
		_words(silk, Vector2(x, fy + 12.0), state, 8, PALE if bool(u["worn"]) and (u.has("weapon") or id != "") else DIM, w, HORIZONTAL_ALIGNMENT_RIGHT)
		if u.has("weapon"):
			said_of = "Your weapon. Taken off, it waits here: empty hands cannot fight, but the tools still work." if bool(u["worn"]) else "Taken off, it waits here: empty hands cannot fight, but the tools still work."
		else:
			said_of = Armour.text_of(id) if id != "" else "Armour from your inventory is worn here, and guards you."
		var said0 := lines_of(pix, said_of, Art.TEXT_SIZE, w)
		for n in mini(said0.size(), 2):
			_words(pix, Vector2(x, fy + 25.0 + 11.0 * float(n)), str(said0[n]), Art.TEXT_SIZE, INK)
	elif not u.is_empty():
		var id := str(u["id"])
		var name := name_of(id)
		if int(u["n"]) > 1:
			name = "%s  x %d" % [name, int(u["n"])]
		_words(silk, Vector2(x, fy + 12.0), name.to_upper(), 8, AMBER)
		if u.has("chest"):
			_words(silk, Vector2(x, fy + 12.0), "IN THE CHEST", 8, DIM, w, HORIZONTAL_ALIGNMENT_RIGHT)
		elif Accessories.has(id):
			_words(silk, Vector2(x, fy + 12.0), "IN USE" if bool(u["worn"]) else "NOT IN USE", 8, PALE if bool(u["worn"]) else DIM, w, HORIZONTAL_ALIGNMENT_RIGHT)
		elif Armour.has(id):
			_words(silk, Vector2(x, fy + 12.0), "+%d DEFENCE" % Armour.defence_of(id), 8, DIM, w, HORIZONTAL_ALIGNMENT_RIGHT)
		elif _for_hotbar(id):
			var on: int = tools.hotbar_slot(i, id)
			_words(silk, Vector2(x, fy + 12.0), "HOTBAR SLOT %d" % (on + 1) if on >= 0 else "NOT ON THE HOTBAR", 8, PALE if on >= 0 else DIM, w, HORIZONTAL_ALIGNMENT_RIGHT)
		var said := lines_of(pix, text_of(id), Art.TEXT_SIZE, w)
		for n in mini(said.size(), 2):
			_words(pix, Vector2(x, fy + 25.0 + 11.0 * float(n)), str(said[n]), Art.TEXT_SIZE, INK)
	elif v.chest >= 0:
		_words(pix, Vector2(x, fy + 25.0), "Take what you want. What you leave stays in the chest." if loot.has_left(v.chest, i) else "The chest is empty.", Art.TEXT_SIZE, DIM)
	else:
		_words(pix, Vector2(x, fy + 25.0), "Armour guards you only while it is worn." if v.page == 1 else "An accessory works only while it is in the satchel.", Art.TEXT_SIZE, DIM)
	if t < v.note_until and v.note != "":
		root.draw_rect(Rect2(x - 2.0, fy + 2.0, w + 4.0, 13.0), PLATE)
		_words(pix, Vector2(x, fy + 12.0), v.note, Art.TEXT_SIZE, AMBER)

	# What the buttons do, for the device this player is on.
	var pad: bool = players[i].input.on_pad()
	var hold := not v.held.is_empty()
	var line1 := ("A: %s     X: turn" if pad else "E: %s     R: turn") % ("put down" if hold else "pick up")
	var other := "satchel" if v.page == 1 else "equipment"
	var turn_to := ("LB, RB: %s" if pad else "C: %s") % other
	var line2 := ("B: let go" if hold else "Y: wear or take off     %s     B: close" % turn_to) if pad else ("Esc: let go" if hold else "Q: wear or take off     %s     Tab: close" % turn_to)
	if v.chest >= 0:
		line1 = "A: take     Y: take everything" if pad else "E: take     Q: take everything"
		line2 = "B: close" if pad else "Tab: close"
	elif u.has("weapon") or u.has("armour"):
		var does := ""
		if u.has("weapon"):
			does = "take off" if bool(u["worn"]) else "put back in hand"
		elif str(u["id"]) != "":
			does = "take off"
		line1 = (("A: %s" if pad else "E: %s") % does) if does != "" else ""
		line2 = "%s     %s" % [turn_to, "B: close" if pad else "Tab: close"]
	elif not hold and not u.is_empty() and Armour.has(str(u["id"])):
		line1 = "A: wear it" if pad else "E: wear it"
		line2 = "%s     %s" % [turn_to, "B: close" if pad else "Tab: close"]
	elif not hold and not u.is_empty() and _for_hotbar(str(u["id"])) and not bool(u["worn"]):
		line1 = "A: on or off the hotbar" if pad else "E: on or off the hotbar     1 to 8: into that slot"
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
