extends Node2D
## Oopsie Pawsie — les traces que les mini-jeux laissent dans la maison.
## Une victoire laisse de vrais dégâts (sang, croquettes éclatées, télé qui grésille…),
## une défaite des traces plus légères. Les taches sont tirées avec une graine fixe :
## elles restent identiques à chaque retour dans la maison.
## Ce nœud se dessine au sol (au-dessus des meubles, sous le chat et le voile de nuit) ;
## `glow` dessine ce qui brille (arcs électriques, étincelles), au-dessus du voile de nuit.

const Sang := preload("res://scripts/mini_games/souris_sang.gd")
const Debris := preload("res://scripts/mini_games/croquettes_debris.gd")
const GRIFFE_TEX := preload("res://assets/sprites/rythme/griffe.png")
const FISH_TEX := preload("res://assets/sprites/aquarium/poisson.svg")

## Zones (coordonnées de la maison) où apparaissent les traces de chaque mini-jeu.
const SOURIS_SPOT := Vector2(428, 238)
## Le sang reste sur le carrelage : pas sur la poubelle (au-dessus) ni sur le frigo (à gauche).
const SOURIS_FLOOR := Rect2(372, 210, 104, 205)
const CROQUETTES_FLOOR := Rect2(104, 266, 180, 54)
const AQUARIUM_FLOOR := Rect2(662, 232, 180, 50)
const SOFA_RECT := Rect2(732, 362, 160, 78)
const SOFA_SURROUND := Rect2(700, 340, 230, 140)
const TV_RECT := Rect2(728, 646, 168, 72)

const COL_WET := Color(0.16, 0.26, 0.36, 0.28)
const COL_BONE := Color("f3eee2")
const COL_SCORCH := Color(0.08, 0.06, 0.06, 0.5)
const COL_ARC := Color(0.55, 0.9, 1.0)
const COL_FLOUR := Color(1, 1, 1, 0.55)
## Télé : chance qu'un arc finisse en petite explosion, et durée de l'éclair.
const POP_CHANCE := 0.3
const POP_TIME := 0.18

## Calque lumineux (étincelles de la télé), à mettre au-dessus du voile de nuit.
var glow: Node2D

var _blobs: Array = []    # [PackedVector2Array, Color]
var _pieces: Array = []   # [position, taille, couleur, forme]
var _bones: Array[Vector2] = []

## Télé : fréquence des arcs (0 = aucun), arcs et étincelles en cours, fumée.
var _tv_level := 0.0
var _tv_timer := 0.0
var _arcs: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
var _smoke_timer := 0.0
var _pops: Array[Dictionary] = []


func _init() -> void:
	glow = Node2D.new()
	glow.draw.connect(_draw_glow)


## Construit les traces d'après GameManager.results. `layers` = calques de la maison (pour cacher la souris).
func setup(results: Dictionary, layers: Dictionary) -> void:
	seed(4242)
	for game in results:
		var won: bool = results[game].won
		match game:
			"souris": _souris(won, layers)
			"croquettes": _croquettes(won)
			"aquarium": _aquarium(won)
			"canape": _canape(won)
			"cable": _tele(won)
	randomize()
	queue_redraw()


# --- Mini-jeu par mini-jeu -----------------------------------------------------------

## Souris éliminée : elle a disparu, il reste une flaque de sang et des giclées.
## Ratée : juste des griffures sur le carrelage.
func _souris(won: bool, layers: Dictionary) -> void:
	if won:
		(layers["souris"] as CanvasItem).visible = false
		_blobs.append([Sang.blob(SOURIS_SPOT, 24.0, Vector2.ZERO, 1.0, 0.15), Sang.COL_BLOOD_DARK])
		_blobs.append([Sang.blob(SOURIS_SPOT + Vector2(-4, -3), 15.0, Vector2.ZERO, 1.0, 0.1), Sang.COL_BLOOD])
		for i in 22:
			var off := Vector2.from_angle(randf_range(-0.5, PI + 0.5)) * randf_range(22.0, 75.0)
			if not SOURIS_FLOOR.has_point(SOURIS_SPOT + off):
				continue
			_blobs.append([Sang.blob(SOURIS_SPOT + off, randf_range(2.0, 7.0), off, 1.8, 0.2),
				[Sang.COL_BLOOD, Sang.COL_BLOOD_DARK, Sang.COL_BLOOD_LIGHT].pick_random()])
		# Traînée de gouttes vers la pièce, là où elle a tenté de fuir.
		for i in 7:
			_blobs.append([Sang.blob(SOURIS_SPOT + Vector2(14 + i * 7, 26 + i * 12) + Vector2(randf_range(-3, 3), randf_range(-3, 3)),
				randf_range(2.0, 3.5), Vector2.ZERO, 1.0, 0.0), Sang.COL_BLOOD])
		_scratch(SOURIS_SPOT + Vector2(26, 18), 0.2, Color(0.45, 0.05, 0.08, 0.7))
	else:
		for i in 3:
			_scratch(SOURIS_SPOT + Vector2(randf_range(-40, 40), randf_range(15, 45)), 0.17, Color(0.3, 0.25, 0.2, 0.45))


