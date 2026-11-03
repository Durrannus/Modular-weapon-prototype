extends CanvasLayer
## On-screen info: health, kills, the current combo, and control hints.

var player = null
var kills := 0
var spawning := true
var panel: Control
var pause_button: Button

signal pause_pressed

const SwingBuild := preload("res://scripts/weapon/swing_build.gd")


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
	# Clickable spawn pause, top right (P / Start does the same).
	pause_button = Button.new()
	pause_button.position = Vector2(1280 - 250, 16)
	pause_button.size = Vector2(230, 44)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.add_theme_font_size_override("font_size", 18)
	pause_button.pressed.connect(func(): pause_pressed.emit())
	panel.add_child(pause_button)


func _process(_delta: float) -> void:
	pause_button.text = "Pause enemies (P)" if spawning else "Resume enemies (P)"
	panel.queue_redraw()


func _draw_hud() -> void:
	if player == null:
		return
	var font := ThemeDB.fallback_font
	var size := panel.size

	# Health
	var hp_frac := clampf(player.hp / player.max_hp, 0.0, 1.0)
	panel.draw_rect(Rect2(20, 20, 240, 18), Color(0, 0, 0, 0.6))
	panel.draw_rect(Rect2(20, 20, 240 * hp_frac, 18), Color(0.85, 0.25, 0.3))
	panel.draw_string(font, Vector2(26, 34), "HP %d / %d" % [roundi(player.hp), roundi(player.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	panel.draw_string(font, Vector2(20, 62), "Kills: %d" % kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.9, 0.9))
	if not spawning:
		panel.draw_string(font, Vector2(20, 84), "Enemies paused (P / Start)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.8, 0.4))
	if player.knocked_out_timer > 0.0:
		panel.draw_string(font, Vector2(0, 140), "Knocked out! Back to the start.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(1, 0.5, 0.5))

	# Dodge charges
	var dodge_y := 104.0 if not spawning else 84.0
	panel.draw_string(font, Vector2(20, dodge_y), "Dodge", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.78, 0.85))
	for i in maxi(player.DODGE_MAX_CHARGES, player.dodge_charges):
		var full: bool = i < player.dodge_charges
		var c := Color(0.5, 0.85, 1.0) if full else Color(0.3, 0.32, 0.38)
		panel.draw_circle(Vector2(72 + i * 16, dodge_y - 5), 6.0, c)
	if player.dodge_charges < player.DODGE_MAX_CHARGES:
		var frac: float = player.dodge_refill / player.DODGE_REFILL
		panel.draw_arc(Vector2(72 + player.dodge_charges * 16, dodge_y - 5), 6.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, Color(0.5, 0.85, 1.0), 2.0)

	# The blade's chain along the bottom; the last hit is the finisher.
	var steps: Array = player.weapon.get("steps", [])
	var x := 20.0
	var y := size.y - 110.0
	panel.draw_string(font, Vector2(x, y - 10), "Chain", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.78, 0.85))
	for i in steps.size():
		var label: String = steps[i]["move"]
		if i == steps.size() - 1:
			label += "  (finisher)"
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24.0
		var active: bool = player.current_step == i
		var next: bool = player.current_step < 0 and player.step_index == i and player.step_index > 0
		var bg := Color(0.2, 0.22, 0.28, 0.85)
		if active:
			bg = Color(0.95, 0.75, 0.3, 0.95)
		elif next:
			bg = Color(0.35, 0.38, 0.48, 0.95)
		panel.draw_rect(Rect2(x, y, w, 30), bg)
		panel.draw_string(font, Vector2(x + 12, y + 21), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK if active else Color.WHITE)
		x += w + 8.0

	# The swing path, bottom of the grip to the tip; slots light up when they fire.
	var line: Array = player.weapon.get("line", [])
	var info: Dictionary = player.weapon.get("slot_info", {})
	x = 20.0
	y = size.y - 62.0
	panel.draw_string(font, Vector2(x, y - 8), "Swing path (grip to tip)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.78, 0.85))
	for i in line.size():
		var id: String = line[i]
		var label := "empty" if id == "" else str(SwingBuild.FITTINGS[id]["name"])
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20.0
		var col := Color(0.25, 0.26, 0.3, 0.85)
		var text_col := Color(0.6, 0.62, 0.68)
		if id != "":
			col = SwingBuild.FITTINGS[id]["color"]
			col = col.darkened(0.55) if not info.get(i, {}).has("unused") else Color(0.2, 0.2, 0.22)
			text_col = Color.WHITE
		var since: float = player.game_time - float(player.slot_flash.get(i, -99.0))
		var glow := clampf(1.0 - since / 0.45, 0.0, 1.0)
		if glow > 0.0 and id != "":
			col = col.lerp(SwingBuild.FITTINGS[id]["color"].lightened(0.4), glow)
			text_col = text_col.lerp(Color.BLACK, glow)
			panel.draw_rect(Rect2(x - 4, y - 4, w + 8, 36), Color(1, 1, 1, 0.35 * glow))
		panel.draw_rect(Rect2(x, y, w, 28), col)
		panel.draw_string(font, Vector2(x + 10, y + 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, text_col)
		x += w + 6.0
		if i < line.size() - 1:
			panel.draw_string(font, Vector2(x - 2, y + 20), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.62, 0.7))
			x += 12.0

	# Hints
	var hint := "Tab / Y: forge    Click / X: attack    Space / A: dodge"
	panel.draw_string(font, Vector2(0, size.y - 16), hint, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 20, 14, Color(0.7, 0.72, 0.8))
