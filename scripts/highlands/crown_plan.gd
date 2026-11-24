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
##     GATEHOUSE (24 by 12 tiles), a linking room, the CRANE YARD (28 by 15), a short linking room (10 by 3), the
##     SHAMAN'S FURNACE (22 by 12), a linking room, and the THRONE ROOM (38 by 26, with stands two tiles deep round its
##     back and both sides for the goblins who watch the fight, and the hoard's alcove through the back stand into the
##     wall behind it: version 50, after the Art builder's still of the hall, hall_final.png). Walls between them are
##     two tiles thick. Two side rooms (10 by 5) open off two of the linking rooms, each with a
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
##   - The Throne Room is as version 48 made it, with version 50's stands: the throne at the back, in a gap in the
##     back stand, patches of spike traps to either side of the middle and a row of them inside its door, scrap piles
##     round its edge, the hoard behind bars in an alcove right of the throne. The stands are cut out of the rock as
##     floor (the planks are painted into it) and nobody of the squad or the enemies can step onto them.
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
const ALCOVE := Vector2i(3, 3)     # the hoard's alcove: wide, and how deep it goes into the wall behind the back stand (tiles)
const ABOVE := 4                   # the rock above the back stand, before the alcove is cut into it (tiles)
const ALCOVE_OUT := 11             # its middle is this many tiles to the right of the throne's
## The rooms from the top of the block down: [name, wide, deep]. The walls between them are WALL thick; above the
## Throne Room are the block's top wall and the back stand (ABOVE + STANDS; the hoard's alcove is cut into them), below the Gatehouse the block's
## bottom wall with the gate in it.
const STACK := [["room", 38, 26], ["link_c", 10, 5], ["furnace", 22, 12], ["link_b", 10, 3], ["crane", 28, 15], ["link_a", 10, 5], ["gatehouse", 24, 12]]
## Version 50: the watching goblins' stands, this many tiles deep round the back and both sides of the Throne Room
## (the room takes them from the block: link_b, which has no side room, is two tiles shorter than the others).
const STANDS := 2
## How many tiles below the room's top edge the front of the throne's step is: the throne stands in a gap in the back
## stand and its back rises over the stand and the wall behind it, as in the Art builder's still of the hall.
const THRONE_DOWN := 3
const SIDES := [["side_a", "link_a", 1], ["side_b", "link_c", -1]]     # [name, off which linking room, which side]
const SIDE := Vector2i(10, 5)
const BARRED := ["gatehouse", "crane", "furnace"]                       # the rooms whose far door is barred until they are beaten
const TRAPS := [Rect2i(5, 12, 4, 3), Rect2i(29, 12, 4, 3), Rect2i(9, 19, 4, 3), Rect2i(25, 19, 4, 3)]   # the patches of spike traps, in tiles from the hall's corner: clear of the middle, the same on both sides
const TRAP_ROW := 5                # and a row of them inside the door, this many tiles above the hall's bottom wall
const TRAP_ROW_WIDE := 7           # (so many tiles wide)
const HOARD_LIGHT := 30            # the chest's own pool of light (art pixels)
const BRAZIER_LIGHT := 58          # a brazier lights the floor this far round it (art pixels)
const CHEST_ID := 100000           # the side rooms' chests are numbered from here (the land's are numbered by their place)
## The scrap piles round the arena's edge, where the Art builder's still of the hall has them (version 50): [the
## pile's picture, where its foot is (art pixels from the hall's top left corner; a negative x is from the right wall,
## a negative y from the bottom wall), mirrored]. Two big heaps in the low corners, smaller ones along the walls.
const HEAPS := [
	["scrap_pile_big", Vector2(46, -3), false], ["scrap_pile_big", Vector2(-46, -3), true],
	["scrap_pile_mid", Vector2(32, 58), false], ["scrap_pile_mid", Vector2(-32, 58), true],
	["scrap_pile_side", Vector2(26, 344), false], ["scrap_pile_side", Vector2(-26, 344), true],
	["scrap_pile_small", Vector2(128, -3), false], ["scrap_pile_small", Vector2(-122, -3), true],
]
## The watching goblins on the stands, after the Art builder's still: [pose, a cap], taken in turn.
const POSES := ["cheer", "lean", "fist", "drum", "lean", "cheer", "fist", "lean"]
## The Crane Yard's scrap piles, out in the yard for the slingers to throw from behind: [tiles from the room's top left
## corner (the middle of the pile's foot), a large one, mirrored].
const YARD_HEAPS := [[Vector2(6, 5), true, false], [Vector2(21, 4), false, true], [Vector2(9, 11), false, false], [Vector2(19, 10), true, true],
	[Vector2(11, 7), false, false]]
