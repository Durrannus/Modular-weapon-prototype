extends CanvasLayer
## The lab's screen: the game's numbers in pages, each with - and + and a box to
## type in, a search box that finds a number on any page, (in the test
## arena) a page that puts any enemy in the room, and (wherever there is a boss)
## a page that starts and ends any boss fight (version 69).
## The numbers themselves live in scripts/lab.gd.
##
## It pauses the game while it is open, like the pause menu. It is never there
## in an online game: both computers must have the same numbers.

const Art := preload("res://scripts/art.gd")
const Lab := preload("res://scripts/lab.gd")

signal closed

const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const FAINT := Color("#5f8072")
const AMBER := Color("#ffc850")
const DARK := Color("#19142a")
const SPAWN := "Spawn"
const BOSSES := "Bosses"
const BOSSES_NOTE := "Start or end any boss fight. Starting closes the lab, so the fight begins. A fight won here counts as won."
const HINT := "Hold - or + to keep going. Shift: bigger steps. Click a number to type it. Distances: the screen is 640 wide."
const FOUND_NOTE := "Every number with those words, from all the pages. Esc or a page's button goes back."
const NONE_NOTE := "No number has those words. Try one word: dagger, recharge, health."
const LABEL_W := 238.0      # room for a number's name
const WAS_W := 98.0         # room for "GAME: 0.45 SEC" beside a changed number
const LIST_W := 478.0       # the list's width, without its scroll bar
const REPEAT_AFTER := 0.4   # holding - or +: the wait before it repeats...
const REPEAT_EVERY := 0.07  # ...and how often

var is_open := false
var game = null             # the arena or the cave behind this screen
var page := "All weapons"
var dirty := false          # a number changed since the screen opened
var query := ""             # what the search box holds ("": a page is showing)

var _root: Control
var _pages: VBoxContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _note: Label
var _status: Label
var _hint: Label
var _page_buttons := {}
var _rows := {}             # id -> {name, edit, was, reset}
var _held := Callable()     # what the held button does
var _held_for := 0.0
var _said_left := 0.0
var _count_label: Label     # the Spawn page's "in the arena now" line
var _arrive_button: Button
var _boss_rows := {}        # the Bosses page: a fight's id -> {state, start, end, back}
var _closed_tick := -10     # the game tick it was last closed on
var _search: SearchBox
var _reset_page_button: Button   # "Reset this page", or "Reset these" over a search
var _close_button: Button


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("covers_version")
	Lab.setup()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.09, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var plate := Panel.new()
	plate.position = Vector2(8, 6)
	plate.size = Vector2(624, 348)
	var plate_box: StyleBox = Art.nine("swing/ui/panel.png", 8)
	if plate_box == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = DARK
		plate_box = flat
	plate.add_theme_stylebox_override("panel", plate_box)
	_root.add_child(plate)
	var title := _words("THE LAB", AMBER, 16, true)
	title.position = Vector2(18, 12)
	_root.add_child(title)
	var about := _words("Changes work at once, in the arena and the cave, and are saved.", DIM)
	about.position = Vector2(102, 15)
	_root.add_child(about)
	_search = SearchBox.new()
	_search.position = Vector2(478, 13)
	_search.size = Vector2(144, 16)
	_search.changed.connect(_searched)
	_root.add_child(_search)
	# The pages, down the left.
	_pages = VBoxContainer.new()
	_pages.position = Vector2(18, 38)
	_pages.add_theme_constant_override("separation", 2)
	_root.add_child(_pages)
	# The page's note, then its numbers.
	_note = _words("", DIM)
	_note.position = Vector2(132, 36)
	_note.size = Vector2(492, 14)
	_note.clip_text = true
	_root.add_child(_note)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(132, 53)
	_scroll.size = Vector2(492, 252)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_root.add_child(_scroll)
	var bar_back := StyleBoxFlat.new()
	bar_back.bg_color = Color("#0f0c1c")
	bar_back.content_margin_left = 3
	bar_back.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = FAINT
	var grab_hot := StyleBoxFlat.new()
	grab_hot.bg_color = AMBER
	_scroll.get_v_scroll_bar().add_theme_stylebox_override("scroll", bar_back)
	_scroll.get_v_scroll_bar().add_theme_stylebox_override("grabber", grab)
	_scroll.get_v_scroll_bar().add_theme_stylebox_override("grabber_highlight", grab_hot)
	_scroll.get_v_scroll_bar().add_theme_stylebox_override("grabber_pressed", grab_hot)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(LIST_W, 0)
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)
	# The bottom row.
	_status = _words("", DIM)
	_status.position = Vector2(18, 313)
	_status.size = Vector2(212, 14)
	_root.add_child(_status)
	var bar := HBoxContainer.new()
	bar.position = Vector2(236, 310)
	bar.add_theme_constant_override("separation", 4)
	_root.add_child(bar)
	for item in [["Reset this page", 100, _reset_page], ["Reset everything", 108, _reset_all], ["Copy my changes", 104, _copy], ["Close (L)", 64, close]]:
		var b := _button(str(item[0]), float(item[1]), 18.0)
		b.pressed.connect(item[2])
		bar.add_child(b)
		if _reset_page_button == null:
			_reset_page_button = b
		_close_button = b   # (the last one)
	_hint = _words(HINT, FAINT)
	_hint.position = Vector2(18, 332)
	_hint.size = Vector2(604, 14)
	_root.add_child(_hint)


