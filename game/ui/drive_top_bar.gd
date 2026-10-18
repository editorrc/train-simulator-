class_name DriveTopBar
extends Control
## In-trip header in the Panorama style: one graphite band over the scene, fading out
## downwards. Row 1: ARTEM, series and route, text navigation. Row 2: next station and
## distance on the left; speed with the current limit, controller / brake valve / reverser
## positions and the clock on the right. Read-only view of SimWorld; redraws on change.

signal action(id: String)

const HEIGHT: float = 132.0
const LIMIT_RED := Color("d9483b")

var world: SimWorld
var announcer: StationAnnouncer
var subtitle: String = ""
var paused: bool = false
var _nav: HBoxContainer
var _key: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = HEIGHT
	offset_bottom = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav = HBoxContainer.new()
	_nav.add_theme_constant_override("separation", 4)
	_nav.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_nav.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_nav.offset_right = -24
	_nav.offset_top = 6
	add_child(_nav)
	for entry: Array in [
		["Камера", "camera"],
		["З платформи", "platform"],
		["Пульт", "desk"],
		["Схема", "map"],
		["Налаштування", "settings"],
		["Керування", "controls"],
	]:
		_nav.add_child(_link(str(entry[0]), str(entry[1])))
	var pause: Button = _link("‖  Пауза", "pause")
	pause.add_theme_stylebox_override("normal", PanoramaTheme.selector_style(false))
	pause.add_theme_stylebox_override("hover", PanoramaTheme.selector_style(false, true))
	pause.add_theme_stylebox_override("pressed", PanoramaTheme.selector_style(true))
	_nav.add_child(pause)


## True over the navigation links (the rest of the band lets the scene take the mouse).
func over_controls(at: Vector2) -> bool:
	return _nav != null and _nav.get_global_rect().has_point(at)


func _link(text: String, id: String) -> Button:
	var button := Button.new()
	button.text = button.tr(text)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 17)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.content_margin_left = 12
	flat.content_margin_right = 12
	flat.content_margin_top = 8
	flat.content_margin_bottom = 8
	var hover: StyleBoxFlat = flat.duplicate()
	hover.border_color = PanoramaTheme.ACCENT
	hover.border_width_bottom = 2
	for state: String in ["normal", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, flat)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", PanoramaTheme.MUTED)
	button.add_theme_color_override("font_hover_color", PanoramaTheme.TEXT)
	button.add_theme_color_override("font_pressed_color", PanoramaTheme.ACCENT)
	button.pressed.connect(func() -> void: action.emit(id))
	return button


func _process(_delta: float) -> void:
	if world == null:
		return
	var t: Train = world.player()
	var key: int = hash(
		[
			roundi(Units.ms_to_kmh(absf(t.speed_ms))),
			t.last_speed_limit_ms,
			t.controller_index,
			t.brake_valve_index,
			t.reverser,
			int(world.clock_s()),
			_station_line(),
			paused,
			size,
		]
	)
	if key != _key:
		_key = key
		queue_redraw()


func _station_line() -> Array:
	if announcer == null:
		return ["", "", ""]
	var state: Dictionary = announcer.info()
	if str(state["at"]) != "":
		return [tr("СТАНЦІЯ"), announcer.station_name(str(state["at"])), ""]
	if str(state["next"]) == "":
		return [tr("НАСТУПНА"), "—", ""]
	var d: float = float(state["distance"])
	var distance: String = "%.1f км" % (d / 1000.0) if d >= 1000.0 else "%d м" % roundi(d)
	return [tr("НАСТУПНА"), announcer.station_name(str(state["next"])), distance]


