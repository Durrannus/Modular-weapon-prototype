extends Node
## Pip, his cage, the quests and the keepers' waystone (version 46). Where they stand is folk_plan.gd's.
##
## The rules, from the Game Bible:
##   - The Slinger Roost: "Pip is locked in a hanging scrap cage in the middle; clear the camp and break the cage".
##   - Pip: "Freed, he moves to the base". His shop "sells tin and copper bars and one rotating tier 1 accessory"
##     (the accessory since version 47; buying parts waits for the anvil). He "gives the odd hint about places".
##   - The quests: "Smoke over the Canyon: find the stone-throwers' roost and free Pip... Opens his shop." Then "The
##     Scrap Crown (Pip): take the three horn pieces from the three elites." And, never required, "Light the Watch
##     (repair the Watchpost waystone with copper)".
##   - Waystones: "old keeper stones, found broken and repaired with the biome's bars (copper in the Greystone
##     Highlands). Every repaired stone links to all the others and to the forge."
##
## Claude's choices, until Darren says otherwise:
##   - The cage breaks after CAGE_BLOWS blows, by the use button or by any tool, and only once everyone who guards
##     the Roost is down.
##   - Pip waits where he dropped until nobody is near, and is then at the base, beside the cave mouth (rooms cannot
##     be built yet). The first time you speak to him there he tells you of the horn; after that he is a shop.
##   - A bar costs TIN_PRICE or COPPER_PRICE coins, a healing potion POTION_PRICE (version 70). He buys nothing yet. His one accessory (ware()) costs
##     ACCESSORY_PRICE and changes each time the forge's level rises; he will not sell you one you already have.
##   - The waystone takes REPAIR_COPPER copper bars, from the whole squad's bags (whoever uses it first). A mended
##     stone takes the whole squad to the forge, and the forge's screen takes them back. Nobody travels while an
##     enemy is after them. Once its stone is lit, nothing comes back to live at the Watchpost.
##   - The quests are the world's: they are saved with it. "Smoke over the Canyon" is there from the first moment
##     (the two quests before it, the smith's, need building). "Light the Watch" shows once the stone has been seen.
##   - Pip's words are stand-ins. The story is Darren's to write.
##   - Since version 48 the horn's quests ("The Scrap Crown", "Mend the Horn", "Blow the Horn") are crown.gd's:
##     Pip mends the horn in his shop, and what he says of it follows how things stand with Rattlecrown.
##   - Smoke (version 47, asked for in the review of version 46: the first quest had nothing to find it by in a
##     land 350 tiles out). While Pip is caged the camp's smoke stands over the Roost, half a screen tall, and
##     while the Roost is off the screen a small far-off plume stood at the screen's edge on the Roost's side,
##     over the quest's own mark (SMOKE_SIGN, in the lab). Since version 69 that plume is off unless the lab puts it
##     back (Darren, 28 November: "only have it on the map"); the smoke is on both maps (version 59). Both go once the
##     cage is broken. The puffs are the Art builder's (art/smoke): the
##     game's greys, a pixel at a time. Looks only: nothing in the rules reads them.
##
## The rules run on the game's tick (tick()); nothing here asks any dice.

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")
const Shop := preload("res://scripts/ui/shop.gd")
const Accessories := preload("res://scripts/highlands/accessories.gd")

const UNIT := Art.PIXEL
const TILE := 16.0 * UNIT
const SORT_BIAS := 14.0            # as the land's things: players sort by their middle, things by their feet
const REACH := 60.0                # how near you stand to use any of them (world units)
const SEEN := 14.0 * TILE          # a place has been found once somebody has come this near
const PIP_GOES := 760.0            # Pip leaves the Roost once nobody is this near him (farther than a corner of the screen is from its middle)
const CHEER := 1.3                 # seconds he cheers before he speaks
const FADE_OUT := 0.35             # a waystone's journey: the screen goes dark ...
const FADE_IN := 0.5               # ... and comes back somewhere else
const CAGE_AT := Vector2(20, -27)  # the cage's middle from the foot of its post, in art pixels (the art's README)
const DROP_AT := Vector2(20, 0)    # where Pip lands
const SMOKE_AT := Vector2(-15, -2) # where the camp's smoke rises from, from the foot of the cage's post (art pixels), if the art has no fire for it
const FIRE_AT := Vector2(-15, 6)   # where the camp's fire stands, from the foot of the cage's post (art pixels): beside it, away from the cage
## The Roost's own smoke (version 59; Darren, 25 November: "actually have big smoke coming from the camp fire when u get
## to the location"): a thick column, not the one thread it was. Five strands of the art's puffs side by side, a puff
## in each every COLUMN_EVERY seconds, that move apart as they rise: about two puffs wide at the fire, four or five
## where it breaks up, and it climbs past the top of the screen. Embers rise from the fire into it. (column())
const SMOKE_LIFE := 36.0           # seconds a puff of it lasts (the art's own plume: 13)
const COLUMN_EVERY := 0.5          # a new puff in each strand this often
const COLUMN_RISE := 7.0           # art pixels a second, so it stands about 250 art pixels tall (the art's own rises 6)
const COLUMN_SPREAD := Vector3(4.0, 1.4, 22.0)   # the side strands start this far out (art pixels), move out this much a second, up to this
const COLUMN_AGES := [0.0, 1.0, 4.0]   # a puff is the art's fresh one, then opened, then wide from these ages; it breaks up for the last fifth of its life
const SMOKE_THIN := 0.4            # how much of the column shows while somebody stands in it (it is drawn over them)
const EMBERS := 9                  # sparks rising off the fire at a time
## The camp fire is bigger too: the Art builder's fire three times over, its stone rings run together into one hearth,
## two of them a little behind and to the sides of the first, each a beat apart (art pixels from the fire's foot).
## (A stand-in until the Art builder draws a big camp fire.)
const FIRE_MORE := [Vector2(-8, -3), Vector2(8, -2)]
const EMBER_COLS := [Color8(255, 236, 152), Color8(255, 200, 80), Color8(255, 156, 50), Color8(240, 106, 42)]   # the fire's own colours
const FACE := "folk/pip_portrait.png"

static var CAGE_BLOWS := 3
static var REPAIR_COPPER := 5
static var TIN_PRICE := 6
static var COPPER_PRICE := 10
static var ACCESSORY_PRICE := 40
static var POTION_PRICE := 15
static var SMOKE_SIGN := 0         # the far-off plume at the screen's edge that shows the way to the Roost: how many puffs tall (0: none;
                                   # Darren, 28 November: "take the smoke signal indicator off the game and only have it on the map")

