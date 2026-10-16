class_name Gauge
extends RefCounted
## Round dial instrument drawn onto any CanvasItem (speedometer, manometers, kilovoltmeter).

const FACE := Color("efe9d6")
const INK := Color("1d1f1c")
const RIM := Color("2a2f2c")


## needles: [{value: float, color: Color}] ; marks: [{value: float, color: Color}] (red line etc.)
static func draw(
	ci: CanvasItem,
	center: Vector2,
	radius: float,
	v_min: float,
	v_max: float,
	major: float,
	minor: float,
	label: String,
	unit: String,
	needles: Array[Dictionary],
	marks: Array[Dictionary] = [],
	digital: String = ""
) -> void:
	var font: Font = ThemeDB.fallback_font
	ci.draw_circle(center, radius + 6.0, RIM)
	ci.draw_circle(center, radius + 2.0, Color("4a524d"))
	ci.draw_circle(center, radius, FACE)
	var a0: float = deg_to_rad(135.0)
	var a1: float = deg_to_rad(405.0)
	var ang: Callable = func(v: float) -> float:
		return lerpf(a0, a1, clampf((v - v_min) / (v_max - v_min), 0.0, 1.0))
	for m: Dictionary in marks:
		var am: float = ang.call(float(m["value"]))
		ci.draw_arc(center, radius - 6.0, am - 0.04, am + 0.04, 4, m["color"] as Color, 8.0)
	var v: float = v_min
	while v <= v_max + 1e-6:
		var a: float = ang.call(v)
		var is_major: bool = (
			is_zero_approx(fmod(v - v_min + 1e-6, major)) or fmod(v - v_min + 1e-6, major) < 1e-3
		)
		var l: float = radius * (0.16 if is_major else 0.08)
		var dir := Vector2(cos(a), sin(a))
		ci.draw_line(
			center + dir * (radius - 3.0),
			center + dir * (radius - 3.0 - l),
			INK,
			2.0 if is_major else 1.0
		)
		if is_major:
			var txt: String = str(snappedf(v, 0.1)).trim_suffix(".0")
			var fs: int = int(maxf(10.0, radius * 0.16))
			var tsz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var tp: Vector2 = center + dir * (radius * 0.66) + Vector2(-tsz.x * 0.5, fs * 0.35)
			ci.draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
		v += minor
	var lfs: int = int(maxf(9.0, radius * 0.12))
	var lsz: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs)
	ci.draw_string(
		font,
		center + Vector2(-lsz.x * 0.5, radius * 0.88),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		lfs,
		INK
	)
	var usz: Vector2 = font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs - 2)
	ci.draw_string(
		font,
		center + Vector2(-usz.x * 0.5, radius * 0.7),
		unit,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		lfs - 2,
		Color(INK, 0.7)
	)
	if digital != "":
		var dfs: int = int(maxf(12.0, radius * 0.24))
		var dsz: Vector2 = font.get_string_size(digital, HORIZONTAL_ALIGNMENT_LEFT, -1, dfs)
		var box := Rect2(
			center + Vector2(-dsz.x * 0.5 - 6, radius * 0.18), Vector2(dsz.x + 12, dfs + 6)
		)
		ci.draw_rect(box, Color("1a1d1b"))
		ci.draw_string(
			font,
			box.position + Vector2(6, dfs),
			digital,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			dfs,
			Color("9df0b0")
		)
	for n: Dictionary in needles:
		var an: float = ang.call(float(n["value"]))
		var d := Vector2(cos(an), sin(an))
		ci.draw_line(
			center - d * radius * 0.12, center + d * radius * 0.86, n["color"] as Color, 3.0, true
		)
	ci.draw_circle(center, radius * 0.07, RIM)
