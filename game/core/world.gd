class_name SimWorld
extends RefCounted
## The whole simulation state. step() advances it by one fixed tick; apply_command() is the
## only way to change controls. No Node, no input, no rendering (docs/DECISIONS.md D-002).

## Reverser changes are refused above this speed, m/s.
const REVERSER_MAX_SPEED_MS: float = 0.1

var graph: TrackGraph
var trains: Dictionary[StringName, Train] = {}
var player_train_id: StringName = &""
var scenario_id: StringName = &""
var world_seed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tick: int = 0
## Scenario clock: seconds since local midnight at tick 0.
var start_time_s: float = 0.0
var dt: float = SimConfig.SIM_DT
## Every applied command with the tick it took effect on.
var command_log: Array[Dictionary] = []
## Events of the most recent step (and of commands applied since).
var events: Array[Dictionary] = []


func _init(p_graph: TrackGraph, p_seed: int = 0) -> void:
	graph = p_graph
	world_seed = p_seed
	rng.seed = p_seed


func add_train(train: Train, is_player: bool = false) -> void:
	trains[train.id] = train
	if is_player:
		player_train_id = train.id


func player() -> Train:
	return trains.get(player_train_id) as Train


func clock_s() -> float:
	return start_time_s + tick * dt


func step() -> Array[Dictionary]:
	events = []
	for t: Train in trains.values():
		t.step(graph, dt, events)
	tick += 1
	for e: Dictionary in events:
		e["tick"] = tick
	return events


## Applies a command now. Returns false (and emits &"command_rejected") if not allowed.
func apply_command(cmd: Dictionary) -> bool:
	var ok: bool = _execute(cmd)
	if ok:
		var logged: Dictionary = cmd.duplicate()
		logged["tick"] = tick
		command_log.append(logged)
	else:
		events.append({"type": &"command_rejected", "command": cmd, "tick": tick})
	return ok


func _execute(cmd: Dictionary) -> bool:
	var type: StringName = StringName(str(cmd.get("type", "")))
	if type == Commands.SWITCH_SET:
		return set_switch(StringName(str(cmd["node"])), bool(cmd["diverging"]))
	var t: Train = trains.get(StringName(str(cmd.get("train", "")))) as Train
	if t == null:
		return false
	var positions: int = t.consist.controller_positions.size()
	var valve_positions: int = t.consist.brake_valve_positions.size()
	var index: int = -1
	match type:
		Commands.CONTROLLER_STEP:
			index = _bounded(t.controller_index + int(cmd["delta"]), positions)
		Commands.CONTROLLER_SET:
			index = t.consist.controller_index_of(str(cmd["position"]))
		Commands.BRAKE_VALVE_STEP:
			index = _bounded(t.brake_valve_index + int(cmd["delta"]), valve_positions)
		Commands.BRAKE_VALVE_SET:
			index = t.consist.brake_valve_index_of(str(cmd["position"]))
		Commands.REVERSER_SET:
			var value: int = int(cmd["value"])
			if value >= -1 and value <= 1 and absf(t.speed_ms) <= REVERSER_MAX_SPEED_MS:
				t.reverser = value
				return true
			return false
	if index < 0:
		return false
	if type == Commands.CONTROLLER_STEP or type == Commands.CONTROLLER_SET:
		t.controller_index = index
	else:
		t.brake_valve_index = index
	return true


static func _bounded(index: int, size: int) -> int:
	return index if index >= 0 and index < size else -1


## Throws a switch unless a train stands on it (switches under a train are locked).
func set_switch(node_id: StringName, diverging: bool) -> bool:
	for t: Train in trains.values():
		if node_id in t.occupied_nodes(graph):
			return false
	var state: TrackNode.SwitchState = (
		TrackNode.SwitchState.DIVERGING if diverging else TrackNode.SwitchState.STRAIGHT
	)
	return graph.set_switch(node_id, state)


## Serializable dynamic state (static content is referenced by scenario id).
func to_dict() -> Dictionary:
	var switches: Dictionary = {}
	for n: TrackNode in graph.nodes.values():
		if n.kind == TrackNode.Kind.SWITCH:
			switches[n.id] = (
				"diverging" if n.state == TrackNode.SwitchState.DIVERGING else "straight"
			)
	var train_states: Dictionary = {}
	for t: Train in trains.values():
		train_states[t.id] = t.to_dict()
	return {
		"format": 1,
		"scenario": scenario_id,
		"seed": world_seed,
		"rng_state": rng.state,
		"tick": tick,
		"switches": switches,
		"trains": train_states,
	}


## Restores dynamic state onto a world built from the same scenario.
func restore(d: Dictionary) -> void:
	tick = int(d["tick"])
	rng.seed = int(d["seed"])
	rng.state = int(d["rng_state"])
	var switches: Dictionary = d["switches"]
	for node_id: Variant in switches:
		var state: TrackNode.SwitchState = (
			TrackNode.SwitchState.DIVERGING
			if str(switches[node_id]) == "diverging"
			else TrackNode.SwitchState.STRAIGHT
		)
		graph.set_switch(StringName(str(node_id)), state)
	var train_states: Dictionary = d["trains"]
	for tid: Variant in train_states:
		var t: Train = trains.get(StringName(str(tid))) as Train
		if t != null:
			t.restore(train_states[tid] as Dictionary)
