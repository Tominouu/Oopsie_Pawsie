extends Node2D
## Oopsie Pawsie — mini-jeu façon Docteur Maboule (maquette Figma « MINI JEU - DOCTEUR MABOULE »).
## Maintenir CLIC GAUCHE sur la patte-prise, la guider dans le couloir sans toucher
## les bords. Arriver au bout débranche le câble : c'est gagné.

enum State { INTRO, IDLE, DRAGGING, LOST, WON }

const SCREEN := Vector2(1280, 720)
const HEADER_H := 116.0
const BOARD_RECT := Rect2(46, 119, 1188, 552)
const HALF_WIDTH := 34.0    # demi-largeur du couloir
## Manette : vitesse du curseur pendant qu'on traîne la prise, et force du recentrage dans le couloir.
const PAD_DRAG_PRECISION := 0.4
const PAD_CENTERING := 2.5
const PLUG_RADIUS := 11.0   # rayon de contact de la prise (= taille dessinée)
const GRAB_RADIUS := 30.0   # tolérance pour attraper la prise
const END_RADIUS := 24.0
const TRAIL_STEP := 8.0     # distance entre deux points du câble
const SAMPLE_STEP := 3.0    # pas de vérification entre deux positions de souris
const MIX_RATE := 22050.0

# Points de passage du parcours (lissés ensuite en courbe).
const PATH_POINTS := [
	Vector2(120, 620), Vector2(330, 620), Vector2(420, 470), Vector2(260, 360),
	Vector2(330, 200), Vector2(560, 180), Vector2(640, 360), Vector2(560, 560),
	Vector2(780, 620), Vector2(900, 450), Vector2(820, 260), Vector2(1000, 160),
	Vector2(1160, 260), Vector2(1100, 450), Vector2(1170, 610),
]

const FONT := preload("res://assets/fonts/FredokaOne-Regular.ttf")
const HEADER_TEX := preload("res://assets/sprites/cable/header.svg")
const NUIT_TEX := preload("res://assets/sprites/cable/nuit.svg")
const CHRONO_TEX := preload("res://assets/sprites/cable/chrono.svg")
const GEAR_TEX := preload("res://assets/sprites/cable/parametres.svg")
const BOLT_TEX := preload("res://assets/sprites/cable/boulon.svg")
const PATTE_TEX := preload("res://assets/sprites/cable/patte.svg")
const FERMER_TEX := preload("res://assets/sprites/cable/fermer.svg")

## Ancrage (coussinets) de la patte dans patte.svg, en taille réelle — comme dans
## le jeu de rythme et le placard, la grosse patte remplace entièrement le curseur.
const PAW_ANCHOR := Vector2(92.6, 90.0)
const PAW_ROTATION := -0.6
## La patte suit la souris directement (c'est le curseur). Le point qu'on guide
## dans le couloir est décalé par rapport à la patte pour rester toujours visible
## (relié par un bâton, comme sur la maquette) : c'est LUI qui doit toucher la
## prise de départ puis slalomer jusqu'à l'arrivée.
## Attention : le point guidé = souris + ce décalage, donc le point le plus à
## droite du parcours (~1170 px) doit rester atteignable avec une souris qui ne
## dépasse pas SCREEN.x (1280) : il faut |PIN_OFFSET.x| < SCREEN.x - 1170, sinon
## le dernier virage devient impossible à atteindre (échec garanti).
const PIN_OFFSET := Vector2(-95.0, 0.0)

const COL_OUTER := Color("f5c36b")
const COL_BOARD := Color("393838")
const COL_TRACK := Color("aeaeae")
const COL_GUIDE := Color("8e8e8e")
const COL_WALL_HIT := Color("ff5a52")
const COL_PLUG := Color("ae2623")
const COL_CABLE_DEAD := Color("8d8d8d")
const COL_GOAL := Color("6ce770")
const COL_CREAM := Color("fff2e4")
const COL_DARK := Color("2b1710")
const COL_BODY_TEXT := Color("6e4d41")
const COL_CLOSE_BG := Color("d9d9d9")

@export var time_limit := 30.0
@export var result_delay := 0.6

