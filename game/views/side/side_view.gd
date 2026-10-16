class_name SideView
extends Control
## The railway seen from the side, like a platformer, on a neutral backdrop: track
## (sleepers, rails, optional ballast), catenary where the line is electrified, platforms,
## line-side posts and boards, and the train. No scenery on purpose: the same view serves
## main lines and, later, the metro. Pure view of SimWorld (reads only).
## Drawing is in screen space with our
## own camera so text stays crisp; geometry uses RouteProfile chainage and elevation.

const RAIL_TOP: float = 0.0
const SLEEPER_PITCH_M: float = 0.55
const MAST_PITCH_M: float = 65.0
const CONTACT_WIRE_M: float = 6.0
const MESSENGER_AT_MAST_M: float = 7.4
const MESSENGER_SAG_M: float = 0.8
const PLATFORM_H_M: float = 1.1
const FAR_TRACK_RISE_M: float = 0.55
const COUPLING_GAP_M: float = 0.8
const BACKDROP_TOP := Color("1d2329")
const BACKDROP_HORIZON := Color("39434b")
const GRID := Color(1, 1, 1, 0.035)
const GROUND := Color("2b2f2c")
const MIN_PPM: float = 3.0
const MAX_PPM: float = 40.0

var world: SimWorld
var profile: RouteProfile
var stations: Dictionary = {}
var livery: Dictionary = {}
var fleet_number: String = ""
## Pixels per metre (zoom) and where the rail sits on screen (fraction of height).
var ppm: float = 20.0
var rail_y_frac: float = 0.52
## Camera chainage; follows the train unless the player pans.
var cam_ch: float = 0.0
var follow: bool = true

var _ballast_tex: ImageTexture
var _wheel_angle: float = 0.0
var _last_odometer: float = 0.0
var _time: float = 0.0
var _limits: Array[Dictionary] = []


func setup(
	p_world: SimWorld, p_stations: Dictionary, p_livery: Dictionary, p_number: String
) -> void:
	world = p_world
	profile = RouteProfile.build(world.graph)
	stations = p_stations
	livery = p_livery
	fleet_number = p_number
	_ballast_tex = _make_ballast_texture()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_collect_speed_signs()
	cam_ch = _head_ch()


func _process(delta: float) -> void:
	if world == null:
		return
	_time += delta
	var t: Train = world.player()
	var moved: float = t.odometer_m - _last_odometer
	_last_odometer = t.odometer_m
	_wheel_angle += signf(t.speed_ms) * absf(moved) / TrainPainter.WHEEL_R * _dir()
	if follow:
		# Keep the cab about two thirds across in the direction of travel.
		var target: float = _head_ch() - _dir() * size.x * 0.18 / ppm
		cam_ch = lerpf(cam_ch, target, clampf(delta * 4.0, 0.0, 1.0))
	queue_redraw()


## Jump the camera to its follow target (no easing), e.g. after a scene change.
func snap_camera() -> void:
	follow = true
	cam_ch = _head_ch() - _dir() * size.x * 0.18 / ppm


func zoom_by(factor: float) -> void:
	ppm = clampf(ppm * factor, MIN_PPM, MAX_PPM)


func pan_px(dx: float) -> void:
	follow = false
	cam_ch -= dx / ppm


# ---------------------------------------------------------------- helpers


func _dir() -> float:
	return 1.0 if world.player().head.direction > 0 else -1.0


func _head_ch() -> float:
	return world.graph.chainage_at(world.player().head)


func _rail_y() -> float:
	return size.y * rail_y_frac


## Screen point of a chainage and a height above the local rail head.
func sp(ch: float, h: float) -> Vector2:
	var dh: float = profile.height_at(ch) - profile.height_at(cam_ch)
	return Vector2((ch - cam_ch) * ppm + size.x * 0.5, _rail_y() - (dh + h) * ppm)


func _visible_range(margin_m: float) -> Vector2:
	var half: float = size.x * 0.5 / ppm
	return Vector2(cam_ch - half - margin_m, cam_ch + half + margin_m)


