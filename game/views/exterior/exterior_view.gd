class_name ExteriorView
extends RailView
## An orthographic 3D stage in an empty dark space, with a perspective cab view.

var preview_mode: bool = false
var _viewport_container: TextureRect
var _viewport: SubViewport
var _stage: Node3D
var _cab_lamp: SpotLight3D
var _camera: Camera3D
var _environment: WorldEnvironment
var _sun: DirectionalLight3D
var _rail_path: RailPath
var _consist_pose: RailConsistPose
var _links: Array[MeshInstance3D] = []
var _geometry: RouteGeometry
var _cars: Array[TrainCar3D] = []
var _mode: int = 0
var _focus := Vector3.ZERO
var _previous_target := Vector3.ZERO
var _forward := Vector3.FORWARD
var _orbit_reference := Vector3.FORWARD
var _camera_ready: bool = false
var _pan: float = 0.0
var _parallel_offset: float = 0.0
var _platform_side: float = 1.0


func setup(
	p_world: SimWorld, p_stations: Dictionary, p_livery: Dictionary, p_number: String
) -> void:
	super.setup(p_world, p_stations, p_livery, p_number)
	var sc: Dictionary = ContentDB.get_entry(&"scenario", Session.scenario_id)
	var route: Dictionary = ContentDB.get_entry(&"route", StringName(str(sc["route"])))
	_parallel_offset = float(
		((route.get("route", {}) as Dictionary).get("visual", {}) as Dictionary).get(
			"parallel_track_offset_m", 0.0
		)
	)
	_geometry = RouteGeometry.from_dict(route["geometry"])
	_rail_path = RailPath.new(world.graph, _geometry)
	_consist_pose = RailConsistPose.new(_rail_path)
	_viewport_container = TextureRect.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewport_container.stretch_mode = TextureRect.STRETCH_SCALE
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_container.visible = false
	add_child(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport_container.add_child(_viewport)
	_viewport_container.texture = _viewport.get_texture()
	_mode = 0 if preview_mode else int(Settings.get_value("camera", "view_mode", 0))
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
	_stage.add_child(_cab_lamp)

	var t: Train = world.player()
	for i: int in t.consist.vehicles.size():
		if preview_mode and i > 1:
			break
		var car := TrainCar3D.new()
		car.build(t.consist.vehicles[i], livery, i == 0 or i == t.consist.vehicles.size() - 1)
		car.reversed_body = i == t.consist.vehicles.size() - 1 and i > 0
		_stage.add_child(car)
		_cars.append(car)
		if i > 0:
			_links.append(
				TrainCar3D.box(
					_stage,
					Vector3.ZERO,
					Vector3(.16, .16, 1.0),
					TrainCar3D.material(Color("4b5154"), .7)
				)
			)
	_build_track()
	if not preview_mode:
		_build_platforms()


func _position(pos: TrackPosition) -> Vector3:
	return _rail_path.point(pos)


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
	var offsets := PackedFloat64Array([0.0])
	if _parallel_offset != 0:
		offsets.append(_parallel_offset)
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
				for offset: float in offsets:
					beds.append(Transform3D(basis, center + basis.x * offset + Vector3(0, -.42, 0)))
					for x: float in [-.7975, .7975]:
						rails.append(
							Transform3D(
								basis, center + basis.x * (x + offset) + Vector3(0, -.09, 0)
							)
						)
					wires.append(Transform3D(basis, center + basis.x * offset + Vector3(0, 6, 0)))
				d += 2
			var sleeper_at: float = ceil(chunk / .65) * .65
			while sleeper_at < finish:
				var start: Vector3 = _at(segment, sleeper_at)
				var end: Vector3 = _at(segment, minf(sleeper_at + 1, segment.length_m))
				if start.distance_to(end) > .01:
					var basis: Basis = Basis.looking_at((end - start).normalized())
					for offset: float in offsets:
						sleepers.append(
							Transform3D(basis, start + basis.x * offset + Vector3(0, -.25, 0))
						)
				sleeper_at += .65
			var mast_at: float = ceil(chunk / 65) * 65
			while mast_at < finish:
				var p: Vector3 = _at(segment, mast_at)
				var tangent: Vector3 = (
					(_at(segment, minf(mast_at + 1, segment.length_m)) - p).normalized()
				)
				var basis: Basis = Basis.looking_at(tangent)
				for offset: float in offsets:
					var across: float = offset + (3.1 if offset == 0 else -3.1)
					masts.append(Transform3D(basis, p + basis.x * across + Vector3(0, 3.6, 0)))
				mast_at += 65
			_batch(beds, Vector3(3.7, .28, 2.02), ballast, origin)
			_batch(rails, Vector3(.075, .18, 2.02), steel, origin)
			_batch(sleepers, Vector3(2.7, .16, .24), concrete, origin)
			_batch(masts, Vector3(.17, 7.2, .17), poles, origin)
			_batch(wires, Vector3(.025, .025, 2.02), poles, origin)
			chunk = finish


func _platform_strip(
	group: Node3D,
	seg: TrackSegment,
	begin: float,
	end: float,
	side: float,
	across_m: Vector2,
	floor_y: float,
	height: float,
	mat: Material,
	track_offset: float = 0.0
) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offset: float = begin
	while offset < end - .001:
		var next: float = minf(offset + 2.0, end)
		var frames: Array[Transform3D] = [
			_rail_path.frame(TrackPosition.new(seg.id, offset, 1)),
			_rail_path.frame(TrackPosition.new(seg.id, next, 1))
		]
		var corners: Array[PackedVector3Array] = []
		for frame: Transform3D in frames:
			var points := PackedVector3Array()
			for section: Vector2 in [
				Vector2(across_m.x, floor_y),
				Vector2(across_m.y, floor_y),
				Vector2(across_m.y, floor_y + height),
				Vector2(across_m.x, floor_y + height)
			]:
				points.append(
					frame * Vector3(section.x * side + track_offset, section.y, 0) - group.position
				)
			corners.append(points)
		for index: int in 4:
			var other: int = (index + 1) % 4
			TrainCar3D._quad(
				surface,
				[corners[0][index], corners[0][other], corners[1][other], corners[1][index]]
			)
		offset = next
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = mat
	mesh.visibility_range_end = 480
	group.add_child(mesh)


func _build_platforms() -> void:
	var concrete: StandardMaterial3D = TrainCar3D.material(Color("687780"))
	var roof: StandardMaterial3D = TrainCar3D.material(Color("384c5b"), .4)
	var edge: StandardMaterial3D = TrainCar3D.material(Color("e0c772"))
	for mat: StandardMaterial3D in [concrete, roof, edge]:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for st: Variant in stations.get("stations", []):
		var station: Dictionary = st
		var layouts: Array[Dictionary] = []
		for raw: Variant in station["platforms"]:
			var platform: Dictionary = raw
			layouts.append(platform)
			if _parallel_offset != 0:
				var opposite: Dictionary = platform.duplicate()
				opposite["visual_track_offset_m"] = _parallel_offset
				opposite["side"] = "left" if _parallel_offset < 0 else "right"
				layouts.append(opposite)
		for platform: Dictionary in layouts:
			var seg: TrackSegment = world.graph.get_segment(StringName(str(platform["segment"])))
			var begin: float = float(platform["from_m"])
			var end: float = float(platform["to_m"])
			var middle: float = (begin + end) * .5
			var side: float = 1.0 if str(platform["side"]) == "right" else -1.0
			var track_offset: float = float(platform.get("visual_track_offset_m", 0.0))
			var group := Node3D.new()
			_stage.add_child(group)
			group.position = _at(seg, middle)
			_platform_strip(
				group, seg, begin, end, side, Vector2(1.95, 7.95), 0, 1.1, concrete, track_offset
			)
			_platform_strip(
				group, seg, begin, end, side, Vector2(1.95, 2.20), 1.101, .015, edge, track_offset
			)
			_platform_strip(
				group,
				seg,
				maxf(begin, middle - 27),
				minf(end, middle + 27),
				side,
				Vector2(2.0, 7.95),
				4.3,
				.15,
				roof,
				track_offset
			)
			for delta: float in [-24, -12, 0, 12, 24]:
				var frame: Transform3D = _rail_path.frame(
					TrackPosition.new(seg.id, middle + delta, 1)
				)
				var furniture := Node3D.new()
				group.add_child(furniture)
				furniture.transform = Transform3D(
					frame.basis, frame.origin + frame.basis.x * track_offset - group.position
				)
				TrainCar3D.box(furniture, Vector3(side * 6.3, 2.7, 0), Vector3(.13, 3.2, .13), roof)
				TrainCar3D.box(furniture, Vector3(side * 5, 1.5, 0), Vector3(1.5, .15, .5), roof)
			if track_offset != 0:
				continue
			var label := Label3D.new()
			label.text = str(station["name_uk"])
			label.font_size = 64
			label.pixel_size = .025
			label.position = (
				_rail_path.offset_point(TrackPosition.new(seg.id, middle, 1), side * 3, 3.2)
				- group.position
			)
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
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_DISABLED if _mode == 4 else SubViewport.UPDATE_ALWAYS
	)
	if _mode == 4:
		super._process(delta)
		return
	_update_render_size()
	var t: Train = world.player()
	var alpha: float = SimClock.clock.interpolation_alpha()
	var head: TrackPosition = pose.head(world.graph, alpha) if pose != null else t.head
	var point: Vector3 = _position(head)
	var ahead: Vector3 = _position(head.advance(world.graph, 2).position)
	var forward: Vector3 = (ahead - point).normalized()
	if forward.length_squared() < .1:
		forward = _forward
	_forward = forward
	var specs: Array[VehicleSpec] = []
	var extensions := PackedFloat64Array()
	for i: int in _cars.size():
		specs.append(t.consist.vehicles[i])
		if i < _cars.size() - 1:
			extensions.append(_cars[i].suspension.extension)
	var states: Array[Dictionary] = _consist_pose.solve(head, specs, extensions)
	forward = -(states[0]["body"] as Transform3D).basis.z
	_forward = forward
	var active_cab: int = 0 if t.reverser >= 0 else _cars.size() - 1
	var trailing_mass: float = t.total_mass_kg()
	var distance: float = (
		lerpf(pose.previous_distance, pose.current_distance, alpha)
		if pose != null
		else t.odometer_m
	)
	for i: int in _cars.size():
		var spec: VehicleSpec = specs[i]
		var mass: float = (
			spec.mass_empty_kg + spec.seats * t.load_factor * t.consist.passenger_mass_kg
		)
		trailing_mass -= mass
		var car: TrainCar3D = _cars[i]
		car.apply_rail_pose(states[i])
		car.visible = not (_mode == 3 and i == active_cab)
		var trucks: Array = states[i]["bogies"]
		var front: Vector3 = -(trucks[0] as Transform3D).basis.z
		var rear: Vector3 = -(trucks[1] as Transform3D).basis.z
		var curvature: float = (
			atan2(rear.cross(front).y, rear.dot(front))
			/ float(spec.visual.get("bogie_centers_m", 15.0))
		)
		car.suspension.advance(
			spec, mass, trailing_mass, t.speed_ms * t.speed_ms * curvature, t.accel_ms2, delta
		)
		car.animate(
			t,
			distance,
			delta,
			i == 0 if t.reverser >= 0 else i == _cars.size() - 1,
			world.clock_s()
		)
		if i > 0:
			var from: Vector3 = states[i - 1]["rear"]
			var to: Vector3 = states[i]["front"]
			var link: MeshInstance3D = _links[i - 1]
			link.position = (from + to) * .5 + Vector3.UP
			link.look_at(to + Vector3.UP)
			link.scale.z = from.distance_to(to)
	var zoom: float = float(Settings.get_value("camera", "zoom", 1.0))
	var target: Vector3 = point - forward * (18.0 if preview_mode else 8.0 / zoom)
	var lag: float = float(Settings.get_value("camera", "follow_s", .18))
	if not _camera_ready or point.distance_to(_focus) > 350:
		_focus = target
		_previous_target = target
		_orbit_reference = forward
		_platform_side = _platform_side_at(head)
		_camera_ready = true
	for axis: int in 3:
		_focus[axis] = RenderPose.follow(
			_focus[axis], _previous_target[axis], target[axis], delta, lag
		)
	_previous_target = target
	var reference: Vector3 = (
		forward if bool(Settings.get_value("camera", "follow_heading", false)) else _orbit_reference
	)
	var right: Vector3 = reference.cross(Vector3.UP).normalized()
	var yaw: float = deg_to_rad(float(Settings.get_value("camera", "yaw", 0.0)))
	var pitch: float = deg_to_rad(float(Settings.get_value("camera", "pitch", 25.0)))
	var angle: float = (-.6 if _mode == 0 else .6) + yaw
	if _mode == 2:
		angle = 0.0
	var outward: Vector3 = right * _platform_side * cos(angle) + reference * sin(-angle)
	var focus: Vector3 = _focus + right * _pan + Vector3(0, 2, 0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = (18.0 if preview_mode else 45.0) / zoom
	_camera.position = focus + outward * 90 * cos(pitch) + Vector3.UP * 90 * sin(pitch)
	_camera.look_at(focus)
	if _mode == 3:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.fov = clampf(65.0 / zoom, 35.0, 100.0)
		var cab_frame: Transform3D = states[active_cab]["body"]
		var facing: float = 1.0 if active_cab == 0 else -1.0
		_camera.position = (
			cab_frame * Vector3(0, 3.25, (-specs[active_cab].length_m * .5 + 1.6) * facing)
		)
		var look: Vector3 = -cab_frame.basis.z * facing
		look = look.rotated(
			Vector3.UP, deg_to_rad(float(Settings.get_value("camera", "cab_yaw", 0.0)))
		)
		var cab_right: Vector3 = look.cross(Vector3.UP).normalized()
		look = look.rotated(
			cab_right, deg_to_rad(float(Settings.get_value("camera", "cab_pitch", 0.0)))
		)
		_camera.look_at(_camera.position + look * 100.0)
		var shell: Transform3D = (
			_cars[active_cab].global_transform * _cars[active_cab].body.transform
		)
		var end: float = (
			specs[active_cab].length_m * .5
			- float(specs[active_cab].visual.get("body_end_inset_m", .35))
		)
		_cab_lamp.position = shell * Vector3(0, 3.88, -end - .2)
		_cab_lamp.look_at(_cab_lamp.position - shell.basis.z * 100.0 - shell.basis.y * 5.0)

	_cab_lamp.visible = _mode == 3 and t.cab.is_on(&"headlights") and t.power.control_on(t.cab)
	var adaptive: bool = bool(Settings.get_value("visual", "adaptive_detail", true))
	for car: TrainCar3D in _cars:
		var pixel_scale: float = _viewport.size.y / _camera.size
		if _camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
			pixel_scale = (
				_viewport.size.y
				/ (
					2.0
					* tan(deg_to_rad(_camera.fov * .5))
					* maxf(1, _camera.position.distance_to(car.position))
				)
			)
		car.update_detail(car._wheel_radius * 2.0 * pixel_scale if adaptive else 100.0)
	var night: bool = bool(Settings.get_value("visual", "night", false))
	_sun.light_energy = .06 if night else 1.1
	_environment.environment.ambient_light_energy = .15 if night else .7
	cam_ch = world.graph.chainage_at(head)
	queue_redraw()


func next_preset() -> void:
	_mode = (_mode + 1) % 5
	_camera_ready = false
	Settings.set_value("camera", "view_mode", _mode)


func _platform_side_at(head: TrackPosition) -> float:
	var nearest: float = INF
	var result: float = 1.0
	for raw: Variant in stations.get("stations", []):
		for platform: Dictionary in (raw as Dictionary)["platforms"]:
			var middle: float = (float(platform["from_m"]) + float(platform["to_m"])) * .5
			var position := TrackPosition.new(StringName(str(platform["segment"])), middle, 1)
			var distance: float = _position(head).distance_squared_to(_position(position))
			if distance < nearest:
				nearest = distance
				result = (1.0 if str(platform["side"]) != "left" else -1.0) * head.direction
	return result


func platform_view() -> void:
	_mode = 0
	_camera_ready = false
	_pan = 0.0
	Settings.set_value("camera", "view_mode", 0)
	Settings.set_value("camera", "yaw", 0.0)
	Settings.set_value("camera", "pitch", 25.0)


func preset_name() -> String:
	return ["3/4 спереду", "3/4 ззаду", "Збоку 3D", "З кабіни", "Проекція 2.5D"][_mode]


func zoom_by(factor: float) -> void:
	super.zoom_by(factor)
	Settings.set_value(
		"camera", "zoom", clampf(float(Settings.get_value("camera", "zoom", 1.0)) * factor, .3, 3)
	)


func adjust(d_yaw: float, d_pitch: float) -> void:
	if _mode == 3:
		Settings.set_value(
			"camera",
			"cab_yaw",
			clampf(float(Settings.get_value("camera", "cab_yaw", 0.0)) + d_yaw, -110, 110)
		)
		Settings.set_value(
			"camera",
			"cab_pitch",
			clampf(float(Settings.get_value("camera", "cab_pitch", 0.0)) + d_pitch, -60, 60)
		)
		return
	super.adjust(d_yaw, d_pitch)
	Settings.set_value(
		"camera", "yaw", wrapf(float(Settings.get_value("camera", "yaw", 0)) + d_yaw, -180, 180)
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


func _update_render_size() -> void:
	# Texture.get_size() may be logical after stretch; Window.size matches the physical image.
	var physical := Vector2(get_window().size)
	var logical: Vector2 = get_viewport_rect().size
	var ratio: Vector2 = size / logical.max(Vector2.ONE)
	var scale_factor: float = float(Settings.get_value("visual", "render_scale", 1.0))
	var desired := Vector2i((physical * ratio * scale_factor).round())
	desired = desired.clamp(Vector2i(64, 64), Vector2i(8192, 8192))
	if _viewport.size != desired:
		_viewport.size = desired
	var samples: int = int(Settings.get_value("visual", "msaa", 2))
	_viewport.msaa_3d = (
		Viewport.MSAA_DISABLED
		if samples == 0
		else (Viewport.MSAA_4X if samples == 4 else Viewport.MSAA_2X)
	)