var _state := State.INTRO
var _track := PackedVector2Array()
var _end_pos := Vector2.ZERO
var _plug_pos := Vector2.ZERO
var _trail := PackedVector2Array()
var _time_left := 0.0
var _elapsed := 0.0
var _time := 0.0
var _shake := 0.0
var _flash := 0.0
var _sparks: Array[Dictionary] = []
var _board_style: StyleBoxFlat
var _paw: Sprite2D

var _playback: AudioStreamGeneratorPlayback
var _sound := PackedVector2Array()
var _sound_idx := 0

var _time_label: Label
var _popup: Control
var _overlay: ColorRect
var _title_label: Label
var _sub_label: Label

@onready var _audio: AudioStreamPlayer = $Audio


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_build_track()
	_setup_audio()
	_build_board_style()
	_build_hud()
	_build_popup()
	_build_overlay()
	_build_paw()
	_reset()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## La grosse patte remplace le curseur système (même principe que rythme.gd et
## croquettes.gd) : elle suit la souris en continu, le coussinet est le point
## qui agrippe/déplace réellement la prise.
func _build_paw() -> void:
	_paw = Sprite2D.new()
	_paw.texture = PATTE_TEX
	_paw.centered = false
	_paw.offset = -PAW_ANCHOR
	_paw.rotation = PAW_ROTATION
	_paw.z_index = 10
	add_child(_paw)


func _build_board_style() -> void:
	_board_style = StyleBoxFlat.new()
	_board_style.bg_color = COL_BOARD
	_board_style.set_corner_radius_all(24)


func _build_track() -> void:
	var curve := Curve2D.new()
	curve.bake_interval = 6.0
	var n := PATH_POINTS.size()
	for i in n:
		var p: Vector2 = PATH_POINTS[i]
		var prev: Vector2 = PATH_POINTS[maxi(i - 1, 0)]
		var next: Vector2 = PATH_POINTS[mini(i + 1, n - 1)]
		var tangent := (next - prev) * 0.22
		curve.add_point(p, -tangent, tangent)
	_track = curve.get_baked_points()
	_end_pos = _track[_track.size() - 1]


## Remet le parcours à zéro sans toucher à l'état (IDLE ou INTRO selon l'appelant).
func _reset() -> void:
	_plug_pos = _track[0]
	_trail = PackedVector2Array([_plug_pos])
	_elapsed = 0.0
	_time_left = time_limit


# --- HUD (maquette Figma) ------------------------------------------------------

func _build_hud() -> void:
	_add_texture(HEADER_TEX, Vector2.ZERO)
	_add_texture(NUIT_TEX, Vector2(572.75, 24))

	add_child(_make_panel(Rect2(46, 22, 214.272, 69.12), COL_CREAM, 35))
	_add_texture(CHRONO_TEX, Vector2(68.46, 32.37))
	_time_label = _make_label(43, COL_DARK)
	_time_label.position = Vector2(122.03, 30.64)
	add_child(_time_label)

	_build_gear_button()


## Bouton réglages (coin haut droit) : ramène à la maison, comme Échap.
func _build_gear_button() -> void:
	var rect := Rect2(1172, 22, 68.144, 69.144)
	add_child(_make_panel(rect, COL_CREAM, 6))
	_add_texture(GEAR_TEX, Vector2(1182.98, 36))

	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.self_modulate = Color(1, 1, 1, 0)
	btn.pressed.connect(func() -> void:
		GameManager.back_to_house())
	add_child(btn)


