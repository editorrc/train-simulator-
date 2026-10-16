extends TestCase

const POLYGON_GRAPH: String = "res://content/base/routes/test_polygon/track_graph.json"


func _polygon_world(offset_m: float) -> SimWorld:
	return ScenarioBuilder.build(
		Fixtures.scenario("s1_a_to_b", offset_m),
		load_json(POLYGON_GRAPH),
		Fixtures.er9m_consist_data(),
		Fixtures.er9m_vehicles()
	)


func test_controller_steps_are_bounded() -> void:
	var w: SimWorld = Fixtures.world_on_straight()
	assert_false(w.apply_command(Commands.controller_step(&"player", -1)), "already at 0")
	assert_true(w.apply_command(Commands.controller_step(&"player", 1)))
	assert_eq(w.player().controller_position_id(), "М")
	assert_eq(w.events.back()["type"], &"command_rejected")


func test_brake_valve_default_is_running_position() -> void:
	assert_eq(Fixtures.world_on_straight().player().brake_valve_position_id(), "II")


func test_reverser_locked_while_moving() -> void:
	var w: SimWorld = Fixtures.world_on_straight()
	w.apply_command(Commands.reverser_set(&"player", 1))
	w.apply_command(Commands.controller_set(&"player", "2"))
	Fixtures.run_until(w, func(_x: SimWorld) -> bool: return false, 10.0)
	assert_false(w.apply_command(Commands.reverser_set(&"player", -1)))


func test_switch_under_train_is_locked() -> void:
	# Head 50 m past the west switch of station B: the train stands on it.
	var w: SimWorld = _polygon_world(4950.0)
	w.player().head = TrackPosition.new(&"s2_b_track1", 50.0, 1)
	assert_false(w.apply_command(Commands.switch_set(&"sw_b_west", true)))
	assert_true(w.apply_command(Commands.switch_set(&"sw_b_east", true)), "free switch")


func test_scenario_start_state() -> void:
	var w: SimWorld = _polygon_world(520.0)
	assert_eq(w.player().head.segment_id, &"s1_a_to_b")
	assert_almost_eq(w.clock_s(), 8 * 3600.0, 1e-9)
	assert_eq(w.trains.size(), 1)


func _drive(w: SimWorld) -> void:
	# Command script keyed by tick, so record and replay are identical by construction.
	var script: Dictionary = {
		0: Commands.brake_valve_set(&"player", "I"),
		1: Commands.reverser_set(&"player", 1),
		2: Commands.controller_set(&"player", "3"),
		1800: Commands.controller_set(&"player", "0"),
		2400: Commands.brake_valve_set(&"player", "V"),
		2600: Commands.brake_valve_set(&"player", "IV"),
	}
	for i: int in 3600:
		if script.has(i):
			w.apply_command(script[i] as Dictionary)
		w.step()


func test_deterministic_and_replayable() -> void:
	var a: SimWorld = _polygon_world(520.0)
	_drive(a)
	var b: SimWorld = _polygon_world(520.0)
	_drive(b)
	assert_eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()))
	# Replay from the command log alone.
	var c: SimWorld = _polygon_world(520.0)
	var by_tick: Dictionary = {}
	for cmd: Dictionary in a.command_log:
		by_tick[int(cmd["tick"])] = cmd
	for i: int in 3600:
		if by_tick.has(i):
			c.apply_command(by_tick[i] as Dictionary)
		c.step()
	assert_eq(JSON.stringify(c.to_dict()), JSON.stringify(a.to_dict()))


func test_save_and_restore() -> void:
	var a: SimWorld = _polygon_world(520.0)
	_drive(a)
	var saved: String = JSON.stringify(a.to_dict())
	var b: SimWorld = _polygon_world(520.0)
	b.restore(JSON.parse_string(saved) as Dictionary)
	for i: int in 600:
		a.step()
		b.step()
	assert_almost_eq(b.player().speed_ms, a.player().speed_ms, 1e-9)
	assert_almost_eq(b.player().odometer_m, a.player().odometer_m, 1e-6)
	assert_eq(b.tick, a.tick)
