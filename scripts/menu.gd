extends Control


func _on_playgame_button_pressed() -> void:
	$clickSound.play()
	await $clickSound.finished
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_easteregg_pressed() -> void:
	$clickSound.play()
