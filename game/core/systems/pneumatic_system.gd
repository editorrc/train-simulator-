class_name PneumaticSystem
extends RefCounted
## Brake air system of a multiple unit, lumped for the whole train (docs/SIMULATION.md §4):
## ГР (main reservoirs) ← compressors; ГМ/ТМ (brake pipe) ← driver's brake valve №395;
## ЗР (auxiliary reservoir) + distributor (direct release, like ВР №292) → ГЦ/ТЦ (cylinders);
## ЕПГ (electro-pneumatic brake) fills cylinders directly in V/Va without venting the pipe;
## pantograph reservoir, topped up from ГР or by the battery-powered auxiliary compressor.
## All pressures are gauge pressures in Pa; rates come from consist data (kgf/cm² per s).

enum ValveKind { CHARGE, TRAIN, LAP, LAP_FEED, SERVICE, SERVICE_SLOW, EMERGENCY }

const KIND_BY_NAME: Dictionary[String, ValveKind] = {
	"charge": ValveKind.CHARGE,
	"train": ValveKind.TRAIN,
	"lap": ValveKind.LAP,
	"lap_feed": ValveKind.LAP_FEED,
	"service": ValveKind.SERVICE,
	"service_slow": ValveKind.SERVICE_SLOW,
	"emergency": ValveKind.EMERGENCY,
}
## In TRAIN position an overcharged pipe bleeds back to the charge pressure this slowly
## (≈ 0.3 kgf/cm² in 100 s), so the distributors do not apply.
const OVERCHARGE_BLEED_PA_S: float = 0.003 * Units.PA_PER_KGF_CM2
## The auxiliary reservoir follows the pipe up at this rate.
const AUX_RESERVOIR_RATE_PA_S: float = 0.4 * Units.PA_PER_KGF_CM2
## ...and follows slow pipe drops down at this rate while released ("мʼякість"): leaks and
## overcharge elimination do not apply the brakes, a service reduction does.
const AUX_RESERVOIR_SOFT_PA_S: float = 0.006 * Units.PA_PER_KGF_CM2

# Parameters (Pa, Pa/s)
var gr_min: float
var gr_max: float
var compressor_rate: float
var tm_charge: float
var tc_max: float
var charge_rate: float
var fast_charge_rate: float
var service_rate: float
var slow_service_rate: float
var emergency_rate: float
var leak_rate: float
var gr_drain_ratio: float
var distributor_ratio: float
var apply_sensitivity: float
var release_sensitivity: float
var emergency_threshold: float
var tc_fill_rate: float
var tc_emergency_fill_rate: float
var tc_release_rate: float
var ep_fill_rate: float
var panto_min: float
var aux_compressor_rate: float
var aux_compressor_max: float

# State
var p_gr: float = 0.0
var p_tm: float = 0.0
var p_zr: float = 0.0
var p_tc: float = 0.0
var p_panto: float = 0.0
## Compressor governor output (hysteresis between gr_min and gr_max).
var compressor_working: bool = false
## Distributor is in the applied state; tm_min = lowest pipe pressure since application.
var applied: bool = false
var tm_min: float = 0.0
## Cylinder pressure demanded by the electro-pneumatic brake.
var ep_target: float = 0.0
var lap_target: float = 0.0
var last_kind: ValveKind = ValveKind.TRAIN