const BLOW_DOWN := 5               # the horn is blown this many tiles in front of the throne
## Version 52: each of the Scrapyard's other rooms dressed its own way (the project's review of version 49), with only
## what the Throne Room already has, until the Art builder's room art is agreed: braziers [foot, mirrored] and piles
## against the walls [picture, foot, mirrored] (art pixels from the room's top left corner; a negative x is from the
## right wall, a negative y from the bottom wall), a paved way [tiles], how big the soot under a brazier is and how far
## trodden scrap spreads round a pile (times the pile's width). The Gatehouse is the way in: a paved way from the gate
## to the far door between four braziers, piles in its corners. The Crane Yard is open junk: braziers in its four
## corners, its piles out in the yard (YARD_HEAPS) with scrap trodden wide round them. The Furnace is hot: a row of four
## braziers along the back wall with heavy soot, a big pile in each front corner. A side room: a brazier and a pile.
const ROOM_DRESS := {
	"gatehouse": {"braziers": [[Vector2(132, 30), false], [Vector2(-132, 30), true], [Vector2(132, -18), false], [Vector2(-132, -18), true]],
		"heaps": [["scrap_heap_large", Vector2(32, 50), false], ["scrap_heap_small", Vector2(-24, 46), true], ["scrap_heap_large", Vector2(-30, -2), true]],
		"paving": [Rect2i(11, 0, 3, 12)], "soot": Vector2(11, 6), "litter": 0.62},
	"crane": {"braziers": [[Vector2(26, 30), false], [Vector2(-26, 30), true], [Vector2(26, -18), false], [Vector2(-26, -18), true]],
		"heaps": [], "paving": [], "soot": Vector2(11, 6), "litter": 1.0},
	"furnace": {"braziers": [[Vector2(40, 30), false], [Vector2(100, 30), false], [Vector2(-100, 30), true], [Vector2(-40, 30), true]],
		"heaps": [["scrap_heap_large", Vector2(30, -2), false], ["scrap_heap_large", Vector2(-30, -2), true]],
		"paving": [], "soot": Vector2(18, 9), "litter": 0.62},
	"side_a": {"braziers": [[Vector2(80, 30), false]], "heaps": [["scrap_heap_small", Vector2(-22, -2), true]], "paving": [], "soot": Vector2(11, 6), "litter": 0.62},
	"side_b": {"braziers": [[Vector2(80, 30), true]], "heaps": [["scrap_heap_small", Vector2(22, -2), false]], "paving": [], "soot": Vector2(11, 6), "litter": 0.62},
}


static func make(map: LandMap) -> Dictionary:
	if not map.sites.has("scrapyard"):
		return {"ok": false}
	var site: Dictionary = map.sites["scrapyard"]
	var yard: Rect2i = site["rect"]
	var cx: int = (site["gate"] as Vector2i).x
	var rooms := {}
	var y := yard.position.y + ABOVE + STANDS
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
	# The stands round the back and both sides of the Throne Room (cut as floor, for the planks; nobody steps on them),
	# and the hoard's alcove: through the back stand and into the wall behind it.
	var lay := throne_layout()
	for r: Rect2i in lay["stands"]:
		cut.append(Rect2i(room.position + r.position, r.size))
	var al: Rect2i = lay["alcove"]
	var alcove := Rect2i(room.position + al.position, al.size)
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
	# Every other room's braziers and piles (ROOM_DRESS; the Crane Yard's piles out in the yard are the slingers' cover),
	# and lanterns in the linking rooms.
	var dress: Array = plan["dress"]
	var cover: Array = []
	var dressed := room_dress_layout()
	for name in dressed:
		var r: Rect2i = rooms[name]
		var corner := Vector2(r.position) * 16.0
		for b in dressed[name]["braziers"]:
			dress.append(["brazier", corner + (b[0] as Vector2), Vector2(10, 4), bool(b[1])])
		for h in dressed[name]["heaps"]:
			var its := heap_named(str(h[0]))
			var foot := corner + (h[1] as Vector2)
			dress.append([its["name"], foot, its["solid"], bool(h[2])])
			if bool(h[3]):
				cover.append([foot, (its["solid"] as Vector2).x * 0.5])
	var lamps: Array = []
	for name in ["link_a", "link_b", "link_c"]:
		var r: Rect2i = rooms[name]
		lamps.append(Vector2i(r.position.x + 1, r.position.y + 1))
		lamps.append(Vector2i(r.end.x - 2, r.position.y + 1))
	plan["lamps"] = lamps
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


