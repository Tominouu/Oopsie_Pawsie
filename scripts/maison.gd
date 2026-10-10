extends Node2D
## Oopsie Pawsie — la maison (maquette Figma « MAP - Nuit »), hub du jeu.
## Le chat se déplace au clavier (ZQSD / WASD / flèches), à la manette (stick gauche / croix)
## ou en cliquant au sol. Les objets interactifs s'éclairent au survol ou quand le chat est à côté :
## clic dessus (le chat y va tout seul), E / Espace / Entrée ou A à la manette pour lancer le mini-jeu.
## En poussant contre le lit, le chat saute dedans et se glisse sous la couette : on ne voit plus
## que la bosse qu'il fait dans le tissu, qu'on déplace pareil. Pousser contre un bord = ressortir.

const Chat := preload("res://scripts/maison_chat.gd")
const Traces := preload("res://scripts/maison_traces.gd")
const Ciel := preload("res://scripts/ciel.gd")
const EcranFin := preload("res://scripts/ecran_fin.gd")
const Pipi := preload("res://scripts/maison_pipi.gd")
const MEOW := preload("res://assets/sounds/meow1.mp3")
const Noir := preload("res://scripts/maison_noir.gd")
const Torche := preload("res://scripts/maison_torche.gd")

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

## Objets qui lancent un mini-jeu (une « mission ») : nom du résultat (GameManager), calques, scène, texte.
const INTERACTABLES := [
	{"id": "aquarium", "layers": ["aquarium"], "scene": "res://scenes/mini_games/scene_aquarium.tscn", "label": "Catch the pink fish"},
	{"id": "souris", "layers": ["souris"], "scene": "res://scenes/mini_games/souris.tscn", "label": "Hunt the mouse"},
	{"id": "croquettes", "layers": ["placard_gauche", "placard_droit"], "scene": "res://scenes/mini_games/croquettes.tscn", "label": "Search the cupboards"},
	{"id": "canape", "layers": ["canape"], "scene": "res://scenes/mini_games/rythme.tscn", "label": "Scratch the sofa"},
	{"id": "cable", "layers": ["meuble_tv"], "scene": "res://scenes/mini_games/cable.tscn", "label": "Unplug the TV"},
]

## Le lit : en poussant dedans (ou E / A à côté), le chat saute et se glisse sous la couette.
const BED_RECT := Rect2(997, 130, 278, 214)
## Partie du lit couverte par la couette (relevée sur lit.png) : le chat s'y balade dessous.
const DUVET_RECT := Rect2(1011, 132, 158, 195)
## Marge (torse ↔ bord de la couette) que le chat garde quand il est dessous.
const DUVET_MARGIN := 18.0
## Sous la couette, le chat avance moins vite.
const BED_SPEED := 0.55
## Temps à pousser contre le lit (ou contre le bord de la couette) avant de sauter.
const PUSH_TIME := 0.25
const JUMP_TIME := 0.4
## Grossissement du chat en haut du saut (vu de dessus, il se rapproche de la caméra).
const JUMP_LIFT := 0.35
## Le chat ne saute hors du lit que vers un endroit libre assez proche, dans le sens poussé.
const JUMP_OUT_MAX := 170.0
## Pipi au lit : temps pour que la vessie se remplisse avant le suivant.
const PEE_REFILL := 6.0
## Distance torse ↔ arrière-train (là où la tache apparaît).
const PEE_BACK := 20.0
## Lampe torche posée sur le canapé (à avaler pour y voir clair).
const TORCH_POS := Vector2(812, 398)
const TORCH_ROT := -0.35
## Temps d'allumage du faisceau une fois la torche avalée.
const TORCH_ON_TIME := 0.8

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
	BED_RECT,                      # lit
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
## Volume de la musique d'ambiance (dB) : assez bas pour laisser passer les bruitages.
const MUSIC_DB := -12.0
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

