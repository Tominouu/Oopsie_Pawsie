extends Control

const Parametres := preload("res://scripts/parametres.gd")
## Bouton « SETTINGS » de la maquette (le fond est une image, on pose une zone cliquable dessus).
const SETTINGS_RECT := Rect2(432, 486, 395, 87)


func _ready() -> void:
	Input.set_custom_mouse_cursor(
		preload("res://assets/sprites/curseur.png"),
		Input.CURSOR_ARROW,
		Vector2(30, 32)
	)
	var settings := Button.new()
	settings.flat = true
	settings.modulate = Color(1, 1, 1, 0)
	settings.position = SETTINGS_RECT.position
	settings.size = SETTINGS_RECT.size
	settings.z_index = 10
	settings.pressed.connect(_open_settings)
	add_child(settings)


func _on_playgame_button_pressed() -> void:
	# Changement de scène immédiat : pas d'await, donc un double clic ne peut plus
	# relancer change_scene_to_file une fois le menu libéré.
	_play_click_detached()
	get_tree().change_scene_to_file(GameManager.HOUSE_SCENE)


func _open_settings() -> void:
	$clickSound.play()
	Parametres.open(self)


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


## Manette : A ou Start lance la partie, comme le bouton « Jouer » ; View (Back) ouvre les réglages.
## (Les réglages s'ouvrent même en mode clavier + souris, pour pouvoir y réactiver la manette.)
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton and event.pressed):
		return
	var button := (event as InputEventJoypadButton).button_index
	if button == JOY_BUTTON_BACK:
		_open_settings()
	elif GameManager.pad_enabled and button in [JOY_BUTTON_A, JOY_BUTTON_START]:
		_on_playgame_button_pressed()
