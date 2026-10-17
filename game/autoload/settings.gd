extends Node
## User preferences; audio gain changes do not recreate streams or toggle the window.

const PATH: String = "user://settings.cfg"
var config: ConfigFile = ConfigFile.new()
var _save_delay: float = -1.0


func _ready() -> void:
	config.load(PATH)
	apply_audio()
	if DisplayServer.get_name().to_lower() != "headless" and not Engine.is_editor_hint():
		var width: int = int(get_value("display", "width", 0))
		var height: int = int(get_value("display", "height", 0))
		if width > 0 and height > 0:
			DisplayServer.window_set_size(Vector2i(width, height))
		if bool(get_value("display", "fullscreen", false)):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return config.get_value(section, key, default)


func set_value(section: String, key: String, value: Variant) -> void:
	config.set_value(section, key, value)
	_save_delay = .35
	if section == "audio":
		apply_audio()


func apply_audio() -> void:
	for bus: String in ["Master", "TrainMix", "CabControls", "Announcer"]:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0:
			var gain: float = float(get_value("audio", bus, 0.8 if bus == "Master" else 1.0))
			AudioServer.set_bus_volume_db(index, -80.0 if gain <= 0.0 else linear_to_db(gain))


func _process(delta: float) -> void:
	if _save_delay < 0:
		return
	_save_delay -= delta
	if _save_delay <= 0:
		config.save(PATH)
		_save_delay = -1


func _exit_tree() -> void:
	config.save(PATH)
