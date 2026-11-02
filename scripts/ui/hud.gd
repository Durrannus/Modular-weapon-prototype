extends CanvasLayer
## On-screen info: health, kills, the current combo, and control hints.

var player = null
var kills := 0
var spawning := true
var panel: Control


func _ready() -> void:
	layer = 5
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.draw.connect(_draw_hud)


func _process(_delta: float) -> void:
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
	for i in player.DODGE_MAX_CHARGES:
		var full: bool = i < player.dodge_charges
		var c := Color(0.5, 0.85, 1.0) if full else Color(0.3, 0.32, 0.38)
		panel.draw_circle(Vector2(72 + i * 16, dodge_y - 5), 6.0, c)
	if player.dodge_charges < player.DODGE_MAX_CHARGES:
		var frac: float = player.dodge_refill / player.DODGE_REFILL
		panel.draw_arc(Vector2(72 + player.dodge_charges * 16, dodge_y - 5), 6.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, Color(0.5, 0.85, 1.0), 2.0)

	# Combo chips along the bottom: pommel -> handle -> hilt
	var steps: Array = player.weapon.get("steps", [])
	var x := 20.0
	var y := size.y - 70.0
	panel.draw_string(font, Vector2(x, y - 10), "Combo", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.78, 0.85))
	for i in steps.size():
		var label: String = steps[i]["move"]
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

	# Hints
	var hint := "Tab / Y: forge    Click / X: attack    Space / A: dodge    P: pause enemies"
	panel.draw_string(font, Vector2(0, size.y - 16), hint, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 20, 14, Color(0.7, 0.72, 0.8))
