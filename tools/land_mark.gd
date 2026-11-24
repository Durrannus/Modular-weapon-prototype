extends SceneTree
## Prints a fingerprint of the land each seed makes, and how long it took. For changing the land's maker without
## changing the land: run it before and after, and the lines must be the same.
##
##   godot --headless --path . -s tools/land_mark.gd -- seeds=1,2,3
##
## With HL_TIMES=1 in the environment the maker prints how long each of its steps took as well.

const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")


func _init() -> void:
	var seeds: Array = [1, 2, 3, 424242]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = []
			for s in a.substr(6).split(","):
				seeds.append(int(s))
	var total := 0
	for s in seeds:
		var t0 := Time.get_ticks_msec()
		var m: LandMap = WorldGen.make(int(s))
		var ms := Time.get_ticks_msec() - t0
		total += ms
		print("seed %d: %s  inner %s  (%d ms, layout %d, %d places, %d ways, %d things, %d plants, %d ore clusters)" % [int(s), mark(m), inner_mark(m), ms, m.tries, m.pockets.size(),
			m.links.size(), m.things.size(), m.plants.size(), m.veins.size()])
	print("%d ms a world" % (total / maxi(seeds.size(), 1)))
	quit()


static func mark(m: LandMap) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(m.kinds)
	ctx.update(m.tones)
	var places: Array = []
	for p in m.pockets:
		places.append([p["at"], p["rx"], p["ry"], p["sealed"], p["gate"], p["site"], p["glen"]])
	for part in [m.things, m.plants, m.decals, m.lamps, m.animals, places, m.links, [m.region, m.mouth, m.spawn, m.base, m.turn]]:
		ctx.update(str(part).to_utf8_buffer())
	return ctx.finish().hex_encode().left(16)


## The same for the inner ring alone: everything within INNER tiles of the cave. (For checking that building the
## rings beyond it did not move anything in it.)
const INNER := 126

static func inner_mark(m: LandMap) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var kinds := PackedByteArray()
	var tones := PackedByteArray()
	for y in range(LandMap.MID - INNER, LandMap.MID + INNER + 1):
		for x in range(LandMap.MID - INNER, LandMap.MID + INNER + 1):
			if (x - LandMap.MID) * (x - LandMap.MID) + (y - LandMap.MID) * (y - LandMap.MID) <= INNER * INNER:
				kinds.append(m.kinds[y * LandMap.SIZE + x])
				tones.append(m.tones[y * LandMap.SIZE + x])
	ctx.update(kinds)
	ctx.update(tones)
	var far := float(INNER * 16)
	var middle := Vector2(LandMap.MID * 16, LandMap.MID * 16)
	for list in [m.things, m.plants, m.decals, m.lamps, m.animals]:
		var near: Array = []
		for t in list:
			if Vector2(float(t["x"]), float(t["y"])).distance_to(middle) <= far:
				near.append(t)
		ctx.update(str(near).to_utf8_buffer())
	var places: Array = []
	for p in m.pockets:
		if (p["at"] as Vector2).distance_to(Vector2(LandMap.MID, LandMap.MID)) <= float(INNER):
			places.append([p["at"], p["rx"], p["ry"], p["sealed"], p["gate"], p["site"], p["glen"]])
	ctx.update(str(places).to_utf8_buffer())
	return ctx.finish().hex_encode().left(16)
