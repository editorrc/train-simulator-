class_name LiverySwatch
extends Button
## Small painted carriage samples, matching the Panorama concept selector.

var livery: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(140, 108)
	toggle_mode = true
	tooltip_text = tr(str(livery.get("name_uk", "")))
	for state: String in ["normal", "hover", "pressed"]:
		var active: bool = state == "pressed"
		var style: StyleBoxFlat = PanoramaTheme.box(
			Color("203c39") if active else PanoramaTheme.BACKGROUND,
			PanoramaTheme.ACCENT if active else PanoramaTheme.BORDER
		)
		style.set_border_width_all(3 if active else 1)
		add_theme_stylebox_override(state, style)


func _draw() -> void:
	var sample := Rect2(12, 10, size.x - 24, 58)
	var paint := Color(str(livery.get("body", "#2f6b45")))
	draw_style_box(PanoramaTheme.box(paint, paint.lightened(.18)), sample)
	if livery.has("lower_body"):
		draw_rect(
			Rect2(sample.position + Vector2(1, 34), Vector2(sample.size.x - 2, 20)),
			Color(str(livery["lower_body"]))
		)
	draw_rect(
		Rect2(sample.position + Vector2(0, 36), Vector2(sample.size.x, 6)),
		Color(str(livery.get("stripe", "#e3c75b")))
	)
	for x: float in [sample.position.x + 15, sample.end.x - 31]:
		draw_rect(Rect2(x, 21, 24, 21), Color("7c8a90"))
		draw_rect(Rect2(x + 1, 22, 22, 19), Color("162631"))
	var title: String = str(livery.get("short_name_uk", livery.get("name_uk", "")))
	var font: Font = get_theme_font("font")
	draw_string(
		font, Vector2(0, 94), tr(title), HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, PanoramaTheme.TEXT
	)
