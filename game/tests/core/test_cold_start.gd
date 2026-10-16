extends TestCase
## The startup procedure of docs/content cab.json, driven through commands only.

const P: StringName = &"player"
const CHECKLIST: String = "res://content/base/rolling_stock/er9m/cab.json"

var w: SimWorld


func before_each() -> void:
	var sc: Dictionary = Fixtures.scenario("line", 500.0)
	sc["start"]["cold_start"] = true
	w = ScenarioBuilder.build(
		sc, Fixtures.straight_track(30000.0), Fixtures.er9m_consist_data(), Fixtures.er9m_vehicles()
	)


func _op(control: StringName, value: bool = true) -> bool:
	return w.apply_command(Commands.cab_control(P, control, value))


func _wait(seconds: float) -> void:
	for i: int in int(seconds * 60.0):
		w.step()


func _last_reason() -> String:
	return "" if w.events.is_empty() else str(w.events.back().get("reason", ""))


func test_cold_train_is_dead() -> void:
	var t: Train = w.player()
	assert_false(t.check("battery_on"))
	assert_false(t.check("pantograph_up"))
	assert_almost_eq(t.air.p_gr, 0.0, 1e-9)
	w.apply_command(Commands.reverser_set(P, 1))
	w.apply_command(Commands.controller_set(P, "4"))
	_wait(5.0)
	assert_almost_eq(t.speed_ms, 0.0, 1e-12, "no power, no motion")


func test_main_breaker_needs_voltage() -> void:
	_op(&"battery")
	_op(&"control_circuits")
	assert_false(_op(&"main_breaker_on"))
	assert_true(_last_reason().contains("напруги"), _last_reason())


func test_pantograph_needs_air() -> void:
	_op(&"battery")
	_op(&"control_circuits")
	_op(&"pantograph")
	_wait(10.0)
	assert_false(w.player().check("pantograph_up"), "no air in the pantograph reservoir")
	_op(&"aux_compressor", true)
	_wait(32.0)
	_op(&"aux_compressor", false)
	_wait(7.0)
	assert_true(w.player().check("pantograph_up"))
	assert_true(w.player().check("catenary_voltage"))


func test_main_breaker_requires_controller_zero() -> void:
	_op(&"battery")
	_op(&"control_circuits")
	w.player().air.p_panto = Units.kgf_cm2_to_pa(5.0)
	_op(&"pantograph")
	_wait(7.0)
	w.apply_command(Commands.controller_set(P, "1"))
	assert_false(_op(&"main_breaker_on"))
	assert_true(_last_reason().contains("контролер"), _last_reason())


func _full_startup() -> void:
	_op(&"battery")
	_op(&"control_circuits")
	_op(&"aux_compressor", true)
	_wait(32.0)
	_op(&"aux_compressor", false)
	_op(&"pantograph")
	_wait(7.0)
	assert_true(_op(&"main_breaker_on"), "ГВ: %s" % _last_reason())
	_op(&"aux_machines")
	_wait(7.0)
	_op(&"compressors")
	_op(&"ep_brake")
	_wait(240.0)
	w.apply_command(Commands.reverser_set(P, 1))


func test_full_startup_checklist_then_drive() -> void:
	_full_startup()
	var t: Train = w.player()
	var cab: Dictionary = load_json(CHECKLIST)
	for step: Variant in cab["startup_checklist"]:
		var check: String = str((step as Dictionary)["check"])
		assert_true(t.check(check), "checklist step not done: " + check)
	w.apply_command(Commands.controller_set(P, "2"))
	_wait(10.0)
	assert_true(t.speed_ms > 2.0, "ready train moves")


func test_lowering_pantograph_under_load_trips() -> void:
	_full_startup()
	w.apply_command(Commands.controller_set(P, "3"))
	_wait(5.0)
	var seen: Array[StringName] = []
	_op(&"pantograph", false)
	for i: int in 60 * 4:
		for e: Dictionary in w.step():
			seen.append(e["type"])
	assert_true(&"pantograph_lowered_under_load" in seen)
	assert_true(&"main_breaker_tripped" in seen)
	assert_true(w.player().check("protection_tripped"))
	_op(&"pantograph", true)
	_wait(7.0)
	w.apply_command(Commands.controller_set(P, "0"))
	assert_false(_op(&"main_breaker_on"), "RP latched")
	assert_true(_op(&"protection_reset"))
	assert_true(_op(&"main_breaker_on"))


func test_traction_blocked_while_brakes_applied() -> void:
	_full_startup()
	w.apply_command(Commands.brake_valve_set(P, "V"))
	_wait(3.0)
	w.apply_command(Commands.brake_valve_set(P, "IV"))
	w.apply_command(Commands.controller_set(P, "4"))
	_wait(5.0)
	assert_almost_eq(w.player().speed_ms, 0.0, 1e-12)


func test_overspeed_event() -> void:
	var g: Dictionary = Fixtures.straight_track(30000.0)
	g["segments"][0]["speed_limits"] = [{"from_m": 0, "to_m": 30000, "speed_kmh": 40}]
	var sc: Dictionary = Fixtures.scenario("line", 500.0)
	var world: SimWorld = ScenarioBuilder.build(
		sc, g, Fixtures.er9m_consist_data(), Fixtures.er9m_vehicles()
	)
	world.apply_command(Commands.brake_valve_set(P, "I"))
	world.apply_command(Commands.reverser_set(P, 1))
	world.apply_command(Commands.controller_set(P, "4"))
	var count: int = 0
	for i: int in 60 * 60:
		for e: Dictionary in world.step():
			if e["type"] == &"overspeed":
				count += 1
	assert_eq(count, 1, "one event per entry into overspeed")
