extends Node
## Chests, what enemies leave when they fall, coins and Memory (version 44).
##
## From the Game Bible:
##   - Random chests "scattered around": "usually tin or copper bars, coins and Memory (straight into your bar)".
##     Which chests have been opened is saved with the world.
##   - "Coins are a plain counter." Bars go in the inventory (bag.gd). Both belong to the character.
##   - Memory is "earned from everything: killing, mining, chopping and building". What you carry belongs to the
##     character; it is shown as a bar under their health, and poured into the forge to level the squad
##     (levels.gd, version 45).
##   - Elites give "the same kinds of loot as the chests", and three of them a piece of the Rusted Warhorn: the body
##     from the Elite Scrap Brute, the bell from the Elite Cliff Hound, the mouthpiece from the Elite Pebble Slinger.
##
## Claude's choices, until Darren says otherwise (they are listed in the README and the Game Bible):
##   - EVERYONE gets a chest's loot and a kill's Memory, each their own full share: nobody races for it.
##   - The Warhorn's pieces are KEPT THINGS: they take no room in the bag and cannot be lost. An elite gives its
##     piece to whoever has not got it yet.
##   - A bar that does not fit in your bag lies where it fell until you have room and walk over it. What still lies
##     there when you leave is lost.
##   - An enemy that was called into a fight (a hound answering a howl, a shaman's bat) gives nothing: howls and
##     bats cannot be farmed.
##   - Digging plain rock gives no Memory (it would be the safest and fastest way to earn it there is); ore and
##     pines give a little.
##   - What falling costs (some coins and half your unbanked Memory, left as a marker) is levels.gd's, since
##     version 45.
##   - ACCESSORIES (version 47; the Bible: "Any of them can spawn randomly in any chest ... elites and stashes can
##     drop them too"). Some chests hold one (loot_plan.gd says which), and an elite leaves one about half the time.
##     Everyone gets their own. Whoever has that accessory already gets GIFT_COINS coins in its place: a second
##     one would do nothing (gear.gd), and there is nobody to sell it to yet.
##
## THE RULES AND THE LOOKS ARE KEPT APART, as everywhere: what you hold changes at once, on the tick (give(),
## open(), tick()); the things that hop out and fly to you are looks only, with dice of their own.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const LootPlan := preload("res://scripts/highlands/loot_plan.gd")
const Accessories := preload("res://scripts/highlands/accessories.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")
const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Sim := preload("res://scripts/sim.gd")

const UNIT := Art.PIXEL
const TILE := 16.0 * UNIT
const SORT_BIAS := 14.0            # as land_view.gd: players sort by their middle, things by their feet
const LID_FPS := 10.0              # the lid opens over five pictures
const OUT_AT := 0.2                # what is inside comes out as the lid is thrown open
const SHOW_TIME := 1.4             # it stands open with its loot showing this long, and is empty after
const HOP := 0.18                  # loot hops out ...
const LIE := 0.32                  # ... lies a moment ...
const FLY := 0.36                  # ... and flies to you
const PICK := 44.0                 # how near you come to something of yours that lies on the ground
const REACH := 54.0                # how near a chest you stand to open it
const SAY_TIME := 4.0

## The three pieces of the Rusted Warhorn, and who carries each.
const HORN := {"scrap_brute": "horn_body", "hound": "horn_bell", "slinger": "horn_mouthpiece"}
const KEPT := ["horn_body", "horn_bell", "horn_mouthpiece"]
const KEPT_NAMES := {"horn_body": "the Warhorn's body", "horn_bell": "the Warhorn's bell", "horn_mouthpiece": "the Warhorn's mouthpiece"}

static var MEMORY_FOR := {"hound": 4, "slinger": 4, "scrap_brute": 12, "shaman": 8}
static var ELITE_MEMORY := 40
static var ELITE_COINS_MIN := 15
static var ELITE_COINS_MAX := 30
static var ELITE_BARS_MIN := 2
static var ELITE_BARS_MAX := 4
static var WORK_MEMORY := {"tin_ore": 1, "copper_ore": 1, "wood": 1}
static var ELITE_GIFT := 0.5       # how often an elite leaves an accessory
static var GIFT_COINS := 20        # what you get in place of an accessory you already have

