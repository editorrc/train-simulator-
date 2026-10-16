class_name TrackPosition
extends RefCounted
## A point on the track with a heading: segment + offset from end A + direction.
## direction = +1 means facing towards end B (offset grows when moving forward),
## direction = -1 means facing towards end A.
## Treated as a value: advance() returns a new position and never mutates this one.

## Hard cap on node crossings in one advance() call, against malformed graphs.
const MAX_HOPS: int = 10000

var segment_id: StringName
var offset_m: float
var direction: int


func _init(p_segment_id: StringName = &"", p_offset_m: float = 0.0, p_direction: int = 1) -> void:
	segment_id = p_segment_id
	offset_m = p_offset_m
	direction = 1 if p_direction >= 0 else -1


func copy() -> TrackPosition:
	return TrackPosition.new(segment_id, offset_m, direction)


func reversed() -> TrackPosition:
	return TrackPosition.new(segment_id, offset_m, -direction)


## Moves `distance_m` along the track following switch states. Negative distance moves
## backwards (heading is kept). Stops at an end of track.
## Returns a TrackAdvance with the new position, distance actually moved and events
## (each event: {type: StringName, node: StringName, at_m: float from the start}).
func advance(graph: TrackGraph, distance_m: float) -> TrackAdvance:
	var result := TrackAdvance.new()
	var pos: TrackPosition = copy() if distance_m >= 0.0 else reversed()
	var remaining: float = absf(distance_m)
	var hops: int = 0
	while true:
		var seg: TrackSegment = graph.get_segment(pos.segment_id)
		if seg == null:
			push_error("TrackPosition: unknown segment %s" % pos.segment_id)
			result.blocked = true
			break
		var to_exit: float = seg.length_m - pos.offset_m if pos.direction > 0 else pos.offset_m
		if remaining <= to_exit:
			pos.offset_m += pos.direction * remaining
			result.moved_m += remaining
			break
		result.moved_m += to_exit
		remaining -= to_exit
		var exit_end := TrackEnd.new(
			seg.id, TrackEnd.Side.B if pos.direction > 0 else TrackEnd.Side.A
		)
		var node: TrackNode = graph.node_at(exit_end)
		var passed: Dictionary = (
			node.pass_through(exit_end)
			if node != null
			else {"next": null, "event": &"end_of_track"}
		)
		var event: StringName = passed["event"]
		if event != &"":
			result.events.append(
				{"type": event, "node": node.id if node != null else &"", "at_m": result.moved_m}
			)
		var next: TrackEnd = passed["next"]
		if next == null:
			pos.offset_m = seg.length_m if pos.direction > 0 else 0.0
			result.blocked = true
			break
		var next_seg: TrackSegment = graph.get_segment(next.segment_id)
		pos.segment_id = next.segment_id
		if next.side == TrackEnd.Side.A:
			pos.direction = 1
			pos.offset_m = 0.0
		else:
			pos.direction = -1
			pos.offset_m = next_seg.length_m
		hops += 1
		if hops > MAX_HOPS:
			push_error("TrackPosition: too many node crossings, graph loop with zero length?")
			result.blocked = true
			break
	result.position = pos if distance_m >= 0.0 else pos.reversed()
	return result


func _to_string() -> String:
	return "%s@%.2f(%s)" % [segment_id, offset_m, "+" if direction > 0 else "-"]
