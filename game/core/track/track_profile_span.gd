class_name TrackProfileSpan
extends RefCounted
## Piecewise-exact integration under a uniformly distributed vehicle, towards its rear.

var grade_ratio: float = 0.0
var inverse_radius_m: float = 0.0
var speed_limit_ms: float = INF


static func sample(graph: TrackGraph, front: TrackPosition, length_m: float) -> TrackProfileSpan:
	var result := TrackProfileSpan.new()
	var cursor: TrackPosition = front.reversed()
	var remaining: float = length_m
	for hop: int in TrackPosition.MAX_HOPS:
		var segment: TrackSegment = graph.get_segment(cursor.segment_id)
		if segment == null or remaining <= .000000001:
			break
		var available: float = (
			segment.length_m - cursor.offset_m if cursor.direction > 0 else cursor.offset_m
		)
		var extent: float = minf(remaining, available)
		var end: float = cursor.offset_m + cursor.direction * extent
		result._integrate(
			segment, minf(cursor.offset_m, end), maxf(cursor.offset_m, end), -cursor.direction
		)
		remaining -= extent
		if remaining <= .000000001:
			break
		var exit := TrackEnd.new(
			segment.id, TrackEnd.Side.B if cursor.direction > 0 else TrackEnd.Side.A
		)
		var node: TrackNode = graph.node_at(exit)
		var next: TrackEnd = node.pass_through(exit)["next"] if node != null else null
		if next == null:
			# Preserve clamped-position behaviour for a consist extending beyond a buffer.
			result.grade_ratio += segment.grade_ratio_at(end) * -cursor.direction * remaining
			var radius: float = segment.curve_radius_at(end)
			result.inverse_radius_m += remaining / radius if radius > 0 else 0.0
			result.speed_limit_ms = minf(result.speed_limit_ms, segment.speed_limit_at(end))
			break
		var previous: TrackSegment = graph.get_segment(next.segment_id)
		cursor = TrackPosition.new(
			next.segment_id,
			0 if next.side == TrackEnd.Side.A else previous.length_m,
			1 if next.side == TrackEnd.Side.A else -1
		)
	if length_m > 0:
		result.grade_ratio /= length_m
		result.inverse_radius_m /= length_m
	return result


func _integrate(segment: TrackSegment, low: float, high: float, heading: int) -> void:
	var cuts := PackedFloat64Array([low, high])
	for grade: Dictionary in segment.grade_points:
		var at: float = float(grade["at_m"])
		if at > low and at < high:
			cuts.append(at)
	for intervals: Array[Dictionary] in [segment.curves, segment.speed_limits]:
		for interval: Dictionary in intervals:
			for key: String in ["from_m", "to_m"]:
				var at: float = float(interval[key])
				if at > low and at < high:
					cuts.append(at)
	cuts.sort()
	for index: int in range(1, cuts.size()):
		var span: float = cuts[index] - cuts[index - 1]
		if span <= 0:
			continue
		var middle: float = (cuts[index] + cuts[index - 1]) * .5
		grade_ratio += segment.grade_ratio_at(middle) * heading * span
		var radius: float = segment.curve_radius_at(middle)
		inverse_radius_m += span / radius if radius > 0 else 0.0
		speed_limit_ms = minf(speed_limit_ms, segment.speed_limit_at(middle))
