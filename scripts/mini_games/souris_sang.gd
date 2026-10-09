extends Control
## Oopsie Pawsie — le sang (cartoon) du mini-jeu de la souris.
## Ce nœud dessine les taches au sol (sous la souris) ; `air` dessine les gouttes en vol
## (à placer au-dessus de la souris). Les deux sont coupés au bord du terrain de jeu.
## Les gouttes volent, ralentissent, puis s'écrasent en tache : le sol se couvre au fil des coups.

const COL_BLOOD := Color("b3001b")
const COL_BLOOD_DARK := Color("6d0010")
const COL_BLOOD_LIGHT := Color("e5383b")
## Au-delà, les plus vieilles taches disparaissent (garde le dessin léger).
const MAX_DECALS := 2000
## Freinage des gouttes : il leur reste DRAG de leur vitesse au bout d'une seconde.
const DRAG := 0.03
const LAND_SPEED := 70.0
## Micro-gouttes laissées par seconde par une goutte rapide.
const TRAIL_RATE := 20.0

## Calque des gouttes en vol, à ajouter dans la scène au-dessus de la souris.
var air: Control

var _decals: Array = []          # [PackedVector2Array, Color]
var _drops: Array[Dictionary] = []


func setup(rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	air = Control.new()
	air.position = rect.position
	air.size = rect.size
	air.clip_contents = true
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	air.draw.connect(_draw_air)


## Giclée au point d'impact `at`, projetée surtout dans la direction `dir`.
## power ≈ 1 pour un coup, 3+ pour le coup fatal.
func splash(at: Vector2, dir: Vector2, power: float) -> void:
	dir = dir.normalized() if dir != Vector2.ZERO else Vector2.UP
	# Grosse tache centrale + éclaboussures collées autour.
	_add_decal(at, randf_range(16.0, 24.0) * sqrt(power), dir, 1.35, COL_BLOOD_DARK)
	_add_decal(at + dir * 6.0, randf_range(10.0, 15.0) * sqrt(power), dir, 1.6, COL_BLOOD)
	for i in int(8 * power):
		var off := Vector2.from_angle(dir.angle() + randfn(0.0, 1.1)) * randf_range(10.0, 45.0) * sqrt(power)
		_add_decal(at + off, randf_range(2.5, 7.0), off, 1.8, _random_red())
	# Gouttes projetées : la plupart dans le sens du coup, quelques-unes partout.
	for i in int(34 * power):
		var angle := dir.angle() + (randf() * TAU if randf() < 0.25 else randfn(0.0, 0.75))
		var big := randf() < 0.15
		_drops.append({
			"p": at,
			"v": Vector2.from_angle(angle) * randf_range(220.0, 950.0) * (0.75 + 0.25 * power),
			"r": randf_range(2.5, 6.0) * (1.9 if big else 1.0),
			"c": _random_red(),
		})


## Petite goutte qui tombe (souris blessée).
func drip(at: Vector2) -> void:
	_add_decal(at + Vector2(randf_range(-6, 6), randf_range(-6, 6)), randf_range(2.0, 4.5), Vector2.ZERO, 1.0, _random_red())


## Mare qui s'étale lentement sous le corps.
func pool(at: Vector2, radius: float) -> void:
	var p := Polygon2D.new()
	p.polygon = blob(Vector2.ZERO, radius, Vector2.ZERO, 1.0)
	p.color = COL_BLOOD_DARK
	p.position = at - position
	p.scale = Vector2.ONE * 0.2
	add_child(p)
	var shine := Polygon2D.new()
	shine.polygon = blob(Vector2(-radius * 0.25, -radius * 0.2), radius * 0.35, Vector2.ZERO, 1.0)
	shine.color = Color(COL_BLOOD_LIGHT, 0.5)
	p.add_child(shine)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 2.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Éclaboussures « sur la caméra » : grosses taches sur l'écran qui coulent puis s'effacent.
static func screen_splats(parent: Node, count: int, screen: Vector2) -> void:
	for i in count:
		var root := Node2D.new()
		root.position = Vector2(randf_range(60, screen.x - 60), randf_range(60, screen.y - 60))
		parent.add_child(root)
		var r := randf_range(40.0, 100.0)
		var color := Color(COL_BLOOD, 0.88)
		var main := Polygon2D.new()
		main.polygon = blob(Vector2.ZERO, r, Vector2.ZERO, 1.0, 0.08)
		main.color = color
		root.add_child(main)
		# Gouttelettes rondes projetées autour de la tache.
		for j in randi_range(4, 8):
			var drop := Polygon2D.new()
			var off := Vector2.from_angle(randf() * TAU) * r * randf_range(1.1, 1.8)
			drop.polygon = blob(off, randf_range(4.0, 11.0), Vector2.ZERO, 1.0, 0.0)
			drop.color = color
			root.add_child(drop)
		# Coulures vers le bas : fines en haut, avec une goutte ronde au bout.
		for j in randi_range(1, 3):
			var run := Polygon2D.new()
			var x := randf_range(-r * 0.55, r * 0.55)
			var top := sqrt(maxf(r * r - x * x, 0.0)) * 0.7
			var length := top + randf_range(r * 0.4, r * 1.3)
			var w := randf_range(5.0, 10.0)
			run.polygon = PackedVector2Array([
				Vector2(x - w, 0), Vector2(x + w, 0), Vector2(x + w * 0.55, length), Vector2(x - w * 0.55, length)])
			run.color = color
			root.add_child(run)
			var tip := Polygon2D.new()
			tip.polygon = blob(Vector2(x, length), w * 0.95, Vector2.ZERO, 1.0, 0.0)
			tip.color = color
			root.add_child(tip)
		root.scale = Vector2.ONE * 0.3
		var tw := root.create_tween()
		tw.tween_property(root, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(randf_range(0.8, 1.4))
		tw.tween_property(root, "position:y", root.position.y + randf_range(30, 70), 1.6)
		tw.parallel().tween_property(root, "modulate:a", 0.0, 1.6)
		tw.tween_callback(root.queue_free)


## Tache aux bords irréguliers (étoilée), étirée dans la direction `dir`.
static func blob(center: Vector2, radius: float, dir: Vector2, stretch: float, spikes := 0.2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 16
	var axis := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	for i in n:
		var a := TAU * i / n + randf_range(-0.12, 0.12)
		var rad := radius * randf_range(0.75, 1.15)
		if randf() < spikes:
			rad *= randf_range(1.3, 1.8)
		var v := Vector2.from_angle(a) * rad
		# Étire le long de l'axe (les gouttes rapides font des traînées).
		var along := v.dot(axis) * stretch
		var across := v.dot(axis.orthogonal())
		pts.append(center + axis * along + axis.orthogonal() * across)
	return pts


func _process(delta: float) -> void:
	if _drops.is_empty():
		return
	var keep := 1.0 - pow(DRAG, delta)
	for i in range(_drops.size() - 1, -1, -1):
		var d := _drops[i]
		var v: Vector2 = d.v
		var p: Vector2 = d.p + v * delta
		d.p = p
		d.v = v.lerp(Vector2.ZERO, keep)
		# Traînée de micro-gouttes tant que la goutte va vite (fréquence par seconde,
		# pas par image : sinon un PC rapide noie le sol sous des milliers de taches).
		if v.length() > 400.0 and randf() < TRAIL_RATE * delta:
			_add_decal(p, d.r * 0.45, v, 2.5, d.c)
		if (d.v as Vector2).length() < LAND_SPEED:
			_add_decal(p, d.r * 1.5, v, clampf(1.0 + v.length() / 300.0, 1.0, 2.2), d.c)
			_drops.remove_at(i)
	air.queue_redraw()


func _add_decal(at: Vector2, radius: float, dir: Vector2, stretch: float, color: Color) -> void:
	_decals.append([blob(at - position, radius, dir, stretch), color])
	if _decals.size() > MAX_DECALS:
		_decals.pop_front()
	queue_redraw()


func _draw() -> void:
	for d in _decals:
		draw_colored_polygon(d[0], d[1])


func _draw_air() -> void:
	for d in _drops:
		var p: Vector2 = d.p - air.position
		var v: Vector2 = d.v
		air.draw_line(p - v * 0.025, p, d.c, d.r * 1.6)
		air.draw_circle(p, d.r, d.c)


func _random_red() -> Color:
	var roll := randf()
	if roll < 0.2:
		return COL_BLOOD_DARK
	if roll < 0.35:
		return COL_BLOOD_LIGHT
	return COL_BLOOD
