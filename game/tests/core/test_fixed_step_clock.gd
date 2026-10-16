extends TestCase


func _run(clock: FixedStepClock, frame_delta: float) -> int:
	var steps: int = clock.accumulate(frame_delta)
	for i: int in steps:
		clock.commit_step()
	return steps


func test_steps_match_real_time() -> void:
	var clock := FixedStepClock.new(0.01, 100)
	var total: int = 0
	for i: int in 100:
		total += _run(clock, 0.016)
	# 1.6 s of frames at 10 ms steps → 160 steps (±1 for float accumulation).
	assert_between(float(total), 159.0, 160.0)
	assert_eq(clock.tick, total)
	assert_almost_eq(clock.sim_time, total * 0.01, 1e-9)


func test_pause_stops_time() -> void:
	var clock := FixedStepClock.new(0.01, 100)
	clock.paused = true
	assert_eq(_run(clock, 1.0), 0)
	assert_eq(clock.tick, 0)


func test_time_scale() -> void:
	var clock := FixedStepClock.new(0.01, 100)
	clock.time_scale = 4.0
	assert_eq(_run(clock, 0.1), 40)


func test_backlog_is_capped() -> void:
	var clock := FixedStepClock.new(0.01, 8)
	assert_eq(_run(clock, 5.0), 8, "a 5 s hitch must not run 500 steps")
	assert_almost_eq(clock.interpolation_alpha(), 0.0, 1e-9, "backlog dropped")


func test_default_step_is_60hz() -> void:
	assert_almost_eq(SimConfig.SIM_DT, 1.0 / 60.0, 1e-12)
