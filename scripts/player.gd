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
const BowArt := preload("res://scripts/weapon/bow_art.gd")
const Arrow := preload("res://scripts/arrow.gd")
const RuneFx := preload("res://scripts/fx/rune_fx.gd")
const Sfx := preload("res://scripts/sfx.gd")
const SpriteOnce := preload("res://scripts/fx/sprite_once.gd")
const ForgeSpirit := preload("res://scripts/fx/forge_spirit.gd")
const PlayerInput := preload("res://scripts/player_input.gd")
const Sim := preload("res://scripts/sim.gd")

static var MOVE_SPEED := 220.0      # about 3.7 body heights a second, like Core Keeper
const ACCEL := 3000.0          # full speed in about 4 frames
const DECEL := 4200.0          # stops in about 3
const TURN := 5200.0           # reversing is quicker than starting
const FACE_LINGER := 0.28      # keep facing the swing this long after it ends
const DIAGONAL_GRACE := 0.07   # letting go of two keys a moment apart still ends on the diagonal
const RADIUS := 16.0
const COMBO_WINDOW := 0.5      # stop attacking this long and the combo resets
const FINISHER_RECOVERY := 0.1   # short pause after the finisher, so holding keeps a steady beat

static var DODGE_SPEED := 620.0
static var DODGE_TIME := 0.15
static var DODGE_MAX_CHARGES := 1
static var DODGE_REFILL := 0.8      # seconds per charge

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
static var MOVES := {
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
	# Bow shots (14 November). "windup" is the draw: the arrow leaves as it ends,
	# towards wherever you are aiming at that moment, and the rest of the move is
	# reaching for the next arrow. Same times as the sword's light and heavy moves,
	# so a bow's damage a second is its damage times its speed too.
	#   flight  this arrow's speed (1.0 = the bow's)
	"quick_shot": {"windup": 0.13, "time": LIGHT, "shape": "shot", "power": 1.0, "knock": 130.0, "stun": 0.1, "freeze": 0.03,
		"curve": [0.0, 0.0, 4.0, 22.0]},
	"heavy_shot": {"windup": 0.22, "time": HEAVY, "shape": "shot", "power": 1.5, "knock": 300.0, "stun": 0.25, "freeze": 0.08, "shake": 6.0,
		"curve": [0.0, 0.0, 4.0, 22.0], "big": true, "flight": 1.15},
	# The longbow's only move: a long draw, a fast arrow and a hard shove.
	"long_shot": {"windup": 0.25, "time": HEAVY, "shape": "shot", "power": 1.5, "knock": 340.0, "stun": 0.3, "freeze": 0.08, "shake": 6.0,
		"curve": [0.0, 0.0, 4.0, 22.0], "big": true, "flight": 1.25},
	# Hammer (15 November). A maul's side swing is a short, blunt arc. Its slam, and
	# every blow of a warhammer, lands on a patch of floor in front of you (shape
	# "impact": everything within the head's impact size of where it comes down).
	# A hammer pins what it hits (a long stun and a small shove) where a sword
	# shoves it away, because a hammer has to stay close.
	"maul_swing": {"windup": 0.1, "time": LIGHT, "shape": "arc", "arc": 110.0, "power": 1.0, "knock": 130.0, "stun": 0.3, "freeze": 0.07, "shake": 4.0,
		"curve": [-1.0, 0.9, 12.0, 16.0], "smear": "hammer_smear", "smear_else": "chop_smear", "alternate": true},
	"maul_slam": {"windup": 0.17, "time": HEAVY, "shape": "impact", "power": 1.5, "knock": 180.0, "stun": 0.6, "freeze": 0.12, "shake": 15.0,
		"curve": [-1.5, 0.3, 9.0, 19.0], "smear": "hammer_slam_smear", "smear_else": "overhead_smear", "big": true, "burst": "hammer_impact", "burst_else": "slam_burst"},
	"crush": {"windup": 0.19, "time": HEAVY, "shape": "impact", "power": 1.5, "knock": 150.0, "stun": 0.7, "freeze": 0.12, "shake": 12.0,
		"curve": [-1.5, 0.3, 9.0, 19.0], "smear": "hammer_slam_smear", "smear_else": "overhead_smear", "big": true, "burst": "hammer_impact", "burst_else": "slam_burst"},
	# Staff casts (15 November). Like a bow's shots: "windup" is the gathering, the
	# bolt leaves as it ends, towards wherever you are aiming at that moment.
	#   bolt   what leaves the staff (SwingBuild.CAST_MANA has what each costs)
	"bolt": {"windup": 0.12, "time": LIGHT, "shape": "cast", "bolt": "bolt", "power": 1.0, "knock": 110.0, "stun": 0.1, "freeze": 0.03,
		"curve": [0.0, 0.0, 2.0, 10.0], "smear": ""},
	"burst": {"windup": 0.2, "time": HEAVY, "shape": "cast", "bolt": "burst", "power": 1.5, "knock": 260.0, "stun": 0.25, "freeze": 0.06, "shake": 5.0,
		"curve": [0.0, 0.0, 0.0, 13.0], "smear": "", "big": true},
	"spray": {"windup": 0.12, "time": LIGHT, "shape": "cast", "bolt": "spray", "power": 1.0, "knock": 90.0, "stun": 0.08, "freeze": 0.02,
		"curve": [0.0, 0.0, 2.0, 10.0], "smear": ""},
	"orb": {"windup": 0.22, "time": HEAVY, "shape": "cast", "bolt": "orb", "power": 1.5, "knock": 300.0, "stun": 0.3, "freeze": 0.07, "shake": 6.0,
		"curve": [0.0, 0.0, 0.0, 13.0], "smear": "", "big": true},
	# The old parts-grid moves (weapon_build.gd), kept so that screen still works.
	"stab": {"windup": 0.06, "time": 0.25, "shape": "line", "width": 16.0, "range": 115.0, "power": 1.15, "knock": 320.0,
		"curve": [0.0, 0.0, 4.0, 26.0], "smear": "thrust_smear"},
	"lunge": {"windup": 0.15, "time": 0.38, "shape": "line", "width": 24.0, "range": 85.0, "power": 1.3, "knock": 300.0, "dash": 170.0,
		"curve": [0.0, 0.0, 4.0, 26.0], "smear": "thrust_smear"},
	"spin": {"windup": 0.07, "time": 0.44, "shape": "circle", "range": 72.0, "power": 0.85, "knock": 260.0,
		"curve": [0.0, TAU, 14.0, 14.0], "smear": "slash_smear"},
}

var color := Color(0.35, 0.7, 1.0)
static var MAX_HP := 100.0     # everyone's health (the lab can change it)
var max_hp := MAX_HP
var hp := MAX_HP
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
var unhurt := false            # nothing can hurt them (the test arena's "Invincible" switch)
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
var weapon_stamp := 0      # goes up every time the weapon changes (an arrow remembers which one loosed it)
var spirit: Node2D         # the forge spirit at your shoulder: it holds the runes, so none are drawn on the weapon
var spirit_lit := -9.0     # when an active rune's sign last landed in the weapon (it lights for a moment)
var with_spirit := true    # false until the spirit has joined you (the tutorial cave: at the forge)
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
static var LEAP_RANGE := 260.0     # how far away an enemy can be
const LEAP_TIME := 0.14       # the jump itself
const LEAP_AIM := 1.0         # prefers an enemy within this many radians of the aim
static var LEAP_DAMAGE := 1.0      # the landing strike, in blade hits
static var LEAP_STUN := 0.3
const LEAP_EMPTY := 130.0     # with nobody in range, it jumps this far the way you aim
var leap_targets: Array = []  # enemies already leapt to in this burst
var leap_burst := -9.0        # game_time the last leap of a burst began
var leap_landing: Dictionary = {}   # the strike waiting for the jump to end: {at, dir, size, power, target}

# Weak Point (passive, 11 November): the finisher marks the enemy it hit, and the
# next sword hit on the mark is a big crit. Only so many marks at a time.
static var WEAK_CRIT := 2.5        # a full-strength mark's hit, in normal hits
const WEAK_DODGE_REACH := 70.0  # On Dodge: how close the dodge must pass
var weak_marks: Array = []    # this player's marks, oldest first: [[enemy, mark]]

# Ghostwield (active, 11 November afternoon): a see-through copy of your sword in
# your other hand. While it is out, every swing you make is copied a moment
# later from the other side at a share of its strength, and the copy's hits set
# your passive runes off again as ghosted effects (the same share, ghost-coloured).
const GHOST_DELAY := 0.15        # a copy lands this long after your swing
const GHOST_GAP := 0.1           # Twice: the next copy comes this long after the one before
const GHOST_SHOVE := 0.5         # a copy knocks back and stuns this much as hard
const GHOST_DODGE_WIDTH := 30.0  # On Dodge: how far to each side of the dodge the ghost cuts
const GHOST_COLOR := Color("#a8b4ff")
var ghost_left := 0.0            # seconds the ghost sword has left (0: it isn't out)
var ghost_total := 1.0           # how long this one was called for (the HUD's bar)
var ghost_power := 0.5           # its copies, as a share of your swing
var ghost_count := 1             # copies of each swing (Twice: two)
var ghost_button := -1           # the button that called it
var ghost_swings: Array = []     # copies on their way: [{at, move, dir, side, finisher, fired}]
var ghost_born := -9.0           # game_time it appeared, and went (for the pictures)
var ghost_gone := -9.0
var ghost_show: Dictionary = {}  # the copy on screen now: {t0, dir, side, move}
var ghost_smears: Array = []     # its smears: [{t0, a0, a1, center, dir, side, move}]
var ghost_fx := false            # what is being put on screen right now is a ghosted effect
var dodge_from := Vector2.ZERO   # where the last dodge began
var ghost_group: CanvasGroup     # the ghost sword, recoloured as one picture
var ghost_layer: Node2D
var ghost_trail: Node2D

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
const GHOST_SHADER := preload("res://shaders/ghost.gdshader")
const GHOST_GLOW_SHADER := preload("res://shaders/ghost_glow.gdshader")


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
	# Orbit's orbs go round you: behind the body on one layer, in front on another.
	staff_back = _glow_layer()
	staff_back.show_behind_parent = true
	staff_back.draw.connect(_draw_orbs.bind(staff_back, false))
	# A Spectre: your body and weapon again, beside you (see "The staff's runes").
	spectre_group = CanvasGroup.new()
	spectre_group.name = "Spectre"
	var spectre_mat := ShaderMaterial.new()
	spectre_mat.shader = GHOST_SHADER
	spectre_group.material = spectre_mat
	spectre_group.fit_margin = 24.0
	spectre_group.visible = false
	add_child(spectre_group)
	spectre_layer = Node2D.new()
	spectre_group.add_child(spectre_layer)
	spectre_layer.draw.connect(_draw_spectre)
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
	# Ghostwield's sword and its smears, under the real sword.
	ghost_trail = Node2D.new()
	ghost_trail.material = _ghost_glow()
	add_child(ghost_trail)
	ghost_trail.draw.connect(_draw_ghost_trail)
	ghost_group = CanvasGroup.new()
	ghost_group.name = "Ghost"
	var ghost_mat := ShaderMaterial.new()
	ghost_mat.shader = GHOST_SHADER
	ghost_group.material = ghost_mat
	ghost_group.visible = false
	add_child(ghost_group)
	ghost_layer = Node2D.new()
	ghost_group.add_child(ghost_layer)
	ghost_layer.draw.connect(_draw_ghost)
	weapon_group = CanvasGroup.new()
	weapon_group.name = "Weapon"
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	weapon_group.material = mat
	add_child(weapon_group)
	weapon_layer = Node2D.new()
	weapon_group.add_child(weapon_layer)
	weapon_layer.draw.connect(_draw_weapon)
	staff_front = _glow_layer()
	staff_front.draw.connect(_draw_orbs.bind(staff_front, true))
	spirit = ForgeSpirit.new()
	spirit.name = "Spirit"
	spirit.player = self
	add_child(spirit)
	# A small cool light that follows the player, so they read in the darkest corner.
	light = PointLight2D.new()
	var stepped := Art.stepped_light(64)
	light.texture = stepped if stepped != null else Art.light_texture()
	light.texture_scale = Art.PIXEL if stepped != null else 2.4
	light.energy = 0.55
	light.color = Color(0.85, 0.92, 1.0)
	light.position = Vector2(0, -10)
	add_child(light)


## A layer of your own that glows: added on top of the picture and never dimmed.
func _glow_layer() -> Node2D:
	var n := Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	n.material = add
	add_child(n)
	return n


func set_weapon(stats: Dictionary) -> void:
	weapon = stats
	weapon_stamp += 1
	bow_draw = 0.0
	bow_nocked = false
	rune_queue.clear()
	slot_flash.clear()
	sweep_flash.clear()
	rune_counts.clear()
	leap_landing = {}
	_clear_marks()
	_stop_hold(true)
	_end_ghost(true)
	steady_rune = _steady_rune()
	_drop_steady()
	momentum_rune = _momentum_rune()
	stagger_rune = _stagger_rune()
	_drop_momentum()
	rumbles.clear()
	_end_bulwark(true)
	overflow_rune = _overflow_rune()
	_drop_overflow()
	orbs.clear()
	spectre_swings.clear()
	spectre_shots.clear()
	cast_weak = false
	dodge_arrow = false
	snipe_button = -1
	ability_charge = [1.0, 1.0, 1.0]
	ability_wait = [0.0, 0.0, 0.0]
	_reset_combo()


func _reset_combo() -> void:
	cast_weak = false
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
	_run_ghost(delta)
	_run_rains()
	_run_rumbles()
	_update_momentum(delta)
	_update_bulwark(delta)
	_update_mana(delta)
	_run_orbs()
	_run_spectre(delta)
	if is_down:
		_stop_hold(true)
		snipe_button = -1
		_drop_steady()
		_drop_momentum()
		_end_bulwark(true)
		_drop_overflow()
		orbs.clear()
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
	_update_lance()

	# Walking: a few frames to get going and to stop, so it has weight without lag.
	var speed := MOVE_SPEED * (1.0 + float(weapon.get("move_speed", 0.0)))
	var target := move * speed
	if hold_button >= 0:
		target *= SwingBuild.LANCE_MOVE if _beaming() else HOLD_MOVE
	elif snipe_button >= 0:
		target *= SwingBuild.SNIPE_MOVE
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

	_update_steady(delta, move)
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
	# A swing goes where you aimed as it began. A bow or a staff follows your aim
	# until the arrow or the bolt leaves.
	if current_step >= 0 and hit_time >= 0.0 and _ranged():
		anim_dir = aim_dir
		face_dir = aim_dir
	if snipe_button >= 0:
		anim_dir = aim_dir
		face_dir = aim_dir
		face_linger = FACE_LINGER


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
		dodge_from = global_position
		dodge_arrow = true
		_overflow_dodge()
		_spectre_dodge()
		_dust(global_position + FEET)
		Sfx.play(self, "dodge", -12.0)
		_trigger("dodge", [])
		_dodge_counts()


# --- Combo ------------------------------------------------------------------

func _steps() -> Array:
	return weapon.get("steps", [])


func _speed() -> float:
	# (Steady Aim's build-up is extra attack speed: nothing unless the bow has the rune.
	# A staff's cast without the mana for it is a slow one.)
	return maxf(float(weapon.get("speed", 1.0)) * (1.0 + steady) * (SwingBuild.MANA_SLOW if cast_weak else 1.0), 0.2)


func armed() -> bool:
	return weapon.has("blade") and not _steps().is_empty()


func _is_bow() -> bool:
	return weapon.get("weapon", "sword") == "bow"


func _is_staff() -> bool:
	return weapon.get("weapon", "sword") == "staff"


func _is_hammer() -> bool:
	return weapon.get("weapon", "sword") == "hammer"


## A bow or a staff: what it does leaves the hand and flies.
func _ranged() -> bool:
	return _is_bow() or _is_staff()


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
		if dodge_timer > 0.0 or hold_button >= 0 or snipe_button >= 0 or not leap_landing.is_empty():
			attack_buffered = true
		elif current_step >= 0:
			queued = true
	var held := input.attack_held
	if need_release:
		# A click that closed a menu shouldn't also swing: wait for the button to come up.
		need_release = held
		held = false
	# (No swinging in the middle of a Whirlwind or a Leap: the swing starts as it ends.)
	if current_step < 0 and dodge_timer <= 0.0 and hold_button < 0 and snipe_button < 0 and leap_landing.is_empty() and (input.attack_pressed or attack_buffered or held):
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
	# A cast the staff has no mana for is a weak, slow one (decided as it starts).
	cast_weak = str(info["shape"]) == "cast" and mana < _cast_cost(info)
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
	bow_from = [pose_angle, pose_hand]
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
	cast_weak = false
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
	if str(info["shape"]) == "shot":
		_loose(info)
		return
	if str(info["shape"]) == "cast":
		_cast(info)
		return
	var area := 1.0 + float(weapon.get("area", 0.0))
	# (Momentum: each step built up makes the swing hit harder.)
	var dmg: float = float(weapon.get("damage", 4.0)) * float(info["power"]) * (1.0 + momentum_bonus())
	var knock: float = info["knock"]
	var stun: float = float(info.get("stun", 0.12))
	var freeze: float = float(info.get("freeze", 0.05))
	var dir := anim_dir
	var hit_list: Array = []

	# One shape in front, tested once on the hit frame (like Core Keeper): reach is
	# the blade's length plus a little margin, so it matches the sword you hold.
	var reach := _move_reach(info)
	var shape := str(info["shape"])
	var swing := {"shape": shape, "dir": dir, "reach": reach,
		"half_arc": deg_to_rad(float(info.get("arc", 120.0)) * 0.5), "width": float(info.get("width", 16.0))}
	# Where it lands: an Aftershock rumbles there.
	last_impact = global_position + dir * reach * (IMPACT_AT if shape == "impact" else 0.7)
	var found := _swing_hits(info, dir, reach)
	for f in found:
		_hit_enemy(f[1], dmg, f[2], knock, stun, freeze, swing)
		hit_list.append(f[1])
		_add_stagger(f[1], float(info["power"]))
	var hits := hit_list.size()
	_add_momentum(hits)

	if shape == "impact":
		# Where a hammer lands: the floor takes it, and the patch it hit shows.
		var patch := float(weapon.get("impact", SwingBuild.HAMMER_IMPACT))
		var burst := str(info.get("burst", ""))
		if Art.piece_texture(burst) != null:
			Art.play_piece(self, burst, global_position + dir * reach * IMPACT_AT + Vector2(0, 8), 0.0, patch / 44.0)
		else:
			Art.play_piece(self, str(info.get("burst_else", "slam_burst")), global_position + dir * reach * IMPACT_AT + Vector2(0, 8), 0.0, patch / 62.0)
	elif info.has("burst"):
		# Where a slam lands: the ground breaks at the end of the blade. Seen from
		# above, so it is never turned.
		Art.play_piece(self, str(info["burst"]), global_position + dir * reach * 0.72 + Vector2(0, 8), 0.0, reach / 137.0)

	var fx := Fx.new()
	fx.kind = shape
	if shape == "arc" or shape == "impact" or (shape == "line" and Art.piece_texture(_smear_piece(info)) != null):
		fx.kind = "none"  # the sword's own smear shows the swing
	fx.dir = dir
	fx.radius = reach
	fx.arc = float(info.get("arc", 120.0))
	fx.width = float(info.get("width", 16.0)) * area
	fx.color = weapon.get("hit_color", Color.WHITE)
	fx.thick = info.get("big", false)
	_fx_root().add_child(fx)
	fx.global_position = global_position

	Sfx.play(self, "swing", -14.0, 0.7 if _is_hammer() else 1.0)
	var finisher := current_step == _steps().size() - 1 and _steps().size() > 1
	var fired: Array = []   # the runes this swing set off
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
			# (A hammer's slam still lands on the floor.)
			shake = maxf(shake, 5.0 if shape == "impact" else 2.5)
			Sfx.play(self, "finisher", -12.0)
		fired.append_array(_trigger("finisher", hit_list))
	if hits > 0:
		Sfx.play(self, "thud" if _is_hammer() else "hit", -5.0 if _is_hammer() else -8.0)
		fired.append_array(_trigger("hit", hit_list))
		_hit_refund()
	# Ghostwield: the ghost sword copies this swing a moment later, from the other side.
	if ghost_left > 0.0:
		for n in ghost_count:
			ghost_swings.append({"at": game_time + GHOST_DELAY + n * GHOST_GAP, "move": move, "dir": dir,
				"side": -swing_side if n % 2 == 0 else swing_side, "finisher": finisher, "fired": fired})
	# A Spectre with you does the same, whatever you swing (see "The staff's runes").
	if spectre_left > 0.0:
		for n in spectre_count:
			spectre_swings.append({"at": game_time + SwingBuild.SPECTRE_DELAY + float(n) * SwingBuild.SPECTRE_GAP, "move": move, "dir": dir,
				"side": -swing_side if n % 2 == 0 else swing_side, "finisher": finisher, "fired": fired,
				"power": spectre_power, "dmg": dmg, "spectre": true})


