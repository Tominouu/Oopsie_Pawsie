extends Node2D
## Oopsie Pawsie — la lampe torche posée sur le canapé (dessinée à la main, vue de dessus).
## Le chat l'avale : elle file vers sa gueule en rapetissant.

const COL_BODY := Color("3b3b3f")
const COL_GRIP := Color("27272a")
const COL_HEAD := Color("f2c230")
const COL_HEAD_DARK := Color("b98d12")
const COL_LENS := Color("fff6c8")

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Avalée : file vers `mouth`, rapetisse et disparaît. `on_done` est appelé à la fin.
func swallow(mouth: Vector2, on_done: Callable) -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "position", mouth, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", Vector2.ONE * 0.1, 0.3)
	tw.parallel().tween_property(self, "rotation", rotation + TAU, 0.3)
	tw.tween_callback(func() -> void:
		on_done.call()
		queue_free())


func _draw() -> void:
	# Ombre portée.
	draw_rect(Rect2(-15, -3, 32, 10), Color(0, 0, 0, 0.25))
	# Corps et poignée striée.
	draw_rect(Rect2(-17, -5, 24, 10), COL_BODY)
	for i in 4:
		draw_line(Vector2(-14 + i * 5, -5), Vector2(-14 + i * 5, 5), COL_GRIP, 1.5)
	draw_rect(Rect2(-6, -6.5, 4, 3), Color("d23b2b"))  # bouton
	# Tête évasée.
	draw_colored_polygon(PackedVector2Array([Vector2(7, -5), Vector2(15, -9), Vector2(15, 9), Vector2(7, 5)]), COL_HEAD)
	draw_line(Vector2(7, 5), Vector2(15, 9), COL_HEAD_DARK, 1.5)
	draw_rect(Rect2(14, -8, 3, 16), COL_LENS)
	# Petit éclat qui pulse pour attirer l'œil dans le noir.
	var s := 3.0 + 1.5 * sin(_t * 4.0)
	var c := Vector2(20, -10)
	draw_line(c - Vector2(s, 0), c + Vector2(s, 0), Color(1, 1, 0.85, 0.9), 1.5)
	draw_line(c - Vector2(0, s), c + Vector2(0, s), Color(1, 1, 0.85, 0.9), 1.5)
