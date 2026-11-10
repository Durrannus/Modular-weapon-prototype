extends SceneTree
## Checks that the version number (scripts/version.gd) was raised when the
## game's files changed, and raises it when asked.
##   godot --headless --path . -s tests/version_check.gd            check
##   godot --headless --path . -s tests/version_check.gd -- stamp   give a changed game the next number
## Run "stamp" as the last thing before every push that changes the game.

const Version := preload("res://scripts/version.gd")


func _init() -> void:
	var now := Version.files_id()
	var same := now == Version.FILES
	if "stamp" in OS.get_cmdline_user_args():
		if same:
			print("Nothing has changed: still version %d (%s)." % [Version.NUMBER, now])
			quit(0)
			return
		var text := FileAccess.get_file_as_string(Version.SELF)
		var number := RegEx.create_from_string("const NUMBER := \\d+")
		var files := RegEx.create_from_string("const FILES := \"[^\"]*\"")
		if number.search(text) == null or files.search(text) == null:
			print("FAIL  couldn't find NUMBER and FILES in %s" % Version.SELF)
			quit(1)
			return
		text = number.sub(text, "const NUMBER := %d" % (Version.NUMBER + 1))
		text = files.sub(text, "const FILES := \"%s\"" % now)
		var out := FileAccess.open(Version.SELF, FileAccess.WRITE)
		out.store_string(text)
		out.close()
		print("Stamped: this is now version %d (%s)." % [Version.NUMBER + 1, now])
		quit(0)
		return
	print(("PASS  " if same else "FAIL  ") + "the game's files are the ones version %d was given to (%s%s)" % [
			Version.NUMBER, now, "" if same else ", stamped %s" % Version.FILES])
	if not same:
		print("      Something changed since. Run this again with \"-- stamp\" to give it the next number.")
	print("RESULT: %s" % ("all passed" if same else "1 failed"))
	quit(0 if same else 1)
