extends Node
## Oopsie Pawsie — état global (autoload « GameManager »).
## Retient où était le chat dans la maison pour l'y remettre au retour d'un mini-jeu,
## et rend tous les mini-jeux jouables à la manette (Xbox) :
##   stick gauche = déplace le curseur, stick droit = pareil mais plus lent (visée fine),
##   LT maintenu = mode précision, A ou RT = clic gauche (maintenir = maintenir le clic),
##   B = retour à la maison, Y = recommencer (touche R).
## Les jeux peuvent aider le joueur : set_pad_precision() ralentit le curseur,
## pad_aim_assist() le freine et l'attire près d'une cible, pad_pull() le guide.

const HOUSE_SCENE := "res://scenes/maison.tscn"
const TITLE_SCENE := "res://scenes/menu.tscn"

const CURSOR_SPEED := 950.0
## Le stick droit déplace le curseur moins vite, pour viser finement.
const RIGHT_STICK_FACTOR := 0.35
## Vitesse en mode précision (LT maintenue).
const PRECISION_FACTOR := 0.3
const PAD_DEADZONE := 0.2
const TRIGGER_THRESHOLD := 0.5
## Au-delà de cet écart, on considère que la vraie souris a bougé : le curseur manette repart de là.
const MOUSE_RESYNC := 3.0

## Position / orientation du chat dans la maison ; INF = pas encore placé (position de la maquette).
var cat_position := Vector2.INF
var cat_rotation := 0.0
## Résultats des mini-jeux de la partie en cours, pour que la maison en garde les traces :
## { "souris": {"won": déjà gagné au moins une fois, "last": dernier résultat}, ... }
var results := {}

var _button_click := false
var _trigger_click := false
var _click_held := false
## Position du curseur manette, gardée en flottant : la souris de l'OS n'a que des pixels entiers
## et arrondir à chaque image ralentissait le curseur dans un sens et l'accélérait dans l'autre.
var _cursor := Vector2.INF
var _last_warp := Vector2.INF
## Aides demandées par le jeu pour l'image en cours (remises à zéro après usage).
var _precision := 1.0
var _assist_targets: Array[Vector3] = []   # (x, y, rayon)
var _pull := Vector2.INF
var _pull_strength := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func launch_mini_game(scene_path: String, from_position: Vector2, from_rotation: float) -> void:
	cat_position = from_position
	cat_rotation = from_rotation
	get_tree().change_scene_to_file(scene_path)


func back_to_house() -> void:
	_release_click()
	get_tree().change_scene_to_file(HOUSE_SCENE)


func back_to_title() -> void:
	# Une nouvelle partie repart de la position de la maquette, dans une maison propre.
	cat_position = Vector2.INF
	cat_rotation = 0.0
	results.clear()
	get_tree().change_scene_to_file(TITLE_SCENE)


## Appelé par chaque mini-jeu à sa fin. Une victoire laisse ses traces pour de bon.
func record_result(game: String, won: bool) -> void:
	var r: Dictionary = results.get(game, {"won": false})
	r.won = r.won or won
	r.last = won
	results[game] = r


# --- Aides à la manette, appelées par les mini-jeux à chaque image ------------------

## Multiplie la vitesse du curseur manette pour cette image (ex. 0.35 pendant qu'on traîne le câble).
func set_pad_precision(factor: float) -> void:
	_precision = minf(_precision, factor)


## Près de `target` (dans le rayon), le curseur ralentit et est légèrement attiré vers la cible.
func pad_aim_assist(target: Vector2, radius: float) -> void:
	_assist_targets.append(Vector3(target.x, target.y, radius))


## Attire doucement le curseur vers `point` pendant qu'on bouge le stick (ex. recentrer dans un couloir).
func pad_pull(point: Vector2, strength: float) -> void:
	_pull = point
	_pull_strength = strength


# --- Manette dans les mini-jeux ------------------------------------------------------

