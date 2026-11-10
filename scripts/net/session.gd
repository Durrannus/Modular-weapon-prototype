extends Node
## Online play for two players, one on each computer.
##
## HOW IT WORKS, IN SHORT
## Both computers run the whole game themselves. The only thing sent between them
## is what each player pressed. Every press is acted on a few ticks later (the
## "delay", usually 2 to 5 sixtieths of a second), on both computers, on the same
## tick. Both games start the same and get the same presses on the same ticks, so
## they stay identical: enemies, the boss, the forge, everything, without any of
## that needing network code of its own.
##
## If a computer hasn't yet received the other player's presses for the next
## tick, it waits (the game holds still for a moment). Every twenty ticks the two
## compare a checksum of the game; if they ever differ, a warning shows.
##
## WHAT THIS ASKS OF THE REST OF THE GAME
## - Anything that decides what happens runs in _physics_process, never _process.
## - Random numbers that matter come from scripts/sim.gd, never plain randf().
## - Nothing reads Input for gameplay: players only read their PlayerInput.
## - A choice made in a menu (a sword change, closing the forge) is sent with
##   Net.command() and applied on a tick, in the game's net_command().
## - Nothing but this script pauses the tree while online.

signal lobby_changed               # something the "Play online" screen shows has changed
signal start_game(mode: String)    # both computers: make the game now, then call attach()
signal ended(reason: String)       # the session is over; reason is shown on the title screen
signal sampling                    # just before this computer's controls are read (tests drive bots from here)

const PlayerInput := preload("res://scripts/player_input.gd")
const Net := preload("res://scripts/net/net.gd")
const Sim := preload("res://scripts/sim.gd")
const PortOpener := preload("res://scripts/net/port_opener.gd")
const Art := preload("res://scripts/art.gd")

const PROTOCOL := 1                # change when the messages below change
const PORT := 24565
const INPUT_BYTES := 14            # one player's controls for one tick
const HASH_EVERY := 20             # ticks between checksums
const MIN_DELAY := 2
const MAX_DELAY := 12
const WAIT_NOTICE := 0.7           # seconds of waiting before "Waiting for your friend" shows
const WAIT_GIVE_UP := 20.0
const JOIN_GIVE_UP := 8.0
const RESEND_MS := 12              # while waiting, ask again this often

var port := PORT
var use_router := true             # ask the router to open the port when hosting
var peer: ENetMultiplayerPeer = null
var hosting := false
var my_index := 0                  # which player this computer is: the host is 0
var other_id := 0                  # the other computer's id on the connection (0 = nobody)
var linked := false                # connected, and both copies of the game match
var playing := false               # a game is running
var status := ""                   # one line for the "Play online" screen
var error := ""                    # the last thing that went wrong, for the same screen
var ping_ms := -1.0
var opener: PortOpener = null

var game: Node = null
var local: PlayerInput             # this computer's controls
var mode := ""
var delay := 3                     # ticks between pressing and acting
var tick := 0                      # the next tick to run
var desynced := false
var waits := 0                     # how many frames this game has spent waiting for the other computer
var test_drop := 0.0               # tests: lose this share of the packets on purpose
var test_lag := 0                  # tests: hold every packet back this many milliseconds (a far-away friend)
var _held: Array = []              # [[clock milliseconds to send at, what to send]]
var dump: FileAccess = null        # tests: every checksum and what went into it

var _build := ""
var _game_id := 0
var _inputs: Array = [{}, {}]      # per player: tick -> their controls for that tick
var _outbox := {}                  # my controls the other computer hasn't confirmed yet
var _newest := -1                  # the newest tick my controls are known for
var _got_upto := -1                # I have the other player's controls for every tick up to this
var _peer_got_upto := -1           # and they have mine up to this
var _cmds: Array = []              # menu choices waiting to go out with the next tick
var _hashes := {}                  # tick -> my checksum
var _dumps := {}                   # tick -> what went into it (for the out-of-sync report)
var _their_hashes := {}
var _last_hash_tick := -1
var _wait_from := -1                # when the current wait began (clock milliseconds), -1 = not waiting
var _need_release := false
var _ping_at := 0                   # clock milliseconds of the next ping
var _rtts: Array = []
var _join_from := 0
var _left := false
var _resent_at := 0
var _polling := false               # inside multiplayer.poll(): the connection mustn't be closed under it
var _closing: Array = []            # connections to close as soon as the poll returns
var _overlay: CanvasLayer
var _note: Label
var _warn: Label


