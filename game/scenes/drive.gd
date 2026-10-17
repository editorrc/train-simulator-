extends Control
## Drive scene: the fixed side view of the railway, and floating panels over it (driver's
## desk, telemetry, route map, startup checklist, event log). Game-layer glue only:
## builds the world, steps it from SimClock, turns input into Commands.

const MENU_SCENE: String = "res://scenes/main_menu.tscn"

var world: SimWorld
var side: RailView
var desk: CabPanel
var minimap: Minimap
var telemetry: TelemetryView
var procedure: ProcedureView
var log_view: EventLogView
var announcer: StationAnnouncer
var audio: TrainAudio
var panels: Array[FloatingPanel] = []
var bindings: ControlBindings
var controls_dialog: AcceptDialog
var settings_dialog: SettingsDialog
var pose := RenderPose.new()
var _pause_overlay: Control
var _toolbar: HBoxContainer
var _dialog_was_paused: bool = false
var _route_label: Label
var _caption: Label
var _status: Label
var _drag_button: int = MOUSE_BUTTON_NONE
var _orbit_drag: bool = false
var _pan_drag: bool = false
var _paused: bool = false
var _expanded: Dictionary = {}
var _panels_visible: bool = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PanoramaTheme.create()
	bindings = ControlBindings.new(
		ContentDB.get_entry(&"cab", &"er9m_cab"), Settings.get_value("controls", "bindings", {})
	)
	world = Session.build_world()
	if world == null:
		push_error("drive: cannot build scenario %s" % Session.scenario_id)
		return
	var scenario: Dictionary = ContentDB.get_entry(&"scenario", Session.scenario_id)
	var route: Dictionary = ContentDB.get_entry(&"route", StringName(str(scenario["route"])))
	var consist: Dictionary = ContentDB.get_entry(&"consist", StringName(str(scenario["consist"])))
	var cab_def: Dictionary = ContentDB.get_entry(&"cab", StringName(str(consist.get("cab", ""))))
	var livery: Dictionary = _livery(consist)

	pose.reset(world.player())
	side = ExteriorView.new()
	side.pose = pose
	side.set_anchors_preset(Control.PRESET_FULL_RECT)
	side.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(side)
	side.setup(world, route["stations"], livery, str(consist.get("number", "")))

	desk = CabPanel.new()
	desk.world = world
	desk.bindings = bindings
	desk.cab_def = cab_def
	desk.command.connect(_command)
	minimap = Minimap.new()
	minimap.world = world
	minimap.geometry = RouteGeometry.from_dict(route["geometry"])
	minimap.stations = route["stations"]
	minimap.switch_clicked.connect(_toggle_switch)
	telemetry = TelemetryView.new()
	telemetry.world = world
	procedure = ProcedureView.new()
	procedure.world = world
	procedure.steps = cab_def.get("startup_checklist", [])
	log_view = EventLogView.new()

	_add_panel("desk", "Пульт машиніста · ЕР9М", desk, 0.96)
	_add_panel("telemetry", "Телеметрія і графіки", telemetry, 0.55)
	_add_panel("map", "Схема колії", minimap, 0.6)
	_add_panel("procedure", "Підготовка до роботи", procedure, 0.78)
	_add_panel("log", "Журнал подій", log_view, 0.6)
	if not UiLayout.restore(panels, get_viewport_rect().size):
		_default_layout()
	side.snap_camera.call_deferred()

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color("dfe8e3"))
	_status.position = Vector2(0, 6)
	_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	add_child(_status)

	audio = TrainAudio.new()
	audio.world = world
	add_child(audio)

	announcer = StationAnnouncer.new()
	announcer.world = world
	announcer.stations = route["stations"]
	announcer.enabled_route = str(scenario["route"]) == "kyiv_city_ring"
	add_child(announcer)
	_route_label = Label.new()
	_route_label.position = Vector2(36, 104)
	_route_label.add_theme_font_size_override("font_size", 23)
	add_child(_route_label)
	_caption = Label.new()
	_caption.position = Vector2(36, 140)
	_caption.add_theme_font_size_override("font_size", 21)
	_caption.add_theme_color_override("font_color", Color("ffe5a2"))
	_caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_caption)
	announcer.caption.connect(func(text: String) -> void: _caption.text = text)
	desk.announcement_requested.connect(announcer.repeat)
	settings_dialog = SettingsDialog.new()
	add_child(settings_dialog)
	controls_dialog = AcceptDialog.new()
	controls_dialog.title = tr("Керування")
	controls_dialog.size = Vector2i(1200, 860)
	var controls := ControlsView.new()
	controls.bindings = bindings
	controls.custom_minimum_size = Vector2(1100, 740)
	controls_dialog.add_child(controls)
	add_child(controls_dialog)
	for dialog: AcceptDialog in [settings_dialog, controls_dialog]:
		dialog.visibility_changed.connect(
			func() -> void:
				if not dialog.visible:
					_set_paused(_dialog_was_paused)
		)
	_build_navigation()
	get_window().focus_exited.connect(
		func() -> void:
			_release_controls()
			_orbit_drag = false
			_pan_drag = false
	)
	SimClock.set_paused(false)
	SimClock.set_time_scale(1.0)
	SimClock.step.connect(_on_sim_step)
	log_view.push("Сценарій: %s" % scenario["name_uk"])
	if bool((scenario["start"] as Dictionary).get("cold_start", false)):
		log_view.push("Поїзд холодний. Дивіться «Підготовка до роботи».", "warn")


