class_name TrainCar3D
extends Node3D
## Visual reconstruction, not factory CAD. Wheels stay on the rails; only the body sways.

static var _shared_wheel_meshes: Dictionary[String, Mesh] = {}

var doors: Array[Dictionary] = []
var lamp: SpotLight3D
var pantograph: Node3D
var body: Node3D
var trucks: Array[Node3D] = []
var reversed_body: bool = false
var suspension := RailSuspension.new()
var wheels: Array[MultiMesh] = []
var _wheel_offsets: Array[Transform3D] = []
var _wheel_radius: float = .525
var _wheel_distance: float = INF
var _wheel_meshes: Array[Mesh] = []
var _wheel_lod: int = 2
var _door_left: float = 0.0
var _door_right: float = 0.0
var _length: float = 20.0
var _pantograph_arms: MultiMesh
var _pantograph_bar: MeshInstance3D
var _pantograph_position: float = INF


static func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.65
	return mat


static func box(parent: Node3D, at: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = mat
	item.position = at
	parent.add_child(item)
	return item


static func cylinder(
	parent: Node3D, at: Vector3, radius: float, height: float, mat: Material, segments: int = 40
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = mat
	item.position = at
	parent.add_child(item)
	return item


func build(spec: VehicleSpec, livery: Dictionary, cab: bool) -> void:
	_length = spec.length_m - 2.0 * float(spec.visual.get("body_end_inset_m", .35))
	var end: float = _length * 0.5
	var paint: StandardMaterial3D = material(Color(str(livery.get("body", "#287958"))), 0.25)
	var door_paint: StandardMaterial3D = material(
		Color(str(livery.get("doors", livery.get("body", "#287958")))), .25
	)
	var roof: StandardMaterial3D = material(Color(str(livery.get("roof", "#88928c"))), 0.2)
	var stripe: StandardMaterial3D = material(Color(str(livery.get("stripe", "#e9d37c"))))
	var steel: StandardMaterial3D = material(Color("667078"), 0.7)
	var dark: StandardMaterial3D = material(Color("171e24"), 0.3)
	var glass: StandardMaterial3D = material(Color("253e4a"), 0.5)
	var black: StandardMaterial3D = material(Color("0d1418"))
	body = Node3D.new()
	add_child(body)
	box(body, Vector3(0, 1.16, 0), Vector3(3.05, 0.30, _length - 0.25), dark)
	var rear: float = end - 0.15
	var front: float = -end + (1.6 if cab else 0.15)
	_rounded_shell(front, rear, paint, roof)
	box(body, Vector3(0, 0.9, -1), Vector3(2.0, 0.5, 6.0), dark)
	for side: float in [-1.0, 1.0]:
		if livery.has("lower_body"):
			box(
				body,
				Vector3(side * 1.721, 1.85, (front + rear) * .5),
				Vector3(.025, 1.15, rear - front),
				material(Color(str(livery["lower_body"])), .25)
			)
		box(
			body,
			Vector3(side * 1.71, 2.0, (front + rear) * 0.5),
			Vector3(0.025, 0.20, rear - front),
			stripe
		)
		# Shallow pressed ribs and sill trim remain in the same rigid mesh batch.
		for y: float in [1.46, 1.55, 1.64, 1.73, 1.82, 2.24, 2.33, 2.42]:
			box(
				body,
				Vector3(side * 1.726, y, (front + rear) * .5),
				Vector3(.028, .018, rear - front),
				paint
			)
		var windows: int = int(spec.visual.get("windows_per_side", 9))
		for i: int in windows:
			var z: float = lerpf(-end + 4.0, end - 4.0, float(i) / maxf(windows - 1, 1))
			box(body, Vector3(side * 1.716, 3.12, z), Vector3(0.04, 1.05, 1.25), black)
			box(body, Vector3(side * 1.744, 3.12, z), Vector3(0.025, 0.92, 1.12), glass)
			box(body, Vector3(side * 1.76, 3.37, z), Vector3(0.025, 0.025, 1.12), steel)
		for z: float in [-end + 2.6, end - 2.6]:
			box(body, Vector3(side * 1.73, 2.28, z), Vector3(0.025, 2.13, 1.28), black)
			for leaf: float in [-1.0, 1.0]:
				var panel := Node3D.new()
				panel.position = Vector3(side * 1.77, 0, z + leaf * 0.31)
				body.add_child(panel)
				box(panel, Vector3(0, 2.28, 0), Vector3(0.035, 2.06, 0.6), door_paint)
				box(panel, Vector3(side * 0.025, 2.95, 0), Vector3(0.02, 0.72, 0.43), glass)
				doors.append({"node": panel, "base": panel.position.z, "leaf": leaf, "side": side})
	var bogie_half: float = float(spec.visual.get("bogie_centers_m", 15.0)) * .5
	var axle_half: float = float(spec.visual.get("axle_spacing_m", 2.6)) * .5
	var radius: float = float(spec.visual.get("wheel_diameter_m", 1.05)) * .5
	_wheel_radius = radius
	for segments: int in [8, 16, 40]:
		_wheel_meshes.append(_wheel_mesh(radius, steel, dark, segments))
	var wheel_mesh: Mesh = _wheel_meshes[_wheel_lod]
	for axle: float in [-axle_half, axle_half]:
		_wheel_offsets.append(Transform3D(Basis.IDENTITY, Vector3(0, radius, axle)))
	for z: float in [-bogie_half, bogie_half]:
		var truck := Node3D.new()
		truck.position.z = z
		add_child(truck)
		trucks.append(truck)
		box(truck, Vector3(0, .65, 0), Vector3(2.45, .4, 3.2), dark)
		for side: float in [-1.0, 1.0]:
			box(truck, Vector3(side * 1.12, .70, 0), Vector3(.22, .32, 2.9), steel)
			for axle: float in [-axle_half, axle_half]:
				box(truck, Vector3(side * 1.21, .58, axle), Vector3(.28, .30, .33), dark)
				for coil: int in 4:
					cylinder(
						truck,
						Vector3(side * 1.1, .87 + coil * .055, axle * .55),
						.16,
						.025,
						steel,
						12
					)
		RigidMeshBatch.merge(truck)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = wheel_mesh
		multi.instance_count = _wheel_offsets.size()
		for index: int in _wheel_offsets.size():
			multi.set_instance_transform(index, _wheel_offsets[index])
		var wheel_instances := MultiMeshInstance3D.new()
		wheel_instances.multimesh = multi
		wheel_instances.material_override = RigidMeshBatch.material()
		truck.add_child(wheel_instances)
		wheels.append(multi)
	for z: float in [-end - .25, end + .25]:
		box(self, Vector3(0, 1.0, z), Vector3(.35, .22, .50), steel)
	if spec.has_pantograph:
		_build_pantograph(dark)
	if cab:
		_cab(
			end,
			material(Color(str(livery.get("front", livery.get("body", "#287958")))), .25),
			material(Color(str(livery.get("front_stripe", livery.get("stripe", "#e9d37c"))))),
			glass,
			black,
			steel
		)
		_cab_roof(end, roof)
	var moving: Array[Node3D] = []
	if pantograph != null:
		moving.append(pantograph)
	for door: Dictionary in doors:
		var panel: Node3D = door["node"]
		moving.append(panel)
		RigidMeshBatch.merge(panel)
	RigidMeshBatch.merge(body, moving)
	var separate: Array[Node3D] = [body]
	separate.append_array(trucks)
	RigidMeshBatch.merge(self, separate)


func _build_pantograph(dark: Material) -> void:
	pantograph = Node3D.new()
	body.add_child(pantograph)
	var rod := BoxMesh.new()
	rod.size = Vector3(.06, 1, .06)
	_pantograph_arms = MultiMesh.new()
	_pantograph_arms.transform_format = MultiMesh.TRANSFORM_3D
	_pantograph_arms.mesh = rod
	_pantograph_arms.instance_count = 8
	var arms := MultiMeshInstance3D.new()
	arms.multimesh = _pantograph_arms
	arms.material_override = dark
	pantograph.add_child(arms)
	_pantograph_bar = box(pantograph, Vector3(0, 6, 0), Vector3(1.9, .08, .18), dark)
	for x: float in [-.55, .55]:
		for z: float in [-.8, .8]:
			cylinder(body, Vector3(x, 4.38, z), .12, .2, material(Color("6a4836")), 16)
	_animate_pantograph(1.0)


func _animate_pantograph(position: float) -> void:
	if _pantograph_arms == null or position == _pantograph_position:
		return
	var base: float = 4.55
	var top: float = lerpf(4.75, 6.0, position)
	var half_height: float = (top - base) * .5
	var spread: float = sqrt(1.0 - half_height * half_height)
	var index: int = 0
	for x: float in [-.55, .55]:
		for side: float in [-1.0, 1.0]:
			var middle := Vector3(x, (top + base) * .5, side * spread)
			for end: Vector3 in [Vector3(x, base, 0), Vector3(x, top, 0)]:
				var direction: Vector3 = (end - middle).normalized()
				var basis := Basis(Vector3.RIGHT, direction, Vector3.RIGHT.cross(direction))
				_pantograph_arms.set_instance_transform(
					index, Transform3D(basis, (middle + end) * .5)
				)
				index += 1
	_pantograph_bar.position.y = top
	_pantograph_position = position


func _wheel_mesh(radius: float, steel: Material, dark: Material, segments: int) -> Mesh:
	var key: String = "%f:%d" % [radius, segments]
	if _shared_wheel_meshes.has(key):
		return _shared_wheel_meshes[key]
	var part := Node3D.new()
	var shaft: MeshInstance3D = cylinder(part, Vector3.ZERO, .09, 2.7, steel, segments)
	shaft.rotation.z = PI / 2
	for x: float in [-.84, .84]:
		var tread: MeshInstance3D = cylinder(part, Vector3(x, 0, 0), radius, .16, steel, segments)
		tread.rotation.z = PI / 2
		var web: MeshInstance3D = cylinder(
			part, Vector3(x, 0, 0), radius * .83, .165, dark, segments
		)
		web.rotation.z = PI / 2
		var flange: MeshInstance3D = cylinder(
			part, Vector3(x - signf(x) * .067, 0, 0), radius + .025, .025, steel, segments
		)
		flange.rotation.z = PI / 2
		var hub: MeshInstance3D = cylinder(part, Vector3(x, 0, 0), .16, .24, steel, segments)
		hub.rotation.z = PI / 2
	var merged: MeshInstance3D = RigidMeshBatch.merge(part)
	var result: Mesh = merged.mesh
	part.free()
	_shared_wheel_meshes[key] = result
	return result


func update_detail(projected_diameter_px: float) -> void:
	var level: int = 0 if projected_diameter_px < 8 else (1 if projected_diameter_px < 20 else 2)
	if level == _wheel_lod:
		return
	for multi: MultiMesh in wheels:
		multi.mesh = _wheel_meshes[level]
	_wheel_lod = level


func _cab(
	end: float, paint: Material, stripe: Material, glass: Material, black: Material, steel: Material
) -> void:
	# Sloped and tapered front mask, with an octagonal rear cross-section.
	var back: PackedVector3Array = _section(-end + 1.6, 1.7, 1.22, 4.12)
	var face: PackedVector3Array = _section(-end, 1.51, 1.32, 3.85)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in back.size():
		var j: int = (i + 1) % back.size()
		_quad(surface, [back[i], back[j], face[j], face[i]])
	_quad(surface, [face[0], face[1], face[2], face[3], face[4], face[5], face[6], face[7]])
	surface.generate_normals()
	var shell := MeshInstance3D.new()
	shell.mesh = surface.commit()
	var mat: StandardMaterial3D = (paint as StandardMaterial3D).duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material_override = mat
	body.add_child(shell)
	box(body, Vector3(0, 2.12, -end - .035), Vector3(2.95, .22, .045), stripe)
	for x: float in [-.77, .77]:
		var frame: MeshInstance3D = box(
			body, Vector3(x, 3.25, -end - .04), Vector3(1.25, .80, .055), black
		)
		frame.rotation.x = -.12
		box(frame, Vector3(0, 0, -.035), Vector3(1.10, .66, .025), glass)
		var wiper: MeshInstance3D = box(
			frame, Vector3(.10, -.14, -.06), Vector3(.42, .025, .02), steel
		)
		wiper.rotation.z = .30
	for side: float in [-1.0, 1.0]:
		var window: MeshInstance3D = box(
			body, Vector3(side * 1.61, 3.2, -end + .94), Vector3(.04, .82, .85), black
		)
		box(window, Vector3(side * .025, 0, 0), Vector3(.025, .69, .72), glass)
		box(body, Vector3(side * 1.35, 2.40, -end - .09), Vector3(.035, 1.05, .035), steel)
	for y: float in [.65, .90]:
		box(body, Vector3(0, y, -end - .10), Vector3(.72, .06, .24), steel)
	for x: float in [-1.1, 1.1]:
		var housing: MeshInstance3D = cylinder(body, Vector3(x, 1.72, -end - .07), .18, .12, black)
		housing.rotation.x = PI / 2.0
		cylinder(housing, Vector3(0, -.08, 0), .13, .025, material(Color("e1d3a5")))
	var top: MeshInstance3D = cylinder(body, Vector3(0, 3.88, -end - .04), .25, .17, steel)
	top.rotation.x = PI / 2.0
	var lens_mat: StandardMaterial3D = material(Color("fff2d2"))
	lens_mat.emission_enabled = true
	lens_mat.emission = Color("fff0c0")
	cylinder(top, Vector3(0, -.10, 0), .19, .025, lens_mat)
	for y: float in [2.33, 2.40, 2.47, 2.54]:
		box(body, Vector3(0, y, -end - .035), Vector3(1.6, .025, .025), black)
	var badge := Label3D.new()
	badge.text = "ЕР9М"
	badge.font_size = 48
	badge.pixel_size = .007
	badge.position = Vector3(0, 2.74, -end - .06)
	badge.rotation.y = PI
	body.add_child(badge)
	lamp = SpotLight3D.new()
	lamp.position = Vector3(0, 3.88, -end - .2)
	lamp.rotation.x = deg_to_rad(-3)
	lamp.spot_range = 120
	lamp.spot_angle = 23
	lamp.light_energy = 7
	lamp.light_color = Color("ffe5b5")
	body.add_child(lamp)
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.0
	beam_mesh.bottom_radius = 7.5
	beam_mesh.height = 50.0
	beam_mesh.radial_segments = 24
	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	var haze := StandardMaterial3D.new()
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.cull_mode = BaseMaterial3D.CULL_DISABLED
	haze.albedo_color = Color(1.0, .89, .62, .025)
	beam.material_override = haze
	beam.position.z = -25.0
	beam.rotation.x = PI / 2.0
	lamp.add_child(beam)


func _cab_roof(end: float, roof: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 20:
		var a: float = PI * i / 20.0
		var b: float = PI * (i + 1) / 20.0
		var points: Array[Vector3] = [
			Vector3(cos(a) * 1.53, 3.79 + sin(a) * .53, -end - .02),
			Vector3(cos(b) * 1.53, 3.79 + sin(b) * .53, -end - .02),
			Vector3(cos(b) * 1.7, 3.70 + sin(b) * .55, -end + 1.65),
			Vector3(cos(a) * 1.7, 3.70 + sin(a) * .55, -end + 1.65)
		]
		for index: int in [0, 2, 1, 0, 3, 2]:
			var point: Vector3 = points[index]
			tool.set_normal(Vector3(point.x / 1.6, (point.y - 3.7) / .55, 0).normalized())
			tool.add_vertex(point)
		tool.set_normal(Vector3(0, 0, -1))
		for point: Vector3 in [Vector3(0, 3.79, -end - .02), points[1], points[0]]:
			tool.add_vertex(point)
	var shell := MeshInstance3D.new()
	shell.mesh = tool.commit()
	shell.material_override = roof
	body.add_child(shell)


static func _section(z: float, half: float, floor_y: float, roof_y: float) -> PackedVector3Array:
	return PackedVector3Array(
		[
			Vector3(-half + .2, floor_y, z),
			Vector3(half - .2, floor_y, z),
			Vector3(half, floor_y + .2, z),
			Vector3(half, roof_y - .3, z),
			Vector3(half - .3, roof_y, z),
			Vector3(-half + .3, roof_y, z),
			Vector3(-half, roof_y - .3, z),
			Vector3(-half, floor_y + .2, z)
		]
	)


static func _quad(surface: SurfaceTool, points: Array) -> void:
	for i: int in range(1, points.size() - 1):
		for index: int in [0, i + 1, i]:
			surface.add_vertex(points[index])


func animate(t: Train, distance: float, dt: float, leading: bool, _clock_s: float) -> void:
	_animate_pantograph(t.power.pantograph_position)
	_door_left = move_toward(
		_door_left,
		1.0 if t.cab.is_on(&"doors_right" if reversed_body else &"doors_left") else 0.0,
		dt / 1.1
	)
	_door_right = move_toward(
		_door_right,
		1.0 if t.cab.is_on(&"doors_left" if reversed_body else &"doors_right") else 0.0,
		dt / 1.1
	)
	for item: Dictionary in doors:
		var panel: Node3D = item["node"]
		panel.position.z = (
			float(item["base"])
			+ float(item["leaf"]) * .60 * (_door_left if float(item["side"]) < 0 else _door_right)
		)
	if distance != _wheel_distance:
		var spin := Basis(Vector3.RIGHT, fmod(-distance / _wheel_radius, TAU))
		for multi: MultiMesh in wheels:
			for index: int in _wheel_offsets.size():
				var local: Transform3D = _wheel_offsets[index]
				local.basis = spin * local.basis
				multi.set_instance_transform(index, local)
		_wheel_distance = distance
	var sway: float = float(Settings.get_value("camera", "sway", 1.0))
	body.rotation = Vector3(
		suspension.pitch * sway, PI if reversed_body else 0.0, suspension.roll * sway
	)
	if lamp != null:
		lamp.visible = leading and t.cab.is_on(&"headlights") and t.power.control_on(t.cab)


func apply_rail_pose(state: Dictionary) -> void:
	transform = state["body"]
	var inverse: Transform3D = transform.affine_inverse()
	var bogies: Array = state["bogies"]
	for i: int in trucks.size():
		trucks[i].transform = inverse * (bogies[i] as Transform3D)


func _rounded_shell(front: float, rear: float, paint: Material, roof: Material) -> void:
	var section := PackedVector2Array(
		[Vector2(-1.5, 1.22), Vector2(1.5, 1.22), Vector2(1.7, 1.42), Vector2(1.7, 3.70)]
	)
	for i: int in range(1, 17):
		var angle: float = PI * i / 16.0
		section.append(Vector2(cos(angle) * 1.7, 3.70 + sin(angle) * .55))
	section.append(Vector2(-1.7, 1.42))
	for is_roof: bool in [false, true]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in section.size():
			var j: int = (i + 1) % section.size()
			if (i >= 3 and i < 19) != is_roof:
				continue
			var a := Vector3(section[i].x, section[i].y, front)
			var b := Vector3(section[j].x, section[j].y, front)
			var points: Array[Vector3] = [a, b, Vector3(b.x, b.y, rear), Vector3(a.x, a.y, rear)]
			var edge: Vector2 = section[j] - section[i]
			var normal := Vector3(edge.y, -edge.x, 0).normalized()
			for index: int in [0, 2, 1, 0, 3, 2]:
				var point: Vector3 = points[index]
				tool.set_normal(
					(
						(
							Vector3(point.x / (1.7 * 1.7), (point.y - 3.70) / (.55 * .55), 0)
							. normalized()
						)
						if is_roof
						else normal
					)
				)
				tool.add_vertex(point)
		if not is_roof:
			for z: float in [front, rear]:
				tool.set_normal(Vector3(0, 0, -1 if z == front else 1))
				var cap: Array = []
				for point: Vector2 in section:
					cap.append(Vector3(point.x, point.y, z))
				if z == rear:
					cap.reverse()
				_quad(tool, cap)
		tool.index()
		var shell := MeshInstance3D.new()
		shell.mesh = tool.commit()
		var mat: StandardMaterial3D = (
			((roof if is_roof else paint) as StandardMaterial3D).duplicate()
		)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		shell.material_override = mat
		body.add_child(shell)
