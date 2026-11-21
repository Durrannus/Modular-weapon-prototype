extends SceneTree
## Retakes the stills the forge shows for a rune while Alt is held
## (art/swing/previews/<rune>.png, 352 x 240): each rune is used once in the
## arena by a scripted player and the screen is cut out round it. Run it again
## whenever a rune's look or rule changes, so the stills never show an old game.
## It needs a screen (xvfb will do):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --fixed-fps 60 -s tools/take_previews.gd
##   ... -s tools/take_previews.gd -- only=quake,hook   (just those)   out=<folder>   (somewhere else)

const PlayerInput := preload("res://scripts/player_input.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")

const SIZE := Vector2i(352, 240)
## Every rune's shot. foes: where the enemies stand, from the player. how:
##   "press"   press its button, and shoot `wait` frames later
##   "hold"    hold its button down for `wait` frames, then shoot
##   "release" hold its button for `hold` frames, let go, and shoot `wait` frames later
##   "hits"    hold attack until the first enemy has been hit `hits` times, then `wait` frames
##   "stun"    hold attack until the first enemy is stunned for a second or more, then `wait` frames
##   "rumble"  hold attack until an Aftershock is on its way, then `wait` frames
##   "after"   press its button, wait `hold` frames, then as "hits"
##   "shoot"   hold attack for `hold` frames, then shoot
##   "bolt"    one press of attack, and shoot `wait` frames after the bolt leaves
## look: the middle of the still, from the player.
const SHOTS := {
	"shockwave": {"weapon": "sword", "foes": [Vector2(46, 0), Vector2(110, -20), Vector2(130, 30)], "how": "hits", "hits": 3, "wait": 9, "look": Vector2(60, -6)},
	"shards": {"weapon": "sword", "foes": [Vector2(46, 0), Vector2(104, -22), Vector2(108, 24)], "how": "hits", "hits": 1, "wait": 3, "look": Vector2(56, -6)},
	"weak_point": {"weapon": "sword", "foes": [Vector2(46, 0)], "how": "hits", "hits": 3, "wait": 12, "look": Vector2(30, -8)},
	"whirlwind": {"weapon": "sword", "foes": [Vector2(52, 0), Vector2(-44, 28), Vector2(0, -54)], "how": "hold", "wait": 22, "look": Vector2(0, -8)},
	"leap": {"weapon": "sword", "foes": [Vector2(170, 0)], "how": "press", "wait": 12, "look": Vector2(-50, -8), "loose": true},
	"ghostwield": {"weapon": "sword", "foes": [Vector2(46, 0)], "how": "after", "hold": 24, "hits": 1, "wait": 9, "look": Vector2(20, -8)},
	"pierce": {"weapon": "bow", "foes": [Vector2(120, 0), Vector2(170, 0), Vector2(220, 0)], "how": "hits", "hits": 3, "wait": 4, "look": Vector2(110, -8)},
	"ricochet": {"weapon": "bow", "foes": [Vector2(140, 0), Vector2(200, 62), Vector2(190, -66)], "how": "hits", "hits": 3, "wait": 5, "look": Vector2(84, -20)},
	"steady_aim": {"weapon": "bow", "foes": [Vector2(180, 0)], "how": "shoot", "hold": 230, "look": Vector2(70, -8)},
	"volley": {"weapon": "bow", "foes": [Vector2(150, -34), Vector2(150, 34), Vector2(176, 0)], "how": "press", "wait": 6, "look": Vector2(80, -8)},
	"snipe": {"weapon": "bow", "foes": [Vector2(250, 0)], "how": "release", "hold": 60, "wait": 4, "look": Vector2(90, -8)},
	"arrow_rain": {"weapon": "bow", "foes": [Vector2(150, 0), Vector2(180, 30), Vector2(130, -24)], "how": "press", "wait": 44, "look": Vector2(110, -8)},
	"momentum": {"weapon": "hammer", "foes": [Vector2(46, 0)], "how": "hits", "hits": 3, "wait": 8, "look": Vector2(16, -8)},
	"stagger": {"weapon": "hammer", "foes": [Vector2(46, 0)], "how": "stun", "wait": 4, "look": Vector2(30, -8)},
	"aftershock": {"weapon": "hammer", "foes": [Vector2(46, 0), Vector2(70, 40)], "how": "rumble", "wait": 40, "look": Vector2(40, -4)},
	"quake": {"weapon": "hammer", "foes": [Vector2(90, 4), Vector2(170, -10), Vector2(130, 70)], "how": "press", "wait": 7, "look": Vector2(90, -4)},
	"bulwark": {"weapon": "hammer", "foes": [Vector2(60, 0), Vector2(-50, 30)], "how": "press", "wait": 22, "look": Vector2(0, -8)},
	"hook": {"weapon": "hammer", "foes": [Vector2(190, 0)], "how": "press", "wait": 7, "look": Vector2(90, -8), "loose": true},
	"orbit": {"weapon": "staff", "foes": [Vector2(190, 0)], "how": "hits", "hits": 3, "wait": 45, "look": Vector2(10, -8)},
	"chain": {"weapon": "staff", "foes": [Vector2(170, 0), Vector2(180, 84), Vector2(250, 130), Vector2(290, 50)], "how": "hits", "hits": 3, "wait": 3, "look": Vector2(130, 24)},
	"overflow": {"weapon": "staff", "foes": [Vector2(230, 0)], "how": "bolt", "wait": 5, "look": Vector2(46, -8)},
	"nova": {"weapon": "staff", "foes": [Vector2(62, 0), Vector2(-52, 30), Vector2(0, -44)], "how": "press", "wait": 8, "look": Vector2(0, -6)},
	"lance": {"weapon": "staff", "foes": [Vector2(200, 0)], "how": "hold", "wait": 150, "look": Vector2(100, -8)},
	"spectre": {"weapon": "staff", "foes": [Vector2(200, 0)], "how": "after", "hold": 24, "hits": 1, "wait": 2, "look": Vector2(70, -8)},
}
## The plain weapon each rune is shot on: its one rune and nothing else.
const WEAPONS := {
	"sword": ["iron_broadsword", "wrapped_grip", "plain_pommel"],
	"bow": ["iron_shortbow", "wrapped_bow_grip", "plain_string"],
	"hammer": ["iron_maul", "bound_haft", "plain_weight"],
	"staff": ["iron_apprentice", "carved_shaft", "plain_cap"],
}
const LAST := {"bow": "iron_arrows", "staff": "iron_crystal"}

