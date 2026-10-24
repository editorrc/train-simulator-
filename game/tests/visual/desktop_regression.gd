extends SceneTree
var time: float = 0.0
var phase: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_open.call_deferred()


func _open() -> void:
	UiLayout.clear()
	root.get_node("Settings").set_value("camera", "view_mode", 0)
	root.get_node("Settings").set_value("audio", "auto_announcements", true)
	root.get_node("Settings").set_value("visual", "night", false)
	change_scene_to_file("res://scenes/main_menu.tscn")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _process(delta: float) -> bool:
	time += delta
	if time < 1.6:
		return false
	time = 0
	var scene: Node = current_scene
	if scene == null:
		return false
	match phase:
		0:
			root.get_texture().get_image().save_png("/tmp/train-final-menu.png")
			scene.call("_start")
		1:
			var w: SimWorld = scene.get("world")
			check(w.player().consist.vehicles.size() == 6, "menu formation selection")
			var desk: Node = scene.call("_panel", "desk")
			print(
				"LAYOUT size=",
				(scene as Control).size,
				" desk=",
				desk.get("position"),
				"/",
				desk.get("size")
			)
			check(
				(
					(desk.get("position") as Vector2).y + (desk.get("size") as Vector2).y
					<= (scene as Control).size.y + 1
				),
				"desk fits screen"
			)
			root.get_texture().get_image().save_png("/tmp/train-final-front.png")
			scene.call("_expand_panel", "desk")
		2:
			var desk: Node = scene.get("desk")
			check((desk.get("_hits") as Array).size() >= 30, "all desk controls have mouse regions")
			desk.call("_click", {"kind": "hold", "id": "whistle"})
			var w: SimWorld = scene.get("world")
			check(w.player().cab.is_on(&"whistle"), "mouse whistle hold")
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			desk.call("_input", release)
			check(not w.player().cab.is_on(&"whistle"), "mouse release outside desk")
			desk.call("_click", {"kind": "announcer", "id": ""})
			var announcer: Node = scene.get("announcer")
			check((announcer.get("_player") as AudioStreamPlayer).stream != null, "offline voice")
			root.get_texture().get_image().save_png("/tmp/train-final-desk.png")
			scene.call("_expand_panel", "desk")
			scene.call("_expand_panel", "map")
		3:
			root.get_texture().get_image().save_png("/tmp/train-final-map.png")
			scene.call("_expand_panel", "map")
			(scene.get("side") as Node).call("next_preset")
		4:
			root.get_texture().get_image().save_png("/tmp/train-final-rear.png")
			root.get_node("Settings").set_value("visual", "night", true)
		5:
			root.get_texture().get_image().save_png("/tmp/train-final-night.png")
			var view: Node = scene.get("side")
			view.call("next_preset")
			view.call("next_preset")
		6:
			root.get_texture().get_image().save_png("/tmp/train-final-cab.png")
			(scene.get("side") as Node).call("next_preset")
		7:
			root.get_texture().get_image().save_png("/tmp/train-final-projection.png")
			(scene.get("settings_dialog") as AcceptDialog).popup_centered()
		8:
			root.get_texture().get_image().save_png("/tmp/train-final-settings.png")
			root.get_node("Settings").set_value("visual", "night", false)
			print("VISUAL_QA ", "PASS" if failures.is_empty() else "FAIL")
			VisualQa.finish.call_deferred(self, 0 if failures.is_empty() else 1)
	phase += 1
	return false
