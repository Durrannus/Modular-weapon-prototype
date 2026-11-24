extends "res://scripts/foes/foe.gd"
## Rattlecrown, the Scrap King (version 48): the boss of the Greystone Highlands, once he is on his feet.
##
## The Game Bible: "a goblin chief on a fixed scrap throne; his crown is the broken Twice thread. Phase 1: he
## watches from the throne and does not attack while the three horn elites fight you all at once. Phase 2: he kicks
## the throne apart and fights on foot with a scrap club: Club Slam, Scrap Toss, Charge. No crown yet, so each
## attack goes off once. Phase 3: he puts on the crown and every attack goes off twice." And its rules: "every
## attack shows on the floor before it lands, the tip line names each attack, health scales with players like the
## guardian."
##
## Phase 1 is not his: the throne and the three elites are crown.gd's (scripts/highlands/crown.gd), which puts this
## enemy on the floor when the throne is kicked apart. In the test arena he is simply put down on his feet.
##
##   CLUB SLAM   he walks up to you, raises the club (an orange ring closes in on the floor in front of him), and
##               brings it down. Whoever stands in the ring is hurt.
##   SCRAP TOSS  he draws his arm back (a smaller ring where you stand), and lobs a lump of scrap onto it.
##   CHARGE      he lowers his head (a lane on the floor), and runs down it. If he ends against rock he is dazed.
##
## After each attack he stands a moment: that is when to hit him. Nothing knocks him back or stuns him (as the
## forge guardian). His first three attacks are one of each, so every one is seen early; after that he picks, never
## the same one twice running.
##
## CROWNED (at CROWN_AT of his health he stops, puts the crown on, and cannot be hurt while he does): each attack
## goes off twice. So that both can be read on the floor (asked for in the review of the plan): the second slam's
## ring and the second charge's lane only appear once the first has landed, and the second toss's ring, which is
## on the floor together with the first, is never laid on top of it (TOSS_APART).
##
## Claude's choices, until Darren says otherwise: every number here (they are in the lab), the three attacks'
## shapes, when the crown goes on, and that he stays in the Throne Room.
##
## Everything runs on game ticks and asks the game's shared dice (Sim), so the same fight plays the same way twice.

const Scrap := preload("res://scripts/foes/scrap.gd")

signal attack_started(kind, twice)     # "slam", "toss" or "charge", as he begins it: the tip line names it
signal crown_put_on

static var HP := 420.0
static var HP_PER_PLAYER := 0.7        # each player after the first adds this share of it (the guardian's rule)
static var SPEED := 72.0
static var CROWN_AT := 0.5             # the crown goes on at this share of his health
static var SLAM := 20.0
static var SLAM_WINDUP := 0.95
static var TOSS := 14.0
static var TOSS_WINDUP := 0.7
static var TOSS_FLIGHT := 0.75
static var CHARGE := 20.0
static var CHARGE_WINDUP := 1.0
static var CHARGE_SPEED := 500.0
static var CHARGE_DIST := 330.0
static var REST := 1.1                 # he stands this long after an attack
static var AGAIN := 0.3                # crowned: the wait between an attack and its second go
static var SECOND := 0.75              # crowned: the second go's warning is this share of the first's

const FIRST := ["slam", "toss", "charge"]
## What follows from how big he is drawn is measured for the first draft's king (a picture 72 art pixels wide) and
## grows with the picture (`big`), so a redrawn, larger king needs no new numbers here. The rings' reach is read
## from the rings' own pictures.
const DRAWN := 72.0
const BODY := 17.0                     # his body's radius
const SLAM_OUT := 52.0                 # the club comes down this far in front of his feet (26 art pixels)
const SLAM_REACH := Vector2(56.0, 28.0)    # the ring's reach from its middle if the art does not say: across and deep
const SLAM_NEAR := 66.0                # he slams once you are this near
const SLAM_CHOKE := 0.65               # the nearest the club comes down, as a share of its reach
const SLAM_TIME := 0.3
const SLAM_AT := 0.1                   # the blow lands this long into the swing (the strip's second picture)
const BLOW_SHOW := 0.2                 # the ring's last picture stays this long
const LOCK := 0.25                     # he stops turning this long before a slam or a charge
const TOSS_TIME := 0.3
const TOSS_FAR := 560.0
const TOSS_REACH := Vector2(36.0, 18.0)    # the same for the scrap's ring
const TOSS_APART := 84.0               # crowned: the second ring is at least this far from the first
const HAND := Vector2(30.0, 58.0)      # where the scrap leaves his hand: in front of him, and up
const CROWN_TIME := 0.8
const WALK_MOST := 4.0                 # seconds he walks after you for one attack before he thinks of another
const DAZED := 0.8                     # longer on his heels when a charge ends against rock
const PUSH := 520.0                    # how hard a charge throws you aside

