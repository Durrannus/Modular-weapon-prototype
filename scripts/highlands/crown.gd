extends Node
## Rattlecrown's fight, and the way to it (version 48): the Scrapyard gate, the Throne Room, the Rusted Warhorn,
## the three phases, what beating him gives, and what the world save keeps. Where everything stands is
## crown_plan.gd's; Rattlecrown on his feet is scripts/foes/rattlecrown.gd.
##
## The rules, from the Game Bible:
##   - "The Rusted Warhorn. Body from the Elite Scrap Brute, bell from the Elite Cliff Hound, mouthpiece from the
##     Elite Pebble Slinger, joined with bronze at the anvil with Pip's help. Blow it at the Scrapyard gate, then in
##     the Throne Room. For repeat fights it is re-made from one elite piece of each kind."
##   - "Phase 1: he watches from the throne and does not attack while the three horn elites fight the players all at
##     once. Phase 2: he kicks the throne apart and fights on foot ... Phase 3: he puts on the crown and every
##     attack goes off twice."
##   - "Every attack shows on the floor before it lands, the tip line names each attack, health scales with players
##     like the guardian."
##   - "First kill: Twice, an active blank, a seat, a big chunk of Memory; the forge's beam points to the Greenwood.
##     Repeat kills: coins, bronze, scrap."
##
## STAND-INS, all Claude's choices until the outer ring and the anvil are built (version 49 on):
##   1. The Throne Room is cut into the rock of a top corner of the land that is laid out so far, not in the
##      Scrapyard's outer ring (crown_plan.gd).
##   2. The Scrapyard gate stands in the Throne Room's own door (the Scrapyard's four rooms are not built).
##   3. Pip mends the horn himself, by his cave-mouth camp, for MEND_TIN tin bars and MEND_COPPER copper bars (tin
##      and copper make the bronze; there is no anvil yet). It takes every player's pieces.
##   4. The first kill's hoard gives the Twice thread to everyone, Memory, coins and bars. The active blank, the
##      trophy seat and the forge's beam to the Greenwood wait for what they belong to. A repeat kill's gives coins
##      and bars (bars stand in for bronze and scrap).
##
## THE GATE SHUTS BEHIND YOU, AND HIS HOARD. Darren, 23 November, of the Art builder's ideas for the bigger hall:
## "Make the chest golden and the gate better as it's special loot, quite like the idea of goblins watching on the
## fight and the gate closing behind". How they work is Claude's choice until he says:
##   - When the horn is blown in front of the throne the Scrapyard gate shuts. It opens again when he falls, and
##     when the fight is called off. Whoever of the squad is outside it then is left outside until it opens.
##   - What beating him gives is not thrown on the floor: it is HIS HOARD, a chest that stands in view in an alcove
##     in the back wall to the right of the throne, behind bars of its own. The bars go up when he falls. Whoever
##     opens the chest, everybody gets their own full share (as every chest). An unopened hoard is kept with the
##     world. The bars stay up, the chest empty, until the horn is blown again.
##   - The chest and its bars are STAND-INS until the Art builder's golden chest and hoard gate land: the land's
##     own chest, and bars drawn by the code (hoard_chest, hoard_chest_empty, hoard_gate_shut, _opening and _open
##     in the Scrapyard's sheet are used as soon as they are there).
##   - The goblins who watch the fight from the tops of the walls are scenery, and wait for their art.
##
## SPIKE TRAPS. Darren, 23 November, of the first Throne Room: "room needs to be bigger with spike traps". He said
## nothing of how they work, so that is Claude's choice until he does:
##   - A trap is one tile of the floor: holes in it that are always there to be seen. Nothing happens until
##     somebody of the squad steps on it. Then it rattles for SPIKE_WARN seconds (its own warning), and the spikes
##     come up and stay up for SPIKE_UP seconds. Whoever is on it as they come up, or steps onto it while they are
##     up, is hurt (once for each time it comes up). Then it goes down and rests a moment.
##   - So walking or running straight across traps does not hurt (you are off each one before its spikes are up);
##     standing on one, or being knocked onto one and staying, does. A dodge takes you over raised spikes unhurt,
##     as it takes you through anything.
##   - Only the squad sets them off, and only the squad is hurt: the goblins know where they laid them.
##   - They lie in patches to either side of the middle of the room, and in a row just inside the gate: the
##     first thing you cross, and the place to learn what they do.
##   - Their pictures are a stand-in drawn by the code until the Art builder's land (spike_trap_down, _warn, _rise
##     and _up, in the Scrapyard's sheet).
##
## Claude's other choices here:
##   - The mended horn is the squad's (the world's), not one player's. Beating him cracks it again: for another
##     fight the three elites must be beaten again (they come back like everything else on the land) and Pip paid
##     again. The gate stays open once it has been opened.
##   - The three elites of phase 1 are called in: they leave no loot and no horn pieces (they cannot be farmed for
##     them). The white hound howls only once in the room. When the last of the three falls, whatever answered the
##     howl runs.
##   - The fight is called off if nobody of the squad stands in the room for RESET_AFTER seconds (everybody
##     fell): he sits back down with all his health, the gate opens, and the horn calls him again. The horn is not
##     used up by a fight that is lost.
##   - While the fight is on, the quest's mark at the screen's edge is off, the line of news sits lower and the
##     word "Saved" is not shown, so the boss's bar and the tip line have the top middle to themselves.
##   - The horn's sound, the words on the screen and Pip's words are stand-ins. The story is Darren's to write.
##
## The rules run on the game's tick (tick()); nothing here asks any dice.

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const CrownPlan := preload("res://scripts/highlands/crown_plan.gd")
const Folk := preload("res://scripts/highlands/folk.gd")
const Loot := preload("res://scripts/highlands/loot.gd")
const Nav := preload("res://scripts/highlands/nav.gd")
const Pack := preload("res://scripts/foes/pack.gd")
const Make := preload("res://scripts/foes/make.gd")
const Foe := preload("res://scripts/foes/foe.gd")
const Hound := preload("res://scripts/foes/hound.gd")
const Rattlecrown := preload("res://scripts/foes/rattlecrown.gd")

