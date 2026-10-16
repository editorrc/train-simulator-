class_name Synth
extends RefCounted
## Procedural sound samples (no recorded assets): rail-joint clack, rolling rumble, traction
## motor whine, transformer hum, compressor, air hiss, horn, breaker clunk.
## Loops are generated with an integer number of cycles so they repeat seamlessly.

const RATE: int = 22050


static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


static func _noise(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(-1.0, 1.0)


## One wheel crossing a rail joint: thump + short metallic ring.
static func rail_clack() -> AudioStreamWAV:
	var n: int = int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 25
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		lp += (_noise(rng) - lp) * 0.35
		var thump: float = sin(TAU * 70.0 * t) * exp(-t * 38.0)
		var ring: float = sin(TAU * 1250.0 * t) * exp(-t * 60.0) * 0.25
		out[i] = (thump * 0.9 + lp * exp(-t * 55.0) * 0.8 + ring) * 0.8
	return _to_wav(out, false)


## Low rumble of wheels on rails (brown-ish noise), 2 s loop.
static func rolling_loop() -> AudioStreamWAV:
	var n: int = RATE * 2
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a: float = 0.0
	var b: float = 0.0
	for i: int in n:
		a += (_noise(rng) - a) * 0.06
		b += (a - b) * 0.2
		out[i] = b * 3.0
	_crossfade_edges(out, 2000)
	return _to_wav(out, true)


## Traction motor / gear whine: 220 Hz with harmonics, 1 s loop (pitch is scaled at runtime).
static func motor_loop() -> AudioStreamWAV:
	var n: int = RATE
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		out[i] = (
			(
				sin(TAU * 220.0 * t) * 0.5
				+ sin(TAU * 440.0 * t) * 0.22
				+ sin(TAU * 660.0 * t) * 0.12
				+ sin(TAU * 1540.0 * t) * 0.05
			)
			* 0.6
		)
	return _to_wav(out, true)


## Transformer / phase-splitter hum of an AC unit: 100 Hz family + a little 400 Hz whine.
static func hum_loop() -> AudioStreamWAV:
	var n: int = RATE
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		out[i] = (
			(
				sin(TAU * 100.0 * t) * 0.45
				+ sin(TAU * 200.0 * t) * 0.25
				+ sin(TAU * 300.0 * t) * 0.12
				+ sin(TAU * 400.0 * t) * 0.06
			)
			* 0.5
		)
	return _to_wav(out, true)


## Piston compressor: 6 chugs per second, 1 s loop.
static func compressor_loop() -> AudioStreamWAV:
	var n: int = RATE
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		var phase: float = fmod(t * 6.0, 1.0)
		var env: float = exp(-phase * 9.0)
		lp += (_noise(rng) - lp) * 0.25
		out[i] = (sin(TAU * 48.0 * t) * 0.7 + lp * 0.6) * (0.25 + env * 0.75) * 0.7
	return _to_wav(out, true)


## Air exhaust hiss (high-passed noise), 1 s loop.
static func hiss_loop() -> AudioStreamWAV:
	var n: int = RATE
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var prev: float = 0.0
	for i: int in n:
		var x: float = _noise(rng)
		out[i] = (x - prev * 0.9) * 0.45
		prev = x
	_crossfade_edges(out, 800)
	return _to_wav(out, true)


## Two-tone horn (тифон), 1 s loop.
static func horn_loop() -> AudioStreamWAV:
	var n: int = RATE
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var s: float = 0.0
		for f: float in [311.0, 370.0]:
			s += (
				sin(TAU * f * t) * 0.5
				+ sin(TAU * f * 2.0 * t) * 0.18
				+ sin(TAU * f * 3.0 * t) * 0.08
			)
		out[i] = clampf(s * 0.55, -0.9, 0.9)
	return _to_wav(out, true)


## Main breaker / contactor clunk.
static func clunk() -> AudioStreamWAV:
	var n: int = int(RATE * 0.25)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in n:
		var t: float = float(i) / RATE
		out[i] = (sin(TAU * 55.0 * t) * exp(-t * 18.0) + _noise(rng) * exp(-t * 90.0) * 0.6) * 0.9
	return _to_wav(out, false)


static func _crossfade_edges(buf: PackedFloat32Array, n: int) -> void:
	var size: int = buf.size()
	for i: int in n:
		var f: float = float(i) / n
		var a: float = buf[i]
		var b: float = buf[size - n + i]
		buf[i] = a * f + b * (1.0 - f)