var out := "res://art/swing/previews"
var only: Array = []
var boot
var g
var p
var home := Vector2.ZERO
var made: Array = []


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		if a.begins_with("only="):
			only = Array(a.substr(5).split(","))
	boot = load("res://scenes/boot.tscn").instantiate()
	root.add_child(boot)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _foe(offset: Vector2, loose: bool):
	var e = EnemyScript.new()
	e.kind = "slime"
	e.position = home + offset
	g.world.add_child(e)
	e.max_hp = 5000.0
	e.hp = 5000.0
	e.speed = 0.0
	e.contact_damage = 0.0
	if not loose:
		e.knock_resist = 0.05
	made.append(e)
	return e


func _quiet() -> void:
	p.input.attack_held = false
	p.input.attack_pressed = false
	p.input.ability_held = [false, false, false]
	p.input.ability_pressed = [false, false, false]
	p.input.move = Vector2.ZERO
	p.input.stick_aim = Vector2.RIGHT


## The arena cleared, the player in the middle with this rune alone on a plain weapon.
func _set_up(id: String, shot: Dictionary) -> void:
	_quiet()
	for e in made:
		if is_instance_valid(e):
			e.queue_free()
	made.clear()
	var kind: String = shot["weapon"]
	var data: Array = (WEAPONS[kind] as Array).duplicate()
	g.swap_weapon(0, kind)
	await _frames(3)
	var seats := 4
	data.append([id])
	if LAST.has(kind):
		data.append(LAST[kind])
	while not SwingBuild.valid_data(data) and seats > 0:
		(data[3] as Array).append("")
		seats -= 1
	g.builds[0].set_data(data)
	g.builds[0].changed.emit()
	await _frames(150)      # long enough for the last rune's effects and words to be gone
	p.global_position = home
	p.reset_physics_interpolation()
	p.hp = p.max_hp
	p.mana = SwingBuild.MANA
	p.dodge_charges = 1
	p.ability_charge = [1.0, 1.0, 1.0]
	p.ability_wait = [0.0, 0.0, 0.0]
	p._reset_combo()
	g.rig.snap()
	for at in shot["foes"]:
		_foe(at, shot.get("loose", false))
	await _frames(6)
	p.weapon["crit"] = 0.0   # no lucky hits: a crit's big number would hide the effect


