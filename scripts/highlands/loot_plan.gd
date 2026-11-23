extends RefCounted
## Where the chests stand on a Highlands map, and what is in each (version 44). The same map always gives the same
## plan: it has its own dice, started from the map's number, and it changes nothing on the land (so a world saved
## before chests existed is still the same land, and nothing has to be laid out again). It must be made from the
## land AS IT WAS MADE, before a save's digging and felling are done to it again: otherwise a felled pine could
## move a chest.
##
## The rules, from the Game Bible:
##   - "Random chests, scattered around": "usually tin or copper bars, coins and Memory".
##   - "Not every place is a quest. Some places are just enemies plus a chest with a random, modest reward."
##   - Chests opened are saved with the world.
## And Claude's choices, until Darren says otherwise:
##   - About half the places somebody lives in have a chest, at the back of the place (the far side from the cave),
##     and a few of the empty ones.
##   - Every sealed place (the ones only a pickaxe finds) has one, and it is a richer one: digging in is paid for.
##   - The Keeper's Watchpost and the Old Quarry each have a richer one.
##   - The open place nearest the cave always has a small one, so the first chest is met in the safe hills.
##   - Nearer the cave the bars are mostly tin; farther out mostly copper. A richer chest holds both.
##   - ACCESSORIES are in some chests since version 47 (the Bible: "sometimes a tier 1 accessory"): the first chest
##     always holds one, so the satchel is met in the safe hills; a richer chest holds one about half the time
##     and any other about one time in seven. Which one is the chest's own roll (`gift`).
##   - Blank rune stones and the unique parts are NOT in the chests yet: there is no anvil to do anything with them.
##
## A chest: {id (its place's number: what the world save keeps), pocket, kind: "first", "plain", "guarded", "sealed"
## or "site", tile, foot (art pixels), coins, memory, items: [[what, how many]], gift: an accessory or ""}.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const FoePlan := preload("res://scripts/highlands/foe_plan.gd")
const Accessories := preload("res://scripts/highlands/accessories.gd")

static var GUARDED_SHARE := 0.5    # of the places somebody lives in, how many have a chest
static var EMPTY_SHARE := 0.2      # of the places nobody lives in, beyond the safe hills
static var COINS_MIN := 8
static var COINS_MAX := 18
static var BARS_MIN := 1
static var BARS_MAX := 3
static var MEMORY := 15
static var RICH := 2.5             # a sealed place's chest and a named place's hold this many times the coins and Memory
static var FIRST := 0.6            # and the first one, by the cave, this share
static var GIFT := 0.15            # how often a chest holds an accessory ...
static var RICH_GIFT := 0.5        # ... and a richer one (the first chest always does)
const FIRST_FROM := 12.0           # tiles from the cave: the first chest is in the nearest place at least this far out
const TALL := 30                   # a thing at least this tall (art pixels) would hide a chest standing behind it


