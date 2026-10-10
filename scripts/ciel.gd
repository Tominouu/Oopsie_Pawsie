extends Control
## Oopsie Pawsie — l'indicateur de la nuit, en haut au centre (maquettes Figma « nuit » et « jour »).
## Il suit GameManager.night_progress() : les étoiles s'éteignent, la lune descend et se couche,
## le ciel passe du violet nuit au bleu du matin, puis le soleil se lève et le nuage arrive.
## Les calques (découpés dans nuit.svg et jour.svg, même cadre) sont coupés à la forme du dôme.

const DIR := "res://assets/sprites/ciel/"
## Emplacement du dôme dans le bandeau (maquette).
const RECT := Rect2(572.4, 24, 134, 67)

var _night_fond: TextureRect
var _stars: TextureRect
var _moon: TextureRect
var _sun: TextureRect
var _cloud: TextureRect


func _ready() -> void:
	position = RECT.position
	size = RECT.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Le ciel du matin est toujours là, en dessous ; il sert aussi de masque (forme du dôme).
	var day := _layer("jour_fond", self)
	day.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_night_fond = _layer("nuit_fond", day)
	_stars = _layer("nuit_etoiles", day)
	_moon = _layer("nuit_lune", day)
	_sun = _layer("jour_soleil", day)
	_cloud = _layer("jour_nuage", day)
	_update(GameManager.night_progress())


func _layer(file: String, parent: Control) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(DIR + file + ".svg")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = RECT.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


func _process(_delta: float) -> void:
	_update(GameManager.night_progress())


func _update(p: float) -> void:
	# Ciel : la nuit pâlit dans la deuxième moitié, puis laisse place au matin.
	_night_fond.modulate.a = 1.0 - smoothstep(0.45, 0.95, p)
	# Étoiles : elles scintillent et s'éteignent peu à peu.
	var twinkle := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.004)
	_stars.modulate.a = (1.0 - smoothstep(0.15, 0.7, p)) * twinkle
	# Lune : elle descend vers la droite et passe sous l'horizon.
	var moon_t := smoothstep(0.0, 0.95, p)
	_moon.position = Vector2(34.0, 52.0) * moon_t
	_moon.modulate.a = 1.0 - smoothstep(0.85, 1.0, p)
	# Soleil : il monte depuis l'horizon à l'aube.
	var sun_t := smoothstep(0.55, 1.0, p)
	_sun.position = Vector2(-10.0, 46.0) * (1.0 - sun_t)
	_sun.modulate.a = smoothstep(0.5, 0.65, p)
	# Nuage : il arrive par la droite une fois le jour presque levé.
	var cloud_t := smoothstep(0.7, 1.0, p)
	_cloud.position = Vector2(70.0 * (1.0 - cloud_t), 0.0)
	_cloud.modulate.a = cloud_t
