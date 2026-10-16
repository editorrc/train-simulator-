extends SceneTree
## Renders the 2D demo, drives the train for a while and saves a screenshot.
## Needs a display (use xvfb-run on CI/servers):
##   xvfb-run godot --rendering-driver opengl3 --path game \
##     -s res://tests/visual/capture_demo.gd -- --out=/tmp/demo.png --seconds=40

var _out: String = "user://demo.png"
var _seconds: float = 40.0
var _demo: Node
var _frames: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
	_demo = (load("res://scenes/demo_2d.tscn") as PackedScene).instantiate()
	root.add_child(_demo)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		var world: SimWorld = _demo.get("world")
		var p: StringName = world.player_train_id
		world.apply_command(Commands.brake_valve_set(p, "I"))
		world.apply_command(Commands.reverser_set(p, 1))
		world.apply_command(Commands.controller_set(p, "3"))
		# Fast-forward the simulation (rendering is not needed for every tick).
		for i: int in int(_seconds / world.dt):
			world.step()
	if _frames == 10:
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		return true
	return false
