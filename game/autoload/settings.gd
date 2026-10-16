extends Node
## Player settings persisted in user://settings.cfg.
## TODO: key bindings (T2.4), audio volumes, language, units display.

const PATH: String = "user://settings.cfg"

var config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	config.load(PATH)


func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return config.get_value(section, key, default)


func set_value(section: String, key: String, value: Variant) -> void:
	config.set_value(section, key, value)
	config.save(PATH)
