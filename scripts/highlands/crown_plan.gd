extends RefCounted
## Rattlecrown's Scrapyard on a Highlands map: its gate, its rooms and his Throne Room (version 49; version 48 had
## the Throne Room alone, in a corner of the land).
##
## The Game Bible: Rattlecrown's Scrapyard is "a walled dungeon on the surface", in the outer ring, far east, "seen
## early but sealed until the horn" ("Blow it at the Scrapyard gate, then in the Throne Room"), and its layout is
## "1) Gatehouse: Cliff Hound pack and an elite handler; 2) Crane Yard: Slingers on scrap towers while a goblin crane
## drops junk (break the operator's cab); 3) Shaman's Furnace: two Shamans shielding Scrap Brutes, kill the Shamans
## first; 4) Throne Room: Rattlecrown. Between them are small linking rooms and optional side rooms branching off,
## with chests and enemies."
##
## The land's maker (world_gen.gd) keeps a block of rock for it that nothing opens and nobody can dig, with the ground
## in front of its gate below it. This cuts the rooms into that block, every time the world is opened, so the rooms
## can change without the land being made differently. How it is laid out is Claude's choice, after the Art
## builder's stills of the rooms (scrapyard_rooms.png, not agreed by Darren):
##
##   - The rooms stand one above the other, so each is come into at the bottom and left by a door three tiles wide
##     in the middle of its top wall, and the throne is seen from the front as it is drawn. From the gate up: the
##     GATEHOUSE (24 by 12 tiles), a linking room, the CRANE YARD (28 by 15), a linking room, the SHAMAN'S FURNACE
##     (22 by 12), a linking room, and the THRONE ROOM (38 by 26, with the hoard's alcove in its back wall). Walls
##     between them are two tiles thick. Two side rooms (10 by 5) open off two of the linking rooms, each with a
##     chest and a few goblins.
##   - The SCRAPYARD GATE is in the Gatehouse's bottom wall: the horn opens it for good. The Throne Room's own door
##     has a gate as well, which stands open and shuts behind the squad when the horn is blown in front of the
##     throne (Darren, 23 November: "quite like the idea of goblins watching on the fight and the gate closing
##     behind").
##   - The far door of the Gatehouse, the Crane Yard and the Furnace is BARRED until everybody in that room is
##     beaten (crown.gd).
##   - Who is in each room (the enemies' plan for the rooms, `groups`): the Gatehouse four Cliff Hounds and an elite
##     slinger standing in for the elite handler, who has no piece of the horn; the Crane Yard four slingers behind
##     scrap piles (the crane and its cab wait for their art); the Furnace two Shamans and two Brutes, each Shaman
##     keeping one Brute warded while it lives; each side room two slingers and a Brute.
##   - Lights: braziers in every room, as in the Throne Room.
##   - The Throne Room is as version 48 made it: the throne against its top wall, patches of spike traps to either
##     side of the middle and a row of them inside its door, scrap piles round it, the hoard behind bars in an alcove
##     right of the throne.
##   - What is scrap-themed art is the Art builder's; until it lands the rooms are dug floor with the first try's
##     braziers and scrap piles (placeholders).
##
## The same map always gives the same plan, and nothing here is saved: `stamp` cuts it into the land every time the
## world is opened, before a save's digging is done to it again.
##
## The plan: {ok, yard: Rect2i (the block), rooms: {name: Rect2i} (gatehouse, link_a, crane, link_b, furnace, link_c,
## room (the Throne Room), side_a, side_b), cut: [Rect2i] (every room, door and opening that is cut), room: Rect2i (the
## Throne Room), door: Vector2i (the middle tile of the row below the Throne Room: its own gate's), inner: Vector2i
## (the same), inner_foot: Vector2 (art pixels), gate: Vector2i (the Scrapyard gate's middle tile), gate_foot: Vector2
## (art pixels: the middle of its bottom edge), meet: Vector2i (the middle of the ground in front of the gate), bars:
## [{room, tile: Vector2i (the middle tile of the barred row), foot: Vector2 (art pixels)}] (the rooms' far doors),
## approach: Rect2i (the rock cut away outside the gate, down to the ground in front),
## throne, throne_solid, blow, spots, dress: [[name, foot, solid, mirrored]], cover: [[foot, half width]] (what a
## slinger hides behind, art pixels), traps, trap_row, alcove, hoard, hoard_bars: Vector2 (the hoard's bars' foot),
## lamps: [Vector2i], keeps: [Rect2i], groups: [the enemies' plan for the rooms, as foe_plan.gd's with pocket -1 and
## a room], chests: [as loot_plan.gd's, with pocket -1], compass: "east" (which way it lies from the cave)}. `ok` is
## false on a land that has no Scrapyard (one of the tools makes the inner ring alone).

