extends RefCounted
## One player's controls, read once per physics tick.
##
## kind:
##   "any"    one player on their own: keyboard, mouse and every controller
##   "kbm"    keyboard and mouse only (two players: the other one has a controller)
##   "pad"    one controller (device)
##   "script" nothing is read; tests set the fields themselves
##
## Presses are latched: attack_pressed is true for exactly one poll() per press,
## however short the press was, so a quick tap is never lost and never doubled.

var kind := "any"
var device := 0            # controller id for "pad"
var using_pad := false     # what this player touched last (aim source and button prompts)

var move := Vector2.ZERO
var stick_aim := Vector2.ZERO
var attack_held := false
var attack_pressed := false
var dash_pressed := false
var interact_pressed := false
var pause_pressed := false

var _was := {"attack": false, "dash": false, "interact": false, "pause": false}
var _latched := {"attack": false, "dash": false, "interact": false, "pause": false}

const STICK_DEAD := 0.25
const TRIGGER_ON := 0.4


static func make(kind_: String, device_ := 0) -> RefCounted:
	var p = new()
	p.kind = kind_
	p.device = device_
	p.using_pad = kind_ == "pad"
	return p


## A short name for menus: "Keyboard + mouse", "Controller 1".
func label() -> String:
	match kind:
		"kbm": return "Keyboard + mouse"
		"pad": return "Controller %d" % (device + 1)
		"script": return "Script"
	return "Keyboard, mouse or controller"


func uses_mouse() -> bool:
	return kind == "kbm" or (kind == "any" and not using_pad)


## True if this event came from one of this player's devices.
func owns(event: InputEvent) -> bool:
	match kind:
		"any":
			return true
		"kbm":
			return event is InputEventKey or event is InputEventMouse
		"pad":
			return (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device == device
	return false


## Call from _input: notes which device is in use and latches button taps that
## could be shorter than one physics tick.
func feed(event: InputEvent) -> void:
	if kind == "script" or not owns(event):
		return
	if kind == "any":
		if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
			using_pad = false
		elif event is InputEventJoypadButton:
			using_pad = true
		elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4:
			using_pad = true
	if event is InputEventJoypadMotion or event.is_echo() or not event.is_pressed():
		return
	for name in _latched:
		if _event_is(event, name):
			_latched[name] = true


func _event_is(event: InputEvent, name: String) -> bool:
	if event is InputEventMouseButton:
		var b := (event as InputEventMouseButton).button_index
		return (name == "attack" and b == MOUSE_BUTTON_LEFT) or (name == "dash" and b == MOUSE_BUTTON_RIGHT)
	if event is InputEventKey:
		var k := (event as InputEventKey).physical_keycode
		match name:
			"dash": return k == KEY_SPACE or k == KEY_SHIFT
			"interact": return k == KEY_E or k == KEY_F
		return false
	if event is InputEventJoypadButton:
		var j := (event as InputEventJoypadButton).button_index
		match name:
			"attack": return j == JOY_BUTTON_X
			"dash": return j == JOY_BUTTON_A
			"interact": return j == JOY_BUTTON_Y
			"pause": return j == JOY_BUTTON_START
	return false


func _held(name: String) -> bool:
	match kind:
		"any":
			if name == "pause":
				return false
			return Input.is_action_pressed(name)
		"kbm":
			match name:
				"attack": return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
				"dash": return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
				"interact": return Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_F)
		"pad":
			match name:
				"attack": return Input.is_joy_button_pressed(device, JOY_BUTTON_X) or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_ON
				"dash": return Input.is_joy_button_pressed(device, JOY_BUTTON_A) or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > TRIGGER_ON
				"interact": return Input.is_joy_button_pressed(device, JOY_BUTTON_Y)
				"pause": return Input.is_joy_button_pressed(device, JOY_BUTTON_START)
	return false


func _pad_stick(x_axis: JoyAxis, y_axis: JoyAxis) -> Vector2:
	var v := Vector2(Input.get_joy_axis(device, x_axis), Input.get_joy_axis(device, y_axis))
	var l := v.length()
	if l < STICK_DEAD:
		return Vector2.ZERO
	return v / l * minf((l - STICK_DEAD) / (1.0 - STICK_DEAD), 1.0)


## Read everything for this tick.
func poll() -> void:
	if kind == "script":
		return
	match kind:
		"any":
			move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			stick_aim = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		"kbm":
			var v := Vector2.ZERO
			if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): v.x -= 1.0
			if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): v.x += 1.0
			if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): v.y -= 1.0
			if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): v.y += 1.0
			move = v.normalized()
			stick_aim = Vector2.ZERO
		"pad":
			var v := _pad_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT): v.x -= 1.0
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT): v.x += 1.0
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP): v.y -= 1.0
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN): v.y += 1.0
			move = v.limit_length(1.0)
			stick_aim = _pad_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	var pressed := {}
	for name in _was:
		var now := _held(name)
		pressed[name] = (now and not _was[name]) or _latched[name]
		_was[name] = now
		_latched[name] = false
	attack_held = _was["attack"]
	attack_pressed = pressed["attack"]
	dash_pressed = pressed["dash"]
	interact_pressed = pressed["interact"]
	pause_pressed = pressed["pause"]


## Forget anything held or latched (after a menu closes, so its last click doesn't swing).
func clear() -> void:
	for name in _was:
		_was[name] = _held(name) if kind != "script" else false
		_latched[name] = false
	attack_pressed = false
	dash_pressed = false
	interact_pressed = false
	pause_pressed = false
