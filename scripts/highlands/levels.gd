extends Node
## Memory, the forge's levels, the role trees' perks and what falling costs (version 45).
##
## From the Game Bible ("Levelling and specializations", decided 11 November; "Role trees", agreed 12 November):
##   - Memory "is earned from everything: killing, mining, chopping and building. It fills a bar on your character."
##     (What earns it is loot.gd's; what you carry is in your purse there, and in your character's save.)
##   - "At the forge you pour your bar in. When the forge's meter is full, every player levels up at the same time."
##     "The level belongs to the world save." "The forge shows how much more Memory the team needs for the next
##     level. On each level up, the forge speaks a short line recalling a fragment of its past."
##   - "One point per level, spent across four role trees." "Tree choices belong to each character." Points can be
##     reset at the forge "for a cost in Memory, paid from the Memory the player is carrying, not from what's banked".
##   - Death: "You lose some money and half your unbanked Memory (left as a glowing marker you or a teammate can
##     collect), never gear."
##
## Claude's choices, until Darren says otherwise (they are listed in the README and the Game Bible):
##   - The squad starts at level 0. Level 1 needs FIRST_LEVEL Memory and every level after it LEVEL_STEP more (the
##     Bible leaves "Memory needed per level" open; it asks for about level 5 at the Highlands' boss). Version 51
##     raised LEVEL_STEP from 100 to 300 once the middle and outer rings were filled: `tools/memory_sum.gd` adds up
##     what lies on the way to Rattlecrown, and a usual run (the inner ring, half the middle ring, the way through the
##     outer ring and the Scrapyard) now comes to about 4,600 Memory, level 5; going straight there, level 4.
##   - EVERY PLAYER POURS THEIR OWN FULL SHARE (loot.gd gives everyone a full share of every chest and kill), so the
##     forge needs that much FROM EACH PLAYER: with two players the meter is twice as long. A squad of four then
##     levels at the pace of one player alone. What is banked is kept as one player's share of it.
##   - A Memory bar is full when you carry what the forge still needs from you for the next level.
##   - Falling leaves HALF your carried Memory at the place you fell, as a marker that anybody can take by walking
##     over it. Markers are saved with the world and stay until somebody takes them. A TENTH of your coins is gone
##     for good ("some money"). The marker is a light: it is drawn over whatever stands there, so a bush or a pine
##     never hides it.
##   - Forgetting your perks costs FORGET_COST Memory for each perk, all of them at once.
##   - A character with more perks than the world's level keeps them, and the first so many are awake (perks.gd).
##   - The forge's lines (FORGE_LINES) are stand-ins written only from what the Bible already says about the forge.
##     The story is Darren's: they are his to rewrite.
##
## THE FOUR SIGNATURE PERKS are built here and in the places they hook into:
##   - Challenge (Warden): finisher() tells each enemy the finisher hit (enemy.gd's challenge()); softened() takes
##     the quarter off what a Challenged enemy does to its challenger.
##   - Punish (Striker): punishes() is asked by the player's own hit (player.gd's _hit_enemy()); what Open means is
##     enemy.gd's is_open() and each enemy's own (a lunge, a swing or a throw that hit nobody).
##   - Kindle (Mender): finisher() drops a Spark; tick() lets somebody who is hurt take it.
##   - Ore Sense (Delver): the looks only (_draw_under): the ore near that player shimmers through the rock. (The
##     Bible also names buried chests and hidden rooms. The land has neither yet, so there is nothing of theirs to
##     show; the art for a chest's shimmer is on the sheet for when it has.)
## Their looks are the Art builder's first drafts (art/roles/: the Spark, the shimmer; enemy.gd draws the marks for
## Challenged and Open).
##
## THE RULES AND THE LOOKS ARE KEPT APART, as everywhere: what changes the game happens on the tick (pour(), learn(),
## forget(), fell(), finisher(), tick()); the bar, the roundel, the markers' pictures and the level-up are looks.

const Perks := preload("res://scripts/highlands/perks.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")
const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Enemy := preload("res://scripts/enemy.gd")

const UNIT := Art.PIXEL
const TILE := 16.0 * UNIT
const FEET := 14.0                 # a player's feet are this far under their middle
const PICK := 44.0                 # how near a marker you come to take it
const SPARK_PICK := 30.0           # and a Spark
const MARKER_ARMS := 1.5           # a marker cannot be taken in its first moments (you may wake right beside it)
const RISE_TIME := 0.8             # the level-up's eight pictures
const SIZE := Vector2(640, 360)
const MARGIN := 10.0
const HP_BAR := Vector2(92, 12)    # the health bar (scripts/ui/hud.gd): the Memory bar sits right under it
const BAR_DROP := 8.0              # what is under the health bar moves down this far to make room

