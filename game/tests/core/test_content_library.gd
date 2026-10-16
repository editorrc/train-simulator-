extends TestCase


func test_loads_base_mod() -> void:
	var lib := ContentLibrary.new()
	lib.load_all("res://content")
	assert_true(lib.errors.is_empty(), ", ".join(lib.errors))
	assert_true(&"er9m_motor" in lib.ids_of(&"vehicle"))
	assert_true(&"er9m_10" in lib.ids_of(&"consist"))
	var route: Dictionary = lib.get_entry(&"route", &"test_polygon")
	assert_true(route.has("track_graph") and route.has("geometry") and route.has("stations"))


func test_builds_world_from_scenario() -> void:
	var lib := ContentLibrary.new()
	lib.load_all("res://content")
	var w: SimWorld = lib.build_world(&"polygon_free_drive")
	assert_not_null(w)
	assert_eq(w.player().consist.vehicles.size(), 10)
	assert_almost_eq(w.player().head.offset_m, 520.0, 1e-9)


func test_duplicate_id_without_override_is_an_error() -> void:
	var lib := ContentLibrary.new()
	lib.load_mod("res://content/base")
	lib.load_mod("res://content/base")
	assert_false(lib.errors.is_empty())
