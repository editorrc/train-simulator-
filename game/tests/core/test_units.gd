extends TestCase


func test_speed_round_trip() -> void:
	assert_almost_eq(Units.kmh_to_ms(36.0), 10.0, 1e-9)
	assert_almost_eq(Units.ms_to_kmh(Units.kmh_to_ms(120.0)), 120.0, 1e-9)


func test_pressure_round_trip() -> void:
	assert_almost_eq(Units.kgf_cm2_to_pa(5.0), 490332.5, 1e-6)
	assert_almost_eq(Units.pa_to_kgf_cm2(Units.kgf_cm2_to_pa(4.8)), 4.8, 1e-9)


func test_force_and_mass() -> void:
	assert_almost_eq(Units.tf_to_n(1.0), 9806.65, 1e-9)
	assert_almost_eq(Units.n_to_tf(Units.tf_to_n(25.0)), 25.0, 1e-9)
	assert_almost_eq(Units.tonnes_to_kg(48.0), 48000.0, 1e-9)
	assert_almost_eq(Units.kg_to_tonnes(48000.0), 48.0, 1e-9)


func test_grade() -> void:
	assert_almost_eq(Units.permille_to_ratio(6.0), 0.006, 1e-12)
	assert_almost_eq(Units.ratio_to_permille(-0.008), -8.0, 1e-12)


func test_specific_resistance() -> void:
	# 1 N/kN on a 1000 t train = 1 N per 1 kN of weight = m·g/1000.
	assert_almost_eq(Units.specific_resistance_to_n(1.0, 1_000_000.0), 9806.65, 1e-6)


func test_distance() -> void:
	assert_almost_eq(Units.km_to_m(50.8), 50800.0, 1e-9)
	assert_almost_eq(Units.m_to_km(1500.0), 1.5, 1e-12)
