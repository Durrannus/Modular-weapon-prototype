extends Node2D
## The basic tools of the Highlands: a pickaxe, an axe and a mallet on a tool belt.
##
## Darren, 22 November 2026: "put in basic tools". How they are used is his too (the Game Bible's "Using tools"):
## a separate WORK button uses the tool you have picked, and a CYCLE button steps through the pickaxe, the axe and
## the mallet ("would rather cycle tools to what u need rather than auto picking it"). The game never picks the
## tool for you. Your weapon stays your weapon: attack and it swings, and its swing path and spirit stay on screen.
## Tools sit on a belt that belongs to the character, they never break, and a better tool replaces the old one.
## What they win goes into the character's materials bag (bag.gd), never into the accessory backpack.
##
##   pickaxe   digs rock (it becomes dug floor and gives stone), mines tin and copper out of it, breaks up boulders
##   axe       fells pines for wood, and leaves the stump
##   mallet    is for building, and there is nothing to build yet
##
## Until there is a workbench to make them at, everyone starts with the basic three (Claude's choice).
##
## Rules for the code: everything that changes the game (which tool is picked, how worn a tile is, what breaks,
## what goes in a bag) is worked out in tick(), once a physics tick, from the players' buttons alone. Chips, dust
## and the pictures flying to you are only looks, and take their dice from `dice`, which nothing else uses.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Bag := preload("res://scripts/highlands/bag.gd")
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
const REACH := 46.0                 # how far from your middle a tool reaches (world units; a tile is 32)
const HAND_PIVOT := Vector2(0, -14) # the swing goes round this point of the body, as the sword's does
const HAND_RADIUS := 9.0
const WALK := 0.35                  # walking speed while a tool swings
const FORGET := 4.0                 # a part-dug tile is whole again after this long without a blow
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


## What one player carries and is doing with it. The belt, the tool that is picked and the bag belong to the
## character (the character save will hold them); the rest is this moment's.
class Hand:
	var tool := 0                                                         # which of TOOLS is picked
	var belt := {"pickaxe": "basic", "axe": "basic", "mallet": "basic"}   # the make of each tool ("" = none)
	var bag := Bag.new()
	var swing := -1.0             # seconds into the swing (-1: no tool is swinging)
	var struck := false           # this swing's blow has landed
	var dir := Vector2.DOWN       # where this swing goes
	var target := {}              # what it will strike, or struck ({}: nothing)
	var picked_at := -9.0         # when the picked tool last changed (the belt lights up)
	var gained := {}              # item -> when some last went into the bag
	var told_at := -9.0           # when a word was last put over their head ("Bag full")


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
var clock := 0.0
var dice := RandomNumberGenerator.new()
var chips: Array = []             # [{at, vel, life, col}] in world units
var flies: Array = []             # [{from, i, t, item}] a pick-up on its way to player i
var over: Over
var layer: CanvasLayer
var panel: Control
var sheet: Texture2D              # the tool pictures (art/tools/tools.png) ...
var boxes := {}                   # ... and where each one is on it: name -> {box: [x, y, w, h], pivot, strike, foot}


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
## {tile, kind, fixed}; a thing is {thing, class}. {} when there is nothing.
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
				best = {"tile": t, "kind": map.kind(t.x, t.y), "fixed": map.fixed(t.x, t.y)}
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
							best = {"thing": t, "class": cls}
							best_d = d
							break
						d += 3.0
	return best


func _wear_key(t: Dictionary) -> int:
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
	if tool == "mallet":
		_tell(p, h, "Nothing to build yet")
		Sfx.play(game, "swing", -14.0, 0.8)
		return
	if t.is_empty():
		Sfx.play(game, "swing", -14.0, 0.9)
		return
	var at := _middle(t)
	if t.get("fixed", false):
		_tell(p, h, "Too hard to dig")
		Sfx.play(game, "click", -8.0, 0.7)
		_chip(at, p.global_position, 2, [Color("c2c8a0")])
		return
	var gives: Array = TILE_GIVES[int(t["kind"])] if t.has("tile") else THING_GIVES[str(t["class"])]
	# Ore and wood are never thrown away: with no room for them the tool stays its blow. Stone is only rubble,
	# and digging must always be possible, so a full bag just leaves it lying.
	if str(gives[0]) != "stone" and h.bag.room(str(gives[0])) < int(gives[1]):
		_tell(p, h, "Bag full")
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
	var cols: Array = [Color("5f8072"), Color("446264"), Color("8ba688")]
	if t.has("tile") and int(t["kind"]) != LandMap.ROCK:
		cols.append(ITEM_COL[str(gives[0])])
		cols.append(ITEM_COL[str(gives[0])])
	elif t.has("thing") and str(t["class"]) == "pine":
		cols = [Color("8f4f38"), Color("b87644"), Color("2a7f70")]
	_chip(at, p.global_position, 4, cols)
	if t.has("thing"):
		_shake(t["thing"])
		Sfx.play(game, "thud" if str(t["class"]) == "pine" else "hit", -9.0, 1.25 if str(t["class"]) == "pine" else 0.8)
	else:
		Sfx.play(game, "hit", -8.0, 0.8)
		Sfx.play(game, "click", -13.0, 0.55)
	if int(w["hits"]) >= need:
		wear.erase(key)
		_break(i, t, gives)


