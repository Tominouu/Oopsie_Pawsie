extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_playgame_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/mini_games/scene_aquarium.tscn")


func _on_easteregg_pressed() -> void:
	$clickSound.play()
const GAMES := {
	"AquariumButton": "res://scenes/mini_games/scene_aquarium.tscn",
	"CableButton": "res://scenes/mini_games/cable.tscn",
	"CroquettesButton": "res://scenes/mini_games/croquettes.tscn",
}


func _ready() -> void:
	for button_name in GAMES:
		var button: Button = $CenterContainer/VBoxContainer.get_node(button_name)
		button.pressed.connect(_on_game_button_pressed.bind(GAMES[button_name]))


func _on_game_button_pressed(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