func _livery(consist: Dictionary) -> Dictionary:
	var set_d: Dictionary = ContentDB.get_entry(
		&"liveries", StringName(str(consist.get("liveries", "")))
	)
	var list: Array = set_d.get("liveries", [])
	for l: Variant in list:
		if StringName(str((l as Dictionary)["id"])) == Session.livery_id:
			return l
	return list[0] if not list.is_empty() else {}


func _add_panel(id: String, title: String, content: Control, opacity: float) -> void:
	var p := FloatingPanel.new(id, title, content)
	p.opacity = opacity
	p.layout_changed.connect(func(_p: FloatingPanel) -> void: UiLayout.save(panels))
	add_child(p)
	panels.append(p)


func _panel(id: String) -> FloatingPanel:
	for p: FloatingPanel in panels:
		if p.panel_id == id:
			return p
	return null


## Desk centred at the bottom, charts collapsed in the top-left corner, map top-right.
func _default_layout() -> void:
	var v: Vector2 = get_viewport_rect().size
	var desk_w: float = minf(1560.0, v.x - 40.0)
	var desk_h: float = minf(360.0, v.y * 0.38)
	var d: FloatingPanel = _panel("desk")
	d.collapsed = false
	d.position = Vector2((v.x - desk_w) * 0.5, v.y - desk_h - 8)
	d.size = Vector2(desk_w, desk_h)
	var t: FloatingPanel = _panel("telemetry")
	t.collapsed = false
	t.position = Vector2(8, 184)
	t.size = Vector2(560, 300)
	t.set_collapsed(true)
	var m: FloatingPanel = _panel("map")
	m.collapsed = false
	m.position = Vector2(v.x - 648, 184)
	m.size = Vector2(640, 390)
	var pr: FloatingPanel = _panel("procedure")
	pr.collapsed = false
	pr.position = Vector2(8, 220)
	pr.size = Vector2(440, 340)
	var scenario: Dictionary = ContentDB.get_entry(&"scenario", Session.scenario_id)
	if not bool((scenario["start"] as Dictionary).get("cold_start", false)):
		pr.set_collapsed(true)
	var lg: FloatingPanel = _panel("log")
	lg.collapsed = false
	lg.position = Vector2(v.x - 440, 242)
	lg.size = Vector2(432, 190)
	lg.set_collapsed(true)
	for p: FloatingPanel in panels:
		p._layout_content()


func _on_sim_step(_dt: float, _tick: int) -> void:
	for e: Dictionary in world.step():
		EventBus.sim_event.emit(e)
		_log_event(e)
	pose.capture(world.player())


func _process(_delta: float) -> void:
	if world == null:
		return
	audio.listener_ch = side.cam_ch
	audio.paused = _paused
	audio.announcing = announcer.is_announcing()
	announcer.paused = _paused
	_route_label.text = announcer.route_text()
	var flags: PackedStringArray = []
	if _paused:
		flags.append("ПАУЗА")

	var clock: float = world.clock_s()
	_status.text = (
		"%02d:%02d:%02d   %s"
		% [int(clock / 3600.0) % 24, int(clock / 60.0) % 60, int(clock) % 60, "  ".join(flags)]
	)
	_status.position = Vector2(size.x - _status.size.x - 36, 104)


