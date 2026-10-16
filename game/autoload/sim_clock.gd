extends Node
## Drives the fixed-step simulation from the frame loop.
## Logic lives in FixedStepClock (core/), this node only feeds it frame time.

## Emitted once per fixed simulation step; the game layer calls SimWorld.step() here.
signal step(dt: float, tick: int)

var clock: FixedStepClock = FixedStepClock.new()


func _process(delta: float) -> void:
	var steps: int = clock.accumulate(delta)
	for i: int in steps:
		clock.commit_step()
		step.emit(clock.step_dt, clock.tick)


func set_paused(value: bool) -> void:
	clock.paused = value


func set_time_scale(scale: float) -> void:
	if scale in SimConfig.TIME_SCALES:
		clock.time_scale = scale
	else:
		push_warning("SimClock: unsupported time scale %s" % scale)