static var FIRST_LEVEL := 100      # Memory the forge needs from each player for the squad's first level ...
static var LEVEL_STEP := 300       # ... and this much more for every level after it (100 until version 51)
static var LEVEL_CAP := 20         # the Bible: "about 20 (suggested)"
static var FALL_MEMORY := 0.5      # the share of your carried Memory that stays where you fell
static var FALL_COINS := 0.1       # the share of your coins that is gone for good
static var FORGET_COST := 20       # Memory for each perk you forget
static var CHALLENGE_TIME := 5.0
static var CHALLENGE_BOSS_TIME := 3.0
static var CHALLENGE_BOSS_REST := 10.0
static var CHALLENGE_SOFTEN := 0.25
static var SPARK_EVERY := 4.0
static var SPARK_HEAL := 0.1
static var SPARK_LIFE := 10.0
static var ORE_SENSE_TILES := 9.0
# The Striker's other perks (version 53). The Bible gives these numbers; how far behind is "behind" is enemy.gd's.
static var CLOSE_CALL_OPEN := 2.0  # Close Call: an enemy whose attack you dodged through is Open this long
static var SHARP_TIME := 6.0       # Sharp: this long without being hit and your weapon glints ...
static var SHARP_TIMES := 2.0      # ... and your next finisher hits this many times as hard
static var EXPOSE_TIME := 4.0      # Expose: a boss or an elite you crit is Exposed this long ...
static var EXPOSE_MORE := 0.15     # ... and everyone's hits on it do this much more
static var EXECUTION_TIMES := 3.0  # Execution: a finisher on an Open enemy hits this many times as hard ...
static var EXECUTION_BELOW := 1.0 / 3.0   # ... and a normal enemy left below this share of its health dies outright

## What the forge says as the squad reaches each level, from level 1. Stand-ins: see the top of this file.
const FORGE_LINES := [
	"I remember hands. Many hands, and the ring of hammers.",
	"I remember these hills before the quarry. Tin came first. Then copper.",
	"They called themselves keepers. I think I was what they kept.",
	"Bells in a gorge. Three notes, or four. I knew the tune once.",
	"A watch was kept on the hill. One of them stayed up there when the others came down to me.",
	"They said that I must sleep. I do not remember agreeing.",
]
const FORGE_LINE_LATER := "More comes back to me. Not enough yet."

const INK := Color("#e8e4bc")
const AMBER := Color("#ffc850")
const PLATE := Color("#19142a")
const PALE := Color("#7fe0c0")     # the Spark's verdigris, for the number it heals
const GLINT := Color("#fff0b4")    # the Striker's pale gold (the Open mark's): Sharp's glint, Close Call, Execution


class Layer extends Node2D:
	var draws: Callable

	func _draw() -> void:
		draws.call(self)


var game                           # the Highlands scene
var map: LandMap
var players: Array = []
var loot                           # loot.gd: the purses (carried Memory and coins), and the line everyone reads

var level := 0                     # the squad's level: the world's
var banked := 0.0                  # what the forge holds towards the next level, as ONE player's share of it
var perks: Array = []              # per player: the perks they have learnt, in the order they learnt them
var markers: Array = []            # [{at: Vector2, memory: int, age: float}] what fallen players left
var sparks: Array = []             # [{at: Vector2, left: float, by: int}] the Menders' Sparks
var spark_wait: Array = []         # per player: seconds until their finisher can knock out another Spark
var rises: Array = []              # looks only: [{i, t}] the level-up playing over player i
var takes: Array = []              # looks only: [{at, t}] a marker going as it is taken
var spark_takes: Array = []        # looks only: [{at, t}] a Spark going as it is taken
var was_full: Array = []           # per player: their bar was full on the last tick
var calm: Array = []               # per player: seconds since they were last hit (Sharp glints at SHARP_TIME)
var sharp_spent: Array = []        # per player: their glint went into a finisher this tick (it goes at the tick's end)
var close_called: Array = []       # per player: the dodge (when it began) that last made a Close Call: one word a dodge
var sensed: Array = []             # looks only: what Ore Sense shows now, [[tile, "tin" | "copper"]]
var sensed_t := 0.0
var clock := 0.0
var under: Layer
var over: Layer
var layer: CanvasLayer
var panel: Control


