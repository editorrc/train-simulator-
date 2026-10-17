extends Node
## What the player chose in the menu (scenario, livery) for the drive scene to pick up.

var scenario_id: StringName = &"kyiv_city_free_drive"
var livery_id: StringName = &"classic_green"

var car_count: int = 6


func build_world() -> SimWorld:
	var scenario: Dictionary = ContentDB.get_entry(&"scenario", scenario_id)
	var bundle: Dictionary = ContentDB.get_entry(&"route", StringName(str(scenario["route"])))
	var formation: Dictionary = (
		ContentDB.get_entry(&"consist", StringName(str(scenario["consist"]))).duplicate(true)
	)
	# Shorten the base formation by removing complete intermediate trailer/motor pairs.
	var cars: Array = ["er9m_head", "er9m_motor"]
	for i: int in (car_count - 4) / 2:
		cars.append_array(["er9m_trailer", "er9m_motor"])
	cars.append_array(["er9m_motor", "er9m_head"])
	formation["vehicles"] = cars
	return ScenarioBuilder.build(
		scenario, bundle["track_graph"], formation, ContentDB.library.vehicles()
	)
