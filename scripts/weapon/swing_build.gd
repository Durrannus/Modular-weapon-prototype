extends RefCounted
## The swing path (3 November design). A sword is a blade plus a grip. A bow
## (14 November) is put together the same way: see "Bows" below.
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
		"desc": "Thrust, thrust, lunge: long, straight reach, and each thrust goes through to a second enemy."},
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
	"great_sweep": "sweep", "great_back": "backswing", "slam": "slam",
	"quick_shot": "quick shot", "heavy_shot": "heavy shot", "long_shot": "long shot"}

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


# --- Bows -----------------------------------------------------------------------
# Game Bible, the weapons table; built 14 November. A bow is four parts:
#   limbs   the chain you always shoot and how it feels (draw speed, range), and
#           slots by tier, like a blade
#   grip    slots
#   string  numbers only, like a sword's pommel
#   arrows  the damage (their metal). Once owned you never run out.
# The line reads the way a sword's does: grip slots first (they sit under the
# hand), then the limb's (above it, on the upper limb).
# In this file the limbs live where a sword's blade does (`blade`) and the string
# where its pommel does (`pommel`), so whatever reads a sword can read a bow.

## Limb shapes. The numbers are multiples of the shortbow with the same arrows,
## and damage x speed stays within a tenth of it, as for blade shapes.
##   range  how far an arrow flies, as a multiple of BOW_RANGE
const BOW_SHAPES := {
	"shortbow": {"name": "Shortbow", "chain": ["quick_shot", "quick_shot", "heavy_shot"],
		"damage": 1.0, "speed": 1.0, "range": 1.0,
		"desc": "Quick shot, quick shot, heavy shot: the balanced bow."},
	# Three heavy shots are 4.5 hits in the time a shortbow makes 3.5 (1.35 s
	# against 1.17), so each arrow is a tenth lighter and the two bows do the same
	# a second. What the longbow buys is reach and a shove on every shot; what it
	# costs is fewer arrows and slower feet.
	"longbow": {"name": "Longbow", "chain": ["long_shot", "long_shot", "long_shot"],
		"damage": 0.9, "speed": 1.0, "range": 1.35, "swing_move": 0.7,
		"desc": "Three slow, heavy shots that fly a third further. You walk slower while shooting."},
}
## An arrow is worth this much of a broadsword's hit in the same metal. Shooting
## from range is safer than standing in reach, and Darren doesn't want everyone
## fighting from range (10 November, about Shockwave), so the bow does less a
## second than the sword, to one enemy at a time.
const BOW_DAMAGE := 0.75
const BOW_RANGE := 520.0       # how far a shortbow's arrow flies (a sword reaches 91)
const BOW_FLIGHT := 1300.0     # how fast an arrow flies, a second
const BOW_MOVE := 0.8          # walking speed while shooting ("slightly slowed")

const LIMBS := {
	"wooden_shortbow": {"name": "Wooden Shortbow", "shape": "shortbow", "slots": 0,
		"desc": "Quick shot, quick shot, heavy shot: a training bow."},
	"tin_shortbow": {"name": "Tin Shortbow", "shape": "shortbow", "slots": 1,
		"desc": "Quick shot, quick shot, heavy shot: wood, shod with tin."},
	"iron_shortbow": {"name": "Iron Shortbow", "shape": "shortbow", "slots": 2},
	"iron_longbow": {"name": "Iron Longbow", "shape": "longbow", "slots": 2},
}
const LIMB_ORDER := ["iron_shortbow", "iron_longbow"]

const BOW_GRIPS := {
	"wooden_bow_grip": {"name": "Wooden Bow Grip", "slots": 1, "desc": "One slot."},
	"tin_bow_grip": {"name": "Tin Bow Grip", "slots": 1, "desc": "One slot."},
	"wrapped_bow_grip": {"name": "Wrapped Bow Grip", "slots": 2, "desc": "Two slots."},
	"horn_bow_grip": {"name": "Horn Bow Grip", "slots": 3, "desc": "Three slots."},
}
const BOW_GRIP_ORDER := ["wooden_bow_grip", "wrapped_bow_grip", "horn_bow_grip"]

