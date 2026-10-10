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

const EcranFin := preload("res://scripts/ecran_fin.gd")
const FONT := preload("res://assets/fonts/FredokaOne-Regular.ttf")
## Fin d'un mini-jeu : temps laissé pour profiter des effets avant la transition / l'écran de défaite.
const WIN_DELAY := 1.6
const LOSE_DELAY := 0.9
## Transition de victoire : disque transparent qui se referme (rayon en fraction de la hauteur d'écran).
const IRIS_OPEN := 1.3
const IRIS_SHADER := """
shader_type canvas_item;
uniform float radius = 1.3;
uniform vec4 fill : source_color = vec4(0.169, 0.09, 0.063, 1.0);
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1280.0 / 720.0, 1.0);
	float edge = smoothstep(radius - 0.006, radius + 0.006, length(p));
	COLOR = vec4(fill.rgb, fill.a * edge);
}
"""

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
## La nuit : il faut réussir les 5 missions (mini-jeux) avant que le jour se lève.
enum NightState { RUNNING, WON, LATE }
const MISSIONS_TOTAL := 5
## Durée de la nuit, en secondes de jeu (maison + mini-jeux).
const NIGHT_DURATION := 300.0
var night_time := 0.0
var night_state := NightState.RUNNING

## Résultats des mini-jeux de la partie en cours, pour que la maison en garde les traces :
## { "souris": {"won": déjà gagné au moins une fois, "last": dernier résultat}, ... }
var results := {}
## Taches de pipi dans le lit du maître cette nuit : { "pos", "r", "seed" } (voir maison_pipi.gd).
var pee_stains: Array = []
## Le chat a avalé la lampe torche du canapé : il éclaire devant lui pour le reste de la nuit.
var has_torch := false

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
var _transitioning := false

## Réglages (page SETTINGS), gardés dans user://settings.cfg.
const SETTINGS_PATH := "user://settings.cfg"
## false = mode « clavier + souris » : la manette est ignorée partout (sauf dans la page des réglages).
var pad_enabled := true
var sound_off := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()


# --- Réglages ------------------------------------------------------------------------

func set_pad_enabled(on: bool) -> void:
	pad_enabled = on
	_save_settings()


func set_sound_off(off: bool) -> void:
	sound_off = off
	_apply_settings()
	_save_settings()


## Manettes à écouter (aucune en mode clavier + souris).
func pads() -> Array[int]:
	return Input.get_connected_joypads() if pad_enabled else [] as Array[int]


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		pad_enabled = cfg.get_value("controls", "pad_enabled", true)
		sound_off = cfg.get_value("audio", "sound_off", false)
	_apply_settings()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "pad_enabled", pad_enabled)
	cfg.set_value("audio", "sound_off", sound_off)
	cfg.save(SETTINGS_PATH)


func _apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), sound_off)


func launch_mini_game(scene_path: String, from_position: Vector2, from_rotation: float) -> void:
	cat_position = from_position
	cat_rotation = from_rotation
	get_tree().change_scene_to_file(scene_path)


func back_to_house() -> void:
	_release_click()
	get_tree().change_scene_to_file(HOUSE_SCENE)


func back_to_title() -> void:
	_reset_night()
	get_tree().change_scene_to_file(TITLE_SCENE)


## Recommence une nuit complète (bouton RETRY / TRY AGAIN des écrans de fin de nuit).
func restart_night() -> void:
	_reset_night()
	back_to_house()


## Une nouvelle nuit repart de la position de la maquette, dans une maison propre.
func _reset_night() -> void:
	cat_position = Vector2.INF
	cat_rotation = 0.0
	results.clear()
	pee_stains.clear()
	has_torch = false
	night_time = 0.0
	night_state = NightState.RUNNING


## Appelé par chaque mini-jeu à sa fin. Une victoire laisse ses traces pour de bon.
func record_result(game: String, won: bool) -> void:
	var r: Dictionary = results.get(game, {"won": false})
	r.won = r.won or won
	r.last = won
	results[game] = r
	# Toutes les missions faites avant le jour : le temps s'arrête, la maison affichera la victoire.
	if night_state == NightState.RUNNING and missions_done() >= MISSIONS_TOTAL:
		night_state = NightState.WON


# --- La nuit -------------------------------------------------------------------------

## Nombre de mini-jeux différents déjà gagnés cette nuit.
func missions_done() -> int:
	var n := 0
	for game in results:
		if results[game].won:
			n += 1
	return n


func is_mission_done(game: String) -> bool:
	return results.has(game) and results[game].won


## 0 = début de la nuit, 1 = le jour est levé.
func night_progress() -> float:
	return clampf(night_time / NIGHT_DURATION, 0.0, 1.0)


## La nuit avance dans la maison comme dans les mini-jeux (pas au menu titre).
func _tick_night(delta: float) -> void:
	if night_state != NightState.RUNNING or get_tree().paused:
		return
	var scene := get_tree().current_scene
	if scene == null or not (scene.scene_file_path == HOUSE_SCENE or _in_mini_game()):
		return
	night_time += delta
	if night_time >= NIGHT_DURATION:
		night_state = NightState.LATE
		# Trop tard : si on est dans un mini-jeu, retour à la maison où s'affiche « YOU LOSE ».
		if _in_mini_game():
			transition_to_house("THE SUN IS RISING…")


# --- Fin d'un mini-jeu ------------------------------------------------------------------

## Fin commune à tous les mini-jeux, après un court délai pour profiter des effets :
## victoire = transition fluide vers la maison (prochaine mission), défaite = écran « OOPSIE / TRY AGAIN ».
func end_mini_game(won: bool) -> void:
	var scene := get_tree().current_scene
	# Temps réel : les arrêts sur image des jeux ne doivent pas rallonger l'attente.
	await get_tree().create_timer(WIN_DELAY if won else LOSE_DELAY, true, false, true).timeout
	if get_tree().current_scene != scene:
		return  # le joueur est déjà parti (Échap / B)
	if won:
		transition_to_house()
	else:
		scene.add_child(EcranFin.defaite())


## Iris qui se ferme sur le mini-jeu, un message (« MISSION RÉUSSIE ! »), puis se rouvre sur la maison.
func transition_to_house(message := "MISSION COMPLETE!") -> void:
	if _transitioning:
		return
	_transitioning = true
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var iris := ColorRect.new()
	iris.size = Vector2(1280, 720)
	iris.mouse_filter = Control.MOUSE_FILTER_STOP  # pas de clic parasite pendant la transition
	var shader := Shader.new()
	shader.code = IRIS_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("radius", IRIS_OPEN)
	iris.material = mat
	layer.add_child(iris)
	var label := Label.new()
	label.text = message
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color("fff2e4"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(1280, 720)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ZERO
	layer.add_child(label)

	var close := create_tween()
	close.tween_method(func(r: float) -> void: mat.set_shader_parameter("radius", r), IRIS_OPEN, 0.0, 0.55) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	close.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	close.tween_interval(0.45)
	await close.finished
	back_to_house()
	# Laisse la maison se construire avant de rouvrir.
	await get_tree().process_frame
	await get_tree().process_frame
	var open := create_tween()
	open.tween_property(label, "modulate:a", 0.0, 0.2)
	open.tween_method(func(r: float) -> void: mat.set_shader_parameter("radius", r), 0.0, IRIS_OPEN, 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await open.finished
	layer.queue_free()
	_transitioning = false


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
	if not (event is InputEventJoypadButton) or not _in_mini_game() or not pad_enabled:
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
	_tick_night(delta)
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
	for pad in pads():
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