var team := 0                          # how many players his health is for (0: he counts them)
var big := 1.0                         # how much bigger than the first draft's king he is drawn
var slam_out := SLAM_OUT               # how far in front of his feet the club comes down (world units; from his art)
var hand := HAND                       # where the scrap leaves his hand (world units; from his art)
var slam_near := SLAM_NEAR             # he slams once you are this near (world units; follows slam_out)
var slam_dist := SLAM_OUT              # how far out this slam's club comes down (world units; _reach_for)
var slam_reach := SLAM_REACH
var toss_reach := TOSS_REACH
var room := Rect2()                    # with a size (world units): he fights only those inside it, and stays in it
var crowned := false
var attacks := 0
var done := {}                         # the attacks he has made at least once
var next := ""                         # what he is walking up to do
var last := ""
var goes := 1                          # goes of this attack still to come, this one counted
var first_go := true
var walk_t := 0.0
var windup := 1.0                      # how long this warning lasts in all
var aim := Vector2.RIGHT               # the way a slam or a charge goes
var aim_at := Vector2.ZERO             # where a toss is aimed
var first_mark := Vector2.INF          # where the first of two tosses was aimed
var struck := {}
var charge_left := 0.0
var hit_any := false                   # this attack (both goes) has hurt somebody
var blow_done := false
var blow_t := 9.0                      # seconds since a slam landed
var blow_at := Vector2.ZERO


func _setup() -> void:
	kind = "rattlecrown"
	_stats()
	var info: Dictionary = Art.json(Scrap.BOOK).get("enemies", {}).get("rattlecrown", {})
	var frame: Array = info.get("frame", [DRAWN, DRAWN])
	big = clampf(float(frame[0]) / DRAWN, 1.0, 2.5)
	radius = roundf(minf(BODY * big, 28.0))
	# Where his art puts the club's head on the slam's blow and the lump as it leaves his hand, if it says (art
	# pixels in front of his feet, and up; version 50's animated art does): the ring is laid where the club lands.
	var reach: Dictionary = info.get("reach", {})
	slam_out = float(reach["slam"][0]) * Art.PIXEL if reach.has("slam") else SLAM_OUT * big
	hand = Vector2(float(reach["hand"][0]), float(reach["hand"][1])) * Art.PIXEL if reach.has("hand") else HAND * big
	slam_near = slam_out + (SLAM_NEAR - SLAM_OUT) * big     # he slams once you are about where the club comes down
	slam_reach = Scrap.reach_of("slam_mark", SLAM_REACH)
	toss_reach = Scrap.reach_of("scrap_mark", TOSS_REACH)
	contact_damage = 0.0
	knock_resist = 0.0                 # nothing knocks him back or stuns him
	color = Color("#c9923a")


func _stats() -> void:
	var n := team
	if n <= 0:
		n = maxi(get_tree().get_nodes_in_group("player").size(), 1) if is_inside_tree() else 1
	max_hp = HP * (1.0 + HP_PER_PLAYER * float(n - 1))
	speed = SPEED


## 1 on the throne's wreck, 2 on foot, 3 crowned (the throne's own phase is crown.gd's).
func phase() -> int:
	return 3 if crowned else 2


func _physics_process(delta: float) -> void:
	blow_t += delta
	super._physics_process(delta)
	_see_through()
	_through.queue_redraw()
	_through_marks.queue_redraw()
	_through_ghosts.queue_redraw()


# --- Seen through him (version 50, after the Overseer's review) ----------------------------------------------------
# At his new size (134 by 120 art pixels) his body covers what is just behind it: his own marks on the floor, and a
# player above him on the screen. A hazard must be seen, and so must your own character, so both show through his
# body, clipped to it: his marks in their warning orange, a little see-through, and anyone behind him as a flat
# shape in their own colour. Outside his body nothing changes (the marks lie on the floor, under everyone).

