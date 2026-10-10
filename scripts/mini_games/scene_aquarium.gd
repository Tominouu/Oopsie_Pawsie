extends Node2D
## Oopsie Pawsie — mini-jeu de l'aquarium (maquette Figma « MINI JEU - AQUARIUM »).
## Parmi tous les poissons rouges se cache un poisson rose : pêche-le d'un coup de patte
## avant la fin du chrono. Chaque plouf fait du bruit, et un mauvais poisson (éjecté sur
## le parquet) encore plus : si la jauge déborde, toute la maison se réveille.

enum State { INTRO, PLAYING, FINISHED }

const Fish := preload("res://scripts/mini_games/fishs_red.gd")
const Eau := preload("res://scripts/mini_games/aquarium_eau.gd")
const SON_TEX := preload("res://assets/sprites/aquarium/son.svg")
const MEOW := preload("res://assets/sounds/meow1.mp3")

const FONT := preload("res://assets/fonts/FredokaOne-Regular.ttf")
const FOND_TEX := preload("res://assets/sprites/aquarium/fond_bois.svg")
const HEADER_TEX := preload("res://assets/sprites/aquarium/header.svg")
const CHRONO_TEX := preload("res://assets/sprites/aquarium/chrono.svg")
const REGLAGES_TEX := preload("res://assets/sprites/aquarium/reglages.svg")
const FERMER_TEX := preload("res://assets/sprites/aquarium/fermer.svg")
const PATTE_TEX := preload("res://assets/sprites/aquarium/patte.svg")
## Les deux variantes de poisson de la maquette (la « gauche » y est retournée par une transformation).
const POISSON_DROITE_TEX := preload("res://assets/sprites/aquarium/poisson.svg")
const POISSON_GAUCHE_TEX := preload("res://assets/sprites/aquarium/poisson_gauche.svg")
## Le poisson rose de la maquette (tourné à droite), donné à un poisson tiré au hasard.
const POISSON_ROSE_TEX := preload("res://assets/sprites/aquarium/poisson_rose.svg")
const VISEUR_TEX := preload("res://assets/sprites/aquarium/viseur.svg")

const SCREEN := Vector2(1280, 720)

## Aquarium : rectangle extérieur et épaisseur de la bordure (maquette).
const TANK_RECT := Rect2(121, 158, 1038, 511)
const TANK_BORDER := 9
const TANK_RADIUS := 25

## Position de chaque poisson dans la maquette ; true = tourné à droite.
## Les poissons tournés à gauche sont des copies retournées : Figma donne leur bord DROIT en x.
const FISH_LAYOUT := [
	[Vector2(252.76, 391.37), true], [Vector2(510.23, 309.52), true], [Vector2(472.52, 341.71), true],
	[Vector2(335.52, 262.62), true], [Vector2(212.12, 273.74), true], [Vector2(148.06, 459.42), true],
	[Vector2(251.85, 494.29), true], [Vector2(644.50, 236.87), true], [Vector2(754.85, 338.95), true],
	[Vector2(1038.38, 401.04), true], [Vector2(922.23, 271.82), true], [Vector2(806.36, 227.67), true],
	[Vector2(308.86, 368.38), true], [Vector2(157.79, 344.28), true], [Vector2(409.98, 464.03), true],
	[Vector2(535.06, 535.76), true], [Vector2(625.18, 476.90), true], [Vector2(821.99, 505.41), true],
	[Vector2(782.00, 582.00), true], [Vector2(1002.70, 497.53), true], [Vector2(702.44, 395.05), true],
	[Vector2(586.56, 276.42), true], [Vector2(855.10, 291.13), true], [Vector2(533.22, 443.79), true],
	[Vector2(412.74, 463.11), false], [Vector2(280.62, 536.46), false], [Vector2(290.35, 418.88), false],
	[Vector2(467.92, 332.52), false], [Vector2(331.71, 329.69), false], [Vector2(240.08, 255.09), false],
	[Vector2(330.93, 223.08), false], [Vector2(673.93, 407.01), false], [Vector2(553.45, 519.21), false],
	[Vector2(504.71, 535.76), false], [Vector2(419.18, 529.32), false], [Vector2(524.02, 402.41), false],
	[Vector2(757.61, 523.80), false], [Vector2(730.94, 331.60), false], [Vector2(651.85, 338.95), false],
	[Vector2(906.53, 374.00), false], [Vector2(822.91, 460.35), false], [Vector2(1079.53, 327.00), false],
	[Vector2(1116.53, 228.00), false], [Vector2(977.41, 418.04), false], [Vector2(826.59, 247.91), false],
	[Vector2(503.79, 243.31), false],
]