const FINISHER_PAUSE := 0.07


# --- The bow --------------------------------------------------------------------
# A shot is a move like a swing: the draw is its wind-up, and where a swing would
# land the arrow leaves (scripts/arrow.gd). What the arrow hits comes back here.

## The arrow leaves the bow, towards the aim.
func _loose(info: Dictionary) -> void:
	var dir := aim_dir
	anim_dir = dir
	var finisher := current_step == _steps().size() - 1 and _steps().size() > 1
	var a := Arrow.new()
	a.shooter = self
	a.stamp = weapon_stamp
	a.dir = dir
	a.speed = float(weapon.get("flight", SwingBuild.BOW_FLIGHT)) * float(info.get("flight", 1.0))
	a.left = float(weapon.get("range", SwingBuild.BOW_RANGE))
	a.damage = float(weapon.get("damage", 4.0)) * float(info["power"])
	a.knock = float(info["knock"])
	a.stun = float(info.get("stun", 0.1))
	a.freeze = float(info.get("freeze", 0.03))
	a.heavy = info.get("big", false)
	a.finisher = finisher
	a.kind = str(weapon.get("arrows", "wooden_arrows"))
	a.crit = float(weapon.get("crit", 0.05))
	a.crit_damage = float(weapon.get("crit_damage", 1.5))
	_fit_arrow(a, finisher)
	get_parent().add_child(a)
	a.global_position = global_position
	a.reset_physics_interpolation()
	bow_loosed = game_time
	var snap := _strip("bow_loose", global_position + pose_hand, dir.angle())
	if snap != null:
		snap.follow = self
		snap.follow_offset = pose_hand
	Sfx.play(self, "bow", -5.0 if a.heavy else -9.0, 0.8 if a.heavy else 1.0)
	squash = Vector2(1.06, 0.95) if a.heavy else Vector2(1.03, 0.98)
	var fired: Array = []
	if finisher:
		shake = maxf(shake, 2.5)
		fired = _trigger("finisher", [])
	_spectre_copies(a, fired)


## One of your arrows hit an enemy (called by the arrow, on the tick it lands).
func arrow_hit(a, e) -> void:
	if a.bolt != "":
		_bolt_hit(a, e)
		return
	var dmg: float = a.damage
	# Pierce: what is behind the first enemy may take less.
	if a.through > 0:
		dmg *= float(a.pierce_power)
	if a.rune != "":
		_rune_arrow_hit(a, e, dmg)
		return
	# (copied: a Spectre's copy of an arrow. It hits in the ghost's colour and sets
	# your passive runes off at its share, but it is no arrow of yours: no time off
	# a recharge for it, and nothing for Steady Aim.)
	var copied: bool = float(a.copy) > 0.0
	_hit_enemy(e, dmg, a.dir, a.knock, a.stun, a.freeze, {}, copied, a)
	Sfx.play(self, "hit", -6.0 if a.heavy else -9.0, 1.0 if a.heavy else 1.25)
	if a.heavy and not copied:
		shake = maxf(shake, float(MOVES["heavy_shot"].get("shake", 6.0)))
	# Runes belong to the bow that loosed it: an arrow still in the air when you
	# changed weapon is only an arrow.
	if a.stamp != weapon_stamp:
		return
	if a.through == 0 and not copied:
		# Once for each arrow, however many enemies it goes on through.
		if a.pierce > 0:
			_label("PIERCE!", SwingBuild.FITTINGS["pierce"]["color"])
		_hit_refund()
		if steady_rune.get("per_hit", false):
			_add_steady(SwingBuild.STEADY_HIT)
	_trigger("hit", [e], _copy_ghost(a))
	_ricochet(a, e, dmg)


## One of your arrows stopped in a wall or on the floor without hitting anyone.
func arrow_spent(a) -> void:
	if a.bolt != "":
		_bolt_spent(a)


# --- The staff --------------------------------------------------------------------
# A cast is a move like a bow's shot: the gathering is its wind-up, and where a
# swing would land a bolt leaves the crystal (scripts/arrow.gd flies it, as it
# flies arrows). Mana: each cast costs a little and it refills quickly; a cast
# with too little left is a weak, slow one that costs nothing.

const IMPACT_AT := 0.6           # a hammer's head comes down this far along its reach
var mana := SwingBuild.MANA
var mana_rest := 0.0             # seconds since the last cast
var mana_denied := -9.0          # game_time a cast last found too little mana (the HUD blinks)
var cast_weak := false           # the cast being made is a weak one


func _update_mana(delta: float) -> void:
	mana_rest += delta
	var rate := SwingBuild.MANA_REGEN + (SwingBuild.MANA_REST_REGEN if mana_rest >= SwingBuild.MANA_REST else 0.0)
	mana = minf(mana + rate * delta, SwingBuild.MANA)
	# (Saved Up on Overflow counts how long it has stayed full.)
	var was_ready := overflow_charged()
	overflow_charge = overflow_charge + delta if mana_full() else 0.0
	if overflow_charged() and not was_ready and _is_staff():
		Sfx.play(self, "click", -6.0, 1.6)


func _cast_cost(info: Dictionary) -> float:
	return float(SwingBuild.CAST_MANA.get(str(info.get("bolt", "")), 0.0))


## The cast leaves the staff, towards the aim.
func _cast(info: Dictionary) -> void:
	var dir := aim_dir
	anim_dir = dir
	var finisher := current_step == _steps().size() - 1 and _steps().size() > 1
	var weak := cast_weak
	# Overflow: a cast made on full mana (before it is paid for) is a bigger one.
	var over := _overflow_cast(mana_full())
	if weak:
		mana_denied = game_time
	else:
		mana = maxf(mana - _cast_cost(info), 0.0)
	mana_rest = 0.0
	var power := float(info["power"]) * (SwingBuild.MANA_WEAK if weak else 1.0) * float(over["damage"])
	var kind := "spark" if weak else str(info["bolt"])
	var made: Array = []
	if kind == "spray":
		# Three sparks in a fan. The middle one is the cast as far as runes go.
		for i in 3:
			var spark := _bolt("spark", dir.rotated(float(i - 1) * SwingBuild.SPRAY_SPREAD), power * SwingBuild.SPRAY_DAMAGE, info, finisher, over)
			spark.quiet = i != 1
			made.append(spark)
	else:
		made.append(_bolt(kind, dir, power, info, finisher, over))
	# Twice on Overflow: this one is cast again (see _run_overflow_echoes).
	for n in int(over.get("again", 0)):
		for b in made:
			overflow_echoes.append({"at": game_time + SwingBuild.OVERFLOW_ECHO * float(n + 1), "kind": b.bolt, "dir": b.dir, "power": power * (SwingBuild.SPRAY_DAMAGE if kind == "spray" else 1.0),
				"info": info, "over": over, "stamp": weapon_stamp})
	var heavy: bool = info.get("big", false) and not weak
	var flash := _strip("cast_flash", _crystal_world(), dir.angle(), 1.4 if heavy else 1.0)
	if flash != null:
		flash.modulate = weapon.get("hit_color", Color.WHITE)
	Sfx.play(self, "cast", -7.0 if heavy else -11.0, (0.75 if heavy else 1.0) * (1.3 if weak else 1.0))
	squash = Vector2(1.05, 0.96) if heavy else Vector2(1.02, 0.99)
	var fired: Array = []
	if finisher:
		shake = maxf(shake, 2.5)
		fired = _trigger("finisher", [])
	for b in made:
		_spectre_copies(b, fired)


## One bolt on its way. kind: "bolt", "burst" (it bursts where it lands), "spark"
## (small and weak) or "orb" (slow, and it bursts wide).
## over: what Overflow does to it (see _overflow_cast).
func _bolt(kind: String, dir: Vector2, power: float, info: Dictionary, finisher: bool, over: Dictionary = {}) -> Node2D:
	var size := float(weapon.get("size", 1.0)) * float(over.get("size", 1.0))
	var a := Arrow.new()
	a.shooter = self
	a.stamp = weapon_stamp
	a.dir = dir
	a.bolt = kind
	a.speed = float(weapon.get("flight", SwingBuild.STAFF_FLIGHT)) * (SwingBuild.ORB_FLIGHT if kind == "orb" else 1.0)
	a.left = float(weapon.get("range", SwingBuild.STAFF_RANGE))
	a.damage = float(weapon.get("damage", 4.0)) * power
	a.knock = float(info["knock"])
	a.stun = float(info.get("stun", 0.1))
	a.freeze = float(info.get("freeze", 0.03))
	a.heavy = kind == "burst" or kind == "orb"
	a.finisher = finisher
	a.crit = float(weapon.get("crit", 0.05))
	a.crit_damage = float(weapon.get("crit_damage", 1.5))
	a.color = weapon.get("hit_color", Color.WHITE)
	a.half_width = SwingBuild.BOLT_WIDTH * size * (0.6 if kind == "spark" else (1.5 if a.heavy else 1.0))
	if kind == "burst":
		a.splash = SwingBuild.BURST_RADIUS * size
	elif kind == "orb":
		a.splash = SwingBuild.ORB_RADIUS * size
	# (Overflow with Wider, or its blast: it bursts where it lands, at least this wide.)
	a.splash = maxf(a.splash, float(over.get("splash", 0.0)))
	a.big = float(over.get("size", 1.0))
	if over.get("glow", false):
		a.halo = "overflow_glow"
	get_parent().add_child(a)
	a.global_position = global_position
	a.reset_physics_interpolation()
	return a


## One of your bolts hit an enemy.
func _bolt_hit(a, e) -> void:
	var at: Vector2 = e.global_position
	var copied: bool = float(a.copy) > 0.0   # a Spectre's copy of a bolt (see arrow_hit)
	_hit_enemy(e, a.damage, a.dir, a.knock, a.stun, a.freeze, {}, copied, a)
	Sfx.play(self, "hit", -6.0 if a.heavy else -10.0, 1.1 if a.heavy else 1.4)
	var hits: Array = [e]
	if a.splash > 0.0:
		hits.append_array(_bolt_burst(a, at, {e.get_instance_id(): true}))
	# Runes belong to the staff that cast it, and a spray counts once.
	if a.stamp != weapon_stamp or a.rune != "" or a.quiet:
		return
	if not copied:
		_hit_refund()
		_overflow_refund()
	_trigger("hit", hits, _copy_ghost(a))
	_chain_bolt(a, at, hits)


## One of your bolts stopped in a wall or at the end of its reach.
func _bolt_spent(a) -> void:
	if a.splash > 0.0:
		var hits := _bolt_burst(a, a.global_position, {})
		if not hits.is_empty() and a.stamp == weapon_stamp and a.rune == "" and not a.quiet:
			var first: Vector2 = hits[0].global_position
			if float(a.copy) <= 0.0:
				_hit_refund()
				_overflow_refund()
			_trigger("hit", hits, _copy_ghost(a))
			_chain_bolt(a, first, hits)
		return
	var fizz := _strip("bolt_hit", a.global_position + Arrow.HEIGHT, a.dir.angle(), 0.7)
	if fizz != null:
		fizz.modulate = a.color


## A burst (or an orb) goes off at `at`: everything within its reach is hit,
## except `skip` (the enemy it landed on, which the bolt itself has hit). Returns
## the enemies it caught.
func _bolt_burst(a, at: Vector2, skip: Dictionary) -> Array:
	var caught: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.immune or skip.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - at
		if rel.length() > float(a.splash) + float(e.radius):
			continue
		_hit_enemy(e, a.damage, rel.normalized() if rel.length() > 1.0 else a.dir, a.knock, a.stun, a.freeze, {}, float(a.copy) > 0.0, a)
		caught.append(e)
	var orb: bool = a.bolt == "orb"
	var name := "orb_hit" if orb else "burst_hit"
	# (The pictures are drawn for a burst of 28 art pixels and an orb's of 44.)
	var pop := _strip(name, at + Arrow.HEIGHT * 0.5, 0.0, float(a.splash) / (88.0 if orb else 56.0))
	if pop != null:
		pop.modulate = a.color
	shake = maxf(shake, 7.0 if orb else 5.0)
	Sfx.play(self, "finisher", -9.0, 1.5 if orb else 1.9)
	return caught


## Where the staff's crystal is, in the world: bolts and the cast's flash start there.
func _crystal_world() -> Vector2:
	var pose := _sword_pose()
	var blade: String = weapon.get("blade", "wooden_apprentice")
	var grip: String = weapon.get("grip", "wooden_shaft")
	var seat := Vector2(SwordArt.blade_x(blade, "hand"), 0) + SwordArt.crystal_at(blade, "hand") - SwordArt.pivot(blade, grip, "hand")
	return global_position + (pose[1] as Vector2) + (seat * Art.PIXEL).rotated(float(pose[0]) + PI * 0.5)


# --- The bow's runes ----------------------------------------------------------------
# Pierce, Ricochet and Steady Aim are passive; Volley, Snipe and Arrow Rain go on
# the ability buttons. An arrow that a rune looses (a Volley's, a Snipe's, a
# Ricochet's jump) is a real arrow in the rune's colour. It never crits and sets
# no other rune off, like the strike at the end of the sword's Leap.

var steady := 0.0             # Steady Aim: the attack speed built up so far (0.3 is +30%)
var steady_rune := {}         # what the bow's Steady Aim runes come to ({} with none): see _steady_rune
var steady_full := false      # it is at its most (said once, when it gets there)
var steady_arrows := 0        # Saved Up on Steady Aim: arrows loosed at full speed
var dodge_arrow := false      # the next arrow is the first one after a dodge (Pierce with On Dodge)
var snipe_button := -1        # the button whose Snipe is being drawn (-1: none)
var snipe_t := 0.0            # how long it has been held
var snipe_perfect := false    # the last one was let go in the sweet spot
var rains: Array = []         # Arrow Rain's showers that are falling: [{at, ticks, next, scale, dmg, col, pin}]
const SNIPE_RING := Vector2(0, -8)   # where Snipe's closing ring is drawn, from the player's centre


## Saved Up: true on every third time rune `i` would fire (always, without it).
func _counts(i: int) -> bool:
	var every := int(weapon["effects"][i].get("every", 1))
	if every <= 1:
		return true
	rune_counts[i] = int(rune_counts.get(i, 0)) + 1
	return int(rune_counts[i]) % every == 0


## How long after one firing of a rune its Twice comes.
func _repeat_gap(id: String, why: String) -> float:
	match id:
		"leap":
			return LEAP_TIME + 0.12 if why == "" else REPEAT_GAP   # one leap has to land before the next sets off
		"arrow_rain":
			# The second shower comes as the first one ends.
			return SwingBuild.RAIN_DODGE_TIME if why == "dodge" else float(SwingBuild.FITTINGS[id]["time"])
		"aftershock":
			return SwingBuild.AFTERSHOCK_GAP
		"quake":
			return SwingBuild.QUAKE_GAP
		"nova":
			return SwingBuild.NOVA_GAP
	return REPEAT_GAP


## Runes whose Twice is one bigger firing, not two firings: Weak Point (two marks),
## Ricochet (two jumps), Bulwark (its burst stuns twice as long), Chain (twice as
## many jumps), Spectre (two copies of each attack).
static func _fires_once(id: String) -> bool:
	return id in ["weak_point", "ricochet", "bulwark", "chain", "spectre"]


## Pierce and Steady Aim's burst change an arrow of the chain as it leaves the bow.
## Pierce is on the finisher's arrow (Every Hit: on every arrow; On Dodge: also on
## the first arrow after a dodge).
func _fit_arrow(a, finisher: bool) -> void:
	var after_dodge := dodge_arrow
	dodge_arrow = false
	var effects: Array = weapon.get("effects", [])
	for i in effects.size():
		var e: Dictionary = effects[i]
		if e["id"] != "pierce":
			continue
		var on: bool = e["trigger"] == "hit" or (finisher and e["trigger"] == "finisher") or (after_dodge and "dodge" in e.get("also", []))
		if not on or not _counts(i):
			continue
		a.pierce = mini(int(a.pierce) + SwingBuild.pierce_count(e), SwingBuild.PIERCE_MAX)
		a.pierce_power = minf(float(e.get("power", 1.0)), 1.0)
		a.half_width = maxf(float(a.half_width), Arrow.HALF_WIDTH + SwingBuild.PIERCE_WIDTH * (float(e["size"]) - 1.0))
		a.streak = "pierce_trail"
		_flash_effect(i)
	# Saved Up on Steady Aim: once it is full, every third arrow is three times as heavy.
	if steady_rune.get("burst", false) and steady >= float(steady_rune["cap"]) - 0.001:
		steady_arrows += 1
		if steady_arrows % SwingBuild.SAVED_UP_EVERY == 0:
			a.damage = float(a.damage) * SwingBuild.SAVED_UP_POWER
			a.knock = float(a.knock) * 1.3
			a.heavy = true
			for i in steady_rune["effects"]:
				_flash_effect(i)
			_label("STEADY AIM x3!", SwingBuild.FITTINGS["steady_aim"]["color"])


## One of a rune's own arrows hit an enemy.
func _rune_arrow_hit(a, e, dmg: float) -> void:
	var at: Vector2 = e.global_position - a.dir * float(e.radius) * 0.4 + Arrow.HEIGHT * 0.5
	if a.rune == "snipe":
		# The farther it flew, the harder it lands.
		dmg *= lerpf(SwingBuild.SNIPE_NEAR, SwingBuild.SNIPE_FAR, clampf(float(a.hit_flown) / SwingBuild.SNIPE_DISTANCE, 0.0, 1.0))
	e.take_hit(dmg, a.dir, a.knock, false, a.color, a.stun, a.freeze)
	if a.rune == "snipe":
		_strip("snipe_hit", at, a.dir.angle())
		shake = maxf(shake, 9.0)
		Sfx.play(self, "finisher", -5.0, 1.3)
	else:
		if _strip("arrow_hit", at, a.dir.angle()) == null:
			Art.play_piece(self, "hit_spark", at, a.dir.angle())
		Sfx.play(self, "hit", -10.0, 1.35)
	if a.rune == "ricochet" and int(a.bounce.get("jumps", 0)) > 0:
		_bounce(e.global_position, a.struck, float(a.damage), int(a.bounce["jumps"]), float(a.bounce["range"]), a.bounce.get("splinter", false), a.color, str(a.kind))


## Ricochet: an arrow of the chain that hit `e` jumps on to the nearest other enemy.
func _ricochet(a, e, dmg: float) -> void:
	var effects: Array = weapon.get("effects", [])
	var fired: Array = []
	var jumps := 0
	var share := 0.0
	var reach := 0.0
	var splinter := false
	for i in effects.size():
		var f: Dictionary = effects[i]
		if f["id"] != "ricochet" or not _counts(i):
			continue
		fired.append(i)
		jumps += int(f["count"])
		share = maxf(share, SwingBuild.RICOCHET_DAMAGE * float(f.get("power", 1.0)))
		reach = maxf(reach, SwingBuild.RICOCHET_RANGE * float(f["size"]))
		splinter = splinter or f.get("splinter", false)
	if fired.is_empty():
		return
	var col: Color = SwingBuild.FITTINGS["ricochet"]["color"]
	if _bounce(e.global_position, a.struck, dmg * share, mini(jumps, SwingBuild.MAX_COUNT), reach, splinter, col, str(a.kind)) > 0:
		for i in fired:
			_flash_effect(i)
		_label("RICOCHET!", col)


## Sends a Ricochet arrow from `from` to the nearest enemy that isn't in `struck`
## (two of them, to the two nearest, when it splits). Returns how many went.
func _bounce(from: Vector2, struck: Dictionary, dmg: float, jumps: int, reach: float, splinter: bool, col: Color, kind: String) -> int:
	var taken := struck.duplicate()
	var made := 0
	for k in (2 if splinter else 1):
		var best = null
		var best_d := reach
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead or e.immune or taken.has(e.get_instance_id()):
				continue
			var d: float = e.global_position.distance_to(from) - float(e.radius)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		taken[best.get_instance_id()] = true
		var to: Vector2 = best.global_position - from
		var b := _rune_arrow("ricochet", to.normalized() if to.length() > 0.5 else aim_dir, dmg, col)
		b.global_position = from
		b.reset_physics_interpolation()
		b.kind = kind
		b.left = to.length() + 24.0
		b.knock = 90.0
		b.stun = 0.08
		b.freeze = 0.02
		b.struck = struck.duplicate()
		b.flown = Arrow.HIDE_FIRST   # it is drawn from where it turns
		b.bounce = {"jumps": jumps - 1, "range": reach, "splinter": splinter}
		made += 1
	if made > 0:
		_strip("ricochet_spark", from + Arrow.HEIGHT * 0.5)
		Sfx.play(self, "click", -9.0, 1.5)
	return made


