extends TestCase

const POLYGON: String = "res://content/base/routes/test_polygon/track_graph.json"

var graph: TrackGraph


func before_each() -> void:
	graph = TrackGraph.from_dict(load_json(POLYGON))


func test_move_within_segment() -> void:
	var start := TrackPosition.new(&"s1_a_to_b", 100.0, 1)
	var r: TrackAdvance = start.advance(graph, 250.0)
	assert_eq(r.position.segment_id, &"s1_a_to_b")
	assert_almost_eq(r.position.offset_m, 350.0, 1e-9)
	assert_almost_eq(r.moved_m, 250.0, 1e-9)
	assert_false(r.blocked)
	assert_almost_eq(start.offset_m, 100.0, 1e-9, "advance must not mutate the original")


func test_facing_switch_straight() -> void:
	var r: TrackAdvance = TrackPosition.new(&"s1_a_to_b", 4900.0, 1).advance(graph, 300.0)
	assert_eq(r.position.segment_id, &"s2_b_track1")
	assert_almost_eq(r.position.offset_m, 200.0, 1e-9)
	assert_eq(r.position.direction, 1)


func test_facing_switch_diverging() -> void:
	graph.set_switch(&"sw_b_west", TrackNode.SwitchState.DIVERGING)
	var r: TrackAdvance = TrackPosition.new(&"s1_a_to_b", 4900.0, 1).advance(graph, 300.0)
	assert_eq(r.position.segment_id, &"s3_b_track2")
	assert_almost_eq(r.position.offset_m, 200.0, 1e-9)


func test_through_station_loop_to_next_segment() -> void:
	graph.set_switch(&"sw_b_west", TrackNode.SwitchState.DIVERGING)
	graph.set_switch(&"sw_b_east", TrackNode.SwitchState.DIVERGING)
	# 100 m to switch + 820 m loop + 80 m into s4.
	var r: TrackAdvance = TrackPosition.new(&"s1_a_to_b", 4900.0, 1).advance(graph, 1000.0)
	assert_eq(r.position.segment_id, &"s4_b_to_c")
	assert_almost_eq(r.position.offset_m, 80.0, 1e-9)
	assert_true(r.events.is_empty(), "no events on a correctly set route")


func test_trailing_wrong_switch_reports_event() -> void:
	# East switch stays "straight", train comes off track 2 → trails through it (взріз).
	graph.set_switch(&"sw_b_west", TrackNode.SwitchState.DIVERGING)
	var r: TrackAdvance = TrackPosition.new(&"s1_a_to_b", 4900.0, 1).advance(graph, 1000.0)
	assert_eq(r.position.segment_id, &"s4_b_to_c")
	assert_true(r.has_event(&"switch_trailed"))
	assert_eq(r.events[0]["node"], &"sw_b_east")
	assert_almost_eq(float(r.events[0]["at_m"]), 920.0, 1e-9)


func test_backwards_keeps_heading() -> void:
	var r: TrackAdvance = TrackPosition.new(&"s2_b_track1", 50.0, 1).advance(graph, -150.0)
	assert_eq(r.position.segment_id, &"s1_a_to_b")
	assert_almost_eq(r.position.offset_m, 4900.0, 1e-9)
	assert_eq(r.position.direction, 1, "moving backwards does not turn the train around")


func test_entering_segment_from_end_b_flips_direction() -> void:
	# Travelling west from s4 into the station: enters s2 through its end B.
	var r: TrackAdvance = TrackPosition.new(&"s4_b_to_c", 100.0, -1).advance(graph, 300.0)
	assert_eq(r.position.segment_id, &"s2_b_track1")
	assert_eq(r.position.direction, -1)
	assert_almost_eq(r.position.offset_m, 600.0, 1e-9)


func test_end_of_track_blocks() -> void:
	var r: TrackAdvance = TrackPosition.new(&"s4_b_to_c", 4400.0, 1).advance(graph, 500.0)
	assert_true(r.blocked)
	assert_true(r.has_event(&"end_of_track"))
	assert_almost_eq(r.position.offset_m, 4500.0, 1e-9)
	assert_almost_eq(r.moved_m, 100.0, 1e-9)


func test_full_length_west_to_east() -> void:
	var r: TrackAdvance = TrackPosition.new(&"s1_a_to_b", 0.0, 1).advance(graph, 20000.0)
	assert_true(r.blocked)
	assert_almost_eq(r.moved_m, 5000.0 + 800.0 + 4500.0, 1e-6)
