class_name LiverySwatch
extends Button
## Small painted carriage samples, matching the Panorama concept selector.

var livery: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(112, PanoramaTheme.SELECTOR_HEIGHT)
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	tooltip_text = tr(str(livery.get("name_uk", "")))
	add_theme_stylebox_override("normal", PanoramaTheme.selector_style(false))
	add_theme_stylebox_override("hover", PanoramaTheme.selector_style(false, true))
	add_theme_stylebox_override("pressed", PanoramaTheme.selector_style(true))
	add_theme_stylebox_override("hover_pressed", PanoramaTheme.selector_style(true, true))


func _draw() -> void:
	var sample := Rect2(12, 10, size.x - 24, 40)
	var paint := Color(str(livery.get("body", "#2f6b45")))
	draw_style_box(PanoramaTheme.box(paint, paint.lightened(.18)), sample)
	if livery.has("lower_body"):
		draw_rect(
			Rect2(sample.position + Vector2(1, 24), Vector2(sample.size.x - 2, 15)),
			Color(str(livery["lower_body"]))
		)
	draw_rect(
		Rect2(sample.position + Vector2(0, 26), Vector2(sample.size.x, 5)),
		Color(str(livery.get("stripe", "#e3c75b")))
	)
	for x: float in [sample.position.x + 15, sample.end.x - 31]:
		draw_rect(Rect2(x, 16, 24, 15), Color("7c8a90"))
		draw_rect(Rect2(x + 1, 17, 22, 13), Color("162631"))
	var title: String = str(livery.get("short_name_uk", livery.get("name_uk", "")))
	var font: Font = get_theme_font("font")
	# Shrink long names (e.g. «Синьо-жовтий») to fit the cell instead of cutting them.
	var font_size: int = 15
	while font_size > 11 and font.get_string_size(tr(title), 0, -1, font_size).x > size.x - 8:
		font_size -= 1
	draw_string(
		font,
		Vector2(0, 72),
		tr(title),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		font_size,
		PanoramaTheme.TEXT
	)
