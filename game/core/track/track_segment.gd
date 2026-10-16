class_name TrackSegment
extends RefCounted
## A piece of track between two nodes, measured from end A (offset 0) to end B.
## Holds only what the physics needs: length, profile, curvature, limits, power supply.
## Drawing geometry lives separately (geometry.json) and is never read by the core.

enum Electrification { NONE, AC_25KV, DC_3KV }

var id: StringName
var length_m: float
var node_a: StringName
var node_b: StringName
var electrification: Electrification = Electrification.NONE
## Piecewise-constant grade: sorted by at_m, each entry {at_m: float, ratio: float}.
## Grade ratio is signed in the A→B direction (positive = uphill going A→B).
var grade_points: Array[Dictionary] = []
## Curves: {from_m, to_m, radius_m}.
var curves: Array[Dictionary] = []
## Permanent speed limits: {from_m, to_m, speed_ms}.
var speed_limits: Array[Dictionary] = []


## Grade ratio (rise/run) at an offset, signed for travel A→B.
func grade_ratio_at(offset_m: float) -> float:
	var g: float = 0.0
	for p: Dictionary in grade_points:
		if float(p["at_m"]) <= offset_m:
			g = float(p["ratio"])
		else:
			break
	return g


## Curve radius at an offset in m, or INF on straight track.
func curve_radius_at(offset_m: float) -> float:
	for c: Dictionary in curves:
		if offset_m >= float(c["from_m"]) and offset_m <= float(c["to_m"]):
			return float(c["radius_m"])
	return INF


## Lowest permanent speed limit covering the offset in m/s, or INF if unrestricted.
func speed_limit_at(offset_m: float) -> float:
	var limit: float = INF
	for s: Dictionary in speed_limits:
		if offset_m >= float(s["from_m"]) and offset_m <= float(s["to_m"]):
			limit = minf(limit, float(s["speed_ms"]))
	return limit


static func electrification_from_string(s: String) -> Electrification:
	match s:
		"ac_25kv":
			return Electrification.AC_25KV
		"dc_3kv":
			return Electrification.DC_3KV
	return Electrification.NONE


## Builds a segment from JSON (railway units with unit-suffixed keys) converting to SI.
static func from_dict(d: Dictionary) -> TrackSegment:
	var s := TrackSegment.new()
	s.id = StringName(str(d["id"]))
	s.length_m = float(d["length_m"])
	s.node_a = StringName(str(d["node_a"]))
	s.node_b = StringName(str(d["node_b"]))
	s.electrification = electrification_from_string(str(d.get("electrification", "none")))
	for p: Variant in d.get("grades", []):
		var pd: Dictionary = p
		s.grade_points.append(
			{"at_m": float(pd["at_m"]), "ratio": Units.permille_to_ratio(float(pd["permille"]))}
		)
	s.grade_points.sort_custom(
		func(x: Dictionary, y: Dictionary) -> bool: return float(x["at_m"]) < float(y["at_m"])
	)
	for c: Variant in d.get("curves", []):
		var cd: Dictionary = c
		s.curves.append(
			{
				"from_m": float(cd["from_m"]),
				"to_m": float(cd["to_m"]),
				"radius_m": float(cd["radius_m"])
			}
		)
	for l: Variant in d.get("speed_limits", []):
		var ld: Dictionary = l
		(
			s
			. speed_limits
			. append(
				{
					"from_m": float(ld["from_m"]),
					"to_m": float(ld["to_m"]),
					"speed_ms": Units.kmh_to_ms(float(ld["speed_kmh"])),
				}
			)
		)
	return s
