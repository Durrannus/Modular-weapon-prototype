extends CharacterBody2D

const WeaponBuild := preload("res://scripts/weapon/weapon_build.gd")
## The player: movement, dodge, aiming, and running the combo the weapon build
## produced. Each combo step is one move (slash, stab, lunge, spin, overhead).
## Blade elements add effects on hit (fire, water, lightning, steam, electrified).
##
## Feel rules (9 November, measured against Core Keeper and similar games):
## - You face the way you walk. Attacking turns you to the aim for a moment.
## - One press is one swing. A press during a swing queues exactly one more.
##   Holding attack keeps the chain going at a steady beat.
## - Hits never freeze the game. The enemy freezes for a few frames and is knocked
##   back; only a finisher that connects plants you for a moment.

signal knocked_out(player)

const Fx := preload("res://scripts/fx/fx.gd")
const Art := preload("res://scripts/art.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const SwordArt := preload("res://scripts/weapon/sword_art.gd")
const RuneFx := preload("res://scripts/fx/rune_fx.gd")
const Sfx := preload("res://scripts/sfx.gd")
const SpriteOnce := preload("res://scripts/fx/sprite_once.gd")
const PlayerInput := preload("res://scripts/player_input.gd")
const Sim := preload("res://scripts/sim.gd")

const MOVE_SPEED := 220.0      # about 3.7 body heights a second, like Core Keeper
const ACCEL := 3000.0          # full speed in about 4 frames
const DECEL := 4200.0          # stops in about 3
const TURN := 5200.0           # reversing is quicker than starting
const FACE_LINGER := 0.28      # keep facing the swing this long after it ends
const DIAGONAL_GRACE := 0.07   # letting go of two keys a moment apart still ends on the diagonal
const RADIUS := 16.0
const COMBO_WINDOW := 0.5      # stop attacking this long and the combo resets
const FINISHER_RECOVERY := 0.1   # short pause after the finisher, so holding keeps a steady beat

const DODGE_SPEED := 620.0
const DODGE_TIME := 0.15
const DODGE_MAX_CHARGES := 1
const DODGE_REFILL := 0.8      # seconds per charge

## The sword moves. A blade's shape picks three of them for its chain
## (SHAPES in swing_build.gd). Times are at attack speed 1.0.
##   windup   time before the hit lands          time    the whole move
##   shape    "arc" (arc: degrees), "line" (width: half-width) or "circle"
##   power    damage, in blade hits               max_hits  a line stops after this many enemies
##   reach    extra reach for this move (1.0 = the blade's)
##   curve    how the sword swings: [start, end, arm at start, arm at end], angles
##            from the aim; a thrust starts and ends on the aim
##   smear    the picture of the swing            mirror  swung the other way
##   alternate  every other one in a chain is mirrored
## Every light move takes the same time and every finisher the same time, and a
## chain is always 1 + 1 + 1.5 hits, so a shape's damage a second is its damage
## times its speed and nothing else.
const LIGHT := 0.36
const HEAVY := 0.45
const MOVES := {
	# Broadsword (and the wooden and tin blades): slash, slash, overhead.
	"slash": {"windup": 0.055, "time": LIGHT, "shape": "arc", "arc": 120.0, "power": 1.0, "knock": 240.0, "stun": 0.16, "freeze": 0.05,
		"curve": [-0.9, 0.9, 13.0, 16.0], "smear": "slash_smear", "alternate": true},
	"overhead": {"windup": 0.14, "time": HEAVY, "shape": "arc", "arc": 120.0, "power": 1.5, "knock": 400.0, "stun": 0.3, "freeze": 0.1, "shake": 11.0,
		"curve": [-1.4, 0.45, 10.0, 18.0], "smear": "overhead_smear", "big": true},
	# Dagger: stab, slash, stab. Quick pokes at one enemy and a short flick.
	"dagger_stab": {"windup": 0.05, "time": LIGHT, "shape": "line", "width": 12.0, "max_hits": 1, "power": 1.0, "knock": 150.0, "stun": 0.1, "freeze": 0.03,
		"curve": [0.0, 0.0, 4.0, 22.0], "smear": "thrust_smear"},
	"dagger_slash": {"windup": 0.05, "time": LIGHT, "shape": "arc", "arc": 60.0, "power": 1.0, "knock": 170.0, "stun": 0.1, "freeze": 0.03,
		"curve": [-0.56, 0.56, 12.0, 15.0], "smear": "flick_smear"},
	"dagger_finish": {"windup": 0.09, "time": HEAVY, "shape": "line", "width": 14.0, "max_hits": 1, "power": 1.5, "knock": 300.0, "stun": 0.25, "freeze": 0.08, "shake": 7.0,
		"curve": [0.0, 0.0, 2.0, 26.0], "smear": "thrust_smear"},
	# Sabre: slash, backslash, wide sweep. Every cut is wide.
	"sabre_slash": {"windup": 0.055, "time": LIGHT, "shape": "arc", "arc": 160.0, "power": 1.0, "knock": 220.0, "stun": 0.14, "freeze": 0.04,
		"curve": [-1.3, 1.3, 13.0, 16.0], "smear": "sweep_smear"},
	"sabre_back": {"windup": 0.055, "time": LIGHT, "shape": "arc", "arc": 160.0, "power": 1.0, "knock": 220.0, "stun": 0.14, "freeze": 0.04,
		"curve": [-1.3, 1.3, 13.0, 16.0], "smear": "sweep_smear", "mirror": true},
	"sabre_sweep": {"windup": 0.12, "time": HEAVY, "shape": "arc", "arc": 160.0, "power": 1.5, "knock": 340.0, "stun": 0.25, "freeze": 0.08, "shake": 9.0,
		"curve": [-1.48, 1.48, 12.0, 18.0], "smear": "sweep_smear", "big": true},
	# Rapier: thrust, thrust, lunge. A straight line that goes through to a second
	# enemy. The lunge reaches further instead of moving you: attacks never carry
	# you into the enemy (Darren, 9 November).
	"thrust": {"windup": 0.06, "time": LIGHT, "shape": "line", "width": 13.0, "max_hits": 2, "power": 1.0, "knock": 200.0, "stun": 0.12, "freeze": 0.04,
		"curve": [0.0, 0.0, 4.0, 26.0], "smear": "thrust_smear"},
	"long_thrust": {"windup": 0.14, "time": HEAVY, "shape": "line", "width": 15.0, "max_hits": 2, "reach": 1.25, "power": 1.5, "knock": 340.0, "stun": 0.25, "freeze": 0.08, "shake": 8.0,
		"curve": [0.0, 0.0, 0.0, 32.0], "smear": "thrust_smear", "big": true},
	# Falchion: chop, chop, cleave. Everything shoves hard, and the cleave staggers.
	"chop": {"windup": 0.08, "time": LIGHT, "shape": "arc", "arc": 110.0, "power": 1.0, "knock": 430.0, "stun": 0.2, "freeze": 0.06, "shake": 4.0,
		"curve": [-1.05, 0.35, 11.0, 17.0], "smear": "chop_smear"},
	"cleave": {"windup": 0.15, "time": HEAVY, "shape": "arc", "arc": 110.0, "power": 1.5, "knock": 560.0, "stun": 0.8, "freeze": 0.11, "shake": 12.0,
		"curve": [-1.5, 0.4, 10.0, 18.0], "smear": "overhead_smear", "big": true},
	# Greatsword: sweep, backswing, slam. Half a circle each way, then the ground breaks.
	"great_sweep": {"windup": 0.1, "time": LIGHT, "shape": "arc", "arc": 180.0, "power": 1.0, "knock": 320.0, "stun": 0.2, "freeze": 0.06, "shake": 4.0,
		"curve": [-1.48, 1.48, 13.0, 17.0], "smear": "sweep_smear"},
	"great_back": {"windup": 0.1, "time": LIGHT, "shape": "arc", "arc": 180.0, "power": 1.0, "knock": 320.0, "stun": 0.2, "freeze": 0.06, "shake": 4.0,
		"curve": [-1.48, 1.48, 13.0, 17.0], "smear": "sweep_smear", "mirror": true},
	"slam": {"windup": 0.19, "time": HEAVY, "shape": "arc", "arc": 120.0, "power": 1.5, "knock": 480.0, "stun": 0.45, "freeze": 0.12, "shake": 15.0,
		"curve": [-1.5, 0.3, 9.0, 19.0], "smear": "overhead_smear", "big": true, "burst": "slam_burst"},
	# The old parts-grid moves (weapon_build.gd), kept so that screen still works.
	"stab": {"windup": 0.06, "time": 0.25, "shape": "line", "width": 16.0, "range": 115.0, "power": 1.15, "knock": 320.0,
		"curve": [0.0, 0.0, 4.0, 26.0], "smear": "thrust_smear"},
	"lunge": {"windup": 0.15, "time": 0.38, "shape": "line", "width": 24.0, "range": 85.0, "power": 1.3, "knock": 300.0, "dash": 170.0,
		"curve": [0.0, 0.0, 4.0, 26.0], "smear": "thrust_smear"},
	"spin": {"windup": 0.07, "time": 0.44, "shape": "circle", "range": 72.0, "power": 0.85, "knock": 260.0,
		"curve": [0.0, TAU, 14.0, 14.0], "smear": "slash_smear"},
}

var color := Color(0.35, 0.7, 1.0)
var max_hp := 100.0
var hp := 100.0
var spawn_point := Vector2.ZERO
var aim_dir := Vector2.RIGHT   # where an attack goes: the mouse, the right stick, or the way you face
var face_dir := Vector2.DOWN   # where the body looks
var input: PlayerInput         # this player's controls (set before adding; defaults to every device)
var index := 0                 # 0 = player one
var character := "crew_a"      # body strips: art/body/<character>_*.png
var rig = null                 # the shared camera (camera_rig.gd)
var frozen := false            # a dialogue or cutscene has the controls
var is_down := false           # knocked out and waiting to get back up
var down_time := 0.0           # how long they've been down (plays the fall)
var down_flip := false         # fell facing left
var rise_timer := 0.0          # getting back up: the fall played backwards
var auto_respawn := true       # get straight back up at spawn_point (the test arena)
var show_marker := false       # coloured ring under the feet (two players)
var light: PointLight2D     # the small light the player carries
var interact_ready := false    # standing at something usable: A on a controller uses it and doesn't dodge
var note := ""                 # a word over their head ("AT THE FORGE", online, for the other player to read)

## Screen shake goes to the shared camera.
var shake: float:
	set(v):
		if rig != null:
			rig.shake = v
	get:
		return rig.shake if rig != null else 0.0

var walk_vel := Vector2.ZERO
var hurt_vel := Vector2.ZERO   # knocked back by a hit
var hit_pause := 0.0           # planted for a moment when a finisher connects
var hurt_flash := 0.0
var face_linger := 0.0
var diag_dir := Vector2.ZERO
var diag_time := -9.0
var walk_phase := 0.0
var settle := 0.0              # 0 = holding the end of the swing, 1 = back at rest
var return_t := 0.0            # easing the sword back to rest after the last swing
var return_from: Array = [0.0, Vector2.ZERO]

var weapon: Dictionary = {}
var step_index := 0        # next combo step
var current_step := -1     # step being played, -1 when idle
var step_timer := 0.0
var step_elapsed := 0.0
var hit_time := -1.0       # when the current move's hit lands (-1 once landed)
var step_duration := 0.0
var queued := false
var combo_timer := 0.0
var lunge_timer := 0.0
var lunge_dir := Vector2.RIGHT
var lunge_speed := 0.0
var dodge_timer := 0.0
var dodge_dir := Vector2.RIGHT
var dodge_charges := DODGE_MAX_CHARGES
var dodge_refill := 0.0
var invuln := 0.0
var anim_move := ""
var anim_dir := Vector2.RIGHT
var knocked_out_timer := 0.0
var facing := "down"       # nearest of 4 directions to the aim: up, down, left, right
var facing8 := "down"      # nearest of 8: adds down_right, up_right, down_left, up_left
var weapon_layer: Node2D
var weapon_group: CanvasGroup  # holds the sword so it gets one outline
var anim_time := 0.0

# Swing animation. The sword rests lowered at the side and only swings out on attack.
# The hand orbits the shoulder, so the whole arm and sword sweep round the body.
const SHOULDER := Vector2(0, -18)   # relative to the player's centre
const ARM := 15.0                   # shoulder to hand while swinging
var swing_side := 1.0               # +1 / -1: slashes alternate direction
var pose_angle := PI * 0.4          # what's drawn, smoothed toward the target pose
var pose_hand := Vector2(10, -14)
var pose_from_angle := 0.0          # where the current swing started from
var trail: Array = []               # [hand, angle, time] samples while sweeping
var trail_layer: Node2D
var under_lit: Node2D               # the shadow, behind the body
var under_bright: Node2D            # the who-is-who ring, behind the body and never dimmed
var rim: Node2D                     # the body's lit rim (its _glow image), never dimmed
var squash := Vector2.ONE           # body squash and stretch
var lean := 0.0                     # body lean in radians
var stepped := false                # has this swing's step forward happened
var trail_te := -1.0                # step time of the last trail sample

# Swing path runes
const REPEAT_GAP := 0.16      # Twice: the second go comes this long after the first
var game_time := 0.0
var rune_queue: Array = []    # [{at, effect, size, power, hits}]
var slot_flash := {}          # slot index -> game_time it last fired
var last_kill_pos := Vector2.ZERO
var sweep_flash := {}         # slot index -> game_time the swing passes it
var dodge_started := -9.0     # game_time the last dodge began
var attack_buffered := false  # attack pressed mid-dodge, swung as the dodge ends
var rune_counts := {}         # effect index -> triggers seen (Saved Up fires every third)

# Leap (active since 11 November): a press jumps you to an enemy and lands you at
# your blade's full reach from it, with a strike as you land. It used to land on
# top of the enemy, which got you hit every time.
const LEAP_RANGE := 260.0     # how far away an enemy can be
const LEAP_TIME := 0.14       # the jump itself
const LEAP_AIM := 1.0         # prefers an enemy within this many radians of the aim
const LEAP_DAMAGE := 1.0      # the landing strike, in blade hits
const LEAP_STUN := 0.3
const LEAP_EMPTY := 130.0     # with nobody in range, it jumps this far the way you aim
var leap_targets: Array = []  # enemies already leapt to in this burst
var leap_burst := -9.0        # game_time the last leap of a burst began
var leap_landing: Dictionary = {}   # the strike waiting for the jump to end: {at, dir, size, power, target}

# Weak Point (passive, 11 November): the finisher marks the enemy it hit, and the
# next sword hit on the mark is a big crit. Only so many marks at a time.
const WEAK_CRIT := 2.5        # a full-strength mark's hit, in normal hits
const WEAK_DODGE_REACH := 70.0  # On Dodge: how close the dodge must pass
var weak_marks: Array = []    # this player's marks, oldest first: [[enemy, mark]]

# Active runes (Whirlwind, Hook, Leap) wait for their ability button instead of firing
# by themselves. Each button has a meter from 0 (used up) to 1 (full) that refills
# over the rune's recharge time. A press rune needs a full meter and empties it.
# A hold rune spends one turn's worth of meter for every turn, and keeps going
# while the button stays down and there is meter left.
const ABILITY_WAIT := 0.35      # a hold rune's meter starts to refill this long after it stops
const HOLD_MOVE := 0.75         # walking speed while a hold rune is going
const HOLD_KNOCK := 0.35        # a held Whirlwind shoves this much as hard, so enemies stay in reach
var ability_charge: Array = [1.0, 1.0, 1.0]
var ability_wait: Array = [0.0, 0.0, 0.0]
var ability_denied: Array = [-9.0, -9.0, -9.0]  # game_time of the last press that wasn't ready
var ability_used: Array = [-9.0, -9.0, -9.0]    # game_time it last went off
var ability_refunded: Array = [-9.0, -9.0, -9.0]  # game_time a landed swing last brought it back sooner (Every Hit)
var hold_button := -1           # which button's hold rune is going right now (-1: none)
var hold_left := 0.0            # time left in its current turn
var hold_turn := 0.28           # how long that turn takes
var hold_turns := 0             # turns so far in this hold
var hold_angle := 0.0           # where the spin started (and where every turn starts)
var hold_side := 1.0            # +1 clockwise, -1 the other way
var hold_fx: Array = []         # what the current turn put on screen, removed if it's cut short

## Where the body sprite's feet sit, relative to the player's centre.
const FEET := Vector2(0, 14)
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	if input == null:
		input = PlayerInput.new()
	if Art.texture("body/%s_idle_down.png" % character) == null:
		character = "crew_a"
	spawn_point = global_position
	# The sword is its own layer so it can sit behind the body when facing up.
	# All sword parts and the hand go in one CanvasGroup so the outline shader
	# draws one outline round the assembled sword.
	# Under the body: its shadow (lit like the floor), then the ring that says who
	# is who (kept bright). On top of the body: its lit rim, also kept bright.
	under_lit = Node2D.new()
	under_lit.show_behind_parent = true
	add_child(under_lit)
	under_lit.draw.connect(_draw_shadow)
	under_bright = Node2D.new()
	under_bright.show_behind_parent = true
	under_bright.material = Art.unshaded()
	add_child(under_bright)
	under_bright.draw.connect(_draw_ring)
	rim = Node2D.new()
	rim.material = Art.unshaded()
	add_child(rim)
	rim.draw.connect(_draw_rim)
	# The swing's smear glows: added on top of the picture and never dimmed.
	trail_layer = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	trail_layer.material = add
	add_child(trail_layer)
	trail_layer.draw.connect(_draw_trail)
	weapon_group = CanvasGroup.new()
	weapon_group.name = "Weapon"
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	weapon_group.material = mat
	add_child(weapon_group)
	weapon_layer = Node2D.new()
	weapon_group.add_child(weapon_layer)
	weapon_layer.draw.connect(_draw_weapon)
	# A small cool light that follows the player, so they read in the darkest corner.
	light = PointLight2D.new()
	var stepped := Art.stepped_light(64)
	light.texture = stepped if stepped != null else Art.light_texture()
	light.texture_scale = Art.PIXEL if stepped != null else 2.4
	light.energy = 0.55
	light.color = Color(0.85, 0.92, 1.0)
	light.position = Vector2(0, -10)
	add_child(light)


func set_weapon(stats: Dictionary) -> void:
	weapon = stats
	rune_queue.clear()
	slot_flash.clear()
	sweep_flash.clear()
	rune_counts.clear()
	leap_landing = {}
	_clear_marks()
	_stop_hold(true)
	ability_charge = [1.0, 1.0, 1.0]
	ability_wait = [0.0, 0.0, 0.0]
	_reset_combo()


func _reset_combo() -> void:
	step_index = 0
	current_step = -1
	hit_time = -1.0
	queued = false
	combo_timer = 0.0
	lunge_timer = 0.0


func _input(event: InputEvent) -> void:
	input.feed(event)


func _physics_process(delta: float) -> void:
	input.poll()
	invuln = maxf(invuln - delta, 0.0)
	hurt_flash = maxf(hurt_flash - delta, 0.0)
	game_time += delta
	_run_rune_queue()
	_run_shards()
	_run_leap()
	if is_down:
		_stop_hold(true)
		_refill_abilities(delta)
		walk_vel = Vector2.ZERO
		hurt_vel = hurt_vel.move_toward(Vector2.ZERO, 1800.0 * delta)
		velocity = hurt_vel
		move_and_slide()
		return

	var move := Vector2.ZERO if frozen else input.move
	_update_facing(delta, move)
	_update_dodge(delta, move)
	_update_abilities(delta)

	# Walking: a few frames to get going and to stop, so it has weight without lag.
	var speed := MOVE_SPEED * (1.0 + float(weapon.get("move_speed", 0.0)))
	var target := move * speed
	if hold_button >= 0:
		target *= HOLD_MOVE
	elif current_step >= 0:
		# Barely slowed while swinging; the blade's shape can change that.
		target *= float(weapon.get("swing_move", SwingBuild.SWING_MOVE))
	var rate := ACCEL
	if move == Vector2.ZERO:
		rate = DECEL
	elif walk_vel.dot(target) < 0.0:
		rate = TURN
	walk_vel = walk_vel.move_toward(target, rate * delta)
	var vel := walk_vel
	if hit_pause > 0.0:
		vel = Vector2.ZERO
	if dodge_timer > 0.0:
		dodge_timer -= delta
		vel = dodge_dir * DODGE_SPEED
		walk_vel = dodge_dir * speed if move != Vector2.ZERO else Vector2.ZERO
	elif lunge_timer > 0.0:
		lunge_timer -= delta
		vel = lunge_dir * lunge_speed
	hurt_vel = hurt_vel.move_toward(Vector2.ZERO, 1800.0 * delta)
	velocity = vel + hurt_vel
	move_and_slide()
	if rig != null:
		var kept: Vector2 = rig.leash(self, global_position)
		if kept != global_position:
			global_position = kept
	walk_phase += delta * 14.0 * clampf(velocity.length() / MOVE_SPEED, 0.55, 1.3)

	_update_combat(delta)


## Where the body looks and where an attack would go.
## Looking: the way you walk (or the right stick). Attacking: the mouse, the right
## stick, or straight ahead.
func _update_facing(delta: float, move: Vector2) -> void:
	face_linger = maxf(face_linger - delta, 0.0)
	var stick := input.stick_aim
	if hold_button >= 0:
		face_dir = Vector2.RIGHT.rotated(_hold_angle_now())   # the body turns with the spin
		face_linger = 0.0
	elif current_step >= 0:
		face_dir = anim_dir
		face_linger = FACE_LINGER
	elif dodge_timer > 0.0:
		face_dir = dodge_dir
	elif not input.uses_mouse() and stick.length() > 0.3:
		face_dir = stick.normalized()
	elif move.length() > 0.2 and face_linger <= 0.0:
		var diagonal := absf(move.x) > 0.3 and absf(move.y) > 0.3
		if diagonal:
			diag_dir = move.normalized()
			diag_time = game_time
			face_dir = diag_dir
		elif game_time - diag_time > DIAGONAL_GRACE:
			face_dir = move.normalized()
	if frozen:
		return
	if input.uses_mouse():
		# Online the mouse arrives with the rest of this player's controls, as an
		# offset from the player; here it is read straight from the screen.
		var to_mouse: Vector2 = input.aim_offset if input.kind == "net" else get_global_mouse_position() - global_position
		if to_mouse.length() > 4.0:
			aim_dir = to_mouse.normalized()
	elif stick.length() > 0.3:
		aim_dir = stick.normalized()
	elif move.length() > 0.2:
		aim_dir = move.normalized()
	elif current_step < 0:
		aim_dir = face_dir


# --- Dodge ------------------------------------------------------------------
# Everyone has a short step. One charge that refills. Cancels the swing and
# resets the combo. It goes the way you're pushing, or the way you face.

func _update_dodge(delta: float, move: Vector2) -> void:
	if dodge_charges < DODGE_MAX_CHARGES:
		dodge_refill += delta
		if dodge_refill >= DODGE_REFILL:
			dodge_refill = 0.0
			dodge_charges += 1
	if input.dash_pressed and interact_ready and input.using_pad:
		return
	if input.dash_pressed and not frozen and dodge_charges > 0 and dodge_timer <= 0.0:
		dodge_charges -= 1
		dodge_refill = 0.0
		# (Mid-spin the body faces anywhere, so a standing dodge goes where you aim.)
		dodge_dir = move.normalized() if move.length() > 0.1 else (aim_dir if hold_button >= 0 else face_dir)
		dodge_timer = DODGE_TIME
		invuln = maxf(invuln, DODGE_TIME + 0.06)
		hit_pause = 0.0
		face_linger = 0.0
		_reset_combo()
		dodge_started = game_time
		_dust(global_position + FEET)
		Sfx.play(self, "dodge", -12.0)
		_trigger("dodge", [])


# --- Combo ------------------------------------------------------------------

func _steps() -> Array:
	return weapon.get("steps", [])


func _speed() -> float:
	return maxf(float(weapon.get("speed", 1.0)), 0.2)


func armed() -> bool:
	return weapon.has("blade") and not _steps().is_empty()


func _update_combat(delta: float) -> void:
	if frozen or not armed():
		attack_buffered = false
		queued = false
		if current_step >= 0:
			_reset_combo()
		return
	# One press, one swing. A press during a swing (or a dodge) queues the next one;
	# holding the button keeps the chain going.
	if input.attack_pressed:
		if dodge_timer > 0.0 or hold_button >= 0 or not leap_landing.is_empty():
			attack_buffered = true
		elif current_step >= 0:
			queued = true
	var held := input.attack_held
	if need_release:
		# A click that closed a menu shouldn't also swing: wait for the button to come up.
		need_release = held
		held = false
	# (No swinging in the middle of a Whirlwind or a Leap: the swing starts as it ends.)
	if current_step < 0 and dodge_timer <= 0.0 and hold_button < 0 and leap_landing.is_empty() and (input.attack_pressed or attack_buffered or held):
		attack_buffered = false
		_start_step()

	if hit_pause > 0.0:
		hit_pause -= delta
		return
	if current_step >= 0:
		step_elapsed += delta
		if hit_time >= 0.0 and step_elapsed >= hit_time:
			hit_time = -1.0
			_do_move(_steps()[current_step]["move"])
		if step_elapsed >= step_duration:
			_end_step()
	elif combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			step_index = 0


var need_release := false


func _start_step() -> void:
	var steps := _steps()
	if steps.is_empty():
		return
	if step_index >= steps.size():
		step_index = 0
	current_step = step_index
	var move: String = steps[current_step]["move"]
	var info: Dictionary = MOVES.get(move, MOVES["slash"])
	var speed := _speed()
	step_elapsed = 0.0
	hit_time = float(info["windup"]) / speed
	step_duration = float(info["time"]) / speed
	if current_step == steps.size() - 1 and steps.size() > 1:
		step_duration += FINISHER_RECOVERY / speed
	queued = false
	anim_move = move
	anim_dir = aim_dir
	face_dir = anim_dir
	face_linger = FACE_LINGER
	swing_side = 1.0
	if info.get("mirror", false) or (info.get("alternate", false) and current_step % 2 == 1):
		swing_side = -1.0
	pose_from_angle = wrapf(pose_angle - anim_dir.angle(), -PI, PI)
	stepped = false
	settle = 0.0
	return_t = 0.0
	smear_t0 = -1.0
	# The swing travels up the sword: each slot lights for a moment, grip to tip.
	for i in weapon.get("line", []).size():
		sweep_flash[i] = game_time + float(i) * 0.04
	if info.has("dash"):
		lunge_dir = aim_dir
		lunge_timer = hit_time
		lunge_speed = float(info["dash"]) / maxf(hit_time, 0.01)


func _end_step() -> void:
	var steps := _steps()
	var was_last := current_step >= steps.size() - 1
	step_index = 0 if was_last else current_step + 1
	current_step = -1
	if queued or (input.attack_held and not need_release):
		queued = false
		_start_step()
	else:
		combo_timer = COMBO_WINDOW
		# Ease the sword back to rest from wherever the swing left it.
		return_from = [pose_angle, pose_hand]
		return_t = RETURN_TIME


const RETURN_TIME := 0.12


func _do_move(move: String) -> void:
	var info: Dictionary = MOVES.get(move, MOVES["slash"])
	var area := 1.0 + float(weapon.get("area", 0.0))
	var dmg: float = float(weapon.get("damage", 4.0)) * float(info["power"])
	var knock: float = info["knock"]
	var stun: float = float(info.get("stun", 0.12))
	var freeze: float = float(info.get("freeze", 0.05))
	var dir := anim_dir
	var hit_list: Array = []

	# One shape in front, tested once on the hit frame (like Core Keeper): reach is
	# the blade's length plus a little margin, so it matches the sword you hold.
	var reach := _hit_reach() * float(info.get("reach", 1.0))
	if not weapon.has("blade"):
		reach = float(info.get("range", 74.0)) * float(weapon.get("reach", 1.0)) * area
	var shape := str(info["shape"])
	var swing := {"shape": shape, "dir": dir, "reach": reach,
		"half_arc": deg_to_rad(float(info.get("arc", 120.0)) * 0.5), "width": float(info.get("width", 16.0))}
	var found: Array = []   # [distance along the swing, enemy, knock direction]
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - global_position
		var r: float = e.radius
		var hit := false
		match shape:
			"line":
				var along := rel.dot(dir)
				var side_d := absf(rel.dot(dir.orthogonal()))
				hit = along > -r and along <= reach + r and side_d <= float(info["width"]) + r
			"circle":
				hit = rel.length() <= reach + r
			_:
				# The arc only has to touch the enemy's body, not reach its middle.
				var d := rel.length()
				var body := asin(minf(r / maxf(d, 1.0), 1.0))
				hit = d <= reach + r and (d < r + RADIUS or absf(dir.angle_to(rel)) <= float(swing["half_arc"]) + body)
		if hit:
			var kdir := rel.normalized() if rel.length() > 0.01 else dir
			if shape == "line":
				kdir = dir
			found.append([rel.dot(dir) if shape == "line" else rel.length(), e, kdir])
	# A thrust stops after so many enemies, nearest first (the rapier goes through
	# to a second one, the dagger's stab stays in the first).
	if info.has("max_hits") and found.size() > int(info["max_hits"]):
		found.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
		found.resize(int(info["max_hits"]))
	for f in found:
		_hit_enemy(f[1], dmg, f[2], knock, stun, freeze, swing)
		hit_list.append(f[1])
	var hits := hit_list.size()

	if info.has("burst"):
		# Where a slam lands: the ground breaks at the end of the blade. Seen from
		# above, so it is never turned.
		Art.play_piece(self, str(info["burst"]), global_position + dir * reach * 0.72 + Vector2(0, 8), 0.0, reach / 137.0)

	var fx := Fx.new()
	fx.kind = shape
	if shape == "arc" or (shape == "line" and Art.piece_texture(str(info.get("smear", ""))) != null):
		fx.kind = "none"  # the sword's own smear shows the swing
	fx.dir = dir
	fx.radius = reach
	fx.arc = float(info.get("arc", 120.0))
	fx.width = float(info.get("width", 16.0)) * area
	fx.color = weapon.get("hit_color", Color.WHITE)
	fx.thick = info.get("big", false)
	_fx_root().add_child(fx)
	fx.global_position = global_position

	Sfx.play(self, "swing", -14.0)
	var finisher := current_step == _steps().size() - 1 and _steps().size() > 1
	if finisher:
		# A finisher that connects lands loud: you plant for a moment, the screen
		# shakes and it thumps. A miss is just a swing. Nothing else in the game stops.
		if hits > 0:
			shake = maxf(shake, maxf(10.0, float(info.get("shake", 0.0))))
			# (Shorter on a fast blade, longer on a slow one, so the pause never
			# changes how one shape's damage a second compares with another's.)
			hit_pause = FINISHER_PAUSE / _speed()
			Sfx.play(self, "finisher", -4.0)
		else:
			shake = maxf(shake, 2.5)
			Sfx.play(self, "finisher", -12.0)
		_trigger("finisher", hit_list)
	if hits > 0:
		Sfx.play(self, "hit", -8.0)
		_trigger("hit", hit_list)
		_hit_refund()


const FINISHER_PAUSE := 0.07


## swing: the swing's shape ({shape, dir, reach, half_arc, width}), to tell whether
## it reaches a Weak Point mark on the enemy. Empty for anything that isn't a swing.
func _hit_enemy(e, dmg: float, kdir: Vector2, knock: float, stun := 0.12, freeze := 0.05, swing := {}) -> void:
	# A Weak Point mark turns this hit into a big crit, whoever's mark it is.
	var mark: Dictionary = {}
	if not swing.is_empty() and not e.weak_marks.is_empty():
		var spot_at: Vector2 = e.global_position
		for m in e.weak_marks:
			if e.weak_reached(m, global_position, swing):
				spot_at = e.global_position + (e.weak_spot_drawn(m) if e.weak_big() else Vector2(0, -e.radius * 0.5))
				break
		mark = e.pop_weak_mark(global_position, swing)
		if not mark.is_empty():
			_forget_mark(mark)
			var bonus := (WEAK_CRIT - 1.0) * float(mark["power"]) + maxf(float(weapon.get("crit_damage", 1.6)) - 1.6, 0.0)
			var col: Color = SwingBuild.FITTINGS["weak_point"]["color"]
			e.take_hit(dmg * (1.0 + bonus), kdir, knock, true, col, maxf(stun, 0.3), maxf(freeze, 0.09))
			# (The break is the hit's spark: it plays in place of the usual crit spark.)
			Art.play_piece(self, "weak_break", spot_at, 0.0, 1.0 + 0.25 * minf(float(mark["power"]), 3.0))
			shake = maxf(shake, 9.0 + 2.0 * minf(float(mark["power"]), 3.0))
			hit_pause = maxf(hit_pause, 0.05)
			Sfx.play(self, "finisher", -3.0, 1.5)
			_label("WEAK POINT!", col)
			_apply_elements(e, dmg * (1.0 + bonus))
			return
	var crit := Sim.chance() < float(weapon.get("crit", 0.05))
	var final := dmg * (float(weapon.get("crit_damage", 1.5)) if crit else 1.0)
	e.take_hit(final, kdir, knock, crit, weapon.get("hit_color", Color.WHITE), stun, freeze)
	# A spark where the blade lands, thrown the way the hit goes.
	Art.play_piece(self, "hit_spark_crit" if crit else "hit_spark", e.global_position - kdir * float(e.radius) * 0.4, kdir.angle())
	_apply_elements(e, final)


# --- Swing path runes -----------------------------------------------------------
# A rune fires on its trigger (finisher, hit, kill). Twice queues repeats a beat
# apart. Identical runes firing at the same moment merge into one bigger effect.

func _trigger(trigger: String, hits: Array) -> void:
	var effects: Array = weapon.get("effects", [])
	for i in effects.size():
		var e: Dictionary = effects[i]
		if e["trigger"] != trigger and not (trigger in e.get("also", [])):
			continue
		# Saved Up: count the triggers and only fire on every third one.
		var every := int(e.get("every", 1))
		if every > 1:
			rune_counts[i] = int(rune_counts.get(i, 0)) + 1
			if int(rune_counts[i]) % every != 0:
				continue
		# (Twice on Weak Point is two marks from one firing, not two firings.)
		for n in (1 if e["id"] == "weak_point" else int(e["count"])):
			_queue_rune(i, game_time + n * REPEAT_GAP, float(e["size"]), hits, float(e.get("power", 1.0)))


## held: one turn of a hold rune (it follows the spin, and only the first turn is named).
func _queue_rune(effect: int, at: float, size: float, hits: Array, power := 1.0, held := false) -> void:
	var id: String = weapon["effects"][effect]["id"]
	for q in rune_queue:
		if q["effect"] != effect and weapon["effects"][q["effect"]]["id"] == id and absf(float(q["at"]) - at) < 0.03 and q["held"] == held:
			q["size"] = minf(maxf(float(q["size"]), size) * 1.3, SwingBuild.MAX_SIZE)
			q["power"] = float(q["power"]) + power
			q["merged"].append(effect)
			return
	rune_queue.append({"at": at, "effect": effect, "size": size, "power": power, "hits": hits.duplicate(), "merged": [], "held": held})


func _run_rune_queue() -> void:
	var due: Array = []
	for q in rune_queue:
		if float(q["at"]) <= game_time:
			due.append(q)
	for q in due:
		rune_queue.erase(q)
		_fire_rune(q)


## Called by main whenever an enemy dies.
func on_kill(where: Vector2 = Vector2.INF) -> void:
	last_kill_pos = where if where != Vector2.INF else global_position
	_trigger("kill", [])


func _flash_effect(effect: int) -> void:
	var e: Dictionary = weapon["effects"][effect]
	slot_flash[int(e["slot"])] = game_time
	for s in e["band_slots"] + e.get("relayed", []):
		slot_flash[int(s)] = game_time
		var spark := _strip("band_spark", _slot_world(int(s)))
		if spark != null:
			spark.follow = self
			spark.follow_offset = spark.global_position - global_position


## Shockwave is a light hit that shoves (Darren, 10 November: a strong wave would
## have everyone fighting from range). It was 1.1 times the blade's damage.
const SHOCKWAVE_DAMAGE := 0.4
const HOOK_DAMAGE := 0.3
const HOOK_STUN := 0.5          # long enough to land a swing on what you pulled in
const WHIRLWIND_DAMAGE := 0.9   # for each turn


func _fire_rune(q: Dictionary) -> void:
	var effect: int = q["effect"]
	if effect >= weapon.get("effects", []).size():
		return
	_flash_effect(effect)
	for m in q["merged"]:
		_flash_effect(m)
	var id: String = weapon["effects"][effect]["id"]
	var size: float = q["size"]
	var power: float = q["power"]
	var col: Color = SwingBuild.FITTINGS[id]["color"]
	var dmg := float(weapon.get("damage", 8.0))
	match id:
		"shockwave":
			var w := RuneFx.new()
			w.kind = "wave"
			w.dir = aim_dir
			w.size = size
			w.color = col
			w.damage = dmg * SHOCKWAVE_DAMAGE * power
			w.knock = 380.0 * size
			_fx_root().add_child(w)
			w.global_position = global_position + aim_dir * 30.0
			_strip("shockwave_burst", global_position + aim_dir * 40.0, 0.0, size)
			shake = maxf(shake, 9.0 * size)
			Sfx.play(self, "shockwave", -2.0, 1.0 / sqrt(size))
		"hook":
			var reach := 260.0 * size
			var ring := RuneFx.new()
			ring.kind = "ring"
			ring.size = reach
			ring.color = col
			ring.life = 0.3
			_fx_root().add_child(ring)
			ring.global_position = global_position
			var tip := _tip_world()
			for e in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(e) or e.dead:
					continue
				var rel: Vector2 = global_position - e.global_position
				var d := rel.length()
				if d > reach + e.radius or d < 40.0:
					continue
				var pull := sqrt(2.0 * 1300.0 * maxf(d - 45.0, 0.0))
				e.take_hit(dmg * HOOK_DAMAGE * power, rel / d, 0.0, false, col)
				e.knock = rel / d * pull * e.knock_resist
				e.apply_stun(HOOK_STUN)
				var chain := RuneFx.new()
				chain.kind = "chain"
				chain.from_node = self
				chain.from_offset = tip - global_position
				chain.to_node = e
				chain.color = col
				chain.life = 0.4
				_fx_root().add_child(chain)
				_strip("hook_snag", e.global_position)
				var yank := _strip("hook_yank", e.global_position, (rel / d).angle())
				if yank != null:
					yank.follow = e
					yank.life = 0.35
			Sfx.play(self, "hook", -4.0)
		"shards":
			# From each hit enemy (or from you, on a dodge), metal shards jump to the
			# closest enemy, then on to the next closest.
			var starts: Array = []
			for h in q["hits"]:
				if is_instance_valid(h):
					starts.append(h)
			if starts.is_empty():
				starts.append(self)
			var splinter: bool = weapon["effects"][effect].get("splinter", false)
			for s in starts:
				_shards(s, size, power, dmg, col, splinter)
			Sfx.play(self, "cleave", -6.0, 1.2)
		"leap":
			if not _leap(size, power, col):
				return
		"weak_point":
			var count: int = int(weapon["effects"][effect]["count"]) + (q["merged"] as Array).size()
			if not _weak_point(q["hits"], count, size, power, col):
				return
		"whirlwind":
			# One full turn. Held on its button, each turn starts where the spin began
			# and turns the same way; fired by a band (Every Hit, On Dodge) it starts
			# at the aim. A held turn shoves less, so enemies stay inside the spin.
			var held: bool = q.get("held", false)
			var start := Vector2.RIGHT.rotated(hold_angle) if held else aim_dir
			var side := hold_side if held else -swing_side
			var w := RuneFx.new()
			w.kind = "spin"
			w.dir = start
			w.spin_side = side
			w.size = 78.0 * float(weapon.get("reach", 1.0)) * size
			w.life = hold_turn if held else 0.26
			w.color = col
			w.damage = dmg * WHIRLWIND_DAMAGE * power
			w.knock = 300.0 * size * (HOLD_KNOCK if held else 1.0)
			w.from_node = self
			var spin := _strip("whirlwind_spin", global_position, start.angle(), w.size / (36.0 * Art.PIXEL))
			if spin != null:
				spin.follow = self
				spin.fps = float(spin.frames) / w.life   # the strip takes exactly one turn
				# Mirrored, the strip would start behind you: turn it half round so it
				# starts at the aim, the same place the hits start.
				spin.flip = side < 0.0
				if spin.flip:
					spin.angle += PI
				w.drawn = false
			_fx_root().add_child(w)
			w.global_position = global_position
			if held:
				hold_fx = [w, spin]
			shake = maxf(shake, (3.5 if held and hold_turns > 1 else 7.0) * size)
			Sfx.play(self, "cleave", -4.0 if not held or hold_turns <= 1 else -9.0, 0.8 if not held else 0.8 + 0.06 * minf(float(hold_turns), 6.0))
			if held and hold_turns > 1:
				return   # only the first turn of a hold is named
	# Name what fired above the player, so it's obvious which rune did what.
	if id == "weak_point":
		_label("MARKED", col)
	else:
		_label(str(SwingBuild.FITTINGS[id]["name"]).to_upper() + ("!" if power <= 1.0 else " x%s!" % str(snappedf(power, 0.5)).trim_suffix(".0")), col)


# --- Active runes ---------------------------------------------------------------

func _abilities() -> Array:
	return weapon.get("abilities", [])


## How full a button's meter must be to use its rune: all of it for a press rune,
## one turn's worth for a hold rune.
func ability_cost(b: int) -> float:
	var list := _abilities()
	if b >= list.size():
		return 1.0
	return 1.0 / maxf(float(list[b]["turns"]), 1.0) if list[b]["use"] == "hold" else 1.0


func ability_ready(b: int) -> bool:
	return b < _abilities().size() and float(ability_charge[b]) >= ability_cost(b) - 0.0001


## The meters fill back up (not the one whose rune is going, and a hold rune's
## only after a short wait).
func _refill_abilities(delta: float) -> void:
	var list := _abilities()
	for b in ability_charge.size():
		if b >= list.size():
			ability_charge[b] = 1.0
			ability_wait[b] = 0.0
		elif b != hold_button:
			ability_wait[b] = maxf(float(ability_wait[b]) - delta, 0.0)
			if float(ability_wait[b]) <= 0.0:
				ability_charge[b] = minf(float(ability_charge[b]) + delta / float(list[b]["recharge"]), 1.0)


func _update_abilities(delta: float) -> void:
	var list := _abilities()
	_refill_abilities(delta)
	# The turn that's going: when it ends, the next one starts if the button is
	# still down and there's meter for it.
	if hold_button >= 0:
		if hold_button >= list.size() or frozen or dodge_timer > 0.0 or not armed():
			_stop_hold(true)
		else:
			hold_left -= delta
			if hold_left <= 0.0:
				if input.ability_held[hold_button] and ability_ready(hold_button):
					_start_turn(hold_button)
				else:
					_stop_hold(false)
	if frozen or not armed() or dodge_timer > 0.0:
		return
	for b in mini(list.size(), ability_charge.size()):
		if not input.ability_pressed[b] or hold_button == b:
			continue
		if not ability_ready(b):
			ability_denied[b] = game_time
			Sfx.play(self, "dodge", -20.0, 0.6)
			continue
		var a: Dictionary = list[b]
		if a["use"] == "hold":
			# Starting a spin drops the swing you were in the middle of.
			_stop_hold(true)
			_reset_combo()
			hit_pause = 0.0
			hold_angle = aim_dir.angle()
			hold_side = -swing_side
			hold_turns = 0
			_start_turn(b)
		else:
			ability_charge[b] = 0.0
			ability_used[b] = game_time
			for i in a["effects"]:
				var e: Dictionary = weapon["effects"][i]
				# (One leap has to land before the next one sets off.)
				var gap := LEAP_TIME + 0.12 if e["id"] == "leap" else REPEAT_GAP
				for n in int(e["count"]):
					_queue_rune(i, game_time + n * gap, float(e["size"]), [], float(e.get("power", 1.0)))


## Every Hit on an active rune (Darren, 11 November): a swing that lands takes a
## bit off that rune's recharge. One swing counts once, however many enemies it
## catches, so a crowd doesn't hand the ability straight back.
func _hit_refund() -> void:
	var list := _abilities()
	for b in mini(list.size(), ability_charge.size()):
		var seconds := float(list[b].get("refund", 0.0))
		if seconds <= 0.0 or b == hold_button or float(ability_charge[b]) >= 1.0:
			continue
		ability_charge[b] = minf(float(ability_charge[b]) + seconds / float(list[b]["recharge"]), 1.0)
		ability_refunded[b] = game_time


## One more turn of a hold rune: spends a turn's worth of meter and fires its runes once.
func _start_turn(b: int) -> void:
	var a: Dictionary = _abilities()[b]
	ability_charge[b] = maxf(float(ability_charge[b]) - ability_cost(b), 0.0)
	ability_used[b] = game_time
	hold_button = b
	hold_turn = maxf(float(a["turn"]), 0.05)
	hold_left += hold_turn
	hold_turns += 1
	hold_fx = []
	for i in a["effects"]:
		var e: Dictionary = weapon["effects"][i]
		_queue_rune(i, game_time, float(e["size"]), [], float(e.get("power", 1.0)), true)
	_run_rune_queue()   # this tick, so the blade and the body turn together


## Ends a hold rune. cut: it was stopped mid-turn (a dodge, a knock-out, a new
## sword), so what that turn put on screen goes too.
func _stop_hold(cut: bool) -> void:
	if hold_button < 0:
		return
	ability_wait[hold_button] = ABILITY_WAIT
	hold_button = -1
	hold_left = 0.0
	hold_turns = 0
	if cut:
		for n in hold_fx:
			if is_instance_valid(n):
				n.queue_free()
	hold_fx = []
	# The sword eases back to rest from wherever the spin left it.
	return_from = [pose_angle, pose_hand]
	return_t = RETURN_TIME


## Which way the spin points right now, as an angle.
func _hold_angle_now() -> float:
	return hold_angle + hold_side * TAU * clampf(1.0 - hold_left / hold_turn, 0.0, 1.0)


## Shards: a chain of metal shards from `from` to the closest enemy, then the next.
## Each jump takes SHARD_FLIGHT; the hit lands when the shard arrives. Counted in
## game ticks (not a timer), so it lands on the same tick on every computer.
const SHARD_JUMPS := 2
const SHARD_RANGE := 130.0
var shard_queue: Array = []   # shards in the air: [{at, next, fronts, hit, jumps, size, power, dmg, col, splinter}]

func _shards(from: Node2D, size: float, power: float, dmg: float, col: Color, splinter := false) -> void:
	_shard_jump({"fronts": [from], "hit": {from.get_instance_id(): true}, "jumps": SHARD_JUMPS,
		"size": size, "power": power, "dmg": dmg, "col": col, "splinter": splinter})


## Sends the shards on from where they are now to the closest enemies not hit yet.
func _shard_jump(s: Dictionary) -> void:
	if int(s["jumps"]) <= 0:
		return
	var next: Array = []
	for current in s["fronts"]:
		if not is_instance_valid(current):
			continue
		# Every Hit on Shards: each shard splinters in two as it jumps.
		for k in (2 if s["splinter"] else 1):
			var best = _closest_enemy(current.global_position, SHARD_RANGE * float(s["size"]), s["hit"])
			if best == null:
				break
			s["hit"][best.get_instance_id()] = true
			_shard_fly(current.global_position, best.global_position, s["col"])
			next.append(best)
	if next.is_empty():
		return
	s["next"] = next
	s["jumps"] = int(s["jumps"]) - 1
	s["at"] = game_time + SHARD_FLIGHT
	shard_queue.append(s)


## Lands the shards that have arrived, and sends them on.
func _run_shards() -> void:
	var due: Array = []
	for s in shard_queue:
		if float(s["at"]) <= game_time:
			due.append(s)
	for s in due:
		shard_queue.erase(s)
		for e in s["next"]:
			if not is_instance_valid(e) or e.dead:
				continue
			var dir: Vector2 = (e.global_position - global_position).normalized()
			e.take_hit(float(s["dmg"]) * 0.6 * float(s["power"]), dir, 140.0, false, s["col"])
			if _strip("shards_hit", e.global_position, 0.0, float(s["size"])) == null:
				_strip("cleave_echo", e.global_position, 0.0, float(s["size"]))
		s["fronts"] = s["next"]
		_shard_jump(s)


const SHARD_FLIGHT := 0.09


func _closest_enemy(from: Vector2, range_px: float, skip: Dictionary):
	var best = null
	var best_d := range_px
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or skip.has(e.get_instance_id()):
			continue
		var d: float = e.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = e
	return best


## A spinning shard sprite flying from a to b (a plain streak if the art is missing).
func _shard_fly(a: Vector2, b: Vector2, col: Color) -> void:
	var shard := _strip("shards_shard", a)
	if shard != null:
		shard.life = SHARD_FLIGHT
		shard.velocity = (b - a) / SHARD_FLIGHT
		return
	var line := Fx.new()
	line.kind = "chain"
	line.to = b - a
	line.color = col
	line.life = 0.16
	_fx_root().add_child(line)
	line.global_position = a


## Leap: jump to an enemy and land at the blade's full reach from it, striking as
## you land. It picks the nearest enemy near your aim, or else the nearest one,
## and not one already leapt to in this burst if there is another (Twice). With nobody in range it
## jumps a short way where you aim. Returns false if it couldn't go at all.
func _leap(size: float, power: float, col: Color) -> bool:
	if is_down or frozen:
		return false
	if game_time - leap_burst > 1.0:
		leap_targets.clear()
	leap_burst = game_time
	var best = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.immune:
			continue
		var rel: Vector2 = e.global_position - global_position
		var d := rel.length()
		if d > LEAP_RANGE * size + float(e.radius):
			continue
		# Someone new beats someone already leapt to in this burst; anyone near the
		# aim beats anyone who isn't; then the nearest.
		var score := d + (0.0 if absf(aim_dir.angle_to(rel)) <= LEAP_AIM else 1000.0) + (5000.0 if e in leap_targets else 0.0)
		if score < best_score:
			best_score = score
			best = e
	var dir := aim_dir
	var travel := LEAP_EMPTY
	if best != null:
		leap_targets.append(best)
		var rel: Vector2 = best.global_position - global_position
		if rel.length() > 0.5:
			dir = rel.normalized()
		# Land so the enemy sits just inside the blade's reach. Already closer than
		# that: hop back out to it.
		var stand := _hit_reach() + float(best.radius) - 12.0
		travel = rel.length() - stand
	_stop_hold(true)
	_reset_combo()
	hit_pause = 0.0
	dodge_timer = 0.0  # a Leap on a dodge takes over the dodge
	# A whole number of ticks, so the jump covers exactly the distance.
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var ticks := maxi(roundi(LEAP_TIME / tick), 1)
	lunge_dir = dir * signf(travel) if travel != 0.0 else dir
	lunge_timer = (float(ticks) - 0.5) * tick
	lunge_speed = absf(travel) / (float(ticks) * tick)
	aim_dir = dir
	face_dir = dir
	invuln = maxf(invuln, LEAP_TIME + 0.1)
	leap_landing = {"at": game_time + (float(ticks) - 0.5) * tick, "dir": dir, "size": size, "power": power, "col": col, "hit": best != null}
	var trail := _strip("leap_trail", global_position, lunge_dir.angle(), size)
	if trail != null:
		trail.follow = self
	_dust(global_position + FEET)
	Sfx.play(self, "dodge", -8.0, 1.3)
	return true


## The strike at the end of a Leap: one cut in front of you at the blade's reach.
func _run_leap() -> void:
	if leap_landing.is_empty() or game_time < float(leap_landing["at"]):
		return
	var l := leap_landing
	leap_landing = {}
	var dir: Vector2 = l["dir"]
	var size: float = l["size"]
	var col: Color = l["col"]
	_strip("leap_land", global_position + FEET, 0.0, size)
	shake = maxf(shake, 5.0)
	Sfx.play(self, "cleave", -6.0, 1.3)
	if is_down or not l["hit"]:
		return
	var reach := _hit_reach() * (1.0 + 0.25 * (size - 1.0))
	var half_arc := deg_to_rad(70.0)
	var dmg := float(weapon.get("damage", 8.0)) * LEAP_DAMAGE * float(l["power"])
	var struck := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - global_position
		if rel.length() <= reach + float(e.radius) and (rel.length() < float(e.radius) + RADIUS or absf(dir.angle_to(rel)) <= half_arc):
			e.take_hit(dmg, dir, 160.0, false, col, LEAP_STUN, 0.06)
			e.apply_stun(LEAP_STUN)
			Art.play_piece(self, "hit_spark", e.global_position - dir * float(e.radius) * 0.4, dir.angle())
			struck += 1
	# The cut shows as a swing: the sword snaps across in front of you.
	if current_step < 0:
		anim_dir = dir
		anim_move = "slash"
		swing_side = 1.0
		_start_smear()
		return_from = [dir.angle() + 0.9, _hand_point()]
		return_t = RETURN_TIME
	if struck > 0:
		shake = maxf(shake, 8.0)
		Sfx.play(self, "hit", -6.0)


## How far a swing reaches from the player's centre (see _do_move).
func _hit_reach() -> float:
	return _reach_px() + REACH_MARGIN


# --- Weak Point -------------------------------------------------------------------

## Marks enemies: the ones the swing hit, nearest first, or (On Dodge, no hits) the
## enemy the dodge passes closest to. count: how many marks this player can have
## out at once (Twice: two). With marks to spare and one enemy, a big enemy gets a
## second spot. An enemy whose mark was struck by this very swing isn't marked
## again by it. Returns false if nothing was marked.
func _weak_point(hits: Array, count: int, size: float, power: float, col: Color) -> bool:
	var targets: Array = []
	for h in hits:
		if is_instance_valid(h) and not h.dead and not h.immune and h.weak_popped > 0.05:
			targets.append(h)
	if hits.is_empty() and game_time - dodge_started < 0.05:
		var passed = _dodge_passes()
		if passed != null:
			targets.append(passed)
	if targets.is_empty():
		return false
	targets.sort_custom(func(a, b): return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	count = clampi(count, 1, SwingBuild.MAX_COUNT)
	var placed := 0
	var slot := 0
	while placed < count and slot < count:
		var e = targets[slot % targets.size()]
		slot += 1
		var mine := 0
		for pair in weak_marks:
			if pair[0] == e:
				mine += 1
				pair[1]["left"] = e.WEAK_LIFE   # still there: it just lasts longer
		# One mark on a small enemy; a big one can carry a spot for each mark.
		if mine >= (count if e.weak_big() else 1):
			continue
		if slot > targets.size() and not e.weak_big():
			continue
		# The spot is never right in front of you: you have to step round to it.
		var from_enemy: Vector2 = global_position - e.global_position
		var turn := deg_to_rad(Sim.between(80.0, 140.0)) * (1.0 if Sim.chance() < 0.5 else -1.0)
		var m: Dictionary = e.add_weak_mark(index, power, size, from_enemy.angle() + turn)
		weak_marks.append([e, m])
		placed += 1
		Art.play_piece(self, "weak_mark_on", e.global_position + (e.weak_spot_drawn(m) if e.weak_big() else Vector2(0, -e.radius * 0.5)), 0.0, 1.5 if size > 1.0 else 1.0)
	# Only `count` marks at a time: the oldest go.
	_prune_marks()
	while weak_marks.size() > count:
		var old: Array = weak_marks.pop_front()
		if is_instance_valid(old[0]):
			old[0].weak_marks.erase(old[1])
	if placed > 0:
		Sfx.play(self, "hook", -10.0, 1.8)
	return placed > 0


## The enemy a dodge that starts now will pass closest to (null if none is near).
func _dodge_passes():
	var a := global_position
	var b := a + dodge_dir * DODGE_SPEED * DODGE_TIME
	var best = null
	var best_d := WEAK_DODGE_REACH
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.immune:
			continue
		var d: float = Geometry2D.get_closest_point_to_segment(e.global_position, a, b).distance_to(e.global_position) - float(e.radius)
		if d < best_d:
			best_d = d
			best = e
	return best


func _prune_marks() -> void:
	for pair in weak_marks.duplicate():
		if not is_instance_valid(pair[0]) or pair[0].dead or not (pair[1] in pair[0].weak_marks):
			weak_marks.erase(pair)


## A mark was struck (by anyone): its owner stops counting it.
func _forget_mark(mark: Dictionary) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		for pair in p.weak_marks.duplicate():
			if is_same(pair[1], mark):
				p.weak_marks.erase(pair)


func _clear_marks() -> void:
	for pair in weak_marks:
		if is_instance_valid(pair[0]):
			pair[0].weak_marks.erase(pair[1])
	weak_marks.clear()


## Plays one of the art's effect strips (art/swing/fx/) at a world position.
func _strip(name: String, where: Vector2, angle := 0.0, size := 1.0) -> Node2D:
	var info: Dictionary = SwordArt.data().get("fx", {}).get(name, {})
	var tex := Art.texture("swing/fx/%s.png" % name)
	if tex == null or info.is_empty():
		return null
	var n := SpriteOnce.new()
	n.texture = tex
	n.frames = int(info.get("frames", 1))
	n.fps = float(info.get("fps", 12))
	var o: Array = info.get("origin", [0, 0])
	n.origin = Vector2(o[0], o[1])
	n.angle = angle
	n.size = size
	n.additive = true
	_fx_root().add_child(n)
	n.global_position = where
	return n


## Rune effects go on their own layer above the lighting, so they stay bright.
var fx_parent: Node = null

func _fx_root() -> Node:
	return fx_parent if is_instance_valid(fx_parent) else get_parent()


func _label(text: String, col: Color) -> void:
	var l := RuneFx.new()
	l.kind = "text"
	l.text = text
	l.color = col
	l.life = 0.7
	_fx_root().add_child(l)
	l.global_position = global_position + Vector2(randf_range(-20, 20), -70)


# --- Elements ---------------------------------------------------------------

func _apply_elements(target, dmg: float) -> void:
	var elements: Array = weapon.get("elements", [])
	var combos: Array = weapon.get("combos", [])
	if "fire" in elements:
		target.apply_burn(maxf(1.0, dmg * 0.12), 2.5)
	if "water" in elements:
		target.apply_slow(0.45, 2.0)
	if "lightning" in elements:
		var electrified := "electrified" in combos
		_chain(target, dmg * 0.5, 3 if electrified else 1, electrified)
	if "steam" in combos:
		_steam(target, dmg * 0.4)


## Lightning jumps to the nearest enemy nearby. Electrified jumps further and stuns.
func _chain(from_enemy, dmg: float, jumps: int, stun: bool) -> void:
	var color_key := "electrified" if stun else "lightning"
	var col: Color = WeaponBuild.ELEMENT_COLORS[color_key]
	var hit_ids := {from_enemy.get_instance_id(): true}
	var current = from_enemy
	if stun and is_instance_valid(current) and not current.dead:
		current.apply_stun(0.35)
	for i in jumps:
		var best = null
		var best_d := 150.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead or hit_ids.has(e.get_instance_id()):
				continue
			var d: float = e.global_position.distance_to(current.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			return
		hit_ids[best.get_instance_id()] = true
		var line := Fx.new()
		line.kind = "chain"
		line.to = best.global_position - current.global_position
		line.color = col
		line.life = 0.18
		get_parent().add_child(line)
		line.global_position = current.global_position
		var dir: Vector2 = (best.global_position - current.global_position).normalized()
		best.take_hit(dmg, dir, 60.0, false, col)
		if stun:
			best.apply_stun(0.5)
		current = best


## Steam bursts around the target and scalds enemies next to it.
func _steam(target, dmg: float) -> void:
	var col: Color = WeaponBuild.ELEMENT_COLORS["steam"]
	var radius := 64.0 * (1.0 + float(weapon.get("area", 0.0)))
	var burst := Fx.new()
	burst.kind = "burst"
	burst.radius = radius
	burst.color = col
	burst.life = 0.3
	get_parent().add_child(burst)
	burst.global_position = target.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e == target:
			continue
		if e.global_position.distance_to(target.global_position) <= radius + e.radius:
			var dir: Vector2 = (e.global_position - target.global_position).normalized()
			e.take_hit(dmg, dir, 140.0, false, col)


# --- Taking damage ------------------------------------------------------------

## from: where the hit came from (you're knocked away from it).
func take_damage(amount: float, from: Vector2 = Vector2.INF) -> void:
	if invuln > 0.0 or is_down:
		return
	hp -= amount
	invuln = 0.8
	hurt_flash = 0.12
	shake = maxf(shake, 7.0)
	Sfx.play(self, "hurt", -5.0)
	var away := Vector2.UP
	if from != Vector2.INF and from.distance_to(global_position) > 0.5:
		away = (global_position - from).normalized()
		hurt_vel = away * 330.0
	Art.play_piece(self, "hurt_burst", global_position + Vector2(0, -8), away.angle())
	if hp <= 0.0:
		hp = 0.0
		_reset_combo()
		dodge_timer = 0.0
		if auto_respawn:
			hp = max_hp
			global_position = spawn_point
			hurt_vel = Vector2.ZERO
			reset_physics_interpolation()
			knocked_out_timer = 2.0
			invuln = 2.0
			if rig != null:
				rig.snap()
		else:
			is_down = true
			down_time = 0.0
			down_flip = face_dir.x < 0.0
		knocked_out.emit(self)


## Back on your feet (after a room is cleared, or a restart).
func get_up(at: Vector2 = Vector2.INF, hp_frac := 1.0) -> void:
	if is_down:
		rise_timer = 3.0 / 8.0
	is_down = false
	hp = maxf(hp, max_hp * hp_frac)
	invuln = 1.5
	hurt_vel = Vector2.ZERO
	walk_vel = Vector2.ZERO
	_reset_combo()
	if at != Vector2.INF:
		global_position = at
		reset_physics_interpolation()


func _process(delta: float) -> void:
	knocked_out_timer = maxf(knocked_out_timer - delta, 0.0)
	facing = _facing_of(face_dir)
	facing8 = _facing8_of(face_dir)
	# Behind the body when facing away, or when the hand is above the body's centre.
	weapon_group.show_behind_parent = facing8 in ["up", "up_left", "up_right", "left"]
	weapon_group.visible = not is_down and rise_timer <= 0.0
	anim_time += delta
	if is_down:
		down_time += delta
	rise_timer = maxf(rise_timer - delta, 0.0)
	_update_pose(delta)
	trail_layer.queue_redraw()
	# The outline is one game pixel: as many screen pixels as the window's scale.
	var scale_px := maxf(floorf(float(get_window().size.y) / 360.0), 1.0)
	(weapon_group.material as ShaderMaterial).set_shader_parameter("px", scale_px)
	queue_redraw()
	weapon_layer.queue_redraw()
	under_bright.queue_redraw()
	rim.queue_redraw()


## A puff of dust at the feet (dodging).
func _dust(where: Vector2) -> void:
	var tex := Art.texture("cave/dust_puff.png")
	if tex == null:
		return
	var n := SpriteOnce.new()
	n.texture = tex
	n.frames = 4
	n.fps = 14.0
	n.origin = Vector2(8, 10)
	get_parent().add_child(n)
	n.z_index = 0
	n.global_position = where


## The nearest of 8 directions. Diagonals cover the middle 45 degrees between axes.
static func _facing8_of(d: Vector2) -> String:
	var a := fposmod(d.angle(), TAU)
	var i := int(roundf(a / (PI / 4.0))) % 8
	return ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"][i]


static func _facing_of(d: Vector2) -> String:
	if absf(d.x) > absf(d.y):
		return "right" if d.x > 0.0 else "left"
	return "down" if d.y > 0.0 else "up"


# --- Drawing ------------------------------------------------------------------



func _draw() -> void:
	var blink := invuln > 0.0 and dodge_timer <= 0.0 and int(invuln * 20.0) % 2 == 0
	var b := _body_now()
	if not b.is_empty():
		var tint := Color.WHITE
		if b.get("grey", false):
			tint = Color(0.55, 0.55, 0.62)
		elif hurt_flash > 0.0:
			tint = Color(3.0, 1.2, 1.2)
		elif blink:
			tint = Color(2.0, 2.0, 2.0)
		draw_set_transform(b["at"], b["angle"], b["scale"])
		draw_texture_rect_region(b["tex"], Rect2(-_body_origin(), b["src"].size), b["src"], tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# Stand-in body: a circle with eyes showing which way it faces.
	var body := Color(1, 1, 1) if blink else color
	if dodge_timer > 0.0:
		body = color.lightened(0.4)
		body.a = 0.6
	draw_circle(Vector2.ZERO, RADIUS, body)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 28, color.darkened(0.45), 2.5)
	if facing != "up":
		var eye := Color(0.08, 0.1, 0.16)
		if facing == "down":
			draw_rect(Rect2(Vector2(-6, 2), Vector2(3, 5)), eye)
			draw_rect(Rect2(Vector2(3, 2), Vector2(3, 5)), eye)
		else:
			var x := 7.0 if facing == "right" else -10.0
			draw_rect(Rect2(Vector2(x, -3), Vector2(3, 5)), eye)


func _draw_shadow() -> void:
	if Art.draw_piece(under_lit, "shadow_m", 0, FEET):
		return
	under_lit.draw_set_transform(FEET, 0.0, Vector2(1.0, 0.45))
	under_lit.draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.3))
	under_lit.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Two players: a coloured ring under the feet says who is who.
func _draw_ring() -> void:
	if not show_marker:
		return
	var fade := Color(1, 1, 1, 0.45 if is_down else 1.0)
	if Art.draw_piece(under_bright, "ring_%s" % ("a" if index % 2 == 0 else "b"), 0, FEET, 0.0, false, fade):
		return
	var mc: Color = Art.PLAYER_COLORS[index % Art.PLAYER_COLORS.size()]
	mc.a = 0.45 if is_down else 0.9
	under_bright.draw_set_transform(FEET, 0.0, Vector2(1.0, 0.45))
	under_bright.draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 24, mc, 2.0)
	under_bright.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The thin lit edge along the top of the body (the strip's _glow image).
func _draw_rim() -> void:
	if note != "":
		var font := Art.font("Silkscreen-Regular")
		var at := Vector2(-80.0, -64.0)
		rim.draw_string_outline(font, at, note, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 16, 8, Color(0.06, 0.04, 0.09))
		rim.draw_string(font, at, note, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 16, Color("#ffc850"))
	var b := _body_now()
	if b.is_empty() or b["glow"] == null or hurt_flash > 0.0 or b.get("grey", false):
		return
	rim.draw_set_transform(b["at"], b["angle"], b["scale"])
	rim.draw_texture_rect_region(b["glow"], Rect2(-_body_origin(), b["src"].size), b["src"])
	rim.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## What the body looks like right now: {tex, glow, src, at, angle, scale}, or
## empty when there is no art for this character.
func _body_now() -> Dictionary:
	var anim := ""
	var frames := 1
	var frame := 0
	var mirrored := false
	if (is_down or rise_timer > 0.0) and Art.texture("body/%s_down.png" % character) != null:
		# Knocked out: reeling, hitting the floor, lying. Getting up is the same strip backwards.
		anim = "down"
		frames = 3
		frame = mini(int(down_time * 8.0), 2) if is_down else clampi(int(rise_timer * 8.0), 0, 2)
		mirrored = down_flip
	else:
		var strip := _body_strip()
		anim = strip[0]
		frames = int(strip[1])
		frame = int(strip[2])
		mirrored = strip[3]
	var rel := "body/%s_%s.png" % [character, anim]
	var tex := Art.texture(rel)
	if tex == null:
		return {}
	var fw := tex.get_width() / maxi(frames, 1)
	var out := {"tex": tex, "glow": Art.glow_texture(rel),
		"src": Rect2(float(posmod(frame, frames) * fw), 0.0, float(fw), float(tex.get_height()))}
	if is_down and anim != "down":
		# No knocked-out strip for this character: lying on their side, greyed.
		out["at"] = FEET + Vector2(-14, -8)
		out["angle"] = PI * 0.5
		out["scale"] = Vector2(Art.PIXEL, Art.PIXEL)
		out["grey"] = true
	else:
		out["at"] = FEET
		out["angle"] = lean
		out["scale"] = Vector2(Art.PIXEL * squash.x * (-1.0 if mirrored else 1.0), Art.PIXEL * squash.y)
	return out


## [animation name, frame count, current frame, mirrored] for the body sprite.
## Diagonals use the *_down_right / *_up_right strips (mirrored for the left side)
## when the art has them, otherwise the nearest of the 4 main directions.
func _body_strip() -> Array:
	var anim := "idle"
	var frame := 0
	var frames := 4
	if dodge_timer > 0.0:
		anim = "dodge"
		frames = 3
		frame = clampi(int((1.0 - dodge_timer / DODGE_TIME) * 3.0), 0, 2)
	elif is_down:
		frame = 0
	elif walk_vel.length() > 30.0 and hit_pause <= 0.0:
		# The legs keep pace with the ground: faster when running, slower when easing off.
		anim = "walk"
		frames = 6
		frame = int(walk_phase) % frames
	else:
		frame = int(anim_time * 6.0) % frames
	if "_" in facing8:
		var base := facing8.replace("left", "right")
		if Art.texture("body/%s_%s_%s.png" % [character, anim, base]) != null:
			return ["%s_%s" % [anim, base], frames, frame, facing8.ends_with("left")]
	return ["%s_%s" % [anim, facing], frames, frame, false]


func _body_data() -> Dictionary:
	var d: Dictionary = Art.json("body/%s.json" % character)
	return d if not d.is_empty() else Art.anchors().get("body", {})


func _body_origin() -> Vector2:
	var o: Array = _body_data().get("origin_feet", [28, 52])
	return Vector2(o[0], o[1])


## Where the hand is (the sword's pivot), relative to the player's centre.
func _hand_point() -> Vector2:
	var strip := _body_strip()
	var strips: Dictionary = _body_data().get("strips", {})
	var info: Dictionary = strips.get(strip[0], {})
	var hands: Array = info.get("hand", [])
	if hands.is_empty():
		return FEET + Vector2(0, -12)
	var h: Array = hands[posmod(int(strip[2]), hands.size())]
	var hx: float = float(h[0])
	if strip[3]:
		hx = float(_body_data().get("frame", [56, 56])[0]) - 1.0 - hx  # mirrored strip
	var off := (Vector2(hx, h[1]) - _body_origin()) * Art.PIXEL
	return FEET + off


# --- Weapon layer --------------------------------------------------------------
# The sword is assembled from the parts on the grid: each part is drawn on its
# own grid cells (5 art pixels per cell), the whole thing is rotated to point at
# the aim and held at the hand. The grid's top row is the tip.

## The sword's pose: [angle, hand position relative to the player's centre].
func _sword_pose() -> Array:
	return [pose_angle, pose_hand]


## How far the sword reaches from the hand, in world units, and what the smear
## shows. The broadsword reaches 73 (a little past the drawn blade: Darren, 7 Nov,
## drew the blades a third shorter to suit the small crew and kept the range). A
## shape's reach multiplies the whole hit range, margin and all, so a rapier hits
## at 1.4 times the distance a broadsword does.
const BASE_REACH := 73.0
const REACH_MARGIN := 18.0     # the hit lands this far past the smear

func _reach_px() -> float:
	return (BASE_REACH + REACH_MARGIN) * float(weapon.get("reach", 1.0)) - REACH_MARGIN


## Where the sword should be right now, during a swing. Returns [angle, hand, sweeping].
## Snappy, like comparable top-down games: hold the wind-up, jump across in ~30 ms
## (the sword is hidden and a crescent smear shows the arc), hold the end, ease to rest.
## The hand moves on a short arc round the body's centre, sword pointing outward.
const SWING_PIVOT := Vector2(0, -14)
const SWING_RADIUS := 9.0
const SWEEP_TIME := 0.03

## The move being swung (or the last one).
func _move_info() -> Dictionary:
	return MOVES.get(anim_move, MOVES["slash"])


## A thrust goes straight out along the aim instead of round in an arc.
static func _is_thrust(curve: Array) -> bool:
	return absf(float(curve[1]) - float(curve[0])) < 0.05


func _swing_times() -> Array:
	var info := _move_info()
	var hit_at := float(info["windup"]) / _speed()
	var sweep_start := maxf(hit_at - SWEEP_TIME * 0.5, 0.0)
	return [sweep_start, sweep_start + SWEEP_TIME]


func _attack_pose() -> Array:
	var curve: Array = _move_info()["curve"]
	var side := swing_side
	var times := _swing_times()
	var sweep_start: float = times[0]
	var sweep_end: float = times[1]
	var start_a: float = float(curve[0]) * side
	var end_a: float = float(curve[1]) * side
	var thrust := _is_thrust(curve)
	var te := step_elapsed
	var rel := end_a
	var radius := SWING_RADIUS
	var sweeping := false
	if te < sweep_start:
		# Wind up: get to the start pose quickly, then hold it.
		var k := clampf(te / maxf(sweep_start * 0.4, 0.001), 0.0, 1.0)
		rel = lerp_angle(pose_from_angle, start_a, k)
		radius = SWING_RADIUS * (0.4 if thrust else 1.0)
	elif te < sweep_end:
		var k := (te - sweep_start) / SWEEP_TIME
		rel = lerpf(start_a, end_a, k)
		radius = SWING_RADIUS * (lerpf(0.4, 1.6, k) if thrust else 1.0)
		sweeping = true
	else:
		radius = SWING_RADIUS * (1.6 if thrust else 1.0)
	var angle := anim_dir.angle() + rel
	# The sword stays in his right hand: the hand only reaches a little toward the swing.
	var hand := _hand_point() + Vector2.RIGHT.rotated(angle) * (radius - SWING_RADIUS + 3.0)
	# The end pose is held while the chain keeps going (the next swing starts from
	# it). If no next swing is coming, it eases back to the resting pose.
	if settle > 0.0:
		var r := _rest_pose()
		var e := settle * settle * (3.0 - 2.0 * settle)
		angle = lerp_angle(angle, r[0], e)
		hand = hand.lerp(r[1], e)
	return [angle, hand, sweeping]


## Ready stance: the sword held up just in front of him, always in his right hand
## (the body sprite's hand anchor), by facing (not the mouse). Angle: -PI/2 = up.
## Facing down his right hand is on screen-left; facing up it is on screen-right;
## facing left it is on his far side, so the sword is drawn behind him.
const READY_ANGLE := {"right": -0.85, "left": -(PI - 0.85), "down": -1.85, "up": -1.3,
	"down_right": -1.5, "down_left": -(PI - 1.5), "up_right": -1.1, "up_left": -(PI - 1.1)}

func _rest_pose() -> Array:
	return [READY_ANGLE.get(facing8, READY_ANGLE.get(facing, -1.85)), _hand_point()]


func _update_pose(delta: float) -> void:
	if hold_button >= 0:
		# Spinning: the sword is held straight out and goes round with the body.
		var a := _hold_angle_now()
		pose_angle = a
		pose_hand = _hand_point() + Vector2.RIGHT.rotated(a) * 4.0
		lean = lerpf(lean, 0.0, 1.0 - exp(-12.0 * delta))
	elif current_step >= 0:
		# Settle only when nothing is queued and the button is up.
		var chaining := queued or (input.attack_held and not need_release)
		if step_elapsed > float(_swing_times()[1]) + 0.065 and not chaining and hit_pause <= 0.0:
			settle = minf(settle + delta / 0.13, 1.0)
		elif chaining:
			settle = maxf(settle - delta / 0.05, 0.0)
		var p := _attack_pose()
		pose_angle = p[0]
		pose_hand = p[1]
		if p[2] or (smear_t0 < 0.0 and step_elapsed >= float(_swing_times()[1]) and not stepped):
			if smear_t0 < 0.0 or not stepped:
				_start_smear()
			if not stepped:
				# No step forward: swinging never moves you (it pushed you into enemies).
				stepped = true
				squash = Vector2(0.9, 1.1) if _move_info().get("big", false) else Vector2(0.95, 1.06)
		elif step_elapsed < float(_move_info()["windup"]) / _speed():
			# Wind up: crouch into it.
			squash = squash.lerp(Vector2(1.1, 0.9) if _move_info().get("big", false) else Vector2(1.04, 0.96), 1.0 - exp(-30.0 * delta))
	else:
		# At rest the sword snaps to its place (no spinning round when you turn).
		# Straight after a swing it eases there from where the swing ended.
		var r := _rest_pose()
		pose_angle = r[0]
		pose_hand = r[1]
		if return_t > 0.0:
			return_t = maxf(return_t - delta, 0.0)
			var k := return_t / RETURN_TIME
			k = k * k
			pose_angle = lerp_angle(r[0], float(return_from[0]), k)
			pose_hand = (r[1] as Vector2).lerp(return_from[1], k)
		lean = lerpf(lean, 0.0, 1.0 - exp(-12.0 * delta))
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-12.0 * delta))



