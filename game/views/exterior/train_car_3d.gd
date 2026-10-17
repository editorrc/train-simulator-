class_name TrainCar3D
extends Node3D
## Visual reconstruction, not factory CAD. Wheels stay on the rails; only the body sways.

var body: Node3D
var wheels: Array[Node3D] = []
var doors: Array[Dictionary] = []
var lamp: SpotLight3D
var _door_left: float = 0.0
var _door_right: float = 0.0
var _length: float = 20.0


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
	parent: Node3D, at: Vector3, radius: float, height: float, mat: Material
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = mat
	item.position = at
	parent.add_child(item)
	return item


func build(spec: VehicleSpec, livery: Dictionary, cab: bool) -> void:
	_length = spec.length_m
	var end: float = _length * 0.5
	var paint: StandardMaterial3D = material(Color(str(livery.get("body", "#287958"))), 0.25)
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
	box(body, Vector3(0, 2.66, (front + rear) * 0.5), Vector3(3.4, 2.9, rear - front), paint)
	box(body, Vector3(0, 4.14, (front + rear) * 0.5), Vector3(3.3, 0.22, rear - front), roof)
	box(body, Vector3(0, 0.9, -1), Vector3(2.0, 0.5, 6.0), dark)
	for side: float in [-1.0, 1.0]:
		box(
			body,
			Vector3(side * 1.71, 2.0, (front + rear) * 0.5),
			Vector3(0.025, 0.20, rear - front),
			stripe
		)
		for i: int in 7:
			var z: float = lerpf(-end + 4.0, end - 4.0, i / 6.0)
			box(body, Vector3(side * 1.716, 3.12, z), Vector3(0.04, 1.05, 1.25), black)
			box(body, Vector3(side * 1.744, 3.12, z), Vector3(0.025, 0.92, 1.12), glass)
			box(body, Vector3(side * 1.76, 3.37, z), Vector3(0.025, 0.025, 1.12), steel)
		for z: float in [-end + 2.6, end - 2.6]:
			box(body, Vector3(side * 1.73, 2.28, z), Vector3(0.025, 2.13, 1.28), black)
			for leaf: float in [-1.0, 1.0]:
				var panel := Node3D.new()
				panel.position = Vector3(side * 1.77, 0, z + leaf * 0.31)
				body.add_child(panel)
				box(panel, Vector3(0, 2.28, 0), Vector3(0.035, 2.06, 0.6), paint)
				box(panel, Vector3(side * 0.025, 2.95, 0), Vector3(0.02, 0.72, 0.43), glass)
				doors.append({"node": panel, "base": panel.position.z, "leaf": leaf, "side": side})
	for z: float in [-7.5, 7.5]:
		box(self, Vector3(0, .65, z), Vector3(2.45, .40, 3.2), dark)
		for axle: float in [-1.3, 1.3]:
			var shaft: MeshInstance3D = cylinder(self, Vector3(0, .525, z + axle), .09, 2.7, steel)
			shaft.rotation.z = PI / 2.0
			for x: float in [-.79, .79]:
				var wheel: MeshInstance3D = cylinder(
					self, Vector3(x, .525, z + axle), .525, .16, dark
				)
				wheel.rotation.z = PI / 2.0
				wheels.append(wheel)
				var rim: MeshInstance3D = cylinder(wheel, Vector3(0, .09, 0), .48, .035, steel)
				rim.rotation.z = 0.0
				cylinder(wheel, Vector3(0, .13, 0), .16, .09, dark)
	for z: float in [-end - .15, end + .15]:
		box(self, Vector3(0, 1.0, z), Vector3(.45, .25, .75), steel)
	if spec.has_pantograph:
		for sign_x: float in [-1.0, 1.0]:
			var rod: MeshInstance3D = box(
				body, Vector3(sign_x * .38, 4.85, 0), Vector3(.06, 1.7, .06), dark
			)
			rod.rotation.z = sign_x * .45
		box(body, Vector3(0, 5.7, 0), Vector3(1.9, .08, .18), dark)
	if cab:
		_cab(end, paint, stripe, glass, black, steel)


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
	for x: float in [-1.1, 1.1]:
		var housing: MeshInstance3D = cylinder(body, Vector3(x, 1.72, -end - .07), .18, .12, black)
		housing.rotation.x = PI / 2.0
		cylinder(housing, Vector3(0, .08, 0), .13, .025, material(Color("e1d3a5")))
	var top: MeshInstance3D = cylinder(body, Vector3(0, 3.88, -end - .04), .25, .17, steel)
	top.rotation.x = PI / 2.0
	var lens_mat: StandardMaterial3D = material(Color("fff2d2"))
	lens_mat.emission_enabled = true
	lens_mat.emission = Color("fff0c0")
	cylinder(top, Vector3(0, .10, 0), .19, .025, lens_mat)
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


func animate(t: Train, distance: float, dt: float, leading: bool, clock_s: float) -> void:
	_door_left = move_toward(_door_left, 1.0 if t.cab.is_on(&"doors_left") else 0.0, dt / 1.1)
	_door_right = move_toward(_door_right, 1.0 if t.cab.is_on(&"doors_right") else 0.0, dt / 1.1)
	for item: Dictionary in doors:
		var panel: Node3D = item["node"]
		panel.position.z = (
			float(item["base"])
			+ float(item["leaf"]) * .60 * (_door_left if float(item["side"]) < 0 else _door_right)
		)
	for wheel: Node3D in wheels:
		wheel.rotation.x = -distance / .525
	var sway: float = (
		float(Settings.get_value("camera", "sway", .2)) * minf(absf(t.speed_ms) / 30.0, 1.0)
	)
	body.rotation.z = sin(clock_s * 3.1) * .006 * sway
	body.position.y = sin(clock_s * 4.3) * .008 * sway
	if lamp != null:
		lamp.visible = leading and t.cab.is_on(&"headlights") and t.power.control_on(t.cab)
