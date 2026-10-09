extends Sprite2D
## Oopsie Pawsie — la souris du mini-jeu « Élimine l'intrus ».
## Elle alterne pauses et sprints vers un point au hasard ; chaque coup reçu
## la fait fuir plus vite et réduit ses pauses.

enum Mode { PAUSED, RUNNING, STUNNED, DEAD }

## Dans souris.svg la tête pointe vers +Y local.
const HEAD_ANGLE := PI * 0.5
## Centre du corps dans le repère local (déduit de la position du viseur dans la maquette).
const BODY_OFFSET := Vector2(-22, 50)
const STUN_TIME := 0.18

var bounds := Rect2()
var base_speed := 480.0
var hits := 0

var _mode := Mode.PAUSED
var _timer := 0.8
var _target := Vector2.ZERO
var _speed := 0.0


func body_position() -> Vector2:
	return to_global(BODY_OFFSET)


func is_dead() -> bool:
	return _mode == Mode.DEAD


func take_hit(lethal: bool) -> void:
	hits += 1
	modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)
	if lethal:
		_mode = Mode.DEAD
		var tween := create_tween().set_parallel()
		tween.tween_property(self, "scale", Vector2(1.25, 0.55), 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "self_modulate", Color(0.55, 0.55, 0.55, 0.0), 0.9).set_delay(0.3)
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
	_speed = base_speed * (1.0 + hits * 0.15) * randf_range(0.85, 1.15)
	_mode = Mode.RUNNING
