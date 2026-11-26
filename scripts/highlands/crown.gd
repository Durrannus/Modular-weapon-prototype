extends Node
## Rattlecrown's fight, and the way to it (version 48; his Scrapyard since version 49): the Scrapyard gate, its rooms'
## barred doors and rules, the Throne Room, the Rusted Warhorn, the three phases, what beating him gives, and what
## the world save keeps. Where everything stands is crown_plan.gd's; Rattlecrown on his feet is
## scripts/foes/rattlecrown.gd.
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
## THE SCRAPYARD (version 49; how it works is Claude's choice until Darren says):
##   - The Scrapyard gate is in the Gatehouse's bottom wall; the horn opens it, for good.
##   - The far door of the Gatehouse, the Crane Yard and the Shaman's Furnace is barred until everybody in that room
##     is beaten; then the bars go up. The rooms fill again (and their doors are barred again) only while nobody of
##     the squad is inside the Scrapyard's walls (foes.gd).
##   - In the Furnace each Shaman keeps one Brute warded while it lives ("kill the Shamans first").
##   - The Gatehouse's "elite handler" is an elite slinger for now: elite loot, but no piece of the horn.
##   - The crane and its cab, the kennels and the watching goblins wait for their art.
##
## STAND-INS, all Claude's choices until the anvil is built:
##   1. (Until version 49 the Throne Room stood in a corner of the land, with the Scrapyard gate in its own door.)
##   2. (Gone with it.)
##   3. Pip mends the horn himself, by his cave-mouth camp, for MEND_TIN tin bars and MEND_COPPER copper bars (tin
##      and copper make the bronze; there is no anvil yet). It takes every player's pieces.
##   4. The first kill's hoard gives everyone the Twice thread, an ACTIVE BLANK stone, a TROPHY SEAT, Memory, coins
##      and bars (Darren, 24 November: "Twice + an active blank + +1 seat + Memory", the blank in the golden hoard
##      chest with the other loot). Claude's: everybody gets their own blank, as every chest's loot; the seat is the
##      spirit's own, on every weapon, once a character (scripts/weapon/swing_build.gd, `trophy`). The forge's
##      beam to the Greenwood waits for the Greenwood. A repeat kill's gives coins and bars (bars stand in for
##      bronze and scrap).
##
## THE GATE SHUTS BEHIND YOU, AND HIS HOARD. Darren, 23 November, of the Art builder's ideas for the bigger hall:
## "Make the chest golden and the gate better as it's special loot, quite like the idea of goblins watching on the
## fight and the gate closing behind". How they work is Claude's choice until he says:
##   - When the horn is blown in front of the throne the Throne Room's own gate shuts. It opens again when he falls,
##     and when the fight is called off. Whoever of the squad is outside it then is left outside until it opens.
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
##   - A trap is one tile of the floor, always there to be seen: a slab sunk below a kerb, with holes in it.
##     Nothing happens until somebody of the squad steps on it. Then it rattles for SPIKE_WARN seconds (its own warning), and the spikes
##     come up and stay up for SPIKE_UP seconds. Whoever is on it as they come up, or steps onto it while they are
##     up, is hurt (once for each time it comes up). Then it goes down and rests a moment.
##   - So walking or running straight across traps does not hurt (you are off each one before its spikes are up);
##     standing on one, or being knocked onto one and staying, does. A dodge takes you over raised spikes unhurt,
##     as it takes you through anything.
##   - Only the squad sets them off, and only the squad is hurt: the goblins know where they laid them.
##   - They lie in patches to either side of the middle of the room, and in a row just inside the gate: the
##     first thing you cross, and the place to learn what they do.
##   - Since version 50 the slabs are painted into the floor from the Art builder's still of the hall (the floor's
##     own paving, sunk below a kerb, three collared holes), and the spikes are its pictures (spike_trap_warn, _rise
##     and _up in the Scrapyard's sheet); while a trap rattles its rim is drawn in warning orange.
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
const SHUT_TIP := 1.8              # the tip line says the gate has shut for this long, then what is coming
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
	"shut": "The gate shuts behind you.",
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
var first_win := false
var hoard := ""                    # what his hoard's chest holds, unopened: "" nothing, "first" (the first kill's), "again"
var shut_in := false               # the gate has shut behind the squad (a fight is on)
var card_in := 0.0                 # seconds until the card says what the first hoard held
var tip_left := 0.0
var tip_next := ""             # the tip that follows the one showing, and in how long
var tip_next_in := 0.0