## Strings: no slots, numbers only. The same four fixed test rolls as the pommels.
const STRINGS := {
	"plain_string": {"name": "Plain String", "desc": "No bonus.", "color": Color("#dcd6b0")},
	"keen_string": {"name": "Keen String", "crit": 0.08, "desc": "+8% crit chance.", "color": Color("#78c0cc")},
	"heavy_string": {"name": "Heavy String", "crit_damage": 0.4, "desc": "+40% crit damage.", "color": Color("#cf8a48")},
	"light_string": {"name": "Light String", "speed": 0.1, "desc": "+10% draw speed.", "color": Color("#f6faf0")},
}
const STRING_ORDER := ["plain_string", "keen_string", "heavy_string", "light_string"]

## Arrows: the bow's damage. The first kinds are the three metals and nothing else.
const ARROWS := {
	"wooden_arrows": {"name": "Wooden Arrows", "metal": "wood", "desc": "Sharpened wood: the lightest hit. Arrows never run out."},
	"tin_arrows": {"name": "Tin Arrows", "metal": "tin", "desc": "Tin heads: a harder hit. Arrows never run out."},
	"iron_arrows": {"name": "Iron Arrows", "metal": "iron", "desc": "Iron heads: the hardest hit so far. Arrows never run out."},
}
const ARROW_ORDER := ["wooden_arrows", "tin_arrows", "iron_arrows"]

## What everyone starts with, and the arena's test bow (the iron sword's match).
const STARTERS := {
	"sword": ["wooden_blade", "wooden_grip", "plain_pommel", [""]],
	"bow": ["wooden_shortbow", "wooden_bow_grip", "plain_string", [""], "wooden_arrows"],
}
const TEST_BOW := ["iron_shortbow", "wrapped_bow_grip", "plain_string", ["volley", "snipe", "arrow_rain", "ricochet"], "iron_arrows"]


## Which weapon a blade or a pair of limbs makes: "sword" or "bow".
static func weapon_of(head: String) -> String:
	return "bow" if LIMBS.has(head) else "sword"


## A sword's blade or a bow's limbs: the part that sets the chain.
static func head_part(id: String) -> Dictionary:
	return LIMBS[id] if LIMBS.has(id) else BLADES[id]


## A grip of either weapon.
static func grip_part(id: String) -> Dictionary:
	return BOW_GRIPS[id] if BOW_GRIPS.has(id) else GRIPS[id]


## A sword's pommel or a bow's string: the part that is numbers only.
static func butt_part(id: String) -> Dictionary:
	return STRINGS[id] if STRINGS.has(id) else POMMELS[id]


