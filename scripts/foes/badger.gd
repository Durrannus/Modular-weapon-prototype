extends "res://scripts/foes/creature.gd"
## The peat badger (version 63; the Art builder's moor sheet). Neutral (creature.gd): it snuffles about its home and
## leaves you alone. Hit it and it comes at you and BITES: its jaw opens first (the warning: no mark on the floor),
## then it snaps at whoever is in front of it. Missing, it is Open for a moment. Hurt to DIG_AT of its health, it
## DIGS IN and is gone, leaving a heap of soil: no Memory for it, and it is back home later like any other (finish
## it while it digs and it is yours). (Claude's numbers.)

static var HP := 18.0
static var SPEED := 105.0
static var BITE := 7.0
static var BITE_WINDUP := 0.35       # its jaw open before it bites (the warning)
static var BITE_REACH := 30.0        # how far past its body its bite reaches
static var DIG_AT := 0.35            # hurt to this share of its health, it digs in and is gone
static var DIG_TIME := 0.5           # digging takes this long: it can still be hit meanwhile
const BITE_TIME := 0.2
const AFTER := 0.7                   # standing after a bite
const MOUND := 1.2                   # the heap of soil stays this long

var fled := false              # it dug in and got away: no kill, no Memory (foes.gd)
var bit := false


func _setup() -> void:
	kind = "badger"
	_stats()
	radius = 10.0
	contact_damage = 0.0
	knock_resist = 0.8
	color = Color("#6c7078")
	add_to_group("creatures")


func _stats() -> void:
	max_hp = HP
	speed = SPEED


func _fight(delta: float) -> Vector2:
	if mode != "dig" and hp <= max_hp * DIG_AT:
		_set_mode("dig", DIG_TIME)
		Sfx.play(self, "thud", -12.0, 1.5)
		return Vector2.ZERO
	var to_p: Vector2 = target.global_position - global_position
	var dist := to_p.length()
	match mode:
		"idle", "amble", "display":
			_set_mode("go")
		"go":
			if dist > 0.01:
				facing = to_p / dist
			if dist < radius + 16.0 + BITE_REACH * 0.6 and sees(target.global_position):
				_set_mode("jaw", BITE_WINDUP)
				Sfx.play(self, "warn", -15.0, 1.4)
				return Vector2.ZERO
			return _go(target.global_position, speed, delta)
		"jaw":
			if mode_t > 0.1 and dist > 0.01:
				facing = to_p / dist
			if mode_t <= 0.0:
				_set_mode("bite", BITE_TIME)
				bit = false
		"bite":
			if not bit:
				bit = true
				var landed := false
				for p in players():
					var rel: Vector2 = p.global_position - global_position
					if rel.length() < radius + 16.0 + BITE_REACH and (rel.length() < 8.0 or facing.dot(rel.normalized()) > 0.3) and p.can_be_hit(self):
						p.take_damage(BITE, global_position, self)
						landed = true
				Sfx.play(self, "swing", -9.0, 1.5)
				if not landed:
					open_for(AFTER + BITE_TIME)
			if mode_t <= 0.0:
				_set_mode("after", AFTER)
		"after":
			if mode_t <= 0.0:
				_set_mode("go")
		"dig":
			if mode_t <= 0.0:
				_vanish()
	return Vector2.ZERO


## Gone into the ground: the heap of soil stays a moment where it was (the dig strip's last frame).
func _vanish() -> void:
	if dead:
		return
	fled = true
	dead = true
	var info := _art_info()
	var strip: Dictionary = info.get("strips", {}).get("dig", {})
	var box: Array = strip.get("box", [])
	if box.size() == 4 and is_instance_valid(get_parent()):
		var n := int(strip.get("frames", 1))
		var w := float(box[2]) / float(maxi(n, 1))
		var heap := SpriteOnce.new()
		heap.texture = strip_tex([float(box[0]) + w * float(n - 1), box[1], w, box[3]], MOOR_SHEET)
		heap.frames = 1
		heap.fps = 4.0
		heap.hold = MOUND
		heap.origin = Vector2(info["origin_feet"][0], info["origin_feet"][1])
		heap.feet = _feet()
		heap.flip = _flip("dig")
		get_parent().add_child(heap)
		heap.z_index = 0
		heap.global_position = global_position
	died.emit(self)
	queue_free()


func _anim() -> Array:
	if mode != "dig" and _hit_showing():
		return ["hit", hit_anim, false]
	match mode:
		"jaw":
			return ["bite", 0.0, false]
		"bite", "after":
			var t := BITE_TIME - mode_t if mode == "bite" else BITE_TIME
			return ["bite", 0.1 + t, false]
		"dig":
			return ["dig", (DIG_TIME - mode_t) / maxf(DIG_TIME, 0.05) * 0.375, false]
	return _walk_or_stand()
