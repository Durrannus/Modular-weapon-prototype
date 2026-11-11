extends RefCounted
## The swing path (3 November design). A sword is a blade plus a grip.
## - The blade's shape sets the three-hit chain you always swing, and how it
##   feels: speed, reach, arc and one lean (11 November, the six blade shapes).
##   Its metal sets the damage.
## - Grip and blade both have slots. Slots hold runes (effects) or bands (modifiers).
## - Read the sword as one line from the bottom of the grip to the tip of the blade.
##   A band boosts the next rune above it. Bands in a row stack onto that rune.
##   A band with no rune above it does nothing.

signal changed

## The six blade shapes (Game Bible, "Blade shapes", decided 11 November). Every
## sword blade in the game is one of these. The numbers are multiples of the
## broadsword of the same metal, and damage x speed stays within a tenth of the
## broadsword's for every shape: a shape is a way of playing, not more power.
##   chain       the three moves (tuned in MOVES in player.gd)
##   swing_move  walking speed while swinging (most blades: 0.9)
##   crit        extra crit chance
const SHAPES := {
	"dagger": {"name": "Dagger", "chain": ["dagger_stab", "dagger_slash", "dagger_finish"],
		"damage": 0.6, "speed": 1.6, "reach": 0.6, "swing_move": 1.0,
		"desc": "Stab, slash, stab: very fast with a short reach, and you keep your full speed while attacking."},
	"sabre": {"name": "Sabre", "chain": ["sabre_slash", "sabre_back", "sabre_sweep"],
		"damage": 0.85, "speed": 1.25, "reach": 0.9, "crit": 0.1,
		"desc": "Slash, backslash, wide sweep: quick, wide cuts with 10% more crit chance."},
	"broadsword": {"name": "Broadsword", "chain": ["slash", "slash", "overhead"],
		"damage": 1.0, "speed": 1.0, "reach": 1.0,
		"desc": "Slash, slash, overhead: the balanced blade."},
	"rapier": {"name": "Rapier", "chain": ["thrust", "thrust", "long_thrust"],
		"damage": 0.9, "speed": 1.1, "reach": 1.4,
		"desc": "Thrust, thrust, lunge: a long reach in a straight line, and every thrust goes through to a second enemy."},
	"falchion": {"name": "Falchion", "chain": ["chop", "chop", "cleave"],
		"damage": 1.35, "speed": 0.8, "reach": 0.9,
		"desc": "Chop, chop, cleave: slow, heavy hits that knock enemies back, and the cleave staggers them."},
	"greatsword": {"name": "Greatsword", "chain": ["great_sweep", "great_back", "slam"],
		"damage": 1.6, "speed": 0.65, "reach": 1.5, "swing_move": 0.7,
		"desc": "Sweep, backswing, slam: huge reach and damage, but very slow, and you walk slower while swinging."},
}
const SHAPE_ORDER := ["dagger", "sabre", "broadsword", "rapier", "falchion", "greatsword"]
const SWING_MOVE := 0.9        # walking speed while swinging, unless the shape says otherwise

## What a move is called on screen.
const MOVE_NAMES := {"slash": "slash", "overhead": "overhead",
	"dagger_stab": "stab", "dagger_slash": "slash", "dagger_finish": "stab",
	"sabre_slash": "slash", "sabre_back": "backslash", "sabre_sweep": "sweep",
	"thrust": "thrust", "long_thrust": "lunge",
	"chop": "chop", "cleave": "cleave",
	"great_sweep": "sweep", "great_back": "backswing", "slam": "slam"}

## A broadsword's damage in each metal. (Later metals each add about a quarter.)
const METALS := {"wood": 5.0, "tin": 8.0, "iron": 11.0}

