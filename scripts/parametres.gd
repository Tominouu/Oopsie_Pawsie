extends CanvasLayer
## Oopsie Pawsie — page SETTINGS (maquette Figma « 1280/720 ECRAN SETTINGS »).
## S'ouvre par-dessus le menu titre ou la maison (le jeu est en pause, la nuit ne compte pas).
##   CONTROLS : GAMEPAD ou KEYBOARD + MOUSE (en clavier + souris, la manette est ignorée).
##   SOUND + MUSIC : OFF coupe tout le son.
##   KEYBOARD CONTROLS : rappel des touches (lettres selon la disposition du clavier : ZQSD en AZERTY).
## Souris : clic sur une case ou son texte. Clavier / manette : haut-bas pour choisir,
## Entrée / Espace / A pour cocher, Échap / B ou BACK HOME pour revenir.

const FONT := preload("res://assets/fonts/FredokaOne-Regular.ttf")
const DIR := "res://assets/sprites/reglages/"

const COL_DARK := Color("2c201d")
const COL_CREAM := Color("fff2e4")
const COL_FOCUS := Color("f89309")

const BOX := 53.856
const BOX_BORDER := 4.48
const BOX_RADIUS := 6.336
## Lignes cochables : case (coin haut-gauche) et texte.
const ROWS := [
	{"id": "pad", "box": Vector2(109, 254.82), "text": "GAMEPAD"},
	{"id": "keyboard", "box": Vector2(109, 314.34), "text": "KEYBOARD + MOUSE"},
	{"id": "sound_off", "box": Vector2(109, 528.82), "text": "OFF"},
]
const TEXT_X := 183.07
const BACK_RECT := Rect2(109, 93, 230.52, 42.33)
## Touches : case, action, touche physique (la lettre affichée dépend du clavier).
const KEYS := [
	[254.82, "UP", KEY_W], [314.34, "DOWN", KEY_S], [374.57, "LEFT", KEY_A], [434.09, "RIGHT", KEY_D],
]
const KEYS_X := 642.0
const KEYS_TEXT_X := 716.07
## La patte de la maquette : centre et rotation (pivotée dans Figma).
const PAW_CENTER := Vector2(1084, 586)
const PAW_ROT := -31.0

signal closed

## Éléments que le clavier / la manette parcourent : les 3 lignes puis BACK HOME.
var _focus := -1
var _boxes: Array[Panel] = []
var _crosses: Array[TextureRect] = []
var _row_rects: Array[Rect2] = []
var _back: Panel
var _was_paused := false
## Stick gauche : un cran par inclinaison (pas de défilement en continu).
var _stick_held := false


## Ouvre la page par-dessus `parent` (le menu ou la maison).
static func open(parent: Node) -> CanvasLayer:
	var page: CanvasLayer = load("res://scripts/parametres.gd").new()
	parent.add_child(page)
	return page


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	_refresh()


func _build() -> void:
	var root := Control.new()
	root.size = Vector2(1280, 720)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_gui_input)
	add_child(root)

	var bg := TextureRect.new()
	bg.texture = load(DIR + "fond.png")
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# Bouton BACK HOME : flèche vers la gauche + texte, sur fond sombre arrondi.
	_back = Panel.new()
	_back.position = BACK_RECT.position
	_back.size = BACK_RECT.size
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.add_theme_stylebox_override("panel", _style(COL_DARK, COL_DARK, 3.06, 9.18))
	root.add_child(_back)
	var arrow := TextureRect.new()
	arrow.texture = load(DIR + "fleche.svg")
	arrow.flip_h = true
	arrow.position = Vector2(22.3, 11.4)
	arrow.size = Vector2(24.07, 19.53)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.add_child(arrow)
	var back_label := _label("BACK HOME", 25.5, COL_CREAM)
	back_label.position = Vector2(58.63, 5.92)
	_back.add_child(back_label)

	root.add_child(_title("CONTROLS", Vector2(109, 173)))
	root.add_child(_title("SOUND + MUSIC", Vector2(109, 447)))
	root.add_child(_title("KEYBOARD CONTROLS", Vector2(642, 173)))

	for row in ROWS:
		var box := _box(row.box)
		root.add_child(box)
		_boxes.append(box)
		var cross := TextureRect.new()
		cross.texture = load(DIR + "croix.svg")
		cross.position = Vector2(10.24, 10.75)
		cross.size = Vector2(33.26, 32.16)
		cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(cross)
		_crosses.append(cross)
		var text := _label(row.text, 40, COL_DARK)
		text.position = Vector2(TEXT_X, row.box.y - 0.58)
		root.add_child(text)
		# Zone cliquable : la case et son texte.
		_row_rects.append(Rect2(row.box, Vector2(TEXT_X - row.box.x + text.get_minimum_size().x, BOX)))

	for k in KEYS:
		var box := _box(Vector2(KEYS_X, k[0]))
		root.add_child(box)
		var letter := _label(_key_name(k[2]), 40, COL_DARK)
		letter.size = Vector2(BOX, 48)
		letter.position = Vector2(0, 2.0)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(letter)
		var action := _label(k[1], 40, COL_DARK)
		action.position = Vector2(KEYS_TEXT_X, k[0] - 0.58)
		root.add_child(action)

	var paw := TextureRect.new()
	paw.texture = load(DIR + "patte.svg")
	paw.size = paw.texture.get_size()
	paw.pivot_offset = paw.size * 0.5
	paw.position = PAW_CENTER - paw.size * 0.5
	paw.rotation_degrees = PAW_ROT
	paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(paw)


