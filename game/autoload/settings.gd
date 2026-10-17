extends Node
## User preferences; audio gain changes do not recreate streams or toggle the window.

const PATH: String = "user://settings.cfg"
var config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	config.load(PATH)
	apply_audio()


func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return config.get_value(section, key, default)


func set_value(section: String, key: String, value: Variant) -> void:
	config.set_value(section, key, value)
	config.save(PATH)
	if section == "audio":
		apply_audio()


func apply_audio() -> void:
	for bus: String in ["Master", "TrainMix", "CabControls", "Announcer"]:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0:
			var gain: float = float(get_value("audio", bus, 0.8 if bus == "Master" else 1.0))
			AudioServer.set_bus_volume_db(index, -80.0 if gain <= 0.0 else linear_to_db(gain))
