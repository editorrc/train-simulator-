class_name ParityTrajectory
extends RefCounted
## Runs the scripted drive from parity_script.json and samples the player train.
## Used by test_parity.gd (GDScript vs committed reference) and, through the committed
## reference, by web_preview/parity_check.js (JS port vs GDScript).

const SCRIPT_PATH: String = "res://tests/parity/parity_script.json"
const REFERENCE_PATH: String = "res://tests/parity/parity_reference.json"


static func run() -> Array[Dictionary]:
	var script: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRIPT_PATH))
	var lib := ContentLibrary.new()
	lib.load_all("res://content")
	var world: SimWorld = lib.build_world(StringName(str(script["scenario"])))
	var by_tick: Dictionary = {}
	for c: Variant in script["commands"]:
		var cd: Dictionary = c
		var tick: int = int(cd["tick"])
		if not by_tick.has(tick):
			by_tick[tick] = []
		(by_tick[tick] as Array).append(cd["cmd"])
	var every: int = int(script["sample_every"])
	var samples: Array[Dictionary] = []
	for i: int in int(script["ticks"]):
		for cmd: Variant in by_tick.get(i, []):
			world.apply_command(cmd as Dictionary)
		var events: Array[Dictionary] = world.step()
		var t: Train = world.player()
		if world.tick % every == 0 or not events.is_empty():
			var types: PackedStringArray = []
			for e: Dictionary in events:
				types.append(str(e["type"]))
			(
				samples
				. append(
					{
						"tick": world.tick,
						"speed_ms": t.speed_ms,
						"odometer_m": t.odometer_m,
						"segment": str(t.head.segment_id),
						"offset_m": t.head.offset_m,
						"brake_demand": t.brake_demand,
						"traction_fraction": t.traction_fraction,
						"events": types,
					}
				)
			)
	return samples