const LandMap := preload("res://scripts/highlands/land_map.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const LootPlan := preload("res://scripts/highlands/loot_plan.gd")
const Art := preload("res://scripts/art.gd")

const ROOM := Vector2i(38, 26)     # the Throne Room, in tiles: wide and deep (the screen is 40 by 22 and a half)
const HALL := 3                    # every door is this many tiles wide
const WALL := 2                    # the rock between two rooms is this thick
const ALCOVE := Vector2i(3, 2)     # the hoard's alcove in the back wall: wide and deep (tiles)
const ALCOVE_OUT := 11             # its middle is this many tiles to the right of the throne's
## The rooms from the top of the block down: [name, wide, deep]. The walls between them are WALL thick; above the
## Throne Room are the block's top wall and the hoard's alcove (WALL + ALCOVE.y), below the Gatehouse the block's
## bottom wall with the gate in it.
const STACK := [["room", 38, 26], ["link_c", 10, 5], ["furnace", 22, 12], ["link_b", 10, 5], ["crane", 28, 15], ["link_a", 10, 5], ["gatehouse", 24, 12]]
const SIDES := [["side_a", "link_a", 1], ["side_b", "link_c", -1]]     # [name, off which linking room, which side]
const SIDE := Vector2i(10, 5)
const BARRED := ["gatehouse", "crane", "furnace"]                       # the rooms whose far door is barred until they are beaten
const TRAPS := [Rect2i(5, 12, 4, 3), Rect2i(29, 12, 4, 3), Rect2i(9, 19, 4, 3), Rect2i(25, 19, 4, 3)]   # the patches of spike traps, in tiles from the hall's corner: clear of the middle, the same on both sides
const TRAP_ROW := 5                # and a row of them inside the door, this many tiles above the hall's bottom wall
const TRAP_ROW_WIDE := 7           # (so many tiles wide)
const HOARD_LIGHT := 30            # the chest's own pool of light (art pixels)
const BRAZIER_LIGHT := 58          # a brazier lights the floor this far round it (art pixels)
const CHEST_ID := 100000           # the side rooms' chests are numbered from here (the land's are numbered by their place)
## The scrap piles round the arena: [which wall (0 the back, 1 the right, 2 the front, 3 the left), how far along it
## (art pixels from the hall's top left corner), a large one, mirrored]. Not the same on both sides, so that it
## does not look laid out with a ruler.
const HEAPS := [
	[0, 120, true, false], [0, 188, false, true], [0, 424, true, true], [0, 540, false, false],
	[1, 120, false, true], [1, 232, true, false], [1, 330, false, false],
	[2, 112, true, true], [2, 200, false, false], [2, 408, false, true], [2, 480, true, false],
	[3, 144, true, false], [3, 248, false, true], [3, 336, true, true],
]
## The Crane Yard's scrap piles, out in the yard for the slingers to throw from behind: [tiles from the room's top left
## corner (the middle of the pile's foot), a large one, mirrored].
const YARD_HEAPS := [[Vector2(6, 5), true, false], [Vector2(21, 4), false, true], [Vector2(9, 11), false, false], [Vector2(19, 10), true, true],
	[Vector2(11, 7), false, false]]
const BLOW_DOWN := 5               # the horn is blown this many tiles in front of the throne


static func make(map: LandMap) -> Dictionary:
	if not map.sites.has("scrapyard"):
		return {"ok": false}
	var site: Dictionary = map.sites["scrapyard"]
	var yard: Rect2i = site["rect"]
	var cx: int = (site["gate"] as Vector2i).x
	var rooms := {}
	var y := yard.position.y + WALL + ALCOVE.y
	for row in STACK:
		var w := int(row[1])
		rooms[str(row[0])] = Rect2i(cx - w / 2, y, w, int(row[2]))
		y += int(row[2]) + WALL
	for row in SIDES:
		var link: Rect2i = rooms[str(row[1])]
		var x := link.end.x + WALL if int(row[2]) > 0 else link.position.x - WALL - SIDE.x
		rooms[str(row[0])] = Rect2i(x, link.position.y, SIDE.x, SIDE.y)
	var room: Rect2i = rooms["room"]
	var gatehouse: Rect2i = rooms["gatehouse"]
	# What is cut: every room, the door in every wall between two of them (three wide, in the middle), the way into
	# each side room, the gate's door in the bottom wall, and the hoard's alcove.
	var cut: Array = []
	for name in rooms:
		cut.append(rooms[name])
	for k in range(1, STACK.size()):
		var above: Rect2i = rooms[str(STACK[k - 1][0])]
		cut.append(Rect2i(cx - HALL / 2, above.end.y, HALL, WALL))
	cut.append(Rect2i(cx - HALL / 2, gatehouse.end.y, HALL, yard.end.y - gatehouse.end.y))
	for row in SIDES:
		var link: Rect2i = rooms[str(row[1])]
		var x := link.end.x if int(row[2]) > 0 else link.position.x - WALL
		cut.append(Rect2i(x, link.position.y + 1, WALL, HALL))
	var alcove := Rect2i(room.position.x + ROOM.x / 2 + ALCOVE_OUT - ALCOVE.x / 2, room.position.y - ALCOVE.y, ALCOVE.x, ALCOVE.y)
	cut.append(alcove)
	var gate := Vector2i(cx, gatehouse.end.y)
	var door := Vector2i(cx, room.end.y)
	# Outside the gate, the rock that the land keeps round the block (nothing is opened within two tiles of it) is
	# cut away down to the ground in front, so that the gate stands at the back of a short way in.
	var down := 0
	while down < 8 and LandMap.rocky(map.kind(cx, yard.end.y + down)):
		down += 1
	var plan := _throne_room(room, door, alcove)
	plan["ok"] = true
	plan["yard"] = yard
	plan["rooms"] = rooms
	plan["cut"] = cut
	plan["approach"] = Rect2i(cx - HALL / 2, yard.end.y, HALL, down)
	plan["gate"] = gate
	plan["gate_foot"] = Vector2(gate.x * 16 + 8, gate.y * 16 + 16)
	plan["inner"] = door
	plan["inner_foot"] = Vector2(door.x * 16 + 8, door.y * 16 + 16)
	plan["meet"] = Vector2i(floori((site["at"] as Vector2).x), floori((site["at"] as Vector2).y))
	plan["keeps"] = [yard]
	var a := (Vector2(cx, gatehouse.end.y) - Vector2(LandMap.MID, LandMap.MID)).angle()
	plan["compass"] = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"][posmod(roundi(a / (PI / 4.0)), 8)]
	# The rooms' far doors, barred until the room is beaten: the bars stand in the wall's row next to the room.
	var bars: Array = []
	for name in BARRED:
		var r: Rect2i = rooms[name]
		var t := Vector2i(cx, r.position.y - 1)
		bars.append({"room": name, "tile": t, "foot": Vector2(t.x * 16 + 8, t.y * 16 + 16)})
	plan["bars"] = bars
	# Braziers in every room but the Throne Room (which has its own four): two by the top wall, and in a big room two
	# more by the bottom one. Lanterns in the linking rooms.
	var dress: Array = plan["dress"]
	var lamps: Array = []
	for name in ["gatehouse", "crane", "furnace", "side_a", "side_b"]:
		var r: Rect2i = rooms[name]
		var corner := Vector2(r.position) * 16.0
		var wide := float(r.size.x) * 16.0
		var spots: Array = [[Vector2(wide * 0.5 - 56.0, 30.0), false], [Vector2(wide * 0.5 + 56.0, 30.0), true]]
		if name.begins_with("side"):
			spots = [[Vector2(wide * 0.5, 30.0), false]]
		elif r.size.y >= 12:
			spots.append([Vector2(26.0, float(r.size.y) * 16.0 - 18.0), false])
			spots.append([Vector2(wide - 26.0, float(r.size.y) * 16.0 - 18.0), true])
		for sp in spots:
			dress.append(["brazier", corner + (sp[0] as Vector2), Vector2(10, 4), bool(sp[1])])
	for name in ["link_a", "link_b", "link_c"]:
		var r: Rect2i = rooms[name]
		lamps.append(Vector2i(r.position.x + 1, r.position.y + 1))
		lamps.append(Vector2i(r.end.x - 2, r.position.y + 1))
	plan["lamps"] = lamps
	# The Crane Yard's scrap piles, out in the yard: what its slingers hide behind. A pile against a wall in the
	# Gatehouse and the Furnace.
	var cover: Array = []
	var crane: Rect2i = rooms["crane"]
	for h in YARD_HEAPS:
		var its := heap(bool(h[1]))
		var foot := Vector2(crane.position) * 16.0 + (h[0] as Vector2) * 16.0 + Vector2(8, 12)
		dress.append([its["name"], foot, its["solid"], bool(h[2])])
		cover.append([foot, (its["solid"] as Vector2).x * 0.5])
	for pair in [["gatehouse", 1], ["furnace", -1]]:
		var r: Rect2i = rooms[str(pair[0])]
		var its := heap(true)
		var x := float(r.end.x) * 16.0 - float(its["wide"]) * 0.5 - 2.0 if int(pair[1]) > 0 else float(r.position.x) * 16.0 + float(its["wide"]) * 0.5 + 2.0
		dress.append([its["name"], Vector2(x, float(r.end.y) * 16.0 - 2.0), its["solid"], int(pair[1]) < 0])
	plan["cover"] = cover
	plan["groups"] = groups(rooms)
	plan["chests"] = chests(map, rooms)
	return plan


## Who is in the rooms: groups as the enemies' plan has them (foe_plan.gd), with no place of the land's (pocket -1)
## and the room they are in. A member may say who it stands in for ("handler": the Gatehouse's elite, who has no
## piece of the horn).
static func groups(rooms: Dictionary) -> Array:
	var out: Array = []
	var rows := [
		["gatehouse", "hounds", [["hound", false], ["hound", false], ["hound", false], ["hound", false], ["slinger", true, "handler"]]],
		["crane", "goblins", [["slinger", false], ["slinger", false], ["slinger", false], ["slinger", false]]],
		["furnace", "goblins", [["shaman", false], ["shaman", false], ["scrap_brute", false], ["scrap_brute", false]]],
		["side_a", "goblins", [["scrap_brute", false], ["slinger", false], ["slinger", false]]],
		["side_b", "goblins", [["scrap_brute", false], ["slinger", false], ["slinger", false]]],
	]
	for row in rows:
		var r: Rect2i = rooms[str(row[0])]
		out.append({"id": -1, "pocket": -1, "home": Vector2(r.get_center()), "r": float(mini(r.size.x, r.size.y)) * 0.5, "members": row[2],
			"what": row[1], "site": "scrapyard", "room": row[0]})
	return out


## The side rooms' chests: one at the back of each, a richer one (the land's "site" kind), each with its own number.
static func chests(map: LandMap, rooms: Dictionary) -> Array:
	var out: Array = []
	var n := 0
	for name in ["side_a", "side_b"]:
		var r: Rect2i = rooms[name]
		var tile := Vector2i(r.end.x - 2 if r.position.x > (rooms["link_a"] as Rect2i).position.x else r.position.x + 1, r.position.y + 1)
		var c := {"id": CHEST_ID + n, "pocket": -1, "kind": "site", "tile": tile, "foot": Vector2(tile.x * 16 + 8, tile.y * 16 + 12)}
		c.merge(LootPlan._holds(map.seed_value, CHEST_ID + n, "site", true, 3))
		out.append(c)
		n += 1
	return out


## The Throne Room itself, as version 48 made it.
static func _throne_room(room: Rect2i, door: Vector2i, alcove: Rect2i) -> Dictionary:
	var lamps: Array = []
	var down := throne_down()
	var throne := Vector2((room.position.x + ROOM.x / 2) * 16, (room.position.y + down) * 16)
	# Four standing braziers, two beside the throne and two lower down: [name, where its foot is (art pixels), how
	# wide and how deep it is solid, mirrored].
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
	# His hoard: the chest in the middle of the alcove, bars across its mouth.
	var mouth := Vector2((float(alcove.position.x) + float(ALCOVE.x) * 0.5) * 16.0, float(room.position.y) * 16.0)
	return {
		"room": room, "door": door,
		"throne": throne, "throne_solid": throne_size(),
		"blow": throne + Vector2(0, BLOW_DOWN * 16),
		"spots": [room.position + Vector2i(ROOM.x / 2, down + 3), room.position + Vector2i(7, 17), room.position + Vector2i(ROOM.x - 8, down + 1)],
		"dress": dress, "traps": traps, "trap_row": trap_row, "alcove": alcove, "hoard": mouth + Vector2(0, -12), "hoard_bars": mouth,
		"lamps": lamps,
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


## Cuts the rooms into the land, lights them, and locks the rock round them. Call it once, right after the land and
## the other plans are made and before a save's changes are done to it. Returns how many tiles of rock it cut.
static func stamp(map: LandMap, plan: Dictionary) -> int:
	if not bool(plan.get("ok", false)):
		return 0
	var cut := 0
	for r: Rect2i in plan["cut"]:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				cut += _cut(map, x, y)
	var way: Rect2i = plan.get("approach", Rect2i())
	for y in range(way.position.y, way.end.y):
		for x in range(way.position.x, way.end.x):
			if LandMap.rocky(map.kind(x, y)):
				map.set_kind(x, y, LandMap.YARD if x == way.position.x + way.size.x / 2 else LandMap.GRASS)
				cut += 1
	map.stamp_lamp({"x": int((plan["hoard"] as Vector2).x), "y": int((plan["hoard"] as Vector2).y) - 4, "r": HOARD_LIGHT})
	for at in plan["lamps"]:
		map.stamp_lamp({"x": at.x * 16 + 8, "y": at.y * 16 + 6, "r": 46})
		map.stamp_thing({"n": "lantern", "x": at.x * 16 + 8, "y": at.y * 16 + 12, "f": false})
	for d in plan["dress"]:
		if str(d[0]) == "brazier":
			map.stamp_lamp({"x": int((d[1] as Vector2).x), "y": int((d[1] as Vector2).y) - 4, "r": BRAZIER_LIGHT})
	for k in plan["keeps"]:
		if not map.keeps.has(k):
			map.keeps.append(k)
	return cut


static func _cut(map: LandMap, x: int, y: int) -> int:
	if not LandMap.rocky(map.kind(x, y)):
		return 0
	map.set_kind(x, y, LandMap.FLOOR)
	return 1


## Is this place (world units) inside the Scrapyard's walls?
static func in_yard(plan: Dictionary, at: Vector2, grow := 0.0) -> bool:
	if not bool(plan.get("ok", false)):
		return false
	var r: Rect2i = plan["yard"]
	return Rect2(Vector2(r.position) * 32.0, Vector2(r.size) * 32.0).grow(grow).has_point(at)


## Is this place (world units) inside the Throne Room?
static func in_room(plan: Dictionary, at: Vector2, grow := 0.0) -> bool:
	if not bool(plan.get("ok", false)):
		return false
	var room: Rect2i = plan["room"]
	return Rect2(Vector2(room.position) * 32.0, Vector2(room.size) * 32.0).grow(grow).has_point(at)
