extends Node2D
## Oopsie Pawsie — mini-jeu façon Docteur Maboule (maquette Figma « MINI JEU - DOCTEUR MABOULE »).
## Maintenir CLIC GAUCHE sur la patte-prise, la guider dans le couloir sans toucher
## les bords. Arriver au bout débranche le câble : c'est gagné.

enum State { IDLE, DRAGGING, LOST, WON }

const SCREEN := Vector2(1280, 720)
const HEADER_H := 116.0
const BOARD_RECT := Rect2(46, 119, 1188, 552)
const HALF_WIDTH := 34.0    # demi-largeur du couloir
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

## Ancrage (coussinets) de la patte dans patte.svg, en taille réelle — comme dans
## le jeu de rythme et le placard, la grosse patte remplace entièrement le curseur.
const PAW_ANCHOR := Vector2(92.6, 90.0)
const PAW_ROTATION := -0.6
## La patte suit la souris directement (c'est le curseur). Le point qu'on guide
## dans le couloir est décalé par rapport à la patte pour rester toujours visible
## (relié par un bâton, comme sur la maquette) : c'est LUI qui doit toucher la
## prise de départ puis slalomer jusqu'à l'arrivée.
const PIN_OFFSET := Vector2(-159.0, 0.0)

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

var _state := State.IDLE
var _track := PackedVector2Array()
var _end_pos := Vector2.ZERO
var _plug_pos := Vector2.ZERO
var _trail := PackedVector2Array()
var _fails := 0
var _elapsed := 0.0
var _best := INF
var _message := ""
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
var _stats_label: Label

@onready var _audio: AudioStreamPlayer = $Audio


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_build_track()
	_setup_audio()
	_build_board_style()
	_build_hud()
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


func _reset() -> void:
	_state = State.IDLE
	_plug_pos = _track[0]
	_trail = PackedVector2Array([_plug_pos])
	_elapsed = 0.0
	_message = ""


# --- HUD (maquette Figma) ------------------------------------------------------

func _build_hud() -> void:
	_add_texture(HEADER_TEX, Vector2.ZERO)
	_add_texture(NUIT_TEX, Vector2(572.75, 24))

	add_child(_make_panel(Rect2(46, 22, 214.272, 69.12), COL_CREAM, 35))
	_add_texture(CHRONO_TEX, Vector2(68.46, 32.37))
	_time_label = _make_label(43, COL_DARK)
	_time_label.position = Vector2(122.03, 24)
	_time_label.size = Vector2(150, 56)
	add_child(_time_label)

	_stats_label = _make_label(18, COL_CREAM)
	_stats_label.position = Vector2(660, 46)
	_stats_label.size = Vector2(492, 30)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_stats_label)

	_build_gear_button()


## Bouton réglages (coin haut droit) : ramène au menu, comme Échap.
func _build_gear_button() -> void:
	var rect := Rect2(1172, 22, 68.144, 69.144)
	add_child(_make_panel(rect, COL_CREAM, 14))
	var icon_size: Vector2 = GEAR_TEX.get_size() * 0.72
	_add_texture(GEAR_TEX, rect.position + (rect.size - icon_size) * 0.5, icon_size)

	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.self_modulate = Color(1, 1, 1, 0)
	btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	add_child(btn)


func _add_texture(tex: Texture2D, pos: Vector2, size := Vector2.ZERO) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.position = pos
	t.size = size if size != Vector2.ZERO else tex.get_size()
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return

	var point := _cursor_point()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT and _state == State.DRAGGING:
				_lose("Tu as lâché le câble !")
			return
		match _state:
			State.IDLE:
				if mb.button_index == MOUSE_BUTTON_LEFT and point.distance_to(_plug_pos) <= GRAB_RADIUS:
					_state = State.DRAGGING
					_play(_synth(500.0, 900.0, 0.07, false, 0.25))
			State.LOST, State.WON:
				_reset()
	elif event is InputEventMouseMotion and _state == State.DRAGGING:
		_move_plug(point)
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_R:
		_reset()


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


func _distance_to_track(p: Vector2) -> float:
	var best := INF
	for i in _track.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, _track[i], _track[i + 1])
		best = minf(best, p.distance_squared_to(c))
	return sqrt(best)


func _lose(reason: String) -> void:
	_state = State.LOST
	_fails += 1
	_message = reason
	_shake = 1.0
	_flash = 1.0
	_spawn_sparks(_plug_pos, COL_WALL_HIT, 24)
	_play(_synth(115.0, 95.0, 0.5, true, 0.18))


func _win() -> void:
	_state = State.WON
	_plug_pos = _end_pos
	_best = minf(_best, _elapsed)
	_message = "Câble débranché en %.2f s" % _elapsed
	_spawn_sparks(_track[0], COL_PLUG, 24)
	_spawn_sparks(_end_pos, COL_GOAL, 30)
	var jingle := PackedVector2Array()
	for f in [523.0, 659.0, 784.0, 1047.0]:
		jingle.append_array(_synth(f, f, 0.11, false, 0.25))
	_play(jingle)


# --- Boucle ------------------------------------------------------------------

func _process(delta: float) -> void:
	_paw.position = get_local_mouse_position()
	_time += delta
	if _state == State.DRAGGING:
		_elapsed += delta
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
	var secs := int(_elapsed)
	_time_label.text = "%02d:%02d" % [secs / 60, secs % 60]
	var best := "—" if _best == INF else "%.2f s" % _best
	_stats_label.text = "Record : %s   ·   Ratés : %d" % [best, _fails]


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
	_draw_banner()


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


func _draw_banner() -> void:
	match _state:
		State.LOST:
			_banner("OOPSIE !", _message, COL_WALL_HIT, "Clic pour réessayer  ·  R pour recommencer  ·  Échap : menu")
		State.WON:
			_banner("PAWSOME !", _message, COL_GOAL, "Clic pour rejouer  ·  Échap : menu")
		State.IDLE:
			_hint("Maintiens CLIC GAUCHE sur la patte et guide le câble jusqu'au point vert sans toucher les bords")


func _hint(text: String) -> void:
	var rect := Rect2(SCREEN.x / 2 - 420, SCREEN.y - 40, 840, 30)
	draw_rect(rect, Color(COL_DARK, 0.55))
	_text(text, rect.position + Vector2(0, 21), rect.size.x, 16, COL_CREAM)


func _banner(title: String, sub: String, color: Color, hint: String) -> void:
	var rect := Rect2(SCREEN.x / 2 - 300, SCREEN.y / 2 - 100, 600, 200)
	draw_rect(rect, Color(COL_DARK, 0.9))
	draw_rect(rect, color, false, 4.0)
	_text(title, rect.position + Vector2(0, 70), rect.size.x, 52, color)
	_text(sub, rect.position + Vector2(0, 118), rect.size.x, 22, COL_CREAM)
	_text(hint, rect.position + Vector2(0, 168), rect.size.x, 16, Color(COL_CREAM, 0.7))


func _text(s: String, pos: Vector2, width: float, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(FONT, pos, s, align, width, size, color)


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
