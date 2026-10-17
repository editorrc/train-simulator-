extends SceneTree
## Fixed workload for before/after comparisons; wall time is host-specific, not a Mac FPS claim.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 800)
	for frame: int in 4:
		await process_frame
	root.get_node("Session").set("car_count", 10)
	var settings: Node = root.get_node("Settings")
	var previous: Dictionary = {}
	for key: String in ["zoom", "view_mode"]:
		previous[key] = settings.call("get_value", "camera", key, 1.0 if key == "zoom" else 0)
	settings.call("set_value", "camera", "zoom", .3)
	settings.call("set_value", "camera", "view_mode", 0)
	settings.call("set_value", "visual", "render_scale", 1.0)
	settings.call(
		"set_value", "visual", "msaa", 2 if "--msaa2" in OS.get_cmdline_user_args() else 4
	)
	var began: int = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/drive.tscn")
	for frame: int in 12:
		await process_frame
	var startup_ms: int = Time.get_ticks_msec() - began
	var world: SimWorld = current_scene.get("world")
	world.player().speed_ms = 25.0
	var draws: float = 0
	var process_s: float = 0
	var physics_s: float = 0
	var began_us: int = Time.get_ticks_usec()
	for frame: int in 60:
		await process_frame
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		process_s += Performance.get_monitor(Performance.TIME_PROCESS)
		physics_s += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var result: Dictionary = {
		"startup_ms": startup_ms,
		"frame_ms": (Time.get_ticks_usec() - began_us) / 60000.0,
		"process_ms": process_s * 1000 / 60,
		"physics_ms": physics_s * 1000 / 60,
		"draw_calls": draws / 60,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"framebuffer": str(root.get_texture().get_size()),
		"window_size": str(root.size),
		"display_size": str(DisplayServer.window_get_size()),
		"render_size": str((current_scene.get("side") as Node).get("_viewport").size)
	}
	result["msaa_mode"] = (current_scene.get("side") as Node).get("_viewport").msaa_3d
	var capture: Image = root.get_texture().get_image()
	result["capture_size"] = str(capture.get_size())
	print("PERFORMANCE_QA ", JSON.stringify(result))
	capture.save_png("/tmp/train-performance.png")
	for key: String in previous:
		settings.call("set_value", "camera", key, previous[key])
	quit()
