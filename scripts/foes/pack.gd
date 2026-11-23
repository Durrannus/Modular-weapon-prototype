extends RefCounted
## One group of the Highlands' enemies: a pack of hounds, or some goblins together (version 43).
##
## It has a home (the open place it lives in). Until one of it sees a player it is CALM: everyone stands at home.
## When one of them sees or hears a player, or is hit, the whole group is ALERT and fights. When every player has
## gone far enough from its home, it gives up: everyone walks back, gets their health back, and whatever came in
## the middle of the fight (bats, hounds that answered a howl) goes.

const SIGHT := 300.0           # how far one of them sees a player, with no rock between (world units; a tile is 32)
const HEAR := 110.0            # this close it notices you even round a corner
const LEASH := 640.0           # every player this far from its home, and it gives up...
const LEASH_NEAR := 380.0      # ...unless one of them still has a player this close
const GIVE_UP := 1.5           # seconds of that before it does
const LOOK_EVERY := 0.2

var id := 0
var home := Vector2.ZERO       # world units
var reach := 200.0             # about how far its open place goes from its home (world units)
var members: Array = []        # everyone of it there is right now (the foes' own nodes), those called in too
var plan := {}                 # its entry in the map's plan (foe_plan.gd)
var alert := false
var fight_time := 0.0          # seconds since it last became alert
var howls := 0                 # how many times its leader has called hounds in this fight
var cover: Array = []          # what a slinger can throw from behind: [[the thing's middle (world), its half width]]
var nav = null
var _far := 0.0
var _look := 0.0


func wake() -> void:
	if not alert:
		alert = true
		fight_time = 0.0
		howls = 0
	_far = 0.0


func living() -> Array:
	var out: Array = []
	for e in members:
		if is_instance_valid(e) and not e.dead:
			out.append(e)
	return out


func tick(delta: float, players: Array) -> void:
	members = members.filter(func(e): return is_instance_valid(e) and not e.dead)
	var up: Array = []
	for p in players:
		if is_instance_valid(p) and not p.is_down and p.knocked_out_timer <= 0.0:
			up.append(p)
	if alert:
		fight_time += delta
		var gone := true
		for p in up:
			if p.global_position.distance_to(home) < maxf(LEASH, reach + 320.0):
				gone = false
			for e in members:
				if not e.summoned and e.global_position.distance_to(p.global_position) < LEASH_NEAR and e.global_position.distance_to(home) < LEASH * 1.5:
					gone = false
		_far = _far + delta if gone else 0.0
		if _far >= GIVE_UP or members.is_empty():
			alert = false
			_far = 0.0
		return
	_look -= delta
	if _look > 0.0:
		return
	_look = LOOK_EVERY
	for e in members:
		if e.summoned or e.held:
			continue
		for p in up:
			var d: float = e.global_position.distance_to(p.global_position)
			if d < HEAR or (d < SIGHT and (nav == null or nav.sees(e.global_position, p.global_position))):
				wake()
				return
