extends Control
## Oopsie Pawsie — le carnage alimentaire (cartoon) du mini-jeu des croquettes,
## pendant du sang de la souris et de l'eau de l'aquarium.
## Chaque produit dégagé répand son contenu : les morceaux volent, retombent (l'étagère
## est vue de face, il y a donc de la gravité), rebondissent et s'entassent.
## Ce nœud dessine les morceaux posés ; `air` dessine ceux en vol et les nuages de farine.

const Sang := preload("res://scripts/mini_games/souris_sang.gd")

enum Shape { ROUND, SQUARE, TRIANGLE, STICK }

## Contenu de chaque produit (index = ordre de PRODUCTS dans croquettes.gd), puis le sachet de croquettes.
const CONTENTS := {
	"cereales": {"shape": Shape.SQUARE, "size": Vector2(5, 8), "colors": [Color("e0a040"), Color("c07828"), Color("f0c060")]},
	"chips": {"shape": Shape.TRIANGLE, "size": Vector2(7, 11), "colors": [Color("f8d25a"), Color("f2bf3a"), Color("fde59a")]},
	"mais": {"shape": Shape.ROUND, "size": Vector2(3, 4.5), "colors": [Color("f8d830"), Color("f0c020")]},
	"pois": {"shape": Shape.ROUND, "size": Vector2(3.5, 5), "colors": [Color("6cbf3a"), Color("4e9e2a"), Color("8ad65a")]},
	"farine": {"shape": Shape.ROUND, "size": Vector2(2, 3.5), "colors": [Color("ffffff"), Color("f4efe6")]},
	"pates": {"shape": Shape.STICK, "size": Vector2(3, 11), "colors": [Color("f6d77e"), Color("eec45c")]},
	"poisson": {"shape": Shape.ROUND, "size": Vector2(4, 6), "colors": [Color("f28c3a"), Color("e06a28")]},
	"croquettes": {"shape": Shape.ROUND, "size": Vector2(5, 8), "colors": [Color("8a5326"), Color("a8672e"), Color("6e3f1c")]},
}

const GRAVITY := 1500.0
const MAX_PIECES := 1800
## Bas de l'écran : tout ce qui tombe de l'étagère du bas s'entasse ici.
const SCREEN_FLOOR := 714.0

## Calque des morceaux en vol et des nuages, à mettre au-dessus des produits.
var air: Control

## Dessus de l'étagère du haut : ce qui part d'au-dessus y retombe.
var _shelf_top := 398.0
var _flying: Array[Dictionary] = []
var _pieces: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []


func setup(screen: Vector2, shelf_top: float) -> void:
	size = screen
	_shelf_top = shelf_top
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	air = Control.new()
	air.size = screen
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	air.draw.connect(_draw_air)


## Explosion du contenu `kind` à `at`, projeté surtout vers `dir`. power ≈ 1 pour un produit.
func burst(at: Vector2, kind: String, power: float, dir := Vector2.UP) -> void:
	var c: Dictionary = CONTENTS[kind]
	for i in int(34 * power):
		var angle := dir.angle() + randfn(0.0, 0.9)
		_spawn(at + Vector2(randf_range(-12, 12), randf_range(-12, 12)), \
			Vector2.from_angle(angle) * randf_range(200.0, 700.0) * (0.8 + 0.2 * power), c)
	if kind == "farine":
		for i in int(5 * power):
			puff(at + Vector2(randf_range(-30, 30), randf_range(-30, 20)), randf_range(35.0, 70.0) * sqrt(power))


## Quelques morceaux qui s'échappent d'un produit en vol.
func spill(at: Vector2, kind: String, velocity: Vector2) -> void:
	_spawn(at, velocity * 0.3 + Vector2(randf_range(-80, 80), randf_range(-60, 40)), CONTENTS[kind])


## Nuage de farine qui gonfle puis se dissipe (il cache ce qu'il y a derrière).
func puff(at: Vector2, radius: float) -> void:
	_clouds.append({"p": at, "r": radius, "t": 0.0, "life": randf_range(1.8, 3.0),
		"drift": Vector2(randf_range(-25, 25), randf_range(-30, -5))})


