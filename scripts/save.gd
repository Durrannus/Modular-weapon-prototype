extends RefCounted
## Saved characters and saved worlds.
##
## Darren, 21 November 2026: "It works like terraria, player is saved". Each player's CHARACTER is its own save and
## goes into any world; each WORLD is its own save. (The Game Bible: the character carries its weapons, parts, runes,
## threads, backpack, accessories and presets, and since 22 November its materials bag and its tool belt; the world
## keeps its map, what was changed on it, the base, its story progress and the squad's shared level.)
##
## There is no save button. The game saves by itself: every minute, when you pause, when you leave the forge, when
## you go back to the title and when the game is closed (scripts/highlands/highlands.gd).
##
## ON THE DISK: one small JSON file for each character and each world, in the game's own data folder:
##
##   saves/characters/character_3.json        the save
##   saves/characters/character_3.json.bak    the save as it was before the last change: the one backup
##   saves/worlds/world_2.json  (and .bak)
##   saves/deleted/...                        what was deleted on the pick screen, kept until somebody clears it out
##
## A save is written to a new file first and then swapped in, so a crash or a power cut in the middle of a write
## leaves the old save or the new one, never half of each. If a save cannot be read, its backup is read instead and
## the screen says so.
##
## This file only knows files. What goes INTO a character or a world is decided where they are used: a world save
## holds the world's number and what was dug, felled and left behind since the land was made, never the land itself
## (the same number always makes the same land: world_gen.gd).

const FORMAT := 1                 # raised when a save is written in a way an older game could not read
const CHARACTERS := "characters"
const WORLDS := "worlds"
const WORDS := {CHARACTERS: "character", WORLDS: "world"}
const TITLES := {CHARACTERS: "Character", WORLDS: "World"}

static var root := "user://saves"     # the tests keep theirs somewhere else


static func folder(kind: String) -> String:
	return "%s/%s" % [root, kind]


static func path(kind: String, id: String) -> String:
	return "%s/%s/%s.json" % [root, kind, id]


## Is this a save's own name, such as "world_12"? (Nothing else is ever made into a file name.)
static func good_id(kind: String, id: String) -> bool:
	var word: String = WORDS.get(kind, "")
	return word != "" and id.begins_with(word + "_") and id.substr(word.length() + 1).is_valid_int() and int(id.substr(word.length() + 1)) > 0


## One file, as a save: {} if it is not there, is not JSON, or is not a save of this kind with this name.
static func _read_file(file: String, kind: String, id: String) -> Dictionary:
	if not FileAccess.file_exists(file):
		return {}
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()              # (parse() says nothing on the console about a file it cannot read; we fall back quietly)
	var read := json.parse(f.get_as_text())
	f.close()
	if read != OK or not (json.data is Dictionary):
		return {}
	var d: Dictionary = json.data
	if str(d.get("kind", "")) != WORDS[kind] or str(d.get("id", "")) != id or not (d.get("format") is float or d.get("format") is int):
		return {}
	if not (d.get("name") is String) or str(d["name"]).strip_edges() == "":
		d["name"] = "%s %s" % [TITLES[kind], id.get_slice("_", 1)]
	return d


## A save, by its name: {} if there is none that can be read. If the save itself is damaged or missing, its backup
## is read, and the answer says so with "restored": true. A save written by a newer game than this one is marked
## "newer": true and must not be played or written over.
static func read(kind: String, id: String) -> Dictionary:
	if not good_id(kind, id):
		return {}
	var d := _read_file(path(kind, id), kind, id)
	if d.is_empty():
		d = _read_file(path(kind, id) + ".bak", kind, id)
		if d.is_empty():
			return {}
		d["restored"] = true
	if int(d["format"]) > FORMAT:
		d["newer"] = true
	return d


