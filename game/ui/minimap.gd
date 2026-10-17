class_name Minimap
extends Control
## Top-down schematic of the route (switches clickable), drawn to fit the panel.

signal switch_clicked(node_id: StringName)

var world: SimWorld
var geometry: RouteGeometry
var stations: Dictionary = {}
var _tf_scale := Vector2.ONE
var _tf_off := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _process(_delta: float) -> void:
	queue_redraw()


func _tp(p: Vector2) -> Vector2:
	return p * _tf_scale + _tf_off


func _fit() -> void:
	var b: Rect2 = geometry.bounds()
	var pad: float = 55.0 if stations.get("stations", []).size() > 3 else 14.0
	var sx: float = (size.x - pad * 2) / maxf(b.size.x, 1.0)
	# Exaggerate the lateral scale so parallel tracks separate, within the panel height.
	var sy: float = minf(sx * 12.0, (size.y - pad * 2 - 14) / maxf(b.size.y, 1.0))
	_tf_scale = Vector2(sx, sy)
	_tf_off = Vector2(pad - b.position.x * sx, pad + 14 - b.position.y * sy)


func _point(pos: TrackPosition) -> Vector2:
	var seg: TrackSegment = world.graph.get_segment(pos.segment_id)
	return _tp(geometry.point_at(pos.segment_id, pos.offset_m, seg.length_m))


func _draw() -> void:
	if world == null or size.x < 40:
		return
	_fit()
	var font: Font = ThemeDB.fallback_font
	for feature: Variant in geometry.map_features:
		var river := PackedVector2Array()
		for raw: Variant in feature["points"]:
			var p := Vector2(float(raw[0]), -float(raw[1]))
			river.append(_tp(p))
		draw_polyline(river, Color(.20, .40, .56, .5), maxf(8.0, size.x * .013), true)
	for pts: PackedVector2Array in geometry.polylines.values():
		var sp := PackedVector2Array()
		for i: int in range(0, pts.size(), maxi(1, pts.size() / 100)):
			sp.append(_tp(pts[i]))
		sp.append(_tp(pts[pts.size() - 1]))
		draw_polyline(sp, Color("8e9a95"), 2.0, true)
	for st: Variant in stations.get("stations", []):
		var sd: Dictionary = st
		for p: Variant in sd["platforms"]:
			var pd: Dictionary = p
			var seg_id := StringName(str(pd["segment"]))
			var seg: TrackSegment = world.graph.get_segment(seg_id)
			var a: Vector2 = _tp(geometry.point_at(seg_id, float(pd["from_m"]), seg.length_m))
			var b: Vector2 = _tp(geometry.point_at(seg_id, float(pd["to_m"]), seg.length_m))
			draw_line(a, b, Color("e0a83a"), 5.0)
		var first: Dictionary = (sd["platforms"] as Array)[0]
		var s0: TrackSegment = world.graph.get_segment(StringName(str(first["segment"])))
		var lp: Vector2 = _tp(geometry.point_at(s0.id, float(first["from_m"]), s0.length_m))
		draw_string(
			font,
			(
				lp
				+ Vector2(
					(
						-(
							font
							. get_string_size(
								str(sd["name_uk"]),
								HORIZONTAL_ALIGNMENT_LEFT,
								-1,
								18 if size.y > 600 else 12
							)
							. x
						)
						if lp.x > size.x * .7
						else 0
					),
					-8
				)
			),
			str(sd["name_uk"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18 if size.y > 600 else 12,
			Color("dfe8e3")
		)
	for n: TrackNode in world.graph.nodes.values():
		if n.kind == TrackNode.Kind.SWITCH:
			var div: bool = n.state == TrackNode.SwitchState.DIVERGING
			draw_circle(_node_point(n), 6, Color("e7a23c") if div else Color("4cc488"))
	var t: Train = world.player()
	var body := PackedVector2Array()
	var d: float = 0.0
	while d <= t.length_m():
		body.append(_point(t.head.advance(world.graph, -d).position))
		d += 10.0
	draw_polyline(body, Color("57e38a"), 6.0, true)
	draw_circle(body[0], 4, Color.WHITE)


func _node_point(n: TrackNode) -> Vector2:
	var seg: TrackSegment = world.graph.get_segment(n.trunk.segment_id)
	var off: float = 0.0 if n.trunk.side == TrackEnd.Side.A else seg.length_m
	return _tp(geometry.point_at(n.trunk.segment_id, off, seg.length_m))


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for n: TrackNode in world.graph.nodes.values():
		if n.kind == TrackNode.Kind.SWITCH and mb.position.distance_to(_node_point(n)) < 14:
			switch_clicked.emit(n.id)
			accept_event()
			return
