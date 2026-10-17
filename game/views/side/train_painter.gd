class_name TrainPainter
extends RefCounted
## Draws a multiple-unit car in side elevation. All geometry in metres in a local frame:
## x from the car's left end (0) to its right end (length), y up = negative.
## The caller sets the canvas transform (position at rail level, scale = pixels per metre).

const STEEL := Color(0.16, 0.17, 0.17)
const STEEL_LIGHT := Color(0.42, 0.44, 0.44)
const GLASS := Color(0.12, 0.17, 0.22)
const GLASS_SHINE := Color(0.55, 0.68, 0.78, 0.35)
const RUBBER := Color(0.1, 0.1, 0.1)
const HEADLIGHT := Color(1.0, 0.95, 0.75)
const MARKER_WHITE := Color(1.0, 0.98, 0.9)
const MARKER_RED := Color(0.95, 0.12, 0.1)
const INSULATOR := Color(0.86, 0.82, 0.74)
const WHEEL_R: float = 0.525


## opts keys: cab_left, cab_right (bool), lead_right (bool: travel direction is to the right),
## panto (0..1 or -1 for none), panto_top (m above rail when fully up), headlights (bool),
## wheel_angle (rad), brake (0..1), speed (m/s), time (s), lit_windows (bool)
static func draw_car(ci: CanvasItem, v: VehicleSpec, livery: Dictionary, opts: Dictionary) -> void:
	draw_running_gear(ci, v, opts)
	draw_side(ci, v, livery, opts)
	draw_roof_profile(ci, v, livery, opts)
	var panto: float = float(opts.get("panto", -1.0))
	if panto >= 0.0:
		var h_top: float = float(v.visual.get("height_m", 4.25))
		draw_pantograph(
			ci, v.length_m * 0.5, -h_top - 0.2, float(opts.get("panto_top", 6.0)), panto, opts
		)


## Underframe equipment and bogies (in the plane of the near wheels).
static func draw_running_gear(ci: CanvasItem, v: VehicleSpec, opts: Dictionary) -> void:
	var vis: Dictionary = v.visual
	var floor_h: float = float(vis.get("floor_m", 1.2))
	var bogie_c: float = float(vis.get("bogie_centers_m", 15.0))
	var axle_s: float = float(vis.get("axle_spacing_m", 2.6))
	var mid: float = v.length_m * 0.5
	ci.draw_rect(Rect2(mid - 5.6, -floor_h, 11.2, 0.45), Color(0.2, 0.21, 0.21))
	for bx: float in [mid - 4.6, mid - 1.4, mid + 1.9]:
		ci.draw_rect(Rect2(bx, -floor_h + 0.05, 2.2, 0.55), Color(0.26, 0.27, 0.27))
		ci.draw_rect(Rect2(bx, -floor_h + 0.05, 2.2, 0.08), Color(0.34, 0.35, 0.35))
	for sign: float in [-1.0, 1.0]:
		_bogie(ci, mid + sign * bogie_c * 0.5, axle_s, opts)


## The body side seen square-on: shell, livery, doors, windows, cab side windows.
static func draw_side(ci: CanvasItem, v: VehicleSpec, livery: Dictionary, opts: Dictionary) -> void:
	var length: float = v.length_m
	var vis: Dictionary = v.visual
	var h_top: float = float(vis.get("height_m", 4.25))
	var floor_h: float = float(vis.get("floor_m", 1.2))
	var body := Color(str(livery["body"]))
	var stripe := Color(str(livery["stripe"]))
	var skirt := Color(str(livery["skirt"]))
	var front := Color(str(livery["front"]))
	var front_stripe := Color(str(livery["front_stripe"]))
	var frame := Color(str(livery["window_frame"]))
	var cab_l: bool = bool(opts.get("cab_left", false))
	var cab_r: bool = bool(opts.get("cab_right", false))
	var nose: float = 0.55
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0 if not cab_l else 0.15, -floor_h))
	pts.append(Vector2(length if not cab_r else length - 0.15, -floor_h))
	if cab_r:
		pts.append(Vector2(length, -2.3))
		pts.append(Vector2(length - nose, -h_top + 0.1))
	else:
		pts.append(Vector2(length, -h_top))
	if cab_l:
		pts.append(Vector2(nose, -h_top + 0.1))
		pts.append(Vector2(0.0, -2.3))
	else:
		pts.append(Vector2(0.0, -h_top))
	ci.draw_colored_polygon(pts, body)
	ci.draw_rect(Rect2(0.1, -floor_h - 0.32, length - 0.2, 0.32), skirt)
	ci.draw_rect(Rect2(0.2, -h_top + 0.02, length - 0.4, 0.12), body.lightened(0.18))
	ci.draw_rect(Rect2(0.15, -2.02, length - 0.3, 0.16), stripe)
	ci.draw_rect(Rect2(0.3, -3.22, length - 0.6, 0.06), stripe)
	if cab_r:
		_cab_end(ci, length, -1.0, h_top, floor_h, nose, front, front_stripe, frame, opts, "right")
	if cab_l:
		_cab_end(ci, 0.0, 1.0, h_top, floor_h, nose, front, front_stripe, frame, opts, "left")
	var door_w: float = 1.25
	var inset_l: float = 3.3 if cab_l else 1.4
	var inset_r: float = 3.3 if cab_r else 1.4
	for dx: float in [inset_l, length - inset_r - door_w]:
		_door(ci, dx, door_w, floor_h, frame, float(opts.get("doors", 0.0)))
	var win_from: float = inset_l + door_w + 0.5
	var win_to: float = length - inset_r - door_w - 0.5
	var n: int = int(vis.get("windows_per_side", 9))
	var pitch: float = (win_to - win_from) / n
	for i: int in n:
		var wx: float = win_from + i * pitch + 0.12
		_window(
			ci, Rect2(wx, -3.05, pitch - 0.24, 0.92), frame, bool(opts.get("lit_windows", false))
		)


