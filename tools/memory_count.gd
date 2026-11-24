extends RefCounted
## How much Memory a world holds on the way to Rattlecrown, ring by ring (version 51). The levelling curve
## (scripts/highlands/levels.gd, FIRST_LEVEL and LEVEL_STEP) is set against these sums: `tools/memory_sum.gd` prints
## them, and tests/highlands_levels.gd checks the curve against two worlds.
##
## For each world: the Memory in chests, in enemies and in ore, for the inner, middle and outer ring and the
## Scrapyard; what lies within NEAR tiles of the walk from the cave past the three Warhorn elites to the Scrapyard's
## gate; and three ways of playing:
##   - straight there: the inner ring cleared once, then only what lies by the walk (the Warhorn's three elites
##     included), then the Scrapyard's rooms;
##   - a usual run: the inner ring, half of the middle ring, what lies by the walk in the outer ring, the Scrapyard;
##   - everything: every chest and every enemy once.
## Ore: every player mines MINED of the ore that lies by the way they go (1 Memory a piece, to the miner only).
## Rooms and enemies that fill again are not counted.

const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const FoePlan := preload("res://scripts/highlands/foe_plan.gd")
const LootPlan := preload("res://scripts/highlands/loot_plan.gd")
const CrownPlan := preload("res://scripts/highlands/crown_plan.gd")
const Loot := preload("res://scripts/highlands/loot.gd")
const Levels := preload("res://scripts/highlands/levels.gd")

const NEAR := 15.0      # tiles either side of the walk that somebody passing would take in
const MINED := 0.25     # the share of the ore by the way that gets mined
const MIDDLE_SHARE := 0.5
const DX := [1, -1, 0, 0]
const DY := [0, 0, 1, -1]

const size := LandMap.SIZE


static func _ring(at: Vector2, centre: Vector2) -> int:
	var d := at.distance_to(centre)
	if d < WorldGen.RINGS[1]:
		return 0
	if d < WorldGen.RINGS[2]:
		return 1
	return 2


## One world's sums: {inner, middle, outer, yard, straight, usual, all, lines: [what to print]}.
static func world(seed_value: int) -> Dictionary:
	var map: LandMap = WorldGen.make(seed_value)
	var centre := Vector2(map.base_at)
	var groups := FoePlan.make(map)
	var chests := LootPlan.make(map, groups)
	var crown := CrownPlan.make(map)
	var yard_groups: Array = crown.get("groups", []) if crown.get("ok", false) else []
	var yard_chests: Array = crown.get("chests", []) if crown.get("ok", false) else []
	var gate: Vector2i = crown.get("gate", Vector2i(LandMap.MID, LandMap.MID))
	# The walk: from the cave to each elite that holds a piece of the Warhorn (the gate wants the horn), nearest
	# first, and on to the gate.
	var stops: Array = []
	for g in groups:
		for mem in g["members"]:
			if bool(mem[1]) and Loot.HORN.has(str(mem[0])):
				stops.append(Vector2i(g["home"]))
	var here := Vector2i(map.spawn)
	var near := PackedByteArray()
	near.resize(size * size)
	while true:
		var next := gate
		if not stops.is_empty():
			stops.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(Vector2(here)) < Vector2(b).distance_to(Vector2(here)))
			next = stops.pop_front()
		_near_walk(map, here, next, near)
		here = next
		if next == gate:
			break
	# [chests, foes, ore] for inner, middle, outer; and the same for only what lies by the walk.
	var all := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	var by := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for c in chests:
		var t: Vector2 = Vector2(c["tile"])
		var r := _ring(t, centre)
		all[r][0] += float(c["memory"])
		if _by(near, t):
			by[r][0] += float(c["memory"])
	for g in groups:
		var m := 0.0
		for mem in g["members"]:
			m += float(Loot.ELITE_MEMORY) if bool(mem[1]) else float(Loot.MEMORY_FOR.get(str(mem[0]), 0))
		var t: Vector2 = g["home"]
		var r := _ring(t, centre)
		all[r][1] += m
		if _by(near, t):
			by[r][1] += m
	for y in size:
		for x in size:
			var k := map.kinds[y * size + x]
			if k == LandMap.TIN or k == LandMap.COPPER:
				var t := Vector2(x, y)
				var r := _ring(t, centre)
				all[r][2] += 1.0
				if _by(near, t):
					by[r][2] += 1.0
	var yard := 0.0
	for g in yard_groups:
		for mem in g["members"]:
			yard += float(Loot.ELITE_MEMORY) if bool(mem[1]) else float(Loot.MEMORY_FOR.get(str(mem[0]), 0))
	for c in yard_chests:
		yard += float(c["memory"])
	var inner: float = all[0][0] + all[0][1] + all[0][2] * MINED
	var straight: float = inner + by[1][0] + by[1][1] + by[1][2] * MINED + by[2][0] + by[2][1] + by[2][2] * MINED + yard
	var middle_half: float = (all[1][0] + all[1][1] + all[1][2] * MINED) * MIDDLE_SHARE
	var middle_rest: float = maxf(by[1][0] + by[1][1] + by[1][2] * MINED, middle_half)
	var usual: float = inner + middle_rest + by[2][0] + by[2][1] + by[2][2] * MINED + yard
	var every: float = yard
	for r in 3:
		every += all[r][0] + all[r][1] + all[r][2] * MINED
	var lines: Array = []
	lines.append("world %d (gate %d tiles out): inner chests %d foes %d ore %d | middle %d %d %d (by the walk %d %d %d) | outer %d %d %d (by the walk %d %d %d) | Scrapyard %d" % [
		seed_value, roundi(Vector2(gate).distance_to(centre)),
		all[0][0], all[0][1], all[0][2], all[1][0], all[1][1], all[1][2], by[1][0], by[1][1], by[1][2],
		all[2][0], all[2][1], all[2][2], by[2][0], by[2][1], by[2][2], yard])
	lines.append("    straight there %d (level %d), usual %d (level %d), everything %d (level %d)" % [straight, level_of(straight), usual, level_of(usual), every, level_of(every)])
	return {"straight": straight, "usual": usual, "all": every, "inner": inner,
		"middle": all[1][0] + all[1][1] + all[1][2] * MINED, "outer": all[2][0] + all[2][1] + all[2][2] * MINED, "yard": yard, "lines": lines}


