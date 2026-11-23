extends SceneTree
## The lab (scripts/lab.gd, scripts/ui/lab_screen.gd): every number it shows is
## really there in the game and inside its limits, a change reaches the game and
## comes back out again, the file keeps it, an online game never sees it, the
## screen works in the arena and the cave, and the arena's spawner makes every
## enemy in the game. The search finds a number on any page. Prints FAIL lines
## and a RESULT line.
##   godot --headless --path . --fixed-fps 60 -s tests/lab.gd [-- show]

const Lab := preload("res://scripts/lab.gd")
const LabScreen := preload("res://scripts/ui/lab_screen.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Player := preload("res://scripts/player.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Guardian := preload("res://scripts/cave/guardian.gd")
const Crawler := preload("res://scripts/cave/crawler.gd")
const PlayerInput := preload("res://scripts/player_input.gd")
const Art := preload("res://scripts/art.gd")
const FILE := "user://lab_test.json"

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


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Typed letters, the way the keyboard sends them (each with its key, so a
## typed L is also the lab's key and a typed B the arena's weapon swap).
func _type(text: String) -> void:
	for ch in text:
		for down in [true, false]:
			var ev := InputEventKey.new()
			ev.pressed = down
			ev.keycode = KEY_SLASH if ch == "/" else (KEY_SPACE if ch == " " else (ch.to_upper().unicode_at(0) as Key))
			ev.physical_keycode = ev.keycode
			ev.unicode = ch.unicode_at(0) if down else 0
			Input.parse_input_event(ev)
			await _frames(2)


## A real key press, the way the keyboard sends it.
func _key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.pressed = down
		ev.keycode = code
		ev.physical_keycode = code
		Input.parse_input_event(ev)
		await _frames(3)


func _wipe() -> void:
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))


func _run() -> void:
	await process_frame
	await process_frame
	Lab.file = FILE
	_wipe()
	_rows()
	_search()
	_changes()
	_file()
	await _arena()
	await _cave()
	Lab.reset_all()
	Lab.started = false
	_wipe()
	print("RESULT: %d checks, %d failed" % [checks, fails])
	quit(0 if fails == 0 else 1)


