extends Node2D
## The basic tools of the Highlands: a pickaxe, an axe and a mallet on a tool belt.
##
## Darren, 22 November 2026: "put in basic tools". How they are used is his too (the Game Bible's "Using tools"):
## a separate WORK button uses the tool you have picked, and a CYCLE button steps through the pickaxe, the axe and
## the mallet ("would rather cycle tools to what u need rather than auto picking it"). The game never picks the
## tool for you. Your weapon stays your weapon: attack and it swings, and its swing path and spirit stay on screen.
## Tools sit on a belt that belongs to the character, they never break, and a better tool replaces the old one.
## What they win goes into the character's inventory (bag.gd).
##
##   pickaxe   digs rock (it becomes dug floor and gives stone), mines tin and copper out of it, breaks up boulders
##   axe       fells pines for wood, and leaves the stump
##   mallet    is for building, and there is nothing to build yet
##
## Until there is a workbench to make them at, everyone starts with the basic three (Claude's choice).
##
## Rules for the code: everything that changes the game (which tool is picked, how worn a tile is, what breaks,
## what goes in a bag, the moment a landed blow holds the swing) is worked out in tick(), once a physics tick, from
## the players' buttons alone. Chips, sparks, cracks, bursts, the pine that leans and falls, and the pictures flying
## to you are only looks; they take their dice from `dice`, which nothing else uses. The drawn ones (cracks, bursts,
## the pines' shake and fall) are the Art builder's, in art/dig_fx/, and its README says how each is to be used.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Bag := preload("res://scripts/highlands/bag.gd")
const ItemArt := preload("res://scripts/highlands/item_art.gd")
const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const SpriteOnce := preload("res://scripts/fx/sprite_once.gd")

const UNIT := Art.PIXEL
const TILE := 16.0 * UNIT
const CHUNK := LandMap.CHUNK * TILE

const TOOLS := ["pickaxe", "axe", "mallet"]
const NAMES := {"pickaxe": "Pickaxe", "axe": "Axe", "mallet": "Mallet"}
const POWER := {"basic": 1}         # what one blow of a tool of that make is worth
const SWING := 0.42                 # seconds one swing takes
const STRIKE := 0.2                 # how far into it the blow lands
const HIT_STOP := 0.05              # a blow that lands holds the tool there this long
const REACH := 46.0                 # how far from your middle a tool reaches (world units; a tile is 32)
const HAND_PIVOT := Vector2(0, -14) # the swing goes round this point of the body, as the sword's does
const HAND_RADIUS := 9.0
const STRUCK_AT := 0.3              # how far past your aim the tool has come round as the blow lands (radians)
const RAISED := -1.9                # where it is held before a blow, back over the shoulder
const WALK := 0.35                  # walking speed while a tool swings
const FORGET := 4.0                 # a part-dug tile is whole again after this long without a blow
## Looks only.
const JOLT := 0.1                   # how long a struck tile jolts
const FALL := 520.0                 # how fast chips fall (world units a second, each second)
const HOP := 0.16                   # what you win hops out of the tile ...
const LIE := 0.22                   # ... lies there a moment ...
const FLY := 0.34                   # ... and flies to you
const SWAY := [0.05, 0.06]          # a struck pine leans one way this long, then the other (the Art builder's times)
## How many blows of a basic tool it takes.
const TILE_NEED := {LandMap.ROCK: 3, LandMap.TIN: 4, LandMap.COPPER: 4}
const THING_NEED := {"pine": 5, "boulder": 4}
## What it gives: [item, how many].
const TILE_GIVES := {LandMap.ROCK: ["stone", 1], LandMap.TIN: ["tin_ore", 2], LandMap.COPPER: ["copper_ore", 2]}
const THING_GIVES := {"pine": ["wood", 3], "boulder": ["stone", 2]}
const THING_TOOL := {"pine": "axe", "boulder": "pickaxe"}

## Colours for the chips (the art's own ramps).
const ITEM_COL := {"stone": Color("8ba688"), "wood": Color("b87644"), "tin_ore": Color("dcd6b0"), "copper_ore": Color("cf8a48")}
const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const FAINT := Color("#5f8072")
const AMBER := Color("#ffc850")
const PLATE := Color("#19142a")
const SHADE := Color(0.098, 0.078, 0.165, 0.5)
const SIZE := Vector2(640, 360)
const MARGIN := 10.0
const SLOT := 18.0


## What one player carries and is doing with it. The belt, the tool that is picked, the inventory and the backpack
## that sets its size belong to the character and are in its save (hand_data(), set_hand_data()); the rest is this
## moment's.
class Hand:
	var tool := 0                                                         # which of TOOLS is picked
	var belt := {"pickaxe": "basic", "axe": "basic", "mallet": "basic"}   # the make of each tool ("" = none)
	var bag := Bag.new()
	var swing := -1.0             # seconds into the swing (-1: no tool is swinging)
	var struck := false           # this swing's blow has landed
	var pause := 0.0              # the tool stays where it struck for a moment (a blow that lands has weight)
	var dir := Vector2.DOWN       # where this swing goes
	var target := {}              # what it will strike, or struck ({}: nothing)
	var picked_at := -9.0         # when the picked tool last changed (the belt lights up)
	var gained := {}              # item -> when some last went into the bag
	var told_at := -9.0           # when a word was last put over their head ("Inventory full")


## Chips, dust and pick-ups: over everything on the land.
class Over extends Node2D:
	var owner_tools

	func _draw() -> void:
		owner_tools._draw_over(self)


