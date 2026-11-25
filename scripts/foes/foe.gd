extends "res://scripts/enemy.gd"
## What the enemies of the Greystone Highlands share (version 43): the Cliff Hound, the Pebble Slinger, the Scrap
## Brute, the Goblin Shaman and its bats (scripts/foes/), and the elite of each.
##
## THEY LIVE SOMEWHERE. Out on the land an enemy belongs to a group with a home (pack.gd; the Highlands' own
## foes.gd wakes the groups near the players and puts the far ones away). A group that has seen nobody stands at
## its home; once one of it sees a player, or is hit, the whole group fights; when everybody has gone far enough
## away it walks home and gets its health back. In the test arena there is no group: an enemy put there fights at
## once, as the arena's own enemies do.
##
## THEY FIND THEIR WAY. The land is mostly rock, so a straight line at the player ends in a wall. Where there is a
## map, `nav` (scripts/highlands/nav.gd) gives the way round, and _go() walks it.
##
## AN ELITE is the same creature, marked (`elite`): tougher, with one trick of its own, drawn from its own
## pictures with a thin rim of light ("glow faintly", the Game Bible). It always counts as the toughest enemy.
##
## A WARD (the elite shaman's) makes a goblin impossible to hurt for a few seconds: `warded`.
##
## NO MARKS FOR THEIR ATTACKS. Darren, 23 November: "Not every enemy has to have telegraph markers for its moves,
## only bosses." So none of these, elites included, draws a lane, a circle or a ring: each one's wind-up pose (and
## the sound that goes with it) is the warning. The marks belong to the Forge guardian and to Rattlecrown.

const GOBLINS := ["slinger", "scrap_brute", "shaman"]
const SHEET := "foes/enemies.png"
const BOOK := "foes/enemies.json"
const ART_NAMES := {"scrap_brute": "brute"}      # the game's name -> the art's (the arena already has a "brute")
const WARD_WORD_EVERY := 0.7

var pack = null                # the group it belongs to, or null (the test arena)
var home := Vector2.INF        # where it stands when nothing is happening
var nav = null                 # the way round the rock, where there is a map
var warded := 0.0              # seconds of a ward left: nothing hurts it
var summoned := false          # it came in the middle of a fight (a bat, a hound that answered a howl), and goes when the fight is over
var mode := "idle"
var mode_t := 0.0

var _path := PackedVector2Array()
var _path_i := 0
var _path_goal := Vector2.INF
var _path_t := 0.0
var _path_stamp := -1
var _clear_t := 0.0
var _clear := true
var _clear_goal := Vector2.INF
var _last_pos := Vector2.INF
var _wanted := 0.0
var _stuck := 0.0
var _side_t := 0.0
var _side := 1.0
var _word_t := 0.0
var _own := 0                  # a small number of its own, from where it first stood: the same on every run and every machine


func _ready() -> void:
	art_set = "foes"
	super._ready()
	add_to_group("highlands_foes")
	if home == Vector2.INF:
		home = position
	_last_pos = position
	# (Never the object's own number: that one differs from run to run, and the fights with it.)
	_own = absi(int(round(position.x)) * 7 + int(round(position.y)) * 13)


func _set_mode(m: String, time := 0.0) -> void:
	mode = m
	mode_t = time


## Is its group fighting? (An enemy with no group, in the test arena, always is.)
func fighting() -> bool:
	return pack == null or pack.alert


## The others of its group that are still standing (in the arena: every Highlands enemy there).
func allies() -> Array:
	var out: Array = []
	var all: Array = pack.members if pack != null else get_tree().get_nodes_in_group("highlands_foes")
	for e in all:
		if is_instance_valid(e) and e != self and not e.dead and e.pack == pack:
			out.append(e)
	return out


# --- What it does each tick ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if warded > 0.0 and not dead:
		warded = maxf(warded - delta, 0.0)
	_word_t = maxf(_word_t - delta, 0.0)
	super._physics_process(delta)
	_out_of_rock(delta)


