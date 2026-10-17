class_name SettingsDialog
extends AcceptDialog
signal camera_changed


func _ready() -> void:
	title = tr("Налаштування")
	size = Vector2i(1000, 850)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 680)
	add_child(scroll)
	var view := PreferencesView.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.camera_changed.connect(func() -> void: camera_changed.emit())
	scroll.add_child(view)