## In the prototype every iron shape has two slots: slots come from a blade's
## tier, never from its shape.
const BLADES := {
	# The tutorial cave's blades. Wooden is the training sword from the ship crate
	# (no slots: its one slot is on the grip). Tin is the first real metal.
	"wooden_blade": {"name": "Wooden Blade", "shape": "broadsword", "metal": "wood", "slots": 0, "element": "",
		"desc": "Slash, slash, overhead: a training sword."},
	"tin_blade": {"name": "Tin Blade", "shape": "broadsword", "metal": "tin", "slots": 1, "element": "",
		"desc": "Slash, slash, overhead: soft, but real metal."},
	"iron_dagger": {"name": "Iron Dagger", "shape": "dagger", "metal": "iron", "slots": 2, "element": ""},
	"iron_sabre": {"name": "Iron Sabre", "shape": "sabre", "metal": "iron", "slots": 2, "element": ""},
	"iron_broadsword": {"name": "Iron Broadsword", "shape": "broadsword", "metal": "iron", "slots": 2, "element": ""},
	"iron_rapier": {"name": "Iron Rapier", "shape": "rapier", "metal": "iron", "slots": 2, "element": ""},
	"iron_falchion": {"name": "Iron Falchion", "shape": "falchion", "metal": "iron", "slots": 2, "element": ""},
	"iron_greatsword": {"name": "Iron Greatsword", "shape": "greatsword", "metal": "iron", "slots": 2, "element": ""},
}
## Elemental blades are parked for now (Darren, 3 November), so only iron blades.
const BLADE_ORDER := ["iron_dagger", "iron_sabre", "iron_broadsword", "iron_rapier", "iron_falchion", "iron_greatsword"]


## Everything about a blade in one place: its own entry, its shape's chain and
## lean, and its numbers worked out from shape and metal.
static func blade_info(id: String) -> Dictionary:
	var b: Dictionary = BLADES[id]
	var s: Dictionary = SHAPES[b["shape"]]
	return {
		"name": b["name"], "shape": b["shape"], "shape_name": s["name"], "metal": b["metal"],
		"slots": int(b["slots"]), "element": b["element"],
		"chain": s["chain"],
		"damage": float(METALS[b["metal"]]) * float(s["damage"]),
		"speed": float(s["speed"]),
		"reach": float(s["reach"]),
		"crit": float(s.get("crit", 0.0)),
		"swing_move": float(s.get("swing_move", SWING_MOVE)),
		"desc": str(b.get("desc", s["desc"])),
	}


## Slots never make a part weaker (Game Bible): a grip with more of them swings
## just as fast.
const GRIPS := {
	"tin_grip": {"name": "Tin Grip", "slots": 1, "desc": "One slot."},
	"wooden_grip": {"name": "Wooden Grip", "slots": 1, "desc": "One slot."},
	"wrapped_grip": {"name": "Wrapped Grip", "slots": 2, "desc": "Two slots."},
	"long_grip": {"name": "Long Grip", "slots": 3, "desc": "Three slots."},
	"ringed_grip": {"name": "Ringed Grip", "slots": 2, "built_in": "wider",
		"desc": "Two slots, and a band built into the pommel makes every rune a bit bigger."},
	"gilded_grip": {"name": "Gilded Grip", "slots": 2, "ruby_slot": 1,
		"desc": "Two slots, and the ruby top slot doubles what is in it: a rune fires twice, a band counts as two."},
}
const GRIP_ORDER := ["wooden_grip", "wrapped_grip", "long_grip", "ringed_grip", "gilded_grip"]

## Pommels (Game Plan, decided 7 November in the prototype): no slots, stats only.
## These are fixed test rolls; real pommels will roll stats in the rarity tiers.
const POMMELS := {
	"plain_pommel": {"name": "Plain Pommel", "desc": "No bonus.", "color": Color("#94a8b8")},
	"keen_pommel": {"name": "Keen Pommel", "crit": 0.08, "desc": "+8% crit chance.", "color": Color("#78c0cc")},
	"heavy_pommel": {"name": "Heavy Pommel", "crit_damage": 0.4, "desc": "+40% crit damage.", "color": Color("#cf8a48")},
	"light_pommel": {"name": "Light Pommel", "speed": 0.1, "desc": "+10% swing speed.", "color": Color("#e8e4bc")},
}
const POMMEL_ORDER := ["plain_pommel", "keen_pommel", "heavy_pommel", "light_pommel"]

