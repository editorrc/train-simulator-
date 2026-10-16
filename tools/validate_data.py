#!/usr/bin/env python3
"""Validate game content (base game + mods) against JSON Schemas and cross-references.

Usage:
    python tools/validate_data.py                 # game/content/* and mods/*
    python tools/validate_data.py path/to/mod ... # specific mod roots

A "mod root" is a directory containing mod.json. Every *.json file inside must map to a
schema (see SCHEMA_RULES); unmapped files are errors, so new content types cannot slip in
without a schema. Exit code 1 on any problem.
"""
from __future__ import annotations

import fnmatch
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

REPO = Path(__file__).resolve().parent.parent
SCHEMAS = REPO / "schemas"

# (glob relative to the mod root, schema name). First match wins.
SCHEMA_RULES: list[tuple[str, str]] = [
    ("mod.json", "mod_manifest"),
    ("routes/*/route.json", "route"),
    ("routes/*/track_graph.json", "track_graph"),
    ("routes/*/geometry.json", "geometry"),
    ("routes/*/stations.json", "stations"),
    ("rolling_stock/*/vehicles/*.json", "vehicle"),
    ("rolling_stock/*/consist.json", "consist"),
    ("rolling_stock/*/cab.json", "cab"),
    ("rolling_stock/*/liveries.json", "liveries"),
    ("scenarios/*.json", "scenario"),
]


def load_validators() -> dict[str, Draft202012Validator]:
    out = {}
    for path in SCHEMAS.glob("*.schema.json"):
        schema = json.loads(path.read_text(encoding="utf-8"))
        Draft202012Validator.check_schema(schema)
        out[path.name.removesuffix(".schema.json")] = Draft202012Validator(schema)
    return out


def schema_for(rel: str) -> str | None:
    for pattern, name in SCHEMA_RULES:
        if fnmatch.fnmatchcase(rel, pattern) and rel.count("/") == pattern.count("/"):
            return name
    return None


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []

    def error(self, where: Path | str, msg: str) -> None:
        self.errors.append(f"{where}: {msg}")


def validate_root(root: Path, validators: dict, rep: Report, index: dict) -> None:
    for path in sorted(root.rglob("*.json")):
        rel = path.relative_to(root).as_posix()
        name = schema_for(rel)
        shown = path.relative_to(REPO) if path.is_relative_to(REPO) else path
        if name is None:
            rep.error(shown, "no schema mapped for this file (add a rule in SCHEMA_RULES)")
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            rep.error(shown, f"invalid JSON: {e}")
            continue
        for err in sorted(validators[name].iter_errors(data), key=lambda e: list(e.path)):
            loc = "/".join(str(p) for p in err.path) or "(root)"
            rep.error(shown, f"[{name}] {loc}: {err.message}")
        index.setdefault(name, []).append((shown, path, data))