## Sous la couette, le chat est enfant de ce masque : son ombre ne déborde pas du tissu.
var _duvet_clip: Polygon2D
var _in_bed := false
var _jumping := false
var _push := 0.0
var _near_bed := false
var _bed_hovered := false
## Point visé sous la couette après un clic (INF = aucun).
var _bed_target := Vector2.INF
## Point de la couette cliqué depuis le sol : le chat y saute en arrivant au lit.
var _bed_pending := Vector2.INF
## Taches de pipi dans le lit (enfant du masque de la couette, sous le chat).
var _pipi: Pipi
var _pee_cooldown := 0.0
var _pee_rot := 0.0
var _was_peeing := false

## Obscurité de la nuit, et la torche (null une fois avalée). _torch_power : 0 → 1, le faisceau.
var _dark: Noir
var _torch: Torche
var _torch_power := 0.0
var _traces_glow: Node

var _prompt: PanelContainer
var _prompt_label: Label
var _tooltip: PanelContainer
var _tooltip_label: Label
var _ui_layer: CanvasLayer
## Écran de fin de nuit (victoire ou « trop tard ») une fois affiché.
var _end_screen: CanvasLayer
var _missions_label: Label
var _missions_pill: Panel


func _ready() -> void:
	# Musique d'ambiance de la maison (reprend là où elle s'était arrêtée).
	Sons.play_music("maison_calme", MUSIC_DB)
	var shader := Shader.new()
	shader.code = HIGHLIGHT_SHADER
	_highlight_mat.shader = shader
	_build_map()
	_build_grid()
	_build_cat()
	_build_ui()


func _exit_tree() -> void:
	# La musique s'arrête en fondu quand on part dans un mini-jeu ou au menu.
	Sons.stop_music()


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

	# La lampe torche sur le canapé, tant que le chat ne l'a pas avalée.
	if GameManager.has_torch:
		_torch_power = 1.0
	else:
		_torch = Torche.new()
		_torch.position = TORCH_POS
		_torch.rotation = TORCH_ROT
		add_child(_torch)

	# Traces laissées par les mini-jeux déjà joués (sang, croquettes, télé qui grésille…).
	var traces := Traces.new()
	add_child(traces)
	traces.setup(GameManager.results, _layers)

	# Voile bleu de la nuit (sous le bandeau et le chat, comme dans la maquette).
	var night := ColorRect.new()
	night.color = NIGHT_TINT
	night.size = SCREEN
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)
	# Ce qui brille (étincelles de la télé) passe au-dessus du voile de nuit… et de l'obscurité (voir _build_cat).
	_traces_glow = traces.glow
	add_child(_traces_glow)

	_add_texture(load(DIR + "header.svg"), Vector2.ZERO)
	# Le dôme nuit → jour qui montre le temps qui reste (voir ciel.gd).
	add_child(Ciel.new())
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

	# Compteur des missions réussies cette nuit (maquette : pastille « 0/5 » en haut à gauche).
	var pill := Panel.new()
	_missions_pill = pill
	pill.position = Vector2(48, 22)
	pill.size = Vector2(132, 69)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = COL_CREAM
	pill_style.set_corner_radius_all(35)
	pill.add_theme_stylebox_override("panel", pill_style)
	add_child(pill)
	_missions_label = Label.new()
	_missions_label.text = "%d/%d" % [GameManager.missions_done(), GameManager.MISSIONS_TOTAL]
	_missions_label.add_theme_font_override("font", FONT)
	_missions_label.add_theme_font_size_override("font_size", 43)
	_missions_label.add_theme_color_override("font_color", COL_DARK)
	_missions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_missions_label.position = Vector2(48, 30.64)
	_missions_label.size = Vector2(132, 52)
	_missions_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_missions_label)


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
	_duvet_clip = Polygon2D.new()
	var r := DUVET_RECT
	_duvet_clip.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	_duvet_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(_duvet_clip)
	_pipi = Pipi.new()
	_duvet_clip.add_child(_pipi)

	_cat = Chat.new()
	var saved: Vector2 = GameManager.cat_position
	if saved.is_finite() and _is_walkable(saved):
		_cat.position = saved
		_cat.rotation = GameManager.cat_rotation
	else:
		_cat.position = CAT_START
	add_child(_cat)

	# Le noir de la nuit recouvre la maison et le chat (pas le bandeau du haut).
	_dark = Noir.new(Rect2(0, HEADER_H, SCREEN.x, SCREEN.y - HEADER_H))
	add_child(_dark)
	# Restent visibles dans le noir : les étincelles de la télé et le bouton quitter.
	move_child(_traces_glow, -1)
	move_child(_layers["bouton_quitter"], -1)
	_refresh_dark(0.0)
	if not GameManager.has_torch:
		_hint_torch.call_deferred()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	_ui_layer = layer
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
	# Écran de fin de nuit affiché : il gère lui-même ses touches ; Échap ramène quand même au menu.
	if _end_screen != null:
		if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
			GameManager.back_to_title()
		return
	# Pendant le pipi, on ne bouge pas (on finit ce qu'on a commencé).
	if _pipi.is_peeing():
		return
	# Manette (Xbox) : A = interagir, X = pipi (dans le lit), Start = retour au menu.
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_using_pad = true
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				_interact()
			JOY_BUTTON_X:
				_try_pee()
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
				_interact()
			KEY_P:
				_try_pee()
		return
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return

	var p: Vector2 = make_input_local(event).position
	if QUIT_RECT.has_point(p):
		GameManager.back_to_title()
		return
	if _jumping:
		return
	var obj := _object_at(p)
	if _in_bed:
		_click_from_bed(p, obj)
		return
	if not obj.is_empty():
		if _near == obj:
			_launch(obj)
		else:
			_walk_to_cell(_reach_cell(obj), obj)
		return
	if DUVET_RECT.has_point(p):
		if _near_bed:
			_jump_in(p)
		else:
			_walk_to_cell(_nearest_free_cell(p), {})
			_bed_pending = p
		return
	if p.y > HEADER_H:
		_walk_to_cell(_nearest_free_cell(p), {})


