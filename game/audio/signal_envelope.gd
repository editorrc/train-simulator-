class_name SignalEnvelope
extends RefCounted
## A held signal's attack and release in seconds. Re-pressing preserves the current gain.

var gain: float = 0.0
var attack_s: float = 0.06
var release_s: float = 0.65
var _held: bool = false
var _elapsed: float = 0.0
var _start: float = 0.0


func advance(held: bool, dt: float) -> float:
	if held != _held:
		_held = held
		_elapsed = 0.0
		_start = gain
	_elapsed += maxf(dt, 0.0)
	var duration: float = attack_s if held else release_s
	var fraction: float = clampf(_elapsed / maxf(duration, .001), 0.0, 1.0)
	var eased: float = fraction * fraction * (3.0 - 2.0 * fraction)
	gain = lerpf(_start, 1.0 if held else 0.0, eased)
	return gain
