extends TestCase
## The committed reference must match the current GDScript physics. If you changed the
## physics on purpose: re-record (see record_reference.gd), then update web_preview/sim.js
## until `node web_preview/parity_check.js` passes.


func test_reference_is_current() -> void:
	var ref: Dictionary = load_json(ParityTrajectory.REFERENCE_PATH)
	var expected: Array = ref.get("samples", [])
	var actual: Array[Dictionary] = ParityTrajectory.run()
	assert_eq(actual.size(), expected.size(), "sample count")
	for i: int in mini(actual.size(), expected.size()):
		var a: Dictionary = actual[i]
		var e: Dictionary = expected[i]
		if (
			int(a["tick"]) != int(e["tick"])
			or absf(float(a["speed_ms"]) - float(e["speed_ms"])) > 1e-9
			or absf(float(a["odometer_m"]) - float(e["odometer_m"])) > 1e-6
		):
			fail("diverged at sample %d (tick %s): %s vs %s" % [i, a["tick"], a, e])
			return
