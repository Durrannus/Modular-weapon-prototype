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
	"iron_shortblade": {"name": "Iron Shortblade", "chain": ["slash", "slash", "slash"], "damage": 7.0, "speed": 1.3, "reach": 0.9, "slots": 1, "element": "",
		"desc": "Slash, slash, slash. Short and fast, light hits. 1 slot."},
	"iron_blade": {"name": "Iron Blade", "chain": ["slash", "slash", "overhead"], "damage": 11.0, "speed": 1.0, "reach": 1.0, "slots": 2, "element": "",
		"desc": "Slash, slash, overhead. 2 slots."},
	"iron_longblade": {"name": "Iron Longblade", "chain": ["slash", "slash", "overhead"], "damage": 16.0, "speed": 0.78, "reach": 1.15, "slots": 3, "element": "",
		"desc": "Slash, slash, overhead. Long reach, slow, heavy hits. 3 slots."},
}
## Elemental blades are parked for now (Darren, 3 November), so only iron blades.
const BLADE_ORDER := ["iron_shortblade", "iron_blade", "iron_longblade"]

const GRIPS := {
	"wooden_grip": {"name": "Wooden Grip", "slots": 1, "speed": 1.0, "desc": "1 slot. Quick."},
	"wrapped_grip": {"name": "Wrapped Grip", "slots": 2, "speed": 0.95, "desc": "2 slots. A touch slower."},
	"long_grip": {"name": "Long Grip", "slots": 3, "speed": 0.88, "desc": "3 slots. Slower swings."},
	"ringed_grip": {"name": "Ringed Grip", "slots": 2, "speed": 0.95, "built_in": "wider",
		"desc": "2 slots. Special: a band in the pommel makes every rune a bit bigger."},
	"gilded_grip": {"name": "Gilded Grip", "slots": 2, "speed": 0.95, "ruby_slot": 1,
		"desc": "2 slots. Special: the ruby top slot doubles what's in it. A rune fires twice, a band counts as two (caps still apply)."},
}
const GRIP_ORDER := ["wooden_grip", "wrapped_grip", "long_grip", "ringed_grip", "gilded_grip"]

## Runes do something on their own; bands change the next rune above them.
## Rule-benders bend the reading rule itself. Only one per sword.
const FITTINGS := {
	"shockwave": {"kind": "rune", "name": "Shockwave", "trigger": "finisher", "color": Color("#ffb24a"),
		"desc": "Your finisher sends a rolling wave forward."},
	"hook": {"kind": "rune", "name": "Hook", "trigger": "finisher", "color": Color("#ff9a3c"),
		"desc": "Your finisher yanks nearby enemies in on chains."},
	"cleave": {"kind": "rune", "name": "Cleave", "trigger": "hit", "color": Color("#9fc8ff"),
		"desc": "Every hit also strikes an enemy behind the target."},
	# Second Wind is parked (Darren, 6 November: "meh"); Whirlwind replaces it in the tray.
	"second_wind": {"kind": "rune", "name": "Second Wind", "trigger": "kill", "color": Color("#8ff0c0"), "parked": true,
		"desc": "Every kill refills a dodge charge (up to 2)."},
	"leap": {"kind": "rune", "name": "Leap", "trigger": "dodge_attack", "color": Color("#f4e07a"),
		"desc": "Attacking straight after a dodge jumps you to the nearest enemy."},
	"whirlwind": {"kind": "rune", "name": "Whirlwind", "trigger": "finisher", "color": Color("#ff7ad9"),
		"desc": "Your finisher spins a full circle, cutting everything around you."},
	"twice": {"kind": "band", "name": "Twice", "color": Color("#6fd6cb"),
		"desc": "The rune above happens twice."},
	"wider": {"kind": "band", "name": "Wider", "color": Color("#6fd6cb"),
		"desc": "The rune above is bigger."},
	"every_hit": {"kind": "band", "name": "Every Hit", "color": Color("#6fd6cb"),
		"desc": "The rune above happens on every hit instead, at half strength."},
	"saved_up": {"kind": "band", "name": "Saved Up", "color": Color("#6fd6cb"),
		"desc": "The rune above only happens every third time, but three times as strong."},
	"on_dodge": {"kind": "band", "name": "On Dodge", "color": Color("#6fd6cb"),
		"desc": "The rune above also happens when you dodge."},
	# Mirror is parked (Darren, 6 November): it overlapped Twice too much. The rules stay, but it's kept out of the forge.
	"mirror": {"kind": "bender", "name": "Mirror", "color": Color("#d9a6ff"), "parked": true,
		"desc": "Rare. Copies the fitting below it. One rule-bender per sword."},
	"relay": {"kind": "bender", "name": "Relay", "color": Color("#d9a6ff"),
		"desc": "Rare. The bands on the rune below also boost the next rune above. One rule-bender per sword."},
}
const FITTING_ORDER := ["shockwave", "hook", "cleave", "whirlwind", "leap", "second_wind",
	"twice", "wider", "every_hit", "saved_up", "on_dodge", "mirror", "relay"]