## Should it ever find itself inside rock or water (far from the camera the land has no walls yet, and a hard knock
## can come at the wrong moment), it is put back on the nearest ground it can stand on. Looked at twice a second.
var _rock_t := 0.0

func _out_of_rock(delta: float) -> void:
	_rock_t -= delta
	if _rock_t > 0.0 or nav == null or dead or collision_mask == 0:
		return
	_rock_t = 0.5
	var tile: Vector2i = nav.tile_of(global_position)
	if nav.map.walkable(tile.x, tile.y):
		return
	var to: Vector2i = nav.nearest_free(tile, 8)
	if to.x >= 0:
		global_position = nav.middle_of(to)
		knock = Vector2.ZERO
		reset_physics_interpolation()


func _think(delta: float) -> Vector2:
	mode_t -= delta
	if not fighting():
		return _calm(delta)
	if target == null:
		return Vector2.ZERO
	return _fight(delta)


## Fighting: the velocity it wants. Each kind has its own.
func _fight(_delta: float) -> Vector2:
	return Vector2.ZERO


## Nothing to fight: it walks home if it is away from it, getting its health back, and stands there.
func _calm(delta: float) -> Vector2:
	if mode != "idle":
		_stand_down()
	if hp < max_hp:
		hp = minf(hp + max_hp * 0.4 * delta, max_hp)
	if global_position.distance_to(home) > 26.0:
		var v := _go(home, speed * 0.8, delta)
		if v.length() > 1.0:
			facing = v.normalized()
		return v
	return Vector2.ZERO


## It stops what it was in the middle of (the fight is over).
func _stand_down() -> void:
	_set_mode("idle")


# --- Finding the way ----------------------------------------------------------------------

## Can it see that place: no rock in between? (Always, where there is no map.)
func sees(at: Vector2) -> bool:
	return nav == null or nav.sees(global_position, at)


## The velocity that takes it towards `goal` at `spd`: straight there if nothing is in the way, otherwise along the
## way round. If it is making no headway (a boulder, another enemy) it steps to one side for a moment.
func _go(goal: Vector2, spd: float, delta: float) -> Vector2:
	var to := goal - global_position
	if to.length() < 6.0:
		_wanted = 0.0
		return Vector2.ZERO
	var dir := to.normalized()
	if nav != null:
		_clear_t -= delta
		if _clear_t <= 0.0 or goal.distance_to(_clear_goal) > 40.0:
			_clear_t = 0.15 + float(_own % 7) * 0.01
			_clear_goal = goal
			_clear = nav.clear(global_position, goal)
		if not _clear:
			dir = _along_path(goal, delta, dir)
	# No headway? Step aside.
	if _last_pos != Vector2.INF and _wanted > 1.0:
		if global_position.distance_to(_last_pos) < _wanted * delta * 0.3:
			_stuck += delta
		else:
			_stuck = maxf(_stuck - delta * 2.0, 0.0)
	_last_pos = global_position
	if _stuck > 0.3:
		_stuck = 0.0
		_side_t = 0.45
		_side = -_side
	if _side_t > 0.0:
		_side_t -= delta
		dir = (dir + dir.orthogonal() * _side * 1.3).normalized()
	_wanted = spd
	return dir * spd


func _along_path(goal: Vector2, delta: float, straight: Vector2) -> Vector2:
	_path_t -= delta
	if _path_t <= 0.0 or goal.distance_to(_path_goal) > 48.0 or _path_stamp != nav.stamp:
		_path_t = 0.5 + float(_own % 5) * 0.03
		_path_goal = goal
		_path_stamp = nav.stamp
		_path = nav.path(global_position, goal)
		_path_i = 1
	if _path.size() < 2:
		return straight
	while _path_i < _path.size() - 1 and global_position.distance_to(_path[_path_i]) < 14.0:
		_path_i += 1
	# Cut the corner where the next turn can already be walked to.
	if _path_i < _path.size() - 1 and nav.clear(global_position, _path[_path_i + 1]):
		_path_i += 1
	var to: Vector2 = _path[mini(_path_i, _path.size() - 1)] - global_position
	return to.normalized() if to.length() > 1.0 else straight