## `groups` is the enemies' plan for the same map (foe_plan.gd): a chest knows whether somebody guards it.
static func make(map: LandMap, groups: Array) -> Array:
	Painter.load_kit()
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldGen._mix(map.seed_value & 0xffffffff, map.seed_value >> 32, 4400)
	var cave := Vector2(LandMap.MID + 0.5, LandMap.MID + 0.5)
	var lived := {}
	for g in groups:
		lived[int(g["pocket"])] = true
	# The first chest: the nearest plain open place that is not right at the cave's door.
	var first := -1
	var first_d := INF
	for i in map.pockets.size():
		var p: Dictionary = map.pockets[i]
		var d: float = (p["at"] as Vector2).distance_to(cave)
		if bool(p.get("sealed", false)) or str(p.get("site", "")) != "" or lived.has(i) or d < FIRST_FROM:
			continue
		if d < first_d:
			first_d = d
			first = i
	var out: Array = []
	for i in map.pockets.size():
		var p: Dictionary = map.pockets[i]
		# Every place rolls its dice whether or not it is used, so one place changing does not move the rest.
		var roll := rng.randf()
		var at: Vector2 = p["at"]
		var d := at.distance_to(cave)
		var kind := ""
		if str(p.get("site", "")) in ["watchpost", "quarry"]:
			kind = "site"
		elif bool(p.get("sealed", false)):
			kind = "sealed"
		elif i == first:
			kind = "first"
		elif d < FoePlan.SAFE:
			continue
		elif lived.has(i):
			if roll < GUARDED_SHARE:
				kind = "guarded"
		elif roll < EMPTY_SHARE:
			kind = "plain"
		if kind == "":
			continue
		# At the back of the place, as seen coming from the cave. A sealed place's is in its middle.
		var want := at
		if kind != "sealed" and d > 0.5:
			want = at + (at - cave) / d * minf(float(p["rx"]), float(p["ry"])) * 0.55
		var tile := _stand(map, at, want, maxf(float(p["rx"]), float(p["ry"])))
		if tile.x < 0 and kind == "sealed":
			# A sealed place can be small and crowded, and nobody has to get through it: less room will do.
			for need in [6, 4]:
				if tile.x < 0:
					tile = _stand(map, at, want, maxf(float(p["rx"]), float(p["ry"])), need)
		if tile.x < 0:
			continue
		var c := {"id": i, "pocket": i, "kind": kind, "tile": tile, "foot": Vector2(tile.x * 16 + 8, tile.y * 16 + 12)}
		c.merge(_holds(map.seed_value, i, kind, d >= FoePlan.NEAR))
		out.append(c)
	return out


