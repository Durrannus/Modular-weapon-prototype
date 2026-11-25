extends "res://scripts/foes/hound.gd"
## The goblins' war dog (version 64). Darren, 25 November 2026: "The wolfs don't need armour and the wolfs at the
## goblin camp can have scrap armour and red eyes." So the hounds that live with goblins (the Scrapyard's Gatehouse,
## and some of the groups in the goblin ground round it: foe_plan.gd) are this one: a Cliff Hound with scrap
## strapped on and red eyes, from the Art builder's sheet (art/foes/hounds.png and hounds.json, its README). The
## wild hounds on the moor and in the snow keep their own look.
##
## It moves and fights as a hound does (circles, crouches, lunges; hound.gd's numbers), and its plate gives it
## HP_MORE times a hound's health (Claude's). It has no elite and never howls.

const HOUND_SHEET := "foes/hounds.png"
const HOUND_BOOK := "foes/hounds.json"
static var HP_MORE := 1.3      # its plate: this many times a wild hound's health


func _setup() -> void:
	super._setup()
	kind = "scrap_hound"
	color = Color("#6e6a7c")


func _stats() -> void:
	super._stats()
	max_hp = HP * maxf(float(HP_MORE), 0.1)


func art_name() -> String:
	return "scrap_hound"


func _art_info() -> Dictionary:
	return Art.json(HOUND_BOOK).get("enemies", {}).get("scrap_hound", {})


func _art_tex(anim: String) -> Texture2D:
	var strip: Dictionary = _art_info().get("strips", {}).get(anim, {})
	return strip_tex(strip.get("box"), HOUND_SHEET)


func _art_key() -> String:
	return "foes/scrap_hound"
