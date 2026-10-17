class_name TrainAudio
extends Node
## Continuous recorded loops run on the audio thread; frame updates only set smooth gains.

const RECORDINGS: String = "res://audio/recordings/"
var world: SimWorld
var listener_ch: float = 0.0
var paused: bool = false
var announcing: bool = false
var _rolling: AudioStreamPlayer
var _motor: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _compressor: AudioStreamPlayer
var _hiss: AudioStreamPlayer
var _horn: AudioStreamPlayer
var _whistle: AudioStreamPlayer
var _clack: AudioStreamPlayer
var _joint_playback: AudioStreamGeneratorPlayback
var _joint_capacity: int = 0
var _mix_thread: Thread
var _mix_mutex := Mutex.new()
var _mix_running: bool = false
var _mix_velocity: float = 0.0
var _mix_paused: bool = false
var _joint_mixer := RailJointMixer.new()
var _controls: Dictionary[String, AudioStreamPlayer] = {}
var _horn_envelope := SignalEnvelope.new()
var _whistle_envelope := SignalEnvelope.new()
var _speed: float = 0.0
var _duck: float = 1.0
var _last_tc: float = 0.0
var _last_tm: float = 0.0
var _last_breaker: bool = false


func _ready() -> void:
	for name: String in ["TrainMix", "CabControls", "Announcer"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, name)
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		limiter.threshold_db = -2.0
		AudioServer.add_bus_effect(0, limiter)
	_rolling = _player("rolling_loop")
	_motor = _player("motor_loop")
	_hum = _player("motor_loop")
	_compressor = _player("compressor_loop")
	_hiss = _player("hiss_loop")
	_horn = _player("horn_sustain", false)
	_whistle = _player("whistle_sustain", false)
	_whistle_envelope.release_s = 0.50
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = .45
	_clack = AudioStreamPlayer.new()
	_clack.stream = generator
	_clack.bus = "TrainMix"
	add_child(_clack)
	_clack.play()
	_joint_playback = _clack.get_stream_playback() as AudioStreamGeneratorPlayback
	_joint_capacity = _joint_playback.get_frames_available()
	_joint_mixer.setup(world.player().consist.vehicles)
	_joint_mixer.distance_m = world.graph.chainage_at(world.player().head)
	for index: int in 4:
		var recording: AudioStreamWAV = (
			load(RECORDINGS + "wheel_clack_%d.wav" % index) as AudioStreamWAV
		)
		var sample := PackedFloat32Array()
		for at: int in range(0, recording.data.size(), 2):
			sample.append(recording.data.decode_s16(at) / 32768.0)
		_joint_mixer.samples.append(sample)
	for name: String in [
		"switch_click",
		"switch_on",
		"switch_off",
		"controller_notch",
		"lever_latch",
		"button_click",
		"door_latch"
	]:
		_controls[name] = _player(name, false, false, "CabControls")
		_controls[name].max_polyphony = 4
		_controls[name].volume_db = -18.0
	_last_tc = world.player().air.p_tc
	_last_tm = world.player().air.p_tm
	Settings.apply_audio()
	_mix_running = true
	if not OS.has_feature("web"):
		_mix_thread = Thread.new()
		_mix_thread.start(_mix_joints)


func _player(
	name: String, autoplay: bool = true, loop: bool = true, bus: String = "TrainMix"
) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load(RECORDINGS + name + ".wav") as AudioStreamWAV
	if stream != null:
		RecordedStream.configure_loop(stream, loop)
	p.stream = stream
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	if autoplay:
		p.play()
	return p


static func _db(gain: float) -> float:
	return -80.0 if gain <= 0.0001 else linear_to_db(gain)


func _volume(player: AudioStreamPlayer, target: float, delta: float) -> void:
	var current: float = db_to_linear(player.volume_db)
	player.volume_db = _db(lerpf(current, target, 1.0 - exp(-delta / 0.45)))


func _signal(player: AudioStreamPlayer, envelope: SignalEnvelope, held: bool, dt: float) -> void:
	var gain: float = envelope.advance(held, dt)
	if gain > 0.0:
		if not player.playing:
			player.play()
		player.volume_db = _db(gain * 0.38)
	elif player.playing:
		player.stop()