func _draw() -> void:
	# Graphite band fading into the scene.
	var top := Color(PanoramaTheme.BACKGROUND, .94)
	var bottom := Color(PanoramaTheme.BACKGROUND, 0.0)
	draw_polygon(
		PackedVector2Array(
			[Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, HEIGHT), Vector2(0, HEIGHT)]
		),
		PackedColorArray([top, top, bottom, bottom])
	)
	if world == null:
		return
	var font: Font = get_theme_default_font()
	var heading: Font = font
	var heading_path: String = "res://ui/fonts/e-UkraineHead-Regular.otf"
	if ResourceLoader.exists(heading_path):
		heading = load(heading_path) as Font
	# Row 1: brand and what is being driven.
	draw_string(
		font, Vector2(36, 30), "ARTEM", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, PanoramaTheme.MUTED
	)
	# Series/route line yields to the navigation on narrow windows.
	var room: float = (_nav.position.x if _nav != null else size.x) - 98 - 24
	var text: String = subtitle
	while (
		text.length() > 4 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > room
	):
		text = text.left(-2) + "…"
		text = text.replace("……", "…")
	if room > 80:
		draw_string(
			font, Vector2(98, 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PanoramaTheme.MUTED
		)
	# Row 2 left: next station.
	var line: Array = _station_line()
	draw_string(
		font, Vector2(36, 66), str(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PanoramaTheme.MUTED
	)
	draw_string(
		heading,
		Vector2(36, 102),
		str(line[1]),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		32,
		PanoramaTheme.TEXT
	)
	var name_w: float = heading.get_string_size(str(line[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	draw_string(
		font,
		Vector2(36 + name_w + 16, 100),
		str(line[2]),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		22,
		PanoramaTheme.ACCENT
	)
	# Row 2 right, laid out from the right edge: clock, reverser, valve, controller, speed.
	var t: Train = world.player()
	var x: float = size.x - 36
	var clock: float = world.clock_s()
	var time_text: String = (
		"%02d:%02d:%02d" % [int(clock / 3600.0) % 24, int(clock / 60.0) % 60, int(clock) % 60]
	)
	x = _readout(font, x, tr("ПАУЗА") if paused else tr("ЧАС"), time_text)
	var rev: String = {1: tr("Уперед"), 0: "0", -1: tr("Назад")}[t.reverser]
	x = _readout(font, x - 28, tr("РЕВЕРСОР"), rev)
	x = _readout(font, x - 28, tr("КРАН"), t.brake_valve_position_id())
	x = _readout(font, x - 28, tr("КОНТРОЛЕР"), t.controller_position_id())
	x -= 40
	# Speed limit sign and speed.
	if not is_inf(t.last_speed_limit_ms):
		var c := Vector2(x - 24, 84)
		draw_circle(c, 24, Color.WHITE)
		draw_arc(c, 21, 0, TAU, 40, LIMIT_RED, 6.0, true)
		var limit: String = str(roundi(Units.ms_to_kmh(t.last_speed_limit_ms)))
		var lw: float = font.get_string_size(limit, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(
			font,
			c + Vector2(-lw * .5, 6),
			limit,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			17,
			Color("1b1d1f")
		)
		x -= 64
	var speed: String = str(roundi(Units.ms_to_kmh(absf(t.speed_ms))))
	var unit_w: float = font.get_string_size("км/год", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(
		font,
		Vector2(x - unit_w, 102),
		"км/год",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		PanoramaTheme.MUTED
	)
	var sw: float = heading.get_string_size(speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	var over: bool = (
		not is_inf(t.last_speed_limit_ms) and absf(t.speed_ms) > t.last_speed_limit_ms + .3
	)
	draw_string(
		heading,
		Vector2(x - unit_w - 8 - sw, 104),
		speed,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		46,
		LIMIT_RED if over else PanoramaTheme.TEXT
	)


## Caption over value, right-aligned at `right`; returns the left edge.
func _readout(font: Font, right: float, caption: String, value: String) -> float:
	var vw: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var cw: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var w: float = maxf(vw, cw)
	draw_string(
		font,
		Vector2(right - w, 66),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		PanoramaTheme.MUTED
	)
	draw_string(
		font, Vector2(right - w, 102), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, PanoramaTheme.TEXT
	)
	return right - w
