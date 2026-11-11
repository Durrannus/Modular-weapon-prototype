extends SceneTree
## Automatic checks for the sword rules (swing_build.gd). No game window needed.
## Run from the project folder:
##   godot --headless --path . -s tests/test_swing_build.gd
## Prints each failed check and exits with code 1 if any failed.

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const Player := preload("res://scripts/player.gd")

var failures := 0
var checks := 0


func _init() -> void:
	test_band_boosts_rune_above()
	test_order_swap()
	test_band_with_no_rune_does_nothing()
	test_caps()
	test_refit_keeps_grip_and_blade_slots()
	test_ringed_grip()
	test_sentences()
	test_every_hit()
	test_saved_up()
	test_on_dodge()
	test_leap()
	test_weak_point()
	test_three_buttons()
	test_mirror()
	test_relay()
	test_one_bender_per_sword()
	test_gilded_ruby()
	test_whirlwind()
	test_active_runes()
	test_shards()
	test_pommels()
	test_blade_shapes()
	test_presets()
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + what)


func eq(got, want, what: String) -> void:
	check(got == want, "%s (got %s, want %s)" % [what, str(got), str(want)])


func effect(r: Dictionary, id: String) -> Dictionary:
	for e in r["effects"]:
		if e["id"] == id:
			return e
	return {}


# --- The one rule -------------------------------------------------------------

func test_band_boosts_rune_above() -> void:
	var r := SwingBuild.resolve(["twice", "shockwave", "wider", "hook"])
	eq(r["effects"].size(), 2, "test sword A has two runes")
	eq(effect(r, "shockwave")["count"], 2, "A: Twice boosts Shockwave")
	eq(effect(r, "shockwave")["size"], 1.0, "A: Shockwave is normal size")
	eq(effect(r, "hook")["count"], 1, "A: Hook fires once")
	eq(effect(r, "hook")["size"], 1.6, "A: Wider boosts Hook")


func test_order_swap() -> void:
	var r := SwingBuild.resolve(["shockwave", "twice", "wider", "hook"])
	eq(effect(r, "shockwave")["count"], 1, "B: Shockwave is plain")
	eq(effect(r, "hook")["count"], 2, "B: both bands stack onto Hook (Twice)")
	eq(effect(r, "hook")["size"], 1.6, "B: both bands stack onto Hook (Wider)")
	eq(effect(r, "hook")["band_slots"], [1, 2], "B: Hook's bands are slots 1 and 2")


func test_band_with_no_rune_does_nothing() -> void:
	var r := SwingBuild.resolve(["hook", "twice"])
	eq(effect(r, "hook")["count"], 1, "a band below nothing does not boost the rune under it")
	check(r["slots"][1].get("unused", false), "a band with no rune above is marked unused")
	var empty := SwingBuild.resolve(["twice", "", "shards"])
	eq(effect(empty, "shards")["count"], 2, "an empty slot between band and rune is skipped")


func test_caps() -> void:
	var r := SwingBuild.resolve(["twice", "twice", "twice", "shockwave"])
	eq(effect(r, "shockwave")["count"], SwingBuild.MAX_COUNT, "Twice tops out at 3 fires")
	eq(SwingBuild.wider_size(1), 1.6, "one Wider is 1.6x")
	eq(SwingBuild.wider_size(2), 1.85, "two Wider is 1.85x")
	eq(SwingBuild.wider_size(3), 2.0, "three Wider is 2x")
	eq(SwingBuild.wider_size(5), 2.0, "Wider never passes 2x")


func test_refit_keeps_grip_and_blade_slots() -> void:
	var b = SwingBuild.new()
	b.set_grip("wrapped_grip")
	b.set_blade("iron_broadsword")
	b.line = ["twice", "shockwave", "wider", "hook"]
	b.set_grip("wooden_grip")
	eq(b.line, ["twice", "wider", "hook"], "a smaller grip drops its top grip slot, blade slots stay")
	b.set_blade("tin_blade")
	eq(b.line, ["twice", "wider"], "a smaller blade drops its top blade slot")
	eq(b.line.size(), b.slot_count(), "line length matches slot count")