## Runes do something on their own; bands change the next rune above them.
## Rule-benders bend the reading rule itself. Only one per sword.
##
## Runes are passive or active (Darren, 10 November). A passive rune fires by
## itself on a moment of the chain (its "trigger"). An active rune (trigger
## "active") waits for its ability button:
##   use       "press": one press uses it, and it needs its whole recharge again
##             "hold":  it keeps going, turn after turn, while the button is down
##   recharge  seconds from used up to ready
##   turns     hold only: how many turns a full meter holds
##   turn      hold only: how long one turn takes, in seconds
const FITTINGS := {
	"shockwave": {"kind": "rune", "name": "Shockwave", "trigger": "finisher", "color": Color("#ffc850"),
		"desc": "Your finisher sends a wave forward."},
	"hook": {"kind": "rune", "name": "Hook", "trigger": "active", "use": "press", "recharge": 4.0, "color": Color("#ff9c32"),
		"desc": "Press its button to yank nearby enemies in."},
	# Shards replaced Cleave (Darren, 6 November).
	"shards": {"kind": "rune", "name": "Shards", "trigger": "hit", "color": Color("#d0dcd8"),
		"desc": "Every hit sends shards jumping to the nearest enemies."},
	# Weak Point (Darren, 11 November): the sword's single-target passive. The finisher
	# marks the enemy it hit; the next sword hit on the mark is a big crit. Small
	# enemies glow all over. Big ones get a spot on one side that you have to reach.
	"weak_point": {"kind": "rune", "name": "Weak Point", "trigger": "finisher", "color": Color("#b8f4ff"),
		"desc": "Your finisher marks an enemy, and your next hit on the mark is a big crit."},
	"whirlwind": {"kind": "rune", "name": "Whirlwind", "trigger": "active", "use": "hold", "recharge": 5.0, "turns": 3, "turn": 0.28, "color": Color("#f078b4"),
		"desc": "Hold its button to spin and cut everything around you."},
	# Leap is active since 11 November (it was "attack straight after a dodge").
	"leap": {"kind": "rune", "name": "Leap", "trigger": "active", "use": "press", "recharge": 3.0, "color": Color("#f0c070"),
		"desc": "Press its button to leap at the nearest enemy and strike it."},
	"twice": {"kind": "band", "name": "Twice", "color": Color("#86d4a4"),
		"desc": "The rune above happens twice."},
	"wider": {"kind": "band", "name": "Wider", "color": Color("#86d4a4"),
		"desc": "The rune above is bigger."},
	"every_hit": {"kind": "band", "name": "Every Hit", "color": Color("#86d4a4"),
		"desc": "The rune above happens on every hit, at half strength."},
	"saved_up": {"kind": "band", "name": "Saved Up", "color": Color("#86d4a4"),
		"desc": "The rune above is three times as strong, but comes a third as often."},
	"on_dodge": {"kind": "band", "name": "On Dodge", "color": Color("#86d4a4"),
		"desc": "The rune above also happens when you dodge."},
	# Mirror is parked (Darren, 6 November): it overlapped Twice too much. The rules stay, but it's kept out of the forge.
	"mirror": {"kind": "bender", "name": "Mirror", "color": Color("#a878d0"), "parked": true,
		"desc": "Rare. Copies the fitting below it. One rule-bender per sword."},
	"relay": {"kind": "bender", "name": "Relay", "color": Color("#a878d0"),
		"desc": "Rare: the bands under the rune below also boost the next rune above."},
}
## Passive runes first, then active ones (the forge tray shows them as two groups).
const FITTING_ORDER := ["shockwave", "shards", "weak_point", "whirlwind", "hook", "leap",
	"twice", "wider", "every_hit", "saved_up", "on_dodge", "mirror", "relay"]
const EVERY_HIT_POWER := 0.5
const SAVED_UP_EVERY := 3
const SAVED_UP_POWER := 3.0

