extends RefCounted
## Where Rattlecrown's Throne Room, the way to it and the Scrapyard gate are on a Highlands map (version 48).
##
## The Game Bible puts Rattlecrown in the Throne Room of his Scrapyard, "a walled dungeon on the surface" that is
## "sealed until the horn is blown at its gate". The Scrapyard belongs to the outer ring, and the land is only laid
## out as far as the inner ring so far. Until the outer ring is built this is the stand-in (Claude's choice):
##
##   - The inner ring is a circle inside a square of land, so the square's corners are solid rock that nothing uses.
##     The THRONE ROOM is cut into one of the two top corners: a hall of dug floor with the throne against its top
##     wall and its door in the bottom wall, so that the throne is seen from the front as it is drawn. Darren, 23
##     November, of the first hall (26 by 16 tiles): "room needs to be bigger with spike traps". So it is 38 by 26,
##     more than a screen each way, and patches of spike traps lie in its floor to either side of the middle, with
##     a row of them just inside the door (how they work is crown.gd's).
##   - A WAY IN three tiles wide runs down from the door and then across to the nearest ground somebody can walk
##     to from the cave. It never opens a sealed place and never crosses water.
##   - The GATE stands in the door itself (as in the Art builder's still of the bigger hall), so that it can shut
##     behind whoever is inside: Darren, 23 November, "quite like the idea of goblins watching on the fight and the
##     gate closing behind". The rock round the room and round the gate's end of the way can never be dug
##     (LandMap.keeps), so the gate is the only way in.
##   - HIS HOARD (Darren, the same message: "Make the chest golden and the gate better as it's special loot"): an
##     alcove in the back wall, to the right of the throne, with a chest in it behind bars of its own. What opens
##     the bars and what the chest gives is crown.gd's.
##   - SCRAP PILES stand round the arena, against its walls (Darren, 23 November, of the still of the arena:
##     "also put scrap piles around the arena"). They are solid, and they keep clear of the door, the traps, the
##     hoard's mouth and where the elites come in. Which wall, where and how many is Claude's choice (HEAPS).
##
## The same map always gives the same plan. The plan is made from the land AS IT WAS MADE, and `stamp` then cuts
## the room and the way into that land every time the world is opened, before a save's digging is done to it
## again. The land's maker is not touched (WorldGen.GEN stays as it is), and what `stamp` cuts is never written
## into a world save.
##
## The plan: {ok, side (-1 the top left corner, 1 the top right), room: Rect2i (tiles), door: Vector2i (the middle
## tile of the first row of the way), hall: [Vector2i] (every tile of the way), gate: Vector2i (its middle tile),
## gate_foot: Vector2 (art pixels: the middle of the gate's bottom edge), throne: Vector2 (art pixels: the middle of
## the front edge of the throne's step), throne_solid, blow: Vector2 (art pixels: where the horn is blown in the
## room), spots: [Vector2i] (where the three elites come in: the brute, the hound, the slinger), dress: [[name,
## foot, solid, mirrored]] (the braziers and the scrap piles), traps: [Vector2i] (the tiles with a spike trap), trap_row: Vector2i (the
## middle tile of the row of them inside the door), alcove: Rect2i (the hoard's, tiles), hoard: Vector2 (art pixels:
## the chest's foot), bars: Vector2 (art pixels: the middle of the foot of the hoard's bars), lamps: [Vector2i],
## keeps: [Rect2i], meet: Vector2i (where the way meets open ground)}. `ok` is false on a land with no place for
## it (none has been met).

