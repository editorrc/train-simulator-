class_name CabNose
extends RefCounted
## Driver's cab nose of an ER9-family multiple unit, generated as one smooth surface.
## Visual reconstruction (not factory CAD). Side profile, from the buffer beam up:
## a vertical lower front, windscreens leaning back, then the roof dome with the headlight.
## In plan the front wraps round the side walls with a rounded corner.
##
## Local frame of the car body: x across (±half width), y up from the rail head, z along
## the car with the nose tip at `tip_z` and the body behind it (+z). Everything placed on the
## nose (stripes, windscreens, lamps) is built as a patch that follows the same surface, so
## lean and curvature always match.

const FLOOR_Y: float = 1.22
const SIDE_TOP_Y: float = 3.70
const ROOF_RISE: float = 0.55
const HALF_WIDTH: float = 1.70
const CHAMFER: float = 0.20
## Height where the windscreen lean starts and ends, and how far it leans back (m).
const LEAN_FROM_Y: float = 2.35
const LEAN_TO_Y: float = 3.80
const LEAN_BACK: float = 0.38
## The roof dome sweeps back this far above the windscreens.
const DOME_BACK: float = 1.12
const CORNER_R: float = 0.42
## The flat-type front is slightly convex in plan: corners sit this far behind the centre.
const PLAN_BULGE: float = 0.1
## Length of the nose section before the regular body shell starts.
const LENGTH: float = 1.6

var tip_z: float = 0.0


func _init(p_tip_z: float) -> void:
	tip_z = p_tip_z


## Half width of the body cross-section at height y.
static func half_at(y: float) -> float:
	if y < FLOOR_Y + CHAMFER:
		return HALF_WIDTH - CHAMFER + (y - FLOOR_Y)
	if y <= SIDE_TOP_Y:
		return HALF_WIDTH
	var s: float = clampf((y - SIDE_TOP_Y) / ROOF_RISE, 0.0, 1.0)
	return HALF_WIDTH * sqrt(maxf(1.0 - s * s, 0.0))


static func top_y() -> float:
	return SIDE_TOP_Y + ROOF_RISE


## How far the front surface is set back from the tip at height y, on the centre line.
static func profile_back(y: float) -> float:
	if y <= LEAN_FROM_Y:
		return 0.0
	if y <= LEAN_TO_Y:
		return LEAN_BACK * (y - LEAN_FROM_Y) / (LEAN_TO_Y - LEAN_FROM_Y)
	var s: float = clampf((y - LEAN_TO_Y) / (top_y() - LEAN_TO_Y), 0.0, 1.0)
	return LEAN_BACK + DOME_BACK * (1.0 - sqrt(maxf(1.0 - s * s, 0.0)))


## Extra set-back towards the side walls (rounded corner in plan).
static func corner_back(x: float, y: float) -> float:
	var half: float = half_at(y)
	var r: float = minf(CORNER_R, half)
	var into: float = absf(x) - (half - r)
	if into <= 0.0:
		return 0.0
	return r - sqrt(maxf(r * r - into * into, 0.0))


func point(x: float, y: float) -> Vector3:
	var u: float = x / maxf(half_at(y), .01)
	return Vector3(x, y, tip_z + profile_back(y) + corner_back(x, y) + PLAN_BULGE * u * u)


## Outward surface normal (points forward, away from the body).
func normal(x: float, y: float) -> Vector3:
	var e: float = 0.01
	var half: float = half_at(y)
	var x0: float = clampf(x - e, -half, half)
	var x1: float = clampf(x + e, -half, half)
	var y0: float = maxf(y - e, FLOOR_Y)
	var y1: float = minf(y + e, top_y())
	var du: Vector3 = point(x1, y) - point(x0, y)
	var dv: Vector3 = point(x, y1) - point(x, y0)
	var n: Vector3 = dv.cross(du).normalized()
	return n if n.z < 0.0 else -n


