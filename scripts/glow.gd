extends Node2D
## The glowing pixels of a sprite: embers, eyes, lit runes. The art keeps them in
## a second image (<name>_glow.png) with the same frames as the sprite. This node
## sits on top of the sprite it belongs to and ignores the lights and the dark
## tint, so those pixels stay bright in the dark.

const Art := preload("res://scripts/art.gd")

var texture: Texture2D
var frames := 1
var frame := 0
var feet := Vector2.ZERO
var origin := Vector2.ZERO
var flip := false
var px := Art.PIXEL
var angle := 0.0


func _ready() -> void:
	material = Art.unshaded()


## Show this frame of this strip (null hides it). Only redraws when something changed.
func put(tex: Texture2D, frames_ := 1, frame_ := 0, feet_ := Vector2.ZERO, origin_ := Vector2.ZERO, flip_ := false, px_ := Art.PIXEL, angle_ := 0.0) -> void:
	if tex == texture and frames_ == frames and frame_ == frame and feet_ == feet and origin_ == origin and flip_ == flip and px_ == px and angle_ == angle:
		return
	texture = tex
	frames = frames_
	frame = frame_
	feet = feet_
	origin = origin_
	flip = flip_
	px = px_
	angle = angle_
	queue_redraw()


func _draw() -> void:
	if texture != null:
		Art.draw_strip(self, texture, frames, frame, feet, origin, flip, Color.WHITE, px, angle)
