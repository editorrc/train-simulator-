extends TestCase


func test_camera_follow_is_independent_of_render_rate() -> void:
	var expected: float = 80.0 - 40.0 * .18 * (1.0 - exp(-2.0 / .18))
	for fps: int in [20, 60, 144]:
		var position: float = 0.0
		for frame: int in 2 * fps:
			var before: float = frame * 40.0 / fps
			var after: float = (frame + 1) * 40.0 / fps
			position = RenderPose.follow(position, before, after, 1.0 / fps, .18)
		assert_almost_eq(position, expected, 1e-7, "camera lag at %d fps" % fps)


func test_visual_head_crosses_segment_boundaries() -> void:
	var lib := ContentLibrary.new()
	lib.load_all("res://content")
	var w: SimWorld = lib.build_world(&"kyiv_city_free_drive")
	var t: Train = w.player()
	var seg: TrackSegment = w.graph.get_segment(t.head.segment_id)
	t.head = TrackPosition.new(seg.id, seg.length_m - .2, 1)
	t.speed_ms = 40.0
	var pose := RenderPose.new()
	pose.reset(t)
	w.step()
	pose.capture(t)
	var first: TrackPosition = pose.head(w.graph, 0)
	var last: TrackPosition = pose.head(w.graph, 1)
	assert_eq(first.segment_id, seg.id)
	assert_eq(last.segment_id, t.head.segment_id)
	assert_almost_eq(last.offset_m, t.head.offset_m, 1e-6)
