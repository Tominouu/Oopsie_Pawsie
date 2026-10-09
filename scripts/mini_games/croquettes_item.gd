extends Sprite2D
## Oopsie Pawsie — un produit sur les étagères du mini-jeu des croquettes.
## L'origine du sprite est le milieu du bas : le produit « pose » sur l'étagère.

var is_target := false
## Vrai pendant que le produit est en train d'être jeté (il n'est plus cliquable).
var flying := false


func setup(tex: Texture2D) -> void:
	texture = tex
	offset = Vector2(0, -tex.get_height() * 0.5)


## `global_point` est en coordonnées écran ; on teste les pixels réels du dessin.
func hit_test(global_point: Vector2) -> bool:
	return not flying and is_pixel_opaque(to_local(global_point))
