class_name RailView
extends Control
## The railway in a 2.5D orthographic projection: a platformer-like view, tilted down so
## both rails, the sleepers and the roofs are visible, and turnable to see the cab nose
## (3/4 front) or the tail (3/4 rear). World axes: x = chainage along the track (m),
## y = across the track (negative = towards the camera), z = height above the rail head.
## Pure view of SimWorld. No scenery on purpose: the same view serves main lines and metro.

const HALF_GAUGE_M: float = 0.76
const TRACK_SPACING_M: float = 4.1
const SLEEPER_PITCH_M: float = 0.55
const SLEEPER_HALF_M: float = 1.35
const BALLAST_TOP_HALF_M: float = 1.9
const BALLAST_FOOT_HALF_M: float = 3.3
const BALLAST_DEPTH_M: float = 0.6
const RAIL_H_M: float = 0.18
const MAST_PITCH_M: float = 65.0
const CONTACT_WIRE_M: float = 6.0
const MESSENGER_AT_MAST_M: float = 7.4
const MESSENGER_SAG_M: float = 0.8
const PLATFORM_EDGE_M: float = 1.92
const PLATFORM_DEPTH_M: float = 6.0
const PLATFORM_H_M: float = 1.1
const COUPLING_GAP_M: float = 0.8
const MIN_PPM: float = 3.0
const MAX_PPM: float = 45.0

const BACKDROP_TOP := Color("22272a")
const BACKDROP_HORIZON := Color("30352f")
const GROUND := Color("2c302c")
const GROUND_FAR := Color("353a35")

## Camera presets: yaw is mirrored with the direction of travel so "front" always shows
## the leading cab.
const PRESETS: Array[Dictionary] = [
	{"name": "3/4 спереду", "yaw": -28.0, "pitch": 25.0},
	{"name": "Збоку", "yaw": 0.0, "pitch": 20.0},
	{"name": "3/4 ззаду", "yaw": 28.0, "pitch": 25.0},
	{"name": "Зверху", "yaw": -10.0, "pitch": 48.0},
]

var pose: RenderPose
var world: SimWorld
var profile: RouteProfile
var stations: Dictionary = {}
var livery: Dictionary = {}
var fleet_number: String = ""
var ppm: float = 20.0
## Where the rail head at the camera point sits on screen (fraction of height).
var rail_y_frac: float = 0.56
var cam_ch: float = 0.0
var follow: bool = true
var preset_index: int = 0
## Manual offsets on top of the preset, degrees.
var yaw_offset: float = 0.0
var pitch_offset: float = 0.0

var _render_head_ch: float = 0.0
var _previous_camera_target: float = 0.0
var _doors: float = 0.0
var _yaw: float = 0.0
var _pitch: float = 0.0
var _cy: float = 1.0
var _sy: float = 0.0
var _cp: float = 1.0
var _sp: float = 0.0
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
	_apply_angles(_target_yaw(), _target_pitch())
	snap_camera()


func preset_name() -> String:
	return str(PRESETS[preset_index]["name"])


func next_preset() -> void:
	preset_index = (preset_index + 1) % PRESETS.size()
	yaw_offset = 0.0
	pitch_offset = 0.0


func adjust(d_yaw: float, d_pitch: float) -> void:
	yaw_offset = clampf(yaw_offset + d_yaw, -60.0, 60.0)
	pitch_offset = clampf(pitch_offset + d_pitch, -20.0, 50.0)


func snap_camera() -> void:
	follow = true
	_apply_angles(_target_yaw(), _target_pitch())
	_render_head_ch = world.graph.chainage_at(world.player().head)
	cam_ch = _follow_target()
	_previous_camera_target = cam_ch


func zoom_by(factor: float) -> void:
	ppm = clampf(ppm * factor, MIN_PPM, MAX_PPM)


func pan_px(dx: float) -> void:
	follow = false
	cam_ch -= dx / (ppm * maxf(_cy, 0.3))


