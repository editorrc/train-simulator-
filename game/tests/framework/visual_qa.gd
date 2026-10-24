class_name VisualQa
extends RefCounted
## Schedule this deferred, so the caller releases its local resource references.
## AudioServer retires stopped playbacks on its next mix; quit() immediately after
## exercising a sound otherwise reports live WAV/playback resources as shutdown leaks.


static func finish(tree: SceneTree, exit_code: int = 0) -> void:
	if tree.current_scene != null:
		tree.current_scene.queue_free()
	for frame: int in 4:
		await tree.process_frame
	await tree.create_timer(.1).timeout
	tree.quit(exit_code)
