extends Node2D
## Oopsie Pawsie — la maison (maquette Figma « MAP - Nuit »), hub du jeu.
## Le chat se déplace au clavier (ZQSD / WASD / flèches), à la manette (stick gauche / croix)
## ou en cliquant au sol. Les objets interactifs s'éclairent au survol ou quand le chat est à côté :
## clic dessus (le chat y va tout seul), E / Espace / Entrée ou A à la manette pour lancer le mini-jeu.

const Chat := preload("res://scripts/maison_chat.gd")

const FONT := preload("res://assets/fonts/FredokaOne-Regular.ttf")
const DIR := "res://assets/sprites/maison/"

const SCREEN := Vector2(1280, 720)
const HEADER_H := 116.0

## Calques de la carte, dans l'ordre de la maquette : nom du PNG (exporté en 2×) et coin haut-gauche.
const LAYERS := [
	["sol_cuisine", Vector2(0, 116)], ["etagere", Vector2(8, 464)], ["poubelle", Vector2(378, 134)],
	["frigo", Vector2(287, 117)], ["tapis", Vector2(624, 407)], ["lit", Vector2(997, 130)],
	["cuisine", Vector2(0, 116)], ["placard_gauche", Vector2(101, 210)], ["placard_droit", Vector2(186, 210)],
	["meuble_tv", Vector2(725, 646)], ["table", Vector2(171, 443)], ["canape", Vector2(728, 358)],
	["bouton_quitter", Vector2(0, 642)], ["table_basse", Vector2(738, 479)], ["fauteuil", Vector2(957, 464)],
	["souris", Vector2(406, 210)], ["aquarium", Vector2(667, 116)], ["table_chevet", Vector2(1231, 338)],
	["plante", Vector2(907, 613)],
]

## Objets qui lancent un mini-jeu : calques concernés, scène, texte affiché.
const INTERACTABLES := [
	{"layers": ["aquarium"], "scene": "res://scenes/mini_games/scene_aquarium.tscn", "label": "Pêcher le poisson rose"},
	{"layers": ["souris"], "scene": "res://scenes/mini_games/souris.tscn", "label": "Chasser la souris"},
	{"layers": ["placard_gauche", "placard_droit"], "scene": "res://scenes/mini_games/croquettes.tscn", "label": "Fouiller les placards"},
	{"layers": ["canape"], "scene": "res://scenes/mini_games/rythme.tscn", "label": "Griffer le canapé"},
	{"layers": ["meuble_tv"], "scene": "res://scenes/mini_games/cable.tscn", "label": "Débrancher la télé"},
]

## Zones où le chat ne peut pas marcher (meubles), relevées sur la maquette.
const OBSTACLES := [
	Rect2(0, 0, 1280, 116),        # bandeau
	Rect2(0, 116, 86, 285),        # plaques de cuisson
	Rect2(0, 116, 280, 143),       # plan de travail + évier + placards
	Rect2(287, 117, 81, 140),      # frigo
	Rect2(378, 134, 55, 70),       # poubelle
	Rect2(8, 464, 80, 185),        # étagère
	Rect2(171, 443, 390, 254),     # table + chaises
	Rect2(667, 116, 168, 96),      # meuble de l'aquarium
	Rect2(997, 130, 278, 214),     # lit
	Rect2(1231, 338, 45, 74),      # table de chevet
	Rect2(728, 358, 167, 85),      # canapé
	Rect2(738, 479, 136, 76),      # table basse
	Rect2(957, 464, 75, 97),       # fauteuil
	Rect2(725, 646, 173, 74),      # meuble TV
	Rect2(935, 632, 60, 76),       # pot de la plante
	Rect2(0, 642, 83, 78),         # bouton quitter
]

## Chat de la maquette : coin haut-gauche (41 × 131) et centre du torse dans l'image.
const CAT_START := Vector2(522, 290) + Chat.TORSO
const CAT_RADIUS := 18.0
## La tête est à ~30 px devant le torse.
const HEAD_OFFSET := 30.0
const HEAD_RADIUS := 8.0
## Distance max (bord de l'objet ↔ torse du chat) pour pouvoir interagir.
const REACH := CAT_RADIUS + 34.0
const CELL := 10
const PAD_DEADZONE := 0.25

