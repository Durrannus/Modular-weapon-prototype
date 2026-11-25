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
##   - Elites are rare. Since version 49 the Hound Den is "a pack fight led by the Elite Cliff Hound", and the Slinger
##     Roost is "led by the Elite Pebble Slinger". The elite shaman has no place of its own yet, so it holds one open
##     place in the outer ring (Claude's choice).
##   - GOBLIN GROUND ROUND THE SCRAPYARD (Darren, 25 November 2026: "I want the goblins to spawn more around the scrap
##     boss area"; version 61). Every open place within SCRAP_REACH tiles of the Scrapyard gate has goblins living in
##     it (none is left empty, no hounds), a Scrap Brute leads most of them and a Shaman stands at the back of more
##     (SCRAP_BRUTE, SCRAP_SHAMAN), and the watch on the gate is bigger. (Claude's: how far, and those shares. The
##     Old Quarry and the Watchpost keep theirs; the Den and the Roost are not that near.)
##   - Farther out is harder (the research's rings; the numbers are Claude's): in the middle ring hound packs are
##     three or four and more goblin groups have a Brute or a Shaman; in the outer ring packs are up to five,
##     goblin groups are bigger still, and fewer places are empty. See RINGS.
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
static var SCRAP_REACH := 90.0 # tiles round the Scrapyard gate that are goblin ground (version 61)
static var SCRAP_BRUTE := 0.8  # there, how many groups a Scrap Brute leads ...
static var SCRAP_SHAMAN := 0.6 # ... and how many have a Shaman at the back
static var BRUTE_SHARE := 0.3  # of goblin groups, how many a Scrap Brute leads
static var SHAMAN_SHARE := 0.3 # and how many have a Shaman at the back
## The middle and the outer ring: the share of empty places; how many hounds a pack has at least and at most; of goblin
## groups, how many a Brute leads and how many have a Shaman; how many slingers at least and at most.
static var RINGS := [{}, {},
	{"empty": 0.30, "hounds": [3, 4], "brute": 0.45, "shaman": 0.40, "slingers": [2, 3]},
	{"empty": 0.25, "hounds": [3, 5], "brute": 0.60, "shaman": 0.50, "slingers": [3, 4]}]


static func make(map: LandMap) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldGen._mix(map.seed_value & 0xffffffff, map.seed_value >> 32, 3000)
	var cave := Vector2(LandMap.MID + 0.5, LandMap.MID + 0.5)
	var yard: Vector2 = map.sites["scrapyard"]["at"] if map.sites.has("scrapyard") else Vector2.INF
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
		var ring := int(p.get("ring", 1))
		if g["site"] == "roost":
			g["what"] = "goblins"
			g["members"] = [["slinger", true], ["slinger", false], ["slinger", false], ["slinger", false], ["scrap_brute", false]]
		elif g["site"] == "den":
			g["what"] = "hounds"
			g["members"] = [["hound", true], ["hound", false], ["hound", false], ["hound", false]]
		elif g["site"] == "scrapyard":
			# The ground in front of the gate: goblins on watch (a bigger watch since version 61).
			g["what"] = "goblins"
			g["members"] = [["scrap_brute", false], ["slinger", false], ["slinger", false], ["slinger", false], ["shaman", false]]
		elif not (g["site"] in ["watchpost", "quarry"]) and at.distance_to(yard) < SCRAP_REACH:
			# Goblin ground round the Scrapyard: never empty, never hounds, mostly led by a Brute (version 61).
			g["what"] = "goblins"
			var rule: Dictionary = RINGS[maxi(ring, 2)]
			var brute := brute_roll < float(SCRAP_BRUTE) and not small
			var shaman := shaman_roll < float(SCRAP_SHAMAN) and not small
			var lo: int = rule["slingers"][0]
			var hi: int = rule["slingers"][1]
			var slingers := lo + mini(int(size_roll * float(hi - lo + 1)), hi - lo)
			if small or ring < 2:
				slingers = 2
			if brute:
				g["members"].append(["scrap_brute", false])
			for k in slingers:
				g["members"].append(["slinger", false])
			if shaman:
				g["members"].append(["shaman", false])
		elif ring >= 2:
			var rule: Dictionary = RINGS[ring]
			if roll < float(rule["empty"]):
				continue
			var spare := 1.0 - float(rule["empty"])
			if roll < float(rule["empty"]) + spare * 0.4:
				g["what"] = "hounds"
				var lo: int = rule["hounds"][0]
				var hi: int = rule["hounds"][1]
				var n := lo + mini(int(size_roll * float(hi - lo + 1)), hi - lo)
				if small:
					n = lo - 1
				for k in n:
					g["members"].append(["hound", false])
			else:
				g["what"] = "goblins"
				var brute := brute_roll < float(rule["brute"]) and not small
				var shaman := shaman_roll < float(rule["shaman"]) and not small
				var lo: int = rule["slingers"][0]
				var hi: int = rule["slingers"][1]
				var slingers := lo + mini(int(size_roll * float(hi - lo + 1)), hi - lo)
				if small:
					slingers = 2
				if brute:
					g["members"].append(["scrap_brute", false])
				for k in slingers:
					g["members"].append(["slinger", false])
				if shaman:
					g["members"].append(["shaman", false])
		elif g["site"] == "watchpost":
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
		# The three world elites who carry the Rusted Warhorn's pieces (Darren, 24 November: the body from the Elite
		# Scrap Brute at the Old Quarry, the bell from the Elite Cliff Hound at the Hound Den, the mouthpiece from the
		# Elite Pebble Slinger at the Slinger Roost; no other elite, and never the Scrapyard's or Rattlecrown's).
		if g["site"] in ["quarry", "den", "roost"]:
			g["horn"] = true
		out.append(g)
	_elites(map, out, rng, cave)
	for k in out.size():
		out[k]["id"] = k
	return out


## The elites with no place of their own each take over one far group: since version 49 only the elite shaman, in
## the outer ring. (A land made without its outer rings, by one of the tools, has no Den or Roost: there all three
## take far groups as they did before.)
static func _elites(map: LandMap, out: Array, rng: RandomNumberGenerator, cave: Vector2) -> void:
	var held: Array = []
	for g in out:
		if str(g["site"]) in ["quarry", "roost", "den"]:
			held.append(g["home"])
	var bands: Array = []
	var from := ELITE_FAR
	if not map.sites.has("den"):
		bands.append([["hound", true], ["hound", false], ["hound", false]])
	if not map.sites.has("roost"):
		bands.append([["slinger", true], ["slinger", false], ["slinger", false]])
	if map.sites.has("scrapyard"):
		from = WorldGen.RINGS[2] + 10.0
	bands.append([["shaman", true], ["scrap_brute", false], ["slinger", false], ["slinger", false]])
	for band in bands:
		var start := rng.randi()
		var best := -1
		for step in out.size():
			var k := (start + step) % maxi(out.size(), 1)
			var g: Dictionary = out[k]
			if str(g["site"]) != "" or (g["home"] as Vector2).distance_to(cave) < from or float(g["r"]) < 4.3:
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
		out[best]["horn"] = str(band[0][0]) in ["hound", "slinger"]      # (standing in for the Den's or the Roost's)
		held.append(out[best]["home"])


## How many of each kind a plan holds, for the tests and the README: {"hound": n, "hound_elite": n, ...}.
static func count(plan: Array) -> Dictionary:
	var out := {}
	for g in plan:
		for m in g["members"]:
			var name := str(m[0]) + ("_elite" if bool(m[1]) else "")
			out[name] = int(out.get(name, 0)) + 1
	return out