## A way to back off from `from` that is not straight into a wall: away from it, or as near to that as the land
## allows. (Kept for a moment once chosen, so it does not dither between two ways.)
var _flee_turn := 0.0
var _flee_t := 0.0

func _away(from: Vector2, delta: float) -> Vector2:
	var away := (global_position - from).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	if nav == null:
		return away
	_flee_t -= delta
	if _flee_t > 0.0 and nav.clear(global_position, global_position + away.rotated(_flee_turn) * 44.0):
		return away.rotated(_flee_turn)
	for turn in [0.0, 0.7, -0.7, 1.3, -1.3, 1.9, -1.9]:
		var d := away.rotated(turn)
		if nav.clear(global_position, global_position + d * 44.0):
			_flee_turn = turn
			_flee_t = 0.5
			return d
	return Vector2.ZERO


# --- Being hit ----------------------------------------------------------------------------

func take_hit(dmg: float, dir: Vector2, knockback: float, crit: bool, num_color: Color, stun := 0.0, freeze_time := 0.0) -> void:
	if dead or immune:
		return
	if pack != null:
		pack.wake()
	if warded > 0.0:
		_say("WARDED", Color("#8ba688"))
		Sfx.play(self, "anvil", -22.0, 2.4)
		return
	super.take_hit(dmg, dir, knockback, crit, num_color, stun, freeze_time)


func _apply_damage(dmg: float, crit: bool, num_color: Color) -> void:
	if warded > 0.0:
		return
	super._apply_damage(dmg, crit, num_color)


func add_stagger(points: float) -> bool:
	return false if warded > 0.0 else super.add_stagger(points)


func apply_stun(duration: float) -> void:
	if warded <= 0.0:
		super.apply_stun(duration)


func apply_burn(damage_per_tick: float, duration: float) -> void:
	if warded <= 0.0:
		super.apply_burn(damage_per_tick, duration)


func apply_slow(amount: float, duration: float) -> void:
	if warded <= 0.0:
		super.apply_slow(amount, duration)


## A word over its head (BLOCKED, WARDED), not more often than every so often.
func _say(word: String, col: Color) -> void:
	if _word_t > 0.0:
		return
	_word_t = WARD_WORD_EVERY
	var n := DamageNumber.new()
	n.text = word
	n.color = col
	get_parent().add_child(n)
	n.global_position = global_position + Vector2(0, _head_y() - 4.0)


## A goblin or a hound is flesh and blood: dust where it falls, not the forge's green.
func _death_burst() -> void:
	var tex := Art.texture("cave/dust_puff.png")
	if tex == null:
		return
	for i in 2:
		var n := SpriteOnce.new()
		n.texture = tex
		n.frames = 4
		n.fps = 12.0
		n.origin = Vector2(8, 10)
		get_parent().add_child(n)
		n.z_index = 0
		n.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(0, 10))


# --- Its pictures -------------------------------------------------------------------------
# The Art builder hands the Highlands' enemies over as ONE sheet and a book of boxes (art/foes/enemies.png and
# enemies.json, with its README): each strip of frames is cut out of the sheet here, when it is first wanted.

static var _strips := {}

## A strip of the sheet as a picture of its own (null if the book has no such box). `from` is another sheet (the moor
## creatures': creature.gd).
static func strip_tex(box, from := SHEET) -> Texture2D:
	if not (box is Array) or (box as Array).size() != 4:
		return null
	var key := "%s:%d,%d,%d,%d" % [from, int(box[0]), int(box[1]), int(box[2]), int(box[3])]
	if not _strips.has(key):
		var sheet := Art.texture(from)
		var tex: AtlasTexture = null
		if sheet != null:
			tex = AtlasTexture.new()
			tex.atlas = sheet
			tex.region = Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3]))
		_strips[key] = tex
	return _strips[key]