static func _hash(i: int, salt: int = 0) -> float:
	var x: int = (i * 374761393 + salt * 668265263) & 0x7FFFFFFF
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7FFFFFFF
	return float(x & 0xFFFF) / 65535.0


# ---------------------------------------------------------------- drawing


func _draw() -> void:
	if world == null:
		return
	_draw_backdrop()
	_draw_ground()
	_draw_far_tracks()
	_draw_far_platforms()
	_draw_masts()
	_draw_track(false)
	_draw_train()
	_draw_wires()
	_draw_near_platforms()
	_draw_line_signs()


## Far city: panel blocks, the TV tower and golden domes, faded into the horizon colour.
func _draw_backdrop() -> void:
	var w: float = size.x
	var hy: float = _rail_y()
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, hy), Vector2(0, hy)]),
		PackedColorArray([BACKDROP_TOP, BACKDROP_TOP, BACKDROP_HORIZON, BACKDROP_HORIZON])
	)
	# Faint metre grid for scale (every 10 m, height marks every 1 m up to the wire).
	var rng: Vector2 = _visible_range(0.0)
	var k0: int = int(ceil(rng.x / 10.0))
	var k1: int = int(floor(rng.y / 10.0))
	for k: int in range(k0, k1 + 1):
		var x: float = sp(k * 10.0, 0.0).x
		draw_line(Vector2(x, 0), Vector2(x, hy), GRID, 1.0)


func _draw_ground() -> void:
	var rng: Vector2 = _visible_range(10.0)
	var top := PackedVector2Array()
	var step: float = maxf(4.0, 40.0 / ppm)
	var ch: float = rng.x
	while ch <= rng.y:
		top.append(sp(ch, -0.2))
		ch += step
	var ground := PackedVector2Array()
	for p: Vector2 in top:
		ground.append(p + Vector2(0, 0.55 * ppm))
	for k: int in range(top.size() - 1, -1, -1):
		ground.append(Vector2(top[k].x, size.y))
	draw_colored_polygon(ground, GROUND)
	# Ballast shoulder with stones (texture scrolls with chainage).
	var ballast := PackedVector2Array()
	var uvs := PackedVector2Array()
	var uv_scale: float = 1.0 / 1.6
	ch = rng.x
	var idx: int = 0
	var pts_top := PackedVector2Array()
	while ch <= rng.y:
		pts_top.append(sp(ch, -0.12))
		ch += step
	for p: Vector2 in pts_top:
		ballast.append(p)
	for k: int in range(pts_top.size() - 1, -1, -1):
		ballast.append(pts_top[k] + Vector2(0, 0.7 * ppm))
	ch = rng.x
	for p: Vector2 in ballast:
		var world_x: float = (p.x - size.x * 0.5) / ppm + cam_ch
		uvs.append(Vector2(world_x * uv_scale, (p.y - _rail_y()) / ppm * uv_scale))
		idx += 1
	draw_polygon(ballast, PackedColorArray([Color.WHITE]), uvs, _ballast_tex)


func _draw_track_at(rise: float, dim: float, from_ch: float, to_ch: float) -> void:
	var rng: Vector2 = _visible_range(2.0)
	var a: float = maxf(rng.x, from_ch)
	var b: float = minf(rng.y, to_ch)
	if a >= b:
		return
	# Sleepers seen end-on (concrete), with rail fastenings.
	var sleeper := Color(0.62, 0.61, 0.58).darkened(dim)
	if ppm >= 5.0:
		var k0: int = int(ceil(a / SLEEPER_PITCH_M))
		var k1: int = int(floor(b / SLEEPER_PITCH_M))
		for k: int in range(k0, k1 + 1):
			var p: Vector2 = sp(k * SLEEPER_PITCH_M, rise - 0.02)
			draw_rect(Rect2(p.x - 0.13 * ppm, p.y, 0.26 * ppm, 0.2 * ppm), sleeper)
			draw_rect(Rect2(p.x - 0.13 * ppm, p.y, 0.26 * ppm, 0.04 * ppm), sleeper.lightened(0.15))
	else:
		_band(a, b, rise - 0.02, rise - 0.22, sleeper)
	# Rail: web/foot in shadow, shiny head.
	_band(a, b, rise + 0.18, rise - 0.02, Color(0.25, 0.22, 0.2).darkened(dim))
	_band(a, b, rise + 0.18, rise + 0.12, Color(0.75, 0.76, 0.78).darkened(dim))