## Patte : centre et rotation dans la maquette (recalés sur la position des griffes).
const PAW_CENTER := Vector2(1029.8, 604.3)
const PAW_ROTATION := -32.86
## Point d'impact dans patte.svg (centre des coussinets).
const PAW_ANCHOR := Vector2(92.6, 90.0)

const CLOSE_RECT := Rect2(1075.5, 278.5, 33.66, 33.66)
## Marge autour de la croix pour la viser sans avoir à être au pixel près.
const CLOSE_MARGIN := 12.0

## Jauge de bruit : même emplacement et même style que dans le mini-jeu de la souris.
const GAUGE_RECT := Rect2(1200, 295, 30, 226)
const NOISE_MAX := 100.0
## Délai mini entre deux coups de patte (le temps que la patte revienne un peu).
const DIP_COOLDOWN := 0.3
## Rayon autour du plouf dans lequel les poissons paniquent.
const PANIC_RADIUS := 230.0
## Manette : le viseur freine sur le poisson le plus proche (n'importe lequel, pour ne rien dévoiler).
const PAD_ASSIST_RADIUS := 60.0
const DIP_WORDS := ["PLOP!", "SPLASH!", "BLOOP!", "SPLOOSH!"]
const WRONG_WORDS := ["OOPS!", "NOT HIM!", "MISS!", "YUCK!"]
## Où atterrissent les poissons éjectés : bandes de parquet libres autour de l'aquarium.
const LANDING_ZONES := [Rect2(22, 190, 70, 440), Rect2(170, 684, 700, 20), Rect2(170, 128, 900, 14)]

const COL_WATER := Color("c0d9e1")
const COL_NOISE := Color("e01518")
const COL_TANK_BORDER := Color("569da9")
const COL_CREAM := Color("fff2e4")
const COL_DARK := Color("2b1710")
const COL_BODY_TEXT := Color("6e4d41")
const COL_CLOSE_BG := Color("d9d9d9")
const COL_PAW := Color("f89309")
const WIN_COLOR := Color(0.25, 0.85, 0.45)
const LOSE_COLOR := Color(0.95, 0.30, 0.30)

@export var time_limit := 30.0
@export var result_delay := 0.9
## Bruit d'un plouf (tout coup de patte dans l'eau), et en plus pour un mauvais poisson attrapé.
## Avec 8 et 20 : 3 mauvais poissons (+ un plouf dans le vide) passent, le 4e réveille la maison.
@export var noise_per_dip := 8.0
@export var noise_per_wrong_fish := 20.0

var _state := State.INTRO
## Vrai quand la pop-up vient d'être fermée avec A : le clic simulé qui suit ne doit pas compter.
var _skip_next_click := false
var _time_left := 0.0
var _fishes: Array[Fish] = []
var _target: Fish

var _water: Panel
var _paw: Sprite2D
var _paw_rest := Vector2.ZERO
var _paw_tween: Tween
var _viseur: Sprite2D

var _time_label: Label
var _popup: Control
var _close_btn: Control
var _close_cross: TextureRect
var _overlay: ColorRect
var _title_label: Label
var _sub_label: Label

var _noise := 0.0
var _noise_shown := 0.0
var _wrong_fish := 0
var _cooldown := 0.0
var _gauge_fill: Panel
var _son_icon: TextureRect
var _eau: Eau
var _fx_layer: CanvasLayer
var _flash: ColorRect
var _shake := 0.0
var _audio: AudioStreamPlayer