func test_ringed_grip() -> void:
	var b = SwingBuild.new()
	b.set_grip("ringed_grip")
	b.set_blade("iron_broadsword")
	b.line = ["shockwave", "", "", ""]
	eq(b.compute()["effects"][0]["size"], 1.3, "Ringed grip makes runes 1.3x")
	b.line = ["wider", "wider", "wider", "shockwave"]
	eq(b.compute()["effects"][0]["size"], SwingBuild.MAX_SIZE, "Ringed grip stays under the 2x cap")


func test_sentences() -> void:
	var r := SwingBuild.resolve(["twice", "shockwave", "wider", "hook"])
	eq(SwingBuild.sentence(effect(r, "shockwave")), "Your finisher sends two shockwaves forward.", "Shockwave x2 sentence")
	eq(SwingBuild.sentence(effect(r, "hook")), "Press right mouse: pulls enemies in from further away. Recharges in 4 seconds.", "wide Hook sentence")
	for id in SwingBuild.FITTING_ORDER:
		if SwingBuild.FITTINGS[id]["kind"] != "rune":
			continue
		var e := effect(SwingBuild.resolve([id]), id)
		check(SwingBuild.sentence(e) != "", "every rune has a sentence: " + id)


# --- New bands ------------------------------------------------------------------

func test_every_hit() -> void:
	var e := effect(SwingBuild.resolve(["every_hit", "shockwave"]), "shockwave")
	eq(e["trigger"], "hit", "Every Hit moves Shockwave to every hit")
	eq(e["power"], 0.5, "Every Hit halves the strength")
	eq(SwingBuild.sentence(e), "Every hit sends a shockwave forward, at half strength.", "Every Hit sentence")
	var r := SwingBuild.resolve(["every_hit", "shards"])
	check(r["slots"][0].has("band"), "Every Hit on Shards works: they splinter")
	check(effect(r, "shards").get("splinter", false), "Every Hit makes Shards splinter")
	eq(effect(r, "shards")["power"], 0.5, "splintered Shards are half strength")
	check(SwingBuild.resolve(["every_hit", "every_hit", "shards"])["slots"][1].get("unused", false), "a second Every Hit on Shards does nothing")
	eq(SwingBuild.sentence(effect(r, "shards")), "Every hit sends shards jumping to the closest enemies, splitting in two at each jump, at half strength.", "Splinter sentence")


func test_saved_up() -> void:
	var e := effect(SwingBuild.resolve(["saved_up", "shockwave"]), "shockwave")
	eq(e["every"], 3, "Saved Up fires every third time")
	eq(e["power"], 3.0, "Saved Up is three times as strong")
	eq(SwingBuild.sentence(e), "Every third finisher sends a shockwave forward, three times as strong.", "Saved Up sentence")
	var r := SwingBuild.resolve(["saved_up", "saved_up", "hook"])
	eq(effect(r, "hook")["power"], 3.0, "a second Saved Up doesn't stack")
	check(r["slots"][1].get("unused", false), "the second Saved Up shows as doing nothing")
	var both := effect(SwingBuild.resolve(["every_hit", "saved_up", "shockwave"]), "shockwave")
	eq(both["power"], 1.5, "Every Hit then Saved Up: every third hit at 1.5x")
	eq(both["trigger"], "hit", "Every Hit then Saved Up still on hits")


func test_on_dodge() -> void:
	var e := effect(SwingBuild.resolve(["on_dodge", "shockwave"]), "shockwave")
	eq(e["also"], ["dodge"], "On Dodge adds the dodge trigger")
	eq(e["trigger"], "finisher", "On Dodge keeps the finisher trigger")
	eq(SwingBuild.sentence(e), "Your finisher sends a shockwave forward. Dodging does it too.", "On Dodge sentence")
	eq(effect(SwingBuild.resolve(["on_dodge", "shards"]), "shards")["also"], ["dodge"], "On Dodge works on Shards (they fly from you)")


