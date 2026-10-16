class_name TrackGraph
extends RefCounted
## Track topology: segments joined by nodes (ends, joints, switches).
## Loaded from a route's track_graph.json (schema: schemas/track_graph.schema.json).

var segments: Dictionary[StringName, TrackSegment] = {}
var nodes: Dictionary[StringName, TrackNode] = {}

## Reverse index "segment:side" -> node id, rebuilt by _index().
var _end_to_node: Dictionary[String, StringName] = {}


func get_segment(id: StringName) -> TrackSegment:
	return segments.get(id) as TrackSegment


func get_node_by_id(id: StringName) -> TrackNode:
	return nodes.get(id) as TrackNode


## The node attached to a given segment end, or null if the end is dangling.
func node_at(end: TrackEnd) -> TrackNode:
	var key: String = str(end)
	if not _end_to_node.has(key):
		return null
	return nodes[_end_to_node[key]]


func set_switch(node_id: StringName, state: TrackNode.SwitchState) -> bool:
	var n: TrackNode = get_node_by_id(node_id)
	if n == null or n.kind != TrackNode.Kind.SWITCH:
		return false
	n.state = state
	return true


## Structural checks. Returns human-readable problems; empty means the graph is sound.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary[String, StringName] = {}
	for n: TrackNode in nodes.values():
		for e: TrackEnd in n.all_ends():
			if e == null:
				errors.append("node %s: missing connection" % n.id)
				continue
			var key: String = str(e)
			if seen.has(key):
				errors.append("end %s is connected to both %s and %s" % [key, seen[key], n.id])
			seen[key] = n.id
			var seg: TrackSegment = get_segment(e.segment_id)
			if seg == null:
				errors.append("node %s references unknown segment %s" % [n.id, e.segment_id])
				continue
			var declared: StringName = seg.node_a if e.side == TrackEnd.Side.A else seg.node_b
			if declared != n.id:
				errors.append(
					(
						"segment %s end %s declares node %s, but node %s claims it"
						% [seg.id, key, declared, n.id]
					)
				)
		if n.kind == TrackNode.Kind.END and n.ends.size() != 1:
			errors.append("end node %s must have exactly 1 connection" % n.id)
		if n.kind == TrackNode.Kind.JOINT and n.ends.size() != 2:
			errors.append("joint node %s must have exactly 2 connections" % n.id)
	for s: TrackSegment in segments.values():
		if s.length_m <= 0.0:
			errors.append("segment %s has non-positive length" % s.id)
		for side: TrackEnd.Side in [TrackEnd.Side.A, TrackEnd.Side.B]:
			var key: String = str(TrackEnd.new(s.id, side))
			if not seen.has(key):
				errors.append("segment end %s is not connected to any node" % key)
	return errors


static func from_dict(d: Dictionary) -> TrackGraph:
	var g := TrackGraph.new()
	for sd: Variant in d.get("segments", []):
		var s: TrackSegment = TrackSegment.from_dict(sd as Dictionary)
		g.segments[s.id] = s
	for nd: Variant in d.get("nodes", []):
		var n: TrackNode = TrackNode.from_dict(nd as Dictionary)
		g.nodes[n.id] = n
	g._index()
	return g


func _index() -> void:
	_end_to_node.clear()
	for n: TrackNode in nodes.values():
		for e: TrackEnd in n.all_ends():
			if e != null:
				_end_to_node[str(e)] = n.id


## Grade ratio at a position, signed for the position's heading (positive = uphill ahead).
func grade_ratio_at(pos: TrackPosition) -> float:
	var seg: TrackSegment = get_segment(pos.segment_id)
	if seg == null:
		return 0.0
	return seg.grade_ratio_at(pos.offset_m) * pos.direction


## Curve radius at a position in m (INF on straight track).
func curve_radius_at(pos: TrackPosition) -> float:
	var seg: TrackSegment = get_segment(pos.segment_id)
	return seg.curve_radius_at(pos.offset_m) if seg != null else INF


## Permanent speed limit at a position in m/s (INF if none).
func speed_limit_at(pos: TrackPosition) -> float:
	var seg: TrackSegment = get_segment(pos.segment_id)
	return seg.speed_limit_at(pos.offset_m) if seg != null else INF