## An arrow loosed by a rune, from the bow in the hand.
func _rune_arrow(rune: String, dir: Vector2, dmg: float, col: Color) -> Node2D:
	var a := Arrow.new()
	a.shooter = self
	a.stamp = weapon_stamp
	a.rune = rune
	a.color = col
	a.dir = dir
	a.speed = float(weapon.get("flight", SwingBuild.BOW_FLIGHT))
	a.left = float(weapon.get("range", SwingBuild.BOW_RANGE))
	a.damage = dmg
	a.knock = 180.0
	a.stun = 0.12
	a.freeze = 0.04
	a.kind = str(weapon.get("arrows", "wooden_arrows"))
	get_parent().add_child(a)
	a.global_position = global_position
	a.reset_physics_interpolation()
	return a


## What the bow's Steady Aim runes come to: how fast it builds, how far, and
## what the bands add. Empty when the bow has none.
func _steady_rune() -> Dictionary:
	var out := {}
	var effects: Array = weapon.get("effects", [])
	for i in effects.size():
		var e: Dictionary = effects[i]
		if e["id"] != "steady_aim":
			continue
		if out.is_empty():
			out = {"rate": 0.0, "cap": 0.0, "per_hit": false, "burst": false, "keep": false, "effects": []}
		out["rate"] = float(out["rate"]) + SwingBuild.steady_rate(e)
		out["cap"] = maxf(float(out["cap"]), SwingBuild.steady_cap(e))
		out["per_hit"] = out["per_hit"] or e.get("per_hit", false)
		out["burst"] = out["burst"] or int(e.get("every", 1)) > 1
		out["keep"] = out["keep"] or "dodge" in e.get("also", [])
		out["effects"].append(i)
	return out


func _drop_steady() -> void:
	steady = 0.0
	steady_full = false
	steady_arrows = 0


## Steady Aim: stand still while you shoot and the bow gets faster and faster.
## Walking empties it at once. So does a dodge, unless the rune has On Dodge.
func _update_steady(delta: float, move: Vector2) -> void:
	if steady_rune.is_empty():
		return
	var keep: bool = steady_rune["keep"]
	var dodging := dodge_timer > 0.0 or game_time - dodge_started < DODGE_TIME + 0.12
	if (dodging and not keep) or (move.length() > 0.2 and not (dodging and keep)):
		_drop_steady()
		return
	# It only builds while you are shooting (drawing a Snipe counts).
	if current_step >= 0 or snipe_button >= 0:
		_add_steady(float(steady_rune["rate"]) * delta)


## More Steady Aim. Each fifth of the way lights a step of the ring at your feet.
func _add_steady(more: float) -> void:
	if steady_rune.is_empty():
		return
	var cap := float(steady_rune["cap"])
	var before := steady_step()
	steady = minf(steady + more, cap)
	if steady_step() > before:
		for i in steady_rune["effects"]:
			_flash_effect(i)
		Sfx.play(self, "click", -15.0, 1.0 + 0.12 * float(steady_step()))
	if steady >= cap - 0.0001 and not steady_full:
		steady_full = true
		_label("STEADY AIM +%d%%!" % roundi(cap * 100.0), SwingBuild.FITTINGS["steady_aim"]["color"])


## How many of the ring's five steps are lit.
func steady_step() -> int:
	if steady_rune.is_empty():
		return 0
	return clampi(int(steady / maxf(float(steady_rune["cap"]), 0.01) * 5.0 + 0.001), 0, 5)


## Volley: a fan of arrows from the bow. Up close all of them hit one enemy.
func _volley(size: float, power: float, col: Color) -> void:
	var n := SwingBuild.volley_arrows(size)
	var dmg := float(weapon.get("damage", 8.0)) * SwingBuild.VOLLEY_DAMAGE * power
	for k in n:
		var a := _rune_arrow("volley", aim_dir.rotated((float(k) - float(n - 1) * 0.5) * SwingBuild.VOLLEY_SPREAD), dmg, col)
		a.knock = 200.0
		a.stun = 0.15
	_loosed_by_rune(aim_dir)
	var fan := _strip("volley_fan", global_position + pose_hand, aim_dir.angle(), 1.0 + 0.25 * float(n - 3) * 0.5)
	if fan != null:
		fan.follow = self
		fan.follow_offset = pose_hand
	Sfx.play(self, "bow", -3.0, 0.85)
	shake = maxf(shake, 4.0)
	squash = Vector2(1.07, 0.94)


## Snipe: one heavy arrow that flies fast and far, and lands harder the farther
## it flew (see _rune_arrow_hit).
func _snipe_shot(power: float, col: Color) -> void:
	var a := _rune_arrow("snipe", aim_dir, float(weapon.get("damage", 8.0)) * power, col)
	a.speed = float(a.speed) * 1.6
	a.left = float(a.left) * SwingBuild.SNIPE_RANGE
	a.knock = 380.0
	a.stun = 0.35
	a.freeze = 0.09
	a.heavy = true
	a.streak = "snipe_trail"
	_loosed_by_rune(aim_dir)
	var snap := _strip("bow_loose", global_position + pose_hand, aim_dir.angle(), 1.4)
	if snap != null:
		snap.follow = self
		snap.follow_offset = pose_hand
	Sfx.play(self, "bow", -2.0, 0.6)
	shake = maxf(shake, 5.0)
	squash = Vector2(1.1, 0.92)


## A rune's arrow just left the bow: the string snaps and the body looks that way.
func _loosed_by_rune(dir: Vector2) -> void:
	bow_loosed = game_time
	if current_step < 0:
		face_dir = dir
		face_linger = FACE_LINGER
		return_from = [dir.angle(), BOW_CHEST + dir * BOW_HOLD]
		return_t = RETURN_TIME


## The button's Snipe is let go: how long it was drawn says how good it is.
func _loose_snipe() -> void:
	var b := snipe_button
	var held := snipe_t
	snipe_button = -1
	var list := _abilities()
	if b < 0 or b >= list.size():
		return
	var a: Dictionary = list[b]
	ability_charge[b] = 0.0
	ability_used[b] = game_time
	# Wider gives a longer sweet spot.
	var sweet := 0.0
	for i in a["effects"]:
		sweet = maxf(sweet, SwingBuild.SNIPE_SWEET * float(weapon["effects"][i]["size"]))
	var quality := 1.0
	if held < SwingBuild.SNIPE_CHARGE:
		quality = SwingBuild.SNIPE_EARLY
	elif held <= SwingBuild.SNIPE_CHARGE + sweet:
		quality = SwingBuild.SNIPE_PERFECT
	snipe_perfect = quality > 1.0
	for i in a["effects"]:
		var e: Dictionary = weapon["effects"][i]
		for n in int(e["count"]):
			_queue_rune(i, game_time + n * REPEAT_GAP, float(e["size"]), [], float(e.get("power", 1.0)) * quality)
	_run_rune_queue()   # this tick: the arrow leaves as the button comes up


## Where a rune that needs a place lands. With a mouse it is the pointer, no
## further than `reach`. Without one it is the enemy nearest your aim, or else a
## fixed way ahead.
func _aim_point(reach: float) -> Vector2:
	if input.uses_mouse():
		var off: Vector2 = input.aim_offset if input.kind == "net" else get_global_mouse_position() - global_position
		return global_position + off.limit_length(reach)
	var best = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.immune:
			continue
		var rel: Vector2 = e.global_position - global_position
		if rel.length() < best_d and absf(aim_dir.angle_to(rel)) <= 0.6:
			best_d = rel.length()
			best = e
	return best.global_position if best != null else global_position + aim_dir * minf(200.0, reach)


## Arrow Rain: marks the ground at `at`, and arrows pour down on it. Counted in
## game ticks, so every computer has the same arrows land on the same tick.
func _rain(at: Vector2, time: float, scale: float, dmg: float, col: Color, pin: bool) -> void:
	var tps := float(Engine.physics_ticks_per_second)
	rains.append({"at": at, "ticks": maxi(roundi(time * tps), 1), "next": maxi(roundi(SwingBuild.RAIN_TICK * tps), 1),
		"scale": scale, "dmg": dmg, "col": col, "pin": pin})
	var mark := _strip("rain_mark", at, 0.0, scale)
	if mark != null:
		mark.life = time + 0.15
		mark.fade_tail = 0.3
	_loosed_by_rune(aim_dir)
	Sfx.play(self, "bow", -5.0, 0.7)


func _run_rains() -> void:
	var tick := maxi(roundi(SwingBuild.RAIN_TICK * float(Engine.physics_ticks_per_second)), 1)
	for r in rains.duplicate():
		r["ticks"] = int(r["ticks"]) - 1
		r["next"] = int(r["next"]) - 1
		if int(r["next"]) <= 0:
			r["next"] = tick
			_rain_falls(r)
		if int(r["ticks"]) <= 0:
			rains.erase(r)


## One fall of a shower: every enemy standing on the marked ground is hit.
func _rain_falls(r: Dictionary) -> void:
	var at: Vector2 = r["at"]
	var rad: Vector2 = SwingBuild.RAIN_RADIUS * float(r["scale"])
	var hits := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.immune:
			continue
		var rel: Vector2 = (e.global_position - at) / (rad + Vector2.ONE * float(e.radius))
		if rel.length_squared() > 1.0:
			continue
		e.take_hit(float(r["dmg"]), Vector2.ZERO, 0.0, false, r["col"], SwingBuild.RAIN_PIN if r["pin"] else 0.0, 0.0)
		if r["pin"]:
			e.apply_stun(SwingBuild.RAIN_PIN)
		_rain_arrow(e.global_position + Vector2(randf_range(-4.0, 4.0), randf_range(-2.0, 4.0)), true)
		hits += 1
	# More arrows where nobody stands. (Only for the eye: they are thrown with the
	# picture's dice, not the game's.)
	for k in 4:
		var turn := randf() * TAU
		_rain_arrow(at + Vector2(cos(turn) * rad.x, sin(turn) * rad.y) * sqrt(randf()) * 0.92, false)
	Sfx.play(self, "hit" if hits > 0 else "swing", -13.0 if hits > 0 else -20.0, 1.5)


## One arrow of the rain coming down at `where`. landed: it is already there (it
## hit someone this tick), so the fall is skipped.
func _rain_arrow(where: Vector2, landed: bool) -> void:
	var a := _strip("rain_arrow", where)
	if a != null:
		a.hold = 0.35
		if landed:
			a.t = 2.0 / maxf(a.fps, 1.0)
		else:
			a.wait = randf() * 0.2
	if landed:
		_strip("rain_hit", where)


# --- The hammer's runes --------------------------------------------------------------
# Momentum, Stagger and Aftershock are passive; Quake, Bulwark and Hook go on the
# ability buttons. Momentum and Stagger don't "fire": Momentum builds on you with
# every swing that lands, and Stagger fills a meter on each enemy you hit. What a
# rune hits (a rumble, an eruption, a break) never crits and sets nothing else off.

var momentum := 0             # Momentum: how many of its five steps are lit
var momentum_rune := {}       # what the hammer's Momentum runes come to ({} with none): see _momentum_rune
var momentum_count := 0       # Saved Up on Momentum: hits counted towards the next step
var momentum_idle := 0.0      # seconds since a hit last landed
var momentum_full := false    # it is at its most (said once, when it gets there)
var stagger_rune := {}        # the same for Stagger: see _stagger_rune
var last_impact := Vector2.ZERO   # where the last swing landed
var rumbles: Array = []       # Aftershock's rumbles on their way: [{at, where, scale, dmg, col}]
var quake_targets: Array = [] # enemies a Quake has already erupted under in this burst
var quake_burst := -9.0       # game_time the last eruption of a burst went off
var hook_targets: Array = []  # enemies this press's chains already have hold of (Twice: the second takes another)
var bulwark_left := 0.0       # seconds of Bulwark's shield left (0: it isn't up)
var bulwark_total := 1.0      # how long this one was put up for (the HUD's bar)
var bulwark_stun := 1.5       # how long its burst stuns, when enemies break it
var bulwark_hits := 0         # hits it can still take: the last one breaks it
var bulwark_blocked := -9.0   # game_time it last stopped a hit
var bulwark_fx: Node2D = null # the shield's picture
const BULWARK_BLOCK_GAP := 0.3   # an enemy leaning on the shield counts as a hit this often at most
const QUAKE_AIM := 300.0         # picking Quake's enemy: being a radian off the aim counts as this many px further away
var stagger_said := -9.0         # game_time "STAGGER!" was last written (one swing can break several meters)


## What the hammer's Momentum runes come to together ({} with none).
##   gain: steps for each swing that lands   every: Saved Up, a step for every so many
##   step: what one step adds to a swing     per_hit: every enemy a swing catches counts
##   dodge: a dodge counts as a hit
func _momentum_rune() -> Dictionary:
	var out := {}
	var effects: Array = weapon.get("effects", [])
	for i in effects.size():
		var e: Dictionary = effects[i]
		if e["id"] != "momentum":
			continue
		if out.is_empty():
			out = {"gain": 0, "every": 1, "step": 0.0, "per_hit": false, "dodge": false, "effects": []}
		out["gain"] = int(out["gain"]) + int(e["count"])
		out["every"] = maxi(int(out["every"]), int(e.get("every", 1)))
		out["step"] = maxf(float(out["step"]), SwingBuild.momentum_step(e))
		out["per_hit"] = out["per_hit"] or e.get("per_hit", false)
		out["dodge"] = out["dodge"] or "dodge" in e.get("also", [])
		out["effects"].append(i)
	return out


## How much harder a swing hits for the Momentum built up (0.4 is +40%).
func momentum_bonus() -> float:
	return 0.0 if momentum_rune.is_empty() else float(momentum) * float(momentum_rune["step"])


## A swing landed on `landed` enemies (or a dodge counted as one): more Momentum.
## One swing is one step however many it catches, unless the rune has Every Hit.
func _add_momentum(landed: int) -> void:
	if momentum_rune.is_empty() or landed <= 0 or is_down:
		return
	momentum_idle = 0.0
	var gain := int(momentum_rune["gain"]) * (landed if momentum_rune["per_hit"] else 1)
	var every := int(momentum_rune["every"])
	if every > 1:
		momentum_count += gain
		@warning_ignore("integer_division")
		gain = momentum_count / every
		momentum_count %= every
	if gain <= 0 or momentum >= SwingBuild.MOMENTUM_STEPS:
		return
	momentum = mini(momentum + gain, SwingBuild.MOMENTUM_STEPS)
	for i in momentum_rune["effects"]:
		_flash_effect(i)
	Sfx.play(self, "click", -14.0, 0.9 + 0.12 * float(momentum))
	if momentum >= SwingBuild.MOMENTUM_STEPS and not momentum_full:
		momentum_full = true
		_label("MOMENTUM +%d%%!" % roundi(momentum_bonus() * 100.0), SwingBuild.FITTINGS["momentum"]["color"])


func _drop_momentum() -> void:
	momentum = 0
	momentum_count = 0
	momentum_idle = 0.0
	momentum_full = false


## Stop hitting and Momentum drains away: after a wait, a step at a time.
func _update_momentum(delta: float) -> void:
	if momentum <= 0:
		return
	momentum_idle += delta
	if momentum_idle >= SwingBuild.MOMENTUM_HOLD + SwingBuild.MOMENTUM_DRAIN:
		momentum_idle -= SwingBuild.MOMENTUM_DRAIN
		momentum -= 1
		momentum_full = false


## Momentum's chevrons round the feet: one lit for each step.
func _draw_momentum_ring() -> void:
	if momentum_rune.is_empty() or is_down or (momentum <= 0 and current_step < 0):
		return
	var col: Color = SwingBuild.FITTINGS["momentum"]["color"]
	var tex := BowArt.fx_texture("momentum_ring")
	var info := BowArt.fx("momentum_ring")
	if tex == null or info.is_empty():
		under_bright.draw_set_transform(FEET, 0.0, Vector2(1.0, 0.45))
		under_bright.draw_arc(Vector2.ZERO, 22.0, -PI * 0.5, -PI * 0.5 + TAU * float(momentum) / float(SwingBuild.MOMENTUM_STEPS), 24, col, 2.0)
		under_bright.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var size: Array = info.get("frame", [48, 24])
	var o: Array = info.get("origin", [24, 12])
	under_bright.draw_set_transform(FEET, 0.0, Vector2(Art.PIXEL, Art.PIXEL))
	under_bright.draw_texture_rect_region(tex, Rect2(-float(o[0]), -float(o[1]), float(size[0]), float(size[1])),
		Rect2(float(momentum) * float(size[0]), 0, float(size[0]), float(size[1])))
	under_bright.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## What the hammer's Stagger runes come to together ({} with none).
##   gain: how much of a swing each swing adds to the meter (Twice: 2; Saved Up: a third)
##   power: Saved Up's break is three times the blow and the stun
##   size: Wider, the break also stuns what is near   dodge: a dodge past an enemy counts as a hit
func _stagger_rune() -> Dictionary:
	var out := {}
	var effects: Array = weapon.get("effects", [])
	for i in effects.size():
		var e: Dictionary = effects[i]
		if e["id"] != "stagger":
			continue
		if out.is_empty():
			out = {"gain": 0.0, "power": 1.0, "size": 1.0, "dodge": false, "effects": []}
		out["gain"] = float(out["gain"]) + float(e["count"]) / float(maxi(int(e.get("every", 1)), 1))
		out["power"] = maxf(float(out["power"]), float(e.get("power", 1.0)))
		out["size"] = maxf(float(out["size"]), float(e["size"]))
		out["dodge"] = out["dodge"] or "dodge" in e.get("also", [])
		out["effects"].append(i)
	return out


## A swing of yours landed on `e` (points: 1 for a swing, 1.5 for a slam): its
## Stagger meter fills. Full, it breaks: a heavy blow, and the enemy is stunned.
func _add_stagger(e, points: float) -> void:
	if stagger_rune.is_empty() or not is_instance_valid(e) or e.dead:
		return
	if not e.add_stagger(points * float(stagger_rune["gain"])):
		return
	var power := maxf(float(stagger_rune["power"]), 1.0)
	var size := float(stagger_rune["size"])
	var col: Color = SwingBuild.FITTINGS["stagger"]["color"]
	var time := SwingBuild.STAGGER_STUN * power
	var at: Vector2 = e.global_position
	for i in stagger_rune["effects"]:
		_flash_effect(i)
	_strip("stagger_break", at + Vector2(0, -float(e.radius) * 0.3), 0.0, 1.0 + 0.3 * (power - 1.0) / 2.0)
	e.stagger_break(time)
	# (The blow keeps the shove the swing just gave it.)
	var kept: Vector2 = e.knock
	e.take_hit(float(weapon.get("damage", 8.0)) * SwingBuild.STAGGER_DAMAGE * power, (at - global_position).normalized(), 0.0, false, col, 0.0, 0.08)
	if is_instance_valid(e) and not e.dead:
		e.knock = kept
	# Wider: the break stuns what stands near it too.
	if size > 1.0:
		var ring := RuneFx.new()
		ring.kind = "ring"
		ring.size = SwingBuild.STAGGER_REACH * size
		ring.color = col
		ring.life = 0.25
		_fx_root().add_child(ring)
		ring.global_position = at
		for o in get_tree().get_nodes_in_group("enemies"):
			if o == e or not is_instance_valid(o) or o.dead or o.immune:
				continue
			if o.global_position.distance_to(at) <= SwingBuild.STAGGER_REACH * size + float(o.radius):
				o.stagger_break(time)
	shake = maxf(shake, 8.0)
	Sfx.play(self, "finisher", -5.0, 1.6)
	if game_time - stagger_said > 0.3:
		stagger_said = game_time
		_label("STAGGER!" if power <= 1.0 else "STAGGER x3!", col)


## On Dodge on Momentum and Stagger: a dodge counts as a hit (for Stagger, on the
## enemy the dodge passes).
func _dodge_counts() -> void:
	if momentum_rune.get("dodge", false):
		_add_momentum(1)
	if stagger_rune.get("dodge", false):
		var passed = _dodge_passes()
		if passed != null:
			_add_stagger(passed, 1.0)


## Aftershock: the ground at `where` trembles, and a moment later it rumbles and
## hurts whatever is still near.
func _rumble(where: Vector2, patch: float, dmg: float, col: Color) -> void:
	rumbles.append({"at": game_time + SwingBuild.AFTERSHOCK_DELAY, "where": where, "scale": patch, "dmg": dmg, "col": col})
	var crack := _strip("aftershock_crack", where, 0.0, patch)
	if crack != null:
		crack.life = SwingBuild.AFTERSHOCK_DELAY
		crack.z_index = 0
	Sfx.play(self, "rumble", -16.0, 1.5)


