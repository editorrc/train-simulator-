class_name TrainAudio
extends Node
## Drives the procedural sounds from the simulation state every frame (view layer only).

const JOINT_PITCH_M: float = 25.0
const MAX_CLACKS_PER_FRAME: int = 6

var world: SimWorld
## Chainage the listener is at (camera centre), for joint loudness.
var listener_ch: float = 0.0

var _rolling: AudioStreamPlayer
var _motor: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _compressor: AudioStreamPlayer
var _hiss: AudioStreamPlayer
var _horn: AudioStreamPlayer
var _clack: AudioStreamPlayer
var _clunk: AudioStreamPlayer
var _axle_joint: PackedInt32Array = []
var _last_tc: float = 0.0
var _last_tm: float = 0.0
var _last_breaker: bool = false
var _last_panto_up: bool = false


func _ready() -> void:
	_rolling = _player(Synth.rolling_loop())
	_motor = _player(Synth.motor_loop())
	_hum = _player(Synth.hum_loop())
	_compressor = _player(Synth.compressor_loop())
	_hiss = _player(Synth.hiss_loop())
	_horn = _player(Synth.horn_loop())
	_clack = _player(Synth.rail_clack(), false)
	_clack.max_polyphony = 12
	_clunk = _player(Synth.clunk(), false)


func _player(stream: AudioStream, autoplay_loop: bool = true) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -80.0
	add_child(p)
	if autoplay_loop:
		p.play()
	return p


static func _db(lin: float) -> float:
	return -80.0 if lin <= 0.001 else linear_to_db(lin)


func _process(delta: float) -> void:
	if world == null or delta <= 0.0:
		return
	var t: Train = world.player()
	var v: float = absf(t.speed_ms)
	_rolling.volume_db = _db(clampf(v / 25.0, 0.0, 1.0) * 0.55)
	_rolling.pitch_scale = 0.6 + clampf(v / 30.0, 0.0, 1.0) * 0.8
	var load_share: float = clampf(
		absf(t.last_traction_n) / maxf(t.consist.max_traction_force_n(), 1.0), 0.0, 1.0
	)
	_motor.pitch_scale = clampf(0.15 + v / 22.0, 0.15, 3.5)
	_motor.volume_db = _db(
		(0.08 + load_share * 0.5) * clampf(v / 2.0, 0.0, 1.0) + load_share * 0.15
	)
	_hum.volume_db = _db((0.12 if t.power.main_breaker_on else 0.0) + (0.12 * t.power.aux_progress))
	_hum.pitch_scale = 0.5 + 0.5 * maxf(t.power.aux_progress, 0.2)
	_compressor.volume_db = _db(0.45 if t.air.compressor_working else 0.0)
	# Hiss follows how fast air is leaving the pipe or the cylinders.
	var d_tc: float = (_last_tc - t.air.p_tc) / delta
	var d_tm: float = (_last_tm - t.air.p_tm) / delta
	_last_tc = t.air.p_tc
	_last_tm = t.air.p_tm
	var vent: float = maxf(d_tc, 0.0) + maxf(d_tm, 0.0) * 0.6
	_hiss.volume_db = _db(clampf(vent / Units.kgf_cm2_to_pa(1.2), 0.0, 1.0) * 0.6)
	_horn.volume_db = _db(0.5 if t.cab.is_on(&"horn") and t.power.control_on(t.cab) else 0.0)
	if t.power.main_breaker_on != _last_breaker:
		_last_breaker = t.power.main_breaker_on
		_clunk.volume_db = -4.0
		_clunk.play()
	if t.power.pantograph_up() and not _last_panto_up:
		_clunk.volume_db = -12.0
		_clunk.play()
	_last_panto_up = t.power.pantograph_up()
	_rail_joints(t)


## Every axle crossing a rail joint plays a clack: the classic "та-дам, та-дам".
func _rail_joints(t: Train) -> void:
	var head_ch: float = world.graph.chainage_at(t.head)
	if is_nan(head_ch):
		return
	var dir: float = 1.0 if t.head.direction > 0 else -1.0
	var axles: PackedFloat32Array = []
	var behind: float = 0.0
	for v: VehicleSpec in t.consist.vehicles:
		var mid: float = behind + v.length_m * 0.5
		var bc: float = float(v.visual.get("bogie_centers_m", 15.0)) * 0.5
		var ax: float = float(v.visual.get("axle_spacing_m", 2.6)) * 0.5
		for off: float in [-bc - ax, -bc + ax, bc - ax, bc + ax]:
			axles.append(head_ch - dir * (mid + off))
		behind += v.length_m
	if _axle_joint.size() != axles.size():
		_axle_joint.resize(axles.size())
		for i: int in axles.size():
			_axle_joint[i] = int(floor(axles[i] / JOINT_PITCH_M))
		return
	var played: int = 0
	for i: int in axles.size():
		var j: int = int(floor(axles[i] / JOINT_PITCH_M))
		if j != _axle_joint[i]:
			_axle_joint[i] = j
			if played < MAX_CLACKS_PER_FRAME and absf(t.speed_ms) > 0.5:
				var dist: float = absf(axles[i] - listener_ch)
				var loud: float = (
					clampf(1.0 - dist / 160.0, 0.08, 1.0)
					* clampf(absf(t.speed_ms) / 12.0, 0.25, 1.0)
				)
				_clack.volume_db = _db(loud * 0.8)
				_clack.pitch_scale = 0.9 + 0.2 * float((i * 7) % 5) / 5.0
				_clack.play()
				played += 1
