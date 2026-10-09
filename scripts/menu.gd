extends Control

func _ready() -> void:
	Input.set_custom_mouse_cursor(
		preload("res://assets/sprites/curseur.png"),
		Input.CURSOR_ARROW,
		Vector2(30, 32)
	)

func _on_playgame_button_pressed() -> void:
	# Changement de scène immédiat : pas d'await, donc un double clic ne peut plus
	# relancer change_scene_to_file une fois le menu libéré.
	_play_click_detached()
	get_tree().change_scene_to_file(GameManager.HOUSE_SCENE)


## Joue le son du clic sur un lecteur attaché à la racine, pour qu'il ne soit
## pas coupé quand le menu est libéré par le changement de scène.
func _play_click_detached() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = $clickSound.stream
	player.finished.connect(player.queue_free)
	get_tree().root.add_child(player)
	player.play()


func _on_easteregg_pressed() -> void:
	$clickSound.play()


## Manette : A ou Start lance la partie, comme le bouton « Jouer ».
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed \
			and (event as InputEventJoypadButton).button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
		_on_playgame_button_pressed()
