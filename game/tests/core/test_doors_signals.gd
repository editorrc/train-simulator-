extends TestCase


func _world() -> SimWorld:
	return ScenarioBuilder.build(
		Fixtures.scenario("line", 500.0),
		Fixtures.straight_track(30000.0),
		Fixtures.er9m_consist_data(),
		Fixtures.er9m_vehicles()
	)


func test_doors_block_traction_and_cannot_open_while_moving() -> void:
	var w: SimWorld = _world()
	var t: Train = w.player()
	assert_false(t.cab.is_on(&"doors_left"))
	assert_eq(t.operate(&"doors_left", true), "")
	t.reverser = 1
	t.controller_index = 5
	for i: int in 120:
		w.step()
	assert_almost_eq(t.speed_ms, 0.0, 1e-9)
	t.operate(&"doors_left", false)
	t.speed_ms = 10.0
	assert_false(t.operate(&"doors_left", true).is_empty())
	assert_false(t.cab.is_on(&"doors_left"))


func test_whistle_and_horn_are_independent() -> void:
	var t: Train = _world().player()
	assert_eq(t.operate(&"whistle", true), "")
	assert_true(t.cab.is_on(&"whistle"))
	assert_false(t.cab.is_on(&"horn"))
	assert_eq(t.operate(&"horn", true), "")
	t.operate(&"whistle", false)
	assert_true(t.cab.is_on(&"horn"))
