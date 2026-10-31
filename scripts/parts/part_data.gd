class_name PartData
extends Resource
## One weapon part. Every part is a .tres file in res://parts/.
## To add a part: duplicate a .tres file in the editor and change the values.
## No code needed unless you invent a brand new move or effect.

enum PartType { HILT, BLADE, HANDLE, GEM }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var part_type: PartType = PartType.HILT
@export var material: String = "wood"
## Cells the part covers on the build grid, as Vector2i offsets from its top-left.
@export var shape: Array = [Vector2i(0, 0)]
@export var color: Color = Color.WHITE

@export_group("Hilt")
## The moves this hilt adds to the combo, one per combo step.
## Known moves: "slash", "stab", "spin" (see MOVES in player.gd).
@export var moves: Array = []

@export_group("Stats")
## Blades: base damage. The first blade (closest to the handle) sets damage.
@export var damage: float = 0.0
## Blades: reach multiplier.
@export var reach: float = 1.0
## Handles: attack speed multiplier. The first handle sets speed.
@export var speed: float = 1.0

@export_group("Effects")
## Effects this part switches on: "wave", "burn", "split", "dodge"
## ("lunge" also works: the last combo hit dashes forward).
@export var effects: Array = []
## If set, the part only works when another part provides this effect.
@export var requires_effect: String = ""


func type_name() -> String:
	match part_type:
		PartType.HILT:
			return "Hilt"
		PartType.BLADE:
			return "Blade"
		PartType.HANDLE:
			return "Handle"
		_:
			return "Gem"
