extends Node
## The enemies out on the Greystone Highlands (version 43): who lives where (foe_plan.gd), and which of them are
## really there right now.
##
## The land is big and most of it is far from anybody, so a group only stands on the land while a player is within
## WAKE of its home; farther than SLEEP and calm, it is put away again (and is whole when it next wakes). One that
## dies stays dead for BACK_AFTER seconds and then comes back, at home, when nobody is near to see it.
##
## Nothing here is saved: load a world and every group is at home (Claude's choice, like the part-dug rock). It
## asks the game's shared dice only for what decides the fight, so two computers playing together agree.

const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Nav := preload("res://scripts/highlands/nav.gd")
const FoePlan := preload("res://scripts/highlands/foe_plan.gd")
const Pack := preload("res://scripts/foes/pack.gd")
const Make := preload("res://scripts/foes/make.gd")
const Sim := preload("res://scripts/sim.gd")

const TILE := 32.0
const WAKE := 1400.0           # a group is on the land while a player is this near its home (the screen is 1280 across)
const SLEEP := 1800.0          # and put away again beyond this, if it is calm
static var BACK_AFTER := 200.0 # seconds before one that died is back (Darren's lab, version 57; was 300.0)
const BACK_UNSEEN := 900.0     # it only comes back with nobody this near its home
const CHECK := 0.25
const COVER := ["boulder", "cairn", "stone", "barrel"]     # what a slinger will stand behind

var game
var map: LandMap
var world: Node2D
var players: Array = []
var nav: Nav
var plan: Array = []
var packs := {}                # plan index -> its Pack, for the groups that are on the land
var fallen := {}               # plan index -> {member index: seconds until it is back}
var on := true                 # false: nobody wakes (the tests of other things switch them off)
var quiet := {}                # plan index -> true: nobody comes to live there any more (a lit waystone keeps its place: folk.gd)
## The Scrapyard (version 49): its rooms' groups are added to the plan by the game, each with a "room". They are only
## on the land while somebody is inside its walls (`yard`, world units), and they come back only while nobody is.
var yard := Rect2()
var cover_extra: Array = []    # more for a slinger to stand behind than the land's things: [[its middle (world units), how wide (art pixels)]]
var _t := 0.0


func setup() -> void:
	nav = Nav.new()
	nav.setup(map)
	plan = FoePlan.make(map)


func tick(delta: float) -> void:
	for i in packs:
		(packs[i] as Pack).tick(delta, players)
	_t -= delta
	if _t > 0.0:
		return
	_t = CHECK
	_back(CHECK)
	if not on:
		return
	var wake := -1
	var wake_d := WAKE
	for i in plan.size():
		var g: Dictionary = plan[i]
		var home: Vector2 = (g["home"] as Vector2) * TILE
		var near := INF
		for p in players:
			if is_instance_valid(p):
				near = minf(near, p.global_position.distance_to(home))
		if packs.has(i):
			var pack: Pack = packs[i]
			if near > SLEEP and not pack.alert:
				_sleep(i)
			elif not pack.alert:
				_send_off(pack)
		elif near < wake_d and not quiet.has(i) and (not g.has("room") or inside_yard()):
			wake = i
			wake_d = near
	# One at a time (waking a group is the dear part), the nearest first: whoever arrives somewhere all at once
	# (a fall, and later a waystone) has the group beside them on the land before they can look round.
	if wake >= 0:
		_wake(wake)


## Puts a group on the land, everyone at their own spot round its home.
func _wake(i: int) -> Pack:
	var g: Dictionary = plan[i]
	var pack := Pack.new()
	pack.id = i
	pack.plan = g
	pack.nav = nav
	pack.home = Nav.middle_of(nav.nearest_free(Nav.tile_of((g["home"] as Vector2) * TILE), 6))
	pack.reach = float(g["r"]) * TILE
	pack.cover = _cover(pack.home, pack.reach + 128.0)
	packs[i] = pack
	var members: Array = g["members"]
	var spots := _spots(pack, members.size())
	for k in members.size():
		if (fallen.get(i, {}) as Dictionary).has(k):
			continue
		_put(pack, i, k, spots[k % spots.size()])
	return pack


