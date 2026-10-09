extends Node2D
## Oopsie Pawsie — mini-jeu de rythme façon osu! : griffe le canapé en rythme.
## Les empreintes arrivent de la droite : clique dessus quand elles passent sur la zone
## de frappe. Plus c'est pile au bon moment, plus ça rapporte (PERFECT / GREAT / OK),
## et chaque coup laisse une vraie griffure dans le canapé.

enum State { PLAYING, FINISHED }

const Note := preload("res://scripts/mini_games/rythme_note.gd")
const Rembourrage := preload("res://scripts/mini_games/rythme_rembourrage.gd")

const FONT := preload("res://assets/fonts/FredokaOne-Regular.ttf")
const POINT_TEX := preload("res://assets/sprites/rythme/point.png")
const PATTE_TEX := preload("res://assets/sprites/rythme/patte.png")
const HEADER_TEX := preload("res://assets/sprites/rythme/header.svg")
const NUIT_TEX := preload("res://assets/sprites/rythme/nuit.svg")
const CHRONO_TEX := preload("res://assets/sprites/rythme/chrono.svg")
## Mouchetures du tissu, exportées de Figma puis rendues transparentes autour (le fond reste celui du jeu).
const TEXTURE_TEX := preload("res://assets/sprites/rythme/texture.png")
const MEOW := preload("res://assets/sounds/meow1.mp3")

const SCREEN := Vector2(1280, 720)
const HEADER_H := 116.0
const HIT_X := 320.0
## Tolérance en pixels autour de la zone de frappe pour taper une note (large : jouable à la manette).
const TAP_WINDOW := 85.0
## Distance max clic ↔ centre de la note (× NOTE_SCALE).
const TAP_HIT_RADIUS := 64.0
const NOTE_SCALE := 1.6
const SPAWN_MARGIN := 170.0
const LANE_MIN_Y := 190.0
const LANE_MAX_Y := 620.0
## Le cercle d'approche apparaît autant de secondes avant que la note soit pile sur la zone.
const APPROACH_TIME := 0.8

## Jugements : écart max (px) à la zone de frappe, points, texte, couleur, force de l'effet.
const JUDGES := [
	{"max": 22.0, "points": 300, "text": "PERFECT !", "color": Color("ffd23f"), "power": 1.8},
	{"max": 48.0, "points": 200, "text": "GREAT !", "color": Color("7ee081"), "power": 1.2},
	{"max": TAP_WINDOW, "points": 100, "text": "OK", "color": Color("8ecae6"), "power": 0.8},
]
## Combo à partir duquel la patte s'enflamme, et palier des bannières « COMBO xN ! ».
const HOT_COMBO := 10
const COMBO_STEP := 10

## Fond d'origine du mini-jeu.
const COL_BG := Color("eac89c")
const COL_CREAM := Color("fff2e4")
const COL_DARK := Color("2b1710")
const COL_ZONE := Color(1, 0.95, 0.85)
const WIN_COLOR := Color(0.25, 0.85, 0.45)
const LOSE_COLOR := Color(0.95, 0.30, 0.30)

@export var time_limit := 30.0
@export var note_speed := 420.0
@export_range(0.0, 1.0) var win_accuracy := 0.65

var _state := State.PLAYING
var _time_left := 0.0
var _elapsed := 0.0
var _travel_time := 0.0

var _chart: Array[float] = []   # instant de frappe de chaque note
var _lanes: Array[float] = []   # hauteur de chaque note
var _spawn_cursor := 0
var _notes: Array[Note] = []

var _combo := 0
var _best_combo := 0
var _hits := 0
var _perfects := 0
var _total := 0
var _score := 0
var _miss_flash := 0.0
var _zone_pulse := 0.0
var _shake := 0.0
var _spark_acc := 0.0

var _paw: Sprite2D
var _paw_base_scale := Vector2.ONE
var _paw_tip_offset := Vector2.ZERO
var _paw_tween: Tween
var _fx: Rembourrage

var _time_label: Label
var _score_label: Label
var _combo_label: Label
var _overlay: ColorRect
var _title_label: Label
var _sub_label: Label
var _audio: AudioStreamPlayer