const LandMap := preload("res://scripts/highlands/land_map.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const Art := preload("res://scripts/art.gd")

const ROOM := Vector2i(38, 26)     # the hall, in tiles: wide and deep (the screen is 40 by 22 and a half)
const HALL := 3                    # the way in is this many tiles wide
const EDGE := 8                    # the hall keeps this far from the edge of the land that is laid out
const WALL := 4                    # this much rock round the hall and the gate's end of the way can never be dug
const GATE_OUT := 0                # the gate stands this many tiles below the door's first row (0: in the door itself)
const TRAPS := [Rect2i(5, 12, 4, 3), Rect2i(29, 12, 4, 3), Rect2i(9, 19, 4, 3), Rect2i(25, 19, 4, 3)]   # the patches of spike traps, in tiles from the hall's corner: clear of the middle, the same on both sides
const TRAP_ROW := 5                # and a row of them inside the door, this many tiles above the hall's bottom wall
const TRAP_ROW_WIDE := 7           # (so many tiles wide)
const ALCOVE := Vector2i(3, 2)     # the hoard's alcove in the back wall: wide and deep (tiles)
const ALCOVE_OUT := 11             # its middle is this many tiles to the right of the throne's
const HOARD_LIGHT := 30            # the chest's own pool of light (art pixels)
const MOST := 60                   # how many meeting places are tried for each corner before it is given up
const LAMP_EVERY := 9              # a lantern stands by the way every so many tiles, as in the land's old tunnels
const BRAZIER_LIGHT := 58          # a brazier lights the floor this far round it (art pixels)
## The scrap piles round the arena: [which wall (0 the back, 1 the right, 2 the front, 3 the left), how far along it
## (art pixels from the hall's top left corner), a large one, mirrored]. Not the same on both sides, so that it
## does not look laid out with a ruler.
const HEAPS := [
	[0, 120, true, false], [0, 188, false, true], [0, 424, true, true], [0, 540, false, false],
	[1, 120, false, true], [1, 232, true, false], [1, 330, false, false],
	[2, 112, true, true], [2, 200, false, false], [2, 408, false, true], [2, 480, true, false],
	[3, 144, true, false], [3, 248, false, true], [3, 336, true, true],
]
const BLOW_DOWN := 5               # the horn is blown this many tiles in front of the throne


static func make(map: LandMap) -> Dictionary:
	var seen := map.reach(Vector2i(floori(map.spawn.x), floori(map.spawn.y)))
	var best := {}
	var best_len := 1 << 30
	for side in [-1, 1]:
		var p := _try(map, seen, side)
		if not p.is_empty() and (p["hall"] as Array).size() < best_len:
			best = p
			best_len = (p["hall"] as Array).size()
	if best.is_empty():
		return {"ok": false}
	best["ok"] = true
	return best


## The hall in one top corner and the shortest way from it that passes the rules, or {} if there is none.
static func _try(map: LandMap, seen: PackedByteArray, side: int) -> Dictionary:
	var mid := LandMap.MID
	var far := WorldGen.REACH - EDGE
	var x0 := mid + far - ROOM.x if side > 0 else mid - far
	var y0 := mid - far
	var room := Rect2i(x0, y0, ROOM.x, ROOM.y)
	var door := Vector2i(x0 + ROOM.x / 2, room.end.y)
	# Every tile somebody can walk to that lies low enough for the gate to stand above it, nearest first.
	var low := door.y + GATE_OUT + 4
	var found: Array = []
	for y in range(low, mini(door.y + 110, map.region.end.y - 4)):
		for x in range(maxi(door.x - 110, map.region.position.x + 4), mini(door.x + 110, map.region.end.x - 4)):
			if map.reached(seen, x, y):
				found.append(Vector2i(x, y))
	found.sort_custom(func(a, b):
		var da: int = absi(a.x - door.x) + absi(a.y - door.y)
		var db: int = absi(b.x - door.x) + absi(b.y - door.y)
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	for k in mini(found.size(), MOST):
		var meet: Vector2i = found[k]
		var hall := _way(door, meet)
		if _passes(map, hall):
			return _plan(side, room, door, hall, meet)
	return {}


## The tiles of the way: straight down from the door to the meeting place's row, then across to it, three wide.
static func _way(door: Vector2i, meet: Vector2i) -> Array:
	var tiles := {}
	var half := HALL / 2
	for y in range(door.y, meet.y + half + 1):
		for dx in range(-half, half + 1):
			tiles[Vector2i(door.x + dx, y)] = true
	var step := 1 if meet.x >= door.x else -1
	var x := door.x
	while x != meet.x + step:
		for dy in range(-half, half + 1):
			tiles[Vector2i(x, meet.y + dy)] = true
		x += step
	var out: Array = tiles.keys()
	out.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else a.x < b.x)
	return out


## The way may not cross water, and may not come within three tiles of a place that is sealed in the rock.
static func _passes(map: LandMap, hall: Array) -> bool:
	for t in hall:
		if map.kind(t.x, t.y) == LandMap.WATER or not map.region.has_point(t):
			return false
		for p in map.pockets:
			if not bool(p.get("sealed", false)):
				continue
			var at: Vector2 = p["at"]
			var rx := float(p["rx"]) + 3.0
			var ry := float(p["ry"]) + 3.0
			var d := Vector2((float(t.x) + 0.5 - at.x) / rx, (float(t.y) + 0.5 - at.y) / ry)
			if d.length_squared() <= 1.0:
				return false
	return true


static func _plan(side: int, room: Rect2i, door: Vector2i, hall: Array, meet: Vector2i) -> Dictionary:
	var gate := Vector2i(door.x, door.y + GATE_OUT)
	var lamps: Array = []
	for at in [Vector2i(room.position.x + 2, room.position.y + 2), Vector2i(room.end.x - 3, room.position.y + 2),
			Vector2i(room.position.x + 2, room.end.y - 3), Vector2i(room.end.x - 3, room.end.y - 3),
			Vector2i(door.x - 1, gate.y + 2), Vector2i(door.x + 1, gate.y + 2)]:
		lamps.append(at)
	# Lanterns down the way and along it, on one side and then the other.
	var n := 0
	var y := gate.y + 2 + LAMP_EVERY
	while y < meet.y - 3:
		lamps.append(Vector2i(door.x + (1 if n % 2 == 0 else -1), y))
		y += LAMP_EVERY
		n += 1
	var step := 1 if meet.x >= door.x else -1
	var x := door.x + step * LAMP_EVERY
	while absi(meet.x - x) > 3 and signi(meet.x - x) == step:
		lamps.append(Vector2i(x, meet.y - 1))
		x += step * LAMP_EVERY
	var keeps: Array = [room.grow(WALL), Rect2i(door.x - HALL / 2 - WALL, door.y, HALL + WALL * 2, GATE_OUT + 3)]
	var down := throne_down()
	var throne := Vector2((room.position.x + ROOM.x / 2) * 16, (room.position.y + down) * 16)
	# What stands in the room: four standing braziers, two beside the throne and two lower down, and nothing else
	# (the floor stays clear): [name, where its foot is (art pixels), how wide and how deep it is solid, mirrored].
	var corner := Vector2(room.position) * 16.0
	var out := throne_size().x * 0.5 + 12.0
	var dress: Array = [
		["brazier", throne + Vector2(-out, -2), Vector2(10, 4), false],
		["brazier", throne + Vector2(out, -2), Vector2(10, 4), true],
		["brazier", corner + Vector2((ROOM.x / 2 - 7) * 16, 17 * 16 + 8), Vector2(10, 4), false],
		["brazier", corner + Vector2((ROOM.x / 2 + 7) * 16, 17 * 16 + 8), Vector2(10, 4), true],
	]
	# The scrap piles, each against its wall. One against the back wall is solid all the way to the wall (it hides
	# whatever is behind it); the others are solid as wide and as deep as their foot.
	for h in HEAPS:
		var its := heap(bool(h[2]))
		var along := float(h[1])
		var solid: Vector2 = its["solid"]
		var foot := Vector2(float(its["wide"]) * 0.5 + 2.0, along)
		match int(h[0]):
			0:
				foot = Vector2(along, float(its["tall"]))
				solid = Vector2(solid.x, float(its["tall"]))
			1:
				foot = Vector2(float(ROOM.x) * 16.0 - float(its["wide"]) * 0.5 - 2.0, along)
			2:
				foot = Vector2(along, float(ROOM.y) * 16.0 - 2.0)
		dress.append([its["name"], corner + foot, solid, bool(h[3])])
	# The spike traps: a tile each.
	var traps: Array = []
	for r: Rect2i in TRAPS:
		for ty in range(r.position.y, r.end.y):
			for tx in range(r.position.x, r.end.x):
				traps.append(room.position + Vector2i(tx, ty))
	var trap_row := Vector2i(door.x, room.end.y - TRAP_ROW)
	for dx in range(-(TRAP_ROW_WIDE / 2), TRAP_ROW_WIDE / 2 + 1):
		traps.append(trap_row + Vector2i(dx, 0))
	# His hoard: an alcove cut into the back wall, the chest in the middle of it, bars across its mouth.
	var alcove := Rect2i(room.position.x + ROOM.x / 2 + ALCOVE_OUT - ALCOVE.x / 2, room.position.y - ALCOVE.y, ALCOVE.x, ALCOVE.y)
	var mouth := Vector2((float(alcove.position.x) + float(ALCOVE.x) * 0.5) * 16.0, float(room.position.y) * 16.0)
	return {
		"side": side, "room": room, "door": door, "hall": hall, "meet": meet, "gate": gate,
		"gate_foot": Vector2(gate.x * 16 + 8, gate.y * 16 + 16),
		"throne": throne, "throne_solid": throne_size(),
		"blow": throne + Vector2(0, BLOW_DOWN * 16),
		"spots": [room.position + Vector2i(ROOM.x / 2, down + 3), room.position + Vector2i(7, 17), room.position + Vector2i(ROOM.x - 8, down + 1)],
		"dress": dress, "traps": traps, "trap_row": trap_row, "alcove": alcove, "hoard": mouth + Vector2(0, -12), "bars": mouth,
		"lamps": lamps, "keeps": keeps,
	}


## How many tiles below the top wall the front of the throne's step is: as far as the throne's picture is tall, so
## that its back stands against the wall whichever throne the art has.
static func throne_down() -> int:
	var his: Dictionary = Art.json("foes/rattlecrown.json").get("enemies", {}).get("throne", {})
	var o: Array = his.get("origin_feet", [52, 88])
	return clampi(ceili(float(o[1]) / 16.0), 5, ROOM.y - 14)


## How wide and how deep the throne (and its wreck) is solid, in art pixels: the art's own word for it ("solid"),
## or about half its picture's width.
static func throne_size() -> Vector2:
	var his: Dictionary = Art.json("foes/rattlecrown.json").get("enemies", {}).get("throne", {})
	if his.get("solid") is Array and (his["solid"] as Array).size() == 2:
		return Vector2(float(his["solid"][0]), float(his["solid"][1]))
	var f: Array = his.get("frame", [104, 96])
	return Vector2(roundf(float(f[0]) * 0.48), 14.0)


## A scrap pile: its picture's name, how wide and tall the picture is and how much of its foot is solid, read from
## the Scrapyard's sheet so that a redrawn pile of another size still stands against its wall.
static func heap(large: bool) -> Dictionary:
	var name := "scrap_heap_large" if large else "scrap_heap_small"
	var info: Dictionary = Art.json("scrapyard/scrapyard.json").get("sprites", {}).get(name, {})
	var frame: Array = info.get("frame", [48, 30] if large else [32, 20])
	var solid: Array = info.get("solid", [40, 8] if large else [22, 6])
	return {"name": name, "wide": float(frame[0]), "tall": float(frame[1]), "solid": Vector2(float(solid[0]), float(solid[1]))}


## The tiles something solid stands on, for the enemies' way-finding: `foot` is the middle of its front edge and
## `size` how wide and deep it is (art pixels).
static func tiles_under(foot: Vector2, size: Vector2) -> Array:
	var out: Array = []
	for row in range(floori((foot.y - size.y + 1.0) / 16.0), floori((foot.y - 1.0) / 16.0) + 1):
		for x in range(floori((foot.x - size.x * 0.5 - 4.0) / 16.0), floori((foot.x + size.x * 0.5 + 4.0) / 16.0) + 1):
			var middle := float(x) * 16.0 + 8.0
			if middle >= foot.x - size.x * 0.5 - 4.0 and middle <= foot.x + size.x * 0.5 + 4.0:
				out.append(Vector2i(x, row))
	return out


## Cuts the hall and the way into the land, lights them, and locks the rock round them. Call it once, right after
## the land and the other plans are made and before a save's changes are done to it. Returns how many tiles of
## rock it cut.
static func stamp(map: LandMap, plan: Dictionary) -> int:
	if not bool(plan.get("ok", false)):
		return 0
	var cut := 0
	var room: Rect2i = plan["room"]
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			cut += _cut(map, x, y)
	for t in plan["hall"]:
		cut += _cut(map, t.x, t.y)
	var alcove: Rect2i = plan["alcove"]
	for y in range(alcove.position.y, alcove.end.y):
		for x in range(alcove.position.x, alcove.end.x):
			cut += _cut(map, x, y)
	map.stamp_lamp({"x": int((plan["hoard"] as Vector2).x), "y": int((plan["hoard"] as Vector2).y) - 4, "r": HOARD_LIGHT})
	for at in plan["lamps"]:
		map.stamp_lamp({"x": at.x * 16 + 8, "y": at.y * 16 + 6, "r": 46})
		map.stamp_thing({"n": "lantern", "x": at.x * 16 + 8, "y": at.y * 16 + 12, "f": false})
	for d in plan["dress"]:
		if str(d[0]) == "brazier":
			map.stamp_lamp({"x": int((d[1] as Vector2).x), "y": int((d[1] as Vector2).y) - 4, "r": BRAZIER_LIGHT})
	for k in plan["keeps"]:
		map.keeps.append(k)
	return cut


static func _cut(map: LandMap, x: int, y: int) -> int:
	if not LandMap.rocky(map.kind(x, y)):
		return 0
	map.set_kind(x, y, LandMap.FLOOR)
	return 1


## Is this place (world units) inside the hall?
static func in_room(plan: Dictionary, at: Vector2, grow := 0.0) -> bool:
	if not bool(plan.get("ok", false)):
		return false
	var room: Rect2i = plan["room"]
	return Rect2(Vector2(room.position) * 32.0, Vector2(room.size) * 32.0).grow(grow).has_point(at)