## Pop-up de mission (maquette Figma), même principe que croquettes.gd / souris.gd /
## scene_aquarium.gd : explique l'objectif avant de commencer, se ferme au premier clic.
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
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = COL_CREAM
	style.border_color = COL_DARK
	style.set_border_width_all(6)
	style.set_corner_radius_all(18)
	box.add_theme_stylebox_override("panel", style)
	_popup.add_child(box)

	var title := _make_label(42, COL_DARK)
	title.text = "MISSION : DOCTEUR MABOULE"
	title.position = Vector2(215, 328)
	title.size = Vector2(860, 45)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup.add_child(title)

	var body := _make_label(32, COL_BODY_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(782, 0)
	body.text = "Maintiens CLIC GAUCHE sur la patte et guide la prise dans le couloir " \
		+ "sans toucher les bords, jusqu'au point vert, avant la fin du chrono."
	body.position = Vector2(254, 400)
	body.size = Vector2(782, 160)
	_popup.add_child(body)

	_popup.add_child(_make_panel(Rect2(1075.5, 278.5, 33.66, 33.66), COL_CLOSE_BG, 4))
	_popup.add_child(_add_texture(FERMER_TEX, Vector2(1081.44, 286.32), false))


## Écran de fin (gagné/perdu), même principe que rythme.gd / croquettes.gd / souris.gd :
## voile sombre plein écran + gros titre + sous-titre, qui s'estompe en fondu.
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

	var point := _cursor_point()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT and _state == State.DRAGGING:
				_lose("Tu as lâché le câble !")
			return
		match _state:
			State.INTRO:
				_start_game()
			State.IDLE:
				if mb.button_index == MOUSE_BUTTON_LEFT and point.distance_to(_plug_pos) <= GRAB_RADIUS:
					_state = State.DRAGGING
					_play(_synth(500.0, 900.0, 0.07, false, 0.25))
			State.LOST, State.WON:
				if _overlay.visible:
					get_tree().reload_current_scene()
	elif event is InputEventMouseMotion and _state == State.DRAGGING:
		_move_plug(point)
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_R \
			and _state != State.INTRO:
		_reset()
		_state = State.IDLE


func _start_game() -> void:
	_state = State.IDLE
	var tween := _popup.create_tween()
	tween.tween_property(_popup, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_popup.hide)


## Position du point guidé dans le couloir : la patte (= souris) + le décalage
## du bâton. C'est cette position qui doit attraper la prise puis slalomer.
func _cursor_point() -> Vector2:
	return get_local_mouse_position() + PIN_OFFSET


func _notification(what: int) -> void:
	if _state != State.DRAGGING:
		return
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_lose("Tu es sorti de la fenêtre !")


## Avance la prise vers la souris par petits pas : un geste rapide ne peut pas
## « sauter » par-dessus un bord.
func _move_plug(target: Vector2) -> void:
	var from := _plug_pos
	var steps := maxi(1, ceili(from.distance_to(target) / SAMPLE_STEP))
	for s in range(1, steps + 1):
		var p := from.lerp(target, float(s) / steps)
		_plug_pos = p
		if _distance_to_track(p) + PLUG_RADIUS > HALF_WIDTH:
			_lose("BZZZT ! Tu as touché le bord.")
			return
		if p.distance_to(_trail[_trail.size() - 1]) >= TRAIL_STEP:
			_trail.append(p)
		if p.distance_to(_end_pos) <= END_RADIUS:
			_win()
			return


## Aides à la manette (sans effet à la souris) : le curseur est attiré vers la prise
## pour l'attraper, puis, pendant qu'on la traîne, il va moins vite et se recentre
## doucement dans le couloir (uniquement sur le côté, il ne fait pas avancer tout seul).
func _update_pad_assist() -> void:
	match _state:
		State.IDLE:
			GameManager.pad_aim_assist(to_global(_plug_pos - PIN_OFFSET), 70.0)
		State.DRAGGING:
			GameManager.set_pad_precision(PAD_DRAG_PRECISION)
			var center := _closest_on_track(_cursor_point())
			GameManager.pad_pull(to_global(center - PIN_OFFSET), PAD_CENTERING)


func _closest_on_track(p: Vector2) -> Vector2:
	var best := p
	var best_d := INF
	for i in _track.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, _track[i], _track[i + 1])
		var d := p.distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = c
	return best


func _distance_to_track(p: Vector2) -> float:
	var best := INF
	for i in _track.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, _track[i], _track[i + 1])
		best = minf(best, p.distance_squared_to(c))
	return sqrt(best)