## Every row: a real number of the game's, inside its limits, with words that fit.
func _rows() -> void:
	_check(not Lab.started, "a test never reads anybody's lab file")
	Lab.setup()
	_check(Lab.rows.size() >= 180, "the lab shows plenty of numbers (%d)" % Lab.rows.size())
	var font := Art.font(Art.TEXT)
	var seen := {}
	var pages := {}
	for row in Lab.rows:
		var id: String = row["id"]
		var who := "%s > %s > %s" % [row["page"], row["group"], row["label"]]
		_check(not seen.has(id), "%s: its id is its own (%s)" % [who, id])
		seen[id] = true
		pages[row["page"]] = int(pages.get(row["page"], 0)) + 1
		_check(row["page"] in Lab.PAGES, "%s: its page is one of the lab's" % who)
		_check(str(row["label"]) != "" and str(row["group"]) != "", "%s has a name and a group" % who)
		var d := float(Lab.defaults[id])
		_check(d >= float(row["lo"]) and d <= float(row["hi"]), "%s: the game's own number (%s) is inside its limits (%s to %s)" % [who, d, row["lo"], row["hi"]])
		_check(float(row["step"]) > 0.0, "%s has a step" % who)
		for place in row["at"]:
			var v = Lab._read(place)
			_check(v is float or v is int, "%s: %s is a number in the game" % [who, place])
			_check(is_equal_approx(float(v), d), "%s: %s holds the same number as the row's first place" % [who, place])
		if font != null:
			var w := font.get_string_size(str(row["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE).x
			_check(w <= LabScreen.LABEL_W, "%s: its name fits its column (%d of %d)" % [who, w, LabScreen.LABEL_W])
		# One step up and one back down is where it started: no number drifts.
		Lab.nudge(id, 1)
		_check(Lab.is_changed(id) or is_equal_approx(d, float(row["hi"])), "%s: a step up changes it" % who)
		_check(Lab.value(id) <= float(row["hi"]) + 0.0001, "%s: a step up stays inside its limit" % who)
		Lab.nudge(id, -1)
		_check(not Lab.is_changed(id), "%s: a step up and a step down is the game's own number again (%s, was %s)" % [who, Lab.value(id), d])
		if show:
			print("  %-16s %-34s %-52s %s" % [row["page"], row["group"], row["label"], Lab.words(id, d)])
	for page in Lab.PAGES:
		_check(int(pages.get(page, 0)) > 0, "the page %s has numbers" % page)
		if font != null and Lab.PAGE_NOTES.has(page):
			_check(font.get_string_size(str(Lab.PAGE_NOTES[page]), HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE).x <= 492.0, "the page %s's note fits" % page)
	_check(Lab.changed_count() == 0, "nothing is left changed")


func _ids(found: Array) -> Array:
	var ids: Array = []
	for row in found:
		ids.append(row["id"])
	return ids


## The search (Lab.find): a word finds every number that holds it, on any page.
func _search() -> void:
	_check(Lab.find("").is_empty() and Lab.find("   ").is_empty(), "nothing typed finds nothing")
	_check(Lab.find("zzz").is_empty(), "a word nothing is called finds nothing")
	var dagger := Lab.find("dagger")
	var all_dagger := dagger.size() == 4
	for row in dagger:
		all_dagger = all_dagger and row["page"] == "Sword" and row["group"] == "Dagger"
	_check(all_dagger, "dagger finds the dagger's four numbers and nothing else (%d)" % dagger.size())
	_check(_ids(Lab.find("DAGGER")) == _ids(dagger) and _ids(Lab.find(" Dagger ")) == _ids(dagger), "capitals and spaces around it make no difference")
	_check(_ids(Lab.find("damage dagger")) == ["build:SHAPES/dagger/damage"] and _ids(Lab.find("dagger damage")) == ["build:SHAPES/dagger/damage"], "two words find what holds both, in either order")
	var recharges: Array = []
	for row in Lab.rows:
		if row["label"] == "Recharge":
			recharges.append(row["id"])
	var found_recharge := _ids(Lab.find("recharge"))
	var has_all := recharges.size() >= 12
	for id in recharges:
		has_all = has_all and id in found_recharge
	_check(has_all and "build:EVERY_HIT_REFUND" in found_recharge, "recharge finds every rune's Recharge, and Every Hit's \"recharges it by\" (%d)" % found_recharge.size())
	_check(_ids(Lab.find("cooldown")) == found_recharge, "cooldown finds the same")
	var hp := _ids(Lab.find("hp"))
	_check("player:MAX_HP" in hp and "guardian:HP" in hp and "enemy:STATS/brute/hp" in hp and "crawler:HP" in hp, "hp finds the players', the guardian's and the enemies' health")
	var sword_damage := _ids(Lab.find("sword damage"))
	_check("build:SHAPES/dagger/damage" in sword_damage and "build:METALS/iron" in sword_damage and "player:SHOCKWAVE_DAMAGE" in sword_damage, "sword damage finds the shapes' damage, the metals and the sword runes' damage")
	_check(not ("build:SHAPES/dagger/reach" in sword_damage) and not ("guardian:SLAM_DAMAGE" in sword_damage), "...and not a sword's reach or the guardian's slam")
	var crabs := Lab.find("crabs")
	_check(crabs.size() == 9, "crabs finds the three crabs' numbers (%d)" % crabs.size())
	var boss: Array = []
	for row in Lab.rows:
		if row["page"] == "Forge guardian" or (row["page"] == "Levelling" and str(row["label"]).to_lower().contains("boss")):
			boss.append(row["id"])
	_check(_ids(Lab.find("boss")) == boss and "levels:CHALLENGE_BOSS_TIME" in boss, "boss finds the forge guardian's page, and what Challenge does to a boss")
	# Every number is found by its own page, group and name, and what is found
	# comes in the lab's own order.
	for row in Lab.rows:
		var who := "%s %s %s" % [row["page"], row["group"], row["label"]]
		_check(row["id"] in _ids(Lab.find(who)), "%s: its own words find it" % who)
		_check(row["id"] in _ids(Lab.find(str(row["label"]))), "%s: its name alone finds it" % who)
	var at := -1
	var in_order := true
	for row in Lab.find("speed"):
		var i := Lab.rows.find(row)
		in_order = in_order and i > at
		at = i
	_check(in_order and at > 0, "what a search finds comes in the lab's own order")
	var font := Art.font(Art.TEXT)
	if font != null:
		for text in [LabScreen.FOUND_NOTE, LabScreen.NONE_NOTE]:
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Art.TEXT_SIZE).x
			_check(w <= 492.0, "the line above a search fits (%d of 492)" % w)


## A change reaches the game's own code, and a reset takes it out again.
func _changes() -> void:
	_check(is_equal_approx(float(SwingBuild.blade_info("iron_broadsword")["damage"]), 11.0), "an iron broadsword hits for 11 to begin with")
	Lab.set_value("build:METALS/iron", 22.0)
	_check(is_equal_approx(float(SwingBuild.blade_info("iron_broadsword")["damage"]), 22.0), "iron at 22: an iron broadsword hits for 22")
	_check(is_equal_approx(float(SwingBuild.blade_info("iron_greatsword")["damage"]), 22.0 * 1.6), "...and a greatsword for 1.6 times that")
	_check(is_equal_approx(float(SwingBuild.blade_info("tin_blade")["damage"]), 8.0), "...and tin is as it was")
	_check(Lab.changed_count() == 1 and Lab.changed_on("All weapons") == 1 and Lab.changed_on("Sword") == 0, "one number is changed, on its own page")
	_check(Lab.words("build:METALS/iron", Lab.value("build:METALS/iron")) == "22", "it reads 22")
	Lab.reset("build:METALS/iron")
	_check(is_equal_approx(float(SwingBuild.blade_info("iron_broadsword")["damage"]), 11.0) and Lab.changed_count() == 0, "reset: 11 again, nothing changed")
	# A number kept in several places (every finisher's strength).
	Lab.set_value("chain_finisher", 2.0)
	_check(is_equal_approx(float(Player.MOVES["overhead"]["power"]), 2.0) and is_equal_approx(float(Player.MOVES["crush"]["power"]), 2.0)
		and is_equal_approx(float(Player.MOVES["burst"]["power"]), 2.0), "the third hit at 200%: the sword's, the hammer's and the staff's finishers all follow")
	_check(is_equal_approx(float(Player.MOVES["slash"]["power"]), 1.0), "...and a normal hit is still one hit")
	Lab.reset("chain_finisher")
	_check(is_equal_approx(float(Player.MOVES["overhead"]["power"]), 1.5), "reset: 150% again")
	# Limits, whole numbers, shares and seconds.
	Lab.set_value("build:METALS/iron", 99999.0)
	_check(is_equal_approx(Lab.value("build:METALS/iron"), 500.0), "a number can't go past its limit")
	Lab.reset("build:METALS/iron")
	Lab.set_value("player:SHARD_COUNT", 4.4)
	_check(Player.SHARD_COUNT is int and Player.SHARD_COUNT == 4, "a whole number stays whole (Shards: 4 in a burst)")
	Lab.reset("player:SHARD_COUNT")
	Lab.set_value("build:FITTINGS/whirlwind/recharge", 9.0)
	_check(is_equal_approx(float(SwingBuild.FITTINGS["whirlwind"]["recharge"]), 9.0), "Whirlwind's recharge follows")
	var e := {"id": "whirlwind", "count": 1, "size": 1.0, "power": 1.0, "every": 1, "also": [], "trigger": "active", "button": 0}
	_check(SwingBuild.sentence(e).contains("Recharges in 9 seconds"), "...and so does the forge's sentence: %s" % SwingBuild.sentence(e))
	Lab.reset("build:FITTINGS/whirlwind/recharge")
	_check(is_equal_approx(Lab.typed("build:BOW_DAMAGE", "85%"), 0.85) and is_equal_approx(Lab.typed("build:BOW_DAMAGE", " 85 "), 0.85), "typing 85 on a share means 85%")
	_check(is_equal_approx(Lab.typed("build:FITTINGS/leap/recharge", "2,5 sec"), 2.5), "typing 2,5 sec means two and a half seconds")
	_check(is_nan(Lab.typed("build:METALS/iron", "lots")), "words are not a number")
	_check(Lab.words("build:BOW_DAMAGE", 0.8) == "80%" and Lab.words("build:FITTINGS/leap/recharge", 3.0) == "3 sec" and Lab.words("player:DODGE_TIME", 0.15) == "0.15 sec", "numbers read as 80%, 3 sec and 0.15 sec")
	_check(Lab.summary() == "Lab: no numbers changed.", "nothing to copy while nothing is changed")
	_check(Lab.changed_count() == 0, "nothing is left changed")


## The file: what was changed is still changed after the game is started again;
## an online game plays with the game's own numbers.
func _file() -> void:
	Lab.started = false
	Lab.set_value("build:BOW_DAMAGE", 0.9)
	_check(not FileAccess.file_exists(FILE), "nothing is written before the real game starts the lab")
	Lab.reset("build:BOW_DAMAGE")
	Lab.start()
	_check(Lab.started and Lab.changed_count() == 0, "started with no file: every number is the game's own")
	Lab.set_value("build:BOW_DAMAGE", 0.9)
	Lab.set_value("guardian:HP", 400.0)
	_check(FileAccess.file_exists(FILE), "a change is written to the file at once")
	var text := Lab.summary()
	_check(text.contains("Bow > Every bow > An arrow, against a sword hit in that metal: 70% -> 90%  [build:BOW_DAMAGE = 0.9]"), "the copied list says it in words and exactly: %s" % text)
	_check(text.contains("[guardian:HP = 400]") and text.begins_with("Lab numbers changed (2)"), "...for both numbers")
	# The game is started again: forget everything, then read the file.
	Lab.changes = {}
	Lab._apply_all()
	_check(is_equal_approx(SwingBuild.BOW_DAMAGE, 0.7), "(forgotten: the game's own number)")
	Lab.started = false
	Lab.start()
	_check(is_equal_approx(SwingBuild.BOW_DAMAGE, 0.9) and is_equal_approx(Guardian.HP, 400.0) and Lab.changed_count() == 2, "started again: both changes are back in force")
	# Online: the game's own numbers, and the lab remembers its own for afterwards.
	Lab.set_in_force(false)
	_check(is_equal_approx(SwingBuild.BOW_DAMAGE, 0.7) and is_equal_approx(Guardian.HP, 255.0), "an online game plays with the game's own numbers")
	_check(Lab.changed_count() == 2, "...and the lab still remembers its own")
	Lab.set_in_force(true)
	_check(is_equal_approx(SwingBuild.BOW_DAMAGE, 0.9) and is_equal_approx(Guardian.HP, 400.0), "back offline: the lab's numbers again")
	# A file with rubbish in it does no harm.
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"changes": {"build:BOW_DAMAGE": 99.0, "no:SUCH/number": 3.0, "guardian:HP": "big", "build:METALS/tin": 8.0}}))
	f.close()
	Lab.load_file()
	Lab._apply_all()
	_check(Lab.changed_count() == 1 and is_equal_approx(SwingBuild.BOW_DAMAGE, 5.0), "a bad file: numbers the game doesn't have are dropped, the rest kept inside their limits")
	_check(is_equal_approx(Guardian.HP, 255.0), "...and the guardian's health is the game's own")
	Lab.reset_all()
	_check(Lab.changed_count() == 0 and is_equal_approx(SwingBuild.BOW_DAMAGE, 0.7), "reset everything: all the game's own")