func _run_rumbles() -> void:
	var due: Array = []
	for r in rumbles:
		if float(r["at"]) <= game_time:
			due.append(r)
	for r in due:
		rumbles.erase(r)
		var where: Vector2 = r["where"]
		var patch := float(r["scale"])
		var burst := _strip("aftershock_burst", where, 0.0, patch)
		if burst == null:
			var ring := RuneFx.new()
			ring.kind = "ring"
			ring.size = SwingBuild.AFTERSHOCK_RADIUS * patch
			ring.color = r["col"]
			ring.life = 0.25
			_fx_root().add_child(ring)
			ring.global_position = where
		var struck := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead:
				continue
			var rel: Vector2 = e.global_position - where
			if rel.length() > SwingBuild.AFTERSHOCK_RADIUS * patch + float(e.radius):
				continue
			e.take_hit(float(r["dmg"]), rel.normalized() if rel.length() > 1.0 else Vector2.UP, 110.0, false, r["col"], SwingBuild.AFTERSHOCK_STUN, 0.05)
			struck += 1
		shake = maxf(shake, (6.0 if struck > 0 else 3.0) * minf(patch, 2.0))
		Sfx.play(self, "slam", -9.0 if struck > 0 else -15.0, 1.3 / sqrt(maxf(patch, 0.5)))


## Quake: the ground erupts under the enemy nearest your aim, and catches whatever
## stands close to it. With nobody in range it erupts a little way in front of you.
func _quake(size: float, power: float, col: Color) -> void:
	if game_time - quake_burst > 1.0:
		quake_targets.clear()
	quake_burst = game_time
	var best = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.immune:
			continue
		var rel: Vector2 = e.global_position - global_position
		var d := rel.length()
		if d > SwingBuild.QUAKE_RANGE + float(e.radius):
			continue
		# Someone new beats someone it has already erupted under in this burst.
		# Then it is the one you are pointing at: how far off your aim counts for
		# more than how far away (a radian off is worth QUAKE_AIM px), and anyone
		# behind you comes last.
		var off := absf(aim_dir.angle_to(rel)) if d > 1.0 else 0.0
		var score := d + off * QUAKE_AIM + (1000.0 if off > PI * 0.5 else 0.0) + (5000.0 if e in quake_targets else 0.0)
		if score < best_score:
			best_score = score
			best = e
	var spot := global_position + aim_dir * SwingBuild.QUAKE_EMPTY + FEET
	if best != null:
		quake_targets.append(best)
		spot = best.global_position + best._feet()
	if _strip("quake_erupt", spot, 0.0, size) == null:
		var ring := RuneFx.new()
		ring.kind = "ring"
		ring.size = SwingBuild.QUAKE_RADIUS * size
		ring.color = col
		ring.life = 0.25
		_fx_root().add_child(ring)
		ring.global_position = spot
	var dmg := float(weapon.get("damage", 8.0)) * SwingBuild.QUAKE_DAMAGE * power
	var struck := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position + e._feet() - spot
		if rel.length() > SwingBuild.QUAKE_RADIUS * size + float(e.radius):
			continue
		e.take_hit(dmg, rel.normalized() if rel.length() > 4.0 else Vector2.UP, 150.0, false, col, SwingBuild.QUAKE_STUN, 0.08)
		e.apply_stun(SwingBuild.QUAKE_STUN)
		struck += 1
	shake = maxf(shake, (9.0 if struck > 0 else 4.0) * minf(size, 1.6))
	Sfx.play(self, "slam", -5.0 if struck > 0 else -11.0, 1.1 / sqrt(size))


## Hook: one chain takes hold of one enemy and drags it to you (Darren, 19
## November; until version 33 it pulled in everyone near). It goes for the enemy
## nearest your aim within reach; On Dodge's quick chain (`quick`) for the one
## nearest you. A second chain of the same press (Twice, `again`) takes another
## enemy, never the same one, and does nothing if there is no other. A boss, like
## anything else that can't be moved, is too heavy: the chain pulls you a little
## way towards it instead. With nobody in reach the chain flies out the way you
## aim and comes back empty. `hit`: what the chain's bite does. `saved`: Saved Up,
## the enemy arrives stunned. Returns whether to write the rune's name.
func _hook(size: float, hit: float, saved: bool, col: Color, quick := false, again := false) -> bool:
	if not again:
		hook_targets.clear()
	var reach := HOOK_REACH * size
	var best = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.immune or e in hook_targets:
			continue
		var rel: Vector2 = e.global_position - global_position
		var d := rel.length()
		if d > reach + float(e.radius):
			continue
		# The one you are pointing at: how far off your aim counts for more than how
		# far away, and anyone behind you comes last. (A dodge's chain: the nearest.)
		var score := d
		if not quick:
			var off := absf(aim_dir.angle_to(rel)) if d > 1.0 else 0.0
			score += off * HOOK_AIM + (1000.0 if off > PI * 0.5 else 0.0)
		if score < best_score:
			best_score = score
			best = e
	var tip := _tip_world()
	if best == null:
		if again:
			return false
		_hook_chain(tip, null, global_position + aim_dir * reach, col)
		Sfx.play(self, "hook", -9.0, 1.3)
		return true
	hook_targets.append(best)
	var rel: Vector2 = global_position - best.global_position
	var d := rel.length()
	var toward := rel / d if d > 0.5 else -aim_dir
	_hook_chain(tip, best, Vector2.INF, col)
	_strip("hook_snag", best.global_position)
	Sfx.play(self, "hook", -4.0)
	best.take_hit(hit, toward, 0.0, false, col)
	if best.is_boss() or float(best.knock_resist) <= 0.0:
		# Too heavy: you go to it. Never right up against it.
		var travel := clampf(d - float(best.radius) - HOOK_KEEP, 0.0, HOOK_TUG)
		if travel > 1.0 and not is_down and not frozen:
			var tick := 1.0 / float(Engine.physics_ticks_per_second)
			var ticks := maxi(roundi(HOOK_TUG_TIME / tick), 1)
			lunge_dir = -toward
			lunge_timer = (float(ticks) - 0.5) * tick
			lunge_speed = travel / (float(ticks) * tick)
			_dust(global_position + FEET)
		_label("TOO HEAVY!", col)
		return false
	if best.dead:
		return true
	# Dragged all the way, however hard it is to shove: the speed that the ground
	# takes off again (1300 a second, see enemy.gd) over just that distance.
	best.knock = toward * sqrt(2.0 * 1300.0 * maxf(d - float(best.radius) - HOOK_STOP, 0.0))
	best.apply_stun(HOOK_STUN + (SwingBuild.HOOK_SAVED_STUN if saved else 0.0))
	var yank := _strip("hook_yank", best.global_position, toward.angle())
	if yank != null:
		yank.follow = best
		yank.life = 0.35
	return true


## The chain on screen: from the hammer to the enemy it has hold of, or out to
## `to` and back with nobody on it.
func _hook_chain(tip: Vector2, e, to: Vector2, col: Color) -> void:
	var chain := RuneFx.new()
	chain.kind = "chain"
	chain.from_node = self
	chain.from_offset = tip - global_position
	chain.to_node = e
	chain.to_at = to
	chain.color = col
	chain.life = 0.4 if e != null else 0.3
	_fx_root().add_child(chain)


## Bulwark: a shield for `time` seconds that blocks what comes from somewhere
## (Darren, 19 November: it only blocks; until version 33 it also stunned
## whoever hit it). It takes so many hits, one for each second it was put up
## for, and the last one breaks it: then it bursts, and the enemies around you
## are stunned for `stun` seconds. If it just runs out, nothing bursts.
func _bulwark(time: float, stun: float, col: Color) -> void:
	if is_down:
		return
	if is_instance_valid(bulwark_fx):
		bulwark_fx.queue_free()
	var was_up := bulwark_left > 0.0
	bulwark_hits = maxi(SwingBuild.bulwark_hits(time), bulwark_hits if was_up else 0)
	bulwark_left = maxf(bulwark_left, time)
	bulwark_total = bulwark_left
	bulwark_stun = maxf(stun, bulwark_stun if was_up else 0.0)
	bulwark_fx = _strip("bulwark_shield", global_position)
	if bulwark_fx != null:
		bulwark_fx.follow = self
		bulwark_fx.life = bulwark_left
	else:
		bulwark_fx = RuneFx.new()
		bulwark_fx.kind = "ring"
		bulwark_fx.size = 30.0
		bulwark_fx.color = col
		bulwark_fx.life = bulwark_left
		bulwark_fx.from_node = self
		_fx_root().add_child(bulwark_fx)
		bulwark_fx.global_position = global_position
	Sfx.play(self, "ghost", -6.0, 1.5)


func _update_bulwark(delta: float) -> void:
	if bulwark_left <= 0.0:
		return
	bulwark_left -= delta
	if bulwark_left <= 0.0:
		_end_bulwark()


## quiet: it is taken away (a new weapon, a knock-out) or broken, not run out.
func _end_bulwark(quiet := false) -> void:
	var was := bulwark_left > 0.0 or is_instance_valid(bulwark_fx)
	bulwark_left = 0.0
	bulwark_hits = 0
	if is_instance_valid(bulwark_fx):
		bulwark_fx.queue_free()
	bulwark_fx = null
	if was and not quiet:
		var gone := _strip("bulwark_end", global_position)
		if gone != null:
			gone.follow = self
		Sfx.play(self, "ghost", -12.0, 0.8)


## The shield stops a hit that came from `from`, and that is all it does to
## whoever dealt it. Each hit it stops is one it can take no more: the last
## breaks it. (An enemy leaning on it is stopped all the time, and counted once
## every BULWARK_BLOCK_GAP.)
func _bulwark_block(from: Vector2) -> void:
	if game_time - bulwark_blocked < BULWARK_BLOCK_GAP:
		return
	bulwark_blocked = game_time
	bulwark_hits -= 1
	var col: Color = SwingBuild.FITTINGS["bulwark"]["color"]
	var away := (from - global_position).normalized() if from.distance_to(global_position) > 0.5 else Vector2.RIGHT
	_strip("bulwark_block", global_position + away * 20.0 + Vector2(0, -8), away.angle())
	shake = maxf(shake, 5.0)
	Sfx.play(self, "anvil", -10.0, 1.6)
	if bulwark_hits <= 0:
		_bulwark_burst(col)
	else:
		_label("BLOCKED!", col)


## Enemies broke the shield: it bursts. Everything near you is stunned and
## shoved back a step; nothing is hurt.
func _bulwark_burst(col: Color) -> void:
	var stun := bulwark_stun
	_end_bulwark(true)
	var reach := SwingBuild.BULWARK_BURST
	var ring := RuneFx.new()
	ring.kind = "pulse"
	ring.size = reach / 140.0
	ring.color = col
	ring.life = 0.35
	_fx_root().add_child(ring)
	ring.global_position = global_position
	var gone := _strip("bulwark_end", global_position, 0.0, 1.5)
	if gone != null:
		gone.follow = self
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position - global_position
		if rel.length() > reach + float(e.radius):
			continue
		e.apply_stun(stun)
		e.knock = (rel.normalized() if rel.length() > 0.5 else Vector2.RIGHT) * 220.0 * float(e.knock_resist)
	shake = maxf(shake, 10.0)
	Sfx.play(self, "slam", -6.0, 1.5)
	_label("SHIELD BURST!", col)


# --- The staff's runes ---------------------------------------------------------------
# Orbit, Chain and Overflow are passive; Nova, Lance and Spectre go on the ability
# buttons. Overflow doesn't "fire": it changes the bolts you cast on full mana.
# Chain goes off where the finisher's bolt lands, not as it is cast. What a rune
# hits (an orb's strike, a jump of lightning, a ring, the beam) never crits and
# sets nothing else off. The buttons run on their own recharge, not on mana.

var overflow_rune := {}       # what the staff's Overflow runes come to ({} with none): see _overflow_rune
var overflow_count := 0       # Overflow bolts cast with this staff so far (Twice: every other one is cast again)
var overflow_charge := 0.0    # seconds your mana has been full in a row (Saved Up: the blast is ready after a few)
var overflow_echoes: Array = []   # Twice: the second casts on their way: [{at, kind, dir, power, info, over}]
var overflow_said := -9.0     # game_time "OVERFLOW!" was last written
var overflow_aura: Node2D = null   # the sign at the crystal while mana is full
var orbs: Array = []          # Orbit's orbs circling you, oldest first: [{until, dmg, reach, col}]
var orb_struck := -9.0        # game_time an orb last struck
var chain_jumps := 0          # Chain: every jump its lightning has made (both computers must count the same)
var lance_at := Vector2.ZERO  # where the beam ends this tick, in the world
var lance_on = null           # the enemy it is burning into (null: a wall, or nothing)
var lance_wall := false       # it ends on a wall
var lance_stage := 1          # its strength: 1 to 3
var lance_size := 1.0         # Wider: a thicker beam
var lance_fx: Node2D = null   # the beam's picture
var spectre_left := 0.0       # seconds a Spectre has left with you (0: none)
var spectre_total := 1.0      # how long this one was called for (the HUD's bar)
var spectre_power := 0.5      # what its copies do, as a share of the attack they copy
var spectre_count := 1        # ghosts with you: each copies every attack (Twice: two)
var spectre_burst := 0.0      # On Dodge: what one ghost's burst does when you dodge (0: it has none)
var spectre_by: Node2D = null # whose rune it is: you, or a teammate with a staff
var spectre_stamp := 0        # that player's weapon when they called it
var spectre_on: Node2D = null # the caster's side: who has your Spectre now
var spectre_shots: Array = [] # its copies of your arrows and bolts, on their way: [{at, arrow, fired, power, stamp}]
var spectre_swings: Array = []   # its copies of your swings, on their way (as ghost_swings, with their own "power")
var spectre_born := -9.0
var spectre_gone := -9.0
var spectre_group: CanvasGroup   # the ghost's picture: your body and weapon again, see-through
var spectre_layer: Node2D
var spectre_offset := Vector2(-20, -8)   # where the ghost stands, from you (what is on screen)
var spectre_offset2 := Vector2(20, -8)   # and a second one, at your other shoulder
var staff_back: Node2D        # the orbs when they pass behind you...
var staff_front: Node2D       # ...and in front
const ORBIT_CENTRE := Vector2(0, -4)
const MANA_FULL := 0.01       # mana within this of the top counts as full


## What the staff's Overflow runes come to together ({} with none). The bands are
## Darren's (11 November): see "Overflow bands" in the Game Bible.
##   bonus: how much harder a bolt cast on full mana hits (0.3 is +30%)
##   wide: Wider, the bolt bursts where it lands (how many times OVERFLOW_SPLASH)
##   casts: Twice, every other Overflow bolt is cast this many times
##   refund: Every Hit, mana back for each bolt that lands
##   blast: Saved Up, a rune that gives no steady bonus but turns the next bolt
##          into a blast once mana has stayed full for OVERFLOW_CHARGE seconds
##   dodge_mana: On Dodge, mana back for each dodge
func _overflow_rune() -> Dictionary:
	var out := {}
	var effects: Array = weapon.get("effects", [])
	for i in effects.size():
		var e: Dictionary = effects[i]
		if e["id"] != "overflow":
			continue
		if out.is_empty():
			out = {"bonus": 0.0, "wide": 0.0, "casts": 1, "refund": 0.0, "blast": false, "dodge_mana": 0.0, "effects": []}
		if int(e.get("every", 1)) > 1:
			out["blast"] = true
		else:
			out["bonus"] = float(out["bonus"]) + SwingBuild.OVERFLOW_DAMAGE
		if float(e["size"]) > 1.0:
			out["wide"] = maxf(float(out["wide"]), float(e["size"]) / SwingBuild.wider_size(1))
		if e.get("per_hit", false):
			out["refund"] = float(out["refund"]) + SwingBuild.OVERFLOW_REFUND
		if "dodge" in e.get("also", []):
			out["dodge_mana"] = float(out["dodge_mana"]) + SwingBuild.OVERFLOW_DODGE_MANA
		out["casts"] = maxi(int(out["casts"]), int(e["count"]))
		out["effects"].append(i)
	return out


func mana_full() -> bool:
	return mana >= SwingBuild.MANA - MANA_FULL


## Saved Up on Overflow: the blast is ready (mana has stayed full long enough).
func overflow_charged() -> bool:
	return not overflow_rune.is_empty() and overflow_rune["blast"] and mana_full() and overflow_charge >= SwingBuild.OVERFLOW_CHARGE


## A cast is leaving the staff. full: mana was full before it was paid for.
## Returns what Overflow does to it: {damage, size (both to multiply by), glow,
## splash (0: as the bolt has it), again (how many more times it is cast)}.
func _overflow_cast(full: bool) -> Dictionary:
	var out := {"damage": 1.0, "size": 1.0, "glow": false, "splash": 0.0, "again": 0}
	if overflow_rune.is_empty() or not full:
		return out
	var blast := overflow_charged()
	var bonus := float(overflow_rune["bonus"])
	if not blast and bonus <= 0.0:
		return out   # (Saved Up alone: nothing until the blast is ready)
	var wide := float(overflow_rune["wide"])
	out["damage"] = (1.0 + bonus) * (SwingBuild.OVERFLOW_BLAST if blast else 1.0)
	out["size"] = 1.0 + SwingBuild.OVERFLOW_SIZE + (SwingBuild.OVERFLOW_BLAST_SIZE if blast else 0.0)
	out["glow"] = true
	if blast:
		out["splash"] = SwingBuild.OVERFLOW_BLAST_SPLASH * maxf(wide * SwingBuild.wider_size(1), 1.0)
	elif wide > 0.0:
		out["splash"] = SwingBuild.OVERFLOW_SPLASH * wide
	# Twice: the first Overflow bolt, the third, the fifth... is cast again.
	overflow_count += 1
	if int(overflow_rune["casts"]) > 1 and overflow_count % 2 == 1:
		out["again"] = int(overflow_rune["casts"]) - 1
	overflow_charge = 0.0
	for i in overflow_rune["effects"]:
		_flash_effect(i)
	if blast:
		overflow_said = game_time
		_label("OVERFLOW BLAST!", SwingBuild.FITTINGS["overflow"]["color"])
		shake = maxf(shake, 4.0)
	elif game_time - overflow_said > 1.5:
		overflow_said = game_time
		_label("OVERFLOW +%d%%!" % roundi(bonus * 100.0), SwingBuild.FITTINGS["overflow"]["color"])
	return out


## Twice on Overflow: the same bolt again a moment later, free of mana. It is the
## rune's own bolt, so it never crits and sets nothing else off.
func _run_overflow_echoes() -> void:
	var due: Array = []
	for o in overflow_echoes:
		if float(o["at"]) <= game_time:
			due.append(o)
	for o in due:
		overflow_echoes.erase(o)
		if int(o["stamp"]) != weapon_stamp or is_down:
			continue
		var b := _bolt(str(o["kind"]), o["dir"], float(o["power"]), o["info"], false, o["over"])
		b.quiet = true
		b.crit = 0.0
		var flash := _strip("cast_flash", _crystal_world(), (o["dir"] as Vector2).angle(), 0.8)
		if flash != null:
			flash.modulate = SwingBuild.FITTINGS["overflow"]["color"]
		Sfx.play(self, "cast", -14.0, 1.25)


## Every Hit on Overflow: a bolt of yours has landed, and a little mana comes back.
func _overflow_refund() -> void:
	if overflow_rune.is_empty() or float(overflow_rune["refund"]) <= 0.0:
		return
	mana = minf(mana + float(overflow_rune["refund"]), SwingBuild.MANA)


## On Dodge on Overflow: each dodge gives a little mana back.
func _overflow_dodge() -> void:
	if overflow_rune.is_empty() or float(overflow_rune["dodge_mana"]) <= 0.0 or not _is_staff():
		return
	mana = minf(mana + float(overflow_rune["dodge_mana"]), SwingBuild.MANA)
	for i in overflow_rune["effects"]:
		_flash_effect(i)


func _drop_overflow() -> void:
	overflow_count = 0
	overflow_charge = 0.0
	overflow_echoes.clear()


## The sign at the crystal: it says the next bolt is an Overflow one. It shows
## while mana is full (with Saved Up alone, only once the blast is ready, and
## bigger for a blast).
func _update_overflow_aura() -> void:
	var ready := not overflow_rune.is_empty() and (float(overflow_rune["bonus"]) > 0.0 or overflow_charged())
	var on := ready and _is_staff() and mana_full() and not is_down and weapon_group.visible and visible
	if on and not is_instance_valid(overflow_aura):
		overflow_aura = _strip("overflow_aura", _crystal_world())
		if overflow_aura != null:
			overflow_aura.life = 100000.0
			overflow_aura.follow = self
	elif not on and is_instance_valid(overflow_aura):
		overflow_aura.queue_free()
		overflow_aura = null
	if is_instance_valid(overflow_aura):
		overflow_aura.follow_offset = _crystal_world() - global_position
		overflow_aura.scale = Vector2.ONE * (1.6 if overflow_charged() else 1.0)