const NAME := "Pip"
## Stand-ins, all of them: the story is Darren's to write.
const FREED_LINES := [
	"Out! At last. You have no idea how long I have hung in that pot.",
	"I'm Pip. I mend things. Rattlecrown's lot only break them, so I ran, and the slingers hung me up here for it.",
	"You came out of the old forge, didn't you? I know the way. Go on: I'll see you at your cave.",
]
const WAIT_LINE := "Go on, don't wait for me. I'll see you at your cave."
const MET_LINES := [
	"Made it. I'll camp here by your door until there is a room for me.",
	"Now listen. Rattlecrown, the Scrap King, sits behind his wall and comes out for one thing only: his war horn.",
	"The horn is in three pieces, and three of his best carry them. The big brute in the old quarry. The white hound. And the best thrower at the roost.",
	"Bring me all three and we can mend it. Until then I sell bars, if you have the coins.",
]
const SHOP_LINE := "Tin and copper, straight bars, and a red draught for your cuts. Fair prices. What do you need?"

const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const AMBER := Color("#ffc850")
const SHADE := Color(0.098, 0.078, 0.165, 0.5)
const DARK := Color("#19142a")
const SIZE := Vector2(640, 360)
const MARGIN := 10.0
const TRACK_W := 172.0             # how wide the quests' corner is


## Somebody or something that stands on the land and is drawn from a sheet of strips, its feet at its place.
class Actor extends Node2D:
	const PX := 2.0
	const LIFT := 14.0

	var sheet: Texture2D
	var strips := {}               # name -> {box: [x, y, w, h], frames, fps}
	var origin := Vector2.ZERO     # the feet, in art pixels from a frame's top left corner
	var anim := ""
	var at := 0.0                  # seconds into the strip
	var loop := true
	var flip := false
	var _shown := -1

	func play(name: String, loop_ := true, again := false) -> void:
		if name == anim and not again:
			return
		anim = name
		at = 0.0
		loop = loop_
		_shown = -1
		queue_redraw()

	func frames() -> int:
		return maxi(int(strips.get(anim, {}).get("frames", 1)), 1)

	func fps() -> float:
		return maxf(float(strips.get(anim, {}).get("fps", 1.0)), 0.01)

	func frame() -> int:
		var n := frames()
		var k := int(at * fps())
		return k % n if loop else mini(k, n - 1)

	## A strip played once has run out.
	func done() -> bool:
		return not loop and at * fps() >= float(frames())

	func step(delta: float) -> void:
		at += delta
		if frame() != _shown:
			queue_redraw()

	func face(left: bool) -> void:
		if flip != left:
			flip = left
			queue_redraw()

	func _draw() -> void:
		var s: Dictionary = strips.get(anim, {})
		if sheet == null or not s.has("box"):
			return
		var box: Array = s["box"]
		var fw := float(box[2]) / float(frames())
		_shown = frame()
		draw_set_transform(Vector2(0, LIFT), 0.0, Vector2(-PX if flip else PX, PX))
		draw_texture_rect_region(sheet, Rect2(-origin, Vector2(fw, float(box[3]))), Rect2(float(box[0]) + fw * float(_shown), float(box[1]), fw, float(box[3])))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The camp's smoke: drawn over everything on the land, by the clock (folk.draw_plume).
class Plume extends Node2D:
	var folk

	func _draw() -> void:
		if folk != null:
			folk.draw_plume(self)


var game                           # the Highlands scene
var map: LandMap
var world: Node2D                  # the y-sorted layer everything stands in
var players: Array = []
var tools                          # tools.gd: the bags, and what a tool may strike
var loot                           # loot.gd: the purses, and a line for everyone
var foes                           # foes.gd: who guards the Roost (may be null)
var plan := {}                     # folk_plan.gd's

var pip := 0                       # 0 caged, 1 freed and still at the Roost, 2 at the base, 3 met there (his shop is open)
var cage_hits := 0
var stones := {}                   # waystone id -> true: mended and lit
var found := {}                    # "roost", "watch" -> true: somebody has been there
var chart = null                   # the small map in the corner (charts.gd), which the quests go under
var travel := {}                   # a journey by waystone: {to, t, moved}
var clock := 0.0
var cheer_left := 0.0
var freed_said := true
var speaking := false              # Pip's words are up
var mending := false               # the waystone's copper is going in
var told_at := -9.0
var smoke_until := INF             # no new puff over the Roost after this moment of the clock (the cage is broken)

var cage: Actor
var pip_actor: Actor
var stone: Actor
var smoke: Plume
var fire: Actor                    # the camp fire at the smoke's foot
var fires: Array = []              # and the two behind it (FIRE_MORE)
var body: StaticBody2D
var pip_shape: CollisionShape2D
var layer: CanvasLayer
var panel: Control
var shop


func _ready() -> void:
	body = StaticBody2D.new()
	body.collision_layer = 4       # as the land's rock (land_view.gd)
	body.collision_mask = 0
	add_child(body)
	layer = CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	panel = Control.new()
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	panel.draw.connect(_draw_hud)
	shop = Shop.new()
	shop.folk = self
	add_child(shop)
	shop.closed.connect(_shop_closed)
	# The quests' corner is drawn again every frame, and put away while a screen has the game standing still (the
	# forge's, the shop, the pause menu): this node does not run then, but the tree still says when a frame is due.
	get_tree().process_frame.connect(_redraw)


# --- Where everything is (world units) ------------------------------------------------------

func has_roost() -> bool:
	return not (plan.get("roost", {}) as Dictionary).is_empty()


func has_stone() -> bool:
	return not (plan.get("stone", {}) as Dictionary).is_empty()


func cage_feet() -> Vector2:
	return (plan["roost"]["foot"] as Vector2) * UNIT


func cage_middle() -> Vector2:
	return cage_feet() + CAGE_AT * UNIT


## Where the camp's fire stands (its foot), and where its smoke rises from: the fire's own picture says how far
## above its foot (`smoke_from`, in art/smoke).
func fire_feet() -> Vector2:
	return cage_feet() + FIRE_AT * UNIT


func smoke_feet() -> Vector2:
	var its: Dictionary = Art.json("smoke/smoke.json").get("sprites", {}).get("roost_fire", {})
	if not its.has("box"):
		return cage_feet() + SMOKE_AT * UNIT
	var o: Array = its.get("origin", [10, 17])
	var from: Array = its.get("smoke_from", [10, 7])
	return fire_feet() + Vector2(float(from[0]) - float(o[0]), float(from[1]) - float(o[1])) * UNIT


