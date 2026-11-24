extends "res://scripts/foes/foe.gd"
## The Goblin Shaman (version 43; decided by Darren on 23 November): it "stays at the back of goblin groups and
## summons a few bats that swoop and nip at you. Kill the shaman and the bats scatter, so it's a priority target."
##
## It keeps behind the other goblins, well away from you, and backs off if you come near (slower than you run).
## Every few seconds it raises its staff (the warning) and a bat comes; it keeps up to three. A hit while the
## staff is up spoils the call. When it dies, every bat of its own scatters.
##
## The ELITE calls two at a time and keeps six, and every so often it WARDS another goblin near it: for a few
## seconds that goblin cannot be hurt (three scrap shields circle it, and blows on it say WARDED).

const Bat := preload("res://scripts/foes/bat.gd")

static var HP := 30.0  # Darren's lab, 24 Nov (version 57; was 22.0)
static var SPEED := 85.0
static var FLEE := 110.0
static var KEEP := 230.0             # how far from you it likes to stand
static var NEAR := 150.0             # it backs away inside this
static var CAST_TIME := 0.5          # the staff raised before a bat comes (Darren's lab, version 57; was 0.9)
static var CAST_EVERY := 2.0  # Darren's lab, 24 Nov (version 57; was 5.0)
static var BATS := 6                 # the most bats of its own at once (Darren's lab, version 57; was 3)
static var ELITE_HP := 70.0
static var ELITE_BATS := 6
static var ELITE_A_CAST := 2
static var WARD_EVERY := 9.0
static var WARD_TIME := 3.0          # how long the warded goblin cannot be hurt
static var WARD_CAST := 0.7
static var WARD_REACH := 280.0
const BEHIND := 80.0                 # how far behind the other goblins it stands

var bats: Array = []
var cast_in := 1.2
var ward_in := 4.0
var ward_on = null


func _setup() -> void:
	kind = "shaman"
	_stats()
	radius = 9.0
	contact_damage = 0.0
	color = Color("#4a4458")
	cast_in = Sim.between(1.0, 1.8)
	ward_in = Sim.between(3.0, 5.0)
	add_to_group("goblins")


func _stats() -> void:
	max_hp = ELITE_HP if elite else HP
	speed = SPEED


func _my_bats() -> int:
	bats = bats.filter(func(b): return is_instance_valid(b) and not b.dead and not b.leaving)
	return bats.size()


## The other goblins of its group that can still fight.
func _goblins() -> Array:
	return allies().filter(func(e): return e.kind in GOBLINS)


func _fight(delta: float) -> Vector2:
	var to_p: Vector2 = target.global_position - global_position
	var dist := to_p.length()
	match mode:
		"idle":
			_set_mode("move")
		"move":
			cast_in -= delta
			ward_in -= delta
			if dist > 0.01:
				facing = to_p / dist
			if dist < NEAR:
				return _away(target.global_position, delta) * FLEE
			if elite and ward_in <= 0.0:
				ward_on = _pick_ward()
				if ward_on != null:
					_set_mode("ward", WARD_CAST)
					Sfx.play(self, "warn", -15.0, 1.5)
					return Vector2.ZERO
				ward_in = 1.5
			if cast_in <= 0.0 and _my_bats() < (ELITE_BATS if elite else BATS):
				_set_mode("cast", CAST_TIME)
				Sfx.play(self, "warn", -16.0, 1.0)
				return Vector2.ZERO
			# Behind the others, as seen from you; with nobody to stand behind, just a good way off.
			var others := _goblins()
			var spot := Vector2.INF
			if not others.is_empty():
				var middle := Vector2.ZERO
				for e in others:
					middle += e.global_position
				middle /= float(others.size())
				var back: Vector2 = middle - target.global_position
				spot = middle + back.normalized() * BEHIND
				if spot.distance_to(target.global_position) < NEAR + 30.0 or (nav != null and not nav.is_free(nav.tile_of(spot))):
					spot = Vector2.INF
			if spot != Vector2.INF:
				return _go(spot, speed, delta) if global_position.distance_to(spot) > 20.0 else Vector2.ZERO
			if dist > KEEP + 50.0 or not sees(target.global_position):
				return _go(target.global_position, speed, delta)
		"cast":
			if mode_t <= 0.0:
				_call_bats()
				_set_mode("move")
				cast_in = CAST_EVERY
		"ward":
			if is_instance_valid(ward_on) and not ward_on.dead:
				var to_it: Vector2 = ward_on.global_position - global_position
				if to_it.length() > 0.01:
					facing = to_it.normalized()
			if mode_t <= 0.0:
				if is_instance_valid(ward_on) and not ward_on.dead:
					ward_on.warded = WARD_TIME
					Sfx.play(self, "anvil", -14.0, 1.9)
				ward_on = null
				ward_in = WARD_EVERY
				_set_mode("move")
	return Vector2.ZERO


## Which goblin gets the ward: the one of its group nearest to a player (the one being fought), within reach.
func _pick_ward():
	var best = null
	var best_d := INF
	for e in _goblins():
		if e.warded > 0.0 or e.global_position.distance_to(global_position) > WARD_REACH:
			continue
		for p in players():
			var d: float = e.global_position.distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best


func _call_bats() -> void:
	var most: int = ELITE_BATS if elite else BATS
	for i in (ELITE_A_CAST if elite else 1):
		if _my_bats() >= most:
			break
		var b = Bat.new()
		b.shaman = self
		b.pack = pack
		b.nav = null
		b.summoned = true
		b.home = global_position
		b.position = position + Vector2(facing.x * 10.0 + float(i) * 8.0 - 4.0, -6.0)
		get_parent().add_child(b)
		if pack != null:
			pack.members.append(b)
		bats.append(b)
	Sfx.play(self, "cast", -10.0, 0.7)


## A hit while the staff is up spoils the call or the ward.
func _on_hit() -> void:
	if mode == "cast":
		_set_mode("move")
		cast_in = 2.0
	elif mode == "ward":
		_set_mode("move")
		ward_in = 3.0
		ward_on = null


## Kill the shaman and its bats scatter.
func _die() -> void:
	for b in bats:
		if is_instance_valid(b) and not b.dead:
			b.scatter()
	super._die()


func _stand_down() -> void:
	super._stand_down()
	for b in bats:
		if is_instance_valid(b) and not b.dead:
			b.scatter()
	bats.clear()


func _anim() -> Array:
	var strips: Dictionary = _art_info().get("strips", {})
	var hit_strip: Dictionary = strips.get("hit", {})
	if not hit_strip.is_empty() and hit_anim < float(hit_strip["frames"]) / float(hit_strip["fps"]):
		return ["hit", hit_anim, false]
	match mode:
		"cast":
			# The staff goes up, and comes down as the bat comes (the strip's middle frame is that moment).
			return ["cast", 0.0 if mode_t > 0.15 else 0.2, false]
		"ward":
			return ["ward" if strips.has("ward") else "cast", 0.0 if mode_t > 0.15 else 0.2, false]
	if velocity.length() > 15.0:
		return ["move", anim_time, true]
	return ["idle", anim_time, true]