## Orbit: one more orb circles you. It waits for an enemy to come near (see
## _run_orbs). Only so many at once: a new one takes the oldest one's place.
func _orbit(size: float, power: float, col: Color) -> void:
	if is_down:
		return
	while orbs.size() >= SwingBuild.ORBIT_MAX:
		orbs.pop_front()
	orbs.append({"until": game_time + SwingBuild.ORBIT_TIME, "dmg": float(weapon.get("damage", 8.0)) * SwingBuild.ORBIT_DAMAGE * power,
		"reach": SwingBuild.ORBIT_REACH * size, "col": col})
	Sfx.play(self, "click", -11.0, 1.8)


## Where orb `k` of `n` is right now, from your centre. They share one circle,
## evenly spaced, and go round together.
func _orb_place(k: int, n: int) -> Vector2:
	var turn := _orb_turn(k, n)
	return ORBIT_CENTRE + Vector2(cos(turn) * SwingBuild.ORBIT_RADIUS, sin(turn) * SwingBuild.ORBIT_RADIUS * SwingBuild.ORBIT_FLAT)


func _orb_turn(k: int, n: int) -> float:
	return TAU * game_time / SwingBuild.ORBIT_PERIOD + TAU * float(k) / float(maxi(n, 1))


## Every tick: an orb whose time is up goes, and the oldest one strikes the
## nearest enemy that has come within its reach.
func _run_orbs() -> void:
	while not orbs.is_empty() and float(orbs[0]["until"]) <= game_time:
		orbs.pop_front()
	if orbs.is_empty() or game_time - orb_struck < SwingBuild.ORBIT_GAP:
		return
	var o: Dictionary = orbs[0]
	var best = null
	var best_d := float(o["reach"])
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.immune:
			continue
		var d: float = e.global_position.distance_to(global_position) - float(e.radius)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	var from := global_position + _orb_place(0, orbs.size())
	orbs.pop_front()
	orb_struck = game_time
	var to: Vector2 = best.global_position
	var rel := to - global_position
	best.take_hit(float(o["dmg"]), rel.normalized() if rel.length() > 1.0 else aim_dir, SwingBuild.ORBIT_KNOCK, false, o["col"], SwingBuild.ORBIT_STUN, 0.04)
	# The orb darts across and bursts on them. (The hit has landed already: this
	# is only what you see.)
	var zip := _strip("orbit_orb", from)
	if zip != null:
		zip.life = 0.07
		zip.velocity = (to + Arrow.HEIGHT * 0.5 - from) / 0.07
	var pop := _strip("orbit_hit", to + Arrow.HEIGHT * 0.5)
	if pop != null:
		pop.wait = 0.06
	shake = maxf(shake, 3.0)
	Sfx.play(self, "hit", -9.0, 1.6)


## The orbs, drawn on the layer behind you while they pass behind and on the one
## in front while they pass in front.
func _draw_orbs(layer: Node2D, front: bool) -> void:
	if orbs.is_empty() or is_down:
		return
	var tex := BowArt.fx_texture("orbit_orb")
	var info := BowArt.fx("orbit_orb")
	var n := orbs.size()
	for k in n:
		if (sin(_orb_turn(k, n)) >= 0.0) != front:
			continue
		var at := _orb_place(k, n)
		# It blinks through its last second and a half, so you see it going.
		var left := float(orbs[k]["until"]) - game_time
		var tint := Color.WHITE
		if left < 1.5 and int(left * 8.0) % 2 == 1:
			tint.a = 0.35
		if tex == null or info.is_empty():
			var col: Color = orbs[k]["col"]
			layer.draw_circle(at, 5.0, Color(col.r, col.g, col.b, tint.a))
			continue
		var frames := maxi(int(info.get("frames", 6)), 1)
		var frame := int(anim_time * float(info.get("fps", 12)) + k * 2) % frames
		var fw := float(tex.get_width()) / frames
		var o: Array = info.get("origin", [fw * 0.5, tex.get_height() * 0.5])
		layer.draw_set_transform(at, 0.0, Vector2(Art.PIXEL, Art.PIXEL))
		layer.draw_texture_rect_region(tex, Rect2(-float(o[0]), -float(o[1]), fw, tex.get_height()), Rect2(frame * fw, 0, fw, tex.get_height()), tint)
	layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Chain: one of your bolts landed at `at` and caught `hits`. With the rune, a
## finisher's forks into lightning there (Every Hit: any bolt's).
func _chain_bolt(a, at: Vector2, hits: Array) -> void:
	var effects: Array = weapon.get("effects", [])
	var fired: Array = []
	var jumps := 0
	var power := 0.0
	var reach := 0.0
	for i in effects.size():
		var f: Dictionary = effects[i]
		if f["id"] != "chain" or not (f["trigger"] == "hit" or (a.finisher and f["trigger"] == "finisher")):
			continue
		if not _counts(i):
			continue
		fired.append(i)
		jumps += SwingBuild.CHAIN_JUMPS * int(f["count"])
		power = maxf(power, float(f.get("power", 1.0)))
		reach = maxf(reach, SwingBuild.CHAIN_RANGE * float(f["size"]))
	if fired.is_empty():
		return
	# (A Spectre's copy of the bolt forks too, at its share, in the ghost's colour.)
	var copied: bool = float(a.copy) > 0.0
	var col: Color = GHOST_COLOR if copied else SwingBuild.FITTINGS["chain"]["color"]
	var skip := {}
	for h in hits:
		if is_instance_valid(h):
			skip[h.get_instance_id()] = true
			break   # only the one it struck: the lightning may go on to the rest of the burst
	ghost_fx = copied
	var made := _chain_lightning(at, skip, mini(jumps, SwingBuild.CHAIN_JUMPS * SwingBuild.MAX_COUNT), reach,
		float(weapon.get("damage", 8.0)) * SwingBuild.CHAIN_DAMAGE * power * (float(a.copy) if copied else 1.0), col)
	ghost_fx = false
	if made > 0 and not copied:
		for i in fired:
			_flash_effect(i)
		_label("CHAIN!" if power <= 1.0 else "CHAIN x%s!" % str(snappedf(power, 0.5)).trim_suffix(".0"), col)


## Lightning from `from` to the nearest enemy that isn't in `struck`, then on to
## the next nearest from there, `jumps` times. Returns how many it reached.
func _chain_lightning(from: Vector2, struck: Dictionary, jumps: int, reach: float, dmg: float, col: Color) -> int:
	var taken := struck.duplicate()
	var at := from
	var made := 0
	for k in jumps:
		var best = null
		var best_d := reach
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead or e.immune or taken.has(e.get_instance_id()):
				continue
			var d: float = e.global_position.distance_to(at) - float(e.radius)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		taken[best.get_instance_id()] = true
		var to: Vector2 = best.global_position
		var gap := to - at
		best.take_hit(dmg, gap.normalized() if gap.length() > 1.0 else Vector2.UP, 70.0, false, col, 0.15, 0.02)
		# (All the jumps land on this tick. On screen each shows a moment after the last.)
		var arc := _strip("chain_arc", at + Arrow.HEIGHT * 0.5)
		if arc != null:
			arc.rotation = gap.angle()
			arc.scale = Vector2(maxf(gap.length(), 12.0) / (96.0 * Art.PIXEL), 1.0)
			arc.wait = 0.04 * float(made)
		else:
			var line := Fx.new()
			line.kind = "chain"
			line.to = gap
			line.color = col
			line.life = 0.18
			_fx_root().add_child(line)
			line.global_position = at
		var pop := _strip("chain_hit", to + Arrow.HEIGHT * 0.5)
		if pop != null:
			pop.wait = 0.04 * float(made)
		at = to
		made += 1
	if made > 0:
		chain_jumps += made
		shake = maxf(shake, 4.0)
		Sfx.play(self, "cast", -6.0, 1.8)
	return made


## Nova: a ring bursts out from `at`. Everything inside it is hit and thrown
## outwards. It is an oval, like everything that lies on the floor.
func _nova(size: float, power: float, col: Color, at: Vector2) -> void:
	var rad := Vector2(SwingBuild.NOVA_RADIUS, SwingBuild.NOVA_RADIUS * SwingBuild.NOVA_FLAT) * size
	var centre := at + FEET
	# (The picture is drawn for a ring that reaches 60 art pixels to the sides.)
	if _strip("nova_ring", centre, 0.0, rad.x / (60.0 * Art.PIXEL)) == null:
		var ring := RuneFx.new()
		ring.kind = "ring"
		ring.size = rad.x
		ring.color = col
		ring.life = 0.3
		_fx_root().add_child(ring)
		ring.global_position = centre
	var dmg := float(weapon.get("damage", 8.0)) * SwingBuild.NOVA_DAMAGE * power
	var struck := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = e.global_position + e._feet() - centre
		if (rel / (rad + Vector2.ONE * float(e.radius))).length_squared() > 1.0:
			continue
		e.take_hit(dmg, rel.normalized() if rel.length() > 4.0 else aim_dir, SwingBuild.NOVA_KNOCK, false, col, SwingBuild.NOVA_STUN, 0.06)
		struck += 1
	shake = maxf(shake, (8.0 if struck > 0 else 4.0) * minf(size, 1.6))
	squash = Vector2(1.08, 0.93)
	Sfx.play(self, "shockwave", -4.0 if struck > 0 else -9.0, 1.3 / sqrt(size))


## Is Lance's beam being held?
func _beaming() -> bool:
	var list := _abilities()
	return hold_button >= 0 and hold_button < list.size() and str(list[hold_button]["id"]) == "lance"


## Where a beam from here along `dir` stops: at the first enemy on its line, at a
## wall, or at the end of the staff's range. {end, enemy (or null), wall}
func _lance_scan(dir: Vector2, size: float) -> Dictionary:
	var from := global_position
	var reach := float(weapon.get("range", SwingBuild.STAFF_RANGE))
	var wall := false
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * reach, Arrow.WALLS)
	var stop := get_world_2d().direct_space_state.intersect_ray(q)
	if not stop.is_empty():
		reach = from.distance_to(stop["position"])
		wall = true
	var best = null
	var half := SwingBuild.LANCE_WIDTH * size
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.immune:
			continue
		var rel: Vector2 = e.global_position - from
		var along := rel.dot(dir)
		var side := absf(rel.dot(dir.orthogonal()))
		var r: float = float(e.radius) + half
		if side > r or along + r < 0.0:
			continue
		var enter := maxf(along - sqrt(r * r - side * side), 0.0)
		if enter < reach:
			reach = enter
			best = e
	return {"end": from + dir * reach, "enemy": best, "wall": wall and best == null}


## One pulse of the beam along your aim: whoever it is burning into is hurt.
## stage: its strength, 1 to 3. Returns whether it hit someone.
func _lance_pulse(size: float, power: float, col: Color, stage: int) -> bool:
	var scan := _lance_scan(aim_dir, size)
	lance_at = scan["end"]
	lance_on = scan["enemy"]
	lance_wall = scan["wall"]
	lance_stage = stage
	lance_size = size
	var e = scan["enemy"]
	if e == null:
		Sfx.play(self, "cast", -15.0, 0.7 + 0.15 * float(stage))
		return false
	e.take_hit(float(weapon.get("damage", 8.0)) * SwingBuild.LANCE_DAMAGE * float(stage) * power, aim_dir, 30.0 * float(stage), false, col, 0.12, 0.0)
	shake = maxf(shake, 1.5 + 1.5 * float(stage))
	Sfx.play(self, "cast", -10.0, 0.7 + 0.15 * float(stage))
	return true


## Every tick while the beam is held: it follows your aim, so its picture ends
## where it would hit now. When the hold is over the picture goes.
func _update_lance() -> void:
	if not _beaming():
		_end_lance()
		return
	var scan := _lance_scan(aim_dir, lance_size)
	lance_at = scan["end"]
	lance_on = scan["enemy"]
	lance_wall = scan["wall"]
	if not is_instance_valid(lance_fx):
		lance_fx = _beam_node()
		lance_fx.draw.connect(_draw_lance)


func _end_lance() -> void:
	if is_instance_valid(lance_fx):
		lance_fx.queue_free()
	lance_fx = null


## A layer for a beam's picture: above everything and never dimmed, like the
## other effects. It sits at the world's origin, so it is drawn on in world places.
func _beam_node() -> Node2D:
	var n := Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	n.material = add
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_fx_root().add_child(n)
	n.z_index = 30
	n.global_position = Vector2.ZERO
	return n


func _draw_lance() -> void:
	if not is_instance_valid(lance_fx):
		return
	_draw_beam(lance_fx, _crystal_world(), lance_at + Arrow.HEIGHT * 0.6, lance_stage, lance_size, lance_on != null or lance_wall)


## A beam from `from` to `to`: the art's strip for its strength laid end to end,
## a flare where it starts and (capped) where it burns in.
func _draw_beam(layer: Node2D, from: Vector2, to: Vector2, stage: int, size: float, capped: bool) -> void:
	var d := to - from
	var length := d.length()
	if length < 2.0:
		return
	var name := "lance_beam_%d" % clampi(stage, 1, SwingBuild.LANCE_STAGES)
	var tex := BowArt.fx_texture(name)
	var info := BowArt.fx(name)
	if tex == null or info.is_empty():
		var col: Color = SwingBuild.FITTINGS["lance"]["color"]
		layer.draw_line(from, to, col, (2.0 + 2.0 * float(stage)) * size)
	else:
		var n := maxi(int(info.get("frames", 4)), 1)
		var frame := int(anim_time * float(info.get("fps", 16))) % n
		var fw := float(tex.get_width()) / n
		var fh := float(tex.get_height())
		var o: Array = info.get("origin", [0, fh * 0.5])
		var art_len := length / Art.PIXEL
		layer.draw_set_transform(from, d.angle(), Vector2(Art.PIXEL, Art.PIXEL * size))
		var x := 0.0
		while x < art_len:
			var w := minf(fw, art_len - x)
			layer.draw_texture_rect_region(tex, Rect2(x, -float(o[1]), w, fh), Rect2(frame * fw, 0, w, fh))
			x += fw
		layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_fx_frame(layer, "lance_start", from, 0.8 + 0.2 * float(stage))
	if capped:
		_draw_fx_frame(layer, "lance_end", to, (0.6 + 0.2 * float(stage)) * sqrt(size))


## The frame a looping effect strip is on right now, drawn on `layer` at `at`.
func _draw_fx_frame(layer: Node2D, name: String, at: Vector2, size := 1.0) -> void:
	var tex := BowArt.fx_texture(name)
	var info := BowArt.fx(name)
	if tex == null or info.is_empty():
		return
	var n := maxi(int(info.get("frames", 4)), 1)
	var frame := int(anim_time * float(info.get("fps", 16))) % n
	var fw := float(tex.get_width()) / n
	var o: Array = info.get("origin", [fw * 0.5, tex.get_height() * 0.5])
	layer.draw_set_transform(at, 0.0, Vector2(Art.PIXEL, Art.PIXEL) * size)
	layer.draw_texture_rect_region(tex, Rect2(-float(o[0]), -float(o[1]), fw, tex.get_height()), Rect2(frame * fw, 0, fw, tex.get_height()))
	layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## On Dodge on Lance: one flash of the beam at full strength, there and gone.
func _lance_flash(size: float, power: float, col: Color) -> void:
	var kept := [lance_at, lance_on, lance_wall, lance_stage, lance_size]
	var struck := _lance_pulse(size, power * SwingBuild.LANCE_DODGE, col, SwingBuild.LANCE_STAGES)
	var from := global_position + Arrow.HEIGHT
	var to: Vector2 = lance_at + Arrow.HEIGHT * 0.6
	var capped: bool = struck or lance_wall
	# (A beam that is being held keeps its own end.)
	lance_at = kept[0]
	lance_on = kept[1]
	lance_wall = kept[2]
	lance_stage = kept[3]
	lance_size = kept[4]
	var n := _beam_node()
	n.draw.connect(func() -> void: _draw_beam(n, from, to, SwingBuild.LANCE_STAGES, size, capped))
	var fade := n.create_tween()
	fade.tween_property(n, "modulate:a", 0.0, 0.2)
	fade.tween_callback(n.queue_free)


## Who a Spectre goes to: the teammate you are aiming at, if one is near enough
## and close enough to your aim; otherwise you.
func _spectre_target() -> Node2D:
	var best: Node2D = self
	var best_off := SwingBuild.SPECTRE_CONE
	for p in get_tree().get_nodes_in_group("player"):
		if p == self or not is_instance_valid(p) or p.is_down:
			continue
		var rel: Vector2 = p.global_position - global_position
		if rel.length() > SwingBuild.SPECTRE_AIM or rel.length() < 1.0:
			continue
		var off := absf(aim_dir.angle_to(rel))
		if off < best_off:
			best_off = off
			best = p
	return best


## Calls the Spectre from its button. Every Spectre rune on the staff is one copy
## of each attack: a second rune counts like a Twice, and the longest and
## strongest of them win.
func _summon_spectre(effects: Array) -> void:
	var count := 0
	var time := 0.0
	var power := 0.0
	var bursts := false
	for i in effects:
		var e: Dictionary = weapon["effects"][i]
		count += int(e["count"])
		time = maxf(time, SwingBuild.spectre_time(float(e["size"])))
		power = maxf(power, SwingBuild.spectre_power(float(e.get("power", 1.0))))
		bursts = bursts or "dodge" in e.get("also", [])
		_flash_effect(i)
	# On Dodge: a burst worth a bolt of this staff from a half-strength ghost, two from a whole one.
	var burst := float(weapon.get("damage", 8.0)) * SwingBuild.SPECTRE_BURST * power / SwingBuild.SPECTRE_POWER if bursts else 0.0
	var who := _spectre_target()
	who.take_spectre(self, time, power, clampi(count, 1, SwingBuild.MAX_COUNT), burst)
	_label("SPECTRE!" if power < 1.0 else "SPECTRE x2!", GHOST_COLOR)


## A Spectre comes to stand with you, called by `by` (yourself, or a teammate):
## for `time` seconds it copies your basic attacks at `power` of their strength.
## count: how many ghosts (Twice: two).  burst: On Dodge, what each one's burst
## does when you dodge (0: none).
func take_spectre(by: Node2D, time: float, power: float, count: int, burst := 0.0) -> void:
	if is_down:
		return
	var fresh := spectre_left <= 0.0
	if not fresh and is_instance_valid(spectre_by) and spectre_by != by and spectre_by.spectre_on == self:
		spectre_by.spectre_on = null   # one ghost each: the new one takes the old one's place
	spectre_power = power if fresh or time >= spectre_left else maxf(spectre_power, power)
	spectre_count = count if fresh or time >= spectre_left else maxi(spectre_count, count)
	spectre_burst = burst if fresh or time >= spectre_left else maxf(spectre_burst, burst)
	spectre_left = maxf(spectre_left, time)
	spectre_total = spectre_left
	spectre_by = by
	spectre_stamp = by.weapon_stamp
	by.spectre_on = self
	if fresh:
		spectre_born = game_time
		spectre_gone = -9.0
		for off in _spectre_places():
			var arrive := _strip("spectre_appear", global_position + off + FEET)
			if arrive != null:
				arrive.follow = self
				arrive.follow_offset = off + FEET
	Sfx.play(self, "ghost", -5.0, 1.25)


## The Spectre goes: its time is up, you were knocked out, or the staff it came
## from was changed. quiet: no picture or sound.
func _end_spectre(quiet := false) -> void:
	var was := spectre_left > 0.0
	spectre_left = 0.0
	spectre_burst = 0.0
	if is_instance_valid(spectre_by) and spectre_by.spectre_on == self:
		spectre_by.spectre_on = null
	spectre_by = null
	if not was or quiet:
		spectre_gone = -9.0
		return
	spectre_gone = game_time
	for off in _spectre_places():
		var leave := _strip("spectre_appear", global_position + off + FEET)
		if leave != null:
			leave.backwards = true
			leave.follow = self
			leave.follow_offset = off + FEET
	Sfx.play(self, "ghost", -11.0, 0.8)


## How much of its time the Spectre you called has left, 0 to 1 (0: it isn't out).
func spectre_out() -> float:
	if not is_instance_valid(spectre_on) or spectre_on.spectre_by != self or float(spectre_on.spectre_left) <= 0.0:
		return 0.0
	return clampf(float(spectre_on.spectre_left) / maxf(float(spectre_on.spectre_total), 0.1), 0.0, 1.0)


## Where the ghosts stand, from you: one at your shoulder, a second at the other.
func _spectre_places() -> Array:
	return [spectre_offset, spectre_offset2] if spectre_count > 1 else [spectre_offset]


