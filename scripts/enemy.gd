extends CharacterBody2D

const WeaponBuild := preload("res://scripts/weapon/weapon_build.gd")
## Simple enemies. Set `kind` before adding to the scene:
## "slime" (chaser), "charger" (winds up and dashes), "brute" (slow and tough),
## "dummy" (training dummy: never moves, never dies).

signal died(enemy)

const DamageNumber := preload("res://scripts/fx/damage_number.gd")
const Fx := preload("res://scripts/fx/fx.gd")
const Art := preload("res://scripts/art.gd")

var kind := "slime"
var max_hp := 30.0
var hp := 30.0
var speed := 85.0
var radius := 14.0
var color := Color(0.5, 0.9, 0.4)
var contact_damage := 10.0
var knock_resist := 1.0
var dead := false

var knock := Vector2.ZERO
var flash := 0.0
var burn_time := 0.0
var burn_tick := 0.0
var burn_damage := 2.0
var slow_time := 0.0
var slow_amount := 0.0
var stun_time := 0.0
var facing := Vector2.RIGHT

# Training dummy: damage log for the damage-per-second readout.
const DPS_WINDOW := 3.0
var dps_log: Array = []  # [[time_seconds, damage], ...]

# Charger state
var state := "chase"
var state_timer := 0.0
var charge_dir := Vector2.RIGHT


func _ready() -> void:
	add_to_group("enemies")
	match kind:
		"charger":
			max_hp = 22.0
			speed = 120.0
			radius = 13.0
			color = Color(0.95, 0.45, 0.35)
			contact_damage = 14.0
		"brute":
			max_hp = 120.0
			speed = 52.0
			radius = 26.0
			color = Color(0.55, 0.45, 0.8)
			contact_damage = 20.0
			knock_resist = 0.3
		"dummy":
			max_hp = 100.0
			speed = 0.0
			radius = 18.0
			color = Color(0.7, 0.55, 0.35)
			contact_damage = 0.0
			knock_resist = 0.0
		_:
			pass
	hp = max_hp
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 2 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	if dead:
		return
	flash = maxf(flash - delta, 0.0)
	slow_time = maxf(slow_time - delta, 0.0)
	stun_time = maxf(stun_time - delta, 0.0)
	_update_burn(delta)
	if kind == "dummy":
		return

	var desired := Vector2.ZERO
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var to_p: Vector2 = player.global_position - global_position
		if to_p.length() > 0.01:
			facing = to_p.normalized()
		if kind == "charger":
			desired = _charger_ai(to_p, delta)
		else:
			desired = facing * speed
		if to_p.length() < radius + 16.0 + 2.0 and contact_damage > 0.0 and stun_time <= 0.0:
			player.take_damage(contact_damage)

	if slow_time > 0.0:
		desired *= 1.0 - slow_amount
	if stun_time > 0.0:
		desired = Vector2.ZERO
	if knock.length() > 60.0:
		desired *= 0.2
	knock = knock.move_toward(Vector2.ZERO, 1300.0 * delta)
	velocity = desired + knock
	move_and_slide()


func _charger_ai(to_p: Vector2, delta: float) -> Vector2:
	state_timer -= delta
	match state:
		"chase":
			if to_p.length() < 240.0 and state_timer <= 0.0:
				state = "windup"
				state_timer = 0.55
				return Vector2.ZERO
			return to_p.normalized() * speed
		"windup":
			charge_dir = to_p.normalized()
			if state_timer <= 0.0:
				state = "charge"
				state_timer = 0.35
			return Vector2.ZERO
		"charge":
			if state_timer <= 0.0:
				state = "rest"
				state_timer = 0.7
			return charge_dir * 560.0
		"rest":
			if state_timer <= 0.0:
				state = "chase"
				state_timer = 0.5
			return Vector2.ZERO
	return Vector2.ZERO


func _update_burn(delta: float) -> void:
	if burn_time <= 0.0:
		return
	burn_time -= delta
	burn_tick -= delta
	if burn_tick <= 0.0:
		burn_tick = 0.5
		_apply_damage(burn_damage, false, WeaponBuild.ELEMENT_COLORS["fire"])


## A hit from the player. num_color colours the damage number (by element).
func take_hit(dmg: float, dir: Vector2, knockback: float, crit: bool, num_color: Color) -> void:
	if dead:
		return
	flash = 0.1
	knock = dir * knockback * knock_resist
	if kind == "charger" and state == "windup":
		state = "rest"  # a good hit interrupts the charge
		state_timer = 0.6
	_apply_damage(dmg, crit, num_color)


func apply_burn(damage_per_tick: float, duration: float) -> void:
	burn_damage = maxf(burn_damage if burn_time > 0.0 else 0.0, damage_per_tick)
	burn_time = maxf(burn_time, duration)