func _process(delta: float) -> void:
	if world == null:
		return
	if pose != null:
		_render_head_ch = world.graph.chainage_at(
			pose.head(world.graph, SimClock.clock.interpolation_alpha())
		)
		if absf(cam_ch - _render_head_ch) > 1000:
			cam_ch = _follow_target()
			_previous_camera_target = cam_ch
	_time += delta
	var t: Train = world.player()
	var moved: float = t.odometer_m - _last_odometer
	_last_odometer = t.odometer_m
	_wheel_angle += signf(t.speed_ms) * absf(moved) / TrainPainter.WHEEL_R * _dir()
	var k: float = clampf(delta * 4.0, 0.0, 1.0)
	_apply_angles(lerpf(_yaw, _target_yaw(), k), lerpf(_pitch, _target_pitch(), k))
	if follow:
		cam_ch = RenderPose.follow(
			cam_ch,
			_previous_camera_target,
			_follow_target(),
			delta,
			float(Settings.get_value("camera", "follow_s", .18))
		)
	_previous_camera_target = _follow_target()
	queue_redraw()


func _target_yaw() -> float:
	return float(PRESETS[preset_index]["yaw"]) * _dir() + yaw_offset


func _target_pitch() -> float:
	return clampf(float(PRESETS[preset_index]["pitch"]) + pitch_offset, -10.0, 80.0)


func _apply_angles(yaw_deg: float, pitch_deg: float) -> void:
	_yaw = yaw_deg
	_pitch = pitch_deg
	_cy = cos(deg_to_rad(_yaw))
	_sy = sin(deg_to_rad(_yaw))
	_cp = cos(deg_to_rad(_pitch))
	_sp = sin(deg_to_rad(_pitch))


func _follow_target() -> float:
	return _head_ch() - _dir() * size.x * 0.16 / ppm


func _dir() -> float:
	return 1.0 if world.player().head.direction > 0 else -1.0


func _head_ch() -> float:
	return _render_head_ch if pose != null else world.graph.chainage_at(world.player().head)


# ---------------------------------------------------------------- projection


## World point → screen.
func proj(x: float, y: float, z: float) -> Vector2:
	var dx: float = x - cam_ch
	var dz: float = z + profile.height_at(x) - profile.height_at(cam_ch)
	var sx: float = dx * _cy - y * _sy
	var d: float = dx * _sy + y * _cy
	var up: float = dz * _cp + d * _sp
	return Vector2(size.x * 0.5 + sx * ppm, size.y * rail_y_frac - up * ppm)


## World direction → screen (linear part, in pixels per metre).
func lin(v: Vector3) -> Vector2:
	var sx: float = v.x * _cy - v.y * _sy
	var d: float = v.x * _sy + v.y * _cy
	return Vector2(sx, -(v.z * _cp + d * _sp)) * ppm


## Canvas transform drawing a plane: local x along `u`, local y along `v`, from `origin`.
func plane(origin: Vector3, u: Vector3, v: Vector3) -> Transform2D:
	return Transform2D(lin(u), lin(v), proj(origin.x, origin.y, origin.z))


func depth(x: float, y: float) -> float:
	return (x - cam_ch) * _sy + y * _cy


func _visible_range(margin_m: float) -> Vector2:
	var half: float = size.x * 0.5 / (ppm * maxf(absf(_cy), 0.35)) + 25.0
	return Vector2(cam_ch - half - margin_m, cam_ch + half + margin_m)


static func _hash(i: int, salt: int = 0) -> float:
	var x: int = (i * 374761393 + salt * 668265263) & 0x7FFFFFFF
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7FFFFFFF
	return float(x & 0xFFFF) / 65535.0


# ---------------------------------------------------------------- drawing