## The swing's smear: one solid crescent over the whole arc, brightest at the
## leading edge, fading out over ~100 ms.
var smear_t0 := -1.0
var smear_a0 := 0.0
var smear_a1 := 0.0
var smear_center := Vector2.ZERO
var smear_dir := 0.0          # the swing's direction, as an angle
var smear_side := 1.0         # -1: the back-hand slash, mirrored
var smear_move := "slash"
const SMEAR_LIFE := 0.1

func _start_smear() -> void:
	var curve: Array = _move_info()["curve"]
	var side := swing_side
	smear_t0 = game_time
	smear_a0 = anim_dir.angle() + float(curve[0]) * side
	smear_a1 = anim_dir.angle() + float(curve[1]) * side
	smear_center = _hand_point()
	smear_dir = anim_dir.angle()
	smear_side = side
	smear_move = anim_move


func _draw_trail() -> void:
	if smear_t0 < 0.0 or not weapon.has("blade"):
		return
	var age := (game_time - smear_t0) / SMEAR_LIFE
	if age >= 1.0:
		return
	var info: Dictionary = MOVES.get(smear_move, MOVES["slash"])
	var length_px := _reach_px() * float(info.get("reach", 1.0))
	var r_in := 3.0 + length_px * 0.45
	var r_out := 3.0 + length_px
	var thrust := absf(smear_a1 - smear_a0) < 0.05
	var piece := str(info.get("smear", "slash_smear"))
	if Art.piece_texture(piece) != null:
		# The art reaches 40 px from the hand: scale it to this blade. A swing the
		# other way is the same picture mirrored across the aim (flipped left to
		# right, then turned half round). A thrust is a straight streak, never mirrored.
		var n := int(Art.piece(piece).get("frames", 4))
		var frame := mini(int(age * n), n - 1)
		if thrust:
			# A streak from the hand to where the thrust lands: stretched along its
			# length to the blade's reach, but kept thin, so a rapier's is a long
			# needle and not a fat bar.
			var tex := Art.piece_texture(piece)
			var o: Array = Art.piece(piece).get("origin", [48, 48])
			var fw := float(tex.get_width()) / n
			var along := (r_out + REACH_MARGIN) / 40.0
			var across := clampf(along, 1.6, 2.0) * (1.3 if info.get("big", false) else 1.0)
			trail_layer.draw_set_transform(smear_center, smear_dir, Vector2(along, across))
			trail_layer.draw_texture_rect_region(tex, Rect2(-float(o[0]), -float(o[1]), fw, tex.get_height()), Rect2(frame * fw, 0, fw, tex.get_height()))
			trail_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		var back := smear_side < 0.0
		Art.draw_piece(trail_layer, piece, frame, smear_center,
			smear_dir + (PI if back else 0.0), back, Color.WHITE, Art.PIXEL * r_out / 80.0)
		return
	var col: Color = weapon.get("hit_color", Color.WHITE).lerp(Color(0.8, 0.9, 1.0), 0.5)
	var fade := 1.0 - age
	if thrust:
		# A thrust: a straight streak along the blade instead of an arc.
		var d := Vector2.RIGHT.rotated(smear_a0)
		var n := d.orthogonal() * 4.0
		var c := smear_center
		draw_colored_polygon_on(trail_layer, PackedVector2Array([c + d * r_in - n, c + d * (r_out + 10.0) - n, c + d * (r_out + 10.0) + n, c + d * r_in + n]), Color(col.r, col.g, col.b, 0.8 * fade))
		return
	var steps := 16
	for i in steps:
		var s0 := float(i) / steps
		var s1 := float(i + 1) / steps
		var a0 := lerpf(smear_a0, smear_a1, s0)
		var a1 := lerpf(smear_a0, smear_a1, s1)
		var d0 := Vector2.RIGHT.rotated(a0)
		var d1 := Vector2.RIGHT.rotated(a1)
		# Thin at the trailing end, full width and opaque at the leading edge.
		var w0 := lerpf(r_out - 4.0, r_in, s0)
		var w1 := lerpf(r_out - 4.0, r_in, s1)
		var alpha := (0.15 + 0.85 * s1 * s1) * fade
		var c := smear_center
		draw_colored_polygon_on(trail_layer, PackedVector2Array([c + d0 * w0, c + d0 * r_out, c + d1 * r_out, c + d1 * w1]), Color(col.r, col.g, col.b, alpha))