const QUIT_RECT := Rect2(10, 655, 62, 60)
const NIGHT_TINT := Color(0, 29.0 / 255.0, 56.0 / 255.0, 0.17)
const COL_FLOOR := Color("b19e8a")
const COL_CREAM := Color("fff2e4")
const COL_DARK := Color("2b1710")
## Surbrillance : éclaircit vers le blanc sans changer la teinte (un modulate > 1 sature les couleurs).
const HIGHLIGHT_SHADER := """
shader_type canvas_item;
uniform float amount = 0.2;
void fragment() {
	// COLOR contient déjà la texture : ne pas la remultiplier.
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), amount);
}
"""

var _layers := {}
var _cat: Chat
var _grid := AStarGrid2D.new()
var _path := PackedVector2Array()
## Objet vers lequel le chat marche après un clic (son mini-jeu se lance à l'arrivée).
var _pending: Dictionary = {}
var _near: Dictionary = {}
var _hovered: Dictionary = {}
var _quit_hovered := false
## Vrai quand la dernière entrée vient de la manette (la bulle affiche alors « A : … »).
var _using_pad := false
var _highlight_mat := ShaderMaterial.new()

var _prompt: PanelContainer
var _prompt_label: Label
var _tooltip: PanelContainer
var _tooltip_label: Label


func _ready() -> void:
	var shader := Shader.new()
	shader.code = HIGHLIGHT_SHADER
	_highlight_mat.shader = shader
	_build_map()
	_build_grid()
	_build_cat()
	_build_ui()


# --- Construction ----------------------------------------------------------------

func _build_map() -> void:
	var floor_rect := ColorRect.new()
	floor_rect.color = COL_FLOOR
	floor_rect.size = SCREEN
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)

	for entry in LAYERS:
		var tex: Texture2D = load(DIR + entry[0] + ".png")
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.position = entry[1]
		t.size = tex.get_size() * 0.5
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t)
		_layers[entry[0]] = t

	# Voile bleu de la nuit (sous le bandeau et le chat, comme dans la maquette).
	var night := ColorRect.new()
	night.color = NIGHT_TINT
	night.size = SCREEN
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)

	_add_texture(load(DIR + "header.svg"), Vector2.ZERO)
	_add_texture(load(DIR + "nuit.svg"), Vector2(572.75, 24))
	var gear_bg := Panel.new()
	gear_bg.position = Vector2(1172, 22)
	gear_bg.size = Vector2(68.144, 69.144)
	gear_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = COL_CREAM
	style.set_corner_radius_all(6)
	gear_bg.add_theme_stylebox_override("panel", style)
	add_child(gear_bg)
	_add_texture(load(DIR + "reglages.svg"), Vector2(1182.98, 36))


func _build_grid() -> void:
	_grid.region = Rect2i(0, 0, int(SCREEN.x) / CELL, int(SCREEN.y) / CELL)
	_grid.cell_size = Vector2(CELL, CELL)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for y in _grid.region.size.y:
		for x in _grid.region.size.x:
			var center := _cell_center(Vector2i(x, y))
			_grid.set_point_solid(Vector2i(x, y), not _is_walkable(center))


func _build_cat() -> void:
	_cat = Chat.new()
	var saved: Vector2 = GameManager.cat_position
	if saved.is_finite() and _is_walkable(saved):
		_cat.position = saved
		_cat.rotation = GameManager.cat_rotation
	else:
		_cat.position = CAT_START
	add_child(_cat)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_prompt = _make_bubble()
	_prompt_label = _prompt.get_child(0)
	layer.add_child(_prompt)
	_tooltip = _make_bubble()
	_tooltip_label = _tooltip.get_child(0)
	layer.add_child(_tooltip)


func _make_bubble() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = COL_CREAM
	style.border_color = COL_DARK
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", style)
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", COL_DARK)
	p.add_child(l)
	p.visible = false
	return p


func _add_texture(tex: Texture2D, pos: Vector2) -> void:
	var t := TextureRect.new()
	t.texture = tex
	t.position = pos
	t.size = tex.get_size()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)


# --- Géométrie ---------------------------------------------------------------------

func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL + Vector2(CELL, CELL) * 0.5


