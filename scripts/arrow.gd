extends Node2D
## An arrow in flight (14 November). It flies straight along `dir` until it hits an
## enemy, hits a wall or has flown its range, then sticks where it stopped for a
## moment and fades.
##
## Everything that decides what it hits happens in _physics_process, a whole tick
## at a time, with nothing random in it: online, both computers fly the same
## arrow. Its place is the arrow's POINT on the floor; the picture is drawn a
## little above that, at the height it left the bow.

const Art := preload("res://scripts/art.gd")
const BowArt := preload("res://scripts/weapon/bow_art.gd")
const SpriteOnce := preload("res://scripts/fx/sprite_once.gd")

const HALF_WIDTH := 4.0        # how close its line must pass to an enemy's edge
const HEIGHT := Vector2(0, -14)
const HIDE_FIRST := 22.0       # not drawn until it has cleared the bow
const HIDE_FIRST_BOLT := 40.0  # ...or, a staff's bolt, until it is past the crystal
const STUCK_TIME := 0.9        # how long a spent arrow stays
const STUCK_FADE := 0.3
const WALLS := 4               # the physics layer walls are on

var shooter = null             # the player who loosed it (told what it hits)
var stamp := 0                 # the shooter's weapon at the time (see player.gd weapon_stamp)
var dir := Vector2.RIGHT
var speed := 1300.0
var left := 520.0              # how much further it flies
var damage := 5.0
var knock := 130.0
var stun := 0.1
var freeze := 0.03
var crit := 0.05               # the bow's luck when it was loosed
var crit_damage := 1.5
var heavy := false             # the chain's heavy shot: a thicker streak, and it lands harder
var finisher := false
var kind := "wooden_arrows"    # whose picture
var pierce := 0                # how many more enemies it goes on through (the Pierce rune)
var pierce_power := 1.0        # what it does to the ones behind the first, as a share
var through := 0               # how many it has hit so far
var half_width := HALF_WIDTH   # Pierce with Wider: a thicker path
var struck := {}               # the enemies it has hit already
## A rune's own arrow ("volley", "snipe", "ricochet"; "" for a shot of the chain).
## It is drawn in the rune's colour and sets no other rune off.
var rune := ""
var color := Color.WHITE       # the rune's colour: the number over the enemy, and the streak's tint
var streak := ""               # the streak's strip, if not the usual one ("pierce_trail", "snipe_trail")
var bounce := {}               # Ricochet: what its next jump is like ({jumps, range, splinter})
## A staff's cast (15 November) flies the same way: "bolt", "burst", "spark" or
## "orb" ("" for an arrow). It is drawn from a strip tinted with `color` (the
## crystal's), and never sticks: it is gone where it stops.
var bolt := ""
var splash := 0.0              # a burst or an orb: it hurts everything this near where it stops
var small := false             # a plain bolt's very small splash: no burst is shown for it
var quiet := false             # one of a spray's side sparks: it sets no rune off
var halo := ""                 # Overflow: a strip drawn round the bolt as it flies ("overflow_glow")
var big := 1.0                 # Overflow: the bolt is drawn this much bigger
## A Spectre's copy of an arrow or a bolt (15 November): the share of the real one
## it is worth (0 for a real one). It is drawn in the ghost's colour.
var copy := 0.0
var flown := 0.0
var hit_flown := 0.0           # how far it had flown when it last hit someone (Snipe counts it)
var flying := true
var rest := 0.0                # seconds since it stopped
var in_wall := false
var _trail: Node2D


func _ready() -> void:
	add_to_group("arrows")
	rotation = 0.0
	# Arrows stay bright in the dark, like the players' rims: you have to see them.
	material = Art.unshaded()
	if bolt != "":
		# A bolt is light: it adds to what is behind it, like its streak.
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = glow
	z_index = 1
	_trail = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_trail.material = add
	_trail.show_behind_parent = true
	add_child(_trail)
	_trail.draw.connect(_draw_trail)