func _command(cmd: Dictionary) -> void:
	var before: Dictionary = audio.control_snapshot()
	if world.apply_command(cmd):
		audio.play_command(cmd, before)
		if (
			str(cmd.get("control", "")) in ["doors_left", "doors_right"]
			and not bool(cmd.get("value", true))
		):
			if bool((before["cab"] as Dictionary).get(str(cmd["control"]), false)):
				announcer.enqueue("doors_closing")
	else:
		var reason: String = (
			str(world.events.back().get("reason", "")) if not world.events.is_empty() else ""
		)
		log_view.push("Відхилено: %s" % reason, "warn")


func _toggle_switch(node_id: StringName) -> void:
	var n: TrackNode = world.graph.get_node_by_id(node_id)
	var to_div: bool = n.state == TrackNode.SwitchState.STRAIGHT
	if world.apply_command(Commands.switch_set(node_id, to_div)):
		log_view.push("Стрілка %s → %s" % [node_id, "на бічну колію" if to_div else "прямо"])
	else:
		log_view.push("Стрілка %s замкнена під поїздом" % node_id, "warn")


func _log_event(e: Dictionary) -> void:
	match e["type"]:
		&"wheel_slip":
			log_view.push("Боксування! Зменште позицію контролера", "warn")
		&"buffer_stop_collision":
			log_view.push(
				"Зіткнення з упором на %.0f км/год" % Units.ms_to_kmh(absf(float(e["speed_ms"]))),
				"bad"
			)
		&"end_of_track":
			log_view.push("Кінець колії", "warn")
		&"switch_trailed":
			log_view.push("Взріз стрілки %s — порушення ПТЕ" % e["node"], "bad")
		&"overspeed":
			log_view.push(
				(
					"Перевищення: %.0f при обмеженні %.0f км/год"
					% [Units.ms_to_kmh(float(e["speed_ms"])), Units.ms_to_kmh(float(e["limit_ms"]))]
				),
				"bad"
			)
		&"pantograph_lowered_under_load":
			log_view.push("Струмоприймач опущено під навантаженням — спрацював захист", "bad")
		&"main_breaker_tripped":
			log_view.push("ГВ вимкнувся (немає напруги або кола керування)", "warn")


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or world == null or settings_dialog.visible or controls_dialog.visible:
		return
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		_set_paused(not _paused)
		get_viewport().set_input_as_handled()
		return
	for edge: Dictionary in bindings.consume(key):
		var id: String = edge["id"]
		if id == "pause" and edge["pressed"]:
			_set_paused(not _paused)
		elif not _paused:
			if not desk.apply_action(id, bool(edge["pressed"])) and edge["pressed"]:
				_ui_action(id)
		get_viewport().set_input_as_handled()


func _release_controls() -> void:
	bindings.release_all()
	desk.release_holds()
	_orbit_drag = false
	_pan_drag = false


func _set_paused(value: bool) -> void:
	_release_controls()
	_paused = value
	SimClock.set_paused(value)
	_pause_overlay.visible = value
	if value:
		_pause_overlay.move_to_front()


func _open_dialog(dialog: AcceptDialog) -> void:
	_dialog_was_paused = _paused
	_set_paused(true)
	_pause_overlay.hide()
	dialog.popup_centered_clamped(Vector2i.ZERO, .94)


func _ui_action(id: String) -> void:
	match id:
		"camera":
			side.next_preset()
		"platform":
			(side as ExteriorView).platform_view()
		"desk":
			_expand_panel("desk")
		"map":
			_expand_panel("map")
		"settings":
			_open_dialog(settings_dialog)
		"controls":
			_open_dialog(controls_dialog)
		"announcer":
			announcer.repeat()
		"panels":
			_panels_visible = not _panels_visible
			for panel: FloatingPanel in panels:
				panel.visible = _panels_visible
		"layout":
			_expanded.clear()
			UiLayout.clear()
			_default_layout()
		"zoom_in":
			side.zoom_by(1.2)
		"zoom_out":
			side.zoom_by(1.0 / 1.2)