func _ready() -> void:
	under = Layer.new()
	under.draws = _draw_under
	under.z_index = -8             # the Sparks: on the ground, under everybody
	add_child(under)
	over = Layer.new()
	over.draws = _draw_over
	over.z_index = 40
	add_child(over)
	layer = CanvasLayer.new()
	layer.layer = 6                # over the health bars' own plate (scripts/ui/hud.gd is on 5)
	add_child(layer)
	panel = Control.new()
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	panel.draw.connect(_draw_hud)
	for i in players.size():
		perks.append([])
		spark_wait.append(0.0)
		was_full.append(false)
		calm.append(0.0)
		sharp_spent.append(false)
		close_called.append(-99.0)
		if is_instance_valid(players[i]):
			players[i].roles = self


func _exit_tree() -> void:
	for p in players:
		if is_instance_valid(p) and p.roles == self:
			p.roles = null


# --- The forge's levels -------------------------------------------------------------------

## The Memory the forge needs from each player to take the squad from `at` to the next level (0 at the cap).
static func need(at: int) -> float:
	if at >= LEVEL_CAP:
		return 0.0
	return float(maxi(FIRST_LEVEL + LEVEL_STEP * maxi(at, 0), 1))


## How many are playing: the forge needs every one of them's share.
func squad() -> int:
	return maxi(players.size(), 1)


## What player i carries (it is their purse's, in loot.gd).
func carried(i: int) -> int:
	return int(loot.purses[i].memory) if loot != null and i >= 0 and i < loot.purses.size() else 0


## The Memory the forge still needs from each player for the next level (0 at the cap).
func each_still() -> float:
	return maxf(need(level) - banked, 0.0)


## The forge's meter in whole Memory, as the screen shows it: [what it holds, what it needs], for the whole squad.
func meter() -> Array:
	var n := float(squad())
	return [roundi(banked * n), roundi(need(level) * n)]


## How full player i's bar is, 0 to 1: full when they carry what the forge still needs from them.
func share(i: int) -> float:
	var still := each_still()
	if still <= 0.0:
		return 0.0
	return clampf(float(carried(i)) / still, 0.0, 1.0)


## Player i pours everything they carry into the forge. Returns {poured, levels: how many the squad gained,
## from: the level before, was: how full the meter was before (0 to 1)}. At the cap nothing is taken.
func pour(i: int) -> Dictionary:
	var out := {"poured": 0, "levels": 0, "from": level, "was": banked / need(level) if need(level) > 0.0 else 0.0}
	var m := carried(i)
	if m <= 0 or level >= LEVEL_CAP:
		return out
	var n := float(squad())
	loot.purses[i].memory = 0
	banked += float(m) / n
	while level < LEVEL_CAP and banked >= need(level) - 0.0001:
		banked = maxf(banked - need(level), 0.0)
		level += 1
		out["levels"] = int(out["levels"]) + 1
	if level >= LEVEL_CAP and banked > 0.0:
		# The last level there is: what is left over goes back to whoever brought it.
		var back := floori(banked * n)
		loot.purses[i].memory = back
		m -= back
		banked = 0.0
	out["poured"] = m
	if int(out["levels"]) > 0:
		for k in players.size():
			rises.append({"i": k, "t": -0.12 * float(k)})
		if loot != null:
			loot.say("The squad is level %d: a point for everyone to spend at the forge" % level)
	return out


## What the forge says on reaching a level.
static func line_for(at: int) -> String:
	if at >= 1 and at <= FORGE_LINES.size():
		return str(FORGE_LINES[at - 1])
	return FORGE_LINE_LATER


# --- The role trees -----------------------------------------------------------------------

## The perks of player i that are awake in this world: the first so many as the squad has levels.
func awake(i: int) -> Array:
	return Perks.awake(perks[i], level) if i >= 0 and i < perks.size() else []


## Is this perk of player i's awake?
func has(i: int, id: String) -> bool:
	return i >= 0 and i < perks.size() and (perks[i] as Array).find(id) >= 0 and (perks[i] as Array).find(id) < level


func has_p(p, id: String) -> bool:
	return has(players.find(p), id)


func any_has(id: String) -> bool:
	for i in perks.size():
		if has(i, id):
			return true
	return false


## The points player i has to spend: one for every level, less what they have spent.
func points(i: int) -> int:
	return maxi(level - (perks[i] as Array).size(), 0) if i >= 0 and i < perks.size() else 0


