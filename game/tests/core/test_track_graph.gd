extends TestCase

const POLYGON: String = "res://content/base/routes/test_polygon/track_graph.json"

var graph: TrackGraph


func before_each() -> void:
	graph = TrackGraph.from_dict(load_json(POLYGON))


func test_polygon_loads_and_is_valid() -> void:
	assert_eq(graph.segments.size(), 4)
	assert_eq(graph.nodes.size(), 4)
	var errors: PackedStringArray = graph.validate()
	assert_true(errors.is_empty(), "validate(): %s" % ", ".join(errors))


func test_node_lookup_by_end() -> void:
	var n: TrackNode = graph.node_at(TrackEnd.new(&"s1_a_to_b", TrackEnd.Side.B))
	assert_not_null(n)
	assert_eq(n.id, &"sw_b_west")
	assert_eq(n.kind, TrackNode.Kind.SWITCH)


func test_profile_converted_to_si() -> void:
	var s1: TrackSegment = graph.get_segment(&"s1_a_to_b")
	assert_almost_eq(s1.grade_ratio_at(0.0), 0.0, 1e-12)
	assert_almost_eq(s1.grade_ratio_at(1500.0), 0.006, 1e-12)
	assert_almost_eq(s1.grade_ratio_at(3000.0), -0.004, 1e-12)
	assert_almost_eq(s1.curve_radius_at(3300.0), 800.0, 1e-9)
	assert_eq(s1.curve_radius_at(100.0), INF)
	assert_almost_eq(s1.speed_limit_at(100.0), Units.kmh_to_ms(60.0), 1e-9)
	assert_almost_eq(s1.speed_limit_at(1000.0), Units.kmh_to_ms(120.0), 1e-9)
	assert_eq(s1.electrification, TrackSegment.Electrification.AC_25KV)


func test_set_switch() -> void:
	assert_true(graph.set_switch(&"sw_b_west", TrackNode.SwitchState.DIVERGING))
	assert_eq(graph.get_node_by_id(&"sw_b_west").state, TrackNode.SwitchState.DIVERGING)
	assert_false(graph.set_switch(&"end_west", TrackNode.SwitchState.DIVERGING), "not a switch")


func test_validate_reports_broken_graph() -> void:
	var data: Dictionary = {
		"segments":
		[
			{"id": "x", "length_m": 100, "node_a": "n1", "node_b": "n2"},
			{"id": "y", "length_m": 0, "node_a": "n2", "node_b": "n3"},
		],
		"nodes":
		[
			{"id": "n1", "kind": "end", "ends": [{"segment": "x", "end": "a"}]},
			{"id": "n2", "kind": "joint", "ends": [{"segment": "x", "end": "b"}]},
		],
	}
	var errors: PackedStringArray = TrackGraph.from_dict(data).validate()
	var text: String = "\n".join(errors)
	assert_true(text.contains("joint node n2 must have exactly 2"), text)
	assert_true(text.contains("segment y has non-positive length"), text)
	assert_true(text.contains("y:a is not connected"), text)