func _draw() -> void:
	if world == null:
		return
	var w: float = size.x
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, size.y), Vector2(0, size.y)]),
		PackedColorArray(
			[
				PanoramaTheme.BACKGROUND,
				PanoramaTheme.BACKGROUND,
				PanoramaTheme.BACKGROUND,
				PanoramaTheme.BACKGROUND
			]
		)
	)
	var rng: Vector2 = _visible_range(10.0)

	var far_tracks: Array[Dictionary] = []
	var main_tracks: Array[Dictionary] = []
	for t: Dictionary in profile.tracks:
		(far_tracks if bool(t["far"]) else main_tracks).append(t)
	for p: Dictionary in _platforms(true):
		_draw_platform(p, false)
	for t: Dictionary in far_tracks:
		_draw_track(TRACK_SPACING_M, float(t["from"]), float(t["to"]), rng)
	_draw_masts(rng)
	for t: Dictionary in main_tracks:
		_draw_track(0.0, float(t["from"]), float(t["to"]), rng)
	_draw_train()
	_draw_wires(rng)
	for p: Dictionary in _platforms(false):
		_draw_platform(p, true)
	_draw_line_signs(rng)


func _draw_ground(rng: Vector2) -> void:
	# The orthographic ground plane fills the backdrop; only the near edge is drawn.
	var edge := PackedVector2Array()
	var x: float = rng.x
	while x <= rng.y:
		edge.append(proj(x, -BALLAST_FOOT_HALF_M - 0.5, -BALLAST_DEPTH_M))
		x += 10.0
	edge.append(proj(rng.y, -BALLAST_FOOT_HALF_M - 0.5, -BALLAST_DEPTH_M))
	edge.append(Vector2(edge[edge.size() - 1].x, size.y + 10))
	edge.append(Vector2(edge[0].x, size.y + 10))
	draw_colored_polygon(edge, GROUND)


## Horizontal band (z constant) between lateral offsets y0..y1, chainage a..b.
func _flat(
	a: float, b: float, y0: float, y1: float, z: float, col: Color, tex: Texture2D = null
) -> void:
	var step: float = 8.0
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var x: float = a
	while true:
		top.append(proj(x, y1, z))
		bottom.append(proj(x, y0, z))
		if x >= b:
			break
		x = minf(x + step, b)
	var poly := PackedVector2Array(top)
	var uvs := PackedVector2Array()
	for k: int in range(bottom.size() - 1, -1, -1):
		poly.append(bottom[k])
	if tex == null:
		draw_colored_polygon(poly, col)
		return
	x = a
	var xs: Array[float] = []
	while true:
		xs.append(x)
		if x >= b:
			break
		x = minf(x + step, b)
	for xx: float in xs:
		uvs.append(Vector2(xx / 1.6, y1 / 1.6))
	for k: int in range(xs.size() - 1, -1, -1):
		uvs.append(Vector2(xs[k] / 1.6, y0 / 1.6))
	draw_polygon(poly, PackedColorArray([col]), uvs, tex)


## Vertical band (y constant) between heights z0..z1.
func _wall(a: float, b: float, y: float, z0: float, z1: float, col: Color) -> void:
	var step: float = 8.0
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var x: float = a
	while true:
		top.append(proj(x, y, z1))
		bottom.append(proj(x, y, z0))
		if x >= b:
			break
		x = minf(x + step, b)
	for k: int in range(bottom.size() - 1, -1, -1):
		top.append(bottom[k])
	draw_colored_polygon(top, col)


## Sloped band from (y0, z0) to (y1, z1), e.g. a ballast shoulder.
func _slope(a: float, b: float, y0: float, z0: float, y1: float, z1: float, col: Color) -> void:
	var step: float = 8.0
	var p0 := PackedVector2Array()
	var p1 := PackedVector2Array()
	var x: float = a
	while true:
		p0.append(proj(x, y0, z0))
		p1.append(proj(x, y1, z1))
		if x >= b:
			break
		x = minf(x + step, b)
	for k: int in range(p1.size() - 1, -1, -1):
		p0.append(p1[k])
	draw_colored_polygon(p0, col)


