class_name Fixtures
extends RefCounted
## Shared test data builders.

const ER9M_DIR: String = "res://content/base/rolling_stock/er9m/"


static func read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func er9m_vehicles() -> Dictionary:
	var out: Dictionary = {}
	for id: String in ["er9m_head", "er9m_motor", "er9m_trailer"]:
		out[id] = read(ER9M_DIR + "vehicles/%s.json" % id)
	return out


static func er9m_consist_data() -> Dictionary:
	return read(ER9M_DIR + "consist.json")


static func er9m() -> ConsistSpec:
	return ConsistSpec.from_dict(er9m_consist_data(), er9m_vehicles())


## A single straight segment with a constant grade (‰), ends are buffer stops.
static func straight_track(length_m: float, permille: float = 0.0) -> Dictionary:
	return {
		"segments":
		[
			{
				"id": "line",
				"length_m": length_m,
				"node_a": "west",
				"node_b": "east",
				"grades": [{"at_m": 0, "permille": permille}],
			}
		],
		"nodes":
		[
			{"id": "west", "kind": "end", "ends": [{"segment": "line", "end": "a"}]},
			{"id": "east", "kind": "end", "ends": [{"segment": "line", "end": "b"}]},
		],
	}


static func scenario(segment: String, offset_m: float, load: float = 0.5) -> Dictionary:
	return {
		"id": "test",
		"name_uk": "test",
		"route": "r",
		"consist": "er9m_10",
		"start": {"segment": segment, "offset_m": offset_m, "direction": 1, "time": "08:00"},
		"passenger_load": load,
	}


## World with the player ER9M on a straight track, head at `offset_m`.
static func world_on_straight(
	length_m: float = 30000.0, permille: float = 0.0, offset_m: float = 500.0
) -> SimWorld:
	return ScenarioBuilder.build(
		scenario("line", offset_m),
		straight_track(length_m, permille),
		er9m_consist_data(),
		er9m_vehicles()
	)


## Runs the world until `predicate(world)` is true or `max_s` simulated seconds pass.
## Returns the simulated time spent, s.
static func run_until(world: SimWorld, predicate: Callable, max_s: float) -> float:
	var steps: int = int(max_s / world.dt)
	for i: int in steps:
		if predicate.call(world):
			return i * world.dt
		world.step()
	return max_s