## Player i spends a point on a perk. Returns "" if they have it now, or why not, in words.
func learn(i: int, id: String) -> String:
	if i < 0 or i >= perks.size():
		return "Nobody to learn it."
	var why := Perks.why_not(id, perks[i], points(i))
	if why == "":
		(perks[i] as Array).append(id)
	return why


## What forgetting every perk costs player i, in the Memory they carry.
func forget_cost(i: int) -> int:
	return int(FORGET_COST) * (perks[i] as Array).size() if i >= 0 and i < perks.size() else 0


## Player i forgets all their perks and has their points back, for Memory they are carrying. False if they have no
## perks, or do not carry enough.
func forget(i: int) -> bool:
	if i < 0 or i >= perks.size() or (perks[i] as Array).is_empty() or carried(i) < forget_cost(i):
		return false
	loot.purses[i].memory -= forget_cost(i)
	perks[i] = []
	return true


# --- Falling ------------------------------------------------------------------------------

## Player i fell at this place. Half the Memory they carried stays there as a marker; a tenth of their coins is gone.
func fell(i: int, at: Vector2) -> void:
	if loot == null or i < 0 or i >= loot.purses.size():
		return
	var purse = loot.purses[i]
	var share := clampf(FALL_MEMORY, 0.0, 1.0)
	if game != null and "gear" in game and game.gear != null:
		share = game.gear.fall_share(i, share)      # (the Ashen Locket)
	var lost_m := floori(float(purse.memory) * share)
	var lost_c := floori(float(purse.coins) * clampf(FALL_COINS, 0.0, 1.0))
	purse.memory -= lost_m
	purse.coins -= lost_c
	if lost_m > 0:
		_marker(at, lost_m)
	var who := "You fell" if players.size() == 1 else "Player %d fell" % (i + 1)
	var whose := "you" if players.size() == 1 else "they"
	if lost_m > 0 and lost_c > 0:
		loot.say("%s: %d Memory waits where %s fell, and %d coins are gone" % [who, lost_m, whose, lost_c])
	elif lost_m > 0:
		loot.say("%s: %d Memory waits where %s fell" % [who, lost_m, whose])
	elif lost_c > 0:
		loot.say("%s: %d coins are gone" % [who, lost_c])


func _marker(at: Vector2, memory: int) -> void:
	markers.append({"at": at, "memory": memory, "age": 0.0})


# --- The signature perks ------------------------------------------------------------------

## Player p's finisher landed on these enemies (player.gd tells us: a melee finisher, a heavy arrow, a staff's surge).
func finisher(p, hits: Array) -> void:
	var i := players.find(p)
	if i < 0 or hits.is_empty():
		return
	if has(i, "challenge"):
		for e in hits:
			if is_instance_valid(e) and not e.dead and e.has_method("challenge"):
				e.challenge(p, CHALLENGE_BOSS_TIME if e.is_boss() else CHALLENGE_TIME, CHALLENGE_BOSS_REST)
	if has(i, "kindle") and float(spark_wait[i]) <= 0.0:
		for e in hits:
			if not is_instance_valid(e):
				continue
			# Knocked out of the enemy, on the side away from whoever struck it (where there is ground to lie on).
			var away: Vector2 = e.global_position - p.global_position
			var at: Vector2 = e.global_position + (away.normalized() * 28.0 if away.length() > 1.0 else Vector2.ZERO)
			if map != null and not map.walkable(int(floorf(at.x / TILE)), int(floorf(at.y / TILE))):
				at = e.global_position
			sparks.append({"at": at, "left": float(SPARK_LIFE), "by": i})
			spark_wait[i] = float(SPARK_EVERY)
			Sfx.play(game, "pickup", -14.0, 1.6)
			break


## What a hit on player p comes to after Challenge: an enemy that p has Challenged does a quarter less to p.
func softened(p, amount: float, by) -> float:
	if by != null and is_instance_valid(by) and "challenged_by" in by and by.challenged_by == p and float(by.challenge_left) > 0.0:
		return amount * (1.0 - clampf(CHALLENGE_SOFTEN, 0.0, 1.0))
	return amount


## Does player p's own hit on this enemy crit for certain? (Punish: it does while the enemy is Open, or what counts
## as Open for p.)
func punishes(p, e) -> bool:
	return has_p(p, "punish") and hits_open(p, e)


# --- The Striker's other perks (version 53) -------------------------------------------------
# Close Call, Flank, Keep the Chain, Sharp, Kill Rush, Expose and Execution. Each is told here by the place in
# player.gd it hangs on: dodged() by an attack that found p mid-dodge, boost() and landed() by p's own hit,
# was_hit() by a hit p took, killed() by a kill credited to p, keeps_chain() by p's dodge.