func _press(hold: bool) -> void:
	p.input.ability_pressed = [true, false, false]
	p.input.ability_held = [true, false, false]
	await _frames(1)
	p.input.ability_pressed = [false, false, false]
	if not hold:
		p.input.ability_held = [false, false, false]


## Holds attack until the first enemy has been hit `n` times (or `most` frames pass).
func _until_hits(n: int, most := 900) -> void:
	var foe = made[0]
	var hp: float = foe.hp
	var seen := 0
	p.input.attack_held = true
	p.input.attack_pressed = true
	await _frames(1)
	p.input.attack_pressed = false
	for i in most:
		await _frames(1)
		if not is_instance_valid(foe):
			break
		if foe.hp < hp - 0.001:
			seen += 1
			hp = foe.hp
			if seen >= n:
				break
	p.input.attack_held = false


func _save(id: String, look: Vector2) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	# (The game is drawn at 640 x 360 and shown twice the size; one world unit is
	# one pixel of the picture taken.)
	var at: Vector2 = p.get_global_transform_with_canvas().origin * (float(img.get_width()) / root.get_visible_rect().size.x) + look
	var x := clampi(roundi(at.x) - SIZE.x / 2, 0, img.get_width() - SIZE.x)
	var y := clampi(roundi(at.y) - SIZE.y / 2, 0, img.get_height() - SIZE.y)
	var path := "%s/%s.png" % [out, id]
	img.get_region(Rect2i(Vector2i(x, y), SIZE)).save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
	print("took %s" % id)
	await physics_frame


func _take(id: String) -> void:
	var shot: Dictionary = SHOTS[id]
	await _set_up(id, shot)
	var wait := int(shot.get("wait", 0))
	match str(shot["how"]):
		"press":
			await _press(false)
			await _frames(wait)
		"hold":
			await _press(true)
			await _frames(wait)
		"release":
			await _press(true)
			await _frames(int(shot["hold"]))
			p.input.ability_held = [false, false, false]
			await _frames(wait)
		"hits":
			await _until_hits(int(shot["hits"]))
			await _frames(wait)
		"after":
			await _press(false)
			await _frames(int(shot["hold"]))
			await _until_hits(int(shot["hits"]))
			await _frames(wait)
		"stun":
			p.input.attack_held = true
			for i in 1500:
				await _frames(1)
				if float(made[0].staggered) > 0.0:
					break
			p.input.attack_held = false
			await _frames(wait)
		"rumble":
			p.input.attack_held = true
			for i in 900:
				await _frames(1)
				if not p.rumbles.is_empty():
					break
			p.input.attack_held = false
			await _frames(wait)
		"shoot":
			p.input.attack_held = true
			await _frames(int(shot["hold"]))
		"bolt":
			p.input.attack_pressed = true
			await _frames(1)
			p.input.attack_pressed = false
			for i in 80:
				await _frames(1)
				if not get_nodes_in_group("arrows").is_empty():
					break
			await _frames(wait)
	await _save(id, shot["look"])
	_quiet()


func _run() -> void:
	await process_frame
	await process_frame
	boot._start("arena", [PlayerInput.make("script")])
	await _frames(10)
	g = boot.game
	p = g.player
	g.spawning = false
	g.hud.visible = false       # the stills show the fight, not the bars
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	home = g.ARENA.get_center()
	await _frames(5)
	for id in SHOTS:
		if only.is_empty() or id in only:
			await _take(id)
	quit(0)
