extends CanvasLayer
## Oopsie Pawsie — écrans de fin, d'après les maquettes Figma :
##   - defaite()   : un mini-jeu raté (« MINI JEU - END 2 ») → TRY AGAIN relance le mini-jeu ;
##   - victoire()  : les 5 missions faites avant le jour → PAWSOME, RETRY relance une nuit ;
##   - trop_tard() : le jour s'est levé avant la fin des missions → YOU LOSE, TRY AGAIN relance une nuit.
## Posé par-dessus la scène : voile coloré (le bandeau du haut reste visible), le chat, un titre,
## éventuellement une phrase, et un gros bouton. Clic, Entrée / Espace ou A / Start = le bouton.

const FONT := preload("res://assets/fonts/FredokaOne-Regular.ttf")
const PAW_TEX := preload("res://assets/sprites/defaite/patte_bouton.svg")
const CAT_SAD_TEX := preload("res://assets/sprites/defaite/chat_triste.png")
const CAT_HAPPY_TEX := preload("res://assets/sprites/defaite/chat_content.png")
const CAT_LATE_TEX := preload("res://assets/sprites/defaite/chat_trop_tard.png")

const SCREEN := Vector2(1280, 720)
const HEADER_H := 116.0
const PAW_ROTATION := 11.7
const COL_CREAM := Color("fff2e4")
const COL_RED_VEIL := Color(122.0 / 255.0, 30.0 / 255.0, 0.0, 0.76)
const COL_GREEN_VEIL := Color(62.0 / 255.0, 113.0 / 255.0, 0.0, 0.81)
const ORANGE_BUTTON := [Color("d74209"), Color("e8561d"), Color("b53607"), Color("6d1e00")]
const GREEN_BUTTON := [Color("2d4b00"), Color("3d6400"), Color("223900"), Color("192a00")]

## Réglages de l'écran (remplis par les constructeurs ci-dessous). Les rectangles viennent de la maquette.
var veil_color := COL_RED_VEIL
var cat_texture: Texture2D = CAT_SAD_TEX
var cat_rect := Rect2(2, 203, 468, 517)      # les chats sont exportés en 2×
var title := "OOPSIE"
var title_rect := Rect2(365, 295, 559.2, 106.8)
var subtitle := ""
var subtitle_rect := Rect2()
var button_text := "TRY AGAIN"
var button_rect := Rect2(415.4, 422.2, 460.8, 99.6)
var button_colors: Array = ORANGE_BUTTON      # normal, survol, appuyé, bordure
## Ce que fait le bouton.
var on_confirm: Callable

var _done := false


## Mini-jeu raté : TRY AGAIN relance le mini-jeu.
static func defaite() -> CanvasLayer:
	var s := new()
	s.on_confirm = func() -> void: s.get_tree().reload_current_scene()
	return s


## Les 5 missions sont faites et il fait encore nuit.
static func victoire() -> CanvasLayer:
	var s := new()
	s.veil_color = COL_GREEN_VEIL
	s.cat_texture = CAT_HAPPY_TEX
	s.cat_rect = Rect2(0, 205, 448, 515)
	s.title = "PAWSOME"
	s.title_rect = Rect2(367, 263, 559.2, 106.8)
	s.subtitle = "Well done, you’ve managed to ruin everything overnight!"
	s.subtitle_rect = Rect2(367, 371, 559, 107)
	s.button_text = "RETRY"
	s.button_rect = Rect2(416, 470.2, 460.8, 99.6)
	s.button_colors = GREEN_BUTTON
	s.on_confirm = func() -> void: GameManager.restart_night()
	return s


## Le jour s'est levé avant la fin des missions.
static func trop_tard() -> CanvasLayer:
	var s := new()
	s.cat_texture = CAT_LATE_TEX
	s.cat_rect = Rect2(0, 205, 448, 515)
	# (« YOU LOOSE » dans la maquette : corrigé en « YOU LOSE ».)
	s.title = "YOU LOSE"
	s.title_rect = Rect2(367, 263, 559.2, 106.8)
	s.subtitle = "Failure, you didn’t complete your missions last night!"
	s.subtitle_rect = Rect2(395, 371, 503, 107)
	s.button_rect = Rect2(416, 470.2, 460.8, 99.6)
	s.on_confirm = func() -> void: GameManager.restart_night()
	return s