static func from_dict(d: Dictionary) -> PneumaticSystem:
	var p := PneumaticSystem.new()
	var k: Callable = func(key: String) -> float: return Units.kgf_cm2_to_pa(float(d[key]))
	p.gr_min = k.call("main_reservoir_min_kgf_cm2")
	p.gr_max = k.call("main_reservoir_max_kgf_cm2")
	p.compressor_rate = k.call("compressor_rate_kgf_cm2_s")
	p.tm_charge = k.call("brake_pipe_charge_kgf_cm2")
	p.tc_max = k.call("brake_cylinder_max_kgf_cm2")
	p.charge_rate = k.call("charge_rate_kgf_cm2_s")
	p.fast_charge_rate = k.call("fast_charge_rate_kgf_cm2_s")
	p.service_rate = k.call("service_rate_kgf_cm2_s")
	p.slow_service_rate = k.call("slow_service_rate_kgf_cm2_s")
	p.emergency_rate = k.call("emergency_rate_kgf_cm2_s")
	p.leak_rate = k.call("brake_pipe_leak_kgf_cm2_s")
	p.gr_drain_ratio = float(d["main_reservoir_drain_ratio"])
	p.distributor_ratio = float(d["distributor_ratio"])
	p.apply_sensitivity = k.call("distributor_sensitivity_kgf_cm2")
	p.release_sensitivity = k.call("release_sensitivity_kgf_cm2")
	p.emergency_threshold = k.call("emergency_threshold_kgf_cm2")
	p.tc_fill_rate = k.call("cylinder_fill_rate_kgf_cm2_s")
	p.tc_emergency_fill_rate = k.call("cylinder_emergency_fill_rate_kgf_cm2_s")
	p.tc_release_rate = k.call("cylinder_release_rate_kgf_cm2_s")
	p.ep_fill_rate = k.call("ep_fill_rate_kgf_cm2_s")
	p.panto_min = k.call("pantograph_min_kgf_cm2")
	p.aux_compressor_rate = k.call("aux_compressor_rate_kgf_cm2_s")
	p.aux_compressor_max = k.call("aux_compressor_max_kgf_cm2")
	return p


static func kind_from_string(s: String) -> ValveKind:
	return KIND_BY_NAME.get(s, ValveKind.LAP)


## Ready-to-run state: reservoirs and pipe charged, brakes released.
func charge_fully() -> void:
	p_gr = gr_max
	p_tm = tm_charge
	p_zr = tm_charge
	p_tc = 0.0
	p_panto = gr_max
	applied = false
	ep_target = 0.0


## Brake effort 0..1 (cylinder pressure relative to its maximum).
func brake_fraction() -> float:
	return clampf(p_tc / tc_max, 0.0, 1.0)


func step(
	dt: float,
	kind: ValveKind,
	compressors_enabled: bool,
	aux_compressor_running: bool,
	ep_brake_active: bool
) -> void:
	_compressors(dt, compressors_enabled, aux_compressor_running)
	_driver_valve(dt, kind, ep_brake_active)
	_distributor(dt, kind, ep_brake_active)
	last_kind = kind


func _compressors(dt: float, enabled: bool, aux_running: bool) -> void:
	if not enabled:
		compressor_working = false
	elif p_gr < gr_min:
		compressor_working = true
	elif p_gr >= gr_max:
		compressor_working = false
	if compressor_working:
		p_gr = minf(gr_max, p_gr + compressor_rate * dt)
	# Pantograph reservoir: fed from ГР through a check valve, or by the aux compressor.
	if p_gr > p_panto:
		p_panto = p_gr
	if aux_running and p_panto < aux_compressor_max:
		p_panto = minf(aux_compressor_max, p_panto + aux_compressor_rate * dt)


## Moves the pipe toward `target` at `rate`, drawing the air from ГР.
func _feed_pipe(dt: float, target: float, rate: float) -> void:
	var limit: float = minf(target, p_gr)
	if p_tm >= limit:
		return
	var dp: float = minf(rate * dt, limit - p_tm)
	p_tm += dp
	p_gr = maxf(0.0, p_gr - dp * gr_drain_ratio)


