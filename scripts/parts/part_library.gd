extends RefCounted

const PartData := preload("res://scripts/parts/part_data.gd")
## Loads every part file in res://parts/.

const PARTS_DIR := "res://parts/"


static func load_all() -> Array:
	var parts: Array = []
	var dir := DirAccess.open(PARTS_DIR)
	if dir == null:
		push_error("Could not open %s" % PARTS_DIR)
		return parts
	for f in dir.get_files():
		var file_name: String = f
		# Exported builds rename resources to *.tres.remap
		file_name = file_name.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var res = load(PARTS_DIR + file_name)
		if res is PartData:
			parts.append(res)
	parts.sort_custom(func(a, b):
		if a.part_type != b.part_type:
			return a.part_type < b.part_type
		return a.display_name < b.display_name)
	return parts


static func find(parts: Array, id: String) -> PartData:
	for p in parts:
		if p.id == id:
			return p
	return null
