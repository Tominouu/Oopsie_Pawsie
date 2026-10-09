extends Node2D
## Oopsie Pawsie — mini-jeu façon Docteur Maboule.
## Maintenir CLIC GAUCHE sur la patte-prise, la guider dans le couloir sans toucher
## les bords. Arriver au bout débranche le câble : c'est gagné.

enum State { IDLE, DRAGGING, LOST, WON }

const SCREEN := Vector2(1280, 720)
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
const SOCKET_POS := Vector2(48, 620)

const COL_BG := Color("1e1b2e")
const COL_TRACK := Color("2f2a47")
const COL_GUIDE := Color(1, 1, 1, 0.07)
const COL_WALL := Color("e9c46a")
const COL_WALL_HIT := Color("ff4d4d")
const COL_PLUG := Color("ff8fab")
const COL_CABLE := Color("f4f1de")
const COL_CABLE_DEAD := Color("6c6783")
const COL_GOAL := Color("57cc99")
const COL_TEXT := Color("f4f1de")

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

var _playback: AudioStreamGeneratorPlayback
var _sound := PackedVector2Array()
var _sound_idx := 0

@onready var _audio: AudioStreamPlayer = $Audio


func _ready() -> void:
	_build_track()
	_setup_audio()
	_reset()


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


# --- Entrées -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		GameManager.back_to_house()
		return

	var mouse := get_local_mouse_position()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT and _state == State.DRAGGING:
				_lose("Tu as lâché le câble !")
			return
		match _state:
			State.IDLE:
				if mb.button_index == MOUSE_BUTTON_LEFT and mouse.distance_to(_plug_pos) <= GRAB_RADIUS:
					_state = State.DRAGGING
					_play(_synth(500.0, 900.0, 0.07, false, 0.25))
			State.LOST, State.WON:
				_reset()
	elif event is InputEventMouseMotion and _state == State.DRAGGING:
		_move_plug(mouse)
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_R:
		_reset()


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
	_spawn_sparks(SOCKET_POS + Vector2(14, 0), COL_WALL, 30)
	_spawn_sparks(_end_pos, COL_GOAL, 30)
	var jingle := PackedVector2Array()
	for f in [523.0, 659.0, 784.0, 1047.0]:
		jingle.append_array(_synth(f, f, 0.11, false, 0.25))
	_play(jingle)


# --- Boucle ------------------------------------------------------------------

func _process(delta: float) -> void:
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
	queue_redraw()


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
	draw_rect(Rect2(-Vector2(40, 40), SCREEN + Vector2(80, 80)), COL_BG)

	# Couloir : bordure métallique puis piste.
	var wall := COL_WALL.lerp(COL_WALL_HIT, _flash)
	if _state == State.LOST:
		wall = COL_WALL_HIT
	_draw_thick(_track, HALF_WIDTH + 5.0, wall)
	_draw_thick(_track, HALF_WIDTH, COL_TRACK)
	draw_polyline(_track, COL_GUIDE, 2.0, true)

	# Arrivée.
	var pulse := 1.0 + 0.08 * sin(_time * 5.0)
	draw_circle(_end_pos, END_RADIUS * pulse, COL_GOAL.darkened(0.4))
	draw_circle(_end_pos, END_RADIUS * 0.7 * pulse, COL_GOAL)
	_text("FIN", _end_pos + Vector2(-40, 7), 80, 18, COL_BG)

	_draw_socket()
	_draw_cable()
	_draw_plug()

	for sp in _sparks:
		var c: Color = sp.color
		c.a = clampf(sp.life * 2.0, 0.0, 1.0)
		draw_line(sp.pos, sp.pos - sp.vel * 0.03, c, 3.0)

	draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(1, 0.2, 0.2, 0.25 * _flash))
	_draw_hud()


func _draw_thick(points: PackedVector2Array, radius: float, color: Color) -> void:
	draw_polyline(points, color, radius * 2.0, true)
	draw_circle(points[0], radius, color)
	draw_circle(points[points.size() - 1], radius, color)


