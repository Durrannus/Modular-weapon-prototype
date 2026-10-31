extends Node2D
## A wave sent out by a wave blade. Passes through enemies, hitting each once.

const RADIUS := 20.0

var velocity := Vector2.ZERO
var damage := 5.0
var crit_chance := 0.05
var burn := false
var color := Color(0.6, 0.9, 1.0)
var life := 0.6
var hit_ids := {}


func _ready() -> void:
	z_index = 4


func _physics_process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var id: int = e.get_instance_id()
		if hit_ids.has(id):
			continue
		if global_position.distance_to(e.global_position) <= RADIUS + e.radius:
			hit_ids[id] = true
			var crit := randf() < crit_chance
			e.take_hit(damage * (2.0 if crit else 1.0), velocity.normalized(), 120.0, crit, burn)
	queue_redraw()


func _draw() -> void:
	var a := velocity.angle()
	var c := color
	c.a = clampf(life / 0.2, 0.0, 1.0)
	draw_arc(Vector2.ZERO, RADIUS, a - 1.1, a + 1.1, 16, c, 5.0)
	c.a *= 0.4
	draw_arc(Vector2(-8, 0).rotated(a), RADIUS, a - 0.9, a + 0.9, 12, c, 3.0)