var gate: Folk.Actor               # the Scrapyard gate
var inner: Folk.Actor              # the Throne Room's own gate
var inner_shape: CollisionShape2D
var doors: Array = []              # the rooms' barred far doors: [{room, group (its index in the enemies' plan), bars: Bars, shape, open}]
var ward_group := -1               # the Furnace's group in the enemies' plan
var throne: Folk.Actor
var chest: Sprite2D                # the hoard's
var chest_t := -1.0                # seconds since its lid started up (under 0: it is not moving)
var bars: Bars
var bars_shape: CollisionShape2D
var yard: Texture2D                # the Scrapyard's sheet, and its book
var yard_book := {}
var _chest_texs := {}              # the hoard chest's pictures, made once
var dress: Array = []
var scenery: Array = []            # the stands' fronts and rails, and the goblins who watch (still pictures)
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
	const TALL := 11.0             # how far the spikes stand up (art pixels)
	# The stand-in's colours are the ones of the Art builder's still of the hall (hall_final.png): the floor's own
	# paving stone, sunk below a kerb, with an iron collar round each hole.
	const STONE := Color("#344856")
	const JOINT := Color("#2b3247")
	const KERB := Color("#446264")
	const KERB_TOP := Color("#5f8072")
	const HOLE := Color("#19142a")
	const COLLAR := Color("#6e6a7c")
	const IRON := Color("#8c8894")
	const TIP := Color("#e0e2d0")
	const WARN := Color("#ff8a3c")    # the game's warning orange, as the marks of his attacks

	var tile := Vector2i.ZERO
	var sheet: Texture2D
	var book := {}                 # the Scrapyard's sprites, if the art has the trap's
	var state := "down"            # down, warn, rise, up, lower
	var t := 0.0
	var rest := 0.0
	var hit := {}                  # the players this rise has hurt
	var edges := 0                 # the sides with no trap beside them (1 up, 2 right, 4 down, 8 left): the kerb runs there
	var spikes: Node2D             # the stand-in's spikes: they stand among the players while the floor stays under them
	var _shown := ""

	## True when the Scrapyard's sheet has the trap's own pictures (then nothing here is drawn by the code).
	func drawn() -> bool:
		return sheet != null and (book.get("spike_trap_down", {}) as Dictionary).has("box")

	func go(to: String) -> void:
		state = to
		t = 0.0
		# Down, it lies in the floor under everyone; up, the spikes stand among them. (The stand-in's floor stays
		# under everyone and its spikes are a thing of their own.)
		z_index = -4 if to in ["down", "warn"] or not drawn() else 0
		queue_redraw()
		if spikes != null:
			spikes.queue_redraw()

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
			if spikes != null:
				spikes.queue_redraw()

	## Where the four holes of the stand-in are: the top left corner of each.
	func holes() -> Array:
		var out: Array = []
		for j in 2:
			for i in 2:
				out.append(Vector2(-12.0 + 16.0 * float(i), -10.0 + 14.0 * float(j)))
		return out

	## The stand-in's spikes, drawn by `spikes` (a thing of its own, so that it sorts among the players).
	func draw_spikes(on: Node2D) -> void:
		if state in ["down", "warn"] or drawn():
			return
		var tall := roundf(up() * TALL) * PX
		if tall <= 0.0:
			return
		for at: Vector2 in holes():
			# A pale blade three art pixels wide with a shaded side, and a point.
			on.draw_rect(Rect2(at.x + 2.0, at.y + 4.0 - tall, 4, tall), TIP)
			on.draw_rect(Rect2(at.x + 6.0, at.y + 4.0 - tall, 2, tall), IRON)
			on.draw_rect(Rect2(at.x + 2.0, at.y + 2.0 - tall, 4, 2), TIP)
			on.draw_rect(Rect2(at.x + 2.0, at.y - tall, 2, 2), TIP)

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
			if state == "warn":
				# The slab itself is painted into the floor (CrownPlan.stamp); while it rattles its rim is warning
				# orange, so the warning is seen round the feet of whoever set it off.
				draw_rect(Rect2(-16, -16, 32, 2), WARN)
				draw_rect(Rect2(-16, 14, 32, 2), WARN)
				draw_rect(Rect2(-16, -16, 2, 32), WARN)
				draw_rect(Rect2(14, -16, 2, 32), WARN)
			draw_set_transform(Vector2(0, 16), 0.0, Vector2(PX, PX))
			draw_texture_rect_region(sheet, Rect2(-float(o[0]), -float(o[1]), fw, float(box[3])), Rect2(float(box[0]) + fw * float(k), float(box[1]), fw, float(box[3])))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		# The stand-in, after the Art builder's still of the hall: the floor's own paving, sunk below a kerb, with an
		# iron collar round each of its four holes and the spikes' tips showing in them (Darren, 23 November, of the
		# traps and the paving: "it has to look part of the world and not just a thing placed onto"). While it
		# rattles the collars and the slab's rim are warning orange and the tips jump. The spikes themselves are draw_spikes'.
		draw_rect(Rect2(-16, -16, 32, 32), STONE)
		draw_rect(Rect2(-16, 14, 32, 2), JOINT)
		draw_rect(Rect2(14, -16, 2, 32), JOINT)
		var left := 4.0 if edges & 8 else 0.0
		var right := 4.0 if edges & 2 else 0.0
		if edges & 1:
			draw_rect(Rect2(-16, -16, 32, 4), JOINT)          # the shadow of the kerb on the sunk floor
			draw_rect(Rect2(-16.0 - left, -20, 32.0 + left + right, 4), KERB)
			draw_rect(Rect2(-16.0 - left, -20, 32.0 + left + right, 2), KERB_TOP)
			draw_rect(Rect2(14, -20, 2, 4), JOINT)
		if edges & 4:
			draw_rect(Rect2(-16.0 - left, 16, 32.0 + left + right, 4), KERB)
			draw_rect(Rect2(-16.0 - left, 16, 32.0 + left + right, 2), KERB_TOP)
			draw_rect(Rect2(14, 16, 2, 4), JOINT)
		if edges & 8:
			draw_rect(Rect2(-16, -16, 2, 32), JOINT)
			draw_rect(Rect2(-20, -16, 4, 32), KERB)
			draw_rect(Rect2(-20, 14, 4, 2), JOINT)
		if edges & 2:
			draw_rect(Rect2(16, -16, 4, 32), KERB)
			draw_rect(Rect2(16, 14, 4, 2), JOINT)
		var jump := 0.0
		if state == "warn":
			jump = 2.0 if int(t * 16.0) % 2 == 0 else 0.0
			# The rattle's warning has to be seen round the feet of whoever set it off: the slab's own rim, too.
			draw_rect(Rect2(-16, -16, 32, 2), WARN)
			draw_rect(Rect2(-16, 14, 32, 2), WARN)
			draw_rect(Rect2(-16, -16, 2, 32), WARN)
			draw_rect(Rect2(14, -16, 2, 32), WARN)
		for at: Vector2 in holes():
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(12, 8)), WARN if state == "warn" else COLLAR)
			draw_rect(Rect2(at, Vector2(8, 4)), HOLE)
			if state in ["down", "warn"]:
				draw_rect(Rect2(at.x + 2.0, at.y + 2.0 - jump, 4, 2.0 + jump), TIP if state == "warn" else IRON)