## It gives way: the tile becomes dug floor, the pine a stump, the boulder nothing; what it held goes in the bag.
func _break(i: int, t: Dictionary, gives: Array) -> void:
	var p = players[i]
	var h: Hand = hands[i]
	var at := _middle(t)
	if t.has("tile"):
		var tile: Vector2i = t["tile"]
		if map.dig(tile.x, tile.y) < 0:
			return
		land.changed(tile)
		Sfx.play(game, "thud", -8.0, 0.9)
		_dust(at)
		_chip(at, p.global_position, 6, [Color("5f8072"), Color("446264"), Color("344856")])
	else:
		var thing: Dictionary = t["thing"]
		var foot := Vector2(float(thing["x"]), float(thing["y"]))
		if str(t["class"]) == "pine":
			_fell(thing, p.global_position)
			map.remove_thing(thing)
			map.add_thing({"n": "pine_stump", "x": int(thing["x"]), "y": int(thing["y"]), "f": false})
			Sfx.play(game, "slam", -12.0, 1.3)
		else:
			map.remove_thing(thing)
			Sfx.play(game, "thud", -8.0, 0.8)
			_dust(at)
		land.things_changed(foot)
		land.changed(Vector2i(int(foot.x) / LandMap.TILE_PX, int(foot.y) / LandMap.TILE_PX))   # its shadow is painted into the ground
	var got: int = h.bag.add(str(gives[0]), int(gives[1]))
	if got > 0:
		h.gained[str(gives[0])] = clock
		for n in got:
			flies.append({"from": at + Vector2(dice.randf_range(-8.0, 8.0), dice.randf_range(-8.0, 8.0)), "i": i, "t": -0.07 * float(n), "item": str(gives[0])})
	h.target = {}


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

func _chip(at: Vector2, from: Vector2, n: int, cols: Array) -> void:
	var away := (from - at).normalized()
	for k in n:
		var dir := (away * 0.7 + Vector2(dice.randf_range(-1.0, 1.0), dice.randf_range(-1.0, 0.4))).normalized()
		chips.append({"at": at + away * 10.0 + Vector2(dice.randf_range(-5.0, 5.0), dice.randf_range(-5.0, 5.0)),
			"vel": dir * dice.randf_range(60.0, 150.0), "life": dice.randf_range(0.22, 0.4), "col": cols[dice.randi() % cols.size()]})


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


## The struck thing shivers.
func _shake(thing: Dictionary) -> void:
	var s: Sprite2D = land.sprite_of(thing)
	if s == null:
		return
	var home := float(thing["x"]) * UNIT
	var tw := s.create_tween()
	tw.tween_property(s, "position:x", home + 2.0, 0.04)
	tw.tween_property(s, "position:x", home - 2.0, 0.05)
	tw.tween_property(s, "position:x", home, 0.04)


