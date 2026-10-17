class_name ExteriorView
extends RailView
## An orthographic 3D stage in an empty dark space, with a perspective cab view.

var preview_mode: bool = false
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _stage: Node3D
var _cab_lamp: SpotLight3D
var _camera: Camera3D
var _environment: WorldEnvironment
var _sun: DirectionalLight3D
var _geometry: RouteGeometry
var _cars: Array[TrainCar3D] = []
var _mode: int = 0
var _focus := Vector3.ZERO
var _previous_target := Vector3.ZERO
var _forward := Vector3.FORWARD
var _camera_ready: bool = false
var _pan: float = 0.0


func setup(
	p_world: SimWorld, p_stations: Dictionary, p_livery: Dictionary, p_number: String
) -> void:
	super.setup(p_world, p_stations, p_livery, p_number)
	var sc: Dictionary = ContentDB.get_entry(&"scenario", Session.scenario_id)
	var route: Dictionary = ContentDB.get_entry(&"route", StringName(str(sc["route"])))
	_geometry = RouteGeometry.from_dict(route["geometry"])
	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_viewport)
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	_environment = WorldEnvironment.new()
	_environment.environment = Environment.new()
	_environment.environment.background_mode = Environment.BG_COLOR
	_environment.environment.background_color = Color("171c22")
	_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.environment.ambient_light_color = Color("b3c4da")
	_stage.add_child(_environment)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-42, -35, 0)
	_stage.add_child(_sun)
	_camera = Camera3D.new()
	_camera.near = .1
	_camera.far = 650
	_stage.add_child(_camera)
	_camera.current = true
	_cab_lamp = SpotLight3D.new()
	_cab_lamp.spot_range = 140
	_cab_lamp.spot_angle = 25
	_cab_lamp.light_energy = 7
	_cab_lamp.light_color = Color("ffe5b5")
	_camera.add_child(_cab_lamp)

	var t: Train = world.player()
	for i: int in t.consist.vehicles.size():
		if preview_mode and i > 1:
			break
		var car := TrainCar3D.new()
		car.build(t.consist.vehicles[i], livery, i == 0 or i == t.consist.vehicles.size() - 1)
		_stage.add_child(car)
		_cars.append(car)
	_build_track()
	if not preview_mode:
		_build_platforms()


func _position(pos: TrackPosition) -> Vector3:
	var segment: TrackSegment = world.graph.get_segment(pos.segment_id)
	var p: Vector2 = _geometry.point_at(pos.segment_id, pos.offset_m, segment.length_m)
	return Vector3(p.x, 0, p.y)


func _at(segment: TrackSegment, offset: float) -> Vector3:
	return _position(TrackPosition.new(segment.id, offset, 1))


func _batch(
	transforms: Array[Transform3D], dimensions: Vector3, mat: Material, origin: Vector3
) -> void:
	if transforms.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i: int in transforms.size():
		var tf: Transform3D = transforms[i]
		tf.origin -= origin
		multi.set_instance_transform(i, tf)
	var item := MultiMeshInstance3D.new()
	item.multimesh = multi
	item.material_override = mat
	item.position = origin
	item.visibility_range_end = 480
	item.visibility_range_end_margin = 30
	_stage.add_child(item)


