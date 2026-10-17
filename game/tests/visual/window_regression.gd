extends SceneTree
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var settings: Node = root.get_node("Settings")
	var config: ConfigFile = settings.get("config")
	var previous: String = config.encode_to_text()
	config.clear()
	settings.call("_restore_display")
	check(root.mode == Window.MODE_MAXIMIZED, "fresh launch requests maximized window")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1100, 680)
	for frame: int in 4:
		await process_frame
	settings.call("_capture_display")
	check(
		str(settings.call("get_value", "display", "window_mode", "")) == "windowed",
		"manual window mode is remembered"
	)
	check(
		int(settings.call("get_value", "display", "width", 0)) == root.size.x,
		"manual width is remembered"
	)
	check(
		int(settings.call("get_value", "display", "height", 0)) == root.size.y,
		"manual height is remembered"
	)
	var remembered: Vector2i = root.size
	root.size = Vector2i(960, 600)
	settings.call("_restore_display")
	for frame: int in 4:
		await process_frame
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen()
	)
	check(
		root.size == remembered.clamp(Vector2i(960, 600), usable.size),
		"saved size restores within available display"
	)
	config.clear()
	config.parse(previous)
	settings.call("_restore_display")
	print("WINDOW_QA ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