## Lettre de la touche physique selon la disposition du clavier (W → Z en AZERTY).
func _key_name(physical: Key) -> String:
	var k := DisplayServer.keyboard_get_keycode_from_physical(physical)
	return OS.get_keycode_string(k).to_upper() if k != KEY_NONE else OS.get_keycode_string(physical)


func _label(text: String, size: float, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", int(size))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _title(text: String, pos: Vector2) -> Label:
	var l := _label(text, 50, COL_DARK)
	l.position = pos
	return l


func _box(pos: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(BOX, BOX)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(COL_CREAM, COL_DARK, BOX_BORDER, BOX_RADIUS))
	return p


func _style(bg: Color, border: Color, width: float, radius: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(int(round(width)))
	s.set_corner_radius_all(int(round(radius)))
	return s


func _checked(i: int) -> bool:
	match ROWS[i].id:
		"pad":
			return GameManager.pad_enabled
		"keyboard":
			return not GameManager.pad_enabled
		_:
			return GameManager.sound_off


func _toggle(i: int) -> void:
	match ROWS[i].id:
		"pad":
			GameManager.set_pad_enabled(true)
		"keyboard":
			GameManager.set_pad_enabled(false)
		"sound_off":
			GameManager.set_sound_off(not GameManager.sound_off)
	Sons.play("survol")
	_refresh()


## Coche les cases et entoure en orange l'élément choisi au clavier / à la manette.
func _refresh() -> void:
	for i in _boxes.size():
		_crosses[i].visible = _checked(i)
		var focused := i == _focus
		_boxes[i].add_theme_stylebox_override("panel", _style(COL_CREAM, COL_FOCUS if focused else COL_DARK, BOX_BORDER, BOX_RADIUS))
	_back.add_theme_stylebox_override("panel", _style(COL_DARK, COL_FOCUS if _focus == ROWS.size() else COL_DARK, 3.06, 9.18))


func _close() -> void:
	Sons.play("popup_fermer")
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()


func _activate(i: int) -> void:
	if i == ROWS.size():
		_close()
	elif i >= 0:
		_toggle(i)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p := (event as InputEventMouseButton).position
		if BACK_RECT.has_point(p):
			_close()
			return
		for i in _row_rects.size():
			if _row_rects[i].has_point(p):
				_focus = i
				_toggle(i)
				return
	elif event is InputEventMouseMotion:
		# Survol : le doigt montre ce qui est cliquable.
		var p := (event as InputEventMouseMotion).position
		var hover := BACK_RECT.has_point(p)
		for r in _row_rects:
			hover = hover or r.has_point(p)
		(get_child(0) as Control).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover else Control.CURSOR_ARROW


## Clavier et manette (la manette marche ici même en mode clavier + souris, pour pouvoir la réactiver).
func _input(event: InputEvent) -> void:
	var move := 0
	var confirm := false
	var back := false
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_UP, KEY_W, KEY_Z:
				move = -1
			KEY_DOWN, KEY_S:
				move = 1
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				confirm = true
			KEY_ESCAPE:
				back = true
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_UP:
				move = -1
			JOY_BUTTON_DPAD_DOWN:
				move = 1
			JOY_BUTTON_A:
				confirm = true
			JOY_BUTTON_B, JOY_BUTTON_BACK, JOY_BUTTON_START:
				back = true
	elif event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == JOY_AXIS_LEFT_Y:
		var v := (event as InputEventJoypadMotion).axis_value
		if absf(v) > 0.6 and not _stick_held:
			move = signi(int(signf(v)))
			_stick_held = true
		elif absf(v) < 0.3:
			_stick_held = false
	else:
		return
	get_viewport().set_input_as_handled()
	if back:
		_close()
	elif move != 0:
		_focus = posmod(_focus + move, ROWS.size() + 1) if _focus >= 0 else (0 if move > 0 else ROWS.size())
		Sons.play("survol")
		_refresh()
	elif confirm:
		if _focus < 0:
			_focus = 0
			_refresh()
		else:
			_activate(_focus)
