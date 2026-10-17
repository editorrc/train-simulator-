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
	var next: int = 0
	for frame: int in frames:
		while (
			next < hits.size()
			and maxi(0, int(ceil(float(hits[next]["fraction"]) * frames)) - 1) <= frame
		):
			var hit: Dictionary = hits[next]
			var axle: int = int(hit["axle"])
			var distance: float = absf(axle_offsets[axle] - 8.0)
			var attenuation: float = 1.0 / pow(1.0 + distance / 22.0, 1.5)
			var variant: int = (
				posmod(int(hit["joint"]) * 7 + axle * 3, samples.size())
				if not samples.is_empty()
				else 0
			)
			if not samples.is_empty():
				_voices.append(
					{
						"sample": variant,
						"cursor": 0,
						"gain": .24 * attenuation * clampf(absf(velocity_ms) / 25.0, .05, 1.0),
						"pan": clampf((axle_offsets[axle] - 8.0) / 100.0, -.25, .25)
					}
				)
			next += 1
		var value := Vector2.ZERO
		for voice: Dictionary in _voices:
			var sample: PackedFloat32Array = samples[int(voice["sample"])]
			var cursor: int = int(voice["cursor"])
			if cursor >= sample.size():
				continue
			var mono: float = sample[cursor] * float(voice["gain"])
			if muted:
				mono *= .25
			value += Vector2(mono * (1.0 - float(voice["pan"])), mono * (1.0 + float(voice["pan"])))
			voice["cursor"] = cursor + 1
		buffer[frame] = value
	var remaining: Array[Dictionary] = []
	for voice: Dictionary in _voices:
		if int(voice["cursor"]) < samples[int(voice["sample"])].size():
			remaining.append(voice)
	_voices = remaining
	distance_m = finish
	return buffer