# --- Opening and closing --------------------------------------------------------------

func open() -> void:
	if is_open:
		return
	is_open = true
	dirty = false
	_make_pages()
	if not _page_buttons.has(page):
		page = Lab.PAGES[0]
	if query != "":
		_show_found()   # (the search you left is still there)
	else:
		_show_page(page)
	_root.visible = true
	get_tree().paused = true
	# The lit button is the page that is showing. Over a search no page is, so
	# Close is lit.
	if query != "":
		_close_button.grab_focus()
	else:
		(_page_buttons[page] as Button).grab_focus()


## Closing puts the changes to work: weapons are worked out again and everyone
## alive takes their new numbers.
func close() -> void:
	if not is_open:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()   # (a number being typed is taken first)
	is_open = false
	_closed_tick = Engine.get_physics_frames()
	_held = Callable()
	_root.visible = false
	get_tree().paused = false
	if dirty and is_instance_valid(game) and game.has_method("lab_changed"):
		game.lab_changed()
	closed.emit()


## True on the tick the screen closed and the one after: the key that closed it
## must not open it again.
func just_closed() -> bool:
	return Engine.get_physics_frames() <= _closed_tick + 1


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	var key := event as InputEventKey if event is InputEventKey and event.pressed and not event.echo else null
	# "/" (or Ctrl+F) goes to the search box.
	if key != null and (key.unicode == 47 or key.keycode == KEY_SLASH or (key.keycode == KEY_F and key.ctrl_pressed)):
		_search.grab_focus()
		get_viewport().set_input_as_handled()
		return
	var esc: bool = key != null and key.keycode == KEY_ESCAPE
	# Esc over a search goes back to the page first.
	if esc and query != "":
		_pick_page(page)
		get_viewport().set_input_as_handled()
		return
	var back: bool = event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	if esc or back or event.is_action_pressed("lab"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open:
		return
	if _held.is_valid():
		_held_for += delta
		while _held_for > REPEAT_AFTER + REPEAT_EVERY:
			_held_for -= REPEAT_EVERY
			_held.call()
	if _said_left > 0.0:
		_said_left -= delta
		if _said_left <= 0.0:
			_hint.text = HINT
			_hint.add_theme_color_override("font_color", FAINT)
	if page == SPAWN:
		_refresh_spawn()
	elif page == BOSSES:
		_refresh_bosses()


# --- Pages ------------------------------------------------------------------------------

## The page buttons: the lab's pages, and Spawn where there is an arena to spawn into.
func _make_pages() -> void:
	for c in _pages.get_children():
		_pages.remove_child(c)
		c.queue_free()
	_page_buttons = {}
	var names: Array = Lab.PAGES.duplicate()
	if _can_spawn():
		names.append(SPAWN)
	if _can_boss():
		names.append(BOSSES)
	for n in names:
		var b := _button(str(n), 104.0, 17.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_pick_page.bind(str(n)))
		_pages.add_child(b)
		_page_buttons[n] = b


func _can_spawn() -> bool:
	return is_instance_valid(game) and game.has_method("spawn_enemies")


func _can_boss() -> bool:
	return is_instance_valid(game) and game.has_method("boss_fights")


## A page's button: the page, and the search is put away.
func _pick_page(which: String) -> void:
	query = ""
	_search.put_text("")
	_show_page(which)


func _empty_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows = {}
	_count_label = null
	_arrive_button = null
	_boss_rows = {}
	_scroll.scroll_vertical = 0


func _show_page(which: String) -> void:
	page = which
	_empty_list()
	if which == SPAWN:
		_note.text = "Puts enemies in the arena, near you. Close the lab to fight them."
		_make_spawn_page()
	elif which == BOSSES:
		_note.text = BOSSES_NOTE
		_make_boss_page()
	else:
		_note.text = str(Lab.PAGE_NOTES.get(which, ""))
		var group := ""
		for row in Lab.rows:
			if row["page"] != which:
				continue
			if row["group"] != group:
				group = row["group"]
				_list.add_child(_heading(group, _list.get_child_count() > 0))
			_list.add_child(_make_row(row))
	_refresh_status()


# --- The search -------------------------------------------------------------------------

## The search box changed: its numbers from every page, or (emptied) the page again.
func _searched(text: String) -> void:
	query = text.strip_edges()
	if query == "":
		_show_page(page)
	else:
		_show_found()


## Every number the search finds, each lot under "PAGE > GROUP".
func _show_found() -> void:
	_empty_list()
	var found := Lab.find(query)
	_note.text = NONE_NOTE if found.is_empty() else FOUND_NOTE
	var under := ""
	for row in found:
		var head := "%s > %s" % [row["page"], row["group"]]
		if head != under:
			under = head
			_list.add_child(_heading(head, _list.get_child_count() > 0))
		_list.add_child(_make_row(row))
	_refresh_status()


## The page you are on is marked, and a page with changed numbers says how many.
func _refresh_status() -> void:
	_reset_page_button.text = "RESET THIS PAGE" if query == "" else "RESET THESE"
	for n in _page_buttons:
		var b: Button = _page_buttons[n]
		var changed := Lab.changed_on(str(n)) if not n in [SPAWN, BOSSES] else 0
		b.text = ("%s (%d)" % [n, changed] if changed > 0 else str(n)).to_upper()
		b.add_theme_color_override("font_color", AMBER if n == page and query == "" else (INK if changed == 0 else Color("#86d4a4")))
	var total := Lab.changed_count()
	_status.text = "Every number is the game's own." if total == 0 else ("1 number changed." if total == 1 else "%d numbers changed." % total)
	_status.add_theme_color_override("font_color", DIM if total == 0 else AMBER)


# --- A number's row -----------------------------------------------------------------------

func _make_row(row: Dictionary) -> Control:
	var id: String = row["id"]
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var name_label := _words(str(row["label"]), INK)
	name_label.custom_minimum_size = Vector2(LABEL_W, 16)
	name_label.clip_text = true
	box.add_child(name_label)
	var less := _button("-", 16.0, 16.0)
	less.button_down.connect(_hold.bind(_nudge.bind(id, -1)))
	less.button_up.connect(_let_go)
	box.add_child(less)
	var edit := NumberBox.new()
	edit.custom_minimum_size = Vector2(58, 16)
	edit.typed.connect(_typed.bind(id))
	box.add_child(edit)
	var more := _button("+", 16.0, 16.0)
	more.button_down.connect(_hold.bind(_nudge.bind(id, 1)))
	more.button_up.connect(_let_go)
	box.add_child(more)
	var was := _words("", DIM)
	was.custom_minimum_size = Vector2(WAS_W, 16)
	was.clip_text = true
	box.add_child(was)
	var reset := _button("Reset", 38.0, 16.0)
	reset.pressed.connect(_reset.bind(id))
	box.add_child(reset)
	_rows[id] = {"name": name_label, "edit": edit, "was": was, "reset": reset}
	_refresh_row(id)
	return box


func _refresh_row(id: String) -> void:
	if not _rows.has(id):
		return
	var r: Dictionary = _rows[id]
	var changed := Lab.is_changed(id)
	(r["edit"] as NumberBox).show_number(Lab.words(id, Lab.value(id)), AMBER if changed else INK)
	(r["name"] as Label).add_theme_color_override("font_color", AMBER if changed else INK)
	(r["was"] as Label).text = "game: %s" % Lab.words(id, float(Lab.defaults[id])) if changed else ""
	(r["reset"] as Button).visible = changed


func _nudge(id: String, way: int) -> void:
	Lab.nudge(id, way, Input.is_key_pressed(KEY_SHIFT))
	_changed(id)


## A number was typed in the box (Enter, or a click somewhere else). Something
## that isn't a number just puts the old one back.
func _typed(text: String, id: String) -> void:
	if not _rows.has(id):
		return
	var v := Lab.typed(id, text)
	if is_nan(v) or is_equal_approx(v, Lab.value(id)):
		_refresh_row(id)
		return
	Lab.set_value(id, v)
	_changed(id)


func _reset(id: String) -> void:
	Lab.reset(id)
	_changed(id)
	# (Its Reset button has just gone: keep the place for a controller.)
	if _rows.has(id) and get_viewport().gui_get_focus_owner() == null:
		((_rows[id]["edit"] as Control).get_parent().get_child(3) as Button).grab_focus()


func _changed(id: String) -> void:
	dirty = true
	_refresh_row(id)
	_refresh_status()


func _hold(what: Callable) -> void:
	what.call()
	_held = what
	_held_for = 0.0


func _let_go() -> void:
	_held = Callable()


## Over a search it resets the numbers the search is showing.
func _reset_page() -> void:
	if query != "":
		Lab.reset_these(_rows.keys())
	elif page == SPAWN or page == BOSSES:
		return
	else:
		Lab.reset_page(page)
	dirty = true
	for id in _rows:
		_refresh_row(id)
	_refresh_status()


func _reset_all() -> void:
	Lab.reset_all()
	dirty = true
	for id in _rows:
		_refresh_row(id)
	_refresh_status()


## Puts every change on the clipboard as plain lines, to paste into a message.
func _copy() -> void:
	DisplayServer.clipboard_set(Lab.summary())
	_say("Copied. Paste it to Claude to make these the game's own numbers." if Lab.changed_count() > 0 else "Nothing is changed yet, so there is nothing to copy.")


func _say(text: String) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", AMBER)
	_said_left = 4.0


# --- The Spawn page (the test arena) ------------------------------------------------------

func _make_spawn_page() -> void:
	_list.add_child(_heading("Put in the arena", false))
	for entry in game.SPAWNABLE:
		var kind := str(entry[0])
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		var name_label := _words(str(entry[1]), INK)
		name_label.custom_minimum_size = Vector2(150, 16)
		box.add_child(name_label)
		var about := _words(str(entry[2]), DIM)
		about.custom_minimum_size = Vector2(216, 16)
		about.clip_text = true
		box.add_child(about)
		for n in ([1] if kind in ["guardian", "dummy"] else [1, 5]):
			var b := _button("+%d" % n, 30.0, 16.0)
			b.pressed.connect(_spawn.bind(kind, n))
			box.add_child(b)
		_list.add_child(box)
	_list.add_child(_heading("The room", true))
	_count_label = _words("", INK)
	_count_label.custom_minimum_size = Vector2(0, 16)
	_list.add_child(_count_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var clear := _button("Remove every enemy", 130.0, 18.0)
	clear.pressed.connect(func(): game.clear_enemies())
	row.add_child(clear)
	_arrive_button = _button("", 230.0, 18.0)
	_arrive_button.pressed.connect(func(): game.spawning = not game.spawning)
	row.add_child(_arrive_button)
	_list.add_child(row)
	var tip := _words("Pause enemies (P) holds them still while you look. Invincible (H) decides whether they can hurt you.", DIM)
	tip.custom_minimum_size = Vector2(LIST_W, 30)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(tip)
	_refresh_spawn()


func _spawn(kind: String, count: int) -> void:
	game.spawn_enemies(kind, count)
	_refresh_spawn()


func _refresh_spawn() -> void:
	if _count_label == null or not _can_spawn():
		return
	var n: int = game.enemy_total()
	_count_label.text = "In the arena now: %s." % ("no enemies" if n == 0 else ("1 enemy" if n == 1 else "%d enemies" % n))
	_arrive_button.text = ("NEW ENEMIES ARRIVE BY THEMSELVES: %s" % ("ON" if game.spawning else "OFF"))


# --- The Bosses page (version 69) ----------------------------------------------------------
# Darren, 28 November 2026: "give the lab the ability to start and end the boss fight whenever, to all boss fights in
# future too." Any game with a boss answers boss_fights() with its fights ({id, name, about, state, can_start,
# can_end, can_back}), and start_boss(id), end_boss(id) and back_boss(id) do the rest: a new boss needs only an entry
# in its game's list, and this page shows it.

func _make_boss_page() -> void:
	var fights: Array = game.boss_fights()
	if fights.is_empty():
		var none := _words("There is no boss here.", DIM)
		none.custom_minimum_size = Vector2(LIST_W, 16)
		_list.add_child(none)
		return
	for f in fights:
		var id := str(f["id"])
		_list.add_child(_heading(str(f["name"]), _list.get_child_count() > 0))
		var about := _words(str(f.get("about", "")), DIM)
		about.custom_minimum_size = Vector2(LIST_W, 0)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(about)
		var state := _words("", INK)
		state.custom_minimum_size = Vector2(LIST_W, 16)
		state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(state)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var start := _button("Start the fight", 120.0, 18.0)
		start.pressed.connect(_start_boss.bind(id))
		row.add_child(start)
		var end := _button("End the fight", 120.0, 18.0)
		end.pressed.connect(_end_boss.bind(id))
		row.add_child(end)
		var back: Button = null
		if game.has_method("back_boss"):
			back = _button("Take everybody back", 150.0, 18.0)
			back.pressed.connect(_back_boss.bind(id))
			row.add_child(back)
		_list.add_child(row)
		_boss_rows[id] = {"state": state, "start": start, "end": end, "back": back}
	_refresh_bosses()


func _refresh_bosses() -> void:
	if _boss_rows.is_empty() or not _can_boss():
		return
	for f in game.boss_fights():
		var r: Dictionary = _boss_rows.get(str(f["id"]), {})
		if r.is_empty():
			continue
		(r["state"] as Label).text = "Now: " + str(f["state"])
		(r["start"] as Button).disabled = not bool(f.get("can_start", false))
		(r["end"] as Button).disabled = not bool(f.get("can_end", false))
		if r["back"] != null:
			(r["back"] as Button).visible = bool(f.get("can_back", false))


func _start_boss(id: String) -> void:
	var why: String = game.start_boss(id)
	if why != "":
		_say(why)
		_refresh_bosses()
		return
	close()


func _end_boss(id: String) -> void:
	_say(str(game.end_boss(id)))
	_refresh_bosses()


func _back_boss(id: String) -> void:
	_say(str(game.back_boss(id)))
	_refresh_bosses()


# --- The kit --------------------------------------------------------------------------------

func _words(text: String, color: Color, size := Art.TEXT_SIZE, heading := false) -> Label:
	var l := Label.new()
	l.text = text
	var f := Art.font("Silkscreen-Regular" if heading else Art.TEXT)
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _heading(text: String, gap: bool) -> Control:
	var l := _words(text.to_upper(), AMBER, 8, true)
	l.custom_minimum_size = Vector2(0, 18 if gap else 12)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


## A button from the menu kit: verdigris when idle, ember (with dark words) on the
## one you're on.
func _button(text: String, w: float, h: float) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(w, h)
	b.clip_text = true
	var f := Art.font("Silkscreen-Regular")
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 8)
	var idle := Art.nine("swing/ui/button.png", 3)
	var hot := Art.nine("swing/ui/button_hot.png", 3)
	if idle != null and hot != null:
		b.add_theme_stylebox_override("normal", idle)
		b.add_theme_stylebox_override("hover", hot)
		b.add_theme_stylebox_override("pressed", hot)
		b.add_theme_stylebox_override("focus", hot)
		b.add_theme_stylebox_override("disabled", idle)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_disabled_color", FAINT)
		for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, DARK)
	return b