func _draw_track(y0: float, from_ch: float, to_ch: float, rng: Vector2) -> void:
	var a: float = maxf(rng.x, from_ch)
	var b: float = minf(rng.y, to_ch)
	if a >= b:
		return
	var ballast := Color("8c877d")
	_slope(
		a,
		b,
		y0 + BALLAST_TOP_HALF_M,
		-0.05,
		y0 + BALLAST_FOOT_HALF_M,
		-BALLAST_DEPTH_M,
		ballast.darkened(0.25)
	)
	_flat(a, b, y0 - BALLAST_TOP_HALF_M, y0 + BALLAST_TOP_HALF_M, -0.05, Color.WHITE, _ballast_tex)
	_slope(
		a,
		b,
		y0 - BALLAST_TOP_HALF_M,
		-0.05,
		y0 - BALLAST_FOOT_HALF_M,
		-BALLAST_DEPTH_M,
		ballast.darkened(0.05)
	)
	# Concrete sleepers with their near faces.
	var sleeper := Color("9c9a92")
	if ppm >= 4.0:
		var k0: int = int(ceil(a / SLEEPER_PITCH_M))
		var k1: int = int(floor(b / SLEEPER_PITCH_M))
		for k: int in range(k0, k1 + 1):
			var x: float = k * SLEEPER_PITCH_M
			var y_n: float = y0 - SLEEPER_HALF_M
			var y_f: float = y0 + SLEEPER_HALF_M
			var top := PackedVector2Array(
				[
					proj(x - 0.13, y_f, 0.0),
					proj(x + 0.13, y_f, 0.0),
					proj(x + 0.13, y_n, 0.0),
					proj(x - 0.13, y_n, 0.0)
				]
			)
			draw_colored_polygon(top, sleeper)
			var face := PackedVector2Array(
				[
					proj(x - 0.13, y_n, 0.0),
					proj(x + 0.13, y_n, 0.0),
					proj(x + 0.13, y_n, -0.18),
					proj(x - 0.13, y_n, -0.18)
				]
			)
			draw_colored_polygon(face, sleeper.darkened(0.3))
	# Rails: far rail first; web in shadow, polished head on top.
	for ry: float in [y0 + HALF_GAUGE_M, y0 - HALF_GAUGE_M]:
		_wall(a, b, ry - 0.04, 0.0, RAIL_H_M, Color("3b332d"))
		_flat(a, b, ry - 0.04, ry + 0.04, RAIL_H_M, Color("c4c7ca"))


func _mast_y(x: float) -> float:
	for t: Dictionary in profile.tracks:
		if bool(t["far"]) and x >= float(t["from"]) - 20.0 and x <= float(t["to"]) + 20.0:
			return TRACK_SPACING_M + 3.1
	return 3.1


func _draw_masts(rng: Vector2) -> void:
	var k0: int = int(ceil(rng.x / MAST_PITCH_M))
	var k1: int = int(floor(rng.y / MAST_PITCH_M))
	for k: int in range(k0, k1 + 1):
		var x: float = k * MAST_PITCH_M
		if not profile.electrified_at(x):
			continue
		var my: float = _mast_y(x)
		var foot: Vector2 = proj(x, my, -BALLAST_DEPTH_M)
		var head: Vector2 = proj(x, my, 9.6)
		var w0: float = 0.45 * ppm
		var w1: float = 0.25 * ppm
		draw_colored_polygon(
			PackedVector2Array(
				[
					foot + Vector2(-w0 * 0.5, 0),
					foot + Vector2(w0 * 0.5, 0),
					head + Vector2(w1 * 0.5, 0),
					head + Vector2(-w1 * 0.5, 0)
				]
			),
			Color("8e918b")
		)
		draw_line(
			foot + Vector2(w0 * 0.2, 0),
			head + Vector2(w1 * 0.2, 0),
			Color("a9aca5"),
			maxf(1.0, 0.06 * ppm)
		)
		draw_rect(Rect2(head - Vector2(0.1, 0.3) * ppm, Vector2(0.2, 0.3) * ppm), Color("c9b98f"))


