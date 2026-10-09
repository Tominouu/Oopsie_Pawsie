extends Node2D
## Oopsie Pawsie — mini-jeu « Élimine l'intrus » (maquette Figma « MINI JEU - SOURIS »).
## Le viseur suit la souris de l'ordi ; clic gauche = coup de patte. 5 coups pour
## éliminer la souris avant la fin du chrono, sans que la jauge de bruit déborde :
## chaque coup fait du bruit, et un coup raté en fait encore plus.

enum State { INTRO, PLAYING, FINISHED }

const Proie := preload("res://scripts/mini_games/souris_proie.gd")

const FONT := preload("res://assets/fonts/FredokaOne-Regular.ttf")
const HEADER_TEX := preload("res://assets/sprites/souris/header.svg")
const NUIT_TEX := preload("res://assets/sprites/souris/nuit.svg")
const SOURIS_TEX := preload("res://assets/sprites/souris/souris_corps.svg")
const QUEUE_TEX := preload("res://assets/sprites/souris/souris_queue.svg")
const PATTE_TEX := preload("res://assets/sprites/souris/patte.svg")
const SON_TEX := preload("res://assets/sprites/souris/son.svg")
const CHRONO_TEX := preload("res://assets/sprites/souris/chrono.svg")
const VISEUR_TEX := preload("res://assets/sprites/souris/viseur.svg")
const FERMER_TEX := preload("res://assets/sprites/souris/fermer.svg")
const GRIFFE_TEX := preload("res://assets/sprites/rythme/griffe.png")
const MEOW := preload("res://assets/sounds/meow1.mp3")

const SCREEN := Vector2(1280, 720)
const HEADER_H := 116.0

## Carrelage : tuiles de 251.25 × 277.38, joints de ~10 px (maquette).
const TILE_SIZE := Vector2(251.25, 277.38)
const TILE_STEP := Vector2(261.3, 287.43)
const TILE_ORIGIN := Vector2(-11.375, -186.55)

## Position de départ de la souris (centre du sprite) et son angle dans la maquette.
const SOURIS_START := Vector2(527.9, 474.2)
const SOURIS_START_ROT := -114.17
## Zone où le corps de la souris peut aller (évite le bandeau et la jauge).
const PLAYFIELD := Rect2(90, 190, 1040, 470)

## Point d'impact de la patte dans patte.svg (centre des coussinets).
const PAW_ANCHOR := Vector2(92.6, 90.0)
const PAW_REST_DROP := 150.0
const PAW_REST_MIN_Y := 430.0

const GAUGE_RECT := Rect2(1200, 295, 30, 226)
const CLOSE_RECT := Rect2(1075.5, 278.5, 33.66, 33.66)
## Marge autour de la croix pour la viser sans avoir à être au pixel près.
const CLOSE_MARGIN := 12.0

const HIT_RADIUS := 55.0
## Manette : rayon autour du corps où l'aide à la visée agit.
const PAD_ASSIST_RADIUS := 90.0
const STRIKE_COOLDOWN := 0.22
const NOISE_MAX := 100.0

const COL_GROUT := Color("ba9b7c")
const COL_TILE := Color("604a31")
const COL_CREAM := Color("fff2e4")
const COL_DARK := Color("2b1710")
const COL_BODY_TEXT := Color("6e4d41")
const COL_NOISE := Color("e01518")
const COL_CLOSE_BG := Color("d9d9d9")
const COL_PAW := Color("f89309")
const WIN_COLOR := Color(0.25, 0.85, 0.45)
const LOSE_COLOR := Color(0.95, 0.30, 0.30)

@export var time_limit := 30.0
@export_range(1, 20) var hits_to_kill := 5
## Bruit ajouté par un coup réussi / raté (sur 100). Avec 12 et 20 :
## 5 coups parfaits passent large, 3 ratés + les coups nécessaires font déborder.
@export var noise_per_hit := 12.0
@export var noise_per_miss := 20.0
@export var result_delay := 0.9

var _state := State.INTRO
## Vrai quand la pop-up vient d'être fermée avec A : le clic simulé qui suit ne doit pas compter.
var _skip_next_click := false
var _time_left := 0.0
var _noise := 0.0
var _noise_shown := 0.0
var _misses := 0
var _cooldown := 0.0

var _proie: Proie
var _paw: Sprite2D
var _paw_tween: Tween
var _striking := false
var _viseur: Sprite2D