const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const AMBER := Color("#ffc850")
const SHADE := Color(0.098, 0.078, 0.165, 0.5)
const SIZE := Vector2(640, 360)
const MARGIN := 10.0
const HP_BAR := 92.0               # the health bar's width (scripts/ui/hud.gd): the purse sits beside it


## What one character has that is counted and not carried in the bag. It is in the character's save.
class Purse:
	var coins := 0
	var memory := 0
	var kept := {}                 # the kept things it has: name -> true
	var gained := {}               # what -> when some last arrived (its number lights up)
	var told_at := -9.0


class Layer extends Node2D:
	var draws: Callable

	func _draw() -> void:
		draws.call(self)


var game                           # the Highlands scene
var map: LandMap
var world: Node2D                  # the y-sorted layer everything stands in
var players: Array = []
var tools                          # tools.gd: the bags
var nav                            # the enemies' way-finding, told where the chests stand (may be null)
var plan: Array = []               # loot_plan.gd's chests
var chests: Array = []             # one for each of the plan's: {plan, sprite, state: 0 shut, 1 opening, 2 open, t}
var opened := {}                   # chest id -> true: what the world save keeps
var purses: Array = []             # a Purse per player
var lying: Array = []              # [{item, i, at}] what did not fit in somebody's bag
var flies: Array = []              # looks only: [{item, i, from, spot, t, wait, mote}]
var said := ""                     # a line for everyone to read for a few seconds
var said_until := -9.0
var said_y := 42.0                 # where that line is (lower while a boss's bar and tip have the top middle: crown.gd)
var clock := 0.0
var dice := RandomNumberGenerator.new()    # looks only
var sheet: Texture2D
var book := {}
var body: StaticBody2D
var under: Layer
var over: Layer
var layer: CanvasLayer
var panel: Control
var _tex := {}


func _ready() -> void:
	dice.seed = 20261123
	sheet = Art.texture("loot/loot.png")
	book = Art.json("loot/loot.json").get("sprites", {})
	body = StaticBody2D.new()
	body.collision_layer = 4       # as the land's rock (land_view.gd)
	body.collision_mask = 0
	add_child(body)
	under = Layer.new()
	under.draws = _draw_under
	under.z_index = -9             # the chests' shadows: on the ground, under everything that stands on it
	add_child(under)
	over = Layer.new()
	over.draws = _draw_over
	over.z_index = 40
	add_child(over)
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	panel = Control.new()
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	panel.draw.connect(_draw_hud)
	for i in players.size():
		purses.append(Purse.new())


## Stands the plan's chests on the land. (The plan is made by the game, from the land as it was first made.)
func setup(plan_: Array) -> void:
	plan = plan_
	for c in plan:
		_stand(c)


func _frame(name: String, frame := 0) -> AtlasTexture:
	var key := "%s#%d" % [name, frame]
	if not _tex.has(key):
		var info: Dictionary = book.get(name, {})
		var box: Array = info.get("box", [0, 0, 1, 1])
		var w := int(info["frame"][0]) if info.has("frame") else int(box[2])
		var t := AtlasTexture.new()
		t.atlas = sheet
		t.region = Rect2(int(box[0]) + frame * w, int(box[1]), w, int(box[3]))
		_tex[key] = t
	return _tex[key]


func _stand(c: Dictionary) -> void:
	var foot: Vector2 = c["foot"]
	var f: Array = book.get("chest", {}).get("foot", [9, 20])
	var s := Sprite2D.new()
	s.texture = _frame("chest", 0)
	s.centered = false
	s.offset = Vector2(-float(f[0]), -float(f[1]) + SORT_BIAS / UNIT)
	s.scale = Vector2(UNIT, UNIT)
	s.position = foot * UNIT - Vector2(0, SORT_BIAS)
	world.add_child(s)
	var solid: Array = book.get("chest", {}).get("solid", [16, 5])
	var size := Vector2(float(solid[0]), float(solid[1])) * UNIT
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	shape.position = foot * UNIT - Vector2(0, size.y * 0.5)
	body.add_child(shape)
	if nav != null:
		nav.block(c["tile"])
	var k := chests.size()
	chests.append({"plan": c, "sprite": s, "state": 0, "t": 0.0})
	if game != null and "interactables" in game:
		game.interactables.append({"at": foot * UNIT - Vector2(0, 10), "radius": REACH, "lift": 46.0, "text": "Open the chest",
			"can": func(_i): return int(chests[k]["state"]) == 0, "use": func(i): open(k, i)})
	under.queue_redraw()


