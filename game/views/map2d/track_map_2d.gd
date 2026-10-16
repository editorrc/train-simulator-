class_name TrackMap2D
extends Node2D
## Top-down schematic of the route with the trains on it. Pure view: reads SimWorld,
## never changes it (switch clicks are reported through the `switch_clicked` signal).

signal switch_clicked(node_id: StringName)

const TRACK_COLOR := Color(0.62, 0.66, 0.72)
const TRACK_WIDTH: float = 3.0
const PLATFORM_COLOR := Color(0.95, 0.75, 0.25)
const TRAIN_COLOR := Color(0.2, 0.75, 0.45)
const TRAIN_HEAD_COLOR := Color(0.95, 0.95, 0.95)
const SWITCH_STRAIGHT := Color(0.3, 0.8, 1.0)
const SWITCH_DIVERGING := Color(1.0, 0.45, 0.3)
const SWITCH_PICK_RADIUS_PX: float = 18.0
## Spacing of sample points along a train body, m.
const TRAIN_SAMPLE_M: float = 5.0

var world: SimWorld
var geometry: RouteGeometry
var stations: Dictionary = {}


func setup(p_world: SimWorld, p_geometry: RouteGeometry, p_stations: Dictionary) -> void:
	world = p_world
	geometry = p_geometry
	stations = p_stations
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func track_point(pos: TrackPosition) -> Vector2:
	var seg: TrackSegment = world.graph.get_segment(pos.segment_id)
	return (
		geometry.point_at(pos.segment_id, pos.offset_m, seg.length_m)
		if seg != null
		else Vector2.ZERO
	)


func _draw() -> void:
	if world == null:
		return
	var px: float = 1.0 / maxf(get_viewport_transform().get_scale().x * global_scale.x, 1e-6)
	for pts: PackedVector2Array in geometry.polylines.values():
		draw_polyline(pts, TRACK_COLOR, TRACK_WIDTH * px, true)
	_draw_platforms(px)
	_draw_switches(px)
	for t: Train in world.trains.values():
		_draw_train(t, px)


func _draw_platforms(px: float) -> void:
	var font: Font = ThemeDB.fallback_font
	for st: Variant in stations.get("stations", []):
		var sd: Dictionary = st
		var label_at := Vector2.ZERO
		for p: Variant in sd["platforms"]:
			var pd: Dictionary = p
			var seg_id: StringName = StringName(str(pd["segment"]))
			var seg: TrackSegment = world.graph.get_segment(seg_id)
			var pts := PackedVector2Array()
			var x: float = float(pd["from_m"])
			while x <= float(pd["to_m"]):
				pts.append(geometry.point_at(seg_id, x, seg.length_m))
				x += 10.0
			draw_polyline(pts, PLATFORM_COLOR, 9.0 * px, true)
			label_at = pts[0]
		# Font size is in world units: 15 screen pixels at the current zoom.
		draw_string(
			font,
			label_at + Vector2(0, -16 * px),
			str(sd["name_uk"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			maxi(1, int(15 * px)),
			Color.WHITE
		)


func _draw_switches(px: float) -> void:
	for n: TrackNode in world.graph.nodes.values():
		if n.kind != TrackNode.Kind.SWITCH:
			continue
		var p: Vector2 = _node_point(n)
		var diverging: bool = n.state == TrackNode.SwitchState.DIVERGING
		draw_circle(p, 7.0 * px, SWITCH_DIVERGING if diverging else SWITCH_STRAIGHT)


func _node_point(n: TrackNode) -> Vector2:
	var e: TrackEnd = n.trunk if n.kind == TrackNode.Kind.SWITCH else n.ends[0]
	var seg: TrackSegment = world.graph.get_segment(e.segment_id)
	var off: float = 0.0 if e.side == TrackEnd.Side.A else seg.length_m
	return geometry.point_at(e.segment_id, off, seg.length_m)


func _draw_train(t: Train, px: float) -> void:
	var pts := PackedVector2Array()
	var d: float = 0.0
	var length: float = t.length_m()
	while d < length:
		pts.append(track_point(t.head.advance(world.graph, -d).position))
		d += TRAIN_SAMPLE_M
	pts.append(track_point(t.rear(world.graph)))
	draw_polyline(pts, TRAIN_COLOR, 10.0 * px, true)
	draw_circle(pts[0], 6.0 * px, TRAIN_HEAD_COLOR)


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or world == null:
		return
	var local: Vector2 = get_global_mouse_position()
	var px: float = 1.0 / maxf(get_viewport_transform().get_scale().x, 1e-6)
	for n: TrackNode in world.graph.nodes.values():
		if (
			n.kind == TrackNode.Kind.SWITCH
			and local.distance_to(_node_point(n)) < SWITCH_PICK_RADIUS_PX * px
		):
			switch_clicked.emit(n.id)
			get_viewport().set_input_as_handled()
			return
