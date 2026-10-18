class_name PreferencesView
extends VBoxContainer
## Immediate, persisted camera and audio preferences.

signal camera_changed


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var rows: VBoxContainer = self
	rows.add_child(PanoramaTheme.label("Звук", 24, PanoramaTheme.ACCENT))
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
	rows.add_child(PanoramaTheme.label("Інтерфейс", 24, PanoramaTheme.ACCENT))
	var logo := OptionButton.new()
	var variants: Array[String] = ["b", "a"]
	logo.add_item(tr("Логотип: вістря на лінії меню"))
	logo.add_item(tr("Логотип: великий у кутку"))
	logo.select(maxi(0, variants.find(str(Settings.get_value("ui", "logo_variant", "b")))))
	logo.item_selected.connect(
		func(index: int) -> void: Settings.set_value("ui", "logo_variant", variants[index])
	)
	rows.add_child(logo)
	rows.add_child(PanoramaTheme.label("Камера та зображення", 24, PanoramaTheme.ACCENT))
	_slider(rows, tr("Масштаб"), "camera", "zoom", 0.3, 3.0, 1.0)
	_slider(rows, tr("Поворот камери"), "camera", "yaw", -180, 180, 0)
	_slider(rows, tr("Нахил камери"), "camera", "pitch", 10, 70, 25)
	_slider(rows, tr("Затримка супроводу камери (с)"), "camera", "follow_s", 0.0, 0.5, 0.18)
	_slider(rows, tr("Хитання кузова"), "camera", "sway", 0, 1, 1.0)
	_slider(rows, tr("Роздільність 3D (масштаб)"), "visual", "render_scale", .75, 2.0, 1.0)
	_check(
		rows, tr("Автоматична деталізація коліс за масштабом"), "visual", "adaptive_detail", true
	)
	_check(rows, tr("Поворот камери за напрямком поїзда"), "camera", "follow_heading", false)
	_check(rows, tr("Нічне освітлення"), "visual", "night", false)
	_check(rows, tr("Автоматичний інформатор"), "audio", "auto_announcements", true)
	var antialiasing := OptionButton.new()
	var sample_counts: Array[int] = [0, 2, 4]
	antialiasing.add_item(tr("Згладжування: вимкнено"))
	antialiasing.add_item(tr("Згладжування: 2× (збалансовано)"))
	antialiasing.add_item(tr("Згладжування: 4×"))
	antialiasing.select(maxi(0, sample_counts.find(int(Settings.get_value("visual", "msaa", 2)))))
	antialiasing.item_selected.connect(
		func(index: int) -> void: Settings.set_value("visual", "msaa", sample_counts[index])
	)
	rows.add_child(antialiasing)
	var full := CheckBox.new()
	full.text = tr("Повний екран")
	full.button_pressed = get_tree().root.mode == DisplayServer.WINDOW_MODE_FULLSCREEN
	full.toggled.connect(
		func(on: bool) -> void:
			Settings.set_value("display", "fullscreen", on)
			get_tree().root.mode = (
				Window.MODE_FULLSCREEN
				if on
				else (
					Window.MODE_MAXIMIZED
					if str(Settings.get_value("display", "window_mode", "maximized")) == "maximized"
					else Window.MODE_WINDOWED
				)
			)
	)
	rows.add_child(full)
	var maximized := CheckBox.new()
	maximized.text = tr("Розгорнуте вікно")
	maximized.button_pressed = (get_tree().root.mode == DisplayServer.WINDOW_MODE_MAXIMIZED)
	maximized.toggled.connect(
		func(on: bool) -> void:
			Settings.set_value("display", "window_mode", "maximized" if on else "windowed")
			Settings.set_value("display", "fullscreen", false)
			full.set_pressed_no_signal(false)
			get_tree().root.mode = Window.MODE_MAXIMIZED if on else Window.MODE_WINDOWED
	)
	rows.add_child(maximized)
	var resolution := OptionButton.new()
	for dimensions: Vector2i in [
		Vector2i(1280, 800), Vector2i(1600, 1000), Vector2i(1920, 1080), Vector2i(2560, 1440)
	]:
		resolution.add_item("%d × %d" % [dimensions.x, dimensions.y])
	var current: Vector2i = get_tree().root.size
	var sizes: Array[Vector2i] = [
		Vector2i(1280, 800), Vector2i(1600, 1000), Vector2i(1920, 1080), Vector2i(2560, 1440)
	]
	if current in sizes:
		resolution.select(sizes.find(current))
	else:
		resolution.add_item(tr("Поточне: %d × %d") % [current.x, current.y])
		resolution.select(4)
		resolution.set_item_disabled(4, true)
	resolution.item_selected.connect(
		func(index: int) -> void:
			var dimensions: Array[Vector2i] = [
				Vector2i(1280, 800),
				Vector2i(1600, 1000),
				Vector2i(1920, 1080),
				Vector2i(2560, 1440)
			]
			get_tree().root.mode = Window.MODE_WINDOWED
			get_tree().root.size = dimensions[index]
			Settings.set_value("display", "width", dimensions[index].x)
			Settings.set_value("display", "height", dimensions[index].y)
			Settings.set_value("display", "fullscreen", false)
			Settings.set_value("display", "window_mode", "windowed")
			full.set_pressed_no_signal(false)
			maximized.set_pressed_no_signal(false)
	)
	rows.add_child(resolution)


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
	text.custom_minimum_size.x = 460
	row.add_child(text)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 100.0
	slider.value = float(Settings.get_value(section, key, default))
	slider.custom_minimum_size.x = 240
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := Label.new()
	value.custom_minimum_size.x = 80
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