## The names of every save of a kind that has a file (or only a backup left).
static func ids(kind: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(folder(kind))
	if dir == null:
		return out
	for file in dir.get_files():
		var id := ""
		if file.ends_with(".json"):
			id = file.trim_suffix(".json")
		elif file.ends_with(".json.bak"):
			id = file.trim_suffix(".json.bak")
		if id != "" and good_id(kind, id) and not (id in out):
			out.append(id)
	return out


## Every save of a kind that can be read, the one played last first.
static func list(kind: String) -> Array:
	var out: Array = []
	for id in ids(kind):
		var d := read(kind, id)
		if not d.is_empty():
			out.append(d)
	out.sort_custom(func(a, b):
		if float(a.get("played", 0.0)) != float(b.get("played", 0.0)):
			return float(a.get("played", 0.0)) > float(b.get("played", 0.0))
		return number(str(a["id"])) > number(str(b["id"])))
	return out


static func number(id: String) -> int:
	return int(id.get_slice("_", 1))


## A name nobody has yet for a new save of this kind: one more than the highest ever given, counting the deleted
## ones (so a deleted save's files are never mixed up with a new one's) and `taken` (names handed out but not yet
## written: two players each making a new character on the same screen).
static func new_id(kind: String, taken: Array = []) -> String:
	var top := 0
	for id in ids(kind) + taken:
		top = maxi(top, number(str(id)))
	var dir := DirAccess.open(root + "/deleted")
	if dir != null:
		for file in dir.get_files():
			var id := file.get_slice(".", 0)
			if good_id(kind, id):
				top = maxi(top, number(id))
	return "%s_%d" % [WORDS[kind], top + 1]


## A save that has not been written yet: its name, what it is called on the screen, and when it was made.
static func fresh(kind: String, taken: Array = []) -> Dictionary:
	var id := new_id(kind, taken)
	var now := Time.get_unix_time_from_system()
	return {"format": FORMAT, "kind": WORDS[kind], "id": id, "name": "%s %d" % [TITLES[kind], number(id)], "made": now, "played": now, "seconds": 0.0, "unsaved": true}


## The text a save is written as. (The marks this file adds while a save is in use are left out.)
static func text_of(data: Dictionary) -> String:
	var d := data.duplicate()
	for mark in ["restored", "newer", "unsaved", "relaid"]:
		d.erase(mark)
	d["format"] = FORMAT
	return JSON.stringify(d, "\t")


## Writes a save. The save that was there becomes the backup. Returns false, and leaves what was there alone, if the
## new file could not be written whole.
static func write(kind: String, data: Dictionary) -> bool:
	var id := str(data.get("id", ""))
	if not good_id(kind, id) or data.get("newer", false):
		return false
	DirAccess.make_dir_recursive_absolute(folder(kind))
	var file := path(kind, id)
	var text := text_of(data)
	var f := FileAccess.open(file + ".tmp", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	var ok := f.get_error() == OK
	f.close()
	# Read it back before anything is swapped: a disk that is full writes a short file without complaint.
	if not ok or FileAccess.get_file_as_string(file + ".tmp") != text:
		DirAccess.remove_absolute(file + ".tmp")
		return false
	if FileAccess.file_exists(file):
		if not _read_file(file, kind, id).is_empty():
			# Only a save that can be read is worth keeping as the backup: a damaged one must not push the good backup out.
			if FileAccess.file_exists(file + ".bak"):
				DirAccess.remove_absolute(file + ".bak")
			if DirAccess.rename_absolute(file, file + ".bak") != OK:
				DirAccess.remove_absolute(file + ".tmp")
				return false
		else:
			DirAccess.remove_absolute(file)
	if DirAccess.rename_absolute(file + ".tmp", file) != OK:
		return false
	data.erase("unsaved")
	return true


## Takes a save off the lists. Its file and its backup are moved to saves/deleted/, not destroyed, so a save deleted
## by mistake can still be put back by hand.
static func remove(kind: String, id: String) -> bool:
	if not good_id(kind, id):
		return false
	var bin := root + "/deleted"
	DirAccess.make_dir_recursive_absolute(bin)
	var moved := false
	for ending in [".json", ".json.bak"]:
		var from := "%s/%s%s" % [folder(kind), id, ending]
		if not FileAccess.file_exists(from):
			continue
		var to := "%s/%s%s" % [bin, id, ending]
		if FileAccess.file_exists(to):
			DirAccess.remove_absolute(to)
		if DirAccess.rename_absolute(from, to) == OK:
			moved = true
	DirAccess.remove_absolute("%s/%s.json.tmp" % [folder(kind), id])
	return moved


## When a save was last played, in a few words: "today 20:31", "yesterday 9:05", "14 Nov", "3 Mar 2025".
static func when(stamp: float, now := -1.0) -> String:
	if stamp <= 0.0:
		return "never"
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var shift := float(int(Time.get_time_zone_from_system().get("bias", 0))) * 60.0
	var then: Dictionary = Time.get_datetime_dict_from_unix_time(int(stamp + shift))
	var today: Dictionary = Time.get_datetime_dict_from_unix_time(int(now + shift))
	var days := int(floor((now + shift) / 86400.0)) - int(floor((stamp + shift) / 86400.0))
	var clock := "%d:%02d" % [int(then["hour"]), int(then["minute"])]
	if days <= 0:
		return "today " + clock
	if days == 1:
		return "yesterday " + clock
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var text := "%d %s" % [int(then["day"]), months[int(then["month"]) - 1]]
	if int(then["year"]) != int(today["year"]):
		text += " %d" % int(then["year"])
	return text


## How long something has been played, in a few words: "under a minute", "12 min", "3 h 05".
static func how_long(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes < 1:
		return "under a minute"
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %02d" % [minutes / 60, minutes % 60]