func _to_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x) / CELL, 0, _grid.region.size.x - 1), clampi(int(p.y) / CELL, 0, _grid.region.size.y - 1))


func _is_walkable(p: Vector2) -> bool:
	if p.x < CAT_RADIUS or p.y < CAT_RADIUS or p.x > SCREEN.x - CAT_RADIUS or p.y > SCREEN.y - CAT_RADIUS:
		return false
	for r in OBSTACLES:
		if _rect_distance(r, p) < CAT_RADIUS:
			return false
	return true


func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()


func _object_rect(obj: Dictionary) -> Rect2:
	var rect := Rect2()
	for i in obj.layers.size():
		var t: TextureRect = _layers[obj.layers[i]]
		var r := Rect2(t.position, t.size)
		rect = r if i == 0 else rect.merge(r)
	return rect


func _object_at(p: Vector2) -> Dictionary:
	for obj in INTERACTABLES:
		for layer_name in obj.layers:
			var t: TextureRect = _layers[layer_name]
			if Rect2(t.position, t.size).has_point(p):
				return obj
	return {}


## Case libre la plus proche de `p` (recherche en anneaux).
func _nearest_free_cell(p: Vector2) -> Vector2i:
	var start := _to_cell(p)
	if not _grid.is_point_solid(start):
		return start
	for radius in range(1, 40):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var c := start + Vector2i(x, y)
				if not _grid.is_in_boundsv(c) or _grid.is_point_solid(c):
					continue
				var d := _cell_center(c).distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = c
		if best.x >= 0:
			return best
	return _to_cell(_cat.position)


## Case libre à portée de l'objet, la plus proche du chat.
func _reach_cell(obj: Dictionary) -> Vector2i:
	var rect := _object_rect(obj)
	var best := Vector2i(-1, -1)
	var best_d := INF
	var area := Rect2i(_to_cell(rect.position - Vector2(REACH, REACH)), Vector2i.ZERO) \
		.expand(_to_cell(rect.end + Vector2(REACH, REACH)))
	for y in range(area.position.y, area.end.y + 1):
		for x in range(area.position.x, area.end.x + 1):
			var c := Vector2i(x, y)
			if not _grid.is_in_boundsv(c) or _grid.is_point_solid(c):
				continue
			var center := _cell_center(c)
			if _rect_distance(rect, center) > REACH - 4.0:
				continue
			var d := center.distance_squared_to(_cat.position)
			if d < best_d:
				best_d = d
				best = c
	return best


# --- Entrées -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Manette (Xbox) : A = interagir, Start = retour au menu.
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_using_pad = true
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				if not _near.is_empty():
					_launch(_near)
			JOY_BUTTON_START:
				GameManager.back_to_title()
		return
	if event is InputEventKey or event is InputEventMouseButton:
		_using_pad = false
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE:
				GameManager.back_to_title()
			KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				if not _near.is_empty():
					_launch(_near)
		return
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return

	var p: Vector2 = make_input_local(event).position
	if QUIT_RECT.has_point(p):
		GameManager.back_to_title()
		return
	var obj := _object_at(p)
	if not obj.is_empty():
		if _near == obj:
			_launch(obj)
		else:
			_walk_to_cell(_reach_cell(obj), obj)
		return
	if p.y > HEADER_H:
		_walk_to_cell(_nearest_free_cell(p), {})


func _walk_to_cell(target: Vector2i, obj: Dictionary) -> void:
	if target.x < 0:
		return
	var from := _nearest_free_cell(_cat.position)
	var path := _grid.get_point_path(from, target)
	if path.is_empty():
		return
	_path = path
	_pending = obj


func _launch(obj: Dictionary) -> void:
	GameManager.launch_mini_game(obj.scene, _cat.position, _cat.rotation)


# --- Boucle -------------------------------------------------------------------------

func _process(delta: float) -> void:
	var dir := _keyboard_direction()
	if dir == Vector2.ZERO:
		dir = _pad_direction()
	if dir != Vector2.ZERO:
		_path.clear()
		_pending = {}
		_cat.walk(_slide(dir * Chat.SPEED * delta), delta)
	elif not _path.is_empty():
		_follow_path(delta)
	else:
		_cat.idle(delta)

	_update_near()
	if not _pending.is_empty() and _near == _pending and _path.is_empty():
		_launch(_pending)
		return
	_update_hover()
	_update_highlights()


