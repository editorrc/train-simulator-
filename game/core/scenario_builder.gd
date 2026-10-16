class_name ScenarioBuilder
extends RefCounted
## Builds a SimWorld from plain content dictionaries (no file access here: the content
## layer reads files, the core only sees data).

const PLAYER_TRAIN_ID: StringName = &"player"


## scenario: scenario JSON; track_graph: the route's track_graph JSON;
## consist: consist JSON; vehicles: vehicle id -> vehicle JSON.
static func build(
	scenario: Dictionary,
	track_graph: Dictionary,
	consist: Dictionary,
	vehicles: Dictionary,
	world_seed: int = 0
) -> SimWorld:
	var graph: TrackGraph = TrackGraph.from_dict(track_graph)
	var world := SimWorld.new(graph, world_seed)
	world.scenario_id = StringName(str(scenario["id"]))
	var switches: Dictionary = scenario.get("switches", {})
	for node_id: Variant in switches:
		graph.set_switch(
			StringName(str(node_id)),
			(
				TrackNode.SwitchState.DIVERGING
				if str(switches[node_id]) == "diverging"
				else TrackNode.SwitchState.STRAIGHT
			)
		)
	var start: Dictionary = scenario["start"]
	world.start_time_s = _parse_hhmm(str(start.get("time", "00:00")))
	var head := TrackPosition.new(
		StringName(str(start["segment"])), float(start["offset_m"]), int(start["direction"])
	)
	var spec: ConsistSpec = ConsistSpec.from_dict(consist, vehicles)
	var train := Train.new(PLAYER_TRAIN_ID, spec, head, float(scenario.get("passenger_load", 0.5)))
	match str(scenario.get("weather", "clear")):
		"rain":
			train.rail_condition = Adhesion.RailCondition.WET
		"snow":
			train.rail_condition = Adhesion.RailCondition.ICE
	world.add_train(train, true)
	return world


static func _parse_hhmm(s: String) -> float:
	var parts: PackedStringArray = s.split(":")
	if parts.size() != 2:
		return 0.0
	return int(parts[0]) * 3600.0 + int(parts[1]) * 60.0
