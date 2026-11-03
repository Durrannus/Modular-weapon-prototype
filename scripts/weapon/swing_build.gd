extends RefCounted
## The swing path (3 November design). A sword is a blade plus a grip.
## - The blade sets the basic three-hit chain you always swing (for now every
##   blade but the wooden one is slash, slash, overhead; extra moves like lunge
##   are meant to come from runes later).
## - Grip and blade both have slots. Slots hold runes (effects) or bands (modifiers).
## - Read the sword as one line from the bottom of the grip to the tip of the blade.
##   A band boosts the next rune above it. Bands in a row stack onto that rune.
##   A band with no rune above it does nothing.

signal changed

const BLADES := {
	"wooden_blade": {"name": "Wooden Blade", "chain": ["slash", "slash", "slash"], "damage": 9.0, "speed": 1.0, "reach": 1.0, "slots": 1, "element": "", "cells": 1,
		"desc": "Slash, slash, slash. 1 slot."},
	"iron_longblade": {"name": "Iron Longblade", "chain": ["slash", "slash", "overhead"], "damage": 12.0, "speed": 0.9, "reach": 1.15, "slots": 2, "element": "", "cells": 2,
		"desc": "Slash, slash, overhead. Hits hard, a bit slower. 2 slots."},
	"fire_shard": {"name": "Fire Blade", "chain": ["slash", "slash", "overhead"], "damage": 8.0, "speed": 1.05, "reach": 1.0, "slots": 2, "element": "fire", "cells": 1,
		"desc": "Slash, slash, overhead. Sets enemies burning. 2 slots."},
	"water_shard": {"name": "Water Blade", "chain": ["slash", "slash", "overhead"], "damage": 8.0, "speed": 1.05, "reach": 1.0, "slots": 2, "element": "water", "cells": 1,
		"desc": "Slash, slash, overhead. Slows enemies. 2 slots."},
	"lightning_shard": {"name": "Lightning Blade", "chain": ["slash", "slash", "overhead"], "damage": 7.0, "speed": 1.1, "reach": 1.0, "slots": 2, "element": "lightning", "cells": 1,
		"desc": "Slash, slash, overhead. Lightning jumps to a nearby enemy. 2 slots."},
}
## Elemental blades are parked for now (Darren, 3 November), so only plain blades are offered.
const BLADE_ORDER := ["wooden_blade", "iron_longblade"]

const GRIPS := {
	"short_grip": {"name": "Short Grip", "slots": 1, "speed": 1.0, "sprite": "wooden_handle", "hilt": "wooden_hilt", "pommel": "wooden_pommel",
		"desc": "1 slot. Quick."},
	"wrapped_grip": {"name": "Wrapped Grip", "slots": 2, "speed": 0.95, "sprite": "wrapped_handle", "hilt": "wooden_hilt", "pommel": "curved_pommel",
		"desc": "2 slots. A touch slower."},
	"long_grip": {"name": "Long Grip", "slots": 3, "speed": 0.88, "sprite": "long_handle", "hilt": "cross_hilt", "pommel": "spike_pommel",
		"desc": "3 slots. Slower swings."},
}
const GRIP_ORDER := ["short_grip", "wrapped_grip", "long_grip"]

## Runes do something on their own; bands change the next rune above them.
const FITTINGS := {
	"shockwave": {"kind": "rune", "name": "Shockwave", "trigger": "finisher", "color": Color(1.0, 0.72, 0.25),
		"desc": "Your finisher sends a rolling wave forward."},
	"hook": {"kind": "rune", "name": "Hook", "trigger": "finisher", "color": Color(0.95, 0.45, 0.3),
		"desc": "Your finisher yanks nearby enemies in on chains."},
	"cleave": {"kind": "rune", "name": "Cleave", "trigger": "hit", "color": Color(1.0, 0.9, 0.55),
		"desc": "Every hit also strikes an enemy behind the target."},
	"second_wind": {"kind": "rune", "name": "Second Wind", "trigger": "kill", "color": Color(0.5, 1.0, 0.6),
		"desc": "Every kill refills a dodge charge (up to 2)."},
	"twice": {"kind": "band", "name": "Twice", "color": Color(0.45, 0.95, 0.9),
		"desc": "The rune above happens twice."},
	"wider": {"kind": "band", "name": "Wider", "color": Color(0.55, 0.75, 1.0),
		"desc": "The rune above is bigger."},
}
const FITTING_ORDER := ["shockwave", "hook", "cleave", "second_wind", "twice", "wider"]

## The test swords from the 3 November notes, bottom to top.
const TEST_SWORDS := {
	"A": {"blade": "iron_longblade", "grip": "wrapped_grip", "line": ["twice", "shockwave", "wider", "hook"]},
	"B": {"blade": "iron_longblade", "grip": "wrapped_grip", "line": ["shockwave", "twice", "wider", "hook"]},
}

var blade := "wooden_blade"
var grip := "short_grip"
## Slot contents bottom to top: grip slots first, then blade slots. "" is empty.
var line: Array = [""]