func pip_landing() -> Vector2:
	return cage_feet() + DROP_AT * UNIT


func pip_home() -> Vector2:
	return (plan["pip"]["foot"] as Vector2) * UNIT


func stone_feet() -> Vector2:
	return (plan["stone"]["foot"] as Vector2) * UNIT


## Where a journey to the forge ends: in front of the cave mouth, where everyone first stood.
func forge_spot() -> Vector2:
	return map.spawn * TILE


## And where a journey to the waystone ends: in front of it.
func stone_spot() -> Vector2:
	return stone_feet() + Vector2(0, 30)


## Where Pip is right now (INF while he is in the cage).
func pip_at() -> Vector2:
	if pip == 1 and has_roost():
		return pip_landing()
	if pip >= 2:
		return pip_home()
	return Vector2.INF


# --- Setting up -----------------------------------------------------------------------------

## Stands the plan's things on the land. (The plan is made by the game, from the land as it was first made.)
func setup(plan_: Dictionary) -> void:
	plan = plan_
	if not has_roost():
		pip = 2                    # a land with nowhere to hang the cage (none is known): Pip is at the base from the start
	var book: Dictionary = Art.json("folk/folk.json").get("actors", {})
	var sheet := Art.texture("folk/folk.png")
	var its: Array = game.interactables if game != null and "interactables" in game else []
	if has_roost():
		cage = _actor(sheet, book.get("pip_cage", {}), cage_feet())
		cage.play("idle")
		# The camp fire the smoke rises from (the Art builder's, version 48): it stands on the ground among the
		# land's things, burns while Pip is caged, and is nothing anybody bumps into.
		var its_fire: Dictionary = Art.json("smoke/smoke.json").get("sprites", {}).get("roost_fire", {})
		if its_fire.has("box"):
			for n in FIRE_MORE.size():
				var more := _actor(Art.texture("smoke/smoke.png"), {"strips": {"burn": its_fire}, "origin_feet": its_fire.get("origin", [10, 17])}, fire_feet() + (FIRE_MORE[n] as Vector2) * UNIT)
				more.play("burn")
				more.at = 0.2 * float(n + 1)
				more.flip = n == 0
				more.add_to_group("unlit")    # the fire is a light itself (version 68)
				fires.append(more)
			fire = _actor(Art.texture("smoke/smoke.png"), {"strips": {"burn": its_fire}, "origin_feet": its_fire.get("origin", [10, 17])}, fire_feet())
			fire.play("burn")
			fire.add_to_group("unlit")
		smoke = Plume.new()
		smoke.folk = self
		smoke.z_index = 41             # over everything that stands on the land, and over the rock tops
		smoke.position = smoke_feet()
		add_child(smoke)
		_solid(cage_feet(), Vector2(6, 4) * UNIT)
		_block(plan["roost"]["tile"])
		its.append({"at": cage_feet() + Vector2(DROP_AT.x * UNIT, -6.0), "radius": REACH + 12.0, "lift": 122.0, "text": "Break the cage",
			"words": func(_i): return cage_words(), "can": func(_i): return pip == 0 and cage != null and cage.anim != "break", "use": func(i): strike_cage(i)})
		its.append({"at": pip_landing(), "radius": REACH, "lift": 72.0, "text": "Talk to Pip",
			"can": func(_i): return pip == 1 and cheer_left <= 0.0 and freed_said and pip_actor.visible, "use": func(i): talk(i)})
		if tools != null:
			# (The box reaches from the cage down to the ground under it: you strike it standing under it or beside it.)
			tools.extras.append({"box": Rect2(cage_feet() + Vector2(DROP_AT.x * UNIT - 22.0, -84.0), Vector2(44, 84)),
				"can": func(): return pip == 0 and cage.anim != "break", "strike": func(i, _at): strike_cage(i)})
	pip_actor = _actor(sheet, book.get("pip", {}), pip_home())
	pip_actor.visible = false
	its.append({"at": pip_home(), "radius": REACH, "lift": 72.0, "text": "Talk to Pip",
		"can": func(_i): return pip >= 2, "use": func(i): talk(i)})
	if has_stone():
		var sbook: Dictionary = Art.json("waystone/waystone.json")
		var strips := {}
		for name in (sbook.get("sprites", {}) as Dictionary):
			strips[name] = sbook["sprites"][name]
		var foot: Array = sbook.get("foot", [13, 46])
		stone = _actor(Art.texture("waystone/waystone.png"), {"strips": strips, "origin_feet": foot}, stone_feet())
		stone.play("waystone_broken")
		var solid: Array = sbook.get("solid", [18, 5])
		_solid(stone_feet(), Vector2(float(solid[0]), float(solid[1])) * UNIT)
		_block(plan["stone"]["tile"])
		its.append({"at": stone_feet() - Vector2(0, 6), "radius": REACH + 6.0, "lift": 100.0, "text": "The waystone",
			"words": func(i): return stone_words(i), "can": func(_i): return not mending and travel.is_empty(), "use": func(i): use_stone(i)})
	_show()


func _actor(sheet: Texture2D, info: Dictionary, feet: Vector2) -> Actor:
	var a := Actor.new()
	a.sheet = sheet
	a.strips = info.get("strips", {})
	var o: Array = info.get("origin_feet", [0, 0])
	a.origin = Vector2(float(o[0]), float(o[1]))
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


func _block(tile: Vector2i) -> void:
	if foes != null and foes.nav != null:
		foes.nav.block(tile)


## Everything as the state says it is (after setting up, and after a save is read).
func _show() -> void:
	if cage != null:
		cage.play("empty" if pip >= 1 else "idle")
	if pip >= 1 and smoke_until == INF:
		smoke_until = -INF             # freed before this game was opened: the fire is long out
	if pip_actor != null:
		pip_actor.visible = pip >= 1
		if pip == 1 and has_roost():
			pip_actor.position = pip_landing() - Vector2(0, SORT_BIAS)
			pip_actor.play("bare_idle")
		elif pip >= 2:
			pip_actor.position = pip_home() - Vector2(0, SORT_BIAS)
			pip_actor.play("idle")
		if pip >= 2 and pip_shape == null:
			pip_shape = _solid(pip_home(), Vector2(10, 4) * UNIT)
	if stone != null and not mending:
		stone.play("waystone_lit" if lit("watchpost") else "waystone_broken")
	_quiet()