const UNIT := Art.PIXEL
const TILE := 16.0 * UNIT
const SORT_BIAS := 14.0            # as the land's things: players sort by their middle, things by their feet
const REACH := 76.0                # how near the gate you stand to use it (world units)
const BLOW_REACH := 104.0          # and how near the spot in front of the throne
const SEEN := 12.0 * TILE          # the way in has been found once somebody has come this near its mouth
const CALL_TIME := 1.1             # he points, and then the three come in
const WON_TIME := 2.4              # seconds he takes to fall
const HOARD_REACH := 64.0          # how near his hoard's chest you stand to open it
const HOARD_OUT := 0.3             # what it holds comes out this long after the lid starts up (as the land's chests)
const HOARD_CARD := 1.6            # and the card says what the first one held this long after
const HOARD_TIP := "Rattlecrown is beaten. His hoard stands open, right of the throne."
const ELITES := ["scrap_brute", "hound", "slinger"]
const NEWS_Y := 86.0               # where the line of news sits while the boss's bar and the tip line are up
const TIP_W := 200.0               # the tip line is no wider than this: it stays between the corners' bars and the quests

static var RESET_AFTER := 5.0      # nobody standing in the room for this long: the fight is called off
static var SPIKES := 8.0           # what a spike trap does to whoever is on it
static var SPIKE_WARN := 0.6       # it rattles this long before the spikes come up
static var SPIKE_UP := 1.1         # they stay up this long
static var SPIKE_REST := 0.5       # and it cannot be set off again for this long after they go down
static var MEND_TIN := 3
static var MEND_COPPER := 3
static var FIRST_MEMORY := 150
static var FIRST_COINS := 80
static var FIRST_BARS := 4         # of tin, and of copper
static var AGAIN_MEMORY := 40
static var AGAIN_COINS := 40
static var AGAIN_BARS := 2

## What the tip line says as the fight goes on, and as each attack begins (once crowned, TIPS_TWICE).
const SAYS := {
	"call": "His three champions come first. He watches until they fall.",
	"kick": "His champions are down. He kicks his throne apart.",
	"foot": "Rattlecrown is on his feet. Every attack of his shows on the floor first.",
	"crown": "He has put on his crown. Every attack now comes twice.",
}
const TIPS := {
	"slam": "Club Slam: get out of the ring.",
	"toss": "Scrap Toss: step off the ring where it will land.",
	"charge": "Charge: step out of the lane. If he ends against the rock, strike.",
}
const TIPS_TWICE := {
	"slam": "Club Slam, twice: he steps after you for the second.",
	"toss": "Scrap Toss, twice: two rings. Stand on neither.",
	"charge": "Charge, twice: he turns and comes again.",
}

var game                           # the Highlands scene
var map: LandMap
var world: Node2D                  # the y-sorted layer everything stands in
var players: Array = []
var tools                          # tools.gd: the bags
var loot                           # loot.gd: the purses, and a line for everyone
var foes                           # foes.gd: the way-finding
var folk                           # folk.gd: Pip and the pieces
var plan := {}                     # crown_plan.gd's

var horn := false                  # the squad holds the mended Warhorn
var gate_open := false
var beaten := 0                    # how many times he has been beaten in this world
var found := false                 # somebody has been to the mouth of the way in
var stage := "wait"                # wait, call (he points), elites, kick, foot, crown, won
var stage_t := 0.0
var empty_t := 0.0                 # seconds nobody has stood in the room during a fight
var clock := 0.0
var told_at := -9.0
var first_win := false
var hoard := ""                    # what his hoard's chest holds, unopened: "" nothing, "first" (the first kill's), "again"
var shut_in := false               # the gate has shut behind the squad (a fight is on)
var card_in := 0.0                 # seconds until the card says what the first hoard held
var tip_left := 0.0

var gate: Folk.Actor
var throne: Folk.Actor
var chest: Sprite2D                # the hoard's
var chest_t := -1.0                # seconds since its lid started up (under 0: it is not moving)
var bars: Bars
var bars_shape: CollisionShape2D
var yard: Texture2D                # the Scrapyard's sheet, and its book
var yard_book := {}
var dress: Array = []
var traps: Array = []              # every spike trap (Trap)
var trap_at := {}                  # tile -> its Trap
var body: StaticBody2D
var gate_shape: CollisionShape2D
var court: Pack                    # the three elites of phase 1, and whatever answers the hound's howl
var elites: Array = []
var boss = null


