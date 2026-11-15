extends SceneTree
## The tutorial cave's words, for each of the four weapons on its own and for
## every pair of them: the weapon's card, the first fight's hint, the rune's
## card, the forge's lines, the card for an active first rune's button, every
## line the smith says and the tin parts' card. Each must name the right weapon
## and rune, leave no blank behind, and fit its plate. Prints PASS / FAIL lines
## ("show" also prints every text, to read them through).
##   godot --headless --path . --fixed-fps 60 -s tests/cave_words.gd [-- show]

const PlayerInput := preload("res://scripts/player_input.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const KINDS := ["sword", "bow", "hammer", "staff"]
const SAY_WIDTH := 412.0      # the speech box's room for words, beside the smith's face
const SAY_LINES := 4
const CARD_LINES := 6
const HINT_LINES := 2

var fails := 0
var checks := 0
var show := false


func _init() -> void:
	show = "show" in OS.get_cmdline_user_args()
	_run()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL  " + what)


## A cave with one player for each weapon named, each holding that weapon.
func _cave(kinds: Array):
	var m = load("res://scripts/cave/cave.gd").new()
	var inputs: Array = []
	for k in kinds:
		inputs.append(PlayerInput.make("script"))
	m.inputs = inputs
	root.add_child(m)
	return m


## One text: nothing left to fill in, and no more lines than its plate holds.
func _fits(m, who: String, what: String, text: String, width: float, most: int, has: Array = []) -> void:
	if show:
		print("  [%s] %s: %s" % [who, what, text.replace("\n", " / ")])
	_check(text != "", "%s: %s is empty" % [who, what])
	for blank in ["%s", "%d", "%w", "[ability]", "[attack]"]:
		_check(not text.contains(blank), "%s: %s still has '%s' in it: %s" % [who, what, blank, text])
	var rows: int = m.ui._wrap(text, width).size()
	_check(rows <= most, "%s: %s takes %d lines, its plate holds %d: %s" % [who, what, rows, most, text])
	for word in has:
		_check(text.to_lower().contains(str(word).to_lower()), "%s: %s doesn't say '%s': %s" % [who, what, word, text])


func _run() -> void:
	await physics_frame
	var groups: Array = []
	for a in KINDS:
		groups.append([a])
	for a in KINDS.size():
		for b in range(a + 1, KINDS.size()):
			groups.append([KINDS[a], KINDS[b]])
			groups.append([KINDS[b], KINDS[a]])
	for kinds in groups:
		await _one(kinds)
	# Every weapon in the crate has its words, its first rune and its tin parts.
	var cave = load("res://scripts/cave/cave.gd")
	for kind in cave.CRATE_WEAPONS:
		_check(cave.WORDS.has(kind) and cave.STARTER_RUNE.has(kind) and cave.TIN_PARTS.has(kind) and SwingBuild.STARTERS.has(kind), "the crate's %s has words, a first rune, tin parts and a wooden starter" % kind)
		_check(SwingBuild.FITTINGS[cave.STARTER_RUNE[kind]].get("weapon", "sword") == kind, "the %s's first rune is one of its own" % kind)
		_check(SwingBuild.weapon_of(cave.TIN_PARTS[kind][0]) == kind, "the %s's tin parts start with its own head" % kind)
	print("RESULT: %d checks, %d failed" % [checks, fails])
	quit(0 if fails == 0 else 1)


func _one(kinds: Array) -> void:
	var m = _cave(kinds)
	await physics_frame
	var who := " + ".join(kinds)
	var same := kinds.size() == 1
	var runes: Array = []
	for kind in kinds:
		runes.append(str(SwingBuild.FITTINGS[m.STARTER_RUNE[kind]]["name"]))
	if show:
		print("== %s" % who)
	# The crate: each takes their weapon and gets its card.
	m.stage = "crate"
	m.crate_open = true
	m.picks_ready = true
	for i in kinds.size():
		m.ui.card_title = ""
		m._take_weapon(i, kinds[i])
		_check(m.builds[i].weapon() == kinds[i] and m.armed[i], "%s: P%d holds the wooden %s" % [who, i + 1, kinds[i]])
		_check(m.ui.card_title == "Wooden %s" % kinds[i], "%s: the card is the wooden %s's (%s)" % [who, kinds[i], m.ui.card_title])
		_fits(m, who, "the wooden %s's card" % kinds[i], m.ui.card_body, 330.0, CARD_LINES)
	_fits(m, who, "the first fight's hint", m._fight1_hint(), 360.0, HINT_LINES)
	# The pedestal: a rune each, their own weapon's.
	m.ui.card_title = ""
	m.stage = "rune"
	m._take_rune(0)
	for i in kinds.size():
		_check(m.STARTER_RUNE[kinds[i]] in m.owned[i], "%s: P%d was given %s" % [who, i + 1, runes[i]])
	_check(m.ui.card_title == ("%s rune" % runes[0] if same else "A rune each"), "%s: the rune card's title (%s)" % [who, m.ui.card_title])
	_fits(m, who, "the rune card", m.ui.card_body, 330.0, CARD_LINES, kinds if same else runes)
	# The forge: fit it.
	m.ui.card_title = ""
	m.stage = "forge"
	m._forge_objective()
	_fits(m, who, "the forge objective", m.ui.objective, 360.0, 1, kinds if same else ["weapon"])
	_fits(m, who, "the forge hint", m.ui.hint, 360.0, HINT_LINES)
	for i in kinds.size():
		_check(not m._fitted(i), "%s: P%d's rune isn't fitted yet" % [who, i + 1])
		var data: Array = SwingBuild.STARTERS[kinds[i]].duplicate(true)
		data[3] = [m.STARTER_RUNE[kinds[i]]]
		m.builds[i].set_data(data)
		_check(m._fitted(i), "%s: P%d's rune is fitted" % [who, i + 1])
	# An active first rune gets a card for its button before the guardian wakes.
	var active: Array = kinds.filter(func(kind): return kind in ["hammer", "staff"])
	m._rune_fitted()
	if active.is_empty():
		_check(m.stage == "boss_wake" and m.ui.card_title == "", "%s: the guardian wakes at once" % who)
	else:
		_check(m.stage == "ability_card", "%s: the ability card comes first (stage %s)" % [who, m.stage])
		var names: Array = []
		for kind in active:
			names.append(str(SwingBuild.FITTINGS[m.STARTER_RUNE[kind]]["name"]))
		_check(m.ui.card_title == (names[0] if names.size() == 1 else "Active runes"), "%s: the ability card's title (%s)" % [who, m.ui.card_title])
		_fits(m, who, "the ability card", m.ui.card_body, 330.0, CARD_LINES, ["[mouse_right]"] + (names if names.size() > 1 else []))
		m.ui.on_card.call()
		_check(m.stage == "boss_wake", "%s: then the guardian wakes" % who)
	# The smith.
	m.ui.card_title = ""
	m.stage = "smith"
	m._talk_smith(0)
	var said: Array = m.ui.lines.duplicate()
	_check(said.size() == 7, "%s: the smith has seven things to say (%d)" % [who, said.size()])
	for n in said.size():
		_fits(m, who, "the smith's line %d" % (n + 1), said[n], SAY_WIDTH, SAY_LINES)
	if same:
		_check(str(said[1]).contains("your %s" % kinds[0]), "%s: he names the %s" % [who, kinds[0]])
		_check(str(said[2]).begins_with("Square stones like yours" if not active.is_empty() else "Round stones like yours"), "%s: he knows which kind of stone it is: %s" % [who, said[2]])
	else:
		_check(str(said[2]).begins_with("Round stones work" if active.size() == 1 else ("Square stones like yours" if active.size() == 2 else "Round stones like yours")), "%s: he knows which kinds of stone they are: %s" % [who, said[2]])
	# He hands over the tin parts, each their own weapon's.
	m.ui.lines = []
	m.ui.on_said.call()
	for i in kinds.size():
		for part in m.TIN_PARTS[kinds[i]]:
			_check(part in m.owned[i], "%s: P%d was given %s" % [who, i + 1, part])
	_fits(m, who, "the tin card's title", m.ui.card_title, 330.0, 1, ["tin"])
	m.ui.card_title = ""
	m.stage = "tin"
	m._forge_objective()
	_fits(m, who, "the tin objective", m.ui.objective, 360.0, 1, ["tin"] + (kinds if same else ["weapon"]))
	_fits(m, who, "the tin hint", m.ui.hint, 360.0, HINT_LINES)
	m._talk_smith(0)
	_fits(m, who, "the smith's reminder", m.ui.lines[0], SAY_WIDTH, SAY_LINES)
	# Forging the tin weapon is what opens the stairs: the wooden one doesn't.
	for i in kinds.size():
		_check(not m._tin_done(i), "%s: P%d's wooden %s isn't the tin one" % [who, i + 1, kinds[i]])
		var tin: Array = SwingBuild.STARTERS[kinds[i]].duplicate(true)
		var parts: Array = m.TIN_PARTS[kinds[i]]
		tin[0] = parts[0]
		tin[1] = parts[1]
		tin[3] = [m.STARTER_RUNE[kinds[i]], ""]
		if tin.size() > 4:
			# (A bow's arrows and a staff's crystal are its damage: without the tin
			# ones it is not the tin weapon yet.)
			m.builds[i].set_data(tin)
			_check(not m._tin_done(i), "%s: P%d's %s still needs its tin %s" % [who, i + 1, kinds[i], "arrows" if kinds[i] == "bow" else "crystal"])
			tin[4] = parts[2]
		_check(SwingBuild.valid_data(tin), "%s: the tin %s is a weapon the forge can make (%s)" % [who, kinds[i], str(tin)])
		m.builds[i].set_data(tin)
		_check(m._tin_done(i), "%s: P%d's tin %s is done" % [who, i + 1, kinds[i]])
	m.queue_free()
	await physics_frame
