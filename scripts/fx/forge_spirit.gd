extends Node2D
## The forge spirit: the small ringed ember that floats at a player's shoulder
## and holds their runes (Darren, 16 and 17 November: nothing is drawn on the
## weapon any more; one spirit for each player, always there but small).
##
## Over it sits one mark for each ACTIVE rune fitted, in button order: ember when
## the rune is ready, half lit for the last third of its recharge, verdigris
## while it recharges. When an active rune is used the spirit flares, the rune's
## sign leaps to the weapon hand and the weapon lights for a moment. When any
## rune goes off (a passive one too) the ember glows for a moment.
##
## It only draws. Nothing here changes the fight, so two players online never
## have to agree on it. The sizes are the art's (art/spirit/spirit.json), in art
## pixels; one art pixel is Art.PIXEL world units.

const Art := preload("res://scripts/art.gd")
const SpriteOnce := preload("res://scripts/fx/sprite_once.gd")

const PLAY := "spirit/play/"
const SIGNS := "spirit/signs/"

const BEHIND := 13.0          # art px from the player's middle to the ember, on the side away from where they face
const ABOVE_FEET := 26.0      # art px from the feet up to the ember
const TURN := 0.35            # how far to one side they must face for that to decide its side
const SETTLE := 0.2           # seconds they must face a new way before it changes sides (a spin never moves it)
const GLIDE := 9.0            # how briskly it crosses to the other side
const OVER := 5.0             # art px it lifts on the way across, so it goes over the head and not through the face
const FLOAT_EVERY := 1.6      # seconds for one float up and down (1 art px)
const FADE := 0.25            # seconds to appear when you first hold a weapon

const FRAME := Vector2(19, 19)
const ORIGIN := Vector2(9, 11)     # the ember, in the spirit's picture
const FRAMES := 6
const FPS := 8.0

const MARK_GAP := 6.0         # art px between marks
const MARK_UP := 12.0         # art px from the ember up to the marks
const MARK_MIDDLE := 2.0      # the middle of three sits this much higher
const HALF_FROM := 2.0 / 3.0  # a mark is half lit for the last third of the recharge
const PING_FRAMES := 3
const PING_FPS := 14.0

const LEAP_TIME := 0.12       # seconds the sign takes from the spirit to the weapon hand
const LEAP_ARC := 5.0         # art px the sign's path rises in the middle
const TRAIL_EVERY := 4.0      # art px between the sparks it leaves
const TINT_TIME := 0.15       # seconds the weapon stays lit
const BURST_FRAMES := 5       # the flare on the spirit and the burst on the weapon
const BURST_FPS := 18.0
const GLOW_TIME := 0.18       # seconds the ember glows when a rune goes off
const EMBER := Color("#ffc850")

var player                    # the player it belongs to (its parent)

var _glow: Node2D             # its glows: added on top of the picture
var _t := 0.0                 # its own clock (the float, the loop, the bursts)
var _side := -1.0             # -1: on the player's left, +1: on their right
var _want := -1.0             # the side it would be on for the way they face now
var _want_for := 0.0          # how long that has been so
var _x := -BEHIND * Art.PIXEL # where it is across, easing to its side
var _there := 0.0             # 0 hidden .. 1 there
var _stamp := -1              # the weapon it last looked at
var _seen: Array = [-9.0, -9.0, -9.0]          # each button's last use, once it has been shown
var _ready_before: Array = [true, true, true]
var _held_before := -1
var _leaps: Array = []        # signs on their way: {id, t0, from, dropped}
var _flares: Array = []       # flares on the spirit: when each began
var _lands: Array = []        # bursts on the weapon hand: when each began
var _pings: Dictionary = {}   # button -> when its mark came back


func _ready() -> void:
	if player == null:
		player = get_parent()
	# It draws itself afresh every frame, so it skips the smoothing the engine
	# does between physics ticks. Bright in the dark, and in front of the world.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	material = Art.unshaded()
	z_index = 6
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = add
	add_child(_glow)
	_glow.draw.connect(_draw_glow)


## Where the ember is, from the player's centre (world units, on whole art pixels).
func ember_at() -> Vector2:
	var across := _x / (BEHIND * Art.PIXEL)
	var lift := (1.0 - across * across) * OVER
	var bob := 1.0 if fmod(_t, FLOAT_EVERY) < FLOAT_EVERY * 0.5 else 0.0
	var feet: Vector2 = player.FEET
	return Vector2(roundf(_x / Art.PIXEL), feet.y / Art.PIXEL - ABOVE_FEET - roundf(lift) - bob) * Art.PIXEL