func _build_track() -> void:
	var ballast: StandardMaterial3D = TrainCar3D.material(Color("686964"))
	var steel: StandardMaterial3D = TrainCar3D.material(Color("a2a9ad"), .75)
	var concrete: StandardMaterial3D = TrainCar3D.material(Color("898b87"))
	var poles: StandardMaterial3D = TrainCar3D.material(Color("454e51"), .4)
	for segment: TrackSegment in world.graph.segments.values():
		var chunk: float = 0.0
		while chunk < segment.length_m:
			var finish: float = minf(chunk + 200, segment.length_m)
			var origin: Vector3 = _at(segment, (chunk + finish) * .5)
			if preview_mode and origin.distance_to(_position(world.player().head)) > 300:
				chunk = finish
				continue
			var rails: Array[Transform3D] = []
			var beds: Array[Transform3D] = []
			var sleepers: Array[Transform3D] = []
			var masts: Array[Transform3D] = []
			var wires: Array[Transform3D] = []
			var d: float = chunk
			while d < finish:
				var start: Vector3 = _at(segment, d)
				var end: Vector3 = _at(segment, minf(d + 2, segment.length_m))
				var forward: Vector3 = (end - start).normalized()
				if forward.length_squared() < .1:
					break
				var basis: Basis = Basis.looking_at(forward, Vector3.UP)
				var center: Vector3 = (start + end) * .5
				beds.append(Transform3D(basis, center + Vector3(0, -.17, 0)))
				for x: float in [-.76, .76]:
					rails.append(Transform3D(basis, center + basis.x * x + Vector3(0, .13, 0)))
				wires.append(Transform3D(basis, center + Vector3(0, 6, 0)))
				d += 2
			var sleeper_at: float = ceil(chunk / .65) * .65
			while sleeper_at < finish:
				var start: Vector3 = _at(segment, sleeper_at)
				var end: Vector3 = _at(segment, minf(sleeper_at + 1, segment.length_m))
				if start.distance_to(end) > .01:
					sleepers.append(
						Transform3D(Basis.looking_at((end - start).normalized()), start)
					)
				sleeper_at += .65
			var mast_at: float = ceil(chunk / 65) * 65
			while mast_at < finish:
				var p: Vector3 = _at(segment, mast_at)
				var tangent: Vector3 = (
					(_at(segment, minf(mast_at + 1, segment.length_m)) - p).normalized()
				)
				var basis: Basis = Basis.looking_at(tangent)
				masts.append(Transform3D(basis, p + basis.x * 3.1 + Vector3(0, 3.6, 0)))
				mast_at += 65
			_batch(beds, Vector3(3.7, .28, 2.02), ballast, origin)
			_batch(rails, Vector3(.075, .18, 2.02), steel, origin)
			_batch(sleepers, Vector3(2.7, .16, .24), concrete, origin)
			_batch(masts, Vector3(.17, 7.2, .17), poles, origin)
			_batch(wires, Vector3(.025, .025, 2.02), poles, origin)
			chunk = finish