## A lit waystone keeps its place: whoever lived there does not come back.
func _quiet() -> void:
	if foes == null or not has_stone() or not lit(str(plan["stone"]["id"])):
		return
	var g := int(plan["stone"].get("group", -1))
	if g >= 0:
		foes.quiet[g] = true


# --- The cage ---------------------------------------------------------------------------------

## Is everyone who guards the Roost down?
func roost_clear() -> bool:
	if not has_roost() or foes == null or not foes.on:
		return true
	var g := int(plan["roost"].get("group", -1))
	if g < 0 or g >= foes.plan.size():
		return true
	return (foes.fallen.get(g, {}) as Dictionary).size() >= (foes.plan[g]["members"] as Array).size()


func cage_words() -> String:
	return "Break the cage" if roost_clear() else "Pip's cage: clear the roost first"


## Somebody strikes the cage (the use button, or any tool). True if the blow counted.
func strike_cage(i: int) -> bool:
	if pip != 0 or cage == null or cage.anim == "break":
		return false
	if not roost_clear():
		_tell(i, "Clear the roost first")
		Sfx.play(game, "click", -8.0, 0.6)
		return false
	cage_hits += 1
	Sfx.play(game, "anvil", -12.0, 1.7)
	Sfx.play(game, "click", -6.0, 0.8)
	if cage_hits < int(CAGE_BLOWS):
		cage.play("hit", false, true)
		return true
	# It gives way: the floor swings down and Pip drops out.
	cage.play("break", false, true)
	pip = 1
	smoke_until = clock            # the camp's fire is left to die: no new smoke
	freed_said = false
	cheer_left = -1.0              # set once the cage's own strip has shown him drop
	Sfx.play(game, "slam", -9.0, 1.4)
	Sfx.play(game, "thud", -10.0, 1.1)
	if i >= 0 and i < players.size() and is_instance_valid(players[i]):
		players[i].shake = maxf(players[i].shake, 2.0)
	return true


# --- Pip --------------------------------------------------------------------------------------

## Somebody speaks to Pip.
func talk(i: int) -> void:
	if game == null or game.ui == null or game.ui.busy():
		return
	if pip == 1:
		_say([WAIT_LINE])
	elif pip == 2:
		_say(MET_LINES, func():
			pip = 3
			loot.say("Quest done: Smoke over the Canyon")
			Sfx.play(game, "pickup", -8.0, 1.0)
			game.save_now())
	elif pip >= 3 and not shop.is_open:
		shop.open(i)


func _say(lines: Array, done := Callable()) -> void:
	speaking = true
	game.ui.say(NAME, FACE, lines, func():
		speaking = false
		game._swallow_presses()
		if done.is_valid():
			done.call())


func _shop_closed(_i: int) -> void:
	if game != null:
		game._swallow_presses()
		game.save_now()


## The one accessory Pip has for sale ("" in a game with no Accessory Satchel). Which one comes from the world's
## number and the forge's level, so it changes each time the squad levels up and is the same for everyone.
func ware() -> String:
	if game == null or not ("gear" in game) or game.gear == null or map == null:
		return ""
	var level := int(game.levels.level) if "levels" in game and game.levels != null else 0
	return str(Accessories.POOL[posmod(int(map.seed_value) + level, Accessories.POOL.size())])


## What a thing costs at Pip's.
func price(item: String) -> int:
	if Accessories.has(item):
		return int(ACCESSORY_PRICE)
	if item == "potion":
		return int(POTION_PRICE)
	return int(TIN_PRICE) if item == "tin_bar" else int(COPPER_PRICE)


## Player i buys one. "" if they did; otherwise why not, in words.
func buy(i: int, item: String) -> String:
	if loot == null or tools == null or i < 0 or i >= loot.purses.size():
		return "Nobody is there to buy."
	var purse = loot.purses[i]
	var cost := price(item)
	if Accessories.has(item) and loot.owns(i, item):
		return "You have one. A second would do nothing more."
	if int(purse.coins) < cost:
		return "That is %d coins. You have %d." % [cost, int(purse.coins)]
	if tools.bag_of(i).room(item) < 1:
		return "Your inventory is full."
	purse.coins = int(purse.coins) - cost
	tools.bag_of(i).add(item, 1)
	if Accessories.has(item) and game != null and "gear" in game and game.gear != null:
		game.gear.nudge(i)
	return ""


## How many of the Warhorn's three pieces the squad has (the most any one of them holds).
func pieces() -> int:
	var n := 0
	if loot != null:
		for purse in loot.purses:
			n = maxi(n, (purse.kept as Dictionary).size())
	return n


## Rattlecrown's side of things (crown.gd), where the game has it.
func crown():
	return game.crown if game != null and "crown" in game and game.crown != null and game.crown.ok() else null


## Pip, asked about the horn by player i: where the pieces they lack are, or what to do with the horn.
func crown_words(i: int) -> String:
	var his = crown()
	if his != null and his.horn:
		if his.gate_open:
			return "His gate stands open. Blow the horn again in front of his throne. He will send his three best at you first, all at once."
		return "It is mended, and it is loud. His gate is far to the %s: follow the lanterns up the cut way, and blow it at the gate." % his.side_word()
	var kept: Dictionary = loot.purses[i].kept if loot != null and i >= 0 and i < loot.purses.size() else {}
	var lacks: Array = []
	if not kept.has("horn_body"):
		lacks.append("The body: the big brute in the old quarry has it.")
	if not kept.has("horn_bell"):
		lacks.append("The bell: the white hound wears it, out in the far hills.")
	if not kept.has("horn_mouthpiece"):
		lacks.append("The mouthpiece: the best thrower at the roost. You have met.")
	if lacks.is_empty():
		if his != null:
			return "That is all three! Tin and copper make bronze. Bring me %d tin bars and %d copper bars and I will join them." % [int(his.MEND_TIN), int(his.MEND_COPPER)]
		return "That is all three! Now it wants bronze and an anvil to join them, and we have neither yet."
	if his != null and int(his.beaten) > 0:
		# (Said shorter: by now you know where they are.)
		var short: Array = []
		for pair in [["horn_body", "the body from the quarry brute"], ["horn_bell", "the bell from the white hound"], ["horn_mouthpiece", "the mouthpiece from the roost"]]:
			if not kept.has(pair[0]):
				short.append(pair[1])
		var last := str(short.pop_back())
		return "The horn cracked when he fell. For another go I need %s again." % (last if short.is_empty() else ", ".join(short) + " and " + last)
	return " ".join(lacks)


# --- The waystone ----------------------------------------------------------------------------