## Does player p's hit on this enemy count as a hit on an Open enemy? It does while the enemy is Open, and with Flank
## when p hits it from behind (enemy.gd's behind(): its back is the side it is drawn facing away from).
func hits_open(p, e) -> bool:
	if not is_instance_valid(e) or not e.has_method("is_open"):
		return false
	if e.is_open():
		return true
	return has_p(p, "flank") and e.has_method("behind") and is_instance_valid(p) and e.behind(p.global_position)


## An attack of this enemy's found player p while p's dodge made them untouchable. Close Call: it is Open for
## CLOSE_CALL_OPEN. (The word over p shows once a dodge, however many times the attack finds them in it.)
func dodged(p, by) -> void:
	var i := players.find(p)
	if not has(i, "close_call") or by == null or not is_instance_valid(by) or not by.has_method("open_for") or by.dead:
		return
	by.open_for(CLOSE_CALL_OPEN)
	if float(close_called[i]) != float(p.dodge_started):
		close_called[i] = p.dodge_started
		p._label("CLOSE CALL", GLINT)
		Sfx.play(game, "click", -8.0, 1.8)


## Keep the Chain: does p's dodge leave their combo where it was?
func keeps_chain(p) -> bool:
	return has_p(p, "keep_the_chain")


## Player p was hit (it hurt them). Sharp's clock starts again, and a glint is lost.
func was_hit(p) -> void:
	var i := players.find(p)
	if i >= 0 and i < calm.size():
		calm[i] = 0.0


## Is player p's weapon glinting (Sharp: they have gone SHARP_TIME without being hit)?
func glinting(i: int) -> bool:
	return _sharp(i) and not bool(sharp_spent[i])


## Sharp is ready: a finisher that lands this tick is doubled (every enemy it hits, though the first spends it).
func _sharp(i: int) -> bool:
	return has(i, "sharp") and i < calm.size() and float(calm[i]) >= SHARP_TIME


## A kill is credited to player p (the Highlands' foes.gd tells them, then us). Kill Rush: a dodge charge back.
func killed(p) -> void:
	if has_p(p, "kill_rush") and is_instance_valid(p) and p.has_method("dodge_back"):
		p.dodge_back()


## What player p's own hit on enemy e is worth, before it lands: {times, execution}. `fin` says it is p's finisher.
## Sharp: a glinting finisher hits SHARP_TIMES as hard (the glint goes once the swing is done: every enemy one
## finisher hits has it). Execution: a finisher on an Open enemy hits EXECUTION_TIMES as hard. Exposed (somebody's
## Expose) is in enemy.gd's take_hit(), since it is everyone's hits, runes too.
func boost(p, e, fin: bool) -> Dictionary:
	var out := {"times": 1.0, "execution": false}
	var i := players.find(p)
	if i < 0 or not fin:
		return out
	if _sharp(i):
		out["times"] = float(out["times"]) * SHARP_TIMES
		sharp_spent[i] = true
	if has(i, "execution") and hits_open(p, e):
		out["times"] = float(out["times"]) * EXECUTION_TIMES
		out["execution"] = true
	return out


## Player p's own hit on enemy e has landed (`crit`: it was a crit; `was`: e's health before it). Expose: a crit on a
## boss or an elite Exposes it. Execution: a normal enemy left below EXECUTION_BELOW of its health dies outright.
func landed(p, e, crit: bool, boosted: Dictionary, was: float) -> void:
	var i := players.find(p)
	if i < 0 or not is_instance_valid(e):
		return
	if crit and has(i, "expose") and not e.dead and (e.is_boss() or bool(e.elite)) and e.has_method("expose"):
		e.expose(EXPOSE_TIME)
	if bool(boosted.get("execution", false)):
		p._label("EXECUTION", GLINT)
		if not e.dead and float(e.hp) < was and not e.is_boss() and not bool(e.elite) and float(e.hp) < float(e.max_hp) * EXECUTION_BELOW:
			e._apply_damage(float(e.hp), true, GLINT)


# --- Once a tick --------------------------------------------------------------------------

