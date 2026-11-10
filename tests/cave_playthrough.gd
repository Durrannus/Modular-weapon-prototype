extends SceneTree
## Plays the tutorial cave from start to finish with scripted players, to prove
## the whole run works: crate, crawlers, burrowers, the rune, the forge, the
## guardian, the smith, the tin sword and the stairs.
##   godot --headless --path . --fixed-fps 60 -s tests/cave_playthrough.gd -- [players=2] [shots] [mortal]
## The bots can't be knocked out unless "mortal" is given (they dodge badly).
## "wipe" knocks everyone out once in room 2 and once at the boss, to prove both
## start over. "down" (two players) knocks player two out in room 1, to prove the
## other can finish the room and that player two gets back up.
## With "shots" (needs a window, so leave out --headless) it saves a screenshot of
## each stage to the game's user folder, or to the folder in shots=/some/folder.

const PlayerInput := preload("res://scripts/player_input.gd")
var shot_dir := "user://cave_shots/"   # or shots=/some/folder/

var m
var n_players := 1
var shots := false
var mortal := false
var test_wipe := false
var test_down := false
var wipes_done := {}
var down_seen := false
var got_up := false
var frame := 0
var stage_seen := {}
var stage_frames := 0
var last_stage := ""
var stuck := {}        # player index -> [last position, frames without progress, strafe frames left, strafe side]
var forge_step := 0
var forge_wait := 0
var finished := false
var shot_queue: Array = []
var hits_taken := 0
var hits_by_stage := {}
var last_hp: Array = []


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("players="):
			n_players = int(a.split("=")[1])
		elif a == "shots" or a.begins_with("shots="):
			shots = true
			if a.begins_with("shots="):
				shot_dir = a.split("=")[1].rstrip("/") + "/"
		elif a == "mortal":
			mortal = true
		elif a == "wipe":
			test_wipe = true
		elif a == "down":
			test_down = true
	_begin()


## Where bot i's presses go: straight into that player's controls. (The online
## test sends them through the network session; see tests/online_cave.gd.)
func _inp(i: int):
	return m.players[i].input


func _begin() -> void:
	m = load("res://scripts/cave/cave.gd").new()
	var inputs: Array = []
	for i in n_players:
		inputs.append(PlayerInput.make("script"))
	m.inputs = inputs
	m.exit_to_title.connect(func(): finished = true)
	root.add_child(m)
	physics_frame.connect(_tick)
	if shots:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))


func _shot(name: String) -> void:
	if not shots or stage_seen.has("shot_" + name):
		return
	stage_seen["shot_" + name] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shot_dir + name + ".png")


## The halls between rooms are narrow: a bot that's in a room further south than
## its target lines up with the hall first, then walks through.
func _via(from: Vector2, target: Vector2) -> Vector2:
	var T: float = m.TILE
	var mid: float = m.CENTRE_X * T
	for h in m.HALLS:
		var top := float(h.position.y) * T
		var bottom := float(h.end.y) * T
		if from.y > top and target.y < top:
			if from.y > bottom + 8.0 and absf(from.x - mid) > 20.0:
				return Vector2(mid, bottom + 0.9 * T)
			return Vector2(mid, top - 0.9 * T)
	return target


func _go(i: int, target: Vector2, stop := 10.0) -> bool:
	var p = m.players[i]
	var inp = _inp(i)
	var via := _via(p.global_position, target)
	var to: Vector2 = via - p.global_position
	if via == target and to.length() <= stop:
		inp.move = Vector2.ZERO
		stuck.erase(i)
		return true
	var dir := to.normalized()
	# Stuck on a rock or a prop: slide sideways for a moment, longer each time.
	var s: Array = stuck.get(i, [p.global_position, 0, 0, 1.0, 0])
	if s[2] > 0:
		s[2] -= 1
		dir = (dir * 0.2 + dir.orthogonal() * float(s[3])).normalized()
	else:
		if p.global_position.distance_to(s[0]) < 1.0:
			s[1] += 1
		else:
			s[1] = 0
		if s[1] > 14:
			s[1] = 0
			s[4] += 1
			s[2] = 26 + 14 * int(s[4])
			s[3] = -float(s[3])
	s[0] = p.global_position
	stuck[i] = s
	inp.move = dir
	return false


func _press(i: int, what: String) -> void:
	var inp = _inp(i)
	match what:
		"interact": inp.interact_pressed = true
		"attack": inp.attack_pressed = true
		"dash": inp.dash_pressed = true


func _clear_presses() -> void:
	for i in m.players.size():
		var inp = _inp(i)
		inp.interact_pressed = false
		inp.attack_pressed = false
		inp.dash_pressed = false
		inp.attack_held = false
		inp.stick_aim = Vector2.ZERO
		inp.move = Vector2.ZERO


func _nearest_foe(from: Vector2):
	var best = null
	var best_d := INF
	for e in get_nodes_in_group("foes"):
		if not is_instance_valid(e) or e.dead:
			continue
		if e.kind == "guardian" and e.mode in ["dormant", "wake", "dead"]:
			continue
		var d: float = e.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = e
	return best