func _init() -> void:
	name = "NetSession"            # the same path on both computers, so their messages find each other
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -1000   # first thing every tick, before the game moves
	local = PlayerInput.make("any")


func _ready() -> void:
	_build = build_id()
	_make_overlay()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func _exit_tree() -> void:
	_polling = false
	_shut()


# --- Hosting and joining --------------------------------------------------------

## Opens a game for a friend to join. False (with `error` set) if the port is taken.
func host() -> bool:
	_shut()
	error = ""
	peer = ENetMultiplayerPeer.new()
	if peer.create_server(port, 1) != OK:
		peer = null
		error = "Couldn't open port %d on this computer. Is another copy of the game already hosting?" % port
		lobby_changed.emit()
		return false
	hosting = true
	my_index = 0
	_use_peer()
	if use_router:
		opener = PortOpener.new()
		opener.open(port)
	status = "Waiting for your friend to join."
	lobby_changed.emit()
	return true


## Connects to a friend who is hosting. `address` is what their screen shows,
## with ":port" on the end only if they changed the port.
func join(address: String) -> bool:
	_shut()
	error = ""
	var where := address.strip_edges()
	var to_port := port
	if where.begins_with("[") and "]" in where:
		# An IPv6 address in brackets, perhaps with a port: [2001:db8::1]:24565
		var rest := where.substr(where.find("]") + 1)
		if rest.begins_with(":") and rest.substr(1).is_valid_int():
			to_port = int(rest.substr(1))
		where = where.substr(1, where.find("]") - 1)
	elif where.count(":") == 1:
		var parts := where.split(":")
		where = parts[0]
		if parts[1].is_valid_int():
			to_port = int(parts[1])
	if where == "":
		error = "Type the address your friend's screen shows."
		lobby_changed.emit()
		return false
	peer = ENetMultiplayerPeer.new()
	if peer.create_client(where, to_port) != OK:
		peer = null
		error = "That doesn't look like an address. It should look like 81.2.69.160"
		lobby_changed.emit()
		return false
	hosting = false
	my_index = 1
	_use_peer()
	_join_from = Time.get_ticks_msec()
	status = "Connecting..."
	lobby_changed.emit()
	return true


func _use_peer() -> void:
	# The connection is read at the top of every game tick (see _physics_process),
	# so presses are never left waiting for the next drawn frame.
	get_tree().multiplayer_poll = false
	multiplayer.multiplayer_peer = peer


## Closes the connection (and the router's port) without ending the session.
func _shut() -> void:
	if opener != null:
		opener.close()
		opener = null
	if peer != null:
		# Closing a connection while Godot is in the middle of reading from it
		# crashes, so if that is where we are, it waits until the read is done.
		_closing.append(peer)
		peer = null
		if not _polling:
			_close_waiting()
	linked = false
	other_id = 0
	ping_ms = -1.0
	_rtts.clear()


func _close_waiting() -> void:
	for old in _closing:
		(old as ENetMultiplayerPeer).close()
	_closing.clear()
	if peer == null and is_inside_tree():
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		get_tree().multiplayer_poll = true


## Stops hosting or joining, but keeps the session for another try.
func close() -> void:
	if peer != null and other_id != 0:
		_bye.rpc_id(other_id)
		peer.host.flush()
	_shut()
	status = ""
	error = ""
	lobby_changed.emit()


