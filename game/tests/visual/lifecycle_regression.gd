extends SceneTree
## Exercise real scene ownership, not only process shutdown: three trips must release
## their worlds, render paths and audio workers and return to the same warm menu.

var failures: Array[String] = []
var _errors := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL ", message)


func frames(count: int = 12) -> void:
	for frame: int in count:
		await process_frame


func counts() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"focus_connections": root.focus_exited.get_connections().size(),
	}


func trip() -> void:
	current_scene.call("_start")
	await frames()
	var scene: Node = current_scene
	var world_ref: WeakRef = weakref(scene.get("world"))
	var view_ref: WeakRef = weakref(scene.get("side"))
	var audio_ref: WeakRef = weakref(scene.get("audio"))
	var path_ref: WeakRef = weakref(scene.get("side").get("_rail_path"))
	var worker_ref: WeakRef = weakref(scene.get("audio").get("_mix_thread"))
	scene.call("_leave")
	await frames()
	check(not is_instance_valid(scene), "trip scene released")
	check(world_ref.get_ref() == null, "trip world released")
	check(view_ref.get_ref() == null, "trip view released")
	check(audio_ref.get_ref() == null, "trip audio released")
	check(path_ref.get_ref() == null, "trip path released")
	check(worker_ref.get_ref() == null, "trip audio worker released")
	# A root-window signal must never call a lambda that belonged to a departed trip.
	root.focus_exited.emit()


func _run() -> void:
	root.get_node("Session").set("car_count", 4)
	root.get_node("Settings").call("set_value", "audio", "auto_announcements", false)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await frames()
	# Warm resource/script caches once before comparing equal menu states.
	await trip()
	var baseline: Dictionary = counts()
	print("LIFECYCLE_BASELINE ", JSON.stringify(baseline))
	for cycle: int in 3:
		await trip()
		var sample: Dictionary = counts()
		print("LIFECYCLE_CYCLE ", cycle + 1, " ", JSON.stringify(sample))
		for key: String in baseline:
			check(
				int(sample[key]) == int(baseline[key]), "%s stable after trip %d" % [key, cycle + 1]
			)
	current_scene.queue_free()
	await frames()
	for error: String in _errors.take():
		failures.append(error)
	print("LIFECYCLE_QA ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	quit(0 if failures.is_empty() else 1)