func _ready() -> void:
	randomize()
	_time_left = time_limit
	_travel_time = (SCREEN.x + SPAWN_MARGIN - HIT_X) / note_speed
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	# Griffures du canapé (sous les notes) ; rembourrage en vol (au-dessus).
	_fx = Rembourrage.new()
	add_child(_fx)
	add_child(_fx.air)
	_build_paw()
	_build_ui()
	_audio = AudioStreamPlayer.new()
	_audio.stream = MEOW
	add_child(_audio)
	_generate_chart()
	_update_hud()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_paw() -> void:
	_paw = Sprite2D.new()
	_paw.texture = PATTE_TEX
	_paw_base_scale = Vector2.ONE * 0.42
	_paw.scale = _paw_base_scale
	_paw.z_index = 10
	_paw_tip_offset = Vector2(0, PATTE_TEX.get_height() * 0.5 * _paw_base_scale.y)
	add_child(_paw)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# Bandeau du haut, comme dans les autres mini-jeux.
	_add_texture(layer, HEADER_TEX, Vector2.ZERO)
	_add_texture(layer, NUIT_TEX, Vector2(572.75, 24))
	layer.add_child(_make_panel(Rect2(46, 22, 214.272, 69.12), COL_CREAM, 35))
	_add_texture(layer, CHRONO_TEX, Vector2(68.46, 32.37))
	_time_label = _make_label(43, COL_DARK)
	_time_label.position = Vector2(122.03, 30.64)
	layer.add_child(_time_label)

	layer.add_child(_make_panel(Rect2(980, 22, 260, 69.12), COL_CREAM, 35))
	_score_label = _make_label(36, COL_DARK)
	_score_label.position = Vector2(980, 34)
	_score_label.size = Vector2(260, 50)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_score_label)

	_combo_label = _make_label(64, COL_CREAM)
	_combo_label.add_theme_color_override("font_outline_color", COL_DARK)
	_combo_label.add_theme_constant_override("outline_size", 14)
	_combo_label.position = Vector2(HIT_X - 150, 630)
	_combo_label.size = Vector2(300, 80)
	_combo_label.pivot_offset = _combo_label.size * 0.5
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_combo_label)

	var end_layer := CanvasLayer.new()
	end_layer.layer = 2
	add_child(end_layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	_overlay.size = SCREEN
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_layer.add_child(_overlay)

	_title_label = _make_label(96, Color.WHITE)
	_title_label.add_theme_constant_override("outline_size", 10)
	_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_title_label.position = Vector2(0, SCREEN.y * 0.5 - 120)
	_title_label.size = Vector2(SCREEN.x, 130)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_title_label)

	_sub_label = _make_label(24, Color.WHITE)
	_sub_label.position = Vector2(0, SCREEN.y * 0.5 + 20)
	_sub_label.size = Vector2(SCREEN.x, 50)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_sub_label)


func _add_texture(parent: Node, tex: Texture2D, pos: Vector2) -> void:
	var t := TextureRect.new()
	t.texture = tex
	t.position = pos
	t.size = tex.get_size()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)


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


# --- Génération du parcours ---------------------------------------------------

func _generate_chart() -> void:
	var t := _travel_time + 0.4
	while t < time_limit - 0.8:
		_chart.append(t)
		_lanes.append(randf_range(LANE_MIN_Y, LANE_MAX_Y))
		t += randf_range(0.55, 1.1)


# --- Entrées -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		GameManager.back_to_house()
		return
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	var mb := event as InputEventMouseButton
	_paw_set_pressed(mb.pressed)
	if not mb.pressed:
		return
	if _state == State.FINISHED:
		if _overlay.visible:
			get_tree().reload_current_scene()
		return
	_try_press(make_input_local(event).position)


func _try_press(p: Vector2) -> void:
	var best: Note = null
	var best_dist := INF
	for n in _notes:
		if n.dead or absf(n.position.x - HIT_X) > TAP_WINDOW:
			continue
		var d := p.distance_to(n.position)
		if d <= TAP_HIT_RADIUS * NOTE_SCALE and d < best_dist:
			best = n
			best_dist = d
	if best == null:
		return
	_register_hit(best)
	_notes.erase(best)
	best.queue_free()


# --- Boucle ------------------------------------------------------------------