## The nose shell: front surface plus the short side/roof skin back to the body shell.
func build_shell(parent: Node3D, paint: Material) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: PackedFloat32Array = _rows()
	var cols: int = 28
	var grid: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for y: float in rows:
		var line := PackedVector3Array()
		var nline := PackedVector3Array()
		var half: float = half_at(y)
		for c: int in cols + 1:
			# Denser columns towards the corners, where the surface turns.
			var u: float = sin((float(c) / cols * 2.0 - 1.0) * PI * 0.5)
			var x: float = u * half
			line.append(point(x, y))
			nline.append(normal(x, y))
		grid.append(line)
		normals.append(nline)
	for r: int in rows.size() - 1:
		for c: int in cols:
			_tri(
				tool,
				[grid[r][c], grid[r + 1][c], grid[r + 1][c + 1]],
				[normals[r][c], normals[r + 1][c], normals[r + 1][c + 1]]
			)
			_tri(
				tool,
				[grid[r][c], grid[r + 1][c + 1], grid[r][c + 1]],
				[normals[r][c], normals[r + 1][c + 1], normals[r][c + 1]]
			)
	# Skin from the edge of the front surface back to where the body shell starts.
	var back_z: float = tip_z + LENGTH + PLAN_BULGE
	for r: int in rows.size() - 1:
		for side: int in [0, cols]:
			var a: Vector3 = grid[r][side]
			var b: Vector3 = grid[r + 1][side]
			var na: Vector3 = _section_normal(a)
			var nb: Vector3 = _section_normal(b)
			var a2 := Vector3(a.x, a.y, back_z)
			var b2 := Vector3(b.x, b.y, back_z)
			if side == 0:
				_tri(tool, [a, a2, b2], [na, na, nb])
				_tri(tool, [a, b2, b], [na, nb, nb])
			else:
				_tri(tool, [a, b2, a2], [na, nb, na])
				_tri(tool, [a, b, b2], [na, nb, nb])
	var shell := MeshInstance3D.new()
	shell.mesh = tool.commit()
	shell.material_override = paint
	parent.add_child(shell)
	return shell


static func _section_normal(p: Vector3) -> Vector3:
	if p.y <= SIDE_TOP_Y:
		return Vector3(signf(p.x) if p.x != 0.0 else 1.0, 0, 0)
	return (
		Vector3(p.x / (HALF_WIDTH * HALF_WIDTH), (p.y - SIDE_TOP_Y) / (ROOF_RISE * ROOF_RISE), 0)
		. normalized()
	)


static func _rows() -> PackedFloat32Array:
	var rows := PackedFloat32Array()
	var y: float = FLOOR_Y
	while y < top_y() - 0.001:
		rows.append(y)
		# Finer steps where the profile bends: chamfer, lean start and the dome.
		var step: float = 0.06 if y < FLOOR_Y + CHAMFER or y > LEAN_TO_Y - 0.1 else 0.14
		if absf(y - LEAN_FROM_Y) < 0.15:
			step = 0.05
		y = minf(y + step, top_y())
	rows.append(top_y() - 0.002)
	return rows


static func _tri(tool: SurfaceTool, pts: Array, ns: Array) -> void:
	for i: int in 3:
		tool.set_normal(ns[i])
		tool.add_vertex(pts[i])


## A decal-like piece of surface (stripe, frame, glass) lying on the nose.
## `y_from` / `y_to` give the band edges as functions of x; `lift` raises it off the paint.
func patch(
	parent: Node3D,
	mat: Material,
	x_from: float,
	x_to: float,
	y_from: Callable,
	y_to: Callable,
	lift: float = 0.006
) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols: int = maxi(4, int(absf(x_to - x_from) / 0.08))
	var rows: int = 6
	var grid: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for c: int in cols + 1:
		var x: float = lerpf(x_from, x_to, float(c) / cols)
		var line := PackedVector3Array()
		var nline := PackedVector3Array()
		for r: int in rows + 1:
			var y: float = lerpf(float(y_from.call(x)), float(y_to.call(x)), float(r) / rows)
			var xc: float = clampf(x, -half_at(y), half_at(y))
			var n: Vector3 = normal(xc, y)
			line.append(point(xc, y) + n * lift)
			nline.append(n)
		grid.append(line)
		normals.append(nline)
	for c: int in cols:
		for r: int in rows:
			_tri(
				tool,
				[grid[c][r], grid[c + 1][r + 1], grid[c + 1][r]],
				[normals[c][r], normals[c + 1][r + 1], normals[c + 1][r]]
			)
			_tri(
				tool,
				[grid[c][r], grid[c][r + 1], grid[c + 1][r + 1]],
				[normals[c][r], normals[c][r + 1], normals[c + 1][r + 1]]
			)
	var item := MeshInstance3D.new()
	item.mesh = tool.commit()
	item.material_override = mat
	parent.add_child(item)
	return item


## Basis whose -z looks out of the nose at (x, y): use it to mount lamps and plates.
func mount(x: float, y: float) -> Transform3D:
	var n: Vector3 = normal(x, y)
	var up: Vector3 = Vector3.UP - n * Vector3.UP.dot(n)
	var basis := Basis(up.cross(-n).normalized(), up.normalized(), -n)
	return Transform3D(basis, point(x, y))


## Like mount(), but looking straight ahead along the car (for lamps that must not
## follow the curvature of the roof dome).
func mount_level(x: float, y: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, point(x, y))


static func const_y(value: float) -> Callable:
	return func(_x: float) -> float: return value
