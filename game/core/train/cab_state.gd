class_name CabState
extends RefCounted
## Positions of the cab's switches and buttons. Control ids are the contract between the
## cab data (rolling_stock/<series>/cab.json) and the systems that read them.

const TOGGLES: Array[StringName] = [
	&"battery",
	&"control_circuits",
	&"pantograph",
	&"aux_machines",
	&"compressors",
	&"ep_brake",
	&"headlights",
	&"doors_left",
	&"doors_right",
]
## Held while pressed (sent as value true/false).
const HOLDS: Array[StringName] = [&"aux_compressor", &"horn", &"whistle"]
## Momentary actions, executed by the train when pressed.
const BUTTONS: Array[StringName] = [&"main_breaker_on", &"main_breaker_off", &"protection_reset"]

var values: Dictionary[StringName, bool] = {}


func _init() -> void:
	for id: StringName in TOGGLES + HOLDS:
		values[id] = false


func is_on(id: StringName) -> bool:
	return values.get(id, false)


static func is_known(id: StringName) -> bool:
	return id in TOGGLES or id in HOLDS or id in BUTTONS


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in values:
		out[str(id)] = values[id]
	return out


func restore(d: Dictionary) -> void:
	for key: Variant in d:
		values[StringName(str(key))] = bool(d[key])
