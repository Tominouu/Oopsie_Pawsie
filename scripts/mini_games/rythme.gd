extends Node2D
## Oopsie Pawsie — mini-jeu de rythme façon osu! : les empreintes (TAP) se tapent
## au vol, les griffures (HOLD) se suivent au curseur, le tout au niveau de la patte.

enum State { PLAYING, FINISHED }

const Note := preload("res://scripts/mini_games/rythme_note.gd")

const POINT_TEX := preload("res://assets/sprites/rythme/point.png")
const LIGNE_TEX := preload("res://assets/sprites/rythme/ligne.png")
const GRIFFE_TEX := preload("res://assets/sprites/rythme/griffe.png")
const PATTE_TEX := preload("res://assets/sprites/rythme/patte.png")

const SCREEN := Vector2(1280, 720)
const HIT_X := 320.0
## Tolérance en pixels autour de la zone de frappe pour taper/attraper une note.
const TAP_WINDOW := 50.0
const TAP_HIT_RADIUS := 46.0
const NOTE_SCALE := 1.6
## Les lignes (HOLD) gardent un grossissement plus léger : à NOTE_SCALE, leur tracé
## déborderait de l'écran avant la fin de la griffure.
const HOLD_NOTE_SCALE := 1.15
## Distance max curseur ↔ bille pendant une griffure maintenue.
const HOLD_TOLERANCE := 115.0
const SPAWN_MARGIN := 170.0
const LANE_MIN_Y := 140.0
const LANE_MAX_Y := 560.0
## Points locaux approximant la forme de ligne.png (centrée), du début à la fin.
const CURVE_POINTS: Array[Vector2] = [Vector2(-118, 55), Vector2(-16, -38), Vector2(128, -8)]

const COL_BG := Color("eac89c")
const COL_HEADER := Color(0.1, 0.06, 0.05, 0.85)
const COL_HIT_LINE := Color(1, 1, 1, 0.3)
const COL_TEXT := Color("f4f1de")
const WIN_COLOR := Color(0.25, 0.85, 0.45)
const LOSE_COLOR := Color(0.95, 0.30, 0.30)

@export var time_limit := 30.0
@export var note_speed := 420.0
@export_range(0.0, 1.0) var hold_chance := 0.32
@export_range(0.0, 1.0) var win_accuracy := 0.65

var _state := State.PLAYING
var _time_left := 0.0
var _elapsed := 0.0
var _travel_time := 0.0

var _chart: Array[Dictionary] = []
var _spawn_cursor := 0
var _notes: Array[Note] = []
var _active_hold: Note = null

var _combo := 0
var _best_combo := 0
var _hits := 0
var _total := 0
var _score := 0
var _miss_flash := 0.0

var _paw: Sprite2D
var _paw_base_scale := Vector2.ONE
var _paw_tip_offset := Vector2.ZERO
var _paw_tween: Tween

var _info_label: Label
var _overlay: ColorRect
var _title_label: Label
var _sub_label: Label


func _ready() -> void:
	randomize()
	_time_left = time_limit
	_travel_time = (SCREEN.x + SPAWN_MARGIN - HIT_X) / note_speed
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_build_paw()
	_build_ui(get_viewport_rect().size)
	_generate_chart()


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


func _build_ui(vp: Vector2) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_info_label = _make_label(22, COL_TEXT)
	_info_label.position = Vector2(16, 10)
	layer.add_child(_info_label)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	_overlay.size = vp
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)

	_title_label = _make_label(96, Color.WHITE)
	_title_label.add_theme_constant_override("outline_size", 10)
	_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_title_label.position = Vector2(0, vp.y * 0.5 - 120)
	_title_label.size = Vector2(vp.x, 130)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_title_label)

	_sub_label = _make_label(24, Color.WHITE)
	_sub_label.position = Vector2(0, vp.y * 0.5 + 20)
	_sub_label.size = Vector2(vp.x, 50)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_sub_label)


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


# --- Génération du parcours ---------------------------------------------------

func _generate_chart() -> void:
	var t := _travel_time + 0.4
	while t < time_limit - 0.8:
		var is_hold := randf() < hold_chance
		var dur := randf_range(0.7, 1.2) if is_hold else 0.0
		_chart.append({
			"hit_time": t,
			"kind": Note.Kind.HOLD if is_hold else Note.Kind.TAP,
			"lane_y": randf_range(LANE_MIN_Y, LANE_MAX_Y),
			"hold_duration": dur,
		})
		t += dur + randf_range(0.55, 1.1)


# --- Entrées -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		GameManager.back_to_house()
		return
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	var mb := event as InputEventMouseButton

	if _state == State.FINISHED:
		if mb.pressed and _overlay.visible:
			get_tree().reload_current_scene()
		return

	var p: Vector2 = make_input_local(event).position
	if mb.pressed:
		_try_press(p)
	else:
		_try_release()


func _try_press(p: Vector2) -> void:
	_paw_set_pressed(true)
	if _active_hold != null:
		return
	var best: Note = null
	var best_dist := INF
	for n in _notes:
		if n.judge != Note.Judge.APPROACHING or absf(n.position.x - HIT_X) > TAP_WINDOW:
			continue
		var d := p.distance_to(n.position)
		if d <= TAP_HIT_RADIUS * NOTE_SCALE and d < best_dist:
			best = n
			best_dist = d
	if best == null:
		return
	if best.kind == Note.Kind.TAP:
		_register_hit(best.position)
		_notes.erase(best)
		best.queue_free()
	else:
		best.start_hold()
		_active_hold = best


