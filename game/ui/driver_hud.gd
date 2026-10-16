class_name DriverHud
extends Control
## Debug/driver HUD for the 2D demo (T2.3): speed, limit, controls, forces, clock, events.
## Read-only view of SimWorld.

const MAX_LOG_LINES: int = 8

var world: SimWorld
var paused: bool = false
var time_scale: float = 1.0

var _panel: Label
var _log: Label
var _help: Label
var _log_lines: PackedStringArray = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = _make_label(Vector2(16, 16), 20)
	_log = _make_label(Vector2(16, 430), 15)
	_help = _make_label(Vector2(16, 0), 14)
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_top = -150
	_help.modulate = Color(1, 1, 1, 0.75)
	_help.text = (
		"W/S — контролер ±    Q/E — кран машиніста (до відпуску / до гальмування)\n"
		+ "Backspace — екстрене (VI)    R — реверсор вперед/0/назад\n"
		+ "Клік по стрілці або 1/2 — перевести стрілку    P — пауза    T — прискорення часу\n"
		+ "Колесо миші — масштаб    F — камера за поїздом / вільна (перетягування ПКМ)"
	)


func _make_label(at: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func push_event(text: String) -> void:
	_log_lines.append(text)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.remove_at(0)
	_log.text = "\n".join(_log_lines)


func _process(_delta: float) -> void:
	if world == null:
		return
	var t: Train = world.player()
	var limit: String = (
		"—"
		if is_inf(t.last_speed_limit_ms)
		else "%d" % roundi(Units.ms_to_kmh(t.last_speed_limit_ms))
	)
	var rev: String = {1: "Вперед", 0: "0", -1: "Назад"}[t.reverser]
	var clock: float = world.clock_s()
	var lines: PackedStringArray = [
		"%5.1f км/год   (обмеження %s)" % [Units.ms_to_kmh(t.speed_ms), limit],
		"Реверсор: %s    Контролер: %s" % [rev, t.controller_position_id()],
		(
			"Кран машиніста: %s    гальмування %d%%"
			% [t.brake_valve_position_id(), roundi(t.brake_demand * 100.0)]
		),
		(
			"Тяга %+6.0f кН   Гальма %5.0f кН   Опір %5.0f кН"
			% [t.last_traction_n / 1000.0, t.last_brake_n / 1000.0, t.last_resistance_n / 1000.0]
		),
		"Прискорення %+.2f м/с²   Ухил-сила %+5.0f кН" % [t.accel_ms2, t.last_grade_n / 1000.0],
		"Пробіг %.2f км   Позиція %s" % [Units.m_to_km(t.odometer_m), t.head],
		(
			"Час %02d:%02d:%02d   ×%s%s%s"
			% [
				int(clock / 3600.0) % 24,
				int(clock / 60.0) % 60,
				int(clock) % 60,
				time_scale,
				"   ПАУЗА" if paused else "",
				"   БОКСУВАННЯ!" if t.slipping else ""
			]
		),
	]
	_panel.text = "\n".join(lines)