const EVERY_HIT_POWER := 0.5
const SAVED_UP_EVERY := 3
const SAVED_UP_POWER := 3.0

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
##   effects: one entry per rune: {id, slot, bands (ids), band_slots, trigger, count, size,
##            power (strength multiplier), every (fires on every Nth trigger), also (extra triggers),
##            mirror (true if it's a Mirror's copy)}
##   slots:   for each slot index: {"rune": effect index} / {"band": effect index} /
##            {"unused": true, "why": text} / plus "mirror": true or "relay": true on rule-benders
## ruby: the Gilded grip's ruby slot index (-1 if none). A rune there fires one more
## time, and a band there counts as two bands, both within the caps.
static func resolve(slots: Array, ruby := -1) -> Dictionary:
	var effects: Array = []
	var info := {}
	var line := _apply_mirror(slots, info)
	var pending: Array = []   # band slot indexes waiting for a rune
	var relay_bands: Array = []  # band slots handed on by a Relay
	var relay_slot := -1
	for i in line.size():
		var id: String = line[i]
		if id == "" or info.get(i, {}).has("unused"):
			continue
		var f: Dictionary = FITTINGS[id]
		if f["kind"] == "bender":  # Relay (Mirror was swapped for its copy above)
			if effects.is_empty() or not pending.is_empty():
				info[i] = {"unused": true, "relay": true, "why": "Needs a rune right below it."}
				continue
			relay_bands = (effects[-1]["band_slots"] as Array).duplicate()
			relay_slot = i
			info[i] = {"relay": true}
			continue
		if f["kind"] == "band":
			pending.append(i)
			continue
		var e := {"id": id, "slot": i, "bands": [], "band_slots": pending.duplicate(), "trigger": f["trigger"],
			"count": 1, "size": 1.0, "power": 1.0, "every": 1, "also": [], "mirror": slots[i] == "mirror"}
		var idx := effects.size()
		for s in relay_bands + pending:
			var why := _apply_band(e, str(line[s]))
			if s == ruby and why == "":
				_apply_band(e, str(line[s]))  # the ruby counts it twice
			if s in pending:
				info[s] = {"band": idx} if why == "" else {"unused": true, "why": why}
		if i == ruby:
			e["count"] = mini(int(e["count"]) + 1, MAX_COUNT)
			e["ruby"] = true
		if relay_slot >= 0:
			e["relayed"] = relay_bands
			info[relay_slot]["band"] = idx
			relay_slot = -1
			relay_bands = []
		info[i] = {"rune": idx}
		effects.append(e)
		pending = []
	for s in pending:
		info[s] = {"unused": true, "why": "No rune above it, so it does nothing."}
	if relay_slot >= 0:
		info[relay_slot] = {"unused": true, "relay": true, "why": "Needs a rune above it."}
	for i in slots.size():
		if slots[i] == "mirror":
			info[i] = info.get(i, {})
			info[i]["mirror"] = true
	return {"effects": effects, "slots": info}


## Mirror becomes a copy of the nearest fitting below it. Only the first
## rule-bender on the sword counts; any others do nothing.
static func _apply_mirror(slots: Array, info: Dictionary) -> Array:
	var line := slots.duplicate()
	var seen := false
	for i in line.size():
		var id: String = line[i]
		if id == "" or FITTINGS[id]["kind"] != "bender":
			continue
		if seen:
			info[i] = {"unused": true, "why": "Only one rule-bender works on a sword."}
			continue
		seen = true
		if id != "mirror":
			continue
		var below := ""
		for j in range(i - 1, -1, -1):
			if line[j] != "":
				below = line[j]
				break
		if below == "":
			info[i] = {"unused": true, "mirror": true, "why": "Nothing below it to copy."}
		else:
			line[i] = below
			info[i] = {"mirror": true}
	return line


