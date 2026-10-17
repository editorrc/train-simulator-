class_name Train
extends RefCounted
## One train: static consist + cab + systems (electrical, pneumatic) + longitudinal dynamics.
## See docs/SIMULATION.md §1–§4.

## Traction falls to this share of the adhesion limit while the wheels slip.
const SLIP_TRACTION_SHARE: float = 0.6
## Traction is blocked while the brake cylinders hold more than this, Pa (≈ 0.3 kgf/cm²).
const TRACTION_CUTOFF_TC_PA: float = 0.3 * Units.PA_PER_KGF_CM2
## Brakes count as released below this cylinder pressure, Pa (≈ 0.1 kgf/cm²).
const BRAKES_RELEASED_PA: float = 0.1 * Units.PA_PER_KGF_CM2
## The brake pipe counts as charged within this margin of the charge pressure, Pa.
const PIPE_CHARGED_MARGIN_PA: float = 0.2 * Units.PA_PER_KGF_CM2
## Overspeed is reported this far above the limit, m/s (2 km/h).
const OVERSPEED_MARGIN_MS: float = 2.0 / 3.6
## Hitting the end of track faster than this is a collision, m/s (≈ 3 km/h).
const BUFFER_COLLISION_MS: float = 0.83

var id: StringName
var consist: ConsistSpec
## Front of the leading vehicle; heading = the direction the active cab faces.
var head: TrackPosition
## Signed speed along the heading, m/s (negative = rolling backwards).
var speed_ms: float = 0.0
var accel_ms2: float = 0.0
var load_factor: float = 0.5
var rail_condition: Adhesion.RailCondition = Adhesion.RailCondition.DRY

## Controls
var reverser: int = 0
var controller_index: int = 0
var brake_valve_index: int = 0

var cab: CabState = CabState.new()
var power: ElectricalSystem
var air: PneumaticSystem

## Derived each step
var traction_fraction: float = 0.0
## Brake effort 0..1 from the cylinder pressure (for HUD and the web preview).
var brake_demand: float = 0.0
var overspeed: bool = false
var slipping: bool = false
var odometer_m: float = 0.0

## Last-step forces for HUD/telemetry, N (signed along the heading where it matters)
var last_traction_n: float = 0.0
var last_brake_n: float = 0.0
var last_resistance_n: float = 0.0
var last_grade_n: float = 0.0
var last_speed_limit_ms: float = INF

var _vehicle_masses: PackedFloat64Array = []
var _total_mass: float = 0.0
var _effective_mass: float = 0.0


func _init(p_id: StringName, p_consist: ConsistSpec, p_head: TrackPosition, p_load: float) -> void:
	id = p_id
	consist = p_consist
	head = p_head
	load_factor = p_load
	brake_valve_index = maxi(0, consist.brake_valve_index_of(consist.brake_valve_default))
	power = ElectricalSystem.from_dict(consist.electrical_data)
	air = PneumaticSystem.from_dict(consist.pneumatic_data)
	_recompute_mass()


## Puts the train in the state after a completed startup procedure (warm scenarios).
func warm_start() -> void:
	for id: StringName in CabState.TOGGLES:
		cab.values[id] = id not in [&"doors_left", &"doors_right"]
	power.start_ready()
	air.charge_fully()


## Cab switches and buttons. Returns "" on success or a reason for the player.
func operate(control: StringName, value: bool) -> String:
	if not CabState.is_known(control):
		return "невідомий орган керування %s" % control
	if control in CabState.BUTTONS:
		return power.press(control, cab, controller_index) if value else ""
	if control in [&"doors_left", &"doors_right"] and value:
		if absf(speed_ms) > 0.1 or not power.control_on(cab):
			return "двері: зупиніть поїзд та увімкніть кола керування"
		controller_index = 0
	cab.values[control] = value
	return ""


## Named state checks used by cab lamps and the startup checklist (cab.json).
func check(name: String) -> bool:
	match name:
		"battery_on":
			return cab.is_on(&"battery")
		"control_on":
			return power.control_on(cab)
		"pantograph_air_ok":
			return air.p_panto >= air.panto_min or power.pantograph_up()
		"pantograph_up":
			return power.pantograph_up()
		"catenary_voltage":
			return power.line_voltage > 0.0
		"main_breaker_on":
			return power.main_breaker_on
		"aux_running":
			return power.aux_running()
		"compressors_on":
			return power.compressors_enabled(cab)
		"main_reservoir_charged":
			return air.p_gr >= air.gr_min
		"brake_pipe_charged":
			return air.p_tm >= air.tm_charge - PIPE_CHARGED_MARGIN_PA
		"ep_brake_on":
			return cab.is_on(&"ep_brake") and power.control_on(cab)
		"reverser_set":
			return reverser != 0
		"brakes_released":
			return air.p_tc < BRAKES_RELEASED_PA
		"brakes_applied":
			return air.p_tc >= BRAKES_RELEASED_PA
		"protection_tripped":
			return power.protection_tripped
		"traction_on":
			return absf(last_traction_n) > 1000.0
	push_warning("Train.check: unknown check '%s'" % name)
	return false