## Horizontal band following the profile between heights h_top and h_bottom.
func _band(a: float, b: float, h_top: float, h_bottom: float, col: Color) -> void:
	var step: float = maxf(4.0, 40.0 / ppm)
	var pts := PackedVector2Array()
	var ch: float = a
	while ch < b:
		pts.append(sp(ch, h_top))
		ch += step
	pts.append(sp(b, h_top))
	var n: int = pts.size()
	for k: int in range(n - 1, -1, -1):
		var x_ch: float = a + k * step if k < n - 1 else b
		pts.append(sp(x_ch, h_bottom))
	draw_colored_polygon(pts, col)


func _draw_far_tracks() -> void:
	for t: Dictionary in profile.tracks:
		if bool(t["far"]):
			_draw_track_at(FAR_TRACK_RISE_M, 0.25, float(t["from"]), float(t["to"]))


func _draw_track(_far: bool) -> void:
	for t: Dictionary in profile.tracks:
		if not bool(t["far"]):
			_draw_track_at(0.0, 0.0, float(t["from"]), float(t["to"]))


func _station_center(st: Dictionary) -> float:
	var pf: Dictionary = (st["platforms"] as Array)[0]
	var seg: TrackSegment = world.graph.get_segment(StringName(str(pf["segment"])))
	return seg.chainage_at_a_m + (float(pf["from_m"]) + float(pf["to_m"])) * 0.5