## Everything about a bow's limbs in one place, like blade_info. `arrows` gives
## the damage.
static func limb_info(id: String, arrows: String) -> Dictionary:
	var l: Dictionary = LIMBS[id]
	var s: Dictionary = BOW_SHAPES[l["shape"]]
	var metal: String = ARROWS[arrows]["metal"] if ARROWS.has(arrows) else "wood"
	return {
		"name": l["name"], "shape": l["shape"], "shape_name": s["name"], "metal": metal,
		"slots": int(l["slots"]), "element": "",
		"chain": s["chain"],
		"damage": float(METALS[metal]) * BOW_DAMAGE * float(s["damage"]),
		"speed": float(s["speed"]),
		"reach": 1.0,
		"range": BOW_RANGE * float(s["range"]),
		"flight": BOW_FLIGHT * float(s.get("flight", 1.0)),
		"crit": float(s.get("crit", 0.0)),
		"swing_move": float(s.get("swing_move", BOW_MOVE)),
		"desc": str(l.get("desc", s["desc"])),
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
	"shockwave": {"kind": "rune", "weapon": "sword", "name": "Shockwave", "trigger": "finisher", "color": Color("#ffc850"),
		"desc": "Your finisher sends a wave forward."},
	# Hook left the sword for the hammer (Darren, 11 November afternoon). It waits
	# here, out of the forge, until the hammer is built: its rules and effects stay.
	"hook": {"kind": "rune", "weapon": "sword", "name": "Hook", "trigger": "active", "use": "press", "recharge": 4.0, "color": Color("#ff9c32"), "parked": true,
		"desc": "Press its button to yank nearby enemies in."},
	# Shards replaced Cleave (Darren, 6 November).
	"shards": {"kind": "rune", "weapon": "sword", "name": "Shards", "trigger": "hit", "color": Color("#d0dcd8"),
		"desc": "Every hit sends shards jumping to the nearest enemies."},
	# Weak Point (Darren, 11 November): the sword's single-target passive. The finisher
	# marks the enemy it hit; the next sword hit on the mark is a big crit. Small
	# enemies glow all over. Big ones get a spot on one side that you have to reach.
	"weak_point": {"kind": "rune", "weapon": "sword", "name": "Weak Point", "trigger": "finisher", "color": Color("#b8f4ff"),
		"desc": "Your finisher marks an enemy, and your next hit on the mark is a big crit."},
	"whirlwind": {"kind": "rune", "weapon": "sword", "name": "Whirlwind", "trigger": "active", "use": "hold", "recharge": 5.0, "turns": 3, "turn": 0.28, "color": Color("#f078b4"),
		"desc": "Hold its button to spin and cut everything around you."},
	# Leap is active since 11 November (it was "attack straight after a dodge").
	"leap": {"kind": "rune", "weapon": "sword", "name": "Leap", "trigger": "active", "use": "press", "recharge": 3.0, "color": Color("#f0c070"),
		"desc": "Press its button to leap at the nearest enemy and strike it."},
	# Ghostwield (Darren, 11 November afternoon): the sword's third active rune. A
	# see-through copy of your sword appears in your other hand and copies every
	# swing a moment later from the other side, at half strength, for `time`
	# seconds. Its hits set your passive runes off again as ghosted effects.
	"ghostwield": {"kind": "rune", "weapon": "sword", "name": "Ghostwield", "trigger": "active", "use": "press", "recharge": 45.0, "time": 15.0, "color": Color("#a8b4ff"),
		"desc": "Press its button: a ghost of your sword copies every swing for a while, at half strength."},
	# The bow's own runes (14 November). Steady Aim, Volley, Snipe and Arrow Rain are
	# Darren's (11 November); Pierce and Ricochet were only names, so what they do
	# is a first design. Pierce and Steady Aim don't "fire": Pierce changes the
	# arrow as it leaves the bow, and Steady Aim (trigger "still") builds while you
	# stand and shoot. See player.gd, "The bow's runes".
	"pierce": {"kind": "rune", "weapon": "bow", "name": "Pierce", "trigger": "finisher", "color": Color("#f4f0a8"),
		"desc": "Your finisher's arrow goes on through the enemy it hits."},
	"ricochet": {"kind": "rune", "weapon": "bow", "name": "Ricochet", "trigger": "hit", "color": Color("#40d8c8"),
		"desc": "An arrow that hits jumps on to the nearest other enemy, for half its damage."},
	"steady_aim": {"kind": "rune", "weapon": "bow", "name": "Steady Aim", "trigger": "still", "color": Color("#b8e068"),
		"desc": "Stand still while you shoot and you shoot faster and faster. Moving resets it."},
	"volley": {"kind": "rune", "weapon": "bow", "name": "Volley", "trigger": "active", "use": "press", "recharge": 4.0, "color": Color("#ff8c5a"),
		"desc": "Press its button to loose three arrows in a spread. Up close all three hit."},
	# "charge": hold the button to draw, let go to shoot.
	"snipe": {"kind": "rune", "weapon": "bow", "name": "Snipe", "trigger": "active", "use": "charge", "recharge": 6.0, "color": Color("#6aa0ff"),
		"desc": "Hold its button and let go as the ring closes: a heavy shot that does more the farther it flies."},
	"arrow_rain": {"kind": "rune", "weapon": "bow", "name": "Arrow Rain", "trigger": "active", "use": "press", "recharge": 8.0, "time": 3.0, "color": Color("#c090ff"),
		"desc": "Press its button to mark the ground where you aim. Arrows pour down on it."},
	"twice": {"kind": "band", "name": "Twice", "color": Color("#86d4a4"),
		"desc": "The rune above happens twice."},
	"wider": {"kind": "band", "name": "Wider", "color": Color("#86d4a4"),
		"desc": "The rune above is bigger."},
	# On an active rune it is a different rule (Darren, 11 November afternoon): the
	# rune stays on its button, and every swing you land brings it back sooner.
	"every_hit": {"kind": "band", "name": "Every Hit", "color": Color("#86d4a4"),
		"desc": "A passive rune above fires on every hit at half strength. Your hits recharge an active one."},
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
## Whether this fitting can go on that weapon ("sword" or "bow"). Every weapon has
## its own runes (Game Bible: three passive and three active each); bands and
## rule-benders fit them all. (Hook is the hammer's: it waits with the sword's
## until there is a hammer.)
static func fits(id: String, kind: String) -> bool:
	if not FITTINGS.has(id):
		return false
	var w: String = FITTINGS[id].get("weapon", "")
	return w == "" or w == kind


const FITTING_ORDER := ["shockwave", "shards", "weak_point", "pierce", "ricochet", "steady_aim",
	"whirlwind", "hook", "leap", "ghostwield", "volley", "snipe", "arrow_rain",
	"twice", "wider", "every_hit", "saved_up", "on_dodge", "mirror", "relay"]
const EVERY_HIT_POWER := 0.5
## Every Hit on an active rune: seconds off its recharge for each swing that lands.
const EVERY_HIT_REFUND := 0.5
const SAVED_UP_EVERY := 3
const SAVED_UP_POWER := 3.0
## Ghostwield: what a ghost swing does, as a share of the swing it copies. Saved Up
## brings it to a full copy (and makes the recharge three times as long).
const GHOST_POWER := 0.5


## How strong the ghost's copies are for a Ghostwield rune of this power.
static func ghost_power(power: float) -> float:
	return minf(GHOST_POWER * power, 1.0)


## How long the ghost sword stays. Wider is the band for it: one Wider is a third
## longer (20 seconds for 15).
static func ghost_time(size: float) -> float:
	return float(FITTINGS["ghostwield"]["time"]) * (1.0 + (size - 1.0) / 1.8)

## The bow's runes, in numbers. Damage is a share of one arrow from the same bow.
const PIERCE_MAX := 6            # the most enemies one arrow goes on through
const PIERCE_WIDTH := 14.0       # Wider: how much thicker the arrow's path is, at twice the size
const RICOCHET_DAMAGE := 0.5     # a jump, as a share of the arrow that hit
const RICOCHET_RANGE := 150.0    # how far away the next enemy can be
const STEADY_RATE := 0.1         # attack speed gained each second you stand and shoot
const STEADY_CAP := 0.5          # the most it gives (Wider: 0.8)
const STEADY_HIT := 0.05         # Every Hit: what each arrow that lands adds
const VOLLEY_SPREAD := 0.2       # radians between one arrow of the fan and the next
const VOLLEY_DAMAGE := 1.0       # each arrow
const SNIPE_CHARGE := 0.7        # seconds of holding until the ring closes
const SNIPE_SWEET := 0.25        # how long after that the shot is a perfect one
const SNIPE_HOLD := 2.5          # held this long, it goes by itself
const SNIPE_NEAR := 2.0          # its damage at no distance, in arrows...
const SNIPE_FAR := 6.0           # ...and after SNIPE_DISTANCE or more
const SNIPE_DISTANCE := 480.0
const SNIPE_RANGE := 1.5         # how much further than an arrow it flies
const SNIPE_PERFECT := 1.5       # let go in the sweet spot
const SNIPE_EARLY := 0.5         # let go before the ring closed
const SNIPE_MOVE := 0.5          # walking speed while drawing it
const RAIN_DAMAGE := 0.35        # each time the rain hits an enemy standing in it
const RAIN_TICK := 0.3           # how often that is
const RAIN_RADIUS := Vector2(112, 80)   # the marked ground (an oval: the floor is seen from above)
const RAIN_REACH := 420.0        # how far away you can mark
const RAIN_PIN := 0.4            # Saved Up: each hit holds an enemy this long
const DODGE_SHARE := 0.5         # On Dodge on Volley and Snipe: the dodge's shot, as a share of the button's
const RAIN_DODGE_TIME := 1.0     # On Dodge on Arrow Rain: the small shower's length...
const RAIN_DODGE_SIZE := 0.6     # ...and size


## How many enemies a Pierce rune's arrow goes on through. Saved Up is three
## times as many (its strength is the number).
static func pierce_count(e: Dictionary) -> int:
	return mini(int(e["count"]) * (3 if float(e.get("power", 1.0)) >= 3.0 else 1), PIERCE_MAX)


## How fast Steady Aim builds, as attack speed a second. Twice doubles it; Saved
## Up builds a third as fast (and then every third arrow hits three times as hard).
static func steady_rate(e: Dictionary) -> float:
	return STEADY_RATE * float(e["count"]) / float(maxi(int(e.get("every", 1)), 1))


## The most Steady Aim gives. Wider raises it (one Wider: +80%).
static func steady_cap(e: Dictionary) -> float:
	return STEADY_CAP * float(e["size"])


## How many arrows a Volley looses: three, and two more for each step of Wider.
static func volley_arrows(size: float) -> int:
	return 7 if size >= 1.8 else (5 if size >= 1.25 else 3)


## How much bigger Arrow Rain's ground is across for this size (Wider).
static func rain_scale(size: float) -> float:
	return 1.0 + (size - 1.0) * 0.6


## Active runes take the ability buttons in the order they sit on the sword, grip
## to tip. Two of the same rune share a button. Up to three active runes work on
## one sword (Darren, 11 November; it was two). What the buttons are called and
## which prompt pictures show them (art/cave/ui/prompt_<name>.png). The third
## button's keys (R, B) are a first guess, to settle in testing.
const ACTIVE_BUTTONS := 3
const ABILITY_KEYS := {"kbm": ["right mouse", "Q", "R"], "pad": ["RB", "LB", "B"]}
const ABILITY_PROMPTS := {"kbm": ["mouse_right", "q", "r"], "pad": ["pad_rb", "pad_lb", "pad_b"]}

## The test swords from the 3 November notes, bottom to top. (Leap stands where
## Hook did until 11 November, when Hook left the sword for the hammer.)
const TEST_SWORDS := {
	"A": {"blade": "iron_broadsword", "grip": "wrapped_grip", "line": ["twice", "shockwave", "wider", "leap"]},
	"B": {"blade": "iron_broadsword", "grip": "wrapped_grip", "line": ["shockwave", "twice", "wider", "leap"]},
	# 10 November: two active runes and a passive one. Whirlwind sits lowest, so it
	# gets the first ability button (right mouse or RB), which is the easy one to hold.
	"C": {"blade": "iron_broadsword", "grip": "wrapped_grip", "line": ["whirlwind", "leap", "twice", "shockwave"]},
	# 11 November: the sword's three active runes, one on each button, and a passive.
	"D": {"blade": "iron_broadsword", "grip": "wrapped_grip", "line": ["whirlwind", "leap", "ghostwield", "weak_point"]},
}

var blade := "wooden_blade"   # the sword everyone starts with: no slots on the blade, one on the grip
var grip := "wooden_grip"
var pommel := "plain_pommel"
## Slot contents bottom to top: grip slots first, then blade slots. "" is empty.
var line: Array = [""]
## A bow keeps its limbs in `blade` and its string in `pommel` (see "Bows"), and
## has one part more: its arrows ("" on a sword).
var arrows := ""
## The weapons that aren't in the hand, as get_data() values: {"sword": ..} or
## {"bow": ..}. A player has one of each and swaps between them (weapon_of).
var stowed := {}


## "sword" or "bow": the weapon in the hand.
func weapon() -> String:
	return weapon_of(blade)


## Puts the other weapon in the hand; the one that was there waits in `stowed`.
## A weapon that was never held starts as the plain wooden one.
func take(kind: String) -> void:
	if kind == weapon() or not STARTERS.has(kind):
		return
	var next: Array = stowed.get(kind, STARTERS[kind])
	set_data(next)
	changed.emit()


func slot_count() -> int:
	return int(grip_part(grip)["slots"]) + int(head_part(blade)["slots"])


func grip_slots() -> int:
	return int(grip_part(grip)["slots"])


## Keeps the line the right length after a grip or blade change.
## Grip slots keep their fittings, blade slots keep theirs, extras drop off the top.
func _refit(old_grip_slots: int) -> void:
	var g: Array = line.slice(0, old_grip_slots)
	var b: Array = line.slice(old_grip_slots)
	var gs := grip_slots()
	var bs := int(head_part(blade)["slots"])
	g.resize(gs)
	b.resize(bs)
	line = []
	for x in g + b:
		line.append("" if x == null else x)


## The four setters take a part of the weapon in the hand; a part of the other
## weapon is ignored (a blade doesn't go on a bow).
func set_blade(id: String) -> void:
	if LIMBS.has(id) != (weapon() == "bow") or not (LIMBS.has(id) or BLADES.has(id)):
		return
	var old := grip_slots()
	blade = id
	_refit(old)
	changed.emit()


func set_grip(id: String) -> void:
	if BOW_GRIPS.has(id) != (weapon() == "bow") or not (BOW_GRIPS.has(id) or GRIPS.has(id)):
		return
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
	if STRINGS.has(id) != (weapon() == "bow") or not (STRINGS.has(id) or POMMELS.has(id)):
		return
	pommel = id
	changed.emit()


func set_arrows(id: String) -> void:
	if weapon() != "bow" or not ARROWS.has(id):
		return
	arrows = id
	changed.emit()


## The whole weapon as plain values, to send to the other computer online. A
## sword is [blade, grip, pommel, line]; a bow is [limbs, grip, string, line, arrows].
func get_data() -> Array:
	var out: Array = [blade, grip, pommel, line.duplicate()]
	if weapon() == "bow":
		out.append(arrows)
	return out


## True if `data` is a weapon get_data() could have made (every part exists,
## belongs to the same weapon, and the slots fit), so nothing odd can arrive from
## the other computer.
static func valid_data(data) -> bool:
	if not (data is Array) or data.size() < 4 or not (data[3] is Array):
		return false
	if not (data[0] is String and data[1] is String and data[2] is String):
		return false
	if LIMBS.has(data[0]):
		if data.size() != 5 or not (data[4] is String) or not ARROWS.has(data[4]):
			return false
		if not (BOW_GRIPS.has(data[1]) and STRINGS.has(data[2])):
			return false
	elif data.size() != 4 or not (BLADES.has(data[0]) and GRIPS.has(data[1]) and POMMELS.has(data[2])):
		return false
	if data[3].size() != int(grip_part(data[1])["slots"]) + int(head_part(data[0])["slots"]):
		return false
	for id in data[3]:
		if not (id is String) or (id != "" and not fits(id, weapon_of(data[0]))):
			return false
	return true


## Sets the whole weapon at once. Doesn't announce it: emit `changed` yourself.
## If it is the other weapon, the one in the hand is put away first, and its
## loadout presets with it: each weapon has its own three.
func set_data(data: Array) -> void:
	var kind := weapon_of(data[0])
	if kind != weapon():
		stowed[weapon()] = get_data()
		_presets_away[weapon()] = [preset, preset_data, preset_names]
		var mine: Array = _presets_away.get(kind, [0, [null, null, null], ["", "", ""]])
		_presets_away.erase(kind)
		preset = mine[0]
		preset_data = mine[1]
		preset_names = mine[2]
	stowed.erase(kind)
	blade = data[0]
	grip = data[1]
	pommel = data[2]
	line = (data[3] as Array).duplicate()
	arrows = data[4] if data.size() > 4 else ""


# --- Loadout presets ----------------------------------------------------------
# Game Bible, 11 November: three saved swords a player (A, B and C), which can be
# given names. The chosen one is always the sword in the hand, so every change to
# the sword is saved to it; the other two wait here as get_data() values. They
# are this player's own notes: nothing about them is sent to the other computer
# online (switching sends the new sword like any other change at the forge).
# A bow has three of its own (14 November): the presets you see are the ones of
# the weapon in your hand, and the other weapon's wait in `_presets_away`.

const PRESET_LETTERS := ["A", "B", "C"]
const PRESET_NAME_MAX := 12

var preset := 0                              # the chosen one
var preset_data: Array = [null, null, null]  # the saved swords (the chosen one's entry isn't used)
var preset_names: Array = ["", "", ""]
var _presets_away := {}                      # weapon -> [preset, preset_data, preset_names] of the one not in the hand


## What preset i holds: a get_data() value, or null if it has never been used.
func preset_sword(i: int):
	return get_data() if i == preset else preset_data[i]


## "Preset B: Bossing", or just "Preset B".
func preset_title(i: int) -> String:
	var n := str(preset_names[i])
	return "Preset %s" % PRESET_LETTERS[i] + ("" if n == "" else ": " + n)


## The parts of a saved sword that aren't in `owned` (null = the player owns everything).
static func parts_missing(data, owned) -> Array:
	var out: Array = []
	if data == null or owned == null:
		return out
	for id in [data[0], data[1], data[2]] + (data[3] as Array) + (data as Array).slice(4):
		if id != "" and not (id in owned) and not (id in out):
			out.append(id)
	return out


## Switches to preset i: one click at the forge. A preset that has never been used
## starts as a copy of the sword in the hand. Parts of the saved sword the player
## no longer owns are left off (`owned` is the list of part ids, null = everything)
## and returned.
func use_preset(i: int, owned = null) -> Array:
	if i == preset or i < 0 or i >= preset_data.size():
		return []
	preset_data[preset] = get_data()
	var data = preset_data[i]
	preset = i
	if data != null and weapon_of(data[0]) != weapon():
		data = null   # (can't happen: a weapon's presets only ever hold that weapon)
	var missing := parts_missing(data, owned)
	if data != null:
		var saved_grip_slots := int(grip_part(data[1])["slots"])
		if not (data[0] in missing):
			blade = data[0]
		if not (data[1] in missing):
			grip = data[1]
		if not (data[2] in missing):
			pommel = data[2]
		if data.size() > 4 and not (data[4] in missing):
			arrows = data[4]
		line = []
		for id in data[3]:
			line.append("" if id in missing else id)
		_refit(saved_grip_slots)
	changed.emit()
	return missing


## Loads one of the test swords. With a bow in the hand nothing happens: they are swords.
func load_test(key: String) -> void:
	var t: Dictionary = TEST_SWORDS[key]
	if weapon() != "sword":
		return
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
			# A fourth kind of active rune has no button left.
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
			if e["trigger"] == "active":
				# An active rune fires on its button, not on hits: each swing you land
				# takes a bit off its recharge instead (see abilities()).
				if float(e.get("refund", 0.0)) > 0.0:
					return "Every Hit doesn't stack (max)."
				e["refund"] = EVERY_HIT_REFUND
				return ""
			if e["id"] == "steady_aim":
				# Steady Aim doesn't fire: each arrow that lands adds to what it has built.
				if e.get("per_hit", false):
					return "Every Hit doesn't stack (max)."
				e["per_hit"] = true
				return ""
			if e["trigger"] == "hit":
				if e["id"] in ["shards", "ricochet"] and not e.get("splinter", false):
					e["splinter"] = true  # each shard (or arrow) splits in two as it jumps, at half strength
					e["power"] = float(e["power"]) * EVERY_HIT_POWER
					return ""
				return "%s already works on every hit." % FITTINGS[e["id"]]["name"]
			e["trigger"] = "hit"  # a finisher rune now fires on every hit
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
	if str(e["id"]) in ["pierce", "ricochet", "steady_aim"]:
		return _bow_sentence(e)
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


## The sentence for one of the bow's passive runes. They are about arrows, not
## swings, so they have their own words.
static func _bow_sentence(e: Dictionary) -> String:
	var n: int = e["count"]
	var big: bool = float(e["size"]) > 1.0
	var third := int(e.get("every", 1)) > 1
	var power := float(e.get("power", 1.0))
	var dodge: bool = "dodge" in e.get("also", [])
	match str(e["id"]):
		"pierce":
			# Every Hit: every arrow, and what is behind the first enemy takes half.
			var every_arrow: bool = e["trigger"] == "hit"
			var who := "Every arrow" if every_arrow else ("Every third finisher's arrow" if third else "Your finisher's arrow")
			var through := pierce_count(e)
			var s := "%s goes on through %s" % [who, "the enemy it hits" if through == 1 else "%s enemies" % _num(through)]
			if power < 1.0:
				s += ", hitting those behind at half strength"
			if big:
				s += ", on a wider path"
			s += "."
			if dodge:
				s += " The first arrow after %s does it too." % ("every third dodge" if third else "a dodge")
			return s
		"ricochet":
			var who := "Every third arrow that hits" if third else "An arrow that hits"
			var jumps := "jumps on to the nearest other enemy" if n == 1 else "jumps on %s, from enemy to enemy" % ("twice" if n == 2 else "%s times" % _num(n))
			var share := RICOCHET_DAMAGE * power
			var strength := "half its damage"
			if share < 0.3:
				strength = "a quarter of its damage"
			elif share > 0.75 and share < 1.0:
				strength = "three quarters of its damage"
			elif share >= 1.0:
				strength = "%s times its damage" % str(snappedf(share, 0.25)).trim_suffix(".0")
			var s := "%s %s%s%s, for %s." % [who, jumps, ", splitting in two" if e.get("splinter", false) else "", ", from further away" if big else "", strength]
			if dodge:
				s += " %s sends one from you too." % ("Every third dodge" if third else "A dodge")
			return s
		"steady_aim":
			var quick := "" if n == 1 else (" twice as quickly" if n == 2 else " %s times as quickly" % _num(n))
			if third:
				quick = " slowly" if n == 1 else ""
			var s := "Stand still while you shoot and you shoot faster and faster%s, up to +%d%%." % [quick, roundi(steady_cap(e) * 100.0)]
			if e.get("per_hit", false):
				s += " Each arrow that lands adds to it."
			if third:
				s += " Once it is full, every third arrow hits three times as hard."
			s += " Walking resets it, dodging doesn't." if dodge else " Moving resets it."
			return s
	return ""


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
		"ghostwield":
			# Its strength is how much of your swing the ghost copies, so say that.
			what = "a ghost of your sword copies every swing%s for %d seconds, at %s strength" % ["" if n == 1 else (" twice" if n == 2 else " %d times" % n),
				roundi(ghost_time(float(e["size"]))), "full" if ghost_power(float(e.get("power", 1.0))) >= 1.0 else "half"]
		"volley":
			what = "looses %s arrows in a spread%s" % [_num(volley_arrows(float(e["size"]))), "" if n == 1 else (", twice" if n == 2 else ", %s times" % _num(n))]
		"snipe":
			what = "%s that %s more the farther %s%s" % ["one heavy shot" if n == 1 else "%s heavy shots" % _num(n), "does" if n == 1 else "do",
				"it flies" if n == 1 else "they fly", ", with a longer moment for the perfect shot" if big else ""]
		"arrow_rain":
			what = "marks the ground where you aim, and arrows pour down on it for %d seconds%s%s" % [roundi(float(f["time"])),
				" over a bigger area" if big else "", "" if n == 1 else (", then again" if n == 2 else ", then %s more times" % _num(n - 1))]
		_:
			return ""
	var slow := int(e.get("every", 1))
	if float(e.get("power", 1.0)) >= 3.0 and e["id"] != "ghostwield":
		what += ", three times as strong"
		if e["id"] == "arrow_rain":
			what += " and pinning enemies"
	var how: String = {"hold": "Hold %s", "charge": "Hold %s, then let go"}.get(f["use"], "Press %s") % key
	var s := "%s: %s. Recharges in %d seconds." % [how, what, roundi(float(f["recharge"]) * slow)]
	if float(e.get("refund", 0.0)) > 0.0:
		s += " Each hit you land takes half a second off."
	if "dodge" in e.get("also", []):
		var dodging := "Every third dodge" if slow > 1 else "Dodging"
		if e["id"] == "ghostwield":
			s += " The ghost also cuts along %s." % ("every third dodge" if slow > 1 else "every dodge")
		elif e["id"] == "volley":
			s += " %s looses one too, at half strength." % dodging
		elif e["id"] == "snipe":
			s += " %s looses a quick, weak one too." % dodging
		elif e["id"] == "arrow_rain":
			s += " %s drops a small shower where you were." % dodging
		else:
			s += " Every third dodge does it too." if slow > 1 else " Dodging does it too."
	return s


static func _num(n: int) -> String:
	return ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"][clampi(n, 0, 9)]


## The sword's active runes, one entry per ability button, in button order:
##   {id, use, effects (indexes into `effects`), recharge (seconds), turns, turn, slot, refund}
## (Two Ghostwield runes are one ghost: see _summon_ghost in player.gd.)
## Twice gives a hold rune that many times the turns; a press rune fires that
## many times. Saved Up makes the recharge three times as long. Every Hit gives
## a refund: seconds off the recharge for each swing that lands.
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
				"turns": turns, "turn": float(f.get("turn", 0.0)), "slot": int(e["slot"]),
				"refund": float(e.get("refund", 0.0))}
		else:
			out[b]["effects"].append(i)
			out[b]["recharge"] = maxf(float(out[b]["recharge"]), recharge)
			out[b]["turns"] = maxi(int(out[b]["turns"]), turns)
			out[b]["refund"] = maxf(float(out[b]["refund"]), float(e.get("refund", 0.0)))
	return out