# Leap is active since 11 November: a press, landing at the blade's reach.
func test_leap() -> void:
	var e := effect(SwingBuild.resolve(["leap"]), "leap")
	eq(e["trigger"], "active", "Leap waits for its button")
	eq(SwingBuild.FITTINGS["leap"]["use"], "press", "Leap is used with a press")
	eq(SwingBuild.sentence(e), "Press right mouse: leaps you to the nearest enemy and strikes it from your blade's reach. Recharges in 3 seconds.", "Leap sentence")
	var t := effect(SwingBuild.resolve(["twice", "wider", "leap"]), "leap")
	eq(SwingBuild.sentence(t), "Press right mouse: leaps you to the nearest enemy from further away and strikes it from your blade's reach, then the next one. Recharges in 3 seconds.", "Leap x2 wide sentence")
	eq(SwingBuild.abilities([effect(SwingBuild.resolve(["saved_up", "leap"]), "leap")])[0]["recharge"], 9.0, "Saved Up makes Leap three times as slow to recharge")
	var auto := effect(SwingBuild.resolve(["every_hit", "leap"]), "leap")
	eq(SwingBuild.sentence(auto), "Every hit leaps you to the nearest enemy, at half strength.", "Every Hit Leap sentence")
	check(not SwingBuild.WHEN.has("dodge_attack"), "nothing fires on an attack after a dodge any more")


# Weak Point, the new passive (11 November).
func test_weak_point() -> void:
	var e := effect(SwingBuild.resolve(["weak_point"]), "weak_point")
	eq(e["trigger"], "finisher", "Weak Point marks on the finisher")
	check(not e.has("button"), "and it is passive")
	eq(SwingBuild.sentence(e), "Your finisher marks the enemy it hits, and your next hit on a mark is a big crit.", "Weak Point sentence")
	var two := effect(SwingBuild.resolve(["twice", "wider", "weak_point"]), "weak_point")
	eq(two["count"], 2, "Twice: two marks")
	eq(SwingBuild.sentence(two), "Your finisher marks up to two enemies with bigger spots, and your next hit on a mark is a big crit.", "Weak Point x2 wide sentence")
	var every := effect(SwingBuild.resolve(["every_hit", "weak_point"]), "weak_point")
	eq([every["trigger"], every["power"]], ["hit", 0.5], "Every Hit: a mark on every hit, at half strength")
	eq(SwingBuild.sentence(every), "Every hit marks the enemy it hits, and your next hit on a mark is a smaller crit.", "Every Hit Weak Point sentence")
	var saved := effect(SwingBuild.resolve(["saved_up", "weak_point"]), "weak_point")
	eq([saved["every"], saved["power"]], [3, 3.0], "Saved Up: every third finisher, three times as strong")
	eq(SwingBuild.sentence(saved), "Every third finisher marks the enemy it hits, and your next hit on a mark is a huge crit.", "Saved Up Weak Point sentence")
	eq(effect(SwingBuild.resolve(["on_dodge", "weak_point"]), "weak_point")["also"], ["dodge"], "On Dodge: a dodge marks too")
	check(not SwingBuild.FITTINGS.has("second_wind"), "Second Wind is gone")
	# Three passive and three active sword runes.
	var passive := 0
	var active := 0
	for id in SwingBuild.FITTINGS:
		var f: Dictionary = SwingBuild.FITTINGS[id]
		if f["kind"] == "rune":
			if f["trigger"] == "active":
				active += 1
			else:
				passive += 1
	eq([passive, active], [3, 3], "three passive and three active sword runes")