## Croquettes trouvées : sachet éclaté, croquettes partout devant les placards.
## Ratées : produits renversés et farine, mais pas de croquettes.
func _croquettes(won: bool) -> void:
	var r := CROQUETTES_FLOOR
	var kinds := ["cereales", "chips", "mais", "pois", "pates"]
	if not won:
		_blobs.append([Sang.blob(r.position + Vector2(55, 26), 26.0, Vector2.RIGHT, 1.5, 0.15), COL_FLOUR])
	for i in (25 if won else 45):
		_piece(r, Debris.CONTENTS[kinds.pick_random()])
	if won:
		for i in 70:
			_piece(r.grow(12), Debris.CONTENTS["croquettes"])


## Poisson rose pêché : flaques et son arête. Raté : flaques et poissons rouges qui gigotent par terre.
func _aquarium(won: bool) -> void:
	var r := AQUARIUM_FLOOR
	for i in 6:
		var p := r.position + Vector2(randf() * r.size.x, randf() * r.size.y)
		_blobs.append([Sang.blob(p, randf_range(10.0, 22.0), Vector2.ZERO, 1.0, 0.0), COL_WET])
	if won:
		_bones.append(r.get_center() + Vector2(10, 6))
		return
	for p in [r.position + Vector2(40, 30), r.position + Vector2(130, 42)]:
		var fish := Sprite2D.new()
		fish.texture = FISH_TEX
		fish.position = p
		fish.scale = Vector2.ONE * 0.55
		fish.flip_h = randf() < 0.5
		add_child(fish)
		var base_y: float = p.y
		var tw := fish.create_tween().set_loops()
		tw.tween_property(fish, "rotation", 0.45, 0.12)
		tw.parallel().tween_property(fish, "position:y", base_y - 6.0, 0.12)
		tw.tween_property(fish, "rotation", -0.45, 0.12)
		tw.parallel().tween_property(fish, "position:y", base_y, 0.12)
		tw.tween_callback(func() -> void: fish.flip_h = not fish.flip_h)
		tw.tween_interval(randf_range(0.4, 1.2))


## Canapé : lacéré, rembourrage qui sort de partout (gagné) ou juste deux griffures (perdu).
func _canape(won: bool) -> void:
	for i in (8 if won else 2):
		var p := SOFA_RECT.position + Vector2(randf() * SOFA_RECT.size.x, randf() * SOFA_RECT.size.y)
		_scratch(p, 0.22, Color(0.6, 0.38, 0.26, 0.9))
	if not won:
		return
	for i in 16:
		var on_sofa := i < 7
		var area := SOFA_RECT if on_sofa else SOFA_SURROUND
		var p := area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
		if not on_sofa and SOFA_RECT.grow(4).has_point(p):
			p.y = SOFA_RECT.end.y + randf_range(6, 26)
		_pieces.append([p, randf_range(4.0, 7.0), Color("fffaf0"), -1])


## Télé débranchée : elle grésille (arcs électriques, étincelles, fumée) et a brûlé le sol.
## Ratée : une petite étincelle de temps en temps.
func _tele(won: bool) -> void:
	_tv_level = 1.0 if won else 0.25
	if won:
		_blobs.append([Sang.blob(Vector2(TV_RECT.get_center().x, TV_RECT.position.y - 22), 20.0, Vector2.RIGHT, 2.4, 0.25), COL_SCORCH])


# --- Outils --------------------------------------------------------------------------

func _scratch(at: Vector2, scale_factor: float, color: Color) -> void:
	var g := Sprite2D.new()
	g.texture = GRIFFE_TEX
	g.position = at
	g.rotation = randf_range(-0.7, 0.7)
	g.scale = Vector2.ONE * scale_factor
	g.modulate = color
	add_child(g)


## Un morceau (croquette, chips, petit pois…) posé dans la zone `area`.
func _piece(area: Rect2, content: Dictionary) -> void:
	var s: Vector2 = content.size
	var p := area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
	_pieces.append([p, randf_range(s.x, s.y) * 0.8, (content.colors as Array).pick_random(), content.shape])