func _lose(reason: String) -> void:
	if _state == State.LOST or _state == State.WON:
		return
	_state = State.LOST
	_shake = 1.0
	_flash = 1.0
	_spawn_sparks(_plug_pos, COL_WALL_HIT, 24)
	_play(_synth(115.0, 95.0, 0.5, true, 0.18))
	_finish(false, reason)


func _win() -> void:
	if _state == State.LOST or _state == State.WON:
		return
	_state = State.WON
	_plug_pos = _end_pos
	_spawn_sparks(_track[0], COL_PLUG, 24)
	_spawn_sparks(_end_pos, COL_GOAL, 30)
	var jingle := PackedVector2Array()
	for f in [523.0, 659.0, 784.0, 1047.0]:
		jingle.append_array(_synth(f, f, 0.11, false, 0.25))
	_play(jingle)
	_finish(true, "Câble débranché en %.2f s" % _elapsed)


## Affiche l'écran de fin après un court délai (laisse le temps aux étincelles/au
## son de se jouer), même timing que les autres mini-jeux.
func _finish(won: bool, message: String) -> void:
	_title_label.text = "PAWSOME !" if won else "OOPSIE !"
	_title_label.add_theme_color_override("font_color", COL_GOAL if won else COL_WALL_HIT)
	var hint := "Clic pour rejouer" if won else "Clic pour réessayer"
	_sub_label.text = "%s   ·   %s   ·   Échap / B : maison" % [message, hint]
	await get_tree().create_timer(result_delay).timeout
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.4)


# --- Boucle ------------------------------------------------------------------

func _process(delta: float) -> void:
	_paw.position = get_local_mouse_position()
	_update_pad_assist()
	_time += delta
	if _state == State.DRAGGING:
		_elapsed += delta
	if _state == State.IDLE or _state == State.DRAGGING:
		_time_left = maxf(_time_left - delta, 0.0)
		if _time_left <= 0.0:
			_lose("Temps écoulé ! Le câble est resté branché.")
	_shake = maxf(0.0, _shake - delta * 2.5)
	_flash = maxf(0.0, _flash - delta * 3.0)
	for sp in _sparks:
		var vel: Vector2 = sp.vel
		sp.pos += vel * delta
		sp.vel = vel * 0.92 + Vector2(0, 400.0 * delta)
		sp.life -= delta
	_sparks = _sparks.filter(func(sp: Dictionary) -> bool: return sp.life > 0.0)
	_feed_audio()
	_update_labels()
	queue_redraw()


func _update_labels() -> void:
	_time_label.text = "00:%02d" % ceili(_time_left)


func _spawn_sparks(at: Vector2, color: Color, count: int) -> void:
	for i in count:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		_sparks.append({
			"pos": at, "vel": dir * randf_range(120.0, 420.0),
			"life": randf_range(0.3, 0.7), "color": color,
		})


# --- Dessin ------------------------------------------------------------------

func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 12.0 * _shake
	draw_set_transform(shake)
	draw_rect(Rect2(-Vector2(40, 40), SCREEN + Vector2(80, 80)), COL_OUTER)
	draw_style_box(_board_style, BOARD_RECT)
	_draw_bolts()

	# Couloir : bordure (flash rouge au contact) puis piste.
	var wall := COL_TRACK.lerp(COL_WALL_HIT, _flash)
	if _state == State.LOST:
		wall = COL_WALL_HIT
	_draw_thick(_track, HALF_WIDTH + 5.0, wall)
	_draw_thick(_track, HALF_WIDTH, COL_TRACK)
	draw_polyline(_track, COL_GUIDE, 2.0, true)

	# Arrivée.
	var pulse := 1.0 + 0.08 * sin(_time * 5.0)
	draw_circle(_end_pos, END_RADIUS * pulse, COL_GOAL.darkened(0.35))
	draw_circle(_end_pos, END_RADIUS * 0.68 * pulse, COL_GOAL)

	_draw_cable()
	_draw_stick()
	_draw_plug()

	for sp in _sparks:
		var c: Color = sp.color
		c.a = clampf(sp.life * 2.0, 0.0, 1.0)
		draw_line(sp.pos, sp.pos - sp.vel * 0.03, c, 3.0)

	draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(1, 0.2, 0.2, 0.22 * _flash))