## The screen and the spawner, in the real arena with a scripted player.
func _arena() -> void:
	var m = load("res://scripts/main.gd").new()
	m.inputs = [PlayerInput.make("script")]
	root.add_child(m)
	await _frames(5)
	m.spawning = false
	var p = m.player
	var s = m.lab_screen
	_check(s != null and not s.is_open, "the arena has a lab, closed to begin with")
	_check(m.hud.has_lab, "the HUD knows the lab is there (its button shows)")
	var version = root.get_node_or_null("VersionLabel")
	_check(version != null and version.lab_words() == "", "the version corner says nothing about the lab while nothing is changed")
	_check(is_equal_approx(float(p.weapon["damage"]), 11.0), "the test sword hits for 11")
	# Open: the game stops. Change iron and health; close: both are in force.
	m.open_lab()
	_check(s.is_open and paused, "L opens it and the game stops")
	_check(s._page_buttons.has("Spawn") and s._page_buttons.size() == Lab.PAGES.size() + 1, "its pages are the lab's and Spawn")
	for page in Lab.PAGES:
		s._show_page(page)
		var want := 0
		for row in Lab.rows:
			if row["page"] == page:
				want += 1
		_check(s._rows.size() == want and want > 0, "the page %s shows its %d numbers (%d)" % [page, want, s._rows.size()])
	s._show_page("All weapons")
	s._nudge("build:METALS/iron", 1)
	_check(is_equal_approx(SwingBuild.METALS["iron"], 11.5), "+ on iron: 11.5")
	_check(s._rows["build:METALS/iron"]["was"].text == "game: 11" and s._rows["build:METALS/iron"]["reset"].visible, "the row says what the game's own number is and offers Reset")
	_check(s._status.text == "1 number changed." and str(s._page_buttons["All weapons"].text) == "ALL WEAPONS (1)", "the screen counts it: %s / %s" % [s._status.text, s._page_buttons["All weapons"].text])
	# Typing a number.
	var box = s._rows["build:METALS/iron"]["edit"]
	box.begin()
	box.put("2")
	box.put("2")
	box.finish()
	_check(is_equal_approx(SwingBuild.METALS["iron"], 22.0), "typing 22 in the box: iron is 22")
	box.begin()
	box.finish()
	_check(is_equal_approx(SwingBuild.METALS["iron"], 22.0), "clicking the box and typing nothing changes nothing")
	s._show_page("Players")
	box = s._rows["player:MAX_HP"]["edit"]
	box.begin()
	for ch in "200":
		box.put(ch)
	box.finish()
	p.hp = 50.0
	_check(is_equal_approx(float(p.weapon["damage"]), 11.0), "(the sword in the hand waits for the screen to close)")
	s.close()
	_check(not s.is_open and not paused, "closing it starts the game again")
	_check(is_equal_approx(float(p.weapon["damage"]), 22.0), "the sword in the hand now hits for 22")
	_check(is_equal_approx(p.max_hp, 200.0) and is_equal_approx(p.hp, 100.0), "health 200: half health is still half (%s of %s)" % [p.hp, p.max_hp])
	await _frames(3)
	_check(version.lab_words() == "LAB: 2 NUMBERS CHANGED", "the version corner says so: %s" % version.lab_words())
	# Reset this page, reset everything.
	m.open_lab()
	s._show_page("Players")
	s._reset_page()
	_check(is_equal_approx(Player.MAX_HP, 100.0) and Lab.changed_count() == 1, "reset this page: health is the game's own, iron is still changed")
	s._reset_all()
	_check(Lab.changed_count() == 0 and s._status.text == "Every number is the game's own.", "reset everything")
	s.close()
	_check(is_equal_approx(float(p.weapon["damage"]), 11.0) and is_equal_approx(p.max_hp, 100.0), "and the game follows: 11 damage, 100 health")
	# The spawner: every enemy in the game.
	m.open_lab()
	s._show_page("Spawn")
	var made := {}
	for entry in m.SPAWNABLE:
		var kind := str(entry[0])
		var got: Array = m.spawn_enemies(kind, 1)
		_check(got.size() == 1 and got[0].kind == kind.trim_suffix("_elite") and got[0].elite == kind.ends_with("_elite"), "the spawner makes a %s" % entry[1])
		made[kind] = got[0]
		var e = got[0]
		_check(m.ARENA.has_point(e.global_position) and e.global_position.distance_to(p.global_position) >= 190.0, "the %s is inside the walls and not on top of you" % entry[1])
	var all_but_dummy: int = m.SPAWNABLE.size() - 1
	_check(m.enemy_total() == all_but_dummy, "one of each and a dummy: the room counts all but the dummy (%d)" % m.enemy_total())
	s._refresh_spawn()
	_check(s._count_label.text == "In the arena now: %d enemies." % all_but_dummy, "the page says so: %s" % s._count_label.text)
	var g = made["guardian"]
	_check(g.mode != "dormant" and g.room == m.ARENA and g.show_bar and is_equal_approx(g.max_hp, Guardian.HP), "the guardian is awake, keeps to the arena and shows his health")
	s._spawn("slime", 5)
	_check(m.enemy_total() == all_but_dummy + 5, "+5 makes five more (%d)" % m.enemy_total())
	s._arrive_button.pressed.emit()
	_check(m.spawning, "the switch lets new enemies arrive by themselves again")
	s._arrive_button.pressed.emit()
	_check(not m.spawning and s._arrive_button.text.ends_with("OFF"), "...and stops them")
	s.close()
	# They all live here: three seconds of fighting with nobody hurt and no errors.
	p.hp = p.max_hp
	await _frames(180)
	_check(is_instance_valid(g) and g.mode != "wake", "three seconds on, the guardian is up and fighting (%s)" % g.mode)
	_check(m.ARENA.grow(1.0).has_point(g.global_position), "...and still inside the arena")
	_check(is_equal_approx(p.hp, p.max_hp), "nobody was hurt (Invincible is on)")
	# An enemy already here follows a change, keeping its share of health.
	var crab = null
	for e in get_nodes_in_group("enemies"):
		if e.kind == "slime":
			crab = e
	crab.hp = crab.max_hp * 0.5
	m.open_lab()
	Lab.set_value("enemy:STATS/slime/hp", 60.0)
	Lab.set_value("guardian:HP", 510.0)
	s.dirty = true
	s.close()
	_check(is_equal_approx(crab.max_hp, 60.0) and is_equal_approx(crab.hp, 30.0), "a crab already here: 60 health, still at half")
	_check(is_equal_approx(g.max_hp, 510.0), "the guardian already here: 510 health")
	var fresh: Array = m.spawn_enemies("slime", 1)
	_check(is_equal_approx(fresh[0].max_hp, 60.0), "a new crab: 60 health")
	Lab.reset_all()
	m.lab_changed()
	# Beating the guardian here: a kill, and his suit is cleared away.
	var kills_before: int = m.kills
	g.immune = false
	g.take_hit(99999.0, Vector2.RIGHT, 0.0, false, Color.WHITE)
	await _frames(10)
	_check(g.dead and m.kills == kills_before + 1 and m.suits.size() == 1, "the guardian can be beaten here, and it counts as a kill")
	await _frames(400)
	_check(not is_instance_valid(g) and m.suits.is_empty(), "his empty suit is cleared away after a few seconds")
	# Remove every enemy.
	m.clear_enemies()
	await _frames(3)
	_check(m.enemy_total() == 0, "remove every enemy: none left (%d)" % m.enemy_total())
	_check(is_instance_valid(m.home_dummy) and not m.home_dummy.is_queued_for_deletion(), "...but the room's own dummy stays")
	var dummies := 0
	for e in get_nodes_in_group("enemies"):
		if e.kind == "dummy" and not e.is_queued_for_deletion():
			dummies += 1
	_check(dummies == 1, "...and only that one (%d)" % dummies)
	# The real key: L opens it, L closes it, and it stays closed. Esc closes it too,
	# and doesn't open the pause menu behind it.
	await _key(KEY_L)
	_check(s.is_open and paused, "the L key opens the lab")
	await _key(KEY_L)
	_check(not s.is_open and not paused, "the L key closes it")
	await _frames(5)
	_check(not s.is_open, "...and it stays closed")
	await _key(KEY_L)
	await _key(KEY_ESCAPE)
	_check(not s.is_open and not m.pause_menu.is_open() and not paused, "Esc closes the lab and nothing else")
	# Holding + keeps going.
	m.open_lab()
	s._show_page("Players")
	s._hold(s._nudge.bind("player:MAX_HP", 1))
	_check(is_equal_approx(Player.MAX_HP, 105.0), "pressing + is one step at once (%s)" % Player.MAX_HP)
	for i in 60:
		await process_frame
	s._let_go()
	var held_to: float = Player.MAX_HP
	_check(held_to >= 125.0, "holding it for a second keeps going (%s)" % held_to)
	for i in 30:
		await process_frame
	_check(is_equal_approx(Player.MAX_HP, held_to), "...and stops when you let go")
	s._reset("player:MAX_HP")
	s.close()
	_check(is_equal_approx(p.max_hp, 100.0), "(health back to 100)")
	# The search box: "/" goes to it, and typing finds numbers on every page.
	var kind_before := str(p.weapon.get("kind", ""))
	var switches := [m.invincible, m.enemies_paused]
	m.open_lab()
	s._pick_page("Players")
	_check(s._reset_page_button.text == "RESET THIS PAGE", "(the first button reads Reset this page)")
	await _type("/")
	_check(s._search.has_focus() and s._search.text == "", "the / key goes to the search box, and isn't typed into it")
	await _type("leap")
	_check(s.is_open and s.query == "leap", "typing searches, and a typed L doesn't close the lab (%s)" % s.query)
	_check(s._rows.size() == Lab.find("leap").size() and s._rows.has("player:LEAP_DAMAGE"), "Leap's numbers show (%d)" % s._rows.size())
	_check(s._reset_page_button.text == "RESET THESE", "the first button now reads Reset these")
	for i in 4:
		await _key(KEY_BACKSPACE)
	_check(s.query == "" and s.page == "Players" and s._rows.has("player:MAX_HP"), "rubbing it all out shows the page again")
	await _type("dagger")
	_check(s._rows.size() == 4 and s._note.text == LabScreen.FOUND_NOTE, "dagger: its four numbers, and the line above says what they are (%d)" % s._rows.size())
	Lab.set_value("player:MAX_HP", 150.0)
	s._nudge("build:SHAPES/dagger/damage", 1)
	_check(is_equal_approx(float(SwingBuild.SHAPES["dagger"]["damage"]), 0.65), "a number that was found changes like any other")
	s._reset_page()
	_check(is_equal_approx(float(SwingBuild.SHAPES["dagger"]["damage"]), 0.6) and is_equal_approx(Player.MAX_HP, 150.0), "Reset these resets what the search shows and nothing else")
	Lab.reset("player:MAX_HP")
	await _key(KEY_ESCAPE)
	_check(s.is_open and s.query == "" and s._search.text == "" and s._search.has_focus() and s._rows.has("player:MAX_HP"), "Esc in the box empties it: the page again, the lab still open")
	await _type("zzz")
	_check(s._rows.is_empty() and s._note.text == LabScreen.NONE_NOTE, "a word nothing is called finds nothing, and the line above says so")
	await _key(KEY_ESCAPE)
	await _type("hp bow")
	_check(s.query == "hp bow" and s._rows.is_empty(), "(two words, a space between them: %s)" % s.query)
	for i in 4:
		await _key(KEY_BACKSPACE)
	await _key(KEY_ENTER)
	_check(not s._search.has_focus() and s.query == "hp" and s._rows.size() == Lab.find("hp").size(), "Enter leaves the box with the search still showing")
	await _key(KEY_L)
	_check(not s.is_open, "out of the box, L closes the lab as before")
	await _frames(5)
	_check(m.invincible == switches[0] and m.enemies_paused == switches[1] and str(p.weapon.get("kind", "")) == kind_before, "the H, P and B that were typed flipped no switch and swapped no weapon")
	m.open_lab()
	_check(s.query == "hp" and s._search.text == "hp" and s._rows.size() == Lab.find("hp").size(), "the search is still there when the lab opens again")
	_check(s._close_button.has_focus(), "...and no page's button is lit over it (Close is)")
	await _key(KEY_ESCAPE)
	_check(s.is_open and s.query == "" and s._rows.has("player:MAX_HP"), "Esc over a search goes back to the page first...")
	await _key(KEY_ESCAPE)
	_check(not s.is_open, "...and Esc again closes the lab")
	m.open_lab()
	s._search.grab_focus()
	await _type("bow")
	s._pick_page("Sword")
	_check(s.query == "" and s._search.text == "" and s.page == "Sword" and s._rows.has("build:SHAPES/dagger/damage"), "a page's button puts the search away")
	s.close()
	_check(Lab.changed_count() == 0, "(nothing is left changed)")
	# The pause menu's way in.
	m.pause_menu.open()
	_check(m.pause_menu.is_open(), "(the pause menu is open)")
	m.pause_menu.lab_pressed.emit()
	_check(s.is_open and not m.pause_menu.is_open() and paused, "Lab in the pause menu: the menu closes and the lab opens")
	s.close()
	# Not while the forge is open.
	m.open_forge(0)
	m.open_lab()
	_check(not s.is_open, "the lab doesn't open over the forge")
	m.build_menu._really_close()
	paused = false
	m.queue_free()
	await _frames(3)


