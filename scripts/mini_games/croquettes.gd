extends Node2D
## Oopsie Pawsie — mini-jeu « Mission : opération croquettes » (maquette Figma « MINI JEU - PLACARD »).
## Le sachet de croquettes est caché au fond du placard, derrière plusieurs rangées de produits.
## Clic sur un produit = coup de patte qui le dégage. Clic sur le sachet = gagné, avant la fin du chrono.

enum State { INTRO, PLAYING, FINISHED }

const Item := preload("res://scripts/mini_games/croquettes_item.gd")

const FONT := preload("res://assets/fonts/FredokaOne-Regular.ttf")
const HEADER_TEX := preload("res://assets/sprites/croquettes/header.svg")
const NUIT_TEX := preload("res://assets/sprites/croquettes/nuit.svg")
const CHRONO_TEX := preload("res://assets/sprites/croquettes/chrono.svg")
const FERMER_TEX := preload("res://assets/sprites/croquettes/fermer.svg")
const PATTE_TEX := preload("res://assets/sprites/croquettes/patte.svg")
const CROQUETTES_TEX := preload("res://assets/sprites/croquettes/croquettes.svg")
const MEOW := preload("res://assets/sounds/meow1.mp3")

## Produits qui servent à cacher le sachet (le sac « poisson » est un leurre).
const PRODUCTS: Array[Texture2D] = [
	preload("res://assets/sprites/croquettes/cereales.svg"),
	preload("res://assets/sprites/croquettes/chips.svg"),
	preload("res://assets/sprites/croquettes/conserve_mais.svg"),
	preload("res://assets/sprites/croquettes/conserve_pois.svg"),
	preload("res://assets/sprites/croquettes/farine.svg"),
	preload("res://assets/sprites/croquettes/pates.svg"),
	preload("res://assets/sprites/croquettes/sac_poisson.svg"),
]
const CHIPS_INDEX := 1

const SCREEN := Vector2(1280, 720)
const HEADER_H := 116.0

## Bas des produits de chaque étagère (celle du bas est coupée par l'écran, comme dans la maquette).
const ROW_FLOORS: Array[float] = [398.0, 731.0]
const PLANK_RECT := Rect2(0, 379, 1280, 33)

## Rangée du fond : plus petite, plus haute et plus sombre, pour donner de la profondeur.
const BACK_SCALE := 0.8
const BACK_SHADE := 0.5
const LAYER_RISE := 10.0

## La patte remplace le curseur : le centre de ses coussinets (dans patte.svg) est
## le point qui touche les produits. Le bras est incliné comme dans la maquette.
const PAW_ANCHOR := Vector2(92.6, 90.0)
const PAW_ROTATION := -0.6
## Petit coup de patte vers l'avant (dans l'axe du bras) à chaque clic.
const PAW_TAP := Vector2(-22, -32)

const COL_BG := Color("9f9f9f")
const COL_PLANK := Color("6d6d6d")
const COL_CREAM := Color("fff2e4")
const COL_DARK := Color("2b1710")
const COL_BODY_TEXT := Color("6e4d41")
const COL_CLOSE_BG := Color("d9d9d9")
const WIN_COLOR := Color(0.25, 0.85, 0.45)
const LOSE_COLOR := Color(0.95, 0.30, 0.30)

@export var time_limit := 30.0
## Nombre de rangées de produits par étagère (la 1re est au fond).
@export_range(2, 6) var layers := 4
## Rangées où le sachet peut être caché (0 = tout au fond).
@export_range(0, 5) var target_max_layer := 1
@export var result_delay := 0.9

var _state := State.INTRO
var _time_left := 0.0
var _cleared := 0

var _shelf: Node2D
var _bag: Item
var _paw: Sprite2D
var _paw_tween: Tween
var _striking := false

var _time_label: Label
var _popup: Control
var _overlay: ColorRect
var _title_label: Label
var _sub_label: Label
var _audio: AudioStreamPlayer


