extends Node2D

const RED := Color(0.85, 0.08, 0.10)
const PINK := Color(1.0, 0.45, 0.70)
const TEXT_COLOR := Color(0.05, 0.18, 0.32)
const WIN_COLOR := Color(0.25, 0.85, 0.45)
const LOSE_COLOR := Color(0.95, 0.30, 0.30)

@export var swim_zone := Rect2(0.125, 0.23, 0.745, 0.415)
@export_range(0.03, 0.15, 0.005) var fish_width_ratio := 0.07
@export_range(5, 120) var fish_count := 30
@export_range(0.1, 1.0, 0.05) var pink_difference := 0.5
@export var time_limit := 20.0
@export var result_delay := 0.4

var time_left := 0.0
var finished := false
var success := false
var fishes: Array = []
var target = null

var template: Sprite2D
var background: TextureRect
var info_label: Label
var overlay: ColorRect
var title_label: Label
var sub_label: Label


func _ready() -> void:
	randomize()
	background = $TextureRect
	template = $Sprite2D

	template.visible = false
	template.set_process(false)

	var vp := get_viewport_rect().size
	background.position = Vector2.ZERO
	background.size = vp

	var layer := CanvasLayer.new()
	add_child(layer)

	info_label = _make_label(26, TEXT_COLOR)
	info_label.position = Vector2(16, 8)
	layer.add_child(info_label)

	overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.visible = false
	layer.add_child(overlay)

	title_label = _make_label(96, Color.WHITE)
	title_label.add_theme_constant_override("outline_size", 10)
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	title_label.position = Vector2(0, vp.y * 0.5 - 120)
	title_label.size = Vector2(vp.x, 130)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(title_label)

	sub_label = _make_label(32, Color.WHITE)
	sub_label.position = Vector2(0, vp.y * 0.5 + 20)
	sub_label.size = Vector2(vp.x, 50)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(sub_label)

	start_round()


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _image_rect() -> Rect2:
	var box := Rect2(background.global_position, background.size)
	var tex := background.texture
	if tex == null:
		return box
	var tex_size := tex.get_size()
	var k := minf(box.size.x / tex_size.x, box.size.y / tex_size.y)
	var shown := tex_size * k
	return Rect2(box.position + (box.size - shown) * 0.5, shown)


func start_round() -> void:
	var img := _image_rect()
	var zone := Rect2(img.position + img.size * swim_zone.position, img.size * swim_zone.size)

	var tex_width := 256.0
	if template.texture != null:
		tex_width = template.texture.get_width()
	var fish_scale: float = img.size.x * fish_width_ratio / tex_width

	for i in fish_count:
		var f = template.duplicate()
		add_child(f)
		f.visible = true
		f.bounds = zone
		f.position = zone.position + Vector2(randf() * zone.size.x, randf() * zone.size.y)
		f.base_speed = zone.size.x * randf_range(0.07, 0.13)
		f.velocity = Vector2.from_angle(randf() * TAU) * f.base_speed
		f.scale = Vector2.ONE * fish_scale * randf_range(0.92, 1.12)
		var s := randf_range(0.93, 1.07)
		f.self_modulate = Color(RED.r * s, RED.g * s, RED.b * s)
		fishes.append(f)

	target = fishes.pick_random()
	target.is_target = true
	target.self_modulate = RED.lerp(PINK, pink_difference)

	time_left = time_limit


func _process(delta: float) -> void:
	if finished:
		return
	time_left = maxf(time_left - delta, 0.0)
	info_label.text = "Trouve le poisson rose !   Temps %.1f s" % time_left
	if time_left <= 0.0:
		finish(false, "Temps écoulé !")


func finish(won: bool, reason: String) -> void:
	if finished:
		return
	finished = true
	success = won
	for f in fishes:
		f.set_process(false)
	target.reveal()

	await get_tree().create_timer(result_delay).timeout
	show_result(won, reason)


func show_result(won: bool, reason: String) -> void:
	title_label.text = "RÉUSSITE !" if won else "ÉCHEC"
	title_label.add_theme_color_override("font_color", WIN_COLOR if won else LOSE_COLOR)
	sub_label.text = reason
	overlay.modulate.a = 0.0
	overlay.visible = true
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var p: Vector2 = make_input_local(event).position
	# On teste d'abord les poissons dessinés au-dessus (les derniers de la liste).
	for i in range(fishes.size() - 1, -1, -1):
		var f = fishes[i]
		if not f.contains_point(p):
			continue
		if f.is_target:
			finish(true, "Tu as trouvé le poisson rose en %.1f s." % (time_limit - time_left))
		else:
			finish(false, "Ce n'était pas le bon poisson.")
		return