var game                          # the Highlands scene
var map: LandMap
var land                          # land_view.gd
var players: Array = []
var hands: Array = []             # a Hand per player
var wear := {}                    # what has taken blows: key -> {hits, at, need, tile or thing}
var extras: Array = []            # what else a tool can strike (folk.gd's cage): [{box: Rect2 (world units), can: Callable() -> bool, strike: Callable(i, at)}]
var clock := 0.0
var dice := RandomNumberGenerator.new()
var chips: Array = []             # [{at, vel, life, col, size}] in world units
var flies: Array = []             # [{from, spot, i, t, wait, item}] something won, on its way to player i
var jolts: Array = []             # [{tile, t, dir}] tiles that have just been struck
var over: Over
var layer: CanvasLayer
var panel: Control
var later: Array = []             # [{t, tile}] ground to paint again in a moment (a felled pine's shadow goes as it lands)
var sheet: Texture2D              # the tool pictures (art/tools/tools.png) ...
var boxes := {}                   # ... and where each one is on it: name -> {box: [x, y, w, h], pivot, strike, foot}
var fx_sheet: Texture2D           # cracks, bursts, and the pines' shake and fall (art/dig_fx/dig_fx.png) ...
var fx_rules := {}                # ... what the Art builder says about them (the times, which crack after which blow) ...
var fx := {}                      # ... and where each one is: name -> {box, origin or foot, frames}
var _fx_tex := {}                 # name -> AtlasTexture


func _ready() -> void:
	z_index = -9                  # the target's corners: on the land, under everything that stands on it
	dice.seed = 20261122
	over = Over.new()
	over.owner_tools = self
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
	sheet = Art.texture("tools/tools.png")
	boxes = Art.json("tools/tools.json").get("sprites", {})
	fx_sheet = Art.texture("dig_fx/dig_fx.png")
	fx_rules = Art.json("dig_fx/dig_fx.json")
	fx = fx_rules.get("sprites", {})
	for i in players.size():
		_add_hand(i)


func _add_hand(i: int) -> void:
	hands.append(Hand.new())
	# While a tool swings, the player's own weapon layer draws it (so it gets the weapon's outline, and sits behind
	# or in front of the body as the weapon does).
	players[i].tool_draw = _draw_hand.bind(i)


## The tool player i has picked: "pickaxe", "axe" or "mallet".
func tool_of(i: int) -> String:
	return TOOLS[(hands[i] as Hand).tool]


func bag_of(i: int) -> Bag:
	return (hands[i] as Hand).bag


## What player i carries that belongs to their character, as plain values for the character save: the belt, the
## tool that is picked, the inventory (under "bag", as the materials bag it grew out of was) and the backpack.
func hand_data(i: int) -> Dictionary:
	var h: Hand = hands[i]
	return {"belt": h.belt.duplicate(), "tool": h.tool, "bag": h.bag.data(), "pack": h.bag.pack}


## And back. A make of tool this game does not have becomes the basic one; whatever is missing stays as it was.
func set_hand_data(i: int, d: Dictionary) -> void:
	var h: Hand = hands[i]
	var belt = d.get("belt")
	if belt is Dictionary:
		for name in TOOLS:
			if belt.get(name) is String:
				h.belt[name] = str(belt[name]) if (belt[name] == "" or POWER.has(belt[name])) else "basic"
	if d.get("tool") is int or d.get("tool") is float:
		h.tool = clampi(int(d["tool"]), 0, TOOLS.size() - 1)
	if str(h.belt.get(TOOLS[h.tool], "")) == "":
		for n in TOOLS.size():
			if str(h.belt.get(TOOLS[n], "")) != "":
				h.tool = n
				break
	if d.get("pack") is int or d.get("pack") is float:
		h.bag.pack = clampi(int(d["pack"]), 0, Bag.PACKS.size() - 1)
	if d.has("bag"):
		h.bag.set_data(d["bag"])


# --- The rules: once a tick --------------------------------------------------------------

func tick(delta: float, busy: bool) -> void:
	clock += delta
	for i in players.size():
		var p = players[i]
		var h: Hand = hands[i]
		if busy or p.frozen or p.is_down:
			_stop(p, h)
			continue
		var inp = p.input
		if inp.tool_next_pressed:
			_pick(h, 1)
		if inp.tool_prev_pressed:
			_pick(h, -1)
		# The weapon comes first: a tool never swings through an attack, a dodge or a rune.
		var free: bool = p.current_step < 0 and p.dodge_timer <= 0.0 and p.hold_button < 0 and p.snipe_button < 0 and p.leap_landing.is_empty() \
			and not inp.attack_pressed and not (inp.attack_held and not p.need_release)
		if not free:
			_stop(p, h)
			continue
		if h.swing < 0.0 and inp.work_held:
			_begin(p, h)
		if h.swing < 0.0:
			continue
		if h.pause > 0.0:
			h.pause -= delta
			continue
		h.swing += delta
		if not h.struck and h.swing >= STRIKE:
			h.struck = true
			_strike(i)
		if h.swing >= SWING:
			if inp.work_held:
				_begin(p, h)      # held down: the next swing follows at once, where you aim now
			else:
				_stop(p, h)
	# What has not been struck for a while is whole again.
	for key in wear.keys():
		if clock - float(wear[key]["at"]) > FORGET:
			wear.erase(key)


func _begin(p, h: Hand) -> void:
	h.swing = 0.0
	h.struck = false
	h.dir = p.aim_dir.normalized() if p.aim_dir.length() > 0.1 else p.face_dir
	h.target = find(p, h, h.dir)
	p.tool_dir = h.dir
	p.tool_move = WALK


func _stop(p, h: Hand) -> void:
	h.swing = -1.0
	h.pause = 0.0
	h.target = {}
	p.tool_dir = Vector2.ZERO
	p.tool_move = 1.0


func _pick(h: Hand, step: int) -> void:
	for n in TOOLS.size():
		h.tool = posmod(h.tool + step, TOOLS.size())
		if str(h.belt.get(TOOLS[h.tool], "")) != "":
			break
	h.picked_at = clock
	h.target = {}
	Sfx.play(game, "click", -10.0, 1.3)


static func thing_class(t: Dictionary) -> String:
	var n := str(t["n"])
	if n.begins_with("pine_") and n != "pine_stump":
		return "pine"
	if n.begins_with("boulder_"):
		return "boulder"
	return ""


## What stops you at the foot of a thing, a little grown and a little taller, so that aiming at a trunk finds it.
static func thing_box(t: Dictionary) -> Rect2:
	var solid: Array = Painter.things.get(str(t["n"]), {}).get("solid", [8, 4])
	var size := Vector2(float(solid[0]), float(solid[1])) * UNIT
	var foot := Vector2(float(t["x"]), float(t["y"])) * UNIT
	return Rect2(foot - Vector2(size.x * 0.5 + 5.0, size.y + 19.0), size + Vector2(10.0, 24.0))


