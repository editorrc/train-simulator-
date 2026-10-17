class_name RailJointMixer
extends RefCounted
## Sample-timed rail joints. Wheelbase determines timing; speed does not pitch the impact.

var sample_rate: float = 22050.0
var spacing_m: float = 25.0
var distance_m: float = 0.0
var axle_offsets: PackedFloat64Array = []
var samples: Array[PackedFloat32Array] = []
var _voices: Array[Dictionary] = []


func setup(vehicles: Array[VehicleSpec]) -> void:
	axle_offsets.clear()
	var behind: float = 0.0
	for vehicle: VehicleSpec in vehicles:
		var mid: float = behind + vehicle.length_m * .5
		var bogie: float = float(vehicle.visual.get("bogie_centers_m", 15)) * .5
		var axle: float = float(vehicle.visual.get("axle_spacing_m", 2.6)) * .5
		for offset: float in [-bogie - axle, -bogie + axle, bogie - axle, bogie + axle]:
			axle_offsets.append(mid + offset)
		behind += vehicle.length_m


func events(start: float, end: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if absf(end - start) < .0000001:
		return result
	for axle: int in axle_offsets.size():
		var a: float = (start - axle_offsets[axle]) / spacing_m
		var b: float = (end - axle_offsets[axle]) / spacing_m
		var direction: int = 1 if end > start else -1
		var joint: int = int(floor(a)) + 1 if direction > 0 else int(ceil(a)) - 1
		while joint <= int(floor(b)) if direction > 0 else joint >= int(ceil(b)):
			var at: float = joint * spacing_m + axle_offsets[axle]
			result.append({"fraction": (at - start) / (end - start), "axle": axle, "joint": joint})
			joint += direction
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["fraction"]) < float(b["fraction"])
	)
	return result


func render(frames: int, velocity_ms: float, muted: bool = false) -> PackedVector2Array:
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	var finish: float = distance_m + (0.0 if muted else velocity_ms) * frames / sample_rate
	var hits: Array[Dictionary] = events(distance_m, finish)
	for hit: Dictionary in hits:
		if samples.is_empty():
			break
		var axle: int = int(hit["axle"])
		var distance: float = absf(axle_offsets[axle] - 8.0)
		var attenuation: float = 1.0 / pow(1.0 + distance / 22.0, 1.5)
		_voices.append(
			{
				"sample": posmod(int(hit["joint"]) * 7 + axle * 3, samples.size()),
				"cursor": -maxi(0, int(ceil(float(hit["fraction"]) * frames)) - 1),
				"gain": .24 * attenuation * clampf(absf(velocity_ms) / 25.0, .05, 1.0),
				"pan": clampf((axle_offsets[axle] - 8.0) / 100.0, -.25, .25)
			}
		)
	var remaining: Array[Dictionary] = []
	for voice: Dictionary in _voices:
		# Read voice metadata once per block, rather than doing dictionary lookups per sample.
		var sample: PackedFloat32Array = samples[int(voice["sample"])]
		var cursor: int = int(voice["cursor"])
		var gain: float = float(voice["gain"]) * (.25 if muted else 1.0)
		var pan: float = float(voice["pan"])
		var stereo_gain := Vector2(gain * (1.0 - pan), gain * (1.0 + pan))
		for frame: int in range(maxi(0, -cursor), mini(frames, sample.size() - cursor)):
			buffer[frame] += sample[cursor + frame] * stereo_gain
		voice["cursor"] = cursor + frames
		if cursor + frames < sample.size():
			remaining.append(voice)
	_voices = remaining
	distance_m = finish
	return buffer
