class_name RouteProfile
extends RefCounted
## Side-view geometry along railway chainage: rail-head elevation, which segments are the
## main line and which are parallel (station) tracks drawn behind it.
## Elevation is integrated from segment grades (A→B), starting at 0 m at the lowest chainage.

const SAMPLE_M: float = 2.0

var ch_min: float = 0.0
var ch_max: float = 0.0
## Elevation every SAMPLE_M from ch_min.
var heights: PackedFloat32Array = []
## {segment: StringName, from: float, to: float, far: bool, electrified: bool}
var tracks: Array[Dictionary] = []


static func build(graph: TrackGraph) -> RouteProfile:
	var p := RouteProfile.new()
	var segs: Array[TrackSegment] = []
	for s: TrackSegment in graph.segments.values():
		if not is_nan(s.chainage_at_a_m):
			segs.append(s)
	segs.sort_custom(
		func(a: TrackSegment, b: TrackSegment) -> bool:
			return (
				a.chainage_at_a_m < b.chainage_at_a_m
				or (a.chainage_at_a_m == b.chainage_at_a_m and str(a.id) < str(b.id))
			)
	)
	if segs.is_empty():
		return p
	p.ch_min = segs[0].chainage_at_a_m
	var main: Array[TrackSegment] = []
	var main_end: float = -INF
	for s: TrackSegment in segs:
		var far: bool = s.chainage_at_a_m < main_end - 1.0
		if not far:
			main.append(s)
			main_end = s.chainage_at_a_m + s.length_m
		(
			p
			. tracks
			. append(
				{
					"segment": s.id,
					"from": s.chainage_at_a_m,
					"to": s.chainage_at_a_m + s.length_m,
					"far": far,
					"electrified": s.electrification != TrackSegment.Electrification.NONE,
				}
			)
		)
	p.ch_max = main_end
	var h: float = 0.0
	var ch: float = p.ch_min
	var mi: int = 0
	while ch <= p.ch_max + SAMPLE_M:
		while mi < main.size() - 1 and ch > main[mi].chainage_at_a_m + main[mi].length_m:
			mi += 1
		p.heights.append(h)
		var seg: TrackSegment = main[mi]
		h += seg.grade_ratio_at(ch - seg.chainage_at_a_m) * SAMPLE_M
		ch += SAMPLE_M
	return p


## Rail-head elevation at a chainage, m (clamped to the route ends).
func height_at(ch: float) -> float:
	if heights.is_empty():
		return 0.0
	var f: float = clampf((ch - ch_min) / SAMPLE_M, 0.0, heights.size() - 1.001)
	var i: int = int(f)
	return lerpf(heights[i], heights[i + 1], f - i)


func is_far(segment_id: StringName) -> bool:
	for t: Dictionary in tracks:
		if t["segment"] == segment_id:
			return bool(t["far"])
	return false


## True if a main-line track at this chainage has a catenary.
func electrified_at(ch: float) -> bool:
	for t: Dictionary in tracks:
		if not bool(t["far"]) and ch >= float(t["from"]) and ch <= float(t["to"]):
			return bool(t["electrified"])
	return false