## What the picked tool would strike, the way `dir` points: the nearest thing it works on within reach. A tile is
## {tile, kind, fixed, at}; a thing is {thing, class, at}; `at` is where the blow lands. {} when there is nothing.
func find(p, h: Hand, dir: Vector2) -> Dictionary:
	var tool: String = TOOLS[h.tool]
	if dir == Vector2.ZERO or str(h.belt.get(tool, "")) == "":
		return {}
	var from: Vector2 = p.global_position
	var best := {}
	var best_d := REACH + 1.0
	if tool == "pickaxe":
		var d := 8.0
		while d <= REACH:
			var q := from + dir * d
			var t := Vector2i(floori(q.x / TILE), floori(q.y / TILE))
			if map.is_rock(t.x, t.y):
				best = {"tile": t, "kind": map.kind(t.x, t.y), "fixed": map.fixed(t.x, t.y), "at": q}
				best_d = d
				break
			d += 4.0
	if tool == "pickaxe" or tool == "axe":
		var cx := floori(from.x / CHUNK)
		var cy := floori(from.y / CHUNK)
		for j in range(-1, 2):
			for i in range(-1, 2):
				for t in map.things_in(cx + i, cy + j):
					var cls := thing_class(t)
					if cls == "" or THING_TOOL[cls] != tool:
						continue
					var box := thing_box(t)
					var d := 6.0
					while d < best_d:
						if box.has_point(from + dir * d):
							best = {"thing": t, "class": cls, "at": from + dir * (d + 4.0)}
							best_d = d
							break
						d += 3.0
	# What is not the land's own (Pip's cage): any tool strikes it.
	for e in extras:
		if not bool((e["can"] as Callable).call()):
			continue
		var box: Rect2 = e["box"]
		var d := 6.0
		while d < best_d:
			if box.has_point(from + dir * d):
				best = {"extra": e, "at": from + dir * (d + 4.0)}
				best_d = d
				break
			d += 3.0
	return best


func _wear_key(t: Dictionary) -> int:
	if t.has("extra"):
		return -2000000000 - extras.find(t["extra"])
	if t.has("tile"):
		return int(t["tile"].y) * LandMap.SIZE + int(t["tile"].x)
	return -1 - LandMap.thing_key(t["thing"])


## The blow lands.
func _strike(i: int) -> void:
	var p = players[i]
	var h: Hand = hands[i]
	var tool: String = TOOLS[h.tool]
	var t := find(p, h, h.dir)
	h.target = t
	if t.has("extra"):
		# The blow is the tool's; what comes of it is whoever owns the thing's to say.
		var where := _tip(p, h, t)
		_spark(where, 0.8)
		h.pause = HIT_STOP
		p.squash = Vector2(1.06, 0.95)
		(t["extra"]["strike"] as Callable).call(i, where)
		return
	if tool == "mallet":
		_tell(p, h, "Nothing to build yet")
		Sfx.play(game, "swing", -14.0, 0.8)
		return
	if t.is_empty():
		Sfx.play(game, "swing", -14.0, 0.9)
		return
	var at := _tip(p, h, t)
	var what := _stuff(t)
	if t.get("fixed", false):
		_tell(p, h, "Too hard to dig")
		Sfx.play(game, "click", -6.0, 0.5)
		Sfx.play(game, "anvil", -20.0, 2.2)
		_spark(at, 0.6)
		_chip(at, p.global_position, 2, _cols("stone"))
		h.pause = HIT_STOP
		return
	var gives: Array = TILE_GIVES[int(t["kind"])] if t.has("tile") else THING_GIVES[str(t["class"])]
	# Ore and wood are never thrown away: with no room for them the tool stays its blow. Stone is only rubble,
	# and digging must always be possible, so a full inventory just leaves it lying.
	if str(gives[0]) != "stone" and h.bag.room(str(gives[0])) < int(gives[1]):
		_tell(p, h, "Inventory full")
		Sfx.play(game, "click", -10.0, 0.6)
		return
	var key := _wear_key(t)
	var need: int = TILE_NEED[int(t["kind"])] if t.has("tile") else THING_NEED[str(t["class"])]
	var w: Dictionary = wear.get(key, {"hits": 0})
	w["hits"] = int(w["hits"]) + int(POWER.get(str(h.belt[tool]), 1))
	w["at"] = clock
	w["need"] = need
	w["target"] = t
	wear[key] = w
	# What a blow looks, sounds and feels like: chips in the stuff's own colours fly back at you, the tile jolts
	# (a pine or a boulder shivers), a spark off stone, and a sound for stone, for ore and for wood.
	var gives_way := int(w["hits"]) >= need
	_chip(at, p.global_position, 5 if what == "wood" else 8, _cols(what))
	_sound(what)
	h.pause = HIT_STOP
	p.squash = Vector2(1.06, 0.95)        # the body takes the blow too (it eases back by itself)
	if what == "wood":
		_play("burst_wood", at)
	else:
		_spark(at, 0.8 if what == "stone" else 1.0)
	if t.has("tile"):
		jolts.append({"tile": t["tile"], "t": 0.0, "dir": Vector2(roundf(h.dir.x), roundf(h.dir.y))})
	elif not gives_way:
		_shake(t["thing"], p.global_position)
	if gives_way:
		wear.erase(key)
		_break(i, t, gives)


## It gives way: the tile becomes dug floor, the pine a stump, the boulder nothing; what it held goes in the bag.
## The land changed: the enemies' way-finding is told (a dug tile can be walked, a broken boulder is gone).
func _tell_nav(tile: Vector2i, foot: Vector2) -> void:
	if game == null or not ("foes" in game) or game.foes == null or game.foes.nav == null:
		return
	if foot == Vector2.INF:
		game.foes.nav.tile_changed(tile)
	else:
		game.foes.nav.things_changed(foot)


