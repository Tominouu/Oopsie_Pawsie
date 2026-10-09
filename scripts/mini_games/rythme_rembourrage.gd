extends Node2D
## Oopsie Pawsie — le canapé qui se fait lacérer, pendant du sang de la souris.
## Ce nœud garde les griffures (elles restent jusqu'à la fin) avec le rembourrage qui
## dépasse ; `air` dessine les touffes de rembourrage qui volent et les étincelles du combo.

const GRIFFE_TEX := preload("res://assets/sprites/rythme/griffe.png")

const COL_FLUFF := Color("fffaf0")
const COL_FLUFF_SHADE := Color("e8dcc8")
const COL_SPARK := Color("ffd23f")
const GRAVITY := 260.0
## Tissu déchiré : teinte appliquée au dessin des griffures (brun du tissu, un peu plus sombre).
const COL_TEAR := Color(0.78, 0.5, 0.36)
## Étalement des griffures autour du point de frappe, et nombre max de griffures gardées.
const SCATTER := Vector2(110, 40)
const MAX_MARKS := 40

## Calque des particules en vol, à mettre au-dessus des notes.
var air: Node2D

var _fluff: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
## Petites touffes collées aux griffures (dessinées en permanence).
var _tufts: Array[Dictionary] = []
var _marks: Array[Sprite2D] = []


func _init() -> void:
	air = Node2D.new()
	air.draw.connect(_draw_air)


## Griffure qui reste dans le tissu, avec du rembourrage qui en sort.
func scratch(at: Vector2, size_factor: float) -> void:
	# Les coups tombent tous sur la zone de frappe : on étale les griffures autour pour
	# qu'elles lacèrent le canapé au lieu de s'empiler en une bande sombre.
	at += Vector2(randf_range(-SCATTER.x, SCATTER.x), randf_range(-SCATTER.y, SCATTER.y))
	var g := Sprite2D.new()
	g.texture = GRIFFE_TEX
	g.position = at
	g.rotation = randf_range(-0.6, 0.6)
	g.scale = Vector2.ONE * randf_range(0.5, 0.7) * size_factor
	g.modulate = Color(COL_TEAR, 0.0)
	add_child(g)
	g.create_tween().tween_property(g, "modulate:a", 0.85, 0.06)
	_marks.append(g)
	# Au-delà de MAX_MARKS, les plus vieilles griffures s'estompent.
	if _marks.size() > MAX_MARKS:
		var old: Sprite2D = _marks.pop_front()
		var tw := old.create_tween()
		tw.tween_property(old, "modulate:a", 0.0, 0.5)
		tw.tween_callback(old.queue_free)
	for i in randi_range(2, 4):
		var off := Vector2(randf_range(-28, 28), randf_range(-60, 60)).rotated(g.rotation) * size_factor
		_tufts.append({"p": at + off, "r": randf_range(4.0, 8.0) * size_factor})
	if _tufts.size() > MAX_MARKS * 4:
		_tufts = _tufts.slice(_tufts.size() - MAX_MARKS * 4)
	queue_redraw()


## Touffes de rembourrage qui giclent. power ≈ 1 pour un coup, plus pour un PERFECT.
func burst(at: Vector2, power: float) -> void:
	for i in int(14 * power):
		var v := Vector2.from_angle(randf_range(-PI, 0.0) + randfn(0.0, 0.4)) * randf_range(120.0, 520.0) * sqrt(power)
		_fluff.append({"p": at, "v": v, "r": randf_range(5.0, 11.0), "rot": randf() * TAU,
			"spin": randf_range(-6.0, 6.0), "t": 0.0, "life": randf_range(1.0, 1.8)})


## Étincelles derrière la patte quand le combo est chaud.
func sparkle(at: Vector2, amount: int) -> void:
	for i in amount:
		_sparks.append({"p": at + Vector2(randf_range(-14, 14), randf_range(-14, 14)),
			"v": Vector2.from_angle(randf() * TAU) * randf_range(30.0, 140.0), "t": 0.0, "life": randf_range(0.25, 0.5)})


func _process(delta: float) -> void:
	var keep := 1.0 - pow(0.15, delta)
	for i in range(_fluff.size() - 1, -1, -1):
		var f := _fluff[i]
		f.t += delta
		var v: Vector2 = f.v
		v = v.lerp(Vector2.ZERO, keep)
		v.y += GRAVITY * delta
		f.v = v
		f.p += v * delta
		f.rot += f.spin * delta
		if f.t > f.life:
			_fluff.remove_at(i)
	for i in range(_sparks.size() - 1, -1, -1):
		var s := _sparks[i]
		s.t += delta
		s.p += (s.v as Vector2) * delta
		if s.t > s.life:
			_sparks.remove_at(i)
	air.queue_redraw()


func _draw() -> void:
	for t in _tufts:
		_draw_fluff(self, t.p, t.r, 0.0, 1.0)


func _draw_air() -> void:
	for f in _fluff:
		var fade: float = 1.0 - clampf((f.t - f.life * 0.6) / (f.life * 0.4), 0.0, 1.0)
		_draw_fluff(air, f.p, f.r, f.rot, fade)
	for s in _sparks:
		var k: float = 1.0 - s.t / s.life
		var p: Vector2 = s.p
		var r := 7.0 * k
		air.draw_line(p - Vector2(r, 0), p + Vector2(r, 0), Color(COL_SPARK, k), 2.0)
		air.draw_line(p - Vector2(0, r), p + Vector2(0, r), Color(COL_SPARK, k), 2.0)
		air.draw_circle(p, r * 0.4, Color(1, 1, 1, k))


## Une touffe de rembourrage : trois boules de coton qui se chevauchent.
func _draw_fluff(ci: CanvasItem, p: Vector2, r: float, rot: float, alpha: float) -> void:
	for k in 3:
		var off := Vector2.from_angle(rot + TAU * k / 3.0) * r * 0.55
		ci.draw_circle(p + off + Vector2(0, 1.5), r * 0.8, Color(COL_FLUFF_SHADE, alpha))
	for k in 3:
		var off := Vector2.from_angle(rot + TAU * k / 3.0) * r * 0.55
		ci.draw_circle(p + off, r * 0.75, Color(COL_FLUFF, alpha))
