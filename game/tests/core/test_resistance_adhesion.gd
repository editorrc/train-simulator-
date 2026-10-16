extends TestCase

var spec: VehicleSpec


func before_each() -> void:
	spec = VehicleSpec.from_dict(Fixtures.er9m_vehicles()["er9m_motor"] as Dictionary)


func test_vehicle_spec_converted_to_si() -> void:
	assert_almost_eq(spec.mass_empty_kg, 66000.0, 1e-6)
	assert_almost_eq(spec.max_traction_force_n, 72000.0, 1e-6)
	assert_almost_eq(spec.max_traction_power_w, 800000.0, 1e-6)
	assert_almost_eq(spec.max_speed_ms, Units.kmh_to_ms(120.0), 1e-9)
	assert_true(spec.is_powered())
	assert_false(spec.verified, "ER9M numbers are placeholders until RESEARCH S1/S2")


func test_basic_resistance_davis() -> void:
	# w0 = 1.1 + 0.011·60 + 0.00018·60² = 2.408 N/kN at 60 km/h.
	var expected: float = Units.specific_resistance_to_n(2.408, 66000.0)
	assert_almost_eq(Resistance.basic_n(spec, 66000.0, Units.kmh_to_ms(60.0)), expected, 1e-3)
	assert_almost_eq(
		Resistance.basic_n(spec, 66000.0, -Units.kmh_to_ms(60.0)), expected, 1e-3, "sign-free"
	)


func test_starting_resistance_fades_out() -> void:
	var at_rest: float = Resistance.starting_n(spec, 66000.0, 0.0)
	assert_almost_eq(at_rest, Units.specific_resistance_to_n(2.5, 66000.0), 1e-6)
	assert_true(Resistance.starting_n(spec, 66000.0, Units.kmh_to_ms(2.5)) < at_rest)
	assert_almost_eq(Resistance.starting_n(spec, 66000.0, Units.kmh_to_ms(6.0)), 0.0, 1e-9)


func test_curve_and_grade() -> void:
	# 700 / 500 = 1.4 N/kN.
	assert_almost_eq(
		Resistance.curve_n(1000.0, 500.0), Units.specific_resistance_to_n(1.4, 1000.0), 1e-9
	)
	assert_almost_eq(Resistance.curve_n(1000.0, INF), 0.0, 1e-12)
	# 10 ‰ uphill on 100 t pulls back with ~9.8 kN.
	assert_almost_eq(Resistance.grade_n(100000.0, 0.010), -9806.65, 1e-6)
	assert_true(Resistance.grade_n(100000.0, -0.010) > 0.0, "downhill pushes forward")


func test_adhesion_drops_with_speed_and_wet_rail() -> void:
	var coef: Dictionary = Fixtures.er9m_consist_data()["adhesion"]
	var dry0: float = Adhesion.coefficient(coef, 0.0, Adhesion.RailCondition.DRY)
	assert_almost_eq(dry0, 0.33, 1e-9)
	assert_true(Adhesion.coefficient(coef, 30.0, Adhesion.RailCondition.DRY) < dry0)
	assert_true(Adhesion.coefficient(coef, 0.0, Adhesion.RailCondition.WET) < dry0)


func test_consist_totals() -> void:
	var c: ConsistSpec = Fixtures.er9m()
	assert_eq(c.vehicles.size(), 10)
	assert_almost_eq(c.length_m(), 215.0, 1e-9)
	assert_almost_eq(c.empty_mass_kg(), 546000.0, 1e-6)
	assert_almost_eq(c.max_traction_force_n(), 360000.0, 1e-6)
	assert_eq(c.controller_index_of("М"), 1)
	assert_eq(c.brake_valve_index_of("VI"), 6)
