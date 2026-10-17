extends SceneTree
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _run() -> void:
	root.get_node("Settings").set_value("camera", "view_mode", 0)
	root.get_node("Settings").set_value("camera", "yaw", 0.0)
	root.get_node("Settings").set_value("visual", "render_scale", 1.0)
	change_scene_to_file("res://scenes/drive.tscn")
	for frame: int in 8:
		await process_frame
	var scene: Node = current_scene
	var settings: Node = root.get_node("Settings")
	var view: Node = scene.get("side")
	var viewport: SubViewport = view.get("_viewport")
	check(
		viewport.size == Vector2i(root.get_texture().get_size()),
		"3D resolution equals actual framebuffer"
	)
	var press := InputEventMouseButton.new()
	press.position = root.get_texture().get_size() * Vector2(.45, .28)
	press.global_position = press.position
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = press.position + Vector2(80, 20)
	motion.global_position = motion.position
	motion.relative = Vector2(80, 20)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(motion)
	await process_frame
	check(absf(float(settings.call("get_value", "camera", "yaw", 0.0))) > 1.0, "RMB drag rotates")
	press.pressed = false
	Input.parse_input_event(press)
	await process_frame
	check(not bool(scene.get("_orbit_drag")), "RMB release stops orbit")
	var before: float = float(settings.call("get_value", "camera", "yaw", 0.0))
	var pan := InputEventPanGesture.new()
	pan.position = root.get_texture().get_size() * Vector2(.45, .28)
	pan.delta = Vector2(1, 0)
	Input.parse_input_event(pan)
	await process_frame
	check(
		absf(float(settings.call("get_value", "camera", "yaw", 0.0)) - before) > 1,
		"trackpad pan rotates"
	)
	settings.call("set_value", "visual", "render_scale", 1.5)
	for frame: int in 2:
		await process_frame
	var expected := Vector2i((root.get_texture().get_size() * 1.5).round())
	check(viewport.size == expected, "render scale increases real 3D resolution")
	press.button_index = MOUSE_BUTTON_LEFT
	press.ctrl_pressed = true
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	check(bool(scene.get("_orbit_drag")), "Control-click starts Mac alternative orbit")
	press.ctrl_pressed = false
	press.pressed = false
	Input.parse_input_event(press)
	await process_frame
	check(not bool(scene.get("_orbit_drag")), "release stops orbit even after Control was released")
	settings.call("set_value", "camera", "cab_yaw", 0.0)
	for i: int in 3:
		view.call("next_preset")
	for i: int in 2:
		await process_frame
	var camera: Camera3D = view.get("_camera")
	var cab_before: Quaternion = camera.basis.get_rotation_quaternion()
	var lamp: Node3D = view.get("_cab_lamp")
	var lamp_before: Quaternion = lamp.basis.get_rotation_quaternion()
	view.call("adjust", 20.0, 0.0)
	for i: int in 2:
		await process_frame
	check(
		cab_before.angle_to(camera.basis.get_rotation_quaternion()) > .2,
		"cab view permits looking around"
	)
	check(
		lamp_before.angle_to(lamp.basis.get_rotation_quaternion()) < .001,
		"headlamp stays aligned with train while looking around"
	)
	var world: SimWorld = scene.get("world")
	world.player().reverser = -1
	for i: int in 2:
		await process_frame
	var cars: Array = view.get("_cars")
	check(not (cars.back() as Node3D).visible, "reverse uses rear active cab")
	check(
		camera.position.distance_to((cars.back() as Node3D).position) < 15,
		"camera is physically inside rear car"
	)
	world.player().reverser = 1
	settings.call("set_value", "camera", "cab_yaw", 0.0)
	settings.call("set_value", "camera", "view_mode", 0)
	settings.call("set_value", "visual", "render_scale", 1.0)
	settings.call("set_value", "camera", "yaw", 0.0)
	settings.call("set_value", "camera", "pitch", 25.0)
	print(
		"CAMERA_QA ",
		"PASS" if failures.is_empty() else "FAIL",
		" physical=",
		root.get_texture().get_size(),
		" high-res=",
		expected
	)
	quit(0 if failures.is_empty() else 1)
