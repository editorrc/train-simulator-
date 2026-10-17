class_name SettingsDialog
extends AcceptDialog
## Immediate, persisted camera and audio preferences.

signal camera_changed


func _ready() -> void:
	title = tr("Налаштування · F3")
	size = Vector2i(660, 680)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	add_child(rows)
	for bus: String in ["Master", "TrainMix", "CabControls", "Announcer"]:
		_slider(
			rows,
			tr(
				{
					"Master": "Загальна гучність",
					"TrainMix": "Звуки поїзда",
					"CabControls": "Тумблери та важелі",
					"Announcer": "Інформатор"
				}[bus]
			),
			"audio",
			bus,
			0.0,
			1.0,
			0.8 if bus == "Master" else 1.0
		)
	_slider(rows, tr("Масштаб"), "camera", "zoom", 0.3, 3.0, 1.0)
	_slider(rows, tr("Поворот камери"), "camera", "yaw", -60, 60, 0)
	_slider(rows, tr("Нахил камери"), "camera", "pitch", 10, 70, 25)
	_slider(rows, tr("Затримка супроводу камери (с)"), "camera", "follow_s", 0.0, 0.5, 0.18)
	_slider(rows, tr("Хитання кузова"), "camera", "sway", 0, 1, 0.2)
	_check(rows, tr("Нічне освітлення"), "visual", "night", false)
	_check(rows, tr("Автоматичний інформатор"), "audio", "auto_announcements", true)
	var full := CheckBox.new()
	full.text = tr("Повний екран")
	full.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	full.toggled.connect(
		func(on: bool) -> void:
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
			)
	)
	rows.add_child(full)


func _check(
	rows: VBoxContainer, label: String, section: String, key: String, default: bool
) -> void:
	var b := CheckBox.new()
	b.text = label
	b.button_pressed = bool(Settings.get_value(section, key, default))
	b.toggled.connect(
		func(value: bool) -> void:
			Settings.set_value(section, key, value)
			camera_changed.emit()
	)
	rows.add_child(b)


func _slider(
	rows: VBoxContainer,
	label: String,
	section: String,
	key: String,
	low: float,
	high: float,
	default: float
) -> void:
	var row := HBoxContainer.new()
	var text := Label.new()
	text.text = label
	text.custom_minimum_size.x = 330
	row.add_child(text)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 100.0
	slider.value = float(Settings.get_value(section, key, default))
	slider.custom_minimum_size.x = 180
	var value := Label.new()
	value.text = "%.2f" % slider.value
	slider.value_changed.connect(
		func(v: float) -> void:
			value.text = "%.2f" % v
			Settings.set_value(section, key, v)
			camera_changed.emit()
	)
	row.add_child(slider)
	row.add_child(value)
	rows.add_child(row)
