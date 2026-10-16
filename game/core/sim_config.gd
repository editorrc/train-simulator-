class_name SimConfig
extends RefCounted
## Global simulation constants. Everything here is SI.

## Fixed simulation step, s. The core never uses the frame delta.
const SIM_DT: float = 1.0 / 60.0
## Upper bound on steps per rendered frame, so a long hitch does not freeze the game
## trying to catch up ("spiral of death").
const MAX_STEPS_PER_FRAME: int = 8
## Allowed time-acceleration factors outside graded scenarios.
const TIME_SCALES: Array[float] = [1.0, 2.0, 4.0]