func _break(i: int, t: Dictionary, gives: Array) -> void:
	var p = players[i]
	var h: Hand = hands[i]
	var at := _middle(t)
	var what := _stuff(t)
	var after := 0.0          # looks only: a pine's wood is seen to drop where its crown lands, a moment later
	if t.has("tile"):
		var tile: Vector2i = t["tile"]
		if map.dig(tile.x, tile.y) < 0:
			return
		land.changed(tile)
		_tell_nav(tile, Vector2.INF)
		Sfx.play(game, "slam", -13.0, 1.5)
		Sfx.play(game, "thud", -8.0, 0.9)
		if not _play("burst_" + {"stone": "rock", "tin_ore": "tin", "copper_ore": "copper"}[what], at):
			_dust(at)
		_burst(at, 6, _cols(what))
		p.shake = maxf(p.shake, 2.0)
	else:
		var thing: Dictionary = t["thing"]
		var foot := Vector2(float(thing["x"]), float(thing["y"]))
		var ground := Vector2i(int(foot.x) / LandMap.TILE_PX, int(foot.y) / LandMap.TILE_PX)      # its shadow is painted into the ground
		if str(t["class"]) == "pine":
			var lands := _fell(thing, p.global_position)
			map.remove_thing(thing)
			map.add_thing({"n": "pine_stump", "x": int(thing["x"]), "y": int(thing["y"]), "f": false})
			Sfx.play(game, "slam", -14.0, 1.3)
			Sfx.play(game, "swing", -10.0, 0.6)
			at = lands[0]
			after = lands[1]
			later.append({"t": after, "tile": ground, "at": at, "i": i})
		else:
			map.remove_thing(thing)
			Sfx.play(game, "slam", -13.0, 1.5)
			Sfx.play(game, "thud", -8.0, 0.8)
			at = (foot + Vector2(0, -6)) * UNIT
			if not _play("burst_rock", at):
				_dust(at)
			_burst(at, 6, _cols("stone"))
			land.changed(ground)
			p.shake = maxf(p.shake, 2.0)
		land.things_changed(foot)
		_tell_nav(Vector2i.ZERO, foot)
	# The Prospector's Sieve: an ore mined may give one more (gear.gd asks the game's shared dice).
	var more := 0
	if t.has("tile") and game != null and "gear" in game and game.gear != null:
		more = game.gear.extra_ore(i, str(gives[0]))
	var got: int = h.bag.add(str(gives[0]), int(gives[1]) + more)
	# What was won jumps out, lies a moment, and flies to whoever won it. It lies on the far side of where it came
	# from: dug from right against the rock, the near side is behind your own head.
	var away: Vector2 = (at - p.global_position).normalized()
	for n in got:
		var spot := at + away * dice.randf_range(5.0, 9.0) + away.rotated(PI * 0.5) * dice.randf_range(4.0, 10.0) * (1.0 if n % 2 == 0 else -1.0)
		flies.append({"from": at, "spot": spot, "i": i, "t": -after, "wait": LIE + 0.08 * float(n), "item": str(gives[0])})
	# Mining ore and felling a pine are worth a little Memory (loot.gd says how much).
	if got > 0 and game != null and "loot" in game and game.loot != null:
		game.loot.worked(i, str(gives[0]), at, after)
	h.target = {}


## Where the tool's head is on the screen as the blow lands (world units): chips and sparks come from there. The
## ground a blow lands on is hidden behind your own head when you dig up the screen, so the looks follow the tool.
func _tip(p, h: Hand, t: Dictionary) -> Vector2:
	var info: Dictionary = boxes.get("hand_" + str(TOOLS[h.tool]), {})
	var side := 1.0 if h.dir.x >= 0.0 else -1.0
	var along := 11.0
	var across := 0.0
	var pivot: Array = info.get("pivot", [])
	var strike: Array = info.get("strike", [])
	if pivot.size() == 2 and not strike.is_empty():
		var sum := Vector2.ZERO
		for q in strike:
			sum += Vector2(float(q[0]), float(q[1]))
		sum /= float(strike.size())
		along = float(pivot[1]) - sum.y
		across = sum.x - float(pivot[0])
	var axis := Vector2.RIGHT.rotated(h.dir.angle() + side * STRUCK_AT)
	var tip: Vector2 = p.global_position + HAND_PIVOT + axis * (HAND_RADIUS + along * UNIT) + axis.rotated(PI * 0.5 * side) * across * UNIT
	if t.has("tile"):
		var r := Rect2(Vector2(t["tile"]) * TILE, Vector2(TILE, TILE)).grow(-4.0)
		tip = tip.clamp(r.position, r.end)
	return tip


## What a thing is made of, for its chips and its sound: "stone", "tin_ore", "copper_ore" or "wood".
func _stuff(t: Dictionary) -> String:
	if t.has("thing"):
		return "wood" if str(t["class"]) == "pine" else "stone"
	match int(t["kind"]):
		LandMap.TIN:
			return "tin_ore"
		LandMap.COPPER:
			return "copper_ore"
	return "stone"


## The middle of what is struck, in world units.
func _middle(t: Dictionary) -> Vector2:
	if t.has("tile"):
		return (Vector2(t["tile"]) + Vector2(0.5, 0.5)) * TILE
	var thing: Dictionary = t["thing"]
	return Vector2(float(thing["x"]), float(thing["y"]) - 5.0) * UNIT


## A few words over a player's head, not more than once in a while.
func _tell(p, h: Hand, words: String) -> void:
	if clock - h.told_at < 1.6:
		return
	h.told_at = clock
	p._label(words.to_upper(), INK)


# --- Looks only --------------------------------------------------------------------------

## The colours a thing's chips fly off in: the art's own ramps (the rock face, the two seams, plank and needle).
func _cols(what: String) -> Array:
	var face: Array = Painter.vein_cols.get("face", [])
	var rock: Array = [face[3], face[4], face[4], face[5], face[6]] if face.size() >= 7 else [DIM]
	match what:
		"tin_ore", "copper_ore":
			var seam: Array = Painter.vein_cols.get("tin" if what == "tin_ore" else "copper", [])
			if seam.size() >= 5:
				return [rock[0], rock[1], rock[3], seam[2], seam[3], seam[3], seam[4]]
		"wood":
			return [Color("8f4f38"), Color("b87644"), Color("b87644"), Color("dca25c"), Color("dca25c"), Color("2a7f70")]
	return rock


