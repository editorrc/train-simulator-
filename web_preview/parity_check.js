#!/usr/bin/env node
// Checks that the JS port (sim.js) reproduces the trajectory recorded from the GDScript core.
// Usage: node web_preview/parity_check.js     (exit 1 on divergence)
"use strict";
const fs = require("fs");
const path = require("path");
const Sim = require("./sim.js");

const REPO = path.resolve(__dirname, "..");
const read = (p) => JSON.parse(fs.readFileSync(path.join(REPO, p), "utf8"));
const BASE = "game/content/base/";

const script = read("game/tests/parity/parity_script.json");
const reference = read("game/tests/parity/parity_reference.json").samples;
const scenario = read(`${BASE}scenarios/${script.scenario}.json`);
const route = read(`${BASE}routes/${scenario.route}/route.json`);
const graph = read(`${BASE}routes/${scenario.route}/${route.track_graph}`);
const series = fs.readdirSync(path.join(REPO, BASE, "rolling_stock"));
const vehicles = {};
let consist = null;
for (const s of series) {
  const dir = `${BASE}rolling_stock/${s}/`;
  for (const f of fs.readdirSync(path.join(REPO, dir, "vehicles"))) {
    const v = read(dir + "vehicles/" + f);
    vehicles[v.id] = v;
  }
  const c = read(dir + "consist.json");
  if (c.id === scenario.consist) consist = c;
}

const world = Sim.buildWorld(scenario, graph, consist, vehicles);
const byTick = {};
for (const c of script.commands) (byTick[c.tick] = byTick[c.tick] || []).push(c.cmd);
const samples = [];
for (let i = 0; i < script.ticks; i++) {
  for (const cmd of byTick[i] || []) world.apply_command(cmd);
  const events = world.step();
  const t = world.player();
  if (world.tick % script.sample_every === 0 || events.length) {
    samples.push({ tick: world.tick, speed_ms: t.speed_ms, odometer_m: t.odometer_m, segment: t.head.segment, events: events.map((e) => e.type) });
  }
}

let failures = 0;
if (samples.length !== reference.length) {
  console.error(`sample count differs: js ${samples.length} vs godot ${reference.length}`);
  failures++;
}
for (let i = 0; i < Math.min(samples.length, reference.length); i++) {
  const a = samples[i], e = reference[i];
  const bad = a.tick !== e.tick || a.segment !== e.segment ||
    Math.abs(a.speed_ms - e.speed_ms) > 1e-9 || Math.abs(a.odometer_m - e.odometer_m) > 1e-6 ||
    a.events.join() !== e.events.join();
  if (bad) {
    console.error(`diverged at sample ${i}:\n  js    ${JSON.stringify(a)}\n  godot ${JSON.stringify({ tick: e.tick, speed_ms: e.speed_ms, odometer_m: e.odometer_m, segment: e.segment, events: e.events })}`);
    failures++;
    break;
  }
}
if (failures) process.exit(1);
console.log(`parity ok: ${samples.length} samples, final speed ${samples.at(-1).speed_ms.toFixed(6)} m/s, odometer ${samples.at(-1).odometer_m.toFixed(3)} m`);
