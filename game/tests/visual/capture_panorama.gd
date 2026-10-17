extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Session").set("car_count", 6)
	change_scene_to_file("res://scenes/main_menu.tscn")
	for i: int in 24:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/artem-panorama-latest.png")
	quit()
