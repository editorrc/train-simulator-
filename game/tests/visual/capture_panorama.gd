extends SceneTree
## Menu screenshot for visual review:
## godot --path game -s res://tests/visual/capture_panorama.gd [-- --series=ed9m_main --livery=id]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session: Node = root.get_node("Session")
	session.set("car_count", 6)
	var out: String = "/tmp/artem-panorama-latest.png"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--series="):
			session.call("select_series", StringName(arg.substr(9)))
			out = "/tmp/artem-panorama-%s.png" % arg.substr(9)
		elif arg.begins_with("--livery="):
			session.set("livery_id", StringName(arg.substr(9)))
	change_scene_to_file("res://scenes/main_menu.tscn")
	for i: int in 24:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