## Chips off a blow: they fly back towards whoever struck, up a little, and fall.
func _chip(at: Vector2, from: Vector2, n: int, cols: Array) -> void:
	var away := (from - at).normalized()
	for k in n:
		# Out to either side of the blow, never straight back into your face.
		var dir := away.rotated(dice.randf_range(0.5, 1.5) * (1.0 if dice.randf() < 0.5 else -1.0))
		chips.append({"at": at + Vector2(dice.randf_range(-4.0, 4.0), dice.randf_range(-4.0, 4.0)), "vel": dir * dice.randf_range(70.0, 190.0) + Vector2(0, -50.0),
			"life": dice.randf_range(0.3, 0.55), "col": cols[dice.randi() % cols.size()], "size": [Vector2(2, 2), Vector2(2, 2), Vector2(2, 1), Vector2(1, 2), Vector2(1, 1)][dice.randi() % 5]})


## It breaks: pieces fly out all round.
func _burst(at: Vector2, n: int, cols: Array) -> void:
	for k in n:
		var dir := Vector2.RIGHT.rotated(TAU * (float(k) + dice.randf()) / float(n))
		chips.append({"at": at + dir * dice.randf_range(2.0, 10.0), "vel": dir * dice.randf_range(80.0, 210.0) + Vector2(0, -70.0),
			"life": dice.randf_range(0.35, 0.65), "col": cols[dice.randi() % cols.size()], "size": [Vector2(3, 2), Vector2(2, 2), Vector2(2, 2), Vector2(2, 1), Vector2(1, 1)][dice.randi() % 5]})


## A spark where iron meets stone (the weapons' own hit spark, small).
func _spark(at: Vector2, size: float) -> void:
	Art.play_piece(self, "hit_spark", at, dice.randf_range(0.0, TAU), size * 0.7)


## The sound of a blow. Stand-ins made from the game's own sounds: a stone tick, a ring for ore, a thock for wood.
func _sound(what: String) -> void:
	var lift := dice.randf_range(-0.06, 0.06)      # no two blows quite the same
	match what:
		"wood":
			Sfx.play(game, "thud", -6.0, 1.35 + lift)
			Sfx.play(game, "click", -11.0, 0.5 + lift)
		"tin_ore", "copper_ore":
			Sfx.play(game, "click", -5.0, 0.7 + lift)
			Sfx.play(game, "hit", -10.0, 0.8 + lift)
			Sfx.play(game, "anvil", -17.0, 1.9 if what == "tin_ore" else 1.6)
		_:
			Sfx.play(game, "click", -5.0, 0.7 + lift)
			Sfx.play(game, "hit", -9.0, 0.75 + lift)


func _dust(at: Vector2) -> void:
	var tex := Art.texture("cave/dust_puff.png")
	if tex == null:
		return
	var n := SpriteOnce.new()
	n.texture = tex
	n.frames = 4
	n.fps = 12.0
	n.origin = Vector2(8, 10)
	n.size = 1.4
	add_child(n)
	n.global_position = at


## One picture, or one strip, off the Art builder's sheet of cracks, bursts and falling pines.
func _fx_texture(name: String) -> AtlasTexture:
	if not _fx_tex.has(name):
		var box: Array = fx.get(name, {}).get("box", [])
		if fx_sheet == null or box.size() != 4:
			return null
		var tex := AtlasTexture.new()
		tex.atlas = fx_sheet
		tex.region = Rect2(box[0], box[1], box[2], box[3])
		_fx_tex[name] = tex
	return _fx_tex[name]


## Plays one of the drawn bursts once, its origin at `at` (world units), after `wait` seconds. False if there is none.
## It is among the things that stand on the land, sorted by where it is: whoever stands in front of the tile that
## breaks is in front of its rubble too.
func _play(name: String, at: Vector2, wait := 0.0) -> bool:
	var tex := _fx_texture(name)
	if tex == null:
		return false
	var info: Dictionary = fx[name]
	var n := SpriteOnce.new()
	n.texture = tex
	n.frames = int(info.get("frames", 1))
	n.fps = 1000.0 / float(fx_rules.get("bursts", {}).get("ms_per_frame", 60))
	var o: Array = info.get("origin", [0, 0])
	n.origin = Vector2(float(o[0]), float(o[1]))
	n.wait = wait
	land.world.add_child(n)
	n.z_index = 0
	n.global_position = (at / UNIT).floor() * UNIT
	return true


## Shows one of the sheet's pine pictures on a sprite that stands on the land, its foot where the pine's foot is.
func _pose(s: Sprite2D, name: String) -> void:
	var tex := _fx_texture(name)
	if tex == null or not is_instance_valid(s):
		return
	var f: Array = fx[name].get("foot", [0, 0])
	var x := float(f[0])
	if s.flip_h:
		x = tex.region.size.x - 1.0 - x
	s.texture = tex
	s.offset = Vector2(-x, -float(f[1]) + land.SORT_BIAS / UNIT)


## The thing's own picture again (as land_view.gd stands it).
func _unpose(s: Sprite2D, name: String) -> void:
	if not is_instance_valid(s) or not Painter.things.has(name):
		return
	var f: Array = Painter.things[name]["foot"]
	s.texture = land.thing_texture(name)
	var x := float(f[0])
	if s.flip_h:
		x = s.texture.region.size.x - 1.0 - x
	s.offset = Vector2(-x, -float(f[1]) + land.SORT_BIAS / UNIT)


