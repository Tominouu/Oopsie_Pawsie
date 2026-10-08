extends Sprite2D

@export var facing_right := true

var velocity := Vector2.ZERO
var base_speed := 80.0
var bounds := Rect2()
var is_target := false
var revealed := false

var _turn_timer := randf_range(1.0, 3.0)
var _phase := randf() * TAU


func _process(delta: float) -> void:
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		_turn_timer = randf_range(1.5, 4.0)
		var angle := velocity.angle() + randf_range(-0.9, 0.9)
		velocity = Vector2.from_angle(angle) * base_speed * randf_range(0.8, 1.2)
		velocity.y *= 0.55
		var min_x := base_speed * 0.35
		if absf(velocity.x) < min_x:
			velocity.x = (min_x if velocity.x >= 0.0 else -min_x)

	position += velocity * delta

	if position.x < bounds.position.x:
		position.x = bounds.position.x
		velocity.x = absf(velocity.x)
	elif position.x > bounds.end.x:
		position.x = bounds.end.x
		velocity.x = -absf(velocity.x)
	if position.y < bounds.position.y:
		position.y = bounds.position.y
		velocity.y = absf(velocity.y)
	elif position.y > bounds.end.y:
		position.y = bounds.end.y
		velocity.y = -absf(velocity.y)

	var dir := signf(velocity.x)
	if dir != 0.0:
		flip_h = (dir < 0.0) == facing_right

	var tilt := clampf(atan2(velocity.y, absf(velocity.x)) * dir, -0.5, 0.5)
	var wobble := sin(Time.get_ticks_msec() / 1000.0 * 9.0 + _phase) * 0.05
	rotation = lerp_angle(rotation, tilt + wobble, minf(1.0, 6.0 * delta))


func contains_point(global_point: Vector2) -> bool:
	if texture == null:
		return false
	var p := to_local(global_point)
	if flip_h:
		p.x = -p.x
	var rx := texture.get_width() * 0.39
	var ry := texture.get_height() * 0.39
	return (p.x * p.x) / (rx * rx) + (p.y * p.y) / (ry * ry) <= 1.0


func reveal() -> void:
	if revealed or texture == null:
		return
	revealed = true
	var ring := Line2D.new()
	var radius := texture.get_width() * 0.62
	var pts := PackedVector2Array()
	for i in 48:
		pts.append(Vector2.from_angle(TAU * i / 48.0) * radius)
	ring.points = pts
	ring.closed = true
	ring.width = 12.0
	ring.default_color = Color(1.0, 0.9, 0.1)
	add_child(ring)
