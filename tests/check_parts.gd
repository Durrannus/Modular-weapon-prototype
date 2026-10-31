extends SceneTree
## Checks that every part in res://parts/ fits its own area of the sword grid
## without rotating. Run from the project folder:
##   godot --headless --script res://tests/check_parts.gd

func _initialize() -> void:
	var parts := PartLibrary.load_all()
	var fails := 0
	for p in parts:
		var b := WeaponBuild.new()
		var spots := 0
		for y in WeaponBuild.GRID_H:
			for x in WeaponBuild.GRID_W:
				if b.can_place(p, Vector2i(x, y), 0):
					spots += 1
		var status := "ok" if spots > 0 else "DOES NOT FIT"
		print("%-18s %-7s %s (%d spots)" % [p.id, p.type_name(), status, spots])
		if spots == 0:
			fails += 1
	print("%d parts checked, %d don't fit" % [parts.size(), fails])
	quit(1 if fails > 0 else 0)
