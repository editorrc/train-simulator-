class_name ControlsView
extends VBoxContainer
## A real binding editor. Capture is scoped to this view; no input reaches the train.

signal changed
var bindings: ControlBindings
var _capture: String = ""
var _message: Label
var _buttons: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	add_child(PanoramaTheme.label("Керування", 32))
	var help: Label = PanoramaTheme.label(
		"Клавіші відповідають фізичному розташуванню. Esc — пауза або скасування вибору.",
		18,
		PanoramaTheme.MUTED
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	add_child(
		PanoramaTheme.label(
			(
				"Миша: ПКМ або Control + клік — огляд; колесо — масштаб. "
				+ "Тачпад: прокручування — огляд, щипок — масштаб."
			),
			16,
			PanoramaTheme.MUTED
		)
	)
	_message = PanoramaTheme.label(
		"Натисніть назву клавіші, щоб змінити її.", 18, PanoramaTheme.ACCENT
	)
	add_child(_message)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	for group: int in ControlBindings.GROUPS.size():
		rows.add_child(PanoramaTheme.label(ControlBindings.GROUPS[group], 24, PanoramaTheme.ACCENT))
		for action: Dictionary in bindings.actions:
			if int(action["group"]) != group:
				continue
			var row := HBoxContainer.new()
			var label: Label = PanoramaTheme.label(str(action["label"]))
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var id: String = str(action["id"])
			var button: Button = PanoramaTheme.button(bindings.label_for(id), _begin.bind(id))
			button.custom_minimum_size.x = 240
			_buttons[id] = button
			row.add_child(button)
			rows.add_child(row)
	add_child(PanoramaTheme.button("Відновити стандартні клавіші", _reset))


func _begin(id: String) -> void:
	_capture = id
	_message.text = tr("Натисніть нову клавішу або поєднання. Esc — скасувати.")
	_refresh()


func _input(event: InputEvent) -> void:
	if _capture.is_empty() or not is_visible_in_tree():
		return
	var key: InputEventKey = event as InputEventKey
	if key == null:
		return
	get_viewport().set_input_as_handled()
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		cancel_capture()
		return
	var code: int = ControlBindings.chord(key)
	if (code & KEY_CODE_MASK) in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return
	var conflict: String = bindings.conflict(code, _capture)
	if not bindings.assign(_capture, code):
		_message.text = (
			tr("Клавішу вже використовує: %s") % tr(conflict)
			if not conflict.is_empty()
			else tr("Це системне поєднання. Виберіть іншу клавішу.")
		)
		return
	Settings.set_value("controls", "bindings", bindings.overrides)
	_message.text = tr("Збережено")
	_capture = ""
	_refresh()
	changed.emit()


func cancel_capture() -> void:
	_capture = ""
	_refresh()
	_message.text = tr("Натисніть назву клавіші, щоб змінити її.")


func _refresh() -> void:
	for id: String in _buttons:
		(_buttons[id] as Button).text = (
			tr("Натисніть клавішу…") if id == _capture else bindings.label_for(id)
		)


func _reset() -> void:
	bindings.overrides.clear()
	Settings.set_value("controls", "bindings", {})
	cancel_capture()
	changed.emit()
