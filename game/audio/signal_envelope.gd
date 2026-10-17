class_name SignalEnvelope
extends RefCounted
## A held signal's attack and release in seconds. Re-pressing preserves the current gain.

var gain: float = 0.0
var attack_s: float = 0.06
var release_s: float = 0.45


func advance(held: bool, dt: float) -> float:
	if dt > 0.0:
		gain = move_toward(gain, 1.0 if held else 0.0, dt / (attack_s if held else release_s))
	return gain
