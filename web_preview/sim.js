// Web preview of the simulation core — a line-by-line port of game/core (GDScript).
// The GDScript code is the source of truth. This port exists only so the project can be
// looked at in a browser; parity is enforced by web_preview/parity_check.js against a
// trajectory recorded from Godot (tools/tests/fixtures/parity_reference.json).
// Keep function names and operation order identical to the GDScript originals.
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.UVTSim = factory();
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  // ---- core/units.gd
  const Units = {
    G: 9.80665,
    MS_PER_KMH: 1.0 / 3.6,
    kmh_to_ms: (kmh) => kmh * (1.0 / 3.6),
    ms_to_kmh: (ms) => ms * 3.6,
    permille_to_ratio: (p) => p / 1000.0,
    tonnes_to_kg: (t) => t * 1000.0,
    specific_resistance_to_n: (w, m) => (w * m * 9.80665) / 1000.0,
  };
  const SIM_DT = 1.0 / 60.0;

  // ---- core/track/*
  const SIDE_A = 0, SIDE_B = 1;
  const endKey = (seg, side) => seg + ":" + (side === SIDE_A ? "a" : "b");
  const endFrom = (d) => ({ segment: d.segment, side: d.end === "a" ? SIDE_A : SIDE_B });
  const endEq = (x, y) => x && y && x.segment === y.segment && x.side === y.side;

  function segmentFromDict(d) {
    const s = {
      id: d.id, length_m: +d.length_m, node_a: d.node_a, node_b: d.node_b, electrification: d.electrification || "none",
      grade_points: (d.grades || []).map((p) => ({ at_m: +p.at_m, ratio: Units.permille_to_ratio(+p.permille) }))
        .sort((x, y) => x.at_m - y.at_m),
      curves: (d.curves || []).map((c) => ({ from_m: +c.from_m, to_m: +c.to_m, radius_m: +c.radius_m })),
      speed_limits: (d.speed_limits || []).map((l) => ({ from_m: +l.from_m, to_m: +l.to_m, speed_ms: Units.kmh_to_ms(+l.speed_kmh) })),
    };
    s.grade_ratio_at = (o) => { let g = 0; for (const p of s.grade_points) { if (p.at_m <= o) g = p.ratio; else break; } return g; };
    s.curve_radius_at = (o) => { for (const c of s.curves) if (o >= c.from_m && o <= c.to_m) return c.radius_m; return Infinity; };
    s.speed_limit_at = (o) => { let l = Infinity; for (const x of s.speed_limits) if (o >= x.from_m && o <= x.to_m) l = Math.min(l, x.speed_ms); return l; };
    return s;
  }

  function nodeFromDict(d) {
    const n = { id: d.id, kind: d.kind, ends: [], state: d.state === "diverging" ? "diverging" : "straight" };
    if (n.kind === "switch") { n.trunk = endFrom(d.trunk); n.straight = endFrom(d.straight); n.diverging = endFrom(d.diverging); }
    else n.ends = d.ends.map(endFrom);
    n.all_ends = () => (n.kind === "switch" ? [n.trunk, n.straight, n.diverging] : n.ends);
    n.pass_through = (from) => {
      if (n.kind === "end") return { next: null, event: "end_of_track" };
      if (n.kind === "joint") { for (const e of n.ends) if (!endEq(e, from)) return { next: e, event: "" }; return { next: null, event: "end_of_track" }; }
      if (endEq(from, n.trunk)) return { next: n.state === "straight" ? n.straight : n.diverging, event: "" };
      const ok = (endEq(from, n.straight) && n.state === "straight") || (endEq(from, n.diverging) && n.state === "diverging");
      return { next: n.trunk, event: ok ? "" : "switch_trailed" };
    };
    return n;
  }

  function graphFromDict(d) {
    const g = { segments: {}, nodes: {}, _end: {} };
    for (const s of d.segments) g.segments[s.id] = segmentFromDict(s);
    for (const n of d.nodes) g.nodes[n.id] = nodeFromDict(n);
    for (const n of Object.values(g.nodes)) for (const e of n.all_ends()) g._end[endKey(e.segment, e.side)] = n.id;
    g.node_at = (e) => { const id = g._end[endKey(e.segment, e.side)]; return id === undefined ? null : g.nodes[id]; };
    g.grade_ratio_at = (p) => { const s = g.segments[p.segment]; return s ? s.grade_ratio_at(p.offset) * p.dir : 0; };
    g.curve_radius_at = (p) => { const s = g.segments[p.segment]; return s ? s.curve_radius_at(p.offset) : Infinity; };
    g.speed_limit_at = (p) => { const s = g.segments[p.segment]; return s ? s.speed_limit_at(p.offset) : Infinity; };
    return g;
  }

  // TrackProfileSpan: piecewise-exact profile under a uniformly distributed vehicle.
  function profileSpan(g, front, length) {
    const result = { grade_ratio: 0, inverse_radius_m: 0, speed_limit_ms: Infinity };
    let p = { ...front, dir: -front.dir }, remaining = length;
    for (let hop = 0; hop < 10000; hop++) {
      const s = g.segments[p.segment];
      if (!s || remaining <= 1e-9) break;
      const available = p.dir > 0 ? s.length_m - p.offset : p.offset;
      const extent = Math.min(remaining, available), end = p.offset + p.dir * extent;
      const low = Math.min(p.offset, end), high = Math.max(p.offset, end), cuts = [low, high];
      for (const grade of s.grade_points) if (grade.at_m > low && grade.at_m < high) cuts.push(grade.at_m);
      for (const intervals of [s.curves, s.speed_limits]) for (const interval of intervals)
        for (const key of ['from_m', 'to_m']) if (interval[key] > low && interval[key] < high) cuts.push(interval[key]);
      cuts.sort((a, b) => a - b);
      for (let i = 1; i < cuts.length; i++) {
        const span = cuts[i] - cuts[i - 1];
        if (span <= 0) continue;
        const mid = (cuts[i] + cuts[i - 1]) * .5, radius = s.curve_radius_at(mid);
        result.grade_ratio += s.grade_ratio_at(mid) * -p.dir * span;
        result.inverse_radius_m += radius > 0 ? span / radius : 0;
        result.speed_limit_ms = Math.min(result.speed_limit_ms, s.speed_limit_at(mid));
      }
      remaining -= extent;
      if (remaining <= 1e-9) break;
      const exit = { segment: s.id, side: p.dir > 0 ? SIDE_B : SIDE_A };
      const node = g.node_at(exit), next = node ? node.pass_through(exit).next : null;
      if (!next) {
        result.grade_ratio += s.grade_ratio_at(end) * -p.dir * remaining;
        const radius = s.curve_radius_at(end);
        result.inverse_radius_m += radius > 0 ? remaining / radius : 0;
        result.speed_limit_ms = Math.min(result.speed_limit_ms, s.speed_limit_at(end));
        break;
      }
      p = { segment: next.segment, offset: next.side === SIDE_A ? 0 : g.segments[next.segment].length_m, dir: next.side === SIDE_A ? 1 : -1 };
    }
    if (length > 0) { result.grade_ratio /= length; result.inverse_radius_m /= length; }
    return result;
  }

  // TrackPosition as a plain value {segment, offset, dir}; advance() never mutates.
  function advance(graph, pos, distance) {
    const res = { position: null, moved_m: 0, blocked: false, events: [], nodes_passed: [] };
    const p = distance >= 0 ? { ...pos } : { ...pos, dir: -pos.dir };
    let remaining = Math.abs(distance);
    for (let hops = 0; ; hops++) {
      const seg = graph.segments[p.segment];
      const toExit = p.dir > 0 ? seg.length_m - p.offset : p.offset;
      if (remaining <= toExit) { p.offset += p.dir * remaining; res.moved_m += remaining; break; }
      res.moved_m += toExit; remaining -= toExit;
      const exitEnd = { segment: seg.id, side: p.dir > 0 ? SIDE_B : SIDE_A };
      const node = graph.node_at(exitEnd);
      const passed = node ? node.pass_through(exitEnd) : { next: null, event: "end_of_track" };
      if (node) res.nodes_passed.push(node.id);
      if (passed.event) res.events.push({ type: passed.event, node: node ? node.id : "", at_m: res.moved_m });
      if (!passed.next) { p.offset = p.dir > 0 ? seg.length_m : 0; res.blocked = true; break; }
      const ns = graph.segments[passed.next.segment];
      p.segment = passed.next.segment;
      if (passed.next.side === SIDE_A) { p.dir = 1; p.offset = 0; } else { p.dir = -1; p.offset = ns.length_m; }
      if (hops > 10000) { res.blocked = true; break; }
    }
    res.position = distance >= 0 ? p : { ...p, dir: -p.dir };
    return res;
  }

  // ---- core/train/*
  function vehicleFromDict(d) {
    const r = d.resistance;
    return {
      id: d.id, type: d.type, mass_empty_kg: Units.tonnes_to_kg(+d.mass_empty_t), length_m: +d.length_m,
      seats: +(d.seats || 0), rot: +(d.rotational_inertia_coef ?? 0.1), powered_axles: +d.powered_axles,
      a: +r.a, b: +r.b, c: +r.c, starting: +(r.starting_n_per_kn || 0),
      f_max: d.traction ? +d.traction.max_force_kn * 1000 : 0, p_max: d.traction ? +d.traction.max_power_kw * 1000 : 0,
      brake_max: +d.brakes.max_brake_force_kn * 1000,
    };
  }

  function consistFromDict(d, vehicles) {
    const c = {
      id: d.id, series: d.series, name_uk: d.name_uk, pax_kg: +(d.passenger_mass_kg ?? 75), adhesion: d.adhesion,
      vehicles: d.vehicles.map((id) => vehicleFromDict(vehicles[id])),
      controller: d.controller.positions, ramp: +d.controller.force_ramp_per_s,
      valve: d.brake_valve.positions, valve_default: d.brake_valve.default,
      pneumatic: d.pneumatic, electrical: d.electrical,
    };
    const sum = (f) => c.vehicles.reduce((s, v) => s + f(v), 0);
    c.length_m = () => sum((v) => v.length_m);
    c.f_max = () => sum((v) => v.f_max);
    c.p_max = () => sum((v) => v.p_max);
    c.brake_max = () => sum((v) => v.brake_max);
    c.adhesion_mass = (load) => sum((v) => (v.powered_axles > 0 && v.f_max > 0 ? v.mass_empty_kg + v.seats * load * c.pax_kg : 0));
    c.controller_index_of = (id) => c.controller.findIndex((p) => p.id === id);
    c.valve_index_of = (id) => c.valve.findIndex((p) => p.id === id);
    return c;
  }

  const Resistance = {
    basic_n(v, m, speed) { const k = Units.ms_to_kmh(Math.abs(speed)); return Units.specific_resistance_to_n(v.a + v.b * k + v.c * k * k, m); },
    starting_n(v, m, speed) { const k = Units.ms_to_kmh(Math.abs(speed)); if (k >= 5.0) return 0; return Units.specific_resistance_to_n(v.starting * (1.0 - k / 5.0), m); },
    curve_n(m, r) { if (!isFinite(r) || r <= 0) return 0; return Units.specific_resistance_to_n(700.0 / r, m); },
    grade_n(m, ratio) { return -m * Units.G * ratio; },
  };
  const RAIL = { dry: 1.0, wet: 0.75, leaves: 0.3, ice: 0.5 };
  function adhesionLimit(coef, mass, speed, cond) {
    const v = Units.ms_to_kmh(Math.abs(speed));
    return (coef.a + coef.b / (coef.c + coef.d * v)) * RAIL[cond] * mass * Units.G;
  }


  // ---- core/train/cab_state.gd
  const TOGGLES = ["battery", "control_circuits", "pantograph", "aux_machines", "compressors", "ep_brake", "headlights", "doors_left", "doors_right"];
  const HOLDS = ["aux_compressor", "horn", "whistle"];
  const BUTTONS = ["main_breaker_on", "main_breaker_off", "protection_reset"];

  // ---- core/systems/pneumatic_system.gd
  const KGF = 98066.5;
  const VALVE_KINDS = { charge: 0, train: 1, lap: 2, lap_feed: 3, service: 4, service_slow: 5, emergency: 6 };
  function makeAir(d) {
    const k = (key) => +d[key] * KGF;
    const a = {
      gr_min: k("main_reservoir_min_kgf_cm2"), gr_max: k("main_reservoir_max_kgf_cm2"), compressor_rate: k("compressor_rate_kgf_cm2_s"),
      tm_charge: k("brake_pipe_charge_kgf_cm2"), tc_max: k("brake_cylinder_max_kgf_cm2"), charge_rate: k("charge_rate_kgf_cm2_s"),
      fast_charge_rate: k("fast_charge_rate_kgf_cm2_s"), service_rate: k("service_rate_kgf_cm2_s"), slow_service_rate: k("slow_service_rate_kgf_cm2_s"),
      emergency_rate: k("emergency_rate_kgf_cm2_s"), leak_rate: k("brake_pipe_leak_kgf_cm2_s"), gr_drain_ratio: +d.main_reservoir_drain_ratio,
      distributor_ratio: +d.distributor_ratio, apply_sensitivity: k("distributor_sensitivity_kgf_cm2"), release_sensitivity: k("release_sensitivity_kgf_cm2"),
      emergency_threshold: k("emergency_threshold_kgf_cm2"), tc_fill_rate: k("cylinder_fill_rate_kgf_cm2_s"),
      tc_emergency_fill_rate: k("cylinder_emergency_fill_rate_kgf_cm2_s"), tc_release_rate: k("cylinder_release_rate_kgf_cm2_s"),
      ep_fill_rate: k("ep_fill_rate_kgf_cm2_s"), panto_min: k("pantograph_min_kgf_cm2"), aux_compressor_rate: k("aux_compressor_rate_kgf_cm2_s"),
      aux_compressor_max: k("aux_compressor_max_kgf_cm2"),
      p_gr: 0, p_tm: 0, p_zr: 0, p_tc: 0, p_panto: 0, compressor_working: false, applied: false, tm_min: 0, ep_target: 0, lap_target: 0, last_kind: 1,
    };
    const BLEED = 0.003 * KGF, ZR_RATE = 0.4 * KGF, ZR_SOFT = 0.006 * KGF;
    a.charge_fully = () => { a.p_gr = a.gr_max; a.p_tm = a.tm_charge; a.p_zr = a.tm_charge; a.p_tc = 0; a.p_panto = a.gr_max; a.applied = false; a.ep_target = 0; };
    a.brake_fraction = () => Math.min(Math.max(a.p_tc / a.tc_max, 0), 1);
    const feed = (dt, target, rate) => {
      const limit = Math.min(target, a.p_gr); if (a.p_tm >= limit) return;
      const dp = Math.min(rate * dt, limit - a.p_tm); a.p_tm += dp; a.p_gr = Math.max(0, a.p_gr - dp * a.gr_drain_ratio);
    };
    a.step = (dt, kind, compressorsEnabled, auxRunning, ep) => {
      if (!compressorsEnabled) a.compressor_working = false;
      else if (a.p_gr < a.gr_min) a.compressor_working = true;
      else if (a.p_gr >= a.gr_max) a.compressor_working = false;
      if (a.compressor_working) a.p_gr = Math.min(a.gr_max, a.p_gr + a.compressor_rate * dt);
      if (a.p_gr > a.p_panto) a.p_panto = a.p_gr;
      if (auxRunning && a.p_panto < a.aux_compressor_max) a.p_panto = Math.min(a.aux_compressor_max, a.p_panto + a.aux_compressor_rate * dt);
      // driver's valve
      if (kind !== a.last_kind && kind === 3) a.lap_target = a.p_tm;
      a.p_tm = Math.max(0, a.p_tm - a.leak_rate * dt);
      switch (kind) {
        case 0: feed(dt, a.p_gr, a.fast_charge_rate); break;
        case 1: if (a.p_tm > a.tm_charge) a.p_tm = Math.max(a.tm_charge, a.p_tm - BLEED * dt); else feed(dt, a.tm_charge, a.charge_rate); break;
        case 3: feed(dt, a.lap_target, a.charge_rate); break;
        case 4: if (!ep) a.p_tm = Math.max(0, a.p_tm - a.service_rate * dt); break;
        case 5: if (!ep) a.p_tm = Math.max(0, a.p_tm - a.slow_service_rate * dt); break;
        case 6: a.p_tm = Math.max(0, a.p_tm - a.emergency_rate * dt); break;
      }
      // distributor
      if (a.p_tm > a.p_zr) a.p_zr = Math.min(a.p_tm, a.p_zr + ZR_RATE * dt);
      else if (!a.applied) a.p_zr = Math.max(a.p_tm, a.p_zr - ZR_SOFT * dt);
      const reduction = a.p_zr - a.p_tm;
      if (!a.applied && reduction > a.apply_sensitivity) { a.applied = true; a.tm_min = a.p_tm; }
      if (a.applied) { a.tm_min = Math.min(a.tm_min, a.p_tm); if (a.p_tm > a.tm_min + a.release_sensitivity) a.applied = false; }
      const emergency = a.p_tm < a.emergency_threshold && a.p_zr > a.emergency_threshold;
      let pneu = 0;
      if (a.applied || emergency) pneu = emergency ? a.tc_max : Math.min(Math.max((a.p_zr - a.tm_min) * a.distributor_ratio, 0), a.tc_max);
      if (ep) {
        if (kind === 6) a.ep_target = a.tc_max;
        else if (kind === 4) a.ep_target = Math.min(a.tc_max, a.ep_target + a.ep_fill_rate * dt);
        else if (kind === 5) a.ep_target = Math.min(a.tc_max, a.ep_target + a.ep_fill_rate / 3.0 * dt);
        else if (kind === 0 || kind === 1) a.ep_target = Math.max(0, a.ep_target - a.tc_release_rate * dt);
      } else a.ep_target = 0;
      const target = Math.max(pneu, a.ep_target);
      if (a.p_tc < target) {
        let rate = emergency || kind === 6 ? a.tc_emergency_fill_rate : a.tc_fill_rate;
        if (ep && a.ep_target > pneu) rate = Math.max(rate, a.ep_fill_rate);
        a.p_tc = Math.min(target, a.p_tc + rate * dt);
      } else if (a.p_tc > target) a.p_tc = Math.max(target, a.p_tc - a.tc_release_rate * dt);
      a.last_kind = kind;
    };
    return a;
  }

  // ---- core/systems/electrical_system.gd
  function makePower(d) {
    const e = { raise_s: +d.pantograph_raise_s, lower_s: +d.pantograph_lower_s, aux_s: +d.aux_start_s, nominal_v: +d.catenary_kv * 1000,
      pantograph_position: 0, main_breaker_on: false, protection_tripped: false, aux_progress: 0, line_voltage: 0 };
    e.control_on = (cab) => cab.battery && cab.control_circuits;
    e.pantograph_up = () => e.pantograph_position >= 1.0;
    e.aux_running = () => e.main_breaker_on && e.aux_progress >= 1.0;
    e.compressors_enabled = (cab) => e.aux_running() && cab.compressors;
    e.traction_ready = () => e.main_breaker_on && e.aux_running() && !e.protection_tripped;
    e.press = (button, cab, controllerIndex) => {
      if (button === "main_breaker_on") {
        if (!e.control_on(cab)) return "немає живлення кіл керування";
        if (e.protection_tripped) return "спрацювало реле захисту — спершу «Поверн. РП»";
        if (e.line_voltage <= 0) return "немає напруги в контактній мережі (струмоприймач опущено?)";
        if (controllerIndex !== 0) return "контролер має бути в положенні 0";
        e.main_breaker_on = true;
      } else if (button === "main_breaker_off") e.main_breaker_on = false;
      else if (button === "protection_reset") { if (!e.control_on(cab)) return "немає живлення кіл керування"; e.protection_tripped = false; }
      return "";
    };
    e.step = (dt, cab, airOk, wireLive, current, events) => {
      const wantUp = e.control_on(cab) && cab.pantograph && airOk, wasUp = e.pantograph_up();
      e.pantograph_position = wantUp ? Math.min(1, e.pantograph_position + dt / e.raise_s) : Math.max(0, e.pantograph_position - dt / e.lower_s);
      if (wasUp && !e.pantograph_up() && e.main_breaker_on && current) { events.push({ type: "pantograph_lowered_under_load" }); e.protection_tripped = true; }
      e.line_voltage = e.pantograph_up() && wireLive ? e.nominal_v : 0;
      if (e.main_breaker_on && (e.line_voltage <= 0 || !e.control_on(cab))) { e.main_breaker_on = false; events.push({ type: "main_breaker_tripped" }); }
      e.aux_progress = e.main_breaker_on && cab.aux_machines ? Math.min(1, e.aux_progress + dt / e.aux_s) : 0;
    };
    e.start_ready = () => { e.pantograph_position = 1; e.main_breaker_on = true; e.aux_progress = 1; e.line_voltage = e.nominal_v; };
    return e;
  }

  function makeTrain(id, consist, head, load) {
    const t = {
      id, consist, head, load, rail: "dry", speed_ms: 0, accel_ms2: 0, reverser: 0, controller_index: 0,
      valve_index: Math.max(0, consist.valve_index_of(consist.valve_default)),
      traction_fraction: 0, brake_demand: 0, slipping: false, overspeed: false, odometer_m: 0,
      cab: Object.fromEntries([...TOGGLES, ...HOLDS].map((k) => [k, false])),
      power: makePower(consist.electrical), air: makeAir(consist.pneumatic),
      last: { traction: 0, brake: 0, resistance: 0, grade: 0, limit: Infinity },
    };
    t.masses = consist.vehicles.map((v) => v.mass_empty_kg + v.seats * load * consist.pax_kg);
    t.total_mass = t.masses.reduce((a, b) => a + b, 0);
    t.eff_mass = consist.vehicles.reduce((s, v, i) => s + t.masses[i] * (1.0 + v.rot), 0);
    t.rear = (g) => advance(g, t.head, -consist.length_m()).position;
    t.occupied_nodes = (g) => advance(g, t.head, -consist.length_m()).nodes_passed;
    t.warm_start = () => { for (const k of TOGGLES) t.cab[k] = !["doors_left", "doors_right"].includes(k); t.power.start_ready(); t.air.charge_fully(); };
    t.operate = (control, value) => {
      if (!TOGGLES.includes(control) && !HOLDS.includes(control) && !BUTTONS.includes(control)) return "невідомий орган керування " + control;
      if (BUTTONS.includes(control)) return value ? t.power.press(control, t.cab, t.controller_index) : "";
      if (["doors_left", "doors_right"].includes(control) && value) {
        if (Math.abs(t.speed_ms) > 0.1 || !t.power.control_on(t.cab)) return "двері: зупиніть поїзд та увімкніть кола керування";
        t.controller_index = 0;
      }
      t.cab[control] = !!value; return "";
    };
    t.check = (name) => {
      const P = t.power, A = t.air, c = t.cab;
      switch (name) {
        case "battery_on": return c.battery;
        case "control_on": return P.control_on(c);
        case "pantograph_air_ok": return A.p_panto >= A.panto_min || P.pantograph_up();
        case "pantograph_up": return P.pantograph_up();
        case "catenary_voltage": return P.line_voltage > 0;
        case "main_breaker_on": return P.main_breaker_on;
        case "aux_running": return P.aux_running();
        case "compressors_on": return P.compressors_enabled(c);
        case "main_reservoir_charged": return A.p_gr >= A.gr_min;
        case "brake_pipe_charged": return A.p_tm >= A.tm_charge - 0.2 * KGF;
        case "ep_brake_on": return c.ep_brake && P.control_on(c);
        case "reverser_set": return t.reverser !== 0;
        case "brakes_released": return A.p_tc < 0.1 * KGF;
        case "brakes_applied": return A.p_tc >= 0.1 * KGF;
        case "protection_tripped": return P.protection_tripped;
        case "traction_on": return Math.abs(t.last.traction) > 1000;
      }
      return false;
    };
    return t;
  }

  function trainStep(t, g, dt, events) {
    const c = t.consist;
    // systems
    const seg = g.segments[t.head.segment];
    t.power.step(dt, t.cab, t.air.p_panto >= t.air.panto_min, !!seg && seg.electrification === "ac_25kv", Math.abs(t.last.traction) > 0, events);
    t.air.step(dt, VALVE_KINDS[c.valve[t.valve_index].kind] ?? 2, t.power.compressors_enabled(t.cab), t.cab.aux_compressor && t.cab.battery, t.cab.ep_brake && t.power.control_on(t.cab));
    t.brake_demand = t.air.brake_fraction();
    // traction fraction ramp
    let target = +c.controller[t.controller_index].force;
    if (t.reverser === 0 || !t.power.traction_ready() || t.air.p_tc > 0.3 * KGF || t.cab.doors_left || t.cab.doors_right) target = 0;
    if (t.traction_fraction < target) t.traction_fraction = Math.min(target, t.traction_fraction + c.ramp * dt);
    else t.traction_fraction = Math.max(target, t.traction_fraction - c.ramp * 3.0 * dt);
    // per-vehicle forces
    let grade = 0, resist = 0, starting = 0, limit = Infinity, behind = 0;
    c.vehicles.forEach((v, i) => {
      const m = t.masses[i];
      const front = advance(g, t.head, -behind).position;
      const profile = profileSpan(g, front, v.length_m);
      behind += v.length_m;
      grade += Resistance.grade_n(m, profile.grade_ratio);
      resist += Resistance.basic_n(v, m, t.speed_ms);
      resist += Units.specific_resistance_to_n(700 * profile.inverse_radius_m, m);
      starting += Resistance.starting_n(v, m, t.speed_ms);
      limit = Math.min(limit, profile.speed_limit_ms);
    });
    t.last.limit = limit;
    if (!isFinite(limit)) t.overspeed = false;
    else {
      const v = Math.abs(t.speed_ms);
      if (!t.overspeed && v > limit + 2.0 / 3.6) { t.overspeed = true; events.push({ type: "overspeed", train: t.id, speed_ms: v, limit_ms: limit }); }
      else if (t.overspeed && v <= limit) t.overspeed = false;
    }
    const traction = tractionForce(t, events) * t.reverser;
    const brake = t.air.brake_fraction() * c.brake_max();
    const active = traction + grade, dissipative = resist + brake;
    let nv;
    if (t.speed_ms === 0) {
      const holding = dissipative + starting;
      nv = Math.abs(active) <= holding ? 0 : ((active - Math.sign(active) * holding) / t.eff_mass) * dt;
    } else {
      const a = (active - Math.sign(t.speed_ms) * (dissipative + starting)) / t.eff_mass;
      nv = t.speed_ms + a * dt;
      if (nv * t.speed_ms < 0) nv = 0;
    }
    t.accel_ms2 = (nv - t.speed_ms) / dt;
    t.speed_ms = nv;
    Object.assign(t.last, { traction, brake, resistance: resist + starting, grade });
    move(t, g, t.speed_ms * dt, events);
  }

  function tractionForce(t, events) {
    const c = t.consist;
    if (t.traction_fraction <= 0) { t.slipping = false; return 0; }
    const power = +c.controller[t.controller_index].power;
    const byForce = t.traction_fraction * c.f_max();
    const byPower = (power * c.p_max()) / Math.max(Math.abs(t.speed_ms), 0.5);
    const wanted = Math.min(byForce, byPower);
    const lim = adhesionLimit(c.adhesion, c.adhesion_mass(t.load), t.speed_ms, t.rail);
    const was = t.slipping;
    t.slipping = wanted > lim;
    if (t.slipping && !was) events.push({ type: "wheel_slip", train: t.id });
    return t.slipping ? lim * 0.6 : wanted;
  }

  function move(t, g, dist, events) {
    if (dist === 0) return;
    let res;
    if (dist > 0) { res = advance(g, t.head, dist); t.head = res.position; }
    else { res = advance(g, t.rear(g), dist); t.head = advance(g, res.position, t.consist.length_m()).position; }
    t.odometer_m += res.moved_m;
    for (const e of res.events) events.push({ ...e, train: t.id });
    if (res.blocked) {
      if (Math.abs(t.speed_ms) > 0.83) events.push({ type: "buffer_stop_collision", train: t.id, speed_ms: t.speed_ms });
      t.speed_ms = 0; t.accel_ms2 = 0;
    }
  }

  // ---- core/world.gd + scenario_builder.gd
  function buildWorld(scenario, trackGraph, consistData, vehicles) {
    const graph = graphFromDict(trackGraph);
    for (const [id, st] of Object.entries(scenario.switches || {})) if (graph.nodes[id]) graph.nodes[id].state = st;
    const [hh, mm] = (scenario.start.time || "00:00").split(":").map(Number);
    const head = { segment: scenario.start.segment, offset: +scenario.start.offset_m, dir: scenario.start.direction >= 0 ? 1 : -1 };
    const train = makeTrain("player", consistFromDict(consistData, vehicles), head, +(scenario.passenger_load ?? 0.5));
    if (scenario.weather === "rain") train.rail = "wet";
    if (scenario.weather === "snow") train.rail = "ice";
    if (!scenario.start.cold_start) train.warm_start();
    const w = { graph, trains: { player: train }, tick: 0, dt: SIM_DT, start_time_s: hh * 3600 + mm * 60, events: [], command_log: [] };
    w.player = () => w.trains.player;
    w.clock_s = () => w.start_time_s + w.tick * w.dt;
    w.step = () => { w.events = []; for (const t of Object.values(w.trains)) trainStep(t, graph, w.dt, w.events); w.tick++; for (const e of w.events) e.tick = w.tick; return w.events; };
    w.set_switch = (id, diverging) => {
      for (const t of Object.values(w.trains)) if (t.occupied_nodes(graph).includes(id)) return false;
      const n = graph.nodes[id]; if (!n || n.kind !== "switch") return false;
      n.state = diverging ? "diverging" : "straight"; return true;
    };
    w.apply_command = (cmd) => {
      const reason = execute(w, cmd);
      if (reason === "") { w.command_log.push({ ...cmd, tick: w.tick }); return true; }
      w.events.push({ type: "command_rejected", command: cmd, reason, tick: w.tick });
      return false;
    };
    return w;
  }

  function execute(w, cmd) {
    if (cmd.type === "switch_set") return w.set_switch(cmd.node, !!cmd.diverging) ? "" : "стрілка замкнена під поїздом";
    const t = w.trains[cmd.train]; if (!t) return "немає такого поїзда";
    const c = t.consist;
    if (cmd.type === "cab_control") return t.operate(cmd.control, !!cmd.value);
    if (cmd.type === "reverser_set") {
      if (cmd.value < -1 || cmd.value > 1) return "немає такого положення реверсора";
      if (Math.abs(t.speed_ms) > 0.1) return "реверсор перемикається лише на стоянці";
      t.reverser = cmd.value; return "";
    }
    const bounded = (i, n) => (i >= 0 && i < n ? i : -1);
    let idx = -1;
    switch (cmd.type) {
      case "controller_step": idx = bounded(t.controller_index + cmd.delta, c.controller.length); break;
      case "controller_set": idx = c.controller_index_of(cmd.position); break;
      case "brake_valve_step": idx = bounded(t.valve_index + cmd.delta, c.valve.length); break;
      case "brake_valve_set": idx = c.valve_index_of(cmd.position); break;
      default: return "невідома команда";
    }
    if (idx < 0) return "немає такого положення";
    if (cmd.type.startsWith("controller")) t.controller_index = idx; else t.valve_index = idx;
    return "";
  }

  const Commands = {
    controller_step: (train, delta) => ({ type: "controller_step", train, delta }),
    controller_set: (train, position) => ({ type: "controller_set", train, position }),
    brake_valve_step: (train, delta) => ({ type: "brake_valve_step", train, delta }),
    brake_valve_set: (train, position) => ({ type: "brake_valve_set", train, position }),
    reverser_set: (train, value) => ({ type: "reverser_set", train, value }),
    switch_set: (node, diverging) => ({ type: "switch_set", node, diverging }),
    cab_control: (train, control, value) => ({ type: "cab_control", train, control, value }),
  };

  return { Units, SIM_DT, advance, buildWorld, Commands, graphFromDict };
});
