extends SceneTree
## Packs the whole game into ONE file that runs with a double-click: no Godot to
## install, nothing to unzip. This is the copy to send to a friend.
##
##   godot --headless --path . -s tools/make_exe.gd -- \
##       template=/path/to/windows_release_x86_64.exe  out="/path/to/Modular Weapon Prototype.exe"
##
## `template` is Godot's own empty game runner for the same Godot version as the
## editor you run this with. It comes in "Export templates" on the Godot download
## page (the .tpz file is a zip; the runner is templates/windows_release_x86_64.exe
## inside it). A Linux runner (linux_release.x86_64) works the same way.
##
## What it does:
##  1. Puts project.godot and every file of the game (scripts, art, parts, scenes,
##     shaders) into one pack, exactly as they are in this folder. Nothing is
##     converted, so the packed game is the same game: the version number in the
##     corner and the online "same copy?" check give the same answer as running
##     the folder in Godot.
##  2. Copies the runner and puts the pack on its end, the way Godot's own export
##     does with "Embed PCK" on (same layout, and the same note in the Windows
##     file's section table saying where the pack is).
##
## Not in the pack: tests/, tools/, the README, and the notes and generator
## scripts inside art/ (.md, .py).

const FOLDERS := ["scripts", "art", "parts", "scenes", "shaders"]
const SKIP_ENDINGS := ["md", "py"]
const PACK_MAGIC := 0x43504447     # "GDPC", the mark Godot looks for
const CLASS_LIST := ".godot/global_script_class_cache.cfg"


func _initialize() -> void:
	var template := ""
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("template="):
			template = a.substr(9)
		elif a.begins_with("out="):
			out = a.substr(4)
	if template == "" or out == "":
		print("Use: -- template=<windows_release_x86_64.exe> out=<the file to make>")
		quit(2)
		return
	quit(_make(template, out))


func _make(template: String, out: String) -> int:
	if not FileAccess.file_exists(template):
		push_error("No runner at %s" % template)
		return 1
	var root_dir := ProjectSettings.globalize_path("res://")

	# 1. The pack.
	var files: Array = ["project.godot"]
	for folder in FOLDERS:
		_list(folder, files)
	files.sort()
	var pack_path := out + ".pack.tmp"
	var packer := PCKPacker.new()
	if packer.pck_start(pack_path, 16) != OK:
		push_error("Could not write %s" % pack_path)
		return 1
	for rel in files:
		if packer.add_file("res://" + rel, root_dir.path_join(rel)) != OK:
			push_error("Could not add %s" % rel)
			return 1
	# A packed game looks for the editor's list of named script classes. This game
	# names none, but the list has to be there: take the editor's, or an empty one.
	var classes := FileAccess.get_file_as_bytes("res://" + CLASS_LIST)
	if classes.is_empty():
		classes = "list=[]\n".to_utf8_buffer()
	if packer.add_file_from_buffer("res://" + CLASS_LIST, classes) != OK or packer.flush() != OK:
		push_error("Could not finish the pack")
		return 1
	var pack := FileAccess.get_file_as_bytes(pack_path)
	DirAccess.remove_absolute(pack_path)
	if pack.size() < 8 or pack.decode_u32(0) != PACK_MAGIC:
		push_error("The pack did not come out right")
		return 1

	# 2. The runner with the pack on its end.
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		push_error("Could not write %s" % out)
		return 1
	f.store_buffer(FileAccess.get_file_as_bytes(template))
	var embed_pos := f.get_position()
	for i in embed_pos % 8:
		f.store_8(0)
	var pack_pos := f.get_position()
	f.store_buffer(pack)
	for i in (f.get_position() - embed_pos + 12) % 8:
		f.store_8(0)
	f.store_64(f.get_position() - pack_pos)   # how far back the pack starts
	f.store_32(PACK_MAGIC)
	var embed_size := f.get_position() - embed_pos
	f.close()

	var note := ""
	var kind := FileAccess.get_file_as_bytes(template).slice(0, 2)
	if kind == "MZ".to_ascii_buffer():
		if not _note_in_windows_file(out, embed_pos, embed_size):
			push_error("Could not mark where the pack is in the Windows file")
			return 1
		note = ", marked in the Windows section table"
	elif OS.get_name() != "Windows":
		FileAccess.set_unix_permissions(out, 493)   # rwxr-xr-x: it may be run
	print("Made %s" % out)
	print("  %d files, pack %.1f MB at byte %d%s" % [files.size() + 1, pack.size() / 1048576.0, pack_pos, note])
	print("  whole file %.1f MB" % ((embed_pos + embed_size) / 1048576.0))
	return 0


func _list(rel_dir: String, into: Array) -> void:
	var dir := DirAccess.open("res://" + rel_dir)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_list(rel_dir + "/" + sub, into)
	for file in dir.get_files():
		if file.begins_with(".") or file.get_extension().to_lower() in SKIP_ENDINGS:
			continue
		into.append(rel_dir + "/" + file)


## A Windows runner carries an empty section called "pck". Godot's export points
## it at the pack (and moves it to the end of the section table, since the pack
## is now the last thing in the file). This does the same, step for step, as
## EditorExportPlatformWindows::fixup_embedded_pck in Godot's source.
func _note_in_windows_file(path: String, start: int, size: int) -> bool:
	if start + size >= 0x100000000:
		return false     # a Windows program can't be 4 GB or more
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return false
	f.seek(0x3c)
	var pe := f.get_32()
	f.seek(pe)
	if f.get_32() != 0x00004550:      # "PE\0\0"
		return false
	var header := pe + 4
	f.seek(header + 2)
	var sections := f.get_16()
	f.seek(header + 16)
	var optional_size := f.get_16()
	var optional := header + 20
	f.seek(optional + 32)
	var alignment := f.get_32()
	f.seek(optional + 56)
	var image_size := f.get_32()
	var table := optional + optional_size
	var found := -1
	for i in sections:
		f.seek(table + i * 40)
		var name := f.get_buffer(8)
		if name == PackedByteArray([0x70, 0x63, 0x6b, 0, 0, 0, 0, 0]):     # "pck"
			found = i
			break
	if found < 1:
		return false
	# The section before it grows to cover the gap the moved section leaves.
	f.seek(table + (found - 1) * 40 + 8)
	var before := f.get_32()
	f.seek(table + (found - 1) * 40 + 8)
	f.store_32(before + alignment)
	# Close up the table, and write "pck" again as its last line.
	for i in range(found, sections - 1):
		f.seek(table + (i + 1) * 40)
		var line := f.get_buffer(40)
		f.seek(table + i * 40)
		f.store_buffer(line)
	f.seek(table + (sections - 1) * 40)
	f.store_buffer(PackedByteArray([0x70, 0x63, 0x6b, 0, 0, 0, 0, 0]))
	f.store_32(8)                 # size in memory: next to nothing
	f.store_32(image_size)        # where it would sit in memory
	f.store_32(size)              # size in the file
	f.store_32(start)             # where in the file
	f.store_32(0)
	f.store_32(0)
	f.store_16(0)
	f.store_16(0)
	f.store_32(0x40000000)        # read only
	f.seek(optional + 56)
	f.store_32(image_size + alignment)
	f.close()
	return true