func _ready() -> void:
	randomize()
	_time_left = time_limit
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_build_hud_back()
	_shelf = Node2D.new()
	add_child(_shelf)
	_fill_shelves()
	_build_paw()
	_build_hud_front()
	_build_popup()
	_build_overlay()
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


func _fill_shelves() -> void:
	var rows: Array = []
	for row in ROW_FLOORS.size():
		var row_layers: Array = []
		for layer in layers:
			row_layers.append(_fill_layer(row, layer))
		rows.append(row_layers)

	# Le sachet remplace un produit d'une rangée du fond, loin des bords de l'écran.
	var row := randi() % ROW_FLOORS.size()
	var layer := randi_range(0, mini(target_max_layer, layers - 2))
	var candidates: Array = rows[row][layer].filter(
		func(it: Item) -> bool: return it.position.x > 140.0 and it.position.x < SCREEN.x - 140.0)
	_bag = candidates.pick_random() if not candidates.is_empty() else rows[row][layer][0]
	_bag.setup(CROQUETTES_TEX)
	_bag.rotation = 0.0
	_bag.is_target = true

	# On s'assure qu'au moins deux produits le cachent vraiment.
	var center := _bag.to_global(Vector2(0, -CROQUETTES_TEX.get_height() * 0.5))
	var covering := 0
	for it in _shelf.get_children():
		if it.get_index() > _bag.get_index() and (it as Item).hit_test(center):
			covering += 1
	for i in maxi(0, 2 - covering):
		var front := layers - 1 - i
		var cover := _make_item(PRODUCTS.pick_random(), front)
		cover.position = Vector2(_bag.position.x + randf_range(-20, 20), _floor_y(row, front))

	_update_lighting(false)


func _fill_layer(row: int, layer: int) -> Array:
	var items: Array = []
	var x := randf_range(-60.0, 0.0)
	while x < SCREEN.x + 20.0:
		var index := randi() % PRODUCTS.size()
		var item := _make_item(PRODUCTS[index], layer)
		var w := item.texture.get_width() * item.scale.x
		item.position = Vector2(x + w * 0.5, _floor_y(row, layer))
		# Les sachets de chips sont penchés, comme dans la maquette.
		item.rotation = randf_range(-0.3, 0.3) if index == CHIPS_INDEX else randf_range(-0.03, 0.03)
		items.append(item)
		x += w + randf_range(-40.0, 5.0)
	return items


func _make_item(tex: Texture2D, layer: int) -> Item:
	var k := float(layer) / float(maxi(layers - 1, 1))
	var item := Item.new()
	item.setup(tex)
	item.scale = Vector2.ONE * lerpf(BACK_SCALE, 1.0, k)
	var shade := lerpf(BACK_SHADE, 1.0, k)
	item.modulate = Color(shade, shade, shade)
	_shelf.add_child(item)
	return item


func _floor_y(row: int, layer: int) -> float:
	return ROW_FLOORS[row] - (layers - 1 - layer) * LAYER_RISE


func _build_paw() -> void:
	_paw = Sprite2D.new()
	_paw.texture = PATTE_TEX
	_paw.centered = false
	_paw.offset = -PAW_ANCHOR
	_paw.rotation = PAW_ROTATION
	_paw.position = Vector2(800, 430)
	add_child(_paw)