## Something a slinger throws, or another loose piece of the sheet ("shots" in the book): {tex, frames, fps,
## origin}, or empty.
static func shot(name: String) -> Dictionary:
	var info: Dictionary = Art.json(BOOK).get("shots", {}).get(name, {})
	var tex := strip_tex(info.get("box"))
	if tex == null:
		return {}
	var o: Array = info.get("origin", [0, 0])
	return {"tex": tex, "frames": int(info.get("frames", 1)), "fps": float(info.get("fps", 10)), "origin": Vector2(o[0], o[1])}


## Draws frame `frame` of a loose piece with its origin at `at` (false if the art has none).
static func draw_shot(ci: CanvasItem, name: String, frame: int, at: Vector2, angle := 0.0) -> bool:
	var s := shot(name)
	if s.is_empty():
		return false
	Art.draw_strip(ci, s["tex"], s["frames"], frame, at, s["origin"], false, Color.WHITE, Art.PIXEL, angle)
	return true


## Plays a loose piece once at a place in the world (a puff of dust, a rock breaking). Returns it, or null.
static func play_shot(from: Node, name: String, where: Vector2) -> Node2D:
	var s := shot(name)
	if s.is_empty() or not is_instance_valid(from) or from.get_parent() == null:
		return null
	var n := SpriteOnce.new()
	n.texture = s["tex"]
	n.frames = s["frames"]
	n.fps = s["fps"]
	n.origin = s["origin"]
	from.get_parent().add_child(n)
	n.global_position = where
	return n


## The name its pictures go by in the book: an elite has its own.
func art_name() -> String:
	var name: String = ART_NAMES.get(kind, kind)
	if elite and Art.json(BOOK).get("enemies", {}).has(name + "_elite"):
		return name + "_elite"
	return name


func _art_info() -> Dictionary:
	return Art.json(BOOK).get("enemies", {}).get(art_name(), {})


func _art_tex(anim: String) -> Texture2D:
	var strip: Dictionary = _art_info().get("strips", {}).get(anim, {})
	return strip_tex(strip.get("box"))


func _art_key() -> String:
	return "foes/" + art_name()


func _draw() -> void:
	# An elite's rim: a thin pale bronze line on its lit side, drawn by the art for every frame, under the enemy.
	if elite and not dead:
		var sp := _sprite()
		if not sp.is_empty():
			var rim := _art_tex(str(sp["anim"]) + "_rim")
			if rim != null:
				Art.draw_strip(self, rim, sp["frames"], sp["frame"], _feet(), sp["origin"], sp["flip"])
		else:
			draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 24, Color("#f0c070"), 2.0)
	# A ward is three scrap shields going round the goblin: the far half under it, the near half over it.
	if warded > 0.0 and not dead:
		_draw_ward("back")
	super._draw()
	if warded > 0.0 and not dead:
		_draw_ward("front")


## One half of the ward ("back" or "front"). It flickers in its last half second, as a mark about to go does.
func _draw_ward(half: String) -> void:
	var flicker := warded < 0.5 and int(warded * 12.0) % 2 == 0
	var info: Dictionary = Art.json(BOOK).get("enemies", {}).get("ward_big" if radius >= 16.0 else "ward", {})
	var strip: Dictionary = info.get("strips", {}).get(half, {})
	var tex := strip_tex(strip.get("box"))
	if tex != null:
		if not flicker:
			var o: Array = info.get("origin_feet", [0, 0])
			var n := int(strip.get("frames", 4))
			Art.draw_strip(self, tex, n, int(anim_time * float(strip.get("fps", 6))) % maxi(n, 1), _feet(), Vector2(o[0], o[1]))
		return
	if half == "front":      # no art: a plain bronze ring
		draw_arc(Vector2(0, -radius * 0.5), radius + 9.0, 0.0, TAU, 28, Color(Color("#c9923a"), 0.3 if flicker else 0.9), 2.0)


## An elite's health bar is there from the start of a fight, so it can be told from the others at a glance.
func _draw_over(ci: CanvasItem) -> void:
	super._draw_over(ci)
	if elite and not dead and hp >= max_hp and show_bar and pack != null and pack.alert:
		_draw_bar(ci)