func _build_navigation() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.position = Vector2(32, 20)
	_toolbar.add_theme_constant_override("separation", 8)
	add_child(_toolbar)
	var menu: Button = PanoramaTheme.button("Меню", func() -> void: _set_paused(true))
	menu.focus_mode = Control.FOCUS_NONE
	_toolbar.add_child(menu)
	for entry: Array in [
		["Камера", "camera"],
		["З платформи", "platform"],
		["Пульт", "desk"],
		["Схема колій", "map"],
		["Налаштування", "settings"],
		["Керування", "controls"]
	]:
		var button: Button = PanoramaTheme.button(str(entry[0]), _ui_action.bind(str(entry[1])))
		button.focus_mode = Control.FOCUS_NONE
		_toolbar.add_child(button)
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_overlay)
	var shade := ColorRect.new()
	shade.color = Color(.08, .08, .085, .96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size.x = 560
	rows.add_theme_constant_override("separation", 16)
	center.add_child(rows)
	rows.add_child(PanoramaTheme.label("Рейс на паузі", 48))
	rows.add_child(
		PanoramaTheme.button("Продовжити поїздку", func() -> void: _set_paused(false), true)
	)
	rows.add_child(PanoramaTheme.button("Налаштування", _open_dialog.bind(settings_dialog)))
	rows.add_child(PanoramaTheme.button("Керування", _open_dialog.bind(controls_dialog)))
	rows.add_child(
		PanoramaTheme.label(
			"Повернення до головного меню завершить поточний рейс.", 16, PanoramaTheme.MUTED
		)
	)
	rows.add_child(PanoramaTheme.button("Завершити рейс і вийти в меню", _leave))
	_pause_overlay.hide()


func _leave() -> void:
	_release_controls()
	UiLayout.save(panels)
	get_tree().change_scene_to_file(MENU_SCENE)


func _exit_tree() -> void:
	if SimClock.step.is_connected(_on_sim_step):
		SimClock.step.disconnect(_on_sim_step)
	SimClock.set_paused(true)


func _expand_panel(id: String) -> void:
	var panel: FloatingPanel = _panel(id)
	if _expanded.has(id):
		var saved: Rect2 = _expanded[id]
		panel.position = saved.position
		panel.size = saved.size
		panel.opacity = 0.96 if id == "desk" else 0.6
		_expanded.erase(id)
	else:
		_expanded[id] = Rect2(panel.position, panel.size)
		panel.set_collapsed(false)
		panel.position = size * 0.05
		panel.size = size * 0.9
		panel.opacity = 1.0
		move_child(panel, _toolbar.get_index())
	panel._layout_content()


func _over_panel(at: Vector2) -> bool:
	if (
		_paused
		or (settings_dialog != null and settings_dialog.visible)
		or (controls_dialog != null and controls_dialog.visible)
	):
		return true
	if _toolbar != null and _toolbar.get_global_rect().has_point(at):
		return true
	for panel: FloatingPanel in panels:
		if panel.visible and panel.get_global_rect().has_point(at):
			return true
	return false


func _input(event: InputEvent) -> void:
	if side == null:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		var orbit_button: bool = (
			mb.button_index == MOUSE_BUTTON_RIGHT
			or (mb.button_index == MOUSE_BUTTON_LEFT and mb.ctrl_pressed)
		)
		if not mb.pressed:
			if mb.button_index == _drag_button:
				_orbit_drag = false
				_pan_drag = false
				_drag_button = MOUSE_BUTTON_NONE
			if mb.button_index == MOUSE_BUTTON_MIDDLE or orbit_button:
				_pan_drag = false
		elif not _over_panel(mb.position):
			if orbit_button:
				_drag_button = mb.button_index
				_orbit_drag = not mb.shift_pressed
				_pan_drag = mb.shift_pressed
			elif mb.button_index == MOUSE_BUTTON_MIDDLE:
				_pan_drag = true
			elif mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				side.zoom_by(1.10 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.10)
			get_viewport().set_input_as_handled()
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if _orbit_drag:
			side.adjust(-motion.relative.x * .22, -motion.relative.y * .18)
			get_viewport().set_input_as_handled()
		elif _pan_drag:
			side.pan_px(motion.relative.x)
			get_viewport().set_input_as_handled()
	var pan: InputEventPanGesture = event as InputEventPanGesture
	if pan != null and not _over_panel(pan.position):
		side.adjust(-pan.delta.x * 3.0, -pan.delta.y * 2.0)
		get_viewport().set_input_as_handled()
	var magnify: InputEventMagnifyGesture = event as InputEventMagnifyGesture
	if magnify != null and not _over_panel(magnify.position):
		side.zoom_by(magnify.factor)
		get_viewport().set_input_as_handled()
