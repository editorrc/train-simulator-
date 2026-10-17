extends TestCase


func test_station_and_departure_announce_once() -> void:
	var cues := StationCues.new()
	assert_eq(cues.update("kyiv", "protasiv", 2000), ["kyiv_station"] as Array[String])
	assert_true(cues.update("kyiv", "protasiv", 2000).is_empty())
	assert_eq(cues.update("", "protasiv", 1900), ["protasiv_next"] as Array[String])
	assert_true(cues.update("", "protasiv", 400).is_empty())
	assert_eq(cues.update("protasiv", "demiiivskyi", 3000), ["protasiv_station"] as Array[String])


func test_spawn_near_station_does_not_repeat() -> void:
	var cues := StationCues.new()
	assert_eq(cues.update("", "kyiv", 420), ["kyiv_next"] as Array[String])
	for frame: int in 300:
		assert_true(cues.update("", "kyiv", 300).is_empty())