func _platform_rects(far: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for st: Variant in stations.get("stations", []):
		var sd: Dictionary = st
		for p: Variant in sd["platforms"]:
			var pd: Dictionary = p
			var seg_id := StringName(str(pd["segment"]))
			var seg: TrackSegment = world.graph.get_segment(seg_id)
			var on_far: bool = profile.is_far(seg_id) or str(pd["side"]) == "left"
			if on_far != far:
				continue
			(
				out
				. append(
					{
						"from": seg.chainage_at_a_m + float(pd["from_m"]),
						"to": seg.chainage_at_a_m + float(pd["to_m"]),
						"name": str(sd["name_uk"]),
						"rise": FAR_TRACK_RISE_M + 0.9 if profile.is_far(seg_id) else 0.0,
					}
				)
			)
	return out


func _draw_platform(p: Dictionary, near: bool) -> void:
	var a: float = float(p["from"])
	var b: float = float(p["to"])
	var rise: float = float(p["rise"])
	var face := Color("a9a59b") if near else Color("8f8c84")
	_band(a, b, rise + PLATFORM_H_M, rise - 0.25, face)
	_band(a, b, rise + PLATFORM_H_M + 0.08, rise + PLATFORM_H_M - 0.06, Color("c9c5ba"))
	_band(a, b, rise + PLATFORM_H_M + 0.02, rise + PLATFORM_H_M - 0.06, Color("e8c22a"))
	# Expansion joints on the face.
	var k0: int = int(ceil(a / 6.0))
	var k1: int = int(floor(b / 6.0))
	for k: int in range(k0, k1 + 1):
		var t: Vector2 = sp(k * 6.0, rise + PLATFORM_H_M - 0.06)
		var bt: Vector2 = sp(k * 6.0, rise - 0.25)
		draw_line(t, bt, face.darkened(0.15), maxf(1.0, 0.04 * ppm))
	if near:
		_station_sign(b - 25.0, str(p["name"]))
		_station_sign(a + 25.0, str(p["name"]))


func _draw_far_platforms() -> void:
	for p: Dictionary in _platform_rects(true):
		_draw_platform(p, false)


func _draw_near_platforms() -> void:
	for p: Dictionary in _platform_rects(false):
		_draw_platform(p, true)


func _station_sign(ch: float, title: String) -> void:
	var font: Font = get_theme_default_font()
	var base: Vector2 = sp(ch, PLATFORM_H_M)
	var top: Vector2 = sp(ch, PLATFORM_H_M + 3.2)
	draw_line(
		base + Vector2(-1.2 * ppm, 0),
		top + Vector2(-1.2 * ppm, 0),
		Color("39424a"),
		maxf(2.0, 0.1 * ppm)
	)
	draw_line(
		base + Vector2(1.2 * ppm, 0),
		top + Vector2(1.2 * ppm, 0),
		Color("39424a"),
		maxf(2.0, 0.1 * ppm)
	)
	var r := Rect2(top + Vector2(-2.2 * ppm, -0.2 * ppm), Vector2(4.4 * ppm, 1.0 * ppm))
	draw_rect(r, Color("1b4f9c"))
	draw_rect(r, Color("e9eef5"), false, maxf(1.0, 0.06 * ppm))
	var fs: int = int(clampf(0.55 * ppm, 8.0, 30.0))
	var tw: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(
		font,
		r.get_center() + Vector2(-tw * 0.5, fs * 0.35),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		Color.WHITE
	)


func _draw_masts() -> void:
	var rng: Vector2 = _visible_range(MAST_PITCH_M)
	var k0: int = int(ceil(rng.x / MAST_PITCH_M))
	var k1: int = int(floor(rng.y / MAST_PITCH_M))
	for k: int in range(k0, k1 + 1):
		var ch: float = k * MAST_PITCH_M
		if not profile.electrified_at(ch):
			continue
		var foot: Vector2 = sp(ch, -0.4)
		var head: Vector2 = sp(ch, 9.6)
		var w0: float = 0.45 * ppm
		var w1: float = 0.25 * ppm
		var pole := PackedVector2Array(
			[
				foot + Vector2(-w0 * 0.5, 0),
				foot + Vector2(w0 * 0.5, 0),
				head + Vector2(w1 * 0.5, 0),
				head + Vector2(-w1 * 0.5, 0)
			]
		)
		draw_colored_polygon(pole, Color("8e918b"))
		draw_line(
			foot + Vector2(w0 * 0.25, 0),
			head + Vector2(w1 * 0.25, 0),
			Color("a5a8a1"),
			maxf(1.0, 0.06 * ppm)
		)
		# Cantilever towards the track (side view: a bracket at wire height).
		var arm_y: Vector2 = sp(ch, MESSENGER_AT_MAST_M)
		var wire_y: Vector2 = sp(ch, CONTACT_WIRE_M)
		var steel := Color("5d6266")
		draw_line(arm_y, arm_y + Vector2(0.9 * ppm, 0), steel, maxf(1.5, 0.08 * ppm))
		draw_line(
			wire_y + Vector2(0.9 * ppm, -0.25 * ppm),
			arm_y + Vector2(0, 0.7 * ppm),
			steel,
			maxf(1.0, 0.05 * ppm)
		)
		for ins: Vector2 in [
			arm_y + Vector2(0.25 * ppm, 0), wire_y + Vector2(0.45 * ppm, -0.25 * ppm)
		]:
			draw_rect(
				Rect2(ins - Vector2(0.12, 0.08) * ppm, Vector2(0.24, 0.16) * ppm), Color("c9b98f")
			)
		# Feeder insulator on top.
		draw_rect(Rect2(head - Vector2(0.1, 0.3) * ppm, Vector2(0.2, 0.3) * ppm), Color("c9b98f"))


func _draw_wires() -> void:
	var rng: Vector2 = _visible_range(MAST_PITCH_M)
	var k0: int = int(floor(rng.x / MAST_PITCH_M))
	var k1: int = int(ceil(rng.y / MAST_PITCH_M))
	var copper := Color(0.24, 0.2, 0.17)
	var lw: float = maxf(1.0, 0.035 * ppm)
	for k: int in range(k0, k1):
		var a: float = maxf(k * MAST_PITCH_M, profile.ch_min)
		var b: float = minf((k + 1) * MAST_PITCH_M, profile.ch_max)
		if a >= b or not profile.electrified_at((a + b) * 0.5):
			continue
		var messenger := PackedVector2Array()
		var n: int = 16
		for i: int in n + 1:
			var f: float = float(i) / n
			var ch: float = lerpf(k * MAST_PITCH_M, (k + 1) * MAST_PITCH_M, f)
			var sag: float = MESSENGER_SAG_M * 4.0 * f * (1.0 - f)
			messenger.append(sp(ch, MESSENGER_AT_MAST_M - sag))
		draw_polyline(messenger, copper, lw)
		draw_line(
			sp(k * MAST_PITCH_M, CONTACT_WIRE_M),
			sp((k + 1) * MAST_PITCH_M, CONTACT_WIRE_M),
			copper,
			lw * 1.3
		)
		draw_line(sp(k * MAST_PITCH_M, 9.4), sp((k + 1) * MAST_PITCH_M, 9.4), copper, lw)
		for d: int in range(1, 8):
			var f2: float = d / 8.0
			var ch2: float = lerpf(k * MAST_PITCH_M, (k + 1) * MAST_PITCH_M, f2)
			var sag2: float = MESSENGER_SAG_M * 4.0 * f2 * (1.0 - f2)
			draw_line(
				sp(ch2, MESSENGER_AT_MAST_M - sag2),
				sp(ch2, CONTACT_WIRE_M),
				copper,
				maxf(1.0, lw * 0.6)
			)


func _collect_speed_signs() -> void:
	_limits.clear()
	for s: TrackSegment in world.graph.segments.values():
		if profile.is_far(s.id) or is_nan(s.chainage_at_a_m):
			continue
		for l: Dictionary in s.speed_limits:
			_limits.append(
				{
					"ch": s.chainage_at_a_m + float(l["from_m"]),
					"kmh": roundi(Units.ms_to_kmh(float(l["speed_ms"])))
				}
			)


## Kilometre posts, picket posts, speed boards and the whistle sign "С" before platforms.
func _draw_line_signs() -> void:
	var font: Font = get_theme_default_font()
	var rng: Vector2 = _visible_range(5.0)
	var k0: int = int(ceil(rng.x / 100.0))
	var k1: int = int(floor(rng.y / 100.0))
	for k: int in range(k0, k1 + 1):
		var ch: float = k * 100.0
		if ch < profile.ch_min or ch > profile.ch_max:
			continue
		var is_km: bool = k % 10 == 0
		var h: float = 1.5 if is_km else 0.7
		var base: Vector2 = sp(ch, -0.6)
		var top: Vector2 = sp(ch, -0.6 + h)
		draw_rect(
			Rect2(top + Vector2(-0.12 * ppm, 0), Vector2(0.24 * ppm, base.y - top.y)),
			Color("f2f0ea")
		)
		draw_rect(
			Rect2(top + Vector2(-0.12 * ppm, 0), Vector2(0.24 * ppm, 0.12 * ppm)), Color("202020")
		)
		var label: String = str(k / 10) if is_km else str(k % 10)
		var fs: int = int(clampf(0.38 * ppm, 7.0, 22.0))
		draw_string(
			font,
			top + Vector2(-0.1 * ppm, 0.5 * ppm),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			Color("202020")
		)
	for l: Dictionary in _limits:
		var ch2: float = float(l["ch"])
		if ch2 < rng.x or ch2 > rng.y:
			continue
		_board(ch2 + 3.0, str(l["kmh"]), Color("f4f2ec"), Color("1a1a1a"))
	for st: Variant in stations.get("stations", []):
		var c: float = _station_center(st as Dictionary)
		for ch3: float in [c - 600.0, c + 600.0]:
			if ch3 > rng.x and ch3 < rng.y and ch3 > profile.ch_min and ch3 < profile.ch_max:
				_board(ch3, "С", Color("f4f2ec"), Color("1a1a1a"))


func _board(ch: float, text: String, bg: Color, fg: Color) -> void:
	var font: Font = get_theme_default_font()
	var base: Vector2 = sp(ch, -0.5)
	var top: Vector2 = sp(ch, 2.4)
	draw_line(base, top, Color("3b3f42"), maxf(1.5, 0.08 * ppm))
	var r := Rect2(top + Vector2(-0.45 * ppm, -0.7 * ppm), Vector2(0.9 * ppm, 0.75 * ppm))
	draw_rect(r, bg)
	draw_rect(r, Color("1a1a1a"), false, maxf(1.0, 0.04 * ppm))
	var fs: int = int(clampf(0.48 * ppm, 7.0, 26.0))
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(
		font,
		r.get_center() + Vector2(-tw * 0.5, fs * 0.36),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		fg
	)


func _draw_train() -> void:
	var t: Train = world.player()
	var dir: float = _dir()
	var head_ch: float = _head_ch()
	var far: bool = profile.is_far(t.head.segment_id)
	var rise: float = FAR_TRACK_RISE_M if far else 0.0
	var behind: float = 0.0
	var n: int = t.consist.vehicles.size()
	var lights: bool = t.cab.is_on(&"headlights") and t.power.control_on(t.cab)
	var lit: bool = false
	var opts_base: Dictionary = {
		"lead_right": dir > 0.0,
		"panto_top": CONTACT_WIRE_M,
		"headlights": lights,
		"wheel_angle": _wheel_angle,
		"brake": t.brake_demand,
		"speed": t.speed_ms,
		"time": _time,
		"lit_windows": lit,
	}
	var ends: Array[float] = []
	for i: int in n:
		var v: VehicleSpec = t.consist.vehicles[i]
		var gap: float = COUPLING_GAP_M if i > 0 else 0.0
		behind += gap
		var front_ch: float = head_ch - dir * behind
		var rear_ch: float = head_ch - dir * (behind + v.length_m)
		behind += v.length_m - gap
		var left_ch: float = minf(front_ch, rear_ch)
		var right_ch: float = maxf(front_ch, rear_ch)
		var opts: Dictionary = opts_base.duplicate()
		var is_first: bool = i == 0
		var is_last: bool = i == n - 1
		var front_on_right: bool = dir > 0.0
		opts["cab_right"] = (is_first and front_on_right) or (is_last and not front_on_right)
		opts["cab_left"] = (is_first and not front_on_right) or (is_last and front_on_right)
		opts["panto"] = t.power.pantograph_position if v.has_pantograph else -1.0
		# Rigid body: place it on the line through the rail heights at both ends.
		var p_l: Vector2 = sp(left_ch, rise)
		var p_r: Vector2 = sp(right_ch, rise)
		var ang: float = (p_r - p_l).angle()
		draw_set_transform(p_l, ang, Vector2(ppm, ppm))
		TrainPainter.draw_car(self, v, livery, opts)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ends.append(left_ch)
		ends.append(right_ch)
		if is_first:
			_draw_number(front_ch, rear_ch, rise)
	# Gangways between neighbouring cars.
	ends.sort()
	for k: int in range(1, ends.size() - 1, 2):
		var p: Vector2 = sp(ends[k], rise)
		draw_set_transform(p, 0.0, Vector2(ppm, ppm))
		TrainPainter.draw_gangway(self, 0.0, ends[k + 1] - ends[k])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_number(front_ch: float, rear_ch: float, rise: float) -> void:
	var font: Font = get_theme_default_font()
	var x_ch: float = lerpf(front_ch, rear_ch, 0.14)
	var p: Vector2 = sp(x_ch, rise + 1.62)
	var fs: int = int(clampf(0.32 * ppm, 7.0, 18.0))
	var tw: float = font.get_string_size(fleet_number, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(
		font,
		p + Vector2(-tw * 0.5, 0),
		fleet_number,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		Color(str(livery.get("number", "#ffffff")))
	)


static func _make_ballast_texture() -> ImageTexture:
	var img: Image = Image.create(96, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color("6e6a62"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1520
	for i: int in 420:
		var c := Vector2i(rng.randi_range(0, 95), rng.randi_range(0, 47))
		var r: int = rng.randi_range(1, 3)
		var shade: float = rng.randf_range(-0.22, 0.2)
		var col := (
			Color("7d786e").lightened(shade) if shade > 0 else Color("7d786e").darkened(-shade)
		)
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r:
					img.set_pixel((c.x + dx + 96) % 96, (c.y + dy + 48) % 48, col)
	return ImageTexture.create_from_image(img)