## The stand-in spikes of one trap (see Trap.draw_spikes).
class Spikes extends Node2D:
	var of                         # the Trap

	func _draw() -> void:
		if of != null:
			of.draw_spikes(self)

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
	return (plan["hoard_bars"] as Vector2) * UNIT


## The foot of the Throne Room's own gate.
func inner_feet() -> Vector2:
	return (plan["inner_foot"] as Vector2) * UNIT


func yard_rect() -> Rect2:
	var r: Rect2i = plan["yard"]
	return Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)


func alcove_rect() -> Rect2:
	var r: Rect2i = plan["alcove"]
	return Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)


func room_rect() -> Rect2:
	var r: Rect2i = plan["room"]
	return Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)


## The ground in front of the Scrapyard gate.
func mouth() -> Vector2:
	return (Vector2(plan["meet"]) + Vector2(0.5, 0.5)) * TILE


## Which way from the cave the Scrapyard gate lies, in words.
func side_word() -> String:
	return str(plan.get("compass", "east"))


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
	# The Throne Room's own gate, in the door below it: the same gate, standing open until the fight.
	inner = _actor(yard, {"shut": front, "opening": book.get("gate_front_opening", {}), "open": book.get("gate_front_open", {})},
		front.get("origin", [28, 63]), inner_feet())
	inner_shape = _solid(inner_feet(), Vector2(48, 10) * UNIT)
	for side in [-1.0, 1.0]:
		_solid(inner_feet() + Vector2(side * 20.0 * UNIT, 0.0), Vector2(8, 10) * UNIT)
	# The rooms' barred far doors. (Which group is in which room: the game added the rooms' groups to the enemies'
	# plan.)
	var group_of := {}
	if foes != null:
		for gi in foes.plan.size():
			if (foes.plan[gi] as Dictionary).has("room"):
				group_of[str(foes.plan[gi]["room"])] = gi
	ward_group = int(group_of.get("furnace", -1))
	for d in plan["bars"]:
		var b := Bars.new()
		b.wide = 48.0
		b.sheet = yard
		b.book = {}                # (the hoard's own gate is golden: these are plain bars, drawn by the code until their art)
		var foot: Vector2 = (d["foot"] as Vector2) * UNIT
		b.position = foot - Vector2(0, SORT_BIAS)
		if world != null:
			world.add_child(b)
		else:
			add_child(b)
		doors.append({"room": str(d["room"]), "group": int(group_of.get(str(d["room"]), -1)), "bars": b, "tile": d["tile"],
			"shape": _solid(foot, Vector2(48, 6) * UNIT), "open": false})
		_bar(doors[doors.size() - 1], false, true)
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
		tr.add_to_group("unlit")          # a trap's warning is a danger mark: never dimmed by the light (version 68)
		if world != null:
			world.add_child(tr)
		else:
			add_child(tr)
		traps.append(tr)
		trap_at[tile] = tr
		if not tr.drawn():
			tr.spikes = Spikes.new()
			tr.spikes.of = tr
			tr.spikes.position = tr.position
			tr.spikes.add_to_group("unlit")
			if world != null:
				world.add_child(tr.spikes)
			else:
				add_child(tr.spikes)
	# The kerb runs round each patch of them: along every side of a trap that has no trap beside it.
	for tr: Trap in traps:
		var sides := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		for k in 4:
			if not trap_at.has(tr.tile + sides[k]):
				tr.edges |= 1 << k
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
	its.append({"at": bars_feet() - Vector2(0, 40), "radius": HOARD_REACH, "lift": 104.0, "text": "Open Rattlecrown's hoard",
		"can": func(_i): return hoard != "" and not fighting(), "use": func(i): open_hoard(i)})
	# The braziers and the scrap piles round the arena.
	for d in plan["dress"]:
		var info: Dictionary = book.get(str(d[0]), {})
		var a := _actor(yard, {"idle": info}, info.get("origin", [0, 0]), (d[1] as Vector2) * UNIT)
		if str(d[0]) == "brazier":
			a.add_to_group("unlit")       # a light itself (version 68)
		a.play("idle")
		a.face(bool(d[3]))
		dress.append(a)
		_solid((d[1] as Vector2) * UNIT, (d[2] as Vector2) * UNIT)
		_block_under(d[1], d[2])
	# The stands round the arena (version 50): nobody steps onto them, and on them the goblins watch. (The planks are
	# painted into the floor: CrownPlan.stamp.)
	for r: Rect2i in plan.get("stands", []):
		_solid((Vector2(r.position.x + r.size.x * 0.5, r.end.y)) * TILE, Vector2(r.size) * TILE)
		if foes != null and foes.nav != null:
			for ty in range(r.position.y, r.end.y):
				for tx in range(r.position.x, r.end.x):
					foes.nav.block(Vector2i(tx, ty))
	for d in plan.get("scenery", []):
		var still := _still(str(d[0]), d[1], bool(d[2]), float(d[3]), int(d[4]))
		if still != null:
			scenery.append(still)
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
		var key := "%s:%d" % [name, frame]
		if _chest_texs.has(key):
			return _chest_texs[key]
		var box: Array = own["box"]
		var w := int(own["frame"][0]) if own.has("frame") else int(box[2])
		var t := AtlasTexture.new()
		t.atlas = yard
		t.region = Rect2(int(box[0]) + frame * w, int(box[1]), w, int(box[3]))
		_chest_texs[key] = t
		return t
	return loot._frame(name, frame) if loot != null else null


