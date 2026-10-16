class_name Train
extends RefCounted
## One train: static consist + dynamic state + the longitudinal dynamics step.
## Brakes and traction here are the simple models of M1 (T1.6, T1.8); the pneumatic and
## electrical systems of M3 (T3.1, T3.2) will replace them behind the same state fields.
## See docs/SIMULATION.md §1–§2.

## Traction falls to this share of the adhesion limit while the wheels slip.
const SLIP_TRACTION_SHARE: float = 0.6
## Traction is cut (interlock) above this brake demand.
const TRACTION_CUTOFF_BRAKE: float = 0.05
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

## Internal state of the simple models
var traction_fraction: float = 0.0
var brake_demand: float = 0.0
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
	_recompute_mass()


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
	_update_brake(dt)
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

	var traction: float = _traction_force(events) * reverser
	var brake: float = brake_demand * consist.max_brake_force_n()

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


func _update_brake(dt: float) -> void:
	var pos: Dictionary = consist.brake_valve_positions[brake_valve_index]
	match str(pos["action"]):
		"release":
			brake_demand = maxf(0.0, brake_demand - float(pos.get("rate_per_s", 1.0)) * dt)
		"apply":
			var lim: float = float(pos.get("limit", 1.0))
			if brake_demand < lim:
				brake_demand = minf(lim, brake_demand + float(pos.get("rate_per_s", 0.2)) * dt)
		_:
			pass  # hold (перекриша)


func _update_traction_fraction(dt: float) -> void:
	var target: float = float(consist.controller_positions[controller_index]["force"])
	if reverser == 0 or brake_demand > TRACTION_CUTOFF_BRAKE:
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
		"odometer_m": odometer_m,
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
	odometer_m = float(d["odometer_m"])
	_recompute_mass()
