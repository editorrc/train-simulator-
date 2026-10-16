class_name FixedStepClock
extends RefCounted
## Turns variable frame time into a whole number of fixed simulation steps.
## Pure logic: the SimClock autoload owns one instance and feeds it frame deltas.

var step_dt: float
var max_steps_per_frame: int
var time_scale: float = 1.0
var paused: bool = false
## Total simulated time, s. Advances by exactly step_dt per step.
var sim_time: float = 0.0
## Total number of steps taken since start; the canonical "tick" for replays.
var tick: int = 0

var _accumulator: float = 0.0


func _init(
	p_step_dt: float = SimConfig.SIM_DT, p_max_steps: int = SimConfig.MAX_STEPS_PER_FRAME
) -> void:
	step_dt = p_step_dt
	max_steps_per_frame = p_max_steps


## Adds real frame time and returns how many simulation steps to run now.
## The caller must then call commit_step() once per executed step.
func accumulate(frame_delta: float) -> int:
	if paused or frame_delta <= 0.0:
		return 0
	_accumulator += frame_delta * time_scale
	var steps: int = int(floor(_accumulator / step_dt))
	if steps > max_steps_per_frame:
		# Drop the backlog instead of trying to catch up forever.
		steps = max_steps_per_frame
		_accumulator = 0.0
	else:
		_accumulator -= steps * step_dt
	return steps


func commit_step() -> void:
	tick += 1
	sim_time = tick * step_dt


## Fraction of a step left in the accumulator, for render interpolation (0..1).
func interpolation_alpha() -> float:
	return clampf(_accumulator / step_dt, 0.0, 1.0)