var _time_label: Label
var _son_icon: TextureRect
var _gauge_fill: Panel
var _popup: Control
var _close_btn: Control
var _close_cross: TextureRect
var _overlay: ColorRect
var _title_label: Label
var _sub_label: Label
var _audio: AudioStreamPlayer


func _ready() -> void:
	randomize()
	_time_left = time_limit
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_build_hud_back()
	_build_proie()
	_build_gauge()
	_build_paw()
	_build_hud_front()
	_build_popup()
	_build_overlay()
	_build_viseur()
	_audio = AudioStreamPlayer.new()
	_audio.stream = MEOW
	add_child(_audio)
	_update_time_label()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Construction (ordre = ordre des calques de la maquette) ------------------

func _build_hud_back() -> void:
	_add_texture(HEADER_TEX, Vector2.ZERO)
	_add_texture(NUIT_TEX, Vector2(572.75, 24))


func _build_proie() -> void:
	_proie = Proie.new()
	_proie.texture = SOURIS_TEX
	_proie.tail_texture = QUEUE_TEX
	_proie.position = SOURIS_START
	_proie.rotation_degrees = SOURIS_START_ROT
	_proie.bounds = PLAYFIELD
	add_child(_proie)


func _build_gauge() -> void:
	add_child(_make_panel(GAUGE_RECT, COL_CREAM, 15))
	_gauge_fill = _make_panel(Rect2(GAUGE_RECT.position.x, GAUGE_RECT.end.y, GAUGE_RECT.size.x, 0), COL_NOISE, 15)
	add_child(_gauge_fill)


func _build_paw() -> void:
	_paw = Sprite2D.new()
	_paw.texture = PATTE_TEX
	_paw.centered = false
	_paw.offset = -PAW_ANCHOR
	_paw.position = Vector2(883.6, 403.0)
	add_child(_paw)
	# Prolonge le bras jusqu'en bas de l'écran quand la patte monte haut.
	var img := PATTE_TEX.get_image()
	var row := img.get_height() - 1
	var x0 := -1
	var x1 := -1
	for x in img.get_width():
		if img.get_pixel(x, row).a > 0.5:
			if x0 < 0:
				x0 = x
			x1 = x
	if x0 >= 0:
		var arm := Polygon2D.new()
		arm.color = COL_PAW
		var top := float(row) - PAW_ANCHOR.y
		arm.polygon = PackedVector2Array([
			Vector2(x0 - PAW_ANCHOR.x, top), Vector2(x1 + 1 - PAW_ANCHOR.x, top),
			Vector2(x1 + 1 - PAW_ANCHOR.x, top + SCREEN.y), Vector2(x0 - PAW_ANCHOR.x, top + SCREEN.y),
		])
		arm.show_behind_parent = true
		_paw.add_child(arm)


func _build_hud_front() -> void:
	# Icône haut-parleur : le SVG déborde de ~2 px autour du groupe de la maquette.
	_son_icon = _add_texture(SON_TEX, Vector2(1188, 235) - Vector2(2.07, 2.07))
	_son_icon.pivot_offset = _son_icon.size * 0.5

	add_child(_make_panel(Rect2(46, 22, 214.272, 69.12), COL_CREAM, 35))
	_add_texture(CHRONO_TEX, Vector2(68.46, 32.37))
	_time_label = _make_label(43, COL_DARK)
	_time_label.position = Vector2(122.03, 30.64)
	add_child(_time_label)


