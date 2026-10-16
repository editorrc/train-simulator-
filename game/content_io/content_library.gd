class_name ContentLibrary
extends RefCounted
## Reads content packs (mods) from disk into typed tables. The base game is the mod in
## res://content/base. Path rules mirror tools/validate_data.py (SCHEMA_RULES); data was
## already validated by CI, here we only parse and index.
## Note for exports: add "*.json" to the export filter so these files ship in the .pck.

## type -> { id -> Dictionary }
var entries: Dictionary[StringName, Dictionary] = {}
## type -> { id -> mod id }
var origin: Dictionary[StringName, Dictionary] = {}
var mods: Array[Dictionary] = []
var errors: PackedStringArray = []


## Loads one mod directory (must contain mod.json). Returns false on fatal errors.
func load_mod(root: String) -> bool:
	var manifest: Dictionary = _read_json(root.path_join("mod.json"))
	if manifest.is_empty():
		errors.append("%s: missing or invalid mod.json" % root)
		return false
	var mod_id: StringName = StringName(str(manifest["id"]))
	mods.append(manifest)
	for series: String in _subdirs(root.path_join("rolling_stock")):
		var series_dir: String = root.path_join("rolling_stock").path_join(series)
		for file: String in _json_files(series_dir.path_join("vehicles")):
			_register(
				&"vehicle", _read_json(series_dir.path_join("vehicles").path_join(file)), mod_id
			)
		var consist: Dictionary = _read_json(series_dir.path_join("consist.json"))
		if not consist.is_empty():
			_register(&"consist", consist, mod_id)
	for route: String in _subdirs(root.path_join("routes")):
		var route_dir: String = root.path_join("routes").path_join(route)
		var index: Dictionary = _read_json(route_dir.path_join("route.json"))
		if index.is_empty():
			continue
		var bundle: Dictionary = {"route": index}
		for key: String in ["track_graph", "geometry", "stations", "signals", "timetable"]:
			if index.has(key):
				bundle[key] = _read_json(route_dir.path_join(str(index[key])))
		bundle["id"] = index["id"]
		_register(&"route", bundle, mod_id)
	for file: String in _json_files(root.path_join("scenarios")):
		_register(&"scenario", _read_json(root.path_join("scenarios").path_join(file)), mod_id)
	return true


## Loads every directory under `parent` that has a mod.json, "base" first.
func load_all(parent: String) -> void:
	var dirs: PackedStringArray = _subdirs(parent)
	var ordered: PackedStringArray = []
	if "base" in dirs:
		ordered.append("base")
	for d: String in dirs:
		if d != "base" and FileAccess.file_exists(parent.path_join(d).path_join("mod.json")):
			ordered.append(d)
	for d: String in ordered:
		load_mod(parent.path_join(d))


func get_entry(type: StringName, id: StringName) -> Dictionary:
	return (entries.get(type, {}) as Dictionary).get(id, {})


func ids_of(type: StringName) -> Array:
	return (entries.get(type, {}) as Dictionary).keys()


## All vehicles as id -> Dictionary (what ConsistSpec.from_dict expects).
func vehicles() -> Dictionary:
	var out: Dictionary = {}
	var table: Dictionary = entries.get(&"vehicle", {})
	for id: Variant in table:
		out[str(id)] = table[id]
	return out


## Builds a ready SimWorld for a scenario id, or null with errors appended.
func build_world(scenario_id: StringName, world_seed: int = 0) -> SimWorld:
	var scenario: Dictionary = get_entry(&"scenario", scenario_id)
	if scenario.is_empty():
		errors.append("unknown scenario %s" % scenario_id)
		return null
	var route: Dictionary = get_entry(&"route", StringName(str(scenario["route"])))
	var consist: Dictionary = get_entry(&"consist", StringName(str(scenario["consist"])))
	if route.is_empty() or consist.is_empty():
		errors.append("scenario %s: missing route or consist" % scenario_id)
		return null
	return ScenarioBuilder.build(scenario, route["track_graph"], consist, vehicles(), world_seed)


func _register(type: StringName, data: Dictionary, mod_id: StringName) -> void:
	if data.is_empty() or not data.has("id"):
		return
	var id: StringName = StringName(str(data["id"]))
	if not entries.has(type):
		entries[type] = {}
		origin[type] = {}
	var table: Dictionary = entries[type]
	if table.has(id) and not bool(data.get("override", false)):
		errors.append(
			"%s '%s' from mod '%s' already provided by '%s'" % [type, id, mod_id, origin[type][id]]
		)
		return
	table[id] = data
	(origin[type] as Dictionary)[id] = mod_id


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _subdirs(path: String) -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return PackedStringArray()
	var out: PackedStringArray = dir.get_directories()
	out.sort()
	return out


static func _json_files(path: String) -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return PackedStringArray()
	var out: PackedStringArray = []
	for f: String in dir.get_files():
		if f.ends_with(".json"):
			out.append(f)
	out.sort()
	return out