## One spike trap: a tile of the floor. The rules are the game's (crown.gd, _tick_traps); this is how it looks.
class Trap extends Node2D:
	const PX := 2.0
	const RISE := 2.0 / 12.0       # the spikes take this long to come up, and to go down
	const HOLE := Color("#19142a")
	const LIP := Color(0.78, 0.75, 0.88, 0.14)     # the floor's own stone catching a little light under each hole
	const IRON := Color("#8c8894")
	const TIP := Color("#e0e2d0")

	var tile := Vector2i.ZERO
	var sheet: Texture2D
	var book := {}                 # the Scrapyard's sprites, if the art has the trap's
	var state := "down"            # down, warn, rise, up, lower
	var t := 0.0
	var rest := 0.0
	var hit := {}                  # the players this rise has hurt
	var _shown := ""

	func go(to: String) -> void:
		state = to
		t = 0.0
		# Down, the plate lies in the floor under everyone; up, the spikes stand among them.
		z_index = -4 if to in ["down", "warn"] else 0
		queue_redraw()

	## How far up the spikes are, 0 to 1.
	func up() -> float:
		match state:
			"rise":
				return clampf(t / RISE, 0.0, 1.0)
			"up":
				return 1.0
			"lower":
				return 1.0 - clampf(t / RISE, 0.0, 1.0)
		return 0.0

	func step(delta: float) -> void:
		t += delta
		var now := "%s:%d" % [state, int(t * 12.0) if state != "down" and state != "up" else 0]
		if now != _shown:
			_shown = now
			queue_redraw()

	func _draw() -> void:
		var name := "spike_trap_" + ("rise" if state == "lower" else state)
		var info: Dictionary = book.get(name, {})
		if sheet != null and info.has("box"):
			var box: Array = info["box"]
			var n := maxi(int(info.get("frames", 1)), 1)
			var fw := float(box[2]) / float(n)
			var k := 0
			if state == "warn":
				k = int(t * float(info.get("fps", 8))) % n
			elif state == "rise":
				k = mini(int(t * float(info.get("fps", 12))), n - 1)
			elif state == "lower":
				k = maxi(n - 1 - int(t * float(info.get("fps", 12))), 0)
			var o: Array = info.get("origin", [8, 27])
			draw_set_transform(Vector2(0, 16), 0.0, Vector2(PX, PX))
			draw_texture_rect_region(sheet, Rect2(-float(o[0]), -float(o[1]), fw, float(box[3])), Rect2(float(box[0]) + fw * float(k), float(box[1]), fw, float(box[3])))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		# The stand-in: four holes in the floor itself, with no plate laid on it (Darren, 23 November, of the traps
		# and the paving: "it has to look part of the world and not just a thing placed onto"); tips that rattle in
		# them; four spikes.
		var tall := 0.0
		if state == "warn":
			tall = 4.0 if int(t * 16.0) % 2 == 0 else 2.0
		elif state != "down":
			tall = roundf(up() * 9.0) * PX
		for j in 2:
			for i in 2:
				var at := Vector2(-12.0 + 16.0 * float(i), -10.0 + 14.0 * float(j))
				draw_rect(Rect2(at, Vector2(8, 4)), HOLE)
				draw_rect(Rect2(at + Vector2(0, 4), Vector2(8, 2)), LIP)
				if tall > 0.0:
					draw_rect(Rect2(at.x + 2.0, at.y + 4.0 - tall, 4, tall), IRON)
					draw_rect(Rect2(at.x + 2.0, at.y + 4.0 - tall, 2, tall), TIP if tall > 6.0 else IRON)
					draw_rect(Rect2(at.x + 2.0, at.y + 2.0 - tall, 2, 2), TIP)


## The bars across the mouth of the hoard's alcove. When they are up is the game's (crown.gd); this is how they look.
class Bars extends Node2D:
	const PX := 2.0
	const TIME := 0.5              # they take this long to go up, and to come down
	const DARK := Color("#19142a")
	const IRON := Color("#3a3548")
	const EDGE := Color("#8c8894")

	var wide := 48.0               # art pixels
	var tall := 30.0
	var lift := 14.0               # as the land's things: it sorts by its foot
	var sheet: Texture2D
	var book := {}                 # the Scrapyard's sprites, if the art has the hoard's gate
	var up := false
	var k := 0.0                   # how far up they are, 0 to 1

	func raise(on: bool, at_once := false) -> void:
		up = on
		if at_once:
			k = 1.0 if on else 0.0
		queue_redraw()

	func step(delta: float) -> void:
		var to := 1.0 if up else 0.0
		if k != to:
			k = move_toward(k, to, delta / TIME)
			queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2(0, lift), 0.0, Vector2(PX, PX))
		var name := "hoard_gate_open" if k >= 1.0 else ("hoard_gate_shut" if k <= 0.0 else "hoard_gate_opening")
		var info: Dictionary = book.get(name, {})
		if sheet != null and info.has("box"):
			var box: Array = info["box"]
			var n := maxi(int(info.get("frames", 1)), 1)
			var fw := float(box[2]) / float(n)
			var o: Array = info.get("origin", [fw * 0.5, float(box[3]) - 1.0])
			var f := clampi(int(k * float(n)), 0, n - 1)
			draw_texture_rect_region(sheet, Rect2(-float(o[0]), -float(o[1]), fw, float(box[3])), Rect2(float(box[0]) + fw * float(f), float(box[1]), fw, float(box[3])))
		else:
			# The stand-in: a beam across the top, a post at each side, and bars that go up into the beam.
			var gone := roundf((tall - 8.0) * k)
			var x := -wide * 0.5 + 5.0
			while x < wide * 0.5 - 5.0:
				draw_rect(Rect2(x, -tall + 4.0, 2.0, tall - 4.0 - gone), IRON)
				draw_rect(Rect2(x, -tall + 4.0, 1.0, tall - 4.0 - gone), EDGE)
				x += 6.0
			for side in [-1.0, 1.0]:
				draw_rect(Rect2(side * (wide * 0.5 - 1.5) - 1.5, -tall, 3.0, tall), IRON)
			draw_rect(Rect2(-wide * 0.5, -tall, wide, 5.0), IRON)
			draw_rect(Rect2(-wide * 0.5, -tall, wide, 1.0), EDGE)
			draw_rect(Rect2(-wide * 0.5, -tall + 4.0, wide, 1.0), DARK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ready() -> void:
	body = StaticBody2D.new()
	body.collision_layer = 4       # as the land's rock (land_view.gd)
	body.collision_mask = 0
	add_child(body)


func ok() -> bool:
	return bool(plan.get("ok", false))


# --- Where everything is (world units) ------------------------------------------------------

func gate_feet() -> Vector2:
	return (plan["gate_foot"] as Vector2) * UNIT


func throne_feet() -> Vector2:
	return (plan["throne"] as Vector2) * UNIT


## Where the horn is blown in the room: in front of the throne.
func blow_spot() -> Vector2:
	return (plan["blow"] as Vector2) * UNIT


## The foot of the hoard's chest, and the middle of the foot of its bars.
func hoard_feet() -> Vector2:
	return (plan["hoard"] as Vector2) * UNIT


func bars_feet() -> Vector2:
	return (plan["bars"] as Vector2) * UNIT


func alcove_rect() -> Rect2:
	var r: Rect2i = plan["alcove"]
	return Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)