func _physics_process(delta: float) -> void:
	if not flying:
		rest += delta
		if rest >= STUCK_TIME:
			queue_free()
		return
	var step := minf(speed * delta, left)
	var from := global_position
	# A wall in the way stops it there.
	var reach := step
	var wall := {}
	if step > 0.0:
		var q := PhysicsRayQueryParameters2D.create(from, from + dir * step, WALLS)
		wall = get_world_2d().direct_space_state.intersect_ray(q)
		if not wall.is_empty():
			reach = from.distance_to(wall["position"])
	# Every enemy its line passes through before that, nearest first.
	var found: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.immune or struck.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - from
		var along := rel.dot(dir)
		var side := absf(rel.dot(dir.orthogonal()))
		var r: float = float(e.radius) + half_width
		if side > r:
			continue
		var enter := along - sqrt(r * r - side * side)
		if enter > reach or along + r < 0.0:
			continue
		found.append([maxf(enter, 0.0), e])
	found.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for f in found:
		var e = f[1]
		struck[e.get_instance_id()] = true
		global_position = from + dir * float(f[0])
		hit_flown = flown + float(f[0])
		if is_instance_valid(shooter):
			shooter.arrow_hit(self, e)
		through += 1
		if pierce > 0:
			pierce -= 1
			continue
		queue_free()
		flying = false
		return
	global_position = from + dir * reach
	flown += reach
	left -= reach
	if not wall.is_empty():
		in_wall = true
		_stop()
	elif left <= 0.0:
		_stop()


## It has stopped without hitting anyone: it stands where it is for a moment.
## (A bolt doesn't: it is gone.)
func _stop() -> void:
	flying = false
	rest = 0.0
	if is_instance_valid(shooter):
		shooter.arrow_spent(self)
	if bolt != "":
		queue_free()


func _hide_first() -> float:
	return HIDE_FIRST_BOLT if bolt != "" else HIDE_FIRST


func _process(_delta: float) -> void:
	queue_redraw()
	_trail.queue_redraw()


