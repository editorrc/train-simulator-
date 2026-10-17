extends TestCase


func test_spring_response_has_inertia_and_matches_different_frame_rates() -> void:
	var reference: Vector2
	for fps: int in [20, 60, 144]:
		var state := Vector2.ZERO
		state = RailSuspension.spring(state.x, state.y, 1.0, 5.0, 1.0 / fps)
		assert_between(state.x, .0001, .1, "body does not jump to equilibrium")
		for i: int in 2 * fps - 1:
			state = RailSuspension.spring(state.x, state.y, 1.0, 5.0, 1.0 / fps)
		if fps == 20:
			reference = state
		assert_almost_eq(state.x, reference.x, 1e-5)
		assert_almost_eq(state.y, reference.y, 1e-5)