func _ready() -> void:
	randomize()
	_time_left = time_limit
	_build_background()
	# Flaques sur le parquet (sous l'aquarium) ; gouttes en vol au-dessus de l'aquarium.
	_eau = Eau.new()
	add_child(_eau)
	_build_tank()
	_eau.setup(SCREEN, _water)
	add_child(_eau.air)
	_build_paw()
	_build_hud()
	_build_gauge()
	_build_fx()
	_build_popup()
	_build_overlay()
	_build_viseur()
	_spawn_fishes()
	# Ronds dans l'eau : au-dessus des poissons, coupés au bord de l'aquarium.
	_water.add_child(_eau.surface)
	_audio = AudioStreamPlayer.new()
	_audio.stream = MEOW
	add_child(_audio)
	# Glouglou de l'aquarium en fond, discret.
	add_child(Sons.make_loop("ambiance_bulles", -20.0))
	_update_time_label()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Si on quitte pendant un arrêt sur image, le jeu ne doit pas rester au ralenti.
	Engine.time_scale = 1.0


# --- Construction (ordre = ordre des calques de la maquette) ------------------

func _build_background() -> void:
	_add_texture(FOND_TEX, Vector2(0, 10.31))


func _build_tank() -> void:
	# Eau : sert aussi de masque arrondi pour que les poissons soient coupés au bord.
	var inner := TANK_RECT.grow(-TANK_BORDER)
	_water = _make_panel(inner, COL_WATER, TANK_RADIUS - TANK_BORDER)
	_water.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(_water)

	# Bordure dessinée par-dessus les poissons.
	var border := Panel.new()
	border.position = TANK_RECT.position
	border.size = TANK_RECT.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = COL_TANK_BORDER
	style.set_border_width_all(TANK_BORDER)
	style.set_corner_radius_all(TANK_RADIUS)
	border.add_theme_stylebox_override("panel", style)
	add_child(border)


func _build_paw() -> void:
	_paw = Sprite2D.new()
	_paw.texture = PATTE_TEX
	_paw.centered = false
	_paw.offset = -PAW_ANCHOR
	_paw.rotation_degrees = PAW_ROTATION
	_paw_rest = PAW_CENTER + (PAW_ANCHOR - PATTE_TEX.get_size() * 0.5).rotated(_paw.rotation)
	_paw.position = _paw_rest
	add_child(_paw)
	# Prolonge le bras hors de l'écran quand la patte va chercher un poisson loin.
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


func _build_hud() -> void:
	_add_texture(HEADER_TEX, Vector2.ZERO)
	# Le dôme nuit → jour qui montre le temps qui reste (voir ciel.gd).
	add_child(preload("res://scripts/ciel.gd").new())

	add_child(_make_panel(Rect2(46, 22, 214.272, 69.12), COL_CREAM, 35))
	_add_texture(CHRONO_TEX, Vector2(68.46, 32.37))
	_time_label = _make_label(43, COL_DARK)
	_time_label.position = Vector2(122.03, 30.64)
	add_child(_time_label)

	add_child(_make_panel(Rect2(1172, 22, 68.144, 69.144), COL_CREAM, 6))
	_add_texture(REGLAGES_TEX, Vector2(1182.98, 36))


func _build_gauge() -> void:
	# Icône haut-parleur : le SVG déborde de ~2 px autour du groupe de la maquette de la souris.
	_son_icon = _add_texture(SON_TEX, Vector2(1188, 235) - Vector2(2.07, 2.07))
	_son_icon.pivot_offset = _son_icon.size * 0.5
	add_child(_make_panel(GAUGE_RECT, COL_CREAM, 15))
	_gauge_fill = _make_panel(Rect2(GAUGE_RECT.position.x, GAUGE_RECT.end.y, GAUGE_RECT.size.x, 0), COL_NOISE, 15)
	add_child(_gauge_fill)