func _process(delta: float) -> void:
	_paw.position = get_local_mouse_position() + _paw_tip_offset
	_shake = move_toward(_shake, 0.0, 3.0 * delta)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 12.0 * _shake * _shake
	_zone_pulse = maxf(0.0, _zone_pulse - delta * 4.0)
	_miss_flash = maxf(0.0, _miss_flash - delta * 3.0)
	_combo_label.scale = _combo_label.scale.lerp(Vector2.ONE, minf(1.0, 10.0 * delta))
	# Combo chaud : la patte laisse une traînée d'étincelles.
	# (Fréquence par seconde, pas par image : même rendu quel que soit le PC.)
	if _combo >= HOT_COMBO and _state == State.PLAYING:
		_spark_acc += delta * (40.0 + 2.0 * _combo)
		var n := int(_spark_acc)
		if n > 0:
			_spark_acc -= n
			_fx.sparkle(_paw.position - _paw_tip_offset, n)
	queue_redraw()
	if _state != State.PLAYING:
		return

	_elapsed += delta
	_time_left = maxf(_time_left - delta, 0.0)
	_spawn_due_notes()
	_update_notes(delta)
	_assist_pad()
	_update_hud()
	if _time_left <= 0.0:
		_finish_round()


func _spawn_due_notes() -> void:
	while _spawn_cursor < _chart.size() and _chart[_spawn_cursor] - _travel_time <= _elapsed:
		var n := Note.new()
		n.speed = note_speed
		n.hit_x = HIT_X
		n.position = Vector2(SCREEN.x + SPAWN_MARGIN, _lanes[_spawn_cursor])
		n.texture = POINT_TEX
		n.scale = Vector2.ONE * NOTE_SCALE
		add_child(n)
		move_child(n, _fx.get_index() + 1)
		_notes.append(n)
		_total += 1
		_spawn_cursor += 1


func _update_notes(delta: float) -> void:
	for i in range(_notes.size() - 1, -1, -1):
		var n := _notes[i]
		n.advance(delta)
		if n.position.x < HIT_X - TAP_WINDOW:
			_register_miss(n)
			_notes.remove_at(i)


## Manette : le curseur est freiné et attiré vers la prochaine note à taper.
func _assist_pad() -> void:
	for n in _notes:
		if not n.dead and n.time_to_hit() < APPROACH_TIME:
			GameManager.pad_aim_assist(n.global_position, 130.0)
			return


# --- Score / feedback ----------------------------------------------------------

func _register_hit(n: Note) -> void:
	var dx := absf(n.position.x - HIT_X)
	var judge: Dictionary = JUDGES[JUDGES.size() - 1]
	for j in JUDGES:
		if dx <= float(j.max):
			judge = j
			break
	_hits += 1
	_combo += 1
	_best_combo = maxi(_best_combo, _combo)
	if judge == JUDGES[0]:
		_perfects += 1
	# Le combo multiplie les points (jusqu'à x3).
	_score += int(judge.points) * mini(1 + _combo / 10, 3)

	var power: float = judge.power
	_fx.scratch(n.position, 0.8 + 0.25 * power)
	_fx.burst(n.position, power)
	_zone_pulse = 1.0
	_shake = maxf(_shake, 0.25 * power)
	_pop_text(judge.text, n.position + Vector2(0, -70), judge.color, 34 if judge != JUDGES[0] else 42)
	_combo_label.scale = Vector2.ONE * 1.35
	_paw_swipe()
	if _combo % COMBO_STEP == 0:
		_combo_banner()


func _register_miss(n: Note) -> void:
	if _combo >= 5:
		_pop_text("COMBO PERDU", Vector2(HIT_X, n.position.y + 60), Color("ff6b6b"), 28)
	_combo = 0
	_miss_flash = 1.0
	_shake = maxf(_shake, 0.3)
	_pop_text("RATÉ !", n.position + Vector2(0, -60), Color("c8c8c8"), 30)
	n.crumble()


## Tous les COMBO_STEP coups : bannière, flash, gerbe de rembourrage.
func _combo_banner() -> void:
	_pop_text("COMBO x%d !" % _combo, Vector2(SCREEN.x * 0.55, 330), Color("ffd23f"), 72)
	_shake = maxf(_shake, 0.8)
	_miss_flash = 0.0
	for i in 3:
		_fx.burst(Vector2(randf_range(450, 1150), randf_range(250, 550)), 1.5)


