extends Node2D
## Oopsie Pawsie — le pipi dans le lit du maître (gag de la maison).
## Sous la couette, P (ou X à la manette) : le chat s'arrête, frissonne, et une auréole jaune
## s'étale dans les draps pendant que ça coule. Les taches restent toute la nuit (GameManager.pee_stains).
## Ce nœud vit dans le masque de la couette : rien ne déborde du tissu.

## Durée d'un pipi (le chat ne bouge pas pendant ce temps).
const PEE_TIME := 2.4
## Rayon final d'une tache (± variation).
const STAIN_RADIUS := 27.0
const STAIN_RADIUS_VAR := 6.0
## Gouttelettes qui jaillissent pendant le pipi (par seconde, indépendant des FPS).
const DROPS_PER_SEC := 30.0
## Pitch du son d'eau : plus aigu = petit filet.
const PEE_PITCH := 1.45
const PEE_DB := -10.0

const COL_FILL := Color(1.0, 0.82, 0.12, 0.66)
const COL_CORE := Color(1.0, 0.93, 0.45, 0.45)
const COL_RIM := Color(0.8, 0.55, 0.0, 0.8)
const COL_DROP := Color(1.0, 0.88, 0.3, 0.9)

## Taches : { "pos": Vector2, "r": rayon final, "seed": int, "grow": 0 → 1 }.
var _stains: Array = []
var _drops: Array = []   # { "pos", "vel", "life" }
var _peeing := false
var _pee_t := 0.0
var _pee_at := Vector2.ZERO
var _drop_acc := 0.0
var _sound: AudioStreamPlayer


func _ready() -> void:
	_sound = AudioStreamPlayer.new()
	var stream: AudioStream = load("res://assets/sounds/sfx/pipi.ogg")
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_sound.stream = stream
	_sound.pitch_scale = PEE_PITCH
	add_child(_sound)
	# Taches déjà faites cette nuit (on revient d'un mini-jeu) : déjà sèches, en entier.
	for s in GameManager.pee_stains:
		var copy: Dictionary = s.duplicate()
		copy.grow = 1.0
		_stains.append(copy)
	queue_redraw()


func is_peeing() -> bool:
	return _peeing


## Commence un pipi en `at` (sous l'arrière-train du chat).
func pee(at: Vector2) -> void:
	_peeing = true
	_pee_t = 0.0
	_pee_at = at
	_drop_acc = 0.0
	var stain := {"pos": at, "r": STAIN_RADIUS + randf_range(-STAIN_RADIUS_VAR, STAIN_RADIUS_VAR), "seed": randi(), "grow": 0.0}
	_stains.append(stain)
	GameManager.pee_stains.append({"pos": stain.pos, "r": stain.r, "seed": stain.seed})
	_sound.volume_db = PEE_DB
	_sound.play()


func _process(delta: float) -> void:
	if _peeing:
		_pee_t += delta
		var t := clampf(_pee_t / PEE_TIME, 0.0, 1.0)
		# Ça s'étale vite au début puis ralentit, comme un liquide qui imbibe le tissu.
		_stains[-1].grow = 1.0 - pow(1.0 - t, 2.5)
		_drop_acc += delta * DROPS_PER_SEC * (1.0 - t * 0.7)
		while _drop_acc >= 1.0:
			_drop_acc -= 1.0
			_spawn_drop()
		# Le filet faiblit sur la fin.
		if t > 0.7:
			_sound.volume_db = lerpf(PEE_DB, -40.0, (t - 0.7) / 0.3)
		if t >= 1.0:
			_peeing = false
			_sound.stop()

	for i in range(_drops.size() - 1, -1, -1):
		var d: Dictionary = _drops[i]
		d.life -= delta
		if d.life <= 0.0:
			_drops.remove_at(i)
			continue
		d.vel *= pow(0.02, delta)
		d.pos += d.vel * delta
	if _peeing or not _drops.is_empty():
		queue_redraw()


func _spawn_drop() -> void:
	var a := randf() * TAU
	_drops.append({
		"pos": _pee_at + Vector2.from_angle(a) * randf_range(0.0, 6.0),
		"vel": Vector2.from_angle(a) * randf_range(40.0, 120.0),
		"life": randf_range(0.18, 0.4),
	})


func _draw() -> void:
	for s in _stains:
		_draw_stain(s)
	for d in _drops:
		var c := COL_DROP
		c.a *= clampf(d.life / 0.2, 0.0, 1.0)
		draw_circle(d.pos, 1.8, c)


## Auréole irrégulière : remplissage, cœur plus clair, bord plus foncé (comme une tache qui sèche)
## et quelques éclaboussures autour.
func _draw_stain(s: Dictionary) -> void:
	var g: float = s.grow
	# Trop petite, la tache ne se triangule pas (polygone dégénéré).
	if s.r * g < 2.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = s.seed
	var r: float = s.r * g
	var pos: Vector2 = s.pos
	var n := 28
	var wobble := PackedFloat32Array()
	for i in n:
		wobble.append(rng.randf_range(0.78, 1.15))
	# Lissage : chaque point fait la moyenne avec ses voisins (bords arrondis, pas en étoile).
	var outline := PackedVector2Array()
	var squash := Vector2(rng.randf_range(1.0, 1.25), rng.randf_range(0.8, 1.0))
	for i in n:
		var w := (wobble[i] * 2.0 + wobble[(i + 1) % n] + wobble[(i + n - 1) % n]) * 0.25
		outline.append(pos + (Vector2.from_angle(TAU * i / n) * r * w) * squash)
	draw_colored_polygon(outline, COL_FILL)
	var core := PackedVector2Array()
	for p in outline:
		core.append(pos + (p - pos) * 0.55)
	draw_colored_polygon(core, COL_CORE)
	var rim := outline.duplicate()
	rim.append(outline[0])
	draw_polyline(rim, COL_RIM, 1.6, true)
	# Éclaboussures autour, qui apparaissent quand la tache a presque fini de s'étaler.
	var splash := clampf((g - 0.5) * 2.0, 0.0, 1.0)
	for i in 5:
		var a := rng.randf() * TAU
		var dist: float = s.r * rng.randf_range(1.1, 1.45)
		var size := rng.randf_range(1.5, 3.5)
		if splash > 0.0:
			draw_circle(pos + Vector2.from_angle(a) * dist * squash, size * splash, COL_FILL)