func _build_popup() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_popup = Control.new()
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_popup)

	var box := Panel.new()
	box.position = Vector2(162, 262)
	box.size = Vector2(966, 327)
	# Sinon le Panel avale les clics et la croix ne reçoit jamais le tir.
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = COL_CREAM
	style.border_color = COL_DARK
	style.set_border_width_all(6)
	style.set_corner_radius_all(18)
	box.add_theme_stylebox_override("panel", style)
	_popup.add_child(box)

	var title := _make_label(42, COL_DARK)
	title.text = "ELIMINATE THE INTRUDER"
	title.position = Vector2(215, 328)
	title.size = Vector2(860, 45)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup.add_child(title)

	var body := _make_label(32, COL_BODY_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(872, 0)
	body.text = "Get rid of the mouse without making too much noise within the time limit. " \
		+ "The indicator goes up with each paw swipe, be careful not to go over the limit."
	body.position = Vector2(209, 395)
	body.size = Vector2(872, 196)
	_popup.add_child(body)

	# Bouton fermer : on regroupe fond + croix pour pouvoir le faire réagir au survol du viseur.
	_close_btn = Control.new()
	_close_btn.position = CLOSE_RECT.position
	_close_btn.size = CLOSE_RECT.size
	_close_btn.pivot_offset = CLOSE_RECT.size * 0.5
	_close_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(_close_btn)
	_close_btn.add_child(_make_panel(Rect2(Vector2.ZERO, CLOSE_RECT.size), COL_CLOSE_BG, 4))
	_close_cross = _add_texture(FERMER_TEX, Vector2(1081.44, 286.32) - CLOSE_RECT.position, false)
	_close_btn.add_child(_close_cross)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	_overlay.size = SCREEN
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)

	_title_label = _make_label(96, Color.WHITE)
	_title_label.add_theme_constant_override("outline_size", 10)
	_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_title_label.position = Vector2(0, SCREEN.y * 0.5 - 120)
	_title_label.size = Vector2(SCREEN.x, 130)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_title_label)

	_sub_label = _make_label(26, Color.WHITE)
	_sub_label.position = Vector2(0, SCREEN.y * 0.5 + 20)
	_sub_label.size = Vector2(SCREEN.x, 50)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_sub_label)


func _build_viseur() -> void:
	# Le viseur remplace le curseur : il passe au-dessus de tout.
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_viseur = Sprite2D.new()
	_viseur.texture = VISEUR_TEX
	_viseur.position = Vector2(583, 474)
	layer.add_child(_viseur)


func _add_texture(tex: Texture2D, pos: Vector2, attach := true) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.position = pos
	t.size = tex.get_size()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if attach:
		add_child(t)
	return t


func _make_panel(rect: Rect2, color: Color, radius: int) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", style)
	return p


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- Entrées -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		GameManager.back_to_house()
		return
	if event is InputEventMouse:
		# Le viseur suit exactement la position de l'événement (pas de décalage d'une frame).
		_viseur.position = (event as InputEventMouse).position
	# Manette : A ou Start ferme la pop-up sans avoir à viser la croix.
	if _state == State.INTRO and event is InputEventJoypadButton and event.pressed \
			and (event as InputEventJoypadButton).button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
		# Le clic que GameManager simule pour ce même A arrive juste après : on l'ignore.
		_skip_next_click = (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
		_start_game()
		return
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	if _skip_next_click:
		_skip_next_click = false
		return

	match _state:
		State.INTRO:
			if _is_over_close(_viseur.position):
				_start_game()
		State.PLAYING:
			if _cooldown <= 0.0:
				_strike(make_input_local(event).position)
		State.FINISHED:
			if _overlay.visible:
				get_tree().reload_current_scene()


func _is_over_close(p: Vector2) -> bool:
	return CLOSE_RECT.grow(CLOSE_MARGIN).has_point(p)


func _start_game() -> void:
	_state = State.PLAYING
	var tween := _popup.create_tween()
	tween.tween_property(_popup, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_popup.hide)


# --- Boucle ------------------------------------------------------------------

func _process(delta: float) -> void:
	_viseur.position = get_viewport().get_mouse_position()
	_proie.set_process(_state == State.PLAYING or _proie.is_dead())

	if _state == State.INTRO:
		var hover := _is_over_close(_viseur.position)
		_close_btn.scale = Vector2.ONE * (1.2 if hover else 1.0)
		_close_cross.modulate = COL_NOISE if hover else Color.WHITE

	if not _striking:
		_paw.position = _paw.position.lerp(_paw_rest_position(), minf(1.0, 10.0 * delta))

	_noise_shown = move_toward(_noise_shown, _noise, 120.0 * delta)
	var h := GAUGE_RECT.size.y * clampf(_noise_shown / NOISE_MAX, 0.0, 1.0)
	_gauge_fill.position.y = GAUGE_RECT.end.y - h
	_gauge_fill.size.y = h
	_gauge_fill.visible = h > 0.5
	if _noise >= NOISE_MAX * 0.7 and _state == State.PLAYING:
		_son_icon.scale = Vector2.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.02))
	else:
		_son_icon.scale = Vector2.ONE

	if _state != State.PLAYING:
		return
	# Manette : le viseur freine et colle un peu au corps de la souris (sans effet à la souris).
	GameManager.pad_aim_assist(_proie.body_position(), PAD_ASSIST_RADIUS)
	_cooldown = maxf(0.0, _cooldown - delta)
	_time_left = maxf(_time_left - delta, 0.0)
	_update_time_label()
	if _time_left <= 0.0:
		_finish(false, "Temps écoulé : la souris court toujours !")