const THROUGH_MARKS := 0.85            # how strongly his marks show through his body
const THROUGH_GHOST := 0.9             # how strongly a player behind him shows through it
const GHOST_EDGE := Color("#fff1d6")   # the pale edge round that shape

var _through: Node2D                   # his body again, as a mask only (nothing of it is drawn)
var _through_marks: Node2D             # his marks, inside the mask
var _through_ghosts: Node2D            # players behind him, inside the mask
static var _ghost_mat: ShaderMaterial = null


func _see_through() -> void:
	if _through != null:
		return
	_through = Node2D.new()
	_through.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_through.z_index = 1                   # over everything on the floor's level, him included
	_through.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	add_child(_through)
	_through.draw.connect(_draw_body_mask)
	_through_marks = Node2D.new()
	_through_marks.material = Art.unshaded()
	_through_marks.self_modulate = Color(1, 1, 1, THROUGH_MARKS)
	_through.add_child(_through_marks)
	_through_marks.draw.connect(_draw_marks_through)
	_through_ghosts = Node2D.new()
	_through_ghosts.material = _ghost_material()
	_through.add_child(_through_ghosts)
	_through_ghosts.draw.connect(_draw_ghosts)


## A flat shape in the colour it is drawn with, cut to the picture's own outline; the dark never dims it.
static func _ghost_material() -> ShaderMaterial:
	if _ghost_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nrender_mode unshaded;\nvarying vec4 tint;\nvoid vertex() { tint = COLOR; }\nvoid fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a); }\n"
		_ghost_mat = ShaderMaterial.new()
		_ghost_mat.shader = sh
	return _ghost_mat


func _draw_body_mask() -> void:
	var sp := _sprite()
	if sp.is_empty():
		return
	Art.draw_strip(_through, sp["tex"], sp["frames"], sp["frame"], _feet(), sp["origin"], sp["flip"])