## The chest with this id (its place's number), or -1.
func chest_of(id: int) -> int:
	for k in chests.size():
		if int(chests[k]["plan"]["id"]) == id:
			return k
	return -1


## Where a chest's loot comes out of, in world units.
func mouth_of(k: int) -> Vector2:
	return (chests[k]["plan"]["foot"] as Vector2) * UNIT + Vector2(0, -14)


# --- The rules --------------------------------------------------------------------------

## Somebody opens chest k. Everybody gets what is in it, each their own full share. False if it was open already.
func open(k: int, _by := -1) -> bool:
	if k < 0 or k >= chests.size() or int(chests[k]["state"]) != 0:
		return false
	var ch: Dictionary = chests[k]
	var c: Dictionary = ch["plan"]
	ch["state"] = 1
	ch["t"] = 0.0
	opened[int(c["id"])] = true
	var at := mouth_of(k)
	for i in players.size():
		if not is_instance_valid(players[i]):
			continue
		give(i, "coins", _lucky(i, int(c["coins"])), at, OUT_AT, true)
		for it in c["items"]:
			give(i, str(it[0]), int(it[1]), at, OUT_AT + 0.05, true)
		give(i, "memory", int(c["memory"]), at, OUT_AT + 0.25, true)
	gift(str(c.get("gift", "")), at, OUT_AT + 0.4, true)
	Sfx.play(game, "click", -7.0, 0.7)
	Sfx.play(game, "thud", -12.0, 1.3)
	return true


## The accessories (gear.gd), where the game has them (not online, which is on hold).
func _gear():
	return game.gear if game != null and "gear" in game and game.gear != null else null


## Lucky Copper: the coins player i gets from a chest or an elite.
func _lucky(i: int, n: int) -> int:
	var gear = _gear()
	return gear.coins(i, n) if gear != null else n


## Does player i have this accessory, in their inventory or in their satchel?
func owns(i: int, id: String) -> bool:
	var gear = _gear()
	return (tools != null and tools.bag_of(i).count(id) > 0) or (gear != null and gear.has(i, id))


## An accessory for everybody, each their own, from a place on the land. Whoever has it already gets coins in its
## place. "" gives nothing.
func gift(id: String, from: Vector2, after := 0.0, front := false) -> void:
	if not Accessories.has(id) or _gear() == null:
		return
	var new_to := 0
	for i in players.size():
		if not is_instance_valid(players[i]):
			continue
		if owns(i, id):
			give(i, "coins", int(GIFT_COINS), from, after, front)
		else:
			give(i, id, 1, from, after, front)
			new_to += 1
			_gear().nudge(i)      # the screen tells whoever it is for which button opens the inventory
	var name := Accessories.name_of(id)
	if new_to == 0:
		say("%s again: %d coins instead" % [name, int(GIFT_COINS)])
	else:
		say("Found: %s" % name)
	Sfx.play(game, "pickup", -8.0, 1.2)


## Gives player i so many of a thing, from a place on the land. Coins and Memory are counted at once; a kept thing
## is kept; a thing for the bag goes in if it fits, and lies on the ground where it fell if it does not. `after` and
## `front` are looks only: how long before it is seen to come out, and whether it comes out forwards (a chest
## against a wall) or all round (an enemy).
func give(i: int, item: String, n: int, from: Vector2, after := 0.0, front := false) -> void:
	if n <= 0 or i < 0 or i >= purses.size():
		return
	var purse: Purse = purses[i]
	var shown := n
	if item == "coins":
		purse.coins += n
		shown = clampi(ceili(float(n) / 4.0), 1, 7)
	elif item == "memory":
		purse.memory += n
		shown = clampi(ceili(float(n) / 5.0), 1, 7)
	elif item in KEPT:
		purse.kept[item] = true
		shown = 1
	else:
		var got: int = tools.bag_of(i).add(item, n) if tools != null else 0
		shown = got
		for m in n - got:
			# Round where it fell, each in a place of its own (no dice: where it lies is part of the rules).
			var k := lying.size()
			lying.append({"item": item, "i": i, "at": from + Vector2(0, 14) + Vector2.from_angle(0.5 + float(k) * 2.4) * (16.0 + 6.0 * float(k % 3))})
	for m in shown:
		var turn := dice.randf_range(0.2, PI - 0.2) if front else dice.randf_range(0.0, TAU)
		var spot := from + Vector2(0, 14 if front else 0) + Vector2.from_angle(turn) * dice.randf_range(14.0, 30.0) * Vector2(1.0, 0.7)
		flies.append({"item": item, "i": i, "from": from, "spot": spot, "t": -after - 0.03 * float(m), "wait": (0.0 if item == "memory" else LIE) + 0.07 * float(m), "mote": item == "memory"})