func _ready() -> void:
	layer = 10
	# Les jeux cachent le curseur (viseur, patte…) : ici on a besoin de la souris pour cliquer.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var voile := ColorRect.new()
	voile.color = veil_color
	voile.position = Vector2(0, HEADER_H)
	voile.size = Vector2(SCREEN.x, SCREEN.y - HEADER_H)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP  # bloque les clics vers le jeu en dessous
	add_child(voile)

	var cat := TextureRect.new()
	cat.texture = cat_texture
	cat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cat.stretch_mode = TextureRect.STRETCH_SCALE
	cat.size = cat_rect.size
	cat.position = cat_rect.position + Vector2(0, 420)
	cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cat)

	var title_label := _label(title, 91, title_rect)
	title_label.pivot_offset = title_rect.size * 0.5
	add_child(title_label)

	var sub_label: Label = null
	if subtitle != "":
		sub_label = _label(subtitle, 27, subtitle_rect)
		sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		add_child(sub_label)

	var button := _make_button()
	add_child(button)

	# Entrée en scène : voile, puis le chat qui surgit, le titre et le bouton qui « popent ».
	voile.modulate.a = 0.0
	title_label.scale = Vector2.ZERO
	button.scale = Vector2.ZERO
	var tw := create_tween().set_parallel()
	tw.tween_property(voile, "modulate:a", 1.0, 0.2)
	tw.tween_property(cat, "position", cat_rect.position, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
	if sub_label:
		sub_label.modulate.a = 0.0
		tw.tween_property(sub_label, "modulate:a", 1.0, 0.3).set_delay(0.2)
	tw.tween_property(button, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)


func _label(text: String, font_size: int, rect: Rect2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", COL_CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = rect.position
	l.size = rect.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_button() -> Button:
	var b := Button.new()
	b.position = button_rect.position
	b.size = button_rect.size
	b.pivot_offset = button_rect.size * 0.5
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var states := ["normal", "hover", "pressed"]
	for i in states.size():
		var style := StyleBoxFlat.new()
		style.bg_color = button_colors[i]
		style.border_color = button_colors[3]
		style.set_border_width_all(7)
		style.set_corner_radius_all(22)
		b.add_theme_stylebox_override(states[i], style)
	b.pressed.connect(_confirm)
	b.mouse_entered.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2.ONE * 1.05, 0.1))
	b.mouse_exited.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))

	# Contenu : texte + l'empreinte, centrés (12 px d'écart, comme dans la maquette).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var label := _label(button_text, 48, Rect2())
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var paw_box := Control.new()
	paw_box.custom_minimum_size = Vector2(56, 52)
	# Sinon la boîte prend toute la hauteur du bouton et l'empreinte se retrouve en haut.
	paw_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	paw_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(paw_box)
	var paw := TextureRect.new()
	paw.texture = PAW_TEX
	paw.size = PAW_TEX.get_size()
	paw.position = (paw_box.custom_minimum_size - paw.size) * 0.5
	paw.pivot_offset = paw.size * 0.5
	paw.rotation_degrees = PAW_ROTATION
	paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paw_box.add_child(paw)
	return b


func _unhandled_input(event: InputEvent) -> void:
	var confirm := false
	if event is InputEventKey and event.pressed and not event.echo:
		confirm = (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	elif event is InputEventJoypadButton and event.pressed and GameManager.pad_enabled:
		confirm = (event as InputEventJoypadButton).button_index in [JOY_BUTTON_A, JOY_BUTTON_START]
	if confirm:
		get_viewport().set_input_as_handled()
		_confirm()


func _confirm() -> void:
	if _done:
		return
	_done = true
	Sons.play("popup_fermer")
	on_confirm.call()
