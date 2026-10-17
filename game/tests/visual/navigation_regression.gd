extends SceneTree
## Native Godot GUI acceptance. Run with a real display and --audio-driver Dummy.
var failures: Array[String] = []
var _errors := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL ", message)


func frames(count: int = 8) -> void:
	for i: int in count:
		await process_frame


func capture(name: String) -> void:
	root.get_texture().get_image().save_png("/tmp/train-panorama-" + name + ".png")


func key(code: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func _run() -> void:
	UiLayout.clear()
	var preferences: Node = root.get_node("Settings")
	var old_bindings: Variant = preferences.get_value("controls", "bindings", {})
	preferences.set_value("controls", "bindings", {})
	preferences.set_value("camera", "view_mode", 0)
	preferences.set_value("visual", "night", false)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await frames(16)
	var menu: Node = current_scene
	for count: int in [4, 6, 8, 10]:
		menu.call("_pick_formation", count)
		await frames()
		var preview: Node = menu.get("_preview")
		check(
			(preview.get("_view").get("_cars") as Array).size() == count,
			"preview has %d cars" % count
		)
		check(
			(
				(preview.get("_view").get("world") as SimWorld).player().consist.vehicles.size()
				== count
			),
			"preview physics uses selected formation"
		)
		capture("formation-%d" % count)
	menu.call("_pick_formation", 8)
	for page: int in [1, 2, 3, 4, 0]:
		menu.call("_show_page", page)
		await frames()
		check(int(root.get_node("Session").get("car_count")) == 8, "navigation preserves formation")
		capture("page-%d" % page)
	# Verify actual captured input and conflict feedback in the menu editor.
	menu.call("_show_page", 4)
	await frames()
	var editor: Node = (menu.get("_body") as Control).get_child(0)
	editor.call("_begin", "horn")
	Input.parse_input_event(key(KEY_V))
	await frames(2)
	check(
		(editor.get("bindings") as ControlBindings).binding("horn") == KEY_SPACE,
		"conflict does not replace horn"
	)
	Input.parse_input_event(key(KEY_O))
	await frames(2)
	check(
		(editor.get("bindings") as ControlBindings).binding("horn") == KEY_O,
		"captured binding applied"
	)
	Input.parse_input_event(key(KEY_O, false))
	editor.call("_reset")
	menu.call("_show_page", 0)
	await frames()
	menu.call("_start")
	await frames(20)
	var drive: Node = current_scene
	var world: SimWorld = drive.get("world")
	check(world.player().consist.vehicles.size() == 8, "drive uses eight cars")
	var controller: int = world.player().controller_index
	Input.parse_input_event(key(KEY_UP))
	Input.parse_input_event(key(KEY_UP, true, true))
	Input.parse_input_event(key(KEY_UP, false))
	await frames(2)
	check(world.player().controller_index == controller + 1, "one notch, OS repeat ignored")
	Input.parse_input_event(key(KEY_SPACE))
	await frames(2)
	check(world.player().cab.is_on(&"horn"), "horn starts")
	drive.call("_set_paused", true)
	await frames(2)
	check(not world.player().cab.is_on(&"horn"), "pause releases held horn")
	var tick: int = world.tick
	await frames(10)
	check(world.tick == tick, "pause preserves world tick")
	capture("pause")
	drive.call("_set_paused", false)
	await frames(8)
	check(world.tick > tick, "resume keeps same world and advances")
	capture("drive")
	drive.call("_open_dialog", drive.get("controls_dialog"))
	await frames()
	capture("drive-controls")
	var drive_editor: Node = (drive.get("controls_dialog") as Node).find_child("*", true, false)
	for child: Node in (drive.get("controls_dialog") as Node).get_children():
		if child.has_method("_begin"):
			drive_editor = child
	drive_editor.call("_begin", "whistle")
	Input.parse_input_event(key(KEY_O))
	await frames(2)
	check(
		(drive.get("bindings") as ControlBindings).binding("whistle") == KEY_O,
		"capture in drive dialog"
	)
	check(not world.player().cab.is_on(&"whistle"), "capture never plays whistle")
	drive_editor.call("_reset")
	var before: int = world.player().controller_index
	Input.parse_input_event(key(KEY_UP))
	await frames(2)
	check(world.player().controller_index == before, "dialog blocks driver commands")
	(drive.get("controls_dialog") as AcceptDialog).hide()
	await frames()
	check(not bool(drive.get("_paused")), "dialog restores prior pause state")
	var signs: Array[Node] = (drive.get("side") as Node).find_children(
		"StationSign", "Node3D", true, false
	)
	check(not signs.is_empty(), "station signs exist")
	if not signs.is_empty():
		var name: Label3D = signs[0].get_node("StationName")
		check(
			name.billboard == BaseMaterial3D.BILLBOARD_DISABLED,
			"station name fixed to physical sign"
		)
		check(not name.no_depth_test, "sign respects occlusion")
	preferences.set_value("controls", "bindings", old_bindings)
	for error: String in _errors.take():
		failures.append(error)
	print("NAVIGATION_QA ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	quit(0 if failures.is_empty() else 1)
