class_name TelemetryView
extends Control
## Live numbers and a rolling 2-minute chart: speed vs limit, brake pipe and cylinder pressure.

const WINDOW_S: float = 120.0
const SAMPLE_S: float = 0.25

var world: SimWorld
var _samples: Array[Dictionary] = []
var _acc: float = 0.0


func _process(delta: float) -> void:
	if world == null:
		return
	_acc += delta
	if _acc >= SAMPLE_S:
		_acc = 0.0
		var t: Train = world.player()
		(
			_samples
			. append(
				{
					"t": world.clock_s(),
					"v": Units.ms_to_kmh(absf(t.speed_ms)),
					"lim":
					(
						-1.0
						if is_inf(t.last_speed_limit_ms)
						else Units.ms_to_kmh(t.last_speed_limit_ms)
					),
					"tm": Units.pa_to_kgf_cm2(t.air.p_tm),
					"tc": Units.pa_to_kgf_cm2(t.air.p_tc),
				}
			)
		)
		while _samples.size() > int(WINDOW_S / SAMPLE_S):
			_samples.remove_at(0)
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var font: Font = ThemeDB.fallback_font
	var t: Train = world.player()
	var lines: PackedStringArray = [
		(
			"v %5.1f км/год   a %+.2f м/с²   ухил %+.1f ‰"
			% [
				Units.ms_to_kmh(t.speed_ms),
				t.accel_ms2,
				world.graph.grade_ratio_at(t.head) * 1000.0
			]
		),
		(
			"тяга %+5.0f кН   гальма %4.0f кН   опір %4.0f кН"
			% [t.last_traction_n / 1000.0, t.last_brake_n / 1000.0, t.last_resistance_n / 1000.0]
		),
		(
			"пробіг %.3f км   км %.3f   маса %.0f т"
			% [
				Units.m_to_km(t.odometer_m),
				Units.m_to_km(world.graph.chainage_at(t.head)),
				t.total_mass_kg() / 1000.0
			]
		),
	]
	for i: int in lines.size():
		draw_string(
			font,
			Vector2(8, 18 + i * 18),
			lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			Color("dfe8e3")
		)
	var r := Rect2(36, 70, size.x - 70, size.y - 84)
	if r.size.y < 30 or _samples.size() < 2:
		return
	draw_rect(r, Color(1, 1, 1, 0.04))
	var t1: float = _samples.back()["t"]
	var t0: float = t1 - WINDOW_S
	var x_of: Callable = func(tt: float) -> float:
		return r.position.x + (tt - t0) / WINDOW_S * r.size.x
	var y_speed: Callable = func(v: float) -> float: return r.end.y - v / 140.0 * r.size.y
	var y_press: Callable = func(p: float) -> float: return r.end.y - p / 10.0 * r.size.y
	for v: int in [0, 40, 80, 120]:
		var y: float = y_speed.call(float(v))
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.07))
		draw_string(
			font, Vector2(4, y + 4), str(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9fb3aa")
		)
	for p: int in [0, 5, 10]:
		draw_string(
			font,
			Vector2(r.end.x + 4, y_press.call(float(p)) + 4),
			str(p),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color("9fb3aa")
		)
	var series: Array[Array] = [
		["lim", Color("d43b2c"), y_speed],
		["tm", Color("8fb3ff"), y_press],
		["tc", Color("ffb066"), y_press],
		["v", Color("57e38a"), y_speed]
	]
	for s: Array in series:
		var pts := PackedVector2Array()
		for smp: Dictionary in _samples:
			var val: float = float(smp[s[0]])
			if val < 0.0:
				continue
			pts.append(Vector2(x_of.call(float(smp["t"])), (s[2] as Callable).call(val)))
		if pts.size() > 1:
			draw_polyline(pts, s[1] as Color, 2.0, true)
	var legend: Array[Array] = [
		["швидкість", Color("57e38a")],
		["обмеження", Color("d43b2c")],
		["ГМ", Color("8fb3ff")],
		["ГЦ", Color("ffb066")]
	]
	var lx: float = r.position.x
	for l: Array in legend:
		draw_rect(Rect2(lx, r.position.y - 12, 10, 3), l[1] as Color)
		draw_string(
			font,
			Vector2(lx + 14, r.position.y - 7),
			str(l[0]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color("bcd0c6")
		)
		lx += 90