func lit(id: String) -> bool:
	return bool(stones.get(id, false))


## How many copper bars the whole squad carries.
func copper() -> int:
	var n := 0
	if tools != null:
		for i in players.size():
			n += int(tools.bag_of(i).count("copper_bar"))
	return n


func stone_words(_i: int) -> String:
	if not has_stone():
		return ""
	if lit(str(plan["stone"]["id"])):
		return "Travel to the forge"
	return "Mend the waystone: %d copper bars" % int(REPAIR_COPPER)


func use_stone(i: int) -> void:
	if not has_stone() or mending or not travel.is_empty():
		return
	if lit(str(plan["stone"]["id"])):
		go(forge_spot(), i)
	else:
		mend(i)


## Player i mends the waystone with the squad's copper (their own bars first). False if there is not enough.
func mend(i: int) -> bool:
	if not has_stone() or lit(str(plan["stone"]["id"])):
		return false
	var need := int(REPAIR_COPPER)
	if copper() < need:
		loot.say("The waystone needs %d copper bars. %s %d." % [need, "You have" if players.size() < 2 else "The squad has", copper()])
		Sfx.play(game, "click", -8.0, 0.6)
		return false
	var order: Array = [i]
	for k in players.size():
		if k != i:
			order.append(k)
	for k in order:
		var bag = tools.bag_of(k)
		var n := mini(int(bag.count("copper_bar")), need)
		if n > 0:
			bag.take("copper_bar", n)
			need -= n
	stones[str(plan["stone"]["id"])] = true
	found["watch"] = true
	mending = true
	stone.play("waystone_repair", false, true)
	Sfx.play(game, "anvil", -8.0, 1.2)
	Sfx.play(game, "pickup", -10.0, 0.8)
	loot.say("Quest done: Light the Watch")
	_quiet()
	if game != null:
		game.save_now()
	return true


## Why nobody can travel right now, in words ("" if they can).
func cannot_travel() -> String:
	if not travel.is_empty():
		return "Already on the way"
	if foes != null:
		for k in foes.packs:
			if foes.packs[k].hunting():
				return "Not while enemies are after you"
	return ""


## The whole squad goes to a place by waystone. False (and a word why) if they cannot.
func go(to: Vector2, i := 0) -> bool:
	var why := cannot_travel()
	if why != "":
		_tell(i, why)
		Sfx.play(game, "click", -8.0, 0.6)
		return false
	travel = {"to": to, "t": 0.0, "moved": false}
	if game != null and game.ui != null:
		game.ui.fade_color = DARK
		game.ui.fade_out(FADE_OUT)
	Sfx.play(game, "pickup", -9.0, 0.6)
	return true


## From the forge's screen: to the waystone.
func go_to_stone(i := 0) -> bool:
	if not has_stone() or not lit(str(plan["stone"]["id"])):
		return false
	return go(stone_spot(), i)


func travelling() -> bool:
	return not travel.is_empty()


func _arrive() -> void:
	var n := 0
	for p in players:
		if is_instance_valid(p):
			n += 1
	var k := 0
	for p in players:
		if not is_instance_valid(p):
			continue
		p.global_position = (travel["to"] as Vector2) + Vector2((float(k) - float(n - 1) * 0.5) * 28.0, 0.0)
		p.velocity = Vector2.ZERO
		p.reset_physics_interpolation()
		k += 1
	if game != null:
		game.rig.snap()
		game.land.prime()
		game._swallow_presses()
		if game.ui != null:
			game.ui.fade_in(FADE_IN)
	Sfx.play(game, "anvil", -14.0, 1.9)


# --- Once a tick -----------------------------------------------------------------------------

func tick(delta: float) -> void:
	clock += delta
	_tick_quests(delta)
	for a in [cage, pip_actor, stone, fire] + fires:
		if a != null:
			a.step(delta)
	for f in [fire] + fires:
		if f != null:
			f.visible = smoke_until == INF      # (once the cage is broken the fire is left to die)
	if smoke != null:
		smoke.visible = smoking()
		if smoke.visible:
			smoke.queue_redraw()
			# Nobody is lost in it: while somebody stands in the column it thins to see-through (looks only).
			var thin := 1.0 if players.any(func(q): return is_instance_valid(q) and in_smoke(q.global_position)) else 0.0
			smoke.modulate.a = move_toward(smoke.modulate.a, lerpf(1.0, SMOKE_THIN, thin), delta * 3.0)
	# A journey: dark, somewhere else, light.
	if not travel.is_empty():
		travel["t"] = float(travel["t"]) + delta
		if not bool(travel["moved"]) and float(travel["t"]) >= FADE_OUT:
			travel["moved"] = true
			_arrive()
		if float(travel["t"]) >= FADE_OUT + FADE_IN:
			travel = {}
	# What has been found.
	if has_roost() and not found.has("roost") and _near(cage_feet(), SEEN):
		found["roost"] = true
	if has_stone() and not found.has("watch") and _near(stone_feet(), SEEN):
		found["watch"] = true
	# The cage.
	if cage != null:
		if cage.anim == "hit" and cage.done():
			cage.play("idle")
		elif cage.anim == "break" and cage.done():
			cage.play("empty")
			pip_actor.position = pip_landing() - Vector2(0, SORT_BIAS)
			pip_actor.visible = true
			pip_actor.play("cheer")
			cheer_left = CHEER
	# Pip.
	if pip == 1 and pip_actor != null and pip_actor.visible:
		if cheer_left > 0.0:
			cheer_left -= delta
			if cheer_left <= 0.0:
				cheer_left = 0.0
				pip_actor.play("bare_idle")
		elif not freed_said and game != null and game.ui != null and not game.ui.busy():
			freed_said = true
			_say(FREED_LINES, func():
				loot.say("Pip is free. Meet him at the cave mouth.")
				game.save_now())
		elif freed_said and not speaking and not _near(pip_landing(), PIP_GOES):
			pip = 2
			_show()
	if pip >= 1 and pip_actor != null and pip_actor.visible and cheer_left <= 0.0:
		var at := pip_at()
		var who = _nearest(at)
		if who != null and at.distance_to(who.global_position) < 150.0:
			pip_actor.face(who.global_position.x < at.x)
		var idle := "bare_idle" if pip == 1 else "idle"
		if speaking:
			pip_actor.play("talk" if pip >= 2 else idle)
		elif pip >= 2 and fmod(clock, 11.0) < 2.6 and (who == null or at.distance_to(who.global_position) > 90.0):
			pip_actor.play("work")
		else:
			pip_actor.play(idle)
	# The waystone.
	if stone != null and mending and stone.done():
		mending = false
		stone.play("waystone_lit")