func _draw_bolts() -> void:
	var inset := 24.0
	var half := BOLT_TEX.get_size() * 0.5
	for corner in [
		BOARD_RECT.position + Vector2(inset, inset),
		BOARD_RECT.position + Vector2(BOARD_RECT.size.x - inset, inset),
		BOARD_RECT.position + Vector2(inset, BOARD_RECT.size.y - inset),
		BOARD_RECT.position + Vector2(BOARD_RECT.size.x - inset, BOARD_RECT.size.y - inset),
	]:
		draw_texture(BOLT_TEX, corner - half)


func _draw_thick(points: PackedVector2Array, radius: float, color: Color) -> void:
	draw_polyline(points, color, radius * 2.0, true)
	draw_circle(points[0], radius, color)
	draw_circle(points[points.size() - 1], radius, color)


func _draw_cable() -> void:
	if _trail.size() < 1:
		return
	var pts := PackedVector2Array()
	pts.append_array(_trail)
	pts.append(_plug_pos)
	if pts.size() < 2:
		return
	var col := COL_CABLE_DEAD if _state == State.WON else COL_PLUG
	draw_polyline(pts, col.darkened(0.3), 8.0, true)
	draw_polyline(pts, col, 5.0, true)


## Bâton reliant le point à la patte : toujours la même longueur (= |PIN_OFFSET|),
## puisqu'il relie la patte à son décalage fixe, pas au point du couloir.
func _draw_stick() -> void:
	var point := _cursor_point()
	draw_line(_paw.position, point, COL_PLUG.darkened(0.35), 8.0)
	draw_line(_paw.position, point, COL_PLUG, 5.0)


func _draw_plug() -> void:
	if _state == State.IDLE:
		var point := _cursor_point()
		var hover := point.distance_to(_plug_pos) <= GRAB_RADIUS
		var halo := 0.5 + 0.5 * sin(_time * 6.0)
		# Cible fixe : la prise de départ, à rejoindre avec le point.
		draw_arc(_plug_pos, GRAB_RADIUS - 6.0 + halo * 4.0, 0, TAU, 32,
				Color(COL_PLUG, 0.9 if hover else 0.4), 2.0, true)
		draw_circle(_plug_pos, PLUG_RADIUS * 0.6, COL_PLUG.darkened(0.2))
		# Le point qu'on contrôle, toujours au bout du bâton.
		draw_circle(point, PLUG_RADIUS + 2.0, COL_PLUG.darkened(0.45))
		draw_circle(point, PLUG_RADIUS, COL_PLUG)
		draw_circle(point, PLUG_RADIUS * 0.35, COL_CREAM)
		return
	draw_circle(_plug_pos, PLUG_RADIUS + 2.0, COL_PLUG.darkened(0.45))
	draw_circle(_plug_pos, PLUG_RADIUS, COL_PLUG)
	draw_circle(_plug_pos, PLUG_RADIUS * 0.35, COL_CREAM)


# --- Son (généré, aucun fichier audio) ----------------------------------------

func _setup_audio() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.2
	_audio.stream = gen
	_audio.play()
	_playback = _audio.get_stream_playback()


func _synth(f0: float, f1: float, dur: float, square: bool, vol: float) -> PackedVector2Array:
	var n := int(dur * MIX_RATE)
	var out := PackedVector2Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += lerpf(f0, f1, k) / MIX_RATE
		var v := sin(phase * TAU)
		if square:
			v = signf(v)
		var env := minf(1.0, (1.0 - k) * 10.0) * minf(1.0, k * 200.0)
		out[i] = Vector2.ONE * (v * vol * env)
	return out


func _play(samples: PackedVector2Array) -> void:
	_sound = samples
	_sound_idx = 0


func _feed_audio() -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var take := mini(frames, _sound.size() - _sound_idx)
	if take > 0:
		_playback.push_buffer(_sound.slice(_sound_idx, _sound_idx + take))
		_sound_idx += take
		frames -= take
	# Silence pour garder le flux alimenté.
	for i in frames:
		_playback.push_frame(Vector2.ZERO)
