extends CanvasLayer
## The forge for the swing path. Drawn at the 640x360 base size.
## Top left: the BACK button (the way out, with the key that does the same) and
## the screen's name.
## Left: the parts tray (the weapon's own parts; runes in a passive and an active
## group; threads and the rare rule-benders), then a plate with the name and one
## plain sentence for the part under the cursor.
## Then the weapon, upright over the anvil, with nothing fitted on it: since the
## forge spirit (Darren, 16 and 17 November) the runes are the spirit's.
## Centre: the spirit in its niche with ONE ring of seats round it, a seat for
## every socket the fitted parts give and never one more. The seats are the
## menu. They are read from the start mark on the left: along the bottom, up the
## right and back along the top (grip seats first, then the head's), and a
## thread's line runs along the ring to the seat after it. Under the ring: how
## to use the screen.
## Right: the three loadout presets (A, B and C: whole saved weapons, one click
## to switch), what the weapon does, a row per rune, and the weapon's numbers on
## a plate of their own. Pointing at a part you could fit shows what it would
## change beside each number.
## Nothing on this screen may overlap (Game Bible, 11 November): every kind of
## words has its own plate, and the words are made to fit it.
## Free to swap. Pauses the game while open.

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const SwordArt := preload("res://scripts/weapon/sword_art.gd")
const BowArt := preload("res://scripts/weapon/bow_art.gd")
const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")

signal try_at_dummy
signal closed

## Which parts show in the tray. null = everything (the test arena). In the cave
## it's the list of part ids this player owns.
var owned = null
var hotkey := true         # Tab / Y opens it anywhere (the test arena)
var sandbox := true        # test swords (1, 2, 3, 4) and "try at the dummy" (T)
var keys: Array = SwingBuild.ABILITY_KEYS["kbm"]   # what this player's ability buttons are called
var whose := ""            # "Player 2" when two players share the forge
var pauses := true         # false online: the game can't stop for one player's forge

const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const FAINT := Color("#5f8072")
const AMBER := Color("#ffc850")
const TEAL := Color("#86d4a4")
const FOCUS := Color("#fff0b4")
const PLATE := Color("#19142a")
const WELL := Color("#0f0b18")

const TABS := ["sword", "runes", "threads"]
const BACK_AT := Vector2(6, 9)              # the BACK button; the screen's name follows it on the same row
const BACK_H := 18.0
const TRAY := Rect2(6, 30, 158, 229)        # tabs and part cards
const INFO := Rect2(6, 262, 158, 92)        # the part under the cursor: its name and one sentence
const HELP := Rect2(264, 294, 184, 42)      # how to use the screen, at the foot of the spirit's niche (clear of the anvil)
const PRESETS := Rect2(464, 8, 170, 23)     # loadout presets A, B and C, and the chosen one's name
const RIGHT := Rect2(464, 34, 170, 320)     # "what it does" over the weapon's numbers (see does_rect, stats_rect)
const STAT_HEAD := 22.0                     # the numbers' plate: its title, then a line for each number
const STAT_LINE := 11.0
const STAT_FOOT := 6.0
const PREVIEW := Rect2(260, 91, 184, 150)   # the picture shown while Alt is held (over the spirit, inside the niche)
const GAIN := Color("#86d4a4")              # compare: this number would go up
const LOSS := Color("#ff6a4a")              # compare: it would go down
const SWORD_TOP := 4.0
const SWORD_SLACK := 7.0     # what a sword too tall for that may borrow (4 above, 3 below)
const CENTRE_X := 214.0      # the weapon stands here, between the tray and the niche
const SWORD_BOTTOM := 326.0  # the pommel sits just above the anvil
var sword_bottom := SWORD_BOTTOM

# The spirit's ring (art/spirit/spirit.json has the art's numbers).
const RING_AT := Vector2(352, 166)   # the spirit's ember, the middle of the niche
const RING_R := 88.0                 # from the ember to the middle of each seat
const SEAT := 32.0                   # a seat's picture
const ARC_R := 102.0                 # the arc behind the seats' outer edge that says which part gives them
const ARC_PAD := 12.0                # degrees an arc runs on past its first and last seat
const START_GAP := 24.0              # degrees the ring's line is open at the start mark
const THREAD_SHORT := 19.0           # a thread's line stops this far from the middle of a seat
const ARROW_IN := 11.0               # the little arrows sit this far inside the ring
const SPOKE_FROM := 52.0             # the dotted spoke from the spirit to each seat
const SPOKE_TO := RING_R - THREAD_SHORT
const RING_HALF := 116               # the ring's picture reaches this far each way from the ember
const RING_LINE := Color("#1a5654")
const ARC_LINE := Color("#12383e")
const THREAD_HOT := Color("#ffec98")     # a thread that is changing a rune: its centre line
const THREAD_WARM := Color("#ffc850")    # ... and the rest of its pattern
const THREAD_IDLE_HOT := Color("#2a7f70")    # a thread with no rune after it
const THREAD_IDLE := Color("#1a5654")
const LIT_TIME := 0.35               # seconds the spirit stays lit when something is fitted

var build: SwingBuild
var root: Control
var is_open := false
var selected := 0          # slot index, 0 = bottom of the grip
var tab := 1               # runes
var card := 0              # keyboard cursor in the tray
var hover := ""
var keys_on_cards := false # the tray cursor was last moved with keys or a pad, not the mouse
var buttons := {}          # key -> Rect2, rebuilt every draw
var renaming := false      # typing a name for the chosen preset
var rename_text := ""
var _rename_guard := 0     # frames to ignore keys after typing ends (Enter and Esc mean other things too)
var note := ""             # a line the help plate shows for a few seconds
var note_until := -9.0
var _styles := {}

# Forge feel: heat, embers, sparks, the hammer strike and the finish.
var t := 0.0
var heat := 0.3            # 0..1, jumps to 1 on a hammer strike, cools back down
var strike_t := 9.0        # time since the last hammer strike
var strike_at := Vector2.ZERO
var embers: Array = []     # [pos, vel, life, max_life]
var sparks: Array = []
var steam: Array = []
var dirty := false         # changed since the forge opened
var finishing := -1.0      # >= 0 while the "forged" finish plays
const FINISH_TIME := 1.75
var playing: Array = []   # forge fx strips: [name, pos, start time, normal-blend?]
var sword_top := Vector2.ZERO
var zoom := 2.0
var drag_id := ""          # the fitting being dragged ("" = none)
var drag_from := -1        # the slot it came from, or -1 from the tray
var drag_key := ""         # the button the press started on
var drag_start := Vector2.ZERO
var dragging := false      # true once the mouse has moved far enough            # the sword is drawn this many times its forge size
var sword_size := Vector2.ZERO
var heat_mask: Control     # draws the sword; its child is clipped to the sword's pixels
var heat_fill: Control
var fx_top: Control
var banner: Control
var preview: Control


func _ready() -> void:
	layer = 10
	add_to_group("covers_version")   # its plates fill the corner the version number sits in
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.size = Vector2(640, 360)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)
	root.draw.connect(_draw_forge)
	# Heat on the sword itself: a mask that draws the sword, with an additive
	# fill clipped to it (glowing metal, the shine sweep when it's done).
	heat_mask = Control.new()
	heat_mask.size = root.size
	heat_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	heat_mask.draw.connect(_draw_heat_mask)
	root.add_child(heat_mask)
	heat_fill = Control.new()
	heat_fill.size = root.size
	heat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_fill.material = _additive()
	heat_fill.draw.connect(_draw_heat_fill)
	heat_mask.add_child(heat_fill)
	# Embers, sparks and flashes on top, glowing.
	fx_top = Control.new()
	fx_top.size = root.size
	fx_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_top.material = _additive()
	fx_top.draw.connect(_draw_fx)
	root.add_child(fx_top)
	banner = Control.new()
	banner.size = root.size
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.draw.connect(_draw_banner)
	root.add_child(banner)
	# The "hold Alt" picture goes over everything.
	preview = Control.new()
	preview.size = root.size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.draw.connect(_draw_preview)
	root.add_child(preview)


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func setup(b: SwingBuild) -> void:
	set_build(b)


## Whose sword is on the anvil.
func set_build(b: SwingBuild) -> void:
	if build != null and build.changed.is_connected(_on_changed):
		build.changed.disconnect(_on_changed)
	build = b
	build.changed.connect(_on_changed)
	selected = clampi(selected, 0, build.slot_count() - 1)


## Every change is a hammer blow: the metal heats up, sparks fly, the anvil rings.
func _on_changed() -> void:
	if not is_open:
		return
	dirty = true
	heat = 1.0
	strike_t = 0.0
	var i := clampi(selected, 0, build.slot_count() - 1)
	strike_at = _slot_screen(i).get_center()
	playing.append(["sparks", strike_at, t])
	playing.append(["hammer_strike", Vector2(CENTRE_X, sword_bottom + 4), t])
	for n in 12:
		var a := randf_range(-PI, 0.0)
		sparks.append([strike_at, Vector2(cos(a), sin(a)) * randf_range(40.0, 150.0), 0.0, randf_range(0.3, 0.7)])
	Sfx.play(self, "anvil", -6.0, randf_range(0.95, 1.08))


func open() -> void:
	dirty = false
	finishing = -1.0
	heat = 0.3
	is_open = true
	root.visible = true
	selected = clampi(selected, 0, build.slot_count() - 1)
	opened_at = t
	_stat_last.clear()
	_stat_lit.clear()
	if owned != null:
		# In the cave start on the tab that has something new to fit.
		tab = 1 if _has_unfitted_rune() else 0
		card = 0
	if pauses:
		get_tree().paused = true


var opened_at := -9.0
var _stat_last := {}       # stat name -> the value last shown
var _stat_lit := {}        # stat name -> when it last changed (its icon lights for a moment)


func _has_unfitted_rune() -> bool:
	if owned == null:
		return false
	for id in owned:
		if SwingBuild.FITTINGS.has(id) and not (id in build.line):
			return true
	return false


## Leaving after changes plays the "forged" finish first (press again to skip).
func close() -> void:
	if dirty and finishing < 0.0:
		finishing = 0.0
		Sfx.play(self, "forged", -4.0)
		playing.append(["hammer_strike", Vector2(CENTRE_X, sword_bottom + 4), t])
		return
	_really_close()


func _really_close() -> void:
	finishing = -1.0
	dirty = false
	is_open = false
	renaming = false
	root.visible = false
	if pauses:
		get_tree().paused = false
	drag_id = ""
	dragging = false
	closed.emit()


# --- Input ------------------------------------------------------------------

