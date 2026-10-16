extends TestCase

const II := PneumaticSystem.ValveKind.TRAIN

var air: PneumaticSystem


func before_each() -> void:
	air = PneumaticSystem.from_dict(Fixtures.er9m_consist_data()["pneumatic"] as Dictionary)


func _run(
	seconds: float, kind: PneumaticSystem.ValveKind, compressors: bool = true, ep: bool = false
) -> void:
	for i: int in int(seconds * 60.0):
		air.step(1.0 / 60.0, kind, compressors, false, ep)


func _kgf(pa: float) -> float:
	return Units.pa_to_kgf_cm2(pa)


func test_compressor_governor_hysteresis() -> void:
	_run(200.0, II)
	assert_between(_kgf(air.p_gr), 6.5, 8.0)
	# Drain below the cut-in pressure: compressor must restart and refill to cut-out.
	air.p_gr = Units.kgf_cm2_to_pa(6.0)
	_run(1.0, II)
	assert_true(air.compressor_working)
	_run(60.0, II)
	assert_almost_eq(_kgf(air.p_gr), 8.0, 0.05)


func test_no_compressors_no_air() -> void:
	_run(30.0, II, false)
	assert_almost_eq(air.p_gr, 0.0, 1e-9)
	assert_almost_eq(air.p_tm, 0.0, 1e-9)


func test_train_position_charges_pipe_to_norm() -> void:
	_run(240.0, II)
	assert_almost_eq(_kgf(air.p_tm), 4.8, 0.05)
	assert_almost_eq(_kgf(air.p_tc), 0.0, 1e-6)


func test_position_one_overcharges_and_two_returns() -> void:
	air.charge_fully()
	_run(5.0, PneumaticSystem.ValveKind.CHARGE)
	assert_true(_kgf(air.p_tm) > 5.0, "position I overcharges the pipe")
	_run(60.0, II)
	assert_almost_eq(_kgf(air.p_tc), 0.0, 1e-9, "slow overcharge elimination must not apply")
	_run(600.0, II)
	assert_almost_eq(_kgf(air.p_tm), 4.8, 0.05)


func test_leaks_in_lap_do_not_apply() -> void:
	air.charge_fully()
	_run(30.0, PneumaticSystem.ValveKind.LAP)
	assert_almost_eq(_kgf(air.p_tc), 0.0, 1e-9)


func test_slow_service_applies() -> void:
	air.charge_fully()
	_run(8.0, PneumaticSystem.ValveKind.SERVICE_SLOW)
	assert_true(_kgf(air.p_tc) > 0.3)


func test_service_brake_and_direct_release() -> void:
	air.charge_fully()
	_run(2.5, PneumaticSystem.ValveKind.SERVICE)  # −0.5 kgf/cm² in the pipe
	_run(5.0, PneumaticSystem.ValveKind.LAP_FEED)
	var tc: float = _kgf(air.p_tc)
	# Distributor ratio 2.5: 0.5 reduction → ≈ 1.25 in the cylinders.
	assert_between(tc, 1.0, 1.5, "TC after a 0.5 reduction")
	_run(5.0, PneumaticSystem.ValveKind.LAP_FEED)
	assert_almost_eq(_kgf(air.p_tc), tc, 0.02, "lap holds")
	_run(15.0, II)
	assert_almost_eq(_kgf(air.p_tc), 0.0, 1e-6, "direct release in II")


func test_emergency_fills_cylinders_fast() -> void:
	air.charge_fully()
	_run(4.0, PneumaticSystem.ValveKind.EMERGENCY)
	assert_almost_eq(_kgf(air.p_tc), 3.8, 0.01)
	assert_true(_kgf(air.p_tm) < 0.5, "pipe vented")


func test_ep_brake_keeps_pipe_pressure() -> void:
	air.charge_fully()
	_run(3.0, PneumaticSystem.ValveKind.SERVICE, true, true)
	assert_true(_kgf(air.p_tc) > 2.0, "EP brake fills cylinders")
	assert_true(_kgf(air.p_tm) > 4.7, "without venting the pipe")
	_run(10.0, II, true, true)
	assert_almost_eq(_kgf(air.p_tc), 0.0, 1e-6)


func test_aux_compressor_fills_pantograph_reservoir() -> void:
	for i: int in 60 * 50:
		air.step(1.0 / 60.0, II, false, true, false)
	assert_almost_eq(_kgf(air.p_panto), 5.0, 0.01)
	assert_almost_eq(air.p_gr, 0.0, 1e-9, "main reservoirs untouched")
