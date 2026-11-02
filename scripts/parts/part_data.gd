extends Resource
## One weapon part or charm. Every part is a .tres file in res://parts/.
## To add a part: duplicate a .tres file in the editor and change the values.
##
## A part's SHAPE sets what it does (its move, or a blade's element).
## Its MATERIAL sets how strong its numbers are (see MATERIALS in weapon_build.gd).

enum PartType { POMMEL, HANDLE, HILT, BLADE, CHARM }

@export var id: String = ""
@export var display_name: String = ""
## Keep this short: it's one line in the parts list.
@export var description: String = ""
@export var part_type: PartType = PartType.HILT
## "wood" or "iron" for now. Iron parts roll bigger numbers than wood.
@export var material: String = "wood"
## Cells the part covers on the build grid, as Vector2i offsets from its top-left.
## Parts must fit their own area of the grid without rotating.
@export var shape: Array = [Vector2i(0, 0)]
@export var color: Color = Color.WHITE

@export_group("Move")
## Pommels, handles and hilts each give ONE combo move:
## "slash", "stab", "lunge", "spin" or "overhead" (tuned in MOVES in player.gd).
@export var move: String = ""

@export_group("Blade")
## Blades add their damage together. Bigger blades hit harder.
@export var damage: float = 0.0
## Reach multiplier. The longest blade sets the reach.
@export var reach: float = 1.0
## Swing speed multiplier for heavy blades (below 1 = slower). The heaviest blade counts.
@export var weight: float = 1.0
## "fire", "water", "lightning", or "" for none.
@export var element: String = ""

@export_group("Stat bonuses")
## Fractions, so 0.15 = +15%. The part's material multiplies these.
@export var attack_speed: float = 0.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 0.0
@export var area: float = 0.0
@export var move_speed: float = 0.0


func type_name() -> String:
	match part_type:
		PartType.POMMEL:
			return "Pommel"
		PartType.HANDLE:
			return "Handle"
		PartType.HILT:
			return "Hilt"
		PartType.BLADE:
			return "Blade"
		_:
			return "Charm"