## The box a number sits in. Click it and type a new one: Enter (or a click
## somewhere else) takes it, Esc leaves the old one. The first key replaces the
## number that was there.
class NumberBox extends Control:
	signal typed(text)

	const Art := preload("res://scripts/art.gd")
	var shown := ""
	var color := Color("#e8e4bc")
	var typing := false
	var fresh := false          # nothing typed yet: the old number still shows
	var buffer := ""
	var blink := 0.0

	func _ready() -> void:
		focus_mode = Control.FOCUS_CLICK
		mouse_default_cursor_shape = Control.CURSOR_IBEAM
		focus_exited.connect(finish)

	func show_number(text: String, tint: Color) -> void:
		shown = text
		color = tint
		queue_redraw()

	func begin() -> void:
		typing = true
		fresh = true
		buffer = ""
		blink = 0.0
		queue_redraw()

	## Stops typing and hands over what was typed (nothing typed: nothing changes).
	func finish() -> void:
		if not typing:
			return
		typing = false
		queue_redraw()
		if not fresh and buffer != "":
			typed.emit(buffer)

	func cancel() -> void:
		typing = false
		queue_redraw()

	func put(text: String) -> void:
		if fresh:
			buffer = ""
			fresh = false
		if buffer.length() < 8:
			buffer += text
		queue_redraw()

	func _process(delta: float) -> void:
		if typing:
			blink += delta
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			begin()
			accept_event()
			return
		if not typing or not (event is InputEventKey) or not event.pressed:
			return
		var k := event as InputEventKey
		match k.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				finish()
				release_focus()
			KEY_ESCAPE:
				cancel()
				release_focus()
			KEY_BACKSPACE, KEY_DELETE:
				buffer = "" if fresh else buffer.left(-1)
				fresh = false
				queue_redraw()
			_:
				var ch := char(k.unicode) if k.unicode > 0 else ""
				if ch in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", ","]:
					put("." if ch == "," else ch)
		accept_event()   # (so a letter typed here never reaches the game or closes the lab)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0f0c1c"))
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Color("#ffc850") if typing else Color("#5f8072"), false, 1.0)
		var f := Art.font(Art.TEXT)
		if f == null:
			return
		var text := shown
		var tint := color
		if typing and not fresh:
			text = buffer + ("_" if fmod(blink, 0.8) < 0.5 else " ")
			tint = Color("#ffc850")
		elif typing:
			tint = Color("#8ba688")
		draw_string(f, Vector2(0, size.y * 0.5 + 4.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, Art.TEXT_SIZE, tint)


## The search box. Click it (or press "/") and type: every key changes what the
## list shows. Esc empties it, and Esc again leaves it; Enter leaves it with the
## search still showing.
class SearchBox extends Control:
	signal changed(text)

	const Art := preload("res://scripts/art.gd")
	const EMPTY := "SEARCH EVERY PAGE ( / )"
	const LONGEST := 28
	var text := ""
	var blink := 0.0

	func _ready() -> void:
		focus_mode = Control.FOCUS_CLICK
		mouse_default_cursor_shape = Control.CURSOR_IBEAM
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	## Sets what it holds without telling anyone (the screen put the search away).
	func put_text(to: String) -> void:
		text = to
		queue_redraw()

	func _take(to: String) -> void:
		if to == text:
			return
		text = to
		blink = 0.0
		queue_redraw()
		changed.emit(text)

	func _process(delta: float) -> void:
		if has_focus():
			blink += delta
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			accept_event()
			return
		if not has_focus() or not (event is InputEventKey) or not event.pressed:
			return
		var k := event as InputEventKey
		match k.keycode:
			KEY_TAB, KEY_UP, KEY_DOWN:
				return   # (these walk on to the buttons)
			KEY_ENTER, KEY_KP_ENTER:
				release_focus()
			KEY_ESCAPE:
				if text == "":
					release_focus()
				else:
					_take("")
			KEY_BACKSPACE, KEY_DELETE:
				_take(text.left(-1))
			_:
				if k.unicode >= 32 and k.unicode != 127 and text.length() < LONGEST and not (k.unicode == 32 and text == "") and not k.ctrl_pressed:
					_take(text + char(k.unicode))
		accept_event()   # (so a letter typed here never reaches the game: L would close the lab)

	func _draw() -> void:
		var on := has_focus()
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0f0c1c"))
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Color("#ffc850") if on else Color("#5f8072"), false, 1.0)
		var f := Art.font("Silkscreen-Regular")
		if f == null:
			return
		var room := size.x - 10.0
		var shown := text.to_upper()
		var tint := Color("#ffc850") if on else Color("#e8e4bc")
		if text == "" and not on:
			shown = EMPTY
			tint = Color("#5f8072")
		# A search longer than the box shows its end.
		while shown.length() > 1 and f.get_string_size(shown + "_", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > room:
			shown = shown.substr(1)
		if on:
			shown += "_" if fmod(blink, 0.8) < 0.5 else ""
		draw_string(f, Vector2(5, size.y * 0.5 + 3.0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, tint)
