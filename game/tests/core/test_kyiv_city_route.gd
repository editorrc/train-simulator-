extends TestCase


func test_complete_ring_has_twenty_stations_and_closes() -> void:
	var lib := ContentLibrary.new()
	lib.load_all("res://content")
	var route: Dictionary = lib.get_entry(&"route", &"kyiv_city_ring")
	assert_eq((route["stations"]["stations"] as Array).size(), 20)
	var w: SimWorld = lib.build_world(&"kyiv_city_free_drive")
	var length: float = 0.0
	for seg: TrackSegment in w.graph.segments.values():
		length += seg.length_m
	assert_almost_eq(length, 49500.0, .01)
	var start: TrackPosition = w.player().head
	var end: TrackPosition = start.advance(w.graph, length).position
	assert_eq(end.segment_id, start.segment_id)
	assert_almost_eq(end.offset_m, start.offset_m, .01)
	assert_false(bool(route["route"]["meta"]["verified"]))
