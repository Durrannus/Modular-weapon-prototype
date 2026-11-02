class_name WeaponBuild
extends RefCounted
## The build grid for one weapon, and the rules that turn the parts on it
## into stats and a combo. All the rules live in this file so they're easy to tune.
##
## Combo: pommel move, then handle move, then hilt move (bottom of the sword up),
## then it loops. Blades add damage and elements. Charms add small bonuses.

signal changed

const GRID_W := 3
const GRID_H := 7

## The grid is drawn in the shape of a sword, tip at the top (row 0).
## b = blade, h = hilt, g = grip (handle), c = charm square, p = pommel,
## . = not part of the sword. Change this map to reshape the weapon.
const SHAPE_MAP := [
	"bbb",
	"bbb",
	"bbb",
	"hhh",
	"cgc",
	".g.",
	".p.",
]
const ZONE_NAMES := {"b": "blade", "h": "hilt", "g": "handle", "c": "charm", "p": "pommel"}

## Material multiplies a part's numbers (blade damage and stat bonuses).
const MATERIALS := {"wood": 1.0, "iron": 1.4}

## Elements and the combos two of them make.
const ELEMENT_COMBOS := [
	{"needs": ["fire", "water"], "name": "steam"},
	{"needs": ["water", "lightning"], "name": "electrified"},
]

## Colours for damage numbers and effects.
const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.5, 0.15),
	"water": Color(0.3, 0.65, 1.0),
	"lightning": Color(1.0, 0.92, 0.3),
	"steam": Color(0.88, 0.9, 0.95),
	"electrified": Color(0.4, 0.95, 1.0),
}

const BASE_DAMAGE := 4.0  # bare hilt, no blade
const BASE_CRIT := 0.05
const BASE_CRIT_DAMAGE := 1.5

## Each placement: {"part": PartData, "origin": Vector2i, "rotation": int, "cells": Array}
var placements: Array = []


static func rotated_shape(shape: Array, rotation: int) -> Array:
	var cells: Array = []
	for c in shape:
		var v: Vector2i = c
		for i in posmod(rotation, 4):
			v = Vector2i(-v.y, v.x)
		cells.append(v)
	var min_x := 1000
	var min_y := 1000
	for v in cells:
		min_x = mini(min_x, v.x)
		min_y = mini(min_y, v.y)
	var out: Array = []
	for v in cells:
		out.append(Vector2i(v.x - min_x, v.y - min_y))
	return out


static func material_mult(part: PartData) -> float:
	return float(MATERIALS.get(part.material, 1.0))


func cells_for(part: PartData, origin: Vector2i, rotation: int) -> Array:
	var out: Array = []
	for c in rotated_shape(part.shape, rotation):
		var v: Vector2i = c
		out.append(origin + v)
	return out


func placement_at(cell: Vector2i) -> Dictionary:
	for pl in placements:
		if cell in pl["cells"]:
			return pl
	return {}


func has_part(part: PartData) -> bool:
	for pl in placements:
		if pl["part"] == part:
			return true
	return false


func part_of_type(t: int) -> PartData:
	for pl in placements:
		if pl["part"].part_type == t:
			return pl["part"]
	return null


## The area a cell belongs to ("blade", "hilt", "handle", "charm", "pommel"),
## or "" if the cell isn't part of the weapon.
static func zone_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_W or cell.y >= GRID_H:
		return ""
	var row: String = SHAPE_MAP[cell.y]
	return ZONE_NAMES.get(row[cell.x], "")


## The area a part must go in.
static func zone_for(part: PartData) -> String:
	match part.part_type:
		PartData.PartType.POMMEL:
			return "pommel"
		PartData.PartType.HANDLE:
			return "handle"
		PartData.PartType.HILT:
			return "hilt"
		PartData.PartType.BLADE:
			return "blade"
	return "charm"


func can_place(part: PartData, origin: Vector2i, rotation: int) -> bool:
	return place_problem(part, origin, rotation) == ""


## Why a part can't go here, or "" if it can.
func place_problem(part: PartData, origin: Vector2i, rotation: int) -> String:
	if has_part(part):
		return "That part is already on the sword."
	# One of each part, except blades (several small blades) and charms.
	var t := part.part_type
	if t != PartData.PartType.BLADE and t != PartData.PartType.CHARM and part_of_type(t) != null:
		return "The sword already has a %s. Pick that one up first." % part.type_name().to_lower()
	var zone := zone_for(part)
	for c in cells_for(part, origin, rotation):
		var v: Vector2i = c
		var cell_zone := zone_at(v)
		if cell_zone == "":
			return "That goes off the sword."
		if not placement_at(v).is_empty():
			return "Something is already there."
		if cell_zone != zone:
			return "%ss only go in the %s area." % [part.type_name(), zone]
	return ""


