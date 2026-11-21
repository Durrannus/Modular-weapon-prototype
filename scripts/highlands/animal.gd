extends Node
## A cow, a hare or a crow: scenery that is alive. It only plays its few frames,
## slowly, at the times the art gives (art/highlands/kit.json, "times"), and a hare
## shifts a few pixels when it hops. Nothing in the game depends on it, so its
## clock is its own and never the game's random numbers.

const Painter := preload("res://scripts/highlands/land_painter.gd")

var view                    # the land view (for the pictures)
var sprite: Sprite2D
var kind := "cow"
var steps: Array = []       # [[frame index, seconds], ...]
var step := 0
var left := 0.0
var home := Vector2.ZERO
var out := false            # a hare: has hopped away from where it sits
var way := 1.0              # a hare: which way its first hop goes (the art faces right)


func start(view_, sprite_: Sprite2D, kind_: String, offset_seconds: float) -> void:
	view = view_
	sprite = sprite_
	kind = kind_
	home = sprite.position
	way = -1.0 if sprite.flip_h else 1.0
	var info: Dictionary = Painter.things[kind]
	var order: Array = info.get("order", [])
	for t in info.get("times", []):
		steps.append([order.find(t[0]), float(t[1])])
	if steps.is_empty():
		set_process(false)
		return
	# Not all in step with each other.
	left = float(steps[0][1]) + offset_seconds


func _process(delta: float) -> void:
	left -= delta
	if left > 0.0:
		return
	step = (step + 1) % steps.size()
	left += float(steps[step][1])
	sprite.texture = view.thing_texture(kind, int(steps[step][0]))
	if kind != "hare":
		return
	if int(steps[step][0]) == 2:
		# A hare lands a little way off, and next time hops back.
		out = not out
		sprite.position = home + (Vector2(way * 8.0, 0) if out else Vector2.ZERO)
	elif int(steps[step][0]) == 0:
		# Sitting again: it turns to face the way it will hop next.
		sprite.flip_h = not sprite.flip_h
