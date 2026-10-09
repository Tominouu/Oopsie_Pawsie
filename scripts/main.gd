extends Control


const GAMES := {
	"AquariumButton": "res://scenes/mini_games/scene_aquarium.tscn",
	"CableButton": "res://scenes/mini_games/cable.tscn",
	"CroquettesButton": "res://scenes/mini_games/croquettes.tscn",
	"RythmeButton": "res://scenes/mini_games/rythme.tscn",
}


func _ready() -> void:
	for button_name in GAMES:
		var button: Button = $CenterContainer/VBoxContainer.get_node(button_name)
		button.pressed.connect(_on_game_button_pressed.bind(GAMES[button_name]))


func _on_game_button_pressed(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