## The struck thing shivers: a pine leans away from the blow and back (the Art builder's two pictures), a boulder
## jumps a pixel each way.
func _shake(thing: Dictionary, from: Vector2) -> void:
	var s: Sprite2D = land.sprite_of(thing)
	if s == null:
		return
	if s.has_meta("shake") and (s.get_meta("shake") as Tween).is_valid():
		(s.get_meta("shake") as Tween).kill()
	var name := str(thing["n"])
	var tw := s.create_tween()
	s.set_meta("shake", tw)
	if fx.has(name + "_shake_r") and fx.has(name + "_shake_l"):
		# A blow from the left sends it right first. A pine that stands mirrored uses the other picture, mirrored.
		var right := from.x <= float(thing["x"]) * UNIT
		var first := "r" if right != s.flip_h else "l"
		_pose(s, "%s_shake_%s" % [name, first])
		tw.tween_interval(SWAY[0])
		tw.tween_callback(_pose.bind(s, "%s_shake_%s" % [name, "l" if first == "r" else "r"]))
		tw.tween_interval(SWAY[1])
		tw.tween_callback(_unpose.bind(s, name))
		return
	var home := float(thing["x"]) * UNIT
	tw.tween_property(s, "position:x", home + 2.0, 0.04)
	tw.tween_property(s, "position:x", home - 2.0, 0.05)
	tw.tween_property(s, "position:x", home, 0.04)


## The pine comes down off its stump, away from whoever felled it (the Art builder's six pictures: they hold the tree
## above the cut, so the stump is put down at once). Returns [where its crown comes to lie, how long the fall takes].
func _fell(thing: Dictionary, from: Vector2) -> Array:
	var name := str(thing["n"])
	var foot := Vector2(float(thing["x"]), float(thing["y"]))
	var flip := bool(thing.get("f", false))
	var right := float(thing["x"]) * UNIT >= from.x
	var side := "r" if right != flip else "l"
	var times: Array = fx_rules.get("pines", {}).get("fall_ms", [])
	var s: Sprite2D = land.sprite_of(thing)
	var copy: Sprite2D = null
	var tw: Tween = null
	var took := 0.0
	var last := ""
	for k in times.size():
		var frame := "%s_fall_%s%d" % [name, side, k]
		if _fx_texture(frame) == null:
			break
		if copy == null:
			copy = Sprite2D.new()
			copy.centered = false
			copy.scale = Vector2(UNIT, UNIT)
			copy.flip_h = flip
			copy.position = foot * UNIT - Vector2(0, land.SORT_BIAS)
			if s != null:
				copy.modulate = s.modulate
			land.world.add_child(copy)
			tw = copy.create_tween()
			_pose(copy, frame)
		else:
			tw.tween_callback(_pose.bind(copy, frame))
		tw.tween_interval(float(times[k]) / 1000.0)
		took += float(times[k]) / 1000.0
		last = frame
	if copy == null:
		return [_middle({"thing": thing}), 0.0]
	tw.tween_callback(copy.queue_free)
	# The crown lies where the middle of the last picture is.
	var box: Array = fx[last]["box"]
	var f: Array = fx[last].get("foot", [0, 0])
	var mid := Vector2(float(box[2]) * 0.5 - float(f[0]), float(box[3]) * 0.5 - float(f[1]))
	if flip:
		mid.x = -mid.x
	return [(foot + mid) * UNIT, took]


func _process(delta: float) -> void:
	for c in chips:
		c["at"] += c["vel"] * delta
		c["vel"] = c["vel"] * maxf(1.0 - 3.0 * delta, 0.0) + Vector2(0, FALL * delta)
		c["life"] -= delta
	chips = chips.filter(func(c): return c["life"] > 0.0)
	for j in jolts:
		j["t"] += delta
	jolts = jolts.filter(func(j): return j["t"] < JOLT)
	for l in later:
		l["t"] -= delta
		if l["t"] <= 0.0:
			# The pine is down: its crown breaks up where it lies, and its shadow goes from the ground.
			_play("burst_wood", l["at"])
			_burst(l["at"], 6, _cols("wood"))
			Sfx.play(game, "thud", -7.0, 0.8)
			Sfx.play(game, "click", -12.0, 0.45)
			land.changed(l["tile"])
			if int(l["i"]) < players.size():
				players[int(l["i"])].shake = maxf(players[int(l["i"])].shake, 2.0)
	later = later.filter(func(l): return l["t"] > 0.0)
	for f in flies:
		f["t"] += delta
		if f["t"] >= HOP + float(f["wait"]) + FLY and int(f["i"]) < hands.size():
			(hands[int(f["i"])] as Hand).gained[str(f["item"])] = clock      # its count lights as it arrives
			Sfx.play(game, "click", -13.0, 1.5 + 0.12 * float(dice.randi() % 4))
	flies = flies.filter(func(f): return f["t"] < HOP + float(f["wait"]) + FLY)
	queue_redraw()
	over.queue_redraw()
	panel.queue_redraw()


## On the land: the cracks in rock and ore that have taken blows, and four corners round what a swinging tool will
## strike. Both show how far along the work is: the cracks spread with every blow, and the corners grow and would
## meet as it gives way. (When you dig up the screen from right against the rock, your own head hides most of the
## tile and its cracks; the corners stand outside the tile, so nothing ever hides them. A pine and a boulder have no
## cracks, only the corners.)
func _draw() -> void:
	for j in jolts:
		_draw_jolt(j)
	var live := {}
	for i in hands.size():
		var h: Hand = hands[i]
		if h.swing < 0.0 or h.target.is_empty() or h.target.get("fixed", false):
			continue
		live[_wear_key(h.target)] = [h.target, Art.PLAYER_COLORS[i % Art.PLAYER_COLORS.size()] if players.size() > 1 else INK]
	for key in wear:
		var w: Dictionary = wear[key]
		if (w["target"] as Dictionary).has("tile"):
			_draw_crack(w)
		elif not live.has(key):
			_draw_corners(_mark(w["target"]), DIM, float(w["hits"]) / float(maxi(int(w["need"]), 1)), 0.6 * clampf(FORGET - (clock - float(w["at"])), 0.0, 1.0))
	for key in live:
		var share := 0.0
		if wear.has(key):
			share = float(wear[key]["hits"]) / float(maxi(int(wear[key]["need"]), 1))
		_draw_corners(_mark(live[key][0]), live[key][1], share, 0.9)


