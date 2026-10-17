class_name RailConsistPose
extends RefCounted
## Rigid cars supported by two independently aligned trucks; coupled poses solved together.

var path: RailPath


func _init(p_path: RailPath) -> void:
	path = p_path


func car_at(head: TrackPosition, spec: VehicleSpec, front_distance_m: float) -> Dictionary:
	var span: float = float(spec.visual.get("bogie_centers_m", 15.0))
	var front_track: TrackPosition = head.advance(path.graph, -front_distance_m).position
	var front: Vector3 = path.point(front_track)
	var rear_distance: float = span
	var rear_track: TrackPosition
	var rear: Vector3
	# Preserve the physical pivot spacing (chord), rather than stretching the bogie base.
	for iteration: int in 4:
		rear_track = front_track.advance(path.graph, -rear_distance).position
		rear = path.point(rear_track)
		var error: float = span - front.distance_to(rear)
		if absf(error) < .0001:
			break
		rear_distance += error
	var direction: Vector3 = (front - rear).normalized()
	if direction.length_squared() < .01:
		direction = -path.frame(front_track).basis.z
	var body := Transform3D(Basis.looking_at(direction, Vector3.UP), (front + rear) * .5)
	var inset: float = float(spec.visual.get("body_end_inset_m", .35))
	var half: float = spec.length_m * .5 - inset
	return {
		"body": body,
		"front": body.origin + direction * half,
		"rear": body.origin - direction * half,
		"bogies":
		[
			path.frame(front_track, float(spec.visual.get("axle_spacing_m", 2.6))),
			path.frame(rear_track, float(spec.visual.get("axle_spacing_m", 2.6)))
		],
		"front_track": front_track,
		"rear_track": rear_track,
		"front_distance": front_distance_m
	}


func solve(
	head: TrackPosition, specs: Array[VehicleSpec], extensions: PackedFloat64Array = []
) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var previous_distance: float = 0.0
	for i: int in specs.size():
		var spec: VehicleSpec = specs[i]
		var span: float = float(spec.visual.get("bogie_centers_m", 15.0))
		var distance: float = (spec.length_m - span) * .5
		if i > 0:
			var previous: VehicleSpec = specs[i - 1]
			distance = (
				previous_distance
				+ float(previous.visual.get("bogie_centers_m", 15.0)) * .5
				+ (previous.length_m + spec.length_m) * .5
				- span * .5
			)
			var desired: float = (
				float(previous.visual.get("body_end_inset_m", .35))
				+ float(spec.visual.get("body_end_inset_m", .35))
			)
			if extensions.size() >= i:
				desired += extensions[i - 1]
			var anchor: Vector3 = states[i - 1]["rear"]
			# Newton solve on rail distance, no independent yaw interpolation or delayed following.
			for iteration: int in 5:
				var candidate: Dictionary = car_at(head, spec, distance)
				var length: float = anchor.distance_to(candidate["front"])
				if absf(length - desired) < .0005:
					break
				var ahead: Dictionary = car_at(head, spec, distance + .05)
				var derivative: float = (anchor.distance_to(ahead["front"]) - length) / .05
				if absf(derivative) < .1:
					break
				distance -= clampf((length - desired) / derivative, -.35, .35)
		states.append(car_at(head, spec, distance))
		previous_distance = distance
	return states