func _fight(i: int) -> void:
	var p = m.players[i]
	var inp = _inp(i)
	var foe = _nearest_foe(p.global_position)
	if foe == null:
		inp.move = Vector2.ZERO
		return
	var rel: Vector2 = foe.global_position - p.global_position
	var reach := 46.0 + float(foe.radius)
	# Step out of the way of anything about to land.
	for h in get_nodes_in_group("hazards"):
		if h.shape == "circle" and h.global_position.distance_to(p.global_position) < h.radius + 30.0 and h.t > h.delay - 0.35:
			inp.move = _escape(p, h.global_position)
			if p.dodge_charges > 0:
				inp.dash_pressed = true
			return
	# The cracks of the guardian's quake: step sideways off the one you're standing on.
	for h in get_nodes_in_group("hazards"):
		if h.shape == "lane" and h.damage > 0.0:
			var off: Vector2 = p.global_position - h.global_position
			var across: float = off.dot(h.dir.orthogonal())
			if off.dot(h.dir) > -10.0 and off.dot(h.dir) < h.length + 10.0 and absf(across) < h.width * 0.5 + 16.0:
				inp.move = h.dir.orthogonal() * (1.0 if across >= 0.0 else -1.0)
				return
	if foe.kind == "guardian" and foe.mode in ["charge_ready", "charge"]:
		var side: Vector2 = foe.charge_dir.orthogonal()
		if side.dot(p.global_position - foe.global_position) < 0.0:
			side = -side
		inp.move = side
		if foe.mode == "charge" and p.dodge_charges > 0:
			inp.dash_pressed = true
		return
	if foe.kind == "burrower" and foe.mode in ["warn", "lunge"]:
		var side2: Vector2 = foe.lunge_dir.orthogonal()
		if side2.dot(p.global_position - foe.global_position) < 0.0:
			side2 = -side2
		inp.move = side2
		if foe.mode_t < 0.2 and p.dodge_charges > 0:
			inp.dash_pressed = true
		return
	if rel.length() > reach:
		_go(i, foe.global_position, reach)
	else:
		inp.move = Vector2.ZERO
	if rel.length() < reach + 30.0:
		inp.stick_aim = rel.normalized()
		inp.attack_held = true
		if p.current_step < 0:
			inp.attack_pressed = true


## The way out of a circle: straight away from its middle, unless a wall is in
## the way, in which case the nearest open direction to that.
func _escape(p, from: Vector2) -> Vector2:
	var away: Vector2 = p.global_position - from
	away = away.normalized() if away.length() > 1.0 else Vector2.DOWN
	for turn in [0.0, 0.8, -0.8, 1.57, -1.57, 2.36, -2.36, 3.14]:
		var dir := away.rotated(turn)
		if not p.test_move(p.global_transform, dir * 70.0):
			return dir
	return away


func _all_go(target: Vector2, spread := 40.0) -> bool:
	var all := true
	for i in m.players.size():
		var t := target + Vector2((float(i) - float(m.players.size() - 1) * 0.5) * spread, 0)
		if not _go(i, t, 14.0):
			all = false
	return all


