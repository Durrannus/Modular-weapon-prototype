extends "res://tests/cave_playthrough.gd"
## Two copies of the game play the tutorial cave together over the network, each
## with a scripted player, to prove online play keeps the two games identical.
## Start one copy as the host and one as the joiner (see tests/online.sh):
##   godot --headless --path . -s tests/online_cave.gd -- net=host port=24601
##   godot --headless --path . -s tests/online_cave.gd -- net=join port=24601
## Extras:  drop=0.2    lose a fifth of the packets on purpose
##          slow=8      this copy takes 8 ms longer over every tick (a slow computer)
##          lag=40      hold every packet back 40 ms, as if the other computer were far away
##          hard        nobody's health is topped up, and everyone is knocked out once in room 2
##                      and once at the boss, to prove a room starts over on both computers
##          dump=/file  write every checksum and what went into it, to compare the two
##          arena       play the test arena for 40 seconds instead (forge hotkey, spawning)
## Each bot only ever touches its own computer's controls, exactly like a person
## would; everything else has to arrive through the session.

const Session := preload("res://scripts/net/session.gd")
const Net := preload("res://scripts/net/net.gd")

var session
var role := "host"
var port := 24601
var slow := 0
var arena := false
var me := 0
var spare := PlayerInput.make("script")   # where presses for the other computer's player go: nowhere
var wait_frames := 0
var linger := -1        # clock milliseconds to quit at, once this copy has finished
var result_ok := false
var arena_step := 0
var hard := false
var started := 0


func _begin() -> void:
	n_players = 2
	mortal = true   # no topping up health from outside the game: the game does it itself (min_hp)
	var drop := 0.0
	var lag := 0
	var dump_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("net="):
			role = a.split("=")[1]
		elif a.begins_with("port="):
			port = int(a.split("=")[1])
		elif a.begins_with("drop="):
			drop = float(a.split("=")[1])
		elif a.begins_with("slow="):
			slow = int(a.split("=")[1])
		elif a.begins_with("dump="):
			dump_path = a.split("=")[1]
		elif a == "arena":
			arena = true
		elif a == "hard":
			hard = true
		elif a.begins_with("lag="):
			lag = int(a.split("=")[1])
	session = Session.new()
	session.port = port
	session.use_router = false
	session.test_drop = drop
	session.test_lag = lag
	root.add_child(session)
	Net.session = session
	if dump_path != "":
		session.dump = FileAccess.open(dump_path, FileAccess.WRITE)
	session.start_game.connect(_make_game)
	session.ended.connect(func(reason):
		if linger < 0:
			print("FAIL: the session ended early: %s" % reason)
			quit(1))
	physics_frame.connect(_lobby)


## Before the game: the host waits for the joiner and a few pings, then starts.
func _lobby() -> void:
	if slow > 0:
		OS.delay_msec(slow)
	if linger >= 0:
		if Time.get_ticks_msec() >= linger:
			quit(0 if result_ok else 1)
		return
	if session.playing:
		return
	if session.peer == null and session.error == "":
		# The first frame: the session is in the tree now, so it can connect.
		if role == "host":
			session.host()
		else:
			session.join("127.0.0.1")
	if session.error != "":
		print("FAIL: %s" % session.error)
		quit(1)
		return
	if role == "host" and session.linked:
		wait_frames += 1
		if wait_frames == 60:
			print("[%s] ping %.1f ms, delay %d ticks" % [role, session.ping_ms, session.pick_delay()])
			session.start("arena" if arena else "cave")


func _make_game(mode: String) -> void:
	me = session.my_index
	started = Time.get_ticks_msec()
	m = load("res://scripts/cave/cave.gd" if mode == "cave" else "res://scripts/main.gd").new()
	m.inputs = [PlayerInput.make("net"), PlayerInput.make("net")]
	m.min_hp = 0.0 if hard else 60.0
	m.test_commands = true
	m.exit_to_title.connect(func(): finished = true)
	root.add_child(m)
	session.attach(m)
	session.local = PlayerInput.make("script")
	# Player one's bot plays on a controller (it aims with the stick); player two's
	# plays with a mouse (see _fight), so both ways of aiming cross the network.
	session.local.using_pad = me == 0
	session.sampling.connect(_arena_tick if arena else _tick)
	print("[%s] playing as player %d, delay %d ticks" % [role, me + 1, session.delay])


