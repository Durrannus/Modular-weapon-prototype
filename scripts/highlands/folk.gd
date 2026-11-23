extends Node
## Pip, his cage, the quests and the keepers' waystone (version 46). Where they stand is folk_plan.gd's.
##
## The rules, from the Game Bible:
##   - The Slinger Roost: "Pip is locked in a hanging scrap cage in the middle; clear the camp and break the cage".
##   - Pip: "Freed, he moves to the base". His shop "sells tin and copper bars" (and buys parts and sells an
##     accessory, which wait for the anvil and the backpack). He "gives the odd hint about places".
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
##   - A bar costs TIN_PRICE or COPPER_PRICE coins. He buys nothing yet.
##   - The waystone takes REPAIR_COPPER copper bars, from the whole squad's bags (whoever uses it first). A mended
##     stone takes the whole squad to the forge, and the forge's screen takes them back. Nobody travels while an
##     enemy is after them. Once its stone is lit, nothing comes back to live at the Watchpost.
##   - The quests are the world's: they are saved with it. "Smoke over the Canyon" is there from the first moment
##     (the two quests before it, the smith's, need building). "Light the Watch" shows once the stone has been seen.
##   - Pip's words are stand-ins. The story is Darren's to write.
##
## The rules run on the game's tick (tick()); nothing here asks any dice.

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")
const Shop := preload("res://scripts/ui/shop.gd")

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

static var CAGE_BLOWS := 3
static var REPAIR_COPPER := 5
static var TIN_PRICE := 6
static var COPPER_PRICE := 10

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
const SHOP_LINE := "Tin and copper, straight bars, fair prices. What do you need?"

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
var travel := {}                   # a journey by waystone: {to, t, moved}
var clock := 0.0
var cheer_left := 0.0
var freed_said := true
var speaking := false              # Pip's words are up
var mending := false               # the waystone's copper is going in
var told_at := -9.0

var cage: Actor
var pip_actor: Actor
var stone: Actor
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
	game.ui.say(NAME, "", lines, func():
		speaking = false
		game._swallow_presses()
		if done.is_valid():
			done.call())


func _shop_closed(_i: int) -> void:
	if game != null:
		game._swallow_presses()
		game.save_now()


## What a bar costs at Pip's.
func price(item: String) -> int:
	return int(TIN_PRICE) if item == "tin_bar" else int(COPPER_PRICE)


## Player i buys one. "" if they did; otherwise why not, in words.
func buy(i: int, item: String) -> String:
	if loot == null or tools == null or i < 0 or i >= loot.purses.size():
		return "Nobody is there to buy."
	var purse = loot.purses[i]
	var cost := price(item)
	if int(purse.coins) < cost:
		return "That is %d coins. You have %d." % [cost, int(purse.coins)]
	if tools.bag_of(i).room(item) < 1:
		return "Your bag is full."
	purse.coins = int(purse.coins) - cost
	tools.bag_of(i).add(item, 1)
	return ""


## How many of the Warhorn's three pieces the squad has (the most any one of them holds).
func pieces() -> int:
	var n := 0
	if loot != null:
		for purse in loot.purses:
			n = maxi(n, (purse.kept as Dictionary).size())
	return n


## Pip, asked about the horn by player i: where the pieces they lack are.
func crown_words(i: int) -> String:
	var kept: Dictionary = loot.purses[i].kept if loot != null and i >= 0 and i < loot.purses.size() else {}
	var lacks: Array = []
	if not kept.has("horn_body"):
		lacks.append("The body: the big brute in the old quarry has it.")
	if not kept.has("horn_bell"):
		lacks.append("The bell: the white hound wears it, out in the far hills.")
	if not kept.has("horn_mouthpiece"):
		lacks.append("The mouthpiece: the best thrower at the roost. You have met.")
	if lacks.is_empty():
		return "That is all three! Now it wants bronze and an anvil to join them, and we have neither yet."
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
			if foes.packs[k].alert:
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
	for a in [cage, pip_actor, stone]:
		if a != null:
			a.step(delta)
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


# --- The quests ------------------------------------------------------------------------------

## What the squad has to do, for the corner of the screen: [{id, name, text}].
func quests() -> Array:
	var out: Array = []
	if pip < 3:
		var text := "Find the stone-throwers' roost and free Pip."
		if pip == 0 and found.has("roost") or pip == 1 and not freed_said:
			text = "Clear the roost and break Pip's cage."
		elif pip >= 1:
			text = "Pip is on his way to your cave. Meet him at the cave mouth."
		out.append({"id": "smoke", "name": "Smoke over the Canyon", "text": text})
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


## Where the quests are listed: the top right corner, or under the second player's bars.
func track_at() -> Vector2:
	return Vector2(SIZE.x - MARGIN - TRACK_W, 10.0 if players.size() < 2 else 78.0)


func _draw_hud() -> void:
	if game != null and game.ui != null and (game.ui.busy() or game.ui.fade > 0.5):
		return
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font(Art.TEXT)
	var at := track_at()
	for q in quests():
		var lines := Shop.lines_of(pix, str(q["text"]), Art.TEXT_SIZE, TRACK_W - 12.0)
		var h := 17.0 + 12.0 * float(lines.size()) + 3.0
		panel.draw_rect(Rect2(at, Vector2(TRACK_W, h)), SHADE)
		var mark := Art.texture("hud/objective_mark.png")
		if mark != null:
			panel.draw_texture(mark, at + Vector2(5, 4))
		else:
			panel.draw_colored_polygon(PackedVector2Array([at + Vector2(6, 8.5), at + Vector2(9, 5.5), at + Vector2(12, 8.5), at + Vector2(9, 11.5)]), AMBER)
		panel.draw_string(silk, at + Vector2(16, 12), str(q["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, AMBER)
		for n in lines.size():
			panel.draw_string(pix, at + Vector2(6, 25.0 + 12.0 * float(n)), str(lines[n]), HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE, INK)
		at.y += h + 3.0
