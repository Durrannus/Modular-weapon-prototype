extends Node
## Registers every input action in code, so keyboard/mouse and controller
## bindings live in one readable place. Loaded as an autoload.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # so F11 also works while the game is paused
	_add("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _btn(JOY_BUTTON_DPAD_LEFT)])
	_add("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _btn(JOY_BUTTON_DPAD_RIGHT)])
	_add("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _btn(JOY_BUTTON_DPAD_UP)])
	_add("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _btn(JOY_BUTTON_DPAD_DOWN)])

	_add("aim_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add("aim_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add("aim_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add("aim_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])

	_add("attack", [_mouse(MOUSE_BUTTON_LEFT), _btn(JOY_BUTTON_X), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add("dash", [_key(KEY_SPACE), _key(KEY_SHIFT), _mouse(MOUSE_BUTTON_RIGHT), _btn(JOY_BUTTON_A), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add("build", [_key(KEY_TAB), _btn(JOY_BUTTON_Y)])
	_add("interact", [_key(KEY_E), _key(KEY_F), _btn(JOY_BUTTON_Y)])
	_add("toggle_spawning", [_key(KEY_P), _btn(JOY_BUTTON_START)])

	# Crafting table controls
	_add("menu_place", [_key(KEY_ENTER), _key(KEY_SPACE), _btn(JOY_BUTTON_A)])
	_add("menu_rotate", [_key(KEY_R), _btn(JOY_BUTTON_X)])
	_add("menu_prev", [_key(KEY_Q), _btn(JOY_BUTTON_LEFT_SHOULDER)])
	_add("menu_next", [_key(KEY_E), _btn(JOY_BUTTON_RIGHT_SHOULDER)])
	_add("menu_back", [_key(KEY_ESCAPE), _key(KEY_BACKSPACE), _btn(JOY_BUTTON_B)])


func _add(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.35)
	for e in events:
		InputMap.action_add_event(action, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


func _btn(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = -1
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = -1
	return e


## F11 or Alt+Enter switches between fullscreen (the default) and a window,
## on every screen: the title, the online screens and in a game.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