func _process(delta: float) -> void:
	if is_open:
		_update_fx(delta)
	if renaming or _rename_guard > 0:
		# The keyboard is writing a preset's name: its keys do nothing else.
		_rename_guard = maxi(_rename_guard - 1, 0)
		return
	if Input.is_action_just_pressed("build") and (hotkey or is_open) and t - opened_at > 0.2:
		if finishing >= 0.0:
			_really_close()
		elif is_open:
			close()
		else:
			open()
		return
	if not is_open:
		return
	if finishing >= 0.0:
		finishing += delta
		if finishing >= FINISH_TIME:
			_really_close()
			if _try_after:
				_try_after = false
				try_at_dummy.emit()
		return
	if Input.is_action_just_pressed("menu_back"):
		close()
		return
	if Input.is_action_just_pressed("move_up"):
		selected = mini(selected + 1, build.slot_count() - 1)
	if Input.is_action_just_pressed("move_down"):
		selected = maxi(selected - 1, 0)
	if Input.is_action_just_pressed("menu_next"):
		_set_tab(tab + 1)
	if Input.is_action_just_pressed("menu_prev"):
		_set_tab(tab - 1)
	if Input.is_action_just_pressed("move_right"):
		card = mini(card + 1, _cards().size() - 1)
		keys_on_cards = true
	if Input.is_action_just_pressed("move_left"):
		card = maxi(card - 1, 0)
		keys_on_cards = true
	if Input.is_action_just_pressed("menu_place"):
		_use_card(card)
	if Input.is_action_just_pressed("menu_rotate"):
		_put("")
	if Input.is_action_just_pressed("menu_preset"):
		_use_preset((build.preset + 1) % build.preset_data.size())
	root.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if finishing >= 0.0:
		if event is InputEventMouseButton and event.pressed:
			_really_close()
			get_viewport().set_input_as_handled()
		return
	if renaming:
		if event is InputEventKey:
			if event.pressed:
				_rename_key(event as InputEventKey)
			get_viewport().set_input_as_handled()
			root.queue_redraw()
			return
		if event is InputEventMouseButton and event.pressed:
			_end_rename(true)   # a click anywhere keeps the name, and still does what it would have
	if event is InputEventKey and event.pressed and not event.echo:
		if sandbox:
			match (event as InputEventKey).physical_keycode:
				KEY_1: _load_test("A")
				KEY_2: _load_test("B")
				KEY_3: _load_test("C")
				KEY_4: _load_test("D")
				KEY_T: _try()
	if event is InputEventMouseMotion:
		var m := root.get_local_mouse_position()
		hover = _button_at(m)
		keys_on_cards = false
		if drag_id != "" and not dragging and m.distance_to(drag_start) > 4.0:
			dragging = true
		root.queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()
		get_viewport().set_input_as_handled()
		root.queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		var key := _button_at(root.get_local_mouse_position())
		if mb.button_index == MOUSE_BUTTON_LEFT and _drag_source(key) != "":
			# Runes and bands can be dragged from the tray, or from one slot to another.
			# A press without a drag still acts as a click when the button comes up.
			drag_id = _drag_source(key)
			drag_from = int(key.split(":")[1]) if key.begins_with("slot:") else -1
			drag_key = key
			drag_start = root.get_local_mouse_position()
			dragging = false
		elif mb.button_index == MOUSE_BUTTON_LEFT and key != "":
			_click(key)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and key.begins_with("slot:"):
			selected = int(key.split(":")[1])
			_put("")
		get_viewport().set_input_as_handled()
		root.queue_redraw()


## What a press on this button would pick up: a fitting from the tray or a slot, or "".
func _drag_source(key: String) -> String:
	if key.begins_with("card:") and TABS[tab] != "sword":
		var cards := _cards()
		var i := int(key.split(":")[1])
		if i < cards.size() and not cards[i]["locked"]:
			return cards[i]["id"]
	if key.begins_with("slot:"):
		var i := int(key.split(":")[1])
		if i < build.line.size():
			return build.line[i]
	return ""


func _end_drag() -> void:
	_drop(_button_at(root.get_local_mouse_position()))


## Let go of a dragged part over the button `over` ("" = nowhere).
func _drop(over: String) -> void:
	if drag_id == "":
		return
	var id := drag_id
	var key := drag_key
	var was_drag := dragging
	drag_id = ""
	dragging = false
	if not was_drag:
		_click(key)
		return
	if over.begins_with("slot:"):
		var to := int(over.split(":")[1])
		if drag_from >= 0:
			# Slot to slot: swap the two.
			var other: String = build.line[to] if to < build.line.size() else ""
			build.line[drag_from] = other
			selected = to
			_put(id)
		else:
			selected = to
			_put(id)
	elif drag_from >= 0:
		# Dragged off the sword: take it off.
		selected = drag_from
		_put("")
	Sfx.play(self, "click", -14.0)


func _click(key: String) -> void:
	var p := key.split(":")
	match p[0]:
		"slot":
			selected = int(p[1])
		"tab":
			_set_tab(int(p[1]))
		"card":
			card = int(p[1])
			_use_card(card)
		"use":
			_use_card(card)
		"test":
			_load_test(p[1])
		"does":
			var effects: Array = build.compute()["effects"]
			if int(p[1]) < effects.size():
				selected = int(effects[int(p[1])]["slot"])
		"preset":
			_use_preset(int(p[1]))
		"rename":
			renaming = true
			rename_text = str(build.preset_names[build.preset])
		"back":
			Sfx.play(self, "click", -14.0)
			close()
			return
		"try":
			_try()
			return
	Sfx.play(self, "click", -14.0)


## Switches to loadout preset i: the whole sword changes in one click.
func _use_preset(i: int) -> void:
	if i == build.preset:
		return
	var missing: Array = build.use_preset(i, owned)
	selected = clampi(selected, 0, build.slot_count() - 1)
	if not missing.is_empty():
		var names: Array = []
		for id in missing:
			names.append(_name(id))
		note = "Left off, you don't own it: " + ", ".join(names) + "."
		note_until = t + 6.0


## A key while a preset's name is being typed.
func _rename_key(k: InputEventKey) -> void:
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_end_rename(true)
		KEY_ESCAPE:
			_end_rename(false)
		KEY_BACKSPACE:
			rename_text = rename_text.left(-1) if rename_text != "" else ""
		_:
			var c := char(k.unicode) if k.unicode > 0 else ""
			if c != "" and c.to_upper() in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -'&!" and rename_text.length() < SwingBuild.PRESET_NAME_MAX:
				rename_text += c


func _end_rename(keep: bool) -> void:
	if not renaming:
		return
	renaming = false
	_rename_guard = 2
	if keep:
		build.preset_names[build.preset] = rename_text.strip_edges()


func _set_tab(t: int) -> void:
	tab = posmod(t, TABS.size())
	card = 0


## Every part id, in tray order (the cave shows the owned ones from this list).
const ALL_BLADES := ["wooden_blade", "tin_blade", "iron_dagger", "iron_sabre", "iron_broadsword", "iron_rapier", "iron_falchion", "iron_greatsword"]
const ALL_GRIPS := ["wooden_grip", "tin_grip", "wrapped_grip", "long_grip", "ringed_grip", "gilded_grip"]
const ALL_LIMBS := ["wooden_shortbow", "tin_shortbow", "iron_shortbow", "iron_longbow"]
const ALL_BOW_GRIPS := ["wooden_bow_grip", "tin_bow_grip", "wrapped_bow_grip", "horn_bow_grip"]
const ALL_HEADS := ["wooden_maul", "tin_maul", "iron_maul", "iron_warhammer"]
const ALL_HAFTS := ["wooden_haft", "tin_haft", "bound_haft", "studded_haft"]
const ALL_STAFF_HEADS := ["wooden_apprentice", "tin_apprentice", "iron_apprentice", "iron_storm"]
const ALL_SHAFTS := ["wooden_shaft", "tin_shaft", "carved_shaft", "twisted_shaft"]

## The rows of the first tab for each weapon, top to bottom:
## [heading, card kind, the ids the arena offers, every id (the cave shows the owned ones)].
## A sword and a hammer have three rows; a bow and a staff a fourth, for what they shoot.
const PART_ROWS := {
	"sword": [["Blade", "blades", SwingBuild.BLADE_ORDER, ALL_BLADES], ["Grip", "grips", SwingBuild.GRIP_ORDER, ALL_GRIPS],
		["Pommel", "pommels", SwingBuild.POMMEL_ORDER, SwingBuild.POMMEL_ORDER]],
	"bow": [["Limbs", "limbs", SwingBuild.LIMB_ORDER, ALL_LIMBS], ["Grip", "bow_grips", SwingBuild.BOW_GRIP_ORDER, ALL_BOW_GRIPS],
		["String", "strings", SwingBuild.STRING_ORDER, SwingBuild.STRING_ORDER], ["Arrows", "arrows", SwingBuild.ARROW_ORDER, SwingBuild.ARROW_ORDER]],
	"hammer": [["Head", "heads", SwingBuild.HEAD_ORDER, ALL_HEADS], ["Haft", "hafts", SwingBuild.HAFT_ORDER, ALL_HAFTS],
		["Counterweight", "weights", SwingBuild.WEIGHT_ORDER, SwingBuild.WEIGHT_ORDER]],
	"staff": [["Head", "staff_heads", SwingBuild.STAFF_HEAD_ORDER, ALL_STAFF_HEADS], ["Shaft", "shafts", SwingBuild.SHAFT_ORDER, ALL_SHAFTS],
		["Cap", "caps", SwingBuild.CAP_ORDER, SwingBuild.CAP_ORDER], ["Crystal", "crystals", SwingBuild.CRYSTAL_ORDER, SwingBuild.CRYSTAL_ORDER]],
}
## The widest a card may be in each row of a four-row tab.
const ROW_WIDTHS := {"bow": [64, 34, 34, 40], "staff": [40, 40, 34, 34]}
## Where a part's tray picture is: card kind -> folder under art/swing/.
const ICON_DIRS := {"limbs": "bow/limbs", "bow_grips": "bow/grips", "strings": "bow/strings", "arrows": "bow/arrows",
	"heads": "hammer/heads", "hafts": "hammer/hafts", "weights": "hammer/weights",
	"staff_heads": "staff/heads", "shafts": "staff/shafts", "caps": "staff/caps", "crystals": "staff/crystals"}


## True while the weapon on the anvil is a bow.
func _bow() -> bool:
	return build.weapon() == "bow"


## The table a part of the weapon on the anvil is in ({} if it isn't one of its parts).
func _part_table(id: String) -> Dictionary:
	var w := build.weapon()
	for table in [SwingBuild.heads_of(w), SwingBuild.grips_of(w), SwingBuild.butts_of(w), SwingBuild.shots_of(w)]:
		if table.has(id):
			return table
	return {}


## Which pictures a fitting uses: "runes", "threads" or "rare".
static func _fit_kind(id: String) -> String:
	match str(SwingBuild.FITTINGS[id]["kind"]):
		"rune": return "runes"
		"band": return "threads"
	return "rare"


## The first tab is the weapon's own parts, and is called after it.
func _tab_label(i: int) -> String:
	return build.weapon() if i == 0 else str(TABS[i])


func _has(id: String) -> bool:
	return owned == null or id in owned


## The cards on the current tab: [{id, name, locked}]
func _cards() -> Array:
	var out: Array = []
	match TABS[tab]:
		"sword":
			# The weapon's own parts, a row for each kind.
			var rows: Array = PART_ROWS[build.weapon()]
			for ri in rows.size():
				for id in (rows[ri][2] if owned == null else rows[ri][3]):
					if _has(id):
						var part: Dictionary = _part_table(id)[id]
						out.append({"id": id, "name": part["name"], "locked": part.get("locked", false), "row": ri, "kind": rows[ri][1]})
		"runes":
			for id in SwingBuild.FITTING_ORDER:
				if SwingBuild.FITTINGS[id]["kind"] == "rune" and not SwingBuild.FITTINGS[id].get("parked", false) and _has(id) and SwingBuild.fits(id, build.weapon()):
					out.append({"id": id, "name": SwingBuild.FITTINGS[id]["name"], "locked": false,
						"group": "active" if SwingBuild.FITTINGS[id]["trigger"] == "active" else "passive"})
		"threads":
			# Threads, then the rare rule-benders (they change how threads count).
			for kind in ["band", "bender"]:
				for id in SwingBuild.FITTING_ORDER:
					if SwingBuild.FITTINGS[id]["kind"] == kind and not SwingBuild.FITTINGS[id].get("parked", false) and _has(id):
						out.append({"id": id, "name": SwingBuild.FITTINGS[id]["name"], "locked": false,
							"group": "thread" if kind == "band" else "rare", "kind": _fit_kind(id)})
	return out


