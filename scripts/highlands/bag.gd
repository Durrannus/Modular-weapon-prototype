extends RefCounted
## A character's materials bag.
##
## Darren, 22 November 2026 (a card in the planning thread): "Separate stacking bag". Ore, bars, hides, wood, stone
## and other materials go in here, in stacks, and never into the accessory backpack grid. It belongs to the
## character, and is part of the character save. The Game Bible's first numbers: about 20 slots, 99 a stack.
##
## Nothing in here is random, and it knows nothing about the screen.

const SLOTS := 20
const STACK := 99

## What can be carried so far, in the order the screen lists it.
const ORDER := ["stone", "wood", "tin_ore", "copper_ore"]
const NAMES := {"stone": "Stone", "wood": "Wood", "tin_ore": "Tin ore", "copper_ore": "Copper ore"}

var slots: Array = []        # [[item id, how many]], at most SLOTS of them, none empty


## How many of one thing are in the bag, over all its stacks.
func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s[0] == id:
			n += int(s[1])
	return n


## How many more of it would fit: the room left in its stacks, and every empty slot.
func room(id: String) -> int:
	var n := (SLOTS - slots.size()) * STACK
	for s in slots:
		if s[0] == id:
			n += STACK - int(s[1])
	return n


## Puts up to n in. Returns how many went in (fewer than n when the bag is full).
func add(id: String, n: int) -> int:
	var left := n
	for s in slots:
		if left <= 0:
			break
		if s[0] == id and int(s[1]) < STACK:
			var more := mini(STACK - int(s[1]), left)
			s[1] = int(s[1]) + more
			left -= more
	while left > 0 and slots.size() < SLOTS:
		var more := mini(STACK, left)
		slots.append([id, more])
		left -= more
	return n - left


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


## The bag as plain data, for the character save, and back.
func data() -> Array:
	return slots.duplicate(true)


func set_data(d) -> void:
	slots = []
	if not (d is Array):
		return
	for s in d:
		if s is Array and s.size() == 2 and s[0] is String and (s[1] is int or s[1] is float) and int(s[1]) > 0 and slots.size() < SLOTS:
			slots.append([s[0], mini(int(s[1]), STACK)])
