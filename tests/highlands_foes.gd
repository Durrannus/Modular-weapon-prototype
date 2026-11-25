extends SceneTree
## The enemies of the Greystone Highlands (version 43): the Cliff Hound, the Pebble Slinger, the Scrap Brute, the
## Goblin Shaman and its bats, the elite of each, and where they live on the land. Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands_foes.gd
##
## Each kind is first tried alone in the test arena (a bare room), then the land is checked: who lives where,
## that a group wakes when you come near, fights when it sees you, gives up when you leave, and comes back after
## it is killed.
##
## With shots=/some/folder/ (needs a window, so leave out --headless) it saves 640x360 pictures instead.
## "seed=123456" picks the world for those.

const PlayerInput := preload("res://scripts/player_input.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const WorldGen := preload("res://scripts/highlands/world_gen.gd")
const FoePlan := preload("res://scripts/highlands/foe_plan.gd")
const Foes := preload("res://scripts/highlands/foes.gd")
const Nav := preload("res://scripts/highlands/nav.gd")
const Make := preload("res://scripts/foes/make.gd")
const Foe := preload("res://scripts/foes/foe.gd")
const Hound := preload("res://scripts/foes/hound.gd")
const ScrapHound := preload("res://scripts/foes/scrap_hound.gd")
const Slinger := preload("res://scripts/foes/slinger.gd")
const ScrapBrute := preload("res://scripts/foes/scrap_brute.gd")
const Shaman := preload("res://scripts/foes/shaman.gd")
const Bat := preload("res://scripts/foes/bat.gd")
const Pack := preload("res://scripts/foes/pack.gd")
const Snow := preload("res://scripts/highlands/snow.gd")
const Art := preload("res://scripts/art.gd")
const Sim := preload("res://scripts/sim.gd")
const TILE := 32.0
const HOME := Vector2(900, 560)        # the middle of the arena, far from every wall

var fails := 0
var checks := 0
var shot_dir := ""
var shot_seed := 424242
var debug_seed := 0
var trace := 0                         # "-- trace=30": the long fights print where everybody is every 30 ticks (two runs must print the same)
var soak := 0                          # "-- soak=8": only the long fights, eight times over with different dice
var m                                  # the arena
var p                                  # its player


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shot_dir = a.substr(6)
		elif a.begins_with("seed="):
			shot_seed = int(a.substr(5))
		elif a.begins_with("soak="):
			soak = int(a.substr(5))
		elif a.begins_with("land="):
			debug_seed = int(a.substr(5))
		elif a.begins_with("trace="):
			trace = int(a.substr(6))
	_run()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL  " + what)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await physics_frame
	Painter.load_kit()
	if shot_dir != "":
		await _shots()
		quit()
		return
	if soak > 0:
		for k in range(1, soak + 1):
			await _long_fights(k)
		print("%s  long fights, %d times: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", soak, checks, fails])
		quit(1 if fails > 0 else 0)
		return
	_art()
	_no_marks()
	_plans()
	await _arena_open()
	await _hound()
	await _hound_pack()
	await _slinger()
	await _brute()
	await _shaman()
	await _elite_hound()
	await _elite_slinger()
	await _elite_brute()
	await _elite_shaman()
	await _scrap_hound()
	await _arena_close()
	await _land()
	await _long_fights(43)
	print("%s  the Highlands' enemies: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


# --- The art ---------------------------------------------------------------------------------

## Every strip the enemies ask for is in the Art builder's book, with a box that lies on the sheet.
func _art() -> void:
	var book: Dictionary = Art.json(Foe.BOOK)
	var sheet := Art.texture(Foe.SHEET)
	_check(sheet != null and not book.is_empty(), "the enemies' sheet and its book are there")
	if sheet == null:
		return
	var want := {
		"hound": ["idle", "move", "crouch", "lunge", "hit", "death"],
		"hound_elite": ["idle", "move", "crouch", "lunge", "howl", "hit", "death"],
		"slinger": ["idle", "move", "windup", "throw", "hit", "death"],
		"slinger_elite": ["idle", "move", "windup", "throw", "hit", "death"],
		"brute": ["idle", "move", "windup", "swing", "open", "block", "hit", "death"],
		"brute_elite": ["idle", "move", "windup", "swing", "open", "block", "bash_windup", "bash", "hit", "death"],
		"shaman": ["idle", "move", "cast", "hit", "death"],
		"shaman_elite": ["idle", "move", "cast", "ward", "hit", "death"],
		"bat": ["fly", "dive", "puff"],
		"ward": ["back", "front"],
		"ward_big": ["back", "front"],
	}
	for name in want:
		var e: Dictionary = book.get("enemies", {}).get(name, {})
		_check(not e.is_empty(), "the book has " + name)
		for strip in want[name]:
			var s: Dictionary = e.get("strips", {}).get(strip, {})
			var box: Array = s.get("box", [])
			var ok := box.size() == 4 and int(box[0]) >= 0 and int(box[1]) >= 0 and int(box[0]) + int(box[2]) <= sheet.get_width() and int(box[1]) + int(box[3]) <= sheet.get_height()
			if ok:
				ok = int(box[2]) == int(e["frame"][0]) * int(s["frames"]) and int(box[3]) == int(e["frame"][1])
			_check(ok, "%s has its %s strip, the right size, on the sheet" % [name, strip])
			if name.ends_with("_elite"):
				_check(e.get("strips", {}).has(strip + "_rim"), "%s's %s strip has its rim" % [name, strip])
	for name in ["pebble", "rock", "shard", "pebble_puff", "rock_burst"]:
		_check(not Foe.shot(name).is_empty(), "the book has the " + name)


# --- Who lives where -------------------------------------------------------------------------

func _plans() -> void:
	var cave := Vector2(LandMap.MID + 0.5, LandMap.MID + 0.5)
	var totals := {}
	var groups := 0
	var seeds := [424242, 1, 7, 123456, 987654]
	for seed_value in seeds:
		var map: LandMap = WorldGen.make(seed_value)
		var plan := FoePlan.make(map)
		var again := FoePlan.make(WorldGen.make(seed_value))
		_check(str(plan) == str(again), "seed %d: the same land gives the same enemies" % seed_value)
		_check(plan.size() >= 8, "seed %d: the land has enemies (%d groups)" % [seed_value, plan.size()])
		groups += plan.size()
		var elites := {}
		for g in plan:
			var at: Vector2 = g["home"]
			var kinds: Array = (g["members"] as Array).map(func(mm): return str(mm[0]))
			_check(at.distance_to(cave) >= FoePlan.SAFE, "seed %d: nothing lives within %d tiles of the cave" % [seed_value, int(FoePlan.SAFE)])
			_check(not bool(map.pockets[int(g["pocket"])].get("sealed", false)), "seed %d: nothing lives in a sealed place" % seed_value)
			_check(kinds.count("scrap_brute") <= 1, "seed %d: never two Scrap Brutes together" % seed_value)
			# Two to four in the inner ring; out in the middle and outer rings the groups are bigger (version 49).
			var ring := int(map.pockets[int(g["pocket"])].get("ring", 1))
			var most: int = [0, 4, 5, 6][ring]
			if str(g["what"]) == "creatures":
				# The moor's creatures (version 63): one kind to a place, one to four, none an elite.
				_check(kinds.size() >= 1 and kinds.size() <= 4 and kinds.count(kinds[0]) == kinds.size() and kinds[0] in Make.CREATURES and not (g["members"] as Array).any(func(mm): return bool(mm[1])), "seed %d: a place of moor creatures has one to four of one kind (%s)" % [seed_value, str(kinds)])
				_check(kinds[0] != "capercaillie" or kinds.size() >= 2, "seed %d: capercaillies are never alone" % seed_value)
			else:
				_check(kinds.size() >= 2 and kinds.size() <= most, "seed %d: a group is two to %d in ring %d" % [seed_value, most, ring])
			if "shaman" in kinds:
				_check(kinds.count("shaman") == 1 and ("slinger" in kinds or "scrap_brute" in kinds), "seed %d: a shaman is with other goblins" % seed_value)
			if "hound" in kinds:
				_check(kinds.count("hound") == kinds.size(), "seed %d: hounds keep to themselves" % seed_value)
			if at.distance_to(cave) < FoePlan.NEAR and str(g["site"]) == "":
				_check(str(g["what"]) == "creatures" and kinds.size() <= 3, "seed %d: near the base only a few moor creatures (%s)" % [seed_value, str(kinds)])
			# Outside the goblin ground, the hound ground and the named places: only the moor's creatures (version 63).
			var yard_at: Vector2 = map.sites["scrapyard"]["at"] if map.sites.has("scrapyard") else Vector2.INF
			var snow_at := Snow.centre(map)
			var grounds := at.distance_to(yard_at) < FoePlan.SCRAP_REACH or (snow_at != Vector2.INF and at.distance_to(snow_at) < Snow.REACH + Snow.HOUNDS_NEAR)
			if str(g["site"]) in ["", "cairns", "gorge", "fault"] and not grounds:
				_check(str(g["what"]) == "creatures", "seed %d: away from the goblins' and the hounds' ground only moor creatures live (%s at %s)" % [seed_value, str(kinds), str(at)])
			if "scrap_hound" in kinds:
				_check(at.distance_to(yard_at) < FoePlan.SCRAP_REACH and str(g["what"]) == "goblins" and kinds.count("scrap_hound") <= 2 and "slinger" in kinds, "seed %d: war dogs live only with goblins round the Scrapyard, one or two to a group, beside a slinger (%s)" % [seed_value, str(kinds)])
			if "hound" in kinds:
				_check(str(g["what"]) == "hounds", "seed %d: wild hounds live in packs of their own" % seed_value)
			if "shaman" in kinds and bool(g["members"][0][1]):
				_check(at.distance_to(yard_at) < FoePlan.SCRAP_REACH, "seed %d: the elite shaman holds a place in the goblin ground" % seed_value)
			if str(g["site"]) == "watchpost":
				_check(kinds == ["hound", "hound", "hound"], "seed %d: hounds den at the Watchpost" % seed_value)
			if str(g["site"]) == "quarry":
				_check(g["members"][0] == ["scrap_brute", true], "seed %d: the elite Scrap Brute guards the Old Quarry" % seed_value)
			for mm in g["members"]:
				if bool(mm[1]):
					elites[str(mm[0])] = int(elites.get(str(mm[0]), 0)) + 1
		for kind in ["hound", "slinger", "scrap_brute", "shaman"]:
			_check(int(elites.get(kind, 0)) == 1, "seed %d: one elite %s on the land (%d)" % [seed_value, kind, int(elites.get(kind, 0))])
		# Goblin ground round the Scrapyard (Darren, 25 November: "I want the goblins to spawn more around the scrap
		# boss area"; version 61): every open place near its gate has goblins, none has hounds.
		if map.sites.has("scrapyard"):
			var yard: Vector2 = map.sites["scrapyard"]["at"]
			var lived := {}
			var near_goblins := 0
			var near_groups := 0
			var far_goblins := 0
			var far_groups := 0
			var ok_kind := true
			for g in plan:
				lived[int(g["pocket"])] = true
				var ring := int(map.pockets[int(g["pocket"])].get("ring", 1))
				var n: int = (g["members"] as Array).filter(func(mm): return str(mm[0]) != "hound").size()
				if (g["home"] as Vector2).distance_to(yard) < FoePlan.SCRAP_REACH and not (str(g["site"]) in ["watchpost", "quarry", "den", "roost"]):
					if str(g["what"]) != "goblins":
						ok_kind = false
					near_groups += 1
					near_goblins += n
				elif ring == 3 and str(g["what"]) == "goblins":
					far_groups += 1
					far_goblins += n
			var empty := 0
			for i in map.pockets.size():
				var pk: Dictionary = map.pockets[i]
				if not bool(pk.get("sealed", false)) and (pk["at"] as Vector2).distance_to(yard) < FoePlan.SCRAP_REACH and (pk["at"] as Vector2).distance_to(cave) >= FoePlan.SAFE and not lived.has(i):
					empty += 1
			_check(ok_kind and near_groups > 0, "seed %d: round the Scrapyard every group is goblins (%d groups)" % [seed_value, near_groups])
			_check(empty == 0, "seed %d: and no open place there is left empty (%d empty)" % [seed_value, empty])
			_check(far_groups == 0 or float(near_goblins) / float(near_groups) > float(far_goblins) / float(far_groups), "seed %d: and its groups are bigger than the rest of the outer ring's goblins (%.1f against %.1f a place)" % [seed_value, float(near_goblins) / float(maxi(near_groups, 1)), float(far_goblins) / float(maxi(far_groups, 1))])
			var dogs := 0
			for g in plan:
				dogs += (g["members"] as Array).filter(func(mm): return str(mm[0]) == "scrap_hound").size()
			_check(dogs >= 3, "seed %d: some goblin groups round the Scrapyard keep war dogs (%d)" % [seed_value, dogs])
			var gate: Array = plan.filter(func(g): return str(g["site"]) == "scrapyard")
			_check(gate.size() == 1 and (gate[0]["members"] as Array).size() == 5, "seed %d: a bigger watch on the Scrapyard gate (%s)" % [seed_value, str(gate[0]["members"]) if gate.size() == 1 else "none"])
		var c := FoePlan.count(plan)
		for k in c:
			totals[k] = int(totals.get(k, 0)) + int(c[k])
	print("      over %d lands: %d groups; %s" % [seeds.size(), groups, str(totals)])


## Darren, 23 November: "Not every enemy has to have telegraph markers for its moves, only bosses."
func _no_marks() -> void:
	for f in ["foe", "hound", "slinger", "scrap_brute", "shaman", "bat", "rock", "creature", "boar", "badger", "capercaillie", "scrap_hound"]:
		var src: String = (load("res://scripts/foes/%s.gd" % f) as GDScript).source_code
		_check(not src.contains("Warn.") and not src.contains("warn_ring") and not src.contains("func _draw_ground"), "%s.gd draws no warning mark (only bosses have them)" % f)


# --- Each kind alone, in the arena -----------------------------------------------------------

func _arena_open() -> void:
	m = load("res://scripts/main.gd").new()
	m.inputs = [PlayerInput.make("script")]
	root.add_child(m)
	await _frames(3)
	m.spawning = false
	m._set_invincible(false)
	m.clear_enemies()
	if is_instance_valid(m.home_dummy):
		m.home_dummy.queue_free()
	p = m.player
	await _frames(2)


func _arena_close() -> void:
	m.queue_free()
	await _frames(3)


func _reset(at := HOME) -> void:
	for e in get_nodes_in_group("foes"):
		e.queue_free()
	for h in get_nodes_in_group("hazards"):
		h.queue_free()
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.input.dash_pressed = false
	p.global_position = at
	p.reset_physics_interpolation()
	p.hp = p.max_hp
	p.invuln = 0.0
	p.unhurt = false
	p.hurt_vel = Vector2.ZERO
	await _frames(3)
	p.hp = p.max_hp
	p.invuln = 0.0


func _put(kind: String, offset: Vector2):
	var e = Make.make(kind)
	e.position = p.global_position + offset
	m.world.add_child(e)
	return e


## Runs until `until` says so, or `most` ticks have gone. Returns how many ticks it took (-1: it never did).
func _wait(until: Callable, most: int) -> int:
	for i in most:
		if until.call():
			return i
		await physics_frame
	return -1


## A blow on an enemy from where the player stands.
func _strike(e, dmg := 1.0, from := Vector2.INF) -> void:
	var src: Vector2 = p.global_position if from == Vector2.INF else from
	e.take_hit(dmg, (e.global_position - src).normalized(), 0.0, false, Color.WHITE)


func _hound() -> void:
	await _reset()
	var h = _put("hound", Vector2(260, 0))
	await _frames(2)
	_check(h.max_hp == Hound.HP and not h.elite, "a hound has a hound's health")
	_check(not h._sprite().is_empty(), "a hound is drawn from its pictures")
	# It runs up, then keeps its distance and goes round.
	var t := await _wait(func(): return h.global_position.distance_to(p.global_position) < Hound.RING + 40.0, 240)
	_check(t >= 0, "a hound runs up to its ring round you")
	h.rest = 9.0
	var a0: float = (h.global_position - p.global_position).angle()
	var near := INF
	var far := 0.0
	var swept := 0.0
	var last := a0
	for i in 150:
		await physics_frame
		var rel: Vector2 = h.global_position - p.global_position
		near = minf(near, rel.length())
		far = maxf(far, rel.length())
		swept += absf(angle_difference(last, rel.angle()))
		last = rel.angle()
	_check(near > 70.0 and far < Hound.RING + 70.0, "it circles at a few steps' distance (%d to %d)" % [int(near), int(far)])
	_check(swept > 1.5, "and goes round you (%.1f radians in 2.5 s)" % swept)
	_check(p.hp == p.max_hp, "circling hurts nobody")
	# The crouch is the warning, then the lunge bites.
	h.rest = 0.0
	t = await _wait(func(): return h.mode == "crouch", 60)
	_check(t >= 0, "it crouches before it lunges")
	var crouch := await _wait(func(): return h.mode != "crouch", 90)
	_check(absf(float(crouch) / 60.0 - Hound.CROUCH_TIME) < 0.06, "the crouch lasts its warning time (%.2f s)" % (float(crouch) / 60.0))
	_check(h.mode == "lunge", "then it lunges")
	await _wait(func(): return h.mode != "lunge", 60)
	_check(is_equal_approx(p.hp, p.max_hp - Hound.BITE), "the lunge bites a player who stood still (%.0f)" % (p.max_hp - p.hp))
	_check(h.mode == "recover", "after the lunge it stands a moment")
	# A lunge at a player who has stepped aside misses.
	await _reset()
	h = _put("hound", Vector2(Hound.RING, 0))
	h.rest = 0.0
	await _wait(func(): return h.mode == "crouch", 120)
	await _wait(func(): return h.mode == "crouch" and h.mode_t < Hound.LOCK_TIME, 60)
	p.global_position += Vector2(0, 90)
	p.reset_physics_interpolation()
	await _wait(func(): return h.mode == "recover", 90)
	_check(p.hp == p.max_hp, "a lunge misses a player who stepped aside once its aim was set")
	# A hit in the crouch knocks it out of the lunge.
	await _reset()
	h = _put("hound", Vector2(Hound.RING, 0))
	h.rest = 0.0
	await _wait(func(): return h.mode == "crouch", 120)
	_strike(h)
	await _frames(1)
	_check(h.mode == "recover", "a hit while it crouches stops the lunge")
	await _frames(60)
	_check(p.hp == p.max_hp, "and nobody is bitten")
	# It dies like anything else.
	_strike(h, 999.0)
	await _frames(2)
	_check(not is_instance_valid(h) or h.dead, "a hound can be killed")


## The goblins' war dog (version 64; Darren: "the wolfs at the goblin camp can have scrap armour and red eyes"): a
## hound in scrap armour, from the Art builder's hound sheet, that fights as a hound does.
func _scrap_hound() -> void:
	await _reset()
	var h = _put("scrap_hound", Vector2(260, 0))
	await _frames(2)
	_check(h.kind == "scrap_hound" and h.is_in_group("hounds") and not h.elite, "a scrap hound is a hound of its own kind")
	_check(is_equal_approx(h.max_hp, Hound.HP * ScrapHound.HP_MORE), "its plate gives it more health than a wild hound (%.0f against %.0f)" % [h.max_hp, Hound.HP])
	var sp: Dictionary = h._sprite()
	_check(not sp.is_empty() and Art.json(ScrapHound.HOUND_BOOK).get("enemies", {}).has("scrap_hound"), "it is drawn from the Art builder's hound sheet")
	var wild = _put("hound", Vector2(-260, 0))
	await _frames(2)
	_check(wild._art_info() != h._art_info() and not wild._sprite().is_empty(), "and a wild hound keeps its own pictures")
	wild.queue_free()
	var t := await _wait(func(): return h.mode == "crouch", 400)
	_check(t >= 0, "it circles and crouches as a hound does")
	_check(str(h._sprite().get("anim", "")) == "crouch", "with its own crouch")
	_check(not Make.knows("scrap_hound_elite"), "it has no elite")


func _hound_pack() -> void:
	await _reset()
	var hounds: Array = []
	for i in 3:
		var h = _put("hound", Vector2.from_angle(float(i) * 2.1) * 150.0)
		h.rest = 0.0
		hounds.append(h)
	var most := 0
	var sides := {}
	for i in 420:
		await physics_frame
		p.hp = p.max_hp
		var now := 0
		for h in hounds:
			if h.mode in ["crouch", "lunge"]:
				now += 1
			sides[int(h.side)] = true
		most = maxi(most, now)
	_check(most == 1, "in a pack of three, one hound lunges at a time (%d at once)" % most)
	var spread := 0.0
	for i in 3:
		for j in range(i + 1, 3):
			spread = maxf(spread, absf(angle_difference((hounds[i].global_position - p.global_position).angle(), (hounds[j].global_position - p.global_position).angle())))
	_check(spread > 1.2, "the pack is on more than one side of you (%.1f radians apart)" % spread)
	# Four or more: two may go at once.
	await _reset()
	hounds.clear()
	for i in 4:
		var h = _put("hound", Vector2.from_angle(float(i) * 1.6) * 150.0)
		hounds.append(h)
	most = 0
	for i in 600:
		await physics_frame
		p.hp = p.max_hp
		var now := 0
		for h in hounds:
			if h.mode in ["crouch", "lunge"]:
				now += 1
		most = maxi(most, now)
	_check(most <= 2, "in a pack of four, never more than two at once (%d)" % most)


func _slinger() -> void:
	await _reset()
	var s = _put("slinger", Vector2(200, 0))
	s.reload = 0.2
	await _frames(2)
	_check(s.max_hp == Slinger.HP and not s._sprite().is_empty(), "a slinger has its health and its pictures")
	var t := await _wait(func(): return s.mode == "windup", 60)
	_check(t >= 0, "a slinger whirls its sling before it throws")
	var wind := await _wait(func(): return s.mode != "windup", 90)
	_check(absf(float(wind) / 60.0 - Slinger.WINDUP) < 0.06, "the whirl lasts its warning time (%.2f s)" % (float(wind) / 60.0))
	var rocks := get_nodes_in_group("hazards")
	_check(rocks.size() == 1 and rocks[0].kind == "pebble", "then a pebble is in the air")
	if rocks.size() == 1:
		_check(rocks[0].to.distance_to(p.global_position) < 4.0, "aimed at where you stand")
	_check(p.hp == p.max_hp, "a pebble in the air has hurt nobody yet")
	var land := await _wait(func(): return get_nodes_in_group("hazards").is_empty(), 90)
	_check(absf(float(land) / 60.0 - Slinger.FLIGHT) < 0.06, "it lands after its flight (%.2f s)" % (float(land) / 60.0))
	_check(is_equal_approx(p.hp, p.max_hp - Slinger.PEBBLE), "and hits a player who stood on the spot (%.0f)" % (p.max_hp - p.hp))
	# Step off the spot and it misses.
	await _reset()
	s = _put("slinger", Vector2(200, 0))
	s.reload = 0.1
	await _wait(func(): return not get_nodes_in_group("hazards").is_empty(), 120)
	p.global_position += Vector2(0, 80)
	p.reset_physics_interpolation()
	await _wait(func(): return get_nodes_in_group("hazards").is_empty(), 90)
	_check(p.hp == p.max_hp, "a pebble misses a player who stepped off the spot")
	# A hit while it whirls spoils the throw.
	await _reset()
	s = _put("slinger", Vector2(200, 0))
	s.reload = 0.1
	await _wait(func(): return s.mode == "windup", 60)
	_strike(s)
	await _frames(20)
	_check(s.mode == "move" and get_nodes_in_group("hazards").is_empty(), "a hit while it whirls spoils the throw")
	# Come close and it backs away, slower than you walk.
	await _reset()
	s = _put("slinger", Vector2(80, 0))
	s.reload = 99.0
	var d0: float = s.global_position.distance_to(p.global_position)
	await _frames(40)
	var d1: float = s.global_position.distance_to(p.global_position)
	_check(d1 > d0 + 30.0, "it backs away from a player who comes close (%d to %d)" % [int(d0), int(d1)])
	_check(Slinger.FLEE < p.MOVE_SPEED * 0.7, "and backs away slower than you walk")
	# Too far, it comes nearer; in between, it holds its ground.
	await _reset()
	s = _put("slinger", Vector2(420, 0))
	s.reload = 99.0
	await _frames(120)
	_check(s.global_position.distance_to(p.global_position) < 330.0, "it comes nearer a player who is too far to hit")
	await _wait(func(): return s.velocity.length() < 1.0, 240)
	var hold: float = s.global_position.distance_to(p.global_position)
	_check(hold >= Slinger.NEAR and hold <= Slinger.FAR + 10.0, "and stops a good throw away (%d)" % int(hold))


func _brute() -> void:
	await _reset()
	var b = _put("scrap_brute", Vector2(200, 0))
	b.facing = Vector2.LEFT
	await _frames(2)
	_check(b.max_hp == ScrapBrute.HP and not b._sprite().is_empty(), "a Scrap Brute has its health and its pictures")
	# The shield stops a blow from the front; one from behind lands.
	b.cool = 99.0
	_strike(b, 10.0)
	_check(b.hp == b.max_hp, "a blow on the shield does nothing")
	_check(b._sprite()["anim"] == "block", "and shows on the shield")
	_strike(b, 10.0, b.global_position + Vector2(60, 0))
	_check(is_equal_approx(b.hp, b.max_hp - 10.0), "a blow from behind lands")
	_strike(b, 10.0, b.global_position + Vector2(0, 60))
	_check(is_equal_approx(b.hp, b.max_hp - 20.0), "and one from the side")
	var edge := Vector2.from_angle(deg_to_rad(ScrapBrute.GUARD - 5.0))
	_strike(b, 10.0, b.global_position + Vector2(-edge.x, edge.y) * 60.0)
	_check(is_equal_approx(b.hp, b.max_hp - 20.0), "the shield covers its arc to each side")
	# What rides on a blocked blow is stopped too.
	_strike(b, 10.0)
	b.apply_stun(2.0)
	_check(b.stun_time <= 0.0 and not b.add_stagger(99.0), "a blocked blow stuns and staggers nothing")
	await _frames(2)
	# It turns its shield to you, but slowly.
	p.global_position = b.global_position + Vector2(0, 150)
	p.reset_physics_interpolation()
	await _frames(6)
	_check(absf(b.facing.angle_to(Vector2.DOWN)) > 0.8, "it does not turn at once")
	await _frames(60)
	_check(absf(b.facing.angle_to((p.global_position - b.global_position).normalized())) < 0.3, "but it does turn its shield to you")
	# The swing: a warning, a blow in front of it, then it is open.
	await _reset()
	b = _put("scrap_brute", Vector2(48, 0))
	b.facing = Vector2.LEFT
	b.cool = 0.0
	var t := await _wait(func(): return b.mode == "windup", 60)
	_check(t >= 0, "close to you it raises its weapon")
	_strike(b, 10.0)
	_check(b.hp == b.max_hp, "the shield is still up while its weapon is raised")
	var wind := await _wait(func(): return b.mode != "windup", 90)
	_check(absf(float(wind) / 60.0 - ScrapBrute.WINDUP) < 0.06, "its weapon is up for its warning time (%.2f s)" % (float(wind) / 60.0))
	await _wait(func(): return b.mode == "open", 40)
	_check(is_equal_approx(p.hp, p.max_hp - ScrapBrute.CLUB), "the swing hits a player in front of it (%.0f)" % (p.max_hp - p.hp))
	_check(b.mode == "open" and not b.guarding(), "after the swing its shield is down")
	_strike(b, 10.0)
	_check(is_equal_approx(b.hp, b.max_hp - 10.0), "and a blow from the front lands")
	var open := await _wait(func(): return b.mode != "open", 120)
	_check(absf(float(open) / 60.0 - ScrapBrute.OPEN) < 0.1, "it is open for a second (%.2f s)" % (float(open) / 60.0))
	_check(b.guarding(), "then the shield is up again")
	# A player behind it when it swings is not hit.
	await _reset()
	b = _put("scrap_brute", Vector2(48, 0))
	b.facing = Vector2.LEFT
	b.cool = 0.0
	await _wait(func(): return b.mode == "windup" and b.mode_t < ScrapBrute.WINDUP - ScrapBrute.LOCK_TIME - 0.02, 90)
	p.global_position = b.global_position + Vector2(50, 0)
	p.reset_physics_interpolation()
	await _wait(func(): return b.mode == "open", 90)
	_check(p.hp == p.max_hp, "the swing misses a player who got behind it")
	# Stunned, its shield is down.
	await _reset()
	b = _put("scrap_brute", Vector2(120, 0))
	b.facing = Vector2.LEFT
	b.cool = 99.0
	b.stun_time = 1.0
	_strike(b, 10.0)
	_check(is_equal_approx(b.hp, b.max_hp - 10.0), "a stunned brute's shield is down")


func _shaman() -> void:
	await _reset()
	var s = _put("shaman", Vector2(260, 0))
	await _frames(2)
	_check(s.max_hp == Shaman.HP and not s._sprite().is_empty(), "a shaman has its health and its pictures")
	s.cast_in = 0.1
	var t := await _wait(func(): return s.mode == "cast", 60)
	_check(t >= 0, "a shaman raises its staff")
	var cast := await _wait(func(): return s.mode != "cast", 120)
	_check(absf(float(cast) / 60.0 - Shaman.CAST_TIME) < 0.06, "for its warning time (%.2f s)" % (float(cast) / 60.0))
	_check(get_nodes_in_group("bats").size() == 1, "and a bat comes")
	# A hit while the staff is up spoils the call.
	s.cast_in = 0.0
	await _wait(func(): return s.mode == "cast", 30)
	_strike(s)
	await _frames(70)
	_check(get_nodes_in_group("bats").size() == 1, "a hit while the staff is up spoils the call")
	# It never keeps more than its number.
	for i in 8:
		s.cast_in = 0.0
		await _frames(int(Shaman.CAST_TIME * 60.0) + 8)
		p.hp = p.max_hp
	_check(get_nodes_in_group("bats").size() == Shaman.BATS, "it keeps %d bats and no more (%d)" % [Shaman.BATS, get_nodes_in_group("bats").size()])
	# The bats nip.
	s.cast_in = 99.0
	p.hp = p.max_hp
	p.invuln = 0.0
	t = await _wait(func(): return p.hp < p.max_hp, 400)
	_check(t >= 0 and is_equal_approx(p.max_hp - p.hp, Bat.NIP), "a bat swoops and nips (%.0f)" % (p.max_hp - p.hp))
	# One blow kills a bat.
	var bat = get_nodes_in_group("bats")[0]
	_strike(bat, 5.0)
	await _frames(2)
	_check(get_nodes_in_group("bats").size() == Shaman.BATS - 1, "one blow kills a bat")
	# It keeps away from you.
	p.global_position = s.global_position + Vector2(-70, 0)
	p.reset_physics_interpolation()
	var d0: float = s.global_position.distance_to(p.global_position)
	await _frames(40)
	_check(s.global_position.distance_to(p.global_position) > d0 + 20.0, "a shaman backs away from a player who comes close")
	# Kill the shaman and the bats scatter.
	_strike(s, 999.0)
	await _frames(3)
	_check(get_nodes_in_group("bats").is_empty(), "kill the shaman and its bats scatter")
	# It stands behind the other goblins.
	await _reset()
	var front = _put("slinger", Vector2(200, 0))
	front.reload = 99.0
	s = _put("shaman", Vector2(150, 60))
	s.cast_in = 99.0
	await _frames(240)
	_check(s.global_position.distance_to(p.global_position) > front.global_position.distance_to(p.global_position) + 30.0, "a shaman stands behind the other goblins")


func _elite_hound() -> void:
	await _reset()
	var h = _put("hound_elite", Vector2(140, 0))
	await _frames(2)
	_check(h.elite and h.max_hp == Hound.ELITE_HP, "the pack leader is an elite with more health")
	_check(h.art_name() == "hound_elite" and h._art_tex("idle_rim") != null, "it has its own pictures and its rim")
	h.rest = 99.0
	h.howl_in = 0.1
	var t := await _wait(func(): return h.mode == "howl", 60)
	_check(t >= 0, "the pack leader howls")
	var howl := await _wait(func(): return h.mode != "howl", 120)
	_check(absf(float(howl) / 60.0 - Hound.HOWL_TIME) < 0.06, "the howl takes its time (%.2f s)" % (float(howl) / 60.0))
	await _frames(2)
	_check(get_nodes_in_group("hounds").size() == 1 + Hound.HOWL_CALLS, "and hounds answer it (%d came)" % (get_nodes_in_group("hounds").size() - 1))
	# A hit cuts a howl off.
	for e in get_nodes_in_group("hounds"):
		if e != h:
			e.queue_free()
	await _frames(2)
	h.howl_in = 0.0
	await _wait(func(): return h.mode == "howl", 60)
	_strike(h)
	await _frames(90)
	_check(get_nodes_in_group("hounds").size() == 1, "a hit while it howls cuts the howl off")
	# It does not howl a pack bigger than its most.
	for i in Hound.PACK_MOST - 1:
		var x = _put("hound", Vector2(-200, float(i) * 30.0))
		x.rest = 99.0
	h.howl_in = 0.0
	await _frames(120)
	p.hp = p.max_hp
	_check(get_nodes_in_group("hounds").size() == Hound.PACK_MOST, "it does not call a pack bigger than %d" % Hound.PACK_MOST)
	# Its bite is harder.
	await _reset()
	h = _put("hound_elite", Vector2(Hound.RING, 0))
	h.howl_in = 99.0
	h.rest = 0.0
	await _wait(func(): return h.mode == "recover", 200)
	_check(is_equal_approx(p.hp, p.max_hp - Hound.ELITE_BITE), "the pack leader bites harder (%.0f)" % (p.max_hp - p.hp))


func _elite_slinger() -> void:
	await _reset()
	var s = _put("slinger_elite", Vector2(220, 0))
	s.reload = 0.1
	await _frames(2)
	_check(s.elite and s.max_hp == Slinger.ELITE_HP and s.art_name() == "slinger_elite", "the elite slinger has more health and its own pictures")
	await _wait(func(): return not get_nodes_in_group("hazards").is_empty(), 120)
	var rocks := get_nodes_in_group("hazards")
	_check(rocks.size() == 1 and rocks[0].kind == "rock", "it throws a big rock")
	s.reload = 99.0
	# Stand clear of the rock, in the way of a shard.
	var spot: Vector2 = rocks[0].to if rocks.size() == 1 else p.global_position
	p.global_position = spot + Vector2(0, Slinger.ELITE_SPLASH + 30.0)
	p.reset_physics_interpolation()
	await _wait(func(): return get_nodes_in_group("hazards").any(func(r): return r.kind == "shard"), 120)
	var shards := get_nodes_in_group("hazards").filter(func(r): return r.kind == "shard")
	_check(shards.size() == Slinger.SHARDS, "the rock bursts into %d shards (%d)" % [Slinger.SHARDS, shards.size()])
	_check(p.hp == p.max_hp, "the rock itself misses a player who stepped clear")
	# Point one shard straight at the player: it hurts the first player it meets, and no more.
	if not shards.is_empty():
		shards[0].global_position = spot
		shards[0].dir = (p.global_position - spot).normalized()
	await _wait(func(): return get_nodes_in_group("hazards").is_empty(), 120)
	_check(is_equal_approx(p.hp, p.max_hp - Slinger.SHARD_DAMAGE), "a shard hurts the player it meets (%.0f)" % (p.max_hp - p.hp))
	# Standing on the spot, the rock itself hits.
	await _reset()
	s = _put("slinger_elite", Vector2(220, 0))
	s.reload = 0.1
	await _wait(func(): return not get_nodes_in_group("hazards").is_empty(), 120)
	s.reload = 99.0
	await _wait(func(): return p.hp < p.max_hp, 120)
	_check(is_equal_approx(p.hp, p.max_hp - Slinger.ELITE_ROCK), "the big rock hits a player who stood on the spot (%.0f)" % (p.max_hp - p.hp))


func _elite_brute() -> void:
	await _reset()
	var b = _put("scrap_brute_elite", Vector2(48, 0))
	b.facing = Vector2.LEFT
	b.cool = 0.0
	await _frames(2)
	_check(b.elite and b.max_hp == ScrapBrute.ELITE_HP and b.art_name() == "brute_elite", "the elite brute has more health and its own pictures")
	var seen: Array = []
	var last := ""
	for i in 900:
		await physics_frame
		p.hp = p.max_hp
		p.invuln = 0.0
		if b.mode != last:
			last = b.mode
			if b.mode in ["swing", "bash"]:
				seen.append(b.mode)
		if seen.size() >= 6:
			break
		# Keep in front of it, close.
		if b.mode == "advance" and p.global_position.distance_to(b.global_position) > 70.0:
			p.global_position = b.global_position + b.facing * 50.0
			p.reset_physics_interpolation()
			p.hurt_vel = Vector2.ZERO
	_check(seen == ["swing", "swing", "bash", "swing", "swing", "bash"], "every third attack of the elite is a shield bash (%s)" % str(seen))
	# The bash knocks you a long way back.
	await _reset()
	b = _put("scrap_brute_elite", Vector2(120, 0))
	b.facing = Vector2.LEFT
	b.attacks = ScrapBrute.BASH_EVERY - 1
	b.cool = 0.0
	var t := await _wait(func(): return b.mode == "bash_windup", 60)
	_check(t >= 0, "it draws back for the bash from a little way off")
	var x0: float = p.global_position.x
	await _wait(func(): return p.hp < p.max_hp, 120)
	_check(is_equal_approx(p.hp, p.max_hp - ScrapBrute.BASH), "the bash hits (%.0f)" % (p.max_hp - p.hp))
	await _frames(30)
	_check(x0 - p.global_position.x > 90.0, "and knocks you a long way back (%d)" % int(x0 - p.global_position.x))
	await _wait(func(): return b.mode == "open", 120)
	_check(b.mode == "open", "after the bash it is open")


func _elite_shaman() -> void:
	await _reset()
	var g = _put("slinger", Vector2(120, 0))
	g.reload = 99.0
	var s = _put("shaman_elite", Vector2(260, 0))
	s.cast_in = 99.0
	s.ward_in = 0.1
	await _frames(2)
	_check(s.elite and s.max_hp == Shaman.ELITE_HP and s.art_name() == "shaman_elite", "the elite shaman has more health and its own pictures")
	var t := await _wait(func(): return s.mode == "ward", 60)
	_check(t >= 0, "the elite shaman levels its staff at another goblin")
	await _wait(func(): return g.warded > 0.0, 90)
	_check(g.warded > 0.0, "and that goblin is warded")
	_strike(g, 10.0)
	g.apply_stun(1.0)
	_check(g.hp == g.max_hp and g.stun_time <= 0.0, "a warded goblin cannot be hurt or stunned")
	var ward := await _wait(func(): return g.warded <= 0.0, 400)
	_check(absf(float(ward) / 60.0 - Shaman.WARD_TIME) < 0.1, "the ward lasts its time (%.2f s)" % (float(ward) / 60.0))
	_strike(g, 10.0)
	_check(is_equal_approx(g.hp, g.max_hp - 10.0), "then it can be hurt again")
	# It never wards itself, and with no other goblin it wards nobody.
	g.queue_free()
	await _frames(2)
	s.ward_in = 0.0
	await _frames(120)
	_check(s.warded <= 0.0 and s.mode != "ward", "it does not ward itself")
	# It calls two bats at a time and keeps more.
	for i in 6:
		s.cast_in = 0.0
		await _frames(int(Shaman.CAST_TIME * 60.0) + 8)
		p.hp = p.max_hp
		if i == 0:
			_check(get_nodes_in_group("bats").size() == Shaman.ELITE_A_CAST, "the elite calls %d bats at a time" % Shaman.ELITE_A_CAST)
	_check(get_nodes_in_group("bats").size() == Shaman.ELITE_BATS, "and keeps %d (%d)" % [Shaman.ELITE_BATS, get_nodes_in_group("bats").size()])


# --- On the land -----------------------------------------------------------------------------

func _game(seed_value: int):
	var g = Highlands.new()
	g.inputs = [PlayerInput.make("script")]
	g.world_seed = seed_value
	g.welcome = false
	root.add_child(g)
	return g


func _land() -> void:
	var g = _game(424242)
	await _frames(3)
	var q = g.player
	var foes = g.foes
	print("      the way-finding grid for one land: %.0f ms; %d groups on it" % [foes.nav.made_ms, foes.plan.size()])
	_check(foes.nav.made_ms < 400.0, "the way-finding grid is made quickly (%.0f ms)" % foes.nav.made_ms)
	# At the cave nothing is awake, and the way from the cave to every group's home can be walked.
	await _frames(40)
	var quiet := true
	for e in get_nodes_in_group("foes"):
		if e.fighting() or e.global_position.distance_to(q.global_position) < 30.0 * TILE:
			quiet = false
	_check(quiet, "at the cave mouth no enemy is near and none has seen you")
	var walk := true
	for gr in foes.plan:
		if gr.has("room"):
			continue                  # (the Scrapyard's rooms are behind its gate and their barred doors)
		if foes.nav.steps(q.global_position, (gr["home"] as Vector2) * TILE) < 0:
			walk = false
	_check(walk, "every group's home out on the land can be walked to from the cave")
	# The nearest group of hounds: come near and it is there, at home, calm.
	var hounds: Dictionary = _nearest(foes, q.global_position, "hounds")
	var home: Vector2 = (hounds["home"] as Vector2) * TILE
	q.unhurt = true
	q.global_position = _spot_off(foes, home, 1000.0)
	q.reset_physics_interpolation()
	g.rig.snap()
	await _frames(40)
	var pack = foes.packs.get(int(hounds["id"]))
	_check(pack != null and pack.members.size() == (hounds["members"] as Array).size(), "coming within reach of a group's home puts it on the land")
	if pack == null:
		g.queue_free()
		return
	_check(not pack.alert, "it has not seen you yet")
	var at_home := true
	for e in pack.members:
		if e.global_position.distance_to(pack.home) > pack.reach + 96.0 or not foes.nav.is_free(Nav.tile_of(e.global_position)):
			at_home = false
	_check(at_home, "everyone stands on open ground at its home")
	await _frames(60)
	_check(pack.members.all(func(e): return e.velocity.length() < 1.0), "a calm group stands still")
	# Walk into view and the whole pack fights.
	q.global_position = _spot_off(foes, pack.members[0].global_position, 200.0, true)
	q.reset_physics_interpolation()
	await _frames(30)
	_check(pack.alert, "it sees a player in the open and the whole group fights")
	await _frames(240)
	_check(pack.members.any(func(e): return e.global_position.distance_to(q.global_position) < 220.0), "the hounds close in")
	# Hurt one, go far away: they give up, go home and get their health back.
	var hurt = pack.members[0]
	hurt.take_hit(5.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	q.global_position = _spot_off(foes, home, 1200.0)
	q.reset_physics_interpolation()
	g.rig.snap()
	var t := await _wait(func(): return not pack.alert, 300)
	_check(t >= 0, "with everybody far away the group gives up")
	t = await _wait(func(): return pack.members.all(func(e): return e.global_position.distance_to(e.home) < 40.0), 1500)
	_check(t >= 0, "and walks home")
	_check(is_instance_valid(hurt) and hurt.hp == hurt.max_hp, "and gets its health back")
	# A hit wakes a group that has not seen you.
	hurt.take_hit(1.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	_check(pack.alert, "a hit wakes a calm group")
	await _wait(func(): return not pack.alert, 400)
	# Kill one: it stays dead, then comes back when nobody is near.
	var before: int = pack.members.size()
	Foes.BACK_AFTER = 2.0
	hurt.take_hit(999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(30)
	_check(pack.living().size() == before - 1 and foes.fallen.has(int(hounds["id"])), "a killed hound is gone")
	t = await _wait(func(): return pack.living().size() == before, 400)
	_check(t >= 0, "and is back after its time, with nobody near (%.1f s)" % (float(t) / 60.0))
	Foes.BACK_AFTER = 300.0
	# Far enough away the group is taken off the land again.
	var were: Array = pack.members.duplicate()
	q.global_position = _spot_off(foes, home, Foes.SLEEP + 300.0)
	q.reset_physics_interpolation()
	g.rig.snap()
	await _frames(40)
	_check(not foes.packs.has(int(hounds["id"])), "far from everybody a group is put away")
	_check(were.all(func(e): return not is_instance_valid(e)), "and none of it is left standing about")
	# Goblins: the slingers throw from behind what there is to stand behind, and find their way round the rock.
	var goblins: Dictionary = _nearest(foes, q.global_position, "goblins")
	home = (goblins["home"] as Vector2) * TILE
	q.global_position = _spot_off(foes, home, 260.0, true)
	q.reset_physics_interpolation()
	g.rig.snap()
	await _frames(60)
	pack = foes.packs.get(int(goblins["id"]))
	_check(pack != null and pack.alert, "a goblin group wakes and sees you")
	if pack != null:
		t = await _wait(func(): return not get_nodes_in_group("hazards").is_empty(), 600)
		_check(t >= 0, "a slinger on the land throws at you")
	# Digging changes what can be walked.
	var rock := _rock_beside(g.map, Nav.tile_of(q.global_position))
	if rock.x >= 0:
		_check(not foes.nav.is_free(rock), "rock cannot be walked")
		var stamp: int = foes.nav.stamp
		g.map.dig(rock.x, rock.y)
		g.tools._tell_nav(rock, Vector2.INF)
		_check(foes.nav.is_free(rock) and foes.nav.stamp > stamp, "a dug tile can, and the way-finding knows at once")
	# With the enemies switched off the land is empty (the tests of other things).
	g.queue_free()
	await _frames(3)
	g = _game(424242)
	g.foes.on = false
	await _frames(3)
	g.player.global_position = (g.foes.plan[0]["home"] as Vector2) * TILE
	await _frames(60)
	_check(get_nodes_in_group("foes").is_empty(), "with enemies switched off nothing wakes")
	g.queue_free()
	await _frames(3)


## Long fights on the land with a player who cannot be hurt and keeps walking about: nobody ends up in the rock,
## nobody stands lost while there is somebody to fight, and the game keeps its pace.
func _long_fights(dice: int) -> void:
	var walks := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for seed_value in ([424242, 77] if debug_seed == 0 else [debug_seed]):
		var g = _game(seed_value)
		await _frames(3)
		# The dice are set once the game is made (a game shuffles them when it starts, as it must for real play):
		# from here the same dice give the same fights on every run.
		Sim.seed_with(dice)
		var q = g.player
		q.unhurt = true
		var foes = g.foes
		var by_what := {"hounds": 0, "goblins": 0}
		var in_rock := 0
		var lost := 0
		var fights := 0
		var woke := 0
		var ticks := 0
		var t0 := Time.get_ticks_usec()
		for gr in foes.plan:
			if str(gr["what"]) == "creatures":
				continue                 # (they wake only when hit: the creatures' own suite fights them)
			var elite: bool = (gr["members"] as Array).any(func(mm): return bool(mm[1]))
			if not elite and int(by_what[str(gr["what"])]) >= 3:
				continue
			by_what[str(gr["what"])] = int(by_what[str(gr["what"])]) + (0 if elite else 1)
			fights += 1
			var home: Vector2 = (gr["home"] as Vector2) * TILE
			q.global_position = _spot_off(foes, home, 220.0, true)
			q.reset_physics_interpolation()
			g.rig.snap()
			await _frames(30)
			var pack = foes.packs.get(int(gr["id"]))
			if pack == null or not pack.alert:
				var near := INF
				if pack != null:
					for e in pack.members:
						near = minf(near, e.global_position.distance_to(q.global_position))
				print("      not joined: group %d (%s, seed %d): %s, nearest member %.0f away, player %.0f from its home" % [int(gr["id"]), str(gr["what"]), seed_value, "not on the land" if pack == null else "calm", near, q.global_position.distance_to(home)])
				continue
			woke += 1
			var still := {}                      # enemy -> [where it was, for how many ticks]
			for f in 720:
				q.input.move = walks[(f / 80 + fights) % walks.size()] if (f / 80) % 3 != 2 else Vector2.ZERO
				await physics_frame
				ticks += 1
				if trace > 0 and f % trace == 0:
					var line := "T %d %d %d p %.2f,%.2f" % [seed_value, fights, f, q.global_position.x, q.global_position.y]
					for e in pack.members:
						if is_instance_valid(e):
							line += " | %s %s %.2f,%.2f" % [e.kind, e.mode, e.global_position.x, e.global_position.y]
					print(line)
				for e in pack.members:
					if not is_instance_valid(e) or e.dead or e.kind == "bat":
						continue
					var at: Vector2 = e.global_position
					var tile := Nav.tile_of(at)
					if not is_finite(at.x) or not is_finite(at.y) or g.map.is_rock(tile.x, tile.y):
						in_rock += 1
						if in_rock <= 6 or in_rock % 200 == 0:
							print("      in rock: a %s (%s, summoned %s) of group %d (seed %d) at %s tile %s, mode %s, tick %d, home %s" % [e.kind, "elite" if e.elite else "plain", str(e.summoned), int(gr["id"]), seed_value, str(at), str(tile), e.mode, f, str(Nav.tile_of(e.home))])
					var id: int = e.get_instance_id()
					var was: Array = still.get(id, [at, 0])
					if at.distance_to(was[0]) > 6.0:
						was = [at, 0]
					else:
						was[1] = int(was[1]) + 1
					still[id] = was
					# Standing on one spot for five seconds, far from the player and not able to see them: lost.
					if int(was[1]) == 300 and pack.alert and e.kind != "shaman" and at.distance_to(q.global_position) > 340.0 and not e.sees(q.global_position):
						lost += 1
						print("      lost: a %s of group %d (seed %d) at %s, player at %s" % [e.kind, int(gr["id"]), seed_value, str(Nav.tile_of(at)), str(Nav.tile_of(q.global_position))])
			q.input.move = Vector2.ZERO
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(maxi(ticks, 1))
		# Where everybody ended up, as one number: the same dice must give the same fights on every run.
		var mark := 0.0
		for e in get_nodes_in_group("foes"):
			mark += e.global_position.x + e.global_position.y * 0.37
		print("      seed %d, dice %d: %d fights (%d joined), %.2f ms a tick, everybody ended at mark %.1f" % [seed_value, dice, fights, woke, ms, mark])
		_check(woke >= fights - 1 and fights >= 8, "seed %d: the groups come to fight (%d of %d)" % [seed_value, woke, fights])
		_check(in_rock == 0, "seed %d: nobody is ever inside the rock (%d)" % [seed_value, in_rock])
		_check(lost == 0, "seed %d: nobody stands lost while a fight goes on (%d)" % [seed_value, lost])
		_check(ms < 8.0, "seed %d: a fight keeps the game's pace (%.2f ms a tick)" % [seed_value, ms])
		g.queue_free()
		await _frames(3)


func _nearest(foes, from: Vector2, what: String) -> Dictionary:
	var best := {}
	var best_d := INF
	for gr in foes.plan:
		if str(gr["what"]) != what or (gr["members"] as Array).any(func(mm): return bool(mm[1])):
			continue
		var d: float = ((gr["home"] as Vector2) * TILE).distance_to(from)
		if d < best_d:
			best_d = d
			best = gr
	return best


## Open ground about `far` from a place (with `seen`: in plain view of it), the same one every time.
func _spot_off(foes, from: Vector2, far: float, seen := false) -> Vector2:
	for ring in [0.0, 60.0, -60.0, 120.0, -120.0, 200.0]:
		for s in 24:
			var at: Vector2 = from + Vector2.from_angle(TAU * float(s) / 24.0) * (far + ring)
			var tile := Nav.tile_of(at)
			if not foes.nav.is_free(tile) or foes.nav.steps(at, from) < 0:
				continue
			if seen and not (foes.nav.sees(at, from) and foes.nav.clear(at, from)):
				continue
			return Nav.middle_of(tile)
	return from


func _rock_beside(map: LandMap, c: Vector2i) -> Vector2i:
	for r in range(1, 12):
		for j in range(-r, r + 1):
			for i in range(-r, r + 1):
				var at := c + Vector2i(i, j)
				if map.kind(at.x, at.y) == LandMap.ROCK and not map.fixed(at.x, at.y):
					return at
	return Vector2i(-1, -1)


# --- Pictures --------------------------------------------------------------------------------

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 640:
		img.resize(640, 360, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [shot_dir, name])
	print("saved %s/%s.png" % [shot_dir, name])


## Waits until `until` says so (or `most` ticks), then `after` ticks more, and takes the picture.
func _snap_when(name: String, until: Callable, most := 600, after := 0) -> void:
	await _wait(until, most)
	await _frames(after)
	await _snap(name)


func _hazard(kind: String) -> bool:
	for h in get_nodes_in_group("hazards"):
		if is_instance_valid(h) and h.kind == kind and not h.is_queued_for_deletion():
			return true
	return false


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await _arena_open()
	m._set_invincible(true)
	# Everybody side by side, as they first stand.
	await _reset()
	var names := ["hound", "slinger", "scrap_brute", "shaman", "bat", "hound_elite", "slinger_elite", "scrap_brute_elite", "shaman_elite"]
	for i in names.size():
		var e = _put(names[i], Vector2(-230.0 + 115.0 * float(i % 5) + (58.0 if i >= 5 else 0.0), -150.0 if i < 5 else 130.0))
		e.held = true
	await _frames(2)
	await _snap("01_everyone")
	# Hounds.
	await _reset()
	var hounds: Array = [_put("hound", Vector2(150, -40)), _put("hound", Vector2(-140, 60)), _put("hound", Vector2(30, 160))]
	await _frames(70)
	await _snap("02_hounds_circle")
	await _snap_when("03_hound_crouch", func(): return hounds.any(func(h): return h.mode == "crouch"), 600, 14)
	await _snap_when("04_hound_lunge", func(): return hounds.any(func(h): return h.mode == "lunge"), 200, 5)
	await _snap_when("05_hound_after", func(): return hounds.any(func(h): return h.mode == "recover"), 200, 8)
	# A slinger.
	await _reset()
	var s = _put("slinger", Vector2(210, -30))
	s.reload = 0.3
	await _snap_when("06_slinger_whirl", func(): return s.mode == "windup", 300, 16)
	await _snap_when("07_pebble_up", func(): return _hazard("pebble"), 200, 14)
	await _snap_when("08_pebble_down", func(): return _hazard("pebble"), 10, 20)
	await _frames(8)
	await _snap("09_pebble_landed")
	# A Scrap Brute.
	await _reset()
	var b = _put("scrap_brute", Vector2(150, 0))
	b.facing = Vector2.LEFT
	await _frames(40)
	_strike(b, 5.0)
	await _frames(5)
	await _snap("10_brute_blocked")
	await _snap_when("11_brute_raised", func(): return b.mode == "windup", 600, 20)
	await _snap_when("12_brute_swing", func(): return b.mode == "swing", 200, 6)
	await _snap_when("13_brute_open", func(): return b.mode == "open", 200, 14)
	_strike(b, 5.0)
	await _frames(5)
	await _snap("14_brute_hit_while_open")
	# A shaman behind two slingers.
	await _reset()
	_put("slinger", Vector2(190, -50))
	_put("slinger", Vector2(190, 60))
	var sh = _put("shaman", Vector2(290, 0))
	sh.cast_in = 0.4
	await _snap_when("15_shaman_staff_up", func(): return sh.mode == "cast", 300, 30)
	await _snap_when("16_bat_called", func(): return sh.bats.size() >= 1, 300, 20)
	await _snap_when("17_bats", func(): return sh.bats.size() >= 2, 700, 40)
	await _snap_when("18_bat_swoop", func(): return sh.bats.any(func(x): return is_instance_valid(x) and x.mode == "dive"), 600, 6)
	sh.take_hit(999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(6)
	await _snap("19_shaman_dead_bats_scatter")
	# The pack leader.
	await _reset()
	var eh = _put("hound_elite", Vector2(170, 0))
	_put("hound", Vector2(-120, 120))
	eh.howl_in = 0.5
	await _snap_when("20_leader_howls", func(): return eh.mode == "howl", 400, 36)
	await _snap_when("21_hounds_answer", func(): return get_nodes_in_group("hounds").size() >= 4, 400, 50)
	# The elite slinger.
	await _reset()
	var es = _put("slinger_elite", Vector2(220, 20))
	es.reload = 0.3
	await _snap_when("22_big_rock_raised", func(): return es.mode == "windup", 300, 30)
	await _snap_when("23_big_rock_up", func(): return _hazard("rock"), 200, 26)
	await _snap_when("24_big_rock_coming_down", func(): return _hazard("rock"), 10, 20)
	p.global_position += Vector2(-20, 84)       # off the spot, so the shards are seen flying
	p.reset_physics_interpolation()
	await _snap_when("25_shards", func(): return _hazard("shard"), 100, 5)
	await _snap_when("26_shards_later", func(): return _hazard("shard"), 10, 8)
	# The elite brute.
	await _reset()
	var eb = _put("scrap_brute_elite", Vector2(170, 0))
	eb.attacks = ScrapBrute.BASH_EVERY - 1
	await _snap_when("27_elite_brute_draws_back", func(): return eb.mode == "bash_windup", 400, 30)
	await _snap_when("28_elite_brute_bash", func(): return eb.mode == "bash", 200, 6)
	await _snap_when("29_elite_brute_open", func(): return eb.mode == "open", 200, 10)
	# The elite shaman wards a brute.
	await _reset()
	var wb = _put("scrap_brute", Vector2(130, 30))
	var ws = _put("slinger", Vector2(200, -80))
	var esh = _put("shaman_elite", Vector2(300, 0))
	esh.ward_in = 0.4
	esh.cast_in = 3.0
	await _snap_when("30_elite_shaman_wards", func(): return esh.mode == "ward", 400, 26)
	await _snap_when("31_warded", func(): return wb.warded > 0.0 or ws.warded > 0.0, 200, 20)
	var warded = wb if wb.warded > 0.0 else ws
	warded.take_hit(8.0, Vector2.UP, 0.0, false, Color.WHITE)
	await _frames(6)
	await _snap("32_warded_blow")
	await _snap_when("33_elite_shaman_bats", func(): return esh.bats.size() >= 4, 900, 40)
	await _arena_close()
	# On the land.
	var g = _game(shot_seed)
	await _frames(5)
	var q = g.player
	q.unhurt = true
	var foes = g.foes
	_plan_picture(g.map, foes.plan)
	var n := 0
	for want in [["hounds", "", false], ["goblins", "", false], ["hounds", "watchpost", false], ["goblins", "quarry", true], ["hounds", "", true], ["goblins", "", true]]:
		for gr in _groups(foes, q.global_position, str(want[0]), str(want[1]), bool(want[2])):
			n += 1
			var home: Vector2 = (gr["home"] as Vector2) * TILE
			var kinds: Array = (gr["members"] as Array).map(func(mm): return str(mm[0]) + ("_elite" if bool(mm[1]) else ""))
			var tag := "%02d_%s%s" % [40 + n, str(want[0]) if str(want[1]) == "" else str(want[1]), "_elite" if bool(want[2]) else ""]
			print("      %s: %s at %s, %d tiles from the cave" % [tag, str(kinds), str(gr["home"]), int((gr["home"] as Vector2).distance_to(g.map.spawn))])
			q.global_position = _spot_off(foes, home, 340.0, true)
			q.reset_physics_interpolation()
			g.rig.snap()
			await _frames(30)
			await _snap(tag + "_a_at_home")
			q.global_position = _spot_off(foes, home, 230.0, true)
			q.reset_physics_interpolation()
			g.rig.snap()
			await _frames(110)
			await _snap(tag + "_b_fight")
			await _frames(120)
			await _snap(tag + "_c_fight")
			await _frames(150)
			await _snap(tag + "_d_fight")
	g.queue_free()
	await _frames(3)


## Up to two groups of a sort, nearest first.
func _groups(foes, from: Vector2, what: String, site: String, elite: bool) -> Array:
	var out: Array = []
	for gr in foes.plan:
		if str(gr["what"]) != what or str(gr["site"]) != site:
			continue
		if (gr["members"] as Array).any(func(mm): return bool(mm[1])) != elite:
			continue
		out.append(gr)
	out.sort_custom(func(a, b): return ((a["home"] as Vector2) * TILE).distance_to(from) < ((b["home"] as Vector2) * TILE).distance_to(from))
	return out.slice(0, 1 if site != "" or elite else 2)


## The whole land from above, a dot for every group: hounds pale, goblins dark, elites ringed.
func _plan_picture(map: LandMap, plan: Array) -> void:
	var r: Rect2i = map.region
	var img := Image.create(r.size.x * 2, r.size.y * 2, false, Image.FORMAT_RGB8)
	for y in r.size.y:
		for x in r.size.x:
			var k := map.kind(r.position.x + x, r.position.y + y)
			var c := Color("#3a3944")
			if k == LandMap.WATER:
				c = Color("#3f5f7a")
			elif k == LandMap.TIN or k == LandMap.COPPER:
				c = Color("#6a5a48")
			elif map.walkable(r.position.x + x, r.position.y + y):
				c = Color("#8f9a78")
			img.fill_rect(Rect2i(x * 2, y * 2, 2, 2), c)
	var cave := (Vector2i(map.spawn) - r.position) * 2
	for ring in [FoePlan.SAFE, FoePlan.NEAR]:
		for a in 720:
			var at := cave + Vector2i(Vector2.from_angle(TAU * float(a) / 720.0) * float(ring) * 2.0)
			if Rect2i(0, 0, img.get_width(), img.get_height()).has_point(at):
				img.set_pixelv(at, Color("#e8e2c8"))
	img.fill_rect(Rect2i(cave - Vector2i(3, 3), Vector2i(7, 7)), Color("#ffffff"))
	for gr in plan:
		var at := (Vector2i(gr["home"] as Vector2) - r.position) * 2
		var elite: bool = (gr["members"] as Array).any(func(mm): return bool(mm[1]))
		if elite or str(gr["site"]) != "":
			img.fill_rect(Rect2i(at - Vector2i(6, 6), Vector2i(13, 13)), Color("#ffd24a") if elite else Color("#ffffff"))
		img.fill_rect(Rect2i(at - Vector2i(4, 4), Vector2i(9, 9)), Color("#f2efe6") if str(gr["what"]) == "hounds" else Color("#7a2f2a"))
	img.save_png("%s/00_where_they_live.png" % shot_dir)
	print("saved %s/00_where_they_live.png" % shot_dir)
