extends Node
## Discovers and loads content packs. The base game is itself a mod ("base") in
## res://content/base. See docs/ARCHITECTURE.md §5 and docs/TASKS.md M8.
## TODO(T8.1): manifest parsing, api_version check, dependency ordering, user://mods.

const API_VERSION: String = "0.1.0"
const SEARCH_PATHS: PackedStringArray = ["res://content", "user://mods"]