func room_rect() -> Rect2:
	var r: Rect2i = plan["room"]
	return Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)


## The mouth of the way in: where it meets ground you can walk to from the cave.
func mouth() -> Vector2:
	return (Vector2(plan["meet"]) + Vector2(0.5, 0.5)) * TILE


## Which way from the cave the Scrapyard gate lies, in words.
func side_word() -> String:
	return "north-west" if int(plan.get("side", -1)) < 0 else "north-east"


# --- Setting up -----------------------------------------------------------------------------

## Stands the plan's things on the land. (The room and the way are already cut: CrownPlan.stamp, by the game.)
func setup(plan_: Dictionary) -> void:
	plan = plan_
	if not ok():
		return
	var its: Array = game.interactables if game != null and "interactables" in game else []
	# The gate.
	yard = Art.texture("scrapyard/scrapyard.png")
	yard_book = Art.json("scrapyard/scrapyard.json").get("sprites", {})
	var book := yard_book
	var front: Dictionary = book.get("gate_front_shut", {})
	gate = _actor(yard, {"shut": front, "opening": book.get("gate_front_opening", {}), "open": book.get("gate_front_open", {})},
		front.get("origin", [28, 63]), gate_feet())
	gate_shape = _solid(gate_feet(), Vector2(48, 10) * UNIT)
	# (Open or shut, its posts and its leaves take the 8 pixels of the way at each side.)
	for side in [-1.0, 1.0]:
		_solid(gate_feet() + Vector2(side * 20.0 * UNIT, 0.0), Vector2(8, 10) * UNIT)
	its.append({"at": gate_feet() + Vector2(0, 22), "radius": REACH, "lift": 112.0, "text": "The Scrapyard gate",
		"words": func(_i): return gate_words(), "can": func(_i): return not gate_open, "use": func(i): use_gate(i)})
	# The throne, with him on it.
	var his: Dictionary = Art.json("foes/rattlecrown.json").get("enemies", {}).get("throne", {})
	throne = _actor(Art.texture("foes/rattlecrown.png"), his.get("strips", {}), his.get("origin_feet", [52, 88]), throne_feet())
	_solid(throne_feet(), (plan["throne_solid"] as Vector2) * UNIT)
	_block_under(plan["throne"], plan["throne_solid"])
	its.append({"at": blow_spot(), "radius": BLOW_REACH, "lift": 64.0, "text": "Blow the Rusted Warhorn",
		"can": func(_i): return stage == "wait" and horn and gate_open, "use": func(_i): start()})
	# The spike traps.
	for tile in plan["traps"]:
		var tr := Trap.new()
		tr.tile = tile
		tr.sheet = yard
		tr.book = book
		tr.position = (Vector2(tile) + Vector2(0.5, 0.5)) * TILE
		tr.z_index = -4
		if world != null:
			world.add_child(tr)
		else:
			add_child(tr)
		traps.append(tr)
		trap_at[tile] = tr
	# His hoard: the chest in its alcove, and the bars across the alcove's mouth.
	var of_chest := _chest_info()
	var cf: Array = of_chest.get("foot", [9, 20])
	chest = Sprite2D.new()
	chest.centered = false
	chest.offset = Vector2(-float(cf[0]), -float(cf[1]) + SORT_BIAS / UNIT)
	chest.scale = Vector2(UNIT, UNIT)
	chest.position = hoard_feet() - Vector2(0, SORT_BIAS)
	bars = Bars.new()
	bars.wide = float((plan["alcove"] as Rect2i).size.x) * 16.0
	bars.sheet = yard
	bars.book = book
	bars.position = bars_feet() - Vector2(0, SORT_BIAS)
	for thing in [chest, bars]:
		if world != null:
			world.add_child(thing)
		else:
			add_child(thing)
	var cs: Array = of_chest.get("solid", [16, 5])
	_solid(hoard_feet(), Vector2(float(cs[0]), float(cs[1])) * UNIT)
	bars_shape = _solid(bars_feet(), Vector2(bars.wide, 6.0) * UNIT)
	if foes != null and foes.nav != null:
		var al: Rect2i = plan["alcove"]        # (no enemy has any business in there)
		for ty in range(al.position.y, al.end.y):
			for tx in range(al.position.x, al.end.x):
				foes.nav.block(Vector2i(tx, ty))
	its.append({"at": hoard_feet() - Vector2(0, 10), "radius": HOARD_REACH, "lift": 46.0, "text": "Open Rattlecrown's hoard",
		"can": func(_i): return hoard != "" and not fighting(), "use": func(i): open_hoard(i)})
	# The braziers and the scrap piles round the arena.
	for d in plan["dress"]:
		var info: Dictionary = book.get(str(d[0]), {})
		var a := _actor(yard, {"idle": info}, info.get("origin", [0, 0]), (d[1] as Vector2) * UNIT)
		a.play("idle")
		a.face(bool(d[3]))
		dress.append(a)
		_solid((d[1] as Vector2) * UNIT, (d[2] as Vector2) * UNIT)
		_block_under(d[1], d[2])
	if game != null and "ui" in game and game.ui != null:
		game.ui.hint_w = TIP_W
	_show(true)