## Active runes take the ability buttons in the order they sit on the sword, grip
## to tip. Two of the same rune share a button. Up to three active runes work on
## one sword (Darren, 11 November; it was two). What the buttons are called and
## which prompt pictures show them (art/cave/ui/prompt_<name>.png). The third
## button's keys (R, B) are a first guess, to settle in testing.
const ACTIVE_BUTTONS := 3
const ABILITY_KEYS := {"kbm": ["right mouse", "Q", "R"], "pad": ["RB", "LB", "B"]}
const ABILITY_PROMPTS := {"kbm": ["mouse_right", "q", "r"], "pad": ["pad_rb", "pad_lb", "pad_b"]}

## The test swords from the 3 November notes, bottom to top.
const TEST_SWORDS := {
	"A": {"blade": "iron_broadsword", "grip": "wrapped_grip", "line": ["twice", "shockwave", "wider", "hook"]},
	"B": {"blade": "iron_broadsword", "grip": "wrapped_grip", "line": ["shockwave", "twice", "wider", "hook"]},
	# 10 November: both active runes and a passive one. Whirlwind sits lowest, so it
	# gets the first ability button (right mouse or RB), which is the easy one to hold.
	"C": {"blade": "iron_broadsword", "grip": "wrapped_grip", "line": ["whirlwind", "hook", "twice", "shockwave"]},
	# 11 November: all three active runes, one on each button, and the new passive.
	"D": {"blade": "iron_broadsword", "grip": "wrapped_grip", "line": ["whirlwind", "hook", "leap", "weak_point"]},
}

var blade := "iron_dagger"
var grip := "wooden_grip"
var pommel := "plain_pommel"
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


func set_pommel(id: String) -> void:
	pommel = id
	changed.emit()


## The whole sword as plain values, to send to the other computer online.
func get_data() -> Array:
	return [blade, grip, pommel, line.duplicate()]


## True if `data` is a sword get_data() could have made (every part exists and
## the slots fit), so nothing odd can arrive from the other computer.
static func valid_data(data) -> bool:
	if not (data is Array) or data.size() != 4 or not (data[3] is Array):
		return false
	if not (data[0] is String and data[1] is String and data[2] is String):
		return false
	if not (BLADES.has(data[0]) and GRIPS.has(data[1]) and POMMELS.has(data[2])):
		return false
	if data[3].size() != int(GRIPS[data[1]]["slots"]) + int(BLADES[data[0]]["slots"]):
		return false
	for id in data[3]:
		if not (id is String) or (id != "" and not FITTINGS.has(id)):
			return false
	return true


## Sets the whole sword at once. Doesn't announce it: emit `changed` yourself.
func set_data(data: Array) -> void:
	blade = data[0]
	grip = data[1]
	pommel = data[2]
	line = (data[3] as Array).duplicate()


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
##            mirror (true if it's a Mirror's copy), button (active runes: 0, 1 or 2)}
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
	var buttons: Array = []   # the active runes' ids, in button order
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
		if f["trigger"] == "active" and not (id in buttons) and buttons.size() >= ACTIVE_BUTTONS:
			# A fourth kind of active rune has no button left, unless an Every Hit
			# band below makes it fire by itself.
			var automatic := false
			for s in relay_bands + pending:
				automatic = automatic or str(line[s]) == "every_hit"
			if not automatic:
				info[i] = {"unused": true, "why": "Only three active runes work on one sword."}
				for s in pending:
					info[s] = {"unused": true, "why": "The rune above it has no button."}
				if relay_slot >= 0:
					info[relay_slot] = {"unused": true, "relay": true, "why": "The rune above it has no button."}
					relay_slot = -1
					relay_bands = []
				pending = []
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
		if e["trigger"] == "active":
			if not (id in buttons):
				buttons.append(id)
			e["button"] = buttons.find(id)
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
				if e["id"] == "shards" and not e.get("splinter", false):
					e["splinter"] = true  # each shard splits in two as it jumps, at half strength
					e["power"] = float(e["power"]) * EVERY_HIT_POWER
					return ""
				return "%s already works on every hit." % FITTINGS[e["id"]]["name"]
			e["trigger"] = "hit"  # an active rune stops needing its button
			e["power"] = float(e["power"]) * EVERY_HIT_POWER
		"saved_up":
			if int(e["every"]) > 1:
				return "Saved Up doesn't stack (max)."
			# A passive rune fires on every third trigger. An active rune takes three
			# times as long to recharge instead (see abilities()).
			e["every"] = SAVED_UP_EVERY
			e["power"] = float(e["power"]) * SAVED_UP_POWER
		"on_dodge":
			if "dodge" in e["also"]:
				return "On Dodge doesn't stack (max)."
			e["also"].append("dodge")
	return ""


