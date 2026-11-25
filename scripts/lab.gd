extends RefCounted
## The lab: the game's numbers, changeable while the game runs (Darren, 15
## November: "a lab so I can adjust numbers myself without having to ask").
##
## Every number the lab shows is a row in ROWS below: which page and group it is
## on, what it is called, and where in the game's code it lives. The number in the
## code is the game's own; a change made in the lab is written over it at once
## and kept in a small file on this computer (user://lab.json), so it is still
## there the next time the game starts. It is in force everywhere: the test
## arena and the tutorial cave.
##
## Two rules keep it safe:
## - An online game always uses the game's own numbers (set_in_force(false)):
##   two computers with different numbers would drift apart.
## - Only the game's front door (scripts/boot.gd) calls start(), so the tests,
##   which load a scene directly, never see anybody's lab file.
##
## The screen is scripts/ui/lab_screen.gd.

const Version := preload("res://scripts/version.gd")

const SCRIPTS := {
	"build": "res://scripts/weapon/swing_build.gd",
	"player": "res://scripts/player.gd",
	"enemy": "res://scripts/enemy.gd",
	"crawler": "res://scripts/cave/crawler.gd",
	"burrower": "res://scripts/cave/burrower.gd",
	"guardian": "res://scripts/cave/guardian.gd",
	"arena": "res://scripts/main.gd",
	"hound": "res://scripts/foes/hound.gd",
	"slinger": "res://scripts/foes/slinger.gd",
	"scrap_brute": "res://scripts/foes/scrap_brute.gd",
	"shaman": "res://scripts/foes/shaman.gd",
	"bat": "res://scripts/foes/bat.gd",
	"foes": "res://scripts/highlands/foes.gd",
	"loot": "res://scripts/highlands/loot.gd",
	"loot_plan": "res://scripts/highlands/loot_plan.gd",
	"levels": "res://scripts/highlands/levels.gd",
	"folk": "res://scripts/highlands/folk.gd",
	"bag": "res://scripts/highlands/bag.gd",
	"gear": "res://scripts/highlands/gear.gd",
	"accessories": "res://scripts/highlands/accessories.gd",
	"rattlecrown": "res://scripts/foes/rattlecrown.gd",
	"crown": "res://scripts/highlands/crown.gd",
	"highlands": "res://scripts/highlands/highlands.gd",
	"charts": "res://scripts/highlands/charts.gd",
	"tools": "res://scripts/highlands/tools.gd",
	"world_gen": "res://scripts/highlands/world_gen.gd",
}

## How a number is shown and stepped:
##   "%"  a share (0.8 in the code is shown as 80%)
##   "s"  seconds
##   "d"  a distance in screen dots (the screen is 640 across)
##   "n"  a whole number
##   ""   a plain number (health, damage)
const UNITS := {
	"%": {"step": 0.05, "lo": 0.0, "hi": 10.0},
	"s": {"step": 0.05, "lo": 0.02, "hi": 120.0},
	"d": {"step": 5.0, "lo": 0.0, "hi": 3000.0},
	"n": {"step": 1.0, "lo": 1.0, "hi": 20.0},
	"": {"step": 1.0, "lo": 0.0, "hi": 100000.0},
}

const PAGES := ["All weapons", "Sword", "Bow", "Hammer", "Staff", "Sword runes", "Bow runes", "Hammer runes", "Staff runes", "Threads", "Players", "Enemies", "Highlands enemies", "Chests and loot", "Levelling", "Pip and the waystone", "Inventory and accessories", "Rattlecrown", "Forge guardian"]

## A line under a page's name, where one helps.
const PAGE_NOTES := {
	"All weapons": "A weapon's hit is its metal times its shape. Runes are shares of that hit.",
	"Sword": "Each shape is measured against the broadsword in the same metal.",
	"Bow": "Each bow is measured against the shortbow with the same arrows.",
	"Hammer": "Each head is measured against a broadsword in the same metal.",
	"Staff": "Each head is measured against the apprentice head with the same crystal.",
	"Sword runes": "A rune's damage is a share of one hit of the sword it sits on.",
	"Bow runes": "A rune's damage is a share of one arrow from the bow it sits on.",
	"Hammer runes": "A rune's damage is a share of one swing of the hammer it sits on.",
	"Staff runes": "A rune's damage is a share of one bolt from the staff it sits on.",
	"Threads": "The forge's sentences keep their own words for these (\"half strength\").",
	"Players": "Everyone gets the same numbers.",
	"Enemies": "Enemies already here keep the same share of their health.",
	"Highlands enemies": "The hounds and goblins of the Highlands. You can also put them in the arena: see Spawn.",
	"Chests and loot": "What chests hold and what enemies leave. Chest changes take hold when a world is next opened.",
	"Levelling": "The forge's levels, what falling costs, and the four signature perks of the role trees.",
	"Pip and the waystone": "Pip's cage and his prices, and what the Watchpost's waystone takes to mend.",
	"Inventory and accessories": "Until backpacks can be sewn, the first three numbers say what everybody carries.",
	"Rattlecrown": "The Highlands' boss, his Throne Room and his rewards. He is in the arena too: see Spawn.",
	"Forge guardian": "The tutorial cave's boss. You can also put him in the arena: see Spawn.",
}

## The search: other words people use for the lab's own. Typing the left one
## also finds the right ones.
const ALSO := {
	"hp": ["health"], "life": ["health"],
	"cooldown": ["recharge"], "cd": ["recharge"],
	"damage": ["power", "against", "what its", "one hit"],
	"dmg": ["damage", "power", "against", "what its", "one hit"],
	"boss": ["forge guardian", "rattlecrown"],
	"range": ["reach", "how far"], "distance": ["how far"], "radius": ["reach"],
	"duration": ["lasts", "stays"],
	"windup": ["warning", "time to draw"], "telegraph": ["warning"],
	"move": ["walking"], "movement": ["walking"],
	"attack": ["swing", "shooting", "casting"],
	"stun": ["stuns", "stunned"],
}

static var rows: Array = []        # every number the lab shows, in order
static var by_id := {}             # id -> its row
static var defaults := {}          # id -> the game's own number
static var changes := {}           # id -> the number set in the lab (only those that differ)
static var in_force := true        # false while an online game runs
static var file := "user://lab.json"
static var started := false        # the lab file has been read (the real game, not a test)


# --- The rows ----------------------------------------------------------------------

## One row. `at` is where the number lives: "script:NAME" for a number of its
## own, "script:TABLE/key/key" for one inside a table, or a list of those for a
## number kept in several places (they all get it). step, lo and hi come from the
## unit unless given.
static func _add(page: String, group: String, label: String, at, unit := "", step := -1.0, lo := -1.0, hi := -1.0, id := "") -> void:
	var places: Array = at if at is Array else [at]
	var u: Dictionary = UNITS[unit]
	var row := {"id": str(places[0]) if id == "" else id, "page": page, "group": group, "label": label, "at": places, "unit": unit,
		"step": float(u["step"]) if step < 0.0 else step, "lo": float(u["lo"]) if lo < 0.0 else lo, "hi": float(u["hi"]) if hi < 0.0 else hi}
	row["find"] = _find_words(row)
	rows.append(row)
	by_id[row["id"]] = row


## A rune's recharge (the forge's sentence follows it).
static func _recharge(page: String, group: String, rune: String) -> void:
	_add(page, group, "Recharge", "build:FITTINGS/%s/recharge" % rune, "s", 0.5, 0.5, 300.0)


## Every move whose `key` is `value` in the game's own numbers: the quick attacks
## all take one time and the finishers another, so one row sets them all.
static func _moves(key: String, value: float) -> Array:
	var out: Array = []
	var moves: Dictionary = load(SCRIPTS["player"]).get("MOVES")
	for m in moves:
		if is_equal_approx(float(moves[m].get(key, -1.0)), value):
			out.append("player:MOVES/%s/%s" % [m, key])
	return out


