extends Node
## The Accessory Satchel, and what the accessories worn in it do (version 47).
##
## Darren, 23 November 2026: "I want to be able to put accessories in normal inventory with everything else but have
## an accessories equip satchel and when they are put there they are in use. This is where the rows and size
## matters etc. also want to add craftable backpacks so players can carry more later on".
##
## From the Game Bible ("Inventory, accessories and backpacks"):
##   - The satchel "is where accessories are worn: only the accessories inside it are in use. It is a shape grid,
##     and accessories come in different shapes and sizes, so fitting them in is a puzzle, like Backpack Battles."
##     "It starts at 3x3 and grows with better crafted satchels, up to about 5x5."
##   - "Moving an accessory between the inventory and the satchel works anywhere, and its effect starts the moment
##     it is in the satchel." "For now there are no neighbour bonuses; it's just about fitting accessories in."
##   - "The inventory, the satchel, the backpack and what is in them belong to the character save."
##   - The Delver's perk Deep Pockets: "Your Accessory Satchel has one extra row."
##
## Claude's choices, until Darren says otherwise (they are listed in the README and the Game Bible):
##   - A piece can be turned by quarter turns (the Overseer's plan asks for it, "like Backpack Battles").
##   - TWO OF THE SAME ACCESSORY DO NO MORE THAN ONE (the Bible says so of the Banner Pin; here it holds for all).
##   - The satchels: 3 by 3, the Hide Satchel 3 wide and 4 tall, then 4 by 4, then 5 by 5. Until they can be made
##     (Pip sews the first from hides, and there are no hides yet) the lab says which one everybody wears.
##   - If the satchel becomes smaller (the lab, or Deep Pockets forgotten), what no longer fits goes back into the
##     inventory, and is never lost.
##   - "Near you" for the Banner Pin is about six tiles. "Up close" for the Thorn Charm is about two and a half.
##   - The Wayfinder's Compass points at the nearest open place nobody has walked into yet. The places only a
##     pickaxe finds are left for the pickaxe. Where the squad has been is saved with the world.
##
## THE RULES AND THE LOOKS ARE KEPT APART, as everywhere: what changes the game happens on the tick or at the
## moment a piece is moved (wear(), shift(), stow(), tick(), and the answers player.gd, loot.gd, tools.gd and
## levels.gd ask for); the compass's arrow is a look. The one thing here that is decided by chance (the Sieve's
## extra ore) asks the game's shared dice.

