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
var settings_dialog: SettingsDialog
var pose := RenderPose.new()
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
	var chosen: Dictionary = ContentDB.get_entry(&"scenario", Session.scenario_id)
	var bundle: Dictionary = ContentDB.get_entry(&"route", StringName(str(chosen["route"])))
	var formation: Dictionary = (
		ContentDB.get_entry(&"consist", StringName(str(chosen["consist"]))).duplicate(true)
	)
	var cars: Array = ["er9m_head"]
	for i: int in Session.car_count - 2:
		cars.append("er9m_motor" if i % 2 == 0 else "er9m_trailer")
	cars.append("er9m_head")
	formation["vehicles"] = cars
	world = ScenarioBuilder.build(
		chosen, bundle["track_graph"], formation, ContentDB.library.vehicles()
	)
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
	_route_label.position = Vector2(600, 60)
	_route_label.add_theme_font_size_override("font_size", 23)
	add_child(_route_label)
	_caption = Label.new()
	_caption.position = Vector2(600, 100)
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
	get_window().focus_exited.connect(
		func() -> void:
			desk.release_holds()
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
	t.position = Vector2(8, 8)
	t.size = Vector2(560, 300)
	t.set_collapsed(true)
	var m: FloatingPanel = _panel("map")
	m.collapsed = false
	m.position = Vector2(v.x - 648, 8)
	m.size = Vector2(640, 390)
	var pr: FloatingPanel = _panel("procedure")
	pr.collapsed = false
	pr.position = Vector2(8, 44)
	pr.size = Vector2(440, 340)
	var scenario: Dictionary = ContentDB.get_entry(&"scenario", Session.scenario_id)
	if not bool((scenario["start"] as Dictionary).get("cold_start", false)):
		pr.set_collapsed(true)
	var lg: FloatingPanel = _panel("log")
	lg.collapsed = false
	lg.position = Vector2(v.x - 440, 166)
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
	_status.position.x = (size.x - _status.size.x) * 0.5


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
	if key == null or world == null:
		return
	if desk.handle_key(key):
		get_viewport().set_input_as_handled()
		return
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			desk.release_holds()
			SimClock.step.disconnect(_on_sim_step)
			get_tree().change_scene_to_file(MENU_SCENE)
		KEY_P:
			_paused = not _paused
			SimClock.set_paused(_paused)
		KEY_I:
			announcer.repeat()
		KEY_F3:
			desk.release_holds()
			settings_dialog.popup_centered()
		KEY_F4:
			_expand_panel("desk")
		KEY_F5:
			_expand_panel("map")
		KEY_F8:
			(side as ExteriorView).platform_view()
		KEY_F:
			side.snap_camera()
		KEY_F2:
			side.next_preset()
		KEY_BRACKETLEFT:
			side.adjust(-5.0, 0.0)
		KEY_BRACKETRIGHT:
			side.adjust(5.0, 0.0)
		KEY_PAGEUP:
			side.adjust(0.0, 4.0)
		KEY_PAGEDOWN:
			side.adjust(0.0, -4.0)
		KEY_EQUAL, KEY_KP_ADD:
			side.zoom_by(1.2)
		KEY_MINUS, KEY_KP_SUBTRACT:
			side.zoom_by(1.0 / 1.2)
		KEY_1:
			_toggle_switch(&"sw_b_west")
		KEY_2:
			_toggle_switch(&"sw_b_east")
		KEY_F1:
			_panels_visible = not _panels_visible
			for p: FloatingPanel in panels:
				p.visible = _panels_visible
		KEY_F10:
			UiLayout.clear()
			_default_layout()


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
		move_child(panel, get_child_count() - 1)
	panel._layout_content()


func _over_panel(at: Vector2) -> bool:
	if settings_dialog != null and settings_dialog.visible:
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