func _put(pack: Pack, i: int, k: int, at: Vector2) -> void:
	var m: Array = pack.plan["members"][k]
	var e = Make.make(str(m[0]), bool(m[1]))
	e.set_meta("member", k)
	if m.size() > 2:
		e.set_meta("stands_for", str(m[2]))      # (the Gatehouse's elite handler, played by an elite slinger: no piece of the horn)
	if bool(m[1]) and bool(pack.plan.get("horn", false)):
		e.set_meta("horn", true)                 # (one of the three world elites who carry the Warhorn's pieces)
	at = _apart(at, pack)
	e.pack = pack
	e.nav = nav
	e.home = at
	e.position = at
	e.facing = Vector2.from_angle(float((i * 7 + k * 13) % 16) * TAU / 16.0)
	world.add_child(e)
	pack.members.append(e)
	e.died.connect(_on_died.bind(i, k))


## Never two on the very same spot: two bodies in one place push each other the same way for ever, through
## anything. A spot somebody already stands on is left by a few steps (still inside its tile).
const STEPS_ASIDE := [Vector2.ZERO, Vector2(10, 10), Vector2(-10, 10), Vector2(10, -10), Vector2(-10, -10), Vector2(0, 12), Vector2(12, 0), Vector2(0, -12), Vector2(-12, 0)]

func _apart(at: Vector2, pack: Pack) -> Vector2:
	var out := at
	for step in STEPS_ASIDE:
		out = at + step
		var alone := true
		for e in pack.members:
			if is_instance_valid(e) and e.global_position.distance_to(out) < 13.0:
				alone = false
		if alone:
			break
	return out


## Places to stand round a group's home: free tiles near it that can be walked to from it without going far round,
## a tile and a half apart at least, always the same ones for the same group.
func _spots(pack: Pack, n: int) -> Array:
	var c := Nav.tile_of(pack.home)
	var far := clampi(int(pack.reach / TILE * 0.6), 2, 5)
	var near := _near_reach(c, far + 3)
	var tiles: Array = []
	for j in range(-far, far + 1):
		for i in range(-far, far + 1):
			var at := c + Vector2i(i, j)
			if near.has(at) and Vector2(i, j).length() <= float(far) + 0.5:
				tiles.append(at)
	tiles.sort_custom(func(a, b): return _mix(a, pack.id) < _mix(b, pack.id))
	var out: Array = []
	for at in tiles:
		var ok := true
		for o in out:
			if (Nav.middle_of(at) as Vector2).distance_to(o) < TILE * 1.6:
				ok = false
		if ok:
			out.append(Nav.middle_of(at))
		if out.size() >= n:
			break
	if out.is_empty():
		out.append(pack.home)
	return out


## The free tiles that can be walked to from this one without leaving the square `box` tiles round it. (Asking the
## way-finding instead is slow where a tile beyond a wall is joined to this one only by a long way round.)
func _near_reach(c: Vector2i, box: int) -> Dictionary:
	var seen := {}
	if not nav.is_free(c):
		return seen
	seen[c] = true
	var todo: Array[Vector2i] = [c]
	var k := 0
	while k < todo.size():
		var at: Vector2i = todo[k]
		k += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var to: Vector2i = at + d
			if seen.has(to) or absi(to.x - c.x) > box or absi(to.y - c.y) > box or not nav.is_free(to):
				continue
			seen[to] = true
			todo.append(to)
	return seen


