class_name Adhesion
extends RefCounted
## Wheel–rail adhesion limit. ψк(v) = a + b / (c + d·v), v in km/h (ПТР form);
## coefficients come from consist data. Rail condition scales the result.

enum RailCondition { DRY, WET, LEAVES, ICE }

const CONDITION_FACTOR: Dictionary[RailCondition, float] = {
	RailCondition.DRY: 1.0,
	RailCondition.WET: 0.75,
	RailCondition.LEAVES: 0.3,
	RailCondition.ICE: 0.5,
}


static func coefficient(coef: Dictionary, speed_ms: float, condition: RailCondition) -> float:
	var v: float = Units.ms_to_kmh(absf(speed_ms))
	var a: float = float(coef["a"])
	var b: float = float(coef["b"])
	var c: float = float(coef["c"])
	var d: float = float(coef["d"])
	return (a + b / (c + d * v)) * CONDITION_FACTOR[condition]


## Maximum tractive or braking force the powered wheels can transmit, N.
static func limit_n(
	coef: Dictionary, adhesion_mass_kg: float, speed_ms: float, condition: RailCondition
) -> float:
	return coefficient(coef, speed_ms, condition) * adhesion_mass_kg * Units.G
