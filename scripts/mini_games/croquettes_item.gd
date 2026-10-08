extends Node2D
## Oopsie Pawsie — un objet de l'armoire du mini-jeu des croquettes :
## une forme simple (rond, carré, rectangle, triangle) ou le sac de croquettes.

enum Kind { CIRCLE, SQUARE, RECTANGLE, TRIANGLE, CROQUETTES }

const OUTLINE := Color(0.08, 0.08, 0.1)
const OUTLINE_WIDTH := 3.0

var kind: Kind = Kind.SQUARE
var size := Vector2(60, 60)
var color := Color.WHITE
## Vrai pendant que l'objet est en train d'être jeté (il n'est plus cliquable).
var flying := false


static func base_size(k: Kind) -> Vector2:
	match k:
		Kind.CIRCLE: return Vector2(60, 60)
		Kind.SQUARE: return Vector2(65, 65)
		Kind.RECTANGLE: return Vector2(100, 50)
		Kind.TRIANGLE: return Vector2(75, 65)
		Kind.CROQUETTES: return Vector2(80, 100)
	return Vector2(60, 60)


## `point` est exprimé dans le repère du parent (le conteneur d'objets).
func hit_test(point: Vector2) -> bool:
	var p := (point - position).rotated(-rotation) / scale
	match kind:
		Kind.CIRCLE:
			return p.length() <= size.x * 0.5
		Kind.TRIANGLE:
			return Geometry2D.is_point_in_polygon(p, _triangle_pts())
	return Rect2(-size * 0.5, size).has_point(p)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var r := Rect2(-size * 0.5, size)
	match kind:
		Kind.CIRCLE:
			var radius := w * 0.5
			draw_circle(Vector2.ZERO, radius + OUTLINE_WIDTH * 0.5, OUTLINE)
			draw_circle(Vector2.ZERO, radius - OUTLINE_WIDTH * 0.5, color)
		Kind.SQUARE, Kind.RECTANGLE:
			_poly(_rect_pts(r), color)
		Kind.TRIANGLE:
			_poly(_triangle_pts(), color)
		Kind.CROQUETTES:
			_draw_croquettes(w, h)


func _draw_croquettes(w: float, h: float) -> void:
	var bag := Color(0.88, 0.47, 0.14)
	_poly(PackedVector2Array([
		Vector2(-w * 0.42, -h * 0.5), Vector2(w * 0.42, -h * 0.5),
		Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5),
	]), bag)
	_poly(_rect_pts(Rect2(-w * 0.42, -h * 0.5, w * 0.84, h * 0.12)), bag.darkened(0.3))
	_poly(_rect_pts(Rect2(-w * 0.32, -h * 0.25, w * 0.64, h * 0.45)), Color(1, 0.95, 0.85))
	var kibble := Color(0.45, 0.25, 0.1)
	for offset in [Vector2(-0.14, -0.1), Vector2(0.1, -0.12), Vector2(-0.02, 0.0), Vector2(0.14, 0.06), Vector2(-0.15, 0.08)]:
		draw_circle(Vector2(offset.x * w, offset.y * h), w * 0.06, kibble)
	draw_string(ThemeDB.fallback_font, Vector2(-w * 0.5, h * 0.38), "CROQUETTES",
		HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color.WHITE)


func _poly(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, OUTLINE, OUTLINE_WIDTH, true)


func _triangle_pts() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -size.y * 0.5), Vector2(size.x * 0.5, size.y * 0.5), Vector2(-size.x * 0.5, size.y * 0.5),
	])


func _rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
