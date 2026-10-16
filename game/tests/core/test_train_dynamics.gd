extends TestCase
## Behavioural corridors. Bounds are deliberately wide: the ER9M numbers are placeholders
## (verified:false). Tighten them once RESEARCH S2/R6 data is in.


func _depart(world: SimWorld, position: String) -> void:
	world.apply_command(Commands.brake_valve_set(&"player", "I"))
	world.apply_command(Commands.reverser_set(&"player", 1))
	world.apply_command(Commands.controller_set(&"player", position))


func test_stands_still_without_traction() -> void:
	var w: SimWorld = Fixtures.world_on_straight()
	Fixtures.run_until(w, func(_x: SimWorld) -> bool: return false, 10.0)
	assert_almost_eq(w.player().speed_ms, 0.0, 1e-12)
	assert_almost_eq(w.player().head.offset_m, 500.0, 1e-9)


func test_no_traction_in_neutral_reverser() -> void:
	var w: SimWorld = Fixtures.world_on_straight()
	w.apply_command(Commands.controller_set(&"player", "4"))
	Fixtures.run_until(w, func(_x: SimWorld) -> bool: return false, 5.0)
	assert_almost_eq(w.player().speed_ms, 0.0, 1e-12)


func test_acceleration_to_100_kmh() -> void:
	var w: SimWorld = Fixtures.world_on_straight()
	_depart(w, "4")
	var target: float = Units.kmh_to_ms(100.0)
	var t: float = Fixtures.run_until(
		w, func(x: SimWorld) -> bool: return x.player().speed_ms >= target, 300.0
	)
	# A loaded suburban EMU reaches 100 km/h in roughly a minute or two.
	assert_between(t, 40.0, 150.0, "0→100 km/h time, s")


func test_initial_acceleration_is_realistic() -> void:
	var w: SimWorld = Fixtures.world_on_straight()
	_depart(w, "4")
	Fixtures.run_until(w, func(_x: SimWorld) -> bool: return false, 5.0)
	assert_between(w.player().accel_ms2, 0.3, 0.9, "start acceleration, m/s²")


func test_traction_ramps_up_not_instantly() -> void:
	var w: SimWorld = Fixtures.world_on_straight()
	_depart(w, "4")
	w.step()
	assert_true(w.player().traction_fraction < 0.05)


func test_coasting_slows_down() -> void:
	var w: SimWorld = Fixtures.world_on_straight()
	_depart(w, "4")
	var target: float = Units.kmh_to_ms(80.0)
	Fixtures.run_until(w, func(x: SimWorld) -> bool: return x.player().speed_ms >= target, 300.0)
	w.apply_command(Commands.controller_set(&"player", "0"))
	Fixtures.run_until(w, func(_x: SimWorld) -> bool: return false, 60.0)
	var v: float = w.player().speed_ms
	assert_true(v < target, "coasting loses speed")
	assert_true(v > target * 0.8, "but slowly (low rolling resistance)")


func _braking_distance(position: String) -> float:
	var w: SimWorld = Fixtures.world_on_straight()
	_depart(w, "4")
	var target: float = Units.kmh_to_ms(100.0)
	Fixtures.run_until(w, func(x: SimWorld) -> bool: return x.player().speed_ms >= target, 300.0)
	w.apply_command(Commands.controller_set(&"player", "0"))
	w.apply_command(Commands.brake_valve_set(&"player", position))
	var from: float = w.player().odometer_m
	Fixtures.run_until(w, func(x: SimWorld) -> bool: return x.player().speed_ms <= 0.0, 300.0)
	return w.player().odometer_m - from


func test_service_braking_distance_from_100() -> void:
	assert_between(_braking_distance("V"), 400.0, 1000.0, "service brake, m")


func test_emergency_is_shorter_than_service() -> void:
	var emergency: float = _braking_distance("VI")
	assert_between(emergency, 300.0, 800.0, "emergency brake, m")
	assert_true(emergency < _braking_distance("V"))


func test_lap_position_holds_brake() -> void:
	var w: SimWorld = Fixtures.world_on_straight()
	w.apply_command(Commands.brake_valve_set(&"player", "V"))
	Fixtures.run_until(w, func(_x: SimWorld) -> bool: return false, 1.0)
	w.apply_command(Commands.brake_valve_set(&"player", "IV"))
	var held: float = w.player().brake_demand
	Fixtures.run_until(w, func(_x: SimWorld) -> bool: return false, 5.0)
	assert_almost_eq(w.player().brake_demand, held, 1e-9)


func test_rolls_away_downhill_without_brakes() -> void:
	var w: SimWorld = Fixtures.world_on_straight(30000.0, -10.0)
	w.apply_command(Commands.brake_valve_set(&"player", "I"))
	Fixtures.run_until(w, func(_x: SimWorld) -> bool: return false, 30.0)
	assert_true(w.player().speed_ms > 1.0, "a 10 ‰ grade overcomes rolling resistance")


func test_rolls_back_uphill_and_brakes_hold() -> void:
	var w: SimWorld = Fixtures.world_on_straight(30000.0, 10.0, 15000.0)
	w.apply_command(Commands.brake_valve_set(&"player", "I"))
	Fixtures.run_until(w, func(_x: SimWorld) -> bool: return false, 20.0)
	assert_true(w.player().speed_ms < -0.5, "rolls backwards on an uphill without brakes")
	var held := Fixtures.world_on_straight(30000.0, 10.0, 15000.0)
	held.apply_command(Commands.brake_valve_set(&"player", "V"))
	Fixtures.run_until(held, func(_x: SimWorld) -> bool: return false, 20.0)
	assert_almost_eq(held.player().speed_ms, 0.0, 1e-9, "applied brakes hold on 10 ‰")


func test_wet_rail_slips_on_hard_start() -> void:
	var w: SimWorld = Fixtures.world_on_straight()
	w.player().rail_condition = Adhesion.RailCondition.LEAVES
	w.player().load_factor = 0.0
	_depart(w, "4")
	var slipped: Array[bool] = [false]
	for i: int in 600:
		for e: Dictionary in w.step():
			if e["type"] == &"wheel_slip":
				slipped[0] = true
	assert_true(slipped[0], "full power on leaves must slip")


func test_buffer_stop_collision_event() -> void:
	var w: SimWorld = Fixtures.world_on_straight(1500.0, 0.0, 500.0)
	_depart(w, "4")
	var hit: Array[Dictionary] = []
	for i: int in 6000:
		for e: Dictionary in w.step():
			if e["type"] == &"buffer_stop_collision":
				hit.append(e)
		if not hit.is_empty():
			break
	assert_false(hit.is_empty())
	assert_almost_eq(w.player().head.offset_m, 1500.0, 1e-6)
	assert_almost_eq(w.player().speed_ms, 0.0, 1e-12)


func test_speed_limit_seen_by_whole_train() -> void:
	var w: SimWorld = ScenarioBuilder.build(
		Fixtures.scenario("s1_a_to_b", 800.0),
		load_json("res://content/base/routes/test_polygon/track_graph.json"),
		Fixtures.er9m_consist_data(),
		Fixtures.er9m_vehicles()
	)
	w.step()
	# Head is past 700 m (120 km/h) but the rear is still in the 60 km/h zone.
	assert_almost_eq(w.player().last_speed_limit_ms, Units.kmh_to_ms(60.0), 1e-9)
