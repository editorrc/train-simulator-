class_name TrackEnd
extends RefCounted
## One end of a TrackSegment: end A is at offset 0, end B at offset length_m.

enum Side { A, B }

var segment_id: StringName
var side: TrackEnd.Side


func _init(p_segment_id: StringName, p_side: TrackEnd.Side) -> void:
	segment_id = p_segment_id
	side = p_side


func equals(other: TrackEnd) -> bool:
	return other != null and other.segment_id == segment_id and other.side == side


func _to_string() -> String:
	return "%s:%s" % [segment_id, "a" if side == TrackEnd.Side.A else "b"]


static func side_from_string(s: String) -> TrackEnd.Side:
	match s:
		"a":
			return TrackEnd.Side.A
		"b":
			return TrackEnd.Side.B
	push_error("TrackEnd: unknown side '%s', expected 'a' or 'b'" % s)
	return TrackEnd.Side.A


static func from_dict(d: Dictionary) -> TrackEnd:
	return TrackEnd.new(StringName(str(d["segment"])), side_from_string(str(d["end"])))