const WHEN := {"finisher": "Your finisher", "hit": "Every hit", "kill": "Every kill"}
const WHEN_NTH := {"finisher": "Every third finisher", "hit": "Every third hit", "kill": "Every third kill"}


## One plain sentence per rune, e.g. "Your finisher sends two shockwaves forward."
## keys: what this player's ability buttons are called (ABILITY_KEYS), for
## active runes: "Press Q: pulls enemies in."
static func sentence(e: Dictionary, keys: Array = ABILITY_KEYS["kbm"]) -> String:
	var n: int = e["count"]
	var big: bool = float(e["size"]) > 1.0
	var times := "" if n == 1 else (" twice" if n == 2 else " %d times" % n)
	var trig: String = e["trigger"]
	if trig == "active":
		return _active_sentence(e, keys)
	var when: String = (WHEN_NTH if int(e.get("every", 1)) > 1 else WHEN).get(trig, "It")
	var what := ""
	match str(e["id"]):
		"shockwave":
			what = "sends %s forward" % (("a big shockwave" if big else "a shockwave") if n == 1 else ("%s %sshockwaves" % [_num(n), "big " if big else ""]))
		"hook":
			what = "pulls enemies in%s%s" % [" from further away" if big else "", times]
		"shards":
			what = "sends shards jumping to the closest enemies%s%s%s" % [", splitting in two at each jump" if e.get("splinter", false) else "", times, ", from further away" if big else ""]
		"weak_point":
			# Twice: two marks. Wider: a bigger spot on big enemies.
			what = "marks %s%s, and your next hit on a mark is a %scrit" % ["the enemy it hits" if n == 1 else "up to %s enemies" % _num(n),
				(" with a bigger spot" if n == 1 else " with bigger spots") if big else "", "big " if float(e.get("power", 1.0)) >= 1.0 else ""]
		"whirlwind":
			what = "spins %s, cutting everything around you%s" % ["a full circle" if n == 1 else _num(n) + " times round", ", in a bigger circle" if big else ""]
		"leap":
			what = "leaps you to the nearest enemy%s%s" % ["" if n == 1 else (", then the next one" if n == 2 else ", then %s more" % _num(n - 1)), ", from further away" if big else ""]
		_:
			return ""
	var power := float(e.get("power", 1.0))
	if str(e["id"]) == "weak_point":
		# Its strength is the size of the crit, so say that instead.
		if power < 1.0:
			what = what.replace("a crit", "a smaller crit")
		elif power >= 3.0:
			what = what.replace("a big crit", "a huge crit")
	elif power < 1.0:
		what += ", at half strength"
	elif power >= 3.0:
		what += ", three times as strong"
	elif power > 1.0:
		what += ", %sx as strong" % str(snappedf(power, 0.1))
	var s := "%s %s." % [when, what]
	if "dodge" in e.get("also", []):
		s += " Dodging does it too."
	return s


