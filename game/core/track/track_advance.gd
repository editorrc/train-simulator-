class_name TrackAdvance
extends RefCounted
## Result of TrackPosition.advance().

var position: TrackPosition
## Distance actually covered, m (less than requested if blocked).
var moved_m: float = 0.0
## True if movement stopped at an end of track.
var blocked: bool = false
## {type: StringName, node: StringName, at_m: float}
var events: Array[Dictionary] = []
## Every node crossed, in order (for occupancy, switch locking, signalling).
var nodes_passed: Array[StringName] = []


func has_event(type: StringName) -> bool:
	for e: Dictionary in events:
		if e["type"] == type:
			return true
	return false
