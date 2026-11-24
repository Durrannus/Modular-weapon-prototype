extends SceneTree
## Prints how much Memory a world holds on the way to Rattlecrown, and the level that comes to (version 51). The
## sums and the three ways of playing are explained in tools/memory_count.gd.
##
##   godot --headless --path . -s tools/memory_sum.gd [-- seeds=8]

const Count := preload("res://tools/memory_count.gd")
const Levels := preload("res://scripts/highlands/levels.gd")


func _init() -> void:
	var seeds := 8
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.substr(6))
	var to_five := 0.0
	for lv in 5:
		to_five += Levels.need(lv)
	print("level 5 needs %d Memory from each player (FIRST_LEVEL %d, LEVEL_STEP %d)" % [to_five, Levels.FIRST_LEVEL, Levels.LEVEL_STEP])
	var rows: Array = []
	for s in seeds:
		var row: Dictionary = Count.world(424242 + s * 7919)
		for line in row["lines"]:
			print(line)
		rows.append(row)
	print("")
	print("mean over %d worlds:" % rows.size())
	for k in ["inner", "middle", "outer", "yard", "straight", "usual", "all"]:
		var t := 0.0
		for r in rows:
			t += float(r[k])
		t /= float(rows.size())
		print("  %-9s %5d Memory%s" % [k, roundi(t), "  -> level %d" % Count.level_of(t) if k in ["straight", "usual", "all"] else ""])
	quit()
