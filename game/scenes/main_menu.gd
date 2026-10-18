extends Control
## Panorama: persistent navigation, live formation preview, real preferences and bindings.

const DRIVE_SCENE: String = "res://scenes/drive.tscn"
const PAGES: Array[String] = ["Огляд", "Рейс", "Поїзд", "Налаштування", "Керування"]
var bindings: ControlBindings
var _page: int = 0
var _body: VBoxContainer
var _nav: Array[Button] = []
var _preview: TrainPreview
var _title: Label
var _subtitle: Label
var _scenario_select: OptionButton
var _formation_buttons: Dictionary = {}
var _livery_buttons: Dictionary = {}
var _liveries: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PanoramaTheme.create()
	bindings = ControlBindings.new(
		ContentDB.get_entry(&"cab", &"er9m_cab"), Settings.get_value("controls", "bindings", {})
	)
	var bg := ColorRect.new()
	bg.color = PanoramaTheme.BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Studio light falling in from the top-right corner across the graphite page.
	var light := Gradient.new()
	light.offsets = PackedFloat32Array([0.0, .45, 1.0])
	light.colors = PackedColorArray([Color(1, 1, 1, .085), Color(1, 1, 1, .03), Color(1, 1, 1, 0)])
	var spill := GradientTexture2D.new()
	spill.gradient = light
	spill.fill = GradientTexture2D.FILL_RADIAL
	spill.fill_from = Vector2(.92, -.05)
	spill.fill_to = Vector2(.05, 1.0)
	var glow := TextureRect.new()
	glow.texture = spill
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	# Brand mark as a large, faint emblem: it starts left of the wordmark, fills the upper
	# left corner and runs over the line under the navigation.
	var watermark := TextureRect.new()
	watermark.texture = load("res://ui/artem_mark.svg") as Texture2D
	watermark.position = Vector2(40, -30)
	watermark.size = Vector2(378, 264)
	watermark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	watermark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	watermark.modulate = Color(1, 1, 1, .07)
	watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(watermark)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 104
	root.offset_right = -104
	root.offset_top = 32
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 24)
	add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", -2)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var project: Label = PanoramaTheme.label(
		"PROJECT A.R.T.E.M.", 14, Color(PanoramaTheme.MUTED, .6)
	)
	var spaced := FontVariation.new()
	spaced.base_font = project.get_theme_font("font")
	spaced.spacing_glyph = 3
	project.add_theme_font_override("font", spaced)
	brand.add_child(project)
	brand.add_child(PanoramaTheme.label("Train Emulator", 46))
	header.add_child(brand)
	for i: int in PAGES.size():
		var button: Button = PanoramaTheme.button(PAGES[i], _show_page.bind(i))
		button.add_theme_font_size_override("font_size", 26)
		_nav.append(button)
		header.add_child(button)
	root.add_child(header)
	root.add_child(HSeparator.new())
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	root.add_child(_body)
	_liveries = ContentDB.get_entry(&"liveries", &"er9m_liveries").get("liveries", [])
	if _liveries.is_empty():
		var consist: Dictionary = ContentDB.get_entry(&"consist", &"er9m_10")
		_liveries = ContentDB.get_entry(&"liveries", StringName(str(consist["liveries"]))).get(
			"liveries", []
		)
	_show_page(0)


func _show_page(index: int) -> void:
	_page = index
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_formation_buttons.clear()
	_livery_buttons.clear()
	_preview = null
	_scenario_select = null
	for i: int in _nav.size():
		var style: StyleBoxFlat = PanoramaTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
		style.set_corner_radius_all(0)
		style.set_border_width_all(0)
		style.border_width_bottom = 3 if i == index else 0
		style.border_color = PanoramaTheme.ACCENT
		_nav[i].add_theme_stylebox_override("normal", style)
		_nav[i].add_theme_stylebox_override("hover", style)
		_nav[i].add_theme_stylebox_override("pressed", style)
		_nav[i].add_theme_color_override(
			"font_color", PanoramaTheme.ACCENT if i == index else PanoramaTheme.MUTED
		)
	match index:
		0, 2:
			_overview(index == 2)
		1:
			_routes()
		3:
			_body.add_child(PanoramaTheme.label("Налаштування", 32))
			var scroll := ScrollContainer.new()
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			_body.add_child(scroll)
			var view := PreferencesView.new()
			view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(view)
		4:
			var view := ControlsView.new()
			view.bindings = bindings
			view.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_body.add_child(view)


