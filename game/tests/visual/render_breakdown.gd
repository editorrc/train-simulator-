extends SceneTree
## Draw calls / primitives of the drive scene by group (track, platforms, train), by hiding
## one group at a time. Host-specific frame times; use for relative comparison.


func _initialize() -> void:
	_run.call_deferred()


func _sample(frames: int) -> Dictionary:
	var draws: float = 0.0
	var prims: float = 0.0
	var began: int = Time.get_ticks_usec()
	for i: int in frames:
		await process_frame
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	return {
		"draws": draws / frames,
		"prims": prims / frames,
		"frame_ms": (Time.get_ticks_usec() - began) / 1000.0 / frames
	}


func _run() -> void:
	Engine.max_fps = 0
	root.size = Vector2i(1280, 800)
	root.get_node("Session").set("car_count", 10)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			root.get_node("Settings").call("set_value", "camera", "view_mode", int(arg.substr(7)))
	change_scene_to_file("res://scenes/drive.tscn")
	for i: int in 12:
		await process_frame
	var stage: Node = (current_scene.get("side") as Node).get("_stage")
	var groups: Dictionary = {"track": [], "platforms": [], "train": [], "other": []}
	for child: Node in stage.get_children():
		if child is MultiMeshInstance3D:
			groups["track"].append(child)
		elif child is MeshInstance3D or child.get_script() != null:
			groups["train"].append(child)
		elif child.get_class() == "Node3D":
			groups["platforms"].append(child)
		else:
			groups["other"].append(child)
	print("BREAKDOWN all ", await _sample(20), " stage children ", stage.get_child_count())
	for key: String in ["track", "platforms", "train"]:
		for n: Node3D in groups[key]:
			n.visible = false
		print("BREAKDOWN without %s (%d) " % [key, groups[key].size()], await _sample(20))
		for n: Node3D in groups[key]:
			n.visible = true
	# Cars are re-shown by ExteriorView every frame, so measure them with the whole stage.
	(stage as Node3D).visible = false
	print("BREAKDOWN without 3D stage ", await _sample(20))
	(stage as Node3D).visible = true
	var panels: Array[CanvasItem] = []
	for panel: Node in current_scene.get_children():
		if panel is CanvasItem and panel != current_scene.get("side"):
			panels.append(panel)
	for panel: CanvasItem in panels:
		if not panel.visible:
			continue
		panel.visible = false
		var label: String = panel.name
		var title: Node = panel.find_child("*", true, false)
		for c: Node in panel.find_children("*", "Label", true, false).slice(0, 1):
			label += " «%s»" % (c as Label).text
		print("BREAKDOWN without %s " % label, await _sample(10))
		panel.visible = true
	for panel: CanvasItem in panels:
		panel.visible = false
	print("BREAKDOWN without 2D panels ", await _sample(20))
	quit()
