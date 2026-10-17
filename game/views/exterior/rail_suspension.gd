class_name RailSuspension
extends RefCounted
## Mass-dependent, critically damped secondary suspension, separate from rail contact.

var roll: float = 0.0
var pitch: float = 0.0
var extension: float = 0.0
var _roll_velocity: float = 0.0
var _pitch_velocity: float = 0.0
var _extension_velocity: float = 0.0


static func spring(
	value: float, velocity: float, target: float, omega: float, dt: float
) -> Vector2:
	var offset: float = value - target
	var b: float = velocity + omega * offset
	var decay: float = exp(-omega * maxf(dt, 0.0))
	return Vector2(target + (offset + b * dt) * decay, (velocity - omega * b * dt) * decay)


func advance(
	spec: VehicleSpec,
	mass_kg: float,
	trailing_mass_kg: float,
	lateral_ms2: float,
	longitudinal_ms2: float,
	dt: float
) -> void:
	var omega: float = (
		TAU
		* float(spec.visual.get("secondary_frequency_hz", 1.0))
		* sqrt(50000.0 / maxf(mass_kg, 1.0))
	)
	var roll_target: float = clampf(
		-lateral_ms2 * float(spec.visual.get("secondary_roll_rad_per_ms2", .008)), -.035, .035
	)
	var pitch_target: float = clampf(
		longitudinal_ms2 * float(spec.visual.get("secondary_pitch_rad_per_ms2", .006)), -.018, .018
	)
	var state: Vector2 = spring(roll, _roll_velocity, roll_target, omega, dt)
	roll = state.x
	_roll_velocity = state.y
	state = spring(pitch, _pitch_velocity, pitch_target, omega, dt)
	pitch = state.x
	_pitch_velocity = state.y
	var stiffness: float = maxf(float(spec.visual.get("coupler_stiffness_n_m", 20000000.0)), 1.0)
	var target_extension: float = clampf(
		trailing_mass_kg * longitudinal_ms2 / stiffness, -.025, .025
	)
	state = spring(
		extension,
		_extension_velocity,
		target_extension,
		sqrt(stiffness / maxf(trailing_mass_kg, 10000.0)),
		dt
	)
	extension = state.x
	_extension_velocity = state.y
