extends SceneTree
## Prints where everything in the Throne Room is (CrownPlan.throne_layout), as JSON, for tools/rattlecrown_kit/bake.py:
##
##   godot --headless --path . -s tools/rattlecrown_kit/layout.gd -- out=/tmp/throne_layout.json

const CrownPlan := preload("res://scripts/highlands/crown_plan.gd")


func _init() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	var text := JSON.stringify(_plain(CrownPlan.throne_layout()), "  ")
	if out == "":
		print(text)
	else:
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		print("wrote ", out)
	quit()


func _plain(v):
	if v is Vector2 or v is Vector2i:
		return [v.x, v.y]
	if v is Rect2i:
		return [v.position.x, v.position.y, v.size.x, v.size.y]
	if v is Array:
		var o: Array = []
		for x in v:
			o.append(_plain(x))
		return o
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _plain(v[k])
		return d
	return v