func _near(at: Vector2, far: float) -> bool:
	for p in players:
		if is_instance_valid(p) and p.global_position.distance_to(at) < far:
			return true
	return false


func _nearest(at: Vector2):
	var best = null
	var best_d := INF
	for p in players:
		if is_instance_valid(p) and p.global_position.distance_to(at) < best_d:
			best = p
			best_d = p.global_position.distance_to(at)
	return best


## A few words over a player's head, not more than once in a while.
func _tell(i: int, words: String) -> void:
	if clock - told_at < 1.2 or i < 0 or i >= players.size() or not is_instance_valid(players[i]):
		return
	told_at = clock
	players[i]._label(words.to_upper(), INK)


# --- Looks only: the smoke over the Roost ------------------------------------------------------

## Is there still smoke over the Roost? (Until the last puff made before the cage broke has gone.)
func smoking() -> bool:
	return has_roost() and clock - smoke_until < SMOKE_LIFE


## The puffs of a plume, oldest first: [[where from its foot (art pixels), which of the art's four ages, mirrored]].
## `life` is how long a puff lasts, `until` the last moment one was made. The art's own rules (smoke.json, "plume"):
## a new puff every second, rising 6 pixels a second, drifting 1.5 with a pixel of sway, always on whole pixels,
## every other one mirrored. A taller plume keeps each age for the same share of a puff's life.
func puffs(now: float, life: float, until := INF) -> Array:
	var rules: Dictionary = Art.json("smoke/smoke.json").get("plume", {})
	var every := maxf(float(rules.get("spawn_every_s", 1.0)), 0.1)
	var rise := float(rules.get("rise_px_per_s", 6.0))
	var drift := float(rules.get("drift_px_per_s", 1.5))
	var sway := float(rules.get("sway_px", 1.0))
	var ages: Array = rules.get("frame_at_s", [0, 3, 7, 11])
	var stretch := life / maxf(float(rules.get("life_s", 13.0)), 0.1)
	var out: Array = []
	var newest := int(floor(minf(now, until) / every))
	var oldest := int(floor((now - life) / every)) + 1
	for k in range(oldest, newest + 1):
		var age := now - float(k) * every
		if age < 0.0 or age >= life:
			continue
		var frame := 0
		for j in ages.size():
			if age >= float(ages[j]) * stretch:
				frame = j
		var at := Vector2(-drift * age + sway * sin(age * 0.6 + float(k) * 2.4), -rise * age).round()
		out.append([at, frame, posmod(k, 2) == 1])
	return out


## Draws them, the newest last. `px` is the size of one art pixel there.
func _draw_puffs(ci: CanvasItem, foot: Vector2, px: float, list: Array) -> void:
	var tex := Art.texture("smoke/smoke.png")
	var info: Dictionary = Art.json("smoke/smoke.json").get("sprites", {}).get("smoke_puff", {})
	if tex == null or not info.has("box"):
		return
	var box: Array = info["box"]
	var one: Array = info.get("frame", [18, 14])
	var mid: Array = info.get("origin", [9, 7])
	var size := Vector2(float(one[0]), float(one[1]))
	for p in list:
		ci.draw_set_transform(foot + (p[0] as Vector2) * px, 0.0, Vector2(-px if bool(p[2]) else px, px))
		ci.draw_texture_rect_region(tex, Rect2(Vector2(-float(mid[0]), -float(mid[1])), size), Rect2(float(box[0]) + size.x * float(int(p[1])), float(box[1]), size.x, size.y))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_plume(ci: CanvasItem) -> void:
	# Embers first, under the smoke: while the fire burns, a few sparks in its own colours go up off it, a pixel each,
	# and die out within about 20 pixels.
	if smoke_until == INF:
		for k in EMBERS:
			var t := fposmod(clock * 0.7 + float(k) / float(EMBERS) + 0.37 * float(k * k % 5), 1.0)
			var up := t * (14.0 + float(k % 3) * 4.0)
			var at := Vector2(roundf(sin(float(k) * 1.7 + clock * 1.3) * (1.5 + t * 3.0)), -roundf(up) + 4.0)
			var col: Color = EMBER_COLS[mini(int(t * 4.0), 3)]
			ci.draw_rect(Rect2(at * UNIT, Vector2(UNIT, UNIT)), Color(col, 1.0 - t * 0.6))
	_draw_puffs(ci, Vector2.ZERO, UNIT, column(clock, smoke_until))


## Is this spot (world units) in the Roost's column, or just round it?
func in_smoke(at: Vector2) -> bool:
	var d := (at - smoke_feet()) / UNIT
	var lean := 1.5 * SMOKE_LIFE * clampf(-d.y / (COLUMN_RISE * SMOKE_LIFE), 0.0, 1.0)
	return d.y < 16.0 and d.y > -COLUMN_RISE * SMOKE_LIFE and d.x > -lean - COLUMN_SPREAD.z - 12.0 and d.x < -lean + COLUMN_SPREAD.z + 12.0


## The Roost's column (see SMOKE_LIFE): [[where from its foot (art pixels), which of the art's four ages, mirrored]],
## the oldest and highest first. Five strands, each its own puffs a part of a beat apart; now and then a side strand
## leaves out a puff, so the edges are ragged. `until` is the last moment a puff was made (the cage broken).
func column(now: float, until := INF) -> Array:
	var rules: Dictionary = Art.json("smoke/smoke.json").get("plume", {})
	var drift := float(rules.get("drift_px_per_s", 1.5))
	var sway := float(rules.get("sway_px", 1.0))
	var all: Array = []
	for j in [-2, -1, 0, 1, 2]:
		var phase: float = COLUMN_EVERY * float([0.0, 0.6, 0.3, 0.8, 0.45][j + 2])
		var newest := floori((minf(now, until) - phase) / COLUMN_EVERY)
		var oldest := floori((now - SMOKE_LIFE - phase) / COLUMN_EVERY) + 1
		for k in range(oldest, newest + 1):
			var age := now - (float(k) * COLUMN_EVERY + phase)
			if age < 0.0 or age >= SMOKE_LIFE:
				continue
			if j != 0 and posmod(k * 7 + j * 3, 5 if absi(j) == 1 else 3) == 0:
				continue
			var frame := 3 if age >= SMOKE_LIFE * 0.8 else 0
			if frame == 0:
				for n in COLUMN_AGES.size():
					if age >= float(COLUMN_AGES[n]):
						frame = n
			var out := float(j) * 0.5 * minf(COLUMN_SPREAD.x + COLUMN_SPREAD.y * age, COLUMN_SPREAD.z)
			var at := Vector2(out - drift * age + sway * sin(age * 0.6 + float(k) * 2.4 + float(j)), -COLUMN_RISE * age).round()
			all.append([at, frame, posmod(k + j, 2) == 1, age])
	all.sort_custom(func(a, b): return float(a[3]) > float(b[3]))
	for q in all:
		q.resize(3)
	return all