## His picture's box right now, in the world.
func body_box() -> Rect2:
	var sp := _sprite()
	if sp.is_empty():
		return Rect2(global_position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	var tex: Texture2D = sp["tex"]
	var size := Vector2(float(tex.get_width()) / float(maxi(int(sp["frames"]), 1)), float(tex.get_height()))
	var o: Vector2 = sp["origin"]
	var left := (size.x - o.x) if bool(sp["flip"]) else o.x
	return Rect2(global_position + _feet() - Vector2(left, o.y) * Art.PIXEL, size * Art.PIXEL)


## His tossed scrap whose rings are still on the floor.
func through_shots() -> Array:
	var out: Array = []
	for s in get_tree().get_nodes_in_group("crown_shots"):
		if is_instance_valid(s) and s.by == self:
			out.append(s)
	return out


## The marks his body is over right now: his own (the slam's ring, the charge's lane, a landed slam) and his
## scrap's rings, as [what, where in the world].
func marks_under_him() -> Array:
	var out: Array = []
	var box := body_box()
	if not dead and not held:
		if mode == "slam_windup":
			out.append(["slam", global_position + _feet() + aim * slam_dist])
		elif mode == "charge_windup":
			out.append(["charge", global_position])
	if blow_t < BLOW_SHOW:
		out.append(["blow", blow_at])
	for s in through_shots():
		out.append(["scrap", s.global_position])
	return out.filter(func(m): return m[0] == "charge" or box.grow(maxf(slam_reach.x, toss_reach.x)).has_point(m[1]))


func _draw_marks_through() -> void:
	_draw_ground(_through_marks)
	for s in through_shots():
		s.draw_mark(_through_marks, s.global_position - global_position)


## Players his body hides: anyone higher up the screen than he is (so drawn before him) whose body overlaps his
## picture.
func behind_him() -> Array:
	var out: Array = []
	var box := body_box()
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not p.visible or p.global_position.y >= global_position.y:
			continue
		if box.intersects(Rect2(p.global_position + Vector2(-16.0, -50.0), Vector2(32.0, 56.0))):
			out.append(p)
	return out


func _draw_ghosts() -> void:
	for p in behind_him():
		var col: Color = Art.PLAYER_COLORS[int(p.index) % Art.PLAYER_COLORS.size()]
		col.a = THROUGH_GHOST
		var off: Vector2 = p.global_position - global_position
		var b: Dictionary = p._body_now()
		if b.is_empty():
			_through_ghosts.draw_circle(off, 15.0, col)
			continue
		# A pale edge one art pixel wide all round, then the body in the player's colour, so it reads on his rust.
		var rect := Rect2(-p._body_origin(), (b["src"] as Rect2).size)
		for edge in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			_through_ghosts.draw_set_transform(off + (b["at"] as Vector2) + edge * Art.PIXEL, float(b["angle"]), b["scale"])
			_through_ghosts.draw_texture_rect_region(b["tex"], rect, b["src"], GHOST_EDGE)
		_through_ghosts.draw_set_transform(off + (b["at"] as Vector2), float(b["angle"]), b["scale"])
		_through_ghosts.draw_texture_rect_region(b["tex"], rect, b["src"], col)
		_through_ghosts.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _think(delta: float) -> Vector2:
	mode_t -= delta
	if room.has_area() and (target == null or not room.has_point(target.global_position)):
		target = _room_target()
	return _fight(delta)


## The nearest player who is in his room.
func _room_target():
	var best = null
	var best_d := INF
	for p in players():
		var d: float = p.global_position.distance_squared_to(global_position)
		if room.has_point(p.global_position) and d < best_d:
			best = p
			best_d = d
	return best


func _fight(delta: float) -> Vector2:
	var at: Vector2 = target.global_position if target != null else global_position + aim * 80.0
	var to_p := at - global_position
	var dist := to_p.length()
	match mode:
		"idle":
			if target == null:
				next = ""
				return _walk_home(delta)
			if not crowned and hp <= max_hp * CROWN_AT:
				_set_mode("crown_on", CROWN_TIME)
				immune = true
				Sfx.play(self, "anvil", -9.0, 0.7)
				return Vector2.ZERO
			if next == "":
				next = _pick()
				walk_t = 0.0
			walk_t += delta
			if dist > 1.0:
				facing = to_p.normalized()
			var ready := false
			match next:
				"slam":
					ready = dist <= slam_near
				"toss":
					ready = dist <= TOSS_FAR and sees(at)
				"charge":
					ready = dist <= CHARGE_DIST and _lane_clear(at)
			if ready:
				goes = 2 if crowned else 1
				first_go = true
				hit_any = false
				first_mark = Vector2.INF
				attacks += 1
				done[next] = true
				last = next
				attack_started.emit(next, crowned)
				_begin(next, 1.0)
				return Vector2.ZERO
			if walk_t > WALK_MOST:
				# He cannot get to what he wanted: something else.
				next = "toss" if next != "toss" and sees(at) else "slam"
				walk_t = 0.0
			return _go(at, speed, delta)
		"slam_windup":
			if mode_t > LOCK and target != null and dist > 1.0:
				aim = to_p.normalized()
				facing = aim
				_reach_for(target.global_position)
			if mode_t <= 0.0:
				_set_mode("slam", SLAM_TIME)
				blow_done = false
				Sfx.play(self, "swing", -5.0, 0.5)
		"slam":
			if not blow_done and mode_t <= SLAM_TIME - SLAM_AT:
				blow_done = true
				_blow()
			if mode_t <= 0.0:
				_after()
		"toss_windup":
			if mode_t <= 0.0:
				_set_mode("toss", TOSS_TIME)
		"toss":
			if mode_t <= 0.0:
				_after()
		"charge_windup":
			if mode_t > LOCK and target != null and dist > 1.0:
				aim = to_p.normalized()
				facing = aim
			if mode_t <= 0.0:
				_set_mode("charge")
				charge_left = CHARGE_DIST
				struck.clear()
				Sfx.play(self, "dodge", -4.0, 0.5)
		"charge":
			charge_left -= CHARGE_SPEED * delta
			for p in players():
				if struck.has(int(p.index)):
					continue
				var rel: Vector2 = p.global_position - global_position
				if rel.length() < radius + 16.0 + 6.0 and p.can_be_hit(self):
					struck[int(p.index)] = true
					var before: float = p.hp
					p.take_damage(CHARGE, global_position - aim * 20.0, self)
					if p.hp < before or p.knocked_out_timer > 0.0:
						hit_any = true
						var off := rel - aim * rel.dot(aim)
						if off.length() < 1.0:
							off = aim.orthogonal()
						p.hurt_vel = (aim * 0.5 + off.normalized()).normalized() * PUSH
						Sfx.play(self, "anvil", -12.0, 0.7)
			if get_slide_collision_count() > 0 and charge_left < CHARGE_DIST - 48.0:
				# He ends against rock: dazed, and there is no second go.
				goes = 1
				Sfx.play(self, "slam", -7.0, 0.8)
				_shake(4.0)
				_set_mode("rest", REST + DAZED)
				open_for(REST + DAZED)
				next = ""
				return Vector2.ZERO
			if charge_left <= 0.0:
				_after()
				return Vector2.ZERO
			return aim * CHARGE_SPEED
		"again":
			if target != null and dist > 1.0:
				facing = to_p.normalized()
			if mode_t <= 0.0:
				goes -= 1
				first_go = false
				_begin(last, SECOND)
				return Vector2.ZERO
			# Between two slams he steps after you, so the second is not struck at the air.
			if last == "slam" and target != null and dist > slam_near * 0.8:
				return _go(at, speed * 1.6, delta)
		"rest":
			if mode_t <= 0.0:
				next = ""
				_set_mode("idle")
		"crown_on":
			if mode_t <= 0.0:
				crowned = true
				immune = false
				crown_put_on.emit()
				_set_mode("rest", 0.4)
	return Vector2.ZERO


## What he does next: one of each first, then whichever the dice say, never the same one twice running.
func _pick() -> String:
	for k in FIRST:
		if not done.has(k):
			return k
	var from: Array = FIRST.filter(func(k): return k != last)
	return str(from[clampi(floori(Sim.between(0.0, float(from.size()) - 0.001)), 0, from.size() - 1)])


## How far out the club comes down: where you are, but no nearer than about two thirds of its reach and no farther
## than all of it (his long club's head lands 81 art pixels out at most, in version 50's art).
func _reach_for(at: Vector2) -> void:
	slam_dist = clampf((at - global_position - _feet()).dot(aim), slam_out * SLAM_CHOKE, slam_out)


## The warning of an attack begins. `share`: how much of its usual length it lasts (the second go's is shorter).
func _begin(what: String, share: float) -> void:
	var at: Vector2 = target.global_position if target != null else global_position + aim * 80.0
	var to_p := at - global_position
	if to_p.length() > 1.0:
		aim = to_p.normalized()
		facing = aim
	match what:
		"slam":
			_set_mode("slam_windup", SLAM_WINDUP * share)
			_reach_for(at)
			Sfx.play(self, "warn", -11.0, 0.6)
		"toss":
			_set_mode("toss_windup", TOSS_WINDUP * share)
			aim_at = _in_room(at)
			if first_go:
				first_mark = aim_at
			else:
				# The second leads you, and never comes down on top of the first.
				aim_at = _apart(at + (target.velocity as Vector2) * 0.4 if target != null else at)
			var s := Scrap.new()
			s.by = self
			s.from = global_position + Vector2((-1.0 if facing.x < 0.0 else 1.0) * hand.x, _feet().y)
			s.from_up = hand.y
			s.to = aim_at
			s.wait = mode_t
			s.flight = TOSS_FLIGHT
			s.damage = TOSS
			s.reach = toss_reach
			get_parent().add_child(s)
			Sfx.play(self, "warn", -12.0, 0.9)
		"charge":
			_set_mode("charge_windup", CHARGE_WINDUP * share)
			Sfx.play(self, "warn", -10.0, 0.5)
	windup = mode_t


## A place for a ring that is on the floor of his room, clear of its walls.
func _in_room(at: Vector2) -> Vector2:
	return at.clamp(room.position + Vector2(44, 30), room.end - Vector2(44, 30)) if room.has_area() else at


## Where the second of two tosses comes down: never on top of the first, so both rings can be read.
func _apart(at: Vector2) -> Vector2:
	at = _in_room(at)
	if first_mark == Vector2.INF or at.distance_to(first_mark) >= TOSS_APART:
		return at
	var away := at - first_mark
	if away.length() < 4.0:
		# You have not moved: it comes down beside the first, on the side the dice say.
		away = (first_mark - global_position).orthogonal() * (1.0 if Sim.chance() < 0.5 else -1.0)
	if away.length() < 0.01:
		away = Vector2.RIGHT
	away = away.normalized()
	# (Against a wall that side may have no room: then another side of the first.)
	for turn in [0.0, PI, PI * 0.5, -PI * 0.5]:
		var spot := _in_room(first_mark + away.rotated(turn) * TOSS_APART)
		if spot.distance_to(first_mark) >= TOSS_APART - 1.0:
			return spot
	return _in_room(first_mark + away * TOSS_APART)


## A go of an attack is over: the second go if there is one to come, or he stands and gets his breath.
func _after() -> void:
	if goes > 1:
		_set_mode("again", AGAIN)
		return
	_set_mode("rest", REST)
	next = ""
	if not hit_any and last != "toss":
		open_for(REST)


## The club comes down.
func _blow() -> void:
	blow_at = global_position + _feet() + aim * slam_dist
	blow_t = 0.0
	Sfx.play(self, "slam", -5.0, 0.9)
	for p in players():
		if Scrap.on_mark(p.global_position, blow_at, slam_reach):
			var before: float = p.hp
			p.take_damage(SLAM, global_position, self)
			if p.hp < before or p.knocked_out_timer > 0.0:
				hit_any = true
	_shake(3.0)


## A lump he threw came down on nobody (scrap.gd tells him): he is Open for what is left of his rest.
func toss_missed() -> void:
	if mode == "rest" and not hit_any and mode_t > 0.0:
		open_for(mode_t)


func _shake(by: float) -> void:
	for p in players():
		if p.rig != null:
			p.rig.add_shake(by)
			break


func _lane_clear(at: Vector2) -> bool:
	return nav == null or nav.clear(global_position, at)


## Nobody to fight: he walks back to where he first stood.
func _walk_home(delta: float) -> Vector2:
	if home != Vector2.INF and global_position.distance_to(home) > 26.0:
		var v := _go(home, speed, delta)
		if v.length() > 1.0:
			facing = v.normalized()
		return v
	return Vector2.ZERO


# --- His pictures (a sheet and a book of his own: scrap.gd cuts them) ----------------------------

func art_name() -> String:
	return "rattlecrown_crowned" if crowned else "rattlecrown"


func _art_info() -> Dictionary:
	return Art.json(Scrap.BOOK).get("enemies", {}).get(art_name(), {})


func _art_tex(anim: String) -> Texture2D:
	var strip: Dictionary = _art_info().get("strips", {}).get(anim, {})
	return Scrap.strip_tex(strip.get("box"))


func _anim() -> Array:
	match mode:
		"slam_windup":
			return ["slam_windup", anim_time, true]
		"slam":
			return ["slam", SLAM_TIME - mode_t, false]
		"toss_windup":
			return ["toss_windup", anim_time, true]
		"toss":
			return ["toss", TOSS_TIME - mode_t, false]
		"charge_windup":
			return ["charge_windup", anim_time, true]
		"charge":
			return ["charge", anim_time, true]
		"crown_on":
			return ["crown_on", CROWN_TIME - mode_t, false]
	var hit_strip: Dictionary = _art_info().get("strips", {}).get("hit", {})
	if not hit_strip.is_empty() and hit_anim < float(hit_strip["frames"]) / float(hit_strip["fps"]):
		return ["hit", hit_anim, false]
	if velocity.length() > 10.0:
		return ["move", anim_time, true]
	return ["idle", anim_time, true]


## The marks on the floor: the Club Slam's ring and the Charge's lane, in the game's warning orange.
func _draw_ground(ci: CanvasItem) -> void:
	if dead or held:
		return
	match mode:
		"slam_windup":
			var k := 1.0 - clampf(mode_t / maxf(windup, 0.01), 0.0, 1.0)
			_ring(ci, _feet() + aim * slam_dist, clampi(int(k * 3.0), 0, 2))
		"charge_windup":
			if not Warn.lane(ci, "wide", mode_t <= LOCK, Vector2(0, radius * 0.5), aim, CHARGE_DIST + radius, anim_time):
				ci.draw_line(Vector2.ZERO, aim * (CHARGE_DIST + radius), Color("#ff8a3c"), 6.0)
	if blow_t < BLOW_SHOW:
		_ring(ci, blow_at - global_position, 3)


func _ring(ci: CanvasItem, at: Vector2, frame: int) -> void:
	if not Scrap.draw_shot(ci, "slam_mark", frame, at):
		ci.draw_arc(at, slam_reach.x, 0.0, TAU, 28, Color("#ff8a3c"), 2.0)
