extends CanvasLayer
## The "Play online" screen. One player hosts and reads out their address; the
## other types it in and joins. When both are connected the host picks what to
## play. The work is done by the session (scripts/net/session.gd); this screen
## only shows what it says and passes on the button presses.

signal back   # leave for the title screen

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")

const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const AMBER := Color("#ffc850")
const BAD := Color("#f06a40")
const PLATE := Color("#19142a")
const SAVED := "user://online.cfg"
const WIDTH := 384.0

var session            # the online session, made by boot.gd before this is shown
var view := ""         # "choose", "host" or "join"
var root: Control
var box: VBoxContainer
var info: Label        # the long text in the middle
var status: Label      # what the session says is going on
var problem: Label     # the last thing that went wrong
var address_box: LineEdit
var start_buttons: Array = []
var copy_button: Button
var join_button: Button
var silk: Font
var pix: Font


func _ready() -> void:
	layer = 20
	silk = Art.font("Silkscreen-Regular")
	pix = Art.font("PixelifySans-Regular")
	Input.set_custom_mouse_cursor(null)
	root = Control.new()
	root.size = Vector2(640, 360)
	add_child(root)
	var backdrop := Art.texture("swing/ui/title_backdrop.png")
	if backdrop != null:
		var pic := TextureRect.new()
		pic.texture = backdrop
		root.add_child(pic)
	else:
		var fill := ColorRect.new()
		fill.color = PLATE
		fill.size = root.size
		root.add_child(fill)
	var plate := Panel.new()
	plate.position = Vector2(112, 22)
	plate.size = Vector2(416, 318)
	var plate_box: StyleBox = Art.nine("swing/ui/panel.png", 8)
	if plate_box == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = PLATE
		plate_box = flat
	plate.add_theme_stylebox_override("panel", plate_box)
	root.add_child(plate)
	box = VBoxContainer.new()
	box.position = Vector2(128, 34)
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)
	session.lobby_changed.connect(_refresh)
	# Coming back from a game that just ended, the two computers are still connected.
	if session.peer != null:
		_show("host" if session.hosting else "join")
	else:
		_show("choose")


# --- Building each view ---------------------------------------------------------------

func _show(v: String) -> void:
	view = v
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	start_buttons = []
	copy_button = null
	join_button = null
	address_box = null
	_heading({"choose": "PLAY ONLINE", "host": "HOSTING A GAME", "join": "JOINING A GAME"}[v])
	info = _text("", INK)
	var first: Control = null
	match v:
		"choose":
			info.text = "Two players, one on each computer.\n\nOne of you hosts and tells the other the address the game shows. The other joins with that address.\n\nYou both need exactly the same copy of the game."
			first = _button("Host a game", _host)
			_button("Join a game", func(): _show("join"))
			_button("Back", func(): back.emit())
		"host":
			status = _text("", AMBER)
			start_buttons = [_button("Start: Tutorial cave", func(): session.start("cave")), _button("Start: Test arena", func(): session.start("arena"))]
			copy_button = _button("Copy the address", _copy)
			_button("Stop hosting", _stop)
			first = copy_button
		"join":
			info.text = "Type the address on your friend's screen, then press Join."
			address_box = LineEdit.new()
			address_box.placeholder_text = "for example 81.2.69.160"
			address_box.text = _saved_address()
			address_box.max_length = 80
			address_box.custom_minimum_size = Vector2(WIDTH, 22)
			_style_field(address_box)
			address_box.text_submitted.connect(func(_t): _join())
			box.add_child(address_box)
			join_button = _button("Join", _join)
			status = _text("", AMBER)
			_button("Back", _stop)
			first = address_box
	problem = _text("", BAD)
	_refresh()
	if first != null:
		first.grab_focus.call_deferred()


func _heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(WIDTH, 22)
	if silk != null:
		l.add_theme_font_override("font", silk)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", AMBER)
	box.add_child(l)


func _text(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH, 0)
	if pix != null:
		l.add_theme_font_override("font", pix)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_constant_override("line_spacing", 0)
	l.add_theme_color_override("font_color", col)
	box.add_child(l)
	return l


## The same look as the pause menu's buttons.
func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(WIDTH, 20)
	if silk != null:
		b.add_theme_font_override("font", silk)
	b.add_theme_font_size_override("font_size", 8)
	var idle := Art.nine("swing/ui/button.png", 3)
	var hot := Art.nine("swing/ui/button_hot.png", 3)
	if idle != null and hot != null:
		b.add_theme_stylebox_override("normal", idle)
		b.add_theme_stylebox_override("disabled", idle)
		b.add_theme_stylebox_override("hover", hot)
		b.add_theme_stylebox_override("pressed", hot)
		b.add_theme_stylebox_override("focus", hot)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_disabled_color", Color("#5f8072"))
		for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, PLATE)
	b.pressed.connect(func():
		Sfx.play(self, "click", -10.0)
		pressed.call())
	box.add_child(b)
	return b