func _keyboard_direction() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1
	return d.normalized()


## Stick gauche (analogique : le chat va plus ou moins vite) ou croix directionnelle, sur toutes les manettes.
func _pad_direction() -> Vector2:
	for pad in Input.get_connected_joypads():
		var stick := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		if stick.length() > PAD_DEADZONE:
			# Remet l'échelle à 0 au bord de la zone morte pour un démarrage en douceur.
			return stick.normalized() * clampf((stick.length() - PAD_DEADZONE) / (1.0 - PAD_DEADZONE), 0.0, 1.0)
		var d := Vector2(
			int(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT)) - int(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT)),
			int(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN)) - int(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP)))
		if d != Vector2.ZERO:
			return d.normalized()
	return Vector2.ZERO


## Déplacement qui glisse le long des meubles au lieu de bloquer net.
func _slide(motion: Vector2) -> Vector2:
	var p := _cat.position
	for m in [motion, Vector2(motion.x, 0), Vector2(0, motion.y)]:
		if m != Vector2.ZERO and _can_stand(p + m, m.normalized()):
			return m
	return Vector2.ZERO


## Le torse doit être libre, et la tête (devant, dans le sens de la marche) ne doit pas entrer dans un meuble.
func _can_stand(p: Vector2, facing: Vector2) -> bool:
	if not _is_walkable(p):
		return false
	var head := p + facing * HEAD_OFFSET
	for r in OBSTACLES:
		if _rect_distance(r, head) < HEAD_RADIUS:
			return false
	return true


func _follow_path(delta: float) -> void:
	var step := Chat.SPEED * delta
	var motion := Vector2.ZERO
	while not _path.is_empty() and step > 0.0:
		var to_next := _path[0] - (_cat.position + motion)
		if to_next.length() <= step:
			motion += to_next
			step -= to_next.length()
			_path.remove_at(0)
		else:
			motion += to_next.normalized() * step
			step = 0.0
	_cat.walk(motion, delta)


func _update_near() -> void:
	_near = {}
	var best := REACH
	for obj in INTERACTABLES:
		var d := _rect_distance(_object_rect(obj), _cat.position)
		if d <= best:
			best = d
			_near = obj


func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	_hovered = _object_at(mouse)
	_quit_hovered = QUIT_RECT.has_point(mouse)

	_tooltip.visible = not _hovered.is_empty() or _quit_hovered
	if _tooltip.visible:
		if _quit_hovered:
			_tooltip_label.text = "Retour au menu"
		elif _hovered == _near:
			_tooltip_label.text = "%s  ·  clic" % _hovered.label
		else:
			_tooltip_label.text = "%s  ·  clic pour y aller" % _hovered.label
		_tooltip.reset_size()
		var pos := mouse + Vector2(18, 18)
		pos.x = minf(pos.x, SCREEN.x - _tooltip.size.x - 8)
		pos.y = minf(pos.y, SCREEN.y - _tooltip.size.y - 8)
		_tooltip.position = pos

	# Bulle « E : … » au-dessus de l'objet à portée (cachée si la souris le survole déjà).
	_prompt.visible = not _near.is_empty() and _hovered != _near
	if _prompt.visible:
		_prompt_label.text = "%s : %s" % ["A" if _using_pad else "E", _near.label]
		_prompt.reset_size()
		var rect := _object_rect(_near)
		var pos := Vector2(rect.get_center().x - _prompt.size.x * 0.5, rect.position.y - _prompt.size.y - 8)
		if pos.y < HEADER_H + 4:
			pos.y = rect.end.y + 8
		pos.x = clampf(pos.x, 8, SCREEN.x - _prompt.size.x - 8)
		_prompt.position = pos


func _update_highlights() -> void:
	_highlight_mat.set_shader_parameter("amount", 0.12 + 0.16 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)))
	for obj in INTERACTABLES:
		var lit: bool = obj == _near or obj == _hovered
		for layer_name in obj.layers:
			var t: TextureRect = _layers[layer_name]
			t.material = _highlight_mat if lit else null
	var quit: TextureRect = _layers["bouton_quitter"]
	quit.material = _highlight_mat if _quit_hovered else null
