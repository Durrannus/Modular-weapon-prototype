extends SceneTree
## Smoke check: opens the forge in the real scene with every fitting on the sword,
## draws a few frames and fires every rune on the player. Any script error shows in the log.
##   godot --headless --path . -s tests/smoke_forge.gd

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var forge = null
	for n in main.find_children("*", "", true, false):
		if n.get_script() == preload("res://scripts/ui/swing_forge.gd"):
			forge = n
	if forge == null:
		print("FAIL: no forge found")
		quit(1)
		return
	forge.open()
	var lines := [
		["twice", "shockwave", "relay", "hook"],
		["every_hit", "shockwave", "mirror", "saved_up"],
		["on_dodge", "leap", "mirror", "cleave"],
		["relay", "mirror", "wider", ""],
	]
	forge.build.set_grip("wrapped_grip")
	forge.build.set_blade("iron_blade")
	for l in lines:
		forge.build.line = l.duplicate()
		for t in forge.TABS.size():
			forge._set_tab(t)
			forge.root.queue_redraw()
			await process_frame
		for i in l.size():
			forge.selected = i
			forge.root.queue_redraw()
			await process_frame
	if not forge.buttons.has("tab:4"):
		print("FAIL: the forge never drew")
	forge._set_tab(4)
	forge.selected = 0
	forge._put("mirror")
	forge.selected = 3
	forge._put("relay")
	print("one bender kept: ", forge.build.line)
	forge.close()
	var player = main.find_children("*", "CharacterBody2D", true, false)[0]
	forge.build.line = ["on_dodge", "leap", "saved_up", "shockwave"]
	player.set_weapon(forge.build.compute())
	for trig in ["dodge", "dodge_attack", "finisher", "finisher", "finisher", "hit", "kill"]:
		player._trigger(trig, [])
		for f in 12:
			await physics_frame
	print("smoke done")
	quit(0)
