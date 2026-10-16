extends Node
## Registry of all loaded content (base game + mods), keyed by type and id.
## Filled by ModLoader. Everything gameplay needs (rolling stock, routes, scenarios,
## signal aspects…) is looked up here, never loaded from hard-coded paths.
## TODO(T8.1): typed accessors per content type once loaders exist.

## type (StringName, e.g. &"vehicle", &"route") -> { id (StringName) -> Dictionary }
var _entries: Dictionary[StringName, Dictionary] = {}
## type -> { id -> mod id } to report which mod provided an entry.
var _origin: Dictionary[StringName, Dictionary] = {}


func register(
	type: StringName, id: StringName, data: Dictionary, mod_id: StringName, override: bool = false
) -> bool:
	if not _entries.has(type):
		_entries[type] = {}
		_origin[type] = {}
	var table: Dictionary = _entries[type]
	if table.has(id) and not override:
		push_error(
			(
				"ContentDB: %s '%s' from mod '%s' already provided by '%s' (set override: true to replace)"
				% [type, id, mod_id, _origin[type][id]]
			)
		)
		return false
	table[id] = data
	_origin[type][id] = mod_id
	return true


func get_entry(type: StringName, id: StringName) -> Dictionary:
	if not _entries.has(type):
		return {}
	return _entries[type].get(id, {})


func ids_of(type: StringName) -> Array:
	return _entries.get(type, {}).keys()


func clear() -> void:
	_entries.clear()
	_origin.clear()