## Farine « sur la caméra » : grosses traces blanches qui s'estompent.
static func screen_puffs(parent: Node, count: int, screen: Vector2) -> void:
	for i in count:
		var root := Node2D.new()
		root.position = Vector2(randf_range(80, screen.x - 80), randf_range(80, screen.y - 80))
		parent.add_child(root)
		var r := randf_range(50.0, 120.0)
		for j in 4:
			var blob := Polygon2D.new()
			blob.polygon = Sang.blob(Vector2.from_angle(randf() * TAU) * r * 0.4, r * randf_range(0.5, 0.9), Vector2.ZERO, 1.0, 0.05)
			blob.color = Color(1, 1, 1, 0.45)
			root.add_child(blob)
		root.scale = Vector2.ONE * 0.4
		var tw := root.create_tween()
		tw.tween_property(root, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(randf_range(0.8, 1.5))
		tw.tween_property(root, "modulate:a", 0.0, 1.2)
		tw.tween_callback(root.queue_free)


func _spawn(at: Vector2, v: Vector2, c: Dictionary) -> void:
	var s: Vector2 = c.size
	_flying.append({
		"p": at, "v": v, "rot": randf() * TAU, "spin": randf_range(-14.0, 14.0),
		"size": randf_range(s.x, s.y), "color": (c.colors as Array).pick_random(), "shape": c.shape,
		# Retombe sur l'étagère du haut si le morceau part d'au-dessus, sinon en bas de l'écran.
		"floor": (_shelf_top if at.y < _shelf_top else SCREEN_FLOOR) - randf_range(0.0, 6.0),
		"bounced": false,
	})


func _process(delta: float) -> void:
	var landed := false
	for i in range(_flying.size() - 1, -1, -1):
		var f := _flying[i]
		var v: Vector2 = f.v
		v.y += GRAVITY * delta
		var p: Vector2 = f.p + v * delta
		f.rot += f.spin * delta
		if p.y >= f.floor and v.y > 0.0:
			p.y = f.floor
			if not f.bounced and v.y > 250.0:
				# Petit rebond avant de se poser.
				f.bounced = true
				v = Vector2(v.x * 0.5, -v.y * 0.3)
				f.spin *= 0.5
			else:
				_pieces.append({"p": p, "rot": f.rot, "size": f.size, "color": f.color, "shape": f.shape})
				_flying.remove_at(i)
				landed = true
				continue
		if p.y > SCREEN_FLOOR + 40.0 or p.x < -40.0 or p.x > size.x + 40.0:
			_flying.remove_at(i)
			continue
		f.p = p
		f.v = v
	if _pieces.size() > MAX_PIECES:
		_pieces = _pieces.slice(_pieces.size() - MAX_PIECES)
	if landed:
		queue_redraw()

	for i in range(_clouds.size() - 1, -1, -1):
		var cl := _clouds[i]
		cl.t += delta
		cl.p += (cl.drift as Vector2) * delta
		if cl.t > cl.life:
			_clouds.remove_at(i)
	air.queue_redraw()


func _draw() -> void:
	for pc in _pieces:
		_draw_piece(self, pc.p, pc.rot, pc.size, pc.color, pc.shape)


func _draw_air() -> void:
	for f in _flying:
		_draw_piece(air, f.p, f.rot, f.size, f.color, f.shape)
	for cl in _clouds:
		var k: float = cl.t / cl.life
		var r: float = cl.r * (0.6 + 0.8 * sqrt(k))
		var a := 0.75 * (1.0 - k)
		air.draw_circle(cl.p, r, Color(1, 1, 1, a * 0.6))
		air.draw_circle(cl.p + Vector2(r * 0.3, -r * 0.2), r * 0.7, Color(1, 1, 1, a * 0.5))
		air.draw_circle(cl.p + Vector2(-r * 0.35, r * 0.1), r * 0.6, Color(1, 1, 1, a * 0.5))


func _draw_piece(ci: CanvasItem, p: Vector2, rot: float, s: float, color: Color, shape: int) -> void:
	var outline := color.darkened(0.35)
	match shape:
		Shape.ROUND:
			ci.draw_circle(p, s + 1.0, outline)
			ci.draw_circle(p, s, color)
		Shape.SQUARE:
			ci.draw_set_transform(p, rot)
			ci.draw_rect(Rect2(-Vector2(s, s) * 0.5 - Vector2.ONE, Vector2(s, s) + Vector2(2, 2)), outline)
			ci.draw_rect(Rect2(-Vector2(s, s) * 0.5, Vector2(s, s)), color)
			ci.draw_set_transform(Vector2.ZERO)
		Shape.TRIANGLE:
			var pts := PackedVector2Array()
			for k in 3:
				pts.append(p + Vector2.from_angle(rot + TAU * k / 3.0 + (0.3 if k == 1 else 0.0)) * s)
			ci.draw_colored_polygon(pts, color)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 1.5)
		Shape.STICK:
			var d := Vector2.from_angle(rot) * s * 0.5
			ci.draw_line(p - d, p + d, outline, 5.0)
			ci.draw_line(p - d, p + d, color, 3.0)
