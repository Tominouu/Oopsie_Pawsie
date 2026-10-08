extends Node2D
## Oopsie Pawsie — retrouve les croquettes cachées dans l'armoire.
## Clic sur les objets de l'armoire pour les jeter jusqu'à dégager
## le sac de croquettes avant la fin du temps.

enum State { PLAYING, FINISHED }

const Item := preload("res://scripts/mini_games/croquettes_item.gd")

const CUPBOARD_SIZE := Vector2(720, 440)
## Nombre d'objets posés directement sur le sac pour qu'il soit bien caché.
const COVER_COUNT := 20

const ITEM_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.25), Color(0.25, 0.45, 0.85), Color(0.3, 0.7, 0.35),
	Color(0.95, 0.8, 0.25), Color(0.6, 0.35, 0.8), Color(0.2, 0.7, 0.7),
	Color(0.95, 0.55, 0.7), Color(0.6, 0.6, 0.62), Color(0.78, 0.62, 0.4),
	Color(0.2, 0.25, 0.45),
]
const COL_BG := Color("1e1b2e")
const COL_WOOD := Color(0.55, 0.36, 0.22)
const COL_OUTLINE := Color(0.05, 0.05, 0.07)
const COL_TEXT := Color("f4f1de")
const WIN_COLOR := Color(0.25, 0.85, 0.45)
const LOSE_COLOR := Color(0.95, 0.30, 0.30)

@export_range(20, 300) var item_count := 110
@export var time_limit := 30.0
@export var result_delay := 0.6

var _state := State.PLAYING
var _time_left := 0.0
var _cleared := 0
var _cupboard_pos := Vector2.ZERO
var _items: Node2D
var _bag: Item

var _info_label: Label
var _overlay: ColorRect
var _title_label: Label
var _sub_label: Label


func _ready() -> void:
	randomize()
	var vp := get_viewport_rect().size
	_cupboard_pos = ((vp - CUPBOARD_SIZE) * 0.5 + Vector2(0, 20)).floor()
	_items = Node2D.new()
	_items.position = _cupboard_pos
	add_child(_items)
	_build_ui(vp)
	_time_left = time_limit
	_spawn_items()
	_update_info()


func _build_ui(vp: Vector2) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_info_label = _make_label(24, COL_TEXT)
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

	_sub_label = _make_label(28, Color.WHITE)
	_sub_label.position = Vector2(0, vp.y * 0.5 + 20)
	_sub_label.size = Vector2(vp.x, 50)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_sub_label)


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


# --- Entrées -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var p: Vector2 = make_input_local(event).position
	match _state:
		State.PLAYING:
			_click_items(p - _cupboard_pos)
		State.FINISHED:
			if _overlay.visible:
				get_tree().reload_current_scene()


func _click_items(point: Vector2) -> void:
	# On teste d'abord les objets dessinés au-dessus (les derniers enfants).
	for i in range(_items.get_child_count() - 1, -1, -1):
		var item := _items.get_child(i) as Item
		if item.flying or not item.hit_test(point):
			continue
		if item == _bag:
			finish(true, "Croquettes trouvées en %.1f s !" % (time_limit - _time_left))
		else:
			_throw(item)
		return


# --- Partie ------------------------------------------------------------------

func _spawn_items() -> void:
	var bag_pos := Vector2(
		randf_range(110, CUPBOARD_SIZE.x - 110),
		randf_range(CUPBOARD_SIZE.y * 0.45, CUPBOARD_SIZE.y - 70))
	_bag = _make_item(Item.Kind.CROQUETTES, bag_pos)
	_bag.rotation = randf_range(-0.3, 0.3)

	for i in COVER_COUNT:
		_make_item(_random_kind(), bag_pos + Vector2(randf_range(-35, 35), randf_range(-40, 40)))

	for i in maxi(item_count - COVER_COUNT, 0):
		# sqrt() tasse les objets vers le bas de l'armoire, comme un vrai tas
		var pos := Vector2(
			randf_range(50, CUPBOARD_SIZE.x - 50),
			lerpf(50, CUPBOARD_SIZE.y - 40, sqrt(randf())))
		_make_item(_random_kind(), pos)


func _make_item(kind: Item.Kind, pos: Vector2) -> Item:
	var item := Item.new()
	item.kind = kind
	item.size = Item.base_size(kind) * randf_range(0.85, 1.25)
	item.color = ITEM_COLORS.pick_random()
	item.position = pos
	item.rotation = randf_range(-0.7, 0.7)
	_items.add_child(item)
	return item


func _random_kind() -> Item.Kind:
	return randi_range(Item.Kind.CIRCLE, Item.Kind.TRIANGLE) as Item.Kind


func _throw(item: Item) -> void:
	item.flying = true
	item.move_to_front()  # passe devant le reste pendant le vol
	var dir := (item.position - CUPBOARD_SIZE * 0.5).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	dir = (dir + Vector2(randf_range(-0.4, 0.4), -0.6)).normalized()
	var tween := item.create_tween().set_parallel()
	tween.tween_property(item, "position", item.position + dir * 700.0, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "rotation", item.rotation + randf_range(-8.0, 8.0), 0.5)
	tween.tween_property(item, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(item.queue_free)
	_cleared += 1


func finish(won: bool, reason: String) -> void:
	if _state == State.FINISHED:
		return
	_state = State.FINISHED
	_update_info()
	# Dans tous les cas on montre où était le sac.
	_bag.move_to_front()
	var tween := _bag.create_tween()
	tween.tween_property(_bag, "scale", Vector2(1.5, 1.5), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_bag, "rotation", 0.0, 0.25)
	tween.tween_property(_bag, "scale", Vector2(1.3, 1.3), 0.15)

	await get_tree().create_timer(result_delay).timeout
	_title_label.text = "PAWSOME !" if won else "OOPSIE !"
	_title_label.add_theme_color_override("font_color", WIN_COLOR if won else LOSE_COLOR)
	_sub_label.text = reason + "   ·   Clic pour rejouer   ·   Échap : menu"
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.4)


# --- Boucle ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	_update_info()
	if _time_left <= 0.0:
		finish(false, "Temps écoulé ! Les croquettes étaient là.")


func _update_info() -> void:
	_info_label.text = "Trouve les croquettes !   Temps %.1f s   ·   Objets dégagés : %d   ·   Échap : menu" \
		% [_time_left, _cleared]


# --- Dessin ------------------------------------------------------------------

func _draw() -> void:
	draw_rect(get_viewport_rect(), COL_BG)
	_draw_cupboard()


func _draw_cupboard() -> void:
	var r := Rect2(_cupboard_pos, CUPBOARD_SIZE)
	draw_rect(r, Color(0.32, 0.21, 0.13))
	var x := 60.0
	while x < CUPBOARD_SIZE.x:
		draw_line(r.position + Vector2(x, 0), r.position + Vector2(x, CUPBOARD_SIZE.y), Color(0.24, 0.15, 0.09), 2.0)
		x += 60.0
	# ombre en haut et fond de l'armoire
	draw_rect(Rect2(r.position, Vector2(CUPBOARD_SIZE.x, 40)), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(r.position + Vector2(0, CUPBOARD_SIZE.y - 24), Vector2(CUPBOARD_SIZE.x, 24)), Color(0.22, 0.14, 0.08))
	draw_rect(r.grow(6), COL_WOOD, false, 12.0)
	draw_rect(r.grow(12), COL_OUTLINE, false, 3.0)