func _recompute_mass() -> void:
	_vehicle_masses.clear()
	_total_mass = 0.0
	_effective_mass = 0.0
	for v: VehicleSpec in consist.vehicles:
		var m: float = v.mass_empty_kg + v.seats * load_factor * consist.passenger_mass_kg
		_vehicle_masses.append(m)
		_total_mass += m
		_effective_mass += m * (1.0 + v.rotational_inertia_coef)


func total_mass_kg() -> float:
	return _total_mass


func length_m() -> float:
	return consist.length_m()


func rear(graph: TrackGraph) -> TrackPosition:
	return head.advance(graph, -length_m()).position


## Nodes currently under the train (from head back to rear).
func occupied_nodes(graph: TrackGraph) -> Array[StringName]:
	return head.advance(graph, -length_m()).nodes_passed


func controller_position_id() -> String:
	return str(consist.controller_positions[controller_index]["id"])


func brake_valve_position_id() -> String:
	return str(consist.brake_valve_positions[brake_valve_index]["id"])


## Advances the train by dt. Appends events to `events`.
func step(graph: TrackGraph, dt: float, events: Array[Dictionary]) -> void:
	_update_systems(graph, dt, events)
	_update_traction_fraction(dt)

	# Forces from each vehicle's own place on the track (grade, curve, limits).
	var grade_force: float = 0.0
	var resist: float = 0.0
	var starting: float = 0.0
	var limit: float = INF
	var behind: float = 0.0
	for i: int in consist.vehicles.size():
		var v: VehicleSpec = consist.vehicles[i]
		var m: float = _vehicle_masses[i]
		var center: TrackPosition = head.advance(graph, -(behind + v.length_m * 0.5)).position
		behind += v.length_m
		grade_force += Resistance.grade_n(m, graph.grade_ratio_at(center))
		resist += Resistance.basic_n(v, m, speed_ms)
		resist += Resistance.curve_n(m, graph.curve_radius_at(center))
		starting += Resistance.starting_n(v, m, speed_ms)
		limit = minf(limit, graph.speed_limit_at(center))
	last_speed_limit_ms = limit
	_check_overspeed(events)

	var traction: float = _traction_force(events) * reverser
	var brake: float = air.brake_fraction() * consist.max_brake_force_n()

	# Integrate: active forces (traction, grade) vs dissipative ones (resistance, brakes)
	# that only ever oppose motion and can bring the train to rest but never reverse it.
	var active: float = traction + grade_force
	var dissipative: float = resist + brake
	var new_speed: float
	# Exactly 0 only when standing: the moving branch snaps to 0 instead of reversing.
	if speed_ms == 0.0:
		var holding: float = dissipative + starting
		if absf(active) <= holding:
			new_speed = 0.0
		else:
			new_speed = (active - signf(active) * holding) / _effective_mass * dt
	else:
		var a: float = (active - signf(speed_ms) * (dissipative + starting)) / _effective_mass
		new_speed = speed_ms + a * dt
		if new_speed * speed_ms < 0.0:
			new_speed = 0.0
	accel_ms2 = (new_speed - speed_ms) / dt
	speed_ms = new_speed

	last_traction_n = traction
	last_brake_n = brake
	last_resistance_n = resist + starting
	last_grade_n = grade_force

	_move(graph, speed_ms * dt, events)


func _move(graph: TrackGraph, distance: float, events: Array[Dictionary]) -> void:
	if distance == 0.0:
		return
	var result: TrackAdvance
	if distance > 0.0:
		result = head.advance(graph, distance)
		head = result.position
	else:
		# Moving backwards: the rear leads, so it is the rear that meets switches and ends.
		result = rear(graph).advance(graph, distance)
		head = result.position.advance(graph, length_m()).position
	odometer_m += result.moved_m
	for e: Dictionary in result.events:
		var ev: Dictionary = e.duplicate()
		ev["train"] = id
		events.append(ev)
	if result.blocked:
		if absf(speed_ms) > BUFFER_COLLISION_MS:
			events.append({"type": &"buffer_stop_collision", "train": id, "speed_ms": speed_ms})
		speed_ms = 0.0
		accel_ms2 = 0.0


