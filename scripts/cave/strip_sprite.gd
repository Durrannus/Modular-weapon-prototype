extends Node2D
## A prop drawn from the cave art: a still image or an animated strip (brazier,
## gate, smith). Its position is where its feet are, less SORT_BIAS, so that the
## y-sort lines up with the players (whose position is their middle, not their feet).

const Art := preload("res://scripts/art.gd")
const SORT_BIAS := 14.0

signal finished

var texture: Texture2D
var frames := 1
var fps := 6.0
var origin := Vector2.ZERO   # the feet point in the frame, in art pixels
var loop := true
var playing := true
var flip := false
var tint := Color.WHITE
var t := 0.0
var _done := false


## Set the image. `rel` is a path under art/ (e.g. "cave/barrel.png").
func show_strip(rel: String, frames_ := 1, fps_ := 6.0, loop_ := true) -> void:
	texture = Art.texture(rel)
	frames = maxi(frames_, 1)
	fps = fps_
	loop = loop_
	t = 0.0
	_done = false
	playing = true
	queue_redraw()


func _process(delta: float) -> void:
	if frames <= 1 or not playing:
		return
	t += delta
	if not loop and not _done and t * fps >= float(frames):
		_done = true
		finished.emit()
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var frame := int(t * fps)
	if not loop:
		frame = mini(frame, frames - 1)
	Art.draw_strip(self, texture, frames, frame, Vector2(0, SORT_BIAS), origin, flip, tint)