def cross_check(index: dict, rep: Report) -> None:
    """Reference checks that JSON Schema cannot express."""
    vehicle_ids = {d.get("id") for _, _, d in index.get("vehicle", [])}
    consist_ids = {d.get("id") for _, _, d in index.get("consist", [])}
    route_ids = {d.get("id") for _, _, d in index.get("route", [])}

    cab_ids = {d.get("id") for _, _, d in index.get("cab", [])}
    for shown, _, c in index.get("consist", []):
        for v in c.get("vehicles", []):
            if v not in vehicle_ids:
                rep.error(shown, f"unknown vehicle '{v}'")
        livery_ids = {d.get("id") for _, _, d in index.get("liveries", [])}
        if "liveries" in c and c["liveries"] not in livery_ids:
            rep.error(shown, f"unknown liveries '{c['liveries']}'")
        if "cab" in c and c["cab"] not in cab_ids:
            rep.error(shown, f"unknown cab '{c['cab']}'")
        valve_ids = [p["id"] for p in c.get("brake_valve", {}).get("positions", [])]
        if c.get("brake_valve", {}).get("default") not in valve_ids:
            rep.error(shown, "brake_valve.default is not one of its positions")

    graphs: dict[Path, dict] = {}
    for shown, path, g in index.get("track_graph", []):
        graphs[path.parent] = g
        segs = {s["id"]: s for s in g.get("segments", [])}
        claimed: dict[str, str] = {}
        for n in g.get("nodes", []):
            ends = n.get("ends") or [n.get(k) for k in ("trunk", "straight", "diverging")]
            for e in ends:
                if not isinstance(e, dict):
                    continue
                seg = segs.get(e.get("segment"))
                key = f"{e.get('segment')}:{e.get('end')}"
                if seg is None:
                    rep.error(shown, f"node '{n['id']}' references unknown segment '{e.get('segment')}'")
                    continue
                declared = seg["node_a"] if e.get("end") == "a" else seg["node_b"]
                if declared != n["id"]:
                    rep.error(shown, f"{key} declares node '{declared}' but node '{n['id']}' claims it")
                if key in claimed:
                    rep.error(shown, f"{key} claimed by both '{claimed[key]}' and '{n['id']}'")
                claimed[key] = n["id"]
        for sid, s in segs.items():
            for side in ("a", "b"):
                if f"{sid}:{side}" not in claimed:
                    rep.error(shown, f"segment end {sid}:{side} is not connected to any node")
            for kind in ("curves", "speed_limits"):
                for r in s.get(kind, []):
                    if not (0 <= r["from_m"] <= r["to_m"] <= s["length_m"]):
                        rep.error(shown, f"{sid} {kind} range {r['from_m']}..{r['to_m']} outside 0..{s['length_m']}")
            for gp in s.get("grades", []):
                if gp["at_m"] > s["length_m"]:
                    rep.error(shown, f"{sid} grade point at {gp['at_m']} beyond length")

    for kind in ("stations", "geometry"):
        for shown, path, d in index.get(kind, []):
            g = graphs.get(path.parent)
            if g is None:
                rep.error(shown, "no track_graph.json next to this file")
                continue
            segs = {s["id"]: s for s in g["segments"]}
            if kind == "stations":
                for st in d.get("stations", []):
                    for p in st.get("platforms", []):
                        s = segs.get(p["segment"])
                        if s is None:
                            rep.error(shown, f"platform '{p['id']}' on unknown segment '{p['segment']}'")
                        elif not (0 <= p["from_m"] < p["to_m"] <= s["length_m"]):
                            rep.error(shown, f"platform '{p['id']}' range outside segment '{p['segment']}'")
            else:
                for pl in d.get("polylines", []):
                    if pl["segment"] not in segs:
                        rep.error(shown, f"polyline for unknown segment '{pl['segment']}'")

    for shown, path, sc in index.get("scenario", []):
        if sc.get("route") not in route_ids:
            rep.error(shown, f"unknown route '{sc.get('route')}'")
        if sc.get("consist") not in consist_ids:
            rep.error(shown, f"unknown consist '{sc.get('consist')}'")


def find_mod_roots(args: list[str]) -> list[Path]:
    if args:
        return [Path(a).resolve() for a in args]
    roots = [p.parent for p in (REPO / "game" / "content").glob("*/mod.json")]
    roots += [p.parent for p in (REPO / "mods").glob("*/mod.json")]
    return sorted(roots)


def main(argv: list[str]) -> int:
    validators = load_validators()
    rep = Report()
    index: dict = {}
    roots = find_mod_roots(argv)
    for root in roots:
        if not (root / "mod.json").is_file():
            rep.error(root, "not a mod root (mod.json missing)")
            continue
        validate_root(root, validators, rep, index)
    cross_check(index, rep)
    files = sum(len(v) for v in index.values())
    for e in rep.errors:
        print(f"ERROR {e}")
    print(f"{len(roots)} mod root(s), {files} file(s), {len(rep.errors)} error(s)")
    return 1 if rep.errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
