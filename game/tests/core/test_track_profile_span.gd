extends TestCase


func test_grade_and_curve_are_weighted_by_covered_length() -> void:
	var data: Dictionary = Fixtures.straight_track(1000)
	data["segments"][0]["grades"] = [{"at_m": 0, "permille": 0}, {"at_m": 500, "permille": 10}]
	data["segments"][0]["curves"] = [{"from_m": 500, "to_m": 700, "radius_m": 500}]
	data["segments"][0]["speed_limits"] = [{"from_m": 500, "to_m": 700, "speed_kmh": 60}]
	var graph: TrackGraph = TrackGraph.from_dict(data)
	var half: TrackProfileSpan = TrackProfileSpan.sample(
		graph, TrackPosition.new(&"line", 510, 1), 20
	)
	assert_almost_eq(half.grade_ratio, .005, 1e-12)
	assert_almost_eq(half.inverse_radius_m, .001, 1e-12)
	assert_almost_eq(half.speed_limit_ms, Units.kmh_to_ms(60), 1e-12)
	var shifted: TrackProfileSpan = TrackProfileSpan.sample(
		graph, TrackPosition.new(&"line", 511, 1), 20
	)
	assert_almost_eq(shifted.grade_ratio - half.grade_ratio, .0005, 1e-12, "gradual force entry")
	var reverse: TrackProfileSpan = TrackProfileSpan.sample(
		graph, TrackPosition.new(&"line", 490, -1), 20
	)
	assert_almost_eq(reverse.grade_ratio, -.005, 1e-12)
	assert_almost_eq(reverse.inverse_radius_m, .001, 1e-12)


func test_span_crosses_nodes_and_respects_segment_orientation() -> void:
	var graph: TrackGraph = TrackGraph.from_dict(
		load_json("res://content/base/routes/test_polygon/track_graph.json")
	)
	var first: TrackSegment = graph.get_segment(&"s1_a_to_b")
	var second: TrackSegment = graph.get_segment(&"s2_b_track1")
	first.grade_points = [{"at_m": 0.0, "ratio": .01}]
	second.grade_points = [{"at_m": 0.0, "ratio": -.01}]
	var forward: TrackProfileSpan = TrackProfileSpan.sample(
		graph, TrackPosition.new(second.id, 5, 1), 20
	)
	assert_almost_eq(forward.grade_ratio, .005, 1e-12, "15 m uphill + 5 m downhill")
	var reverse: TrackProfileSpan = TrackProfileSpan.sample(
		graph, TrackPosition.new(first.id, first.length_m - 15, -1), 20
	)
	assert_almost_eq(reverse.grade_ratio, -.005, 1e-12)


func test_world_force_matches_distributed_vehicle_masses() -> void:
	var world: SimWorld = Fixtures.world_on_straight()
	var segment: TrackSegment = world.graph.get_segment(&"line")
	var first: VehicleSpec = world.player().consist.vehicles[0]
	segment.grade_points = [
		{"at_m": 0.0, "ratio": 0.0}, {"at_m": 500.0 - first.length_m * .5, "ratio": .01}
	]
	world.step()
	var mass: float = (
		first.mass_empty_kg
		+ first.seats * world.player().load_factor * world.player().consist.passenger_mass_kg
	)
	assert_almost_eq(world.player().last_grade_n, Resistance.grade_n(mass, .005), .000001)


func test_joined_b_ends_keep_physical_grade_sign() -> void:
	var data: Dictionary = Fixtures.straight_track(100, 10)
	data["segments"][0]["node_b"] = "join"
	data["segments"].append(
		{
			"id": "other",
			"length_m": 100,
			"node_a": "east",
			"node_b": "join",
			"grades": [{"at_m": 0, "permille": -10}]
		}
	)
	data["nodes"][1] = {
		"id": "join",
		"kind": "joint",
		"ends": [{"segment": "line", "end": "b"}, {"segment": "other", "end": "b"}]
	}
	data["nodes"].append({"id": "east", "kind": "end", "ends": [{"segment": "other", "end": "a"}]})
	var graph: TrackGraph = TrackGraph.from_dict(data)
	var forward: TrackProfileSpan = TrackProfileSpan.sample(
		graph, TrackPosition.new(&"other", 95, -1), 20
	)
	assert_almost_eq(forward.grade_ratio, .01, 1e-12)
	var reverse: TrackProfileSpan = TrackProfileSpan.sample(
		graph, TrackPosition.new(&"line", 85, -1), 20
	)
	assert_almost_eq(reverse.grade_ratio, -.01, 1e-12)
