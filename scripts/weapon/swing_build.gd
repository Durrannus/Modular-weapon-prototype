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
	"iron_shortblade": {"name": "Iron Shortblade", "chain": ["slash", "slash", "slash"], "damage": 10.0, "speed": 1.08, "reach": 0.9, "slots": 1, "element": "",
		"desc": "Slash, slash, slash. Quick. 1 slot."},
	"iron_blade": {"name": "Iron Blade", "chain": ["slash", "slash", "overhead"], "damage": 11.0, "speed": 1.0, "reach": 1.0, "slots": 2, "element": "",
		"desc": "Slash, slash, overhead. 2 slots."},
	"iron_longblade": {"name": "Iron Longblade", "chain": ["slash", "slash", "overhead"], "damage": 9.0, "speed": 0.95, "reach": 1.15, "slots": 3, "element": "",
		"desc": "Slash, slash, overhead. More reach and slots, softer hits. 3 slots."},
}
## Elemental blades are parked for now (Darren, 3 November), so only iron blades.
const BLADE_ORDER := ["iron_shortblade", "iron_blade", "iron_longblade"]

const GRIPS := {
	"wooden_grip": {"name": "Wooden Grip", "slots": 1, "speed": 1.0, "desc": "1 slot. Quick."},
	"wrapped_grip": {"name": "Wrapped Grip", "slots": 2, "speed": 0.95, "desc": "2 slots. A touch slower."},
	"long_grip": {"name": "Long Grip", "slots": 3, "speed": 0.88, "desc": "3 slots. Slower swings."},
	"ringed_grip": {"name": "Ringed Grip", "slots": 2, "speed": 0.95, "built_in": "wider",
		"desc": "2 slots. Special: a band in the pommel makes every rune a bit bigger."},
	"gilded_grip": {"name": "Gilded Grip", "slots": 2, "speed": 0.95, "locked": true,
		"desc": "Special: its top slot is an odd slot. Not designed yet."},
}
const GRIP_ORDER := ["wooden_grip", "wrapped_grip", "long_grip", "ringed_grip", "gilded_grip"]

## Runes do something on their own; bands change the next rune above them.
const FITTINGS := {
	"shockwave": {"kind": "rune", "name": "Shockwave", "trigger": "finisher", "color": Color("#ffb24a"),
		"desc": "Your finisher sends a rolling wave forward."},
	"hook": {"kind": "rune", "name": "Hook", "trigger": "finisher", "color": Color("#ff9a3c"),
		"desc": "Your finisher yanks nearby enemies in on chains."},
	"cleave": {"kind": "rune", "name": "Cleave", "trigger": "hit", "color": Color("#9fc8ff"),
		"desc": "Every hit also strikes an enemy behind the target."},
	"second_wind": {"kind": "rune", "name": "Second Wind", "trigger": "kill", "color": Color("#8ff0c0"),
		"desc": "Every kill refills a dodge charge (up to 2)."},
	"twice": {"kind": "band", "name": "Twice", "color": Color("#6fd6cb"),
		"desc": "The rune above happens twice."},
	"wider": {"kind": "band", "name": "Wider", "color": Color("#6fd6cb"),
		"desc": "The rune above is bigger."},
}
const FITTING_ORDER := ["shockwave", "hook", "cleave", "second_wind", "twice", "wider"]

## The test swords from the 3 November notes, bottom to top.
const TEST_SWORDS := {
	"A": {"blade": "iron_blade", "grip": "wrapped_grip", "line": ["twice", "shockwave", "wider", "hook"]},
	"B": {"blade": "iron_blade", "grip": "wrapped_grip", "line": ["shockwave", "twice", "wider", "hook"]},
}

var blade := "iron_shortblade"
var grip := "wooden_grip"
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


# Stacking limits: each extra band of a kind adds less, up to a cap.
const MAX_COUNT := 3          # Twice: at most 3 fires
const MAX_SIZE := 2.0         # Wider: at most 2x size
const WIDER_STEPS := [1.6, 1.85, 2.0]  # 1, 2, 3+ Wider bands


static func wider_size(n: int) -> float:
	if n <= 0:
		return 1.0
	return minf(WIDER_STEPS[mini(n, WIDER_STEPS.size()) - 1], MAX_SIZE)


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
				e["count"] = mini(int(e["count"]) + 1, MAX_COUNT)
			elif band == "wider":
				e["wider"] = int(e.get("wider", 0)) + 1
				e["size"] = wider_size(int(e["wider"]))
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
	if g.get("built_in", "") == "wider":
		for e in r["effects"]:
			e["size"] = minf(float(e["size"]) * 1.3, MAX_SIZE)
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
