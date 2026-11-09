extends CanvasLayer
## Esc pause menu: Resume, Fullscreen on/off, Quit. Pauses the whole game.

const Art := preload("res://scripts/art.gd")

signal to_title

var panel: Control
var build_menu  # Esc closes the forge first if it's open
var locked := false  # a cutscene or the ending is showing: no pausing


## Esc: close the forge if it's open, otherwise open or close this menu.
## Handled here because this node keeps running while the game is paused.
func _unhandled_input(event: InputEvent) -> void:
	var esc: bool = event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE
	# Start on a controller pauses too (and B backs out of this menu).
	var start: bool = event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START and pad_start
	var back: bool = event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B and is_open()
	if locked and not is_open():
		return
	if esc or start or back:
		if is_open():
			resume()
		elif build_menu != null and build_menu.is_open:
			build_menu._really_close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	add_child(panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(160, 0)
	box.position = Vector2(-80, -60)
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var f := Art.font("Silkscreen-Regular")
	if f != null:
		title.add_theme_font_override("font", f)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#ffb24a"))
	box.add_child(title)
	for item in [["Resume", resume], ["Fullscreen on/off", _toggle_full], ["Back to title", _title], ["Quit game", _quit]]:
		var b := Button.new()
		b.text = item[0]
		b.focus_mode = Control.FOCUS_ALL
		if f != null:
			b.add_theme_font_override("font", f)
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(item[1])
		box.add_child(b)


func is_open() -> bool:
	return panel.visible


func open() -> void:
	panel.visible = true
	get_tree().paused = true
	(panel.get_child(1).get_child(1) as Button).grab_focus()


func resume() -> void:
	panel.visible = false
	get_tree().paused = false


func _toggle_full() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## True where Start should pause (the cave). In the arena Start pauses the enemies.
var pad_start := false


func _title() -> void:
	resume()
	to_title.emit()


func _quit() -> void:
	get_tree().quit()