# Up to three active runes, each on its own button (11 November; it was two).
func test_three_buttons() -> void:
	var r := SwingBuild.resolve(["whirlwind", "hook", "leap", "weak_point"])
	eq([effect(r, "whirlwind")["button"], effect(r, "hook")["button"], effect(r, "leap")["button"]], [0, 1, 2], "three active runes take buttons one, two and three")
	for i in 3:
		check(not r["slots"][i].has("unused"), "active rune %d works" % (i + 1))
	var a: Array = SwingBuild.abilities(r["effects"])
	eq(a.size(), 3, "three abilities")
	eq([a[2]["id"], a[2]["use"], a[2]["recharge"]], ["leap", "press", 3.0], "Leap: a press, 3 seconds")
	eq(SwingBuild.sentence(effect(r, "leap")), "Press R: leaps you to the nearest enemy and strikes it from your blade's reach. Recharges in 3 seconds.", "the third active rune names the third button")
	eq(SwingBuild.sentence(effect(r, "leap"), SwingBuild.ABILITY_KEYS["pad"]), "Press B: leaps you to the nearest enemy and strikes it from your blade's reach. Recharges in 3 seconds.", "and the controller's name for it")
	for kind in ["kbm", "pad"]:
		eq([SwingBuild.ABILITY_KEYS[kind].size(), SwingBuild.ABILITY_PROMPTS[kind].size()], [3, 3], kind + " has three ability buttons")
	var s = SwingBuild.new()
	s.load_test("D")
	eq(s.compute()["abilities"].size(), 3, "test sword D has three abilities")


# --- Rule-benders ----------------------------------------------------------------

func test_mirror() -> void:
	var r := SwingBuild.resolve(["twice", "shockwave", "mirror"])
	eq(r["effects"].size(), 2, "Mirror above a rune makes a second copy of it")
	eq(r["effects"][1]["id"], "shockwave", "the copy is the same rune")
	eq(r["effects"][1]["count"], 1, "the copy doesn't get the bands below the original")
	check(r["effects"][1]["mirror"], "the copy is marked as a Mirror")
	var b := SwingBuild.resolve(["wider", "mirror", "hook"])
	eq(effect(b, "hook")["size"], 1.85, "Mirror above a band counts as a second band")
	check(b["slots"][1].get("mirror", false) and b["slots"][1].has("band"), "a mirrored band is grouped with its rune")
	check(SwingBuild.resolve(["mirror", "hook"])["slots"][0].get("unused", false), "Mirror with nothing below does nothing")
	var gap := SwingBuild.resolve(["hook", "", "mirror"])
	eq(gap["effects"].size(), 2, "Mirror skips empty slots to find what to copy")


func test_relay() -> void:
	var r := SwingBuild.resolve(["twice", "shockwave", "relay", "hook"])
	eq(effect(r, "shockwave")["count"], 2, "Relay: the rune below keeps its bands")
	eq(effect(r, "hook")["count"], 2, "Relay: the next rune above gets them too")
	var s := SwingBuild.resolve(["twice", "shockwave", "relay", "wider", "hook"])
	eq(effect(s, "hook")["count"], 2, "Relay plus Hook's own band: Twice")
	eq(effect(s, "hook")["size"], 1.6, "Relay plus Hook's own band: Wider")
	check(SwingBuild.resolve(["relay", "hook"])["slots"][0].get("unused", false), "Relay with no rune below does nothing")
	check(SwingBuild.resolve(["hook", "relay"])["slots"][1].get("unused", false), "Relay with no rune above does nothing")
	check(SwingBuild.resolve(["hook", "twice", "relay", "shards"])["slots"][2].get("unused", false), "Relay needs the rune right below it")


func test_one_bender_per_sword() -> void:
	var r := SwingBuild.resolve(["hook", "mirror", "relay", "shards"])
	check(r["slots"][2].get("unused", false), "a second rule-bender does nothing")
	eq(r["effects"].size(), 3, "the first rule-bender (Mirror) still works")


# --- Gilded grip: the ruby slot doubles what's in it (Darren, 6 November) ----------