func _build_hud_front() -> void:
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
	# Sinon le Panel avale les clics (souris ou A à la manette) faits dans la pop-up.
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = COL_CREAM
	style.border_color = COL_DARK
	style.set_border_width_all(6)
	style.set_corner_radius_all(18)
	box.add_theme_stylebox_override("panel", style)
	_popup.add_child(box)

	var title := _make_label(42, COL_DARK)
	title.text = "MISSION : OPERATION CAT FOOD"
	title.position = Vector2(215, 328)
	title.size = Vector2(860, 45)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup.add_child(title)

	var body := _make_label(32, COL_BODY_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(782, 0)
	body.text = "The food is somewhere in this closet. Move everything around " \
		+ "and turn everything over to find it within the time limit."
	body.position = Vector2(254, 400)
	body.size = Vector2(782, 160)
	_popup.add_child(body)

	_popup.add_child(_make_panel(Rect2(1075.5, 278.5, 33.66, 33.66), COL_CLOSE_BG, 4))
	_popup.add_child(_add_texture(FERMER_TEX, Vector2(1081.44, 286.32), false))


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
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return

	match _state:
		State.INTRO:
			_start_game()
		State.PLAYING:
			_strike(make_input_local(event).position)
		State.FINISHED:
			if _overlay.visible:
				get_tree().reload_current_scene()


func _start_game() -> void:
	_state = State.PLAYING
	var tween := _popup.create_tween()
	tween.tween_property(_popup, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_popup.hide)


# --- Boucle ------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _striking:
		_paw.position = get_viewport().get_mouse_position()

	if _state != State.PLAYING:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	_update_time_label()
	if _time_left <= 0.0:
		_finish(false, "Temps écoulé : les croquettes étaient là !")


func _update_time_label() -> void:
	_time_label.text = "00:%02d" % ceili(_time_left)


# --- Coup de patte -------------------------------------------------------------

func _strike(at: Vector2) -> void:
	_animate_paw(at)
	# On teste d'abord les produits dessinés devant (les derniers enfants).
	for i in range(_shelf.get_child_count() - 1, -1, -1):
		var item := _shelf.get_child(i) as Item
		if not item.hit_test(at):
			continue
		if item.is_target:
			_finish(true, "Croquettes trouvées en %.1f s  ·  %d produits dégagés" \
				% [time_limit - _time_left, _cleared])
		else:
			_throw(item)
		return


func _throw(item: Item) -> void:
	item.flying = true
	item.move_to_front()  # passe devant le reste pendant le vol
	var center := item.to_global(Vector2(0, -item.texture.get_height() * 0.5))
	var side := signf(center.x - SCREEN.x * 0.5)
	if side == 0.0:
		side = 1.0
	var dir := Vector2(side * randf_range(0.6, 1.0), randf_range(-0.9, -0.4)).normalized()
	var tween := item.create_tween()
	tween.tween_property(item, "position", item.position + dir * 900.0, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(item, "rotation", item.rotation + side * randf_range(4.0, 9.0), 0.55)
	tween.parallel().tween_property(item, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	tween.tween_callback(item.queue_free)
	_cleared += 1
	_update_lighting(true)


## Un produit dont le centre n'est plus caché par rien devant lui passe en pleine lumière.
func _update_lighting(animate: bool) -> void:
	var items := _shelf.get_children()
	for i in items.size():
		var item := items[i] as Item
		if item.flying or item.modulate == Color.WHITE:
			continue
		var center := item.to_global(Vector2(0, -item.texture.get_height() * 0.5))
		var covered := false
		for j in range(i + 1, items.size()):
			if (items[j] as Item).hit_test(center):
				covered = true
				break
		if covered:
			continue
		if animate:
			item.create_tween().tween_property(item, "modulate", Color.WHITE, 0.25)
		else:
			item.modulate = Color.WHITE


func _animate_paw(at: Vector2) -> void:
	if _paw_tween:
		_paw_tween.kill()
	_striking = true
	_paw_tween = create_tween()
	_paw_tween.tween_property(_paw, "position", at + PAW_TAP, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_paw_tween.tween_property(_paw, "position", at, 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_paw_tween.tween_callback(func() -> void: _striking = false)


func _finish(won: bool, message: String) -> void:
	if _state == State.FINISHED:
		return
	_state = State.FINISHED
	_update_time_label()
	# Dans tous les cas on montre le sachet, en pleine lumière devant le reste.
	_bag.move_to_front()
	_bag.modulate = Color.WHITE
	var tween := _bag.create_tween()
	tween.tween_property(_bag, "scale", Vector2.ONE * 1.35, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	draw_rect(Rect2(Vector2(0, HEADER_H), SCREEN - Vector2(0, HEADER_H)), COL_BG)
	draw_rect(PLANK_RECT, COL_PLANK)