static func _by(near: PackedByteArray, t: Vector2) -> bool:
	var x := clampi(int(t.x), 0, size - 1)
	var y := clampi(int(t.y), 0, size - 1)
	return near[y * size + x] == 1


## Marks every tile within NEAR tiles of the shortest walk from `from` to `to` (rock may be dug, so the walk goes through
## open ground where it can and through rock at a cost of 4 a tile where it must).
static func _near_walk(map: LandMap, from: Vector2i, to: Vector2i, near: PackedByteArray) -> void:
	var n := size * size
	var best := PackedInt32Array()
	best.resize(n)
	best.fill(1 << 30)
	var back := PackedInt32Array()
	back.resize(n)
	back.fill(-1)
	# A bucket queue (costs 1 or 4).
	var buckets: Array = []
	for i in 8:
		buckets.append([])
	var start := from.y * size + from.x
	var goal := to.y * size + to.x
	best[start] = 0
	(buckets[0] as Array).append(start)
	var cost := 0
	var left := 1
	while left > 0:
		var b: Array = buckets[cost % 8]
		buckets[cost % 8] = []
		left -= b.size()
		for i: int in b:
			if best[i] != cost:
				continue
			if i == goal:
				left = 0
				break
			var x := i % size
			var y := i / size
			for d in 4:
				var nx: int = x + DX[d]
				var ny: int = y + DY[d]
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var k := map.kinds[ny * size + nx]
				if k == LandMap.WATER:
					continue
				var step := 4 if LandMap.rocky(k) else 1
				var j := ny * size + nx
				if cost + step < best[j]:
					best[j] = cost + step
					back[j] = i
					(buckets[(cost + step) % 8] as Array).append(j)
					left += 1
		cost += 1
	var at := goal
	var r := int(NEAR)
	var steps := 0
	while at != -1:
		if steps % 4 == 0:
			var x := at % size
			var y := at / size
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy <= r * r:
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < size and ny < size:
							near[ny * size + nx] = 1
		at = back[at]
		steps += 1


## The squad's level after this much Memory from each player.
static func level_of(m: float) -> int:
	var lv := 0
	var need := Levels.need(0)
	while m >= need and need > 0.0:
		m -= need
		lv += 1
		need = Levels.need(lv)
	return lv