## Where the far-off plume stands on the screen (art pixels), or [] when there is none: Pip is out, or the Roost's
## own smoke can be seen. It stands at the edge of the screen on the Roost's side, clear of the bars, the quests
## and the belts.
func smoke_sign() -> Array:
	if int(SMOKE_SIGN) < 1 or pip != 0 or not has_roost():
		return []
	# (Not while its foot, or the top of the plume, is on the screen.)
	return edge_spot(smoke_feet(), sign_height(), Rect2(-40.0, 0.0, SIZE.x + 80.0, SIZE.y + COLUMN_RISE * SMOKE_LIFE - 20.0))


## Where a far-off sign for a place on the land stands on the screen (art pixels), or [] when the place is in `seen`
## (the part of the screen, and round it, where the place itself shows). It stands at the edge of the screen on the
## place's side, `tall` high, clear of the bars, the quests and the belts.
func edge_spot(place: Vector2, tall: float, seen: Rect2) -> Array:
	if game == null or not ("rig" in game) or game.rig == null:
		return []
	var mid: Vector2 = game.rig.camera.get_screen_center_position()
	var to: Vector2 = (place - mid) / UNIT + SIZE * 0.5
	if seen.has_point(to):
		return []
	var box := Rect2(18.0, 6.0 + tall, SIZE.x - 36.0, SIZE.y - (6.0 + tall) - 20.0)
	var from := SIZE * 0.5
	var dir := (to - from).normalized()
	var far := INF
	if dir.x > 0.001:
		far = minf(far, (box.end.x - from.x) / dir.x)
	elif dir.x < -0.001:
		far = minf(far, (box.position.x - from.x) / dir.x)
	if dir.y > 0.001:
		far = minf(far, (box.end.y - from.y) / dir.y)
	elif dir.y < -0.001:
		far = minf(far, (box.position.y - from.y) / dir.y)
	if far == INF:
		return []
	var at := (from + dir * far).round()
	# What sits in the corners (the bars, the quests, the belts) keeps its room: by a top corner the plume slides
	# along its edge of the screen, towards the middle, until it is clear of them; by a bottom corner (the belts and
	# the swing path) it rises above them, so it never stands in their band (version 52, after the project's review).
	var on_side := absf(at.x - box.position.x) < 0.5 or absf(at.x - box.end.x) < 0.5
	for again in 2:
		for r: Rect2 in hud_corners():
			var low := r.get_center().y > SIZE.y * 0.5
			if low and at.y + 18.0 >= r.position.y and at.x + 12.0 > r.position.x - 16.0 and at.x - 12.0 < r.end.x + 16.0:
				at.y = r.position.y - 19.0
				continue
			if not Rect2(at.x - 12.0, at.y - tall, 24.0, tall + 18.0).intersects(r):
				continue
			if on_side:
				at.y = r.end.y + tall + 1.0
			else:
				at.x = r.end.x + 13.0 if r.get_center().x < SIZE.x * 0.5 else r.position.x - 13.0
	return [at.round()]


## How far above its foot the far-off plume reaches (art pixels): a puff a second, each a little higher.
func sign_height() -> float:
	var rules: Dictionary = Art.json("smoke/smoke.json").get("plume", {})
	return float(rules.get("rise_px_per_s", 6.0)) * maxf(float(int(SMOKE_SIGN)) - 1.0, 0.0) + 14.0


## Where the quests are listed, as a box (empty when there are none). `names`: the box of their names alone.
func track_rect(names := false) -> Rect2:
	var pix := Art.font(Art.TEXT)
	var h := 0.0
	for q in quests():
		h += (17.0 if names else 17.0 + 12.0 * float(Shop.lines_of(pix, str(q["text"]), Art.TEXT_SIZE, TRACK_W - 12.0).size()) + 3.0) + 3.0
	return Rect2(track_at(), Vector2(TRACK_W, maxf(h - 3.0, 0.0)))


## A PANEL OF THE HUD NEVER HIDES A FOE IN A FIGHT (version 70, after the project's review of version 69, where the
## quest list covered one of Rattlecrown's elites). During a boss fight the quest list is put away: the fight's own
## line at the top says what to do. Otherwise, while a foe that is fighting stands under it, the list shrinks to its
## quests' names, and if one stands under those too it goes; it comes back a moment (QUESTS_BACK) after the foe has
## moved. "all", "names" or "none".
const QUESTS_BACK := 1.0
var _quests_mode := "all"
var _quests_held := 0.0

func quests_shown() -> String:
	return _quests_mode


func _tick_quests(delta: float) -> void:
	var want := "all"
	var c = crown()
	if c != null and c.fighting():
		want = "none"
	elif not quests().is_empty():
		var boxes := foe_boxes()
		if not boxes.is_empty():
			if _covers(track_rect(true), boxes):
				want = "none"
			elif _covers(track_rect(), boxes):
				want = "names"
	var rank := {"all": 0, "names": 1, "none": 2}
	if int(rank[want]) >= int(rank[_quests_mode]):
		_quests_mode = want
		_quests_held = QUESTS_BACK
	else:
		_quests_held -= delta
		if _quests_held <= 0.0:
			_quests_mode = want
			_quests_held = QUESTS_BACK


## Where on the screen every foe that is fighting stands, as boxes round their bodies (screen pixels).
func foe_boxes() -> Array:
	var out: Array = []
	if game == null or not ("rig" in game) or game.rig == null:
		return out
	var mid: Vector2 = game.rig.camera.get_screen_center_position()
	for e in game.get_tree().get_nodes_in_group("highlands_foes"):
		if not is_instance_valid(e) or e.dead or not e.fighting():
			continue
		var at: Vector2 = (e.global_position - mid) / UNIT + SIZE * 0.5
		var r: float = float(e.radius) / UNIT + 4.0
		out.append(Rect2(at - Vector2(r, r * 2.6), Vector2(r * 2.0, r * 3.6)))
	return out


