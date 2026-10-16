class_name ElectricalSystem
extends RefCounted
## High-voltage and control circuits of an AC multiple unit (docs/SIMULATION.md §3):
## АКБ → кола керування → струмоприймач (needs air) → напруга КМ → ГВ → допоміжні машини
## → компресори. Interlocks and trips raise events; rules (ПТЕ) judge them elsewhere.

var pantograph_raise_s: float
var pantograph_lower_s: float
var aux_start_s: float
var nominal_line_v: float

## 0 = down, 1 = touching the wire.
var pantograph_position: float = 0.0
var main_breaker_on: bool = false
## Overload/protection relay (РП) latched after a trip under load; reset by a button.
var protection_tripped: bool = false
var aux_progress: float = 0.0
## Line voltage seen by the pantograph, V.
var line_voltage: float = 0.0


static func from_dict(d: Dictionary) -> ElectricalSystem:
	var e := ElectricalSystem.new()
	e.pantograph_raise_s = float(d["pantograph_raise_s"])
	e.pantograph_lower_s = float(d["pantograph_lower_s"])
	e.aux_start_s = float(d["aux_start_s"])
	e.nominal_line_v = float(d["catenary_kv"]) * 1000.0
	return e


func control_on(cab: CabState) -> bool:
	return cab.is_on(&"battery") and cab.is_on(&"control_circuits")


func pantograph_up() -> bool:
	return pantograph_position >= 1.0


func aux_running() -> bool:
	return main_breaker_on and aux_progress >= 1.0


func compressors_enabled(cab: CabState) -> bool:
	return aux_running() and cab.is_on(&"compressors")


func traction_ready() -> bool:
	return main_breaker_on and aux_running() and not protection_tripped


## Momentary buttons. Returns "" on success or a reason (Ukrainian, shown to the player).
func press(button: StringName, cab: CabState, controller_index: int) -> String:
	match button:
		&"main_breaker_on":
			if not control_on(cab):
				return "немає живлення кіл керування"
			if protection_tripped:
				return "спрацювало реле захисту — спершу «Поверн. РП»"
			if line_voltage <= 0.0:
				return "немає напруги в контактній мережі (струмоприймач опущено?)"
			if controller_index != 0:
				return "контролер має бути в положенні 0"
			main_breaker_on = true
		&"main_breaker_off":
			main_breaker_on = false
		&"protection_reset":
			if not control_on(cab):
				return "немає живлення кіл керування"
			protection_tripped = false
	return ""


## `wire_live`: the track under the pantograph has a live catenary of our system.
## `traction_current`: true when the motors are drawing power (for trips under load).
func step(
	dt: float,
	cab: CabState,
	pantograph_air_ok: bool,
	wire_live: bool,
	traction_current: bool,
	events: Array[Dictionary]
) -> void:
	var want_up: bool = control_on(cab) and cab.is_on(&"pantograph") and pantograph_air_ok
	var was_up: bool = pantograph_up()
	if want_up:
		pantograph_position = minf(1.0, pantograph_position + dt / pantograph_raise_s)
	else:
		pantograph_position = maxf(0.0, pantograph_position - dt / pantograph_lower_s)
	if was_up and not pantograph_up() and main_breaker_on and traction_current:
		events.append({"type": &"pantograph_lowered_under_load"})
		protection_tripped = true
	line_voltage = nominal_line_v if pantograph_up() and wire_live else 0.0
	if main_breaker_on and (line_voltage <= 0.0 or not control_on(cab)):
		main_breaker_on = false
		events.append({"type": &"main_breaker_tripped"})
	if main_breaker_on and cab.is_on(&"aux_machines"):
		aux_progress = minf(1.0, aux_progress + dt / aux_start_s)
	else:
		aux_progress = 0.0


## Everything on: as after a completed startup procedure.
func start_ready() -> void:
	pantograph_position = 1.0
	main_breaker_on = true
	aux_progress = 1.0
	line_voltage = nominal_line_v


func to_dict() -> Dictionary:
	return {
		"pantograph_position": pantograph_position,
		"main_breaker_on": main_breaker_on,
		"protection_tripped": protection_tripped,
		"aux_progress": aux_progress,
		"line_voltage": line_voltage,
	}


func restore(d: Dictionary) -> void:
	pantograph_position = float(d["pantograph_position"])
	main_breaker_on = bool(d["main_breaker_on"])
	protection_tripped = bool(d["protection_tripped"])
	aux_progress = float(d["aux_progress"])
	line_voltage = float(d["line_voltage"])
