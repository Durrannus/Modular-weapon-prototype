extends SceneTree
## Automatic checks for the sword rules (swing_build.gd). No game window needed.
## Run from the project folder:
##   godot --headless --path . -s tests/test_swing_build.gd
## Prints each failed check and exits with code 1 if any failed.

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")

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
	test_mirror()
	test_relay()
	test_one_bender_per_sword()
	test_gilded_ruby()
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
	var empty := SwingBuild.resolve(["twice", "", "cleave"])
	eq(effect(empty, "cleave")["count"], 2, "an empty slot between band and rune is skipped")


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
	b.set_blade("iron_blade")
	b.line = ["twice", "shockwave", "wider", "hook"]
	b.set_grip("wooden_grip")
	eq(b.line, ["twice", "wider", "hook"], "a smaller grip drops its top grip slot, blade slots stay")
	b.set_blade("iron_shortblade")
	eq(b.line, ["twice", "wider"], "a smaller blade drops its top blade slot")
	eq(b.line.size(), b.slot_count(), "line length matches slot count")


func test_ringed_grip() -> void:
	var b = SwingBuild.new()
	b.set_grip("ringed_grip")
	b.set_blade("iron_blade")
	b.line = ["shockwave", "", "", ""]
	eq(b.compute()["effects"][0]["size"], 1.3, "Ringed grip makes runes 1.3x")
	b.line = ["wider", "wider", "wider", "shockwave"]
	eq(b.compute()["effects"][0]["size"], SwingBuild.MAX_SIZE, "Ringed grip stays under the 2x cap")


func test_sentences() -> void:
	var r := SwingBuild.resolve(["twice", "shockwave", "wider", "hook"])
	eq(SwingBuild.sentence(effect(r, "shockwave")), "Your finisher sends two shockwaves forward.", "Shockwave x2 sentence")
	eq(SwingBuild.sentence(effect(r, "hook")), "Your finisher pulls enemies in from further away.", "wide Hook sentence")
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
	var r := SwingBuild.resolve(["every_hit", "cleave"])
	check(r["slots"][0].get("unused", false), "Every Hit on Cleave (already every hit) does nothing")
	eq(effect(r, "cleave")["power"], 1.0, "Cleave keeps full strength")


func test_saved_up() -> void:
	var e := effect(SwingBuild.resolve(["saved_up", "hook"]), "hook")
	eq(e["every"], 3, "Saved Up fires every third time")
	eq(e["power"], 3.0, "Saved Up is three times as strong")
	eq(SwingBuild.sentence(e), "Every third finisher pulls enemies in, three times as strong.", "Saved Up sentence")
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
	check(SwingBuild.resolve(["on_dodge", "second_wind"])["slots"][0].get("unused", false), "On Dodge can't go on Second Wind")
	check(SwingBuild.resolve(["on_dodge", "cleave"])["slots"][0].get("unused", false), "On Dodge can't go on Cleave")


func test_leap() -> void:
	var e := effect(SwingBuild.resolve(["leap"]), "leap")
	eq(e["trigger"], "dodge_attack", "Leap fires on an attack straight after a dodge")
	eq(SwingBuild.sentence(e), "An attack straight after a dodge jumps you to the nearest enemy.", "Leap sentence")
	var t := effect(SwingBuild.resolve(["twice", "wider", "leap"]), "leap")
	eq(SwingBuild.sentence(t), "An attack straight after a dodge jumps you to the nearest enemy, then the next one, from further away.", "Leap x2 wide sentence")


# --- Rule-benders ----------------------------------------------------------------

func test_mirror() -> void:
	var r := SwingBuild.resolve(["twice", "shockwave", "mirror"])
	eq(r["effects"].size(), 2, "Mirror above a rune makes a second copy of it")
	eq(r["effects"][1]["id"], "shockwave", "the copy is the same rune")
	eq(r["effects"][1]["count"], 2, "the copy gets the original's bands too")
	var g := SwingBuild.resolve(["twice", "wider", "shockwave", "mirror"])
	eq(g["effects"][1]["count"], 2, "Mirror copies the whole group (Twice)")
	eq(g["effects"][1]["size"], 1.6, "Mirror copies the whole group (Wider)")
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
	check(SwingBuild.resolve(["hook", "twice", "relay", "cleave"])["slots"][2].get("unused", false), "Relay needs the rune right below it")


func test_one_bender_per_sword() -> void:
	var r := SwingBuild.resolve(["hook", "mirror", "relay", "cleave"])
	check(r["slots"][2].get("unused", false), "a second rule-bender does nothing")
	eq(r["effects"].size(), 3, "the first rule-bender (Mirror) still works")


# --- Gilded grip: the ruby slot doubles what's in it (Darren, 6 November) ----------

func test_gilded_ruby() -> void:
	var b = SwingBuild.new()
	b.set_grip("gilded_grip")
	b.set_blade("iron_blade")
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