## Calque d'effets plein écran : flash et gouttes d'eau « sur la caméra ».
func _build_fx() -> void:
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 1
	add_child(_fx_layer)
	_flash = ColorRect.new()
	_flash.color = Color(0.85, 0.95, 1.0)
	_flash.size = SCREEN
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(_flash)


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
	# Sinon le Panel avale les clics et la croix ne reçoit jamais le clic.
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = COL_CREAM
	style.border_color = COL_DARK
	style.set_border_width_all(6)
	style.set_corner_radius_all(18)
	box.add_theme_stylebox_override("panel", style)
	_popup.add_child(box)

	var title := _make_label(42, COL_DARK)
	title.text = "MISSION: WHERE IS … THE FISH?"
	title.position = Vector2(215, 354)
	title.size = Vector2(860, 45)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup.add_child(title)

	var body := _make_label(32, COL_BODY_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(716, 0)
	body.text = "Hidden among all these goldfish is one pink fish. Fish it out in time, " \
		+ "but every splash makes noise!"
	body.position = Vector2(287, 421)
	body.size = Vector2(716, 120)
	_popup.add_child(body)

	# Bouton fermer : fond + croix regroupés pour réagir au survol.
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
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_child(_title_label)

	_sub_label = _make_label(32, Color.WHITE)
	_sub_label.position = Vector2(0, SCREEN.y * 0.5 + 20)
	_sub_label.size = Vector2(SCREEN.x, 50)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_child(_sub_label)


func _build_viseur() -> void:
	# Le viseur remplace le curseur (comme dans le mini-jeu de la souris) et passe au-dessus de tout.
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_viseur = Sprite2D.new()
	_viseur.texture = VISEUR_TEX
	_viseur.position = get_viewport().get_mouse_position()
	layer.add_child(_viseur)


func _spawn_fishes() -> void:
	var origin := _water.position
	# Les centres restent dans l'eau ; les poissons peuvent dépasser et être coupés au bord.
	var bounds := Rect2(Vector2(20, 18), _water.size - Vector2(40, 36))
	for entry in FISH_LAYOUT:
		var right: bool = entry[1]
		var f := Fish.new()
		f.texture = POISSON_DROITE_TEX if right else POISSON_GAUCHE_TEX
		# Les deux SVG exportés regardent à droite : le retournement Figma n'est pas dans le fichier.
		f.facing_right = true
		f.flip_h = not right
		var top_left: Vector2 = entry[0]
		if not right:
			top_left.x -= f.texture.get_width()
		f.position = top_left + f.texture.get_size() * 0.5 - origin
		f.bounds = bounds
		f.base_speed = randf_range(70.0, 120.0)
		# Départ presque à l'horizontale, dans le sens où il regarde sur la maquette.
		var angle := randf_range(-0.15, 0.15) + (0.0 if right else PI)
		f.velocity = Vector2.from_angle(angle) * f.base_speed
		_water.add_child(f)
		_fishes.append(f)

	_target = _fishes.pick_random()
	_target.is_target = true
	_target.texture = POISSON_ROSE_TEX


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

	var p: Vector2 = make_input_local(event).position
	match _state:
		State.INTRO:
			if _is_over_close(p):
				_start_game()
		State.PLAYING:
			if _cooldown <= 0.0:
				_try_catch(p)
		State.FINISHED:
			if _overlay.visible:
				get_tree().reload_current_scene()


func _is_over_close(p: Vector2) -> bool:
	return CLOSE_RECT.grow(CLOSE_MARGIN).has_point(p)


func _start_game() -> void:
	Sons.play("popup_fermer")
	_state = State.PLAYING
	var tween := _popup.create_tween()
	tween.tween_property(_popup, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_popup.hide)


func _try_catch(p: Vector2) -> void:
	# Seuls les clics dans l'eau comptent.
	if not Rect2(_water.global_position, _water.size).has_point(p):
		return
	_cooldown = DIP_COOLDOWN
	_swipe_paw(p)

	# On teste d'abord les poissons dessinés au-dessus (les derniers de la liste).
	var caught: Fish = null
	for i in range(_fishes.size() - 1, -1, -1):
		if _fishes[i].contains_point(p):
			caught = _fishes[i]
			break

	_noise += noise_per_dip
	if caught != null and caught.is_target:
		_catch_target(caught, p)
		_finish(true, "Pink fish caught in %.1f s  ·  Noise %d %%" % [time_limit - _time_left, roundi(_noise)])
		return

	# Plouf : gerbe d'eau, et tous les poissons du coin s'affolent.
	_eau.splash(p, 1.0)
	Sons.play("plouf")
	Sons.play("bulles")
	_shake = maxf(_shake, 0.35)
	var local := p - _water.global_position
	for f in _fishes:
		if f != caught:
			f.panic(local, PANIC_RADIUS)

	if caught != null:
		_wrong_fish += 1
		_noise += noise_per_wrong_fish
		_fling_fish(caught, p)
		Sons.play("plouf", 3.0)
		_shake = maxf(_shake, 0.7)
		_flash_screen(0.25)
		_hit_stop(0.06)
		_pop_text(WRONG_WORDS.pick_random(), p)
		Eau.screen_splats(_fx_layer, 1 + _wrong_fish, SCREEN)
	else:
		_pop_text(DIP_WORDS.pick_random(), p)

	if _noise >= NOISE_MAX:
		_finish(false, "Too much noise: the whole house is awake!")


## Mauvais poisson : éjecté hors de l'aquarium, il atterrit sur le parquet et y gigote.
func _fling_fish(f: Fish, from: Vector2) -> void:
	_fishes.erase(f)
	f.set_process(false)
	f.reparent(self)
	move_child(f, _paw.get_index())
	var zone: Rect2 = LANDING_ZONES.pick_random()
	var land := zone.position + Vector2(randf() * zone.size.x, randf() * zone.size.y)
	var spins := randf_range(1.5, 3.0) * (1.0 if randf() < 0.5 else -1.0)
	var start_rot := f.rotation
	var fly := f.create_tween()
	# Vu de dessus : le poisson « monte » (grossit) puis retombe, en tournoyant et en semant des gouttes.
	fly.tween_method(func(t: float) -> void:
		f.global_position = from.lerp(land, t)
		f.scale = Vector2.ONE * (1.0 + 0.9 * sin(PI * t))
		f.rotation = start_rot + spins * TAU * t
		if randf() < 0.5:
			_eau.dribble(f.global_position), 0.0, 1.0, 0.6)
	fly.tween_callback(func() -> void:
		_eau.splash(land, 0.35)
		_pop_text("FLOP!", land)
		Sons.play("flop")
		_flop(f))


## Le poisson échoué saute et se tortille sur le parquet jusqu'à la fin de la partie.
func _flop(f: Fish) -> void:
	var base_y := f.position.y
	var tw := f.create_tween().set_loops()
	tw.tween_property(f, "rotation", randf_range(0.3, 0.6), 0.12)
	tw.parallel().tween_property(f, "position:y", base_y - 10.0, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "rotation", -randf_range(0.3, 0.6), 0.12)
	tw.parallel().tween_property(f, "position:y", base_y, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: f.flip_h = not f.flip_h)
	tw.tween_interval(randf_range(0.1, 0.5))


## Bon poisson : énorme gerbe d'eau, il s'envole vers le chat qui le gobe.
func _catch_target(f: Fish, from: Vector2) -> void:
	_fishes.erase(f)
	f.set_process(false)
	f.reparent(self)
	move_child(f, get_child_count() - 1)
	_eau.splash(from, 3.5)
	Sons.play("grosse_gerbe")
	Sons.play("plouf", 2.0)
	Sons.play("bulles", 4.0)
	Eau.screen_splats(_fx_layer, 7, SCREEN)
	_shake = 1.5
	_flash_screen(0.5)
	_hit_stop(0.18)
	_pop_text("GOTCHA!", from)
	var local := from - _water.global_position
	for other in _fishes:
		other.panic(local, PANIC_RADIUS * 2.0)
	var fly := f.create_tween()
	fly.tween_property(f, "scale", Vector2.ONE * 2.4, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly.parallel().tween_property(f, "rotation", f.rotation + TAU * 2.0, 0.6)
	fly.parallel().tween_property(f, "global_position", _paw_rest, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(f, "scale", Vector2.ZERO, 0.12)
	fly.tween_callback(func() -> void:
		_pop_text("YUM!", _paw_rest)
		_audio.play())


func _flash_screen(strength: float) -> void:
	_flash.modulate.a = strength
	_flash.create_tween().tween_property(_flash, "modulate:a", 0.0, 0.3)


## Arrêt sur image : le jeu se fige une fraction de seconde pour donner du poids au coup.
func _hit_stop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _pop_text(text: String, at: Vector2) -> void:
	var l := _make_label(40, COL_CREAM)
	l.text = text
	l.add_theme_color_override("font_outline_color", COL_DARK)
	l.add_theme_constant_override("outline_size", 10)
	l.size = Vector2(260, 50)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = at - Vector2(130, 90)
	l.pivot_offset = l.size * 0.5
	l.rotation = randf_range(-0.2, 0.2)
	l.scale = Vector2.ONE * 0.4
	add_child(l)
	var tween := l.create_tween()
	tween.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(l, "position:y", l.position.y - 40, 0.8)
	tween.tween_property(l, "modulate:a", 0.0, 0.25)
	tween.tween_callback(l.queue_free)


func _swipe_paw(at: Vector2) -> void:
	if _paw_tween:
		_paw_tween.kill()
	_paw_tween = create_tween()
	_paw_tween.tween_property(_paw, "position", at, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_paw_tween.tween_interval(0.08)
	_paw_tween.tween_property(_paw, "position", _paw_rest, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


# --- Boucle ------------------------------------------------------------------

func _process(delta: float) -> void:
	_viseur.position = get_viewport().get_mouse_position()
	if _state == State.INTRO:
		var hover := _is_over_close(_viseur.position)
		_close_btn.scale = Vector2.ONE * (1.2 if hover else 1.0)
		_close_cross.modulate = LOSE_COLOR if hover else Color.WHITE
		return

	# Tremblement de l'écran après un plouf.
	_shake = move_toward(_shake, 0.0, 3.0 * delta)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 16.0 * _shake * _shake

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
	_assist_pad()
	_cooldown = maxf(0.0, _cooldown - delta)
	_time_left = maxf(_time_left - delta, 0.0)
	_update_time_label()
	if _time_left <= 0.0:
		_finish(false, "Time's up: the pink fish got away!")


## Manette : le viseur freine sur le poisson le plus proche, quel qu'il soit (rien n'est dévoilé).
func _assist_pad() -> void:
	var best: Fish = null
	var best_d := PAD_ASSIST_RADIUS * 1.5
	for f in _fishes:
		var d := f.global_position.distance_to(_viseur.position)
		if d < best_d:
			best_d = d
			best = f
	if best != null:
		GameManager.pad_aim_assist(best.global_position, PAD_ASSIST_RADIUS)


func _update_time_label() -> void:
	_time_label.text = "00:%02d" % ceili(_time_left)


func _finish(won: bool, reason: String) -> void:
	if _state == State.FINISHED:
		return
	_state = State.FINISHED
	# La maison garde les traces du mini-jeu (voir maison_traces.gd).
	GameManager.record_result("aquarium", won)
	Sons.play("victoire" if won else "defaite")
	for f in _fishes:
		f.set_process(false)
	if not won:
		# Montre où se cachait le poisson rose.
		_target.reveal()
	# Victoire : retour fluide à la maison. Défaite : écran « OOPSIE / TRY AGAIN ».
	GameManager.end_mini_game(won)