func slot_count() -> int:
	return int(GRIPS[grip]["slots"]) + int(BLADES[blade]["slots"])


func grip_slots() -> int:
	return int(GRIPS[grip]["slots"])


## Keeps the line the right length after a grip or blade change.
## Grip slots keep their fittings, blade slots keep theirs, extras drop off the top.
func _refit(old_grip_slots: int) -> void:
	var g: Array = line.slice(0, old_grip_slots)
	var b: Array = line.slice(old_grip_slots)
	var gs := grip_slots()
	var bs := int(BLADES[blade]["slots"])
	g.resize(gs)
	b.resize(bs)
	line = []
	for x in g + b:
		line.append("" if x == null else x)


func set_blade(id: String) -> void:
	var old := grip_slots()
	blade = id
	_refit(old)
	changed.emit()


func set_grip(id: String) -> void:
	var old := grip_slots()
	grip = id
	_refit(old)
	changed.emit()


func set_slot(i: int, fitting: String) -> void:
	if i < 0 or i >= line.size():
		return
	line[i] = fitting
	changed.emit()


func load_test(key: String) -> void:
	var t: Dictionary = TEST_SWORDS[key]
	blade = t["blade"]
	grip = t["grip"]
	line = (t["line"] as Array).duplicate()
	_refit(grip_slots())
	changed.emit()


## Reads the line bottom to top. Returns:
##   effects: one entry per rune: {id, slot, bands (ids), band_slots, trigger, count, size}
##   slots:   for each slot index: {"rune": effect index} / {"band": effect index} / {"unused": true}
static func resolve(slots: Array) -> Dictionary:
	var effects: Array = []
	var info := {}
	var pending: Array = []  # band slot indexes waiting for a rune
	for i in slots.size():
		var id: String = slots[i]
		if id == "":
			continue
		var f: Dictionary = FITTINGS[id]
		if f["kind"] == "band":
			pending.append(i)
			continue
		var e := {"id": id, "slot": i, "bands": [], "band_slots": pending.duplicate(), "trigger": f["trigger"], "count": 1, "size": 1.0}
		for s in pending:
			var band: String = slots[s]
			e["bands"].append(band)
			if band == "twice":
				e["count"] += 1
			elif band == "wider":
				e["size"] *= 1.6
			info[s] = {"band": effects.size()}
		info[i] = {"rune": effects.size()}
		effects.append(e)
		pending = []
	for s in pending:
		info[s] = {"unused": true}
	return {"effects": effects, "slots": info}


## One plain sentence per rune, e.g. "Your finisher sends two shockwaves forward."
static func sentence(e: Dictionary) -> String:
	var n: int = e["count"]
	var big: bool = float(e["size"]) > 1.0
	var times := "" if n == 1 else (" twice" if n == 2 else " %d times" % n)
	match str(e["id"]):
		"shockwave":
			var what := ("a big shockwave" if big else "a shockwave") if n == 1 else ("%s %sshockwaves" % [_num(n), "big " if big else ""])
			return "Your finisher sends %s forward." % what
		"hook":
			return "Your finisher pulls enemies in%s%s." % [" from further away" if big else "", times]
		"cleave":
			return "Every hit also strikes %s behind the target%s." % ["one enemy" if n == 1 else _num(n) + " enemies", ", from further away" if big else ""]
		"second_wind":
			return "Every kill refills %s%s." % ["a dodge charge" if n == 1 else _num(n) + " dodge charges", " and knocks enemies back" if big else ""]
	return ""


static func _num(n: int) -> String:
	return ["zero", "one", "two", "three", "four", "five", "six"][clampi(n, 0, 6)]


## Everything the player needs, as one plain dictionary.
func compute() -> Dictionary:
	var b: Dictionary = BLADES[blade]
	var g: Dictionary = GRIPS[grip]
	var steps: Array = []
	for m in b["chain"]:
		steps.append({"move": m, "from": b["name"]})
	var r := resolve(line)
	var element: String = b["element"]
	var hit_color := Color.WHITE
	if element != "":
		hit_color = ELEMENT_COLORS[element]
	return {
		"blade": blade,
		"grip": grip,
		"line": line.duplicate(),
		"grip_slots": grip_slots(),
		"effects": r["effects"],
		"slot_info": r["slots"],
		"steps": steps,
		"damage": float(b["damage"]),
		"speed": float(b["speed"]) * float(g["speed"]),
		"reach": float(b["reach"]),
		"crit": 0.07,
		"crit_damage": 1.6,
		"area": 0.0,
		"move_speed": 0.0,
		"elements": [element] if element != "" else [],
		"combos": [],
		"hit_color": hit_color,
	}


const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.5, 0.2),
	"water": Color(0.35, 0.65, 1.0),
	"lightning": Color(1.0, 0.95, 0.35),
	"steam": Color(0.85, 0.9, 0.95),
	"electrified": Color(0.6, 0.85, 1.0),
}
