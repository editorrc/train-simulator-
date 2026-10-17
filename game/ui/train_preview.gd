class_name TrainPreview
extends Control
## Shared 3D model and lighting in the main menu, viewed from above and the cab end.

var head: VehicleSpec
var motor: VehicleSpec
var livery: Dictionary = {}
var _view: ExteriorView
var _last_livery: String = ""


func _process(_dt: float) -> void:
	if livery.is_empty():
		return
	var key: String = str(livery.get("id", ""))
	if key == _last_livery and _view != null:
		return
	_last_livery = key
	if _view != null:
		_view.queue_free()
	_view = ExteriorView.new()
	_view.preview_mode = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	var world: SimWorld = ContentDB.build_world(Session.scenario_id)
	var scenario: Dictionary = ContentDB.get_entry(&"scenario", Session.scenario_id)
	var route: Dictionary = ContentDB.get_entry(&"route", StringName(str(scenario["route"])))
	_view.setup(world, route["stations"], livery, "")
