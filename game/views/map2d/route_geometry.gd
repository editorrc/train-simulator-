class_name RouteGeometry
extends RefCounted
## Maps track positions (segment + offset) to 2D drawing coordinates using geometry.json.
## Offsets are mapped proportionally along each polyline, so drawing stays consistent even
## if a polyline's drawn length differs slightly from the segment's track length.
## Coordinates: geometry is x east / y north in metres; Godot 2D is y down, so y is flipped.

## segment id -> PackedVector2Array (already flipped)
var polylines: Dictionary[StringName, PackedVector2Array] = {}
## segment id -> PackedFloat32Array of cumulative lengths
var _cumulative: Dictionary[StringName, PackedFloat32Array] = {}


static func from_dict(geometry: Dictionary) -> RouteGeometry:
	var g := RouteGeometry.new()
	for pl: Variant in geometry.get("polylines", []):
		var d: Dictionary = pl
		var pts := PackedVector2Array()
		for p: Variant in d["points"]:
			var a: Array = p
			pts.append(Vector2(float(a[0]), -float(a[1])))
		var id: StringName = StringName(str(d["segment"]))
		g.polylines[id] = pts
		var cum := PackedFloat32Array([0.0])
		for i: int in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
		g._cumulative[id] = cum
	return g


## Point at `offset_m` along a segment whose track length is `segment_length_m`.
func point_at(segment_id: StringName, offset_m: float, segment_length_m: float) -> Vector2:
	if not polylines.has(segment_id):
		return Vector2.ZERO
	var pts: PackedVector2Array = polylines[segment_id]
	var cum: PackedFloat32Array = _cumulative[segment_id]
	var drawn: float = cum[cum.size() - 1]
	var target: float = clampf(offset_m / segment_length_m, 0.0, 1.0) * drawn
	for i: int in range(1, pts.size()):
		if target <= cum[i]:
			var span: float = cum[i] - cum[i - 1]
			var t: float = 0.0 if span <= 0.0 else (target - cum[i - 1]) / span
			return pts[i - 1].lerp(pts[i], t)
	return pts[pts.size() - 1]


func bounds() -> Rect2:
	var r := Rect2()
	var first: bool = true
	for pts: PackedVector2Array in polylines.values():
		for p: Vector2 in pts:
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
	return r