## The addresses a friend could type to reach this computer.
## {router: "asking" / "open" / "shared" / "failed" / "off", internet: "81.2.69.160" or "", local: ["192.168.1.20", ...]}
func addresses() -> Dictionary:
	var local_ones: Array = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			local_ones.append(a)
	var out := {"router": "off", "internet": "", "local": local_ones}
	if opener != null:
		out["router"] = opener.state
		if opener.state == "open":
			out["internet"] = opener.address
	return out


## What kind of network an address like 192.168.1.20 belongs to, for the lobby.
static func describe(ip: String) -> String:
	var p := ip.split(".")
	var a := int(p[0])
	var b := int(p[1]) if p.size() > 1 else 0
	if a == 100 and b >= 64 and b <= 127:
		return "Tailscale"
	if a == 26:
		return "Radmin VPN"
	if a == 25:
		return "Hamachi"
	if PortOpener.is_private(ip):
		return "same Wi-Fi or network"
	return "internet"


# --- The handshake ----------------------------------------------------------------

## A fingerprint of everything that decides how the game plays: every script and
## the numbers that come with the art. Two computers can only play together if
## theirs match, or the two games would drift apart within seconds.
static func build_id() -> String:
	var files: Array = []
	_list("res://scripts", [".gd"], files)
	_list("res://art", [".json"], files)
	_list("res://parts", [".tres"], files)
	files.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for path in files:
		ctx.update(("%s\n" % path).to_utf8_buffer())
		# Windows may save the same file with different line endings: ignore those.
		ctx.update(FileAccess.get_file_as_string(path).replace("\r", "").to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 12)


