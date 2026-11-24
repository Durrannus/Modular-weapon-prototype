extends RefCounted
## Where Pip's cage, Pip's place at the base and the keepers' waystone stand on a Highlands map (version 46). The
## same map always gives the same plan, and it changes nothing on the land (so a world saved before Pip existed is
## still the same land, and nothing has to be laid out again). Like the chests' plan it must be made from the land
## AS IT WAS MADE, before a save's digging and felling are done to it again.
##
## The rules, from the Game Bible:
##   - The Slinger Roost: "Pip is locked in a hanging scrap cage in the middle"; "Led by the Elite Pebble Slinger".
##   - The Keeper's Watchpost: "A broken waystone outside to repair."
##   - Freed, Pip "moves to the base".
## And Claude's choices, until Darren says otherwise:
##   - Since version 49 the land has its Slinger Roost (world_gen.gd: a rocky hollow in a canyon in the middle ring,
##     east), and the elite slinger's band holds it (foe_plan.gd): the cage hangs in its middle. A land with no such
##     band (one of the tools makes the inner ring alone) hangs the cage in its farthest goblin camp, and failing that
##     in its farthest open place.
##   - The waystone stands on the cave's side of the Watchpost, clear of its chest.
##   - Rooms cannot be built yet, so Pip camps beside the cave mouth.
##
## The plan: {roost: {pocket, group (the plan index of who guards it, or -1), tile, foot (art pixels)},
##            stone: {id: "watchpost", name, pocket, group, tile, foot} or {}, pip: {tile, foot}}.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const LootPlan := preload("res://scripts/highlands/loot_plan.gd")

const CAGE_WIDE := 30.0        # the cage hangs to the right of its post, and Pip drops there: that ground is kept clear too
const STONE_WIDE := 26.0       # the broken waystone's top lies to its right


## `groups` is the enemies' plan for the same map and `chests` the chests' plan: nothing here stands on a chest.
static func make(map: LandMap, groups: Array, chests: Array) -> Dictionary:
	var cave := Vector2(LandMap.MID + 0.5, LandMap.MID + 0.5)
	var taken: Array = []
	for c in chests:
		taken.append(c["tile"])
	var out := {"roost": {}, "stone": {}, "pip": {}}

	# The Roost: the elite slinger's place first, then the goblin camps from the farthest in, then any open place.
	var tries: Array = []         # [[pocket, group]]
	for k in groups.size():
		if (groups[k]["members"] as Array).any(func(m): return str(m[0]) == "slinger" and bool(m[1])):
			tries.append([int(groups[k]["pocket"]), k])
	var camps: Array = []
	for k in groups.size():
		if str(groups[k]["what"]) == "goblins" and str(groups[k]["site"]) == "":
			camps.append([int(groups[k]["pocket"]), k])
	camps.sort_custom(func(a, b): return _far(map, int(a[0]), cave) > _far(map, int(b[0]), cave))
	tries.append_array(camps)
	var open: Array = []
	for i in map.pockets.size():
		var p: Dictionary = map.pockets[i]
		if not bool(p.get("sealed", false)) and str(p.get("site", "")) == "":
			open.append([i, -1])
	open.sort_custom(func(a, b): return _far(map, int(a[0]), cave) > _far(map, int(b[0]), cave))
	tries.append_array(open)
	for pair in tries:
		var p: Dictionary = map.pockets[int(pair[0])]
		var at: Vector2 = p["at"]
		var tile := LootPlan._stand(map, at, at, maxf(float(p["rx"]), float(p["ry"])), 9, taken, CAGE_WIDE)
		if tile.x < 0:
			continue
		var group := int(pair[1])
		if group < 0:
			for k in groups.size():
				if int(groups[k]["pocket"]) == int(pair[0]):
					group = k
		out["roost"] = {"pocket": int(pair[0]), "group": group, "tile": tile, "foot": Vector2(tile.x * 16 + 8, tile.y * 16 + 12)}
		taken.append(tile)
		break

	# The waystone: outside the Watchpost, on the side you come to it from.
	if map.sites.has("watchpost"):
		var pocket := int(map.sites["watchpost"]["pocket"])
		var p: Dictionary = map.pockets[pocket]
		var at: Vector2 = p["at"]
		var d := at.distance_to(cave)
		var want := at
		if d > 0.5:
			want = at - (at - cave) / d * minf(float(p["rx"]), float(p["ry"])) * 0.5
		var tile := Vector2i(-1, -1)
		for need in [9, 6, 4]:
			if tile.x < 0:
				tile = LootPlan._stand(map, at, want, maxf(float(p["rx"]), float(p["ry"])), need, taken, STONE_WIDE)
		if tile.x >= 0:
			var group := -1
			for k in groups.size():
				if int(groups[k]["pocket"]) == pocket:
					group = k
			out["stone"] = {"id": "watchpost", "name": "the Keeper's Watchpost", "pocket": pocket, "group": group, "tile": tile,
				"foot": Vector2(tile.x * 16 + 8, tile.y * 16 + 12)}
			taken.append(tile)

	# Pip's camp: beside the cave mouth, to its right as you look at it, clear of the way in.
	var mouth := Vector2(map.mouth.x + 0.5, map.mouth.y + 0.5)
	var home := Vector2i(-1, -1)
	for want in [mouth + Vector2(4.0, 2.6), mouth + Vector2(-4.0, 2.6), mouth + Vector2(5.0, 4.0), map.spawn + Vector2(3.0, 0.0)]:
		for need in [9, 6]:
			if home.x < 0:
				home = LootPlan._stand(map, map.spawn, want, 8.0, need, taken, 0.0)
	if home.x < 0:
		home = Vector2i(floori(map.spawn.x) + 2, floori(map.spawn.y))
	out["pip"] = {"tile": home, "foot": Vector2(home.x * 16 + 8, home.y * 16 + 12)}
	return out


static func _far(map: LandMap, pocket: int, cave: Vector2) -> float:
	return (map.pockets[pocket]["at"] as Vector2).distance_to(cave)
