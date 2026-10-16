extends Node
## Registry of all loaded content (base game + mods). Thin wrapper over ContentLibrary so
## the same loading code is usable from headless tests without the scene tree.

var library: ContentLibrary = ContentLibrary.new()


func get_entry(type: StringName, id: StringName) -> Dictionary:
	return library.get_entry(type, id)


func ids_of(type: StringName) -> Array:
	return library.ids_of(type)


func build_world(scenario_id: StringName, world_seed: int = 0) -> SimWorld:
	return library.build_world(scenario_id, world_seed)