func _update_systems(graph: TrackGraph, dt: float, events: Array[Dictionary]) -> void:
	var seg: TrackSegment = graph.get_segment(head.segment_id)
	var wire_live: bool = (
		seg != null and seg.electrification == TrackSegment.Electrification.AC_25KV
	)
	power.step(
		dt, cab, air.p_panto >= air.panto_min, wire_live, absf(last_traction_n) > 0.0, events
	)
	var kind: PneumaticSystem.ValveKind = PneumaticSystem.kind_from_string(
		str(consist.brake_valve_positions[brake_valve_index]["kind"])
	)
	air.step(
		dt,
		kind,
		power.compressors_enabled(cab),
		cab.is_on(&"aux_compressor") and cab.is_on(&"battery"),
		cab.is_on(&"ep_brake") and power.control_on(cab)
	)
	brake_demand = air.brake_fraction()


func _check_overspeed(events: Array[Dictionary]) -> void:
	if is_inf(last_speed_limit_ms):
		overspeed = false
		return
	var v: float = absf(speed_ms)
	if not overspeed and v > last_speed_limit_ms + OVERSPEED_MARGIN_MS:
		overspeed = true
		(
			events
			. append(
				{
					"type": &"overspeed",
					"train": id,
					"speed_ms": v,
					"limit_ms": last_speed_limit_ms,
				}
			)
		)
	elif overspeed and v <= last_speed_limit_ms:
		overspeed = false


func _update_traction_fraction(dt: float) -> void:
	var target: float = float(consist.controller_positions[controller_index]["force"])
	if (
		reverser == 0
		or not power.traction_ready()
		or air.p_tc > TRACTION_CUTOFF_TC_PA
		or cab.is_on(&"doors_left")
		or cab.is_on(&"doors_right")
	):
		target = 0.0
	var ramp: float = consist.controller_force_ramp_per_s
	if traction_fraction < target:
		traction_fraction = minf(target, traction_fraction + ramp * dt)
	else:
		# Shedding load is faster than building it up.
		traction_fraction = maxf(target, traction_fraction - ramp * 3.0 * dt)


## Tractive effort magnitude after power and adhesion limits, N.
func _traction_force(events: Array[Dictionary]) -> float:
	if traction_fraction <= 0.0:
		slipping = false
		return 0.0
	var power_share: float = float(consist.controller_positions[controller_index]["power"])
	var by_force: float = traction_fraction * consist.max_traction_force_n()
	var by_power: float = power_share * consist.max_traction_power_w() / maxf(absf(speed_ms), 0.5)
	var wanted: float = minf(by_force, by_power)
	var limit: float = Adhesion.limit_n(
		consist.adhesion, consist.adhesion_mass_kg(load_factor), speed_ms, rail_condition
	)
	var was_slipping: bool = slipping
	slipping = wanted > limit
	if slipping and not was_slipping:
		events.append({"type": &"wheel_slip", "train": id})
	return limit * SLIP_TRACTION_SHARE if slipping else wanted


func to_dict() -> Dictionary:
	return {
		"id": id,
		"head":
		{"segment": head.segment_id, "offset_m": head.offset_m, "direction": head.direction},
		"speed_ms": speed_ms,
		"accel_ms2": accel_ms2,
		"load_factor": load_factor,
		"rail_condition": rail_condition,
		"reverser": reverser,
		"controller_index": controller_index,
		"brake_valve_index": brake_valve_index,
		"traction_fraction": traction_fraction,
		"brake_demand": brake_demand,
		"slipping": slipping,
		"overspeed": overspeed,
		"odometer_m": odometer_m,
		"cab": cab.to_dict(),
		"power": power.to_dict(),
		"air": air.to_dict(),
	}


func restore(d: Dictionary) -> void:
	var h: Dictionary = d["head"]
	head = TrackPosition.new(
		StringName(str(h["segment"])), float(h["offset_m"]), int(h["direction"])
	)
	speed_ms = float(d["speed_ms"])
	accel_ms2 = float(d["accel_ms2"])
	load_factor = float(d["load_factor"])
	rail_condition = int(d["rail_condition"]) as Adhesion.RailCondition
	reverser = int(d["reverser"])
	controller_index = int(d["controller_index"])
	brake_valve_index = int(d["brake_valve_index"])
	traction_fraction = float(d["traction_fraction"])
	brake_demand = float(d["brake_demand"])
	slipping = bool(d["slipping"])
	overspeed = bool(d["overspeed"])
	odometer_m = float(d["odometer_m"])
	cab.restore(d["cab"] as Dictionary)
	power.restore(d["power"] as Dictionary)
	air.restore(d["air"] as Dictionary)
	_recompute_mass()