## Les mini-jeux se jouent à la souris : la manette y pilote donc la souris.
## (Dans la maison, le stick déplace le chat : c'est maison.gd qui s'en occupe.)
func _in_mini_game() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.contains("/mini_games/")


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton) or not _in_mini_game():
		return
	var jb := event as InputEventJoypadButton
	match jb.button_index:
		JOY_BUTTON_A:
			# Pas de set_input_as_handled : le jeu reçoit aussi le bouton A (ex. fermer la pop-up).
			_button_click = jb.pressed
			_update_click()
		JOY_BUTTON_B:
			if jb.pressed:
				get_viewport().set_input_as_handled()
				back_to_house()
		JOY_BUTTON_Y:
			if jb.pressed:
				get_viewport().set_input_as_handled()
				_send_key(KEY_R)


func _process(delta: float) -> void:
	var precision := _precision
	var targets := _assist_targets.duplicate()
	var pull := _pull
	var pull_strength := _pull_strength
	_precision = 1.0
	_assist_targets.clear()
	_pull = Vector2.INF

	if not _in_mini_game():
		_release_click()
		_cursor = Vector2.INF
		return

	var stick := Vector2.ZERO
	var trigger_left := 0.0
	var trigger_right := 0.0
	for pad in Input.get_connected_joypads():
		stick += _stick(pad, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
		stick += _stick(pad, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y) * RIGHT_STICK_FACTOR
		trigger_left = maxf(trigger_left, Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT))
		trigger_right = maxf(trigger_right, Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT))

	# RT = clic (laisse le pouce droit libre pour le stick droit).
	var rt := trigger_right > TRIGGER_THRESHOLD
	if rt != _trigger_click:
		_trigger_click = rt
		_update_click()

	if stick == Vector2.ZERO:
		return

	var vp := get_viewport()
	var real := vp.get_mouse_position()
	if not _cursor.is_finite() or real.distance_to(_last_warp) > MOUSE_RESYNC:
		_cursor = real

	if trigger_left > TRIGGER_THRESHOLD:
		precision *= PRECISION_FACTOR
	for t in targets:
		var target := Vector2(t.x, t.y)
		var d := _cursor.distance_to(target)
		if d < t.z:
			# Freine près de la cible et l'attire un peu (aide à la visée).
			precision *= lerpf(0.35, 1.0, d / t.z)
			_cursor = _cursor.move_toward(target, 160.0 * delta * (1.0 - d / t.z))

	var from := _cursor
	_cursor += stick * CURSOR_SPEED * precision * delta
	if pull.is_finite():
		_cursor = _cursor.lerp(pull, clampf(pull_strength * delta, 0.0, 1.0))
	_cursor = _cursor.clamp(Vector2.ZERO, vp.get_visible_rect().size - Vector2.ONE)

	# Déplace la vraie souris (les jeux lisent get_mouse_position) et prévient les jeux
	# qui réagissent aux mouvements (ex. le câble qu'on traîne).
	vp.warp_mouse(_cursor)
	_last_warp = _cursor
	var motion := InputEventMouseMotion.new()
	motion.position = _to_window(_cursor)
	motion.global_position = motion.position
	motion.relative = _cursor - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _click_held else 0
	Input.parse_input_event(motion)


## Vecteur du stick avec zone morte et courbe progressive (petits mouvements = précis).
## La zone morte est ronde : la vitesse ne dépend que de l'inclinaison, pas de la direction.
func _stick(pad: int, axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	var v := Vector2(Input.get_joy_axis(pad, axis_x), Input.get_joy_axis(pad, axis_y))
	var length := v.length()
	if length <= PAD_DEADZONE:
		return Vector2.ZERO
	var k := clampf((length - PAD_DEADZONE) / (1.0 - PAD_DEADZONE), 0.0, 1.0)
	return v / length * k * k


func _update_click() -> void:
	var held := _button_click or _trigger_click
	if held == _click_held:
		return
	_click_held = held
	_send_click(held)


func _release_click() -> void:
	_button_click = false
	_trigger_click = false
	_click_held = false


func _send_click(pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	# Position précise du curseur manette, sauf si la vraie souris a bougé depuis.
	var pos := get_viewport().get_mouse_position()
	if _cursor.is_finite() and pos.distance_to(_last_warp) <= MOUSE_RESYNC:
		pos = _cursor
	click.position = _to_window(pos)
	click.global_position = click.position
	Input.parse_input_event(click)


func _send_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		Input.parse_input_event(key)


## Les événements injectés sont en coordonnées de fenêtre (différentes du jeu si la fenêtre est agrandie).
func _to_window(viewport_pos: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * viewport_pos
