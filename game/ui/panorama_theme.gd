class_name PanoramaTheme
extends RefCounted

const BACKGROUND := Color("202123")
const SURFACE := Color("292b2e")
const BORDER := Color("4b4e52")
const TEXT := Color("efeff0")
const MUTED := Color("a3a6aa")
const ACCENT := Color("8dceb4")


static func box(color: Color, border: Color = BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


static func create() -> Theme:
	var result := Theme.new()
	result.default_font_size = 20
	var font_path: String = "res://ui/fonts/e-Ukraine-Regular.otf"
	if ResourceLoader.exists(font_path):
		result.default_font = load(font_path) as Font
	for kind: String in ["Label", "Button", "CheckBox", "OptionButton"]:
		result.set_color("font_color", kind, TEXT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_color("font_pressed_color", "Button", ACCENT)
	result.set_stylebox("normal", "Button", box(SURFACE))
	result.set_stylebox("hover", "Button", box(Color("36393c"), ACCENT))
	result.set_stylebox("pressed", "Button", box(Color("35413b"), ACCENT))
	result.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT))
	result.set_stylebox("normal", "OptionButton", box(SURFACE))
	result.set_stylebox("hover", "OptionButton", box(Color("36393c"), ACCENT))
	result.set_stylebox("panel", "PopupMenu", box(SURFACE))
	result.set_stylebox("panel", "AcceptDialog", box(BACKGROUND))
	result.set_stylebox("embedded_border", "Window", box(SURFACE))
	return result


static func label(text: String, font_size: int = 20, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = result.tr(text)
	result.add_theme_font_size_override("font_size", font_size)
	var heading_path: String = "res://ui/fonts/e-UkraineHead-Regular.otf"
	if font_size >= 40 and ResourceLoader.exists(heading_path):
		result.add_theme_font_override("font", load(heading_path) as Font)
	result.add_theme_color_override("font_color", color)
	return result


static func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = result.tr(text)
	result.custom_minimum_size.y = 52
	result.pressed.connect(callback)
	if primary:
		result.add_theme_stylebox_override("normal", box(ACCENT, ACCENT))
		result.add_theme_stylebox_override("hover", box(ACCENT.lightened(.12), ACCENT))
		result.add_theme_stylebox_override("pressed", box(ACCENT.darkened(.15), ACCENT))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			result.add_theme_color_override(state, Color("10231e"))
	return result