static func _covers(panel_box: Rect2, boxes: Array) -> bool:
	if panel_box.size.y <= 0.0:
		return false
	for b: Rect2 in boxes:
		if panel_box.intersects(b):
			return true
	return false


## The corners of the screen that are spoken for: each player's bars above and belt below, and the quests.
func hud_corners() -> Array:
	var out: Array = [Rect2(0.0, 0.0, 216.0, 74.0), Rect2(0.0, 262.0, 276.0, 98.0)]
	if players.size() > 1:
		out.append(Rect2(SIZE.x - 216.0, 0.0, 216.0, 74.0))
		out.append(Rect2(SIZE.x - 276.0, 262.0, 276.0, 98.0))
	if chart != null and is_instance_valid(chart):
		out.append((chart.rect() as Rect2).grow(5.0))
	var track := track_rect()
	if track.size.y > 0.0:
		out.append(track.grow(4.0))
	return out


# --- The quests ------------------------------------------------------------------------------

## What the squad has to do, for the corner of the screen: [{id, name, text}].
func quests() -> Array:
	var out: Array = []
	if pip < 3:
		var text := "Follow the smoke to the stone-throwers' roost and free Pip." if has_roost() else "Find the stone-throwers' roost and free Pip."
		if pip == 0 and found.has("roost") or pip == 1 and not freed_said:
			text = "Clear the roost and break Pip's cage."
		elif pip >= 1:
			text = "Pip is on his way to your cave. Meet him at the cave mouth."
		out.append({"id": "smoke", "name": "Smoke over the Canyon", "text": text})
	elif crown() != null:
		# The Scrap Crown, Mend the Horn, Blow the Horn: crown.gd says which it is.
		var q: Dictionary = crown().quest(pieces())
		if not q.is_empty():
			out.append(q)
	elif pip >= 3:
		var n := pieces()
		var text := "Take the Rusted Warhorn's three pieces from the three elites: %d of 3." % n
		if n >= 3:
			text = "You have all three pieces of the Warhorn. Mending it is not built yet."
		out.append({"id": "crown", "name": "The Scrap Crown", "text": text})
	if has_stone() and found.has("watch") and not lit(str(plan["stone"]["id"])):
		out.append({"id": "watch", "name": "Light the Watch", "text": "Mend the waystone at the Keeper's Watchpost: %d copper bars (%s %d)." \
			% [int(REPAIR_COPPER), "you have" if players.size() < 2 else "the squad has", copper()]})
	return out


# --- What is saved (with the world) ---------------------------------------------------------

func world_data() -> Dictionary:
	var seen: Array = found.keys()
	seen.sort()
	var mended: Array = []
	for id in stones:
		if bool(stones[id]):
			mended.append(str(id))
	mended.sort()
	return {"folk": {"pip": pip, "stones": mended, "found": seen}}


func set_world_data(d) -> void:
	var f = (d as Dictionary).get("folk") if d is Dictionary else null
	pip = 0
	stones = {}
	found = {}
	cage_hits = 0
	if f is Dictionary:
		if f.get("pip") is int or f.get("pip") is float:
			pip = clampi(int(f["pip"]), 0, 3)
		if pip == 1:
			pip = 2               # he has had time to walk
		if f.get("stones") is Array:
			for id in f["stones"]:
				if id is String:
					stones[id] = true
		if f.get("found") is Array:
			for name in f["found"]:
				if name is String:
					found[name] = true
	if not has_roost():
		pip = maxi(pip, 2)
	freed_said = true
	cheer_left = 0.0
	mending = false
	_show()


# --- Looks only: the quests, in the corner ---------------------------------------------------

func _redraw() -> void:
	panel.visible = not get_tree().paused
	if panel.visible:
		panel.queue_redraw()


## Where the quests are listed: the top right corner, or under the second player's bars; under the small map
## when there is one (version 56).
func track_at() -> Vector2:
	if chart != null and is_instance_valid(chart):
		var r: Rect2 = chart.rect()
		return Vector2(SIZE.x - MARGIN - TRACK_W, r.end.y + 9.0)
	return Vector2(SIZE.x - MARGIN - TRACK_W, 10.0 if players.size() < 2 else 78.0)


func _draw_hud() -> void:
	if game != null and game.ui != null and (game.ui.busy() or game.ui.fade > 0.5):
		return
	var sign := smoke_sign()
	if not sign.is_empty():
		# The quest's own mark under it says what the smoke is for: it is the way to "Smoke over the Canyon".
		var its := Art.texture("hud/objective_mark.png")
		if its != null:
			panel.draw_texture(its, (sign[0] as Vector2) + Vector2(-floorf(its.get_width() * 0.5), 9.0))
		_draw_puffs(panel, sign[0], 1.0, puffs(clock, float(int(SMOKE_SIGN))))
	# "Blow the Horn": the quest's mark alone stands at the screen's edge on the side of where the horn is wanted
	# next (the way in, then the gate, then the throne), until that place is on the screen.
	var horn_at: Vector2 = crown().sign_target() if crown() != null and pip >= 3 else Vector2.INF
	if horn_at != Vector2.INF:
		var spot := edge_spot(horn_at, 0.0, Rect2(Vector2.ZERO, SIZE))
		var its := Art.texture("hud/objective_mark.png")
		if not spot.is_empty() and its != null:
			panel.draw_texture(its, (spot[0] as Vector2) + Vector2(-floorf(its.get_width() * 0.5), 2.0 + roundf(sin(clock * 3.0))))
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font(Art.TEXT)
	var at := track_at()
	if _quests_mode == "none":
		return
	for q in quests():
		var lines: Array = Shop.lines_of(pix, str(q["text"]), Art.TEXT_SIZE, TRACK_W - 12.0) if _quests_mode == "all" else []
		var h := 17.0 + (12.0 * float(lines.size()) + 3.0 if not lines.is_empty() else 0.0)
		panel.draw_rect(Rect2(at, Vector2(TRACK_W, h)), Art.shade(SHADE))
		var mark := Art.texture("hud/objective_mark.png")
		if mark != null:
			panel.draw_texture(mark, at + Vector2(5, 4))
		else:
			panel.draw_colored_polygon(PackedVector2Array([at + Vector2(6, 8.5), at + Vector2(9, 5.5), at + Vector2(12, 8.5), at + Vector2(9, 11.5)]), AMBER)
		panel.draw_string(silk, at + Vector2(16, 12), str(q["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, AMBER)
		for n in lines.size():
			panel.draw_string(pix, at + Vector2(6, 25.0 + 12.0 * float(n)), str(lines[n]), HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE, INK)
		at.y += h + 3.0
