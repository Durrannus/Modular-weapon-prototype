extends Node2D
## Plays a sprite strip (a death splat, a rune effect) and then removes itself.
## Set texture, frames, fps and origin. Optional: angle (radians, strips face
## right), size (extra scale), additive glow, life (loop the strip until then),
## and velocity / follow to move it.

const Art := preload("res://scripts/art.gd")
const Glow := preload("res://scripts/glow.gd")

var texture: Texture2D
var glow_texture: Texture2D   # optional: the strip's glowing pixels, kept bright in the dark
var _glow: Node2D
var frames := 1
var fps := 8.0
var origin := Vector2.ZERO
var feet := Vector2.ZERO
var flip := false
var angle := 0.0
var size := 1.0
var additive := false
var life := -1.0          # > 0: loop the strip for this long
var velocity := Vector2.ZERO
var follow: Node2D = null
var follow_offset := Vector2.ZERO
var fade_out := false
var t := 0.0


func _ready() -> void:
	# Effects place and move themselves every frame, so they skip the smoothing
	# the engine does between physics ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	z_index = 30
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
	if glow_texture != null:
		_glow = Glow.new()
		add_child(_glow)
		_glow.put(glow_texture, frames, 0, feet, origin, flip, Art.PIXEL * size, angle)


func _process(delta: float) -> void:
	t += delta
	var end := life if life > 0.0 else float(frames) / fps
	if t >= end:
		queue_free()
		return
	position += velocity * delta
	if follow != null:
		if is_instance_valid(follow):
			global_position = follow.global_position + follow_offset
	queue_redraw()
	if _glow != null:
		_glow.put(glow_texture, frames, _frame(), feet, origin, flip, Art.PIXEL * size, angle)


func _frame() -> int:
	var frame := int(t * fps)
	if life <= 0.0:
		frame = mini(frame, frames - 1)
	return frame


func _draw() -> void:
	if texture == null:
		return
	var frame := _frame()
	var tint := Color.WHITE
	if fade_out and life > 0.0:
		tint.a = clampf(1.0 - t / life, 0.0, 1.0) * 1.5
	Art.draw_strip(self, texture, frames, frame, feet, origin, flip, tint, Art.PIXEL * size, angle)