func _draw_wires(rng: Vector2) -> void:
	var copper := Color(0.36, 0.3, 0.24)
	var lw: float = maxf(1.0, 0.04 * ppm)
	var steel := Color("6d7276")
	var k0: int = int(floor(rng.x / MAST_PITCH_M))
	var k1: int = int(ceil(rng.y / MAST_PITCH_M))
	for k: int in range(k0, k1 + 1):
		var xm: float = k * MAST_PITCH_M
		if profile.electrified_at(xm):
			var my: float = _mast_y(xm)
			# Cantilever: horizontal tube to the messenger, brace down to the contact wire.
			var tracks: Array[float] = [0.0]
			if my > TRACK_SPACING_M:
				tracks.append(TRACK_SPACING_M)
			for ty: float in tracks:
				draw_line(
					proj(xm, my, MESSENGER_AT_MAST_M + 0.4),
					proj(xm, ty, MESSENGER_AT_MAST_M + 0.1),
					steel,
					maxf(1.5, 0.07 * ppm)
				)
				draw_line(
					proj(xm, my, MESSENGER_AT_MAST_M - 0.9),
					proj(xm, ty, CONTACT_WIRE_M + 0.05),
					steel,
					maxf(1.0, 0.05 * ppm)
				)
				var ins: Vector2 = proj(xm, ty + 0.4, MESSENGER_AT_MAST_M + 0.15)
				draw_rect(
					Rect2(ins - Vector2(0.12, 0.08) * ppm, Vector2(0.24, 0.16) * ppm),
					Color("c9b98f")
				)
		if k >= k1:
			continue
		var a: float = maxf(xm, profile.ch_min)
		var b: float = minf(xm + MAST_PITCH_M, profile.ch_max)
		if a >= b or not profile.electrified_at((a + b) * 0.5):
			continue
		var wire_tracks: Array[float] = [0.0]
		if _mast_y((a + b) * 0.5) > TRACK_SPACING_M:
			wire_tracks.append(TRACK_SPACING_M)
		for ty: float in wire_tracks:
			var messenger := PackedVector2Array()
			for i: int in 17:
				var f: float = i / 16.0
				var x: float = xm + f * MAST_PITCH_M
				messenger.append(
					proj(x, ty, MESSENGER_AT_MAST_M - MESSENGER_SAG_M * 4.0 * f * (1.0 - f))
				)
			draw_polyline(messenger, copper, lw)
			draw_line(
				proj(xm, ty, CONTACT_WIRE_M),
				proj(xm + MAST_PITCH_M, ty, CONTACT_WIRE_M),
				copper,
				lw * 1.3
			)
			for d: int in range(1, 8):
				var f2: float = d / 8.0
				var x2: float = xm + f2 * MAST_PITCH_M
				var zt: float = MESSENGER_AT_MAST_M - MESSENGER_SAG_M * 4.0 * f2 * (1.0 - f2)
				draw_line(
					proj(x2, ty, zt), proj(x2, ty, CONTACT_WIRE_M), copper, maxf(1.0, lw * 0.6)
				)
		var feeder_y: float = _mast_y((a + b) * 0.5)
		draw_line(proj(xm, feeder_y, 9.4), proj(xm + MAST_PITCH_M, feeder_y, 9.4), copper, lw)