## A still picture off the Scrapyard's sheet: its foot at `foot` (art pixels), sorting `up` art pixels above it.
func _still(name: String, foot: Vector2, mirrored: bool, up: float, z: int) -> Sprite2D:
	var info: Dictionary = yard_book.get(name, {})
	if yard == null or not info.has("box"):
		return null
	var box: Array = info["box"]
	var o: Array = info.get("origin", [0, 0])
	var t := AtlasTexture.new()
	t.atlas = yard
	t.region = Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3]))
	var sp := Sprite2D.new()
	sp.texture = t
	sp.centered = false
	sp.flip_h = mirrored
	var frames := maxi(int(info.get("frames", 1)), 1)
	sp.hframes = frames
	if frames > 1:
		# A loop (the crowd's cheering): each one starts on its own beat, so they do not all move together.
		sp.set_meta("fps", float(info.get("fps", 4)))
		sp.set_meta("beat", float(posmod(int(foot.x * 7.0 + foot.y * 13.0), 97)) / 97.0 * float(frames))
	var w := float(box[2]) / float(frames)
	var ox := w - float(o[0]) if mirrored else float(o[0])
	sp.offset = Vector2(-ox, -float(o[1]) + up)
	sp.scale = Vector2(UNIT, UNIT)
	sp.position = (foot - Vector2(0, up)) * UNIT
	sp.z_index = z
	if world != null:
		world.add_child(sp)
	else:
		add_child(sp)
	return sp


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
	var way: bool = gate_open
	gate.play("open" if way else "shut")
	gate_shape.set_deferred("disabled", way)
	inner.play("shut" if shut_in else "open")
	inner_shape.set_deferred("disabled", not shut_in)
	# The enemies' way-finding: shut, nobody passes; open, the middle of the way is clear.
	if foes != null and foes.nav != null:
		for pair in [[plan["gate"], way], [plan["inner"], not shut_in]]:
			var at: Vector2i = pair[0]
			for dx in [-1, 0, 1]:
				if bool(pair[1]) and dx == 0:
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
	if was:
		inner.play("opening", false, true)
		Sfx.play(game, "gate", -8.0, 0.9)


