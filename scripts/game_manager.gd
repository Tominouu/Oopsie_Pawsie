extends Node
## Oopsie Pawsie — état global (autoload « GameManager »).
## Retient où était le chat dans la maison pour l'y remettre au retour d'un mini-jeu.

const HOUSE_SCENE := "res://scenes/maison.tscn"
const TITLE_SCENE := "res://scenes/menu.tscn"

## Position / orientation du chat dans la maison ; INF = pas encore placé (position de la maquette).
var cat_position := Vector2.INF
var cat_rotation := 0.0


func launch_mini_game(scene_path: String, from_position: Vector2, from_rotation: float) -> void:
	cat_position = from_position
	cat_rotation = from_rotation
	get_tree().change_scene_to_file(scene_path)


func back_to_house() -> void:
	get_tree().change_scene_to_file(HOUSE_SCENE)


func back_to_title() -> void:
	# Une nouvelle partie repart de la position de la maquette.
	cat_position = Vector2.INF
	cat_rotation = 0.0
	get_tree().change_scene_to_file(TITLE_SCENE)