## Applies one band to a rune. Returns "" if it worked, or why it does nothing.
static func _apply_band(e: Dictionary, band: String) -> String:
	e["bands"].append(band)
	match band:
		"twice":
			e["count"] = mini(int(e["count"]) + 1, MAX_COUNT)
		"wider":
			e["wider"] = int(e.get("wider", 0)) + 1
			e["size"] = wider_size(int(e["wider"]))
		"every_hit":
			if e["trigger"] == "hit":
				return "%s already works on every hit." % FITTINGS[e["id"]]["name"]
			e["trigger"] = "hit"
			e["power"] = float(e["power"]) * EVERY_HIT_POWER
		"saved_up":
			if int(e["every"]) > 1:
				return "Saved Up doesn't stack (max)."
			e["every"] = SAVED_UP_EVERY
			e["power"] = float(e["power"]) * SAVED_UP_POWER
		"on_dodge":
			if "dodge" in e["also"]:
				return "On Dodge doesn't stack (max)."
			if e["id"] == "second_wind":
				return "Second Wind can't refill the dodge you're using."
			if e["id"] == "cleave":
				return "Cleave needs a hit to strike behind."
			e["also"].append("dodge")
	return ""


const WHEN := {"finisher": "Your finisher", "hit": "Every hit", "kill": "Every kill", "dodge_attack": "An attack straight after a dodge"}
const WHEN_NTH := {"finisher": "Every third finisher", "hit": "Every third hit", "kill": "Every third kill", "dodge_attack": "Every third attack after a dodge"}


## One plain sentence per rune, e.g. "Your finisher sends two shockwaves forward."
static func sentence(e: Dictionary) -> String:
	var n: int = e["count"]
	var big: bool = float(e["size"]) > 1.0
	var times := "" if n == 1 else (" twice" if n == 2 else " %d times" % n)
	var trig: String = e["trigger"]
	var when: String = (WHEN_NTH if int(e.get("every", 1)) > 1 else WHEN).get(trig, "It")
	var what := ""
	match str(e["id"]):
		"shockwave":
			what = "sends %s forward" % (("a big shockwave" if big else "a shockwave") if n == 1 else ("%s %sshockwaves" % [_num(n), "big " if big else ""]))
		"hook":
			what = "pulls enemies in%s%s" % [" from further away" if big else "", times]
		"cleave":
			what = "also strikes %s behind the target%s" % ["one enemy" if n == 1 else _num(n) + " enemies", ", from further away" if big else ""]
		"second_wind":
			what = "refills %s%s" % ["a dodge charge" if n == 1 else _num(n) + " dodge charges", " and knocks enemies back" if big else ""]
		"whirlwind":
			what = "spins %s, cutting everything around you%s" % ["a full circle" if n == 1 else _num(n) + " times round", ", in a bigger circle" if big else ""]
		"leap":
			what = "jumps you to the nearest enemy%s%s" % ["" if n == 1 else (", then the next one" if n == 2 else ", then %s more" % _num(n - 1)), ", from further away" if big else ""]
		_:
			return ""
	var power := float(e.get("power", 1.0))
	if power < 1.0:
		what += ", at half strength"
	elif power >= 3.0:
		what += ", three times as strong"
	elif power > 1.0:
		what += ", %sx as strong" % str(snappedf(power, 0.1))
	var s := "%s %s." % [when, what]
	if "dodge" in e.get("also", []):
		s += " Dodging does it too."
	return s


static func _num(n: int) -> String:
	return ["zero", "one", "two", "three", "four", "five", "six"][clampi(n, 0, 6)]


## Everything the player needs, as one plain dictionary.
func compute() -> Dictionary:
	var b: Dictionary = BLADES[blade]
	var g: Dictionary = GRIPS[grip]
	var steps: Array = []
	for m in b["chain"]:
		steps.append({"move": m, "from": b["name"]})
	var r := resolve(line, int(g.get("ruby_slot", -1)))
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