## On Dodge on Spectre (Darren, 11 November): the ghost dodges with you and
## leaves a burst of ghostly damage where it stood. Two ghosts leave two.
func _spectre_dodge() -> void:
	if spectre_left <= 0.0 or spectre_burst <= 0.0 or is_down:
		return
	var at := global_position
	var dmg := spectre_burst * float(mini(spectre_count, 2))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.immune:
			continue
		var rel: Vector2 = e.global_position - at
		if rel.length() > SwingBuild.SPECTRE_BURST_RADIUS + float(e.radius):
			continue
		e.take_hit(dmg, rel.normalized() if rel.length() > 1.0 else Vector2.UP, 260.0, false, GHOST_COLOR, 0.3, 0.03)
	var pop := _strip("burst_hit", at + Arrow.HEIGHT * 0.5, 0.0, SwingBuild.SPECTRE_BURST_RADIUS / 56.0)
	if pop != null:
		pop.modulate = GHOST_COLOR
	var gone := _strip("spectre_appear", at + FEET)
	if gone != null:
		gone.backwards = true
	shake = maxf(shake, 4.0)
	Sfx.play(self, "ghost", -8.0, 1.5)
	if is_instance_valid(spectre_by) and spectre_by.has_method("_spectre_said"):
		spectre_by._spectre_said()


## Your ghost has burst behind a dodge: the rune's slots light up on your staff.
func _spectre_said() -> void:
	var effects: Array = weapon.get("effects", [])
	for i in effects.size():
		if effects[i]["id"] == "spectre" and "dodge" in effects[i].get("also", []):
			_flash_effect(i)


## Every tick: the Spectre's time runs down and its copies that are due go off.
func _run_spectre(delta: float) -> void:
	_run_overflow_echoes()
	if spectre_left > 0.0:
		if spectre_left <= delta or is_down or not is_instance_valid(spectre_by) or int(spectre_by.weapon_stamp) != spectre_stamp:
			_end_spectre()
		else:
			spectre_left -= delta
	if is_down:
		spectre_swings.clear()
		spectre_shots.clear()
		return
	var due: Array = []
	for g in spectre_swings:
		if float(g["at"]) <= game_time:
			due.append(g)
	for g in due:
		spectre_swings.erase(g)
		_ghost_swing(g)
	due = []
	for s in spectre_shots:
		if float(s["at"]) <= game_time:
			due.append(s)
	for s in due:
		spectre_shots.erase(s)
		_spectre_shot(s)


## An arrow or a bolt of yours has just left: a Spectre with you looses it again
## a moment later. fired: the runes its leaving set off (a finisher's).
func _spectre_copies(a, fired: Array) -> void:
	if spectre_left <= 0.0:
		return
	var props := {}
	for k in ["dir", "speed", "left", "damage", "knock", "stun", "freeze", "heavy", "finisher", "kind", "crit", "crit_damage",
			"pierce", "pierce_power", "half_width", "streak", "bolt", "splash", "quiet", "halo", "big"]:
		props[k] = a.get(k)
	for n in spectre_count:
		spectre_shots.append({"at": game_time + SwingBuild.SPECTRE_DELAY + float(n) * SwingBuild.SPECTRE_GAP, "arrow": props,
			"fired": fired, "power": spectre_power, "stamp": weapon_stamp})


## The Spectre's copy of one arrow or bolt: the same one again along the same
## line, in the ghost's colour, at its share of the damage. It costs no mana.
func _spectre_shot(s: Dictionary) -> void:
	if int(s["stamp"]) != weapon_stamp:
		return
	var props: Dictionary = s["arrow"]
	var share := float(s["power"])
	var a := Arrow.new()
	a.shooter = self
	a.stamp = weapon_stamp
	for k in props:
		a.set(k, props[k])
	a.damage = float(props["damage"]) * share
	a.knock = float(props["knock"]) * GHOST_SHOVE
	a.stun = float(props["stun"]) * GHOST_SHOVE
	a.freeze = float(props["freeze"]) * GHOST_SHOVE
	a.copy = share
	a.color = GHOST_COLOR
	get_parent().add_child(a)
	if str(props["bolt"]) == "":
		a.material = _ghost_glow()
	a.global_position = global_position
	a.reset_physics_interpolation()
	Sfx.play(self, "cast" if str(props["bolt"]) != "" else "bow", -17.0, 1.5)
	if props["finisher"] and not props["quiet"]:
		_trigger("finisher", [], {"power": share, "fired": s["fired"]})


## What _trigger is told when a Spectre's arrow or bolt is doing the triggering.
## (Its copies of runes with Saved Up keep their own count.)
func _copy_ghost(a) -> Dictionary:
	if float(a.copy) <= 0.0:
		return {}
	return {"power": float(a.copy), "fired": [], "counts": true}


## Is the Spectre on screen? It appears partway through its arriving picture
## and stays for the first moments of its leaving one.
func _spectre_shown() -> bool:
	if spectre_left > 0.0:
		return game_time - spectre_born >= 3.0 / 16.0
	return game_time - spectre_gone < 2.0 / 16.0


## Where the Spectre stands: at your shoulder, a little behind, whichever way you
## face. It eases there as you turn.
func _update_spectre(delta: float) -> void:
	var shown := _spectre_shown() and not is_down and rise_timer <= 0.0
	spectre_group.visible = shown
	if spectre_left <= 0.0 and not shown:
		return
	# (Two ghosts stand a little wider apart, one at each shoulder.)
	var side := 30.0 if spectre_count > 1 else 24.0
	var want := (face_dir.orthogonal() * side - face_dir * 9.0) * Vector2(1.0, 0.75)
	spectre_offset = spectre_offset.lerp(want, 1.0 - exp(-9.0 * delta))
	var want2 := (-face_dir.orthogonal() * side - face_dir * 9.0) * Vector2(1.0, 0.75)
	spectre_offset2 = spectre_offset2.lerp(want2, 1.0 - exp(-9.0 * delta))
	if not shown:
		return
	spectre_group.show_behind_parent = spectre_offset.y < 0.0
	# It shimmers, and blinks through its last second and a half so you see it going.
	var solid := 0.85 + 0.15 * sin(anim_time * 5.0)
	if spectre_left > 0.0 and spectre_left < 1.5:
		solid = 0.95 if int(spectre_left * 8.0) % 2 == 0 else 0.45
	var scale_px := maxf(floorf(float(get_window().size.y) / 360.0), 1.0)
	(spectre_group.material as ShaderMaterial).set_shader_parameter("px", scale_px)
	(spectre_group.material as ShaderMaterial).set_shader_parameter("strength", solid)
	spectre_layer.queue_redraw()


## The Spectre: your own body and weapon drawn again beside you, once for each
## ghost. (Its CanvasGroup's material turns the whole picture see-through and
## ghost-coloured.)
func _draw_spectre() -> void:
	var b := _body_now()
	var behind: bool = weapon_group.show_behind_parent
	for off in _spectre_places():
		if behind:
			_draw_weapon_on(spectre_layer, off, {})
		if b.is_empty():
			spectre_layer.draw_circle(off, RADIUS, Color.WHITE)
		else:
			spectre_layer.draw_set_transform((off as Vector2) + (b["at"] as Vector2), b["angle"], b["scale"])
			spectre_layer.draw_texture_rect_region(b["tex"], Rect2(-_body_origin(), b["src"].size), b["src"])
			spectre_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not behind:
			_draw_weapon_on(spectre_layer, off, {})


## How far this move reaches from the player's centre.
func _move_reach(info: Dictionary) -> float:
	if not weapon.has("blade"):
		return float(info.get("range", 74.0)) * float(weapon.get("reach", 1.0)) * (1.0 + float(weapon.get("area", 0.0)))
	return _hit_reach() * float(info.get("reach", 1.0))


## The enemies a move catches when swung from here towards `dir`:
## [[distance along the swing, enemy, knock direction]].
func _swing_hits(info: Dictionary, dir: Vector2, reach: float) -> Array:
	var shape := str(info["shape"])
	var half_arc := deg_to_rad(float(info.get("arc", 120.0)) * 0.5)
	var found: Array = []
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
			"impact":
				hit = (rel - dir * reach * IMPACT_AT).length() <= float(weapon.get("impact", SwingBuild.HAMMER_IMPACT)) + r
			_:
				# The arc only has to touch the enemy's body, not reach its middle.
				var d := rel.length()
				var body := asin(minf(r / maxf(d, 1.0), 1.0))
				hit = d <= reach + r and (d < r + RADIUS or absf(dir.angle_to(rel)) <= half_arc + body)
		if hit:
			var kdir := rel.normalized() if rel.length() > 0.01 else dir
			if shape == "line":
				kdir = dir
			elif shape == "impact":
				# Thrown out from where the head came down.
				var from_patch := rel - dir * reach * IMPACT_AT
				kdir = from_patch.normalized() if from_patch.length() > 6.0 else dir
			found.append([rel.dot(dir) if shape == "line" else rel.length(), e, kdir])
	# A thrust stops after so many enemies, nearest first (the rapier goes through
	# to a second one, the dagger's stab stays in the first).
	if info.has("max_hits") and found.size() > int(info["max_hits"]):
		found.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
		found.resize(int(info["max_hits"]))
	return found


## swing: the swing's shape ({shape, dir, reach, half_arc, width}), to tell whether
## it reaches a Weak Point mark on the enemy. Empty for anything that isn't a swing.
## ghost: Ghostwield's copy of a hit, in the ghost's colour (it leaves marks alone:
## a mark is for your own sword).
## spark: an effect strip to show where it lands in place of the blade's spark
## (an arrow's). A crit always gets the crit spark.
func _hit_enemy(e, dmg: float, kdir: Vector2, knock: float, stun := 0.12, freeze := 0.05, swing := {}, ghost := false, shot = null) -> void:
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
	# An arrow carries its bow's luck with it (`shot` is the arrow): the weapon in
	# the hand may have changed while it flew.
	var crit_chance := float(shot.crit) if shot != null else float(weapon.get("crit", 0.05))
	var crit_times := float(shot.crit_damage) if shot != null else float(weapon.get("crit_damage", 1.5))
	var crit := Sim.chance() < crit_chance
	var final := dmg * (crit_times if crit else 1.0)
	e.take_hit(final, kdir, knock, crit, GHOST_COLOR if ghost else weapon.get("hit_color", Color.WHITE), stun, freeze)
	# A spark where the blade lands, thrown the way the hit goes.
	var spark_at: Vector2 = e.global_position - kdir * float(e.radius) * 0.4
	var spark: Node2D = null
	if shot != null and not crit:
		spark = _strip("bolt_hit" if shot.bolt != "" else "arrow_hit", spark_at + Arrow.HEIGHT * 0.5, kdir.angle())
		if spark != null and shot.bolt != "":
			spark.modulate = shot.color
	elif _is_hammer() and not crit and not ghost:
		spark = Art.play_piece(self, "hammer_hit", spark_at, kdir.angle())
	if spark == null:
		spark = Art.play_piece(self, "hit_spark_crit" if crit else "hit_spark", spark_at, kdir.angle())
	if ghost and spark != null:
		spark.material = _ghost_glow()
	_apply_elements(e, final)


# --- Swing path runes -----------------------------------------------------------
# A rune fires on its trigger (finisher, hit, kill). Twice queues repeats a beat
# apart. Identical runes firing at the same moment merge into one bigger effect.

## Returns the runes it set off (their places in the sword's effects).
## ghost: Ghostwield's copy of a swing is doing the triggering, {power, fired}:
## the runes go off again at that share of their strength, as ghosted effects.
func _trigger(trigger: String, hits: Array, ghost: Dictionary = {}) -> Array:
	var fired: Array = []
	var effects: Array = weapon.get("effects", [])
	for i in effects.size():
		var e: Dictionary = effects[i]
		if e["trigger"] != trigger and not (trigger in e.get("also", [])):
			continue
		# The bow's passive runes don't fire like this (see "The bow's runes"): only
		# a dodge sends a Ricochet through here.
		# Nor do Momentum and Stagger, which build hit by hit (see "The hammer's runes").
		# Nor does Overflow, and a Chain forks where a bolt lands (see "The staff's runes").
		if e["id"] in ["pierce", "steady_aim", "momentum", "stagger", "overflow"] or (e["id"] in ["ricochet", "chain"] and trigger != "dodge"):
			continue
		# Saved Up: count the triggers and only fire on every third one. The ghost
		# doesn't count: it copies a saved-up rune when the swing it copies set it off.
		# (A Spectre's arrow or bolt lands in its own time, so those keep their own count.)
		var every := int(e.get("every", 1))
		if every > 1:
			if not ghost.is_empty() and not ghost.get("counts", false):
				if not (i in ghost.get("fired", [])):
					continue
			else:
				var key := i if ghost.is_empty() else -1 - i
				rune_counts[key] = int(rune_counts.get(key, 0)) + 1
				if int(rune_counts[key]) % every != 0:
					continue
		fired.append(i)
		var power := float(e.get("power", 1.0)) * (1.0 if ghost.is_empty() else float(ghost["power"]))
		# (Twice on Weak Point is two marks from one firing, not two firings.)
		# (And on Ricochet it is two jumps, not two arrows.)
		# (On Dodge on Hook: its quick chain goes out as the dodge ends, so what it
		# drags comes to where you now stand.)
		var wait := DODGE_TIME if trigger == "dodge" and str(e["id"]) == "hook" else 0.0
		for n in (1 if _fires_once(str(e["id"])) else int(e["count"])):
			_queue_rune(i, game_time + wait + n * _repeat_gap(str(e["id"]), trigger), float(e["size"]), hits, power, false, trigger, not ghost.is_empty(), n)
	return fired


## held: one turn of a hold rune (it follows the spin, and only the first turn is named).
## why: what set it off ("finisher", "hit", "kill", "dodge", or "" for its button).
## ghost: Ghostwield's copy of the rune (kept apart from the real one).
## nth: which go of a Twice this is, from 0 (Hook's second chain takes another enemy).
func _queue_rune(effect: int, at: float, size: float, hits: Array, power := 1.0, held := false, why := "", ghost := false, nth := 0) -> void:
	var id: String = weapon["effects"][effect]["id"]
	# (where: the place the swing that set it off landed, for an Aftershock.)
	for q in rune_queue:
		if q["effect"] != effect and weapon["effects"][q["effect"]]["id"] == id and absf(float(q["at"]) - at) < 0.03 and q["held"] == held and q["ghost"] == ghost:
			q["size"] = minf(maxf(float(q["size"]), size) * 1.3, SwingBuild.MAX_SIZE)
			q["power"] = float(q["power"]) + power
			q["merged"].append(effect)
			return
	rune_queue.append({"at": at, "effect": effect, "size": size, "power": power, "hits": hits.duplicate(), "merged": [], "held": held, "why": why, "ghost": ghost, "where": last_impact, "nth": nth})


func _run_rune_queue() -> void:
	var due: Array = []
	for q in rune_queue:
		if float(q["at"]) <= game_time:
			due.append(q)
	for q in due:
		rune_queue.erase(q)
		_fire_rune(q)


## Called by main whenever an enemy dies.
## A number was changed in the lab: take the new health (the same share of it
## as before), and no more mana or dodges than there now are.
func lab_changed() -> void:
	var frac := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = MAX_HP
	hp = max_hp * frac
	mana = minf(mana, SwingBuild.MANA)
	dodge_charges = mini(dodge_charges, DODGE_MAX_CHARGES)


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
static var SHOCKWAVE_DAMAGE := 0.4
static var HOOK_DAMAGE := 0.3
static var HOOK_REACH := 260.0     # how far away its chain takes hold of an enemy
static var HOOK_STUN := 0.5          # the enemy it drags can't act for this long: about as long as the drag takes
static var HOOK_TUG := 60.0          # a boss is too heavy to drag: the chain pulls you this far towards it instead
const HOOK_AIM := 300.0              # picking its enemy: being a radian off the aim counts as this many px further away
const HOOK_STOP := 31.0              # the dragged enemy stops with its edge about this far from your middle
const HOOK_KEEP := 34.0              # a tug never brings you nearer than this to the boss's edge
const HOOK_TUG_TIME := 0.15          # how long a tug takes
static var WHIRLWIND_DAMAGE := 0.9   # for each turn


func _fire_rune(q: Dictionary) -> void:
	if int(q["effect"]) >= weapon.get("effects", []).size():
		return
	# A ghosted effect (Ghostwield's copy of a passive rune) is the same effect in
	# the ghost's colour: everything put on screen while this is set gets tinted.
	ghost_fx = q.get("ghost", false)
	_fire_rune_now(q)
	ghost_fx = false


func _fire_rune_now(q: Dictionary) -> void:
	var effect: int = q["effect"]
	var ghost: bool = q.get("ghost", false)
	if not ghost:
		_flash_effect(effect)
		for m in q["merged"]:
			_flash_effect(m)
	var id: String = weapon["effects"][effect]["id"]
	var size: float = q["size"]
	var power: float = q["power"]
	var col: Color = GHOST_COLOR if ghost else SwingBuild.FITTINGS[id]["color"]
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
			if ghost:
				w.material = _ghost_glow()
			w.global_position = global_position + aim_dir * 30.0
			_strip("shockwave_burst", global_position + aim_dir * 40.0, 0.0, size)
			shake = maxf(shake, (4.0 if ghost else 9.0) * size)
			Sfx.play(self, "shockwave", -10.0 if ghost else -2.0, (1.4 if ghost else 1.0) / sqrt(size))
		"hook":
			# One chain, one enemy (Darren, 19 November). Saved Up doesn't make the
			# chain's own hit stronger: what it drags in arrives stunned. On Dodge's
			# is a quick one, at half strength.
			var dodged: bool = q.get("why", "") == "dodge"
			var saved := int(weapon["effects"][effect].get("every", 1)) > 1
			var share := (power / SwingBuild.SAVED_UP_POWER if saved else power) * (SwingBuild.DODGE_SHARE if dodged else 1.0)
			if not _hook(size, dmg * HOOK_DAMAGE * share, saved, col, dodged, int(q.get("nth", 0)) > 0):
				return
		"shards":
			# Out of the back of each enemy hit (or from you the way you aim, on a
			# dodge), a cone of metal shards that fly straight.
			var starts: Array = []
			for h in q["hits"]:
				if is_instance_valid(h):
					starts.append(h)
			if starts.is_empty():
				starts.append(self)
			var splinter: bool = weapon["effects"][effect].get("splinter", false)
			for s in starts:
				_shards(s, size, power, dmg, col, splinter)
			Sfx.play(self, "cleave", -13.0 if ghost else -6.0, 1.5 if ghost else 1.2)
		"leap":
			if not _leap(size, power, col):
				return
		"weak_point":
			var count: int = int(weapon["effects"][effect]["count"]) + (q["merged"] as Array).size()
			if not _weak_point(q["hits"], count, size, power, col, ghost):
				return
		"ghostwield":
			# (Its button calls the ghost straight away, so this is On Dodge.)
			_ghost_dodge_cut(power)
			return
		"ricochet":
			# (An arrow's hit sends its own on, see _ricochet. This is On Dodge: one
			# leaps from you to the nearest enemy.)
			var f: Dictionary = weapon["effects"][effect]
			if _bounce(global_position, {}, dmg * SwingBuild.RICOCHET_DAMAGE * power, mini(int(f["count"]) + (q["merged"] as Array).size(), SwingBuild.MAX_COUNT),
					SwingBuild.RICOCHET_RANGE * size, f.get("splinter", false), col, str(weapon.get("arrows", "wooden_arrows"))) == 0:
				return
		"volley":
			_volley(size, power * (SwingBuild.DODGE_SHARE if q.get("why", "") == "dodge" else 1.0), col)
		"snipe":
			# On a dodge it is a quick one: not drawn at all, and half of that.
			if q.get("why", "") == "dodge":
				_snipe_shot(power * SwingBuild.SNIPE_EARLY * SwingBuild.DODGE_SHARE, col)
			else:
				_snipe_shot(power, col)
				if snipe_perfect:
					_label("PERFECT SNIPE!", col)
					return
		"aftershock":
			# Where the swing landed (On Dodge: where the dodge began). Every Hit's are
			# small ones, Saved Up's huge.
			var f: Dictionary = weapon["effects"][effect]
			var dodged: bool = q.get("why", "") == "dodge"
			var patch := size * (SwingBuild.AFTERSHOCK_HUGE if power >= SwingBuild.SAVED_UP_POWER else 1.0)
			if f["trigger"] == "hit" and not dodged:
				patch *= SwingBuild.AFTERSHOCK_SMALL
			_rumble(dodge_from + FEET if dodged else q.get("where", last_impact), patch, dmg * SwingBuild.AFTERSHOCK_DAMAGE * power, col)
		"quake":
			_quake(size, power * (SwingBuild.DODGE_SHARE if q.get("why", "") == "dodge" else 1.0), col)
		"bulwark":
			# (Twice: its burst stuns twice as long.)
			var f: Dictionary = weapon["effects"][effect]
			var times := mini(int(f["count"]) + (q["merged"] as Array).size(), SwingBuild.MAX_COUNT)
			_bulwark(SwingBuild.bulwark_time(size, power, SwingBuild.BULWARK_DODGE if q.get("why", "") == "dodge" else -1.0), SwingBuild.BULWARK_STUN * times, col)
		"orbit":
			_orbit(size, power, col)
		"chain":
			# (A bolt that lands forks by itself, see _chain_bolt. This is On Dodge: the
			# lightning goes out from you.)
			var f: Dictionary = weapon["effects"][effect]
			var jumps := SwingBuild.CHAIN_JUMPS * mini(int(f["count"]) + (q["merged"] as Array).size(), SwingBuild.MAX_COUNT)
			if _chain_lightning(global_position, {}, jumps, SwingBuild.CHAIN_RANGE * size, dmg * SwingBuild.CHAIN_DAMAGE * power, col) == 0:
				return
		"nova":
			# (On Dodge: a half one where the dodge began.)
			var dodged: bool = q.get("why", "") == "dodge"
			_nova(size, power * (SwingBuild.DODGE_SHARE if dodged else 1.0), col, dodge_from if dodged else global_position)
		"lance":
			if q.get("why", "") == "dodge":
				_lance_flash(size, power, col)
			else:
				# One pulse of the beam. It grows a step for each third of a full hold.
				var turns := int(_abilities()[hold_button]["turns"]) if _beaming() else int(SwingBuild.FITTINGS["lance"]["turns"])
				var stage := SwingBuild.lance_stage(hold_turns, turns)
				var grew := hold_turns > 1 and stage > lance_stage
				_lance_pulse(size, power, col, stage)
				if hold_turns > 1:
					# (Only the first pulse of a hold is named, and each time it grows.)
					if grew:
						_label("LANCE x%d!" % stage, col)
					return
		"spectre":
			# (Its button calls it straight away, so this is On Dodge. That belongs to
			# the ghost, not to this dodge: whoever has it leaves a burst behind when
			# they dodge. See _spectre_dodge.)
			return
		"arrow_rain":
			var wide := SwingBuild.rain_scale(size)
			# (Saved Up: much heavier arrows, and they pin what they hit.)
			if q.get("why", "") == "dodge":
				_rain(dodge_from, SwingBuild.RAIN_DODGE_TIME, wide * SwingBuild.RAIN_DODGE_SIZE, dmg * SwingBuild.RAIN_DAMAGE * power, col, power >= 3.0)
			else:
				_rain(_aim_point(SwingBuild.RAIN_REACH), float(SwingBuild.FITTINGS[id]["time"]), wide, dmg * SwingBuild.RAIN_DAMAGE * power, col, power >= 3.0)
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
	# Name what fired above the player, so it's obvious which rune did what. (A
	# ghosted copy isn't named: the real one just was.)
	if ghost:
		return
	if id == "weak_point":
		_label("MARKED", col)
	else:
		# (A Snipe's strength also says how well it was let go, so only Saved Up is named.)
		var shown := power
		if id == "snipe":
			shown = 3.0 if int(weapon["effects"][effect].get("every", 1)) > 1 else 1.0
		elif id in ["quake", "nova", "lance"] and q.get("why", "") == "dodge":
			shown = 1.0   # (a dodge's is a half one: not worth a number)
		_label(str(SwingBuild.FITTINGS[id]["name"]).to_upper() + ("!" if shown <= 1.0 else " x%s!" % str(snappedf(shown, 0.5)).trim_suffix(".0")), col)


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