func _use_card(i: int) -> void:
	var cards := _cards()
	if i < 0 or i >= cards.size() or cards[i]["locked"]:
		return
	var id: String = cards[i]["id"]
	if not _fit_part(build, id):
		_put(id)
	selected = clampi(selected, 0, build.slot_count() - 1)


func _put(id: String) -> void:
	# One rule-bender per sword: fitting a new one takes the old one off.
	if id != "" and SwingBuild.FITTINGS[id]["kind"] == "bender":
		for i in build.line.size():
			if i != selected and build.line[i] != "" and SwingBuild.FITTINGS[build.line[i]]["kind"] == "bender":
				build.line[i] = ""
	build.set_slot(selected, id)


## Fits a head, grip, butt or shot of b's own weapon to it. False if `id` isn't one.
static func _fit_part(b, id: String) -> bool:
	var w: String = b.weapon()
	if SwingBuild.heads_of(w).has(id):
		b.set_blade(id)
	elif SwingBuild.grips_of(w).has(id):
		b.set_grip(id)
	elif SwingBuild.butts_of(w).has(id):
		b.set_pommel(id)
	elif SwingBuild.shots_of(w).has(id):
		b.set_arrows(id)
	else:
		return false
	return true


func _load_test(k: String) -> void:
	if build.weapon() != "sword":
		return   # the test swords are swords
	build.load_test(k)
	selected = clampi(selected, 0, build.slot_count() - 1)


var _try_after := false

func _try() -> void:
	if dirty:
		_try_after = true
		close()
		return
	close()
	try_at_dummy.emit()


func _button_at(m: Vector2) -> String:
	for k in buttons:
		if (buttons[k] as Rect2).has_point(m):
			return k
	return ""


# --- Drawing helpers ----------------------------------------------------------

func _nine(name: String, r: Rect2, ci: CanvasItem = null) -> void:
	if ci == null:
		ci = root
	if not _styles.has(name):
		var tex := Art.texture("swing/ui/%s.png" % name)
		if tex == null:
			_styles[name] = null
		else:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			var m: Array = SwordArt.data().get("ui", {}).get(name + ".png", {}).get("nine_patch_margins", [4, 4, 4, 4])
			if name == "focus_corners":
				m = [4, 4, 4, 4]
			sb.texture_margin_left = m[0]
			sb.texture_margin_top = m[1]
			sb.texture_margin_right = m[2]
			sb.texture_margin_bottom = m[3]
			if name == "focus_corners":
				sb.draw_center = false
			_styles[name] = sb
	if _styles[name] == null:
		ci.draw_rect(r, PLATE)
		ci.draw_rect(r, FAINT, false, 1.0)
	else:
		ci.draw_style_box(_styles[name], r)


func _head(text: String, pos: Vector2, col := INK, size := 8, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	root.draw_string(Art.font("Silkscreen-Regular"), pos, text.to_upper(), align, width, size, col)


func _body(text: String, pos: Vector2, col := INK, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	root.draw_string(Art.font("PixelifySans-Regular"), pos, text, align, width, 11, col)


## Word-wraps body text to a width; returns the lines.
func _wrap(text: String, width: float) -> Array:
	var f := Art.font("PixelifySans-Regular")
	var lines: Array = []
	var cur := ""
	for w in text.split(" "):
		var tryline := w if cur == "" else cur + " " + w
		if f.get_string_size(tryline, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > width and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = tryline
	if cur != "":
		lines.append(cur)
	return lines


## A part's picture for the tray (null if it has none).
func _icon_texture(kind: String, id: String) -> Texture2D:
	match kind:
		"threads":
			return Art.texture("spirit/threads/%s_icon.png" % id)
		"runes", "rare", "pommels", "blades", "grips":
			return Art.texture("swing/%s/%s_icon.png" % [kind, id])
	return Art.texture("swing/%s/%s_icon.png" % [ICON_DIRS.get(kind, kind), id])


func _icon(kind: String, id: String, center: Vector2, part_scale := 2.0, tint := Color.WHITE) -> void:
	match kind:
		"runes", "threads", "rare":
			var tex := _icon_texture(kind, id)
			if tex != null:
				root.draw_texture(tex, (center - tex.get_size() * 0.5).round(), tint)
			elif SwingBuild.FITTINGS.has(id):
				# No art yet: a plain stone (rune), ring (band) or gem (rule-bender) in its colour.
				var f: Dictionary = SwingBuild.FITTINGS[id]
				var c: Color = f["color"]
				match f["kind"]:
					"rune":
						root.draw_circle(center, 7.0, c.darkened(0.5))
						root.draw_circle(center, 5.0, c)
					"band":
						root.draw_rect(Rect2(center - Vector2(9, 3), Vector2(18, 6)), c.darkened(0.4))
						root.draw_rect(Rect2(center - Vector2(9, 1), Vector2(18, 2)), c)
					_:
						root.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(7, 0), center + Vector2(0, 8), center + Vector2(-7, 0)]), c)
		"pommels":
			var ptex := Art.texture("swing/pommels/%s_icon.png" % id)
			if ptex != null:
				root.draw_texture(ptex, (center - ptex.get_size() * 0.5).round(), tint)
				return
			# No art: a round knob in the pommel's colour.
			var pc: Color = SwingBuild.POMMELS[id]["color"]
			root.draw_circle(center, 8.0, pc.darkened(0.55))
			root.draw_circle(center, 6.5, pc)
			root.draw_circle(center + Vector2(-2, -2), 2.0, pc.lightened(0.5))
		"limbs", "bow_grips", "strings", "arrows", "heads", "hafts", "weights", "staff_heads", "shafts", "caps", "crystals":
			var btex := Art.texture("swing/%s/%s_icon.png" % [ICON_DIRS[kind], id])
			if btex != null:
				root.draw_texture(btex, (center - btex.get_size() * 0.5).round(), tint)
			elif kind == "strings":
				root.draw_rect(Rect2(center - Vector2(9, 1), Vector2(18, 2)), BowArt.string_color(id))
			else:
				root.draw_rect(Rect2(center - Vector2(10, 2), Vector2(20, 4)), Color("#8a6a48"))
		"blades", "grips":
			# Its own picture for the tray, lying down with the tip to the right.
			var card_tex := Art.texture("swing/%s/%s_icon.png" % [kind, id])
			if card_tex != null:
				root.draw_texture(card_tex, (center - card_tex.get_size() * 0.5).round(), tint)
				return
			# No picture: the in-hand sprite at 2x, turned on its side.
			var tex := Art.texture("swing/%s/%s_hand.png" % [kind, id])
			if tex != null:
				root.draw_set_transform(center, PI * 0.5, Vector2(part_scale, part_scale))
				root.draw_texture(tex, (-tex.get_size() * 0.5).round())
				root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- The screen ---------------------------------------------------------------

