extends Control
## Oopsie Pawsie — l'eau (cartoon) du mini-jeu de l'aquarium, pendant du sang de la souris.
## Ce nœud dessine les flaques sur le parquet ; `air` dessine les gouttes en vol (au-dessus de
## l'aquarium) et `surface` les ronds dans l'eau (à mettre dans l'eau, au-dessus des poissons).
## Les gouttes volent, ralentissent puis retombent : dans l'eau elles font un rond,
## sur le parquet elles laissent une flaque qui sèche peu à peu.

const Sang := preload("res://scripts/mini_games/souris_sang.gd")

const COL_DROP := Color(0.78, 0.92, 1.0, 0.95)
const COL_DROP_EDGE := Color(0.33, 0.62, 0.72, 0.95)
## Le bois mouillé fonce : une flaque se voit comme une tache plus sombre du parquet.
const COL_PUDDLE := Color(0.42, 0.24, 0.1, 0.33)
const COL_RIPPLE := Color(1, 1, 1, 0.8)
const DRAG := 0.04
const LAND_SPEED := 70.0
## Durée de vie d'une flaque sur le parquet (elle s'estompe progressivement).
const PUDDLE_LIFE := 9.0
const MAX_PUDDLES := 400

var air: Control
var surface: Control

## Rectangle de l'eau, en coordonnées écran.
var _water_rect := Rect2()
var _drops: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []   # {p (coord. de l'eau), t, life, r}
var _puddles: Array[Dictionary] = []   # {pts, age}
var _redraw_floor := 0.0


func setup(screen: Vector2, water: Control) -> void:
	_water_rect = Rect2(water.position, water.size)
	size = screen
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	air = Control.new()
	air.size = screen
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	air.draw.connect(_draw_air)
	surface = Control.new()
	surface.size = water.size
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.draw.connect(_draw_surface)


## Gerbe d'eau à `at` (coordonnées écran). power ≈ 1 pour un plouf, 3+ pour la grosse prise.
func splash(at: Vector2, power: float) -> void:
	ripple(at, 70.0 * sqrt(power), 0.0)
	ripple(at, 45.0 * sqrt(power), 0.12)
	ripple(at, 25.0 * sqrt(power), 0.24)
	for i in int(26 * power):
		var angle := randf() * TAU
		_drops.append({
			"p": at + Vector2.from_angle(angle) * randf_range(0.0, 10.0),
			"v": Vector2.from_angle(angle) * randf_range(150.0, 720.0) * (0.8 + 0.2 * power),
			"r": randf_range(2.5, 6.5) * (1.7 if randf() < 0.15 else 1.0),
		})


## Rond qui s'élargit à la surface de l'eau (ignoré hors de l'eau).
func ripple(at: Vector2, radius: float, delay: float) -> void:
	if not _water_rect.has_point(at):
		return
	_ripples.append({"p": at - _water_rect.position, "t": -delay, "life": 0.7 + radius / 120.0, "r": radius})


## Traînée de gouttes laissée par un poisson qui vole (coordonnées écran).
func dribble(at: Vector2) -> void:
	_drops.append({"p": at, "v": Vector2.from_angle(randf() * TAU) * randf_range(30.0, 120.0), "r": randf_range(2.0, 4.0)})


