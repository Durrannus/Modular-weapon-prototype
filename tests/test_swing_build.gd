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