func _platforms(far: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for st: Variant in stations.get("stations", []):
		var sd: Dictionary = st
		for p: Variant in sd["platforms"]:
			var pd: Dictionary = p
			var seg_id := StringName(str(pd["segment"]))
			var seg: TrackSegment = world.graph.get_segment(seg_id)
			var track_y: float = TRACK_SPACING_M if profile.is_far(seg_id) else 0.0
			var on_far: bool = str(pd["side"]) == "left"
			if on_far != far:
				continue
			(
				out
				. append(
					{
						"from": seg.chainage_at_a_m + float(pd["from_m"]),
						"to": seg.chainage_at_a_m + float(pd["to_m"]),
						"name": str(sd["name_uk"]),
						"track_y": track_y,
					}
				)
			)
	return out


func _draw_platform(p: Dictionary, near: bool) -> void:
	var visible_range: Vector2 = _visible_range(30.0)
	if float(p["to"]) < visible_range.x or float(p["from"]) > visible_range.y:
		return
	var a: float = float(p["from"])
	var b: float = float(p["to"])
	var ty: float = float(p["track_y"])
	var edge: float = ty - PLATFORM_EDGE_M if near else ty + PLATFORM_EDGE_M
	var back: float = edge - PLATFORM_DEPTH_M if near else edge + PLATFORM_DEPTH_M
	var face := Color("a9a59b")
	var top := Color("bdb9ae")
	if near:
		_wall(a, b, back, -BALLAST_DEPTH_M, PLATFORM_H_M, face.darkened(0.1))
	else:
		_wall(a, b, edge, -BALLAST_DEPTH_M, PLATFORM_H_M, face)
	_flat(a, b, minf(edge, back), maxf(edge, back), PLATFORM_H_M, top)
	var stripe_y: float = edge - 0.6 if near else edge + 0.6
	_flat(
		a,
		b,
		minf(stripe_y, stripe_y + 0.12),
		maxf(stripe_y, stripe_y + 0.12),
		PLATFORM_H_M + 0.005,
		Color("e8c22a")
	)
	# Slab joints.
	var k0: int = int(ceil(a / 6.0))
	var k1: int = int(floor(b / 6.0))
	for k: int in range(k0, k1 + 1):
		draw_line(
			proj(k * 6.0, edge, PLATFORM_H_M),
			proj(k * 6.0, back, PLATFORM_H_M),
			top.darkened(0.12),
			1.0
		)
	var sign_y: float = (edge + back) * 0.5
	for x: float in [a + 25.0, b - 25.0]:
		_station_sign(x, sign_y, PLATFORM_H_M, str(p["name"]))


func _station_sign(x: float, y: float, z0: float, title: String) -> void:
	var font: Font = get_theme_default_font()
	var post_w: float = maxf(2.0, 0.1 * ppm)
	for dx: float in [-1.4, 1.4]:
		draw_line(proj(x + dx, y, z0), proj(x + dx, y, z0 + 3.0), Color("39424a"), post_w)
	var c: Array[Vector2] = [
		proj(x - 2.3, y, z0 + 3.9),
		proj(x + 2.3, y, z0 + 3.9),
		proj(x + 2.3, y, z0 + 2.9),
		proj(x - 2.3, y, z0 + 2.9)
	]
	draw_colored_polygon(PackedVector2Array(c), Color("1b4f9c"))
	draw_polyline(PackedVector2Array(c + [c[0]]), Color("e9eef5"), maxf(1.0, 0.06 * ppm))
	var fs: int = int(clampf(0.5 * ppm, 8.0, 30.0))
	var tw: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var mid: Vector2 = (c[0] + c[2]) * 0.5
	draw_string(
		font,
		mid + Vector2(-tw * 0.5, fs * 0.35),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		Color.WHITE
	)


func _collect_speed_signs() -> void:
	_limits.clear()
	for s: TrackSegment in world.graph.segments.values():
		if profile.is_far(s.id) or is_nan(s.chainage_at_a_m):
			continue
		for l: Dictionary in s.speed_limits:
			(
				_limits
				. append(
					{
						"ch": s.chainage_at_a_m + float(l["from_m"]),
						"kmh": roundi(Units.ms_to_kmh(float(l["speed_ms"]))),
					}
				)
			)


## Kilometre and picket posts, speed boards and the whistle sign "С" on the near side.
func _draw_line_signs(rng: Vector2) -> void:
	var font: Font = get_theme_default_font()
	var y: float = -3.6
	var k0: int = int(ceil(rng.x / 100.0))
	var k1: int = int(floor(rng.y / 100.0))
	for k: int in range(k0, k1 + 1):
		var x: float = k * 100.0
		if x < profile.ch_min or x > profile.ch_max:
			continue
		var is_km: bool = k % 10 == 0
		var h: float = 1.5 if is_km else 0.75
		var base: Vector2 = proj(x, y, -BALLAST_DEPTH_M)
		var top: Vector2 = proj(x, y, -BALLAST_DEPTH_M + h)
		draw_line(base, top, Color("f2f0ea"), maxf(2.0, 0.22 * ppm))
		draw_line(top, top + Vector2(0, 0.12 * ppm), Color("202020"), maxf(2.0, 0.22 * ppm))
		var label: String = str(k / 10) if is_km else str(k % 10)
		var fs: int = int(clampf(0.4 * ppm, 7.0, 22.0))
		draw_string(
			font,
			top + Vector2(0.18 * ppm, 0.45 * ppm),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			Color("e8e8e8")
		)
	for l: Dictionary in _limits:
		var x2: float = float(l["ch"]) + 3.0
		if x2 > rng.x and x2 < rng.y:
			_board(x2, y, str(l["kmh"]))
	for st: Variant in stations.get("stations", []):
		var sd: Dictionary = st
		var pf: Dictionary = (sd["platforms"] as Array)[0]
		var seg: TrackSegment = world.graph.get_segment(StringName(str(pf["segment"])))
		var c: float = seg.chainage_at_a_m + (float(pf["from_m"]) + float(pf["to_m"])) * 0.5
		for x3: float in [c - 600.0, c + 600.0]:
			if x3 > rng.x and x3 < rng.y and x3 > profile.ch_min and x3 < profile.ch_max:
				_board(x3, y, "С")


func _board(x: float, y: float, text: String) -> void:
	var font: Font = get_theme_default_font()
	draw_line(proj(x, y, -BALLAST_DEPTH_M), proj(x, y, 2.4), Color("3b3f42"), maxf(1.5, 0.08 * ppm))
	var c: Array[Vector2] = [
		proj(x - 0.45, y, 3.1),
		proj(x + 0.45, y, 3.1),
		proj(x + 0.45, y, 2.35),
		proj(x - 0.45, y, 2.35)
	]
	draw_colored_polygon(PackedVector2Array(c), Color("f4f2ec"))
	draw_polyline(PackedVector2Array(c + [c[0]]), Color("1a1a1a"), maxf(1.0, 0.04 * ppm))
	var fs: int = int(clampf(0.48 * ppm, 7.0, 26.0))
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var mid: Vector2 = (c[0] + c[2]) * 0.5
	draw_string(
		font,
		mid + Vector2(-tw * 0.5, fs * 0.36),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		Color("1a1a1a")
	)


# ---------------------------------------------------------------- train


func _draw_train() -> void:
	var t: Train = world.player()
	var dir: float = _dir()
	var head_ch: float = _head_ch()
	var y0: float = TRACK_SPACING_M if profile.is_far(t.head.segment_id) else 0.0
	var lights: bool = t.cab.is_on(&"headlights") and t.power.control_on(t.cab)
	_doors = move_toward(
		_doors, 1.0 if t.cab.is_on(&"doors_left") else 0.0, get_process_delta_time() / 1.1
	)
	var base: Dictionary = {
		"doors": _doors,
		"lead_right": dir > 0.0,
		"panto_top": CONTACT_WIRE_M,
		"headlights": lights,
		"wheel_angle": _wheel_angle,
		"brake": t.brake_demand,
		"speed": t.speed_ms,
		"time": _time,
		"lit_windows": false,
	}
	var cars: Array[Dictionary] = []
	var behind: float = 0.0
	var n: int = t.consist.vehicles.size()
	for i: int in n:
		var v: VehicleSpec = t.consist.vehicles[i]
		if i > 0:
			behind += COUPLING_GAP_M
		var front_ch: float = head_ch - dir * behind
		var rear_ch: float = head_ch - dir * (behind + v.length_m)
		behind += v.length_m
		var opts: Dictionary = base.duplicate()
		var first: bool = i == 0
		var last: bool = i == n - 1
		opts["cab_right"] = (first and dir > 0.0) or (last and dir < 0.0)
		opts["cab_left"] = (first and dir < 0.0) or (last and dir > 0.0)
		opts["panto"] = t.power.pantograph_position if v.has_pantograph else -1.0
		var xa: float = minf(front_ch, rear_ch)
		var xb: float = maxf(front_ch, rear_ch)
		cars.append(
			{
				"v": v,
				"xa": xa,
				"xb": xb,
				"opts": opts,
				"first": first,
				"depth": depth((xa + xb) * 0.5, y0)
			}
		)
	for c: Dictionary in cars:
		c["gap_right"] = false
		for o: Dictionary in cars:
			if absf(float(o["xa"]) - float(c["xb"]) - COUPLING_GAP_M) < 0.01:
				c["gap_right"] = true
	cars.sort_custom(
		func(p: Dictionary, q: Dictionary) -> bool: return float(p["depth"]) > float(q["depth"])
	)
	for c: Dictionary in cars:
		_draw_car(c, y0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_car(c: Dictionary, y0: float) -> void:
	var v: VehicleSpec = c["v"]
	var opts: Dictionary = c["opts"]
	var xa: float = float(c["xa"])
	var xb: float = float(c["xb"])
	var half: float = float(v.visual.get("width_m", 3.48)) * 0.5
	var h_top: float = float(v.visual.get("height_m", 4.25))
	var along := Vector3(1, 0, 0)
	var down := Vector3(0, 0, -1)
	var across := Vector3(0, 1, 0)
	# Far wheels/bogies show through below the body on a tilted view; draw them first.
	draw_set_transform_matrix(plane(Vector3(xa, y0 + 0.85, 0.0), along, down))
	TrainPainter.draw_running_gear(self, v, opts)
	# End faces: the one facing the camera.
	var lead_right: bool = bool(opts["lead_right"])
	if _sy < -0.02:
		draw_set_transform_matrix(plane(Vector3(xb, y0, 0.0), across, down))
		_end_face(v, opts, bool(opts["cab_right"]), lead_right)
	elif _sy > 0.02:
		draw_set_transform_matrix(plane(Vector3(xa, y0, 0.0), across * -1.0, down))
		_end_face(v, opts, bool(opts["cab_left"]), not lead_right)
	draw_set_transform_matrix(plane(Vector3(xa, y0 - 0.85, 0.0), along, down))
	TrainPainter.draw_running_gear(self, v, opts)
	if bool(c["gap_right"]):
		draw_set_transform_matrix(plane(Vector3(xb, y0 - 1.0, 0.0), along, down))
		TrainPainter.draw_gangway(self, 0.0, COUPLING_GAP_M)
	draw_set_transform_matrix(plane(Vector3(xa, y0 - half, 0.0), along, down))
	TrainPainter.draw_side(self, v, livery, opts)
	if _sp > 0.02:
		draw_set_transform_matrix(plane(Vector3(xa, y0, h_top + 0.15), along, across))
		TrainPainter.draw_roof(self, v, livery, opts)
	var panto: float = float(opts["panto"])
	if panto >= 0.0:
		draw_set_transform_matrix(plane(Vector3(xa, y0, 0.0), along, down))
		TrainPainter.draw_pantograph(
			self, v.length_m * 0.5, -h_top - 0.2, CONTACT_WIRE_M, panto, opts
		)
		# Pan head is a bar across the car.
		var zh: float = lerpf(h_top + 0.2 + 0.32, CONTACT_WIRE_M, clampf(panto, 0.0, 1.0))
		var xc: float = xa + v.length_m * 0.5
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_line(
			proj(xc, y0 - 0.95, zh),
			proj(xc, y0 + 0.95, zh),
			Color(0.2, 0.2, 0.22),
			maxf(2.0, 0.08 * ppm)
		)
	if bool(c["first"]):
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var number_x: float = xb - 2.6 if lead_right else xa + 2.6
		var p: Vector2 = proj(number_x, y0 - half, 1.62)
		var font: Font = get_theme_default_font()
		var fs: int = int(clampf(0.32 * ppm, 7.0, 18.0))
		draw_string(
			font,
			p,
			fleet_number,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			fs,
			Color(str(livery.get("number", "#ffffff")))
		)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _end_face(v: VehicleSpec, opts: Dictionary, is_cab: bool, leading: bool) -> void:
	if is_cab:
		TrainPainter.draw_front(self, v, livery, opts, leading)
		return
	var half: float = float(v.visual.get("width_m", 3.48)) * 0.5
	var h_top: float = float(v.visual.get("height_m", 4.25))
	var floor_h: float = float(v.visual.get("floor_m", 1.2))
	var body := Color(str(livery["body"]))
	draw_rect(Rect2(-half, -h_top, half * 2.0, h_top - floor_h), body.darkened(0.25))
	draw_rect(Rect2(-0.6, -3.6, 1.2, 2.3), Color(0.1, 0.1, 0.1))


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