func _process(delta: float) -> void:
	if world == null or delta <= 0.0:
		return
	var t: Train = world.player()
	_speed = lerpf(_speed, 0.0 if paused else absf(t.speed_ms), 1.0 - exp(-delta / 0.16))
	_duck = lerpf(_duck, 0.55 if announcing else 1.0, 1.0 - exp(-delta / 0.60))
	var moving: float = clampf(_speed / 8.0, 0.0, 1.0) * _duck
	var load_share: float = clampf(
		absf(t.last_traction_n) / maxf(t.consist.max_traction_force_n(), 1.0), 0.0, 1.0
	)
	_volume(_rolling, moving * 0.25, delta)
	_rolling.pitch_scale = 0.85 + clampf(_speed / 70.0, 0.0, 0.5)
	_volume(_motor, moving * (0.06 + 0.19 * load_share), delta)
	_motor.pitch_scale = 0.85 + clampf(_speed / 65.0, 0.0, 0.55)
	_clack.volume_db = _db(_duck)
	_mix_mutex.lock()
	_mix_velocity = t.speed_ms
	_mix_paused = paused
	_mix_mutex.unlock()
	if _mix_thread == null:
		_fill_joint_buffer(t.speed_ms, paused)
	_volume(_hum, 0.035 * t.power.aux_progress * _duck if not paused else 0.0, delta)
	_volume(_compressor, 0.16 * _duck if t.air.compressor_working and not paused else 0.0, delta)
	var vent: float = (
		maxf((_last_tc - t.air.p_tc) / delta, 0.0)
		+ maxf((_last_tm - t.air.p_tm) / delta, 0.0) * 0.6
	)
	_last_tc = t.air.p_tc
	_last_tm = t.air.p_tm
	_volume(_hiss, clampf(vent / Units.kgf_cm2_to_pa(1.2), 0.0, 1.0) * 0.25 * _duck, delta)
	var enabled: bool = t.power.control_on(t.cab) and not paused
	_signal(_horn, _horn_envelope, enabled and t.cab.is_on(&"horn"), delta)
	_signal(_whistle, _whistle_envelope, enabled and t.cab.is_on(&"whistle"), delta)
	if t.power.main_breaker_on != _last_breaker:
		_controls["lever_latch"].play()
	_last_breaker = t.power.main_breaker_on


func control_snapshot() -> Dictionary:
	var t: Train = world.player()
	return {
		"cab": t.cab.to_dict(),
		"controller": t.controller_index,
		"valve": t.brake_valve_index,
		"reverser": t.reverser
	}


func play_command(cmd: Dictionary, before: Dictionary) -> void:
	var t: Train = world.player()
	var sound: String = ""
	match StringName(str(cmd.get("type", ""))):
		Commands.CONTROLLER_SET, Commands.CONTROLLER_STEP:
			if t.controller_index != int(before["controller"]):
				sound = "controller_notch"
		Commands.BRAKE_VALVE_SET, Commands.BRAKE_VALVE_STEP:
			if t.brake_valve_index != int(before["valve"]):
				sound = "lever_latch"
		Commands.REVERSER_SET:
			if t.reverser != int(before["reverser"]):
				sound = "lever_latch"
		Commands.CAB_CONTROL:
			var id: StringName = StringName(str(cmd["control"]))
			var previous: Dictionary = before["cab"]
			if id in CabState.BUTTONS:
				if bool(cmd["value"]):
					sound = "button_click"
			elif bool(previous.get(str(id), false)) != t.cab.is_on(id):
				sound = (
					"door_latch"
					if id in [&"doors_left", &"doors_right"]
					else ("switch_on" if t.cab.is_on(id) else "switch_off")
				)
	if sound != "":
		_controls[sound].play()


func _mix_joints() -> void:
	# Only the PCM ring buffer and immutable sample data cross this thread boundary.
	# No scene-tree, train, Node transform or resource loading is accessed here.
	while true:
		_mix_mutex.lock()
		var running: bool = _mix_running
		var velocity: float = _mix_velocity
		var muted: bool = _mix_paused
		_mix_mutex.unlock()
		if not running:
			break
		_fill_joint_buffer(velocity, muted)
		OS.delay_usec(2000)


func _exit_tree() -> void:
	_mix_mutex.lock()
	_mix_running = false
	_mix_mutex.unlock()
	if _mix_thread != null and _mix_thread.is_started():
		_mix_thread.wait_to_finish()


func _fill_joint_buffer(velocity: float, muted: bool) -> void:
	var available: int = _joint_playback.get_frames_available()
	var queued: int = _joint_capacity - available
	var frames: int = mini(available, maxi(0, 2205 - queued))
	if frames > 0:
		_joint_playback.push_buffer(_joint_mixer.render(frames, velocity, muted))