func test_gilded_ruby() -> void:
	var b = SwingBuild.new()
	b.set_grip("gilded_grip")
	b.set_blade("iron_broadsword")
	check(not SwingBuild.GRIPS["gilded_grip"].get("locked", false), "the Gilded grip is unlocked")
	b.line = ["", "shockwave", "", ""]
	eq(b.compute()["effects"][0]["count"], 2, "a rune in the ruby slot fires twice")
	b.line = ["twice", "shockwave", "", ""]
	eq(b.compute()["effects"][0]["count"], 3, "ruby plus Twice: three fires (the cap)")
	b.line = ["twice", "twice", "shockwave", ""]
	eq(b.compute()["effects"][0]["count"], SwingBuild.MAX_COUNT, "a band in the ruby slot still respects the Twice cap")
	b.line = ["", "wider", "hook", ""]
	eq(b.compute()["effects"][0]["size"], 1.85, "Wider in the ruby slot counts as two Widers")
	b.line = ["shockwave", "", "hook", ""]
	eq(b.compute()["effects"][0]["count"], 1, "a rune in the bottom (plain) slot is not doubled")
	eq(b.compute()["effects"][1]["count"], 1, "blade slots are not doubled")
	b.line = ["", "saved_up", "hook", ""]
	eq(b.compute()["effects"][0]["power"], 3.0, "Saved Up in the ruby slot doesn't go past its max")
	check(b.compute()["slot_info"][1].has("band"), "Saved Up in the ruby slot still works")


# --- Whirlwind replaces Second Wind (Darren, 6 November) -----------------------------

func test_whirlwind() -> void:
	var e := effect(SwingBuild.resolve(["twice", "wider", "whirlwind"]), "whirlwind")
	eq(e["trigger"], "active", "Whirlwind waits for its button")
	eq(SwingBuild.sentence(e), "Hold right mouse: spins for up to six turns, cutting everything around you, in a bigger circle. Recharges in 5 seconds.", "Whirlwind x2 wide sentence")
	eq(SwingBuild.sentence(effect(SwingBuild.resolve(["on_dodge", "whirlwind"]), "whirlwind")), "Hold right mouse: spins for up to three turns, cutting everything around you. Recharges in 5 seconds. Dodging does it too.", "Whirlwind on dodge")


# --- Active and passive runes (Darren, 10 November) ----------------------------------