func apply_slow(amount: float, duration: float) -> void:
	slow_amount = amount
	slow_time = maxf(slow_time, duration)


func apply_stun(duration: float) -> void:
	if kind == "dummy":
		return
	stun_time = maxf(stun_time, duration)


func _apply_damage(dmg: float, crit: bool, num_color: Color) -> void:
	hp -= dmg
	var n := DamageNumber.new()
	n.text = str(roundi(dmg)) + ("!" if crit else "")
	n.color = num_color
	n.font_size = 26 if crit else 16
	get_parent().add_child(n)
	n.global_position = global_position + Vector2(randf_range(-8, 8), -radius - 6.0)
	if kind == "dummy":
		dps_log.append([Time.get_ticks_msec() / 1000.0, dmg])
		if hp <= 0.0:
			hp = max_hp
		return
	if hp <= 0.0:
		_die()


## Damage per second over the last few seconds (training dummy).
func current_dps() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	while not dps_log.is_empty() and now - float(dps_log[0][0]) > DPS_WINDOW:
		dps_log.pop_front()
	if dps_log.is_empty():
		return 0.0
	var total := 0.0
	for entry in dps_log:
		total += float(entry[1])
	var span := clampf(now - float(dps_log[0][0]), 1.0, DPS_WINDOW)
	return total / span


func _die() -> void:
	dead = true
	var b := Fx.new()
	b.kind = "burst"
	b.radius = radius * 1.6
	b.color = color
	b.life = 0.25
	get_parent().add_child(b)
	b.global_position = global_position
	died.emit(self)
	queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := color
	if burn_time > 0.0:
		c = c.lerp(WeaponBuild.ELEMENT_COLORS["fire"], 0.45)
	elif slow_time > 0.0:
		c = c.lerp(WeaponBuild.ELEMENT_COLORS["water"], 0.4)
	if flash > 0.0:
		c = Color.WHITE

	draw_circle(Vector2(0, radius * 0.8), radius * 0.9, Color(0, 0, 0, 0.25))  # shadow
	var tex := Art.texture("enemies/%s.png" % kind)
	if tex != null:
		# Sprite, centred, flipped to face left/right; tinted by status and hit flash.
		var flip := -1.0 if facing.x < 0.0 else 1.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(Art.PIXEL * flip, Art.PIXEL))
		draw_texture(tex, -tex.get_size() * 0.5, c if c != color else Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_shape(c)

	if stun_time > 0.0:
		for i in 3:
			var a := Time.get_ticks_msec() / 150.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a), sin(a) * 0.4) * radius * 0.8 + Vector2(0, -radius - 6.0), 2.5, WeaponBuild.ELEMENT_COLORS["electrified"])

	if kind == "dummy":
		var dps := current_dps()
		if dps > 0.0:
			var font := ThemeDB.fallback_font
			var label := "DPS %.1f" % dps
			draw_string_outline(font, Vector2(-50, -radius - 14.0), label, HORIZONTAL_ALIGNMENT_CENTER, 100, 16, 4, Color.BLACK)
			draw_string(font, Vector2(-50, -radius - 14.0), label, HORIZONTAL_ALIGNMENT_CENTER, 100, 16, Color(1, 0.95, 0.6))

	if hp < max_hp and kind != "dummy":
		var w := radius * 2.0
		var y := -radius - 10.0
		draw_rect(Rect2(-w * 0.5, y, w, 4.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w * 0.5, y, w * clampf(hp / max_hp, 0.0, 1.0), 4.0), Color(0.9, 0.25, 0.25))

## Stand-in shapes until the enemy sprites land.
func _draw_shape(c: Color) -> void:
	match kind:
		"charger":
			var tip := facing * (radius + 6.0)
			var side := facing.orthogonal() * radius
			draw_colored_polygon(PackedVector2Array([tip, -facing * radius + side, -facing * radius - side]), c)
			if state == "windup":
				var pulse := 0.5 + 0.5 * sin(state_timer * 40.0)
				draw_line(Vector2.ZERO, charge_dir * 200.0, Color(1, 0.2, 0.2, 0.3 + 0.4 * pulse), 4.0)
		"dummy":
			draw_circle(Vector2.ZERO, radius, c)
			draw_line(Vector2(-radius, 0), Vector2(radius, 0), c.darkened(0.4), 3.0)
			draw_line(Vector2(0, -radius), Vector2(0, radius), c.darkened(0.4), 3.0)
		_:
			draw_circle(Vector2.ZERO, radius, c)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, c.darkened(0.4), 2.5)
			draw_circle(facing * radius * 0.45, radius * 0.18, Color(0.1, 0.1, 0.1))
