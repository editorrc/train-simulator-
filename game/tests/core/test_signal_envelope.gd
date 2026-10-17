extends TestCase


func test_release_and_repress_preserve_gain() -> void:
	var e := SignalEnvelope.new()
	e.advance(true, 0.06)
	assert_almost_eq(e.gain, 1.0, 1e-9)
	e.advance(false, 0.15)
	assert_between(e.gain, 0.5, 0.9)
	var fading: float = e.gain
	e.advance(true, 0.01)
	assert_true(e.gain > fading)
	e.advance(false, 1.0)
	assert_almost_eq(e.gain, 0.0, 1e-9)


func test_release_duration_independent_of_frame_rate() -> void:
	for fps: int in [20, 60, 144]:
		var e := SignalEnvelope.new()
		e.advance(true, 1.0)
		for i: int in int(ceil(e.release_s * fps)):
			e.advance(false, 1.0 / fps)
		assert_almost_eq(e.gain, 0.0, 1e-8)