func _try_release() -> void:
	_paw_set_pressed(false)
	if _active_hold == null or _active_hold.judge != Note.Judge.HOLDING:
		return
	_register_miss()
	_notes.erase(_active_hold)
	_active_hold.queue_free()
	_active_hold = null


# --- Boucle ------------------------------------------------------------------

func _process(delta: float) -> void:
	var mouse := get_local_mouse_position()
	if _active_hold != null:
		var target := _active_hold.target_world_position()
		_paw.position = Vector2(target.x, mouse.y) + _paw_tip_offset
	else:
		_paw.position = mouse + _paw_tip_offset
	if _state != State.PLAYING:
		return
	_elapsed += delta
	_time_left = maxf(_time_left - delta, 0.0)
	_miss_flash = maxf(0.0, _miss_flash - delta * 3.0)

	_spawn_due_notes()
	_update_notes(delta)
	_update_info()
	queue_redraw()

	if _time_left <= 0.0:
		_finish_round()


func _spawn_due_notes() -> void:
	while _spawn_cursor < _chart.size() and _chart[_spawn_cursor].hit_time - _travel_time <= _elapsed:
		_spawn_note(_chart[_spawn_cursor])
		_spawn_cursor += 1


func _spawn_note(data: Dictionary) -> void:
	var n := Note.new()
	n.kind = data.kind
	n.speed = note_speed
	n.hit_x = HIT_X
	n.position = Vector2(SCREEN.x + SPAWN_MARGIN, data.lane_y)
	if data.kind == Note.Kind.TAP:
		n.texture = POINT_TEX
		n.scale = Vector2.ONE * NOTE_SCALE
	else:
		n.texture = LIGNE_TEX
		n.hold_duration = data.hold_duration
		n.curve_points = PackedVector2Array(CURVE_POINTS)
		n.scale = Vector2.ONE * HOLD_NOTE_SCALE
	add_child(n)
	_notes.append(n)
	_total += 1


func _update_notes(delta: float) -> void:
	var mouse := get_local_mouse_position()
	for i in range(_notes.size() - 1, -1, -1):
		var n := _notes[i]
		n.advance(delta)
		match n.judge:
			Note.Judge.APPROACHING:
				if n.position.x < HIT_X - TAP_WINDOW:
					_register_miss()
					_despawn(i)
			Note.Judge.HOLDING:
				if absf(mouse.y - n.target_world_position().y) > HOLD_TOLERANCE:
					_register_miss()
					_active_hold = null
					_despawn(i)
			Note.Judge.RESOLVED:
				_register_hit(n.position)
				_active_hold = null
				_paw_set_pressed(false)
				_despawn(i)


func _despawn(i: int) -> void:
	var n := _notes[i]
	_notes.remove_at(i)
	n.queue_free()


# --- Score / feedback ----------------------------------------------------------

func _register_hit(at: Vector2) -> void:
	_hits += 1
	_combo += 1
	_best_combo = maxi(_best_combo, _combo)
	_score += 100 + _combo * 5
	_spawn_griffe(at)


func _register_miss() -> void:
	_combo = 0
	_miss_flash = 1.0


func _paw_set_pressed(pressed: bool) -> void:
	if _paw_tween:
		_paw_tween.kill()
	_paw_tween = _paw.create_tween()
	_paw_tween.tween_property(_paw, "scale", _paw_base_scale * (0.8 if pressed else 1.0), 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _spawn_griffe(at: Vector2) -> void:
	var g := Sprite2D.new()
	g.texture = GRIFFE_TEX
	g.position = at
	g.rotation = randf_range(-0.25, 0.25)
	g.scale = Vector2.ONE * randf_range(0.5, 0.7)
	g.modulate.a = 0.0
	add_child(g)
	var tween := g.create_tween()
	tween.tween_property(g, "modulate:a", 1.0, 0.05)
	tween.tween_interval(0.12)
	tween.tween_property(g, "modulate:a", 0.0, 0.3)
	tween.tween_callback(g.queue_free)


func _update_info() -> void:
	_info_label.text = "Temps %.1f s   ·   Combo x%d (record x%d)   ·   Score %d   ·   Échap / B : maison" \
		% [_time_left, _combo, _best_combo, _score]


func _finish_round() -> void:
	_state = State.FINISHED
	for n in _notes:
		n.queue_free()
	_notes.clear()
	_active_hold = null

	var accuracy := float(_hits) / float(maxi(_total, 1))
	var won := accuracy >= win_accuracy
	_title_label.text = "PAWSOME !" if won else "OOPSIE !"
	_title_label.add_theme_color_override("font_color", WIN_COLOR if won else LOSE_COLOR)
	_sub_label.text = "%d / %d griffures réussies (%.0f%%)   ·   Record combo x%d   ·   Clic pour rejouer   ·   Échap / B : maison" \
		% [_hits, _total, accuracy * 100.0, _best_combo]
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.4)


# --- Dessin ------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), COL_BG)
	draw_rect(Rect2(0, 0, SCREEN.x, 56), COL_HEADER)

	var y := 60.0
	while y < SCREEN.y:
		draw_line(Vector2(HIT_X, y), Vector2(HIT_X, y + 16), COL_HIT_LINE, 4.0)
		y += 32.0

	if _miss_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(1, 0.2, 0.2, 0.18 * _miss_flash))
