class_name RailPath
extends RefCounted
## Shared rail centreline and local frames for trucks, track and platforms.

var graph: TrackGraph
var geometry: RouteGeometry
var profile: RouteProfile


func _init(p_graph: TrackGraph, p_geometry: RouteGeometry) -> void:
	graph = p_graph
	geometry = p_geometry
	profile = RouteProfile.build(graph)


func point(pos: TrackPosition) -> Vector3:
	var segment: TrackSegment = graph.get_segment(pos.segment_id)
	var xy: Vector2 = geometry.point_at(pos.segment_id, pos.offset_m, segment.length_m)
	return Vector3(xy.x, profile.height_at(graph.chainage_at(pos)), xy.y)


func frame(pos: TrackPosition, span_m: float = 1.5) -> Transform3D:
	var before: Vector3 = point(pos.advance(graph, -span_m * .5).position)
	var after: Vector3 = point(pos.advance(graph, span_m * .5).position)
	var direction: Vector3 = after - before
	if direction.length_squared() < .000001:
		direction = Vector3.FORWARD
	return Transform3D(Basis.looking_at(direction.normalized(), Vector3.UP), point(pos))


func offset_point(pos: TrackPosition, across_m: float, height_m: float) -> Vector3:
	var local: Transform3D = frame(pos)
	return local.origin + local.basis.x * across_m + local.basis.y * height_m
