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
		["on_dodge", "leap", "mirror", "shards"],
		["relay", "mirror", "wider", ""],
	]
	forge.build.set_grip("gilded_grip")
	forge.build.set_blade("iron_broadsword")
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
	if not forge.buttons.has("tab:3"):
		print("FAIL: the forge never drew")
	forge._set_tab(3)
	forge.selected = 0
	forge._put("mirror")
	forge.selected = 3
	forge._put("relay")
	print("one bender kept: ", forge.build.line)
	# Drag and drop: tray card onto slot 0, slot 0 onto slot 1 (swap), slot 1 off the sword.
	forge.build.line = ["", "hook", "", ""]
	forge._set_tab(1)
	forge.drag_id = forge._drag_source("card:0"); forge.drag_from = -1; forge.drag_key = "card:0"; forge.dragging = true
	forge._drop("slot:0")
	print("drag card->slot0: ", forge.build.line)
	forge.drag_id = forge._drag_source("slot:0"); forge.drag_from = 0; forge.drag_key = "slot:0"; forge.dragging = true
	forge._drop("slot:1")
	print("drag slot0->slot1 swap: ", forge.build.line)
	forge.drag_id = forge._drag_source("slot:1"); forge.drag_from = 1; forge.drag_key = "slot:1"; forge.dragging = true
	forge._drop("")
	print("drag slot1 off: ", forge.build.line)
	forge.drag_id = forge._drag_source("card:2"); forge.drag_from = -1; forge.drag_key = "card:2"; forge.dragging = false
	forge._drop("")
	print("press without drag = click, selected card: ", forge.card)
	forge._set_tab(0)
	for i in forge._cards().size():
		forge._use_card(i)
	print("sword tab used: ", forge.build.blade, " ", forge.build.grip, " ", forge.build.pommel)
	forge.close()
	var player = main.find_children("*", "CharacterBody2D", true, false)[0]
	forge.build.line = ["every_hit", "shards", "on_dodge", "leap"]
	player.set_weapon(forge.build.compute())
	for k in 6:
		main._spawn_enemy()
	for e in player.get_tree().get_nodes_in_group("enemies"):
		e.global_position = player.global_position + Vector2(50, 0).rotated(randf() * TAU)
	for trig in ["dodge", "dodge_attack", "finisher", "finisher", "finisher", "hit", "kill"]:
		player._trigger(trig, [])
		for f in 12:
			await physics_frame
	forge.build.line = ["on_dodge", "whirlwind", "wider", "leap"]
	player.set_weapon(forge.build.compute())
	for e in player.get_tree().get_nodes_in_group("enemies"):
		e.global_position = player.global_position + Vector2(50, 0).rotated(randf() * TAU)
	for trig in ["dodge", "dodge_attack", "finisher", "finisher", "finisher", "hit", "kill"]:
		player._trigger(trig, [])
		for f in 12:
			await physics_frame
	print("smoke done")
	quit(0)
