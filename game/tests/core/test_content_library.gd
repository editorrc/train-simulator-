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


func test_every_series_formation_builds() -> void:
	var lib := ContentLibrary.new()
	lib.load_all("res://content")
	var scenario: Dictionary = lib.get_entry(&"scenario", &"polygon_free_drive")
	var route: Dictionary = lib.get_entry(&"route", StringName(str(scenario["route"])))
	assert_true(lib.ids_of(&"consist").size() >= 4, "ER9M + three new series")
	for id: Variant in lib.ids_of(&"consist"):
		var consist: Dictionary = lib.get_entry(&"consist", StringName(str(id)))
		assert_false(lib.get_entry(&"cab", StringName(str(consist["cab"]))).is_empty())
		var liveries: Dictionary = lib.get_entry(&"liveries", StringName(str(consist["liveries"])))
		assert_true((liveries.get("liveries", []) as Array).size() >= 2, "%s liveries" % id)
		for count: Variant in consist.get("formations", {}):
			var formation: Dictionary = consist.duplicate(true)
			formation["vehicles"] = consist["formations"][count]
			var w: SimWorld = ScenarioBuilder.build(
				scenario, route["track_graph"], formation, lib.vehicles()
			)
			assert_not_null(w, "%s × %s" % [id, count])
			assert_eq(w.player().consist.vehicles.size(), int(str(count)))
