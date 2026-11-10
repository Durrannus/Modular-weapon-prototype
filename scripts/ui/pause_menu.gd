extends CanvasLayer
## Esc pause menu: Resume, Fullscreen on/off, Back to title, Quit. Pauses the whole game.
## Online it can't pause (the other player is still playing), so it is just a menu:
## the game carries on behind it and your character stands still.

const Art := preload("res://scripts/art.gd")

signal to_title
signal resumed

var panel: Control
var first_button: Button
var build_menu  # Esc closes the forge first if it's open
var locked := false  # a cutscene or the ending is showing: no pausing
var pauses := true   # false online (set before adding it to the scene)


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
	dim.color = Color(0.06, 0.04, 0.09, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	# A dark plate with a bronze edge, from the menu kit.
	var plate := Panel.new()
	plate.position = Vector2(230, 104)
	plate.size = Vector2(180, 150)
	var plate_box: StyleBox = Art.nine("swing/ui/panel.png", 8)
	if plate_box == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("#19142a")
		plate_box = flat
	plate.add_theme_stylebox_override("panel", plate_box)
	panel.add_child(plate)
	var box := VBoxContainer.new()
	box.position = Vector2(246, 114)
	box.custom_minimum_size = Vector2(148, 0)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSED" if pauses else "MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, 20)
	var f := Art.font("Silkscreen-Regular")
	if f != null:
		title.add_theme_font_override("font", f)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#ffc850"))
	box.add_child(title)
	# Buttons: verdigris when idle, ember (with dark words) on the one you're on.
	var idle := Art.nine("swing/ui/button.png", 3)
	var hot := Art.nine("swing/ui/button_hot.png", 3)
	var ink := Color("#e8e4bc")
	var dark := Color("#19142a")
	for item in [["Resume", resume], ["Fullscreen on/off", _toggle_full], ["Back to title" if pauses else "Leave the game", _title], ["Quit game", _quit]]:
		var b := Button.new()
		b.text = str(item[0]).to_upper()
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(148, 20)
		if f != null:
			b.add_theme_font_override("font", f)
		b.add_theme_font_size_override("font_size", 8)
		if idle != null and hot != null:
			b.add_theme_stylebox_override("normal", idle)
			b.add_theme_stylebox_override("hover", hot)
			b.add_theme_stylebox_override("pressed", hot)
			b.add_theme_stylebox_override("focus", hot)
			b.add_theme_color_override("font_color", ink)
			for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(state, dark)
		b.pressed.connect(item[1])
		box.add_child(b)
		if first_button == null:
			first_button = b


func is_open() -> bool:
	return panel.visible


func open() -> void:
	panel.visible = true
	if pauses:
		get_tree().paused = true
	first_button.grab_focus()


func resume() -> void:
	panel.visible = false
	if pauses:
		get_tree().paused = false
	resumed.emit()


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
