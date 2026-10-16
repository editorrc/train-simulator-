extends Node
## Discovers and loads content packs into ContentDB. The base game is itself a mod ("base")
## in res://content/base. See docs/ARCHITECTURE.md §5.
## TODO(T8.1): api_version check, dependency ordering, user://mods, enable/disable list.

const API_VERSION: String = "0.1.0"
const BUILTIN_ROOT: String = "res://content"
const USER_ROOT: String = "user://mods"


func _ready() -> void:
	ContentDB.library.load_all(BUILTIN_ROOT)
	for e: String in ContentDB.library.errors:
		push_error("ModLoader: " + e)