const Accessories := preload("res://scripts/highlands/accessories.gd")
const Bag := preload("res://scripts/highlands/bag.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Sim := preload("res://scripts/sim.gd")

const UNIT := Art.PIXEL
const TILE := 16.0 * UNIT
const SIZE := Vector2(640, 360)
const LOOK := 0.5                  # where the squad has been, and where the compass points, are looked up this often
const NUDGE := 8.0                 # how long the screen says which button opens the inventory, after an accessory comes
const AMBER := Color("#ffc850")
const SHADE := Color(0.098, 0.078, 0.165, 0.5)
const INK := Color("#e8e4bc")
const DARK := Color("#19142a")

## The satchels, least first: what each is called, and how many columns and rows it has.
const SATCHELS := [
	{"name": "Satchel", "size": [3, 3]},
	{"name": "Hide Satchel", "size": [3, 4]},
	{"name": "Leather Satchel", "size": [4, 4]},
	{"name": "Large Satchel", "size": [5, 5]},
]

## Until satchels can be made, the lab says which one everybody wears: the larger of this and the character's own.
static var LAB_SATCHEL := 0
## The lab, for trying them: 1 puts one of every accessory in everybody's inventory (whoever has not got it).
static var LAB_GIVE := 0


## What one character wears. It is in the character's save.
class Kit:
	var satchel := 0               # the satchel this character owns (which of SATCHELS)
	var worn: Array = []           # [{id, x, y, rot}]: the pieces in it, each with its top left cell and its turn
	var calm := 0.0                # seconds since they last took or dealt damage (the Hearthstone Pebble)
	var points := Vector2.INF      # where their compass points (world units; INF: nowhere)
	var nudged := -99.0            # when something new last came for the satchel (the screen says which button opens it)


var game                           # the Highlands scene
var map: LandMap
var players: Array = []
var tools                          # tools.gd: the inventories
var levels                         # levels.gd: the perks (Deep Pockets)
var kits: Array = []               # a Kit per player
var visited := {}                  # place number -> true: somebody has walked into it (the world's)
var clock := 0.0
var _look := 0.0
var layer: CanvasLayer
var panel: Control


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	panel = Control.new()
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	panel.draw.connect(_draw_hud)
	for i in players.size():
		kits.append(Kit.new())
		if is_instance_valid(players[i]):
			players[i].gear = self


func _exit_tree() -> void:
	for p in players:
		if is_instance_valid(p) and p.gear == self:
			p.gear = null
			p.max_hp = p.MAX_HP
			p.hp = minf(p.hp, p.max_hp)


func bag_of(i: int) -> Bag:
	return tools.bag_of(i)


# --- The satchel ----------------------------------------------------------------------------

## Which satchel player i wears: their own, or the lab's if that is larger.
func satchel_now(i: int) -> int:
	return clampi(maxi(int((kits[i] as Kit).satchel), int(LAB_SATCHEL)), 0, SATCHELS.size() - 1)


## How many columns and rows player i's satchel has.
func size_of(i: int) -> Vector2i:
	var s: Array = SATCHELS[satchel_now(i)]["size"]
	var rows := int(s[1])
	if levels != null and levels.has(i, "deep_pockets"):
		rows += 1
	return Vector2i(int(s[0]), rows)


## The cells that are taken: Vector2i -> which piece. `skip` leaves one piece out (the one being moved).
func taken(i: int, skip := -1) -> Dictionary:
	var out := {}
	var worn: Array = (kits[i] as Kit).worn
	for k in worn.size():
		if k == skip:
			continue
		var w: Dictionary = worn[k]
		for c in Accessories.cells(str(w["id"]), int(w["rot"])):
			out[Vector2i(int(w["x"]), int(w["y"])) + c] = k
	return out


## Would this piece fit with its top left cell there, turned so?
func fits(i: int, id: String, x: int, y: int, rot: int, skip := -1) -> bool:
	if not Accessories.has(id):
		return false
	var size := size_of(i)
	var full := taken(i, skip)
	for c in Accessories.cells(id, rot):
		var at: Vector2i = Vector2i(x, y) + c
		if at.x < 0 or at.y < 0 or at.x >= size.x or at.y >= size.y or full.has(at):
			return false
	return true


## The piece that takes this cell, or -1.
func piece_at(i: int, cell: Vector2i) -> int:
	return int(taken(i).get(cell, -1))


## The first place it fits, row by row, as it lies and then turned: [x, y, rot], or [] if there is none.
func first_fit(i: int, id: String, skip := -1) -> Array:
	var size := size_of(i)
	for rot in (4 if Accessories.turns(id) else 1):
		for y in size.y:
			for x in size.x:
				if fits(i, id, x, y, rot, skip):
					return [x, y, rot]
	return []


## Out of the inventory and into the satchel, there. It works from that moment. False, and nothing moves, if the
## inventory has none or it does not fit.
func wear(i: int, id: String, x: int, y: int, rot: int) -> bool:
	if bag_of(i).count(id) < 1 or not fits(i, id, x, y, rot):
		return false
	bag_of(i).take(id, 1)
	(kits[i] as Kit).worn.append({"id": id, "x": x, "y": y, "rot": posmod(rot, 4) if Accessories.turns(id) else 0})
	refresh(i)
	return true


## A piece in the satchel is moved or turned. False, and it stays, if it does not fit there.
func shift(i: int, k: int, x: int, y: int, rot: int) -> bool:
	var worn: Array = (kits[i] as Kit).worn
	if k < 0 or k >= worn.size() or not fits(i, str(worn[k]["id"]), x, y, rot, k):
		return false
	worn[k]["x"] = x
	worn[k]["y"] = y
	worn[k]["rot"] = posmod(rot, 4) if Accessories.turns(str(worn[k]["id"])) else 0
	return true


## A piece comes out of the satchel and back into the inventory. It stops working at once. False, and it stays, if
## the inventory has no slot for it.
func stow(i: int, k: int) -> bool:
	var worn: Array = (kits[i] as Kit).worn
	if k < 0 or k >= worn.size() or bag_of(i).room(str(worn[k]["id"])) < 1:
		return false
	bag_of(i).add(str(worn[k]["id"]), 1)
	worn.remove_at(k)
	refresh(i)
	return true


## Is player i wearing one of these?
func has(i: int, id: String) -> bool:
	if i < 0 or i >= kits.size():
		return false
	for w in (kits[i] as Kit).worn:
		if w["id"] == id:
			return true
	return false


## The satchel may have become smaller, or a save may hold what cannot be: every piece that does not fit where it
## is goes back into the inventory. Nothing is lost.
func settle(i: int) -> void:
	var kit: Kit = kits[i]
	var all: Array = kit.worn
	kit.worn = []
	var out: Array = []
	for w in all:
		if Accessories.has(w["id"]) and fits(i, str(w["id"]), int(w["x"]), int(w["y"]), int(w["rot"])):
			kit.worn.append(w)
		else:
			out.append(w)
	for w in out:
		if Accessories.has(w["id"]):
			bag_of(i).put_back(str(w["id"]))


## What is worn has changed: the body takes it up at once (Field Rations' health, kept at the same share).
func refresh(i: int) -> void:
	if i < 0 or i >= players.size() or not is_instance_valid(players[i]):
		return
	var p = players[i]
	var want: float = float(p.MAX_HP) * (float(Accessories.RATIONS_HEALTH) if has(i, "field_rations") else 1.0)
	if not is_equal_approx(p.max_hp, want) and p.max_hp > 0.0:
		var share: float = p.hp / p.max_hp
		p.max_hp = want
		p.hp = want * share


# --- What the accessories do: asked by the player, the loot, the tools and the levels --------

func _who(p) -> int:
	return players.find(p)


## Tinker's Thimble: how fast the dodge comes back, as a share of the usual.
func dodge_speed(p) -> float:
	return float(Accessories.THIMBLE_DODGE) if has(_who(p), "tinkers_thimble") else 1.0


## Bandolier: how fast active runes come back.
func rune_speed(p) -> float:
	return float(Accessories.BANDOLIER_RUNES) if has(_who(p), "bandolier") else 1.0


## Banner Pin: what a hit on player p comes to. The wearer and teammates near them take a little less; two pins do
## no more than one.
func softened(p, amount: float) -> float:
	for k in players.size():
		var q = players[k]
		if not is_instance_valid(q) or q.is_down or not has(k, "banner_pin"):
			continue
		if q == p or q.global_position.distance_to(p.global_position) <= float(Accessories.PIN_REACH):
			return amount * (1.0 - clampf(float(Accessories.PIN_SOFTEN), 0.0, 1.0))
	return amount


## Iron Bracer: how far a hit throws player p, as a share of the usual.
func knock(p) -> float:
	return float(Accessories.BRACER_KNOCK) if has(_who(p), "iron_bracer") else 1.0


## Player p has been hurt, by this enemy where that is known. The Hearthstone Pebble goes cold; the Thorn Charm
## answers an enemy that stands close.
func struck(p, by) -> void:
	var i := _who(p)
	if i < 0:
		return
	(kits[i] as Kit).calm = 0.0
	if not has(i, "thorn_charm") or by == null or not is_instance_valid(by) or not by.has_method("take_hit") or bool(by.get("dead")):
		return
	var gap: Vector2 = by.global_position - p.global_position
	if gap.length() > float(Accessories.THORN_REACH):
		return
	by.take_hit(float(Accessories.THORN_DAMAGE), gap.normalized() if gap.length() > 0.5 else Vector2.RIGHT, 40.0, false, INK)


## Player p's own hit has landed on something: the Hearthstone Pebble goes cold.
func dealt(p) -> void:
	var i := _who(p)
	if i >= 0:
		(kits[i] as Kit).calm = 0.0


## Ashen Locket: the share of their carried Memory that player i leaves where they fall.
func fall_share(i: int, share: float) -> float:
	return minf(share, float(Accessories.LOCKET_SHARE)) if has(i, "ashen_locket") else share


## Lucky Copper: the coins player i gets from a chest or an elite.
func coins(i: int, n: int) -> int:
	return roundi(float(n) * float(Accessories.LUCKY_COINS)) if has(i, "lucky_copper") and n > 0 else n


## Prospector's Sieve: how many more of it player i gets from one ore mined (the game's shared dice decide).
func extra_ore(i: int, item: String) -> int:
	if not item.ends_with("_ore") or not has(i, "prospectors_sieve"):
		return 0
	return 1 if Sim.chance() < float(Accessories.SIEVE_CHANCE) else 0


## An accessory has come to player i: for a few seconds the screen says which button opens the inventory.
func nudge(i: int) -> void:
	if i >= 0 and i < kits.size():
		(kits[i] as Kit).nudged = clock


## The button that opens the inventory, in words, for a player on that device.
static func key_words(pad: bool) -> String:
	return "Click the left stick" if pad else "Tab"


# --- Once a tick ----------------------------------------------------------------------------

func tick(delta: float) -> void:
	clock += delta
	for i in kits.size():
		var p = players[i]
		if not is_instance_valid(p):
			continue
		var kit: Kit = kits[i]
		settle(i)
		refresh(i)
		kit.calm += delta
		# Hearthstone Pebble: out of the fight for a while, you slowly heal.
		if has(i, "hearthstone_pebble") and not p.is_down and kit.calm >= float(Accessories.PEBBLE_WAIT) and p.hp < p.max_hp:
			p.hp = minf(p.hp + p.max_hp * float(Accessories.PEBBLE_HEAL) * delta, p.max_hp)
	_look -= delta
	if _look <= 0.0:
		_look = LOOK
		_explore()
		if int(LAB_GIVE) >= 1:
			give_all()


## The lab's switch: everybody has one of every accessory (whoever has it already is passed over).
func give_all() -> void:
	for i in kits.size():
		for id in Accessories.ORDER:
			if not has(i, id) and bag_of(i).count(id) == 0:
				bag_of(i).add(id, 1)


## Where the squad has been, and where each compass points.
func _explore() -> void:
	if map == null:
		return
	for k in map.pockets.size():
		if visited.has(k):
			continue
		var pk: Dictionary = map.pockets[k]
		var mid: Vector2 = (pk["at"] as Vector2) * TILE
		var near := (maxf(float(pk["rx"]), float(pk["ry"])) + 1.0) * TILE
		for p in players:
			if is_instance_valid(p) and not p.is_down and p.global_position.distance_to(mid) <= near:
				visited[k] = true
				break
	for i in kits.size():
		(kits[i] as Kit).points = unexplored_from(players[i].global_position) if has(i, "wayfinders_compass") and is_instance_valid(players[i]) else Vector2.INF


## The middle of the nearest open place nobody has walked into yet (world units), or INF if there is none. The
## places sealed in the rock are not counted: they are for the pickaxe to find.
func unexplored_from(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for k in map.pockets.size():
		var pk: Dictionary = map.pockets[k]
		if visited.has(k) or bool(pk.get("sealed", false)):
			continue
		var mid: Vector2 = (pk["at"] as Vector2) * TILE
		var d := from.distance_to(mid)
		if d < best_d:
			best_d = d
			best = mid
	return best


# --- What is saved ----------------------------------------------------------------------------

## Player i's satchel and what is worn in it, as plain values for the character save.
func kit_data(i: int) -> Dictionary:
	var kit: Kit = kits[i]
	var worn: Array = []
	for w in kit.worn:
		worn.append([str(w["id"]), int(w["x"]), int(w["y"]), int(w["rot"])])
	return {"satchel": kit.satchel, "worn": worn}


## And back. Whatever is missing stays as it was; an accessory this game does not know is left out; a piece that
## does not fit where the save says goes into the inventory.
func set_kit_data(i: int, d: Dictionary) -> void:
	var kit: Kit = kits[i]
	if d.get("satchel") is int or d.get("satchel") is float:
		kit.satchel = clampi(int(d["satchel"]), 0, SATCHELS.size() - 1)
	if d.get("worn") is Array:
		kit.worn = []
		for v in d["worn"]:
			if v is Array and v.size() == 4 and Accessories.has(v[0]) and (v[1] is int or v[1] is float) and (v[2] is int or v[2] is float) and (v[3] is int or v[3] is float):
				kit.worn.append({"id": str(v[0]), "x": int(v[1]), "y": int(v[2]), "rot": posmod(int(v[3]), 4) if Accessories.turns(str(v[0])) else 0})
	settle(i)
	refresh(i)
	# A character comes into a world whole: more health from what it wears is health it has.
	if is_instance_valid(players[i]) and not players[i].is_down:
		players[i].hp = players[i].max_hp


## Where the squad has been, for the world save: the places' numbers, in order.
func world_data() -> Dictionary:
	var ids: Array = visited.keys()
	ids.sort()
	return {"visited": ids}


func set_world_data(d: Dictionary) -> void:
	if d.get("visited") is Array:
		visited = {}
		for v in d["visited"]:
			if (v is int or v is float) and int(v) >= 0 and int(v) < map.pockets.size():
				visited[int(v)] = true


# --- Looks only: the compass's arrow ------------------------------------------------------------

func _process(_delta: float) -> void:
	panel.visible = not get_tree().paused
	if panel.visible:
		panel.queue_redraw()


## Where on the screen a compass's arrow is and which way it points: [place (screen dots), direction], or [] when
## the place it points to is in sight (then nothing is drawn: you can see where to go).
func arrow_for(i: int) -> Array:
	var kit: Kit = kits[i]
	if kit.points == Vector2.INF or game == null or not ("rig" in game) or game.rig == null or not is_instance_valid(players[i]) or players[i].is_down:
		return []
	var mid: Vector2 = game.rig.camera.get_screen_center_position()
	var to: Vector2 = (kit.points - mid) / UNIT + SIZE * 0.5
	var box := Rect2(26, 46, SIZE.x - 52, SIZE.y - 46 - 76)        # clear of the health bars above and the belts below
	if box.has_point(to):
		return []
	var from: Vector2 = ((players[i].global_position - mid) / UNIT + SIZE * 0.5).clamp(box.position, box.end)
	var dir := (to - from).normalized()
	# Along that line from the player, out to the edge of the box.
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
	return [(from + dir * far).round(), dir]


## A small arrow at the edge of the screen for everyone who wears the compass. A stand-in drawn here until the Art
## builder draws one: the pale ink of the screen's words on a dark edge, in the wearer's colour with two players.
func _draw_hud() -> void:
	var f := Art.font("Silkscreen-Regular")
	for i in kits.size():
		# Something new for the satchel: which button opens the inventory, above that player's tool belt.
		var since := clock - float((kits[i] as Kit).nudged)
		if since < NUDGE and tools != null and is_instance_valid(players[i]):
			var words := ("%s: inventory" % key_words(players[i].input.on_pad())).to_upper()
			var w := ceilf(f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
			var belt: Rect2 = tools.belt_rect(i)
			var x := belt.end.x + 4.0 - w - 8.0 if i % 2 == 1 else belt.position.x - 4.0
			var a := clampf((NUDGE - since) / 0.4, 0.0, 1.0)
			panel.draw_rect(Rect2(x, belt.position.y - 30.0, w + 8.0, 13.0), Color(SHADE.r, SHADE.g, SHADE.b, SHADE.a * a))
			panel.draw_string(f, Vector2(x + 4.0, belt.position.y - 20.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(AMBER.r, AMBER.g, AMBER.b, a * (0.75 + 0.25 * sin(clock * 5.0))))
	for i in kits.size():
		var a := arrow_for(i)
		if a.is_empty():
			continue
		var at: Vector2 = a[0]
		var dir: Vector2 = a[1]
		var side := dir.rotated(PI * 0.5)
		var col: Color = Art.PLAYER_COLORS[i % Art.PLAYER_COLORS.size()] if players.size() > 1 else INK
		var nudge := dir * (1.0 if fmod(clock, 1.0) < 0.5 else 0.0)
		var tip: Vector2 = at + nudge
		panel.draw_colored_polygon(PackedVector2Array([tip + dir * 2.0, tip - dir * 9.0 + side * 7.0, tip - dir * 6.0, tip - dir * 9.0 - side * 7.0]), DARK)
		panel.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 7.0 + side * 4.5, tip - dir * 5.0, tip - dir * 7.0 - side * 4.5]), col)