## The golden chest's own pictures when the Scrapyard's sheet has them; until then, the land's chest.
func _chest_info() -> Dictionary:
	if yard != null and (yard_book.get("hoard_chest", {}) as Dictionary).has("box"):
		return yard_book["hoard_chest"]
	return loot.book.get("chest", {}) if loot != null else {}


func _chest_tex(name: String, frame := 0) -> Texture2D:
	var own: Dictionary = yard_book.get("hoard_" + name, {})
	if yard != null and own.has("box"):
		var box: Array = own["box"]
		var w := int(own["frame"][0]) if own.has("frame") else int(box[2])
		var t := AtlasTexture.new()
		t.atlas = yard
		t.region = Rect2(int(box[0]) + frame * w, int(box[1]), w, int(box[3]))
		return t
	return loot._frame(name, frame) if loot != null else null


func _actor(sheet: Texture2D, strips: Dictionary, origin: Array, feet: Vector2) -> Folk.Actor:
	var a := Folk.Actor.new()
	a.sheet = sheet
	a.strips = strips
	a.origin = Vector2(float(origin[0]), float(origin[1]))
	a.position = feet - Vector2(0, SORT_BIAS)
	if world != null:
		world.add_child(a)
	else:
		add_child(a)
	return a


func _solid(feet: Vector2, size: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	shape.position = feet - Vector2(0, size.y * 0.5)
	body.add_child(shape)
	return shape


func _block_under(foot: Vector2, size: Vector2) -> void:
	if foes == null or foes.nav == null:
		return
	for t in CrownPlan.tiles_under(foot, size):
		foes.nav.block(t)


## Everything as the state says it is (after setting up, after a save is read, and when a fight begins or ends).
## `at_once`: nothing is seen to move.
func _show(at_once := false) -> void:
	if not ok() or gate == null:
		return
	var way: bool = gate_open and not shut_in
	gate.play("open" if way else "shut")
	gate_shape.set_deferred("disabled", way)
	# The enemies' way-finding: shut, nobody passes; open, the middle of the way is clear.
	if foes != null and foes.nav != null:
		var at: Vector2i = plan["gate"]
		for dx in [-1, 0, 1]:
			if way and dx == 0:
				foes.nav.unblock(at + Vector2i(dx, 0))
			else:
				foes.nav.block(at + Vector2i(dx, 0))
	# He sits on his throne whenever the horn could call him; once he has been beaten, its wreck stands empty until
	# the horn is mended again.
	throne.play("idle" if horn or beaten == 0 else "wreck")
	# His hoard: the bars are up from when he falls until the horn is blown again; the chest is seen full whenever
	# there is something to be had from it, now or by beating him.
	var bars_up: bool = (beaten > 0 or hoard != "") and not shut_in
	bars.raise(bars_up, at_once)
	bars_shape.set_deferred("disabled", bars_up)
	chest_t = -1.0
	chest.texture = _chest_tex("chest", 0) if hoard != "" or horn or beaten == 0 or shut_in else _chest_tex("chest_empty")


## The fight is over, one way or the other: the gate that shut behind the squad opens.
func _let_out() -> void:
	var was := shut_in
	shut_in = false
	_show()
	if was and gate_open:
		gate.play("opening", false, true)
		Sfx.play(game, "gate", -8.0, 0.9)


# --- The horn and the gate --------------------------------------------------------------------

## Can Pip mend the horn right now? (All three pieces, and no horn yet.)
func can_mend() -> bool:
	return ok() and not horn and folk != null and folk.pieces() >= 3


## How many of a bar the whole squad carries.
func squad(item: String) -> int:
	var n := 0
	if tools != null:
		for i in players.size():
			n += int(tools.bag_of(i).count(item))
	return n


## What mending costs, in words.
func mend_cost() -> String:
	return "%d tin, %d copper" % [int(MEND_TIN), int(MEND_COPPER)]


## Pip joins the three pieces with the squad's bars (player i's own first). "" if he did; otherwise why not.
func mend(i: int) -> String:
	if horn:
		return "It is mended already."
	if not can_mend():
		return "It wants all three pieces."
	if squad("tin_bar") < int(MEND_TIN) or squad("copper_bar") < int(MEND_COPPER):
		return "The bronze wants %d tin bars and %d copper bars. %s %d and %d." % [int(MEND_TIN), int(MEND_COPPER),
			"You have" if players.size() < 2 else "The squad has", squad("tin_bar"), squad("copper_bar")]
	var order: Array = [i]
	for k in players.size():
		if k != i:
			order.append(k)
	for pair in [["tin_bar", int(MEND_TIN)], ["copper_bar", int(MEND_COPPER)]]:
		var need := int(pair[1])
		for k in order:
			var bag = tools.bag_of(k)
			var n := mini(int(bag.count(str(pair[0]))), need)
			if n > 0:
				bag.take(str(pair[0]), n)
				need -= n
	# The pieces are in the horn now: everybody's.
	for purse in loot.purses:
		for name in Loot.KEPT:
			(purse.kept as Dictionary).erase(name)
	horn = true
	_show()
	loot.say("Quest done: Mend the Horn")
	Sfx.play(game, "anvil", -8.0, 1.1)
	Sfx.play(game, "pickup", -9.0, 0.9)
	if game != null:
		game.save_now()
	return ""


func gate_words() -> String:
	return "Blow the Rusted Warhorn" if horn else "The Scrapyard gate: only the Rusted Warhorn opens it"


## Somebody uses the gate: with the horn, it opens.
func use_gate(i: int) -> bool:
	if gate_open or not ok():
		return false
	if not horn:
		_tell(i, "It wants the Warhorn")
		Sfx.play(game, "click", -8.0, 0.6)
		return false
	gate_open = true
	gate.play("opening", false, true)
	gate_shape.set_deferred("disabled", true)
	if foes != null and foes.nav != null:
		foes.nav.unblock(plan["gate"])
	_blare()
	Sfx.play(game, "gate", -6.0, 0.9)
	loot.say("The Scrapyard gate is open")
	if game != null:
		game.save_now()
	return true


## The horn's voice: a stand-in made of the game's own sounds, until it has one.
func _blare() -> void:
	Sfx.play(game, "warn", -4.0, 0.35)
	Sfx.play(game, "rumble", -14.0, 1.3)


# --- The fight --------------------------------------------------------------------------------

func fighting() -> bool:
	return stage in ["call", "elites", "kick", "foot", "crown"]


## 0 no fight, 1 he watches from the throne, 2 on foot, 3 crowned.
func phase() -> int:
	match stage:
		"call", "elites", "kick":
			return 1
		"foot":
			return 2
		"crown":
			return 3
	return 0


## The horn is blown in front of the throne: the fight begins. False if it cannot (one is on, or there is no room).
func start() -> bool:
	if stage != "wait" or not ok():
		return false
	stage = "call"
	stage_t = 0.0
	empty_t = 0.0
	# The gate shuts behind the squad, and the hoard's bars come down. (Nobody is shut in the gate itself, or in
	# with the hoard.)
	shut_in = true
	_show()
	for p in players:
		if not is_instance_valid(p):
			continue
		if Rect2(gate_feet() + Vector2(-56, -44), Vector2(112, 64)).has_point(p.global_position):
			p.global_position.y = gate_feet().y - 52.0
		if alcove_rect().grow(6.0).has_point(p.global_position):
			p.global_position = bars_feet() + Vector2(0, 26)
	Sfx.play(game, "gate", -8.0, 0.7)
	throne.play("point")
	_blare()
	_top(true)
	_tip(SAYS["call"])
	if loot != null:
		loot.say("The gate shuts behind you")
	return true


func _top(on: bool) -> void:
	if loot != null:
		loot.said_y = NEWS_Y if on else 42.0


func _tip(words: String) -> void:
	if game != null and "ui" in game and game.ui != null:
		game.ui.hint = words


## The three horn elites come in, all at once.
func _send_elites() -> void:
	court = Pack.new()
	court.id = -1
	court.nav = foes.nav if foes != null else null
	court.home = room_rect().get_center()
	court.reach = room_rect().size.x * 0.5
	court.alert = true
	court.howls = int(Hound.HOWL_MOST) - 1      # the white hound howls only once in here
	elites = []
	for k in ELITES.size():
		var e = Make.make(str(ELITES[k]), true)
		var at: Vector2 = Nav.middle_of(plan["spots"][k])
		e.pack = court
		e.nav = court.nav
		e.summoned = true          # called in: they leave no loot, and no piece of the horn
		e.home = at
		e.position = at
		e.facing = Vector2.DOWN
		world.add_child(e)
		court.members.append(e)
		elites.append(e)
		var puff := Foe.play_shot(e, "pebble_puff", at + Vector2(0, 10))
		if puff != null:
			puff.z_index = 0
	Sfx.play(game, "thud", -8.0, 0.7)


## Whatever answered the white hound's howl runs once the three are down.
func _scatter() -> void:
	if court == null:
		return
	for e in court.members:
		if is_instance_valid(e) and not e.dead:
			Foe.play_shot(e, "pebble_puff", e.global_position)
			e.queue_free()
	court.members.clear()


## He is on his feet, in front of what is left of the throne.
func _stand_boss() -> void:
	boss = Rattlecrown.new()
	var n := 0
	for p in players:
		if is_instance_valid(p):
			n += 1
	boss.team = maxi(n, 1)
	boss.nav = foes.nav if foes != null else null
	boss.room = room_rect().grow(8.0)      # (the doorway counts: nobody is out of his reach against the gate)
	boss.home = throne_feet() + Vector2(0, 3.0 * TILE)
	boss.position = throne_feet() + Vector2(0, 18)
	boss.facing = Vector2.DOWN
	boss.show_bar = false          # his health is the bar at the top of the screen
	world.add_child(boss)
	boss.attack_started.connect(_on_attack)
	boss.crown_put_on.connect(_on_crown)
	boss.died.connect(_on_boss_died)
	if game != null and "ui" in game and game.ui != null:
		game.ui.boss = boss
		game.ui.boss_shown = 1.0
	_tip(SAYS["foot"])
	Sfx.play(game, "slam", -6.0, 0.7)
	for p in players:
		if is_instance_valid(p) and p.rig != null:
			p.rig.add_shake(4.0)
			break


func _on_attack(kind: String, twice: bool) -> void:
	_tip(str((TIPS_TWICE if twice else TIPS).get(kind, "")))


func _on_crown() -> void:
	if stage == "foot":
		stage = "crown"
	_tip(SAYS["crown"])
	Sfx.play(game, "forged", -10.0, 0.7)


func _on_boss_died(_e) -> void:
	_won()


## He is beaten: the gate opens, the bars of his hoard go up, and the world remembers.
func _won() -> void:
	first_win = beaten == 0
	beaten += 1
	horn = false                   # the horn cracks again: another fight wants the three pieces again
	# (A first hoard that was never opened is still the first one.)
	hoard = "first" if first_win or hoard == "first" else "again"
	stage = "won"
	stage_t = 0.0
	boss = null
	_clear_shots()
	if game != null and "ui" in game and game.ui != null:
		game.ui.boss = null
	_top(false)
	_let_out()
	_tip(HOARD_TIP)
	tip_left = 12.0
	loot.say("Quest done: Blow the Horn" if first_win else "Rattlecrown is beaten again")
	Sfx.play(game, "forged", -7.0, 1.0)
	if game != null:
		game.save_now()


## Somebody opens his hoard. Everybody gets what is in it, each their own full share (as the land's chests). False
## if there is nothing in it, or a fight is on.
func open_hoard(_by := -1) -> bool:
	if hoard == "" or fighting() or not ok():
		return false
	var first := hoard == "first"
	hoard = ""
	chest_t = 0.0
	var at := hoard_feet() + Vector2(0, -14)
	for i in players.size():
		if not is_instance_valid(players[i]):
			continue
		loot.give(i, "coins", loot._lucky(i, int(FIRST_COINS) if first else int(AGAIN_COINS)), at, HOARD_OUT, true)
		loot.give(i, "tin_bar", int(FIRST_BARS) if first else int(AGAIN_BARS), at, HOARD_OUT + 0.05, true)
		loot.give(i, "copper_bar", int(FIRST_BARS) if first else int(AGAIN_BARS), at, HOARD_OUT + 0.1, true)
		loot.give(i, "memory", int(FIRST_MEMORY) if first else int(AGAIN_MEMORY), at, HOARD_OUT + 0.25, true)
		if first:
			give_twice(i)
	if first:
		card_in = HOARD_CARD
	tip_left = 0.0
	if game != null and "ui" in game and game.ui != null and str(game.ui.hint) == HOARD_TIP:
		_tip("")
	Sfx.play(game, "click", -7.0, 0.7)
	Sfx.play(game, "thud", -12.0, 1.3)
	if game != null:
		game.save_now()
	return true


## Player i can thread Twice at the forge from now on. (Somebody who can already use every part has it.)
func give_twice(i: int) -> bool:
	if game == null or not ("owned" in game) or i < 0 or i >= (game.owned as Array).size():
		return false
	if game.owned[i] is Array and not ("twice" in game.owned[i]):
		(game.owned[i] as Array).append("twice")
		return true
	return false


## The fight is called off: he sits back down with all his health, and the horn calls him again.
func reset() -> void:
	if court != null:
		for e in court.members:
			if is_instance_valid(e):
				e.queue_free()
		court.members.clear()
	for e in elites:
		if is_instance_valid(e):
			e.queue_free()
	elites = []
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	_clear_shots()
	var was := fighting()
	stage = "wait"
	stage_t = 0.0
	empty_t = 0.0
	if game != null and "ui" in game and game.ui != null:
		game.ui.boss = null
	_tip("")
	_top(false)
	_let_out()
	if was and loot != null:
		loot.say("Rattlecrown sits back down")


func _clear_shots() -> void:
	for s in get_tree().get_nodes_in_group("crown_shots"):
		if is_instance_valid(s):
			s.queue_free()


## How many of the squad are on their feet in the room (its doorway counts).
func standing_in_room() -> int:
	var r := room_rect().grow(TILE)
	var n := 0
	for p in players:
		if is_instance_valid(p) and not p.is_down and r.has_point(p.global_position):
			n += 1
	return n


# --- Once a tick -----------------------------------------------------------------------------

func tick(delta: float) -> void:
	if not ok() or gate == null:
		return
	clock += delta
	gate.step(delta)
	throne.step(delta)
	for a in dress:
		a.step(delta)
	bars.step(delta)
	if gate.anim == "opening" and gate.done():
		gate.play("open")
	# The hoard's lid goes up, and what the first one held is told.
	if chest_t >= 0.0:
		chest_t += delta
		var lid := int(chest_t * Loot.LID_FPS)
		chest.texture = _chest_tex("chest", mini(lid, 4)) if lid <= 4 else _chest_tex("chest_empty")
		if lid > 4:
			chest_t = -1.0
	if card_in > 0.0:
		card_in = maxf(card_in - delta, 0.001)
		if card_in <= 0.001 and game != null and "ui" in game and game.ui != null and not game.ui.busy():
			card_in = 0.0
			game.ui.card("Rattlecrown's hoard", won_text())
	if tip_left > 0.0:
		tip_left -= delta
		if tip_left <= 0.0 and game != null and "ui" in game and game.ui != null and str(game.ui.hint) == HOARD_TIP:
			_tip("")
	if not found and _near(mouth(), SEEN):
		found = true
	_tick_traps(delta)
	match stage:
		"call":
			stage_t += delta
			if stage_t >= CALL_TIME:
				_send_elites()
				throne.play("idle")
				stage = "elites"
		"elites":
			if elites.all(func(e): return not is_instance_valid(e) or e.dead):
				_scatter()
				throne.play("kick", false, true)
				stage = "kick"
				_tip(SAYS["kick"])
				Sfx.play(game, "anvil", -8.0, 0.6)
		"kick":
			if throne.done():
				throne.play("wreck")
				stage = "foot"
				_stand_boss()
		"won":
			stage_t += delta
			if stage_t >= WON_TIME:
				stage = "wait"
	if fighting():
		if standing_in_room() > 0:
			empty_t = 0.0
		else:
			empty_t += delta
			if empty_t >= float(RESET_AFTER):
				reset()


## The tile a player stands on (their feet, a little below their middle).
func tile_under(p) -> Vector2i:
	var feet: Vector2 = p.global_position + Vector2(0, 8)
	return Vector2i(floori(feet.x / TILE), floori(feet.y / TILE))


## The spike traps: somebody of the squad standing on one sets it off; it rattles, comes up, hurts whoever is on
## it, and goes down again.
func _tick_traps(delta: float) -> void:
	var on := {}                   # tile -> the players standing on it
	for p in players:
		if is_instance_valid(p) and not p.is_down:
			var tile := tile_under(p)
			if trap_at.has(tile):
				if not on.has(tile):
					on[tile] = []
				(on[tile] as Array).append(p)
	for tr: Trap in traps:
		if tr.state == "down" and tr.rest <= 0.0 and not on.has(tr.tile):
			continue                   # most of them, most of the time
		tr.step(delta)
		match tr.state:
			"down":
				tr.rest -= delta
				if tr.rest <= 0.0 and on.has(tr.tile):
					tr.go("warn")
					Sfx.play(tr, "click", -9.0, 1.6)
			"warn":
				if tr.t >= float(SPIKE_WARN):
					tr.hit = {}
					tr.go("rise")
					Sfx.play(tr, "cleave", -11.0, 1.3)
			"rise", "up":
				for p in on.get(tr.tile, []):
					if not tr.hit.has(int(p.index)) and p.invuln <= 0.0:
						tr.hit[int(p.index)] = true
						p.take_damage(float(SPIKES), tr.global_position, null)
				if tr.state == "rise" and tr.t >= Trap.RISE:
					tr.go("up")
				elif tr.state == "up" and tr.t >= float(SPIKE_UP):
					tr.go("lower")
			"lower":
				if tr.t >= Trap.RISE:
					tr.go("down")
					tr.rest = float(SPIKE_REST)


## What the card says when the first hoard is opened. (Stand-in words: the story is Darren's to write.)
func won_text() -> String:
	return "His crown lies on top. It was never a crown: it is a thread of the old forge, Twice.\nEveryone here can thread Twice at the forge from now on.\n\nThe Rusted Warhorn cracked as he fell. For another fight, take its three pieces from the elites again and bring them to Pip."


func _near(at: Vector2, far: float) -> bool:
	for p in players:
		if is_instance_valid(p) and p.global_position.distance_to(at) < far:
			return true
	return false


## A few words over a player's head, not more than once in a while.
func _tell(i: int, words: String) -> void:
	if clock - told_at < 1.2 or i < 0 or i >= players.size() or not is_instance_valid(players[i]):
		return
	told_at = clock
	players[i]._label(words.to_upper(), Color("#e8e4bc"))


# --- For the quests' corner (folk.gd draws it) ---------------------------------------------------

## The quest the horn gives right now: {id, name, text}, or {} when there is none. `pieces`: how many of the three
## the squad has.
func quest(pieces: int) -> Dictionary:
	if not ok():
		return {}
	if fighting():
		return {"id": "horn", "name": "Blow the Horn", "text": "Beat Rattlecrown, the Scrap King."}
	if hoard != "":
		return {"id": "hoard", "name": "The King's Hoard", "text": "Open the chest in the back wall of the Throne Room, right of the throne."}
	if horn:
		var text := "Blow the Rusted Warhorn at the Scrapyard gate, far to the %s. Lanterns mark the way in." % side_word()
		if gate_open:
			text = "Blow the Rusted Warhorn in the Throne Room, in front of Rattlecrown."
		return {"id": "horn", "name": "Blow the Horn", "text": text}
	if pieces >= 3:
		return {"id": "mend", "name": "Mend the Horn", "text": "Take the three pieces to Pip. He joins them for %d tin bars and %d copper bars." % [int(MEND_TIN), int(MEND_COPPER)]}
	if beaten > 0:
		return {}                  # he has been beaten: another fight is yours to choose
	return {"id": "crown", "name": "The Scrap Crown", "text": "Take the Rusted Warhorn's three pieces from the three elites: %d of 3." % pieces}


## Where the quest's mark at the screen's edge points (world units), or INF when it points nowhere: to the mouth
## of the way in until somebody has found it, then to the gate, then to the throne; and to his hoard while it
## waits to be opened.
func sign_target() -> Vector2:
	if not ok() or fighting():
		return Vector2.INF
	if hoard != "":
		return hoard_feet() + Vector2(0, -16)
	if not horn or stage != "wait":
		return Vector2.INF
	if not found:
		return mouth()
	if not gate_open:
		return gate_feet() + Vector2(0, -30)
	return blow_spot()


# --- What is saved (with the world) ---------------------------------------------------------

func world_data() -> Dictionary:
	return {"crown": {"horn": horn, "gate": gate_open, "beaten": beaten, "found": found, "hoard": hoard}}


func set_world_data(d) -> void:
	var c = (d as Dictionary).get("crown") if d is Dictionary else null
	horn = false
	gate_open = false
	beaten = 0
	found = false
	hoard = ""
	if c is Dictionary:
		horn = c.get("horn") is bool and bool(c["horn"])
		gate_open = c.get("gate") is bool and bool(c["gate"])
		if c.get("beaten") is int or c.get("beaten") is float:
			beaten = maxi(int(c["beaten"]), 0)
		found = c.get("found") is bool and bool(c["found"])
		if c.get("hoard") is String and str(c["hoard"]) in ["first", "again"]:
			hoard = str(c["hoard"])
	stage = "wait"
	shut_in = false
	card_in = 0.0
	_show(true)
