extends CanvasLayer
## "Forging the land...": shown while a Highlands world is made (version 49). Making the land, from its number, out
## to the outer ring, and the plans of what lives on it, takes a few seconds, all at once; this stands on the screen
## meanwhile, so that the game is not seen to hang. Nothing on it moves.

const Art := preload("res://scripts/art.gd")
const SavePick := preload("res://scripts/ui/save_pick.gd")

var world_name := ""               # the saved world's name, if it has one
var older := false                 # it was saved on a land made differently: it is being laid out again
var root: Control


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.size = SavePick.SCREEN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.draw.connect(_draw_screen)


func _draw_screen() -> void:
	var silk := Art.font("Silkscreen-Regular")
	var pix := Art.font(Art.TEXT)
	var backdrop := Art.texture("swing/ui/title_backdrop.png")
	if backdrop != null:
		root.draw_texture(backdrop, Vector2.ZERO)
	else:
		root.draw_rect(Rect2(Vector2.ZERO, SavePick.SCREEN), SavePick.PLATE)
	var plate := Rect2(170, 138, 300, 84)
	if not Art.draw_nine(root, "swing/ui/panel.png", plate, 8):
		root.draw_rect(plate, SavePick.PLATE)
	_words(silk, Vector2(plate.position.x, plate.position.y + 36.0), "FORGING THE LAND...", 16, SavePick.AMBER, plate.size.x)
	var under := "Laying out the Greystone Highlands" if world_name == "" else world_name
	if older:
		under = "Laying out %s again" % (world_name if world_name != "" else "this world")
	_words(pix, Vector2(plate.position.x, plate.position.y + 58.0), under, Art.TEXT_SIZE, SavePick.DIM, plate.size.x)


func _words(f: Font, at: Vector2, text: String, size: int, col: Color, width: float) -> void:
	root.draw_string(f, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(SavePick.SHADOW, SavePick.SHADOW.a * col.a))
	root.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)