## The marks, in button order: "ready", "half" or "recharging" for each active
## rune fitted. (None for a passive rune, and none at all with no active rune.)
func marks() -> Array:
	var out: Array = []
	var list: Array = player.weapon.get("abilities", [])
	for b in mini(list.size(), _seen.size()):
		if (list[b] as Dictionary).is_empty():
			continue
		out.append(_mark(b))
	return out


func _mark(b: int) -> String:
	if player.ability_ready(b):
		return "ready"
	if float(player.ability_charge[b]) >= float(player.ability_cost(b)) * HALF_FROM:
		return "half"
	return "recharging"


## Where mark `i` of `n` sits, from the ember (art pixels).
static func mark_at(i: int, n: int) -> Vector2:
	var up := MARK_UP + (MARK_MIDDLE if n == 3 and i == 1 else 0.0)
	return Vector2(roundf((float(i) - float(n - 1) * 0.5) * MARK_GAP), -up)


## Signs on their way to the weapon right now.
func leaping() -> int:
	return _leaps.size()


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_t += delta
	_there = move_toward(_there, 1.0 if player.armed() else 0.0, delta / FADE)
	var want := _side_wanted()
	_want_for = _want_for + delta if want == _want else 0.0
	_want = want
	if _want_for >= SETTLE:
		_side = _want
	_x = lerpf(_x, _side * BEHIND * Art.PIXEL, 1.0 - exp(-GLIDE * delta))
	_watch()
	_fly()
	queue_redraw()
	_glow.queue_redraw()


## The side it belongs on: away from where they face, and facing straight up or
## down, the side the weapon is not on (so the two never sit on top of each other).
func _side_wanted() -> float:
	var face: Vector2 = player.face_dir
	if absf(face.x) > TURN:
		return -signf(face.x)
	var hand: Vector2 = player.rest_hand()
	return -signf(hand.x) if absf(hand.x) > 1.0 else _side


## Looks at the player's active runes: one that has just been used sends its
## sign, one that has just come back pings its mark.
func _watch() -> void:
	var list: Array = player.weapon.get("abilities", [])
	var now: float = player.game_time
	var fresh: bool = int(player.weapon_stamp) != _stamp
	_stamp = int(player.weapon_stamp)
	if fresh:
		_leaps.clear()
		_pings.clear()
	for b in _seen.size():
		var fitted: bool = b < list.size() and not (list[b] as Dictionary).is_empty()
		var used := float(player.ability_used[b])
		var ready: bool = fitted and player.ability_ready(b)
		if fresh or not fitted:
			# A new weapon starts with every rune ready: nothing to show for that.
			_seen[b] = used
			_ready_before[b] = ready
			continue
		if used != float(_seen[b]):
			_seen[b] = used
			# A rune you hold sends one sign, when it starts, not one at every turn.
			var going: bool = str(list[b]["use"]) == "hold" and _held_before == b
			if not going and now - used < 0.25:
				_send(str(list[b]["id"]))
		if ready and not bool(_ready_before[b]):
			_pings[b] = _t
		_ready_before[b] = ready
	_held_before = int(player.hold_button)


func _send(id: String) -> void:
	if _there <= 0.0:
		return
	_flares.append(_t)
	_leaps.append({"id": id, "t0": _t, "from": ember_at(), "dropped": 0.0})


## Where a sign is `k` of the way (0..1) along its low arc to the weapon hand.
func _leap_at(leap: Dictionary, k: float) -> Vector2:
	var from: Vector2 = leap["from"]
	var to: Vector2 = player.weapon_hand()
	return from.lerp(to, k) + Vector2(0, -LEAP_ARC * Art.PIXEL * 4.0 * k * (1.0 - k))