## Roof silhouette and ventilators for the pure side view.
static func draw_roof_profile(
	ci: CanvasItem, v: VehicleSpec, livery: Dictionary, opts: Dictionary
) -> void:
	var length: float = v.length_m
	var h_top: float = float(v.visual.get("height_m", 4.25))
	var roof := Color(str(livery["roof"]))
	var cab_l: bool = bool(opts.get("cab_left", false))
	var cab_r: bool = bool(opts.get("cab_right", false))
	var rpts := PackedVector2Array(
		[
			Vector2(0.65 if cab_l else 0.0, -h_top + 0.02),
			Vector2(length - (0.65 if cab_r else 0.0), -h_top + 0.02),
			Vector2(length - (0.95 if cab_r else 0.25), -h_top - 0.2),
			Vector2(0.95 if cab_l else 0.25, -h_top - 0.2),
		]
	)
	ci.draw_colored_polygon(rpts, roof)
	ci.draw_line(
		Vector2(0.3, -h_top - 0.2), Vector2(length - 0.3, -h_top - 0.2), roof.lightened(0.25), 0.04
	)
	for k: int in 4:
		var rx: float = length * (0.18 + k * 0.21)
		ci.draw_rect(Rect2(rx, -h_top - 0.42, 1.1, 0.22), roof.darkened(0.25))
		ci.draw_rect(Rect2(rx + 0.1, -h_top - 0.46, 0.9, 0.05), roof.darkened(0.1))


## Roof seen from above. Local frame: x along the car (0..length), y across it
## (-width/2 .. width/2, positive = far side).
static func draw_roof(ci: CanvasItem, v: VehicleSpec, livery: Dictionary, opts: Dictionary) -> void:
	var length: float = v.length_m
	var half: float = float(v.visual.get("width_m", 3.48)) * 0.5
	var roof := Color(str(livery["roof"]))
	var cab_l: bool = bool(opts.get("cab_left", false))
	var cab_r: bool = bool(opts.get("cab_right", false))
	var x0: float = 0.75 if cab_l else 0.0
	var x1: float = length - (0.75 if cab_r else 0.0)
	ci.draw_rect(Rect2(x0, -half, x1 - x0, half * 2.0), roof)
	# Curved roof shading: darker towards the near and far edges.
	ci.draw_rect(Rect2(x0, -half, x1 - x0, half * 0.35), roof.darkened(0.12))
	ci.draw_rect(Rect2(x0, half * 0.65, x1 - x0, half * 0.35), roof.darkened(0.2))
	ci.draw_rect(Rect2(x0 + 0.2, -0.25, x1 - x0 - 0.4, 0.5), roof.lightened(0.1))
	if cab_l:
		ci.draw_rect(Rect2(0.0, -half + 0.25, 0.75, half * 2.0 - 0.5), Color(str(livery["front"])))
	if cab_r:
		ci.draw_rect(
			Rect2(length - 0.75, -half + 0.25, 0.75, half * 2.0 - 0.5), Color(str(livery["front"]))
		)
	for k: int in 4:
		var rx: float = length * (0.18 + k * 0.21)
		ci.draw_rect(Rect2(rx, -0.6, 1.1, 1.2), roof.darkened(0.3))
		ci.draw_rect(Rect2(rx + 0.1, -0.5, 0.9, 1.0), roof.darkened(0.15))
	if float(opts.get("panto", -1.0)) >= 0.0:
		var cx: float = length * 0.5
		ci.draw_rect(Rect2(cx - 1.3, -0.9, 2.6, 1.8), roof.darkened(0.35))
		for ix: float in [-0.9, 0.9]:
			for iy: float in [-0.6, 0.6]:
				ci.draw_circle(Vector2(cx + ix, iy), 0.13, INSULATOR)