## The cave: the lab is in the pause menu, with no Spawn page, and its numbers are
## in force there (the guardian's health, a crawler's).
func _cave() -> void:
	Lab.set_value("guardian:HP", 300.0)
	Lab.set_value("crawler:HP", 20.0)
	Lab.set_value("build:METALS/wood", 6.0)
	var c = load("res://scripts/cave/cave.gd").new()
	c.inputs = [PlayerInput.make("script")]
	root.add_child(c)
	await _frames(5)
	_check(c.lab_screen != null, "the cave has the lab too")
	_check(is_equal_approx(c.guardian.max_hp, 300.0) and is_equal_approx(c.guardian.hp, 300.0), "the cave's guardian has the lab's health (300)")
	var cr = Crawler.new()
	c.world.add_child(cr)
	_check(is_equal_approx(cr.max_hp, 20.0), "a crawler has the lab's health (20)")
	c.builds[0].changed.emit()
	_check(is_equal_approx(float(c.players[0].weapon["damage"]), 6.0), "the wooden sword hits for the lab's 6")
	c.open_lab()
	_check(c.lab_screen.is_open and not c.lab_screen._page_buttons.has("Spawn"), "it opens, with no Spawn page (that is the arena's)")
	Lab.set_value("guardian:HP", 600.0)
	c.lab_screen.dirty = true
	c.lab_screen.close()
	_check(is_equal_approx(c.guardian.max_hp, 600.0) and is_equal_approx(c.guardian.hp, 600.0), "a change made in the cave reaches the sleeping guardian (600)")
	Lab.reset_all()
	c.lab_changed()
	_check(is_equal_approx(c.guardian.max_hp, 255.0) and is_equal_approx(cr.max_hp, 14.0), "reset: 255 and 14 again")
	paused = false
	c.queue_free()
	await _frames(3)
