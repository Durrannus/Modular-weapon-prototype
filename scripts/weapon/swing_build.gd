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
static var SHAPES := {
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
static var SWING_MOVE := 0.9        # walking speed while swinging, unless the shape says otherwise

## What a move is called on screen.
const MOVE_NAMES := {"slash": "slash", "overhead": "overhead",
	"dagger_stab": "stab", "dagger_slash": "slash", "dagger_finish": "stab",
	"sabre_slash": "slash", "sabre_back": "backslash", "sabre_sweep": "sweep",
	"thrust": "thrust", "long_thrust": "lunge",
	"chop": "chop", "cleave": "cleave",
	"great_sweep": "sweep", "great_back": "backswing", "slam": "slam",
	"quick_shot": "quick shot", "heavy_shot": "heavy shot", "long_shot": "long shot", "charged_shot": "charged shot",
	"maul_swing": "swing", "maul_slam": "slam", "crush": "crushing blow",
	"bolt": "bolt", "burst": "burst", "spray": "spray", "orb": "orb"}

## A broadsword's damage in each metal. (Later metals each add about a quarter.)
static var METALS := {"wood": 5.0, "tin": 8.0, "iron": 11.0}

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
static var BOW_SHAPES := {
	# Three plain shots (Darren, 21 November: no heavy last arrow until later bow
	# parts). The longbow is the later part: its last arrow is a heavy one that
	# takes a moment to charge.
	"shortbow": {"name": "Shortbow", "chain": ["quick_shot", "quick_shot", "quick_shot"],
		"damage": 1.0, "speed": 1.0, "range": 1.0,
		"desc": "Three quick shots: the balanced bow."},
	# Shot, shot, charged shot: 3.75 hits in 1.44 s against a shortbow's 3 in
	# 1.18, so the two bows do the same a second. What the longbow buys is reach
	# and the heavy last arrow; what it costs is the charge and slower feet.
	"longbow": {"name": "Longbow", "chain": ["quick_shot", "quick_shot", "charged_shot"],
		"damage": 1.0, "speed": 1.0, "range": 1.35, "swing_move": 0.7,
		"desc": "Shot, shot, then a heavy shot that takes a moment to charge. Its arrows fly a third further. You walk slower while shooting."},
}
## An arrow is worth this much of a broadsword's hit in the same metal. Shooting
## from range is safer than standing in reach, and Darren doesn't want everyone
## fighting from range (10 November, about Shockwave), so the bow does less a
## second than the sword, to one enemy at a time.
## Seven tenths (it was four fifths until Darren played the bow, 21 November:
## "too much damage also as its ranged so too easy to stay safe"): a wooden arrow
## is 3.5, so a crawler takes four. It hits one enemy, a little harder than a
## staff's bolt (STAFF_DAMAGE), which hurts a very small area.
static var BOW_DAMAGE := 0.7
static var BOW_RANGE := 520.0       # how far a shortbow's arrow flies (a sword reaches 91)
## (1300 until 21 November: "the arrows fly too fast, its too easy to land shots".)
static var BOW_FLIGHT := 800.0      # how fast an arrow flies, a second
static var BOW_MOVE := 0.8          # walking speed while shooting ("slightly slowed")

const LIMBS := {
	"wooden_shortbow": {"name": "Wooden Shortbow", "shape": "shortbow", "slots": 0,
		"desc": "Three quick shots: a training bow."},
	"tin_shortbow": {"name": "Tin Shortbow", "shape": "shortbow", "slots": 1,
		"desc": "Three quick shots: wood, shod with tin."},
	"iron_shortbow": {"name": "Iron Shortbow", "shape": "shortbow", "slots": 2},
	"iron_longbow": {"name": "Iron Longbow", "shape": "longbow", "slots": 2},
}
const LIMB_ORDER := ["iron_shortbow", "iron_longbow"]

const BOW_GRIPS := {
	"wooden_bow_grip": {"name": "Wooden Bow Grip", "slots": 1, "desc": "Gives your spirit one seat."},
	"tin_bow_grip": {"name": "Tin Bow Grip", "slots": 1, "desc": "Gives your spirit one seat."},
	"wrapped_bow_grip": {"name": "Wrapped Bow Grip", "slots": 2, "desc": "Gives your spirit two seats."},
	"horn_bow_grip": {"name": "Horn Bow Grip", "slots": 3, "desc": "Gives your spirit three seats."},
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

# --- Hammers ---------------------------------------------------------------------
# Game Bible, the weapons table; built 15 November. "The close-range heavy hitter:
# big damage in a small area, so you must get in close." A hammer is put together
# exactly like a sword, and lives in the same three places:
#   head           (`blade`)   its weight sets the chain, the swing speed and the
#                              impact size; its metal is the damage; slots by tier
#   haft           (`grip`)    slots
#   counterweight  (`pommel`)  numbers only

## Head shapes. The numbers are multiples of the broadsword of the same metal.
## A hammer does about a quarter more a second than a sword to what it can reach
## (it reaches three quarters as far, swings very slowly and slows your feet), and
## it pins what it hits where a sword shoves it away.
## (Darren, 21 November: "the hammer needs alot slower attack speed ... slow but
## good damage". It was 1.7 hits at 0.7 of the sword's speed.)
##   impact  how big the patch of floor is that a slam hits (1.0 = HAMMER_IMPACT)
static var HAMMER_SHAPES := {
	"maul": {"name": "Maul", "chain": ["maul_swing", "maul_swing", "maul_slam"],
		"damage": 2.8, "speed": 0.45, "reach": 0.75, "impact": 1.0, "swing_move": 0.8,
		"desc": "Swing, swing, slam: short, very slow and very heavy, swung in both hands. The slam hits everything on a patch of floor."},
	# Three slams are 4.5 hits in the time a maul makes 3.5, so each is lighter and
	# the two heads do the same a second. Every blow lands on a patch of floor and
	# stuns for longer; you walk slower still.
	"warhammer": {"name": "Warhammer", "chain": ["crush", "crush", "crush"],
		"damage": 2.45, "speed": 0.45, "reach": 0.75, "impact": 0.85, "swing_move": 0.7,
		"desc": "Three slow crushing blows. Each one lands on a patch of floor and leaves enemies reeling."},
}
static var HAMMER_IMPACT := 38.0    # the radius of a maul's slam on the floor
static var HAMMER_MOVE := 0.8       # walking speed while swinging one

const HEADS := {
	"wooden_maul": {"name": "Wooden Maul", "shape": "maul", "metal": "wood", "slots": 0,
		"desc": "Swing, swing, slam: a training hammer."},
	"tin_maul": {"name": "Tin Maul", "shape": "maul", "metal": "tin", "slots": 1,
		"desc": "Swing, swing, slam: wood, capped with tin."},
	"iron_maul": {"name": "Iron Maul", "shape": "maul", "metal": "iron", "slots": 2},
	"iron_warhammer": {"name": "Iron Warhammer", "shape": "warhammer", "metal": "iron", "slots": 2},
}
const HEAD_ORDER := ["iron_maul", "iron_warhammer"]

const HAFTS := {
	"wooden_haft": {"name": "Wooden Haft", "slots": 1, "desc": "Gives your spirit one seat."},
	"tin_haft": {"name": "Tin Haft", "slots": 1, "desc": "Gives your spirit one seat."},
	"bound_haft": {"name": "Bound Haft", "slots": 2, "desc": "Gives your spirit two seats."},
	"studded_haft": {"name": "Studded Haft", "slots": 3, "desc": "Gives your spirit three seats."},
}
const HAFT_ORDER := ["wooden_haft", "bound_haft", "studded_haft"]

## Counterweights: no slots, numbers only. The same four fixed test rolls as the pommels.
const WEIGHTS := {
	"plain_weight": {"name": "Plain Counterweight", "desc": "No bonus.", "color": Color("#94a8b8")},
	"keen_weight": {"name": "Keen Counterweight", "crit": 0.08, "desc": "+8% crit chance.", "color": Color("#78c0cc")},
	"heavy_weight": {"name": "Heavy Counterweight", "crit_damage": 0.4, "desc": "+40% crit damage.", "color": Color("#cf8a48")},
	"light_weight": {"name": "Light Counterweight", "speed": 0.1, "desc": "+10% swing speed.", "color": Color("#e8e4bc")},
}
const WEIGHT_ORDER := ["plain_weight", "keen_weight", "heavy_weight", "light_weight"]


## Everything about a hammer's head in one place, like blade_info.
static func hammer_info(id: String) -> Dictionary:
	var h: Dictionary = HEADS[id]
	var s: Dictionary = HAMMER_SHAPES[h["shape"]]
	return {
		"name": h["name"], "shape": h["shape"], "shape_name": s["name"], "metal": h["metal"],
		"slots": int(h["slots"]), "element": "",
		"chain": s["chain"],
		"damage": float(METALS[h["metal"]]) * float(s["damage"]),
		"speed": float(s["speed"]),
		"reach": float(s["reach"]),
		"impact": HAMMER_IMPACT * float(s["impact"]),
		"crit": float(s.get("crit", 0.0)),
		"swing_move": float(s.get("swing_move", HAMMER_MOVE)),
		"desc": str(h.get("desc", s["desc"])),
	}


# --- Staffs ----------------------------------------------------------------------
# Game Bible, the weapons table and "Staff."; built 15 November. A staff is four
# parts, like a bow, and lives in the same places:
#   head     (`blade`)   the chain you always cast, the cast speed and the spell
#                        size; slots by tier
#   shaft    (`grip`)    slots
#   cap      (`pommel`)  numbers only
#   crystal  (`arrows`)  the damage (its tier)
# Mana is its resource (Darren, 21 November): the basic attack costs none, the
# runes do (an active rune a lot, a passive one a little each time it goes off),
# and it comes back slowly.

## Head shapes. Multiples of the apprentice head with the same crystal.
##   range  how far a bolt flies, as a multiple of STAFF_RANGE
##   size   spell size: how wide a bolt is and how far a burst reaches
static var STAFF_SHAPES := {
	# Three plain bolts (Darren, 21 November: "remove the heavy like the bow until
	# later parts"). The storm head is the later part: its last cast is the orb.
	"apprentice": {"name": "Apprentice", "chain": ["bolt", "bolt", "bolt"],
		"damage": 1.0, "speed": 1.0, "range": 1.0, "size": 1.0,
		"desc": "Three bolts: the balanced staff. A bolt also hurts whatever is right beside the enemy it hits."},
	# A spray is three sparks: all three only hit from close by. The orb is slow
	# and bursts wide.
	"storm": {"name": "Storm", "chain": ["spray", "spray", "orb"],
		"damage": 0.9, "speed": 1.0, "range": 0.7, "size": 1.25,
		"desc": "Spray, spray, orb: three sparks at a time for close work, then a big slow orb that bursts wide."},
}
## A bolt is worth this much of a broadsword's hit in the same tier: a little
## less than an arrow (BOW_DAMAGE), because it hurts a very small area where it
## lands and an arrow hits one enemy (Darren, 21 November). A wooden bolt is 3,
## so a crawler takes five.
static var STAFF_DAMAGE := 0.6
static var STAFF_RANGE := 400.0     # how far an apprentice's bolt flies (an arrow: 520)
## (760 until 21 November: "the staff progectiles are also too fast".)
static var STAFF_FLIGHT := 520.0    # how fast, a second (an arrow: 800)
## A bolt hurts every enemy whose edge is this near where it lands: only what
## stands right against the one it hit ("a small aoe ... but very small").
static var BOLT_SPLASH := 18.0
static var STAFF_MOVE := 0.8        # walking speed while casting
const BOLT_WIDTH := 7.0        # how close a bolt's line must pass to an enemy's edge (an arrow: 4)
static var BURST_RADIUS := 56.0     # how far from where it lands a burst hurts
const SPRAY_SPREAD := 0.17     # radians between one spark of a spray and the next
static var SPRAY_DAMAGE := 0.4      # each spark, in bolts
const ORB_FLIGHT := 0.4        # the orb's speed, as a share of a bolt's
static var ORB_RADIUS := 70.0        # how far from where it stops an orb hurts (a storm head's is a quarter wider)
## Mana. It comes back slowly (20 seconds from empty; it was 10 a second, and 45
## more after a moment's rest): accessories are to give recharge later, and the
## basic attack no longer costs any (Darren, 21 November).
static var MANA := 100.0
static var MANA_REGEN := 5.0        # a second, always (not while a Lance is held)
static var MANA_REST := 0.7         # this long without spending any...
static var MANA_REST_REGEN := 0.0   # ...and this much more comes back a second (nothing now)
## What each basic cast costs: nothing (the moves are in player.gd).
static var CAST_MANA := {"bolt": 0.0, "burst": 0.0, "spray": 0.0, "orb": 0.0}
## What the staff's runes cost. An active rune: each press (Lance: each pulse of
## the beam, four a second, so a full bar is about three seconds of it). A
## passive rune: each time it goes off, and without the mana it doesn't.
static var RUNE_MANA := {"nova": 25.0, "spectre": 40.0, "lance": 8.0}
static var PASSIVE_MANA := 5.0
static var MANA_WEAK := 0.5         # a cast with too little mana: its damage...
static var MANA_SLOW := 0.75        # ...and how fast you cast it

const STAFF_HEADS := {
	"wooden_apprentice": {"name": "Wooden Apprentice Head", "shape": "apprentice", "slots": 0,
		"desc": "Three bolts: a training staff."},
	"tin_apprentice": {"name": "Tin Apprentice Head", "shape": "apprentice", "slots": 1,
		"desc": "Three bolts: wood, shod with tin."},
	"iron_apprentice": {"name": "Iron Apprentice Head", "shape": "apprentice", "slots": 2},
	"iron_storm": {"name": "Iron Storm Head", "shape": "storm", "slots": 2},
}
const STAFF_HEAD_ORDER := ["iron_apprentice", "iron_storm"]

const SHAFTS := {
	"wooden_shaft": {"name": "Wooden Shaft", "slots": 1, "desc": "Gives your spirit one seat."},
	"tin_shaft": {"name": "Tin Shaft", "slots": 1, "desc": "Gives your spirit one seat."},
	"carved_shaft": {"name": "Carved Shaft", "slots": 2, "desc": "Gives your spirit two seats."},
	"twisted_shaft": {"name": "Twisted Shaft", "slots": 3, "desc": "Gives your spirit three seats."},
}
const SHAFT_ORDER := ["wooden_shaft", "carved_shaft", "twisted_shaft"]

## Caps: no slots, numbers only. The same four fixed test rolls as the pommels.
const CAPS := {
	"plain_cap": {"name": "Plain Cap", "desc": "No bonus.", "color": Color("#94a8b8")},
	"keen_cap": {"name": "Keen Cap", "crit": 0.08, "desc": "+8% crit chance.", "color": Color("#78c0cc")},
	"heavy_cap": {"name": "Heavy Cap", "crit_damage": 0.4, "desc": "+40% crit damage.", "color": Color("#cf8a48")},
	"light_cap": {"name": "Light Cap", "speed": 0.1, "desc": "+10% cast speed.", "color": Color("#e8e4bc")},
}
const CAP_ORDER := ["plain_cap", "keen_cap", "heavy_cap", "light_cap"]

## Crystals: the staff's damage. Three tiers that match wood, tin and iron, and
## each tints the staff's bolts: verdigris, pale sea light and forge light, out
## of the game's own palette (they were mint, electric blue and purple until
## Darren found the effects neon, 21 November).
const CRYSTALS := {
	"sea_glass": {"name": "Sea Glass", "metal": "wood", "color": Color("#86d4a4"),
		"desc": "A shard off the beach: the lightest hit."},
	"tin_crystal": {"name": "Tin-bound Crystal", "metal": "tin", "color": Color("#d0dcd8"),
		"desc": "A crystal in a tin setting: a harder hit."},
	"iron_crystal": {"name": "Iron-bound Crystal", "metal": "iron", "color": Color("#ffec98"),
		"desc": "A crystal in an iron setting: the hardest hit so far."},
}
const CRYSTAL_ORDER := ["sea_glass", "tin_crystal", "iron_crystal"]


## Everything about a staff's head in one place, like limb_info. `crystal` gives
## the damage.
static func staff_info(id: String, crystal: String) -> Dictionary:
	var h: Dictionary = STAFF_HEADS[id]
	var s: Dictionary = STAFF_SHAPES[h["shape"]]
	var metal: String = CRYSTALS[crystal]["metal"] if CRYSTALS.has(crystal) else "wood"
	return {
		"name": h["name"], "shape": h["shape"], "shape_name": s["name"], "metal": metal,
		"slots": int(h["slots"]), "element": "",
		"chain": s["chain"],
		"damage": float(METALS[metal]) * STAFF_DAMAGE * float(s["damage"]),
		"speed": float(s["speed"]),
		"reach": 1.0,
		"range": STAFF_RANGE * float(s["range"]),
		"flight": STAFF_FLIGHT,
		"size": float(s["size"]),
		"crit": float(s.get("crit", 0.0)),
		"swing_move": float(s.get("swing_move", STAFF_MOVE)),
		"desc": str(h.get("desc", s["desc"])),
	}


# --- The four weapons --------------------------------------------------------------

const WEAPON_ORDER := ["sword", "bow", "hammer", "staff"]
const WEAPON_NAMES := {"sword": "Sword", "bow": "Bow", "hammer": "Hammer", "staff": "Staff"}

## What everyone starts with, and the arena's test weapons (the iron sword's match).
const STARTERS := {
	"sword": ["wooden_blade", "wooden_grip", "plain_pommel", [""]],
	"bow": ["wooden_shortbow", "wooden_bow_grip", "plain_string", [""], "wooden_arrows"],
	"hammer": ["wooden_maul", "wooden_haft", "plain_weight", [""]],
	"staff": ["wooden_apprentice", "wooden_shaft", "plain_cap", [""], "sea_glass"],
}
const TEST_BOW := ["iron_shortbow", "wrapped_bow_grip", "plain_string", ["volley", "snipe", "arrow_rain", "ricochet"], "iron_arrows"]
## (The hammer's three active runes, one on each button, and Darren's own passive.)
const TEST_HAMMER := ["iron_maul", "bound_haft", "plain_weight", ["quake", "bulwark", "hook", "aftershock"]]
const TEST_STAFF := ["iron_apprentice", "carved_shaft", "plain_cap", ["nova", "lance", "spectre", "chain"], "iron_crystal"]


## The parts of one weapon, by the place they take: its heads (a sword's blades, a
## bow's limbs), its grips, its butts (pommels, strings, counterweights, caps) and,
## for a bow or a staff, what it shoots (arrows, crystals).
static func heads_of(kind: String) -> Dictionary:
	match kind:
		"bow": return LIMBS
		"hammer": return HEADS
		"staff": return STAFF_HEADS
	return BLADES


static func grips_of(kind: String) -> Dictionary:
	match kind:
		"bow": return BOW_GRIPS
		"hammer": return HAFTS
		"staff": return SHAFTS
	return GRIPS


static func butts_of(kind: String) -> Dictionary:
	match kind:
		"bow": return STRINGS
		"hammer": return WEIGHTS
		"staff": return CAPS
	return POMMELS


static func shots_of(kind: String) -> Dictionary:
	match kind:
		"bow": return ARROWS
		"staff": return CRYSTALS
	return {}


## A bow and a staff fight from range and have a fourth part (arrows, a crystal).
static func ranged(kind: String) -> bool:
	return kind == "bow" or kind == "staff"


## Which weapon a head makes: "sword", "bow", "hammer" or "staff".
static func weapon_of(head: String) -> String:
	for kind in WEAPON_ORDER:
		if heads_of(kind).has(head):
			return kind
	return "sword"


## A sword's blade, a bow's limbs, a hammer's or a staff's head: the part that
## sets the chain.
static func head_part(id: String) -> Dictionary:
	return heads_of(weapon_of(id))[id]


## A grip of any weapon.
static func grip_part(id: String) -> Dictionary:
	for kind in WEAPON_ORDER:
		if grips_of(kind).has(id):
			return grips_of(kind)[id]
	return GRIPS[id]


## A pommel, a string, a counterweight or a cap: the part that is numbers only.
static func butt_part(id: String) -> Dictionary:
	for kind in WEAPON_ORDER:
		if butts_of(kind).has(id):
			return butts_of(kind)[id]
	return POMMELS[id]


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
	"tin_grip": {"name": "Tin Grip", "slots": 1, "desc": "Gives your spirit one seat."},
	"wooden_grip": {"name": "Wooden Grip", "slots": 1, "desc": "Gives your spirit one seat."},
	"wrapped_grip": {"name": "Wrapped Grip", "slots": 2, "desc": "Gives your spirit two seats."},
	"long_grip": {"name": "Long Grip", "slots": 3, "desc": "Gives your spirit three seats."},
	"ringed_grip": {"name": "Ringed Grip", "slots": 2, "built_in": "wider",
		"desc": "Two seats, and the thread wound into it makes every rune a bit bigger."},
	"gilded_grip": {"name": "Gilded Grip", "slots": 2, "ruby_slot": 1,
		"desc": "Two seats. Its ruby seat doubles what is in it: a rune fires twice, a thread counts as two."},
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
## (A rune's "color" is what its label and its small flashes are written in. Each
## is out of the game's own ramps (ember, bronze, steel, stone, bone, verdigris):
## no rune has a loud colour of its own since 21 November, when Darren found the
## abilities "all like neon".)
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
static var FITTINGS := {
	"shockwave": {"kind": "rune", "weapon": "sword", "name": "Shockwave", "trigger": "finisher", "color": Color("#ffc850"),
		"desc": "Your finisher sends a wave forward."},
	# Hook left the sword for the hammer (Darren, 11 November afternoon) as an area
	# pull. Since 19 November it is single target: one chain drags one enemy to
	# you, and a boss is too heavy, so the chain pulls you towards it instead.
	"hook": {"kind": "rune", "weapon": "hammer", "name": "Hook", "trigger": "active", "use": "press", "recharge": 4.0, "color": Color("#ff9c32"),
		"desc": "Press its button: a chain drags the enemy you aim at to you. A boss drags you to it."},
	# Shards replaced Cleave (Darren, 6 November). Since 19 November they burst out
	# of the back of the enemy hit, in a cone, and fly straight.
	"shards": {"kind": "rune", "weapon": "sword", "name": "Shards", "trigger": "hit", "color": Color("#d0dcd8"),
		"desc": "Every hit sends shards out of the enemy's back, into whoever stands behind it."},
	# Weak Point (Darren, 11 November): the sword's single-target passive. The finisher
	# marks the enemy it hit; the next sword hit on the mark is a big crit. Small
	# enemies glow all over. Big ones get a spot on one side that you have to reach.
	"weak_point": {"kind": "rune", "weapon": "sword", "name": "Weak Point", "trigger": "finisher", "color": Color("#ffec98"),
		"desc": "Your finisher marks an enemy, and your next hit on the mark is a big crit."},
	"whirlwind": {"kind": "rune", "weapon": "sword", "name": "Whirlwind", "trigger": "active", "use": "hold", "recharge": 6.0, "turns": 6, "turn": 0.28, "color": Color("#d0dcd8"),
		"desc": "Hold its button to spin and cut everything around you."},
	# Leap is active since 11 November (it was "attack straight after a dodge").
	"leap": {"kind": "rune", "weapon": "sword", "name": "Leap", "trigger": "active", "use": "press", "recharge": 3.0, "color": Color("#f0c070"),
		"desc": "Press its button to leap at the nearest enemy and strike it."},
	# Ghostwield (Darren, 11 November afternoon): the sword's third active rune. A
	# see-through copy of your sword appears in your other hand and copies every
	# swing a moment later from the other side, at a third of its strength, for
	# `time` seconds. Its hits set your passive runes off again as ghosted effects.
	# (15 seconds at half strength until 21 November: "last too long and is quite strong".)
	"ghostwield": {"kind": "rune", "weapon": "sword", "name": "Ghostwield", "trigger": "active", "use": "press", "recharge": 45.0, "time": 8.0, "color": Color("#c8f0c4"),
		"desc": "Press its button: a ghost of your sword copies every swing for a while, at a third of its strength."},
	# The bow's own runes (14 November). Steady Aim, Volley, Snipe and Arrow Rain are
	# Darren's (11 November); Pierce and Ricochet were only names, so what they do
	# is a first design. Pierce and Steady Aim don't "fire": Pierce changes the
	# arrow as it leaves the bow, and Steady Aim (trigger "still") builds while you
	# stand and shoot. See player.gd, "The bow's runes".
	"pierce": {"kind": "rune", "weapon": "bow", "name": "Pierce", "trigger": "finisher", "color": Color("#ffec98"),
		"desc": "Your finisher's arrow goes on through the enemy it hits."},
	"ricochet": {"kind": "rune", "weapon": "bow", "name": "Ricochet", "trigger": "hit", "color": Color("#94a8b8"),
		"desc": "An arrow that hits jumps on to the nearest other enemy, for half its damage."},
	"steady_aim": {"kind": "rune", "weapon": "bow", "name": "Steady Aim", "trigger": "still", "color": Color("#c2c8a0"),
		"desc": "Stand still while you shoot and you shoot faster and faster. Moving resets it."},
	"volley": {"kind": "rune", "weapon": "bow", "name": "Volley", "trigger": "active", "use": "press", "recharge": 4.0, "color": Color("#ff9c32"),
		"desc": "Press its button to loose three arrows in a spread. Up close all three hit."},
	# "charge": hold the button to draw, let go to shoot.
	"snipe": {"kind": "rune", "weapon": "bow", "name": "Snipe", "trigger": "active", "use": "charge", "recharge": 6.0, "color": Color("#d0dcd8"),
		"desc": "Hold its button and let go as the ring closes: a heavy shot that does more the farther it flies."},
	"arrow_rain": {"kind": "rune", "weapon": "bow", "name": "Arrow Rain", "trigger": "active", "use": "press", "recharge": 8.0, "time": 3.0, "color": Color("#dcd6b0"),
		"desc": "Press its button to mark the ground where you aim. Arrows pour down on it."},
	# The hammer's own runes (15 November). The Game Bible names them with a line
	# each, and gives Aftershock its bands' rules (Darren, 11 November afternoon);
	# the numbers and the other bands' rules are a first design. Momentum and
	# Stagger don't "fire": Momentum builds on you and Stagger on the enemy, hit by
	# hit. See player.gd, "The hammer's runes". (Colours: the art thread's.)
	"momentum": {"kind": "rune", "weapon": "hammer", "name": "Momentum", "trigger": "hit", "color": Color("#ffc850"),
		"desc": "Each hit you land makes the next one stronger, in five steps. Stop hitting and it drains away."},
	"stagger": {"kind": "rune", "weapon": "hammer", "name": "Stagger", "trigger": "hit", "color": Color("#e0e2d0"),
		"desc": "Your hits fill a meter on the enemy. When it is full the enemy is stunned."},
	"aftershock": {"kind": "rune", "weapon": "hammer", "name": "Aftershock", "trigger": "finisher", "color": Color("#f06a2a"),
		"desc": "After your finisher the ground rumbles a moment later and hurts whatever is still near."},
	"quake": {"kind": "rune", "weapon": "hammer", "name": "Quake", "trigger": "active", "use": "press", "recharge": 5.0, "color": Color("#cf8a48"),
		"desc": "Press its button: a crack runs along the ground the way you aim and hits every enemy on it."},
	"bulwark": {"kind": "rune", "weapon": "hammer", "name": "Bulwark", "trigger": "active", "use": "press", "recharge": 10.0, "time": 3.0, "color": Color("#f0c070"),
		"desc": "Press its button: a shield blocks hits. Broken by enemies, it bursts and stuns them."},
	# The staff's own runes (15 November). Overflow, Nova, Lance and Spectre are
	# Darren's (11 November afternoon), and so are Overflow's and Spectre's bands;
	# Orbit and Chain were only names, so what they do is a first design, and so
	# are all the numbers and the bands of Orbit, Chain, Nova and Lance.
	# Overflow doesn't "fire": it changes the bolts you cast on full mana. See
	# player.gd, "The staff's runes". (Colours and words: the art thread's.)
	"orbit": {"kind": "rune", "weapon": "staff", "name": "Orbit", "trigger": "finisher", "color": Color("#ffc850"),
		"desc": "Your finisher leaves an orb circling you. It strikes the first enemy that comes near."},
	"chain": {"kind": "rune", "weapon": "staff", "name": "Chain", "trigger": "finisher", "color": Color("#f6faf0"),
		"desc": "Your finisher's bolt forks into lightning that jumps from enemy to enemy."},
	"overflow": {"kind": "rune", "weapon": "staff", "name": "Overflow", "trigger": "hit", "color": Color("#ffec98"),
		"desc": "On full mana your next bolt is bigger and hits harder."},
	"nova": {"kind": "rune", "weapon": "staff", "name": "Nova", "trigger": "active", "use": "press", "recharge": 6.0, "color": Color("#ffec98"),
		"desc": "Press its button: a ring bursts out from you and shoves the crowd back."},
	"lance": {"kind": "rune", "weapon": "staff", "name": "Lance", "trigger": "active", "use": "hold", "recharge": 8.0, "turns": 12, "turn": 0.25, "mana": true, "color": Color("#fff0b4"),
		"desc": "Hold its button: a beam into the first enemy on your aim that builds for as long as your mana lasts."},
	"spectre": {"kind": "rune", "weapon": "staff", "name": "Spectre", "trigger": "active", "use": "press", "recharge": 30.0, "time": 6.0, "color": Color("#c8f0c4"),
		"desc": "Press its button: a ghost of you, or of the teammate you aim at, copies basic attacks."},
	"twice": {"kind": "band", "name": "Twice", "color": Color("#86d4a4"),
		"desc": "The next rune happens twice."},
	"wider": {"kind": "band", "name": "Wider", "color": Color("#86d4a4"),
		"desc": "The next rune is bigger."},
	# On an active rune it is a different rule (Darren, 11 November afternoon): the
	# rune stays on its button, and every swing you land brings it back sooner.
	"every_hit": {"kind": "band", "name": "Every Hit", "color": Color("#86d4a4"),
		"desc": "A passive rune next fires on every hit, at half strength. An active one recharges as you land hits."},
	"saved_up": {"kind": "band", "name": "Saved Up", "color": Color("#86d4a4"),
		"desc": "The next rune is three times as strong, but comes a third as often."},
	"on_dodge": {"kind": "band", "name": "On Dodge", "color": Color("#86d4a4"),
		"desc": "The next rune also happens when you dodge."},
	# Mirror is parked (Darren, 6 November): it overlapped Twice too much. The rules stay, but it's kept out of the forge.
	"mirror": {"kind": "bender", "name": "Mirror", "color": Color("#a878d0"), "parked": true,
		"desc": "Rare. Copies what is in the seat before it. One rule-bender per weapon."},
	"relay": {"kind": "bender", "name": "Relay", "color": Color("#a878d0"),
		"desc": "Rare. Put it after a rune: that rune's threads change the next rune too."},
}
## Passive runes first, then active ones (the forge tray shows them as two groups).
## Whether this fitting can go on that weapon ("sword", "bow", "hammer", "staff").
## Every weapon has its own runes (Game Bible: three passive and three active
## each); bands and rule-benders fit them all.
static func fits(id: String, kind: String) -> bool:
	if not FITTINGS.has(id):
		return false
	var w: String = FITTINGS[id].get("weapon", "")
	return w == "" or w == kind


const FITTING_ORDER := ["shockwave", "shards", "weak_point", "pierce", "ricochet", "steady_aim", "momentum", "stagger", "aftershock",
	"orbit", "chain", "overflow",
	"whirlwind", "leap", "ghostwield", "volley", "snipe", "arrow_rain", "quake", "bulwark", "hook", "nova", "lance", "spectre",
	"twice", "wider", "every_hit", "saved_up", "on_dodge", "mirror", "relay"]
static var EVERY_HIT_POWER := 0.5
## Every Hit on an active rune: seconds off its recharge for each swing that lands.
static var EVERY_HIT_REFUND := 0.5
const SAVED_UP_EVERY := 3
const SAVED_UP_POWER := 3.0
## Ghostwield: what a ghost swing does, as a share of the swing it copies. Saved Up
## brings it to a full copy (and makes the recharge three times as long).
static var GHOST_POWER := 0.35


## How strong the ghost's copies are for a Ghostwield rune of this power.
static func ghost_power(power: float) -> float:
	return minf(GHOST_POWER * power, 1.0)


## How long the ghost sword stays. Wider is the band for it: one Wider is a third
## longer (about 11 seconds for 8).
static func ghost_time(size: float) -> float:
	return float(FITTINGS["ghostwield"]["time"]) * (1.0 + (size - 1.0) / 1.8)

## The bow's runes, in numbers. Damage is a share of one arrow from the same bow.
static var PIERCE_MAX := 6            # the most enemies one arrow goes on through
const PIERCE_WIDTH := 14.0       # Wider: how much thicker the arrow's path is, at twice the size
static var RICOCHET_DAMAGE := 0.5     # a jump, as a share of the arrow that hit
static var RICOCHET_RANGE := 150.0    # how far away the next enemy can be
static var STEADY_RATE := 0.1         # attack speed gained each second you stand and shoot
static var STEADY_CAP := 0.5          # the most it gives (Wider: 0.8)
static var STEADY_HIT := 0.05         # Every Hit: what each arrow that lands adds
const VOLLEY_SPREAD := 0.2       # radians between one arrow of the fan and the next
static var VOLLEY_DAMAGE := 1.0       # each arrow
static var SNIPE_CHARGE := 0.7        # seconds of holding until the ring closes
const SNIPE_SWEET := 0.25        # how long after that the shot is a perfect one
const SNIPE_HOLD := 2.5          # held this long, it goes by itself
static var SNIPE_NEAR := 2.0          # its damage at no distance, in arrows...
static var SNIPE_FAR := 6.0           # ...and after SNIPE_DISTANCE or more
static var SNIPE_DISTANCE := 480.0
const SNIPE_RANGE := 1.5         # how much further than an arrow it flies
static var SNIPE_PERFECT := 1.5       # let go in the sweet spot
static var SNIPE_EARLY := 0.5         # let go before the ring closed
const SNIPE_MOVE := 0.5          # walking speed while drawing it
static var RAIN_DAMAGE := 0.35        # each time the rain hits an enemy standing in it
static var RAIN_TICK := 0.3           # how often that is
const RAIN_RADIUS := Vector2(112, 80)   # the marked ground (an oval: the floor is seen from above)
static var RAIN_REACH := 420.0        # how far away you can mark
const RAIN_PIN := 0.4            # Saved Up: each hit holds an enemy this long
static var DODGE_SHARE := 0.5         # On Dodge on Volley and Snipe: the dodge's shot, as a share of the button's
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


## The hammer's runes, in numbers. Damage is a share of one swing of the same hammer.
static var MOMENTUM_STEPS := 5        # the ring's steps
static var MOMENTUM_STEP := 0.08      # what each step adds to your swings
static var MOMENTUM_STEP_MAX := 0.2   # the most one step can be worth, whatever the bands: Momentum at its most doubles a swing
static var MOMENTUM_HOLD := 2.0       # seconds without landing a hit before it starts to drain...
static var MOMENTUM_DRAIN := 0.5      # ...and then a step goes this often
static var STAGGER_STUN := 1.5        # how long a full meter stuns
static var STAGGER_DAMAGE := 1.0      # the blow as it breaks, in swings
const STAGGER_REACH := 50.0      # Wider: the break also stuns enemies this near, times the size
static var AFTERSHOCK_DELAY := 0.6    # the ground trembles this long, then rumbles
static var AFTERSHOCK_DAMAGE := 0.7
static var AFTERSHOCK_RADIUS := 60.0  # (the rumble's ring is drawn about this big)
static var AFTERSHOCK_STUN := 0.25
const AFTERSHOCK_SMALL := 0.7    # Every Hit: the small rumble's size
const AFTERSHOCK_HUGE := 1.5     # Saved Up: the huge one's
const AFTERSHOCK_GAP := 0.35     # Twice: the second rumble comes this long after the first
# Quake is a crack along your aim since 21 November (Darren's pick: it was an
# eruption under one enemy, "too similar to aftershock").
static var QUAKE_RANGE := 240.0       # how long the crack is, from you (Wider: longer)
static var QUAKE_DAMAGE := 1.5
static var QUAKE_WIDTH := 16.0        # an enemy whose edge is this near the crack's line is caught (Wider: wider)
static var QUAKE_STUN := 0.6
const QUAKE_GAP := 0.3           # Twice: the next crack comes this long after
static var BULWARK_STUN := 1.5        # when enemies break the shield, its burst stuns for this long (Twice: twice as long)
static var BULWARK_HITS := 3          # hits a shield of the usual length takes: the last one breaks it
static var BULWARK_BURST := 90.0      # the burst reaches enemies whose edge is this near you
static var HOOK_SAVED_STUN := 2.0     # Saved Up on Hook: the enemy it drags in arrives stunned, for this much longer
const BULWARK_DODGE := 1.0       # On Dodge: how long a dodge puts it up for


## What each of Momentum's five steps adds to a swing. Wider makes the steps
## bigger; Saved Up makes them much bigger (and a step comes a third as often).
## A step is never worth more than +20%, so Momentum at its most doubles a swing.
static func momentum_step(e: Dictionary) -> float:
	return minf(MOMENTUM_STEP * float(e["size"]) * maxf(float(e.get("power", 1.0)), 1.0), MOMENTUM_STEP_MAX)


## How long a Bulwark lasts. Wider is the band for it, as for the ghost sword (one
## Wider is a third longer: 4 seconds for 3). Saved Up: three times as long.
static func bulwark_time(size: float, power: float, seconds := -1.0) -> float:
	var base := float(FITTINGS["bulwark"]["time"]) if seconds < 0.0 else seconds
	return base * (1.0 + (size - 1.0) / 1.8) * (SAVED_UP_POWER if power >= SAVED_UP_POWER else 1.0)


## How many hits a Bulwark put up for `seconds` takes before it breaks: as many
## as the usual one for as long as the usual one, so a longer shield (Wider,
## Saved Up) takes more and a dodge's short one takes one.
static func bulwark_hits(seconds: float) -> int:
	return maxi(roundi(float(BULWARK_HITS) * seconds / maxf(float(FITTINGS["bulwark"]["time"]), 0.1)), 1)


## The staff's runes, in numbers. Damage is a share of one bolt from the same staff.
const ORBIT_RADIUS := 36.0       # how far from you an orb circles
const ORBIT_FLAT := 0.6          # the circle is an oval on the floor
const ORBIT_PERIOD := 1.2        # seconds for one turn
static var ORBIT_REACH := 62.0        # an enemy whose edge comes this near you is struck (Wider: further)
static var ORBIT_TIME := 8.0          # how long an orb waits for someone
static var ORBIT_MAX := 3             # orbs at once: a new one takes the oldest one's place
static var ORBIT_DAMAGE := 1.0        # its strike
const ORBIT_GAP := 0.25          # two orbs don't strike closer together than this
const ORBIT_KNOCK := 240.0
const ORBIT_STUN := 0.25
static var CHAIN_JUMPS := 3           # how many enemies the lightning goes on to (Twice: six)
static var CHAIN_RANGE := 150.0       # how far one jump reaches (Wider: further)
static var CHAIN_DAMAGE := 0.5        # each jump
static var OVERFLOW_DAMAGE := 0.3     # how much harder a bolt cast on full mana hits
static var OVERFLOW_SIZE := 0.25      # and how much bigger it is
# Its bands are Darren's (11 November, "Overflow bands" in the Game Bible); the numbers are a first pass.
const OVERFLOW_ECHO := 0.12      # Twice: every other Overflow bolt is cast again this long after
const OVERFLOW_SPLASH := 36.0    # Wider: an Overflow bolt bursts this wide where it lands, so it hits more enemies
static var OVERFLOW_REFUND := 3.0     # Every Hit: mana back for each bolt that lands (so the bar is full again, and the next Overflow bolt ready, sooner)
static var OVERFLOW_CHARGE := 3.0     # Saved Up: seconds your mana must stay full...
static var OVERFLOW_BLAST := 3.0      # ...for the next bolt to be a blast this many times as strong...
const OVERFLOW_BLAST_SIZE := 0.9 # ...and this much bigger, bursting OVERFLOW_BLAST_SPLASH wide
const OVERFLOW_BLAST_SPLASH := 64.0
static var OVERFLOW_DODGE_MANA := 10.0   # On Dodge: mana back for each dodge
static var NOVA_RADIUS := 110.0       # how far the ring reaches to the sides...
const NOVA_FLAT := 0.62          # ...and up and down, as a share (it is an oval on the floor)
static var NOVA_DAMAGE := 1.2
static var NOVA_KNOCK := 430.0
static var NOVA_STUN := 0.3
const NOVA_GAP := 0.3            # Twice: the second ring comes this long after
static var LANCE_DAMAGE := 0.75       # one pulse of the beam at its first strength
const LANCE_STAGES := 3          # strengths: one, two and three times LANCE_DAMAGE a pulse; a third of a full hold at each
const LANCE_WIDTH := 10.0        # how close the beam's line must pass to an enemy's edge (Wider: a thicker beam)
static var LANCE_MOVE := 0.5          # walking speed while the beam is held
const LANCE_DODGE := 0.5         # On Dodge: one pulse at full strength, at this share
static var SPECTRE_POWER := 0.5       # what the ghost's copy does, as a share of the attack it copies
const SPECTRE_DELAY := 0.15      # a copy comes this long after the attack
const SPECTRE_GAP := 0.1         # Twice: the second copy comes this long after the first
const SPECTRE_AIM := 320.0       # how far away a teammate can be to be given the ghost...
const SPECTRE_CONE := 0.35       # ...and how far off your aim, in radians
# Its bands are Darren's too ("Spectre bands" in the Game Bible).
const SPECTRE_BURST := 1.0       # On Dodge: the ghost dodges with its player and bursts where it stood, for this many bolts of the caster's staff...
const SPECTRE_BURST_RADIUS := 56.0   # ...to everything this near


## How strong a Spectre's copies are. Saved Up brings them to full copies (and
## makes the recharge three times as long), as for the ghost sword.
static func spectre_power(power: float) -> float:
	return minf(SPECTRE_POWER * power, 1.0)


## How long a Spectre stays. Wider is the band for it (one Wider: about 9 seconds
## for 6, Darren's number).
static func spectre_time(size: float) -> float:
	return float(FITTINGS["spectre"]["time"]) * (1.0 + (size - 1.0) / 1.2)


## The beam's strength (1 to LANCE_STAGES) on its nth pulse of one hold. `turns`
## is how many pulses a full bar of mana pays for (twelve; Twice: twenty-five):
## it grows a step for each third of that, so it builds until the mana is gone.
static func lance_stage(pulse: int, turns: int) -> int:
	@warning_ignore("integer_division")
	return clampi(1 + (maxi(pulse, 1) - 1) * LANCE_STAGES / maxi(turns, 1), 1, LANCE_STAGES)


## How long a Lance can be held on a full bar of mana, in seconds (Twice: each
## pulse costs half as much, so twice as long).
static func lance_time(count: int) -> float:
	var pulse := float(RUNE_MANA.get("lance", 0.0)) / float(maxi(count, 1))
	return floorf(MANA / maxf(pulse, 0.01)) * float(FITTINGS["lance"]["turn"])


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


## The four setters take a part of the weapon in the hand; a part of another
## weapon is ignored (a blade doesn't go on a bow).
func set_blade(id: String) -> void:
	if not heads_of(weapon()).has(id):
		return
	var old := grip_slots()
	blade = id
	_refit(old)
	changed.emit()


func set_grip(id: String) -> void:
	if not grips_of(weapon()).has(id):
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
	if not butts_of(weapon()).has(id):
		return
	pommel = id
	changed.emit()


## A bow's arrows or a staff's crystal.
func set_arrows(id: String) -> void:
	if not shots_of(weapon()).has(id):
		return
	arrows = id
	changed.emit()


## The whole weapon as plain values, to send to the other computer online. A
## sword or a hammer is [head, grip, butt, line]; a bow or a staff has a fifth
## value, its arrows or its crystal.
func get_data() -> Array:
	var out: Array = [blade, grip, pommel, line.duplicate()]
	if ranged(weapon()):
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
	var kind := ""
	for k in WEAPON_ORDER:
		if heads_of(k).has(data[0]):
			kind = k
	if kind == "" or not (grips_of(kind).has(data[1]) and butts_of(kind).has(data[2])):
		return false
	if ranged(kind):
		if data.size() != 5 or not (data[4] is String) or not shots_of(kind).has(data[4]):
			return false
	elif data.size() != 4:
		return false
	if data[3].size() != int(grip_part(data[1])["slots"]) + int(head_part(data[0])["slots"]):
		return false
	for id in data[3]:
		if not (id is String) or (id != "" and not fits(id, kind)):
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
static var MAX_COUNT := 3          # Twice: at most 3 fires
static var MAX_SIZE := 2.0         # Wider: at most 2x size
static var WIDER_STEPS := [1.6, 1.85, 2.0]  # 1, 2, 3+ Wider bands


static func wider_size(n: int) -> float:
	if n <= 0:
		return 1.0
	return minf(WIDER_STEPS[mini(n, WIDER_STEPS.size()) - 1], MAX_SIZE)


## Reads the line bottom to top. Returns:
##   effects: one entry per rune: {id, slot, bands (ids), band_slots, trigger, count, size,
##            power (strength multiplier), every (fires on every Nth trigger), also (extra triggers),
##            mirror (true if it's a Mirror's copy), button (active runes: 0, 1 or 2)}
##   slots:   for each slot index: {"rune": effect index} / {"band": effect index} /
##            {"unused": true, "why": text} / plus "mirror": true or "relay": true on rule-benders,
##            and "dup": true on a second copy of a rune (the forge marks it with a red X)
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
	var seen: Array = []      # the runes that are working already
	for i in line.size():
		var id: String = line[i]
		if id == "" or info.get(i, {}).has("unused"):
			continue
		var f: Dictionary = FITTINGS[id]
		if f["kind"] == "bender":  # Relay (Mirror was swapped for its copy above)
			if effects.is_empty() or not pending.is_empty():
				info[i] = {"unused": true, "relay": true, "why": "Needs a rune in the seat before it."}
				continue
			relay_bands = (effects[-1]["band_slots"] as Array).duplicate()
			relay_slot = i
			info[i] = {"relay": true}
			continue
		if f["kind"] == "band":
			pending.append(i)
			continue
		# Only one of each rune works (Darren, 21 November: "if theres two runes of
		# same type being used make a little red X on it to show its not usuable").
		# The first copy works; a later one does nothing, and nor do the threads in
		# front of it. (Until then a second copy counted like a Twice on the first.
		# A Mirror's copy still does: copying is what a Mirror is for.)
		if id in seen and slots[i] != "mirror":
			info[i] = {"unused": true, "dup": true, "why": "A second %s does nothing: only one of each rune works." % f["name"]}
			for s in pending:
				info[s] = {"unused": true, "why": "The rune after it is a second copy, which does nothing."}
			if relay_slot >= 0:
				info[relay_slot] = {"unused": true, "relay": true, "why": "The rune after it is a second copy, which does nothing."}
				relay_slot = -1
				relay_bands = []
			pending = []
			continue
		if f["trigger"] == "active" and not (id in buttons) and buttons.size() >= ACTIVE_BUTTONS:
			# A fourth kind of active rune has no button left.
			info[i] = {"unused": true, "why": "Only three active runes work on one weapon."}
			for s in pending:
				info[s] = {"unused": true, "why": "The rune after it has no button."}
			if relay_slot >= 0:
				info[relay_slot] = {"unused": true, "relay": true, "why": "The rune after it has no button."}
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
		seen.append(id)
		pending = []
	for s in pending:
		info[s] = {"unused": true, "why": "No rune after it, so it does nothing."}
	if relay_slot >= 0:
		info[relay_slot] = {"unused": true, "relay": true, "why": "Needs a rune after it."}
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
			info[i] = {"unused": true, "why": "Only one rule-bender works on a weapon."}
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
			info[i] = {"unused": true, "mirror": true, "why": "Nothing before it to copy."}
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
			if e["id"] == "overflow":
				# Overflow doesn't fire: with this, every bolt that lands gives a little mana back.
				if e.get("per_hit", false):
					return "Every Hit doesn't stack (max)."
				e["per_hit"] = true
				return ""
			if e["id"] == "momentum":
				# Momentum counts swings that land: with this, every enemy a swing catches.
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
	if str(e["id"]) in ["momentum", "stagger", "aftershock"]:
		return _hammer_sentence(e)
	if str(e["id"]) in ["orbit", "chain", "overflow"]:
		return _staff_sentence(e)
	var when: String = (WHEN_NTH if int(e.get("every", 1)) > 1 else WHEN).get(trig, "It")
	var what := ""
	match str(e["id"]):
		"shockwave":
			what = "sends %s forward" % (("a big shockwave" if big else "a shockwave") if n == 1 else ("%s %sshockwaves" % [_num(n), "big " if big else ""]))
		"shards":
			what = "sends %s out of the enemy's back, into whoever stands behind it%s" % [
				("twice as many shards" if e.get("splinter", false) else "shards") if n == 1 else "%s bursts of %sshards" % [_num(n), "twice as many " if e.get("splinter", false) else ""],
				", from further away" if big else ""]
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


## The sentence for one of the hammer's passive runes.
static func _hammer_sentence(e: Dictionary) -> String:
	var n: int = e["count"]
	var big: bool = float(e["size"]) > 1.0
	var third := int(e.get("every", 1)) > 1
	var power := float(e.get("power", 1.0))
	var dodge: bool = "dodge" in e.get("also", [])
	match str(e["id"]):
		"momentum":
			var who := "enemy you hit" if e.get("per_hit", false) else "swing that lands"
			var step := momentum_step(e)
			var s := "%s %s adds %s of +%d%% to your swings, up to +%d%%. Stop hitting and it drains away." % ["Every third" if third else "Each", who,
				"a step" if n == 1 else "%s steps" % _num(n), roundi(step * 100.0), roundi(step * float(MOMENTUM_STEPS) * 100.0)]
			if dodge:
				s += " A dodge counts as a hit."
			return s
		"stagger":
			var fast := "" if n == 1 else (" twice as fast" if n == 2 else " %s times as fast" % _num(n))
			if third:
				fast = " slowly" if n == 1 else ("" if n >= SAVED_UP_EVERY else " rather slowly")
			var s := "Your hits fill a meter on the enemy%s. When it is full the enemy takes a %s blow and is stunned for %s seconds%s." % [fast,
				"huge" if power >= SAVED_UP_POWER else "heavy", str(snappedf(STAGGER_STUN * maxf(power, 1.0), 0.1)).trim_suffix(".0"),
				", and so is everything near it" if big else ""]
			if dodge:
				s += " Dodging past an enemy counts as a hit on it."
			return s
		"aftershock":
			var every_hit: bool = e["trigger"] == "hit"
			var who := ("Every third hit" if third else "Every hit") if every_hit else ("Every third finisher" if third else "Your finisher")
			var kind := "huge " if power >= SAVED_UP_POWER else ("small " if every_hit else ("big " if big else ""))
			var what := ("a %srumble" % kind) if n == 1 else "%s %srumbles" % [_num(n), kind]
			var s := "%s sets off %s in the ground a moment later that hurt%s whatever is still near" % [who, what, "s" if n == 1 else ""]
			if big and kind != "big ":
				s += ", over a bigger patch"
			if power < 1.0:
				s += ", at half strength"
			elif power >= SAVED_UP_POWER:
				s += ", three times as strong"
			elif power > 1.0:
				s += ", %sx as strong" % str(snappedf(power, 0.1))
			s += "."
			if dodge:
				s += " %s leaves one where you were." % ("Every third dodge" if third else "A dodge")
			return s
	return ""


## The sentence for one of the staff's passive runes.
static func _staff_sentence(e: Dictionary) -> String:
	var n: int = e["count"]
	var big: bool = float(e["size"]) > 1.0
	var third := int(e.get("every", 1)) > 1
	var power := float(e.get("power", 1.0))
	var dodge: bool = "dodge" in e.get("also", [])
	var every_hit: bool = e["trigger"] == "hit"
	var strength := ""
	if power < 1.0:
		strength = ", at half strength"
	elif power >= SAVED_UP_POWER:
		strength = ", three times as strong"
	elif power > 1.0:
		strength = ", %sx as strong" % str(snappedf(power, 0.1))
	match str(e["id"]):
		"orbit":
			var who := ("Every third bolt that hits" if third else "Every bolt that hits") if every_hit else ("Every third finisher" if third else "Your finisher")
			var s := "%s leaves %s circling you%s. %s the first enemy that comes near%s." % [who, "an orb" if n == 1 else "%s orbs" % _num(n), strength,
				"It strikes" if n == 1 else "They strike", ", from further off" if big else ""]
			if dodge:
				s += " %s leaves one too." % ("Every third dodge" if third else "A dodge")
			return s + _passive_cost()
		"chain":
			var who := ("Every third bolt that hits" if third else "Every bolt that hits") if every_hit else ("Every third finisher's bolt" if third else "Your finisher's bolt")
			var s := "%s sends lightning jumping to %s more enemies%s%s." % [who, _num(mini(CHAIN_JUMPS * n, 9)), ", from further away" if big else "", strength]
			if dodge:
				s += " %s sends it out from you too." % ("Every third dodge" if third else "A dodge")
			return s + _passive_cost()
		"overflow":
			# (Saved Up: no steady bonus, but a blast after staying full for a while.)
			var s := ""
			if third:
				s = "After %s seconds on full mana, your next bolt is a huge%s blast, three times as strong." % [_num(roundi(OVERFLOW_CHARGE)), ", wider" if big else ""]
			elif big:
				s = "On full mana your next bolt hits %d%% harder and bursts wide where it lands." % roundi(OVERFLOW_DAMAGE * 100.0)
			else:
				s = "On full mana your next bolt is bigger and hits %d%% harder." % roundi(OVERFLOW_DAMAGE * 100.0)
			if n > 1:
				s += " Every other one is cast %s." % ("twice" if n == 2 else "%s times" % _num(n))
			if e.get("per_hit", false):
				s += " Each bolt that lands gives back %d mana." % roundi(OVERFLOW_REFUND)
			if dodge:
				s += " A dodge gives back %d mana." % roundi(OVERFLOW_DODGE_MANA)
			return s + _passive_cost()
	return ""


## What a staff's passive rune costs, as the end of its sentence.
static func _passive_cost() -> String:
	return " Costs %d mana each time." % roundi(PASSIVE_MANA) if PASSIVE_MANA > 0.0 else ""


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
			what = "a chain drags the enemy nearest your aim to you%s%s%s" % [" from further away" if big else "",
				"" if n == 1 else (", then another" if n == 2 else ", then %s more" % _num(n - 1)),
				", stunned for %s seconds" % str(snappedf(HOOK_SAVED_STUN, 0.1)).trim_suffix(".0") if int(e.get("every", 1)) > 1 else ""]
		"whirlwind":
			what = "spins for up to %s turns, cutting everything around you%s" % [_num(int(f["turns"]) * n), ", in a bigger circle" if big else ""]
		"leap":
			what = "leaps you to the nearest enemy%s and strikes it from your blade's reach%s" % [" from further away" if big else "",
				"" if n == 1 else (", then the next one" if n == 2 else ", then %s more" % _num(n - 1))]
		"ghostwield":
			# Its strength is how much of your swing the ghost copies, so say that.
			what = "a ghost of your sword copies every swing%s for %d seconds, at %s" % ["" if n == 1 else (" twice" if n == 2 else " %d times" % n),
				roundi(ghost_time(float(e["size"]))), _strength(ghost_power(float(e.get("power", 1.0))))]
		"volley":
			what = "looses %s arrows in a spread%s" % [_num(volley_arrows(float(e["size"]))), "" if n == 1 else (", twice" if n == 2 else ", %s times" % _num(n))]
		"snipe":
			what = "%s that %s more the farther %s%s" % ["one heavy shot" if n == 1 else "%s heavy shots" % _num(n), "does" if n == 1 else "do",
				"it flies" if n == 1 else "they fly", ", with a longer moment for the perfect shot" if big else ""]
		"arrow_rain":
			what = "marks the ground where you aim, and arrows pour down on it for %d seconds%s%s" % [roundi(float(f["time"])),
				" over a bigger area" if big else "", "" if n == 1 else (", then again" if n == 2 else ", then %s more times" % _num(n - 1))]
		"quake":
			what = "a %scrack runs along the ground the way you aim and hits every enemy on it%s" % ["longer, wider " if big else "",
				"" if n == 1 else (", then a second one" if n == 2 else ", then %s more" % _num(n - 1))]
		"bulwark":
			# Its strength is how long it lasts and how many hits it takes, so say that.
			var secs := bulwark_time(float(e["size"]), float(e.get("power", 1.0)))
			var hits := bulwark_hits(secs)
			var nth: String = ["last", "last", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth"][hits] if hits <= 9 else "last"
			what = "for %d seconds a shield blocks %s, stunning enemies near you%s" % [roundi(secs),
				"%s hits; the %s bursts it" % [_num(hits) if hits <= 9 else str(hits), nth] if hits > 1 else "one hit, which bursts it",
				"" if n == 1 else (" for twice as long" if n == 2 else " for %s times as long" % _num(n))]
		"nova":
			what = "%s out from you and shove%s the crowd back" % [("a big ring bursts" if big else "a ring bursts") if n == 1 else "%s %srings burst" % [_num(n), "big " if big else ""], "s" if n == 1 else ""]
		"lance":
			# Twice is twice as long a hold (see abilities()).
			# It runs on mana: say what a full bar pays for.
			what = "a %sbeam into the first enemy on your aim that builds until your mana runs out, about %s seconds on a full bar" % ["thick " if big else "", _num(roundi(lance_time(n)))]
		"spectre":
			# Its strength is how much of an attack the ghost copies, so say that.
			what = "%s of you, or of the teammate you aim at, %s their basic attacks for %d seconds, at %s" % ["a ghost" if n == 1 else "%s ghosts" % _num(n), "copies" if n == 1 else "copy",
				roundi(spectre_time(float(e["size"]))), _strength(spectre_power(float(e.get("power", 1.0))))]
		_:
			return ""
	var slow := int(e.get("every", 1))
	if float(e.get("power", 1.0)) >= 3.0 and not (e["id"] in ["ghostwield", "bulwark", "spectre", "hook"]):
		what += ", three times as strong"
		if e["id"] == "arrow_rain":
			what += " and pinning enemies"
	var how: String = {"hold": "Hold %s", "charge": "Hold %s, then let go"}.get(f["use"], "Press %s") % key
	# (A staff's runes cost mana: said with the recharge, so that what comes after
	# it, like Every Hit's half a second off, still reads as about the recharge.)
	var back := "Recharges in %d seconds." % roundi(float(f["recharge"]) * slow)
	var mana := float(RUNE_MANA.get(e["id"], 0.0))
	if mana > 0.0:
		back = "Costs %d mana%s and recharges in %d seconds." % [roundi(mana / (float(n) if f.get("mana", false) else 1.0)), " a pulse" if f.get("mana", false) else "",
			roundi(float(f["recharge"]) * slow)]
	var s := "%s: %s. %s" % [how, what, back]
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
		elif e["id"] == "quake":
			s += " %s sets one off too, at half strength." % dodging
		elif e["id"] == "nova":
			s += " %s sets one off too, at half strength." % dodging
		elif e["id"] == "lance":
			s += " %s fires one flash of it." % dodging
		elif e["id"] == "spectre":
			s += " When they dodge, %s where it stood." % ("it bursts" if n == 1 else "they burst")
		elif e["id"] == "hook":
			s += " %s throws a quick one at the nearest enemy." % dodging
		elif e["id"] == "bulwark":
			s += " %s puts it up for %s." % [dodging, "a second" if slow <= 1 else "%s seconds" % _num(roundi(bulwark_time(1.0, float(e.get("power", 1.0)), BULWARK_DODGE)))]
		else:
			s += " Every third dodge does it too." if slow > 1 else " Dodging does it too."
	return s


## A rune's sentence with no thread on it: what the bare rune does. The forge
## writes this under the rune's name, and each thread's own line under that.
static func base_sentence(e: Dictionary, keys: Array = ABILITY_KEYS["kbm"]) -> String:
	var bare := {"id": e["id"], "slot": e.get("slot", 0), "bands": [], "band_slots": [], "trigger": FITTINGS[e["id"]]["trigger"],
		"count": 1, "size": 1.0, "power": 1.0, "every": 1, "also": [], "mirror": false}
	if e.has("button"):
		bare["button"] = e["button"]
	return sentence(bare, keys)


## What each thread on a rune adds, a short line for each kind of thread, in the
## order they sit on the ring: [{band, name, text}]. (Darren, 21 November: "when u
## hover a rune, any threads affecting it to show then and what they increase.
## rather than just a big decription".) A thread that does nothing to this rune
## has no line: the forge says why under "what it does".
static func thread_lines(e: Dictionary) -> Array:
	var out: Array = []
	var seen: Array = []
	var bands: Array = e.get("bands", [])
	for b in bands:
		if b in seen:
			continue
		seen.append(b)
		var text := _thread_text(e, str(b))
		if text == "":
			continue
		var copies := bands.count(b)
		var name := str(FITTINGS[b]["name"])
		if copies > 1 and str(b) in ["twice", "wider"]:
			name += " x%d" % copies
		out.append({"band": b, "name": name, "text": text})
	if e.get("ruby", false):
		out.append({"band": "ruby", "name": "Ruby seat", "text": "it happens one more time"})
	return out


## One thread's line for one rune, from the rune as the ring has made it (so two
## Twice threads read "three waves").
static func _thread_text(e: Dictionary, band: String) -> String:
	var id := str(e["id"])
	var f: Dictionary = FITTINGS[id]
	var n: int = e["count"]
	var size := float(e["size"])
	var power := float(e.get("power", 1.0))
	var third := int(e.get("every", 1)) > 1
	var active: bool = f["trigger"] == "active"
	var times := "twice" if n == 2 else "%s times" % _num(n)
	var more := "a second one" if n == 2 else "%s more" % _num(n - 1)
	match band:
		"twice":
			if n < 2:
				return ""
			match id:
				"shockwave": return "%s waves" % _num(n)
				"shards": return "%s bursts of shards" % _num(n)
				"weak_point": return "marks up to %s enemies" % _num(n)
				"whirlwind": return "up to %s turns, not %s" % [_num(int(f["turns"]) * n), _num(int(f["turns"]))]
				"leap": return "then leaps to the next enemy" if n == 2 else "then %s more leaps" % _num(n - 1)
				"ghostwield": return "the ghost copies each swing %s" % times
				"hook": return "then a second chain, at another enemy" if n == 2 else "then %s more chains" % _num(n - 1)
				"pierce": return "the arrow goes through %s enemies" % _num(pierce_count(e))
				"ricochet": return "it jumps on %s" % times
				"steady_aim": return "builds %s as quickly" % times
				"volley": return "looses the spread %s" % times
				"snipe": return "%s heavy shots" % _num(n)
				"arrow_rain": return "then a second shower" if n == 2 else "then %s more showers" % _num(n - 1)
				"momentum": return "%s steps for each swing that lands" % _num(n)
				"stagger": return "the meter fills %s as fast" % times
				"aftershock": return "%s rumbles" % _num(n)
				"quake": return "then a second crack" if n == 2 else "then %s more cracks" % _num(n - 1)
				"bulwark": return "its burst stuns for %s as long" % times
				"orbit": return "%s orbs" % _num(n)
				"chain": return "jumps to %s enemies, not %s" % [_num(mini(CHAIN_JUMPS * n, 9)), _num(CHAIN_JUMPS)]
				"overflow": return "every other big bolt is cast %s" % times
				"nova": return "%s rings" % _num(n)
				"lance": return "%d mana a pulse, so about %s seconds" % [roundi(float(RUNE_MANA.get("lance", 0.0)) / float(n)), _num(roundi(lance_time(n)))]
				"spectre": return "%s ghosts" % _num(n)
			return "it happens %s" % times
		"wider":
			if size <= 1.0:
				return ""
			match id:
				"shockwave": return "a bigger wave"
				"shards": return "the shards fly further"
				"weak_point": return "a bigger spot to hit"
				"whirlwind": return "a bigger circle"
				"leap": return "leaps from further away"
				"ghostwield": return "the ghost stays %d seconds, not %d" % [roundi(ghost_time(size)), roundi(ghost_time(1.0))]
				"hook": return "the chain reaches further"
				"pierce": return "the arrow cuts a wider path"
				"ricochet": return "it jumps from further away"
				"steady_aim": return "builds up to +%d%%, not +%d%%" % [roundi(steady_cap(e) * 100.0), roundi(STEADY_CAP * 100.0)]
				"volley": return "%s arrows, not %s" % [_num(volley_arrows(size)), _num(volley_arrows(1.0))]
				"snipe": return "a longer moment for the perfect shot"
				"arrow_rain": return "a bigger area"
				"momentum": return "each step adds +%d%%" % roundi(momentum_step(e) * 100.0)
				"stagger": return "the stun catches everything near it too"
				"aftershock": return "a bigger patch of ground"
				"quake": return "a longer, wider crack"
				"bulwark":
					if third:
						return "lasts a third longer"
					var secs := bulwark_time(size, power)
					return "lasts %d seconds and takes %d hits" % [roundi(secs), bulwark_hits(secs)]
				"orbit": return "the orb strikes from further off"
				"chain": return "it jumps from further away"
				"overflow": return "the big bolt bursts wide where it lands"
				"nova": return "a bigger ring"
				"lance": return "a thicker beam"
				"spectre": return "the ghost stays %d seconds, not %d" % [roundi(spectre_time(size)), roundi(spectre_time(1.0))]
			return "it is bigger"
		"every_hit":
			if active:
				if float(e.get("refund", 0.0)) <= 0.0:
					return ""
				var off := "half a second" if absf(float(e["refund"]) - 0.5) < 0.01 else "%s seconds" % str(snappedf(float(e["refund"]), 0.1)).trim_suffix(".0")
				return "each hit takes %s off" % off
			match id:
				"steady_aim": return "each arrow that lands adds to it" if e.get("per_hit", false) else ""
				"overflow": return "each bolt that lands gives back %d mana" % roundi(OVERFLOW_REFUND) if e.get("per_hit", false) else ""
				"momentum": return "counts every enemy a swing hits" if e.get("per_hit", false) else ""
				"shards": return "twice as many shards, at half strength" if e.get("splinter", false) else ""
				"ricochet": return "it splits in two as it jumps, at half strength" if e.get("splinter", false) else ""
				"pierce": return "every arrow does it; those behind take half" if e["trigger"] == "hit" else ""
			if f["trigger"] == "hit" or e["trigger"] != "hit":
				return ""
			return "on every hit, at half strength"
		"saved_up":
			if not third:
				return ""
			if active:
				var back := "recharges in %d seconds" % roundi(float(f["recharge"]) * float(e["every"]))
				match id:
					"ghostwield": return "copies at %s, but %s" % [_strength(ghost_power(power)), back]
					"spectre": return "copies at %s, but %s" % [_strength(spectre_power(power)), back]
					"bulwark":
						var secs := bulwark_time(size, power)
						return "lasts %d seconds and takes %d hits, but %s" % [roundi(secs), bulwark_hits(secs), back]
					"hook": return "stuns the enemy for %s seconds, but %s" % [str(snappedf(HOOK_SAVED_STUN, 0.1)).trim_suffix(".0"), back]
					"arrow_rain": return "three times as strong and pins enemies, but %s" % back
				return "three times as strong, but %s" % back
			match id:
				"weak_point": return "only every third finisher, but a huge crit"
				"pierce": return "only every third finisher, but through three times as many"
				"steady_aim": return "builds slowly; once full, every third arrow hits three times as hard"
				"momentum": return "a step only every third hit, but each adds +%d%%" % roundi(momentum_step(e) * 100.0)
				"stagger": return "the meter fills slowly, but a huge blow and a %s second stun" % str(snappedf(STAGGER_STUN * maxf(power, 1.0), 0.1)).trim_suffix(".0")
				"overflow": return "after %s seconds on full mana, one huge blast, three times as strong" % _num(roundi(OVERFLOW_CHARGE))
			return "only every third time, but three times as strong"
		"on_dodge":
			if not ("dodge" in e.get("also", [])):
				return ""
			var dodge := "every third dodge" if third else "a dodge"
			match id:
				"ghostwield": return "the ghost also cuts along %s" % ("every third dodge" if third else "every dodge")
				"volley": return "%s looses one too, at half strength" % dodge
				"snipe": return "%s looses a quick, weak one too" % dodge
				"arrow_rain": return "%s leaves a small shower" % dodge
				"quake", "nova": return "%s does it too, at half strength" % dodge
				"lance": return "%s fires one flash of it" % dodge
				"spectre": return "the ghost bursts when its player dodges"
				"hook": return "%s hooks the nearest enemy" % dodge
				"bulwark": return "%s puts it up for %s" % [dodge, "a second" if not third else "%s seconds" % _num(roundi(bulwark_time(1.0, power, BULWARK_DODGE)))]
				"pierce": return "the first arrow after %s does it too" % dodge
				"ricochet": return "%s sends one from you too" % dodge
				"steady_aim": return "dodging no longer resets it"
				"momentum": return "a dodge counts as a hit"
				"stagger": return "dodging past an enemy counts as a hit"
				"aftershock": return "%s leaves one where you were" % dodge
				"orbit": return "%s leaves one too" % dodge
				"chain": return "%s sends it out from you too" % dodge
				"overflow": return "a dodge gives back %d mana" % roundi(OVERFLOW_DODGE_MANA)
			return "%s does it too" % dodge
	return ""


## A share of a hit in words: "full strength", "half strength", "a third of its
## strength", or the number.
static func _strength(share: float) -> String:
	if share >= 0.995:
		return "full strength"
	if absf(share - 0.5) < 0.03:
		return "half strength"
	if absf(share - 1.0 / 3.0) < 0.03:
		return "a third of its strength"
	if absf(share - 0.25) < 0.03:
		return "a quarter of its strength"
	return "%d%% strength" % roundi(share * 100.0)


static func _num(n: int) -> String:
	const WORDS := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
		"thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"]
	return WORDS[n] if n >= 0 and n < WORDS.size() else str(n)


## The sword's active runes, one entry per ability button, in button order:
##   {id, use, effects (indexes into `effects`), recharge (seconds), turns, turn, slot, refund,
##    mana (what a press, or one pulse of a Lance, costs), drain (Lance: it runs on mana)}
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
		# A staff's active runes cost mana. Lance runs on mana and not on a meter
		# ("drain"): each pulse costs some (Twice: half as much, so it lasts twice
		# as long), and its "turns" are the pulses a full bar pays for.
		var mana := float(RUNE_MANA.get(e["id"], 0.0))
		var drain: bool = f.get("mana", false)
		if drain:
			mana /= float(maxi(int(e["count"]), 1))
			turns = maxi(int(MANA / maxf(mana, 0.01)), 1)
		while out.size() <= b:
			out.append({})
		if out[b].is_empty():
			out[b] = {"id": e["id"], "use": f["use"], "effects": [i], "recharge": recharge,
				"turns": turns, "turn": float(f.get("turn", 0.0)), "slot": int(e["slot"]),
				"refund": float(e.get("refund", 0.0)), "mana": mana, "drain": drain}
		else:
			out[b]["effects"].append(i)
			out[b]["recharge"] = maxf(float(out[b]["recharge"]), recharge)
			out[b]["turns"] = maxi(int(out[b]["turns"]), turns)
			out[b]["refund"] = maxf(float(out[b]["refund"]), float(e.get("refund", 0.0)))
	return out


## Everything the player needs, as one plain dictionary. Every weapon gives the
## same things ("blade" is its head, "pommel" its butt); a bow and a staff also
## give "arrows" (the arrows or the crystal), "range" and "flight", a hammer its
## "impact" and a staff its spell "size".
func compute() -> Dictionary:
	var kind := weapon()
	var b: Dictionary
	match kind:
		"bow": b = limb_info(blade, arrows)
		"hammer": b = hammer_info(blade)
		"staff": b = staff_info(blade, arrows)
		_: b = blade_info(blade)
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
		"weapon": kind,
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
	if ranged(kind):
		out["arrows"] = arrows
		out["range"] = float(b["range"])
		out["flight"] = float(b["flight"])
	if kind == "hammer":
		out["impact"] = float(b["impact"])
	if kind == "staff":
		out["size"] = float(b["size"])
		# What one whole chain costs (the forge shows it).
		var cost := 0.0
		for m in b["chain"]:
			cost += float(CAST_MANA.get(m, 0.0))
		out["mana"] = cost
		out["hit_color"] = CRYSTALS[arrows]["color"] if CRYSTALS.has(arrows) else Color.WHITE
	return out


static var BASE_CRIT := 0.07
static var BASE_CRIT_DAMAGE := 1.6

const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.5, 0.2),
	"water": Color(0.35, 0.65, 1.0),
	"lightning": Color(1.0, 0.95, 0.35),
	"steam": Color(0.85, 0.9, 0.95),
	"electrified": Color(0.6, 0.85, 1.0),
}