func _overview(train_page: bool) -> void:
	_title = PanoramaTheme.label("Ваш електропоїзд" if train_page else "До рейсу", 96)
	_body.add_child(_title)
	_subtitle = PanoramaTheme.label("", 26, PanoramaTheme.MUTED)
	_body.add_child(_subtitle)
	_preview = TrainPreview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size.y = 180
	_body.add_child(_preview)
	# The main action sits bottom-right, right above the selector row.
	var action_row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_row.add_child(spacer)
	var start: Button = PanoramaTheme.button("Почати поїздку  →", _start, true)
	start.custom_minimum_size = Vector2(320, 76)
	start.add_theme_font_size_override("font_size", 26)
	action_row.add_child(start)
	_body.add_child(action_row)
	_body.add_child(HSeparator.new())
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 24)
	_body.add_child(dock)
	var route_column := VBoxContainer.new()
	route_column.custom_minimum_size.x = 420
	route_column.add_child(PanoramaTheme.label("Рейс", 20, PanoramaTheme.MUTED))
	_scenario_select = OptionButton.new()
	_scenario_select.custom_minimum_size = Vector2(420, PanoramaTheme.SELECTOR_HEIGHT)
	_scenario_select.add_theme_stylebox_override("normal", PanoramaTheme.selector_style(false))
	_scenario_select.add_theme_stylebox_override("hover", PanoramaTheme.selector_style(false, true))
	_scenario_select.size_flags_horizontal = Control.SIZE_FILL
	_scenario_select.clip_text = true
	var ids: Array = ContentDB.ids_of(&"scenario")
	ids.sort()
	for id: Variant in ids:
		var scenario: Dictionary = ContentDB.get_entry(&"scenario", id)
		_scenario_select.add_item(tr(str(scenario["name_uk"])))
		_scenario_select.set_item_metadata(_scenario_select.item_count - 1, str(id))
		if StringName(str(id)) == Session.scenario_id:
			_scenario_select.select(_scenario_select.item_count - 1)
	_scenario_select.item_selected.connect(
		func(i: int) -> void: _pick_scenario(StringName(str(_scenario_select.get_item_metadata(i))))
	)
	route_column.add_child(_scenario_select)
	dock.add_child(route_column)
	var formation := VBoxContainer.new()
	formation.add_child(PanoramaTheme.label("Вагонів", 20, PanoramaTheme.MUTED))
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 8)
	for count: int in [4, 6, 8, 10]:
		var button: Button = PanoramaTheme.button(str(count), _pick_formation.bind(count))
		button.custom_minimum_size = Vector2(72, PanoramaTheme.SELECTOR_HEIGHT)
		button.add_theme_font_size_override("font_size", 28)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", PanoramaTheme.selector_style(false))
		button.add_theme_stylebox_override("hover", PanoramaTheme.selector_style(false, true))
		button.add_theme_stylebox_override("pressed", PanoramaTheme.selector_style(true))
		button.add_theme_stylebox_override(
			"hover_pressed", PanoramaTheme.selector_style(true, true)
		)
		button.add_theme_color_override("font_pressed_color", PanoramaTheme.TEXT)
		_formation_buttons[count] = button
		count_row.add_child(button)
	formation.add_child(count_row)
	dock.add_child(formation)
	var livery := VBoxContainer.new()
	livery.add_child(PanoramaTheme.label("Забарвлення", 20, PanoramaTheme.MUTED))
	var paints := HBoxContainer.new()
	paints.add_theme_constant_override("separation", 8)
	for raw: Variant in _liveries:
		var data: Dictionary = raw
		var id := StringName(str(data["id"]))
		var swatch := LiverySwatch.new()
		swatch.livery = data
		swatch.pressed.connect(_pick_livery.bind(id))
		_livery_buttons[id] = swatch
		paints.add_child(swatch)
	livery.add_child(paints)
	dock.add_child(livery)
	_update_selection()
	if train_page:
		_body.add_child(
			PanoramaTheme.label(
				"Модель і характеристики наближені. Точні креслення та параметри ще перевіряються.",
				16,
				PanoramaTheme.MUTED
			)
		)


func _routes() -> void:
	_body.add_child(PanoramaTheme.label("Оберіть рейс", 48))
	_body.add_child(
		PanoramaTheme.label("Київська кільцева або навчальний полігон", 24, PanoramaTheme.MUTED)
	)
	var ids: Array = ContentDB.ids_of(&"scenario")
	ids.sort()
	for id: Variant in ids:
		var scenario: Dictionary = ContentDB.get_entry(&"scenario", id)
		var button: Button = PanoramaTheme.button(
			str(scenario["name_uk"]),
			_select_route.bind(StringName(str(id))),
			Session.scenario_id == StringName(str(id))
		)
		_body.add_child(button)
		var info: Label = PanoramaTheme.label(
			str(scenario.get("description_uk", "")), 18, PanoramaTheme.MUTED
		)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(info)
	_body.add_child(
		PanoramaTheme.label(
			"Кільце: справжні назви й порядок зупинок; геометрія та платформи поки ілюстративні.",
			18,
			PanoramaTheme.MUTED
		)
	)
	_body.add_child(PanoramaTheme.button("До огляду поїзда  →", _show_page.bind(0), true))


func _select_route(id: StringName) -> void:
	Session.scenario_id = id
	_show_page(1)


func _update_selection() -> void:
	if _preview == null:
		return
	var scenario: Dictionary = ContentDB.get_entry(&"scenario", Session.scenario_id)
	_subtitle.text = (
		tr("%s · ЕР9М · %d вагонів")
		% [
			(
				tr("Київська кільцева")
				if scenario["route"] == "kyiv_city_ring"
				else tr("Навчальний полігон")
			),
			Session.car_count
		]
	)
	for count: int in _formation_buttons:
		var button: Button = _formation_buttons[count]
		button.toggle_mode = true
		button.set_pressed_no_signal(count == Session.car_count)
	for id: StringName in _livery_buttons:
		var swatch: Button = _livery_buttons[id]
		swatch.set_pressed_no_signal(id == Session.livery_id)
	_preview.livery = _livery_by_id(Session.livery_id)


func _pick_scenario(id: StringName) -> void:
	Session.scenario_id = id
	_update_selection()


func _pick_formation(count: int) -> void:
	Session.car_count = count
	_update_selection()


func _pick_livery(id: StringName) -> void:
	Session.livery_id = id
	_update_selection()


func _livery_by_id(id: StringName) -> Dictionary:
	for raw: Variant in _liveries:
		var data: Dictionary = raw
		if StringName(str(data["id"])) == id:
			return data
	return _liveries[0] if not _liveries.is_empty() else {}


func _start() -> void:
	get_tree().change_scene_to_file(DRIVE_SCENE)
