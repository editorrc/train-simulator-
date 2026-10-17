class_name StationCues
extends RefCounted
## Debounces route transitions so announcements never restart on every render frame.

var _at: String = ""
var _near: String = ""


func update(at_id: String, next_id: String, distance_m: float) -> Array[String]:
	var cues: Array[String] = []
	if at_id != "" and at_id != _at:
		cues.append(at_id + "_station")
	elif at_id == "" and _at != "" and next_id != "":
		cues.append(next_id + "_next")
		_near = next_id
	elif at_id == "" and next_id != "" and distance_m < 450 and _near != next_id:
		cues.append(next_id + "_next")
		_near = next_id
	_at = at_id
	return cues