## The sentence for a rune on an ability button: what to press, what it does, and
## how long it takes to come back.
static func _active_sentence(e: Dictionary, keys: Array) -> String:
	var f: Dictionary = FITTINGS[e["id"]]
	var n: int = e["count"]
	var big: bool = float(e["size"]) > 1.0
	var key: String = str(keys[clampi(int(e.get("button", 0)), 0, keys.size() - 1)])
	var what := ""
	match str(e["id"]):
		"hook":
			what = "pulls enemies in%s%s" % [" from further away" if big else "", "" if n == 1 else (" twice" if n == 2 else " %d times" % n)]
		"whirlwind":
			what = "spins for up to %s turns, cutting everything around you%s" % [_num(int(f["turns"]) * n), ", in a bigger circle" if big else ""]
		"leap":
			what = "leaps you to the nearest enemy%s and strikes it from your blade's reach%s" % [" from further away" if big else "",
				"" if n == 1 else (", then the next one" if n == 2 else ", then %s more" % _num(n - 1))]
		_:
			return ""
	var slow := int(e.get("every", 1))
	if float(e.get("power", 1.0)) >= 3.0:
		what += ", three times as strong"
	var s := "%s %s: %s. Recharges in %d seconds." % ["Hold" if f["use"] == "hold" else "Press", key, what, roundi(float(f["recharge"]) * slow)]
	if "dodge" in e.get("also", []):
		s += " Every third dodge does it too." if slow > 1 else " Dodging does it too."
	return s


static func _num(n: int) -> String:
	return ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"][clampi(n, 0, 9)]


## The sword's active runes, one entry per ability button, in button order:
##   {id, use, effects (indexes into `effects`), recharge (seconds), turns, turn, slot}
## Twice gives a hold rune that many times the turns; a press rune fires that
## many times. Saved Up makes the recharge three times as long.
static func abilities(effects: Array) -> Array:
	var out: Array = []
	for i in effects.size():
		var e: Dictionary = effects[i]
		if e["trigger"] != "active":
			continue
		var f: Dictionary = FITTINGS[e["id"]]
		var b := int(e["button"])
		var recharge := float(f["recharge"]) * float(e.get("every", 1))
		var turns := int(f.get("turns", 1)) * int(e["count"])
		while out.size() <= b:
			out.append({})
		if out[b].is_empty():
			out[b] = {"id": e["id"], "use": f["use"], "effects": [i], "recharge": recharge,
				"turns": turns, "turn": float(f.get("turn", 0.0)), "slot": int(e["slot"])}
		else:
			out[b]["effects"].append(i)
			out[b]["recharge"] = maxf(float(out[b]["recharge"]), recharge)
			out[b]["turns"] = maxi(int(out[b]["turns"]), turns)
	return out


## Everything the player needs, as one plain dictionary.
func compute() -> Dictionary:
	var b := blade_info(blade)
	var g: Dictionary = GRIPS[grip]
	var steps: Array = []
	for m in b["chain"]:
		steps.append({"move": m, "name": MOVE_NAMES.get(m, m), "from": b["name"]})
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
		"shape": b["shape"],
		"grip": grip,
		"line": line.duplicate(),
		"grip_slots": grip_slots(),
		"effects": r["effects"],
		"abilities": abilities(r["effects"]),
		"slot_info": r["slots"],
		"steps": steps,
		"damage": float(b["damage"]),
		"pommel": pommel,
		"speed": float(b["speed"]) * (1.0 + float(POMMELS[pommel].get("speed", 0.0))),
		"reach": float(b["reach"]),
		"swing_move": float(b["swing_move"]),
		"crit": BASE_CRIT + float(b["crit"]) + float(POMMELS[pommel].get("crit", 0.0)),
		"crit_damage": BASE_CRIT_DAMAGE + float(POMMELS[pommel].get("crit_damage", 0.0)),
		"area": 0.0,
		"move_speed": 0.0,
		"elements": [element] if element != "" else [],
		"combos": [],
		"hit_color": hit_color,
	}


const BASE_CRIT := 0.07
const BASE_CRIT_DAMAGE := 1.6

const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.5, 0.2),
	"water": Color(0.35, 0.65, 1.0),
	"lightning": Color(1.0, 0.95, 0.35),
	"steam": Color(0.85, 0.9, 0.95),
	"electrified": Color(0.6, 0.85, 1.0),
}
