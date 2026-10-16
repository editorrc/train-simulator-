class_name Resistance
extends RefCounted
## Resistance to motion (ПТР conventions: specific resistance in N per kN of weight).
## All functions return a force in N; sign handling is the caller's job.

## Below this speed the starting resistance fades in fully, km/h.
const STARTING_FADE_KMH: float = 5.0
## Curve resistance constant: w_r = 700 / R (N/kN, R in m).
const CURVE_K: float = 700.0


## Main (basic) resistance of one vehicle: w0 = a + b·v + c·v², always ≥ 0.
static func basic_n(spec: VehicleSpec, mass_kg: float, speed_ms: float) -> float:
	var v: float = Units.ms_to_kmh(absf(speed_ms))
	var w0: float = spec.davis_a + spec.davis_b * v + spec.davis_c * v * v
	return Units.specific_resistance_to_n(w0, mass_kg)


## Additional resistance when starting from rest, fades linearly to 0 at STARTING_FADE_KMH.
static func starting_n(spec: VehicleSpec, mass_kg: float, speed_ms: float) -> float:
	var v: float = Units.ms_to_kmh(absf(speed_ms))
	if v >= STARTING_FADE_KMH:
		return 0.0
	var w: float = spec.starting_n_per_kn * (1.0 - v / STARTING_FADE_KMH)
	return Units.specific_resistance_to_n(w, mass_kg)


## Curve resistance, ≥ 0. radius_m = INF on straight track.
static func curve_n(mass_kg: float, radius_m: float) -> float:
	if is_inf(radius_m) or radius_m <= 0.0:
		return 0.0
	return Units.specific_resistance_to_n(CURVE_K / radius_m, mass_kg)


## Grade force along the heading, signed: negative uphill (pulls back), positive downhill.
## grade_ratio is signed for the heading (positive = uphill ahead).
static func grade_n(mass_kg: float, grade_ratio: float) -> float:
	# For railway grades sin(atan(i)) ≈ i; the ПТР convention w_i = i (‰) N/kN is the same.
	return -mass_kg * Units.G * grade_ratio