func _paw_rest_position() -> Vector2:
	var target := _viseur.position
	return Vector2(clampf(target.x, 80.0, SCREEN.x - 80.0), maxf(target.y + PAW_REST_DROP, PAW_REST_MIN_Y))


func _update_time_label() -> void:
	_time_label.text = "00:%02d" % ceili(_time_left)


# --- Coup de patte -------------------------------------------------------------

func _strike(at: Vector2) -> void:
	_cooldown = STRIKE_COOLDOWN
	_animate_paw(Vector2(at.x, maxf(at.y, HEADER_H)))

	var hit := at.distance_to(_proie.body_position()) <= HIT_RADIUS
	if hit:
		_noise += noise_per_hit
		var lethal := _proie.hits + 1 >= hits_to_kill
		_proie.take_hit(lethal)
		_spawn_griffe(at)
		if lethal:
			_finish(true, "Souris éliminée en %d coups  ·  Bruit %d %%" % [_proie.hits + _misses, roundi(_noise)])
			return
	elif _proie.tail_hit_test(at):
		# Coup réussi côté bruit, mais sans dégât : la souris perd juste sa queue.
		_noise += noise_per_hit
		_proie.lose_tail(self)
		_spawn_griffe(at)
		_pop_text("SNIP !", at)
	else:
		_misses += 1
		_noise += noise_per_miss

	if _noise >= NOISE_MAX:
		_finish(false, "Trop de bruit : la souris s'est enfuie !")


func _animate_paw(at: Vector2) -> void:
	if _paw_tween:
		_paw_tween.kill()
	_striking = true
	_paw_tween = create_tween()
	_paw_tween.tween_property(_paw, "position", at, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_paw_tween.tween_interval(0.06)
	_paw_tween.tween_property(_paw, "position", _paw_rest_position(), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_paw_tween.tween_callback(func() -> void: _striking = false)


func _spawn_griffe(at: Vector2) -> void:
	var g := Sprite2D.new()
	g.texture = GRIFFE_TEX
	g.position = at
	g.rotation = randf_range(-0.4, 0.4)
	g.scale = Vector2.ONE * 0.5
	g.modulate.a = 0.0
	add_child(g)
	move_child(g, _proie.get_index() + 1)
	var tween := g.create_tween()
	tween.tween_property(g, "modulate:a", 1.0, 0.05)
	tween.tween_interval(0.15)
	tween.tween_property(g, "modulate:a", 0.0, 0.35)
	tween.tween_callback(g.queue_free)


func _pop_text(text: String, at: Vector2) -> void:
	var l := _make_label(40, COL_CREAM)
	l.text = text
	l.add_theme_color_override("font_outline_color", COL_DARK)
	l.add_theme_constant_override("outline_size", 10)
	l.size = Vector2(240, 50)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = at - Vector2(120, 90)
	l.pivot_offset = l.size * 0.5
	l.rotation = randf_range(-0.2, 0.2)
	l.scale = Vector2.ONE * 0.4
	add_child(l)
	move_child(l, _paw.get_index() + 1)
	var tween := l.create_tween()
	tween.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(l, "position:y", l.position.y - 40, 0.8)
	tween.tween_property(l, "modulate:a", 0.0, 0.25)
	tween.tween_callback(l.queue_free)


func _finish(won: bool, message: String) -> void:
	_state = State.FINISHED
	if won:
		_audio.play()
	_title_label.text = "PAWSOME !" if won else "OOPSIE !"
	_title_label.add_theme_color_override("font_color", WIN_COLOR if won else LOSE_COLOR)
	_sub_label.text = "%s   ·   Clic pour rejouer   ·   Échap / B : maison" % message
	await get_tree().create_timer(result_delay).timeout
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.4)


# --- Dessin ------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), COL_GROUT)
	var y := TILE_ORIGIN.y
	while y < SCREEN.y:
		var x := TILE_ORIGIN.x
		while x < SCREEN.x:
			draw_rect(Rect2(Vector2(x, y), TILE_SIZE), COL_TILE)
			x += TILE_STEP.x
		y += TILE_STEP.y