## Bulwark's button while its shield is up: like a spin that's going it is in use,
## and only starts to recharge when the shield drops.
func _shield_up(ability: Dictionary) -> bool:
	return bulwark_left > 0.0 and str(ability.get("id", "")) == "bulwark"


## The meters fill back up (not the one whose rune is going, and a hold rune's
## only after a short wait).
func _refill_abilities(delta: float) -> void:
	var list := _abilities()
	for b in ability_charge.size():
		if b >= list.size():
			ability_charge[b] = 1.0
			ability_wait[b] = 0.0
		elif b != hold_button and not _shield_up(list[b]):
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
	# A Snipe being drawn: it goes when its button comes up (or has been held too
	# long). A dodge drops it, and it isn't used up.
	if snipe_button >= 0:
		if snipe_button >= list.size() or frozen or dodge_timer > 0.0 or not armed():
			snipe_button = -1
		else:
			var before := snipe_t
			snipe_t += delta
			if before < SwingBuild.SNIPE_CHARGE and snipe_t >= SwingBuild.SNIPE_CHARGE:
				# The ring has closed: now is the moment.
				var blink := _strip("snipe_sweet", global_position + SNIPE_RING)
				if blink != null:
					blink.follow = self
					blink.follow_offset = SNIPE_RING
				Sfx.play(self, "click", -6.0, 1.8)
			if not input.ability_held[snipe_button] or snipe_t >= SwingBuild.SNIPE_HOLD:
				_loose_snipe()
	if frozen or not armed() or dodge_timer > 0.0:
		return
	for b in mini(list.size(), ability_charge.size()):
		if not input.ability_pressed[b] or hold_button == b or snipe_button == b:
			continue
		if not ability_ready(b):
			ability_denied[b] = game_time
			Sfx.play(self, "dodge", -20.0, 0.6)
			continue
		var a: Dictionary = list[b]
		if a["use"] == "charge":
			# Drawing a Snipe drops the shot you were in the middle of.
			if snipe_button < 0:
				_stop_hold(true)
				_reset_combo()
				hit_pause = 0.0
				snipe_button = b
				snipe_t = 0.0
				bow_from = [pose_angle, pose_hand]
				Sfx.play(self, "swing", -12.0, 0.6)
			continue
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
			if a["id"] == "ghostwield":
				_summon_ghost(b, a["effects"])
				continue
			if a["id"] == "spectre":
				_summon_spectre(a["effects"])
				continue
			for i in a["effects"]:
				var e: Dictionary = weapon["effects"][i]
				var gap := _repeat_gap(str(e["id"]), "")
				for n in (1 if _fires_once(str(e["id"])) else int(e["count"])):
					_queue_rune(i, game_time + n * gap, float(e["size"]), [], float(e.get("power", 1.0)), false, "", false, n)


## Every Hit on an active rune (Darren, 11 November): a swing that lands takes a
## bit off that rune's recharge. One swing counts once, however many enemies it
## catches, so a crowd doesn't hand the ability straight back. Only your own
## swings count, not the ghost sword's copies of them.
func _hit_refund() -> void:
	var list := _abilities()
	for b in mini(list.size(), ability_charge.size()):
		var seconds := float(list[b].get("refund", 0.0))
		if seconds <= 0.0 or b == hold_button or float(ability_charge[b]) >= 1.0:
			continue
		# (Nor for a ghost that is still out: like a spin that's going, it is in use.)
		if b == ghost_button and ghost_left > 0.0:
			continue
		if _shield_up(list[b]) or (str(list[b]["id"]) == "spectre" and spectre_out() > 0.0):
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
	_end_lance()
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
## (Lance's beam isn't a spin: it points wherever you aim.)
func _hold_angle_now() -> float:
	if _beaming():
		return aim_dir.angle()
	return hold_angle + hold_side * TAU * clampf(1.0 - hold_left / hold_turn, 0.0, 1.0)


# --- Ghostwield -------------------------------------------------------------------

## Calls the ghost sword. Every Ghostwield rune on the sword is one ghost: a
## second rune counts like a Twice, and the longest and strongest of them win.
func _summon_ghost(b: int, effects: Array) -> void:
	var count := 0
	var time := 0.0
	var power := 0.0
	for i in effects:
		var e: Dictionary = weapon["effects"][i]
		count += int(e["count"])
		time = maxf(time, SwingBuild.ghost_time(float(e["size"])))
		power = maxf(power, SwingBuild.ghost_power(float(e.get("power", 1.0))))
		_flash_effect(i)
	ghost_count = clampi(count, 1, SwingBuild.MAX_COUNT)
	ghost_power = power
	ghost_total = maxf(time, 0.1)
	ghost_left = ghost_total
	ghost_button = b
	ghost_born = game_time
	ghost_gone = -9.0
	ghost_swings.clear()
	ghost_show = {}
	var arrive := Art.play_piece(self, "ghost_summon", global_position + _off_hand_point(), _ghost_rest_angle() + PI * 0.5, _ghost_piece_size())
	if arrive != null:
		arrive.follow = self
		arrive.follow_offset = _off_hand_point()
	Sfx.play(self, "ghost", -5.0)
	_label("GHOSTWIELD!" if power < 1.0 else "GHOSTWIELD x2!", GHOST_COLOR)


## The ghost sword goes: its time is up, you were knocked out, or the sword
## changed. quiet: no picture or sound (the sword was changed at the forge).
func _end_ghost(quiet := false) -> void:
	if ghost_left <= 0.0 and ghost_swings.is_empty():
		return
	var was_out := ghost_left > 0.0
	ghost_left = 0.0
	ghost_swings.clear()
	ghost_show = {}
	if not was_out or quiet:
		ghost_gone = -9.0
		return
	ghost_gone = game_time
	var leave := Art.play_piece(self, "ghost_fade", global_position + _off_hand_point(), _ghost_rest_angle() + PI * 0.5, _ghost_piece_size())
	if leave != null:
		leave.follow = self
		leave.follow_offset = _off_hand_point()
	Sfx.play(self, "ghost", -11.0, 0.7)


## Every tick: the ghost's time runs down and the copies that are due land.
func _run_ghost(delta: float) -> void:
	if ghost_left > 0.0:
		if ghost_left <= delta or is_down or not armed():
			_end_ghost()
		else:
			ghost_left -= delta
	while not ghost_smears.is_empty() and game_time - float(ghost_smears[0]["t0"]) > SMEAR_LIFE:
		ghost_smears.pop_front()
	var due: Array = []
	for g in ghost_swings:
		if float(g["at"]) <= game_time:
			due.append(g)
	for g in due:
		ghost_swings.erase(g)
		_ghost_swing(g)


## One copy of a swing lands: the same cut from the other side, from where you
## stand now, at the ghost's share of its strength. Then your passive runes go
## off again, as that swing's ghost.
func _ghost_swing(g: Dictionary) -> void:
	var move: String = g["move"]
	var info: Dictionary = MOVES.get(move, MOVES["slash"])
	var dir: Vector2 = g["dir"]
	var side: float = g["side"]
	# (A Spectre's copy comes through here too: it has its own share of the swing
	# it copies, and it is the figure beside you that swings, not a second sword.)
	var spectre: bool = g.get("spectre", false)
	var share := float(g.get("power", ghost_power))
	var dmg := (float(g["dmg"]) if g.has("dmg") else float(weapon.get("damage", 4.0)) * float(info["power"])) * share
	var hit_list: Array = []
	for f in _swing_hits(info, dir, _move_reach(info)):
		_hit_enemy(f[1], dmg, f[2], float(info["knock"]) * GHOST_SHOVE, float(info.get("stun", 0.12)) * GHOST_SHOVE,
			float(info.get("freeze", 0.05)) * GHOST_SHOVE, {}, true)
		hit_list.append(f[1])
		if spectre:
			_add_stagger(f[1], float(info["power"]) * share)
	var curve: Array = info["curve"]
	if not spectre:
		ghost_show = {"t0": game_time, "dir": dir, "side": side, "move": move}
	ghost_smears.append({"t0": game_time, "a0": dir.angle() + float(curve[0]) * side, "a1": dir.angle() + float(curve[1]) * side,
		"center": spectre_offset + _hand_point() if spectre else _off_hand_point(), "dir": dir.angle(), "side": side, "move": move})
	Sfx.play(self, "swing", -19.0, 1.5)
	var ghost := {"power": share, "fired": g["fired"]}
	if g["finisher"]:
		_trigger("finisher", hit_list, ghost)
	if not hit_list.is_empty():
		Sfx.play(self, "hit", -14.0, 1.35)
		_trigger("hit", hit_list, ghost)


## On Dodge on Ghostwield: the ghost cuts along the dodge, through everything
## you pass, whether or not it is out. power: the rune's (Saved Up: a full hit).
func _ghost_dodge_cut(power: float) -> void:
	var a := dodge_from
	var b := dodge_from + dodge_dir * DODGE_SPEED * DODGE_TIME
	var dmg := float(weapon.get("damage", 8.0)) * SwingBuild.ghost_power(power)
	var struck := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = Geometry2D.get_closest_point_to_segment(e.global_position, a, b).distance_to(e.global_position) - float(e.radius)
		if d <= GHOST_DODGE_WIDTH:
			_hit_enemy(e, dmg, dodge_dir, 120.0, 0.1, 0.03, {}, true)
			struck += 1
	# The cut shows as a streak the length of the dodge with a slash across its
	# middle, in the ghost's colour.
	for piece in [["thrust_smear", a.distance_to(b) / 80.0], ["slash_smear", 0.8]]:
		var cut := Art.play_piece(self, str(piece[0]), a + Vector2(0, -12), dodge_dir.angle(), float(piece[1]))
		if cut != null:
			cut.material = _ghost_glow()
	Sfx.play(self, "swing", -15.0, 1.5)
	if struck > 0:
		Sfx.play(self, "hit", -12.0, 1.35)


static var _ghost_glow_material: ShaderMaterial

## The material that redraws a glowing effect in the ghost's colour.
static func _ghost_glow() -> ShaderMaterial:
	if _ghost_glow_material == null:
		_ghost_glow_material = ShaderMaterial.new()
		_ghost_glow_material.shader = GHOST_GLOW_SHADER
	return _ghost_glow_material


## The arriving and leaving pictures are drawn for a blade about 30 pixels long:
## scaled to the blade in your hand, a little over its size so they flash round it.
func _ghost_piece_size() -> float:
	if not weapon.has("blade"):
		return 1.0
	return clampf(SwordArt.blade_size(str(weapon["blade"]), "hand").y / 26.0, 0.5, 1.3)


## Is the ghost sword on screen? It appears partway through its arriving
## picture and stays for the first moments of its leaving one.
func _ghost_shown() -> bool:
	if ghost_left > 0.0:
		return game_time - ghost_born >= 4.0 / 18.0
	return game_time - ghost_gone < 2.0 / 14.0


## Shards (as Darren set it out on 19 November): when a hit lands, shards burst
## out of the back of the enemy in a cone and fly straight, with no homing, into
## whoever stands behind it. (Until version 33 they jumped to the closest enemy
## and then the next.) Each shard cuts the first enemy on its line, and one burst
## cuts an enemy once however many of its shards reach it: the others fly on
## past. A wall stops a shard. Its line is fixed as it sets off and the cut lands
## when it arrives, counted in game ticks (not a timer), so it lands on the same
## tick on every computer.
static var SHARD_COUNT := 3        # shards in one burst (Every Hit: twice as many, at half strength)
static var SHARD_CONE := 44.0      # how wide a burst fans out, in degrees
static var SHARD_RANGE := 130.0    # how far a shard flies (Wider: further)
static var SHARD_DAMAGE := 0.6    # each shard, in blade hits
const SHARD_SPEED := 1100.0       # px a second
const SHARD_WIDTH := 6.0          # a shard cuts an enemy whose edge it passes this near
var shard_queue: Array = []   # shards in the air that will cut someone: [{at, enemy, dir, dmg, size, col, ghost}]

## from: the enemy that was hit, or you (On Dodge: the burst leaves you the way you aim).
func _shards(from: Node2D, size: float, power: float, dmg: float, col: Color, splinter := false) -> void:
	var dir := aim_dir
	var start := global_position + aim_dir * 14.0
	var cut := {}
	if from != self:
		var back: Vector2 = from.global_position - global_position
		if back.length() > 0.5:
			dir = back.normalized()
		start = from.global_position + dir * float(from.radius)
		cut[from.get_instance_id()] = true
	var n := maxi(SHARD_COUNT, 1) * (2 if splinter else 1)
	var reach := SHARD_RANGE * size
	var space := get_world_2d().direct_space_state
	# The middle shards first: the ones that fly straightest get first pick.
	var mid := float(n - 1) * 0.5
	var order: Array = range(n)
	order.sort_custom(func(a, b):
		var ka := absf(float(a) - mid)
		var kb := absf(float(b) - mid)
		return ka < kb or (ka == kb and a < b))
	for k in order:
		var d := dir if n == 1 else dir.rotated(deg_to_rad(SHARD_CONE) * (float(k) / float(n - 1) - 0.5))
		var far := reach
		# (The wall is looked for from the middle of whoever was hit: the edge the
		# shard leaves from can already be against it.)
		var wall := space.intersect_ray(PhysicsRayQueryParameters2D.create(from.global_position, start + d * reach, Arrow.WALLS))
		if not wall.is_empty():
			far = clampf((wall["position"] - start).dot(d), 0.0, reach)
		var best = null
		var best_at := INF
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead or e.immune or cut.has(e.get_instance_id()):
				continue
			var rel: Vector2 = e.global_position - start
			var r := float(e.radius) + SHARD_WIDTH
			var off := absf(rel.cross(d))
			var along := rel.dot(d)
			if off > r or (along < 0.0 and rel.length() > r):
				continue
			var meet := maxf(along - sqrt(r * r - off * off), 0.0)   # where the shard reaches its edge
			if meet <= far and meet < best_at:
				best_at = meet
				best = e
		if best == null:
			_shard_fly(start, start + d * far, col)
			continue
		cut[best.get_instance_id()] = true
		_shard_fly(start, start + d * best_at, col)
		shard_queue.append({"at": game_time + best_at / SHARD_SPEED, "enemy": best, "dir": d, "dmg": dmg * SHARD_DAMAGE * power,
			"size": size, "col": col, "ghost": ghost_fx})


## Lands the shards that have arrived.
func _run_shards() -> void:
	var due: Array = []
	for s in shard_queue:
		if float(s["at"]) <= game_time:
			due.append(s)
	for s in due:
		shard_queue.erase(s)
		var e = s["enemy"]
		if not is_instance_valid(e) or e.dead:
			continue
		ghost_fx = s.get("ghost", false)
		e.take_hit(float(s["dmg"]), s["dir"], 140.0, false, s["col"])
		if _strip("shards_hit", e.global_position, 0.0, float(s["size"])) == null:
			_strip("cleave_echo", e.global_position, 0.0, float(s["size"]))
	ghost_fx = false


## A spinning shard sprite flying from a to b (a plain streak if the art is missing).
func _shard_fly(a: Vector2, b: Vector2, col: Color) -> void:
	var time := maxf(a.distance_to(b) / SHARD_SPEED, 0.03)
	var shard := _strip("shards_shard", a)
	if shard != null:
		shard.life = time
		shard.velocity = (b - a) / time
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
## ghost: Ghostwield's copy of the rune only marks when you have a mark to spare,
## so its weaker mark never takes the place of a real one.
func _weak_point(hits: Array, count: int, size: float, power: float, col: Color, ghost := false) -> bool:
	if ghost:
		_prune_marks()
		if weak_marks.size() >= clampi(count, 1, SwingBuild.MAX_COUNT):
			return false
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
	var info := BowArt.fx(name)
	var tex := BowArt.fx_texture(name)
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
	if ghost_fx:
		n.material = _ghost_glow()
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
	# Bulwark stops a hit that comes from somewhere. Enough of them break it.
	# (Also with the arena's Invincible switch on, so the rune can be tried there.)
	if bulwark_left > 0.0 and from != Vector2.INF:
		_bulwark_block(from)
		return
	if unhurt:
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
		_end_ghost()
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
	# The ghost sword is in the other hand: behind the body when that hand is on the far side.
	ghost_group.show_behind_parent = facing8 in ["up", "up_left", "up_right", "right"]
	ghost_group.visible = _ghost_shown() and weapon_group.visible
	anim_time += delta
	if is_down:
		down_time += delta
	rise_timer = maxf(rise_timer - delta, 0.0)
	_update_pose(delta)
	_update_overflow_aura()
	_update_spectre(delta)
	staff_back.queue_redraw()
	staff_front.queue_redraw()
	if is_instance_valid(lance_fx):
		lance_fx.queue_redraw()
	trail_layer.queue_redraw()
	# The outline is one game pixel: as many screen pixels as the window's scale.
	var scale_px := maxf(floorf(float(get_window().size.y) / 360.0), 1.0)
	(weapon_group.material as ShaderMaterial).set_shader_parameter("px", scale_px)
	if ghost_group.visible:
		# It shimmers, and blinks through its last two seconds so you see it going.
		var solid := 0.85 + 0.15 * sin(anim_time * 5.0)
		if ghost_left > 0.0 and ghost_left < 2.0:
			solid = 0.95 if int(ghost_left * 8.0) % 2 == 0 else 0.45
		(ghost_group.material as ShaderMaterial).set_shader_parameter("px", scale_px)
		(ghost_group.material as ShaderMaterial).set_shader_parameter("strength", solid)
		ghost_layer.queue_redraw()
	ghost_trail.queue_redraw()
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
	_draw_steady_ring()
	_draw_momentum_ring()
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