## One of the land's enemies fell (foes.gd tells us). Everyone gets its Memory; an elite also leaves what a chest
## would, and its piece of the Warhorn for whoever has not got it. One that was called into the fight leaves nothing.
func foe_died(e) -> void:
	if not is_instance_valid(e) or bool(e.get("summoned")):
		return
	var at: Vector2 = e.global_position + Vector2(0, -8)
	var elite := bool(e.get("elite"))
	var memory := int(ELITE_MEMORY) if elite else int(MEMORY_FOR.get(str(e.kind), 0))
	var coins := 0
	var bars := 0
	var bar := "tin_bar"
	if elite:
		# What decides what you get is asked of the game's shared dice, so two computers playing together agree.
		coins = floori(Sim.between(float(ELITE_COINS_MIN), float(ELITE_COINS_MAX) + 0.999))
		bars = floori(Sim.between(float(ELITE_BARS_MIN), float(ELITE_BARS_MAX) + 0.999))
		bar = "copper_bar" if Sim.chance() < 0.6 else "tin_bar"
	var piece := str(HORN.get(str(e.kind), "")) if elite and not e.has_meta("stands_for") else ""
	for i in players.size():
		if not is_instance_valid(players[i]):
			continue
		give(i, "memory", memory, at, 0.15)
		give(i, "coins", _lucky(i, coins), at, 0.1)
		give(i, bar, bars, at, 0.1)
		if piece != "" and not (purses[i] as Purse).kept.has(piece):
			give(i, piece, 1, at, 0.3)
			var have := (purses[i] as Purse).kept.size()
			say("%s the Rusted Warhorn's %s (%d of 3)" % ["You have" if players.size() == 1 else "Player %d has" % (i + 1), str(KEPT_NAMES[piece]).trim_prefix("the Warhorn's "), have])
			Sfx.play(game, "pickup", -8.0, 1.0)
	# An elite may leave an accessory too. (Asked of the shared dice after everything else, and only where the
	# game has accessories. A Warhorn piece's line is the one that stays on the screen.)
	if elite and _gear() != null:
		var roll := Sim.chance()
		var pick := floori(Sim.between(0.0, float(Accessories.POOL.size()) - 0.001))
		if roll < float(ELITE_GIFT):
			var line := said
			var until := said_until
			gift(str(Accessories.POOL[clampi(pick, 0, Accessories.POOL.size() - 1)]), at, 0.45)
			if piece != "" and until > clock:
				said = line
				said_until = until


## Somebody's tool won something (tools.gd tells us): mining ore and felling a pine are worth a little Memory.
func worked(i: int, item: String, at: Vector2, after := 0.0) -> void:
	give(i, "memory", int(WORK_MEMORY.get(item, 0)), at, after + 0.1)


## Once a tick: the lids, and what lies on the ground for somebody who now has room for it.
func tick(delta: float) -> void:
	clock += delta
	for ch in chests:
		if int(ch["state"]) == 1:
			ch["t"] = float(ch["t"]) + delta
			if float(ch["t"]) >= SHOW_TIME:
				ch["state"] = 2
	if lying.is_empty() or tools == null:
		return
	for l in lying.duplicate():
		var i := int(l["i"])
		if i >= players.size() or not is_instance_valid(players[i]) or players[i].is_down:
			continue
		var p = players[i]
		if p.global_position.distance_to(l["at"]) > PICK:
			continue
		if tools.bag_of(i).add(str(l["item"]), 1) == 1:
			lying.erase(l)
			flies.append({"item": str(l["item"]), "i": i, "from": l["at"], "spot": l["at"], "t": HOP, "wait": 0.0, "mote": false})
		elif clock - (purses[i] as Purse).told_at > 1.6:
			(purses[i] as Purse).told_at = clock
			p._label("INVENTORY FULL", INK)


