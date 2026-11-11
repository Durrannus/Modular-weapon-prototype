extends RefCounted
## The game's version number. It is shown small in the bottom-left corner of every
## screen (scripts/ui/version_label.gd), so anyone can see which copy they have,
## and two people can check that they have the same one.
##
## Every push that changes the game gets the next number. Don't edit the two
## lines below by hand. After changing anything, run
##   godot --headless --path . -s tests/version_check.gd -- stamp
## It raises NUMBER by one and writes the fingerprint of the game's files into
## FILES. Run it without "-- stamp" to check that the two still match.
##
## A copy whose files no longer match FILES (someone changed a script or a
## picture and didn't stamp) shows "+ changes" after its number, so the number
## never claims more than it knows.

const NUMBER := 10
const FILES := "4fc051344128"

## Everything that makes the game what it is. Not project.godot (the editor
## rewrites it), not the tests, and not this file (it holds the answer).
const FOLDERS := ["res://scripts", "res://art", "res://parts", "res://scenes", "res://shaders"]
const TEXT := ["gd", "json", "tres", "tscn", "gdshader"]
const OTHER := ["png", "ttf", "wav", "ogg", "mp3"]
const SELF := "res://scripts/version.gd"


## What the corner of the screen says.
static func label(changed := false) -> String:
	return "Version %d%s" % [NUMBER, " + changes" if changed else ""]


## Every file the fingerprint covers, in a fixed order.
static func files() -> Array:
	var out: Array = []
	for folder in FOLDERS:
		_list(folder, out)
	out.erase(SELF)
	out.sort()
	return out


static func _list(dir_path: String, into: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_list(dir_path + "/" + sub, into)
	for f in dir.get_files():
		var ending := f.get_extension().to_lower()
		if ending in TEXT or ending in OTHER:
			into.append(dir_path + "/" + f)


static func begin() -> HashingContext:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	return ctx


## Adds one file to a fingerprint that is being worked out.
static func add(ctx: HashingContext, path: String) -> void:
	ctx.update(("%s\n" % path).to_utf8_buffer())
	var bytes: PackedByteArray
	if path.get_extension().to_lower() in TEXT:
		# Windows may save the same file with different line endings: ignore those.
		bytes = FileAccess.get_file_as_string(path).replace("\r", "").to_utf8_buffer()
	else:
		bytes = FileAccess.get_file_as_bytes(path)
	if not bytes.is_empty():
		ctx.update(bytes)


static func finish(ctx: HashingContext) -> String:
	return ctx.finish().hex_encode().substr(0, 12)


## The fingerprint of the files as they are now, worked out in one go.
static func files_id() -> String:
	var ctx := begin()
	for path in files():
		add(ctx, path)
	return finish(ctx)
