extends RefCounted
## A character's inventory: everything they carry that is not a counter, a tool or a weapon part.
##
## Darren, 23 November 2026: "I want to be able to put accessories in normal inventory with everything else ...
## also want to add craftable backpacks so players can carry more later on". So this is ONE inventory (it was a
## materials bag until version 47): ore, bars, wood and stone lie in it in stacks, and an accessory lies in it too,
## one to a slot whatever its shape. An accessory does nothing in here: it works only in the Accessory Satchel
## (gear.gd). Coins, Memory, tools and the Warhorn's pieces are not carried here. Blank rune stones are (version 55):
## they can be handed to a teammate at the forge, so they are things, not counters.
##
## The numbers are Claude's until Darren sets them (the Game Bible, "Inventory, accessories and backpacks"): 24
## slots in four rows of six, 99 to a stack, and a backpack adds rows: the Hide Pack one (30 slots), the next two
## (36), and a later one four (48). It belongs to the character, and is part of the character save.
##
## It keeps itself in order: things lie in the slots one after another, in the order they came, and a slot that
## empties closes up. Nothing in it is ever thrown away by the game: if it is made smaller (a backpack taken off in
## the lab) what was in it stays, and nothing new goes in until there is room.
##
## Nothing in here is random, and it knows nothing about the screen.

const Accessories := preload("res://scripts/highlands/accessories.gd")

const COLS := 6
const SLOTS := 24                 # with no backpack: four rows
const STACK := 99
const MOST := 96                  # what a save may hold at the very most (whatever was in it is kept)
## The backpacks, least first: what each is called and how many rows it adds.
const PACKS := [
	{"name": "No backpack", "rows": 0},
	{"name": "Hide Pack", "rows": 1},
	{"name": "Leather Pack", "rows": 2},
	{"name": "Large Pack", "rows": 4},
]

## What can be carried in stacks so far, in the order the screen lists it.
const ORDER := ["stone", "wood", "tin_ore", "copper_ore", "tin_bar", "copper_bar", "passive_blank", "active_blank"]
const NAMES := {"stone": "Stone", "wood": "Wood", "tin_ore": "Tin ore", "copper_ore": "Copper ore", "tin_bar": "Tin bar", "copper_bar": "Copper bar",
	"passive_blank": "Passive blank stone", "active_blank": "Active blank stone"}
const TEXTS := {"stone": "Rubble from digging. For building, once there is something to build.", "wood": "From felled pines. For building, once there is something to build.",
	"tin_ore": "Mined from the pale veins. To be smelted into bars.", "copper_ore": "Mined from the orange veins. To be smelted into bars.",
	"tin_bar": "For tin parts, at the forge's anvil.", "copper_bar": "For copper parts, and for mending waystones.",
	"passive_blank": "At the forge: infuse it into a passive rune, break it down for Memory, or hand it over.",
	"active_blank": "At the forge: infuse it into an active rune, break it down for Memory, or hand it over."}

## Until backpacks can be made (Pip sews the first from hides, and there are no hides yet), the lab says which one
## everybody carries: the larger of this and the character's own counts.
static var LAB_PACK := 0

var pack := 0                # the backpack this character owns (which of PACKS)
var slots: Array = []        # [[item id, how many]], none empty


## What a thing is called.
static func name_of(id: String) -> String:
	return str(NAMES[id]) if NAMES.has(id) else Accessories.name_of(id)


## One line about it.
static func text_of(id: String) -> String:
	return str(TEXTS[id]) if TEXTS.has(id) else Accessories.text_of(id)


## How many of it lie in one slot: an accessory has a slot to itself.
static func stack_of(id: String) -> int:
	return 1 if Accessories.has(id) else STACK


## The backpack in use: the character's own, or the lab's if that is larger.
func pack_now() -> int:
	return clampi(maxi(pack, int(LAB_PACK)), 0, PACKS.size() - 1)


## How many slots there are.
func cap() -> int:
	return SLOTS + COLS * int(PACKS[pack_now()]["rows"])


## How many of one thing are in it, over all its stacks.
func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s[0] == id:
			n += int(s[1])
	return n


## How many more of it would fit: the room left in its stacks, and every empty slot.
func room(id: String) -> int:
	var stack := stack_of(id)
	var n := maxi(cap() - slots.size(), 0) * stack
	for s in slots:
		if s[0] == id:
			n += maxi(stack - int(s[1]), 0)
	return n


## Puts up to n in. Returns how many went in (fewer than n when it is full).
func add(id: String, n: int) -> int:
	var left := n
	var stack := stack_of(id)
	for s in slots:
		if left <= 0:
			break
		if s[0] == id and int(s[1]) < stack:
			var more := mini(stack - int(s[1]), left)
			s[1] = int(s[1]) + more
			left -= more
	while left > 0 and slots.size() < cap():
		var more := mini(stack, left)
		slots.append([id, more])
		left -= more
	return n - left


## Puts one in whether there is room or not: for something that must never be lost (an accessory coming back out
## of a satchel that has been made smaller). With no room it lies past the last slot until room is made.
func put_back(id: String) -> void:
	if add(id, 1) == 0:
		slots.append([id, 1])


## Takes n out, if there are that many. Returns false, and takes nothing, if there are not.
func take(id: String, n: int) -> bool:
	if n <= 0:
		return true
	if count(id) < n:
		return false
	var left := n
	for i in range(slots.size() - 1, -1, -1):
		if slots[i][0] != id:
			continue
		var less := mini(int(slots[i][1]), left)
		slots[i][1] = int(slots[i][1]) - less
		left -= less
		if int(slots[i][1]) == 0:
			slots.remove_at(i)
		if left == 0:
			break
	return true


## It as plain data, for the character save, and back. (A materials bag saved before version 47 is read as it is:
## its 20 stacks fit in the 24 slots.)
func data() -> Array:
	return slots.duplicate(true)


func set_data(d) -> void:
	slots = []
	if not (d is Array):
		return
	for s in d:
		if s is Array and s.size() == 2 and s[0] is String and (s[1] is int or s[1] is float) and int(s[1]) > 0 and slots.size() < MOST:
			slots.append([s[0], mini(int(s[1]), stack_of(s[0]))])
