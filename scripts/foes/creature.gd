extends "res://scripts/foes/foe.gd"
## What the moor's creatures share (version 63): the boar, the badger and the capercaillie. Darren, 25 November 2026:
## "The rest of the zone should be new simple neutral enemies so that the zone feels like it has different sections
## as it feels very samsey atm." Out on the land they live everywhere the goblins round the Scrapyard and the hounds
## in the snow do not (foe_plan.gd).
##
## NEUTRAL. They leave you alone: walking past, even right beside them, wakes nothing (pack.gd's `neutral`). Only a
## blow wakes them, and then their whole group: the boar charges, the badger bites, the capercaillie runs. Once
## nobody has hit any of them for SETTLE seconds and nobody stands within SETTLE_GAP of one, they settle again: back
## to ambling about, and whole again. (In the test arena there is no group, so one put there wakes at once.)
##
## THEY AMBLE. Calm, each one wanders about its home: a few steps somewhere within WANDER tiles, a stop to root,
## snuffle or peck, a few steps more. It throws its own dice for that (started from where it first stood), so the
## game's shared dice are left for what decides a fight.
##
## THEIR PICTURES are the Art builder's moor sheet (art/foes/moor.png and moor.json, and its README): the wildlife
## sheet's form, one book of "actors" by name, everything facing right.
##
## None of them draws a mark on the floor (Darren, 23 November: marks are for bosses). The boar's pawing is its
## warning, and the badger's open jaw.

const MOOR_SHEET := "foes/moor.png"
const MOOR_BOOK := "foes/moor.json"
const TILE := 32.0
static var WANDER := 3.0         # tiles from home it ambles about, at most
static var AMBLE := 0.45         # the share of its speed it ambles at
static var SETTLE := 8.0         # seconds with no blow on any of its group before they settle again...
static var SETTLE_GAP := 220.0   # ...if nobody stands this near one of them (world units; a tile is 32)
const REST_MIN := 1.5            # seconds it stops between ambles, at least and at most
const REST_MAX := 4.5

var timid := false               # it only ever runs (the capercaillie): its group is never "after you"
var _dice := RandomNumberGenerator.new()
var _spot := Vector2.INF


func _ready() -> void:
	super._ready()
	_dice.seed = _own * 2654435761 + 17
	mode_t = _dice.randf_range(0.0, REST_MAX)      # (not all of a group setting off at the same moment)


# --- Calm: ambling about ------------------------------------------------------------------

func _calm(delta: float) -> Vector2:
	if not (mode in ["idle", "amble", "display"]):
		_stand_down()
	if hp < max_hp:
		hp = minf(hp + max_hp * 0.4 * delta, max_hp)
	match mode:
		"amble":
			if mode_t <= 0.0 or global_position.distance_to(_spot) < 8.0:
				_rest()
				return Vector2.ZERO
			var far_off := global_position.distance_to(home) > _reach() + 40.0
			var v := _go(_spot, speed * (0.8 if far_off else float(AMBLE)), delta)
			if v.length() > 1.0:
				facing = v.normalized()
			return v
		"display":
			if mode_t <= 0.0:
				_rest()
		_:
			if mode_t <= 0.0:
				_amble()
	return Vector2.ZERO


func _reach() -> float:
	return maxf(float(WANDER), 0.0) * TILE


## Off somewhere near home (or straight home, when it is far from it after a fight).
func _amble() -> void:
	var far := _reach()
	var spot := home
	if global_position.distance_to(home) < far + 40.0:
		if far < 8.0:
			_rest()
			return
		for i in 6:
			var s := home + Vector2.from_angle(_dice.randf() * TAU) * _dice.randf_range(0.3, 1.0) * far
			if nav == null or (nav.is_free(nav.tile_of(s)) and nav.clear(global_position, s)):
				spot = s
				break
	_spot = spot
	_set_mode("amble", 5.0)


## A stop between ambles.
func _rest() -> void:
	_set_mode("idle", _dice.randf_range(REST_MIN, REST_MAX))


func _stand_down() -> void:
	_set_mode("idle", 0.0)


# --- Its pictures -------------------------------------------------------------------------

func art_name() -> String:
	return kind


func _art_info() -> Dictionary:
	return Art.json(MOOR_BOOK).get("actors", {}).get(kind, {})


func _art_tex(anim: String) -> Texture2D:
	var strip: Dictionary = _art_info().get("strips", {}).get(anim, {})
	return strip_tex(strip.get("box"), MOOR_SHEET)


func _art_key() -> String:
	return "moor/" + kind


## Is its hit strip still playing?
func _hit_showing() -> bool:
	var hs: Dictionary = _art_info().get("strips", {}).get("hit", {})
	return not hs.is_empty() and hit_anim < float(hs["frames"]) / float(hs["fps"])


## Walking or standing, when it is doing nothing else.
func _walk_or_stand() -> Array:
	if velocity.length() > 15.0:
		return ["move", anim_time, true]
	return ["idle", anim_time, true]