static func _list(dir_path: String, endings: Array, into: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_list(dir_path + "/" + sub, endings, into)
	for f in dir.get_files():
		for ending in endings:
			if f.ends_with(ending):
				into.append(dir_path + "/" + f)


func _my_info() -> Dictionary:
	var v := Engine.get_version_info()
	return {"protocol": PROTOCOL, "engine": "%d.%d.%d %s" % [v["major"], v["minor"], v["patch"], v["status"]], "build": _build}


## Why these two copies can't play together ("" if they can).
func _mismatch(theirs: Dictionary) -> String:
	var mine := _my_info()
	if str(theirs.get("engine", "")) != str(mine["engine"]):
		return "You two are running different versions of Godot (%s and %s). You both need the same one." % [str(theirs.get("engine", "?")), mine["engine"]]
	if int(theirs.get("protocol", -1)) != PROTOCOL or str(theirs.get("build", "")) != str(mine["build"]):
		return "Your two copies of the game are different. Look at the version number in the bottom-left corner: you both need the same one."
	return ""


func _on_peer_connected(_id: int) -> void:
	if hosting and not linked:
		status = "Someone is joining..."
		lobby_changed.emit()


## (The joining computer.) Connected: say which copy of the game this is.
func _on_connected() -> void:
	other_id = 1
	status = "Connected. Checking that your two copies of the game match..."
	_hello.rpc_id(1, _my_info())
	lobby_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _hello(info: Dictionary) -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	var why := "That game already has two players." if linked else _mismatch(info)
	if why != "":
		_refuse.rpc_id(id, why)
		var pp := peer.get_peer(id)
		if pp != null:
			pp.peer_disconnect_later()
		if not linked:
			error = "Your friend tried to join, but: " + why
			status = "Waiting for your friend to join."
			lobby_changed.emit()
		return
	other_id = id
	linked = true
	error = ""
	_rtts.clear()
	ping_ms = -1.0
	_welcome.rpc_id(id)
	status = "Your friend has joined. Pick what to play."
	lobby_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _welcome() -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1:
		return
	linked = true
	status = "Connected. Waiting for your friend to start the game."
	lobby_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _refuse(why: String) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1:
		return
	_fail(why)


func _fail(why: String) -> void:
	_shut()
	status = ""
	error = why
	lobby_changed.emit()


func _on_failed() -> void:
	_fail("Couldn't reach that address. Check it against your friend's screen, and that they are still hosting.")


func _on_server_gone() -> void:
	if playing:
		leave("Your friend left the game.", false)
	else:
		_fail("Your friend stopped hosting.")


func _on_peer_disconnected(id: int) -> void:
	if id != other_id:
		return
	if playing:
		leave("Your friend left the game.", false)
	elif hosting:
		linked = false
		other_id = 0
		ping_ms = -1.0
		status = "Your friend left. Waiting for them to join again."
		lobby_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _bye() -> void:
	if multiplayer.get_remote_sender_id() == other_id:
		_on_peer_disconnected(other_id) if hosting else _on_server_gone()


# --- Ping -------------------------------------------------------------------------

## Sends now, or (tests) after test_lag milliseconds, as if the other computer were far away.
func _post(send: Callable) -> void:
	if test_lag <= 0:
		send.call()
		peer.host.flush()
	else:
		_held.append([Time.get_ticks_msec() + test_lag, send])


func _post_held() -> void:
	var now := Time.get_ticks_msec()
	var sent := false
	while not _held.is_empty() and int(_held[0][0]) <= now:
		(_held.pop_front()[1] as Callable).call()
		sent = true
	if sent:
		peer.host.flush()


@rpc("any_peer", "call_remote", "unreliable")
func _ping(sent_at: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == other_id:
		_post(func(): _pong.rpc_id(id, sent_at))


@rpc("any_peer", "call_remote", "unreliable")
func _pong(sent_at: int) -> void:
	if multiplayer.get_remote_sender_id() != other_id:
		return
	_rtts.append(float(Time.get_ticks_usec() - sent_at) / 1000.0)
	while _rtts.size() > 12:
		_rtts.pop_front()
	var sorted := _rtts.duplicate()
	sorted.sort()
	var was := ping_ms
	ping_ms = sorted[sorted.size() / 2]
	if absf(was - ping_ms) >= 1.0:
		lobby_changed.emit()


## How many ticks to wait between a press and acting on it: long enough for the
## press to reach the other computer first, with a little room for hiccups.
func pick_delay() -> int:
	if _rtts.is_empty():
		return 4
	var sorted := _rtts.duplicate()
	sorted.sort()
	var there_and_back: float = sorted[int(float(sorted.size() - 1) * 0.75)]
	return clampi(ceili((there_and_back * 0.5 + 8.0) / (1000.0 / 60.0)) + 1, MIN_DELAY, MAX_DELAY)


# --- Starting and stopping a game ---------------------------------------------------

## (The host.) Starts the game on both computers. mode: "cave" or "arena".
func start(mode_: String) -> void:
	if not hosting or not linked or playing:
		return
	var id := _game_id + 1
	var seed_value := randi()
	var ticks := pick_delay()
	_start.rpc_id(other_id, id, mode_, seed_value, ticks)
	_begin(id, mode_, seed_value, ticks)


@rpc("any_peer", "call_remote", "reliable")
func _start(id: int, mode_: String, seed_value: int, ticks: int) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or not linked or playing:
		return
	if mode_ in ["cave", "arena"]:
		_begin(id, mode_, seed_value, ticks)


func _begin(id: int, mode_: String, seed_value: int, ticks: int) -> void:
	_game_id = id
	mode = mode_
	delay = clampi(ticks, MIN_DELAY, MAX_DELAY)
	playing = true
	game = null
	tick = 0
	waits = 0
	desynced = false
	_warn.visible = false
	_cmds.clear()
	_outbox.clear()
	_hashes.clear()
	_dumps.clear()
	_their_hashes.clear()
	_last_hash_tick = -1
	_wait_from = -1
	_need_release = true
	# Nobody could have pressed anything for the first `delay` ticks: they are empty.
	_inputs = [{}, {}]
	for t in delay:
		for i in 2:
			_inputs[i][t] = _neutral()
	_newest = delay - 1
	_got_upto = delay - 1
	_peer_got_upto = delay - 1
	Sim.seed_with(seed_value)
	# Hold everything still until the game exists; tick 0 starts it (see _step).
	get_tree().paused = true
	_announce_start.call_deferred()


func _announce_start() -> void:
	if playing:
		start_game.emit(mode)


## Call once the game made for start_game is in the tree.
func attach(game_: Node) -> void:
	game = game_
	local.clear()
	print("Online: player %d, %d ticks of delay (%d ms), build %s" % [my_index + 1, delay, roundi(delay * 1000.0 / 60.0), _build])


## The game finished on both computers at once (the end of the cave): back to the
## lobby, still connected, ready for another go.
func stop_game() -> void:
	playing = false
	game = null
	_note.visible = false
	get_tree().paused = false
	if linked:
		status = "Your friend is here. Pick what to play." if hosting else "Connected. Waiting for your friend to start the game."
	lobby_changed.emit()


## Ends the session and tells whoever is listening why.
func leave(reason := "", tell_friend := true) -> void:
	if _left:
		return
	_left = true
	if tell_friend and peer != null and other_id != 0:
		_bye.rpc_id(other_id)
		peer.host.flush()
	_held.clear()
	_shut()
	playing = false
	game = null
	if Net.session == self:
		Net.session = null
	if is_inside_tree():
		get_tree().paused = false
	_overlay.visible = false
	ended.emit(reason)
	queue_free()


# --- Every tick ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if playing:
		local.feed(event)


func _physics_process(_delta: float) -> void:
	if peer == null:
		return
	_polling = true
	multiplayer.poll()
	_polling = false
	if not _closing.is_empty():
		_close_waiting()
	if peer == null:   # something that just arrived closed the connection
		return
	if opener != null and opener.poll():
		lobby_changed.emit()
	if not _held.is_empty():
		_post_held()
	if not playing:
		_lobby_tick()
	elif is_instance_valid(game):
		_step()


## Waiting is timed by the clock, not by game ticks: the game may be standing still.
func _lobby_tick() -> void:
	var now := Time.get_ticks_msec()
	if not hosting and not linked and float(now - _join_from) / 1000.0 > JOIN_GIVE_UP:
		_on_failed()
		return
	if linked and now >= _ping_at:
		_ping_at = now + 250
		var sent_at := Time.get_ticks_usec()
		_post(func(): _ping.rpc_id(other_id, sent_at))


## Runs one tick of the game if everyone's controls for it are here; waits if not.
func _step() -> void:
	if not (_inputs[0].has(tick) and _inputs[1].has(tick)):
		get_tree().paused = true
		waits += 1
		var now := Time.get_ticks_msec()
		if _wait_from < 0:
			_wait_from = now
		var waited := float(now - _wait_from) / 1000.0
		_note.visible = waited > WAIT_NOTICE
		# Send again, in case the last lot was lost on the way (but not in a flood).
		if now - _resent_at >= RESEND_MS:
			_resent_at = now
			_send_inputs()
		if waited > WAIT_GIVE_UP:
			leave("Lost the connection to your friend.")
		return
	_wait_from = -1
	_note.visible = false
	get_tree().paused = false
	# This computer's controls now, to be acted on `delay` ticks from now.
	sampling.emit()
	_newest = tick + delay
	var mine := _sample()
	_inputs[my_index][_newest] = mine
	_outbox[_newest] = mine
	if tick % HASH_EVERY == 0:
		_checksum()
	_send_inputs()
	# Everyone's controls for this tick. The game's own _physics_process runs
	# after this one and acts on them.
	for i in 2:
		_apply(i, _inputs[i][tick])
		_inputs[i].erase(tick)
	tick += 1


static func _neutral() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(INPUT_BYTES)
	b.fill(0)
	return b


func _menu_open() -> bool:
	return (game.get("build_menu") != null and game.build_menu.is_open) or (game.get("pause_menu") != null and game.pause_menu.is_open())


## This computer's controls, packed into a few bytes:
##   byte 0      bits: 1 attack held, 2 attack pressed, 4 dodge pressed, 8 use pressed,
##               16 on a controller, 32 menu choices follow
##   bytes 1-2   move (x, y) from -127 to 127
##   bytes 3-4   right stick the same way
##   bytes 5-12  the mouse, as an offset from the player (two 32-bit floats)
##   byte 13     the ability buttons: 1 first held, 2 first pressed, 4 second held,
##               8 second pressed
##   then, if bit 32 is set, the menu choices made since the last tick
func _sample() -> PackedByteArray:
	local.poll()
	var b := _neutral()
	var flags := 16 if local.using_pad else 0
	if _menu_open():
		# A menu is open on this computer: the player stands still.
		_need_release = true
	else:
		var held := local.attack_held
		var pressed := [local.attack_pressed, local.dash_pressed, local.interact_pressed]
		var ability := 0
		for k in 2:
			if local.ability_held[k]:
				ability |= 1 << (k * 2)
			if local.ability_pressed[k]:
				ability |= 2 << (k * 2)
		if _need_release:
			# The click or button that closed a menu shouldn't also swing or dodge.
			pressed = [false, false, false]
			ability = 0
			if held:
				held = false
			else:
				_need_release = false
		b[13] = ability
		if held:
			flags |= 1
		if pressed[0]:
			flags |= 2
		if pressed[1]:
			flags |= 4
		if pressed[2]:
			flags |= 8
		b.encode_s8(1, roundi(clampf(local.move.x, -1.0, 1.0) * 127.0))
		b.encode_s8(2, roundi(clampf(local.move.y, -1.0, 1.0) * 127.0))
		b.encode_s8(3, roundi(clampf(local.stick_aim.x, -1.0, 1.0) * 127.0))
		b.encode_s8(4, roundi(clampf(local.stick_aim.y, -1.0, 1.0) * 127.0))
		var offset := local.aim_offset
		if local.kind != "script" and my_index < game.players.size():
			var me: Node2D = game.players[my_index]
			offset = me.get_global_mouse_position() - me.global_position
		b.encode_float(5, offset.x)
		b.encode_float(9, offset.y)
	if not _cmds.is_empty():
		flags |= 32
		b.append_array(var_to_bytes(_cmds))
		_cmds = []
	b[0] = flags
	return b


## Hands player i's controls for this tick to their player in the game. Both
## computers unpack the same bytes, so both see exactly the same numbers.
func _apply(i: int, b: PackedByteArray) -> void:
	if i >= game.players.size() or b.size() < INPUT_BYTES:
		return
	var inp: PlayerInput = game.players[i].input
	var flags := b[0]
	inp.attack_held = flags & 1 != 0
	inp.attack_pressed = flags & 2 != 0
	inp.dash_pressed = flags & 4 != 0
	inp.interact_pressed = flags & 8 != 0
	inp.using_pad = flags & 16 != 0
	inp.move = (Vector2(b.decode_s8(1), b.decode_s8(2)) / 127.0).limit_length(1.0)
	inp.stick_aim = (Vector2(b.decode_s8(3), b.decode_s8(4)) / 127.0).limit_length(1.0)
	inp.aim_offset = Vector2(b.decode_float(5), b.decode_float(9))
	inp.ability_held = [b[13] & 1 != 0, b[13] & 4 != 0]
	inp.ability_pressed = [b[13] & 2 != 0, b[13] & 8 != 0]
	if flags & 32 != 0 and b.size() > INPUT_BYTES:
		var cmds = bytes_to_var(b.slice(INPUT_BYTES))
		if cmds is Array:
			for c in cmds:
				if c is Array and not c.is_empty() and c[0] is String:
					game.net_command(i, c)


## A menu choice by this computer's player, to happen on both computers on the
## same tick. cmd is [name, values...]; see net_command() in game_base.gd.
func command(cmd: Array) -> void:
	if playing:
		_cmds.append(cmd)


## Sends every tick of my controls the other computer hasn't confirmed, so one
## lost packet costs nothing: the next one carries the same ticks again.
func _send_inputs() -> void:
	if peer == null or other_id == 0:
		return
	if test_drop > 0.0 and randf() < test_drop:
		return
	var first := _peer_got_upto + 1
	var blobs: Array = []
	var t := first
	while t <= _newest and blobs.size() < 60:
		blobs.append(_outbox.get(t, _neutral()))
		t += 1
	var id := _game_id
	var got := _got_upto
	var hash_tick := _last_hash_tick
	var hash_value := int(_hashes.get(_last_hash_tick, 0))
	_post(func(): _take_inputs.rpc_id(other_id, id, first, blobs, got, hash_tick, hash_value))


@rpc("any_peer", "call_remote", "unreliable", 1)
func _take_inputs(id: int, first: int, blobs: Array, got: int, hash_tick: int, hash_value: int) -> void:
	if not playing or id != _game_id or multiplayer.get_remote_sender_id() != other_id:
		return
	var them := 1 - my_index
	if blobs.size() <= 64:
		for k in blobs.size():
			var t := first + k
			var b = blobs[k]
			if t > _got_upto and t < tick + 600 and b is PackedByteArray and b.size() >= INPUT_BYTES and b.size() <= 4096 and not _inputs[them].has(t):
				_inputs[them][t] = b
	while _inputs[them].has(_got_upto + 1):
		_got_upto += 1
	if got > _peer_got_upto and got <= _newest:
		for t in range(_peer_got_upto + 1, got + 1):
			_outbox.erase(t)
		_peer_got_upto = got
	if hash_tick >= 0:
		if _hashes.has(hash_tick):
			if int(_hashes[hash_tick]) != hash_value:
				_out_of_sync(hash_tick)
		elif hash_tick >= tick:
			_their_hashes[hash_tick] = hash_value


# --- Checking the two games still match -----------------------------------------------

func _checksum() -> void:
	var state: Array = [tick]
	state.append_array(game.net_state())
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(var_to_bytes(state))
	var h := ctx.finish().decode_s64(0)
	_hashes[tick] = h
	_dumps[tick] = state
	_last_hash_tick = tick
	if dump != null:
		dump.store_line("%d %d %s" % [tick, h, var_to_str(state).replace("\n", " ")])
	if _their_hashes.has(tick) and int(_their_hashes[tick]) != h:
		_out_of_sync(tick)
	for old in [tick - HASH_EVERY * 30]:
		_hashes.erase(old)
		_dumps.erase(old)
		_their_hashes.erase(old)


func _out_of_sync(at_tick: int) -> void:
	if desynced:
		return
	desynced = true
	_warn.visible = true
	push_warning("Online: the two games no longer match (first seen at tick %d)." % at_tick)
	# Keep what this computer thought was going on, to compare with the other's.
	var f := FileAccess.open("user://out_of_sync_player%d.txt" % (my_index + 1), FileAccess.WRITE)
	if f != null:
		f.store_line("Out of sync at tick %d. Build %s, delay %d, mode %s." % [at_tick, _build, delay, mode])
		var ticks := _dumps.keys()
		ticks.sort()
		for t in ticks:
			f.store_line("%d %d %s" % [t, int(_hashes.get(t, 0)), var_to_str(_dumps[t]).replace("\n", " ")])


# --- On-screen notes ------------------------------------------------------------------

func _make_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 60
	add_child(_overlay)
	_note = _label("Waiting for your friend...", Color("#e8e4bc"), 150.0)
	_warn = _label("Out of sync: your two games no longer match. Leave and start again.", Color("#f06a40"), 8.0)


func _label(text: String, col: Color, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(640, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var f := Art.font("PixelifySans-Regular")
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#19142a"))
	l.add_theme_constant_override("outline_size", 4)
	l.visible = false
	_overlay.add_child(l)
	return l
