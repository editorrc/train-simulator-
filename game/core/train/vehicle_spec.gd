class_name VehicleSpec
extends RefCounted
## Static description of one vehicle, loaded from rolling_stock/<series>/vehicles/<id>.json.
## All fields SI.

var id: StringName
var series: String
var type: String
var name_uk: String
var mass_empty_kg: float
var length_m: float
var axles: int
var powered_axles: int
var seats: int
var has_cab: bool
var max_speed_ms: float
var rotational_inertia_coef: float
## Davis coefficients, w0 = a + b·v + c·v² in N/kN with v in km/h (ПТР convention).
var davis_a: float
var davis_b: float
var davis_c: float
var starting_n_per_kn: float
## 0 for non-powered vehicles.
var max_traction_force_n: float = 0.0
var max_traction_power_w: float = 0.0
var max_brake_force_n: float
var verified: bool


func is_powered() -> bool:
	return powered_axles > 0 and max_traction_force_n > 0.0


static func from_dict(d: Dictionary) -> VehicleSpec:
	var v := VehicleSpec.new()
	v.id = StringName(str(d["id"]))
	v.series = str(d["series"])
	v.type = str(d["type"])
	v.name_uk = str(d.get("name_uk", ""))
	v.mass_empty_kg = Units.tonnes_to_kg(float(d["mass_empty_t"]))
	v.length_m = float(d["length_m"])
	v.axles = int(d["axles"])
	v.powered_axles = int(d["powered_axles"])
	v.seats = int(d.get("seats", 0))
	v.has_cab = bool(d.get("has_cab", false))
	v.max_speed_ms = Units.kmh_to_ms(float(d.get("max_speed_kmh", 120.0)))
	v.rotational_inertia_coef = float(d.get("rotational_inertia_coef", 0.1))
	var r: Dictionary = d["resistance"]
	v.davis_a = float(r["a"])
	v.davis_b = float(r["b"])
	v.davis_c = float(r["c"])
	v.starting_n_per_kn = float(r.get("starting_n_per_kn", 0.0))
	if d.has("traction"):
		var t: Dictionary = d["traction"]
		v.max_traction_force_n = float(t["max_force_kn"]) * 1000.0
		v.max_traction_power_w = float(t["max_power_kw"]) * 1000.0
	v.max_brake_force_n = float((d["brakes"] as Dictionary)["max_brake_force_kn"]) * 1000.0
	v.verified = bool((d.get("meta", {}) as Dictionary).get("verified", false))
	return v