## Cab end face. Local frame: x across the car (-width/2 .. width/2, left to right as seen),
## y up = negative height.
static func draw_front(
	ci: CanvasItem, v: VehicleSpec, livery: Dictionary, opts: Dictionary, leading: bool
) -> void:
	var half: float = float(v.visual.get("width_m", 3.48)) * 0.5
	var h_top: float = float(v.visual.get("height_m", 4.25))
	var floor_h: float = float(v.visual.get("floor_m", 1.2))
	var front := Color(str(livery["front"]))
	var front_stripe := Color(str(livery["front_stripe"]))
	var frame := Color(str(livery["window_frame"]))
	var face := PackedVector2Array(
		[
			Vector2(-half, -floor_h + 0.3),
			Vector2(half, -floor_h + 0.3),
			Vector2(half, -h_top + 0.3),
			Vector2(half - 0.35, -h_top),
			Vector2(-half + 0.35, -h_top),
			Vector2(-half, -h_top + 0.3),
		]
	)
	ci.draw_colored_polygon(face, front)
	ci.draw_rect(Rect2(-half, -2.02, half * 2.0, 0.18), front_stripe)
	ci.draw_rect(Rect2(-half, -floor_h - 0.02, half * 2.0, 0.3), Color(str(livery["skirt"])))
	# Two windscreen panes with a centre pillar.
	for sx: float in [-1.0, 1.0]:
		var pane := Rect2(
			Vector2(minf(sx * 0.08, sx * (half - 0.25)), -3.9), Vector2(half - 0.33, 1.25)
		)
		ci.draw_rect(pane.grow(0.06), frame)
		ci.draw_rect(pane, GLASS)
		ci.draw_rect(Rect2(pane.position, Vector2(pane.size.x, 0.25)), GLASS_SHINE)
	var lights: bool = bool(opts.get("headlights", false))
	var hl := Vector2(0.0, -h_top + 0.12)
	ci.draw_circle(hl, 0.2, Color(0.2, 0.2, 0.2))
	if leading and lights:
		ci.draw_circle(hl, 0.15, HEADLIGHT)
		ci.draw_circle(hl, 0.6, Color(1.0, 0.95, 0.75, 0.22))
		ci.draw_circle(hl, 1.3, Color(1.0, 0.95, 0.75, 0.07))
	for sx: float in [-1.0, 1.0]:
		var bl := Vector2(sx * (half - 0.45), -1.6)
		ci.draw_circle(bl, 0.13, Color(0.15, 0.15, 0.15))
		if lights:
			var c: Color = MARKER_WHITE if leading else MARKER_RED
			ci.draw_circle(bl, 0.1, c)
			ci.draw_circle(bl, 0.3, Color(c.r, c.g, c.b, 0.2))
	# Coupler and buffer beam.
	ci.draw_rect(Rect2(-half + 0.1, -1.0, half * 2.0 - 0.2, 0.2), Color(0.17, 0.17, 0.17))
	ci.draw_rect(Rect2(-0.25, -1.15, 0.5, 0.35), Color(0.12, 0.12, 0.12))