## Sous la couette : clic dessus = s'y déplacer, clic ailleurs = sauter hors du lit puis y aller.
func _click_from_bed(p: Vector2, obj: Dictionary) -> void:
	if DUVET_RECT.has_point(p):
		var inner := _duvet_inner()
		_bed_target = p.clamp(inner.position, inner.end)
		return
	if p.y <= HEADER_H and obj.is_empty():
		return
	var out := _exit_toward((p - _cat.position).normalized())
	if not out.is_finite():
		out = _cell_center(_nearest_free_cell(_cat.position))
	_jump(out, false, func() -> void:
		if obj.is_empty():
			_walk_to_cell(_nearest_free_cell(p), {})
		else:
			_walk_to_cell(_reach_cell(obj), obj))


func _interact() -> void:
	if _jumping:
		return
	if _in_bed:
		_jump(_cell_center(_nearest_free_cell(_cat.position)), false)
	elif not _near.is_empty():
		_launch(_near)
	elif _near_bed:
		_jump_in(_cat.position)


## Sous la couette : le chat se soulage dans le lit du maître (une tache qui reste toute la nuit).
func _try_pee() -> void:
	if not _in_bed or _jumping or _pipi.is_peeing():
		return
	if _pee_cooldown > 0.0:
		_pop_message("Empty bladder… come back in %d s" % ceili(_pee_cooldown), BED_RECT)
		return
	_bed_target = Vector2.INF
	_push = 0.0
	_pee_rot = _cat.rotation
	var rear := _cat.position - Vector2.UP.rotated(_cat.rotation) * PEE_BACK
	_pipi.pee(rear.clamp(DUVET_RECT.position, DUVET_RECT.end))
	_was_peeing = true


## Fin du pipi : soupir de soulagement.
func _pee_done() -> void:
	_was_peeing = false
	_pee_cooldown = PEE_REFILL
	_cat.rotation = _pee_rot
	_pop_message("Ahhh… much better!", BED_RECT, false)
	var meow := AudioStreamPlayer.new()
	meow.stream = MEOW
	meow.pitch_scale = 1.25
	meow.volume_db = -4.0
	meow.finished.connect(meow.queue_free)
	add_child(meow)
	meow.play()


