extends CanvasLayer
## On-screen info, drawn from the art in art/hud at the game's own 640x360.
## Each player gets a health bar and dodge pips in a top corner and their swing
## path in the bottom corner. The test arena also shows kills, the chain and the
## control hints.

var player = null          # player one
var players: Array = []
var kills := 0
var spawning := true
var mode := "arena"        # "arena" or "cave"
var panel: Control
var pause_button: Button
var trail: Array = []      # per player: the pale bar that trails behind lost health, 0..1

signal pause_pressed

const Art := preload("res://scripts/art.gd")
const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const PLAYER_COLORS := Art.PLAYER_COLORS
const INK := Color("#e8e4bc")
const DIM := Color("#8ba688")
const FAINT := Color("#5f8072")
const AMBER := Color("#ffc850")
const TEAL := Color("#86d4a4")
const VIOLET := Color("#a878d0")
const EMBER := Color("#f06a40")
const PLATE := Color("#19142a")
const SHADE := Color(0.098, 0.078, 0.165, 0.5)   # PLATE, half see-through
const SIZE := Vector2(640, 360)
const MARGIN := 10.0
const BAR := Vector2(92, 12)       # hp_frame.png
const FILL_AT := Vector2(6, 3)     # where the bar itself sits inside the frame
const FILL := Vector2(80, 6)
const CHIP_H := 14.0


func _ready() -> void:
	layer = 5
	panel = Control.new()
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.draw.connect(_draw_hud)
	# Clickable spawn pause, top right (P / Start does the same). Arena only.
	pause_button = Button.new()
	pause_button.size = Vector2(126, 18)
	pause_button.position = Vector2(SIZE.x - MARGIN - pause_button.size.x, 6)
	pause_button.focus_mode = Control.FOCUS_NONE
	var f := Art.font("Silkscreen-Regular")
	if f != null:
		pause_button.add_theme_font_override("font", f)
	pause_button.add_theme_font_size_override("font_size", 8)
	var idle := Art.nine("swing/ui/button.png", 3)
	var hot := Art.nine("swing/ui/button_hot.png", 3)
	if idle != null and hot != null:
		pause_button.add_theme_stylebox_override("normal", idle)
		pause_button.add_theme_stylebox_override("hover", hot)
		pause_button.add_theme_stylebox_override("pressed", hot)
		pause_button.add_theme_color_override("font_color", INK)
		pause_button.add_theme_color_override("font_hover_color", PLATE)
		pause_button.add_theme_color_override("font_pressed_color", PLATE)
		pause_button.add_theme_color_override("font_hover_pressed_color", PLATE)
	pause_button.pressed.connect(func(): pause_pressed.emit())
	panel.add_child(pause_button)


func _process(delta: float) -> void:
	pause_button.visible = mode == "arena" and players.size() <= 1
	pause_button.text = "PAUSE ENEMIES (P)" if spawning else "RESUME ENEMIES (P)"
	# Lost health lingers as a pale bar for a moment, then drains away.
	trail.resize(players.size())
	for i in players.size():
		var p = players[i]
		if not is_instance_valid(p):
			continue
		var frac := clampf(p.hp / p.max_hp, 0.0, 1.0)
		trail[i] = maxf(frac, (trail[i] if trail[i] != null else frac) - delta * 0.45)
	panel.queue_redraw()


