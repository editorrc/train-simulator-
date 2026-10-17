class_name TrainPreview
extends Control
## Shared 3D model and lighting in the main menu, viewed from above and the cab end.

var head: VehicleSpec
var motor: VehicleSpec
var livery: Dictionary = {}
var _view: ExteriorView
var _last_livery: String = ""
var _backdrop: TextureRect


func _process(_dt: float) -> void:
	if livery.is_empty():
		return
	var key: String = "%s:%s:%d" % [livery.get("id", ""), Session.scenario_id, Session.car_count]
	if key == _last_livery and _view != null:
		return
	_last_livery = key
	if _view != null:
		_view.queue_free()
	if _backdrop == null:
		# Soft studio light spill behind the train, neutral grey on the graphite page.
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, .075))
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(.5, .55)
		texture.fill_to = Vector2(.98, .55)
		_backdrop = TextureRect.new()
		_backdrop.texture = texture
		_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_backdrop)
	_view = ExteriorView.new()
	_view.preview_mode = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	var world: SimWorld = Session.build_world()
	var scenario: Dictionary = ContentDB.get_entry(&"scenario", Session.scenario_id)
	var route: Dictionary = ContentDB.get_entry(&"route", StringName(str(scenario["route"])))
	var consist: Dictionary = ContentDB.get_entry(&"consist", world.player().consist.id)
	_view.setup(world, route["stations"], livery, str(consist.get("number", "")))
