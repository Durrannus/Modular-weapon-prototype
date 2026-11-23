extends RefCounted
## Which enemies live where on a Highlands map (version 43). The same map always gives the same plan: it has its
## own dice, started from the map's number, and it changes nothing on the land (so a world saved before enemies
## existed is still the same land).
##
## The rules, from the Game Bible:
##   - Nothing lives near the cave: the base and the first open places round it are safe.
##   - Cliff Hounds: "a mix of pairs and packs of three or four". Near the base only pairs.
##   - Pebble Slingers in twos and threes.
##   - A Scrap Brute is "uncommon... Usually one at a time, leading a small group of Pebble Slingers... never in
##     packs": at most one in a group, and only in some.
##   - A Goblin Shaman "stays at the back of goblin groups": only ever with other goblins.
##   - The Keeper's Watchpost: "A few Cliff Hounds use it as a den."
##   - The Old Quarry: "A goblin scrap camp guarded by the Elite Scrap Brute."
##   - Elites are rare. The Hound Den and the Slinger Roost are not on the land yet, so until they are, the white
##     pack leader, the elite slinger and the elite shaman each hold one far open place (Claude's choice).
##
## A group: {id, pocket, home (tiles), r (tiles), members: [[kind, elite]], what: "hounds" or "goblins", site}.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")

const SAFE := 40.0             # tiles from the cave: nothing lives nearer
const NEAR := 72.0             # out to here the groups are small
const ELITE_FAR := 84.0        # the roaming elites live at least this far out
const ELITE_APART := 40.0      # and this far from each other and from the Quarry
static var EMPTY_NEAR := 0.5   # the share of open places with nothing in them, near the base and farther out
static var EMPTY_FAR := 0.3
static var BRUTE_SHARE := 0.3  # of goblin groups, how many a Scrap Brute leads
static var SHAMAN_SHARE := 0.3 # and how many have a Shaman at the back


static func make(map: LandMap) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldGen._mix(map.seed_value & 0xffffffff, map.seed_value >> 32, 3000)
	var cave := Vector2(LandMap.MID + 0.5, LandMap.MID + 0.5)
	var out: Array = []
	for i in map.pockets.size():
		var p: Dictionary = map.pockets[i]
		# Every place rolls its dice whether or not it is used, so one place changing does not move the rest.
		var roll := rng.randf()
		var size_roll := rng.randf()
		var brute_roll := rng.randf()
		var shaman_roll := rng.randf()
		var at: Vector2 = p["at"]
		var d := at.distance_to(cave)
		if bool(p.get("sealed", false)) or d < SAFE:
			continue
		var small := float(p["rx"]) < 4.3 and not bool(p.get("glen", false))
		var g := {"id": out.size(), "pocket": i, "home": at, "r": maxf(float(p["rx"]), float(p["ry"])), "members": [], "what": "", "site": str(p.get("site", ""))}
		if g["site"] == "watchpost":
			g["what"] = "hounds"
			g["members"] = [["hound", false], ["hound", false], ["hound", false]]
		elif g["site"] == "quarry":
			g["what"] = "goblins"
			g["members"] = [["scrap_brute", true], ["slinger", false], ["slinger", false]]
		elif d < NEAR:
			if roll < EMPTY_NEAR:
				continue
			if roll < EMPTY_NEAR + (1.0 - EMPTY_NEAR) * 0.6:
				g["what"] = "hounds"
				g["members"] = [["hound", false], ["hound", false]]
			else:
				g["what"] = "goblins"
				g["members"] = [["slinger", false], ["slinger", false]]
		else:
			if roll < EMPTY_FAR:
				continue
			if roll < EMPTY_FAR + (1.0 - EMPTY_FAR) * 0.4:
				g["what"] = "hounds"
				var n := 2 if size_roll < 0.4 else (3 if size_roll < 0.75 else 4)
				if small:
					n = 2
				for k in n:
					g["members"].append(["hound", false])
			else:
				g["what"] = "goblins"
				var brute := brute_roll < BRUTE_SHARE and not small
				var shaman := shaman_roll < SHAMAN_SHARE and not small
				var slingers := 2 if (size_roll < 0.5 or small or (brute and shaman)) else 3
				if brute:
					g["members"].append(["scrap_brute", false])
				for k in slingers:
					g["members"].append(["slinger", false])
				if shaman:
					g["members"].append(["shaman", false])
		out.append(g)
	_elites(map, out, rng, cave)
	for k in out.size():
		out[k]["id"] = k
	return out


## The three elites with no place of their own yet each take over one far group (or an empty far place).
static func _elites(map: LandMap, out: Array, rng: RandomNumberGenerator, cave: Vector2) -> void:
	var held: Array = []
	for g in out:
		if str(g["site"]) == "quarry":
			held.append(g["home"])
	var bands := [
		[["hound", true], ["hound", false], ["hound", false]],
		[["slinger", true], ["slinger", false], ["slinger", false]],
		[["shaman", true], ["scrap_brute", false], ["slinger", false], ["slinger", false]],
	]
	for band in bands:
		var start := rng.randi()
		var best := -1
		for step in out.size():
			var k := (start + step) % maxi(out.size(), 1)
			var g: Dictionary = out[k]
			if str(g["site"]) != "" or (g["home"] as Vector2).distance_to(cave) < ELITE_FAR or float(g["r"]) < 4.3:
				continue
			if (g["members"] as Array).any(func(m): return bool(m[1])):
				continue
			var ok := true
			for h in held:
				if (g["home"] as Vector2).distance_to(h) < ELITE_APART:
					ok = false
			if ok:
				best = k
				break
		if best < 0:
			continue
		out[best]["members"] = band.duplicate(true)
		out[best]["what"] = "hounds" if str(band[0][0]) == "hound" else "goblins"
		held.append(out[best]["home"])


## How many of each kind a plan holds, for the tests and the README: {"hound": n, "hound_elite": n, ...}.
static func count(plan: Array) -> Dictionary:
	var out := {}
	for g in plan:
		for m in g["members"]:
			var name := str(m[0]) + ("_elite" if bool(m[1]) else "")
			out[name] = int(out.get(name, 0)) + 1
	return out