## Éclaboussures « sur la caméra » : grosses gouttes d'eau sur l'écran qui coulent puis sèchent.
static func screen_splats(parent: Node, count: int, screen: Vector2) -> void:
	for i in count:
		var root := Node2D.new()
		root.position = Vector2(randf_range(60, screen.x - 60), randf_range(60, screen.y - 60))
		parent.add_child(root)
		var r := randf_range(35.0, 90.0)
		var body := Polygon2D.new()
		body.polygon = Sang.blob(Vector2.ZERO, r, Vector2.ZERO, 1.0, 0.05)
		body.color = Color(0.72, 0.9, 1.0, 0.38)
		root.add_child(body)
		var rim := Line2D.new()
		rim.points = body.polygon
		rim.closed = true
		rim.width = 3.0
		rim.default_color = Color(0.35, 0.65, 0.8, 0.5)
		root.add_child(rim)
		# Reflet, comme sur une vraie goutte.
		var shine := Polygon2D.new()
		shine.polygon = Sang.blob(Vector2(-r * 0.35, -r * 0.35), r * 0.22, Vector2.ZERO, 1.0, 0.0)
		shine.color = Color(1, 1, 1, 0.75)
		root.add_child(shine)
		for j in randi_range(3, 6):
			var drop := Polygon2D.new()
			drop.polygon = Sang.blob(Vector2.from_angle(randf() * TAU) * r * randf_range(1.15, 1.7), randf_range(4.0, 9.0), Vector2.ZERO, 1.0, 0.0)
			drop.color = body.color
			root.add_child(drop)
		root.scale = Vector2.ONE * 0.3
		var tw := root.create_tween()
		tw.tween_property(root, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(randf_range(0.6, 1.2))
		tw.tween_property(root, "position:y", root.position.y + randf_range(40, 90), 1.4)
		tw.parallel().tween_property(root, "modulate:a", 0.0, 1.4)
		tw.tween_callback(root.queue_free)


func _process(delta: float) -> void:
	var keep := 1.0 - pow(DRAG, delta)
	for i in range(_drops.size() - 1, -1, -1):
		var d := _drops[i]
		var v: Vector2 = d.v
		var p: Vector2 = d.p + v * delta
		d.p = p
		d.v = v.lerp(Vector2.ZERO, keep)
		if (d.v as Vector2).length() < LAND_SPEED:
			_land(p, d.r, v)
			_drops.remove_at(i)

	for i in range(_ripples.size() - 1, -1, -1):
		_ripples[i].t += delta
		if _ripples[i].t > _ripples[i].life:
			_ripples.remove_at(i)

	for i in range(_puddles.size() - 1, -1, -1):
		_puddles[i].age += delta
		if _puddles[i].age > PUDDLE_LIFE:
			_puddles.remove_at(i)
	# Les flaques s'estompent lentement : pas besoin de les redessiner à chaque image.
	_redraw_floor -= delta
	if _redraw_floor <= 0.0:
		_redraw_floor = 0.1
		queue_redraw()

	air.queue_redraw()
	surface.queue_redraw()


func _land(p: Vector2, r: float, v: Vector2) -> void:
	if _water_rect.has_point(p):
		ripple(p, r * 3.0, 0.0)
		return
	_puddles.append({"pts": Sang.blob(p, r * 1.8, v, clampf(1.0 + v.length() / 300.0, 1.0, 2.0), 0.0), "age": 0.0})
	if _puddles.size() > MAX_PUDDLES:
		_puddles.pop_front()
	_redraw_floor = 0.0


func _draw() -> void:
	for pd in _puddles:
		var fade := 1.0 - clampf((pd.age - PUDDLE_LIFE * 0.5) / (PUDDLE_LIFE * 0.5), 0.0, 1.0)
		draw_colored_polygon(pd.pts, Color(COL_PUDDLE, COL_PUDDLE.a * fade))


func _draw_air() -> void:
	for d in _drops:
		var p: Vector2 = d.p
		var v: Vector2 = d.v
		var r: float = d.r
		air.draw_line(p - v * 0.02, p, COL_DROP_EDGE, r * 1.4)
		air.draw_circle(p, r + 1.0, COL_DROP_EDGE)
		air.draw_circle(p, r, COL_DROP)
		air.draw_circle(p + Vector2(-r, -r) * 0.35, r * 0.3, Color.WHITE)


func _draw_surface() -> void:
	for rp in _ripples:
		var t: float = rp.t
		if t < 0.0:
			continue
		var k: float = t / rp.life
		var radius: float = rp.r * (0.15 + 0.85 * sqrt(k))
		surface.draw_arc(rp.p, radius, 0.0, TAU, 40, Color(COL_RIPPLE, COL_RIPPLE.a * (1.0 - k)), 3.0 * (1.0 - k) + 1.0, true)