## The pine comes down: its picture tips over, away from whoever felled it, and is gone.
func _fell(thing: Dictionary, from: Vector2) -> void:
	var s: Sprite2D = land.sprite_of(thing)
	if s == null:
		return
	var copy := Sprite2D.new()
	copy.texture = s.texture
	copy.centered = false
	# It turns about its foot (the land's own picture of it is hung a little above the foot, for sorting).
	copy.offset = s.offset - Vector2(0, land.SORT_BIAS / UNIT)
	copy.scale = s.scale
	copy.position = s.position + Vector2(0, land.SORT_BIAS)
	copy.flip_h = s.flip_h
	land.world.add_child(copy)
	var side := 1.0 if float(thing["x"]) * UNIT >= from.x else -1.0
	var tw := copy.create_tween()
	tw.tween_property(copy, "rotation", side * 1.35, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(copy, "modulate:a", 0.0, 0.2).set_delay(0.4)
	tw.tween_callback(copy.queue_free)


func _process(delta: float) -> void:
	for c in chips:
		c["at"] += c["vel"] * delta
		c["vel"] *= maxf(1.0 - 5.0 * delta, 0.0)
		c["life"] -= delta
	chips = chips.filter(func(c): return c["life"] > 0.0)
	for f in flies:
		f["t"] += delta / 0.38
		if f["t"] >= 1.0 and f["i"] < players.size():
			Sfx.play(game, "click", -15.0, 1.6)
	flies = flies.filter(func(f): return f["t"] < 1.0)
	queue_redraw()
	over.queue_redraw()
	panel.queue_redraw()


## On the land: four corners round what a swinging tool will strike, and round what has taken blows. The corners
## grow with every blow, and would meet as it gives way: that is how you see how far along it is. (They stand
## outside the tile, so the tool in your hand never hides them.)
func _draw() -> void:
	var live := {}
	for i in hands.size():
		var h: Hand = hands[i]
		if h.swing < 0.0 or h.target.is_empty() or h.target.get("fixed", false):
			continue
		live[_wear_key(h.target)] = [h.target, Art.PLAYER_COLORS[i % Art.PLAYER_COLORS.size()] if players.size() > 1 else INK]
	for key in wear:
		if live.has(key):
			continue
		var w: Dictionary = wear[key]
		var left := FORGET - (clock - float(w["at"]))
		_draw_corners(_mark(w["target"]), DIM, float(w["hits"]) / float(maxi(int(w["need"]), 1)), 0.6 * clampf(left, 0.0, 1.0))
	for key in live:
		var share := 0.0
		if wear.has(key):
			share = float(wear[key]["hits"]) / float(maxi(int(wear[key]["need"]), 1))
		_draw_corners(_mark(live[key][0]), live[key][1], share, 0.9)


## The box the corners go round: the tile, or the foot of the thing.
func _mark(t: Dictionary) -> Rect2:
	if t.has("tile"):
		return Rect2(Vector2(t["tile"]) * TILE, Vector2(TILE, TILE))
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
		ci.draw_rect(Rect2((c["at"] / UNIT).floor() * UNIT, Vector2(UNIT, UNIT)), c["col"])
	for f in flies:
		if f["t"] < 0.0 or int(f["i"]) >= players.size():
			continue
		var to: Vector2 = players[int(f["i"])].global_position + Vector2(0, -16)
		var t: float = f["t"]
		var at: Vector2 = (f["from"] as Vector2).lerp(to, t * t) + Vector2(0, -26.0 * sin(t * PI))
		var name := "drop_" + str(f["item"])
		_sprite(ci, name, ((at / UNIT).floor() - (_sprite_size(name) * 0.5).floor()) * UNIT, UNIT)


## One picture off the tool sheet, its top left corner at `at`. `px` is the size of one art pixel there.
func _sprite(ci: CanvasItem, name: String, at: Vector2, px: float, tint := Color.WHITE) -> Vector2:
	var box: Array = boxes.get(name, {}).get("box", [])
	if sheet == null or box.size() != 4:
		return Vector2.ZERO
	var size := Vector2(float(box[2]), float(box[3]))
	ci.draw_texture_rect_region(sheet, Rect2(at, size * px), Rect2(box[0], box[1], box[2], box[3]), tint)
	return size


## How big a picture on the tool sheet is, in art pixels.
func _sprite_size(name: String) -> Vector2:
	var box: Array = boxes.get(name, {}).get("box", [])
	return Vector2(float(box[2]), float(box[3])) if box.size() == 4 else Vector2.ZERO


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
		a = aim + side * lerpf(-1.9, 0.3, t * t)
	else:
		var t := clampf((h.swing - STRIKE) / (SWING - STRIKE), 0.0, 1.0)
		a = aim + side * lerpf(0.3, -0.25, t * t)
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


# --- On the screen: the belt and the bag ---------------------------------------------------

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
		# The bag's count of each material, lit for a moment when more comes in.
		var x := belt.end.x + 7.0 if not right else belt.position.x - 4.0 - bag_w
		for item in held:
			var n := str(h.bag.count(item))
			var fresh := clampf(1.0 - (clock - float(h.gained.get(item, -9.0))) / 0.7, 0.0, 1.0)
			_sprite(panel, "item_" + str(item), Vector2(x, belt.position.y + 1.0), 1.0)
			_head(n, Vector2(x + 17.0, belt.position.y + SLOT * 0.5 + 4.0), INK.lerp(AMBER, fresh))
			x += 17.0 + _head_width(n) + 5.0