## Where every other room's braziers and piles stand, in its own art pixels from its top left corner (ROOM_DRESS with
## the corners worked out, and the Crane Yard's piles out in the yard): {name: {size (tiles), braziers: [[foot,
## mirrored]], heaps: [[picture, foot, mirrored, cover]], paving: [Rect2i tiles], soot, litter}}. tools/rattlecrown_kit
## paints each room's floor from it.
static func room_dress_layout() -> Dictionary:
	var out := {}
	for name in ROOM_DRESS:
		var size := room_size(str(name))
		var px := Vector2(size) * 16.0
		var d: Dictionary = ROOM_DRESS[name]
		var braziers: Array = []
		for b in d["braziers"]:
			braziers.append([_from_corner(b[0], px), b[1]])
		var heaps: Array = []
		for h in d["heaps"]:
			heaps.append([h[0], _from_corner(h[1], px), h[2], false])
		if name == "crane":
			for h in YARD_HEAPS:
				heaps.append([heap(bool(h[1]))["name"], (h[0] as Vector2) * 16.0 + Vector2(8, 12), h[2], true])
		out[name] = {"size": size, "braziers": braziers, "heaps": heaps, "paving": d["paving"], "soot": d["soot"], "litter": d["litter"]}
	return out


## A room's size in tiles, by its name.
static func room_size(name: String) -> Vector2i:
	for row in STACK:
		if str(row[0]) == name:
			return Vector2i(int(row[1]), int(row[2]))
	return SIDE


static func _from_corner(at: Vector2, px: Vector2) -> Vector2:
	return Vector2(at.x if at.x >= 0.0 else px.x + at.x, at.y if at.y >= 0.0 else px.y + at.y)


## The Throne Room itself: version 48's room with version 50's stands (positions from throne_layout, which is in the
## room's own tiles and art pixels).
static func _throne_room(room: Rect2i, door: Vector2i, alcove: Rect2i) -> Dictionary:
	var lay := throne_layout()
	var corner := Vector2(room.position) * 16.0
	var throne: Vector2 = corner + (lay["throne"] as Vector2)
	var dress: Array = []
	for d in lay["dress"]:
		dress.append([d[0], corner + (d[1] as Vector2), d[2], d[3]])
	var traps: Array = []
	for t: Vector2i in lay["traps"]:
		traps.append(room.position + t)
	var trap_row: Vector2i = room.position + (lay["trap_row"] as Vector2i)
	var stands: Array = []
	for r: Rect2i in lay["stands"]:
		stands.append(Rect2i(room.position + r.position, r.size))
	var scenery: Array = []
	for d in lay["scenery"]:
		scenery.append([d[0], corner + (d[1] as Vector2), d[2], d[3], d[4]])
	var spots: Array = []
	for t: Vector2i in lay["spots"]:
		spots.append(room.position + t)
	var mouth: Vector2 = corner + (lay["hoard_bars"] as Vector2)
	return {
		"room": room, "door": door,
		"throne": throne, "throne_solid": throne_size(),
		"blow": throne + Vector2(0, BLOW_DOWN * 16),
		"spots": spots, "dress": dress, "traps": traps, "trap_row": trap_row, "alcove": alcove,
		"hoard": corner + (lay["hoard"] as Vector2), "hoard_bars": mouth,
		"stands": stands, "scenery": scenery, "lamps": [],
	}


