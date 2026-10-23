extends TestCase
## E4: verify command-to-effort behaviour against each formation's declared data.
## These tests establish the controller contract, not the accuracy of estimated TTX.


func _world(formation: Dictionary, vehicles: Dictionary) -> SimWorld:
	var world: SimWorld = ScenarioBuilder.build(
		Fixtures.scenario("line", 500.0), Fixtures.straight_track(30000.0), formation, vehicles
	)
	assert_true(world.apply_command(Commands.brake_valve_set(&"player", "I")))
	assert_true(world.apply_command(Commands.reverser_set(&"player", 1)))
	return world


func _settle(world: SimWorld, speed_ms: float) -> void:
	# A constant-speed load stand isolates controller output from changing speed,
	# power limits and wheel slip during an acceleration run. Still use real steps.
	var steps: int = ceili(1.0 / world.player().consist.controller_force_ramp_per_s / world.dt) + 1
	for tick: int in steps:
		world.player().speed_ms = speed_ms
		world.step()


func test_every_formation_has_increasing_notch_effort_and_zero_cutoff() -> void:
	var library := ContentLibrary.new()
	library.load_all("res://content")
	assert_true(library.errors.is_empty())
	for id: StringName in [&"er9m_10", &"ed9m_main", &"epl9t_main", &"ekr1_main"]:
		assert_true(id in library.ids_of(&"consist"), "base series is covered: %s" % id)
	for id: Variant in library.ids_of(&"consist"):
		var data: Dictionary = library.get_entry(&"consist", StringName(str(id)))
		for count: Variant in data["formations"]:
			var formation: Dictionary = data.duplicate(true)
			formation["vehicles"] = data["formations"][count]
			for speed_ms: float in [15.0, 25.0]:
				_check_notches(_world(formation, library.vehicles()), speed_ms, str(count))


func _check_notches(world: SimWorld, speed_ms: float, count: String) -> void:
	var train: Train = world.player()
	var previous: float = -1.0
	for index: int in train.consist.controller_positions.size():
		if index > 0:
			assert_true(world.apply_command(Commands.controller_step(train.id, 1)))
		assert_eq(train.controller_index, index)
		_settle(world, speed_ms)
		var position: Dictionary = train.consist.controller_positions[index]
		var context: String = (
			"%s × %s, %s, %.0f m/s" % [train.consist.id, count, position["id"], speed_ms]
		)
		assert_false(train.slipping, "load stand must remain below adhesion limit: " + context)
		assert_almost_eq(train.traction_fraction, float(position["force"]), 1e-9, context)
		var expected: float = minf(
			float(position["force"]) * train.consist.max_traction_force_n(),
			float(position["power"]) * train.consist.max_traction_power_w() / speed_ms
		)
		assert_almost_eq(train.last_traction_n, expected, .001, context)
		assert_true(
			train.last_traction_n > previous, "each higher notch increases effort: " + context
		)
		previous = train.last_traction_n
	# The final physical notch is reachable; the next step cannot wrap or overrun.
	assert_false(world.apply_command(Commands.controller_step(train.id, 1)))
	assert_eq(train.controller_index, train.consist.controller_positions.size() - 1)
	assert_almost_eq(train.traction_fraction, 1.0, 1e-9, "full controller reaches full demand")
	assert_true(world.apply_command(Commands.controller_set(train.id, "0")))
	world.step()
	assert_almost_eq(train.last_traction_n, 0.0, 1e-9, "zero immediately cuts tractive effort")


func test_epl9t_uses_positions_zero_through_six() -> void:
	var library := ContentLibrary.new()
	library.load_all("res://content")
	var data: Dictionary = library.get_entry(&"consist", &"epl9t_main")
	var world: SimWorld = _world(data, library.vehicles())
	assert_eq(world.player().consist.controller_positions.size(), 7)
	for index: int in 7:
		assert_eq(world.player().consist.controller_index_of(str(index)), index)


func test_ekr1_uses_percent_demand_through_one_hundred() -> void:
	var library := ContentLibrary.new()
	library.load_all("res://content")
	var data: Dictionary = library.get_entry(&"consist", &"ekr1_main")
	var world: SimWorld = _world(data, library.vehicles())
	assert_eq(world.player().consist.controller_positions.size(), 11)
	assert_eq(world.player().consist.controller_index_of("0"), 0)
	for index: int in range(1, 11):
		assert_eq(world.player().consist.controller_index_of("%d%%" % (index * 10)), index)