func _style_field(field: LineEdit) -> void:
	if pix != null:
		field.add_theme_font_override("font", pix)
	field.add_theme_font_size_override("font_size", 11)
	field.add_theme_color_override("font_color", INK)
	field.add_theme_color_override("font_placeholder_color", Color("#5f8072"))
	field.add_theme_color_override("caret_color", AMBER)
	var well := Art.nine("swing/ui/well.png", 3)
	var lit := Art.nine("swing/ui/well_selected.png", 3)
	if well != null and lit != null:
		for sb in [well, lit]:
			sb.content_margin_left = 6
			sb.content_margin_right = 6
			sb.content_margin_top = 3
			sb.content_margin_bottom = 3
		field.add_theme_stylebox_override("normal", well)
		field.add_theme_stylebox_override("focus", lit)


# --- What the buttons do ----------------------------------------------------------------

func _host() -> void:
	if session.host():
		_show("host")
	else:
		_refresh()


func _join() -> void:
	if address_box == null or session.linked:
		return
	var address := address_box.text.strip_edges()
	if session.join(address):
		var cfg := ConfigFile.new()
		cfg.set_value("online", "address", address)
		cfg.save(SAVED)
	_refresh()


## Stop hosting or joining and go back to the first view.
func _stop() -> void:
	session.close()
	_show("choose")


func _saved_address() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVED) == OK:
		return str(cfg.get_value("online", "address", ""))
	return ""


## The address a friend should type: the internet one if the router opened up,
## otherwise this computer's address on the home network or a VPN.
func _best_address() -> String:
	var a: Dictionary = session.addresses()
	if a["internet"] != "":
		return a["internet"]
	# A VPN address reaches further than a home network one, so offer it first.
	for ip in a["local"]:
		if session.describe(ip) in ["Tailscale", "Radmin VPN", "Hamachi"]:
			return ip
	return a["local"][0] if not a["local"].is_empty() else ""


func _copy() -> void:
	var address := _best_address()
	if address != "":
		DisplayServer.clipboard_set(address)
		copy_button.text = "COPIED: " + address


# --- Showing what the session says --------------------------------------------------------

func _refresh() -> void:
	if not is_instance_valid(session) or info == null:
		return
	problem.text = session.error
	problem.visible = session.error != ""
	match view:
		"host":
			info.text = _host_text()
			for b in start_buttons:
				(b as Button).disabled = not session.linked
			status.text = session.status + _ping_text()
			# Once a friend is in, the start buttons are what you want next.
			if session.linked and copy_button != null and copy_button.has_focus():
				(start_buttons[0] as Button).grab_focus.call_deferred()
		"join":
			status.text = session.status + _ping_text()
			var busy: bool = session.peer != null
			address_box.editable = not busy
			join_button.disabled = busy


func _ping_text() -> String:
	if session.linked and session.ping_ms >= 0.0:
		return "  (ping %d ms)" % roundi(session.ping_ms)
	return ""


func _host_text() -> String:
	var a: Dictionary = session.addresses()
	var home: Array = []
	for ip in a["local"]:
		home.append("%s (%s)" % [ip, session.describe(ip)])
	var home_line := ", ".join(home) if not home.is_empty() else "none found"
	match str(a["router"]):
		"asking":
			return "Asking your router to let your friend in...\n\nOn the same Wi-Fi or a VPN, your friend can already use:\n%s" % home_line
		"open":
			return "Your friend should join this address:\n\n        %s\n\nOn the same Wi-Fi or a VPN they can use instead:\n%s" % [a["internet"], home_line]
		"shared":
			return "Your internet provider shares one address between several homes, so a friend can't reach this computer directly. Use a free VPN app (see \"If your friend can't connect\" in the README), then give them the address it shows here:\n%s" % home_line
	return "Your router didn't open the way in by itself. See \"If your friend can't connect\" in the README: it takes a few minutes to sort out.\n\nOn the same Wi-Fi or a VPN, your friend can use:\n%s" % home_line


## Esc or B steps back.
func _unhandled_input(event: InputEvent) -> void:
	var esc: bool = event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE
	var b: bool = event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	if esc or b:
		get_viewport().set_input_as_handled()
		if view == "choose":
			back.emit()
		else:
			_stop()