## A line for everyone, for a few seconds.
func say(text: String) -> void:
	said = text
	said_until = clock + SAY_TIME


# --- What is saved ------------------------------------------------------------------------

## Player i's coins, Memory and kept things, as plain values for the character save.
func purse_data(i: int) -> Dictionary:
	var purse: Purse = purses[i]
	var kept: Array = purse.kept.keys()
	kept.sort()
	return {"coins": purse.coins, "memory": purse.memory, "kept": kept}


## And back. Whatever is missing stays as it was; a kept thing this game does not know is left out.
func set_purse_data(i: int, d: Dictionary) -> void:
	var purse: Purse = purses[i]
	if d.get("coins") is int or d.get("coins") is float:
		purse.coins = maxi(int(d["coins"]), 0)
	if d.get("memory") is int or d.get("memory") is float:
		purse.memory = maxi(int(d["memory"]), 0)
	if d.get("kept") is Array:
		purse.kept = {}
		for name in d["kept"]:
			if name is String and name in KEPT:
				purse.kept[name] = true


## The chests that have been opened, for the world save: their ids, in order.
func opened_ids() -> Array:
	var ids: Array = opened.keys()
	ids.sort()
	return ids


## And back: those chests stand open and empty. An id this land has no chest for is passed over.
func set_opened(d) -> void:
	if not (d is Array):
		return
	for v in d:
		if not (v is int or v is float):
			continue
		var k := chest_of(int(v))
		if k < 0:
			continue
		opened[int(v)] = true
		chests[k]["state"] = 2
		(chests[k]["sprite"] as Sprite2D).texture = _frame("chest_empty")


# --- Looks only ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	for ch in chests:
		var s: Sprite2D = ch["sprite"]
		match int(ch["state"]):
			1:
				s.texture = _frame("chest", clampi(int(float(ch["t"]) * LID_FPS), 0, 4))
			2:
				s.texture = _frame("chest_empty")
	for f in flies:
		var before: float = f["t"]
		f["t"] = before + delta
		if before < 0.0 and float(f["t"]) >= 0.0 and not bool(f["mote"]):
			Sfx.play(game, "click", -16.0, 1.2 + 0.1 * float(dice.randi() % 4))
		if float(f["t"]) >= HOP + float(f["wait"]) + FLY and int(f["i"]) < purses.size():
			(purses[int(f["i"])] as Purse).gained[str(f["item"])] = clock      # its number lights as it arrives
			if tools != null and int(f["i"]) < tools.hands.size():
				tools.hands[int(f["i"])].gained[str(f["item"])] = tools.clock
			Sfx.play(game, "click", -15.0 if bool(f["mote"]) else -12.0, (2.3 if bool(f["mote"]) else 1.7) + 0.12 * float(dice.randi() % 4))
	flies = flies.filter(func(f): return float(f["t"]) < HOP + float(f["wait"]) + FLY)
	over.queue_redraw()
	panel.queue_redraw()


## A soft shadow on the ground under every chest.
func _draw_under(ci: Node2D) -> void:
	for ch in chests:
		Art.draw_piece(ci, "shadow_m", 0, (ch["plan"]["foot"] as Vector2) * UNIT + Vector2(0, -3))