static func _bogie(ci: CanvasItem, x: float, axle_s: float, opts: Dictionary) -> void:
	var brake: float = float(opts.get("brake", 0.0))
	var speed: float = absf(float(opts.get("speed", 0.0)))
	var angle: float = float(opts.get("wheel_angle", 0.0))
	# Frame and springs.
	ci.draw_rect(Rect2(x - 1.75, -0.98, 3.5, 0.42), STEEL)
	ci.draw_rect(Rect2(x - 1.75, -0.98, 3.5, 0.07), STEEL_LIGHT)
	for sx: float in [-0.55, 0.55]:
		for k: int in 4:
			var yy: float = -1.12 + k * 0.05
			ci.draw_line(
				Vector2(x + sx - 0.18, yy), Vector2(x + sx + 0.18, yy + 0.02), STEEL_LIGHT, 0.035
			)
	for ax: float in [-axle_s * 0.5, axle_s * 0.5]:
		var c := Vector2(x + ax, -WHEEL_R)
		ci.draw_circle(c, WHEEL_R, RUBBER)
		ci.draw_arc(c, WHEEL_R - 0.03, 0.0, TAU, 28, STEEL_LIGHT, 0.05)
		ci.draw_circle(c, WHEEL_R * 0.72, Color(0.22, 0.23, 0.23))
		for k: int in 3:
			var a: float = angle + k * TAU / 3.0
			ci.draw_circle(
				c + Vector2(cos(a), sin(a)) * WHEEL_R * 0.45, 0.07, Color(0.12, 0.12, 0.12)
			)
		ci.draw_circle(c, 0.12, STEEL_LIGHT)
		# Axle box.
		ci.draw_rect(Rect2(c.x - 0.18, c.y - 0.2, 0.36, 0.32), STEEL)
		# Brake shoes: glow when braking at speed.
		for side: float in [-1.0, 1.0]:
			var shoe := Rect2(c.x + side * (WHEEL_R + 0.02) - 0.06, c.y - 0.2, 0.12, 0.4)
			ci.draw_rect(shoe, Color(0.3, 0.3, 0.3))
			if brake > 0.05 and speed > 1.0:
				var heat: float = clampf(brake * minf(speed / 15.0, 1.0), 0.0, 1.0)
				ci.draw_circle(
					shoe.get_center(), 0.16 + 0.1 * heat, Color(1.0, 0.45, 0.1, 0.25 + 0.5 * heat)
				)


static func _door(
	ci: CanvasItem, x: float, w: float, floor_h: float, frame: Color, opened: float = 0.0
) -> void:
	var top: float = -3.2
	ci.draw_rect(Rect2(x - 0.05, top - 0.05, w + 0.1, -floor_h - top + 0.1), frame)
	ci.draw_rect(Rect2(x, top, w, -floor_h - top), Color("101820"))
	for k: int in 2:
		var shift: float = (-1.0 if k == 0 else 1.0) * opened * w * .48
		var gx: float = x + k * w * .5 + shift
		ci.draw_rect(Rect2(gx, top, w * .5 - .02, -floor_h - top), frame.lightened(.12))
		ci.draw_rect(Rect2(gx + .12, top + .18, w * .5 - .24, .85), GLASS)
	# Step.
	ci.draw_rect(Rect2(x - 0.05, -floor_h + 0.02, w + 0.1, 0.12), STEEL)


static func _window(ci: CanvasItem, r: Rect2, frame: Color, lit: bool) -> void:
	ci.draw_rect(r.grow(0.06), frame)
	ci.draw_rect(r, Color(0.98, 0.86, 0.55) if lit else GLASS)
	var shine := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.22))
	ci.draw_rect(shine, GLASS_SHINE)
	ci.draw_line(
		Vector2(r.position.x, r.position.y + r.size.y * 0.42),
		Vector2(r.end.x, r.position.y + r.size.y * 0.42),
		frame,
		0.05
	)


static func _cab_end(
	ci: CanvasItem,
	x0: float,
	inward: float,
	h_top: float,
	floor_h: float,
	nose: float,
	front: Color,
	front_stripe: Color,
	frame: Color,
	opts: Dictionary,
	side: String
) -> void:
	var leading: bool = bool(opts.get("lead_right", true)) == (side == "right")
	var x_in: float = x0 + inward * 2.4
	var face := PackedVector2Array(
		[
			Vector2(x0 + inward * 0.15, -floor_h),
			Vector2(x_in, -floor_h),
			Vector2(x_in, -h_top + 0.1),
			Vector2(x0 + inward * nose, -h_top + 0.1),
			Vector2(x0, -2.3),
		]
	)
	ci.draw_colored_polygon(face, front)
	ci.draw_rect(Rect2(minf(x0, x_in), -2.02, 2.4, 0.16), front_stripe)
	# Cab side window and slanted windscreen.
	var cw_x: float = x0 + inward * 1.05
	ci.draw_rect(Rect2(minf(cw_x, cw_x + inward * 0.95), -3.2, 0.95, 0.9).grow(0.05), frame)
	ci.draw_rect(Rect2(minf(cw_x, cw_x + inward * 0.95), -3.2, 0.95, 0.9), GLASS)
	var ws := PackedVector2Array(
		[
			Vector2(x0 + inward * 0.12, -2.55),
			Vector2(x0 + inward * 0.42, -2.55),
			Vector2(x0 + inward * (nose + 0.05), -h_top + 0.35),
			Vector2(x0 + inward * (nose - 0.12), -h_top + 0.35),
		]
	)
	ci.draw_colored_polygon(ws, GLASS)
	# Headlight on the roof dome and buffer lights below the windscreen.
	var hl := Vector2(x0 + inward * (nose + 0.15), -h_top - 0.02)
	ci.draw_circle(hl, 0.16, Color(0.2, 0.2, 0.2))
	var lights_on: bool = bool(opts.get("headlights", false))
	if leading and lights_on:
		ci.draw_circle(hl, 0.12, HEADLIGHT)
		ci.draw_circle(hl, 0.35, Color(1.0, 0.95, 0.75, 0.25))
		ci.draw_circle(hl, 0.7, Color(1.0, 0.95, 0.75, 0.08))
	for dy: float in [-1.55]:
		var bl := Vector2(x0 + inward * 0.25, dy)
		var c: Color = MARKER_WHITE if leading else MARKER_RED
		ci.draw_circle(bl, 0.1, Color(0.15, 0.15, 0.15))
		if lights_on:
			ci.draw_circle(bl, 0.075, c)
			ci.draw_circle(bl, 0.22, Color(c.r, c.g, c.b, 0.18))
	# Coupler.
	ci.draw_rect(Rect2(x0 - inward * 0.35 - 0.2, -1.05, 0.4, 0.18), Color(0.14, 0.14, 0.14))