func _walk_to_cell(target: Vector2i, obj: Dictionary) -> void:
	_bed_pending = Vector2.INF
	if target.x < 0:
		return
	var from := _nearest_free_cell(_cat.position)
	var path := _grid.get_point_path(from, target)
	if path.is_empty():
		return
	_path = path
	_pending = obj


func _launch(obj: Dictionary) -> void:
	# Sur le canapé, il y a d'abord la lampe torche à avaler.
	if obj.id == "canape" and _torch != null:
		_pending = {}
		_eat_torch()
		return
	# Une mission réussie ne se refait pas : la nuit est comptée.
	if GameManager.is_mission_done(obj.id):
		_pending = {}
		_pop_message("Mission already done!", _object_rect(obj))
		return
	Sons.play("lancer_jeu")
	GameManager.launch_mini_game(obj.scene, _cat.position, _cat.rotation)


## Le chat avale la lampe torche : un faisceau sort de sa tête pour le reste de la nuit.
func _eat_torch() -> void:
	if _torch == null or not _torch.is_processing():
		return
	GameManager.has_torch = true
	var mouth := _cat.position + Vector2.UP.rotated(_cat.rotation) * HEAD_OFFSET
	_torch.swallow(mouth, func() -> void:
		Sons.play("conserve", 2.0, 0.8)
		Sons.play("chips")
		_torch = null
		_pop_message("GULP! Now I can see!", Rect2(_cat.position - Vector2(0, 40), Vector2.ZERO), false, 1.6)
		# Le faisceau s'allume en clignotant, comme une vraie lampe.
		var tw := create_tween()
		for v in [0.6, 0.0, 0.8, 0.2]:
			tw.tween_property(self, "_torch_power", v, TORCH_ON_TIME / 8.0)
		tw.tween_property(self, "_torch_power", 1.0, TORCH_ON_TIME / 2.0))


## Premier passage dans le noir : on explique quoi faire.
func _hint_torch() -> void:
	var text := "It's pitch dark… find the flashlight on the sofa!" if GameManager.is_mission_done("cable") \
		else "It's pitch dark… the TV is on, check the sofa!"
	_pop_message(text,Rect2(_cat.position - Vector2(0, 40), Vector2.ZERO), false, 3.5)


func _refresh_dark(delta: float) -> void:
	var item := Vector2.INF if _torch == null else _torch.global_position
	_dark.refresh(delta, _cat.position, Vector2.UP.rotated(_cat.rotation), _torch_power, item)