func _draw() -> void:
	if bolt != "":
		_draw_bolt()
		return
	if flying:
		if flown < HIDE_FIRST:
			return
		var tex := BowArt.arrow_texture(kind)
		if tex == null:
			draw_set_transform(HEIGHT, dir.angle(), Vector2.ONE)
			draw_line(Vector2(-26, 0), Vector2.ZERO, Color("#dca25c"), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		var tip: Array = BowArt.data().get("arrows", {}).get(kind, {}).get("fly", {}).get("tip", [tex.get_width() - 1, tex.get_height() / 2])
		draw_set_transform(HEIGHT, dir.angle(), Vector2(Art.PIXEL, Art.PIXEL))
		draw_texture(tex, -Vector2(float(tip[0]) + 1.0, float(tip[1]) + 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# Spent: the back half of the arrow, standing where it stopped.
	var fade := clampf((STUCK_TIME - rest) / STUCK_FADE, 0.0, 1.0)
	var stuck := BowArt.arrow_texture(kind, "stuck")
	if stuck == null:
		return
	var frames := maxi(int(BowArt.data().get("arrows", {}).get(kind, {}).get("stuck", {}).get("frames", 2)), 1)
	var fw := float(stuck.get_width()) / frames
	var f := 0 if rest < 0.07 else frames - 1
	# In a wall it stays at the height it flew; on the floor it has dropped to it.
	var at := HEIGHT if in_wall else HEIGHT * clampf(1.0 - rest / 0.05, 0.0, 1.0) * 0.5
	draw_set_transform(at, dir.angle() + (0.0 if in_wall else 0.35 * signf(dir.x if absf(dir.x) > 0.01 else 1.0)), Vector2(Art.PIXEL, Art.PIXEL))
	draw_texture_rect_region(stuck, Rect2(-fw, -stuck.get_height() * 0.5, fw, stuck.get_height()), Rect2(f * fw, 0, fw, stuck.get_height()), Color(1, 1, 1, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A staff's bolt: its strip, tinted, turned to the way it flies (an orb is round
## and isn't turned).
func _draw_bolt() -> void:
	if not flying or flown < HIDE_FIRST_BOLT:
		return
	var name := bolt + "_fly"
	var tex := BowArt.fx_texture(name)
	var info := BowArt.fx(name)
	if tex == null or info.is_empty():
		draw_circle(HEIGHT, 9.0 if heavy else 5.0, color)
		return
	var n := maxi(int(info.get("frames", 4)), 1)
	var frame := int(Time.get_ticks_msec() / 1000.0 * float(info.get("fps", 16))) % n
	var fw := float(tex.get_width()) / n
	var o: Array = info.get("origin", [fw - 4.0, tex.get_height() * 0.5])
	draw_set_transform(HEIGHT, 0.0 if bolt == "orb" else dir.angle(), Vector2(Art.PIXEL, Art.PIXEL) * big)
	draw_texture_rect_region(tex, Rect2(-float(o[0]), -float(o[1]), fw, tex.get_height()), Rect2(frame * fw, 0, fw, tex.get_height()), color)
	_draw_halo()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Overflow's halo round a bolt cast on full mana: the art's own colours, turned
## with the bolt.
func _draw_halo() -> void:
	if halo == "":
		return
	var tex := BowArt.fx_texture(halo)
	var info := BowArt.fx(halo)
	if tex == null or info.is_empty():
		draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 16, Color(0.42, 0.72, 1.0, 0.8), 1.5)
		return
	var n := maxi(int(info.get("frames", 4)), 1)
	var frame := int(Time.get_ticks_msec() / 1000.0 * float(info.get("fps", 16))) % n
	var fw := float(tex.get_width()) / n
	var o: Array = info.get("origin", [fw * 0.5, tex.get_height() * 0.5])
	draw_set_transform(HEIGHT, dir.angle(), Vector2(Art.PIXEL, Art.PIXEL) * big)
	draw_texture_rect_region(tex, Rect2(-float(o[0]), -float(o[1]), fw, tex.get_height()), Rect2(frame * fw, 0, fw, tex.get_height()))


## The streak behind it: the art's strip if there is one, else a plain pale line.
func _draw_trail() -> void:
	if not flying or flown < _hide_first() or bolt == "orb":
		return
	var name := streak if streak != "" else ("arrow_trail_heavy" if heavy else "arrow_trail")
	if bolt != "" and streak == "":
		name = "bolt_trail"
	var tex := BowArt.fx_texture(name)
	var info := BowArt.fx(name)
	var o: Array = info.get("origin", [31, 4])
	# It grows out of the bow: never longer than the arrow has flown (or the strip).
	var length := minf(flown - _hide_first(), (float(o[0]) + 1.0) * Art.PIXEL)
	var tail := HEIGHT - dir * (34.0 if bolt == "burst" else (20.0 if bolt != "" else 24.0))
	if length <= 0.0:
		return
	if tex != null and not info.is_empty():
		var n := maxi(int(info.get("frames", 4)), 1)
		var frame := int(Time.get_ticks_msec() / 1000.0 * float(info.get("fps", 20))) % n
		var fw := float(tex.get_width()) / n
		var show := clampf(ceilf(length / Art.PIXEL), 1.0, float(o[0]) + 1.0)   # art pixels, counted back from the arrow's tail
		_trail.draw_set_transform(tail, dir.angle(), Vector2(Art.PIXEL, Art.PIXEL))
		_trail.draw_texture_rect_region(tex, Rect2(1.0 - show, -float(o[1]), show, tex.get_height()),
			Rect2(frame * fw + float(o[0]) + 1.0 - show, 0, show, tex.get_height()), _streak_tint())
		_trail.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var col := Color(1.0, 0.82, 0.55) if heavy else Color(0.86, 0.9, 0.8)
	if rune != "":
		col = color
	var width := 4.0 if heavy else 2.0
	var steps := 6
	for i in steps:
		var a := tail - dir * length * (float(i) / steps)
		var b := tail - dir * length * (float(i + 1) / steps)
		var k := 1.0 - float(i) / steps
		_trail.draw_line(a, b, Color(col.r, col.g, col.b, 0.5 * k * k), maxf(width * k, 1.0))


## A rune's arrow has the usual streak in the rune's colour (the strips drawn for
## one rune, like Snipe's, are that colour already).
func _streak_tint() -> Color:
	if copy > 0.0 and bolt == "":
		return Color(color.r, color.g, color.b, 0.7)
	if bolt != "":
		return Color(color.r, color.g, color.b, 0.8)
	if rune == "" or streak != "":
		return Color.WHITE
	return color.lerp(Color.WHITE, 0.25)