func tick(delta: float) -> void:
	clock += delta
	# Enemies show that they are Open only where somebody can use it.
	Enemy.show_open = any_has("punish")
	Enemy.exposed_more = EXPOSE_MORE
	for i in players.size():
		spark_wait[i] = maxf(float(spark_wait[i]) - delta, 0.0)
		# Sharp: a glint that went into a finisher is gone, and the clock starts again.
		if bool(sharp_spent[i]):
			sharp_spent[i] = false
			calm[i] = 0.0
		var glinted := glinting(i)
		calm[i] = float(calm[i]) + delta
		var p = players[i]
		if not is_instance_valid(p):
			continue
		if glinting(i) and not glinted:
			Sfx.play(game, "click", -12.0, 2.2)
		var full := share(i) >= 1.0
		if full and not bool(was_full[i]):
			p._label("ENOUGH FOR A LEVEL", AMBER)
			Sfx.play(game, "pickup", -10.0, 0.8)
		was_full[i] = full
	# What fallen players left: whoever walks over it takes it.
	for m in markers.duplicate():
		m["age"] = float(m["age"]) + delta
		if float(m["age"]) < MARKER_ARMS:
			continue
		for i in players.size():
			var p = players[i]
			if not is_instance_valid(p) or p.is_down or p.global_position.distance_to(m["at"]) > PICK:
				continue
			markers.erase(m)
			loot.give(i, "memory", int(m["memory"]), (m["at"] as Vector2) + Vector2(0, -20), 0.1)
			loot.say("%s %d Memory back" % ["You have" if players.size() == 1 else "Player %d has" % (i + 1), int(m["memory"])])
			Sfx.play(game, "pickup", -8.0, 1.1)
			takes.append({"at": m["at"], "t": 0.0})
			break
	# The Sparks: somebody who is hurt and walks over one is healed by it.
	for s in sparks.duplicate():
		s["left"] = float(s["left"]) - delta
		if float(s["left"]) <= 0.0:
			sparks.erase(s)
			continue
		for p in players:
			if not is_instance_valid(p) or p.is_down or p.hp >= p.max_hp or p.global_position.distance_to(s["at"]) > SPARK_PICK:
				continue
			var heal: float = p.max_hp * clampf(SPARK_HEAL, 0.0, 1.0)
			p.hp = minf(p.hp + heal, p.max_hp)
			p._label("+%d" % roundi(heal), PALE)
			Sfx.play(game, "pickup", -9.0, 1.9)
			spark_takes.append({"at": s["at"], "t": 0.0})
			sparks.erase(s)
			break


# --- What is saved ------------------------------------------------------------------------

## The squad's level, what the forge holds towards the next, and the markers, as plain values for the world save.
func world_data() -> Dictionary:
	var left: Array = []
	for m in markers:
		left.append([roundi((m["at"] as Vector2).x), roundi((m["at"] as Vector2).y), int(m["memory"])])
	return {"level": level, "banked": snappedf(banked, 0.001), "markers": left}


## And back. Whatever is missing stays as it was.
func set_world_data(d: Dictionary) -> void:
	if d.get("level") is int or d.get("level") is float:
		level = clampi(int(d["level"]), 0, LEVEL_CAP)
	if d.get("banked") is int or d.get("banked") is float:
		banked = clampf(float(d["banked"]), 0.0, maxf(need(level) - 0.001, 0.0))
	if d.get("markers") is Array:
		markers = []
		for v in d["markers"]:
			if v is Array and v.size() == 3 and (v[0] is int or v[0] is float) and (v[1] is int or v[1] is float) and (v[2] is int or v[2] is float) and int(v[2]) > 0:
				_marker(Vector2(float(v[0]), float(v[1])), int(v[2]))
				markers[-1]["age"] = MARKER_ARMS


## Player i's perks, for the character save.
func perks_data(i: int) -> Dictionary:
	return {"perks": (perks[i] as Array).duplicate()}


func set_perks_data(i: int, d: Dictionary) -> void:
	if d.get("perks") is Array:
		perks[i] = Perks.clean(d["perks"])


# --- Looks only ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	for t in takes:
		t["t"] = float(t["t"]) + delta
	takes = takes.filter(func(t): return float(t["t"]) < 4.0 / 12.0)
	for r in rises:
		var before: float = r["t"]
		r["t"] = before + delta
		if before < 0.4 and float(r["t"]) >= 0.4 and int(r["i"]) == 0:
			Sfx.play(game, "anvil", -9.0, 1.5)       # frame 4: the moment the level lands
	rises = rises.filter(func(r): return float(r["t"]) < RISE_TIME)
	for s in spark_takes:
		s["t"] = float(s["t"]) + delta
	spark_takes = spark_takes.filter(func(s): return float(s["t"]) < 4.0 / 12.0)
	# What Ore Sense shows is looked up twice a second.
	sensed_t -= delta
	if sensed_t <= 0.0:
		sensed_t = 0.5
		_sense()
	under.queue_redraw()
	over.queue_redraw()
	panel.queue_redraw()