## Where everything in the Throne Room is, in the room's own tiles (Vector2i, Rect2i: from its top left tile) and art
## pixels (Vector2: from its top left corner). The game and tools/rattlecrown_kit (which paints the room's floor and
## draws the stands to fit) both read it:
##   throne: the middle of the front of its step; dress: [[name, foot, solid, mirrored]] (the braziers and the scrap
##   piles, each solid); traps: [Vector2i]; trap_row: Vector2i (the middle of the row inside the door); stands:
##   [Rect2i] (the back stand left and right of the alcove, the left one, the right one); alcove: Rect2i; hoard: the chest's foot; hoard_bars: the middle of the alcove's
##   mouth; scenery: [[name, foot, mirrored, how far above its foot it sorts (art pixels), z]] (the stands' fronts and
##   rails and the watching goblins, not solid: the stands are); spots: [Vector2i] (where the three elites come in);
##   paving: [Rect2i] (the flagstones: before the throne, down the middle, through the door, in the alcove); heaps:
##   [[name, foot]] (for the debris round each pile); braziers: [Vector2] (for the soot under each).
static func throne_layout() -> Dictionary:
	var W := float(ROOM.x) * 16.0
	var H := float(ROOM.y) * 16.0
	var mid := ROOM.x / 2                                    # the middle column (the throne's and the door's)
	var throne := Vector2(float(mid) * 16.0 + 8.0, float(THRONE_DOWN) * 16.0)
	# Two standing braziers beside the throne, two lower down.
	var out := throne_size().x * 0.5 + 40.0
	var braziers: Array = [throne + Vector2(-out, 10), throne + Vector2(out, 10),
		Vector2(float(mid - 7) * 16.0, 17.0 * 16.0 + 8.0), Vector2(float(mid + 7) * 16.0, 17.0 * 16.0 + 8.0)]
	var dress: Array = []
	for k in braziers.size():
		dress.append(["brazier", braziers[k], Vector2(10, 4), k % 2 == 1])
	var heaps: Array = []
	for h in HEAPS:
		var at: Vector2 = h[1]
		var foot := Vector2(W + at.x if at.x < 0.0 else at.x, H + at.y if at.y < 0.0 else at.y)
		dress.append([h[0], foot, heap_named(str(h[0]))["solid"], bool(h[2])])
		heaps.append([h[0], foot])
	var traps: Array = []
	for r: Rect2i in TRAPS:
		for ty in range(r.position.y, r.end.y):
			for tx in range(r.position.x, r.end.x):
				traps.append(Vector2i(tx, ty))
	var trap_row := Vector2i(mid, ROOM.y - TRAP_ROW)
	for dx in range(-(TRAP_ROW_WIDE / 2), TRAP_ROW_WIDE / 2 + 1):
		traps.append(trap_row + Vector2i(dx, 0))
	var ax := mid + ALCOVE_OUT                               # the alcove's middle column
	var alcove := Rect2i(ax - ALCOVE.x / 2, -STANDS - ALCOVE.y, ALCOVE.x, ALCOVE.y + STANDS)
	# The back stand stops either side of the alcove (the way to the hoard), and runs on behind the throne.
	var stands: Array = [Rect2i(-STANDS, -STANDS, alcove.position.x + STANDS, STANDS), Rect2i(alcove.end.x, -STANDS, ROOM.x + STANDS - alcove.end.x, STANDS),
		Rect2i(-STANDS, 0, STANDS, ROOM.y), Rect2i(ROOM.x, 0, STANDS, ROOM.y)]
	var mouth := Vector2(float(ax) * 16.0 + 8.0, 0.0)
	# The back stand's timber front runs along the room's top edge in three runs: left of the throne, between the
	# throne and the hoard, right of the hoard. Its foot is 14 pixels into the room, but it sorts at the edge, so that
	# whoever stands in the room's top row is in front of it. The rails run down both sides, under everyone.
	var scenery: Array = []
	var runs: Array = [[0, mid - 5], [mid + 5, alcove.position.x - 1], [alcove.end.x, ROOM.x - 1]]
	for k in runs.size():
		scenery.append(["stand_front_%d" % k, Vector2(float(runs[k][0]) * 16.0, 14.0), false, 14.0, 0])
	scenery.append(["stand_rail", Vector2(0.0, H), false, H, -1])
	scenery.append(["stand_rail", Vector2(W - 1.0, H), true, H, -1])
	# The crowd, where the Art builder's still has it: a row along the back stand's fence, a few behind them, and a
	# line down each side.
	var back: Array = []
	var x := 30.0
	while x < float(mid - 5) * 16.0:
		back.append(Vector2(x, -19.0))
		x += 68.0
	back.append(Vector2(float(alcove.end.x) * 16.0 + 34.0, -19.0))
	var front: Array = []
	x = 12.0
	while x < float(mid - 4) * 16.0 - 8.0:
		front.append(Vector2(x, -3.0))
		x += 34.0
	for fx in [float(mid + 5) * 16.0 + 14.0, float(mid + 5) * 16.0 + 48.0, float(alcove.end.x) * 16.0 + 16.0, float(alcove.end.x) * 16.0 + 50.0]:
		front.append(Vector2(fx, -3.0))
	var sides: Array = []
	var y := 34.0
	while y < H:
		sides.append(Vector2(-15.0, y))
		y += 46.0
	y = 52.0
	while y < H:
		sides.append(Vector2(W + 15.0, y))
		y += 46.0
	var i := 0
	for at: Vector2 in back + front + sides:
		var name := "goblin_%s%s" % [POSES[(i * 3 + 1) % POSES.size()], "_cap" if i % 4 == 1 else ""]
		scenery.append([name, at, at.x > W, 0.0, -1 if at.y < 0.0 else 0])
		i += 1
	return {
		"room": ROOM, "stands_deep": STANDS, "throne": throne, "dress": dress, "traps": traps, "trap_row": trap_row,
		"stands": stands, "alcove": alcove, "hoard": mouth + Vector2(0, -44), "hoard_bars": mouth, "scenery": scenery,
		"spots": [Vector2i(mid, THRONE_DOWN + 3), Vector2i(7, 17), Vector2i(ROOM.x - 8, THRONE_DOWN + 1)],
		"paving": [Rect2i(mid - 6, 1, 13, 5), Rect2i(mid - 2, 6, 5, ROOM.y - 6), Rect2i(mid - 1, ROOM.y, 3, WALL), alcove],
		"heaps": heaps, "braziers": braziers, "door": mid,
	}