func test_active_runes() -> void:
	for id in ["shockwave", "shards", "weak_point"]:
		check(SwingBuild.FITTINGS[id]["trigger"] != "active", id + " is passive")
	eq(SwingBuild.FITTINGS["hook"]["use"], "press", "Hook is used with a press")
	eq(SwingBuild.FITTINGS["whirlwind"]["use"], "hold", "Whirlwind is used by holding")
	# Buttons go in the order the runes sit on the sword, grip to tip.
	var r := SwingBuild.resolve(["hook", "shockwave", "whirlwind"])
	eq(effect(r, "hook")["button"], 0, "the lowest active rune gets button one")
	eq(effect(r, "whirlwind")["button"], 1, "the next one up gets button two")
	check(not effect(r, "shockwave").has("button"), "a passive rune has no button")
	eq(effect(SwingBuild.resolve(["whirlwind", "hook"]), "whirlwind")["button"], 0, "swap them and the buttons swap")
	var a: Array = SwingBuild.abilities(r["effects"])
	eq(a.size(), 2, "two active runes, two abilities")
	eq([a[0]["id"], a[0]["use"], a[0]["recharge"]], ["hook", "press", 4.0], "Hook: a press, 4 seconds")
	eq([a[1]["id"], a[1]["use"], a[1]["recharge"], a[1]["turns"]], ["whirlwind", "hold", 5.0, 3], "Whirlwind: a hold, 5 seconds, three turns")
	# Two of the same rune share a button and go off together.
	var two := SwingBuild.resolve(["hook", "wider", "hook"])
	eq([two["effects"][0]["button"], two["effects"][1]["button"]], [0, 0], "two Hooks share button one")
	eq(SwingBuild.abilities(two["effects"])[0]["effects"], [0, 1], "and one press fires both")
	# Bands still change them.
	eq(SwingBuild.abilities(SwingBuild.resolve(["twice", "whirlwind"])["effects"])[0]["turns"], 6, "Twice doubles Whirlwind's turns")
	eq(SwingBuild.abilities(SwingBuild.resolve(["twice", "twice", "twice", "whirlwind"])["effects"])[0]["turns"], 9, "capped at three times")
	eq(effect(SwingBuild.resolve(["twice", "hook"]), "hook")["count"], 2, "Twice makes a press of Hook fire twice")
	eq(effect(SwingBuild.resolve(["wider", "whirlwind"]), "whirlwind")["size"], 1.6, "Wider makes Whirlwind bigger")
	var saved := effect(SwingBuild.resolve(["saved_up", "hook"]), "hook")
	eq(saved["power"], 3.0, "Saved Up makes Hook three times as strong")
	eq(SwingBuild.abilities([saved])[0]["recharge"], 12.0, "and three times as slow to recharge")
	eq(SwingBuild.sentence(saved), "Press right mouse: pulls enemies in, three times as strong. Recharges in 12 seconds.", "Saved Up Hook sentence")
	var auto := effect(SwingBuild.resolve(["every_hit", "whirlwind"]), "whirlwind")
	eq(auto["trigger"], "hit", "Every Hit makes Whirlwind fire by itself")
	check(not auto.has("button"), "so it needs no button")
	eq(SwingBuild.sentence(auto), "Every hit spins a full circle, cutting everything around you, at half strength.", "Every Hit Whirlwind sentence")
	check(SwingBuild.abilities([auto]).is_empty(), "and it isn't an ability")
	var dodge := effect(SwingBuild.resolve(["on_dodge", "hook"]), "hook")
	eq([dodge["trigger"], dodge["also"]], ["active", ["dodge"]], "On Dodge keeps Hook on its button and adds the dodge")
	# The Gilded grip's ruby slot and the sentences' button names.
	var ruby := effect(SwingBuild.resolve(["", "whirlwind"], 1), "whirlwind")
	eq(SwingBuild.abilities([ruby])[0]["turns"], 6, "the ruby slot doubles Whirlwind's turns")
	var second := effect(SwingBuild.resolve(["whirlwind", "hook"]), "hook")
	eq(SwingBuild.sentence(second), "Press Q: pulls enemies in. Recharges in 4 seconds.", "the second active rune names the second button")
	eq(SwingBuild.sentence(second, SwingBuild.ABILITY_KEYS["pad"]), "Press LB: pulls enemies in. Recharges in 4 seconds.", "and the controller's name for it")
	# The whole sword.
	var s = SwingBuild.new()
	s.load_test("C")
	var stats: Dictionary = s.compute()
	eq(stats["abilities"].size(), 2, "test sword C has two abilities")
	eq(stats["abilities"][0]["id"], "whirlwind", "Whirlwind on button one")
	eq(effect({"effects": stats["effects"]}, "shockwave")["count"], 2, "and Shockwave twice, by itself")


func test_shards() -> void:
	var e := effect(SwingBuild.resolve(["twice", "wider", "shards"]), "shards")
	eq(e["trigger"], "hit", "Shards fire on every hit")
	eq(SwingBuild.sentence(e), "Every hit sends shards jumping to the closest enemies twice, from further away.", "Shards x2 wide sentence")
	check(not SwingBuild.FITTINGS.has("cleave"), "Cleave is gone")


func test_pommels() -> void:
	var b = SwingBuild.new()
	eq(b.pommel, "plain_pommel", "swords start with the plain pommel")
	var base: Dictionary = b.compute()
	var slots_before: int = b.slot_count()
	b.set_pommel("keen_pommel")
	eq(snappedf(b.compute()["crit"] - base["crit"], 0.001), 0.08, "Keen pommel: +8% crit chance")
	b.set_pommel("heavy_pommel")
	eq(snappedf(b.compute()["crit_damage"] - base["crit_damage"], 0.001), 0.4, "Heavy pommel: +40% crit damage")
	b.set_pommel("light_pommel")
	eq(snappedf(b.compute()["speed"] / base["speed"], 0.001), 1.1, "Light pommel: +10% swing speed")
	eq(b.slot_count(), slots_before, "pommels add no slots")


# --- The six blade shapes (Game Bible, 11 November) --------------------------------