## The ore tiles near every player who has Ore Sense awake.
func _sense() -> void:
	sensed = []
	if map == null or not any_has("ore_sense"):
		return
	var seen := {}
	var r := int(ceilf(ORE_SENSE_TILES))
	for i in players.size():
		if not has(i, "ore_sense") or not is_instance_valid(players[i]):
			continue
		var at: Vector2 = players[i].global_position / TILE
		var mid := Vector2i(int(floorf(at.x)), int(floorf(at.y)))
		for y in range(mid.y - r, mid.y + r + 1):
			for x in range(mid.x - r, mid.x + r + 1):
				var t := Vector2i(x, y)
				if seen.has(t) or Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(at) > ORE_SENSE_TILES:
					continue
				var k := map.kind(x, y)
				if k == LandMap.TIN or k == LandMap.COPPER:
					seen[t] = true
					sensed.append([t, "tin" if k == LandMap.TIN else "copper"])


## On the ground, under everybody: what Ore Sense shows through the rock, and the Sparks.
func _draw_under(ci: Node2D) -> void:
	# The shimmer: a few glints that come and go on each ore tile, in the ore's own colours. Every tile starts its
	# loop somewhere else, so a vein does not blink as one.
	for k in sensed.size():
		var t: Vector2i = sensed[k][0]
		var what := str(sensed[k][1])
		var at := Vector2(t) * 16.0 * UNIT
		if ItemArt.draw(ci, "shimmer_" + what, at, UNIT, Color.WHITE, int(clock * 4.0) + t.x * 3 + t.y * 5) == Vector2.ZERO:
			if fmod(clock * 0.5 + float(posmod(t.x * 7 + t.y * 13, 10)) * 0.1, 1.0) < 0.3:
				ci.draw_rect(Rect2(at + Vector2(float(3 + posmod(t.x * 5 + t.y * 3, 9)), float(3 + posmod(t.x * 3 + t.y * 11, 9))) * UNIT, Vector2(UNIT, UNIT)), INK)
	# The Sparks: a green square cross (the Memory mote is an amber diamond), hatched in its last two seconds.
	var o := ItemArt.origin("spark")
	for k in sparks.size():
		var s: Dictionary = sparks[k]
		var at := ((s["at"] as Vector2) / UNIT).floor()
		if ItemArt.draw(ci, "spark_fade" if float(s["left"]) < 2.0 else "spark", (at - o) * UNIT, UNIT, Color.WHITE, int(clock * 6.0) + k) == Vector2.ZERO:
			ci.draw_rect(Rect2((at + Vector2(-1, -9)) * UNIT, Vector2(2, 8) * UNIT), PALE)
			ci.draw_rect(Rect2((at + Vector2(-4, -6)) * UNIT, Vector2(8, 2) * UNIT), PALE)
	for s in spark_takes:
		ItemArt.draw(ci, "spark_take", ((((s["at"] as Vector2) / UNIT).floor()) - o) * UNIT, UNIT, Color.WHITE, clampi(int(float(s["t"]) * 12.0), 0, 3))