func _draw_over(ci: Node2D) -> void:
	# What lies on the ground waiting for room: it glints every second or two, as the art asks.
	for k in lying.size():
		var l: Dictionary = lying[k]
		if Accessories.has(l["item"]):
			_draw_accessory(ci, str(l["item"]), (l["at"] as Vector2) + Vector2(0, -16))
			continue
		var name := "drop_" + str(l["item"])
		var glint := fmod(clock + 0.37 * float(k), 1.7) < 0.14
		ItemArt.draw(ci, name, (((l["at"] as Vector2) / UNIT).floor() - Vector2(6, 12)) * UNIT, UNIT, Color.WHITE, 1 if glint else 0)
	for f in flies:
		if int(f["i"]) >= players.size() or not is_instance_valid(players[int(f["i"])]):
			continue
		var t: float = f["t"]
		if t < 0.0:
			continue
		# Out with a hop, a moment on the ground, then up in an arc to whoever it is for.
		var at: Vector2
		if t < HOP:
			var k := t / HOP
			at = (f["from"] as Vector2).lerp(f["spot"], k) + Vector2(0, -14.0 * sin(k * PI))
		elif t < HOP + float(f["wait"]):
			at = f["spot"]
		else:
			var k := clampf((t - HOP - float(f["wait"])) / FLY, 0.0, 1.0)
			var to: Vector2 = players[int(f["i"])].global_position + Vector2(0, -10)
			at = (f["spot"] as Vector2).lerp(to, k * k) + Vector2(0, -30.0 * sin(k * PI))
		if bool(f["mote"]):
			ItemArt.draw(ci, "memory_mote", ((at / UNIT).floor() - Vector2(3, 3)) * UNIT, UNIT, Color.WHITE, int(clock * 10.0))
		elif Accessories.has(f["item"]):
			_draw_accessory(ci, str(f["item"]), at)
		else:
			var name := "drop_" + str(f["item"])
			ItemArt.draw(ci, name, ((at / UNIT).floor() - (ItemArt.size(name) * 0.5).floor()) * UNIT, UNIT)


## An accessory's own picture, its middle at `at` (world units): what comes out of a chest, and what lies waiting.
func _draw_accessory(ci: CanvasItem, id: String, at: Vector2) -> void:
	var tex := Art.texture("accessories/%s_icon.png" % id)
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(((at / UNIT).floor() - (tex.get_size() * 0.5).floor()) * UNIT, tex.get_size() * UNIT), false)


func _head(text: String, pos: Vector2, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	panel.draw_string(Art.font("Silkscreen-Regular"), pos, text.to_upper(), align, width, 8, col)


func _head_width(text: String) -> float:
	return ceilf(Art.font("Silkscreen-Regular").get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)


## Where player i's purse is drawn: beside their health bar, on its inner side.
func purse_rect(i: int) -> Rect2:
	var purse: Purse = purses[i]
	var lead := 26.0 if players.size() > 1 else 0.0
	var w := 15.0 + _head_width(str(purse.coins)) + 2.0
	if not purse.kept.is_empty():
		w += 5.0 + 17.0 * float(purse.kept.size())
	var x := MARGIN + lead + HP_BAR + 10.0
	if i % 2 == 1:
		x = SIZE.x - MARGIN - lead - HP_BAR - 10.0 - w
	return Rect2(x, 7.0, w, 16.0)


## On the screen, beside each health bar: the coins, and the Warhorn's pieces that are held. (The Memory carried is
## the bar under the health bar: levels.gd draws it.)
func _draw_hud() -> void:
	for i in purses.size():
		if i >= players.size() or not is_instance_valid(players[i]):
			continue
		var purse: Purse = purses[i]
		var r := purse_rect(i)
		panel.draw_rect(Rect2(r.position - Vector2(4, 3), r.size + Vector2(8, 6)), SHADE)
		var lit_c := clampf(1.0 - (clock - float(purse.gained.get("coins", -9.0))) / 0.7, 0.0, 1.0)
		ItemArt.draw(panel, "hud_coin", r.position + Vector2(0, 2))
		_head(str(purse.coins), r.position + Vector2(15, 12), INK.lerp(AMBER, lit_c))
		var x := r.end.x - 17.0 * float(purse.kept.size())
		for name in KEPT:
			if purse.kept.has(name):
				var fresh := clampf(1.0 - (clock - float(purse.gained.get(name, -9.0))) / 1.2, 0.0, 1.0)
				ItemArt.draw(panel, "item_" + str(name), Vector2(x + 1.0, r.position.y - roundf(2.0 * fresh)))
				x += 17.0
	if clock < said_until:
		var w := _head_width(said) + 12.0
		var a := clampf((said_until - clock) / 0.4, 0.0, 1.0)
		panel.draw_rect(Rect2(floorf((SIZE.x - w) * 0.5), said_y, w, 14), Color(SHADE.r, SHADE.g, SHADE.b, SHADE.a * a))
		_head(said, Vector2(0, said_y + 10.0), Color(AMBER.r, AMBER.g, AMBER.b, a), SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