func draw_colored_polygon_on(ci: CanvasItem, pts: PackedVector2Array, c: Color) -> void:
	# Long sweeps can make the quad cross itself; split it into two triangles.
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2]]), c)
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[2], pts[3]]), c)


func _draw_weapon() -> void:
	if not weapon.has("blade"):
		# Empty-handed: just the fist at the side.
		var bare := Art.texture("body/hand.png")
		if bare != null:
			weapon_layer.draw_set_transform(_hand_point(), 0.0, Vector2(Art.PIXEL, Art.PIXEL))
			weapon_layer.draw_texture(bare, -bare.get_size() * 0.5)
			weapon_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var pose := _sword_pose()
	var angle: float = pose[0]
	var hand: Vector2 = pose[1]
	# Mid-sweep the sword is hidden: the smear shows the swing (reads as a fast blur).
	var hidden := false
	if current_step >= 0:
		var times := _swing_times()
		hidden = step_elapsed >= float(times[0]) and step_elapsed < float(times[1])
	if not hidden:
		# Art space: x right, y down, tip at the top. Rotate so "up" points along d.
		weapon_layer.draw_set_transform(hand, angle + PI * 0.5, Vector2(Art.PIXEL, Art.PIXEL))
		var blade: String = weapon["blade"]
		var grip: String = weapon["grip"]
		SwordArt.draw(weapon_layer, blade, grip, weapon["line"], "hand", _slot_glow(), -SwordArt.pivot(blade, grip, "hand"), Color.WHITE,
			str(weapon.get("pommel", "plain_pommel")), SwordArt.one_edged(blade) and _edge_flipped(angle))
	# The fist sits on the grip but is drawn upright, never spun with the sword.
	var fist := Art.texture("body/hand.png")
	if fist != null:
		weapon_layer.draw_set_transform(hand, 0.0, Vector2(Art.PIXEL, Art.PIXEL))
		weapon_layer.draw_texture(fist, -fist.get_size() * 0.5)
	weapon_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A one-edged blade (sabre, falchion) is drawn with its edge on the left of the
