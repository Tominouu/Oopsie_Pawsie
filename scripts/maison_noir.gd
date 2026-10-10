extends ColorRect
## Oopsie Pawsie — l'obscurité de la maison.
## Au début de la nuit on n'y voit presque rien : seule la télé éclaire un peu le canapé,
## et le chat ne voit qu'autour de lui. Une fois la lampe torche avalée, un faisceau sort
## de sa tête. L'obscurité recule au fil de la nuit (GameManager.night_progress()).

## Obscurité au début et à la fin de la nuit (opacité du voile).
const DARK_START := 0.96
const DARK_END := 0.6
## Écran de la télé (vu de dessus, il éclaire vers le haut, vers le canapé).
const TV_POS := Vector2(812, 668)

const SHADER := """
shader_type canvas_item;
uniform vec2 rect_pos;
uniform vec2 rect_size;
uniform float darkness = 0.95;
uniform vec2 cat_pos;
uniform vec2 cat_dir = vec2(0.0, -1.0);
uniform float cat_glow = 65.0;
uniform float torch = 0.0;
uniform vec2 tv_pos;
uniform float tv = 1.0;
uniform vec2 item_pos;
uniform float item_glow = 0.0;

float blob(vec2 p, vec2 o, float r) {
	return 1.0 - smoothstep(r * 0.3, r, length(p - o));
}

// Cône de lumière : origine, direction, portée, cosinus des bords net / flou.
float cone(vec2 p, vec2 o, vec2 dir, float len, float cos_in, float cos_out) {
	vec2 d = p - o;
	float dist = length(d);
	if (dist < 0.001) return 1.0;
	float ang = smoothstep(cos_out, cos_in, dot(d / dist, dir));
	return ang * (1.0 - smoothstep(len * 0.3, len, dist));
}

void fragment() {
	vec2 p = rect_pos + UV * rect_size;
	float around = blob(p, cat_pos, cat_glow) * 0.85;
	vec2 head = cat_pos + cat_dir * 26.0;
	float beam = cone(p, head, cat_dir, 380.0, 0.95, 0.82) * torch;
	float halo = blob(p, cat_pos, 130.0) * 0.55 * torch;
	float tv_light = (cone(p, tv_pos, vec2(0.0, -1.0), 360.0, 0.86, 0.55) * 0.75 + blob(p, tv_pos, 80.0) * 0.5) * tv;
	float item = blob(p, item_pos, 46.0) * item_glow;
	float light = clamp(max(max(around, max(beam, halo)), max(tv_light, item)), 0.0, 1.0);
	float a = darkness * (1.0 - light);
	// Reflets colorés : bleu froid de la télé, jaune chaud de la torche.
	vec3 col = vec3(0.01, 0.012, 0.035);
	float tint_tv = tv_light * 0.22;
	float tint_beam = beam * 0.12;
	col = mix(col, vec3(0.35, 0.55, 1.0), tint_tv / max(a + tint_tv + tint_beam, 0.001));
	col = mix(col, vec3(1.0, 0.85, 0.45), tint_beam / max(a + tint_tv + tint_beam, 0.001));
	COLOR = vec4(col, max(a, tint_tv + tint_beam));
}
"""

var _mat := ShaderMaterial.new()
var _tv_t := 0.0


func _init(area: Rect2) -> void:
	position = area.position
	size = area.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_mat.shader = shader
	material = _mat
	_mat.set_shader_parameter("rect_pos", area.position)
	_mat.set_shader_parameter("rect_size", area.size)
	_mat.set_shader_parameter("tv_pos", TV_POS)


## Appelé à chaque image par la maison.
## torch : 0 → 1 (faisceau allumé), item : position de la torche encore posée (INF = avalée).
func refresh(delta: float, cat_pos: Vector2, cat_dir: Vector2, torch: float, item: Vector2) -> void:
	var t := GameManager.night_progress()
	_mat.set_shader_parameter("darkness", lerpf(DARK_START, DARK_END, t))
	_mat.set_shader_parameter("cat_pos", cat_pos)
	_mat.set_shader_parameter("cat_dir", cat_dir)
	_mat.set_shader_parameter("torch", torch)
	# La télé scintille (changements de plan), sans dépendre des FPS.
	_tv_t += delta
	var flicker := 0.85 + 0.1 * sin(_tv_t * 7.0) + 0.06 * sin(_tv_t * 23.0 + 1.3)
	if fmod(_tv_t, 3.7) < 0.12:
		flicker *= 0.6
	# Câble débranché (mission réussie) : la télé est éteinte, plus de lumière.
	if GameManager.is_mission_done("cable"):
		flicker = 0.0
	_mat.set_shader_parameter("tv", flicker)
	if item.is_finite():
		_mat.set_shader_parameter("item_pos", item)
		_mat.set_shader_parameter("item_glow", 0.55 + 0.25 * sin(_tv_t * 3.0))
	else:
		_mat.set_shader_parameter("item_glow", 0.0)
