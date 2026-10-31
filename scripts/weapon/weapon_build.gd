class_name WeaponBuild
extends RefCounted
## The build grid for one weapon, and the rules that turn the parts on it
## into a combo. All combining rules live in compute(), so they're easy to tune.
##
## Combo order: parts are read from the bottom of the weapon (handle end)
## to the top (tip). In the same row, left to right.

signal changed

const GRID_W := 3
const GRID_H := 6

## The grid is shaped like the weapon: each row belongs to an area, from the
## tip (row 0) down to the handle end. Blades, hilts and handles can only go
## in their own area. Gems are small and fit anywhere.
const ROW_ZONES := ["blade", "blade", "blade", "hilt", "hilt", "handle"]

## Pairs of parts that unlock a bonus when both are on the weapon.
const SYNERGIES := [
	{"parts": ["iron_crossguard", "ember_blade"], "name": "Forge-tempered", "text": "+20% crit chance", "crit": 0.20},
	{"parts": ["oak_hilt", "wooden_blade"], "name": "Matching grain", "text": "+15% attack speed", "speed": 0.15},
]

const BASE_DAMAGE := 6.0
const BASE_CRIT := 0.05
const BASE_STEPS := [["slash"], ["slash"]]

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


static func zone_of_row(row: int) -> String:
	return ROW_ZONES[row]


## The area a part must go in, or "" if it fits anywhere.
static func zone_for(part: PartData) -> String:
	match part.part_type:
		PartData.PartType.BLADE:
			return "blade"
		PartData.PartType.HILT:
			return "hilt"
		PartData.PartType.HANDLE:
			return "handle"
	return ""


func can_place(part: PartData, origin: Vector2i, rotation: int) -> bool:
	return place_problem(part, origin, rotation) == ""


## Why a part can't go here, or "" if it can.
func place_problem(part: PartData, origin: Vector2i, rotation: int) -> String:
	var zone := zone_for(part)
	for c in cells_for(part, origin, rotation):
		var v: Vector2i = c
		if v.x < 0 or v.y < 0 or v.x >= GRID_W or v.y >= GRID_H:
			return "That goes off the edge of the grid."
		if not placement_at(v).is_empty():
			return "Something is already there."
		if zone != "" and zone_of_row(v.y) != zone:
			return "%ss only go in the %s area." % [part.type_name(), zone]
	return ""


func place(part: PartData, origin: Vector2i, rotation: int) -> bool:
	if has_part(part) or not can_place(part, origin, rotation):
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


## Placements in combo order: bottom of the weapon first, then upward.
func ordered_placements() -> Array:
	var list: Array = placements.duplicate()
	list.sort_custom(_order_less)
	return list


func _order_less(a: Dictionary, b: Dictionary) -> bool:
	var ka := _order_key(a["cells"])
	var kb := _order_key(b["cells"])
	if ka.y != kb.y:
		return ka.y > kb.y  # lower on the grid (bigger y) comes first
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
## Returns a Dictionary the player reads every attack.
func compute() -> Dictionary:
	var ordered := ordered_placements()
	var hilt_moves: Array = []
	var blade: PartData = null
	var handle: PartData = null
	var hilt: PartData = null
	var effects: Array = []
	var notes: Array = []
	var ids := {}
	var conditional: Array = []

	for pl in ordered:
		var part: PartData = pl["part"]
		ids[part.id] = true
		if part.part_type == PartData.PartType.HILT:
			hilt_moves.append(part.moves)
			if hilt == null:
				hilt = part
		elif part.part_type == PartData.PartType.BLADE:
			if blade == null:
				blade = part
			else:
				notes.append("%s only adds its effect. The lowest blade sets damage." % part.display_name)
		elif part.part_type == PartData.PartType.HANDLE:
			if handle == null:
				handle = part
			else:
				notes.append("%s only adds its effect. The lowest handle sets speed." % part.display_name)

		if part.requires_effect != "":
			conditional.append(part)
		else:
			for e in part.effects:
				if not e in effects:
					effects.append(e)

	for part in conditional:
		if part.requires_effect in effects:
			for e in part.effects:
				if not e in effects:
					effects.append(e)
		else:
			notes.append("%s is asleep: it needs a part with \"%s\"." % [part.display_name, part.requires_effect])

	# Rule: hilts that change the same combo step merge into one move.
	# The lower hilt's move comes first (slash + stab = slash-stab).
	var steps: Array = []
	if hilt_moves.is_empty():
		steps = BASE_STEPS.duplicate(true)
	else:
		var length := 0
		for m in hilt_moves:
			length = maxi(length, m.size())
		for i in length:
			var step: Array = []
			for m in hilt_moves:
				if i < m.size():
					step.append(m[i])
			steps.append(step)

	var damage: float = BASE_DAMAGE
	var reach: float = 0.85
	if blade != null:
		damage = blade.damage
		reach = blade.reach
	var speed: float = 1.0
	if handle != null:
		speed = handle.speed
	var crit: float = BASE_CRIT

	var synergies: Array = []
	for s in SYNERGIES:
		var all_there := true
		for pid in s["parts"]:
			if not ids.has(pid):
				all_there = false
		if all_there:
			synergies.append("%s: %s" % [s["name"], s["text"]])
			crit += float(s.get("crit", 0.0))
			speed *= 1.0 + float(s.get("speed", 0.0))

	return {
		"steps": steps,
		"damage": damage,
		"reach": reach,
		"speed": speed,
		"crit": crit,
		"effects": effects,
		"notes": notes,
		"synergies": synergies,
		"hilt_color": hilt.color if hilt != null else Color(0.55, 0.38, 0.22),
		"blade_color": blade.color if blade != null else Color(0.7, 0.55, 0.35),
		"handle_color": handle.color if handle != null else Color(0.45, 0.3, 0.18),
	}