## Petit message qui monte au-dessus d'un objet puis disparaît.
func _pop_message(text: String, rect: Rect2, refused := true, duration := 0.9) -> void:
	if refused:
		Sons.play("note_ratee")
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", COL_CREAM)
	l.add_theme_color_override("font_outline_color", COL_DARK)
	l.add_theme_constant_override("outline_size", 8)
	l.size = Vector2(700, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(clampf(rect.get_center().x - 350.0, 8.0, SCREEN.x - 708.0), maxf(rect.position.y - 46.0, HEADER_H + 4.0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 30.0, duration)
	tw.parallel().tween_property(l, "modulate:a", 0.0, minf(0.5, duration)).set_delay(duration - minf(0.5, duration))
	tw.tween_callback(l.queue_free)


## Texte d'un objet : sa mission, ou « Mission accomplie » si elle est faite.
func _label_of(obj: Dictionary) -> String:
	if obj.id == "canape" and _torch != null:
		return "Eat the flashlight"
	return "Mission complete!" if GameManager.is_mission_done(obj.id) else obj.label


## Fin de la nuit : les 5 missions faites (victoire) ou le jour levé (défaite).
func _check_night_end() -> void:
	if _end_screen != null:
		return
	match GameManager.night_state:
		GameManager.NightState.WON:
			_end_screen = EcranFin.victoire()
			Sons.play("victoire")
		GameManager.NightState.LATE:
			_end_screen = EcranFin.trop_tard()
			Sons.play("defaite")
		_:
			return
	_path.clear()
	_pending = {}
	_prompt.visible = false
	_tooltip.visible = false
	# Comme dans la maquette : plus de compteur sur les écrans de fin de nuit.
	_missions_pill.visible = false
	_missions_label.visible = false
	add_child(_end_screen)


# --- Boucle -------------------------------------------------------------------------

func _process(delta: float) -> void:
	_refresh_dark(delta)
	_check_night_end()
	if _end_screen != null:
		_cat.idle(delta)
		return
	_pee_cooldown = maxf(_pee_cooldown - delta, 0.0)
	if _pipi.is_peeing():
		# Le chat frissonne sur place pendant que ça coule.
		_cat.idle(delta)
		_cat.rotation = _pee_rot + sin(Time.get_ticks_msec() * 0.045) * 0.06
	elif _was_peeing:
		_pee_done()
	elif _jumping:
		pass
	elif _in_bed:
		_process_bed(delta)
	elif _process_floor(delta):
		return
	_update_hover()
	_update_highlights()


## Renvoie vrai si un mini-jeu vient d'être lancé.
func _process_floor(delta: float) -> bool:
	var dir := _input_direction()
	if dir != Vector2.ZERO:
		_path.clear()
		_pending = {}
		_bed_pending = Vector2.INF
		_cat.walk(_slide(dir * Chat.SPEED * delta), delta)
		_push = _push + delta if _pushing_bed(dir) else 0.0
		if _push >= PUSH_TIME:
			_jump_in(_cat.position + dir * 90.0)
			return false
	elif not _path.is_empty():
		_push = 0.0
		_follow_path(delta)
	else:
		_push = 0.0
		_cat.idle(delta)

	_update_near()
	if not _pending.is_empty() and _near == _pending and _path.is_empty():
		_launch(_pending)
		return true
	if _bed_pending.is_finite() and _path.is_empty():
		var aim := _bed_pending
		_bed_pending = Vector2.INF
		if _near_bed:
			_jump_in(aim)
	return false


## Sous la couette : on se déplace dans les limites du tissu ; pousser contre un bord fait ressortir.
func _process_bed(delta: float) -> void:
	var inner := _duvet_inner()
	var dir := _input_direction()
	var step := Chat.SPEED * BED_SPEED * delta
	if dir != Vector2.ZERO:
		_bed_target = Vector2.INF
	elif _bed_target.is_finite():
		var to_target := _bed_target - _cat.position
		if to_target.length() < 1.0:
			_bed_target = Vector2.INF
		else:
			dir = to_target.normalized()
			step = minf(step, to_target.length())
	if dir == Vector2.ZERO:
		_push = 0.0
		_cat.idle(delta)
		return

	var next := _cat.position + dir * step
	var held := next.clamp(inner.position, inner.end)
	if held.distance_to(next) > 0.01 and not _bed_target.is_finite():
		_push += delta
		if _push >= PUSH_TIME:
			var out := _exit_toward(dir)
			if out.is_finite():
				_jump(out, false)
				return
	else:
		_push = 0.0
	_cat.walk(held - _cat.position, delta)


func _input_direction() -> Vector2:
	var dir := _keyboard_direction()
	return dir if dir != Vector2.ZERO else _pad_direction()


func _duvet_inner() -> Rect2:
	return DUVET_RECT.grow(-DUVET_MARGIN)


## Vrai si le chat est collé au lit et avance vers lui.
func _pushing_bed(dir: Vector2) -> bool:
	var to_bed := _cat.position.clamp(BED_RECT.position, BED_RECT.end) - _cat.position
	if to_bed.length() < 0.01 or to_bed.length() > HEAD_OFFSET + HEAD_RADIUS + 8.0:
		return false
	return dir.dot(to_bed.normalized()) > 0.6


## Endroit libre où atterrir en sautant du lit dans la direction `dir` (INF si rien de proche dans ce sens).
func _exit_toward(dir: Vector2) -> Vector2:
	var p := _cell_center(_nearest_free_cell(_cat.position + dir * 120.0))
	var jump := p - _cat.position
	if jump.length() > JUMP_OUT_MAX or jump.normalized().dot(dir) < 0.3:
		return Vector2.INF
	return p


func _jump_in(aim: Vector2) -> void:
	var inner := _duvet_inner()
	_jump(aim.clamp(inner.position, inner.end), true)


## Saut en arc (le chat grossit en l'air). En entrant, il se glisse sous la couette à
## l'atterrissage ; en sortant, il ressort de dessous avant de sauter.
func _jump(to: Vector2, into_bed: bool, on_land := Callable()) -> void:
	Sons.play("froissement")
	_jumping = true
	_in_bed = false
	_push = 0.0
	_path.clear()
	_pending = {}
	_near = {}
	_near_bed = false
	_bed_pending = Vector2.INF
	_bed_target = Vector2.INF

	var tween := create_tween()
	if not into_bed:
		tween.tween_method(_cat.set_under, 1.0, 0.0, 0.15)
		tween.tween_callback(func() -> void: _cat.reparent(self))
	var from := _cat.position
	var facing := (to - from).angle() + PI * 0.5
	var hop := func(t: float) -> void:
		_cat.position = from.lerp(to, t)
		_cat.rotation = lerp_angle(_cat.rotation, facing, 0.3)
		_cat.scale = Vector2.ONE * Chat.TEXTURE_SCALE * _cat.bulk * (1.0 + JUMP_LIFT * sin(t * PI))
	tween.tween_method(hop, 0.0, 1.0, JUMP_TIME)
	if into_bed:
		tween.tween_callback(func() -> void: _cat.reparent(_duvet_clip))
		tween.tween_method(_cat.set_under, 0.0, 1.0, 0.25)
	tween.tween_callback(func() -> void:
		_jumping = false
		_in_bed = into_bed
		if on_land.is_valid():
			on_land.call())


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
	_near_bed = _near.is_empty() and _rect_distance(BED_RECT, _cat.position) <= REACH


func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	var was_hovered := _hovered
	_hovered = _object_at(mouse)
	if _hovered != was_hovered and not _hovered.is_empty():
		Sons.play("survol")
	_quit_hovered = QUIT_RECT.has_point(mouse)
	_bed_hovered = not _in_bed and not _jumping and _hovered.is_empty() and DUVET_RECT.has_point(mouse)

	_tooltip.visible = not _hovered.is_empty() or _quit_hovered or _bed_hovered
	if _tooltip.visible:
		if _quit_hovered:
			_tooltip_label.text = "Back to menu"
		elif _bed_hovered:
			_tooltip_label.text = "Slip under the duvet  ·  %s" % ("click" if _near_bed else "click to go there")
		elif _hovered == _near:
			_tooltip_label.text = "%s  ·  click" % _label_of(_hovered)
		else:
			_tooltip_label.text = "%s  ·  click to go there" % _label_of(_hovered)
		_tooltip.reset_size()
		var pos := mouse + Vector2(18, 18)
		pos.x = minf(pos.x, SCREEN.x - _tooltip.size.x - 8)
		pos.y = minf(pos.y, SCREEN.y - _tooltip.size.y - 8)
		_tooltip.position = pos

	# Bulle « E : … » au-dessus de l'objet à portée (cachée si la souris le survole déjà).
	var text := ""
	var rect := Rect2()
	if _in_bed:
		text = "Get out of bed"
		rect = BED_RECT
	elif not _near.is_empty() and _hovered != _near:
		text = _label_of(_near)
		rect = _object_rect(_near)
	elif _near_bed and not _bed_hovered:
		text = "Slip under the duvet"
		rect = BED_RECT
	_prompt.visible = text != "" and not _jumping and not _pipi.is_peeing()
	if _prompt.visible:
		_prompt_label.text = "%s: %s" % ["A" if _using_pad else "E", text]
		if _in_bed:
			_prompt_label.text += "   ·   %s: Pee" % ("X" if _using_pad else "P")
		_prompt.reset_size()
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
	var bed: TextureRect = _layers["lit"]
	bed.material = _highlight_mat if (_near_bed or _bed_hovered) and not _in_bed and not _jumping else null
