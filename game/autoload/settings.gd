extends Node
## User preferences; audio gain changes do not recreate streams or toggle the window.

const PATH: String = "user://settings.cfg"
var config: ConfigFile = ConfigFile.new()
var _save_delay: float = -1.0
var _display_poll: float = .5
var _desktop: bool = false


func _ready() -> void:
	config.load(PATH)
	apply_audio()
	_desktop = (
		DisplayServer.get_name().to_lower() != "headless"
		and not Engine.is_editor_hint()
		and not OS.has_feature("web")
	)
	if _desktop:
		_restore_display()


func _restore_display() -> void:
	var saved := Vector2i(
		int(get_value("display", "width", 0)), int(get_value("display", "height", 0))
	)
	var preference: String = str(
		get_value("display", "window_mode", "windowed" if saved.x > 0 else "maximized")
	)
	if preference == "windowed":
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(
			DisplayServer.window_get_current_screen()
		)
		var dimensions: Vector2i = saved.clamp(Vector2i(960, 600), usable.size)
		get_tree().root.mode = Window.MODE_WINDOWED
		get_tree().root.size = dimensions
		get_tree().root.position = usable.position + (usable.size - dimensions) / 2
	else:
		get_tree().root.mode = Window.MODE_MAXIMIZED
	if bool(get_value("display", "fullscreen", false)):
		get_tree().root.mode = Window.MODE_FULLSCREEN


func _capture_display() -> void:
	var mode: int = get_tree().root.mode
	var full: bool = (
		mode
		in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	)
	if mode == DisplayServer.WINDOW_MODE_MINIMIZED:
		return
	_remember_display("fullscreen", full)
	if not full:
		_remember_display(
			"window_mode",
			"maximized" if mode == DisplayServer.WINDOW_MODE_MAXIMIZED else "windowed"
		)
		if mode == DisplayServer.WINDOW_MODE_WINDOWED:
			var dimensions: Vector2i = get_tree().root.size
			_remember_display("width", dimensions.x)
			_remember_display("height", dimensions.y)


func _remember_display(key: String, value: Variant) -> void:
	if not config.has_section_key("display", key) or config.get_value("display", key) != value:
		set_value("display", key, value)


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
	if _desktop:
		_display_poll -= delta
		if _display_poll <= 0:
			_capture_display()
			_display_poll = .25
	if _save_delay < 0:
		return
	_save_delay -= delta
	if _save_delay <= 0:
		config.save(PATH)
		_save_delay = -1


func _exit_tree() -> void:
	if _desktop:
		_capture_display()
	config.save(PATH)