## What one chest holds: {coins, memory, items}. Each chest has dice of its own, so one chest's roll never moves
## another's.
static func _holds(seed_value: int, id: int, kind: String, far: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldGen._mix(seed_value & 0xffffffff, id, 4401)
	var share := RICH if kind in ["sealed", "site"] else (FIRST if kind == "first" else 1.0)
	var coins := roundi(float(rng.randi_range(COINS_MIN, COINS_MAX)) * share * (1.3 if far else 1.0))
	var memory := roundi(float(MEMORY) * share * (1.3 if far else 1.0))
	var copper := rng.randf() < (0.6 if far else 0.3)
	var bars := rng.randi_range(BARS_MIN, BARS_MAX)
	var more := rng.randi_range(BARS_MIN, BARS_MAX)
	var items: Array = []
	if kind in ["sealed", "site"]:
		items = [["tin_bar", bars + 1], ["copper_bar", more + 1]]
	elif kind == "first":
		items = [["tin_bar", 1]]
	else:
		items = [["copper_bar" if copper else "tin_bar", bars]]
	# The accessory: rolled last, so that what chests held before version 47 is what they hold now.
	var roll := rng.randf()
	var pick := rng.randi_range(0, Accessories.POOL.size() - 1)
	var chance := 1.0 if kind == "first" else (RICH_GIFT if kind in ["sealed", "site"] else GIFT)
	return {"coins": maxi(coins, 1), "memory": maxi(memory, 1), "items": items, "gift": str(Accessories.POOL[pick]) if roll < chance else ""}


## The tile for a chest in an open place: one that can be walked to from the place's middle, with open ground all
## round it (so it never plugs a narrow way, and can always be walked round), clear of everything that stands there,
## and not hidden behind a pine. The one nearest to `want`. (-1, -1) if the place has none. `need` is how many of
## the nine tiles at and round it must be open ground: all of them, unless told otherwise. `avoid` is tiles that
## are spoken for (other chests, and what folk_plan.gd stands): nothing goes within two tiles of one. `wide` is how
## much farther to the right than a chest the thing reaches (art pixels): that ground is kept clear as well.
static func _stand(map: LandMap, middle: Vector2, want: Vector2, r: float, need := 9, avoid: Array = [], wide := 0.0) -> Vector2i:
	var far := clampi(ceili(r) + 2, 4, 12)
	var c := Vector2i(floori(middle.x), floori(middle.y))
	# The place's own ground: what can be walked to from its middle without leaving it.
	var start := Vector2i(-1, -1)
	for ring in range(0, 4):
		for j in range(-ring, ring + 1):
			for i in range(-ring, ring + 1):
				if start.x < 0 and maxi(absi(i), absi(j)) == ring and map.walkable(c.x + i, c.y + j):
					start = c + Vector2i(i, j)
	if start.x < 0:
		return Vector2i(-1, -1)
	var seen := {start: true}
	var stack: Array = [start]
	while not stack.is_empty():
		var at: Vector2i = stack.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = at + step
			if seen.has(n) or maxi(absi(n.x - c.x), absi(n.y - c.y)) > far or not map.walkable(n.x, n.y):
				continue
			seen[n] = true
			stack.append(n)
	# What stands near, and the plants.
	var things: Array = []
	var plants: Array = []
	var c0 := Vector2i(floori(float(c.x - far - 6) / LandMap.CHUNK), floori(float(c.y - far - 6) / LandMap.CHUNK))
	var c1 := Vector2i(floori(float(c.x + far + 6) / LandMap.CHUNK), floori(float(c.y + far + 10) / LandMap.CHUNK))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			things.append_array(map.things_in(cx, cy))
			plants.append_array(map.plants_in(cx, cy))
	var best := Vector2i(-1, -1)
	var best_d := INF
	var tiles: Array = seen.keys()
	tiles.sort()      # (a dictionary keeps the order things went in, which is already the same every time; this says so)
	for t: Vector2i in tiles:
		var d := (Vector2(t) + Vector2(0.5, 0.5)).distance_to(want)
		if d >= best_d:
			continue
		var open := 0
		for j in range(-1, 2):
			for i in range(-1, 2):
				if map.walkable(t.x + i, t.y + j):
					open += 1
		if open < need:
			continue
		var near := false
		for other: Vector2i in avoid:
			if maxi(absi(other.x - t.x), absi(other.y - t.y)) <= 2:
				near = true
		if near:
			continue
		var foot := Vector2(t.x * 16 + 8, t.y * 16 + 12)
		var box := Rect2(foot.x - 12.0, foot.y - 16.0, 24.0 + wide, 20.0)      # the chest and a little room round it
		var clear := true
		for th in things:
			var info: Dictionary = Painter.things.get(str(th["n"]), {})
			if info.is_empty():
				continue
			var tf := Vector2(float(th["x"]), float(th["y"]))
			var ground := Rect2(tf.x - 7.0, tf.y - 8.0, 14.0, 10.0)
			if info.has("solid"):
				var s: Array = info["solid"]
				ground = Rect2(tf.x - float(s[0]) * 0.5 - 4.0, tf.y - float(s[1]) - 4.0, float(s[0]) + 8.0, float(s[1]) + 8.0)
			if ground.intersects(box):
				clear = false
				break
			# Something tall that stands in front of it would hide it.
			var rect: Array = info.get("rect", [0, 0, 0, 0])
			if int(rect[3]) >= TALL and tf.y > foot.y and tf.y - float(rect[3]) < foot.y and absf(tf.x - foot.x) < float(rect[2]) * 0.5 + 8.0:
				clear = false
				break
		if not clear:
			continue
		for pl in plants:
			var dx := float(pl["x"]) - foot.x
			if dx > -12.0 and dx < 12.0 + wide and absf(float(pl["y"]) - foot.y) < 9.0:
				clear = false
				break
		if not clear:
			continue
		best = t
		best_d = d
	return best


## How many chests of each kind a plan holds, for the tests and the README: {"guarded": n, ...}.
static func count(plan: Array) -> Dictionary:
	var out := {}
	for c in plan:
		out[str(c["kind"])] = int(out.get(str(c["kind"]), 0)) + 1
	return out
