extends Node2D
## What Rattlecrown tosses (version 48): a lump of scrap, lobbed, and the mark on the floor where it will land.
##
## Rattlecrown is a boss, so his attacks ARE marked on the floor (Darren, 23 November: "Not every enemy has to have
## telegraph markers for its moves, only bosses"). The mark is there from the moment he draws his arm back: an
## orange ring that closes in while the lump is in his hand and in the air, and flashes as it lands. Whoever stands
## on it then is hurt.
##
## The pictures are the Art builder's (art/foes/rattlecrown.png and its book): `scrap`, `scrap_mark`, and the Club
## Slam's `slam_mark`, which rattlecrown.gd draws through the helpers at the bottom of this file.

const Art := preload("res://scripts/art.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Foe := preload("res://scripts/foes/foe.gd")

const SHEET := "foes/rattlecrown.png"
const BOOK := "foes/rattlecrown.json"
const ARC := 64.0              # how high the lump goes above a straight line from his hand to the mark (world units)
const BLOW := 0.2              # the mark's last picture (the blow) stays this long

var from := Vector2.ZERO       # the ground under his hand
var from_up := 58.0            # how high his hand is
var to := Vector2.ZERO
var wait := 0.7                # the mark shows this long before the lump leaves his hand
var flight := 0.75
var damage := 14.0
var reach := Vector2(36.0, 18.0)   # the mark's reach from its middle, across and deep (world units)
var by = null                  # Rattlecrown (he may have fallen since)
var t := 0.0
var thrown := false
var landed := false
var lump: Node2D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("hazards")
	add_to_group("crown_shots")
	z_index = -5                       # the mark lies on the floor, under everyone, and the dark never dims it
	material = Art.unshaded()
	global_position = to
	lump = Node2D.new()
	lump.z_index = 35                  # the lump is in the air, over everyone
	lump.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(lump)
	lump.draw.connect(_draw_lump)


## Is this place (world units) on a mark with this middle and this reach? (A body's own width is allowed for.)
static func on_mark(at: Vector2, middle: Vector2, reach_: Vector2, body := 8.0) -> bool:
	var d := Vector2((at.x - middle.x) / (reach_.x + body), (at.y - middle.y) / (reach_.y + body))
	return d.length_squared() <= 1.0


func _thrower():
	return by if by != null and is_instance_valid(by) and not by.dead else null


func _physics_process(delta: float) -> void:
	t += delta
	if not thrown and t >= wait:
		# He fell with it still in his hand: nothing is thrown, and the mark goes.
		if by != null and _thrower() == null:
			queue_free()
			return
		thrown = true
		Sfx.play(self, "swing", -7.0, 0.7)
	if not landed and t >= wait + flight:
		landed = true
		_land()
	if landed and t >= wait + flight + BLOW:
		queue_free()
		return
	queue_redraw()
	lump.queue_redraw()


func _land() -> void:
	var missed := true
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or p.is_down:
			continue
		if on_mark(p.global_position, to, reach):
			if p.invuln <= 0.0:
				missed = false
			p.take_damage(damage, to, _thrower())
		if p.rig != null:
			p.rig.add_shake(2.0)
	if missed and _thrower() != null and by.has_method("toss_missed"):
		by.toss_missed()
	Sfx.play(self, "slam", -10.0, 1.5)
	Sfx.play(self, "anvil", -16.0, 0.8)
	var puff := Foe.play_shot(self, "pebble_puff", to)
	if puff != null:
		puff.z_index = 0


func _draw() -> void:
	draw_mark(self, Vector2.ZERO)


## The mark, drawn on any canvas item at a place in its own space (Rattlecrown draws it again through his body).
func draw_mark(ci: CanvasItem, at: Vector2) -> void:
	var k := clampf(t / maxf(wait + flight, 0.01), 0.0, 1.0)
	var frame := 3 if landed else clampi(int(k * 3.0), 0, 2)
	if not draw_shot(ci, "scrap_mark", frame, at):
		ci.draw_arc(at, reach.x * (1.0 - 0.5 * k), 0.0, TAU, 24, Color("#ff8a3c"), 2.0)


func _draw_lump() -> void:
	if not thrown or landed:
		return
	var k := clampf((t - wait) / maxf(flight, 0.01), 0.0, 1.0)
	var ground := (from - to).lerp(Vector2.ZERO, k)
	var up := lerpf(from_up, 0.0, k) + sin(k * PI) * ARC
	# Its own shadow on the ground under it, growing as it comes down (as the slingers' rocks).
	var near := 1.0 - sin(k * PI)
	var half := roundf(lerpf(3.0, 6.0, near)) * Art.PIXEL
	var shade := Color(0.098, 0.078, 0.165, lerpf(0.35, 0.6, near))
	lump.draw_rect(Rect2(ground.x - half + Art.PIXEL, ground.y - 2.0 * Art.PIXEL, half * 2.0 - 2.0 * Art.PIXEL, Art.PIXEL), shade)
	lump.draw_rect(Rect2(ground.x - half, ground.y - Art.PIXEL, half * 2.0, 2.0 * Art.PIXEL), shade)
	lump.draw_rect(Rect2(ground.x - half + Art.PIXEL, ground.y + Art.PIXEL, half * 2.0 - 2.0 * Art.PIXEL, Art.PIXEL), shade)
	var info := shot("scrap")
	var frame := int((t - wait) * float(info.get("fps", 10))) if not info.is_empty() else 0
	if not draw_shot(lump, "scrap", frame, ground + Vector2(0, -up)):
		lump.draw_rect(Rect2(ground.x - 5.0, ground.y - up - 5.0, 10, 10), Color("#8c8894"))


# --- Rattlecrown's own sheet ----------------------------------------------------------------
# He has a sheet and a book of his own (art/foes/rattlecrown.png, .json), in the same form as the other enemies'.

static var _strips := {}

## A strip of his sheet as a picture of its own (null if the box is no box).
static func strip_tex(box) -> Texture2D:
	if not (box is Array) or (box as Array).size() != 4:
		return null
	var key := "%d,%d,%d,%d" % [int(box[0]), int(box[1]), int(box[2]), int(box[3])]
	if not _strips.has(key):
		var sheet := Art.texture(SHEET)
		var tex: AtlasTexture = null
		if sheet != null:
			tex = AtlasTexture.new()
			tex.atlas = sheet
			tex.region = Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3]))
		_strips[key] = tex
	return _strips[key]


## A loose piece of his sheet ("shots" in the book): {tex, frames, fps, origin}, or empty.
static func shot(name: String) -> Dictionary:
	var info: Dictionary = Art.json(BOOK).get("shots", {}).get(name, {})
	var tex := strip_tex(info.get("box"))
	if tex == null:
		return {}
	var o: Array = info.get("origin", [0, 0])
	return {"tex": tex, "frames": int(info.get("frames", 1)), "fps": float(info.get("fps", 10)), "origin": Vector2(o[0], o[1])}


## How far a ring on the floor reaches from its middle, across and deep, in world units: half its picture.
static func reach_of(name: String, otherwise: Vector2) -> Vector2:
	var f = Art.json(BOOK).get("shots", {}).get(name, {}).get("frame")
	if f is Array and (f as Array).size() == 2:
		return Vector2(float(f[0]), float(f[1])) * Art.PIXEL * 0.5
	return otherwise


## Draws frame `frame` of a loose piece with its origin at `at` (false if the art has none).
static func draw_shot(ci: CanvasItem, name: String, frame: int, at: Vector2) -> bool:
	var s := shot(name)
	if s.is_empty():
		return false
	Art.draw_strip(ci, s["tex"], s["frames"], frame, at, s["origin"])
	return true
