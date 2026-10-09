extends Sprite2D
## Oopsie Pawsie — le chat joué dans la maison (vu de dessus, tête vers le haut dans chat.png).
## maison.gd décide où il va ; ce script se charge de l'orienter et de l'animer.

const SPEED := 240.0
## Centre du torse dans l'image de la maquette (41 × 131) : c'est le point de collision.
const TORSO := Vector2(20.5, 45.0)
## chat.png est exporté en 2×.
const TEXTURE_SCALE := 0.5

var _walk_time := 0.0


func _ready() -> void:
	centered = false
	scale = Vector2.ONE * TEXTURE_SCALE
	offset = -TORSO / TEXTURE_SCALE


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


func idle(delta: float) -> void:
	_walk_time = 0.0
	scale = scale.lerp(Vector2.ONE * TEXTURE_SCALE, minf(1.0, 10.0 * delta))
