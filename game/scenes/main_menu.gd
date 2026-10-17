extends Control
## Start menu: scenario, train and livery with a live preview, then the drive scene.

const DRIVE_SCENE: String = "res://scenes/drive.tscn"

var _scenario_box: VBoxContainer
var _livery_box: HBoxContainer
var _preview: TrainPreview
var _liveries: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1b2125")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 80
	root.offset_right = -80
	root.offset_top = 50
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 18)
	add_child(root)
	root.add_child(_label("Ukraine Visual Train Sim", 44))
	root.add_child(
		_label(
			"Тренажер машиніста електропоїзда · Київська кільцева · демо 0.3.3", 18, Color("9fb3aa")
		)
	)
	_preview = TrainPreview.new()
	_preview.custom_minimum_size = Vector2(0, 300)
	root.add_child(_preview)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 60)
	root.add_child(row)
	var col1 := VBoxContainer.new()
	col1.add_child(_label("Сценарій", 22))
	_scenario_box = VBoxContainer.new()
	col1.add_child(_scenario_box)
	row.add_child(col1)
	var col2 := VBoxContainer.new()
	col2.add_child(_label("Поїзд", 22))
	for count: int in [4, 6, 10]:
		col2.add_child(
			_option_button(
				"ЕР9М · %d вагонів" % count, Session.car_count == count, _pick_formation.bind(count)
			)
		)
	col2.add_child(_label("Окрас", 22))
	_livery_box = HBoxContainer.new()
	_livery_box.add_theme_constant_override("separation", 8)
	col2.add_child(_livery_box)
	row.add_child(col2)
	var start := Button.new()
	start.text = "Почати  (Enter)"
	start.custom_minimum_size = Vector2(260, 54)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_start)
	root.add_child(start)
	root.add_child(
		_label(
			(
				"Порада: усі панелі в кабіні можна перетягувати за заголовок, змінювати розмір"
				+ " кутом і згортати. F2 — вид, колесо — масштаб, F3 — налаштування,"
				+ " F4 — пульт, F5 — карта, F8 — з платформи."
			),
			14,
			Color("9fb3aa")
		)
	)
	_fill()


func _label(text: String, size_px: int, color: Color = Color("e6eee9")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _option_button(text: String, active: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = active
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(on_press)
	return b


func _fill() -> void:
	for c: Node in _scenario_box.get_children():
		c.queue_free()
	for c: Node in _livery_box.get_children():
		c.queue_free()
	var ids: Array = ContentDB.ids_of(&"scenario")
	ids.sort()
	for id: Variant in ids:
		var sc: Dictionary = ContentDB.get_entry(&"scenario", id as StringName)
		var sid := StringName(str(id))
		_scenario_box.add_child(
			_option_button(str(sc["name_uk"]), sid == Session.scenario_id, _pick_scenario.bind(sid))
		)
	var consist: Dictionary = ContentDB.get_entry(&"consist", &"er9m_10")
	var set_d: Dictionary = ContentDB.get_entry(
		&"liveries", StringName(str(consist.get("liveries", "")))
	)
	_liveries = set_d.get("liveries", [])
	for l: Variant in _liveries:
		var ld: Dictionary = l
		var lid := StringName(str(ld["id"]))
		var b: Button = _option_button(
			str(ld["name_uk"]), lid == Session.livery_id, _pick_livery.bind(lid)
		)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(str(ld["body"]))
		sb.set_content_margin_all(10)
		b.add_theme_stylebox_override("pressed", sb)
		_livery_box.add_child(b)
	var vehicles: Dictionary = ContentDB.library.vehicles()
	_preview.head = VehicleSpec.from_dict(vehicles["er9m_head"] as Dictionary)
	_preview.motor = VehicleSpec.from_dict(vehicles["er9m_motor"] as Dictionary)
	_preview.livery = _livery_by_id(Session.livery_id)


func _pick_scenario(id: StringName) -> void:
	Session.scenario_id = id
	_fill.call_deferred()


func _pick_livery(id: StringName) -> void:
	Session.livery_id = id
	_fill.call_deferred()


func _livery_by_id(id: StringName) -> Dictionary:
	for l: Variant in _liveries:
		if StringName(str((l as Dictionary)["id"])) == id:
			return l
	return _liveries[0] if not _liveries.is_empty() else {}


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER):
		_start()


func _start() -> void:
	get_tree().change_scene_to_file(DRIVE_SCENE)


func _pick_formation(count: int) -> void:
	Session.car_count = count
	get_tree().reload_current_scene()