func _draw_forge() -> void:
	buttons.clear()
	# A still backdrop (the spirit's niche), then a plate behind every kind of words.
	var backdrop := Art.texture("spirit/forge/forge_backdrop_spirit.png")
	if backdrop != null:
		root.draw_texture(backdrop, Vector2.ZERO)
	else:
		root.draw_rect(Rect2(Vector2.ZERO, root.size), WELL)
	var stats := build.compute()
	_nine("panel", TRAY)
	_nine("panel_titled", INFO)
	_nine("well", HELP)
	_nine("well", PRESETS)
	_nine("panel", does_rect(stats))
	_nine("panel_titled", stats_rect(stats))
	_draw_back()
	_head("The forge", title_at(), AMBER, 16)
	if whose != "":
		_head(whose, whose_at(), INK, 8, WHOSE_W, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_tray()
	_draw_sword(stats)
	_draw_ring(stats)
	_draw_presets()
	_draw_does(stats)
	_draw_info()
	_draw_stats(stats)
	_draw_help()
	if dragging:
		for i in build.line.size():
			var r := _slot_screen(i)
			var on := hover == "slot:%d" % i
			root.draw_rect(r.grow(3 if on else 1), FOCUS if on else Color(1, 1, 1, 0.35), false, 1.0)
		_icon(_fit_kind(drag_id), drag_id, root.get_local_mouse_position())


## The plate of numbers sits at the foot of the right-hand column, as tall as the
## weapon has numbers; "what it does" has the rest.
static func stats_rect(stats: Dictionary) -> Rect2:
	var h := STAT_HEAD + stat_rows(stats).size() * STAT_LINE + STAT_FOOT
	return Rect2(RIGHT.position.x, RIGHT.end.y - h, RIGHT.size.x, h)


static func does_rect(stats: Dictionary) -> Rect2:
	return Rect2(RIGHT.position, Vector2(RIGHT.size.x, RIGHT.size.y - stats_rect(stats).size.y - 3.0))


## The way out, top left: a button to click, saying the key that does the same.
## With two players on one screen the row also says whose sword this is, so the
## button keeps to the one word.
func back_label() -> String:
	if whose != "":
		return "Back"
	return "Back (B)" if _on_pad() else "Back (Esc)"


func back_rect() -> Rect2:
	return Rect2(BACK_AT, Vector2(_head_width(back_label()) + 14.0, BACK_H))


func title_at() -> Vector2:
	return Vector2(back_rect().end.x + 8.0, 24)


## Whose weapon this is, with two players at one forge: at the top of the niche,
## in the middle (the title's row has the weapon's tip beside it now).
const WHOSE_W := 90.0

func whose_at() -> Vector2:
	return Vector2(RING_AT.x - WHOSE_W * 0.5, 36)


func _head_width(text: String, size := 8) -> float:
	return ceilf(Art.font("Silkscreen-Regular").get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)


func _draw_back() -> void:
	var r := back_rect()
	buttons["back"] = r
	var hot := hover == "back"
	if not Art.draw_nine(root, "swing/ui/button_hot.png" if hot else "swing/ui/button.png", r, 3):
		root.draw_rect(r, FOCUS if hot else PLATE)
		root.draw_rect(r, FAINT, false, 1.0)
	_head(back_label(), Vector2(r.position.x + 1, r.position.y + 12), PLATE if hot else INK, 8, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## Left: tabs and icon-only cards.
func _draw_tray() -> void:
	var x := 13.0
	var f := Art.font("Silkscreen-Regular")
	for i in TABS.size():
		var w := f.get_string_size(_tab_label(i).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := Rect2(x - 4, 38, w + 9, 14)
		buttons["tab:%d" % i] = r
		# The chosen tab stands proud (its picture starts 2 px higher than the others').
		var drawn := Art.draw_nine(root, "swing/ui/tab_selected.png" if i == tab else "swing/ui/tab.png", r, 4)
		_head(_tab_label(i), Vector2(x, 48), INK if i == tab else (FOCUS if hover == "tab:%d" % i else DIM))
		if i == tab and not drawn:
			root.draw_rect(Rect2(x, 51, w, 1), AMBER)
		x += w + 11
	var cards := _cards()
	card = clampi(card, 0, maxi(cards.size() - 1, 0))
	if cards.is_empty():
		_body("Nothing here yet.", Vector2(14, 78), DIM)
	var rects := _place_cards(cards)
	for i in cards.size():
		var c: Dictionary = cards[i]
		var r: Rect2 = rects[i]
		buttons["card:%d" % i] = r
		_nine("well_selected" if i == card else "well", r)
		if hover == "card:%d" % i and i != card:
			root.draw_rect(r, FOCUS, false, 1.0)
		if c["locked"]:
			var lock := Art.texture("swing/ui/padlock.png")
			if lock != null:
				root.draw_texture(lock, (r.get_center() - lock.get_size() * 0.5).round())
			continue
		_icon(c.get("kind", TABS[tab]), c["id"], r.get_center())
		if c.get("group", "") == "active":
			_badge(r.get_center())
		if _on_sword(c["id"]):
			var fitted := Art.texture("swing/ui/fitted_mark.png")
			if fitted != null:
				root.draw_texture(fitted, Vector2(r.end.x - 7, r.position.y + 2))
			else:
				root.draw_rect(Rect2(r.end.x - 6, r.position.y + 2, 4, 4), AMBER)


## How big a part's card is: its picture and a little room. Every card in a row
## is as tall as the row's tallest picture.
const CARD_PAD := Vector2(4, 4)

func _card_size(c: Dictionary, row_h: float) -> Vector2:
	var tex := _icon_texture(str(c.get("kind", "")), str(c["id"]))
	var w := 26.0 if tex == null else float(tex.get_width())
	return Vector2(maxf(w + CARD_PAD.x, 20.0), row_h)


## Where each card on the current tab goes, in card order. Draws the headings of
## the rows and groups on the way.
func _place_cards(cards: Array) -> Array:
	var rects: Array = []
	rects.resize(cards.size())
	var left := TRAY.position.x + 8.0
	var right := TRAY.end.x - 8.0
	match TABS[tab]:
		"sword":
			# The weapon's own parts: a heading and a row of cards for each kind, each
			# card as wide as its picture. A row that is full carries on underneath.
			var part_rows: Array = PART_ROWS[build.weapon()]
			var y := 56.0
			for ri in part_rows.size():
				var row_h := 0.0
				for c in cards:
					if int(c["row"]) == ri:
						var tex := _icon_texture(str(c["kind"]), str(c["id"]))
						row_h = maxf(row_h, (20.0 if tex == null else float(tex.get_height())) + CARD_PAD.y)
				if row_h <= 0.0:
					continue
				_head(part_rows[ri][0], Vector2(left, y + 7), DIM)
				y += 9.0
				var x := left
				for i in cards.size():
					if int(cards[i]["row"]) != ri:
						continue
					var size := _card_size(cards[i], row_h)
					if x > left and x + size.x > right:
						x = left
						y += row_h + 1.0
					rects[i] = Rect2(x, y, size.x, size.y)
					x += size.x + 1.0
				y += row_h + 3.0
		"runes":
			# Two groups, so the two kinds can be told apart before reading anything:
			# passive runes (round stones), then active ones (square, with a button badge).
			var y := 58.0
			for group in ["passive", "active"]:
				var k := 0
				for i in cards.size():
					if cards[i]["group"] != group:
						continue
					if k == 0:
						var tag := Art.texture("swing/ui/tray_%s.png" % group)
						if tag != null:
							root.draw_texture(tag, Vector2(left, y))
						else:
							_head(group, Vector2(left, y + 8), DIM)
					rects[i] = Rect2(left + (k % 3) * 44, y + 12 + (k / 3) * 44, 38, 38)
					k += 1
				if k > 0:
					y += 12 + ((k + 2) / 3) * 44 + 4
		_:
			# Threads, then (under a heading of their own) the rare rule-benders.
			var y := 60.0
			for group in ["thread", "rare"]:
				var k := 0
				for i in cards.size():
					if cards[i].get("group", "thread") != group:
						continue
					if k == 0 and group == "rare":
						_head("Rare", Vector2(left, y + 7), DIM)
						y += 11.0
					rects[i] = Rect2(left + (k % 3) * 44, y + (k / 3) * 44, 38, 38)
					k += 1
				if k > 0:
					y += ((k + 2) / 3) * 44 + 2
	return rects


## The little button cap on an active rune's stone. `center` is the middle of the
## stone's 26 x 26 picture.
func _badge(center: Vector2) -> void:
	var tex := Art.texture("swing/ui/active_badge.png")
	if tex == null:
		return
	var at: Array = SwordArt.data().get("stones", {}).get("active_badge", {}).get("at_on_icon", [18, 18])
	root.draw_texture(tex, (center - Vector2(13, 13)).round() + Vector2(at[0], at[1]))


## The part the info plate is about: what the mouse is on (a card in the tray or
## a fitting on the sword), else the card the keys are on.
func _info_id() -> String:
	if _preset_hover() >= 0:
		return ""
	var cards := _cards()
	if hover.begins_with("card:"):
		var i := int(hover.split(":")[1])
		if i < cards.size():
			return cards[i]["id"]
	if hover.begins_with("slot:"):
		var i := int(hover.split(":")[1])
		if i < build.line.size() and build.line[i] != "":
			return build.line[i]
	if card < cards.size():
		return cards[card]["id"]
	return ""


func _name(id: String) -> String:
	for w in SwingBuild.WEAPON_ORDER:
		for table in [SwingBuild.heads_of(w), SwingBuild.grips_of(w), SwingBuild.butts_of(w), SwingBuild.shots_of(w)]:
			if table.has(id):
				return table[id]["name"]
	return SwingBuild.FITTINGS[id]["name"]


func _is_rune(id: String) -> bool:
	return SwingBuild.FITTINGS.has(id) and SwingBuild.FITTINGS[id]["kind"] == "rune"


func _on_pad() -> bool:
	return keys == SwingBuild.ABILITY_KEYS["pad"]


## Under the tray: the part's name and one plain sentence, never more, on a plate
## of its own. A rune's picture shows while Alt (LT on a controller) is held.
func _draw_info() -> void:
	var at := INFO.position
	if _preset_hover() >= 0:
		_draw_preset_info(_preset_hover())
		return
	var id := _info_id()
	if id == "":
		_head("Parts", at + Vector2(14, 14), DIM)
		return
	root.draw_string(Art.font("PixelifySans-Regular"), at + Vector2(14, 16), _name(id), HORIZONTAL_ALIGNMENT_LEFT, -1, info_name_size(id), AMBER)
	var y := at.y + 33.0
	for l in info_lines(id):
		_body(l, Vector2(at.x + 9, y))
		y += 12
	if _is_rune(id):
		_body("Hold %s to preview" % ("LT" if _on_pad() else "Alt"), Vector2(at.x + 9, INFO.end.y - 7), DIM)


## A part's sentence, wrapped for the info plate. (Five lines fit, four above a
## rune's preview hint: tests/smoke_forge.gd checks every part.)
const INFO_LINES := 5
const INFO_LINES_RUNE := 4

func info_lines(id: String) -> Array:
	return _wrap(_desc(id), INFO.size.x - 18)


## How big a part's name is written on the info plate: 13, or 11 for the few
## names too long for that.
const INFO_NAME_ROOM := 136.0

func info_name_size(id: String) -> int:
	var w := Art.font("PixelifySans-Regular").get_string_size(_name(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	return 13 if w <= INFO_NAME_ROOM else 11


func _draw_help() -> void:
	var at := HELP.position + Vector2(7, 0)
	var y := 13.0
	for l in help_lines():
		_body(l[0], at + Vector2(0, y), l[1])
		y += 12.0


## How to use the screen, three lines at most, as [words, colour]. It follows what
## the player is doing: naming a preset, pointing at the presets, on a controller.
func help_lines() -> Array:
	if renaming:
		return [["Type a name for this preset.", INK], ["Enter: keep it   Esc: cancel", DIM]]
	if t < note_until:
		var out: Array = []
		for l in _wrap(note, HELP.size.x - 14).slice(0, 3):
			out.append([l, INK])
		return out
	if _preset_hover() >= 0:
		return [["A preset is a saved %s." % build.weapon(), DIM], ["Click A, B or C to switch to it.", DIM], ["Click its name to rename it.", DIM]]
	if _on_pad():
		return [["Stick: pick   A: fit   X: empty", DIM], ["LB RB: tabs   Select: preset", DIM], ["B or Y: back to the game", DIM]]
	return [["Drag a rune onto a seat to fit.", DIM], ["Right-click a seat to empty it.", DIM],
		["T: try at dummy   Esc: back" if sandbox else "Esc or Tab: back to the game", DIM]]


## The preset the mouse is on (its tab, or the name beside the tabs), or the one
## being named. -1 = none.
func _preset_hover() -> int:
	if renaming or hover == "rename":
		return build.preset
	if hover.begins_with("preset:"):
		return int(hover.split(":")[1])
	return -1


## Top right: the three loadout presets as tabs, then the chosen one's name.
## (While a name is being typed the box takes the whole plate, so all of it shows.)
func _draw_presets() -> void:
	var at := PRESETS.position
	if renaming:
		var box := Rect2(at.x + 4, at.y + 4, PRESETS.size.x - 8, 15)
		buttons["rename"] = box
		root.draw_rect(box, WELL)
		root.draw_rect(box, FOCUS, false, 1.0)
		_head(rename_text + ("_" if fmod(t, 0.8) < 0.5 else ""), Vector2(box.position.x + 4, at.y + 15), FOCUS)
		return
	_head("Preset", at + Vector2(7, 15), DIM)
	for i in build.preset_data.size():
		var r := Rect2(at.x + 44 + i * 20, at.y + 5, 18, 14)
		var key := "preset:%d" % i
		buttons[key] = r
		var on: bool = i == build.preset
		var drawn := Art.draw_nine(root, "swing/ui/tab_selected.png" if on else "swing/ui/tab.png", r, 4)
		# A preset that has never been used is fainter.
		var col := INK if on else (FOCUS if hover == key else (DIM if build.preset_data[i] != null else FAINT))
		_head(SwingBuild.PRESET_LETTERS[i], Vector2(r.position.x + 1, at.y + 15), col, 8, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if on and not drawn:
			root.draw_rect(Rect2(r.position.x + 3, r.end.y - 1, r.size.x - 6, 1), AMBER)
	var nr := Rect2(at.x + 106, at.y + 4, PRESETS.size.x - 110, 15)
	buttons["rename"] = nr
	var name := str(build.preset_names[build.preset])
	if name != "":
		_head(_cut_head(name, nr.size.x - 4), Vector2(nr.position.x + 3, at.y + 15), FOCUS if hover == "rename" else INK)
	else:
		_head("Name it", Vector2(nr.position.x + 3, at.y + 15), FOCUS if hover == "rename" else FAINT)


## A heading cut short to fit `width`, ending in two dots when something is left off.
func _cut_head(text: String, width: float) -> String:
	if _head_width(text) <= width:
		return text
	var cut := text
	while cut.length() > 1 and _head_width(cut + "..") > width:
		cut = cut.left(-1)
	return cut.strip_edges() + ".."


## The info plate while the mouse is on a preset: its name, and the sword it
## holds as pictures (blade, grip and pommel, then what is in the slots). A part
## the player no longer owns is greyed out under a padlock.
func _draw_preset_info(i: int) -> void:
	var at := INFO.position
	root.draw_string(Art.font("PixelifySans-Regular"), at + Vector2(14, 16), build.preset_title(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AMBER)
	var data = build.preset_sword(i)
	if data == null:
		var y := at.y + 35.0
		for l in _wrap("Empty. Click it to start it as a copy of this %s." % build.weapon(), INFO.size.x - 18):
			_body(l, Vector2(at.x + 9, y))
			y += 12
		return
	var missing := SwingBuild.parts_missing(data, owned)
	var kinds: Array = PART_ROWS[SwingBuild.weapon_of(data[0])]
	# Its parts side by side, each as wide as its picture, then what is in the seats.
	var part_ids: Array = [data[0], data[1], data[2]]
	if kinds.size() == 4 and data.size() > 4:
		part_ids.append(data[4])
	var x := at.x + 9.0
	for k in part_ids.size():
		var tex := _icon_texture(str(kinds[k][1]), str(part_ids[k]))
		var w := 26.0 if tex == null else float(tex.get_width())
		_part_icon(kinds[k][1], part_ids[k], Vector2(x + floorf(w * 0.5), at.y + 38), missing)
		x += w + 4.0
	x = at.x + 9.0
	for id in data[3]:
		if id == "":
			root.draw_rect(Rect2(x + 6, at.y + 63, 14, 14), WELL)
			root.draw_rect(Rect2(x + 6, at.y + 63, 14, 14), FAINT, false, 1.0)
		else:
			_part_icon(_fit_kind(id), id, Vector2(x + 13, at.y + 70), missing)
		x += 28.0


func _part_icon(kind: String, id: String, center: Vector2, missing: Array) -> void:
	if id in missing:
		_icon(kind, id, center, 2.0, Color(0.42, 0.44, 0.5, 0.55))
		var lock := Art.texture("swing/ui/padlock.png")
		if lock != null:
			root.draw_texture(lock, (center - lock.get_size() * 0.5).round())
		return
	_icon(kind, id, center)
	if SwingBuild.FITTINGS.has(id) and SwingBuild.FITTINGS[id].get("trigger", "") == "active":
		_badge(center)


func _preview_held() -> bool:
	if Input.is_key_pressed(KEY_ALT):
		return true
	for pad in Input.get_connected_joypads():
		if Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > 0.5:
			return true
	return false


## While Alt is held on a rune: a still picture of it firing, over the sword.
func _draw_preview() -> void:
	if not is_open or finishing >= 0.0 or dragging:
		return
	var id := _info_id()
	if id == "" or not _is_rune(id) or not (_preview_held() or preview_always):
		return
	_nine("panel_titled", PREVIEW, preview)
	preview.draw_string(Art.font("Silkscreen-Regular"), PREVIEW.position + Vector2(14, 14), _name(id).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, AMBER)
	var frame := Rect2(PREVIEW.position + Vector2(4, 24), Vector2(176, 120))   # the pictures are 352 x 240
	var tex := Art.texture("swing/previews/%s.png" % id)
	if tex != null:
		preview.draw_texture_rect(tex, frame, false)
	else:
		preview.draw_rect(frame, WELL)
		preview.draw_string(Art.font("PixelifySans-Regular"), frame.position + Vector2(0, 64), "No picture yet", HORIZONTAL_ALIGNMENT_CENTER, frame.size.x, 11, DIM)


var preview_always := false   # for screenshots: show the picture without Alt


func _short(name: String) -> String:
	return name.replace("Iron ", "").replace(" Grip", "")


func _on_sword(id: String) -> bool:
	return id != "" and (id == build.blade or id == build.grip or id == build.pommel or id == build.arrows or id in build.line)


func _desc(id: String) -> String:
	if SwingBuild.POMMELS.has(id):
		return SwingBuild.POMMELS[id]["desc"]
	if SwingBuild.BLADES.has(id):
		return SwingBuild.blade_info(id)["desc"]
	if SwingBuild.GRIPS.has(id):
		return SwingBuild.GRIPS[id]["desc"]
	if SwingBuild.LIMBS.has(id):
		return SwingBuild.limb_info(id, build.arrows)["desc"]
	if SwingBuild.HEADS.has(id):
		return SwingBuild.hammer_info(id)["desc"]
	if SwingBuild.STAFF_HEADS.has(id):
		return SwingBuild.staff_info(id, build.arrows)["desc"]
	for table in [SwingBuild.BOW_GRIPS, SwingBuild.STRINGS, SwingBuild.ARROWS, SwingBuild.HAFTS, SwingBuild.WEIGHTS, SwingBuild.SHAFTS, SwingBuild.CAPS, SwingBuild.CRYSTALS]:
		if table.has(id):
			return table[id]["desc"]
	return SwingBuild.FITTINGS[id]["desc"]


func _boost_text(band: String, rune: String) -> String:
	match band:
		"twice":
			return {"shockwave": "two waves", "hook": "hooks twice", "shards": "two chains", "weak_point": "two marks", "leap": "two leaps", "whirlwind": "spins twice as long", "ghostwield": "copies each swing twice"}.get(rune, "twice")
		"wider":
			return {"shockwave": "a bigger wave", "hook": "reaches further", "shards": "jumps further", "weak_point": "a bigger spot", "leap": "leaps from further away", "whirlwind": "a bigger circle", "ghostwield": "the ghost stays longer"}.get(rune, "bigger")
		"every_hit":
			if SwingBuild.FITTINGS.get(rune, {}).get("trigger", "") == "active":
				return "back sooner with each hit"
			return "on every hit, half strength"
		"saved_up":
			if rune == "ghostwield":
				return "a full copy, 3x the recharge"
			return "every third time, 3x strong"
		"on_dodge":
			if rune == "ghostwield":
				return "the ghost cuts along your dodge"
			return "when you dodge too"
	return ""


## What a band does to its rune, as a short sentence for the side panel.
func _band_line(band: String, rune: String) -> String:
	var rn: String = SwingBuild.FITTINGS[rune]["name"]
	match band:
		"twice":
			return "%s fires twice." % rn
		"wider":
			return "%s %s." % [rn, _boost_text("wider", rune)]
		"every_hit":
			if rune == "shards":
				return "Shards split in two at each jump, at half strength."
			return "%s happens on every hit, at half strength." % rn
		"saved_up":
			return "%s happens every third time, three times as strong." % rn
		"on_dodge":
			return "%s also happens when you dodge." % rn
	return ""


## The weapon's frame at the forge: a sword's from SwordArt (a hammer and a staff
## are drawn like swords), a bow's from BowArt.
func _frame_size() -> Vector2:
	if _bow():
		return BowArt.forge_size(build.blade, build.grip)
	return SwordArt.frame_size(build.blade, build.grip, "forge")


## The weapon itself, with nothing fitted on it: the spirit holds the runes and
## threads now, so the line that is passed on is an empty one.
func _draw_weapon(ci: CanvasItem) -> void:
	if _bow():
		BowArt.draw_forge(ci, build.blade, build.grip, build.pommel, build.arrows, [])
	else:
		SwordArt.draw(ci, build.blade, build.grip, [], "forge", {}, Vector2.ZERO, Color.WHITE, build.pommel, false,
			build.arrows if build.weapon() == "staff" else "")


## The weapon big over the anvil, between the tray and the niche.
func _draw_sword(_stats: Dictionary) -> void:
	var size := _frame_size()
	# Twice its size whenever that fits. A taller sword is drawn smaller, by a
	# whole number of screen pixels for each of its own, so they stay square.
	# The very tallest (a greatsword on a long grip) may use the few pixels above
	# SWORD_TOP and sit a little lower on the anvil, rather than drop a whole size.
	var screen := maxf(roundf(float(get_window().size.y) / 360.0), 1.0)
	var fit := minf((SWORD_BOTTOM - SWORD_TOP + SWORD_SLACK) / size.y, 2.0)
	zoom = maxf(floorf(fit * screen) / screen, 1.0 / screen)
	var top_y := maxf(SWORD_BOTTOM - size.y * zoom, minf(SWORD_TOP, 0.0) if size.y * zoom > SWORD_BOTTOM - SWORD_TOP else SWORD_TOP)
	sword_bottom = top_y + size.y * zoom
	var top := Vector2(CENTRE_X - size.x * zoom * 0.5, top_y).round()
	sword_top = top
	sword_size = size * zoom
	var anvil := Art.texture("swing/ui/anvil.png")
	if anvil != null:
		root.draw_texture(anvil, Vector2(CENTRE_X - anvil.get_width() * 0.5, SWORD_BOTTOM - 2).round())
	root.draw_set_transform(top, 0.0, Vector2(zoom, zoom))
	_draw_weapon(root)
	root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- The spirit's ring ---------------------------------------------------------

## Where seat `i` of `n` is on the ring, in degrees (0 = right, 90 = down). The
## order starts at the start mark on the left, runs along the bottom, up the
## right side and back along the top.
static func seat_angle(i: int, n: int) -> float:
	return 180.0 - (float(i) + 0.5) * 360.0 / float(maxi(n, 1))


static func seat_at(i: int, n: int) -> Vector2:
	var a := deg_to_rad(seat_angle(i, n))
	return (RING_AT + Vector2(cos(a), sin(a)) * RING_R).round()


## A seat's place on the screen. (Still "slot" in the code: a seat is the socket
## a part gives, and `build.line` holds what is in each, grip first.)
func _slot_screen(i: int) -> Rect2:
	return Rect2(seat_at(i, build.line.size()) - Vector2(SEAT, SEAT) * 0.5, Vector2(SEAT, SEAT))


## True where a thread's pattern has a pixel. s: px along the line from the
## thread's seat, d: px off the centre line, u: s / the line's length. (The
## art's rule: art/spirit/spirit.json, "thread_rule".)
static func thread_pixel(kind: String, s: float, d: float, u: float) -> bool:
	match kind:
		"twice":
			return absf(absf(d) - 1.5) < 0.6
		"wider":
			return absf(d) < 0.6 or absf(absf(d) - (0.5 + 3.4 * u)) < 0.6
		"every_hit":
			return absf(d) < 0.6 or (int(s) % 6 in [2, 3] and absf(d) < 1.6)
		"saved_up":
			return absf(d) < 0.6 or (u > 0.2 and int(s) % 7 < 2 + int(u * 3.0) and absf(d) < 0.6 + 2.6 * u)
		"on_dodge":
			return absf(d - 2.2 * (absf(fmod(s, 8.0) - 4.0) - 2.0) / 2.0) < 0.75
	return absf(d) < 0.6


## Which seats hold something that is doing its job (a rune, or a thread or
## rule-bender that changes one). A thread with no rune after it is not.
func _live(stats: Dictionary) -> Array:
	var info: Dictionary = stats["slot_info"]
	var out: Array = []
	for i in build.line.size():
		out.append(build.line[i] != "" and not (info.get(i, {}) as Dictionary).has("unused"))
	return out


var _ring_key := ""
var _ring_tex: ImageTexture

## The ring's still lines as one picture: the ring itself (open at the start
## mark), each thread's pattern along it to the next seat, the dotted spokes,
## and the arcs that say which part gives which seats. It is drawn again only
## when something on the ring changes.
func _ring_picture(live: Array) -> Texture2D:
	var n := build.line.size()
	var gs := build.grip_slots()
	var key := "%d/%d" % [n, gs]
	for i in n:
		key += "/%s%s" % [build.line[i], "+" if live[i] else ""]
	if key == _ring_key and _ring_tex != null:
		return _ring_tex
	_ring_key = key
	var size := RING_HALF * 2 + 1
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var mid := Vector2(RING_HALF, RING_HALF)
	var step := 360.0 / float(maxi(n, 1))
	var first := seat_angle(0, n)
	# The arcs: the grip's seats, then the head's (none for a part that gives no seat).
	var arcs: Array = []
	if gs > 0 and n > 0:
		arcs.append([0, mini(gs, n) - 1])
	if n > gs:
		arcs.append([gs, n - 1])
	var ring_in := (RING_R - 5.5) * (RING_R - 5.5)
	var ring_out := (RING_R + 5.5) * (RING_R + 5.5)
	var arc_in := (ARC_R - 0.5) * (ARC_R - 0.5)
	var arc_out := (ARC_R + 0.5) * (ARC_R + 0.5)
	for y in size:
		for x in size:
			var v := Vector2(x, y) - mid
			var rr := v.length_squared()
			if rr < ring_in or rr > arc_out or (rr > ring_out and rr < arc_in):
				continue
			var deg := rad_to_deg(atan2(v.y, v.x))
			var turn := fposmod(first - deg, 360.0)      # degrees round from the first seat, the way it is read
			if rr >= arc_in:
				for a in arcs:
					if fposmod(turn - (float(a[0]) * step - ARC_PAD), 360.0) <= float(a[1] - a[0]) * step + ARC_PAD * 2.0:
						img.set_pixel(x, y, ARC_LINE)
				continue
			var d := sqrt(rr) - RING_R
			var i := int(turn / step)
			var id: String = build.line[i] if i < n - 1 else ""
			if id != "" and SwingBuild.FITTINGS[id]["kind"] == "band":
				var length := deg_to_rad(step) * RING_R - THREAD_SHORT * 2.0
				var along := deg_to_rad(turn - float(i) * step) * RING_R - THREAD_SHORT
				if along >= 0.0 and along <= length:
					if thread_pixel(id, along, d, along / length):
						var hot := absf(d) < 0.6
						img.set_pixel(x, y, (THREAD_HOT if hot else THREAD_WARM) if live[i] else (THREAD_IDLE_HOT if hot else THREAD_IDLE))
					continue
			# The plain ring: one pixel wide, open at the start mark on the left.
			if absf(d) < 0.5 and absf(fposmod(deg, 360.0) - 180.0) > START_GAP * 0.5:
				img.set_pixel(x, y, RING_LINE)
	for i in n:
		var a := deg_to_rad(seat_angle(i, n))
		var dir := Vector2(cos(a), sin(a))
		for k in int(SPOKE_TO - SPOKE_FROM):
			if k % 4 < 2:
				img.set_pixelv(Vector2i((mid + dir * (SPOKE_FROM + k)).round()), RING_LINE)
	_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


## What the head and the grip are called for this weapon ("Blade", "Grip").
func _part_word(head: bool) -> String:
	return str(PART_ROWS[build.weapon()][0 if head else 1][0])


## The words beside a part's arc: which part gives these seats, and how many.
## Under the arc when it is in the lower half of the ring, over it in the upper.
func _draw_arc_label(first: int, last: int, n: int, head: bool) -> void:
	var count := last - first + 1
	var text := "%s: %d %s" % [_part_word(head), count, "seat" if count == 1 else "seats"]
	var from := seat_angle(first, n) + ARC_PAD     # the arc runs from here ...
	var to := seat_angle(last, n) - ARC_PAD        # ... round to here (angles go down)
	var middle := deg_to_rad((from + to) * 0.5)
	var w := _head_width(text)
	# (The niche is an arch: there is less room across at the top than at the bottom.)
	var room := 94.0 if sin(middle) >= 0.0 else 73.0
	var x := clampf(RING_AT.x + cos(middle) * ARC_R - w * 0.5, RING_AT.x - room, RING_AT.x + room - w)
	var y: float
	if sin(middle) >= 0.0:
		# The lowest point the arc reaches: straight down if it passes there.
		var low := 1.0 if (from >= 90.0 and to <= 90.0) else maxf(sin(deg_to_rad(from)), sin(deg_to_rad(to)))
		y = RING_AT.y + low * ARC_R + 11.0
	else:
		var high := -1.0 if (from >= -90.0 and to <= -90.0) else minf(sin(deg_to_rad(from)), sin(deg_to_rad(to)))
		y = RING_AT.y + high * ARC_R - 5.0
	_head(text, Vector2(roundf(x), roundf(y)), FAINT)


## Centre: the spirit, and round it one seat for every socket the fitted parts
## give. The seats are the menu.
func _draw_ring(stats: Dictionary) -> void:
	var n := build.line.size()
	var gs := build.grip_slots()
	var live := _live(stats)
	root.draw_texture(_ring_picture(live), RING_AT - Vector2(RING_HALF, RING_HALF))
	if gs > 0 and n > 0:
		_draw_arc_label(0, mini(gs, n) - 1, n, false)
	if n > gs:
		_draw_arc_label(gs, n - 1, n, true)
	var start := Art.texture("spirit/forge/start_mark.png")
	if start != null:
		root.draw_texture(start, RING_AT + Vector2(-RING_R, 0) - Vector2(5, 5))
	# A little arrow between each pair of seats: the way the ring is read.
	var arrow := Art.texture("spirit/forge/ring_arrow.png")
	if arrow != null:
		for i in n - 1:
			var a := deg_to_rad(seat_angle(i, n) - 180.0 / float(n))
			root.draw_set_transform((RING_AT + Vector2(cos(a), sin(a)) * (RING_R - ARROW_IN)).round(), a - PI * 0.5, Vector2.ONE)
			root.draw_texture(arrow, Vector2(-3, -3))
		root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The spirit, twice its size like the weapon. It lights for a moment when
	# something is fitted. (It keeps still: nothing in the forge's backdrop moves.)
	var spirit := Art.texture("spirit/forge/spirit_forge_lit.png" if strike_t < LIT_TIME else "spirit/forge/spirit_forge.png")
	if spirit != null:
		root.draw_set_transform(RING_AT, 0.0, Vector2(2, 2))
		root.draw_texture(spirit, -Vector2(21, 28))
		root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The seats: clickable, the chosen one marked. A rare part's own seat (the
	# Gilded Grip's ruby one) has its own picture.
	var special := int(SwingBuild.grip_part(build.grip).get("ruby_slot", -1))
	var row_seat := _does_seat(stats)
	for i in n:
		var r := _slot_screen(i)
		buttons["slot:%d" % i] = r
		var seat := Art.texture("spirit/forge/seat_special.png" if i == special else ("spirit/forge/seat_selected.png" if i == selected else "spirit/forge/seat.png"))
		if seat != null:
			root.draw_texture(seat, r.position)
		else:
			root.draw_rect(r, WELL)
			root.draw_rect(r, AMBER if i == selected else FAINT, false, 1.0)
		var id: String = build.line[i]
		if id != "" and not (dragging and drag_from == i):
			# Something that is doing nothing here (a thread with no rune after it) is dimmed.
			_icon(_fit_kind(id), id, r.get_center(), 2.0, Color.WHITE if live[i] else Color(0.55, 0.6, 0.62, 0.8))
			if SwingBuild.FITTINGS[id].get("trigger", "") == "active":
				_badge(r.get_center())
		if hover == "slot:%d" % i or row_seat == i:
			root.draw_rect(r.grow(1), Color(1, 1, 1, 0.5), false, 1.0)
		if i == selected:
			_socket_focus(r.grow(2))


## The corners round the chosen seat: amber with a dark edge, so they read on the
## niche's dark and on a lit seat alike.
func _socket_focus(b: Rect2) -> void:
	var dark := Color("#19142a")
	var amber := Color("#ffc850")
	var arm := 6.0
	for corner in [[b.position, Vector2(1, 1)], [Vector2(b.end.x, b.position.y), Vector2(-1, 1)],
			[Vector2(b.position.x, b.end.y), Vector2(1, -1)], [b.end, Vector2(-1, -1)]]:
		var c: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		root.draw_rect(Rect2(c - d, Vector2(d.x * (arm + 2.0), d.y * 4.0)).abs(), dark)
		root.draw_rect(Rect2(c - d, Vector2(d.x * 4.0, d.y * (arm + 2.0))).abs(), dark)
		root.draw_rect(Rect2(c, Vector2(d.x * arm, d.y * 2.0)).abs(), amber)
		root.draw_rect(Rect2(c, Vector2(d.x * 2.0, d.y * arm)).abs(), amber)


# --- Forge effects -----------------------------------------------------------

func _update_fx(delta: float) -> void:
	t += delta
	strike_t += delta
	heat = move_toward(heat, 0.3, delta * 0.5)
	if finishing >= 0.0:
		heat = 0.0
	for list in [embers, sparks, steam]:
		var keep: Array = []
		for p in list:
			p[2] += delta
			if p[2] < p[3]:
				if list == sparks:
					p[1].y += 260.0 * delta  # sparks fall
				elif list == embers:
					p[1].x += sin(t * 3.0 + p[0].y) * 8.0 * delta
				p[0] += p[1] * delta
				keep.append(p)
		list.assign(keep)
	heat_mask.queue_redraw()
	heat_fill.queue_redraw()
	fx_top.queue_redraw()
	banner.queue_redraw()
	preview.queue_redraw()
	root.queue_redraw()


func _draw_heat_mask() -> void:
	if sword_size != Vector2.ZERO:
		heat_mask.draw_set_transform(sword_top, 0.0, Vector2(zoom, zoom))
		_draw_weapon(heat_mask)
		heat_mask.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Additive colour on the sword's own pixels: orange heat, hottest at the blade,
## and when it's finished, white-hot cooling to steel with a shine sweeping up.
func _draw_heat_fill() -> void:
	var r := Rect2(sword_top, sword_size)
	if finishing >= 0.0 and Art.texture("swing/forge-fx/heat_%s.png" % build.blade) != null:
		return  # the art's heat and shine strips take over (drawn on the banner layer)
	if finishing >= 0.0:
		var k := finishing / FINISH_TIME
		var white := clampf(1.0 - k * 2.5, 0.0, 1.0)
		heat_fill.draw_rect(r, Color(1.0, 0.75, 0.45, 0.8 * white))
		var sweep_y := lerpf(r.end.y, r.position.y - 20.0, clampf((k - 0.25) / 0.5, 0.0, 1.0))
		for i in 10:
			heat_fill.draw_rect(Rect2(r.position.x, sweep_y + i * 2.0 - 10.0, r.size.x, 2), Color(1, 1, 1, 0.08 * (5.0 - absf(i - 4.5))))
		return
	# No idle glow: the sword only flashes when a part goes on.
	var pulse := 0.0
	var steps := 0
	for i in steps:
		var y0 := r.position.y + r.size.y * i / steps
		var hotness := 1.0 - float(i) / steps  # the blade end is hottest
		var a := heat * pulse * (0.12 + 0.5 * hotness * hotness)
		heat_fill.draw_rect(Rect2(r.position.x, y0, r.size.x, r.size.y / steps + 1), Color(1.0, 0.42 + 0.3 * hotness, 0.12, a))
	if strike_t < 0.15:
		heat_fill.draw_rect(r, Color(1, 0.9, 0.7, 0.6 * (1.0 - strike_t / 0.15)))


## Draws one frame of a forge-fx strip, or nothing once it has finished.
func _fx_strip(ci: CanvasItem, name: String, pos: Vector2, start: float, hold := false, alpha := 1.0) -> void:
	var info: Dictionary = Art.json("swing/forge-fx/forge_fx.json").get("strips", {}).get(name, {})
	var tex := Art.texture("swing/forge-fx/%s.png" % name)
	if tex == null or info.is_empty() or t < start:
		return
	var frames := int(info["frames"])
	var frame := int((t - start) * float(info["fps"]))
	if frame >= frames:
		if not hold:
			return
		frame = frames - 1
	var o = info.get("origin")
	var origin := Vector2.ZERO if o == null else Vector2(o[0], o[1])
	Art.draw_strip(ci, tex, frames, frame, pos, origin, false, Color(1, 1, 1, alpha), 1.0)


func _draw_fx() -> void:
	for p in playing:
		if p[0] == "sparks":
			_fx_strip(fx_top, "sparks", p[1], p[2])
	for p in embers:
		var k: float = p[2] / p[3]
		var c := Color(1.0, 0.55 + 0.3 * (1.0 - k), 0.2, (1.0 - k) * 0.9)
		fx_top.draw_rect(Rect2((p[0] as Vector2).round(), Vector2(1, 1)), c)
	for p in sparks:
		var k: float = p[2] / p[3]
		var c := Color(1.0, 0.85 - 0.4 * k, 0.4 - 0.3 * k, 1.0 - k)
		var tail: Vector2 = p[1] * 0.02
		fx_top.draw_line(p[0], p[0] - tail, c, 1.0)
	if strike_t < 0.25:
		var k := strike_t / 0.25
		fx_top.draw_circle(strike_at, 4.0 + k * 22.0, Color(1.0, 0.8, 0.5, 0.5 * (1.0 - k)))
		fx_top.draw_arc(strike_at, 6.0 + k * 30.0, 0.0, TAU, 24, Color(1.0, 0.7, 0.3, 1.0 - k), 1.0)
	for p in steam:
		var k: float = p[2] / p[3]
		fx_top.draw_circle(p[0], 2.0 + k * 7.0, Color(0.6, 0.65, 0.7, 0.18 * (1.0 - k)))


func _draw_banner() -> void:
	# Hammer strikes and steam (normal blend).
	var keep: Array = []
	for p in playing:
		if t - float(p[2]) < 1.5:
			keep.append(p)
		if p[0] != "sparks":
			_fx_strip(banner, p[0], p[1], p[2])
	playing = keep
	if finishing < 0.0:
		return
	var heat_tex := Art.texture("swing/forge-fx/heat_%s.png" % build.blade)
	var banner_tex := Art.texture("swing/forge-fx/forged_banner.png")
	if banner_tex != null and (heat_tex != null or build.weapon() != "sword"):
		var start := t - finishing
		if heat_tex != null:
			var blade_pos := sword_top + Vector2(SwordArt.blade_x(build.blade, "forge"), 0) * zoom
			var bsrc := SwordArt.blade_size(build.blade, "forge")
			var bsize := bsrc * zoom
			# Heat cools from white-hot to steel, then a glint sweeps up the blade.
			var heat_k := (finishing - 0.1) * 10.0
			if finishing >= 0.1 and heat_k < 8.0:
				var hf := mini(int(heat_k), 7)
				banner.draw_texture_rect_region(heat_tex, Rect2(blade_pos, bsize), Rect2(hf * bsrc.x, 0, bsrc.x, bsrc.y))
			var shine_tex := Art.texture("swing/forge-fx/shine_%s.png" % build.blade)
			var shine_k := (finishing - 0.9) * 16.0
			if shine_tex != null and finishing >= 0.9 and shine_k < 8.0:
				banner.draw_texture_rect_region(shine_tex, Rect2(blade_pos, bsize), Rect2(mini(int(shine_k), 7) * bsrc.x, 0, bsrc.x, bsrc.y))
		# (A bow, a hammer and a staff have no heat pictures of their own: the glow
		# drawn in code, clipped to the weapon, does it; see _draw_heat_fill.)
		var fade := clampf((FINISH_TIME - finishing) / 0.3, 0.0, 1.0)
		_fx_strip(banner, "forged_banner", Vector2(CENTRE_X + 20.0, sword_top.y + 40), start + 0.2, true, fade)
		return
	var k := finishing / FINISH_TIME
	var a := clampf(k * 4.0, 0.0, 1.0) * clampf((1.0 - k) * 4.0, 0.0, 1.0)
	var y := 150.0 - 8.0 * (1.0 - clampf(k * 3.0, 0.0, 1.0))
	banner.draw_rect(Rect2(0, y - 22, 640, 34), Color(0, 0, 0, 0.55 * a))
	var f := Art.font("Silkscreen-Regular")
	banner.draw_string_outline(f, Vector2(0, y + 4), "FORGED!", HORIZONTAL_ALIGNMENT_CENTER, 640, 16, 4, Color(0.1, 0.05, 0.02, a))
	banner.draw_string(f, Vector2(0, y + 4), "FORGED!", HORIZONTAL_ALIGNMENT_CENTER, 640, 16, Color(1.0, 0.75, 0.3, a))
	var names: Array = []
	for e in build.compute()["effects"]:
		names.append(SwingBuild.FITTINGS[e["id"]]["name"])
	var sub := "%s + %s" % [_name(build.blade), _name(build.grip)]
	if not names.is_empty():
		sub += ":  " + ", ".join(names)
	banner.draw_string(Art.font("PixelifySans-Regular"), Vector2(0, y + 18), sub, HORIZONTAL_ALIGNMENT_CENTER, 640, 11, Color(0.9, 0.86, 0.8, a))


## How "what it does" is set out, roomiest first. The first one that fits is used.
## icon: the rune's 26 px picture beside its words. full: every rune's whole
## sentence; without it only the rune you point at (or the chosen seat's) is
## written out and the others keep to their names, so a full ring still fits.
const DOES_HINT := "Point at a seat to read it."
const DOES_PLANS := [
	{"icon": true, "text_x": 33.0, "line": 13.0, "gap": 7.0, "full": true},
	{"icon": false, "text_x": 8.0, "line": 12.0, "gap": 5.0, "full": true},
	{"icon": false, "text_x": 8.0, "line": 12.0, "gap": 4.0, "full": false},
	{"icon": false, "text_x": 8.0, "line": 11.0, "gap": 2.0, "full": false},
]


## The seat "what it does" is about: the one the mouse is on, else the chosen one.
func _focus_seat() -> int:
	if hover.begins_with("slot:"):
		return int(hover.split(":")[1])
	return selected


## The rune (its number among the effects) that the mouse or the chosen seat
## points at: the rune in that seat, or the rune a thread there changes. A row
## of "what it does" under the mouse counts too. -1: none.
func _focus_effect(stats: Dictionary) -> int:
	if hover.begins_with("does:"):
		return int(hover.split(":")[1])
	var seat := _focus_seat()
	var effects: Array = stats["effects"]
	for ei in effects.size():
		if int(effects[ei]["slot"]) == seat:
			return ei
	var si: Dictionary = (stats["slot_info"] as Dictionary).get(seat, {})
	return int(si.get("band", -1))


## The seat of the rune whose row in "what it does" the mouse is on (-1: none),
## so the ring can show which seat the row is about.
func _does_seat(stats: Dictionary) -> int:
	if not hover.begins_with("does:"):
		return -1
	var ei := int(hover.split(":")[1])
	var effects: Array = stats["effects"]
	return int(effects[ei]["slot"]) if ei < effects.size() else -1


## A rune's name for its row. With its sentence left out, an active rune's row
## says which button fires it (the sentence would have).
func _does_title(e: Dictionary, with_key: bool) -> String:
	var name := str(SwingBuild.FITTINGS[e["id"]]["name"])
	if with_key and e["trigger"] == "active" and int(e.get("button", -1)) >= 0 and int(e["button"]) < keys.size():
		return "%s: %s" % [name, keys[int(e["button"])]]
	return name


## Sets out "what it does" for one plan: {rows: [{title, lines, h}], notes, hint, height}.
## idle: the fittings doing nothing, as {seat, name, why}. seat: the seat pointed
## at. room: the height there is (the hint is only added when it still fits).
func _plan_does(effects: Array, idle: Array, plan: Dictionary, focus: int, seat: int, width: float, room: float) -> Dictionary:
	var rows: Array = []
	var height := 0.0
	var line: float = plan["line"]
	for ei in effects.size():
		var e: Dictionary = effects[ei]
		var lines: Array = []
		if plan["full"] or ei == focus:
			lines = _wrap(SwingBuild.sentence(e, keys), width - float(plan["text_x"]))
		var h := line + lines.size() * line
		if plan["icon"]:
			h = maxf(h, 28.0)
		rows.append({"title": _does_title(e, lines.is_empty()), "lines": lines, "h": h})
		height += h + float(plan["gap"])
	# What does nothing, and why. On a crowded ring only the one pointed at says
	# why; the others are named in one line.
	var note_lines: Array = []
	var named: PackedStringArray = []
	for n in idle:
		if plan["full"] or int(n["seat"]) == seat:
			note_lines.append(_wrap("%s: %s" % [n["name"], n["why"]], width))
		else:
			named.append(str(n["name"]))
	if not named.is_empty():
		note_lines.append(_wrap("Doing nothing here: %s." % ", ".join(named), width))
	for l in note_lines:
		height += (l as Array).size() * line + 4.0
	# With only one written out, a last line says how to read the others.
	var hint: Array = []
	if not plan["full"] and effects.size() + idle.size() >= 2:
		var words := _wrap(DOES_HINT, width)
		if height + words.size() * line <= room:
			hint = words
			height += hint.size() * line
	return {"rows": rows, "notes": note_lines, "hint": hint, "height": height}


## Right: a row per rune, its name and one sentence; then the fittings that do
## nothing (and why). It never runs off its plate: with more to say the rows
## close up, and with a full ring only the rune you point at is written out.
## Pointing at a row marks its seat on the ring; clicking it chooses that seat.
func _draw_does(stats: Dictionary) -> void:
	var plate := does_rect(stats)
	var x := plate.position.x + 8.0
	var width := plate.size.x - 16.0
	_head("What it does", Vector2(x, plate.position.y + 14), DIM)
	var effects: Array = stats["effects"]
	var info: Dictionary = stats["slot_info"]
	var top := plate.position.y + 22.0
	var bottom := plate.end.y - 7.0
	var idle: Array = []
	for i in build.line.size():
		var si: Dictionary = info.get(i, {})
		if build.line[i] != "" and si.has("unused"):
			idle.append({"seat": i, "name": str(SwingBuild.FITTINGS[build.line[i]]["name"]), "why": str(si.get("why", "does nothing here."))})
	if effects.is_empty() and idle.is_empty():
		# (With threads but no rune, the notes below say why nothing happens instead.)
		var ey := top + 10.0
		for l in _wrap("Nothing fitted yet. Pick a rune on the left, then click a seat.", width):
			_body(l, Vector2(x, ey), DIM)
			ey += 13
	var focus := _focus_effect(stats)
	var plan: Dictionary = DOES_PLANS[0]
	var set_out := {}
	for pl in DOES_PLANS:
		plan = pl
		set_out = _plan_does(effects, idle, pl, focus, _focus_seat(), width, bottom - top)
		if float(set_out["height"]) <= bottom - top:
			break
	does_fits = float(set_out["height"]) <= bottom - top
	does_plan = DOES_PLANS.find(plan)
	var y := top
	var line_h: float = plan["line"]
	var rows: Array = set_out["rows"]
	for ei in effects.size():
		var row: Dictionary = rows[ei]
		var h: float = row["h"]
		if y + h > bottom + 0.5:
			# (Only with more runes than any weapon in the prototype can hold.)
			_body("and %d more" % (effects.size() - ei), Vector2(x, bottom - 2), DIM)
			return
		var e: Dictionary = effects[ei]
		var key := "does:%d" % ei
		buttons[key] = Rect2(plate.position.x + 4.0, y - 1.0, plate.size.x - 8.0, h + 2.0)
		# Its bar is lit when this is the rune being pointed at (on the ring or here).
		var on := ei == focus
		root.draw_rect(Rect2(x, y, 2, h), FOCUS if on else FAINT)
		if plan["icon"]:
			_icon("runes", e["id"], Vector2(x + 18, y + 14))
			if e["trigger"] == "active":
				_badge(Vector2(x + 18, y + 14))
		var ly := y + line_h - 2.0
		_body(row["title"], Vector2(x + float(plan["text_x"]), ly), AMBER if on or plan["full"] else INK)
		for l in row["lines"]:
			ly += line_h
			_body(l, Vector2(x + float(plan["text_x"]), ly))
		y += h + float(plan["gap"])
	for lines in set_out["notes"]:
		for l in lines:
			if y + line_h > bottom + 0.5:
				return
			_body(l, Vector2(x, y + line_h - 3.0), DIM)
			y += line_h
		y += 4.0
	for l in set_out["hint"]:
		if y + line_h > bottom + 0.5:
			return
		_body(l, Vector2(x, y + line_h - 3.0), FAINT)
		y += line_h


var does_plan := 0      # which of DOES_PLANS the last "what it does" used
var does_fits := true   # the last "what it does" fitted its plate (checked by tests/smoke_forge.gd)


## What each number is called, and where it sits on the stats plate (column, row).
## One column since the forge spirit took the middle of the screen: the plate is
## too narrow for two.
const STAT_ROWS := [
	["damage", 0, 0], ["speed", 0, 1], ["reach", 0, 2], ["crit", 0, 3], ["crit_damage", 0, 4], ["slots", 0, 5], ["move", 0, 6],
]
## A bow's: how far its arrows fly where a sword has its reach, and walking while
## shooting. (Range is a share of the shortbow's, as reach is of the broadsword's.)
const BOW_STAT_ROWS := [
	["damage", 0, 0], ["speed", 0, 1], ["range", 0, 2], ["crit", 0, 3], ["crit_damage", 0, 4], ["slots", 0, 5], ["shoot_move", 0, 6],
]
## A hammer's and a staff's have more: how big the patch of floor a slam hits is;
## a staff's spell size, written "Blast", and what a chain costs in mana.
const HAMMER_STAT_ROWS := [
	["damage", 0, 0], ["speed", 0, 1], ["reach", 0, 2], ["impact", 0, 3], ["crit", 0, 4], ["crit_damage", 0, 5], ["slots", 0, 6], ["move", 0, 7],
]
const STAFF_STAT_ROWS := [
	["damage", 0, 0], ["speed", 0, 1], ["range", 0, 2], ["size", 0, 3], ["crit", 0, 4], ["crit_damage", 0, 5], ["mana", 0, 6], ["slots", 0, 7],
	["cast_move", 0, 8],
]
## The picture beside a number, where it isn't called what the number is.
const STAT_ICONS := {"shoot_move": "move", "cast_move": "move"}


## Which numbers a weapon shows (`s` is its compute()).
static func stat_rows(s: Dictionary) -> Array:
	match s.get("weapon", "sword"):
		"bow": return BOW_STAT_ROWS
		"hammer": return HAMMER_STAT_ROWS
		"staff": return STAFF_STAT_ROWS
	return STAT_ROWS


## A weapon's numbers as the stats plate shows them.
static func stat_values(s: Dictionary) -> Dictionary:
	var out := {
		"damage": float(s["damage"]),
		"speed": roundf(float(s["speed"]) * 100.0),
		"crit": roundf(float(s["crit"]) * 100.0),
		"crit_damage": float(s["crit_damage"]),
		"slots": float((s["line"] as Array).size()),
	}
	var walk := roundf(float(s.get("swing_move", SwingBuild.SWING_MOVE)) * 100.0)
	match s.get("weapon", "sword"):
		"bow":
			out["range"] = roundf(float(s.get("range", SwingBuild.BOW_RANGE)) / SwingBuild.BOW_RANGE * 100.0)
			out["shoot_move"] = walk
		"staff":
			# (Range is a share of the shortbow's for a staff too, so the two can be compared.)
			out["range"] = roundf(float(s.get("range", SwingBuild.STAFF_RANGE)) / SwingBuild.BOW_RANGE * 100.0)
			out["size"] = roundf(float(s.get("size", 1.0)) * 100.0)
			out["mana"] = float(s.get("mana", 0.0))
			out["cast_move"] = walk
		"hammer":
			out["reach"] = roundf(float(s["reach"]) * 100.0)
			out["impact"] = roundf(float(s.get("impact", SwingBuild.HAMMER_IMPACT)) / SwingBuild.HAMMER_IMPACT * 100.0)
			out["move"] = walk
		_:
			out["reach"] = roundf(float(s["reach"]) * 100.0)
			out["move"] = walk
	return out


static func _plain(v: float) -> String:
	return ("%d" % roundi(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % (roundf(v * 10.0) / 10.0))


static func stat_text(key: String, v: float) -> String:
	match key:
		"damage": return "Damage %s" % _plain(v)
		"speed": return "Speed %d%%" % roundi(v)
		"reach": return "Reach %d%%" % roundi(v)
		"range": return "Range %d%%" % roundi(v)
		"shoot_move": return "Walk, shooting %d%%" % roundi(v)     # ("Walk while ..." is too wide with a change beside it)
		"cast_move": return "Walk, casting %d%%" % roundi(v)
		"impact": return "Impact %d%%" % roundi(v)
		"size": return "Blast %d%%" % roundi(v)     # ("Spell size" is too wide with a change beside it)
		"mana": return "Mana a chain %s" % _plain(v)
		"crit": return "Crit %d%%" % roundi(v)
		"crit_damage": return "Crit hits x%s" % _plain(v)
		"slots": return "Seats %d" % roundi(v)
		"move": return "Walk, swinging %d%%" % roundi(v)
	return ""


## The change in a number, as it is written beside it: "+8.3", "-60%". Empty for no change.
static func delta_text(key: String, d: float) -> String:
	if absf(d) < 0.05:
		return ""
	var amount := _plain(absf(d))
	if key in ["speed", "reach", "crit", "move", "range", "shoot_move", "cast_move", "impact", "size"]:
		amount += "%"
	return ("+" if d > 0.0 else "-") + amount


## The part whose effect the stats plate should show: a blade, grip or pommel in
## the tray that isn't the one fitted, under the mouse (or the keys' cursor).
func _compare_id() -> String:
	if TABS[tab] != "sword":
		return ""
	var cards := _cards()
	var i := -1
	if hover.begins_with("card:"):
		i = int(hover.split(":")[1])
	elif keys_on_cards:
		i = card
	if i < 0 or i >= cards.size() or cards[i]["locked"]:
		return ""
	var id: String = cards[i]["id"]
	return "" if _on_sword(id) else id


## What the sword's numbers would be with this blade, grip or pommel fitted.
func stats_with(id: String) -> Dictionary:
	var b := SwingBuild.new()
	b.set_data(build.get_data())
	_fit_part(b, id)
	return b.compute()


## The weapon's numbers, on a bordered plate of their own. While the cursor is on
## a part you could fit, each number it would change shows the change beside it:
## green with a plus for a gain, red with a minus for a loss.
func _draw_stats(stats: Dictionary) -> void:
	var plate := stats_rect(stats)
	var at := plate.position
	var with_id := _compare_id()
	var now := stat_values(stats)
	var then := now if with_id == "" else stat_values(stats_with(with_id))
	if with_id == "":
		_head("Stats", at + Vector2(14, 14), INK)
		_head(_cut_head(_name(build.blade), plate.size.x - 60), at + Vector2(14, 14), DIM, 8, plate.size.x - 24, HORIZONTAL_ALIGNMENT_RIGHT)
	elif stat_changes(now, then).is_empty():
		_head("The same numbers", at + Vector2(14, 14), DIM)
	else:
		_head(_cut_head("With the " + _name(with_id), plate.size.x - 24), at + Vector2(14, 14), FOCUS)
	var rows := stat_rows(stats)
	for row in rows:
		var key: String = row[0]
		var d: float = float(then[key]) - float(now[key])
		_stat(key, stat_text(key, now[key]), at + stat_at(row, rows), delta_text(key, d), d > 0.0)


## Where a number sits on the stats plate (its text baseline), from the plate's corner.
static func stat_at(row: Array, _rows: Array = STAT_ROWS) -> Vector2:
	return Vector2(8, STAT_HEAD + 9.0 + int(row[2]) * STAT_LINE)


## How much room a number has across the plate, with its change beside it.
static func stat_room() -> float:
	return RIGHT.size.x - 8.0 - 6.0


## The numbers a part would change: {name: "+8.3"}.
static func stat_changes(now: Dictionary, then: Dictionary) -> Dictionary:
	var out := {}
	for key in now:
		var d := delta_text(key, float(then[key]) - float(now[key]))
		if d != "":
			out[key] = d
	return out


## How wide a number is on the plate with a change beside it (icon, words, change).
func stat_width(text: String, change: String) -> float:
	var f := Art.font("PixelifySans-Regular")
	var w := 12.0 + f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	if change != "":
		w += 4.0 + f.get_string_size(change, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	return w


## One number on the stats plate: its icon, the words, then the change a hovered
## part would make. pos is the text baseline. The icon lights for a moment when
## the number itself changes.
func _stat(name: String, text: String, pos: Vector2, change := "", gain := true) -> void:
	if _stat_last.has(name) and _stat_last[name] != text:
		_stat_lit[name] = t
	_stat_last[name] = text
	var lit: bool = t - float(_stat_lit.get(name, -9.0)) < 1.2
	var icon := Art.texture("swing/ui/stat_%s%s.png" % [STAT_ICONS.get(name, name), "_hot" if lit else ""])
	var x := pos.x
	if icon != null:
		root.draw_texture(icon, Vector2(x, pos.y - 8))
	x += 12.0
	_body(text, Vector2(x, pos.y), AMBER if lit else INK)
	if change != "":
		x += Art.font("PixelifySans-Regular").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 4.0
		_body(change, Vector2(x, pos.y), GAIN if gain else LOSS)