## Steady Aim's ring at the feet: five steps, one lit for each fifth of the way.
func _draw_steady_ring() -> void:
	if steady_rune.is_empty() or is_down or (steady <= 0.0 and current_step < 0):
		return
	var tex := BowArt.fx_texture("steady_ring")
	var info := BowArt.fx("steady_ring")
	if tex == null or info.is_empty():
		under_bright.draw_set_transform(FEET, 0.0, Vector2(1.0, 0.45))
		under_bright.draw_arc(Vector2.ZERO, 22.0, -PI * 0.5, -PI * 0.5 + TAU * float(steady_step()) / 5.0, 24, SwingBuild.FITTINGS["steady_aim"]["color"], 2.0)
		under_bright.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var size: Array = info.get("frame", [48, 24])
	var o: Array = info.get("origin", [24, 12])
	under_bright.draw_set_transform(FEET, 0.0, Vector2(Art.PIXEL, Art.PIXEL))
	under_bright.draw_texture_rect_region(tex, Rect2(-float(o[0]), -float(o[1]), float(size[0]), float(size[1])),
		Rect2(float(steady_step()) * float(size[0]), 0, float(size[0]), float(size[1])))
	under_bright.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Snipe's ring, closing on you as you draw. It is closed when the shot is at its
## best, and dims once that moment has gone.
func _draw_snipe_ring() -> void:
	if snipe_button < 0:
		return
	var tex := BowArt.fx_texture("snipe_charge")
	var info := BowArt.fx("snipe_charge")
	var full := snipe_t >= SwingBuild.SNIPE_CHARGE
	var late := full and not _snipe_sweet_now()
	var tint := Color(1, 1, 1, 0.55 if late else 1.0)
	if tex == null or info.is_empty():
		var col: Color = SwingBuild.FITTINGS["snipe"]["color"]
		trail_layer.draw_arc(SNIPE_RING, lerpf(56.0, 14.0, clampf(snipe_t / SwingBuild.SNIPE_CHARGE, 0.0, 1.0)), 0.0, TAU, 32, Color(col, tint.a), 2.0)
		return
	var n := maxi(int(info.get("frames", 8)), 1)
	var size: Array = info.get("frame", [64, 64])
	var o: Array = info.get("origin", [32, 32])
	var f := clampi(int(snipe_t / SwingBuild.SNIPE_CHARGE * float(n - 1)), 0, n - 1)
	trail_layer.draw_set_transform(SNIPE_RING, 0.0, Vector2(Art.PIXEL, Art.PIXEL))
	trail_layer.draw_texture_rect_region(tex, Rect2(-float(o[0]), -float(o[1]), float(size[0]), float(size[1])),
		Rect2(float(f) * float(size[0]), 0, float(size[0]), float(size[1])), tint)
	trail_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## True while a Snipe let go right now would be a perfect one.
func _snipe_sweet_now() -> bool:
	if snipe_button < 0 or snipe_button >= _abilities().size():
		return false
	var sweet := 0.0
	for i in _abilities()[snipe_button]["effects"]:
		sweet = maxf(sweet, SwingBuild.SNIPE_SWEET * float(weapon["effects"][i]["size"]))
	return snipe_t >= SwingBuild.SNIPE_CHARGE and snipe_t <= SwingBuild.SNIPE_CHARGE + sweet


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
static var BASE_REACH := 73.0
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
	if _is_bow():
		var a: float = BOW_READY.get(facing8, BOW_READY.get(facing, 0.2))
		return [a, _hand_point() + Vector2(BOW_OUT * signf(cos(a)), 0.0)]
	if _is_staff():
		return [STAFF_READY.get(facing8, STAFF_READY.get(facing, -1.5)), _hand_point()]
	return [READY_ANGLE.get(facing8, READY_ANGLE.get(facing, -1.85)), _hand_point()]


## A staff at rest stands upright in the hand, leaning a little the way you face.
const STAFF_READY := {"right": -1.4, "left": -(PI - 1.4), "down": -1.66, "up": -1.48,
	"down_right": -1.5, "down_left": -(PI - 1.5), "up_right": -1.4, "up_left": -(PI - 1.4)}


## The bow at rest: held upright at the side in the same hand as the sword, its
## back turned outwards and its string to the body, tipped a little forward. The
## angle is the way an arrow on it would point (0 = right). Facing down that hand
## is on screen-left and facing up on screen-right, as for the sword.
const BOW_READY := {"right": 0.2, "down_right": 0.25, "up_right": 0.15, "up": 0.2,
	"left": PI - 0.2, "down_left": PI - 0.25, "up_left": PI - 0.15, "down": PI - 0.2}
const BOW_OUT := 4.0        # at rest it is held this far out from the hand's place
const BOW_CHEST := Vector2(0, -10)
const BOW_HOLD := 15.0      # shooting, the bow is held this far in front of the chest
const BOW_RAISE := 0.05     # bringing it up from the side to the aim
const BOW_SNAP := 0.03      # the string going back after the arrow leaves
var bow_draw := 0.0         # how far the string is drawn, 0..1 (what is on screen)
var bow_nocked := false     # an arrow is on the string
var bow_from: Array = [0.0, Vector2.ZERO]   # the pose the shot began from
var bow_loosed := -9.0      # game_time the last arrow left


## The bow's pose. Shooting, it comes up to the aim and follows it; the string is
## drawn through the wind-up, snaps back as the arrow leaves, and the next arrow
## goes on just before the next shot of a chain.
func _update_bow_pose(delta: float) -> void:
	if snipe_button >= 0:
		# Drawing a Snipe: the bow is up at the aim and the string comes all the way back.
		var k := clampf(snipe_t / BOW_RAISE, 0.0, 1.0)
		pose_angle = lerp_angle(float(bow_from[0]), aim_dir.angle(), k)
		pose_hand = (bow_from[1] as Vector2).lerp(BOW_CHEST + aim_dir * BOW_HOLD, k)
		var d := clampf(snipe_t / SwingBuild.SNIPE_CHARGE, 0.0, 1.0)
		bow_draw = 1.0 - (1.0 - d) * (1.0 - d)
		bow_nocked = true
		squash = squash.lerp(Vector2(1.04, 0.96), 1.0 - exp(-30.0 * delta))
	elif current_step >= 0:
		var wind := float(_move_info()["windup"]) / _speed()
		var k := clampf(step_elapsed / BOW_RAISE, 0.0, 1.0)
		pose_angle = lerp_angle(float(bow_from[0]), anim_dir.angle(), k)
		pose_hand = (bow_from[1] as Vector2).lerp(BOW_CHEST + anim_dir * BOW_HOLD, k)
		if hit_time >= 0.0:
			var d := clampf(step_elapsed / maxf(wind * 0.8, 0.001), 0.0, 1.0)
			bow_draw = 1.0 - (1.0 - d) * (1.0 - d)
			bow_nocked = true
			squash = squash.lerp(Vector2(1.03, 0.97) if _move_info().get("big", false) else Vector2.ONE, 1.0 - exp(-30.0 * delta))
		else:
			bow_draw = maxf(bow_draw - delta / BOW_SNAP, 0.0)
			var chaining := queued or (input.attack_held and not need_release)
			bow_nocked = chaining and step_elapsed > step_duration - 0.06
	else:
		var r := _rest_pose()
		pose_angle = r[0]
		pose_hand = r[1]
		if return_t > 0.0:
			return_t = maxf(return_t - delta, 0.0)
			var k := return_t / RETURN_TIME
			k = k * k
			pose_angle = lerp_angle(r[0], float(return_from[0]), k)
			pose_hand = (r[1] as Vector2).lerp(return_from[1], k)
		bow_draw = maxf(bow_draw - delta / BOW_SNAP, 0.0)
		bow_nocked = false
	lean = lerpf(lean, 0.0, 1.0 - exp(-12.0 * delta))
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-12.0 * delta))


func _update_pose(delta: float) -> void:
	if _is_bow():
		_update_bow_pose(delta)
		return
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
	_draw_snipe_ring()
	if smear_t0 < 0.0 or not weapon.has("blade") or _is_bow():
		return
	_draw_smear(trail_layer, {"t0": smear_t0, "a0": smear_a0, "a1": smear_a1, "center": smear_center,
		"dir": smear_dir, "side": smear_side, "move": smear_move})


## Ghostwield's copies of your swings: the same smears from the other hand, in
## the ghost's colour (the layer's material recolours them).
func _draw_ghost_trail() -> void:
	if not weapon.has("blade") or _is_bow():
		return
	for sm in ghost_smears:
		_draw_smear(ghost_trail, sm)


## The picture of a move's swing: the one drawn for it, or (until it is drawn)
## the sword's that is nearest. "" for a move with no swing in it (a staff's cast).
func _smear_piece(info: Dictionary) -> String:
	var piece := str(info.get("smear", "slash_smear"))
	if piece != "" and Art.piece_texture(piece) == null and info.has("smear_else"):
		return str(info["smear_else"])
	return piece


## One swing's smear on `layer`: {t0, a0, a1, center, dir, side, move}.
func _draw_smear(layer: Node2D, sm: Dictionary) -> void:
	var sa0: float = sm["a0"]
	var sa1: float = sm["a1"]
	var scenter: Vector2 = sm["center"]
	var sdir: float = sm["dir"]
	var sside: float = sm["side"]
	var smove: String = sm["move"]
	var age := (game_time - float(sm["t0"])) / SMEAR_LIFE
	if age >= 1.0:
		return
	var info: Dictionary = MOVES.get(smove, MOVES["slash"])
	var length_px := _reach_px() * float(info.get("reach", 1.0))
	var r_in := 3.0 + length_px * 0.45
	var r_out := 3.0 + length_px
	var thrust := absf(sa1 - sa0) < 0.05
	var piece := _smear_piece(info)
	if piece == "":
		return   # a cast: nothing is swung
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
			layer.draw_set_transform(scenter, sdir, Vector2(along, across))
			layer.draw_texture_rect_region(tex, Rect2(-float(o[0]), -float(o[1]), fw, tex.get_height()), Rect2(frame * fw, 0, fw, tex.get_height()))
			layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		var back := sside < 0.0
		Art.draw_piece(layer, piece, frame, scenter,
			sdir + (PI if back else 0.0), back, Color.WHITE, Art.PIXEL * r_out / 80.0)
		return
	var col: Color = weapon.get("hit_color", Color.WHITE).lerp(Color(0.8, 0.9, 1.0), 0.5)
	var fade := 1.0 - age
	if thrust:
		# A thrust: a straight streak along the blade instead of an arc.
		var d := Vector2.RIGHT.rotated(sa0)
		var n := d.orthogonal() * 4.0
		var c := scenter
		draw_colored_polygon_on(layer, PackedVector2Array([c + d * r_in - n, c + d * (r_out + 10.0) - n, c + d * (r_out + 10.0) + n, c + d * r_in + n]), Color(col.r, col.g, col.b, 0.8 * fade))
		return
	var steps := 16
	for i in steps:
		var s0 := float(i) / steps
		var s1 := float(i + 1) / steps
		var a0 := lerpf(sa0, sa1, s0)
		var a1 := lerpf(sa0, sa1, s1)
		var d0 := Vector2.RIGHT.rotated(a0)
		var d1 := Vector2.RIGHT.rotated(a1)
		# Thin at the trailing end, full width and opaque at the leading edge.
		var w0 := lerpf(r_out - 4.0, r_in, s0)
		var w1 := lerpf(r_out - 4.0, r_in, s1)
		var alpha := (0.15 + 0.85 * s1 * s1) * fade
		var c := scenter
		draw_colored_polygon_on(layer, PackedVector2Array([c + d0 * w0, c + d0 * r_out, c + d1 * r_out, c + d1 * w1]), Color(col.r, col.g, col.b, alpha))


func draw_colored_polygon_on(ci: CanvasItem, pts: PackedVector2Array, c: Color) -> void:
	# Long sweeps can make the quad cross itself; split it into two triangles.
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2]]), c)
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[2], pts[3]]), c)


func _draw_weapon() -> void:
	_draw_weapon_on(weapon_layer, Vector2.ZERO, _slot_glow())


## The weapon in your hand, drawn on `layer` and moved by `off` (a Spectre's is
## yours again, beside you). glow: how lit each slot is.
func _draw_weapon_on(layer: Node2D, off: Vector2, glow: Dictionary) -> void:
	if not weapon.has("blade"):
		# Empty-handed: just the fist at the side.
		var bare := Art.texture("body/hand.png")
		if bare != null:
			layer.draw_set_transform(off + _hand_point(), 0.0, Vector2(Art.PIXEL, Art.PIXEL))
			layer.draw_texture(bare, -bare.get_size() * 0.5)
			layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if _is_bow():
		_draw_bow_on(layer, off, glow)
		return
	var pose := _sword_pose()
	var angle: float = pose[0]
	var hand: Vector2 = off + (pose[1] as Vector2)
	# Mid-sweep the sword is hidden: the smear shows the swing (reads as a fast blur).
	var hidden := false
	if current_step >= 0:
		var times := _swing_times()
		hidden = step_elapsed >= float(times[0]) and step_elapsed < float(times[1]) and _smear_piece(_move_info()) != ""
	if not hidden:
		# Art space: x right, y down, tip at the top. Rotate so "up" points along d.
		layer.draw_set_transform(hand, angle + PI * 0.5, Vector2(Art.PIXEL, Art.PIXEL))
		var blade: String = weapon["blade"]
		var grip: String = weapon["grip"]
		# (No runes or threads on it: the spirit holds those. An empty line draws none.)
		SwordArt.draw(layer, blade, grip, [], "hand", glow, -SwordArt.pivot(blade, grip, "hand"), _spirit_tint(layer),
			str(weapon.get("pommel", "plain_pommel")), SwordArt.one_edged(blade) and _edge_flipped(angle),
			str(weapon.get("arrows", "")) if _is_staff() else "")
	# The fist sits on the grip but is drawn upright, never spun with the sword.
	var fist := Art.texture("body/hand.png")
	if fist != null:
		layer.draw_set_transform(hand, 0.0, Vector2(Art.PIXEL, Art.PIXEL))
		layer.draw_texture(fist, -fist.get_size() * 0.5)
	layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The hand that holds the weapon, from the player's centre: where the forge
## spirit sends a rune's sign.
func weapon_hand() -> Vector2:
	return pose_hand if weapon.has("blade") else _hand_point()


## Where that hand rests for the way the body faces (the spirit keeps to the other side).
func rest_hand() -> Vector2:
	return _hand_point()


## The weapon lit by the spirit: ember when a sign has just landed in it, fading
## back to its own colours. Only your own weapon, not a ghost's or a Spectre's.
func _spirit_tint(layer: Node2D) -> Color:
	var since := game_time - spirit_lit
	if layer != weapon_layer or since < 0.0 or since >= ForgeSpirit.TINT_TIME:
		return Color.WHITE
	return ForgeSpirit.EMBER.lerp(Color.WHITE, since / ForgeSpirit.TINT_TIME)


## Aiming to the left the bow's picture is turned over, so the grip's slots stay
## towards the ground instead of ending up on top.
func _bow_flipped() -> bool:
	return cos(pose_angle) < 0.0


## A place on the bow (BowArt's bow space, art pixels) as an offset from the
## player's centre.
func _bow_point(local: Vector2) -> Vector2:
	if _bow_flipped():
		local.y = -local.y
	return pose_hand + (local * Art.PIXEL).rotated(pose_angle)


## The bow in the hand: stave, string and arrow turned to the aim, then the fist
## on the grip, upright as always. (A second fist on the string hid the face
## whenever you aimed down, so the string is drawn back without one.)
func _draw_bow_on(layer: Node2D, off: Vector2, glow: Dictionary) -> void:
	var limbs: String = weapon["blade"]
	layer.draw_set_transform(off + pose_hand, pose_angle, Vector2(Art.PIXEL, -Art.PIXEL if _bow_flipped() else Art.PIXEL))
	BowArt.draw_hand(layer, limbs, str(weapon["grip"]), str(weapon.get("pommel", "plain_string")), str(weapon.get("arrows", "")),
		[], glow, bow_draw, bow_nocked, _spirit_tint(layer))
	var fist := Art.texture("body/hand.png")
	if fist != null:
		layer.draw_set_transform(off + pose_hand, 0.0, Vector2(Art.PIXEL, Art.PIXEL))
		layer.draw_texture(fist, -fist.get_size() * 0.5)
	layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where the other hand is: the sword hand's place mirrored across the body. Side
## on, both hands are at the same place on screen, so the far one sits a little
## back and up, and the near one a little forward and down.
func _off_hand_point() -> Vector2:
	var h := _hand_point()
	match facing8:
		"right":
			return h + Vector2(-5, -5)
		"left":
			return h + Vector2(-7, 4)
	return Vector2(-h.x, h.y)


## The ghost sword at rest: the real sword's stance mirrored, so the two fan out.
const GHOST_READY := {"down": -1.29, "down_right": -1.1, "right": -1.35, "up_right": -2.04,
	"up": -1.84, "up_left": -1.1, "left": -2.75, "down_left": -2.04}

func _ghost_rest_angle() -> float:
	return GHOST_READY.get(facing8, -1.3)


## The ghost sword's pose: [angle, hand, hidden]. It rests in the other hand,
## winds up when a copy of your swing is on its way, is hidden for the copy's
## smear, holds where the cut ended and eases back.
const GHOST_HOLD := 0.1

func _ghost_pose() -> Array:
	var angle := _ghost_rest_angle()
	var hand := _off_hand_point()
	var hidden := false
	var reach := 0.0
	if not ghost_show.is_empty():
		var since := game_time - float(ghost_show["t0"])
		var curve: Array = MOVES.get(str(ghost_show["move"]), MOVES["slash"])["curve"]
		var end_a: float = (ghost_show["dir"] as Vector2).angle() + float(curve[1]) * float(ghost_show["side"])
		if since < SWEEP_TIME:
			hidden = true
		elif since < GHOST_HOLD:
			angle = end_a
			reach = 3.0
		elif since < GHOST_HOLD + RETURN_TIME:
			var k := 1.0 - (since - GHOST_HOLD) / RETURN_TIME
			angle = lerp_angle(angle, end_a, k * k)
			reach = 3.0 * k
	if not ghost_swings.is_empty():
		# A copy is on its way: swing back to where it starts from.
		var g: Dictionary = ghost_swings[0]
		var curve: Array = MOVES.get(str(g["move"]), MOVES["slash"])["curve"]
		var start_a: float = (g["dir"] as Vector2).angle() + float(curve[0]) * float(g["side"])
		var lead := clampf(1.0 - (float(g["at"]) - game_time) / GHOST_DELAY, 0.0, 1.0)
		angle = lerp_angle(angle, start_a, clampf(lead / 0.5, 0.0, 1.0))
		reach = maxf(reach, 3.0 * lead)
	return [angle, hand + Vector2.RIGHT.rotated(angle) * reach, hidden]


## The ghost sword: your own sword, drawn in the other hand. (Its CanvasGroup's
## material turns the whole picture see-through and ghost-coloured.)
func _draw_ghost() -> void:
	if not weapon.has("blade") or _is_bow():
		return
	var pose := _ghost_pose()
	if pose[2]:
		return
	var angle: float = pose[0]
	var blade: String = weapon["blade"]
	var grip: String = weapon["grip"]
	ghost_layer.draw_set_transform(pose[1], angle + PI * 0.5, Vector2(Art.PIXEL, Art.PIXEL))
	SwordArt.draw(ghost_layer, blade, grip, [], "hand", {}, -SwordArt.pivot(blade, grip, "hand"), Color.WHITE,
		str(weapon.get("pommel", "plain_pommel")), SwordArt.one_edged(blade) and cos(angle) <= 0.0)
	ghost_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	if _is_bow():
		return global_position + _bow_point(BowArt.slot_at(str(weapon["blade"]), str(weapon["grip"]), i) + Vector2(0.5, 0.5))
	var pose := _sword_pose()
	var angle: float = pose[0]
	var hand: Vector2 = pose[1]
	var blade: String = weapon["blade"]
	var grip: String = weapon["grip"]
	var local := (SwordArt.slot_center(blade, grip, "hand", i) - SwordArt.pivot(blade, grip, "hand")) * Art.PIXEL
	return global_position + hand + local.rotated(angle + PI * 0.5)


## The sword's tip in the world.
func _tip_world() -> Vector2:
	if _is_bow():
		return global_position + _bow_point(BowArt.tips(str(weapon["blade"]), bow_draw)[0])
	var pose := _sword_pose()
	var d := Vector2.RIGHT.rotated(float(pose[0]))
	var blade: String = weapon.get("blade", "iron_broadsword")
	var grip: String = weapon.get("grip", "wooden_grip")
	var length_px := SwordArt.pivot(blade, grip, "hand").y * Art.PIXEL
	return global_position + pose[1] + d * length_px