## Everything the player needs, as one plain dictionary. A bow gives the same
## things as a sword ("blade" is its limbs, "pommel" its string), and also
## "arrows", "range" and "flight".
func compute() -> Dictionary:
	var bow := weapon() == "bow"
	var b := limb_info(blade, arrows) if bow else blade_info(blade)
	var g: Dictionary = grip_part(grip)
	var butt: Dictionary = butt_part(pommel)
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
	var out := {
		"weapon": weapon(),
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
		"speed": float(b["speed"]) * (1.0 + float(butt.get("speed", 0.0))),
		"reach": float(b["reach"]),
		"swing_move": float(b["swing_move"]),
		"crit": BASE_CRIT + float(b["crit"]) + float(butt.get("crit", 0.0)),
		"crit_damage": BASE_CRIT_DAMAGE + float(butt.get("crit_damage", 0.0)),
		"area": 0.0,
		"move_speed": 0.0,
		"elements": [element] if element != "" else [],
		"combos": [],
		"hit_color": hit_color,
	}
	if bow:
		out["arrows"] = arrows
		out["range"] = float(b["range"])
		out["flight"] = float(b["flight"])
	return out


const BASE_CRIT := 0.07
const BASE_CRIT_DAMAGE := 1.6

const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.5, 0.2),
	"water": Color(0.35, 0.65, 1.0),
	"lightning": Color(1.0, 0.95, 0.35),
	"steam": Color(0.85, 0.9, 0.95),
	"electrified": Color(0.6, 0.85, 1.0),
}
