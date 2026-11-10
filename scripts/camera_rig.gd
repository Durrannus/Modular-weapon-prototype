extends Node2D
## One camera for everyone. It sits on the midpoint of the players who are still
## standing, so two players share the screen. It moves on the physics tick, the
## same as the players, so the two never judder against each other.

const VIEW := Vector2(1280, 720)   # world units on screen (640x360 at zoom 0.5)
const FOLLOW := 10.0               # how fast it catches up
const EDGE := 26.0                 # players are kept this far inside the screen

var camera: Camera2D
var targets: Array = []
var shake := 0.0
var limits := Rect2()
var has_limits := false
var bias := Vector2.ZERO           # look this far off the players (to show something tall)


func _ready() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(0.5, 0.5)  # 640x360 screen, world keeps its old units
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	camera.make_current()


func set_limits(rect: Rect2, margin := 80.0) -> void:
	limits = rect.grow(margin)
	has_limits = true
	camera.limit_left = int(limits.position.x)
	camera.limit_top = int(limits.position.y)
	camera.limit_right = int(limits.end.x)
	camera.limit_bottom = int(limits.end.y)


func _focus() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for p in targets:
		if is_instance_valid(p) and not p.is_down:
			sum += p.global_position
			n += 1
	if n == 0:
		for p in targets:
			if is_instance_valid(p):
				sum += p.global_position
				n += 1
	return sum / n + bias if n > 0 else global_position


func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(_focus(), 1.0 - exp(-FOLLOW * delta))


func _process(delta: float) -> void:
	shake = move_toward(shake, 0.0, 40.0 * delta)
	camera.offset = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake).round()


## Jump straight to the players (after a teleport or at the start).
func snap() -> void:
	global_position = _focus()
	reset_physics_interpolation()
	camera.reset_physics_interpolation()


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


## The part of the world on screen right now.
func view_rect() -> Rect2:
	var c := camera.get_screen_center_position()
	return Rect2(c - VIEW * 0.5, VIEW)


## With two players, nobody can walk off the shared screen: you can't get further
## from your partner than one screen. Only your own step is stopped, so a partner
## walking away never drags you.
func leash(who: Node2D, pos: Vector2) -> Vector2:
	var reach := VIEW - Vector2(EDGE, EDGE) * 2.0 - Vector2(0.0, 44.0)
	for q in targets:
		if q == who or not is_instance_valid(q) or q.is_down:
			continue
		var o: Vector2 = q.global_position
		pos.x = clampf(pos.x, o.x - reach.x, o.x + reach.x)
		pos.y = clampf(pos.y, o.y - reach.y, o.y + reach.y)
	return pos
