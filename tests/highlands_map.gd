extends SceneTree
## Darren's notes after playing version 55 (version 56): the player drawn smaller, walking slower, every blow doing
## less, the small map in the corner with the land that has been seen, the whole map on M, and the role trees drawn
## as trees. Version 57: the lab's map switch (Darren: "add map reveal to the lab and click on it to teleport. can only
## teleport to ground walkable"). Prints PASS / FAIL lines.
##
##   godot --headless --path . --fixed-fps 60 -s tests/highlands_map.gd

const PlayerInput := preload("res://scripts/player_input.gd")
const LandMap := preload("res://scripts/highlands/land_map.gd")
const Painter := preload("res://scripts/highlands/land_painter.gd")
const Highlands := preload("res://scripts/highlands/highlands.gd")
const Charts := preload("res://scripts/highlands/charts.gd")
const PlayerScript := preload("res://scripts/player.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const ForgeHall := preload("res://scripts/ui/forge_hall.gd")
const Perks := preload("res://scripts/highlands/perks.gd")
const Art := preload("res://scripts/art.gd")
const TILE := 32.0

var fails := 0
var checks := 0


func _init() -> void:
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
	await _rules()
	await _map()
	await _whole_map()
	await _saved()
	await _lab_map()
	_trees()
	print("%s  the Highlands' map, Darren's version 55 notes and the lab's map switch: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func _game(seed_value: int, players := 1, save := {}):
	var g = Highlands.new()
	var inputs: Array = []
	for i in players:
		inputs.append(PlayerInput.make("script"))
	g.inputs = inputs
	g.world_seed = seed_value
	g.world_save = save
	g.with_foes = false
	g.welcome = false
	root.add_child(g)
	return g


func _leave(g) -> void:
	g.queue_free()
	await _frames(3)
	paused = false


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


# --- Smaller, slower, softer ----------------------------------------------------------------------

func _rules() -> void:
	var g = _game(5601)
	await _frames(5)
	var p = g.players[0]
	_check(is_equal_approx(PlayerScript.SIZE, Highlands.PLAYER_SIZE) and Highlands.PLAYER_SIZE < 1.0, "in the Highlands the player is drawn smaller (%.2f)" % PlayerScript.SIZE)
	_check(is_equal_approx(p.body_circle.radius, PlayerScript.RADIUS * Highlands.PLAYER_SIZE), "and their body is as much smaller (radius %.1f)" % p.body_circle.radius)
	_check(is_equal_approx(p.trail_layer.scale.x, Highlands.PLAYER_SIZE) and is_equal_approx(p.weapon_group.scale.x, Highlands.PLAYER_SIZE), "the swing and the weapon are drawn to match")
	_check(is_equal_approx(p._hit_reach(), (p._reach_px() + PlayerScript.REACH_MARGIN) * Highlands.PLAYER_SIZE), "and the swing reaches as far as it is drawn")
	_check(PlayerScript.RADIUS * 2.0 * Highlands.PLAYER_SIZE < TILE, "the player is narrower than a tile (%.0f of %.0f world units)" % [PlayerScript.RADIUS * 2.0 * Highlands.PLAYER_SIZE, TILE])
	_check(is_equal_approx(PlayerScript.PACE, Highlands.PLAYER_PACE) and Highlands.PLAYER_PACE < 1.0, "the player walks slower (%.2f of before)" % PlayerScript.PACE)
	# Walk right for a second on open ground and see how far it goes.
	var m: LandMap = g.map
	var start: Vector2 = p.global_position
	p.input.move = Vector2.RIGHT
	await _frames(60)
	p.input.move = Vector2.ZERO
	var went: float = p.global_position.x - start.x
	_check(went > 0.0 and went <= PlayerScript.MOVE_SPEED * Highlands.PLAYER_PACE * 1.1, "a second's walk goes no further than the slower pace (%.0f world units)" % went)
	_check(is_equal_approx(SwingBuild.DAMAGE_SHARE, Highlands.DAMAGE_DEALT) and Highlands.DAMAGE_DEALT < 1.0, "the squad's blows do less (%.2f)" % SwingBuild.DAMAGE_SHARE)
	var b: Dictionary = g.builds[0].compute()
	SwingBuild.DAMAGE_SHARE = 1.0
	var full: Dictionary = g.builds[0].compute()
	SwingBuild.DAMAGE_SHARE = Highlands.DAMAGE_DEALT
	_check(is_equal_approx(float(b["damage"]), float(full["damage"]) * Highlands.DAMAGE_DEALT), "and the forge's own numbers say so (%.1f of %.1f)" % [float(b["damage"]), float(full["damage"])])
	_check(is_equal_approx(PlayerScript.HURT_SHARE, Highlands.DAMAGE_TAKEN) and Highlands.DAMAGE_TAKEN < 1.0, "enemies' blows do less too (%.2f)" % PlayerScript.HURT_SHARE)
	var hp: float = p.hp
	p.take_damage(10.0, p.global_position + Vector2(40, 0))
	_check(is_equal_approx(hp - p.hp, 10.0 * Highlands.DAMAGE_TAKEN), "a blow of 10 takes %.1f" % (hp - p.hp))
	# The lab's sliders change them while the game runs.
	Highlands.PLAYER_SIZE = 1.0
	g.lab_changed()
	_check(is_equal_approx(PlayerScript.SIZE, 1.0) and is_equal_approx(p.body_circle.radius, PlayerScript.RADIUS) and is_equal_approx(p.trail_layer.scale.x, 1.0), "the lab's size slider takes effect at once")
	Highlands.PLAYER_SIZE = 0.75
	g.lab_changed()
	await _leave(g)
	_check(is_equal_approx(PlayerScript.SIZE, 1.0) and is_equal_approx(PlayerScript.PACE, 1.0) and is_equal_approx(SwingBuild.DAMAGE_SHARE, 1.0) and is_equal_approx(PlayerScript.HURT_SHARE, 1.0), "leaving the Highlands puts the arena and the cave back as they were")


# --- The small map -----------------------------------------------------------------------------

func _map() -> void:
	var g = _game(5602)
	await _frames(12)
	var c = g.charts
	_check(c != null, "the Highlands have a map")
	if c == null:
		await _leave(g)
		return
	var m: LandMap = g.map
	var p = g.players[0]
	var at: Vector2i = Vector2i((p.global_position / TILE).floor())
	_check(c.seen(at.x, at.y), "the land where the player stands has been seen")
	_check(c.seen(at.x + 18, at.y) and c.seen(at.x - 18, at.y) and c.seen(at.x, at.y + 10), "and the land on the screen around them")
	_check(not c.seen(at.x + 60, at.y) and not c.seen(at.x, at.y + 40), "but not the land two screens away")
	var before: int = c.seen_count()
	_check(before > 600 and before < 1400, "about a screen's worth has been seen (%d tiles)" % before)
	# Somewhere far off, seen once the screen is there.
	c.reveal(Vector2(at + Vector2i(90, 0)) * TILE)
	_check(c.seen(at.x + 90, at.y) and c.seen_count() > before, "the map remembers what has been on the screen")
	var r: Rect2 = c.rect()
	_check(r.end.x <= 640.0 - 9.0 and r.position.y >= 9.0 and r.size == Vector2(Charts.VIEW, Charts.VIEW), "the small map is in the top right corner (%s)" % str(r))
	var track: Vector2 = g.folk.track_at()
	_check(track.y > r.end.y, "the quests are listed under it")
	var corners: Array = g.folk.hud_corners()
	_check(corners.any(func(x): return (x as Rect2).encloses(r)), "and the far-off smoke keeps clear of it")
	# Digging shows on the map.
	var from := m.dug.size()
	var rock := Vector2i(-1, -1)
	for dy in range(-12, 13):
		for dx in range(-20, 21):
			if rock.x < 0 and LandMap.rocky(m.kind(at.x + dx, at.y + dy)) and not m.fixed(at.x + dx, at.y + dy):
				rock = Vector2i(at.x + dx, at.y + dy)
	_check(rock.x >= 0, "(there is rock on the screen to dig)")
	if rock.x >= 0:
		m.dig(rock.x, rock.y)
		await _frames(2)
		_check(m.dug.size() == from + 1 and c.kinds_img.get_pixel(rock.x, rock.y).r8 == LandMap.FLOOR, "a dug tile is dug floor on the map")
	# Shown while playing; put away while a screen stops the game.
	await _frames(2)
	_check(c.corner.visible, "the small map shows while the game is played")
	g.packs.open(0)
	await process_frame
	await process_frame
	_check(not c.corner.visible, "and is put away while the inventory is open")
	g.packs.close(0)
	await _frames(2)
	# Two players: under the second player's bars.
	await _leave(g)
	var g2 = _game(5602, 2)
	await _frames(12)
	var r2: Rect2 = g2.charts.rect()
	_check(r2.position.y >= 74.0, "with two players it is under the second player's bars (%s)" % str(r2))
	_check(g2.folk.track_at().y > r2.end.y, "and the quests under it")
	await _leave(g2)


# --- The whole map, on M ---------------------------------------------------------------------

func _whole_map() -> void:
	var g = _game(5603)
	await _frames(12)
	var c = g.charts
	_check(not c.is_open and not paused, "the whole map starts closed")
	c._input(_key(KEY_M))
	_check(c.is_open and paused, "M opens the whole map and the game stands still")
	_check(not g.packs.can_open(0), "the inventory cannot open over it")
	var shown: Rect2 = c.shown_tiles()
	var p = g.players[0]
	var at: Vector2 = p.global_position / TILE
	_check(shown.has_point(at) and shown.has_point(Vector2(g.map.mouth)), "it shows the land that has been seen, with the player and the cave in it")
	var a: Rect2 = c.area()
	# (While Pip is caged the whole map also takes in the Roost's smoke, far off: version 59. Without it:)
	_check(c.smoke_tile() != Vector2.INF and shown.has_point(c.smoke_tile()), "while Pip is caged it takes in the Roost's smoke too")
	var was: int = g.folk.pip
	g.folk.pip = 2
	var small: Rect2 = c.shown_tiles()
	g.folk.pip = was
	_check(minf(a.size.x / small.size.x, a.size.y / small.size.y) >= 3.0 - 0.001, "a small seen land is drawn big (three pixels a tile at least)")
	await process_frame
	c._input(_key(KEY_M))
	_check(c.is_open, "(a press the moment it opens does not shut it)")
	c.clock += 1.0
	c._input(_key(KEY_M))
	_check(not c.is_open and not paused, "M again closes it and the game goes on")
	c._input(_key(KEY_M))
	c.clock += 1.0
	c._input(_key(KEY_ESCAPE))
	_check(not c.is_open and not paused, "Esc closes it too")
	g.packs.open(0)
	c._input(_key(KEY_M))
	_check(not c.is_open, "M does nothing while the inventory is open")
	g.packs.close(0)
	await _frames(2)
	# Once a lot has been seen, it all fits.
	for x in range(0, LandMap.SIZE, 30):
		c.reveal(Vector2(x, LandMap.MID) * TILE)
	shown = c.shown_tiles()
	_check(shown.size.x > 300.0, "a long way seen makes a wide map (%d tiles)" % int(shown.size.x))
	_check(c.open(), "(it opens)")
	var scale := minf(a.size.x / shown.size.x, a.size.y / shown.size.y)
	_check(shown.size.x * scale <= a.size.x + 0.5 and shown.size.y * scale <= a.size.y + 0.5, "and it is drawn small enough to fit")
	c.close()
	# The names of the places, once they have been seen.
	var named := 0
	for name in Charts.PLACE_NAMES:
		_check(g.map.sites.has(name) or name in ["roost", "den", "cairns", "gorge"], "(%s is a place in this world)" % name)
		if g.map.sites.has(name):
			named += 1
	_check(named >= 4, "the map knows the names of the land's places (%d)" % named)
	await _leave(g)


# --- Saved with the world -------------------------------------------------------------------

func _saved() -> void:
	var g = _game(5604)
	await _frames(12)
	var c = g.charts
	c.reveal(Vector2(LandMap.MID + 100, LandMap.MID) * TILE)
	var seen: int = c.seen_count()
	var world: Dictionary = g._world_now().duplicate(true)
	_check(world.get("seen") is String and str(world["seen"]).length() < 20000, "what has been seen is saved with the world, small (%d characters)" % str(world.get("seen", "")).length())
	await _leave(g)
	var g2 = _game(5604, 1, world)
	await _frames(12)
	_check(g2.charts.seen(LandMap.MID + 100, LandMap.MID) and g2.charts.seen_count() >= seen, "and it is all seen again when the world is opened (%d of %d)" % [g2.charts.seen_count(), seen])
	await _leave(g2)
	var copy = Charts.new()
	copy.set_world_data({"seen": "rubbish"})
	copy.set_world_data({"seen": 12})
	copy.set_world_data({})
	_check(copy.explored.is_empty(), "a save that does not read leaves the land unseen")
	copy.free()


# --- The lab's map switch: all of it shown, and a click takes you there (version 57) ---------------

func _lab_map() -> void:
	var g = _game(5605)
	await _frames(12)
	var c = g.charts
	var m: LandMap = g.map
	var nav = g.foes.nav
	var first: Vector2 = g.players[0].global_position
	_check(Charts.LAB_MAP == 0, "the lab's map switch starts off")
	c.open()
	var mid: Rect2 = c.layout()[0]
	_check(not c.click(mid.get_center()) and c.is_open and g.players[0].global_position == first, "while it is off a click on the map does nothing")
	c.close()
	var seen_before: int = c.seen_count()
	var far := Vector2i(m.region.end.x - 10, LandMap.MID)
	_check(not c.shows(far.x, far.y), "(the far edge of the land has not been seen)")
	Charts.LAB_MAP = 1
	_check(c.shows(far.x, far.y) and c.shown_tiles().encloses(Rect2(m.region)), "the switch shows the whole land")
	_check(c.seen_count() == seen_before, "without counting it as seen in the world's save")
	c.open()
	var lay0: Array = c.layout()
	var spots: Array = c.name_spots(lay0[0], lay0[1], lay0[2])
	var crossed := 0
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			if (spots[i]["rect"] as Rect2).intersects(spots[j]["rect"]):
				crossed += 1
	_check(spots.size() >= 8 and crossed == 0, "the whole land on one small map: every place's name is written clear of the others (%d names, %d run into another)" % [spots.size(), crossed])
	c.close()
	# Clicks all over the whole map: every one that goes lands the squad on ground somebody can stand on.
	var rng := RandomNumberGenerator.new()
	rng.seed = 57
	var went := 0
	var refused := 0
	var bad := 0
	var closed := true
	var said := true
	for k in 150:
		if not c.is_open:
			c.open()
		var dest: Rect2 = c.layout()[0]
		var at := dest.position + Vector2(rng.randf() * dest.size.x, rng.randf() * dest.size.y)
		if c.click(at):
			went += 1
			closed = closed and not c.is_open and not paused
			var t := Vector2i((g.players[0].global_position / TILE).floor())
			if not m.walkable(t.x, t.y) or not nav.is_free(t):
				bad += 1
		else:
			refused += 1
			said = said and c.note == "Can't go there" and c.is_open
	_check(went >= 10 and bad == 0, "every click that goes lands on ground that can be stood on (%d went, %d off it)" % [went, bad])
	_check(closed, "and the map closes as the squad arrives")
	_check(refused > 0 and said, "a click on solid rock, far from any ground, says \"Can't go there\" and the map stays open (%d)" % refused)
	if c.is_open:
		c.close()
	# A click on rock right beside open ground goes to the ground beside it.
	var edge := Vector2i(-1, -1)
	var home := Vector2i((first / TILE).floor())
	for dy in range(-12, 13):
		for dx in range(-20, 21):
			var t := home + Vector2i(dx, dy)
			if edge.x < 0 and m.is_rock(t.x, t.y) and nav.is_free(t + Vector2i(0, 1)):
				edge = t
	_check(edge.x >= 0 and c.landing(edge) != edge and c.landing(edge).x >= 0 and m.walkable(c.landing(edge).x, c.landing(edge).y), "a click on rock beside open ground lands on the ground beside it")
	_check(c.landing(Vector2i(-1, -1)) == Vector2i(-1, -1) and c.landing(Vector2i(LandMap.SIZE + 5, 3)) == Vector2i(-1, -1), "off the land nobody goes anywhere")
	# A real click of the mouse's left button on the whole map does the same.
	var aim: Vector2i = c.landing(home + Vector2i(0, 3))
	c.open()
	var lay: Array = c.layout()
	var on_map: Vector2 = (lay[0] as Rect2).position + (Vector2(aim) + Vector2(0.5, 0.5) - (lay[1] as Rect2).position) * float(lay[2])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = c.screen.get_global_transform_with_canvas() * on_map
	c._input(press)
	_check(c.is_open, "(a click in the first moment after opening is not taken, as with the keys)")
	await _frames(12)
	c._input(press)
	var now := Vector2i((g.players[0].global_position / TILE).floor())
	_check(aim.x >= 0 and now == aim and not c.is_open, "a click of the mouse on the whole map takes the squad there (%s, wanted %s)" % [now, aim])
	if c.is_open:
		c.close()
	Charts.LAB_MAP = 0
	_check(not c.shows(far.x, far.y), "switched off, the map is what has really been seen again")
	await _leave(g)
	# Two players: both arrive, each on ground of their own.
	var g2 = _game(5605, 2)
	await _frames(12)
	Charts.LAB_MAP = 1
	var spot: Vector2i = g2.charts.landing(Vector2i((g2.players[0].global_position / TILE).floor()) + Vector2i(0, 4))
	g2.charts.go_to(spot)
	var ta := Vector2i((g2.players[0].global_position / TILE).floor())
	var tb := Vector2i((g2.players[1].global_position / TILE).floor())
	_check(ta == spot and tb != ta and g2.map.walkable(tb.x, tb.y) and g2.foes.nav.is_free(tb), "with two players both go, the second on the free ground beside the first")
	Charts.LAB_MAP = 0
	await _leave(g2)


# --- The role trees ------------------------------------------------------------------------------

func _trees() -> void:
	# Every perk has its icon.
	var order: Array = Art.json("roles/perk_icons.json").get("order", [])
	var icons := Art.texture("roles/perk_icons.png")
	_check(icons != null and icons.get_width() == 128 and icons.get_height() == 64, "the perks' icons are there")
	for tree in Perks.TREES:
		for id in Perks.TREE[tree]:
			_check(str(id) in order, "%s has an icon" % id)
	# The squares stand as a tree, none on another, inside the screen above the words.
	var hall = ForgeHall.new()
	var all: Array = []
	for c in Perks.TREES.size():
		var sig: Rect2 = hall.node_rect(c, 0)
		var cap: Rect2 = hall.node_rect(c, 7)
		_check(is_equal_approx(sig.get_center().x, cap.get_center().x), "%s: the signature stands over the capstone" % Perks.TREES[c])
		for k in range(1, 7, 2):
			var l: Rect2 = hall.node_rect(c, k)
			var r: Rect2 = hall.node_rect(c, k + 1)
			_check(is_equal_approx(l.position.y, r.position.y) and l.end.x < r.position.x and absf(l.get_center().x + r.get_center().x - 2.0 * sig.get_center().x) < 1.5, "%s: row %d is two squares either side of the middle" % [Perks.TREES[c], (k + 1) / 2 + 1])
		for k in 8:
			all.append(hall.node_rect(c, k))
	for i in all.size():
		_check((all[i] as Rect2).end.y < ForgeHall.INFO.position.y and (all[i] as Rect2).position.y > ForgeHall.HEAD_Y + 20.0, "square %d is between the heads and the words" % i)
		for j in range(i + 1, all.size()):
			if (all[i] as Rect2).grow(2.0).intersects((all[j] as Rect2).grow(2.0)):
				_check(false, "squares %d and %d do not touch" % [i, j])
	# The cursor goes the way the tree is drawn.
	hall.view = "trees"
	hall.tree = 1
	hall.place = 0
	hall.move(0, 1)
	_check(hall.place == 1, "down from the signature is the row below")
	hall.move(1, 0)
	_check(hall.tree == 1 and hall.place == 2, "right goes to the square beside it")
	hall.move(1, 0)
	_check(hall.tree == 2 and hall.place == 1, "and on into the next tree")
	hall.move(0, 1)
	_check(hall.place == 3, "down keeps to the side you are on")
	hall.move(-1, 0)
	_check(hall.tree == 1 and hall.place == 4, "left goes back into the tree before")
	hall.move(0, 9)
	_check(hall.place == 7, "down to the capstone")
	hall.move(1, 0)
	_check(hall.tree == 2 and hall.place == 7, "right from a capstone is the next capstone")
	hall.move(0, -1)
	_check(hall.place == 5, "up from the capstone is the row above")
	hall.move(0, -9)
	_check(hall.place == 0, "and up to the signature")
	hall.tree = 0
	hall.place = 1
	hall.move(-1, 0)
	_check(hall.tree == 3 and hall.place == 2, "left of the first tree goes round to the last")
	hall.free()
