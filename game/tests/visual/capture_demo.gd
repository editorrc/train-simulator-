extends SceneTree
## Renders the drive scene (and optionally the menu), runs the simulation and saves a
## screenshot. Needs a display (use xvfb-run on CI/servers):
##   xvfb-run godot --rendering-driver opengl3 --path game \
##     -s res://tests/visual/capture_demo.gd -- --out=/tmp/demo.png --script=drive_warm
## Scripts: menu | drive_warm | drive_cold | drive_brake

var _out: String = "user://demo.png"
var _script: String = "drive_warm"
var _scene: Node
var _frames: int = 0
var _world: SimWorld


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--script="):
			_script = arg.substr(9)
	var session: Node = root.get_node("Session")
	var path: String = "res://scenes/drive.tscn"
	match _script:
		"menu":
			path = "res://scenes/main_menu.tscn"
			session.set("livery_id", &"city_blue")
		"drive_cold":
			session.set("scenario_id", &"polygon_cold_start")
		_:
			session.set("scenario_id", &"polygon_free_drive")
	UiLayout.clear()
	_scene = (load(path) as PackedScene).instantiate()
	root.add_child(_scene)


func _cmd(c: Dictionary) -> void:
	_world.apply_command(c)


func _run(seconds: float) -> void:
	for i: int in int(seconds / _world.dt):
		_world.step()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3 and _script != "menu":
		_world = _scene.get("world")
		var p: StringName = _world.player_train_id
		match _script:
			"drive_warm":
				_cmd(Commands.brake_valve_set(p, "I"))
				_cmd(Commands.reverser_set(p, 1))
				_cmd(Commands.controller_set(p, "3"))
				_run(30.0)
				_cmd(Commands.brake_valve_set(p, "II"))
			"drive_brake":
				_cmd(Commands.brake_valve_set(p, "I"))
				_cmd(Commands.reverser_set(p, 1))
				_cmd(Commands.controller_set(p, "4"))
				_run(40.0)
				_cmd(Commands.controller_set(p, "0"))
				_cmd(Commands.brake_valve_set(p, "V"))
				_run(3.0)
				_cmd(Commands.brake_valve_set(p, "IV"))
			"drive_cold":
				_cmd(Commands.cab_control(p, &"battery", true))
				_cmd(Commands.cab_control(p, &"control_circuits", true))
				_cmd(Commands.cab_control(p, &"aux_compressor", true))
				_run(20.0)
				_cmd(Commands.cab_control(p, &"pantograph", true))
				_run(1.0)
	if _frames == 4 and _script != "menu":
		var view: RailView = _scene.get("side")
		for a: String in OS.get_cmdline_user_args():
			if a.begins_with("--preset="):
				view.preset_index = int(a.substr(9))
		view.snap_camera()
	if _frames == 40:
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		return true
	return false