func place(part: PartData, origin: Vector2i, rotation: int) -> bool:
	if not can_place(part, origin, rotation):
		return false
	placements.append({
		"part": part,
		"origin": origin,
		"rotation": rotation,
		"cells": cells_for(part, origin, rotation),
	})
	changed.emit()
	return true


func remove_at(cell: Vector2i) -> Dictionary:
	var pl := placement_at(cell)
	if not pl.is_empty():
		placements.erase(pl)
		changed.emit()
	return pl


## Placements from the bottom of the sword up (pommel first), left to right.
func ordered_placements() -> Array:
	var list: Array = placements.duplicate()
	list.sort_custom(_order_less)
	return list


func _order_less(a: Dictionary, b: Dictionary) -> bool:
	var ka := _order_key(a["cells"])
	var kb := _order_key(b["cells"])
	if ka.y != kb.y:
		return ka.y > kb.y
	return ka.x < kb.x


## The part's lowest row, and its leftmost cell in that row.
static func _order_key(cells: Array) -> Vector2i:
	var best := Vector2i(1000, -1)
	for c in cells:
		var v: Vector2i = c
		if v.y > best.y or (v.y == best.y and v.x < best.x):
			best = v
	return best


## Turns the grid into weapon stats and a combo.
## Returns a plain Dictionary (easy to send over the network later).
func compute() -> Dictionary:
	var pommel := part_of_type(PartData.PartType.POMMEL)
	var handle := part_of_type(PartData.PartType.HANDLE)
	var hilt := part_of_type(PartData.PartType.HILT)

	# Combo: one move per part, pommel -> handle -> hilt.
	var steps: Array = []
	for p in [pommel, handle, hilt]:
		if p != null and p.move != "":
			steps.append({"move": p.move, "from": p.type_name()})
	if steps.is_empty():
		steps.append({"move": "slash", "from": "Bare hands"})

	var damage := 0.0
	var reach := 0.0
	var weight := 1.0
	var elements: Array = []
	var blade_colors: Array = []
	var blade_cells := 0
	var attack_speed := 0.0
	var crit := BASE_CRIT
	var crit_damage := BASE_CRIT_DAMAGE
	var area := 0.0
	var move_speed := 0.0

	for pl in ordered_placements():
		var part: PartData = pl["part"]
		var m := material_mult(part)
		if part.part_type == PartData.PartType.BLADE:
			damage += part.damage * m
			reach = maxf(reach, part.reach)
			weight = minf(weight, part.weight)
			blade_colors.append(part.color)
			blade_cells += part.shape.size()
			if part.element != "" and not part.element in elements:
				elements.append(part.element)
		attack_speed += part.attack_speed * m
		crit += part.crit_chance * m
		crit_damage += part.crit_damage * m
		area += part.area * m
		move_speed += part.move_speed * m

	if blade_colors.is_empty():
		damage = BASE_DAMAGE
		reach = 0.6

	var combos: Array = []
	for c in ELEMENT_COMBOS:
		var all_there := true
		for e in c["needs"]:
			if not e in elements:
				all_there = false
		if all_there:
			combos.append(c["name"])

	# The colour this sword's hits show in: a combo first, then an element.
	var hit_color := Color.WHITE
	if not combos.is_empty():
		hit_color = ELEMENT_COLORS[combos[0]]
	elif not elements.is_empty():
		hit_color = ELEMENT_COLORS[elements[0]]

	return {
		"steps": steps,
		"hit_color": hit_color,
		"damage": damage,
		"reach": reach,
		"speed": (1.0 + attack_speed) * weight,
		"crit": crit,
		"crit_damage": crit_damage,
		"area": area,
		"move_speed": move_speed,
		"elements": elements,
		"combos": combos,
		"blade_colors": blade_colors,
		"big_blade": blade_cells >= 6 and blade_colors.size() == 1,
		"pommel_color": pommel.color if pommel != null else Color(0.5, 0.35, 0.2),
		"handle_color": handle.color if handle != null else Color(0.45, 0.3, 0.18),
		"hilt_color": hilt.color if hilt != null else Color(0.55, 0.38, 0.22),
	}
