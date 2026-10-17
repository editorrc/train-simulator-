extends TestCase


func test_trucks_stay_on_curve_and_couplings_keep_their_length() -> void:
	var lib := ContentLibrary.new()
	lib.load_all("res://content")
	var route: Dictionary = lib.get_entry(&"route", &"kyiv_city_ring")
	var w: SimWorld = lib.build_world(&"kyiv_city_free_drive")
	var path := RailPath.new(w.graph, RouteGeometry.from_dict(route["geometry"]))
	var solver := RailConsistPose.new(path)
	for offset: float in [50.0, 245.0, 800.0]:
		var head: TrackPosition = w.player().head.advance(w.graph, offset).position
		var cars: Array[Dictionary] = solver.solve(head, w.player().consist.vehicles)
		for i: int in cars.size():
			var car: Dictionary = cars[i]
			var trucks: Array = car["bogies"]
			assert_almost_eq(
				(trucks[0] as Transform3D).origin.distance_to((trucks[1] as Transform3D).origin),
				15.0,
				.002
			)
			assert_almost_eq(
				(trucks[0] as Transform3D).origin.distance_to(path.point(car["front_track"])),
				0.0,
				.001
			)
			assert_almost_eq(
				(trucks[1] as Transform3D).origin.distance_to(path.point(car["rear_track"])),
				0.0,
				.001
			)
			if i > 0:
				assert_almost_eq(
					(cars[i - 1]["rear"] as Vector3).distance_to(car["front"]), .7, .004
				)


func test_platform_edge_follows_rail_curve_with_constant_gap() -> void:
	var lib := ContentLibrary.new()
	lib.load_all("res://content")
	var route: Dictionary = lib.get_entry(&"route", &"kyiv_city_ring")
	var w: SimWorld = lib.build_world(&"kyiv_city_free_drive")
	var path := RailPath.new(w.graph, RouteGeometry.from_dict(route["geometry"]))
	var segment: StringName = w.player().head.segment_id
	for offset: float in [20, 100, 180, 260]:
		var pos := TrackPosition.new(segment, offset, 1)
		var frame: Transform3D = path.frame(pos)
		var edge: Vector3 = path.offset_point(pos, 1.95, 1.1)
		assert_almost_eq((edge - frame.origin).dot(frame.basis.x), 1.95, .001)
		assert_almost_eq((edge - frame.origin).dot(-frame.basis.z), 0.0, .001)


func test_body_turn_is_continuous_across_geometry_vertices() -> void:
	var lib := ContentLibrary.new()
	lib.load_all("res://content")
	var route: Dictionary = lib.get_entry(&"route", &"kyiv_city_ring")
	var w: SimWorld = lib.build_world(&"kyiv_city_free_drive")
	var solver := RailConsistPose.new(
		RailPath.new(w.graph, RouteGeometry.from_dict(route["geometry"]))
	)
	var previous := Basis.IDENTITY
	for frame: int in 400:
		var head: TrackPosition = w.player().head.advance(w.graph, frame * .5).position
		var state: Dictionary = solver.car_at(head, w.player().consist.vehicles[0], 3.25)
		var basis: Basis = (state["body"] as Transform3D).basis
		if frame > 0:
			assert_true(
				previous.get_rotation_quaternion().angle_to(basis.get_rotation_quaternion()) < .01,
				"no heading snaps at 144 km/h"
			)
		previous = basis