func _inp(i: int):
	return session.local if i == me else spare


func _tick() -> void:
	# (stage_frames still holds last tick's count here, so 149 means the 150th tick.)
	if hard and me == 0 and m.stage in ["fight2", "boss"] and m.stage == last_stage and stage_frames == 149 and not wipes_done.has(m.stage):
		wipes_done[m.stage] = true
		print("        (knocking everyone out in %s)" % m.stage)
		Net.command(["test_ko"])
	super._tick()


func _via(from: Vector2, target: Vector2) -> Vector2:
	return target if arena else super._via(from, target)


func _fight(i: int) -> void:
	super._fight(i)
	if i == me and me == 1:
		session.local.aim_offset = session.local.stick_aim * 90.0
		session.local.stick_aim = Vector2.ZERO


## Online each player has their own forge screen: nobody waits for a turn.
func _forge_stage(stage: String) -> void:
	var T: float = m.TILE
	var ok: bool = m._fitted(me) if stage == "forge" else m._tin_done(me)
	if ok or m.is_forging(me):
		session.local.move = Vector2.ZERO
	elif _go(me, Vector2(20.5 + (me - 0.5) * 1.6, 7.75) * T, 22.0) and frame % 10 == 0:
		forge_step = 0
		_press(me, "interact")


## The arena: fight, open the forge with the hotkey, change the sword, close it,
## pause and restart spawning. Ends after 40 seconds of game time.
func _arena_tick() -> void:
	frame += 1
	_clear_presses()
	if frame > 60 * 40:
		session.sampling.disconnect(_arena_tick)
		_report(m.kills > 0)
		return
	if m.build_menu.is_open:
		forge_wait += 1
		if forge_wait % 25 == 0:
			var forge = m.build_menu
			if forge.finishing >= 0.0:
				forge._really_close()
			elif arena_step == 0:
				forge._load_test("B" if me == 0 else "A")
				arena_step = 1
			elif arena_step == 1:
				forge._set_tab(1)
				forge.selected = 0
				forge._use_card(1 + me)
				arena_step = 2
			else:
				forge.close()
				arena_step = 0
		return
	# Each player opens their forge at a different moment, and once at the same one.
	if frame in [300 + me * 140, 1200]:
		Net.command(["forge_open"])
	if me == 0 and frame in [700, 900]:
		Net.command(["spawning"])
	_fight(me)
	# The active runes: a press on each button now and then, the first one held
	# for a while (a Whirlwind there spins on), at different moments for each player.
	var beat := (frame + me * 55) % 200
	session.local.ability_pressed = [beat == 40, beat == 120]
	session.local.ability_held = [beat >= 40 and beat < 85, beat == 120]


func _done(ok: bool) -> void:
	if session.sampling.is_connected(_tick):
		session.sampling.disconnect(_tick)
	super._done(ok)


func _quit(ok: bool) -> void:
	if hard and m.knockouts < 4:
		print("FAIL: the knock-outs didn't happen (%d)" % m.knockouts)
		ok = false
	_report(ok)


## Says how it went, then stays connected for a moment so the other copy can
## finish its last ticks too.
func _report(ok: bool) -> void:
	if session.desynced:
		print("FAIL: the two games went out of sync (see user://out_of_sync_player%d.txt)" % (me + 1))
		ok = false
	if arena:
		print("%s: arena, %d kills, swords %s" % ["PASS" if ok else "FAIL", m.kills, str([m.builds[0].get_data(), m.builds[1].get_data()])])
	print("[%s] %s at tick %d (waited on %d frames, %.0f s on the clock), last checksum %d" % [role, "ok" if ok else "FAILED", session.tick, session.waits, float(Time.get_ticks_msec() - started) / 1000.0, int(session._hashes.get(session._last_hash_tick, 0))])
	result_ok = ok
	linger = Time.get_ticks_msec() + 2500