## A room's barred door: up (open) or down.
func _bar(d: Dictionary, open: bool, at_once := false) -> void:
	d["open"] = open
	(d["bars"] as Bars).raise(open, at_once)
	(d["shape"] as CollisionShape2D).set_deferred("disabled", open)
	if foes != null and foes.nav != null:
		var at: Vector2i = d["tile"]
		for dx in [-1, 0, 1]:
			if open:
				foes.nav.unblock(at + Vector2i(dx, 0))
			else:
				foes.nav.block(at + Vector2i(dx, 0))


## Is everybody in this group of the enemies' plan beaten (and not back yet)?
func beaten_all(g: int) -> bool:
	if foes == null or g < 0 or g >= foes.plan.size():
		return true
	return (foes.fallen.get(g, {}) as Dictionary).size() >= (foes.plan[g]["members"] as Array).size()


## The Scrapyard's rooms: a door's bars go up when its room is beaten and come down if the room fills again; in the
## Furnace, a Shaman that stands keeps its Brute warded.
func _tick_rooms(_delta: float) -> void:
	for d in doors:
		var open := beaten_all(int(d["group"]))
		if open != bool(d["open"]):
			_bar(d, open)
			if open:
				Sfx.play(game, "gate", -12.0, 1.3)
		(d["bars"] as Bars).step(_delta)
	if foes != null and foes.packs.has(ward_group):
		var shamans := {}
		for e in (foes.packs[ward_group] as Pack).members:
			if is_instance_valid(e) and not e.dead and str(e.kind) == "shaman":
				shamans[int(e.get_meta("member", -1))] = true
		for e in (foes.packs[ward_group] as Pack).members:
			if is_instance_valid(e) and not e.dead and str(e.kind) == "scrap_brute" and shamans.has(int(e.get_meta("member", -1)) - 2):
				e.warded = maxf(e.warded, 0.6)


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
		# (The prompt over the gate already says what it wants: no second line on top of it.)
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
		if Rect2(inner_feet() + Vector2(-56, -44), Vector2(112, 64)).has_point(p.global_position):
			p.global_position.y = inner_feet().y - 52.0
		if alcove_rect().grow(6.0).has_point(p.global_position):
			p.global_position = bars_feet() + Vector2(0, 26)
	Sfx.play(game, "gate", -8.0, 0.7)
	throne.play("point")
	_blare()
	_top(true)
	# One line at a time, in the tip line: first that the gate has shut, then what is coming.
	_tip(SAYS["shut"])
	tip_next = SAYS["call"]
	tip_next_in = SHUT_TIP
	return true