func test_blade_shapes() -> void:
	eq(SwingBuild.SHAPE_ORDER.size(), 6, "there are six blade shapes")
	eq(SwingBuild.BLADE_ORDER.size(), 6, "and an iron blade of each")
	var broad := SwingBuild.blade_info("iron_broadsword")
	eq(broad["damage"], 11.0, "the iron broadsword does 11 damage")
	var base_time := 0.0
	for id in SwingBuild.BLADE_ORDER:
		var b := SwingBuild.blade_info(id)
		eq(b["slots"], 2, id + ": every iron shape has two slots")
		eq((b["chain"] as Array).size(), 3, id + ": a three-hit chain")
		var power := 0.0
		var time := 0.0
		for m in b["chain"]:
			check(Player.MOVES.has(m), id + ": the move '%s' exists" % m)
			check(SwingBuild.MOVE_NAMES.has(m), id + ": the move '%s' has a name" % m)
			power += float(Player.MOVES[m]["power"])
			time += float(Player.MOVES[m]["time"])
		eq(snappedf(power, 0.001), 3.5, id + ": a chain is 1 + 1 + 1.5 hits")
		if base_time == 0.0:
			base_time = time
		eq(snappedf(time, 0.001), snappedf(base_time, 0.001), id + ": every chain takes the same time at speed 1")
		# Shape is a way of playing, not more power: damage a second within a tenth of the broadsword's.
		var dps: float = float(b["damage"]) * float(b["speed"]) / (float(broad["damage"]) * float(broad["speed"]))
		check(dps >= 0.9 and dps <= 1.1, "%s: damage a second within 10%% of the broadsword (%.2f)" % [id, dps])
	check(is_equal_approx(SwingBuild.blade_info("iron_dagger")["damage"], 6.6), "dagger: 0.6 of the broadsword's damage")
	eq(SwingBuild.blade_info("iron_dagger")["speed"], 1.6, "dagger: 1.6x speed")
	eq(SwingBuild.blade_info("iron_dagger")["swing_move"], 1.0, "dagger: full speed while attacking")
	eq(SwingBuild.blade_info("iron_sabre")["crit"], 0.1, "sabre: +10% crit chance")
	eq(SwingBuild.blade_info("iron_rapier")["reach"], 1.4, "rapier: 1.4x reach")
	eq(int(Player.MOVES["thrust"]["max_hits"]), 2, "rapier: a thrust goes through to a second enemy")
	eq(str(Player.MOVES["thrust"]["shape"]), "line", "rapier: thrusts are a straight line")
	check(float(Player.MOVES["chop"]["knock"]) > float(Player.MOVES["slash"]["knock"]) * 1.5, "falchion: big knockback")
	check(float(Player.MOVES["cleave"]["stun"]) >= 0.6, "falchion: the finisher staggers")
	eq(SwingBuild.blade_info("iron_greatsword")["swing_move"], 0.7, "greatsword: 70% speed while swinging")
	check(is_equal_approx(SwingBuild.blade_info("iron_greatsword")["damage"], 17.6), "greatsword: 1.6 of the broadsword's damage")
	eq(float(Player.MOVES["great_sweep"]["arc"]), 180.0, "greatsword: sweeps half a circle")
	eq(float(Player.MOVES["dagger_slash"]["arc"]), 60.0, "dagger: a 60 degree slash")
	eq(float(Player.MOVES["sabre_slash"]["arc"]), 160.0, "sabre: 160 degree cuts")
	eq(float(Player.MOVES["slash"]["arc"]), 120.0, "broadsword: 120 degree slashes")
	eq(float(Player.MOVES["overhead"]["power"]), 1.5, "broadsword: the finisher is 1.5 hits")
	# The tutorial's blades are broadswords in softer stuff.
	eq(SwingBuild.blade_info("wooden_blade")["damage"], 5.0, "wooden blade: 5 damage")
	eq(SwingBuild.blade_info("tin_blade")["damage"], 8.0, "tin blade: 8 damage")
	eq(SwingBuild.blade_info("tin_blade")["chain"], broad["chain"], "tin blade: the broadsword's chain")
	# Slots never make a part weaker: a grip with more of them swings just as fast.
	var b = SwingBuild.new()
	b.set_blade("iron_broadsword")
	b.set_grip("wooden_grip")
	var one: float = b.compute()["speed"]
	b.set_grip("long_grip")
	eq(b.compute()["speed"], one, "a three-slot grip swings as fast as a one-slot grip")
	b.set_blade("iron_sabre")
	eq(snappedf(b.compute()["crit"], 0.001), snappedf(SwingBuild.BASE_CRIT + 0.1, 0.001), "a sabre's crit chance reaches the sword")
	eq(b.compute()["steps"][1]["name"], "backslash", "steps carry the move's name for the screen")


