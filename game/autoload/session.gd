extends Node
## What the player chose in the menu (scenario, series, formation, livery) for the drive
## scene to pick up. Series data (formations, liveries, cab) comes from the consist JSON.

const DEFAULT_CONSIST: StringName = &"er9m_10"

var scenario_id: StringName = &"kyiv_city_free_drive"
var consist_id: StringName = DEFAULT_CONSIST
var livery_id: StringName = &"classic_green"
var car_count: int = 6


func consist() -> Dictionary:
	var entry: Dictionary = ContentDB.get_entry(&"consist", consist_id)
	return entry if not entry.is_empty() else ContentDB.get_entry(&"consist", DEFAULT_CONSIST)


## Consist ids of every series in the loaded content, the default series first.
func series_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in ContentDB.ids_of(&"consist"):
		ids.append(StringName(str(id)))
	ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return a == DEFAULT_CONSIST or (b != DEFAULT_CONSIST and str(a) < str(b))
	)
	return ids


## Car count → vehicle ids, as defined by the series data.
func formations() -> Dictionary:
	var entry: Dictionary = consist()
	if entry.has("formations"):
		return entry["formations"]
	return {str((entry["vehicles"] as Array).size()): entry["vehicles"]}


func available_counts() -> Array[int]:
	var counts: Array[int] = []
	for key: Variant in formations():
		counts.append(int(str(key)))
	counts.sort()
	return counts


func liveries() -> Array:
	var entry: Dictionary = consist()
	return ContentDB.get_entry(&"liveries", StringName(str(entry.get("liveries", "")))).get(
		"liveries", []
	)


func livery() -> Dictionary:
	var list: Array = liveries()
	for raw: Variant in list:
		if StringName(str((raw as Dictionary)["id"])) == livery_id:
			return raw
	return list[0] if not list.is_empty() else {}


func cab_definition() -> Dictionary:
	return ContentDB.get_entry(&"cab", StringName(str(consist().get("cab", ""))))


## Switch series and keep the other choices valid for it.
func select_series(id: StringName) -> void:
	consist_id = id
	ensure_valid()


func ensure_valid() -> void:
	var counts: Array[int] = available_counts()
	if not counts.is_empty() and car_count not in counts:
		var best: int = counts[0]
		for c: int in counts:
			if absi(c - car_count) < absi(best - car_count):
				best = c
		car_count = best
	var list: Array = liveries()
	var known: bool = false
	for raw: Variant in list:
		known = known or StringName(str((raw as Dictionary)["id"])) == livery_id
	if not known and not list.is_empty():
		livery_id = StringName(str((list[0] as Dictionary)["id"]))


func build_world() -> SimWorld:
	ensure_valid()
	var scenario: Dictionary = ContentDB.get_entry(&"scenario", scenario_id)
	var bundle: Dictionary = ContentDB.get_entry(&"route", StringName(str(scenario["route"])))
	var formation: Dictionary = consist().duplicate(true)
	formation["vehicles"] = formations()[str(car_count)]
	return ScenarioBuilder.build(
		scenario, bundle["track_graph"], formation, ContentDB.library.vehicles()
	)