func _process(delta: float) -> void:
	if _tv_level <= 0.0:
		return
	# Arcs électriques au hasard au-dessus du meuble TV.
	_tv_timer -= delta
	if _tv_timer <= 0.0:
		_tv_timer = randf_range(0.12, 0.6) / _tv_level
		_spawn_arc()
	for i in range(_arcs.size() - 1, -1, -1):
		_arcs[i].t -= delta
		if _arcs[i].t <= 0.0:
			_arcs.remove_at(i)
	for i in range(_pops.size() - 1, -1, -1):
		_pops[i].t += delta
		if _pops[i].t > POP_TIME:
			_pops.remove_at(i)
	for i in range(_sparks.size() - 1, -1, -1):
		var s := _sparks[i]
		s.t -= delta
		s.v += Vector2(0, 300) * delta
		s.p += (s.v as Vector2) * delta
		if s.t <= 0.0:
			_sparks.remove_at(i)
	# Fumée qui monte (seulement si la télé a vraiment pris).
	if _tv_level >= 1.0:
		_smoke_timer -= delta
		if _smoke_timer <= 0.0:
			_smoke_timer = randf_range(0.25, 0.5)
			_smoke.append({"p": Vector2(TV_RECT.position.x + randf_range(30, TV_RECT.size.x - 30), TV_RECT.position.y + 10),
				"t": 0.0, "life": randf_range(1.8, 2.8), "r": randf_range(5.0, 9.0)})
	for i in range(_smoke.size() - 1, -1, -1):
		var sm := _smoke[i]
		sm.t += delta
		sm.p += Vector2(sin(sm.t * 2.0) * 8.0, -28.0) * delta
		if sm.t > sm.life:
			_smoke.remove_at(i)
	glow.queue_redraw()


func _spawn_arc() -> void:
	var a := Vector2(TV_RECT.position.x + randf_range(10, TV_RECT.size.x - 10), TV_RECT.position.y + randf_range(4, 20))
	var b := a + Vector2(randf_range(-70, 70), randf_range(-55, 5)) * (0.5 + 0.5 * _tv_level)
	var pts := PackedVector2Array([a])
	for k in range(1, 7):
		var t := k / 7.0
		pts.append(a.lerp(b, t) + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
	pts.append(b)
	_arcs.append({"pts": pts, "t": randf_range(0.06, 0.14)})
	# De temps en temps, une petite explosion : éclair lumineux et gerbe d'étincelles.
	var pop := randf() < POP_CHANCE * _tv_level
	if pop:
		_pops.append({"p": b, "t": 0.0})
		Sons.play("tele_zap", -4.0 if _tv_level >= 1.0 else -10.0)
	for k in int((3 + 5 * _tv_level) * (3.0 if pop else 1.0)):
		_sparks.append({"p": b, "v": Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(60.0, 260.0 if pop else 220.0),
			"t": randf_range(0.2, 0.45)})


func _draw() -> void:
	for b in _blobs:
		draw_colored_polygon(b[0], b[1])
	for pc in _pieces:
		var p: Vector2 = pc[0]
		var s: float = pc[1]
		var c: Color = pc[2]
		match pc[3]:
			Debris.Shape.SQUARE:
				draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), c)
			Debris.Shape.TRIANGLE:
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, s * 0.6), p + Vector2(-s, s * 0.6)]), c)
			Debris.Shape.STICK:
				draw_line(p - Vector2(s * 0.5, 0), p + Vector2(s * 0.5, 0), c, 3.0)
			-1:
				# Touffe de rembourrage.
				for k in 3:
					draw_circle(p + Vector2.from_angle(TAU * k / 3.0) * s * 0.5, s * 0.7, c)
			_:
				draw_circle(p, s + 0.8, c.darkened(0.35))
				draw_circle(p, s, c)
	for b in _bones:
		_draw_fish_bone(b)


## Arête du poisson rose : tête, colonne, côtes et queue.
func _draw_fish_bone(at: Vector2) -> void:
	var spine_a := at + Vector2(-26, 0)
	var spine_b := at + Vector2(22, 0)
	draw_line(spine_a, spine_b, COL_BONE, 3.0)
	for k in 5:
		var x := -16.0 + k * 8.0
		draw_line(at + Vector2(x, 0), at + Vector2(x - 4, -9), COL_BONE, 2.0)
		draw_line(at + Vector2(x, 0), at + Vector2(x - 4, 9), COL_BONE, 2.0)
	draw_colored_polygon(PackedVector2Array([spine_b, spine_b + Vector2(14, -9), spine_b + Vector2(16, 8)]), COL_BONE)
	draw_circle(spine_b + Vector2(9, -1), 2.0, Color(0.15, 0.1, 0.1))
	draw_colored_polygon(PackedVector2Array([spine_a, spine_a + Vector2(-11, -8), spine_a + Vector2(-11, 8)]), COL_BONE)


func _draw_glow() -> void:
	for sm in _smoke:
		var k: float = sm.t / sm.life
		glow.draw_circle(sm.p, sm.r * (1.0 + k), Color(0.6, 0.6, 0.62, 0.22 * (1.0 - k)))
	for pop in _pops:
		var k: float = pop.t / POP_TIME
		glow.draw_circle(pop.p, 10.0 + 30.0 * k, Color(COL_ARC, 0.45 * (1.0 - k)))
		glow.draw_circle(pop.p, 6.0 + 10.0 * k, Color(1, 1, 0.85, 0.9 * (1.0 - k)))
	for arc in _arcs:
		glow.draw_polyline(arc.pts, Color(COL_ARC, 0.35), 10.0, true)
		glow.draw_polyline(arc.pts, Color.WHITE, 3.0, true)
	for s in _sparks:
		var k: float = clampf(s.t / 0.45, 0.0, 1.0)
		glow.draw_circle(s.p, 2.5 * k + 0.5, Color(1.0, 0.95, 0.6, k))