## Kept for the tests and older callers: how many tiles below the top edge the front of the throne's step is.
static func throne_down() -> int:
	return THRONE_DOWN


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
	return heap_named("scrap_heap_large" if large else "scrap_heap_small")


static func heap_named(name: String) -> Dictionary:
	var info: Dictionary = Art.json("scrapyard/scrapyard.json").get("sprites", {}).get(name, {})
	var large := name != "scrap_heap_small" and name != "scrap_pile_small"
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
	# The Throne Room's floor (version 50): the paving, the sunk slabs of the spike traps, the soot under the braziers,
	# the scrap trodden in round the piles and the stands' planks, painted into the dug floor (tools/rattlecrown_kit).
	var room: Rect2i = plan["room"]
	for piece in Art.json("scrapyard/throne_floor.json").get("pieces", []):
		var at: Array = piece["at"]
		map.stamp_floor_decal({"sheet": "throne_floor", "rect": piece["rect"], "shade": piece["shade"],
			"x": room.position.x * 16 + int(at[0]), "y": room.position.y * 16 + int(at[1])})
	# The other rooms' floors (version 52): soot under their braziers, scrap trodden in round their piles and the
	# Gatehouse's paved way.
	var rooms: Dictionary = plan["rooms"]
	var floors: Dictionary = Art.json("scrapyard/rooms_floor.json").get("rooms", {})
	for name in floors:
		if not rooms.has(name):
			continue
		var r: Rect2i = rooms[name]
		for piece in floors[name]:
			var at: Array = piece["at"]
			map.stamp_floor_decal({"sheet": "rooms_floor", "rect": piece["rect"], "shade": piece["shade"],
				"x": r.position.x * 16 + int(at[0]), "y": r.position.y * 16 + int(at[1])})
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
