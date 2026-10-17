class_name RenderPose
extends RefCounted
## A one-tick visual interpolation buffer. The deterministic simulation is untouched.

var previous: TrackPosition
var current: TrackPosition
var previous_distance: float = 0.0
var current_distance: float = 0.0
var travel: float = 0.0


func reset(t: Train) -> void:
	previous = t.head
	current = t.head
	previous_distance = t.odometer_m
	current_distance = t.odometer_m
	travel = 0.0


func capture(t: Train) -> void:
	previous = current
	current = t.head
	previous_distance = current_distance
	current_distance = t.odometer_m
	travel = t.speed_ms * SimConfig.SIM_DT


func head(graph: TrackGraph, alpha: float) -> TrackPosition:
	return previous.advance(graph, travel * clampf(alpha, 0, 1)).position


static func follow(
	start: float, target_before: float, target_after: float, dt: float, lag_s: float
) -> float:
	if lag_s <= 0.001 or dt <= 0.0:
		return target_after
	var velocity: float = (target_after - target_before) / dt
	return (
		target_after
		- velocity * lag_s
		+ (start - target_before + velocity * lag_s) * exp(-dt / lag_s)
	)
