extends CanvasLayer
## On-screen info. Each player gets a small panel (health and dodge) in a top
## corner and their swing path in the bottom corner. The test arena also shows
## kills, the chain and the control hints.

var player = null          # player one
var players: Array = []
var kills := 0
var spawning := true
var mode := "arena"        # "arena" or "cave"
var panel: Control
var pause_button: Button

signal pause_pressed

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")
const PLAYER_COLORS := [Color("#5fb8ff"), Color("#ff9a4a"), Color("#8fe08a"), Color("#e08ad8")]


func _ready() -> void:
	layer = 5
	panel = Control.new()
	# UI is laid out at 1280x720 and drawn at half scale onto the 640x360 screen,
	# which the window then doubles, so text stays sharp.
	scale = Vector2(0.5, 0.5)
	panel.size = Vector2(1280, 720)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.draw.connect(_draw_hud)
	# Clickable spawn pause, top right (P / Start does the same). Arena only.
	pause_button = Button.new()
	pause_button.position = Vector2(1280 - 250, 16)
	pause_button.size = Vector2(230, 44)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.add_theme_font_size_override("font_size", 18)
	pause_button.pressed.connect(func(): pause_pressed.emit())
	panel.add_child(pause_button)


func _process(_delta: float) -> void:
	pause_button.visible = mode == "arena" and players.size() <= 1
	pause_button.text = "Pause enemies (P)" if spawning else "Resume enemies (P)"
	panel.queue_redraw()


func _draw_hud() -> void:
	if players.is_empty() and player != null:
		players = [player]
	if players.is_empty():
		return
	var font := ThemeDB.fallback_font
	var size := panel.size
	var many := players.size() > 1

	for i in players.size():
		var p = players[i]
		if not is_instance_valid(p):
			continue
		var right := i % 2 == 1
		var x := size.x - 260.0 if right else 20.0
		var y := 20.0
		var tag: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
		# Health
		var hp_frac := clampf(p.hp / p.max_hp, 0.0, 1.0)
		panel.draw_rect(Rect2(x, y, 240, 18), Color(0, 0, 0, 0.6))
		panel.draw_rect(Rect2(x, y, 240 * hp_frac, 18), Color(0.85, 0.25, 0.3))
		var hp_text := "HP %d / %d" % [roundi(p.hp), roundi(p.max_hp)]
		if many:
			hp_text = "P%d  %s" % [i + 1, hp_text]
			panel.draw_rect(Rect2(x - 6, y, 4, 18), tag)
		if p.is_down:
			hp_text = "P%d  knocked out" % (i + 1) if many else "Knocked out"
		panel.draw_string(font, Vector2(x + 6, y + 14), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		# Dodge charges
		var dodge_y := y + 40.0
		panel.draw_string(font, Vector2(x, dodge_y), "Dodge", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.78, 0.85))
		for d in maxi(p.DODGE_MAX_CHARGES, p.dodge_charges):
			var full: bool = d < p.dodge_charges
			var c := Color(0.5, 0.85, 1.0) if full else Color(0.3, 0.32, 0.38)
			panel.draw_circle(Vector2(x + 52 + d * 16, dodge_y - 5), 6.0, c)
		if p.dodge_charges < p.DODGE_MAX_CHARGES:
			var frac: float = p.dodge_refill / p.DODGE_REFILL
			panel.draw_arc(Vector2(x + 52 + p.dodge_charges * 16, dodge_y - 5), 6.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, Color(0.5, 0.85, 1.0), 2.0)
		_draw_path(p, i, right)

	if mode == "arena":
		var y := 84.0
		panel.draw_string(font, Vector2(20, y), "Kills: %d" % kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.9, 0.9))
		if not spawning:
			panel.draw_string(font, Vector2(20, y + 22), "Enemies paused (P / Start)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.8, 0.4))
		if player.knocked_out_timer > 0.0:
			panel.draw_string(font, Vector2(0, 140), "Knocked out! Back to the start.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(1, 0.5, 0.5))
		if not many:
			_draw_chain(player)
			var hint := "Tab / Y: forge    Click / X: attack    Space / A: dodge"
			panel.draw_string(font, Vector2(0, size.y - 16), hint, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 20, 14, Color(0.7, 0.72, 0.8))


## The blade's chain along the bottom; the last hit is the finisher. (Arena, one player.)
func _draw_chain(p) -> void:
	var font := ThemeDB.fallback_font
	var steps: Array = p.weapon.get("steps", [])
	var x := 20.0
	var y := panel.size.y - 110.0
	panel.draw_string(font, Vector2(x, y - 10), "Chain", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.78, 0.85))
	for i in steps.size():
		var label: String = steps[i]["move"]
		if i == steps.size() - 1:
			label += "  (finisher)"
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24.0
		var active: bool = p.current_step == i
		var next: bool = p.current_step < 0 and p.step_index == i and p.step_index > 0
		var bg := Color(0.2, 0.22, 0.28, 0.85)
		if active:
			bg = Color(0.95, 0.75, 0.3, 0.95)
		elif next:
			bg = Color(0.35, 0.38, 0.48, 0.95)
		panel.draw_rect(Rect2(x, y, w, 30), bg)
		panel.draw_string(font, Vector2(x + 12, y + 21), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK if active else Color.WHITE)
		x += w + 8.0


## The swing path, bottom of the grip to the tip; slots light up when they fire.
func _draw_path(p, i: int, right: bool) -> void:
	var font := ThemeDB.fallback_font
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
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20.0
		cells.append([label, w])
		total += w + (18.0 if s < line.size() - 1 else 0.0)
	var x := panel.size.x - 20.0 - total if right else 20.0
	var y := panel.size.y - 62.0
	var title := "Swing path (grip to tip)"
	if players.size() > 1:
		title = "P%d swing path" % (i + 1)
	panel.draw_string(font, Vector2(x, y - 8), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.78, 0.85))
	for s in line.size():
		var id: String = line[s]
		var label: String = cells[s][0]
		var w: float = cells[s][1]
		var col := Color(0.25, 0.26, 0.3, 0.85)
		var text_col := Color(0.6, 0.62, 0.68)
		if id != "":
			col = SwingBuild.FITTINGS[id]["color"]
			col = col.darkened(0.55) if not info.get(s, {}).has("unused") else Color(0.2, 0.2, 0.22)
			text_col = Color.WHITE
		var since: float = p.game_time - float(p.slot_flash.get(s, -99.0))
		var glow := clampf(1.0 - since / 0.45, 0.0, 1.0)
		if glow > 0.0 and id != "":
			col = col.lerp(SwingBuild.FITTINGS[id]["color"].lightened(0.4), glow)
			text_col = text_col.lerp(Color.BLACK, glow)
			panel.draw_rect(Rect2(x - 4, y - 4, w + 8, 36), Color(1, 1, 1, 0.35 * glow))
		panel.draw_rect(Rect2(x, y, w, 28), col)
		panel.draw_string(font, Vector2(x + 10, y + 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, text_col)
		x += w + 6.0
		if s < line.size() - 1:
			panel.draw_string(font, Vector2(x - 2, y + 20), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.62, 0.7))
			x += 12.0