static func _mix(at: Vector2i, salt: int) -> int:
	var h := (at.x * 73856093) ^ (at.y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## What a slinger can stand behind near a group's home: [[its middle (world units), its half width]].
func _cover(home: Vector2, far: float) -> Array:
	var out: Array = []
	var c := Nav.tile_of(home)
	var cx := floori(float(c.x) / LandMap.CHUNK)
	var cy := floori(float(c.y) / LandMap.CHUNK)
	var span := ceili(far / TILE / LandMap.CHUNK)
	for dj in range(-span, span + 1):
		for di in range(-span, span + 1):
			for t in map.things_in(cx + di, cy + dj):
				var name := str(t["n"])
				var info: Dictionary = Painter.thing_info(name)
				if not info.has("solid") or not COVER.any(func(w): return name.begins_with(w)):
					continue
				var solid: Array = info["solid"]
				var middle := Vector2(float(t["x"]), float(t["y"]) - float(solid[1]) * 0.5) * 2.0
				if middle.distance_to(home) <= far:
					out.append([middle, float(solid[0])])
	for extra in cover_extra:
		if (extra[0] as Vector2).distance_to(home) <= far:
			out.append(extra)
	return out


## Is anybody of the squad inside the Scrapyard's walls?
func inside_yard() -> bool:
	if yard.size.x <= 0.0:
		return false
	for p in players:
		if is_instance_valid(p) and yard.has_point(p.global_position):
			return true
	return false


## Takes a calm group off the land. Whoever was hurt is whole when it wakes again.
func _sleep(i: int) -> void:
	var pack: Pack = packs[i]
	for e in pack.members:
		if is_instance_valid(e):
			e.queue_free()
	pack.members.clear()
	packs.erase(i)


## The fight is over: a hound that came to a howl slips away once nobody is near enough to see it go.
func _send_off(pack: Pack) -> void:
	for e in pack.members.duplicate():
		if not is_instance_valid(e) or not e.summoned or e.kind == "bat":
			continue
		var seen := false
		for p in players:
			if is_instance_valid(p) and p.global_position.distance_to(e.global_position) < 760.0:
				seen = true
		if not seen:
			pack.members.erase(e)
			e.queue_free()


func _on_died(e, i: int, k: int) -> void:
	if not fallen.has(i):
		fallen[i] = {}
	fallen[i][k] = BACK_AFTER
	# What it leaves behind (loot.gd): Memory, and an elite's loot. Those called into a fight never come this way.
	if game != null and "loot" in game and game.loot != null:
		game.loot.foe_died(e)
	credit(e)


## Whose kill it is: the player whose blow last landed on it, or if nobody's did (a burn, a rune's hit), the nearest
## one standing. Their kill runes go off, and the role trees hear of it (Kill Rush). Version 53: before it, a kill in
## the Highlands was nobody's.
func credit(e) -> void:
	var best = e.last_hit_by if "last_hit_by" in e and is_instance_valid(e.last_hit_by) and not e.last_hit_by.is_down else null
	if best == null:
		for p in players:
			if is_instance_valid(p) and not p.is_down and (best == null or p.global_position.distance_to(e.global_position) < best.global_position.distance_to(e.global_position)):
				best = p
	if best != null and best.has_method("on_kill"):
		best.on_kill(e.global_position)


## The dead come back, at home, when their time is up and nobody is near.
func _back(dt: float) -> void:
	var in_yard := inside_yard()
	for i in fallen.keys():
		var gone: Dictionary = fallen[i]
		var walled: bool = i < plan.size() and (plan[i] as Dictionary).has("room")
		for k in gone.keys():
			gone[k] = float(gone[k]) - dt
			if float(gone[k]) > 0.0:
				continue
			if walled and in_yard:
				continue           # the Scrapyard's rooms fill again only while nobody is inside its walls
			if not packs.has(i):
				gone.erase(k)
				continue
			var pack: Pack = packs[i]
			var near := false
			for p in players:
				if is_instance_valid(p) and p.global_position.distance_to(pack.home) < BACK_UNSEEN:
					near = true
			if near or pack.alert or quiet.has(i):
				continue
			gone.erase(k)
			var spots := _spots(pack, (pack.plan["members"] as Array).size())
			_put(pack, i, k, spots[k % spots.size()])
		if gone.is_empty():
			fallen.erase(i)


## A hound answering its leader's howl: it comes running from out of sight, where the land has such a place.
func call_in(by, kind: String):
	var e = Make.make(kind)
	if e == null or not is_instance_valid(by):
		return null
	var at: Vector2 = by.home
	var turn := Sim.between(0.0, TAU)
	var found := false
	for far in [520.0, 440.0, 600.0, 360.0]:
		for s in 12:
			var spot: Vector2 = by.global_position + Vector2.from_angle(turn + TAU * float(s) / 12.0) * far
			if not nav.is_free(Nav.tile_of(spot)):
				continue
			var seen := false
			for p in players:
				if is_instance_valid(p) and p.global_position.distance_to(spot) < 380.0:
					seen = true
			if seen:
				continue
			var n := nav.steps(spot, by.global_position)
			if n < 0 or n > 40:
				continue
			at = Nav.middle_of(Nav.tile_of(spot))
			found = true
			break
		if found:
			break
	if by.pack != null:
		at = _apart(at, by.pack)
	e.pack = by.pack
	e.nav = nav
	e.summoned = true
	e.home = by.home
	e.position = at
	world.add_child(e)
	if by.pack != null:
		by.pack.members.append(e)
	return e


## Everything of the Highlands' enemies that is on the land right now.
func all() -> Array:
	var out: Array = []
	for i in packs:
		out.append_array((packs[i] as Pack).living())
	return out
