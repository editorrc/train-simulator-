class_name ConsistSpec
extends RefCounted
## A train formation: ordered vehicles (index 0 = leading cab) plus train-level control data.
## Built from consist.json and the vehicle files it references.

var id: StringName
var series: String
var name_uk: String
var vehicles: Array[VehicleSpec] = []
var passenger_mass_kg: float = 75.0
## ψк(v) = a + b / (c + d·v), v in km/h.
var adhesion: Dictionary = {}
## [{id: String, force: float, power: float}]
var controller_positions: Array[Dictionary] = []
var controller_force_ramp_per_s: float = 0.5
## [{id, name_uk, kind: "charge"|"train"|"lap"|"lap_feed"|"service"|"service_slow"|"emergency"}]
var brake_valve_positions: Array[Dictionary] = []
var brake_valve_default: String = ""
var pneumatic_data: Dictionary = {}
var electrical_data: Dictionary = {}
var cab_id: StringName = &""


func length_m() -> float:
	var total: float = 0.0
	for v: VehicleSpec in vehicles:
		total += v.length_m
	return total


func empty_mass_kg() -> float:
	var total: float = 0.0
	for v: VehicleSpec in vehicles:
		total += v.mass_empty_kg
	return total


func seats() -> int:
	var total: int = 0
	for v: VehicleSpec in vehicles:
		total += v.seats
	return total


## Weight on powered axles, kg — the adhesion mass.
func adhesion_mass_kg(load_factor: float) -> float:
	var total: float = 0.0
	for v: VehicleSpec in vehicles:
		if v.is_powered():
			total += v.mass_empty_kg + v.seats * load_factor * passenger_mass_kg
	return total


func max_traction_force_n() -> float:
	var total: float = 0.0
	for v: VehicleSpec in vehicles:
		total += v.max_traction_force_n
	return total


func max_traction_power_w() -> float:
	var total: float = 0.0
	for v: VehicleSpec in vehicles:
		total += v.max_traction_power_w
	return total


func max_brake_force_n() -> float:
	var total: float = 0.0
	for v: VehicleSpec in vehicles:
		total += v.max_brake_force_n
	return total


func controller_index_of(position_id: String) -> int:
	for i: int in controller_positions.size():
		if str(controller_positions[i]["id"]) == position_id:
			return i
	return -1


func brake_valve_index_of(position_id: String) -> int:
	for i: int in brake_valve_positions.size():
		if str(brake_valve_positions[i]["id"]) == position_id:
			return i
	return -1


## `vehicle_data`: vehicle id -> vehicle JSON dictionary.
static func from_dict(d: Dictionary, vehicle_data: Dictionary) -> ConsistSpec:
	var c := ConsistSpec.new()
	c.id = StringName(str(d["id"]))
	c.series = str(d["series"])
	c.name_uk = str(d.get("name_uk", ""))
	c.passenger_mass_kg = float(d.get("passenger_mass_kg", 75.0))
	c.adhesion = d["adhesion"]
	for vid: Variant in d["vehicles"]:
		if not vehicle_data.has(str(vid)):
			push_error("ConsistSpec %s: unknown vehicle %s" % [c.id, vid])
			continue
		c.vehicles.append(VehicleSpec.from_dict(vehicle_data[str(vid)] as Dictionary))
	var ctl: Dictionary = d["controller"]
	c.controller_force_ramp_per_s = float(ctl["force_ramp_per_s"])
	for p: Variant in ctl["positions"]:
		c.controller_positions.append(p as Dictionary)
	c.pneumatic_data = d["pneumatic"]
	c.electrical_data = d["electrical"]
	c.cab_id = StringName(str(d.get("cab", "")))
	var bv: Dictionary = d["brake_valve"]
	c.brake_valve_default = str(bv["default"])
	for p: Variant in bv["positions"]:
		c.brake_valve_positions.append(p as Dictionary)
	return c