## picture, which is the anticlockwise side of the sword in the hand. Mid-swing
## the edge leads the cut; at rest it faces away from the body.
func _edge_flipped(angle: float) -> bool:
	if current_step >= 0 and not _is_thrust(_move_info()["curve"]):
		return swing_side > 0.0   # a clockwise cut: the edge goes on the other side
	return cos(angle) > 0.0


## How lit each slot is: a rune firing (and its bands), or the swing passing up the sword.
func _slot_glow() -> Dictionary:
	var lit := {}
	for s in slot_flash:
		var since := game_time - float(slot_flash[s])
		if since >= 0.0 and since < 0.45:
			lit[s] = 1.0 - since / 0.45
	for s in sweep_flash:
		var since := game_time - float(sweep_flash[s])
		if since >= 0.0 and since < 0.1:
			lit[s] = maxf(float(lit.get(s, 0.0)), 1.0)
	return lit


## A slot's position in the world, following the sword in hand.
func _slot_world(i: int) -> Vector2:
	var pose := _sword_pose()
	var angle: float = pose[0]
	var hand: Vector2 = pose[1]
	var blade: String = weapon["blade"]
	var grip: String = weapon["grip"]
	var local := (SwordArt.slot_center(blade, grip, "hand", i) - SwordArt.pivot(blade, grip, "hand")) * Art.PIXEL
	return global_position + hand + local.rotated(angle + PI * 0.5)


## The sword's tip in the world.
func _tip_world() -> Vector2:
	var pose := _sword_pose()
	var d := Vector2.RIGHT.rotated(float(pose[0]))
	var blade: String = weapon.get("blade", "iron_broadsword")
	var grip: String = weapon.get("grip", "wooden_grip")
	var length_px := SwordArt.pivot(blade, grip, "hand").y * Art.PIXEL
	return global_position + pose[1] + d * length_px
