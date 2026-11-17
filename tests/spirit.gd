extends SceneTree
## The forge spirit (version 31): the small ember that floats at every player's
## shoulder and holds their runes. Run in the real arena with a scripted player,
## then in the tutorial cave. It checks the spirit's pictures, where it floats,
## its marks (one for each active rune fitted: ready, half, recharging), the
## sign that leaps to the weapon when a rune is used (one for a rune you hold),
## that it only shows what the game did and changes nothing, and that in the
## cave it joins a player at the forge. Prints PASS / FAIL lines.
##   godot --headless --path . --fixed-fps 60 -s tests/spirit.gd

const ForgeSpirit := preload("res://scripts/fx/forge_spirit.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const PlayerInput := preload("res://scripts/player_input.gd")
const Art := preload("res://scripts/art.gd")

var m
var p
var sp
var fails := 0
var sent := 0          # signs seen setting off, counted every frame by _frames()
var _flying := 0


func _init() -> void:
	m = load("res://scripts/main.gd").new()
	root.add_child(m)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		if sp != null:
			var now: int = sp.leaping()
			if now > _flying:
				sent += now - _flying
			_flying = now


func _press(b: int, hold := false) -> void:
	p.input.ability_pressed[b] = true
	p.input.ability_held[b] = true
	await _frames(1)
	p.input.ability_pressed[b] = false
	p.input.ability_held[b] = hold


func _release() -> void:
	p.input.ability_held = [false, false, false]
	p.input.ability_pressed = [false, false, false]


func _rest() -> void:
	_release()
	p.input.move = Vector2.ZERO
	p.input.attack_held = false
	p.input.attack_pressed = false
	await _frames(40)
	p.ability_charge = [1.0, 1.0, 1.0]
	p.ability_wait = [0.0, 0.0, 0.0]
	await _frames(20)
	sent = 0


func _sword(line: Array) -> void:
	m.build.line = line.duplicate()
	m.build.changed.emit()


func _run() -> void:
	await process_frame
	await process_frame
	p = m.player
	p.input.kind = "script"
	m.spawning = false
	sp = p.spirit
	await _frames(40)

	# --- It is there, and its pictures are ---------------------------------------
	_check(sp != null and sp.get_parent() == p and sp.get_script() == ForgeSpirit, "the player has a forge spirit of their own")
	_check(p.with_spirit and sp._there > 0.99, "in the arena it is there from the start")
	var missing: Array = []
	for f in ["play/spirit.png", "play/mark_ready.png", "play/mark_half.png", "play/mark_recharging.png", "play/mark_ping.png",
			"play/cast.png", "play/trail.png", "play/infuse.png", "forge/spirit_forge.png", "forge/spirit_forge_lit.png",
			"forge/seat.png", "forge/seat_selected.png", "forge/seat_special.png", "forge/start_mark.png", "forge/ring_arrow.png"]:
		if Art.texture("spirit/" + f) == null:
			missing.append(f)
	_check(missing.is_empty(), "every picture of the spirit is in the game %s" % [missing])
	# Every active rune has a sign to leap with; a passive rune needs none.
	var unsigned: Array = []
	for id in SwingBuild.FITTINGS:
		var fit: Dictionary = SwingBuild.FITTINGS[id]
		if fit["kind"] == "rune" and fit.get("trigger", "") == "active" and Art.texture("spirit/signs/sign_%s.png" % id) == null:
			unsigned.append(id)
	_check(unsigned.is_empty(), "every active rune has its sign %s" % [unsigned])
	_check(sp.z_index > 0 and sp.get_child_count() == 1, "it is drawn over the world, with its glow on top")
	_check(not (sp is CollisionObject2D) and sp.find_children("*", "CollisionObject2D", true, false).is_empty(), "it is a picture only: nothing can touch it")

	# --- Where it floats: small, at the shoulder away from where you face ---------
	p.input.stick_aim = Vector2.RIGHT
	await _frames(60)
	var at: Vector2 = sp.ember_at()
	_check(at.x < 0.0 and absf(at.x) <= ForgeSpirit.BEHIND * Art.PIXEL + 0.5, "facing right, it floats behind your left shoulder (%s)" % at)
	_check(at.y < 0.0 and at.y > -2.0 * ForgeSpirit.ABOVE_FEET * Art.PIXEL, "above the shoulder, not far off (%s)" % at)
	_check(at == (at / Art.PIXEL).round() * Art.PIXEL, "on whole art pixels, so it never shimmers")
	p.input.stick_aim = Vector2.LEFT
	await _frames(4)
	_check(sp.ember_at().x < 0.0, "a quick look the other way does not move it")
	await _frames(70)
	_check(sp.ember_at().x > 0.0, "facing left for a moment, it crosses to the other shoulder (%s)" % sp.ember_at())
	p.input.stick_aim = Vector2.DOWN
	await _frames(70)
	var hand: Vector2 = p.rest_hand()
	_check(signf(sp.ember_at().x) == -signf(hand.x), "facing down, it keeps to the side the weapon is not on (hand %s, spirit %s)" % [hand, sp.ember_at()])
	p.input.stick_aim = Vector2.RIGHT
	await _frames(60)

	# --- Marks: one for each active rune fitted -----------------------------------
	_sword(["shockwave", "weak_point", "", ""])
	await _frames(4)
	_check(sp.marks() == [], "passive runes only: no marks over the spirit")
	_sword(["leap", "shockwave", "", ""])
	await _frames(4)
	_check(sp.marks() == ["ready"], "one active rune: one mark, ready")
	_sword(["whirlwind", "leap", "ghostwield", "weak_point"])
	await _frames(4)
	_check(sp.marks() == ["ready", "ready", "ready"], "three active runes: three marks, in button order")
	_check(ForgeSpirit.mark_at(0, 1).x == 0.0, "one mark sits over the middle of the ember")
	_check(ForgeSpirit.mark_at(0, 2).x == -ForgeSpirit.mark_at(1, 2).x and ForgeSpirit.mark_at(1, 2).x > 0.0, "two sit either side of it")
	_check(ForgeSpirit.mark_at(1, 3).y < ForgeSpirit.mark_at(0, 3).y and ForgeSpirit.mark_at(0, 3).y == ForgeSpirit.mark_at(2, 3).y, "of three, the middle one sits a little higher")

	# --- A rune is used: its sign leaps to the weapon, the mark goes dark ----------
	await _rest()
	var used_before: float = p.ability_used[1]
	var lit_before: float = p.spirit_lit
	await _press(1)                      # Leap, a rune you press
	_check(float(p.ability_used[1]) > used_before, "the rune goes off on the press itself: the spirit never makes it wait")
	await _frames(3)
	_check(sent == 1, "one sign sets off from the spirit (%d)" % sent)
	_check(sp.marks()[1] == "recharging" and sp.marks()[0] == "ready", "its mark goes dark, the others stay lit: %s" % [sp.marks()])
	await _frames(int(ForgeSpirit.LEAP_TIME * 60.0) + 4)
	_check(sp.leaping() == 0 and p.spirit_lit > lit_before, "it lands on the weapon a moment later, and the weapon lights")
	var list: Array = p.weapon.get("abilities", [])
	p.ability_charge[1] = 0.7
	await _frames(2)
	_check(sp.marks()[1] == "half", "for the last third of the recharge the mark is half lit: %s" % [sp.marks()])
	p.ability_charge[1] = 1.0
	await _frames(3)
	_check(sp.marks()[1] == "ready" and sp._pings.has(1), "ready again: the mark is lit, with a blink")
	_check(sent == 1, "coming back sends nothing (%d)" % sent)
	# A rune you hold sends one sign when it starts, not one at every turn.
	await _rest()
	_check(str(list[0]["use"]) == "hold", "(Whirlwind is a rune you hold)")
	await _press(0, true)
	await _frames(100)
	_release()
	await _frames(20)
	_check(p.hold_turns >= 2 or float(p.ability_charge[0]) < 0.5, "held for over a second, the Whirlwind turned more than once")
	_check(sent == 1, "and the spirit sent one sign for all of it (%d)" % sent)
	# Changing the weapon is not a rune being used.
	await _rest()
	_sword(["leap", "whirlwind", "", ""])
	await _frames(10)
	m.swap_weapon(0)
	await _frames(10)
	m.swap_weapon(0, "sword")
	await _frames(10)
	_check(sent == 0, "fitting other runes or swapping weapons sends no sign (%d)" % sent)
	_check(sp.marks().size() == 2, "the marks follow the weapon in your hand: %s" % [sp.marks()])

	# --- Nothing is drawn on the weapon in the hand --------------------------------
	_check(p.weapon_hand() is Vector2 and p._spirit_tint(p.weapon_layer) == Color.WHITE, "the weapon is its own colour again once the light has gone")

	# --- It shows what happened and changes nothing --------------------------------
	# Two arenas, one with the spirit and one without, given the same presses, end the same.
	m.queue_free()
	sp = null
	await process_frame
	var ends: Array = []
	for with in [true, false]:
		var a = load("res://scripts/main.gd").new()
		root.add_child(a)
		await process_frame
		await process_frame
		var q = a.player
		q.input.kind = "script"
		q.with_spirit = with
		a.spawning = false
		seed(7)
		q.global_position = Vector2(400, 300)
		a.build.line = ["whirlwind", "leap", "ghostwield", "weak_point"]
		a.build.changed.emit()
		for i in 30:
			await physics_frame
		q.input.stick_aim = Vector2.RIGHT
		for b in [1, 2, 0]:
			q.input.ability_pressed[b] = true
			q.input.ability_held[b] = true
			await physics_frame
			q.input.ability_pressed[b] = false
			q.input.ability_held[b] = false
			for i in 45:
				await physics_frame
		ends.append([q.global_position.snapped(Vector2(0.01, 0.01)), q.ability_charge.duplicate(), q.hp])
		_check((q.spirit._there > 0.99) == with, "an arena %s the spirit: it is %s" % ["with" if with else "without", "there" if with else "hidden"])
		a.queue_free()
		await process_frame
	_check(str(ends[0]) == str(ends[1]), "with the spirit or without, the same presses end the same: %s" % [ends[0]])

	# --- The tutorial cave: it joins you at the forge ------------------------------
	var cave = load("res://scripts/cave/cave.gd").new()
	cave.inputs = [PlayerInput.make("script"), PlayerInput.make("script")]
	root.add_child(cave)
	await process_frame
	await process_frame
	for i in 30:
		await physics_frame
	var all_hidden := true
	for q in cave.players:
		if q.with_spirit or q.spirit._there > 0.0:
			all_hidden = false
	_check(cave.players.size() == 2 and all_hidden, "in the cave nobody has a spirit to begin with")
	cave._use_forge(0)
	for i in 30:
		await process_frame
	_check(cave.players[0].with_spirit and not cave.players[1].with_spirit, "it joins the player who comes to the forge, and only them")
	cave.build_menu._really_close()
	cave._rune_fitted()
	_check(cave.players[1].with_spirit, "once the runes are fitted everyone has theirs")
	_check(cave.players[0].spirit != cave.players[1].spirit, "one spirit each")

	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