func _tick() -> void:
	frame += 1
	if finished:
		_done(true)
		return
	if frame > 60 * 60 * 12:
		print("FAIL: ran out of time in stage '%s'" % m.stage)
		for i in m.players.size():
			var q = m.players[i]
			print("  P%d at tile %s down=%s frozen=%s sword=%s+%s %s owned=%s" % [i + 1, str((q.global_position / m.TILE).snapped(Vector2(0.1, 0.1))), str(q.is_down), str(q.frozen), m.builds[i].blade, m.builds[i].grip, str(m.builds[i].line), str(m.owned[i])])
		print("  forge open=%s forging=%d busy=%s forge_step=%d" % [str(m.build_menu.is_open), m.forging, str(m.ui.busy()), forge_step])
		_done(false)
		return
	_clear_presses()
	if last_hp.is_empty():
		for p in m.players:
			last_hp.append(p.hp)
	for i in m.players.size():
		var p = m.players[i]
		if p.hp < last_hp[i]:
			hits_taken += 1
			hits_by_stage[m.stage] = int(hits_by_stage.get(m.stage, 0)) + 1
		if not mortal:
			p.hp = maxf(p.hp, 60.0)
		last_hp[i] = p.hp
	var stage: String = m.stage
	if stage != last_stage:
		print("[%5.1f s] stage: %s" % [frame / 60.0, stage])
		last_stage = stage
		stage_seen[stage] = true
		stage_frames = 0
	stage_frames += 1
	var T: float = m.TILE
	if test_wipe and stage in ["fight2", "boss"] and stage_frames == 150 and not wipes_done.has(stage):
		wipes_done[stage] = true
		print("        (knocking everyone out in %s)" % stage)
		for p in m.players:
			p.invuln = 0.0
			p.take_damage(9999.0)
	if test_down and m.players.size() > 1:
		var p2 = m.players[1]
		if stage == "fight1" and stage_frames == 90 and not down_seen:
			down_seen = true
			print("        (knocking player two out in fight1)")
			p2.invuln = 0.0
			p2.take_damage(9999.0)
		if down_seen and stage == "walk2" and not p2.is_down:
			got_up = true

	# The forge screen pauses the tree, so drive it from here.
	if m.build_menu.is_open:
		_drive_forge()
		return
	if m.ui.busy():
		if stage_frames % 20 == 0:
			_shot("card_%s" % stage)
		if frame % 24 == 0:
			_press(0, "attack")
		for i in m.players.size():
			_inp(i).move = Vector2.ZERO
		return
	match stage:
		"crate":
			_shot("1_crate")
			for i in m.players.size():
				if m.armed[i]:
					_inp(i).move = Vector2.ZERO
				elif _go(i, Vector2(14.5, 62.6) * T, 20.0) and frame % 10 == 0:
					_press(i, "interact")
		"fight1", "fight2", "fight3", "boss":
			if stage_frames == 150:
				_shot("2_%s" % stage)
			if stage == "boss" and stage_frames in [400, 700]:
				stage_seen.erase("shot_2_boss_%d" % stage_frames)
				_shot("2_boss_%d" % stage_frames)
			for i in m.players.size():
				if not m.players[i].is_down:
					_fight(i)
		"walk2":
			_all_go(Vector2(20.5, 49.0) * T)
		"walk3":
			_shot("3_gate_open")
			_all_go(Vector2(20.5, 33.5) * T)
		"rune":
			_shot("4_rune")
			if _go(0, Vector2(20.5, 30.9) * T, 10.0) and frame % 10 == 0:
				_press(0, "interact")
		"walk4":
			_all_go(Vector2(20.5, 16.0) * T)
		"forge", "tin":
			_shot("5_%s" % stage)
			_forge_stage(stage)
		"boss_wake", "boss_dead":
			_shot("6_%s" % stage)
			for i in m.players.size():
				_inp(i).move = Vector2.ZERO
		"smith":
			_shot("7_smith")
			if _go(0, Vector2(31.0, 14.6) * T, 22.0) and frame % 10 == 0:
				_press(0, "interact")
		"stairs":
			_shot("8_stairs")
			_all_go(Vector2(28.3, 4.9) * T, 30.0)
		"end":
			_shot("9_end")
			if frame % 30 == 0:
				_press(0, "attack")


## One shared forge screen: the players take turns, player one first.
func _forge_stage(stage: String) -> void:
	var T: float = m.TILE
	var who := 0
	for i in m.players.size():
		var ok: bool = m._fitted(i) if stage == "forge" else m._tin_done(i)
		if not ok:
			who = i
			break
	for i in m.players.size():
		if i != who:
			_inp(i).move = Vector2.ZERO
	if _go(who, Vector2(20.5, 7.75) * T, 22.0) and frame % 10 == 0:
		forge_step = 0
		_press(who, "interact")


func _drive_forge() -> void:
	var forge = m.build_menu
	forge_wait += 1
	if forge_wait < 20:
		return
	forge_wait = 0
	var who: int = m.forging
	if forge.finishing >= 0.0:
		forge._really_close()
		return
	if m.stage == "forge":
		match forge_step:
			0:
				_shot("5_forge_screen")
				forge._set_tab(1)
				forge.selected = 0
				forge.card = 0
				forge._use_card(0)
			_:
				_shot("5_forge_fitted")
				forge.close()
	else:
		match forge_step:
			0:
				forge._set_tab(0)
				var cards: Array = forge._cards()
				for c in cards.size():
					if cards[c]["id"] in ["tin_blade", "tin_grip"]:
						forge._use_card(c)
			_:
				_shot("5_tin_screen")
				forge.close()
	forge_step += 1


func _done(ok: bool) -> void:
	if physics_frame.is_connected(_tick):
		physics_frame.disconnect(_tick)
	var want := ["crate", "fight1", "walk2", "fight2", "walk3", "fight3", "rune", "walk4", "forge", "boss", "boss_dead", "smith", "tin", "stairs", "end"]
	var missing: Array = []
	for s in want:
		if not stage_seen.has(s):
			missing.append(s)
	if test_wipe and (m.knockouts < 2 * n_players or wipes_done.size() < 2):
		print("FAIL: the wipes didn't happen (%d knock-outs)" % m.knockouts)
		ok = false
	if test_down and not got_up:
		print("FAIL: player two never got back up after the room was cleared")
		ok = false
	if ok and missing.is_empty():
		print("PASS: %d player(s) finished the cave in %.0f s of game time (%d hits taken, %d knock-outs)" % [n_players, m.run_time, hits_taken, m.knockouts])
		print("  hits by stage: %s" % str(hits_by_stage))
		for i in m.players.size():
			print("  P%d sword: %s + %s %s" % [i + 1, m.builds[i].blade, m.builds[i].grip, str(m.builds[i].line)])
	else:
		print("FAIL: stages never reached: %s" % str(missing))
	_quit(ok and missing.is_empty())


func _quit(ok: bool) -> void:
	quit(0 if ok else 1)