## Which crack a tile shows after so many blows: the Art builder's list for its stuff, the last one just before it
## gives way. "" before the first blow.
func crack_of(kind: int, hits: int, need: int) -> String:
	var list: Array = fx_rules.get("cracks", {}).get({LandMap.TIN: "tin", LandMap.COPPER: "copper"}.get(kind, "rock"), [])
	if list.is_empty() or hits <= 0 or need <= 0:
		return ""
	return str(list[clampi(hits * (list.size() + 1) / need - 1, 0, list.size() - 1)])


## The crack over a struck tile's 16 by 16 (turned over on every other tile, so that no two side by side match). It
## jolts with the tile, and fades as the tile is left alone and becomes whole again.
func _draw_crack(w: Dictionary) -> void:
	var t: Dictionary = w["target"]
	var tile: Vector2i = t["tile"]
	var tex := _fx_texture(crack_of(int(t["kind"]), int(w["hits"]), int(w["need"])))
	if tex == null:
		return
	var at := Vector2(tile) * TILE
	for j in jolts:
		if j["tile"] == tile:
			at += (j["dir"] as Vector2) * (1.0 if float(j["t"]) < JOLT * 0.5 else -1.0) * UNIT
	var turned := posmod(tile.x + tile.y, 2) == 1
	draw_set_transform(at + Vector2(TILE if turned else 0.0, 0.0), 0.0, Vector2(-UNIT if turned else UNIT, UNIT))
	draw_texture(tex, Vector2.ZERO, Color(1, 1, 1, clampf(FORGET - (clock - float(w["at"])), 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A struck tile jolts: for a moment its picture is drawn again a pixel along the blow, then a pixel back.
func _draw_jolt(j: Dictionary) -> void:
	var tile: Vector2i = j["tile"]
	var cx := floori(float(tile.x) / LandMap.CHUNK)
	var cy := floori(float(tile.y) / LandMap.CHUNK)
	var c = land.chunks.get(LandMap.chunk_key(cx, cy))
	if c == null or c["sprite"] == null or (c["sprite"] as Sprite2D).texture == null:
		return
	var px := LandMap.TILE_PX
	var local := Rect2(float((tile.x - cx * LandMap.CHUNK) * px), float((tile.y - cy * LandMap.CHUNK) * px), float(px), float(px))
	var push: Vector2 = (j["dir"] as Vector2) * (1.0 if float(j["t"]) < JOLT * 0.5 else -1.0)
	draw_texture_rect_region((c["sprite"] as Sprite2D).texture, Rect2((Vector2(tile) * float(px) + push) * UNIT, Vector2(px, px) * UNIT), local)


## The box the corners go round: the tile, or the foot of the thing.
func _mark(t: Dictionary) -> Rect2:
	if t.has("tile"):
		return Rect2(Vector2(t["tile"]) * TILE, Vector2(TILE, TILE))
	if t.has("extra"):
		return t["extra"]["box"]
	var foot := Vector2(float(t["thing"]["x"]), float(t["thing"]["y"])) * UNIT
	return Rect2(foot - Vector2(14.0, 18.0), Vector2(28.0, 24.0))


## Four corners round a box, one art pixel thick. `share` is how far along the work is: at 0 they are short, at 1
## they would meet.
func _draw_corners(r: Rect2, col: Color, share: float, alpha: float) -> void:
	var c := Color(col.r, col.g, col.b, alpha)
	var nx := floorf(lerpf(6.0, r.size.x * 0.5, clampf(share, 0.0, 1.0)) / UNIT) * UNIT
	var ny := floorf(lerpf(6.0, r.size.y * 0.5, clampf(share, 0.0, 1.0)) / UNIT) * UNIT
	for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var at: Vector2 = corner[0]
		var s: Vector2 = corner[1]
		draw_rect(Rect2(minf(at.x, at.x + s.x * nx), minf(at.y, at.y + s.y * UNIT), nx, UNIT), c)
		draw_rect(Rect2(minf(at.x, at.x + s.x * UNIT), minf(at.y, at.y + s.y * ny), UNIT, ny), c)


func _draw_over(ci: Node2D) -> void:
	for c in chips:
		ci.draw_rect(Rect2((c["at"] / UNIT).floor() * UNIT, (c["size"] as Vector2) * UNIT), c["col"])
	for f in flies:
		if int(f["i"]) >= players.size():
			continue
		# Out of the tile with a hop, a moment on the ground, then up in an arc to whoever won it.
		var t: float = f["t"]
		if t < 0.0:
			continue
		var at: Vector2
		if t < HOP:
			var k := t / HOP
			at = (f["from"] as Vector2).lerp(f["spot"], k) + Vector2(0, -12.0 * sin(k * PI))
		elif t < HOP + float(f["wait"]):
			at = f["spot"]
		else:
			var k := clampf((t - HOP - float(f["wait"])) / FLY, 0.0, 1.0)
			var to: Vector2 = players[int(f["i"])].global_position + Vector2(0, -10)
			at = (f["spot"] as Vector2).lerp(to, k * k) + Vector2(0, -30.0 * sin(k * PI))
		var name := "drop_" + str(f["item"])
		_sprite(ci, name, ((at / UNIT).floor() - (_sprite_size(name) * 0.5).floor()) * UNIT, UNIT)


## One picture off the tool sheet, its top left corner at `at`. `px` is the size of one art pixel there.
func _sprite(ci: CanvasItem, name: String, at: Vector2, px: float, tint := Color.WHITE) -> Vector2:
	var box: Array = boxes.get(name, {}).get("box", [])
	if sheet == null or box.size() != 4:
		return ItemArt.draw(ci, name, at, px, tint)      # (the bars' pictures are on the loot art's sheet)
	var size := Vector2(float(box[2]), float(box[3]))
	ci.draw_texture_rect_region(sheet, Rect2(at, size * px), Rect2(box[0], box[1], box[2], box[3]), tint)
	return size


## How big a picture on the tool sheet is, in art pixels.
func _sprite_size(name: String) -> Vector2:
	var box: Array = boxes.get(name, {}).get("box", [])
	return Vector2(float(box[2]), float(box[3])) if box.size() == 4 else ItemArt.size(name)


## The tool in the hand of player i while it swings: drawn on the player's weapon layer (player.gd, tool_draw), in the
## player's own space. The pictures point up and are held at their `pivot`; the swing comes over the shoulder and
## down onto the work. The axe's blade leads, so its picture is turned over when the swing goes the other way.
func _draw_hand(layer: Node2D, i: int) -> void:
	var h: Hand = hands[i]
	var info: Dictionary = boxes.get("hand_" + str(TOOLS[h.tool]), {})
	if h.swing < 0.0 or sheet == null or info.is_empty():
		return
	var side := 1.0 if h.dir.x >= 0.0 else -1.0
	var aim := h.dir.angle()
	var a: float
	if h.swing < STRIKE:
		var t := h.swing / STRIKE
		a = aim + side * lerpf(RAISED, STRUCK_AT, t * t)
	else:
		# It springs back off the work and is carried up again for the next blow, so what it struck is seen at once
		# (its new crack, the pine leaning): a tool that lay on the tile after the blow hid them.
		var t := 1.0 - clampf((h.swing - STRIKE) / (SWING - STRIKE), 0.0, 1.0)
		a = aim + side * lerpf(RAISED, STRUCK_AT, t * t)
	var hand := HAND_PIVOT + Vector2.RIGHT.rotated(a) * HAND_RADIUS
	var box: Array = info["box"]
	var pivot: Array = info["pivot"]
	layer.draw_set_transform(hand, a + PI * 0.5, Vector2(-UNIT if side < 0.0 else UNIT, UNIT))
	layer.draw_texture_rect_region(sheet, Rect2(-float(pivot[0]), -float(pivot[1]), float(box[2]), float(box[3])), Rect2(box[0], box[1], box[2], box[3]))
	# The fist sits on the haft, upright, as it does on a weapon.
	var fist := Art.texture("body/hand.png")
	if fist != null:
		layer.draw_set_transform(hand, 0.0, Vector2(UNIT, UNIT))
		layer.draw_texture(fist, -fist.get_size() * 0.5)
	layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- On the screen: the belt and the materials carried ---------------------------------------

func _head(text: String, pos: Vector2, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	panel.draw_string(Art.font("Silkscreen-Regular"), pos, text.to_upper(), align, width, 8, col)


func _head_width(text: String) -> float:
	return ceilf(Art.font("Silkscreen-Regular").get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)


## Where player i's belt is drawn: above their swing path, at their side of the screen.
func belt_rect(i: int) -> Rect2:
	var w := SLOT * 3.0 + 4.0
	var x := SIZE.x - MARGIN - w if i % 2 == 1 else MARGIN
	return Rect2(x, SIZE.y - 28.0 - 18.0 - SLOT, w, SLOT)


## The buttons, in words: what this player would press.
static func hint(pad: bool) -> String:
	return "LT use   Select next" if pad else "F use   C next"


func _draw_hud() -> void:
	for i in hands.size():
		var p = players[i]
		if not is_instance_valid(p) or p.is_down:
			continue
		var h: Hand = hands[i]
		var right := i % 2 == 1
		var belt := belt_rect(i)
		var name := str(NAMES[TOOLS[h.tool]])
		var words := hint(p.input.on_pad())
		# What is carried, beside the belt: a picture and a number for each material there is some of.
		var held: Array = []
		var bag_w := 0.0
		for item in Bag.ORDER:
			if h.bag.count(item) > 0:
				held.append(item)
				bag_w += 17.0 + _head_width(str(h.bag.count(item))) + 5.0
		var words_w := _head_width(name) + 10.0 + _head_width(words)
		var back := Rect2(belt.position - Vector2(4, 14), Vector2(maxf(belt.size.x + (bag_w + 3.0 if bag_w > 0.0 else 0.0), words_w) + 8.0, belt.size.y + 18.0))
		if right:
			back.position.x = belt.end.x + 4.0 - back.size.x
		panel.draw_rect(back, SHADE)
		# The picked tool's name, and the two buttons.
		var lit := clampf(1.0 - (clock - h.picked_at) / 0.5, 0.0, 1.0)
		var line := belt.position.y - 4.0
		_head(name, Vector2(back.position.x + 4.0, line), INK.lerp(AMBER, lit), back.size.x - 8.0, HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT)
		_head(words, Vector2(back.position.x + 4.0, line), DIM, back.size.x - 8.0, HORIZONTAL_ALIGNMENT_LEFT if right else HORIZONTAL_ALIGNMENT_RIGHT)
		# The belt: three places, the picked one framed in amber and the others dimmed.
		for k in TOOLS.size():
			var r := Rect2(belt.position + Vector2(float(k) * (SLOT + 2.0), 0.0), Vector2(SLOT, SLOT))
			var on: bool = k == h.tool
			panel.draw_rect(r, PLATE)
			panel.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2(1, 1)), AMBER if on else FAINT, false, 1.0)
			if on:
				panel.draw_rect(Rect2(r.position + Vector2(1.5, 1.5), r.size - Vector2(3, 3)), Color(AMBER.r, AMBER.g, AMBER.b, 0.35 + 0.5 * lit), false, 1.0)
			if str(h.belt.get(TOOLS[k], "")) != "":
				_sprite(panel, "belt_" + str(TOOLS[k]), r.position + Vector2(1, 1), 1.0, Color.WHITE if on else Color(0.55, 0.55, 0.6))
		# The count of each material carried, lit for a moment when more comes in.
		var x := belt.end.x + 7.0 if not right else belt.position.x - 4.0 - bag_w
		for item in held:
			var n := str(h.bag.count(item))
			var fresh := clampf(1.0 - (clock - float(h.gained.get(item, -9.0))) / 0.7, 0.0, 1.0)
			_sprite(panel, "item_" + str(item), Vector2(x, belt.position.y + 1.0), 1.0)
			_head(n, Vector2(x + 17.0, belt.position.y + SLOT * 0.5 + 4.0), INK.lerp(AMBER, fresh))
			x += 17.0 + _head_width(n) + 5.0
