extends "res://scripts/foes/foe.gd"
## The Pebble Slinger (version 43). Darren, 23 November: no ledges; "They keep their distance, throwing rocks from
## behind rubble or boulders, and back away when you close in."
##
## A slinger wants to be a good throw away from you. If a boulder, a cairn or a standing stone is near, it stands
## BEHIND it as you see it, and shuffles round as you move; the pebble is lobbed over the top (rock.gd). Come close
## and it backs away, slower than you run, so closing in works; an arrow or a bolt works from where you are. It
## whirls its sling before it throws (the warning), and a hit while it whirls spoils the throw.
##
## The ELITE carries a rock as big as its head: a slower, heavier throw that bursts into shards where it lands.

const Rock := preload("res://scripts/foes/rock.gd")

static var HP := 14.0
static var SPEED := 100.0
static var FLEE := 125.0             # backing away (you walk at 220)
static var PEBBLE := 7.0
static var NEAR := 120.0             # it backs away inside this
static var FAR := 250.0              # and comes closer beyond this
static var WINDUP := 0.55            # the sling going round before the throw
static var RELOAD_MIN := 1.5
static var RELOAD_MAX := 2.3
static var FLIGHT := 0.65            # seconds a pebble is in the air
static var SPLASH := 18.0            # how far from the spot a pebble still hits
static var ELITE_HP := 55.0
static var ELITE_ROCK := 12.0
static var ELITE_WINDUP := 0.8
static var ELITE_RELOAD_MIN := 2.6
static var ELITE_RELOAD_MAX := 3.4
static var ELITE_FLIGHT := 0.85
static var ELITE_SPLASH := 46.0
static var SHARDS := 6
static var SHARD_DAMAGE := 5.0
static var SHARD_REACH := 110.0
static var MISS_OPEN := 1.0          # how long it is Open after a pebble of its lands on nobody
const THROW_TIME := 0.3
const THROW_MOST := 320.0            # it does not throw farther than this
const COVER_EVERY := 1.0
const COVER_FAR := 300.0             # how far it will go for something to stand behind

var reload := 1.0
var aim_at := Vector2.ZERO
var cover_at := Vector2.INF     # where it means to stand, behind something; INF = nowhere in particular
var _cover_t := 0.0


func _setup() -> void:
	kind = "slinger"
	_stats()
	radius = 9.0
	contact_damage = 0.0
	color = Color("#6e6a7c")
	reload = Sim.between(0.6, 1.6)
	add_to_group("goblins")


func _stats() -> void:
	max_hp = ELITE_HP if elite else HP
	speed = SPEED


func _fight(delta: float) -> Vector2:
	var to_p: Vector2 = target.global_position - global_position
	var dist := to_p.length()
	match mode:
		"idle":
			_set_mode("move")
		"move":
			reload -= delta
			if dist > 0.01:
				facing = to_p / dist
			var can_see := sees(target.global_position)
			if reload <= 0.0 and can_see and dist <= THROW_MOST and dist > 50.0:
				_set_mode("windup", ELITE_WINDUP if elite else WINDUP)
				Sfx.play(self, "warn", -17.0, 1.2)
				return Vector2.ZERO
			if dist < NEAR:
				cover_at = Vector2.INF
				return _away(target.global_position, delta) * FLEE
			_cover_t -= delta
			if _cover_t <= 0.0:
				_cover_t = COVER_EVERY
				cover_at = _find_cover()
			if cover_at != Vector2.INF:
				return _go(cover_at, speed, delta) if global_position.distance_to(cover_at) > 8.0 else Vector2.ZERO
			if dist > FAR or not can_see:
				return _go(target.global_position, speed, delta)
		"windup":
			if dist > 0.01:
				facing = to_p / dist
			if mode_t <= 0.0:
				_throw()
				_set_mode("throw", THROW_TIME)
		"throw":
			if mode_t <= 0.0:
				_set_mode("move")
				reload = Sim.between(ELITE_RELOAD_MIN, ELITE_RELOAD_MAX) if elite else Sim.between(RELOAD_MIN, RELOAD_MAX)
	return Vector2.ZERO


## Somewhere to stand with a boulder between it and its target: the spot right behind the nearest thing that will
## do, at a good throwing distance. INF if there is nothing.
func _find_cover() -> Vector2:
	if pack == null or pack.cover.is_empty() or target == null:
		return Vector2.INF
	var from: Vector2 = target.global_position
	var best := Vector2.INF
	var best_d := COVER_FAR
	for c in pack.cover:
		var thing: Vector2 = c[0]
		var gap := thing - from
		if gap.length() < NEAR + 10.0 or gap.length() > FAR + 20.0:
			continue
		var spot := thing + gap.normalized() * (float(c[1]) + 22.0)
		if nav != null and (not nav.is_free(nav.tile_of(spot)) or not nav.sees(spot, from)):
			continue
		var taken := false
		for e in allies():
			if e.kind == "slinger" and e.cover_at != Vector2.INF and e.cover_at.distance_to(spot) < 30.0:
				taken = true
		var d := global_position.distance_to(spot)
		if not taken and d < best_d:
			best_d = d
			best = spot
	return best


func _throw() -> void:
	# At where you are, and a little ahead of the way you are walking.
	var lead: Vector2 = target.velocity * 0.25 if "velocity" in target else Vector2.ZERO
	aim_at = target.global_position + lead.limit_length(60.0)
	var r := Rock.new()
	r.kind = "rock" if elite else "pebble"
	r.from = global_position + facing * 8.0
	r.to = aim_at
	r.flight = ELITE_FLIGHT if elite else FLIGHT
	r.damage = ELITE_ROCK if elite else PEBBLE
	r.splash = ELITE_SPLASH if elite else SPLASH
	r.shards = SHARDS if elite else 0
	r.shard_damage = SHARD_DAMAGE
	r.shard_reach = SHARD_REACH
	r.nav = nav
	r.by = self
	get_parent().add_child(r)
	Sfx.play(self, "swing", -9.0, 1.4 if not elite else 0.8)


## Its pebble or rock came down on nobody (rock.gd tells it): it is Open for a moment (the Striker's word).
func rock_missed() -> void:
	open_for(MISS_OPEN)


## A hit while the sling goes round spoils the throw.
func _on_hit() -> void:
	if mode == "windup":
		_set_mode("move")
		reload = 0.7


func _stand_down() -> void:
	super._stand_down()
	cover_at = Vector2.INF


func _anim() -> Array:
	var strips: Dictionary = _art_info().get("strips", {})
	var hit_strip: Dictionary = strips.get("hit", {})
	if not hit_strip.is_empty() and hit_anim < float(hit_strip["frames"]) / float(hit_strip["fps"]):
		return ["hit", hit_anim, false]
	match mode:
		"windup":
			return ["windup", anim_time, true]
		"throw":
			return ["throw", THROW_TIME - mode_t, false]
	if velocity.length() > 15.0:
		return ["move", anim_time, true]
	return ["idle", anim_time, true]
