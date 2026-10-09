extends Sprite2D
## Oopsie Pawsie — la souris du mini-jeu « Élimine l'intrus ».
## Elle alterne pauses et sprints vers un point au hasard ; chaque coup reçu
## la fait fuir plus vite et réduit ses pauses. Un coup sur la queue la lui coupe.

enum Mode { PAUSED, RUNNING, STUNNED, DEAD }

## Dans souris_corps.svg la tête pointe vers +Y local.
const HEAD_ANGLE := PI * 0.5
## Centre du corps dans le repère local (centre de la silhouette sans la queue).
const BODY_OFFSET := Vector2(-20, 60)
const STUN_TIME := 0.18
## Attache de la queue dans le repère local (base de la queue dans le SVG : 54, 137).
const TAIL_BASE := Vector2(-12.6, -20.4)
## Tolérance autour du trait de la queue, qui est très fin.
const TAIL_TOLERANCE := 14.0

var bounds := Rect2()
var base_speed := 480.0
var hits := 0
## Queue dessinée sur le même canevas que le corps (souris_queue.svg).
var tail_texture: Texture2D

var _mode := Mode.PAUSED
var _timer := 0.8
var _target := Vector2.ZERO
var _speed := 0.0
var _panic := 1.0
var _tail: Sprite2D
var _tail_image: Image


func _ready() -> void:
	if tail_texture == null:
		return
	_tail = Sprite2D.new()
	_tail.texture = tail_texture
	# Origine du sprite sur la base de la queue, pour qu'elle gigote autour de ce point.
	_tail.position = TAIL_BASE
	_tail.offset = -TAIL_BASE
	add_child(_tail)
	_tail_image = tail_texture.get_image()


func body_position() -> Vector2:
	return to_global(BODY_OFFSET)


func is_dead() -> bool:
	return _mode == Mode.DEAD


func has_tail() -> bool:
	return _tail != null


## Vrai si `global_point` tombe sur (ou tout près de) la queue.
func tail_hit_test(global_point: Vector2) -> bool:
	if _tail == null:
		return false
	var center := _tail.to_local(global_point) - _tail.offset + _tail_image.get_size() * 0.5
	var step := 3.0
	var y := -TAIL_TOLERANCE
	while y <= TAIL_TOLERANCE:
		var x := -TAIL_TOLERANCE
		while x <= TAIL_TOLERANCE:
			if x * x + y * y <= TAIL_TOLERANCE * TAIL_TOLERANCE:
				var px := Vector2i((center + Vector2(x, y)).floor())
				if px.x >= 0 and px.y >= 0 and px.x < _tail_image.get_width() and px.y < _tail_image.get_height() \
						and _tail_image.get_pixelv(px).a > 0.4:
					return true
			x += step
		y += step
	return false


## Coupe la queue : elle reste par terre à gigoter (comme un lézard) et la souris
## détale en panique, encore plus vite qu'avant.
func lose_tail(floor_node: Node) -> void:
	if _tail == null:
		return
	var tail := _tail
	_tail = null
	tail.reparent(floor_node)
	floor_node.move_child(tail, get_index())

	var base_rot := tail.rotation
	var wiggle := tail.create_tween()
	wiggle.tween_method(func(t: float) -> void:
		tail.rotation = base_rot + sin(t * 38.0) * 0.45 * (1.0 - t / 3.0), 0.0, 3.0, 3.0)
	wiggle.tween_property(tail, "modulate:a", 0.0, 0.6)
	wiggle.tween_callback(tail.queue_free)

	var hop := create_tween()
	hop.tween_property(self, "scale", Vector2(0.8, 1.3), 0.07)
	hop.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_panic = 1.6
	_start_run()


func take_hit(lethal: bool) -> void:
	hits += 1
	modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)
	if lethal:
		_mode = Mode.DEAD
		var tween := create_tween().set_parallel()
		tween.tween_property(self, "scale", Vector2(1.25, 0.55), 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate", Color(0.55, 0.55, 0.55, 0.0), 0.9).set_delay(0.3)
		return
	_mode = Mode.STUNNED
	_timer = STUN_TIME
	var squash := create_tween()
	squash.tween_property(self, "scale", Vector2(1.15, 0.8), 0.06)
	squash.tween_property(self, "scale", Vector2.ONE, 0.12)


func _process(delta: float) -> void:
	match _mode:
		Mode.PAUSED:
			_timer -= delta
			# Petit frémissement pour montrer qu'elle va repartir.
			if _timer < 0.25:
				rotation += sin(Time.get_ticks_msec() * 0.06) * 0.01
			if _timer <= 0.0:
				_start_run()
		Mode.STUNNED:
			_timer -= delta
			if _timer <= 0.0:
				_start_run()
		Mode.RUNNING:
			var body := body_position()
			var to_target := _target - body
			var step := _speed * delta
			if to_target.length() <= step:
				position += to_target
				_mode = Mode.PAUSED
				_timer = randf_range(0.45, 1.2) / (1.0 + hits * 0.25)
				return
			var dir := to_target.normalized()
			position += dir * step
			rotation = lerp_angle(rotation, dir.angle() - HEAD_ANGLE, minf(1.0, 14.0 * delta))


func _start_run() -> void:
	var body := body_position()
	# Vise un point assez loin pour que le sprint soit visible.
	for i in 8:
		_target = Vector2(
			randf_range(bounds.position.x, bounds.end.x),
			randf_range(bounds.position.y, bounds.end.y))
		if _target.distance_to(body) > 260.0:
			break
	_speed = base_speed * (1.0 + hits * 0.15) * _panic * randf_range(0.85, 1.15)
	_panic = 1.0
	_mode = Mode.RUNNING
