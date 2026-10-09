extends Sprite2D
## Oopsie Pawsie — le chat joué dans la maison (vu de dessus, tête vers le haut).
## maison.gd décide où il va ; ce script se charge de l'orienter et de l'animer.
## La queue est un sprite à part (chat_queue.png) qui ondule grâce à un petit shader :
## vite quand le chat marche, doucement quand il est arrêté.

const SPEED := 240.0
## Centre du torse dans l'image de la maquette (41 × 131) : c'est le point de collision.
const TORSO := Vector2(20.5, 45.0)
## Les images du chat sont exportées en 2×.
const TEXTURE_SCALE := 0.5

const BODY_TEX := preload("res://assets/sprites/maison/chat_corps.png")
const TAIL_TEX := preload("res://assets/sprites/maison/chat_queue.png")
## chat_queue.png = la queue découpée à la ligne 166 de l'image 2×, avec 30 px de marge à gauche et à droite.
const TAIL_CUT := 166.0
const TAIL_PAD := 30.0

## Ondulation : plus forte vers le bout de la queue (t = 0 à la base, 1 au bout).
const TAIL_SHADER := """
shader_type canvas_item;
uniform float phase = 0.0;
uniform float amount = 0.3;
// Dans fragment(), COLOR contient déjà la texture : on garde la teinte du sommet à part
// pour ne pas multiplier la couleur deux fois (ça assombrissait la queue).
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	float t = UV.y;
	float wave = sin(phase - t * 4.5) * amount * 22.0 * t * t;
	vec2 uv = UV - vec2(wave * TEXTURE_PIXEL_SIZE.x, 0.0);
	COLOR = texture(TEXTURE, uv) * tint;
}
"""
const WAG_WALK := Vector2(14.0, 1.0)  # (vitesse, amplitude) en marchant
const WAG_IDLE := Vector2(3.0, 0.35)  # (vitesse, amplitude) à l'arrêt

var _walk_time := 0.0
var _tail: Sprite2D
var _tail_mat := ShaderMaterial.new()
var _wag_phase := 0.0
var _wag_amount := WAG_IDLE.y


func _ready() -> void:
	texture = BODY_TEX
	centered = false
	scale = Vector2.ONE * TEXTURE_SCALE
	offset = -TORSO / TEXTURE_SCALE

	var shader := Shader.new()
	shader.code = TAIL_SHADER
	_tail_mat.shader = shader
	_tail = Sprite2D.new()
	_tail.texture = TAIL_TEX
	_tail.centered = false
	_tail.material = _tail_mat
	_tail.show_behind_parent = true
	# Même repère que le corps : la queue reprend pile là où l'image a été coupée.
	_tail.position = offset + Vector2(-TAIL_PAD, TAIL_CUT)
	add_child(_tail)


func walk(motion: Vector2, delta: float) -> void:
	if motion.length_squared() < 0.0001:
		idle(delta)
		return
	position += motion
	# La tête est vers le haut de l'image : angle du déplacement + 90°.
	rotation = lerp_angle(rotation, motion.angle() + PI * 0.5, minf(1.0, 12.0 * delta))
	_walk_time += delta
	var sway := sin(_walk_time * 16.0)
	scale = Vector2(1.0 + 0.04 * sway, 1.0 - 0.03 * sway) * TEXTURE_SCALE
	_wag(WAG_WALK, delta)


func idle(delta: float) -> void:
	_walk_time = 0.0
	scale = scale.lerp(Vector2.ONE * TEXTURE_SCALE, minf(1.0, 10.0 * delta))
	_wag(WAG_IDLE, delta)


func _wag(target: Vector2, delta: float) -> void:
	_wag_phase = fmod(_wag_phase + target.x * delta, TAU * 100.0)
	_wag_amount = move_toward(_wag_amount, target.y, 3.0 * delta)
	_tail_mat.set_shader_parameter("phase", _wag_phase)
	_tail_mat.set_shader_parameter("amount", _wag_amount)