## Loadout presets (Game Bible, 11 November): three saved swords, one click to switch.
func test_presets() -> void:
	check(SwingBuild.valid_data(SwingBuild.new().get_data()), "a new sword (wooden blade, wooden grip) is a valid one")
	var b := SwingBuild.new()
	var emitted := [0]
	b.changed.connect(func(): emitted[0] += 1)
	b.load_test("D")
	var first: Array = b.get_data()
	eq(b.preset, 0, "a sword starts on preset A")
	eq(b.preset_sword(0), first, "the chosen preset is the sword in the hand")
	check(b.preset_sword(1) == null and b.preset_sword(2) == null, "B and C start empty")
	emitted[0] = 0
	eq(b.use_preset(1), [], "switching to an empty preset leaves nothing off")
	eq(emitted[0], 1, "switching presets announces the change once")
	eq(b.preset, 1, "now on preset B")
	eq(b.get_data(), first, "an empty preset starts as a copy of the sword in the hand")
	b.set_blade("iron_greatsword")
	b.set_grip("long_grip")
	b.line = ["shockwave", "twice", "wider", "weak_point", "hook"]
	b.set_pommel("heavy_pommel")
	var second: Array = b.get_data()
	eq(b.preset_sword(0), first, "preset A still holds the first sword")
	b.use_preset(0)
	eq(b.get_data(), first, "back on A: the whole first sword, in one go")
	eq(b.preset_sword(1), second, "and B kept the second one (blade, grip, pommel, runes and bands)")
	b.use_preset(1)
	eq(b.get_data(), second, "back on B: the whole second sword")
	check(SwingBuild.valid_data(b.get_data()), "a sword loaded from a preset is one the other computer accepts")
	eq(b.use_preset(1), [], "choosing the preset you are on does nothing")
	eq(b.use_preset(7), [], "there are only three")
	eq(b.preset, 1, "still on B")
	b.preset_names[1] = "Bossing"
	eq(b.preset_title(1), "Preset B: Bossing", "a named preset reads as the Bible writes it")
	eq(b.preset_title(2), "Preset C", "one with no name is just its letter")
	# A saved part the player no longer owns is left off, and the rest still loads.
	b.use_preset(0)
	var owned := ["iron_broadsword", "iron_greatsword", "wrapped_grip", "plain_pommel", "heavy_pommel",
		"shockwave", "twice", "weak_point", "whirlwind", "hook", "leap"]
	eq(SwingBuild.parts_missing(b.preset_sword(1), owned), ["long_grip", "wider"], "the parts of B that aren't owned any more")
	eq(SwingBuild.parts_missing(b.preset_sword(1), null), [], "owning everything, nothing is missing")
	eq(SwingBuild.parts_missing(null, owned), [], "an empty preset has nothing missing")
	eq(b.use_preset(1, owned), ["long_grip", "wider"], "loading B says what it left off")
	eq(b.blade, "iron_greatsword", "the blade it does own goes on")
	eq(b.grip, "wrapped_grip", "the grip it doesn't own stays as it was")
	eq(b.pommel, "heavy_pommel", "the pommel goes on")
	eq(b.line, ["shockwave", "twice", "weak_point", "hook"], "grip slots keep the grip's fittings, blade slots the blade's, the missing band is left off")
	check(SwingBuild.valid_data(b.get_data()), "and the sword is still a valid one")
