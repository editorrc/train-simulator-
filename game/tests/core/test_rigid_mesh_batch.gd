extends TestCase


func test_batch_preserves_transformed_geometry_and_material_inputs() -> void:
	var root := Node3D.new()
	var mat: StandardMaterial3D = TrainCar3D.material(Color("287958"), .7)
	var box: MeshInstance3D = TrainCar3D.box(root, Vector3(3, 2, 1), Vector3(2, 4, 6), mat)
	box.rotation.y = .5
	var expected: AABB = box.transform * box.mesh.get_aabb()
	var merged: MeshInstance3D = RigidMeshBatch.merge(root)
	var actual: AABB = merged.mesh.get_aabb()
	assert_true(actual.position.distance_to(expected.position) < .00001)
	assert_true(actual.size.distance_to(expected.size) < .00001)
	var arrays: Array = merged.mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var parameters: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	assert_true(colors[0].is_equal_approx(mat.albedo_color))
	assert_almost_eq(parameters[0].x, mat.metallic, .00001)
	assert_almost_eq(parameters[0].y, mat.roughness, .00001)
	root.free()


func test_moving_parts_stay_separate_from_static_batch() -> void:
	var root := Node3D.new()
	var door := Node3D.new()
	root.add_child(door)
	var mat: StandardMaterial3D = TrainCar3D.material(Color.WHITE)
	TrainCar3D.box(root, Vector3.ZERO, Vector3.ONE, mat)
	var leaf: MeshInstance3D = TrainCar3D.box(door, Vector3.ZERO, Vector3.ONE, mat)
	RigidMeshBatch.merge(root, [door])
	door.position.z = .6
	assert_true(is_instance_valid(leaf), "door mesh was not merged into the body")
	assert_eq(leaf.get_parent(), door)
	root.free()


func test_batched_car_keeps_doors_and_all_wheels() -> void:
	var car := TrainCar3D.new()
	var spec: VehicleSpec = VehicleSpec.from_dict(Fixtures.er9m_vehicles()["er9m_head"])
	car.build(spec, {}, true)
	assert_eq(car.doors.size(), 8)
	assert_eq(car.trucks.size(), 2)
	assert_eq(car.wheels.size(), 2)
	for wheels: MultiMesh in car.wheels:
		assert_eq(wheels.instance_count, 2, "two wheelsets, with two wheels each, per truck")
	for door: Dictionary in car.doors:
		assert_eq((door["node"] as Node).get_child_count(), 1)
	assert_true(car.lamp != null)
	car.free()