## Moves the signs along, leaving sparks, and lights the weapon as each lands.
func _fly() -> void:
	var keep: Array = []
	for leap in _leaps:
		var k := clampf((_t - float(leap["t0"])) / LEAP_TIME, 0.0, 1.0)
		var length := ((player.weapon_hand() as Vector2) - (leap["from"] as Vector2)).length()
		var step := TRAIL_EVERY * Art.PIXEL
		while float(leap["dropped"]) + step <= length * k:
			leap["dropped"] = float(leap["dropped"]) + step
			_spark(_leap_at(leap, float(leap["dropped"]) / maxf(length, 1.0)))
		if k < 1.0:
			keep.append(leap)
		else:
			_lands.append(_t)
			player.spirit_lit = player.game_time
	_leaps = keep
	_flares = _flares.filter(func(t0): return _t - float(t0) < BURST_FRAMES / BURST_FPS)
	_lands = _lands.filter(func(t0): return _t - float(t0) < BURST_FRAMES / BURST_FPS)
	for b in _pings.keys():
		if _t - float(_pings[b]) >= PING_FRAMES / PING_FPS:
			_pings.erase(b)


## One spark left behind by a flying sign. It stays where it was dropped.
func _spark(at: Vector2) -> void:
	var tex := Art.texture(PLAY + "trail.png")
	if tex == null:
		return
	var n := SpriteOnce.new()
	n.texture = tex
	n.frames = 4
	n.fps = 16.0
	n.origin = Vector2(2, 2)
	n.additive = true
	player._fx_root().add_child(n)
	n.global_position = (player as Node2D).global_position + at


func _draw() -> void:
	if not is_instance_valid(player) or _there <= 0.0:
		return
	var at := ember_at()
	var tint := Color(1, 1, 1, _there)
	var tex := Art.texture(PLAY + "spirit.png")
	if tex != null:
		Art.draw_strip(self, tex, FRAMES, int(_t * FPS), at, ORIGIN, false, tint)
	var states := marks()
	for i in states.size():
		var mark := Art.texture(PLAY + "mark_%s.png" % states[i])
		if mark != null:
			Art.draw_strip(self, mark, 1, 0, at + mark_at(i, states.size()) * Art.PIXEL, Vector2(2, 2), false, tint)
	for leap in _leaps:
		var sign_tex := Art.texture(SIGNS + "sign_%s.png" % leap["id"])
		if sign_tex != null:
			var k := clampf((_t - float(leap["t0"])) / LEAP_TIME, 0.0, 1.0)
			Art.draw_strip(self, sign_tex, 1, 0, _leap_at(leap, k), Vector2(7, 7))


func _draw_glow() -> void:
	if not is_instance_valid(player) or _there <= 0.0:
		return
	var at := ember_at()
	# A rune going off (any rune): the ember glows for a moment.
	var glow := _rune_glow()
	var tex := Art.texture(PLAY + "spirit.png")
	if glow > 0.0 and tex != null:
		Art.draw_strip(_glow, tex, FRAMES, int(_t * FPS), at, ORIGIN, false, Color(1, 1, 1, 0.7 * glow * _there))
	var cast := Art.texture(PLAY + "cast.png")
	if cast != null:
		for t0 in _flares:
			Art.draw_strip(_glow, cast, BURST_FRAMES, mini(int((_t - float(t0)) * BURST_FPS), BURST_FRAMES - 1), at, Vector2(16, 16))
	var infuse := Art.texture(PLAY + "infuse.png")
	if infuse != null:
		for t0 in _lands:
			Art.draw_strip(_glow, infuse, BURST_FRAMES, mini(int((_t - float(t0)) * BURST_FPS), BURST_FRAMES - 1),
				player.weapon_hand(), Vector2(16, 16))
	var ping := Art.texture(PLAY + "mark_ping.png")
	if ping != null and not _pings.is_empty():
		# A mark's place is its place among the marks drawn, which skips no button
		# today (buttons are handed out in order) but is counted the same way here.
		var list: Array = player.weapon.get("abilities", [])
		var n := marks().size()
		var i := 0
		for b in mini(list.size(), _seen.size()):
			if (list[b] as Dictionary).is_empty():
				continue
			if _pings.has(b):
				Art.draw_strip(_glow, ping, PING_FRAMES, mini(int((_t - float(_pings[b])) * PING_FPS), PING_FRAMES - 1),
					at + mark_at(i, n) * Art.PIXEL, Vector2(4, 4))
			i += 1


## 0..1: how much the ember glows because a rune has just gone off.
func _rune_glow() -> float:
	var now: float = player.game_time
	var best := 0.0
	var flashes: Dictionary = player.slot_flash
	for s in flashes:
		var since := now - float(flashes[s])
		if since >= 0.0 and since < GLOW_TIME:
			best = maxf(best, 1.0 - since / GLOW_TIME)
	return best
