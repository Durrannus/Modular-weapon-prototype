extends Node2D
## Plays a sprite strip once (e.g. an enemy's death splat) and then removes itself.

const Art := preload("res://scripts/art.gd")

var texture: Texture2D
var frames := 1
var fps := 8.0
var origin := Vector2.ZERO
var feet := Vector2.ZERO
var flip := false
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	if t >= float(frames) / fps:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if texture != null:
		Art.draw_strip(self, texture, frames, mini(int(t * fps), frames - 1), feet, origin, flip)