func _draw_socket() -> void:
	var rect := Rect2(SOCKET_POS - Vector2(24, 34), Vector2(48, 68))
	draw_rect(rect, Color("d9d4c7"))
	draw_rect(rect, Color("8d8778"), false, 3.0)
	for dy in [-12.0, 12.0]:
		draw_circle(SOCKET_POS + Vector2(0, dy), 5.0, Color("3a3646"))
	if _state != State.WON:
		# Fiche branchée dans la prise murale.
		draw_rect(Rect2(SOCKET_POS + Vector2(4, -10), Vector2(22, 20)), COL_PLUG.darkened(0.2))


func _draw_cable() -> void:
	var pts := PackedVector2Array()
	if _state == State.WON:
		# Débranché : le câble pend mollement côté prise murale.
		pts.append(SOCKET_POS + Vector2(60, 40))
	else:
		pts.append(SOCKET_POS + Vector2(26, 0))
	pts.append_array(_trail)
	pts.append(_plug_pos)
	var col := COL_CABLE_DEAD if _state == State.WON else COL_CABLE
	draw_polyline(pts, col.darkened(0.5), 8.0, true)
	draw_polyline(pts, col, 5.0, true)


func _draw_plug() -> void:
	var r := PLUG_RADIUS
	if _state == State.IDLE:
		var hover := get_local_mouse_position().distance_to(_plug_pos) <= GRAB_RADIUS
		var halo := 0.5 + 0.5 * sin(_time * 6.0)
		draw_arc(_plug_pos, GRAB_RADIUS - 6.0 + halo * 4.0, 0, TAU, 32,
				Color(COL_PLUG, 0.9 if hover else 0.4), 2.0, true)
	draw_circle(_plug_pos, r + 2.0, COL_PLUG.darkened(0.45))
	draw_circle(_plug_pos, r, COL_PLUG)
	# Empreinte de patte.
	var s := r / 16.0
	var paw := Color.WHITE
	draw_circle(_plug_pos + Vector2(0, 4) * s, 6.0 * s, paw)
	for off in [Vector2(-7, -4), Vector2(-2.5, -9), Vector2(2.5, -9), Vector2(7, -4)]:
		draw_circle(_plug_pos + off * s, 2.6 * s, paw)


func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, SCREEN.x, 64), Color(0, 0, 0, 0.35))
	_text("Oopsie Pawsie", Vector2(24, 42), 400, 30, COL_PLUG, HORIZONTAL_ALIGNMENT_LEFT)
	var best := "—" if _best == INF else "%.2f s" % _best
	var stats := "Temps : %.2f s     Record : %s     Ratés : %d" % [_elapsed, best, _fails]
	_text(stats, Vector2(SCREEN.x - 624, 40), 600, 20, COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

	match _state:
		State.IDLE:
			_text("Maintiens CLIC GAUCHE sur la patte et guide le câble jusqu'à la FIN sans toucher les bords   ·   Échap : maison",
					Vector2(0, SCREEN.y - 22), SCREEN.x, 18, COL_TEXT)
		State.LOST:
			_banner("OOPSIE !", _message, COL_WALL_HIT, "Clic pour réessayer  ·  R pour recommencer  ·  Échap : maison")
		State.WON:
			_banner("PAWSOME !", _message, COL_GOAL, "Clic pour rejouer  ·  Échap : maison")


func _banner(title: String, sub: String, color: Color, hint: String) -> void:
	var rect := Rect2(SCREEN.x / 2 - 300, SCREEN.y / 2 - 100, 600, 200)
	draw_rect(rect, Color(0, 0, 0, 0.75))
	draw_rect(rect, color, false, 4.0)
	_text(title, rect.position + Vector2(0, 70), rect.size.x, 52, color)
	_text(sub, rect.position + Vector2(0, 118), rect.size.x, 22, COL_TEXT)
	_text(hint, rect.position + Vector2(0, 168), rect.size.x, 16, Color(COL_TEXT, 0.7))


func _text(s: String, pos: Vector2, width: float, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, align, width, size, color)


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
