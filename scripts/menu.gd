extends Control

func _ready() -> void:
	Input.set_custom_mouse_cursor(
		preload("res://assets/sprites/curseur.png"),
		Input.CURSOR_ARROW,
		Vector2(30, 32)
	)

func _on_playgame_button_pressed() -> void:
	$clickSound.play()
	await $clickSound.finished
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_easteregg_pressed() -> void:
	$clickSound.play()
