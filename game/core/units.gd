class_name Units
extends RefCounted
## Unit conversions. The simulation core works in SI only (m, s, kg, N, Pa, V, A, rad).
## Railway units (km/h, kgf/cm², tf, ‰) exist only at the edges: data loading and UI.
## JSON fields carry their unit as a suffix (`length_m`, `speed_kmh`, `pressure_kgf_cm2`)
## and are converted here when loaded.

## Standard gravity, m/s².
const G: float = 9.80665
## 1 kgf/cm² in Pa.
const PA_PER_KGF_CM2: float = 98066.5
## 1 tonne-force in N.
const N_PER_TF: float = 9806.65
const MS_PER_KMH: float = 1.0 / 3.6


static func kmh_to_ms(kmh: float) -> float:
	return kmh * MS_PER_KMH


static func ms_to_kmh(ms: float) -> float:
	return ms * 3.6


static func kgf_cm2_to_pa(kgf_cm2: float) -> float:
	return kgf_cm2 * PA_PER_KGF_CM2


static func pa_to_kgf_cm2(pa: float) -> float:
	return pa / PA_PER_KGF_CM2


static func tf_to_n(tf: float) -> float:
	return tf * N_PER_TF


static func n_to_tf(n: float) -> float:
	return n / N_PER_TF


static func tonnes_to_kg(t: float) -> float:
	return t * 1000.0


static func kg_to_tonnes(kg: float) -> float:
	return kg / 1000.0


## Grade in per mille (‰, positive = uphill) to rise/run ratio.
static func permille_to_ratio(permille: float) -> float:
	return permille / 1000.0


static func ratio_to_permille(ratio: float) -> float:
	return ratio * 1000.0


## Specific resistance (N per kN of train weight, the ПТР convention) to a force in N
## for the given mass in kg.
static func specific_resistance_to_n(n_per_kn: float, mass_kg: float) -> float:
	return n_per_kn * mass_kg * G / 1000.0


static func km_to_m(km: float) -> float:
	return km * 1000.0


static func m_to_km(m: float) -> float:
	return m / 1000.0
