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
      id: d.id, length_m: +d.length_m, node_a: d.node_a, node_b: d.node_b,
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

  function makeTrain(id, consist, head, load) {
    const t = {
      id, consist, head, load, rail: "dry", speed_ms: 0, accel_ms2: 0, reverser: 0, controller_index: 0,
      valve_index: Math.max(0, consist.valve_index_of(consist.valve_default)),
      traction_fraction: 0, brake_demand: 0, slipping: false, odometer_m: 0,
      last: { traction: 0, brake: 0, resistance: 0, grade: 0, limit: Infinity },
    };
    t.masses = consist.vehicles.map((v) => v.mass_empty_kg + v.seats * load * consist.pax_kg);
    t.total_mass = t.masses.reduce((a, b) => a + b, 0);
    t.eff_mass = consist.vehicles.reduce((s, v, i) => s + t.masses[i] * (1.0 + v.rot), 0);
    t.rear = (g) => advance(g, t.head, -consist.length_m()).position;
    t.occupied_nodes = (g) => advance(g, t.head, -consist.length_m()).nodes_passed;
    return t;
  }

  function trainStep(t, g, dt, events) {
    const c = t.consist;
    // brake (simple model)
    const vp = c.valve[t.valve_index];
    if (vp.action === "release") t.brake_demand = Math.max(0, t.brake_demand - (vp.rate_per_s ?? 1.0) * dt);
    else if (vp.action === "apply") { const lim = vp.limit ?? 1.0; if (t.brake_demand < lim) t.brake_demand = Math.min(lim, t.brake_demand + (vp.rate_per_s ?? 0.2) * dt); }
    // traction fraction ramp
    let target = +c.controller[t.controller_index].force;
    if (t.reverser === 0 || t.brake_demand > 0.05) target = 0;
    if (t.traction_fraction < target) t.traction_fraction = Math.min(target, t.traction_fraction + c.ramp * dt);
    else t.traction_fraction = Math.max(target, t.traction_fraction - c.ramp * 3.0 * dt);
    // per-vehicle forces
    let grade = 0, resist = 0, starting = 0, limit = Infinity, behind = 0;
    c.vehicles.forEach((v, i) => {
      const m = t.masses[i];
      const center = advance(g, t.head, -(behind + v.length_m * 0.5)).position;
      behind += v.length_m;
      grade += Resistance.grade_n(m, g.grade_ratio_at(center));
      resist += Resistance.basic_n(v, m, t.speed_ms);
      resist += Resistance.curve_n(m, g.curve_radius_at(center));
      starting += Resistance.starting_n(v, m, t.speed_ms);
      limit = Math.min(limit, g.speed_limit_at(center));
    });
    t.last.limit = limit;
    const traction = tractionForce(t, events) * t.reverser;
    const brake = t.brake_demand * c.brake_max();
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
      const ok = execute(w, cmd);
      if (ok) w.command_log.push({ ...cmd, tick: w.tick }); else w.events.push({ type: "command_rejected", command: cmd, tick: w.tick });
      return ok;
    };
    return w;
  }

  function execute(w, cmd) {
    if (cmd.type === "switch_set") return w.set_switch(cmd.node, !!cmd.diverging);
    const t = w.trains[cmd.train]; if (!t) return false;
    const c = t.consist;
    const bounded = (i, n) => (i >= 0 && i < n ? i : -1);
    let idx = -1;
    switch (cmd.type) {
      case "controller_step": idx = bounded(t.controller_index + cmd.delta, c.controller.length); break;
      case "controller_set": idx = c.controller_index_of(cmd.position); break;
      case "brake_valve_step": idx = bounded(t.valve_index + cmd.delta, c.valve.length); break;
      case "brake_valve_set": idx = c.valve_index_of(cmd.position); break;
      case "reverser_set":
        if (cmd.value >= -1 && cmd.value <= 1 && Math.abs(t.speed_ms) <= 0.1) { t.reverser = cmd.value; return true; }
        return false;
    }
    if (idx < 0) return false;
    if (cmd.type.startsWith("controller")) t.controller_index = idx; else t.valve_index = idx;
    return true;
  }

  const Commands = {
    controller_step: (train, delta) => ({ type: "controller_step", train, delta }),
    controller_set: (train, position) => ({ type: "controller_set", train, position }),
    brake_valve_step: (train, delta) => ({ type: "brake_valve_step", train, delta }),
    brake_valve_set: (train, position) => ({ type: "brake_valve_set", train, position }),
    reverser_set: (train, value) => ({ type: "reverser_set", train, value }),
    switch_set: (node, diverging) => ({ type: "switch_set", node, diverging }),
  };

  return { Units, SIM_DT, advance, buildWorld, Commands, graphFromDict };
});