func _driver_valve(dt: float, kind: ValveKind, ep_active: bool) -> void:
	if kind != last_kind and kind == ValveKind.LAP_FEED:
		lap_target = p_tm
	p_tm = maxf(0.0, p_tm - leak_rate * dt)
	match kind:
		ValveKind.CHARGE:
			_feed_pipe(dt, p_gr, fast_charge_rate)
		ValveKind.TRAIN:
			if p_tm > tm_charge:
				p_tm = maxf(tm_charge, p_tm - OVERCHARGE_BLEED_PA_S * dt)
			else:
				_feed_pipe(dt, tm_charge, charge_rate)
		ValveKind.LAP_FEED:
			_feed_pipe(dt, lap_target, charge_rate)
		ValveKind.SERVICE:
			if not ep_active:
				p_tm = maxf(0.0, p_tm - service_rate * dt)
		ValveKind.SERVICE_SLOW:
			if not ep_active:
				p_tm = maxf(0.0, p_tm - slow_service_rate * dt)
		ValveKind.EMERGENCY:
			p_tm = maxf(0.0, p_tm - emergency_rate * dt)
		_:
			pass  # LAP: pipe isolated, only leaks


func _distributor(dt: float, kind: ValveKind, ep_active: bool) -> void:
	if p_tm > p_zr:
		p_zr = minf(p_tm, p_zr + AUX_RESERVOIR_RATE_PA_S * dt)
	elif not applied:
		p_zr = maxf(p_tm, p_zr - AUX_RESERVOIR_SOFT_PA_S * dt)
	var reduction: float = p_zr - p_tm
	if not applied and reduction > apply_sensitivity:
		applied = true
		tm_min = p_tm
	if applied:
		tm_min = minf(tm_min, p_tm)
		if p_tm > tm_min + release_sensitivity:
			applied = false  # direct (non-graduated) release
	var emergency: bool = p_tm < emergency_threshold and p_zr > emergency_threshold
	var pneumatic_target: float = 0.0
	if applied or emergency:
		pneumatic_target = (
			tc_max if emergency else clampf((p_zr - tm_min) * distributor_ratio, 0.0, tc_max)
		)
	# Electro-pneumatic brake: V/Va fill, VI full, III/IV hold, I/II release.
	if ep_active:
		match kind:
			ValveKind.EMERGENCY:
				ep_target = tc_max
			ValveKind.SERVICE:
				ep_target = minf(tc_max, ep_target + ep_fill_rate * dt)
			ValveKind.SERVICE_SLOW:
				ep_target = minf(tc_max, ep_target + ep_fill_rate / 3.0 * dt)
			ValveKind.CHARGE, ValveKind.TRAIN:
				ep_target = maxf(0.0, ep_target - tc_release_rate * dt)
			_:
				pass
	else:
		ep_target = 0.0
	var target: float = maxf(pneumatic_target, ep_target)
	if p_tc < target:
		var rate: float = (
			tc_emergency_fill_rate if emergency or kind == ValveKind.EMERGENCY else tc_fill_rate
		)
		if ep_active and ep_target > pneumatic_target:
			rate = maxf(rate, ep_fill_rate)
		p_tc = minf(target, p_tc + rate * dt)
	elif p_tc > target:
		p_tc = maxf(target, p_tc - tc_release_rate * dt)


func to_dict() -> Dictionary:
	return {
		"p_gr": p_gr,
		"p_tm": p_tm,
		"p_zr": p_zr,
		"p_tc": p_tc,
		"p_panto": p_panto,
		"compressor_working": compressor_working,
		"applied": applied,
		"tm_min": tm_min,
		"ep_target": ep_target,
		"lap_target": lap_target,
		"last_kind": last_kind,
	}


func restore(d: Dictionary) -> void:
	p_gr = float(d["p_gr"])
	p_tm = float(d["p_tm"])
	p_zr = float(d["p_zr"])
	p_tc = float(d["p_tc"])
	p_panto = float(d["p_panto"])
	compressor_working = bool(d["compressor_working"])
	applied = bool(d["applied"])
	tm_min = float(d["tm_min"])
	ep_target = float(d["ep_target"])
	lap_target = float(d["lap_target"])
	last_kind = int(d["last_kind"]) as ValveKind