static func _build_rows() -> void:
	rows = []
	by_id = {}
	var p := "All weapons"
	var g := "Metal: one hit of a broadsword"
	_add(p, g, "Wood", "build:METALS/wood", "", 0.5, 0.5, 500.0)
	_add(p, g, "Tin", "build:METALS/tin", "", 0.5, 0.5, 500.0)
	_add(p, g, "Iron", "build:METALS/iron", "", 0.5, 0.5, 500.0)
	g = "The chain of three"
	_add(p, g, "The third hit, against a normal hit", _moves("power", 1.1), "%", 0.05, 0.5, 5.0, "chain_finisher")
	_add(p, g, "A quick attack takes", _moves("time", 0.36), "s", 0.01, 0.26, 1.0, "chain_light")
	_add(p, g, "A finisher takes", _moves("time", 0.45), "s", 0.01, 0.3, 1.5, "chain_heavy")
	g = "Crits"
	_add(p, g, "Crit chance", "build:BASE_CRIT", "%", 0.01, 0.0, 1.0)
	_add(p, g, "A crit, against a normal hit", "build:BASE_CRIT_DAMAGE", "%", 0.05, 1.0, 5.0)

	p = "Sword"
	g = "Every sword"
	_add(p, g, "A broadsword's reach", "player:BASE_REACH", "d", 1.0, 30.0, 250.0)
	_add(p, g, "Walking speed while swinging", "build:SWING_MOVE", "%", 0.05, 0.1, 1.5)
	for shape in ["dagger", "sabre", "broadsword", "rapier", "falchion", "greatsword"]:
		g = shape.capitalize()
		_add(p, g, "Damage", "build:SHAPES/%s/damage" % shape, "%", 0.05, 0.05, 5.0)
		_add(p, g, "Swing speed", "build:SHAPES/%s/speed" % shape, "%", 0.05, 0.2, 3.0)
		_add(p, g, "Reach", "build:SHAPES/%s/reach" % shape, "%", 0.05, 0.2, 3.0)
		if shape == "sabre":
			_add(p, g, "Extra crit chance", "build:SHAPES/sabre/crit", "%", 0.01, 0.0, 1.0)
		if shape in ["dagger", "greatsword"]:
			_add(p, g, "Walking speed while swinging", "build:SHAPES/%s/swing_move" % shape, "%", 0.05, 0.1, 1.5)

	p = "Bow"
	g = "Every bow"
	_add(p, g, "An arrow, against a sword hit in that metal", "build:BOW_DAMAGE", "%", 0.05, 0.05, 5.0)
	_add(p, g, "How far a shortbow's arrow flies", "build:BOW_RANGE", "d", 10.0, 100.0, 1500.0)
	_add(p, g, "How fast an arrow flies, a second", "build:BOW_FLIGHT", "d", 50.0, 300.0, 4000.0)
	_add(p, g, "Walking speed while shooting", "build:BOW_MOVE", "%", 0.05, 0.1, 1.5)
	_add(p, g, "Quick shot: time to draw", "player:MOVES/quick_shot/windup", "s", 0.01, 0.03, 0.25)
	_add(p, g, "Charged shot: time to charge", "player:MOVES/charged_shot/windup", "s", 0.01, 0.05, 0.56)
	_add(p, g, "Charged shot: how hard, in arrows", "player:MOVES/charged_shot/power", "%", 0.05, 0.5, 5.0)
	for shape in ["shortbow", "longbow"]:
		g = shape.capitalize()
		_add(p, g, "Damage", "build:BOW_SHAPES/%s/damage" % shape, "%", 0.05, 0.05, 5.0)
		_add(p, g, "Shooting speed", "build:BOW_SHAPES/%s/speed" % shape, "%", 0.05, 0.2, 3.0)
		_add(p, g, "How far its arrows fly", "build:BOW_SHAPES/%s/range" % shape, "%", 0.05, 0.2, 3.0)
	_add(p, "Longbow", "Walking speed while shooting", "build:BOW_SHAPES/longbow/swing_move", "%", 0.05, 0.1, 1.5)

	p = "Hammer"
	_add(p, "Every hammer", "How far a maul's slam reaches on the floor", "build:HAMMER_IMPACT", "d", 1.0, 10.0, 200.0)
	for shape in ["maul", "warhammer"]:
		g = shape.capitalize()
		_add(p, g, "Damage", "build:HAMMER_SHAPES/%s/damage" % shape, "%", 0.05, 0.05, 6.0)
		_add(p, g, "Swing speed", "build:HAMMER_SHAPES/%s/speed" % shape, "%", 0.05, 0.2, 3.0)
		_add(p, g, "Reach", "build:HAMMER_SHAPES/%s/reach" % shape, "%", 0.05, 0.2, 3.0)
		_add(p, g, "Size of its slam, against the maul's", "build:HAMMER_SHAPES/%s/impact" % shape, "%", 0.05, 0.2, 4.0)
		_add(p, g, "Walking speed while swinging", "build:HAMMER_SHAPES/%s/swing_move" % shape, "%", 0.05, 0.1, 1.5)

	p = "Staff"
	g = "Every staff"
	_add(p, g, "A bolt, against a sword hit in that tier", "build:STAFF_DAMAGE", "%", 0.05, 0.05, 5.0)
	_add(p, g, "How far a bolt flies", "build:STAFF_RANGE", "d", 10.0, 100.0, 1500.0)
	_add(p, g, "How fast a bolt flies, a second", "build:STAFF_FLIGHT", "d", 20.0, 200.0, 4000.0)
	_add(p, g, "Walking speed while casting", "build:STAFF_MOVE", "%", 0.05, 0.1, 1.5)
	_add(p, g, "A bolt's small splash reaches", "build:BOLT_SPLASH", "d", 1.0, 0.0, 100.0)
	_add(p, g, "How far a burst reaches where it lands", "build:BURST_RADIUS", "d", 2.0, 10.0, 300.0)
	_add(p, g, "Each spark of a spray, against a bolt", "build:SPRAY_DAMAGE", "%", 0.05, 0.05, 3.0)
	_add(p, g, "How far an orb reaches where it stops", "build:ORB_RADIUS", "d", 2.0, 10.0, 300.0)
	g = "Mana"
	_add(p, g, "Mana", "build:MANA", "", 5.0, 10.0, 1000.0)
	_add(p, g, "Mana back each second, always", "build:MANA_REGEN", "", 1.0, 0.0, 500.0)
	_add(p, g, "Rest this long without spending any...", "build:MANA_REST", "s", 0.05, 0.0, 10.0)
	_add(p, g, "...and this much more comes back a second", "build:MANA_REST_REGEN", "", 1.0, 0.0, 1000.0)
	_add(p, g, "A passive rune costs, each time", "build:PASSIVE_MANA", "", 0.5, 0.0, 200.0)
	_add(p, g, "A bolt costs", "build:CAST_MANA/bolt", "", 0.5, 0.0, 200.0)
	_add(p, g, "A burst costs", "build:CAST_MANA/burst", "", 0.5, 0.0, 200.0)
	_add(p, g, "A spray costs", "build:CAST_MANA/spray", "", 0.5, 0.0, 200.0)
	_add(p, g, "An orb costs", "build:CAST_MANA/orb", "", 0.5, 0.0, 200.0)
	_add(p, g, "Out of mana: a cast's damage", "build:MANA_WEAK", "%", 0.05, 0.0, 1.0)
	_add(p, g, "Out of mana: how fast you cast", "build:MANA_SLOW", "%", 0.05, 0.2, 1.0)
	for shape in ["apprentice", "storm"]:
		g = "%s head" % shape.capitalize()
		_add(p, g, "Damage", "build:STAFF_SHAPES/%s/damage" % shape, "%", 0.05, 0.05, 5.0)
		_add(p, g, "Casting speed", "build:STAFF_SHAPES/%s/speed" % shape, "%", 0.05, 0.2, 3.0)
		_add(p, g, "How far its bolts fly", "build:STAFF_SHAPES/%s/range" % shape, "%", 0.05, 0.2, 3.0)
		_add(p, g, "Spell size", "build:STAFF_SHAPES/%s/size" % shape, "%", 0.05, 0.2, 3.0)

	p = "Sword runes"
	_add(p, "Shockwave", "The wave, against a sword hit", "player:SHOCKWAVE_DAMAGE", "%")
	g = "Shards"
	_add(p, g, "Each shard, against a sword hit", "player:SHARD_DAMAGE", "%")
	_add(p, g, "Shards in a burst", "player:SHARD_COUNT", "n", 1.0, 1.0, 8.0)
	_add(p, g, "How far a shard flies", "player:SHARD_RANGE", "d", 5.0, 20.0, 600.0)
	_add(p, g, "How wide a burst fans out, in degrees", "player:SHARD_CONE", "n", 2.0, 0.0, 180.0)
	g = "Weak Point"
	_add(p, g, "The hit on a mark, against a normal hit", "player:WEAK_CRIT", "%", 0.1, 1.0, 10.0)
	_add(p, g, "A mark lasts", "enemy:WEAK_LIFE", "s", 0.5, 1.0, 60.0)
	g = "Whirlwind"
	_add(p, g, "Each turn, against a sword hit", "player:WHIRLWIND_DAMAGE", "%")
	_add(p, g, "Turns on a full meter", "build:FITTINGS/whirlwind/turns", "n", 1.0, 1.0, 12.0)
	_add(p, g, "One turn takes", "build:FITTINGS/whirlwind/turn", "s", 0.02, 0.1, 1.0)
	_recharge(p, g, "whirlwind")
	g = "Leap"
	_add(p, g, "The landing strike, against a sword hit", "player:LEAP_DAMAGE", "%")
	_add(p, g, "How far away the enemy can be", "player:LEAP_RANGE", "d", 10.0, 50.0, 1000.0)
	_add(p, g, "It stuns for", "player:LEAP_STUN", "s", 0.05, 0.0, 5.0)
	_recharge(p, g, "leap")
	g = "Ghostwield"
	_add(p, g, "A ghost swing, against the real swing", "build:GHOST_POWER", "%", 0.05, 0.05, 1.0)
	_add(p, g, "The ghost stays", "build:FITTINGS/ghostwield/time", "s", 1.0, 1.0, 120.0)
	_recharge(p, g, "ghostwield")

	p = "Bow runes"
	_add(p, "Pierce", "The most enemies one arrow goes through", "build:PIERCE_MAX", "n", 1.0, 1.0, 12.0)
	g = "Ricochet"
	_add(p, g, "A jump, against the arrow that hit", "build:RICOCHET_DAMAGE", "%")
	_add(p, g, "How far it jumps", "build:RICOCHET_RANGE", "d", 5.0, 20.0, 600.0)
	g = "Steady Aim"
	_add(p, g, "Shooting speed gained each second", "build:STEADY_RATE", "%", 0.01, 0.01, 2.0)
	_add(p, g, "The most it gives", "build:STEADY_CAP", "%", 0.05, 0.05, 3.0)
	_add(p, g, "Every Hit: each arrow that lands adds", "build:STEADY_HIT", "%", 0.01, 0.0, 1.0)
	g = "Volley"
	_add(p, g, "Each arrow, against a normal arrow", "build:VOLLEY_DAMAGE", "%")
	_recharge(p, g, "volley")
	g = "Snipe"
	_add(p, g, "Up close, against a normal arrow", "build:SNIPE_NEAR", "%", 0.1, 0.1, 20.0)
	_add(p, g, "From far away", "build:SNIPE_FAR", "%", 0.1, 0.1, 30.0)
	_add(p, g, "Far away is this far or more", "build:SNIPE_DISTANCE", "d", 10.0, 50.0, 1500.0)
	_add(p, g, "A perfect shot does this much more", "build:SNIPE_PERFECT", "%", 0.05, 1.0, 5.0)
	_add(p, g, "Let go too early and it does", "build:SNIPE_EARLY", "%", 0.05, 0.05, 1.0)
	_add(p, g, "Time to draw", "build:SNIPE_CHARGE", "s", 0.05, 0.1, 2.0)
	_recharge(p, g, "snipe")
	g = "Arrow Rain"
	_add(p, g, "Each hit, against a normal arrow", "build:RAIN_DAMAGE", "%")
	_add(p, g, "It hits every", "build:RAIN_TICK", "s", 0.05, 0.1, 2.0)
	_add(p, g, "It lasts", "build:FITTINGS/arrow_rain/time", "s", 0.5, 0.5, 30.0)
	_add(p, g, "How far away you can mark", "build:RAIN_REACH", "d", 10.0, 50.0, 1500.0)
	_recharge(p, g, "arrow_rain")

	p = "Hammer runes"
	g = "Momentum"
	_add(p, g, "Each step adds", "build:MOMENTUM_STEP", "%", 0.01, 0.01, 1.0)
	_add(p, g, "The most one step can be worth", "build:MOMENTUM_STEP_MAX", "%", 0.01, 0.01, 2.0)
	_add(p, g, "It holds this long without a hit", "build:MOMENTUM_HOLD", "s", 0.25, 0.25, 30.0)
	_add(p, g, "Then a step goes every", "build:MOMENTUM_DRAIN", "s", 0.05, 0.05, 10.0)
	g = "Stagger"
	_add(p, g, "Swings to fill the meter", "enemy:STAGGER_FULL", "", 0.5, 1.0, 30.0)
	_add(p, g, "A full meter stuns for", "build:STAGGER_STUN", "s", 0.1, 0.1, 10.0)
	_add(p, g, "The blow as it breaks, against a swing", "build:STAGGER_DAMAGE", "%")
	g = "Aftershock"
	_add(p, g, "The rumble, against a swing", "build:AFTERSHOCK_DAMAGE", "%")
	_add(p, g, "How far it reaches", "build:AFTERSHOCK_RADIUS", "d", 2.0, 10.0, 400.0)
	_add(p, g, "It comes this long after the finisher", "build:AFTERSHOCK_DELAY", "s", 0.05, 0.1, 3.0)
	_add(p, g, "It stuns for", "build:AFTERSHOCK_STUN", "s", 0.05, 0.0, 5.0)
	g = "Quake"
	_add(p, g, "The crack, against a swing", "build:QUAKE_DAMAGE", "%")
	_add(p, g, "How long the crack is", "build:QUAKE_RANGE", "d", 10.0, 50.0, 1000.0)
	_add(p, g, "How wide it is, to each side", "build:QUAKE_WIDTH", "d", 1.0, 2.0, 200.0)
	_add(p, g, "It stuns for", "build:QUAKE_STUN", "s", 0.05, 0.0, 5.0)
	_recharge(p, g, "quake")
	g = "Bulwark"
	_add(p, g, "It lasts", "build:FITTINGS/bulwark/time", "s", 0.5, 0.5, 60.0)
	_add(p, g, "Hits it takes before it breaks", "build:BULWARK_HITS", "n", 1.0, 1.0, 20.0)
	_add(p, g, "Broken, its burst stuns for", "build:BULWARK_STUN", "s", 0.1, 0.0, 10.0)
	_add(p, g, "How far its burst reaches", "build:BULWARK_BURST", "d", 5.0, 20.0, 400.0)
	_recharge(p, g, "bulwark")
	g = "Hook"
	_add(p, g, "The chain's bite, against a swing", "player:HOOK_DAMAGE", "%")
	_add(p, g, "How far away it takes hold", "player:HOOK_REACH", "d", 10.0, 60.0, 1000.0)
	_add(p, g, "The dragged enemy can't act for", "player:HOOK_STUN", "s", 0.05, 0.0, 5.0)
	_add(p, g, "Saved Up: extra stun when it arrives", "build:HOOK_SAVED_STUN", "s", 0.1, 0.0, 10.0)
	_add(p, g, "Too heavy to drag: pulls you this far", "player:HOOK_TUG", "d", 5.0, 0.0, 300.0)
	_recharge(p, g, "hook")

	p = "Staff runes"
	g = "Overflow"
	_add(p, g, "A bolt on full mana hits this much harder", "build:OVERFLOW_DAMAGE", "%", 0.05, 0.0, 5.0)
	_add(p, g, "...and is this much bigger", "build:OVERFLOW_SIZE", "%", 0.05, 0.0, 2.0)
	_add(p, g, "Every Hit: mana back for a bolt that lands", "build:OVERFLOW_REFUND", "", 0.5, 0.0, 100.0)
	_add(p, g, "Saved Up: seconds on full mana for a blast", "build:OVERFLOW_CHARGE", "s", 0.5, 0.5, 30.0)
	_add(p, g, "On Dodge: mana back for a dodge", "build:OVERFLOW_DODGE_MANA", "", 1.0, 0.0, 200.0)
	g = "Orbit"
	_add(p, g, "An orb's strike, against a bolt", "build:ORBIT_DAMAGE", "%")
	_add(p, g, "Orbs at once", "build:ORBIT_MAX", "n", 1.0, 1.0, 9.0)
	_add(p, g, "An orb waits", "build:ORBIT_TIME", "s", 0.5, 1.0, 120.0)
	_add(p, g, "How near an enemy must come", "build:ORBIT_REACH", "d", 2.0, 20.0, 400.0)
	g = "Chain"
	_add(p, g, "Enemies the lightning goes on to", "build:CHAIN_JUMPS", "n", 1.0, 1.0, 9.0)
	_add(p, g, "Each jump, against a bolt", "build:CHAIN_DAMAGE", "%")
	_add(p, g, "How far a jump reaches", "build:CHAIN_RANGE", "d", 5.0, 20.0, 600.0)
	g = "Nova"
	_add(p, g, "The ring, against a bolt", "build:NOVA_DAMAGE", "%")
	_add(p, g, "How far the ring reaches", "build:NOVA_RADIUS", "d", 5.0, 20.0, 600.0)
	_add(p, g, "How hard it shoves", "build:NOVA_KNOCK", "", 10.0, 0.0, 2000.0)
	_add(p, g, "It stuns for", "build:NOVA_STUN", "s", 0.05, 0.0, 5.0)
	_add(p, g, "It costs, in mana", "build:RUNE_MANA/nova", "", 1.0, 0.0, 500.0)
	_recharge(p, g, "nova")
	g = "Lance"
	_add(p, g, "A pulse at first strength, against a bolt", "build:LANCE_DAMAGE", "%")
	_add(p, g, "Each pulse costs, in mana", "build:RUNE_MANA/lance", "", 0.5, 0.5, 200.0)
	_add(p, g, "One pulse takes", "build:FITTINGS/lance/turn", "s", 0.01, 0.05, 1.0)
	_add(p, g, "Walking speed while you hold it", "build:LANCE_MOVE", "%", 0.05, 0.0, 1.5)
	_recharge(p, g, "lance")
	g = "Spectre"
	_add(p, g, "The ghost's copy, against the real attack", "build:SPECTRE_POWER", "%", 0.05, 0.05, 1.0)
	_add(p, g, "The ghost stays", "build:FITTINGS/spectre/time", "s", 0.5, 1.0, 120.0)
	_add(p, g, "It costs, in mana", "build:RUNE_MANA/spectre", "", 1.0, 0.0, 500.0)
	_recharge(p, g, "spectre")

	p = "Threads"
	g = "Twice"
	_add(p, g, "The most times one rune can fire", "build:MAX_COUNT", "n", 1.0, 2.0, 6.0)
	g = "Wider"
	_add(p, g, "One thread: the rune's size", "build:WIDER_STEPS/0", "%", 0.05, 1.0, 4.0)
	_add(p, g, "Two threads", "build:WIDER_STEPS/1", "%", 0.05, 1.0, 4.0)
	_add(p, g, "Three threads", "build:WIDER_STEPS/2", "%", 0.05, 1.0, 4.0)
	_add(p, g, "The biggest a rune can get", "build:MAX_SIZE", "%", 0.05, 1.0, 4.0)
	g = "Every Hit"
	_add(p, g, "A passive rune, on every hit, is this strong", "build:EVERY_HIT_POWER", "%", 0.05, 0.05, 0.95)
	_add(p, g, "An active rune: each hit recharges it by", "build:EVERY_HIT_REFUND", "s", 0.05, 0.05, 10.0)
	g = "On Dodge"
	_add(p, g, "A dodge's Volley or Snipe, against a press", "build:DODGE_SHARE", "%", 0.05, 0.05, 2.0)

	p = "Players"
	g = "Health"
	_add(p, g, "Health", "player:MAX_HP", "", 5.0, 5.0, 5000.0)
	g = "Moving"
	_add(p, g, "Walking speed", "player:MOVE_SPEED", "d", 5.0, 60.0, 800.0)
	g = "Dodge"
	_add(p, g, "Dodge speed", "player:DODGE_SPEED", "d", 10.0, 200.0, 2500.0)
	_add(p, g, "A dodge lasts", "player:DODGE_TIME", "s", 0.01, 0.05, 1.0)
	_add(p, g, "Dodges in a row", "player:DODGE_MAX_CHARGES", "n", 1.0, 1.0, 6.0)
	_add(p, g, "A dodge comes back in", "player:DODGE_REFILL", "s", 0.05, 0.05, 10.0)
	g = "In the Highlands"
	_add(p, g, "How big the player is drawn (and their reach)", "highlands:PLAYER_SIZE", "%", 0.05, 0.4, 1.5)
	_add(p, g, "Walking speed, as a share of the above", "highlands:PLAYER_PACE", "%", 0.05, 0.3, 2.0)
	_add(p, g, "The squad's blows do", "highlands:DAMAGE_DEALT", "%", 0.05, 0.1, 3.0)
	_add(p, g, "Enemies' blows, traps and falls do", "highlands:DAMAGE_TAKEN", "%", 0.05, 0.1, 3.0)
	_add(p, g, "Show the whole map, click it to go (1 = on)", "charts:LAB_MAP", "n", 1.0, 0.0, 1.0)
	_add(p, g, "Pine groves in new worlds (0 = none)", "world_gen:GROVES", "", 0.25, 0.0, 10.0)
	g = "Tools (blows of a basic tool)"
	_add(p, g, "Rock", "tools:NEED/rock", "n", 1.0, 1.0, 20.0)
	_add(p, g, "Tin", "tools:NEED/tin", "n", 1.0, 1.0, 20.0)
	_add(p, g, "Copper", "tools:NEED/copper", "n", 1.0, 1.0, 20.0)
	_add(p, g, "A boulder", "tools:NEED/boulder", "n", 1.0, 1.0, 20.0)
	_add(p, g, "A pine", "tools:NEED/pine", "n", 1.0, 1.0, 20.0)
	_add(p, g, "One blow of a basic tool counts as", "tools:POWER/basic", "", 0.25, 0.25, 10.0)
	_add(p, g, "One blow of a bronze tool (none yet)", "tools:POWER/bronze", "", 0.25, 0.25, 10.0)

	p = "Enemies"
	g = "The arena"
	_add(p, g, "A new enemy arrives every", "arena:SPAWN_EVERY", "s", 0.1, 0.2, 60.0)
	_add(p, g, "The most at once (one player)", "arena:MAX_ENEMIES", "n", 1.0, 1.0, 60.0)
	for kind in [["slime", "Small crab"], ["charger", "Horned crab"], ["brute", "Big crab"]]:
		g = kind[1]
		_add(p, g, "Health", "enemy:STATS/%s/hp" % kind[0], "", 1.0, 1.0, 10000.0)
		_add(p, g, "Walking speed", "enemy:STATS/%s/speed" % kind[0], "d", 5.0, 0.0, 600.0)
		_add(p, g, "What its touch does", "enemy:STATS/%s/damage" % kind[0], "", 1.0, 0.0, 1000.0)
	g = "Cave crawler"
	_add(p, g, "Health", "crawler:HP", "", 1.0, 1.0, 10000.0)
	_add(p, g, "Walking speed", "crawler:SPEED", "d", 5.0, 0.0, 600.0)
	_add(p, g, "What its bite does", "crawler:BITE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Warning before it bites", "crawler:REAR_TIME", "s", 0.05, 0.1, 5.0)
	g = "Cave burrower"
	_add(p, g, "Health", "burrower:HP", "", 1.0, 1.0, 10000.0)
	_add(p, g, "Speed underground", "burrower:SPEED", "d", 5.0, 0.0, 600.0)
	_add(p, g, "What its lunge does", "burrower:LUNGE_DAMAGE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Lunge speed", "burrower:LUNGE_SPEED", "d", 10.0, 100.0, 2000.0)
	_add(p, g, "Warning before it lunges", "burrower:WARN_TIME", "s", 0.05, 0.25, 5.0)
	_add(p, g, "Stunned after a miss for", "burrower:STUN_MISS", "s", 0.1, 0.0, 10.0)

	p = "Highlands enemies"
	g = "Cliff Hound"
	_add(p, g, "Health", "hound:HP", "", 1.0, 1.0, 10000.0)
	_add(p, g, "Circling speed", "hound:SPEED", "d", 5.0, 0.0, 600.0)
	_add(p, g, "Running speed", "hound:RUN", "d", 5.0, 0.0, 600.0)
	_add(p, g, "What its bite does", "hound:BITE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Warning before it lunges", "hound:CROUCH_TIME", "s", 0.05, 0.2, 5.0)
	_add(p, g, "Lunge speed", "hound:LUNGE_SPEED", "d", 10.0, 100.0, 2000.0)
	_add(p, g, "How far it lunges", "hound:LUNGE_DIST", "d", 5.0, 50.0, 800.0)
	_add(p, g, "Shortest wait between lunges", "hound:REST_MIN", "s", 0.1, 0.2, 20.0)
	_add(p, g, "Longest wait between lunges", "hound:REST_MAX", "s", 0.1, 0.2, 20.0)
	g = "Elite hound (the pack leader)"
	_add(p, g, "Health", "hound:ELITE_HP", "", 1.0, 1.0, 10000.0)
	_add(p, g, "What its bite does", "hound:ELITE_BITE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "It howls every", "hound:HOWL_EVERY", "s", 0.5, 2.0, 120.0)
	_add(p, g, "The howl takes (hit it to cut it off)", "hound:HOWL_TIME", "s", 0.05, 0.3, 5.0)
	_add(p, g, "Hounds that answer a howl", "hound:HOWL_CALLS", "n", 1.0, 1.0, 6.0)
	_add(p, g, "Howls in one fight", "hound:HOWL_MOST", "n", 1.0, 1.0, 20.0)
	g = "Pebble Slinger"
	_add(p, g, "Health", "slinger:HP", "", 1.0, 1.0, 10000.0)
	_add(p, g, "Walking speed", "slinger:SPEED", "d", 5.0, 0.0, 600.0)
	_add(p, g, "Speed backing away", "slinger:FLEE", "d", 5.0, 0.0, 600.0)
	_add(p, g, "What a pebble does", "slinger:PEBBLE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Warning before it throws", "slinger:WINDUP", "s", 0.05, 0.2, 5.0)
	_add(p, g, "A pebble is in the air for", "slinger:FLIGHT", "s", 0.05, 0.2, 5.0)
	_add(p, g, "Shortest wait between throws", "slinger:RELOAD_MIN", "s", 0.1, 0.2, 20.0)
	_add(p, g, "Longest wait between throws", "slinger:RELOAD_MAX", "s", 0.1, 0.2, 20.0)
	_add(p, g, "It backs away when you are within", "slinger:NEAR", "d", 5.0, 0.0, 600.0)
	g = "Elite slinger"
	_add(p, g, "Health", "slinger:ELITE_HP", "", 1.0, 1.0, 10000.0)
	_add(p, g, "What its rock does", "slinger:ELITE_ROCK", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Warning before it throws", "slinger:ELITE_WINDUP", "s", 0.05, 0.2, 5.0)
	_add(p, g, "The rock is in the air for", "slinger:ELITE_FLIGHT", "s", 0.05, 0.2, 5.0)
	_add(p, g, "Shards from a burst rock", "slinger:SHARDS", "n", 1.0, 1.0, 16.0)
	_add(p, g, "What a shard does", "slinger:SHARD_DAMAGE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "How far a shard flies", "slinger:SHARD_REACH", "d", 5.0, 20.0, 600.0)
	g = "Scrap Brute"
	_add(p, g, "Health", "scrap_brute:HP", "", 1.0, 1.0, 10000.0)
	_add(p, g, "Walking speed", "scrap_brute:SPEED", "d", 2.0, 0.0, 600.0)
	_add(p, g, "What its swing does", "scrap_brute:CLUB", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Warning before it swings", "scrap_brute:WINDUP", "s", 0.05, 0.2, 5.0)
	_add(p, g, "Open after a swing for (your time to hit it)", "scrap_brute:OPEN", "s", 0.05, 0.2, 10.0)
	_add(p, g, "How far its swing reaches", "scrap_brute:REACH", "d", 2.0, 20.0, 300.0)
	g = "Elite brute"
	_add(p, g, "Health", "scrap_brute:ELITE_HP", "", 1.0, 1.0, 10000.0)
	_add(p, g, "What its swing does", "scrap_brute:ELITE_CLUB", "", 1.0, 0.0, 1000.0)
	_add(p, g, "A shield bash every so many attacks", "scrap_brute:BASH_EVERY", "n", 1.0, 2.0, 10.0)
	_add(p, g, "What the bash does", "scrap_brute:BASH", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Warning before the bash", "scrap_brute:BASH_WINDUP", "s", 0.05, 0.2, 5.0)
	_add(p, g, "How hard the bash throws you back", "scrap_brute:BASH_PUSH", "d", 10.0, 0.0, 2000.0)
	g = "Goblin Shaman"
	_add(p, g, "Health", "shaman:HP", "", 1.0, 1.0, 10000.0)
	_add(p, g, "Walking speed", "shaman:SPEED", "d", 5.0, 0.0, 600.0)
	_add(p, g, "The staff is up before a bat comes for", "shaman:CAST_TIME", "s", 0.05, 0.2, 5.0)
	_add(p, g, "It calls a bat every", "shaman:CAST_EVERY", "s", 0.5, 1.0, 60.0)
	_add(p, g, "The most bats it keeps", "shaman:BATS", "n", 1.0, 1.0, 20.0)
	g = "Elite shaman"
	_add(p, g, "Health", "shaman:ELITE_HP", "", 1.0, 1.0, 10000.0)
	_add(p, g, "The most bats it keeps", "shaman:ELITE_BATS", "n", 1.0, 1.0, 20.0)
	_add(p, g, "Bats in one call", "shaman:ELITE_A_CAST", "n", 1.0, 1.0, 6.0)
	_add(p, g, "It wards a goblin every", "shaman:WARD_EVERY", "s", 0.5, 2.0, 120.0)
	_add(p, g, "A warded goblin cannot be hurt for", "shaman:WARD_TIME", "s", 0.1, 0.5, 30.0)
	g = "Bat"
	_add(p, g, "Health", "bat:HP", "", 1.0, 1.0, 10000.0)
	_add(p, g, "What its nip does", "bat:NIP", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Swooping speed", "bat:DIVE_SPEED", "d", 10.0, 50.0, 2000.0)
	_add(p, g, "Shortest wait between swoops", "bat:REST_MIN", "s", 0.1, 0.2, 20.0)
	_add(p, g, "Longest wait between swoops", "bat:REST_MAX", "s", 0.1, 0.2, 20.0)
	g = "On the land"
	_add(p, g, "A killed enemy is back after (with nobody near)", "foes:BACK_AFTER", "s", 10.0, 2.0, 3600.0)

	p = "Chests and loot"
	g = "Chests"
	_add(p, g, "Places with enemies that have a chest", "loot_plan:GUARDED_SHARE", "%", 0.01, 0.0, 1.0)
	_add(p, g, "Empty places that have a chest", "loot_plan:EMPTY_SHARE", "%", 0.01, 0.0, 1.0)
	_add(p, g, "Sealed places that have a chest", "loot_plan:SEALED_SHARE", "%", 0.05, 0.0, 1.0)
	_add(p, g, "Chests that hold a passive blank", "loot_plan:BLANK", "%", 0.01, 0.0, 1.0)
	_add(p, g, "Fewest coins in a chest", "loot_plan:COINS_MIN", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Most coins in a chest", "loot_plan:COINS_MAX", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Fewest bars in a chest", "loot_plan:BARS_MIN", "n", 1.0, 1.0, 20.0)
	_add(p, g, "Most bars in a chest", "loot_plan:BARS_MAX", "n", 1.0, 1.0, 20.0)
	_add(p, g, "Memory in a chest", "loot_plan:MEMORY", "", 1.0, 0.0, 10000.0)
	_add(p, g, "A sealed or named place's chest holds", "loot_plan:RICH", "%", 0.1, 1.0, 10.0)
	_add(p, g, "The first chest, by the cave, holds", "loot_plan:FIRST", "%", 0.05, 0.1, 2.0)
	g = "Memory for a kill"
	_add(p, g, "Cliff Hound", "loot:MEMORY_FOR/hound", "", 1.0, 0.0, 10000.0)
	_add(p, g, "Pebble Slinger", "loot:MEMORY_FOR/slinger", "", 1.0, 0.0, 10000.0)
	_add(p, g, "Scrap Brute", "loot:MEMORY_FOR/scrap_brute", "", 1.0, 0.0, 10000.0)
	_add(p, g, "Goblin Shaman", "loot:MEMORY_FOR/shaman", "", 1.0, 0.0, 10000.0)
	_add(p, g, "Any elite", "loot:ELITE_MEMORY", "", 1.0, 0.0, 10000.0)
	g = "What an elite leaves"
	_add(p, g, "Fewest coins", "loot:ELITE_COINS_MIN", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Most coins", "loot:ELITE_COINS_MAX", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Fewest bars", "loot:ELITE_BARS_MIN", "n", 1.0, 1.0, 20.0)
	_add(p, g, "Most bars", "loot:ELITE_BARS_MAX", "n", 1.0, 1.0, 20.0)
	g = "Memory for work"
	_add(p, g, "A tile of tin ore mined", "loot:WORK_MEMORY/tin_ore", "", 1.0, 0.0, 1000.0)
	_add(p, g, "A tile of copper ore mined", "loot:WORK_MEMORY/copper_ore", "", 1.0, 0.0, 1000.0)
	_add(p, g, "A pine felled", "loot:WORK_MEMORY/wood", "", 1.0, 0.0, 1000.0)

	p = "Levelling"
	g = "The forge's levels"
	_add(p, g, "Memory from each player for level 1", "levels:FIRST_LEVEL", "", 10.0, 10.0, 100000.0)
	_add(p, g, "Every level after it needs this much more", "levels:LEVEL_STEP", "", 10.0, 0.0, 100000.0)
	_add(p, g, "The highest level", "levels:LEVEL_CAP", "n", 1.0, 1.0, 99.0)
	_add(p, g, "Forgetting your perks costs, a perk", "levels:FORGET_COST", "", 5.0, 0.0, 10000.0)
	g = "Falling"
	_add(p, g, "Carried Memory left where you fell", "levels:FALL_MEMORY", "%", 0.05, 0.0, 1.0)
	_add(p, g, "Coins lost for good", "levels:FALL_COINS", "%", 0.05, 0.0, 1.0)
	g = "Challenge (Warden)"
	_add(p, g, "An enemy stays Challenged for", "levels:CHALLENGE_TIME", "s", 0.5, 0.5, 60.0)
	_add(p, g, "A boss stays Challenged for", "levels:CHALLENGE_BOSS_TIME", "s", 0.5, 0.5, 60.0)
	_add(p, g, "Then a boss cannot be Challenged for", "levels:CHALLENGE_BOSS_REST", "s", 0.5, 0.0, 120.0)
	_add(p, g, "Its hits on the challenger do this much less", "levels:CHALLENGE_SOFTEN", "%", 0.05, 0.0, 1.0)
	g = "Punish (Striker): how long an enemy is Open"
	_add(p, g, "A Pebble Slinger whose pebble hit nobody", "slinger:MISS_OPEN", "s", 0.1, 0.1, 10.0)
	g = "Kindle (Mender)"
	_add(p, g, "A Spark at most every", "levels:SPARK_EVERY", "s", 0.5, 0.0, 60.0)
	_add(p, g, "A Spark heals this share of your health", "levels:SPARK_HEAL", "%", 0.05, 0.0, 1.0)
	_add(p, g, "A Spark lasts", "levels:SPARK_LIFE", "s", 0.5, 2.5, 120.0)
	g = "Ore Sense (Delver)"
	_add(p, g, "How far it sees, in tiles", "levels:ORE_SENSE_TILES", "", 1.0, 1.0, 40.0)

	p = "Pip and the waystone"
	g = "Pip"
	_add(p, g, "Blows to break his cage", "folk:CAGE_BLOWS", "n", 1.0, 1.0, 20.0)
	_add(p, g, "A tin bar costs, in coins", "folk:TIN_PRICE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "A copper bar costs, in coins", "folk:COPPER_PRICE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "His accessory costs, in coins", "folk:ACCESSORY_PRICE", "", 1.0, 0.0, 10000.0)
	_add(p, g, "Smoke at the screen's edge: puffs (0 none)", "folk:SMOKE_SIGN", "n", 1.0, 0.0, 10.0)
	g = "The waystone"
	_add(p, g, "Copper bars to mend it", "folk:REPAIR_COPPER", "n", 1.0, 1.0, 99.0)

	p = "Inventory and accessories"
	g = "What everybody carries"
	_add(p, g, "Backpack: 0 none, 1 Hide, 2 Leather, 3 Large", "bag:LAB_PACK", "n", 1.0, 0.0, 3.0)
	_add(p, g, "Satchel: 0 the first, 1 Hide, 2 Leather, 3 Large", "gear:LAB_SATCHEL", "n", 1.0, 0.0, 3.0)
	_add(p, g, "Give everyone every accessory: 1 is yes", "gear:LAB_GIVE", "n", 1.0, 0.0, 1.0)
	g = "Finding accessories"
	_add(p, g, "An ordinary chest holds one", "loot_plan:GIFT", "%", 0.05, 0.0, 1.0)
	_add(p, g, "A sealed or named place's chest holds one", "loot_plan:RICH_GIFT", "%", 0.05, 0.0, 1.0)
	_add(p, g, "An elite leaves one", "loot:ELITE_GIFT", "%", 0.05, 0.0, 1.0)
	_add(p, g, "Coins for one you already have", "loot:GIFT_COINS", "", 1.0, 0.0, 1000.0)
	g = "What they do"
	_add(p, g, "Tinker's Thimble: your dodge comes back at", "accessories:THIMBLE_DODGE", "%", 0.05, 1.0, 5.0)
	_add(p, g, "Hearthstone Pebble: time out of the fight", "accessories:PEBBLE_WAIT", "s", 0.5, 0.5, 60.0)
	_add(p, g, "Hearthstone Pebble: health back each second", "accessories:PEBBLE_HEAL", "%", 0.01, 0.0, 1.0)
	_add(p, g, "Ashen Locket: Memory left where you fell", "accessories:LOCKET_SHARE", "%", 0.05, 0.0, 1.0)
	_add(p, g, "Lucky Copper: coins from chests and elites", "accessories:LUCKY_COINS", "%", 0.05, 1.0, 5.0)
	_add(p, g, "Banner Pin: taken off every hit", "accessories:PIN_SOFTEN", "%", 0.01, 0.0, 1.0)
	_add(p, g, "Banner Pin: how near a teammate must be", "accessories:PIN_REACH", "d", 10.0, 0.0, 3000.0)
	_add(p, g, "Thorn Charm: the hit it gives back", "accessories:THORN_DAMAGE", "", 0.5, 0.0, 1000.0)
	_add(p, g, "Thorn Charm: how near the enemy must be", "accessories:THORN_REACH", "d", 2.0, 0.0, 1000.0)
	_add(p, g, "Iron Bracer: how far a hit still throws you", "accessories:BRACER_KNOCK", "%", 0.05, 0.0, 1.0)
	_add(p, g, "Prospector's Sieve: chance of one more ore", "accessories:SIEVE_CHANCE", "%", 0.05, 0.0, 1.0)
	_add(p, g, "Bandolier: active runes come back at", "accessories:BANDOLIER_RUNES", "%", 0.05, 1.0, 5.0)
	_add(p, g, "Field Rations: your health is", "accessories:RATIONS_HEALTH", "%", 0.05, 1.0, 5.0)

	p = "Rattlecrown"
	g = "The Scrap King"
	_add(p, g, "Health (one player)", "rattlecrown:HP", "", 5.0, 5.0, 100000.0)
	_add(p, g, "Each extra player adds", "rattlecrown:HP_PER_PLAYER", "%", 0.05, 0.0, 5.0)
	_add(p, g, "Walking speed", "rattlecrown:SPEED", "d", 2.0, 0.0, 400.0)
	_add(p, g, "The crown goes on at this much health", "rattlecrown:CROWN_AT", "%", 0.05, 0.0, 1.0)
	_add(p, g, "Rest after an attack (your time to hit him)", "rattlecrown:REST", "s", 0.05, 0.1, 10.0)
	g = "Club Slam"
	_add(p, g, "What it does", "rattlecrown:SLAM", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Warning before it lands", "rattlecrown:SLAM_WINDUP", "s", 0.05, 0.3, 5.0)
	g = "Scrap Toss"
	_add(p, g, "What it does", "rattlecrown:TOSS", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Warning before he throws", "rattlecrown:TOSS_WINDUP", "s", 0.05, 0.2, 5.0)
	_add(p, g, "The scrap is in the air for", "rattlecrown:TOSS_FLIGHT", "s", 0.05, 0.3, 5.0)
	g = "Charge"
	_add(p, g, "What it does", "rattlecrown:CHARGE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Warning before he runs", "rattlecrown:CHARGE_WINDUP", "s", 0.05, 0.4, 5.0)
	_add(p, g, "How fast he runs", "rattlecrown:CHARGE_SPEED", "d", 10.0, 100.0, 2000.0)
	_add(p, g, "How far he runs", "rattlecrown:CHARGE_DIST", "d", 10.0, 100.0, 1000.0)
	g = "Crowned: every attack twice"
	_add(p, g, "The wait before the second go", "rattlecrown:AGAIN", "s", 0.05, 0.1, 3.0)
	_add(p, g, "Second warning, as a share of the first", "rattlecrown:SECOND", "%", 0.05, 0.4, 1.5)
	g = "The Throne Room"
	_add(p, g, "The fight ends with nobody in it for", "crown:RESET_AFTER", "s", 0.5, 1.0, 60.0)
	_add(p, g, "What a spike trap does", "crown:SPIKES", "", 1.0, 0.0, 1000.0)
	_add(p, g, "A spike trap rattles first for", "crown:SPIKE_WARN", "s", 0.05, 0.1, 5.0)
	_add(p, g, "Its spikes stay up for", "crown:SPIKE_UP", "s", 0.1, 0.2, 10.0)
	g = "The horn, and what he gives"
	_add(p, g, "Tin bars to mend the horn", "crown:MEND_TIN", "n", 1.0, 0.0, 99.0)
	_add(p, g, "Copper bars to mend the horn", "crown:MEND_COPPER", "n", 1.0, 0.0, 99.0)
	_add(p, g, "First win: Memory", "crown:FIRST_MEMORY", "", 5.0, 0.0, 100000.0)
	_add(p, g, "First win: coins", "crown:FIRST_COINS", "", 5.0, 0.0, 100000.0)
	_add(p, g, "First win: bars of tin, and of copper", "crown:FIRST_BARS", "n", 1.0, 0.0, 99.0)
	_add(p, g, "A later win: Memory", "crown:AGAIN_MEMORY", "", 5.0, 0.0, 100000.0)
	_add(p, g, "A later win: coins", "crown:AGAIN_COINS", "", 5.0, 0.0, 100000.0)
	_add(p, g, "A later win: bars of tin, and of copper", "crown:AGAIN_BARS", "n", 1.0, 0.0, 99.0)

	p = "Forge guardian"
	g = "Body"
	_add(p, g, "Health (one player)", "guardian:HP", "", 5.0, 5.0, 100000.0)
	_add(p, g, "Each extra player adds", "guardian:HP_PER_PLAYER", "%", 0.05, 0.0, 5.0)
	_add(p, g, "Walking speed", "guardian:SPEED", "d", 2.0, 0.0, 400.0)
	_add(p, g, "Rest after an attack (your time to hit him)", "guardian:REST", "s", 0.05, 0.1, 10.0)
	_add(p, g, "Below half health his waits shrink to", "guardian:RAGE_PACE", "%", 0.05, 0.3, 1.5)
	g = "Slam"
	_add(p, g, "Damage", "guardian:SLAM_DAMAGE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "How far it reaches", "guardian:SLAM_RADIUS", "d", 2.0, 20.0, 400.0)
	_add(p, g, "Warning before it lands", "guardian:SLAM_WINDUP", "s", 0.05, 0.2, 5.0)
	g = "Charge"
	_add(p, g, "Damage", "guardian:CHARGE_DAMAGE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Speed", "guardian:CHARGE_SPEED", "d", 10.0, 100.0, 2000.0)
	_add(p, g, "Warning before he runs", "guardian:CHARGE_WINDUP", "s", 0.05, 0.5, 5.0)
	g = "Quake"
	_add(p, g, "Damage", "guardian:QUAKE_DAMAGE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Warning before the cracks", "guardian:QUAKE_WINDUP", "s", 0.05, 0.2, 5.0)
	g = "Rockfall"
	_add(p, g, "Each rock's damage", "guardian:ROCK_DAMAGE", "", 1.0, 0.0, 1000.0)
	_add(p, g, "Warning before each rock", "guardian:ROCK_WINDUP", "s", 0.05, 0.2, 5.0)
	_add(p, g, "Time between rocks", "guardian:ROCK_GAP", "s", 0.02, 0.1, 5.0)


# --- Reading and writing the game's numbers --------------------------------------------

## The table (or script) that holds the number, and its key there.
static func _holder(place: String) -> Array:
	var parts := place.split(":")
	var script: GDScript = load(SCRIPTS[parts[0]])
	var path := parts[1].split("/")
	if path.size() == 1:
		return [script, path[0]]
	var holder = script.get(path[0])
	for i in range(1, path.size() - 1):
		holder = holder[_key(holder, path[i])]
	return [holder, _key(holder, path[path.size() - 1])]


static func _key(holder, key: String):
	return int(key) if holder is Array else key


static func _read(place: String):
	var h := _holder(place)
	if h[0] is GDScript:
		return (h[0] as GDScript).get(h[1])
	return h[0][h[1]]


## Writes it as the kind of number the game keeps there (whole or not).
static func _write(place: String, v: float) -> void:
	var h := _holder(place)
	var whole: bool = _read(place) is int
	var value = roundi(v) if whole else v
	if h[0] is GDScript:
		(h[0] as GDScript).set(h[1], value)
	else:
		h[0][h[1]] = value


# --- The lab's own numbers --------------------------------------------------------------

## Builds the rows and notes the game's own numbers. Safe to call again.
static func setup() -> void:
	if not rows.is_empty():
		return
	_build_rows()
	defaults = {}
	for row in rows:
		defaults[row["id"]] = float(_read(row["at"][0]))


## The real game calls this once as it starts: reads this computer's lab file
## and puts its numbers in force.
static func start() -> void:
	setup()
	if started:
		return
	started = true
	load_file()
	_apply_all()


## The words a number can be found by: its page, group and name, and its place
## in the code ("SLAM_DAMAGE" gives "slam damage"), all in small letters. A
## number kept in several places (the chain's times sit in every shape's moves)
## goes by its page, group and name alone, or "dagger" would find it.
static func _find_words(row: Dictionary) -> String:
	var text := "%s %s %s" % [row["page"], row["group"], row["label"]]
	if (row["at"] as Array).size() == 1:
		text += " " + str(row["at"][0]).get_slice(":", 1).replace("_", " ").replace("/", " ")
	return text.to_lower()


## The search: every number that holds every word typed, in the lab's own order.
## A word also counts through ALSO ("cooldown" finds Recharge) and without a
## last "s" ("crabs" finds crab). Nothing typed finds nothing.
static func find(text: String) -> Array:
	setup()
	var found: Array = []
	var words := text.to_lower().split(" ", false)
	if words.is_empty():
		return found
	for row in rows:
		var all := true
		for word in words:
			var tries: Array = [word]
			tries.append_array(ALSO.get(word, []))
			if word.length() > 3 and word.ends_with("s"):
				tries.append(word.left(-1))
			var any := false
			for t in tries:
				if (row["find"] as String).contains(str(t)):
					any = true
					break
			if not any:
				all = false
				break
		if all:
			found.append(row)
	return found


## What the lab holds for this number: the change, or the game's own.
static func value(id: String) -> float:
	setup()
	return float(changes.get(id, defaults[id]))


static func is_changed(id: String) -> bool:
	return changes.has(id)


static func changed_count() -> int:
	return changes.size()


## How many of a page's numbers are changed.
static func changed_on(page: String) -> int:
	var n := 0
	for id in changes:
		if by_id.has(id) and by_id[id]["page"] == page:
			n += 1
	return n


## Sets a number: kept inside its limits and on its step's grid, written into the
## game (unless an online game is running) and saved.
static func set_value(id: String, v: float, save_now := true) -> void:
	setup()
	var row: Dictionary = by_id[id]
	v = clampf(v, float(row["lo"]), float(row["hi"]))
	v = roundf(v) if row["unit"] == "n" else snappedf(v, 0.0001)
	if is_equal_approx(v, float(defaults[id])):
		changes.erase(id)
		v = float(defaults[id])
	else:
		changes[id] = v
	if in_force:
		for place in row["at"]:
			_write(place, v)
	if save_now:
		save()


## One step up (+1) or down (-1); `big` is five steps.
static func nudge(id: String, way: int, big := false) -> void:
	var row: Dictionary = by_id[id]
	var step := float(row["step"]) * (5.0 if big else 1.0)
	set_value(id, snappedf(value(id) + step * float(way), float(row["step"]) if float(row["step"]) < 1.0 else 0.0001))


static func reset(id: String) -> void:
	set_value(id, float(defaults[id]))


static func reset_page(page: String) -> void:
	for row in rows:
		if row["page"] == page and changes.has(row["id"]):
			set_value(row["id"], float(defaults[row["id"]]), false)
	save()


## Back to the game's own for these numbers (what a search is showing).
static func reset_these(ids: Array) -> void:
	for id in ids:
		if changes.has(id):
			set_value(str(id), float(defaults[id]), false)
	save()


static func reset_all() -> void:
	for id in changes.keys():
		set_value(id, float(defaults[id]), false)
	save()


## An online game uses the game's own numbers; everything else uses the lab's.
static func set_in_force(on: bool) -> void:
	setup()
	if on == in_force:
		return
	in_force = on
	_apply_all()


static func _apply_all() -> void:
	for row in rows:
		var v := float(changes.get(row["id"], defaults[row["id"]])) if in_force else float(defaults[row["id"]])
		for place in row["at"]:
			_write(place, v)


# --- Words ---------------------------------------------------------------------------

## A number the way the lab shows it: "80%", "0.45 s", "520".
static func words(id: String, v: float) -> String:
	match str(by_id[id]["unit"]):
		"%":
			return "%s%%" % _trim(v * 100.0)
		"s":
			return "%s sec" % _trim(v)
	return _trim(v)


static func _trim(v: float) -> String:
	var s := "%.3f" % snappedf(v, 0.001)
	if s.contains("."):
		s = s.rstrip("0").trim_suffix(".")
	return s


## A typed number back into the game's kind ("85%" or "85" on a share is 0.85).
## Returns NAN for something that isn't a number.
static func typed(id: String, text: String) -> float:
	var t := text.strip_edges().to_lower().replace(",", ".")
	for junk in ["%", "seconds", "sec", "s", "x", " "]:
		t = t.replace(junk, "")
	if not t.is_valid_float():
		return NAN
	var v := t.to_float()
	return v / 100.0 if by_id[id]["unit"] == "%" else v


## Every change as plain lines, to copy and send (Darren, 15 November: "save the
## numbers and it passes them back to you"). Each line says it in words and then,
## in brackets, exactly which number it is, so it can be made the game's own:
##   Sword > Dagger > Damage: 60% -> 70%  [build:SHAPES/dagger/damage = 0.7]
static func summary() -> String:
	setup()
	var lines: Array = []
	for row in rows:
		var id: String = row["id"]
		if changes.has(id):
			lines.append("%s > %s > %s: %s -> %s  [%s = %s]" % [row["page"], row["group"], row["label"], words(id, float(defaults[id])), words(id, float(changes[id])),
				id, _trim(float(changes[id]))])
	if lines.is_empty():
		return "Lab: no numbers changed."
	return "Lab numbers changed (%d), from version %d:\n" % [lines.size(), Version.NUMBER] + "\n".join(lines)


# --- The file -------------------------------------------------------------------------

static func save() -> void:
	if not started:
		return
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"changes": changes}, "\t"))
	f.close()


## Reads the file. Numbers the game no longer has are dropped, and each one is
## kept inside its limits.
static func load_file() -> void:
	changes = {}
	if not FileAccess.file_exists(file):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not (data is Dictionary) or not (data.get("changes") is Dictionary):
		return
	for id in data["changes"]:
		var v = data["changes"][id]
		if by_id.has(id) and (v is float or v is int):
			var row: Dictionary = by_id[id]
			var x := clampf(float(v), float(row["lo"]), float(row["hi"]))
			if not is_equal_approx(x, float(defaults[id])):
				changes[id] = x
