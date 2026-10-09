extends Sprite2D
## Oopsie Pawsie — une note du mini-jeu de rythme : une empreinte à taper (TAP)
## ou une griffure à suivre au curseur pendant un temps donné (HOLD).
## Ce script ne fait jamais avancer la note tout seul : rythme.gd pilote tout
## via advance(), appelée une seule fois par note et par frame.

enum Kind { TAP, HOLD }
enum Judge { APPROACHING, HOLDING, RESOLVED }

var kind: Kind = Kind.TAP
var judge: Judge = Judge.APPROACHING
var speed := 420.0
var hit_x := 0.0
var hold_duration := 1.0
var hold_elapsed := 0.0
## Points locaux (repère de la note) approximant la trace de ligne.png, du début à la fin.
var curve_points: PackedVector2Array = PackedVector2Array()


func advance(delta: float) -> void:
	match judge:
		Judge.APPROACHING:
			position.x -= speed * delta
		Judge.HOLDING:
			hold_elapsed += delta
			if hold_elapsed >= hold_duration:
				judge = Judge.RESOLVED


func hold_progress() -> float:
	return clampf(hold_elapsed / hold_duration, 0.0, 1.0) if hold_duration > 0.0 else 1.0


## Verrouille la note sur la zone de frappe et démarre le suivi de la griffure.
func start_hold() -> void:
	judge = Judge.HOLDING
	position.x = hit_x
	hold_elapsed = 0.0


func curve_point_local(t: float) -> Vector2:
	var n := curve_points.size()
	if n == 0:
		return Vector2.ZERO
	if n == 1:
		return curve_points[0]
	var f := t * float(n - 1)
	var i := clampi(int(f), 0, n - 2)
	return curve_points[i].lerp(curve_points[i + 1], f - i)


func target_world_position() -> Vector2:
	return to_global(curve_point_local(hold_progress()))