func _top(on: bool) -> void:
	if loot != null:
		loot.said_y = NEWS_Y if on else 42.0


func _tip(words: String) -> void:
	tip_next = ""
	tip_next_in = 0.0
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
	boss.add_to_group("unlit")           # the boss and his marks are never dimmed by the light (version 68)
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


func _on_boss_died(e) -> void:
	if foes != null:
		foes.credit(e)      # (the killing blow's kill runes; Kill Rush)
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
			loot.give(i, "active_blank", 1, at, HOARD_OUT + 0.35, true)
			give_seat(i)
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


## Player i's spirit gains its trophy seat, on every weapon (once a character: one who has it already gets nothing).
func give_seat(i: int) -> bool:
	if game == null or not ("builds" in game) or i < 0 or i >= (game.builds as Array).size():
		return false
	return game.builds[i].add_trophy()


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


## Is anybody where the stands and their crowd fill the screen behind the HUD (the Throne Room and its doorway)? The
## HUD's backings are stronger then (Art.shade), so the bars and the belt read over the planks and the goblins.
func busy_view() -> bool:
	var r := room_rect().grow(TILE * 2.0)
	for p in players:
		if is_instance_valid(p) and r.has_point(p.global_position):
			return true
	return false


func _exit_tree() -> void:
	Art.busy_ground = false


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
		Art.busy_ground = false
		return
	clock += delta
	Art.busy_ground = busy_view()
	gate.step(delta)
	inner.step(delta)
	throne.step(delta)
	_tick_rooms(delta)
	for a in dress:
		a.step(delta)
	for sp: Sprite2D in scenery:
		if sp.hframes > 1:
			sp.frame = int(clock * float(sp.get_meta("fps", 4.0)) + float(sp.get_meta("beat", 0.0))) % sp.hframes
	bars.step(delta)
	if gate.anim == "opening" and gate.done():
		gate.play("open")
	if inner.anim == "opening" and inner.done():
		inner.play("open")
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
	if tip_next_in > 0.0:
		tip_next_in -= delta
		if tip_next_in <= 0.0 and tip_next != "":
			_tip(tip_next)
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
	return "His crown lies on top. It was never a crown: it is a thread of the old forge, Twice. Everyone here can thread Twice at the forge from now on.\nUnder it, an active blank stone each: infuse it at the forge. And your spirit has a new seat, on every weapon.\n\nThe Rusted Warhorn cracked as he fell. For another fight, take its three pieces from the elites again and bring them to Pip."


func _near(at: Vector2, far: float) -> bool:
	for p in players:
		if is_instance_valid(p) and p.global_position.distance_to(at) < far:
			return true
	return false


## A few words over a player's head, not more than once in a while.
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
		var text := "Blow the Rusted Warhorn at the Scrapyard gate, far to the %s in the outer ring." % side_word()
		if gate_open:
			text = "Fight through the Scrapyard to the Throne Room, and blow the Rusted Warhorn in front of Rattlecrown."
		return {"id": "horn", "name": "Blow the Horn", "text": text}
	if pieces >= 3:
		return {"id": "mend", "name": "Mend the Horn", "text": "Take the three pieces to Pip. He joins them for %d tin bars and %d copper bars." % [int(MEND_TIN), int(MEND_COPPER)]}
	if beaten > 0:
		return {}                  # he has been beaten: another fight is yours to choose
	return {"id": "crown", "name": "The Scrap Crown", "text": "Take the Rusted Warhorn's three pieces from the three elites: %d of 3." % pieces}


## Where the quest's mark at the screen's edge points (world units), or INF when it points nowhere: to the ground in
## front of the Scrapyard gate until somebody has been there, then to the gate, then to the throne; and to his hoard
## while it waits to be opened.
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
