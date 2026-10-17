extends TestCase


func test_joint_timing_is_consistent_across_audio_block_sizes() -> void:
	var mixer := RailJointMixer.new()
	mixer.axle_offsets = PackedFloat64Array([2.2, 4.8, 17.2, 19.8])
	var all: Array[Dictionary] = mixer.events(0.0, 100.0)
	var split: Array[Dictionary] = []
	for block: int in 40:
		for hit: Dictionary in mixer.events(block * 2.5, (block + 1) * 2.5):
			split.append(hit)
	assert_eq(all.size(), 16, "4 axles cross 4 joints; sleepers are not impacts")
	assert_eq(split.size(), all.size())
	for index: int in all.size():
		assert_eq(all[index]["axle"], split[index]["axle"])
		assert_eq(all[index]["joint"], split[index]["joint"])
	assert_almost_eq(
		float(all[1]["fraction"]) - float(all[0]["fraction"]),
		.026,
		.000001,
		"wheelbase sets paired impacts"
	)


func test_reverse_and_stopped_transport() -> void:
	var mixer := RailJointMixer.new()
	mixer.axle_offsets = PackedFloat64Array([2.2, 4.8])
	assert_true(mixer.events(10, 10).is_empty())
	var forward: Array[Dictionary] = mixer.events(0, 100)
	var reverse: Array[Dictionary] = mixer.events(100, 0)
	assert_eq(forward.size(), reverse.size())


func test_impact_at_audio_block_boundary_is_not_dropped_or_duplicated() -> void:
	var mixer := RailJointMixer.new()
	mixer.sample_rate = 100
	mixer.spacing_m = 1
	mixer.distance_m = .9
	mixer.axle_offsets = PackedFloat64Array([0.0])
	mixer.samples.append(PackedFloat32Array([1.0]))
	var first: PackedVector2Array = mixer.render(10, 1.0)
	var second: PackedVector2Array = mixer.render(10, 1.0)
	assert_true(first[9].x > 0, "joint precisely on block boundary")
	assert_almost_eq(second[0].length(), 0.0, .000001)