## Over everybody: the Memory left where somebody fell (a light: nothing that stands there hides it), and the
## level-up.
func _draw_over(ci: Node2D) -> void:
	var stand := ItemArt.origin("memory_marker")
	for m in markers:
		var at := ((m["at"] as Vector2) + Vector2(0, FEET)) / UNIT
		if ItemArt.draw(ci, "memory_marker", (at.floor() - stand) * UNIT, UNIT, Color.WHITE, int(clock * 6.0)) == Vector2.ZERO:
			ci.draw_rect(Rect2((at.floor() + Vector2(-2, -12)) * UNIT, Vector2(4, 4) * UNIT), AMBER)
	for t in takes:
		var at := ((t["at"] as Vector2) + Vector2(0, FEET)) / UNIT
		ItemArt.draw(ci, "memory_marker_take", (at.floor() - stand) * UNIT, UNIT, Color.WHITE, clampi(int(float(t["t"]) * 12.0), 0, 3))
	for r in rises:
		var i := int(r["i"])
		if float(r["t"]) < 0.0 or i >= players.size() or not is_instance_valid(players[i]):
			continue
		if ItemArt.find("level_up").is_empty():
			continue
		var feet: Vector2 = players[i].global_position + Vector2(0, FEET)
		ItemArt.draw(ci, "level_up", ((feet / UNIT).floor() - ItemArt.origin("level_up")) * UNIT, UNIT, Color.WHITE, clampi(int(float(r["t"]) * 10.0), 0, 7))
	# Sharp: the tip of a glinting weapon twinkles, a pale gold cross that flares about once a second. A stand-in
	# drawn here until the Art builder's picture ("sharp_glint" in art/roles) comes.
	for i in players.size():
		var p = players[i]
		if not glinting(i) or not is_instance_valid(p) or p.is_down or not p.armed() or not p.has_method("_tip_world"):
			continue
		var at: Vector2 = (p._tip_world() / UNIT).floor()
		var beat := fmod(clock * 1.1 + float(i) * 0.37, 1.0)
		if ItemArt.draw(ci, "sharp_glint", (at - ItemArt.origin("sharp_glint")) * UNIT, UNIT, Color.WHITE, int(clock * 8.0)) != Vector2.ZERO:
			continue
		var arm := 3 if beat < 0.14 else (2 if beat < 0.3 else 1)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			ci.draw_rect(Rect2((at + d) * UNIT, Vector2(UNIT, UNIT)), Color(PLATE, 0.7))
		for k in range(1, arm + 1):
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				ci.draw_rect(Rect2((at + d * float(k)) * UNIT, Vector2(UNIT, UNIT)), GLINT)
		ci.draw_rect(Rect2(at * UNIT, Vector2(UNIT, UNIT)), Color.WHITE)


## Where player i's Memory bar is: right under their health bar.
func bar_at(i: int) -> Vector2:
	var lead := 26.0 if players.size() > 1 else 0.0
	var x := SIZE.x - MARGIN - HP_BAR.x if i % 2 == 1 else MARGIN + lead
	return Vector2(x, 7.0 + HP_BAR.y - 1.0)


## On the screen: each player's Memory bar under their health, and the squad's level in a roundel, top middle.
func _draw_hud() -> void:
	var fill := ItemArt.find("memory_fill")
	var empty := ItemArt.find("memory_empty")
	var frame: Dictionary = ItemArt.find("memory_frame")[1] if not ItemArt.find("memory_frame").is_empty() else {}
	var inner: Array = frame.get("fill_at", [6, 2])
	for i in players.size():
		if not is_instance_valid(players[i]):
			continue
		var at := bar_at(i)
		var frac := share(i)
		var lit := 0.0
		if loot != null and i < loot.purses.size():
			lit = clampf(1.0 - (float(loot.clock) - float(loot.purses[i].gained.get("memory", -9.0))) / 0.7, 0.0, 1.0)
		var fill_at := at + Vector2(float(inner[0]), float(inner[1]))
		if fill.is_empty() or empty.is_empty() or frame.is_empty():
			panel.draw_rect(Rect2(fill_at - Vector2(1, 1), Vector2(82, 5)), PLATE)
			panel.draw_rect(Rect2(fill_at, Vector2(ceilf(80.0 * frac), 3)), AMBER)
			continue
		ItemArt.draw(panel, "memory_frame", at)
		ItemArt.draw(panel, "memory_empty", fill_at)
		var w := ceilf(80.0 * frac)
		var box: Array = (fill[1] as Dictionary)["box"]
		if w > 0.0:
			panel.draw_texture_rect_region(fill[0], Rect2(fill_at, Vector2(w, float(box[3]))), Rect2(float(box[0]), float(box[1]), w, float(box[3])))
		# It lights as Memory arrives, and breathes slowly while it holds enough for a level.
		var glow := maxf(lit * 0.45, 0.22 + 0.12 * sin(clock * 2.4) if frac >= 1.0 else 0.0)
		if glow > 0.0 and w > 0.0:
			panel.draw_rect(Rect2(fill_at, Vector2(w, float(box[3]))), Color(1.0, 0.96, 0.8, glow))
	# The squad's level.
	var badge := ItemArt.size("level_badge")
	var bx := floorf((SIZE.x - maxf(badge.x, 15.0)) * 0.5)
	if badge == Vector2.ZERO:
		panel.draw_rect(Rect2(bx, 4, 15, 13), PLATE)
	else:
		ItemArt.draw(panel, "level_badge", Vector2(bx, 4))
	var words := str(level)
	var f := Art.font("Silkscreen-Regular")
	var tw := ceilf(f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	panel.draw_string(f, Vector2(bx + 3.0 + floorf((9.0 - tw) * 0.5) + 1.0, 4.0 + 10.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, AMBER)