func _build_platforms() -> void:
	var concrete: StandardMaterial3D = TrainCar3D.material(Color("687780"))
	var roof: StandardMaterial3D = TrainCar3D.material(Color("384c5b"), .4)
	var edge: StandardMaterial3D = TrainCar3D.material(Color("e0c772"))
	for st: Variant in stations.get("stations", []):
		var station: Dictionary = st
		var platform: Dictionary = station["platforms"][0]
		var seg: TrackSegment = world.graph.get_segment(StringName(str(platform["segment"])))
		var a: Vector3 = _at(seg, float(platform["from_m"]))
		var b: Vector3 = _at(seg, float(platform["to_m"]))
		if preview_mode and a.distance_to(_position(world.player().head)) > 350:
			continue
		var group := Node3D.new()
		_stage.add_child(group)
		group.position = (a + b) * .5
		group.look_at(group.position + (b - a).normalized())
		var length: float = a.distance_to(b)
		TrainCar3D.box(group, Vector3(5, .5, 0), Vector3(6, 1, length), concrete)
		TrainCar3D.box(group, Vector3(2.2, 1.01, 0), Vector3(.25, .025, length), edge)
		TrainCar3D.box(group, Vector3(5, 4.3, 0), Vector3(6, .15, 54), roof)
		for z: float in [-24, -12, 0, 12, 24]:
			TrainCar3D.box(group, Vector3(6.3, 2.65, z), Vector3(.13, 3.3, .13), roof)
			TrainCar3D.box(group, Vector3(5, 1.5, z), Vector3(1.5, .15, .5), roof)
		var label := Label3D.new()
		label.text = str(station["name_uk"])
		label.font_size = 48
		label.pixel_size = .035
		label.position = Vector3(3, 3.2, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.visibility_range_end = 220
		group.add_child(label)


func _draw() -> void:
	if _mode == 4:
		super._draw()


func _process(delta: float) -> void:
	if _camera == null:
		return
	_viewport_container.visible = _mode != 4
	if _mode == 4:
		super._process(delta)
		return
	var t: Train = world.player()
	var alpha: float = SimClock.clock.interpolation_alpha()
	var head: TrackPosition = pose.head(world.graph, alpha) if pose != null else t.head
	var point: Vector3 = _position(head)
	var ahead: Vector3 = _position(head.advance(world.graph, 2).position)
	var forward: Vector3 = (ahead - point).normalized()
	if forward.length_squared() < .1:
		forward = _forward
	_forward = forward
	var behind: float = 0.0
	var clock_s: float = world.clock_s() + alpha * SimConfig.SIM_DT
	for i: int in _cars.size():
		var spec: VehicleSpec = t.consist.vehicles[i]
		var center: TrackPosition = head.advance(world.graph, -behind - spec.length_m * .5).position
		var car_point: Vector3 = _position(center)
		var car_ahead: Vector3 = _position(center.advance(world.graph, 1).position)
		var car: TrainCar3D = _cars[i]
		car.position = car_point
		if car_ahead.distance_to(car_point) > .01:
			car.look_at(car_ahead)
		if i == _cars.size() - 1 and i > 1:
			car.rotate_y(PI)
		car.visible = not (_mode == 3 and i == 0)
		var distance: float = (
			lerpf(pose.previous_distance, pose.current_distance, alpha)
			if pose != null
			else t.odometer_m
		)
		car.animate(
			t, distance, delta, i == 0 if t.reverser >= 0 else i == _cars.size() - 1, clock_s
		)
		behind += spec.length_m
	var zoom: float = float(Settings.get_value("camera", "zoom", 1.0))
	var target: Vector3 = point - forward * (18.0 if preview_mode else 8.0 / zoom)
	var lag: float = float(Settings.get_value("camera", "follow_s", .18))
	if not _camera_ready or point.distance_to(_focus) > 350:
		_focus = target
		_previous_target = target
		_camera_ready = true
	for axis: int in 3:
		_focus[axis] = RenderPose.follow(
			_focus[axis], _previous_target[axis], target[axis], delta, lag
		)
	_previous_target = target
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var yaw: float = deg_to_rad(float(Settings.get_value("camera", "yaw", 0.0)))
	var pitch: float = deg_to_rad(float(Settings.get_value("camera", "pitch", 25.0)))
	var angle: float = (-.6 if _mode == 0 else .6) + yaw
	if _mode == 2:
		angle = 0.0
	var outward: Vector3 = -right * cos(angle) + forward * sin(-angle)
	var focus: Vector3 = _focus + right * _pan + Vector3(0, 2, 0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = (18.0 if preview_mode else 45.0) / zoom
	_camera.position = focus + outward * 90 * cos(pitch) + Vector3.UP * 90 * sin(pitch)
	_camera.look_at(focus)
	if _mode == 3:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.fov = 65
		_camera.position = point - forward * 1.6 + Vector3(0, 3.25, 0)
		_camera.look_at(_camera.position + forward * 100 + Vector3(0, -1.4, 0))
	_cab_lamp.visible = _mode == 3 and t.cab.is_on(&"headlights") and t.power.control_on(t.cab)
	var night: bool = bool(Settings.get_value("visual", "night", false))
	_sun.light_energy = .06 if night else 1.1
	_environment.environment.ambient_light_energy = .15 if night else .7
	cam_ch = world.graph.chainage_at(head)
	queue_redraw()


func next_preset() -> void:
	_mode = (_mode + 1) % 5
	_camera_ready = false


func preset_name() -> String:
	return ["3/4 спереду", "3/4 ззаду", "Збоку 3D", "З кабіни", "Проекція 2.5D"][_mode]


func zoom_by(factor: float) -> void:
	super.zoom_by(factor)
	Settings.set_value(
		"camera", "zoom", clampf(float(Settings.get_value("camera", "zoom", 1.0)) * factor, .3, 3)
	)


func adjust(d_yaw: float, d_pitch: float) -> void:
	super.adjust(d_yaw, d_pitch)
	Settings.set_value(
		"camera", "yaw", clampf(float(Settings.get_value("camera", "yaw", 0)) + d_yaw, -60, 60)
	)
	Settings.set_value(
		"camera",
		"pitch",
		clampf(float(Settings.get_value("camera", "pitch", 25)) + d_pitch, 10, 70)
	)


func pan_px(dx: float) -> void:
	_pan -= dx * .05


func snap_camera() -> void:
	super.snap_camera()
	_camera_ready = false
	_pan = 0.0
