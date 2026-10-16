extends Control
## Drive scene: the fixed side view of the railway, and floating panels over it (driver's
## desk, telemetry, route map, startup checklist, event log). Game-layer glue only:
## builds the world, steps it from SimClock, turns input into Commands.

const MENU_SCENE: String = "res://scenes/main_menu.tscn"

var world: SimWorld
var side: SideView
var desk: CabPanel
var minimap: Minimap
var telemetry: TelemetryView
var procedure: ProcedureView
var log_view: EventLogView
var audio: TrainAudio
var panels: Array[FloatingPanel] = []
var _status: Label
var _paused: bool = false
var _time_scale: float = 1.0
var _panels_visible: bool = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	world = ContentDB.build_world(Session.scenario_id)
	if world == null:
		push_error("drive: cannot build scenario %s" % Session.scenario_id)
		return
	var scenario: Dictionary = ContentDB.get_entry(&"scenario", Session.scenario_id)
	var route: Dictionary = ContentDB.get_entry(&"route", StringName(str(scenario["route"])))
	var consist: Dictionary = ContentDB.get_entry(&"consist", StringName(str(scenario["consist"])))
	var cab_def: Dictionary = ContentDB.get_entry(&"cab", StringName(str(consist.get("cab", ""))))
	var livery: Dictionary = _livery(consist)

	side = SideView.new()
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
	m.position = Vector2(v.x - 528, 8)
	m.size = Vector2(520, 150)
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


func _process(_delta: float) -> void:
	if world == null:
		return
	audio.listener_ch = side.cam_ch
	var flags: PackedStringArray = []
	if _paused:
		flags.append("ПАУЗА")
	if _time_scale != 1.0:
		flags.append("час ×%d" % int(_time_scale))
	var clock: float = world.clock_s()
	_status.text = (
		"%02d:%02d:%02d   %s"
		% [int(clock / 3600.0) % 24, int(clock / 60.0) % 60, int(clock) % 60, "  ".join(flags)]
	)
	_status.position.x = (size.x - _status.size.x) * 0.5


func _command(cmd: Dictionary) -> void:
	if not world.apply_command(cmd):
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
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			side.zoom_by(1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			side.zoom_by(1.0 / 1.12)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and (mm.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_LEFT)) != 0:
		side.pan_px(mm.relative.x)
		return
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
			SimClock.step.disconnect(_on_sim_step)
			get_tree().change_scene_to_file(MENU_SCENE)
		KEY_P:
			_paused = not _paused
			SimClock.set_paused(_paused)
		KEY_T:
			var scales: Array[float] = SimConfig.TIME_SCALES
			_time_scale = scales[(scales.find(_time_scale) + 1) % scales.size()]
			SimClock.set_time_scale(_time_scale)
		KEY_F:
			side.follow = true
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