## Diamond pantograph (in the car's centre plane).
## `pos` 0 = folded, 1 = head at `top` metres above the rail.
static func draw_pantograph(
	ci: CanvasItem, cx: float, base_y: float, top: float, pos: float, opts: Dictionary
) -> void:
	var folded_h: float = 0.32
	# base_y is negative (the roof), so this is the head height above the roof.
	var full_h: float = top + base_y
	var h: float = lerpf(folded_h, full_h, clampf(pos, 0.0, 1.0))
	var head_y: float = base_y - h
	var arm: float = maxf(full_h * 0.5 + 0.15, 1.0)
	var half: float = h * 0.5
	var kx: float = sqrt(maxf(arm * arm - half * half, 0.0))
	var col := Color(0.18, 0.18, 0.2)
	# Base frame on insulators.
	for ix: float in [-0.9, 0.9]:
		ci.draw_rect(Rect2(cx + ix - 0.08, base_y - 0.18, 0.16, 0.18), INSULATOR)
	ci.draw_line(Vector2(cx - 1.1, base_y - 0.2), Vector2(cx + 1.1, base_y - 0.2), col, 0.06)
	var bl := Vector2(cx - 0.35, base_y - 0.2)
	var br := Vector2(cx + 0.35, base_y - 0.2)
	var kl := Vector2(cx - kx * 0.55, base_y - 0.2 - half)
	var kr := Vector2(cx + kx * 0.55, base_y - 0.2 - half)
	var hd := Vector2(cx, head_y)
	for seg: PackedVector2Array in [
		PackedVector2Array([bl, kl, hd]), PackedVector2Array([br, kr, hd])
	]:
		ci.draw_polyline(seg, col, 0.06)
	ci.draw_line(kl, kr, Color(col, 0.6), 0.03)
	# Head with horns and carbon strip.
	ci.draw_line(Vector2(cx - 0.8, head_y), Vector2(cx + 0.8, head_y), col, 0.08)
	ci.draw_line(Vector2(cx - 0.8, head_y), Vector2(cx - 1.0, head_y + 0.18), col, 0.05)
	ci.draw_line(Vector2(cx + 0.8, head_y), Vector2(cx + 1.0, head_y + 0.18), col, 0.05)
	ci.draw_line(
		Vector2(cx - 0.65, head_y - 0.03),
		Vector2(cx + 0.65, head_y - 0.03),
		Color(0.35, 0.35, 0.38),
		0.04
	)
	# Arcing at speed when touching the wire.
	var speed: float = absf(float(opts.get("speed", 0.0)))
	var t: float = float(opts.get("time", 0.0))
	if pos >= 1.0 and speed > 4.0 and fmod(t * 7.3 + cx, 1.0) < 0.12:
		var sp := Vector2(cx + sin(t * 31.0) * 0.5, head_y - 0.05)
		ci.draw_circle(sp, 0.22, Color(0.7, 0.85, 1.0, 0.35))
		ci.draw_circle(sp, 0.08, Color(1, 1, 1, 0.95))


## Rubber gangway between two coupled cars, `x` = left car's right end.
static func draw_gangway(ci: CanvasItem, x: float, gap: float) -> void:
	ci.draw_rect(Rect2(x - 0.1, -3.55, gap + 0.2, 2.25), RUBBER)
	for k: int in 5:
		var yy: float = -3.4 + k * 0.42
		ci.draw_line(Vector2(x, yy), Vector2(x + gap, yy), Color(0.2, 0.2, 0.2), 0.03)
