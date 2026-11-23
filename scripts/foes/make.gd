extends RefCounted
## Makes one of the Highlands' enemies by name: "hound", "slinger", "scrap_brute", "shaman", "bat", and
## "<name>_elite" for the elite of the first four; and "rattlecrown", their boss, on his feet. (The land's foes.gd,
## crown.gd and the test arena's spawn list use it.)

const KINDS := {
	"hound": preload("res://scripts/foes/hound.gd"),
	"slinger": preload("res://scripts/foes/slinger.gd"),
	"scrap_brute": preload("res://scripts/foes/scrap_brute.gd"),
	"shaman": preload("res://scripts/foes/shaman.gd"),
	"bat": preload("res://scripts/foes/bat.gd"),
	"rattlecrown": preload("res://scripts/foes/rattlecrown.gd"),
}

## Those with no elite of their own.
const NO_ELITE := ["bat", "rattlecrown"]


static func knows(name: String) -> bool:
	return KINDS.has(name.trim_suffix("_elite")) and not (name.ends_with("_elite") and name.trim_suffix("_elite") in NO_ELITE)


## The enemy, not yet in the scene (give it a position, and a pack and a nav if it lives on the land).
static func make(name: String, elite := false):
	if name.ends_with("_elite"):
		elite = true
		name = name.trim_suffix("_elite")
	if not KINDS.has(name):
		return null
	var e = KINDS[name].new()
	e.elite = elite
	return e