func _head(text: String, pos: Vector2, col: Color, size := 8, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	panel.draw_string(Art.font("Silkscreen-Regular"), pos, text.to_upper(), align, width, size, col)


func _head_width(text: String) -> float:
	return ceilf(Art.font("Silkscreen-Regular").get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)


## One cell of a row of chips. `look` is the chip image: "", "rune", "band", "empty" or "fired".
func _chip(text: String, x: float, y: float, w: float, look: String, col: Color, tint := Color.WHITE) -> void:
	var file := "hud/chip.png" if look == "" else "hud/chip_%s.png" % look
	if not Art.draw_nine(panel, file, Rect2(x, y, w, CHIP_H), 4, tint):
		panel.draw_rect(Rect2(x, y, w, CHIP_H), Color(PLATE.r, PLATE.g, PLATE.b, tint.a))
		panel.draw_rect(Rect2(x, y, w, CHIP_H), Color(col.r, col.g, col.b, tint.a), false, 1.0)
	if text != "":
		_head(text, Vector2(x + 5, y + 10), col)


func _draw_hud() -> void:
	if players.is_empty() and player != null:
		players = [player]
	if players.is_empty():
		return
	var many := players.size() > 1

	for i in players.size():
		var p = players[i]
		if not is_instance_valid(p):
			continue
		var right := i % 2 == 1
		var lead := 26.0 if many else 0.0     # room for the pennant and "P1"
		var x := SIZE.x - MARGIN - lead - BAR.x if right else MARGIN
		var y := 7.0
		var who: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
		var side := "a" if i % 2 == 0 else "b"
		# A soft dark backing, so the words and pips read over bright floor.
		panel.draw_rect(Rect2(x - 4, y - 3, lead + BAR.x + 8, 29), SHADE)
		if many:
			var tag := Art.texture("hud/tag_%s.png" % side)
			if tag != null:
				panel.draw_texture(tag, Vector2(x, y))
			else:
				panel.draw_rect(Rect2(x, y, 4, 12), who)
			_head("P%d" % (i + 1), Vector2(x + 9, y + 10), who)
		var bar := Vector2(x + lead, y)
		# Health: the frame, the pale trail of what was just lost, then what's left.
		var frac := clampf(p.hp / p.max_hp, 0.0, 1.0)
		var frame := Art.texture("hud/hp_frame.png")
		if frame != null:
			panel.draw_texture(frame, bar)
		else:
			panel.draw_rect(Rect2(bar, BAR), Color(0, 0, 0, 0.6))
		var was: float = trail[i] if i < trail.size() and trail[i] != null else frac
		var lost := Art.texture("hud/hp_lost.png")
		if lost != null and was > frac:
			var lw := roundf(FILL.x * was)
			panel.draw_texture_rect_region(lost, Rect2(bar + FILL_AT, Vector2(lw, FILL.y)), Rect2(0, 0, lw, FILL.y))
		var fill := Art.texture("hud/hp_fill_%s.png" % side)
		var fw := ceilf(FILL.x * frac)
		if fill != null:
			panel.draw_texture_rect_region(fill, Rect2(bar + FILL_AT, Vector2(fw, FILL.y)), Rect2(0, 0, fw, FILL.y))
		else:
			panel.draw_rect(Rect2(bar + FILL_AT, Vector2(fw, FILL.y)), who)
		_head("%d" % roundi(p.hp), Vector2(bar.x + 40, y + 22), FAINT, 8, 50, HORIZONTAL_ALIGNMENT_RIGHT)
		# Dodge charges, or the bad news.
		if p.is_down:
			_head("Knocked out", Vector2(bar.x + 2, y + 22), EMBER)
		else:
			var full_pip := Art.texture("hud/pip_full.png")
			var empty_pip := Art.texture("hud/pip_empty.png")
			for d in maxi(p.DODGE_MAX_CHARGES, p.dodge_charges):
				var at := Vector2(bar.x + 2 + d * 10, y + 15)
				var have: bool = d < p.dodge_charges
				if full_pip == null or empty_pip == null:
					panel.draw_circle(at + Vector2(4, 4), 3.0, TEAL if have else FAINT)
					continue
				panel.draw_texture(full_pip if have else empty_pip, at)
				# The next charge fills in as it comes back.
				if d == p.dodge_charges and p.dodge_charges < p.DODGE_MAX_CHARGES:
					var back: float = clampf(p.dodge_refill / p.DODGE_REFILL, 0.0, 1.0)
					panel.draw_texture(full_pip, at, Color(1, 1, 1, back * 0.55))
		_draw_path(p, i, right)

	if mode == "arena":
		_head("Kills %d" % kills, Vector2(MARGIN, 46), INK)
		if not spawning:
			_head("Enemies paused (P / Start)", Vector2(MARGIN, 58), AMBER)
		if player.knocked_out_timer > 0.0:
			_head("Knocked out! Back to the start.", Vector2(0, 84), EMBER, 16, SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
		if not many:
			_draw_chain(player)
			var hint := "Tab / Y: forge    Click / X: attack    Space / A: dodge"
			panel.draw_string(Art.font("PixelifySans-Regular"), Vector2(0, SIZE.y - 8), hint, HORIZONTAL_ALIGNMENT_RIGHT, SIZE.x - MARGIN, 11, DIM)


## The blade's chain above the swing path; the last hit is the finisher. (Arena, one player.)
func _draw_chain(p) -> void:
	var steps: Array = p.weapon.get("steps", [])
	var x := MARGIN
	var y := SIZE.y - 54.0
	_head("Chain", Vector2(x, y - 5), DIM)
	for i in steps.size():
		var label: String = steps[i]["move"]
		if i == steps.size() - 1:
			label += " (finisher)"
		var w := _head_width(label) + 10.0
		var active: bool = p.current_step == i
		var next: bool = p.current_step < 0 and p.step_index == i and p.step_index > 0
		if active:
			_chip(label, x, y, w, "fired", PLATE)
		elif next:
			_chip(label, x, y, w, "", INK)
		else:
			_chip(label, x, y, w, "empty", DIM)
		x += w + 4.0


## The swing path, bottom of the grip to the tip; slots light up when they fire.
func _draw_path(p, i: int, right: bool) -> void:
	var line: Array = p.weapon.get("line", [])
	if line.is_empty() or not p.weapon.has("blade"):
		return
	var info: Dictionary = p.weapon.get("slot_info", {})
	# Measure first, so the right-hand player's line can end at the screen edge.
	var cells: Array = []
	var total := 0.0
	for s in line.size():
		var id: String = line[s]
		var label := "empty" if id == "" else str(SwingBuild.FITTINGS[id]["name"])
		var w := _head_width(label) + 10.0
		cells.append([label, w])
		total += w + (10.0 if s < line.size() - 1 else 0.0)
	var x := SIZE.x - MARGIN - total if right else MARGIN
	var y := SIZE.y - 20.0
	var title := "Swing path"
	if players.size() > 1:
		title = "P%d swing path" % (i + 1)
	var title_x := x
	if right:
		title_x = minf(x, SIZE.x - MARGIN - _head_width(title))
	panel.draw_rect(Rect2(title_x - 4, y - 14, _head_width(title) + 8, 12), SHADE)
	_head(title, Vector2(title_x, y - 5), DIM)
	for s in line.size():
		var id: String = line[s]
		var label: String = cells[s][0]
		var w: float = cells[s][1]
		var look := "empty"
		var col := FAINT
		if id != "" and not info.get(s, {}).has("unused"):
			var kind: String = SwingBuild.FITTINGS[id]["kind"]
			look = "rune" if kind == "rune" else ("band" if kind == "band" else "")
			col = AMBER if kind == "rune" else (TEAL if kind == "band" else VIOLET)
		_chip(label, x, y, w, look, col)
		# It flashes ember, with dark words, as it fires.
		var since: float = p.game_time - float(p.slot_flash.get(s, -99.0))
		var glow := clampf(1.0 - since / 0.45, 0.0, 1.0)
		if glow > 0.0 and id != "":
			_chip("", x, y, w, "fired", PLATE, Color(1, 1, 1, glow))
			_head(label, Vector2(x + 5, y + 10), Color(PLATE.r, PLATE.g, PLATE.b, glow))
		x += w
		if s < line.size() - 1:
			_head(">", Vector2(x + 3, y + 10), FAINT)
			x += 10.0
