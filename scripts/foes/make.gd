extends RefCounted
## Makes one of the Highlands' enemies by name: "hound", "slinger", "scrap_brute", "shaman", "bat", and
## "<name>_elite" for the elite of the first four; "rattlecrown", their boss, on his feet; and the moor's neutral
## creatures, "boar", "badger" and "capercaillie" (version 63); and "scrap_hound", the goblins' war dog (version 64). (The land's foes.gd,
## crown.gd and the test arena's spawn list use it.)

const KINDS := {
	"hound": preload("res://scripts/foes/hound.gd"),
	"slinger": preload("res://scripts/foes/slinger.gd"),
	"scrap_brute": preload("res://scripts/foes/scrap_brute.gd"),
	"shaman": preload("res://scripts/foes/shaman.gd"),
	"bat": preload("res://scripts/foes/bat.gd"),
	"rattlecrown": preload("res://scripts/foes/rattlecrown.gd"),
	"boar": preload("res://scripts/foes/boar.gd"),
	"badger": preload("res://scripts/foes/badger.gd"),
	"capercaillie": preload("res://scripts/foes/capercaillie.gd"),
	"scrap_hound": preload("res://scripts/foes/scrap_hound.gd"),
}

## Those with no elite of their own.
const NO_ELITE := ["bat", "rattlecrown", "boar", "badger", "capercaillie", "scrap_hound"]
## The moor's creatures (version 63): neutral, they leave you alone until one of them is hit (creature.gd).
const CREATURES := ["boar", "badger", "capercaillie"]


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
