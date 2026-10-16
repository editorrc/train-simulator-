extends SceneTree
## Regenerates parity_reference.json after an intentional physics change:
##   godot --headless --path game -s res://tests/parity/record_reference.gd


func _initialize() -> void:
	var samples: Array[Dictionary] = ParityTrajectory.run()
	var path: String = ProjectSettings.globalize_path(ParityTrajectory.REFERENCE_PATH)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"samples": samples}, " ", false, true) + "\n")
	f.close()
	print("recorded %d samples to %s" % [samples.size(), path])
	quit(0)
