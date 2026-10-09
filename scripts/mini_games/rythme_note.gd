extends Sprite2D
## Oopsie Pawsie — une note du mini-jeu de rythme : une empreinte à taper quand elle
## passe sur la zone de frappe. Ce script ne fait jamais avancer la note tout seul :
## rythme.gd pilote tout via advance(), appelée une seule fois par note et par frame.

var speed := 420.0
var hit_x := 0.0
## Vrai quand la note est ratée et en train de s'effriter (plus cliquable).
var dead := false


func advance(delta: float) -> void:
	if not dead:
		position.x -= speed * delta


## Temps restant (en secondes) avant que la note soit pile sur la zone de frappe.
func time_to_hit() -> float:
	return (position.x - hit_x) / speed


## Note ratée : elle se fissure, tombe et disparaît.
func crumble() -> void:
	dead = true
	modulate = Color(0.55, 0.45, 0.4)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position", position + Vector2(randf_range(-30, 10), 140), 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", randf_range(-1.2, 1.2), 0.6)
	tw.tween_property(self, "scale", scale * 0.6, 0.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(queue_free)