func _paw_set_pressed(pressed: bool) -> void:
	if _paw_tween:
		_paw_tween.kill()
	_paw_tween = _paw.create_tween()
	_paw_tween.tween_property(_paw, "scale", _paw_base_scale * (0.8 if pressed else 1.0), 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Petit coup de griffe : la patte pivote d'un coup puis revient.
func _paw_swipe() -> void:
	var tw := _paw.create_tween()
	tw.tween_property(_paw, "rotation", randf_range(-0.35, -0.2), 0.05)
	tw.tween_property(_paw, "rotation", 0.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pop_text(text: String, at: Vector2, color: Color, font_size: int) -> void:
	var l := _make_label(font_size, color)
	l.text = text
	l.add_theme_color_override("font_outline_color", COL_DARK)
	l.add_theme_constant_override("outline_size", 10)
	l.size = Vector2(480, font_size + 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = at - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.rotation = randf_range(-0.12, 0.12)
	l.scale = Vector2.ONE * 0.4
	l.z_index = 20
	add_child(l)
	var tween := l.create_tween()
	tween.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(l, "position:y", l.position.y - 40, 0.7)
	tween.tween_property(l, "modulate:a", 0.0, 0.25)
	tween.tween_callback(l.queue_free)


func _update_hud() -> void:
	_time_label.text = "00:%02d" % ceili(_time_left)
	_score_label.text = "%d pts" % _score
	_combo_label.text = "x%d" % _combo if _combo >= 2 else ""
	var hot := _combo >= HOT_COMBO
	_combo_label.add_theme_color_override("font_color", Color("ffd23f") if hot else COL_CREAM)


func _finish_round() -> void:
	_state = State.FINISHED
	for n in _notes:
		n.queue_free()
	_notes.clear()

	var accuracy := float(_hits) / float(maxi(_total, 1))
	var won := accuracy >= win_accuracy
	if won:
		_audio.play()
		# Le canapé rend l'âme : rembourrage partout.
		for i in 8:
			_fx.burst(Vector2(randf_range(100, 1180), randf_range(200, 650)), 2.0)
		_shake = 1.0
	# La maison garde les traces du mini-jeu (voir maison_traces.gd).
	GameManager.record_result("canape", won)
	_title_label.text = "PAWSOME !" if won else "OOPSIE !"
	_title_label.add_theme_color_override("font_color", WIN_COLOR if won else LOSE_COLOR)
	_sub_label.text = "%d / %d griffures (%.0f%%)  ·  %d PERFECT  ·  Combo max x%d  ·  %d pts   ·   Clic pour rejouer   ·   Échap / B : maison" \
		% [_hits, _total, accuracy * 100.0, _perfects, _best_combo, _score]
	await get_tree().create_timer(0.8).timeout
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.4)


# --- Dessin ------------------------------------------------------------------

func _draw() -> void:
	# Fond d'origine (un peu plus grand que l'écran pour ne rien découvrir quand l'écran tremble).
	draw_rect(Rect2(Vector2(-20, HEADER_H - 20), SCREEN + Vector2(40, 40)), COL_BG)
	# Texture de tissu de la maquette (calque « TEXTURE »), posée sur le fond.
	draw_texture(TEXTURE_TEX, Vector2.ZERO)
	_draw_hit_zone()
	_draw_approach_rings()
	if _miss_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(1, 0.2, 0.2, 0.18 * _miss_flash))


## Zone de frappe : bande lumineuse qui pulse à chaque coup réussi.
func _draw_hit_zone() -> void:
	var glow := 0.12 + 0.25 * _zone_pulse
	for k in 3:
		var w := TAP_WINDOW * (1.0 - k * 0.3)
		draw_rect(Rect2(HIT_X - w, HEADER_H, w * 2.0, SCREEN.y - HEADER_H), Color(COL_ZONE, glow * 0.5))
	var y := HEADER_H + 6.0
	while y < SCREEN.y:
		draw_line(Vector2(HIT_X, y), Vector2(HIT_X, y + 16), Color(1, 1, 1, 0.5 + 0.5 * _zone_pulse), 4.0)
		y += 32.0


## Cercle d'approche (façon osu!) : il se resserre et touche la note pile au bon moment.
func _draw_approach_rings() -> void:
	var note_r := POINT_TEX.get_width() * 0.5 * NOTE_SCALE
	for n in _notes:
		if n.dead:
			continue
		var t := n.time_to_hit()
		if t > APPROACH_TIME or t < -0.1:
			continue
		var k := clampf(t / APPROACH_TIME, 0.0, 1.0)
		var r := note_r * (1.0 + 1.6 * k)
		var color := Color(1, 1, 1, 0.9 * (1.0 - k) + 0.1)
		draw_arc(Vector2(HIT_X, n.position.y), r, 0.0, TAU, 48, color, 4.0, true)
