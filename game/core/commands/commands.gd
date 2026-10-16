class_name Commands
extends RefCounted
## Player/AI commands. Every change of controls goes through SimWorld.apply_command(), so a
## session is fully described by: scenario + seed + command log (replays, tutorials, AI,
## future multiplayer). A command is a Dictionary {type: StringName, train: StringName, ...}.

const CONTROLLER_STEP: StringName = &"controller_step"
const CONTROLLER_SET: StringName = &"controller_set"
const BRAKE_VALVE_STEP: StringName = &"brake_valve_step"
const BRAKE_VALVE_SET: StringName = &"brake_valve_set"
const REVERSER_SET: StringName = &"reverser_set"
const SWITCH_SET: StringName = &"switch_set"
const CAB_CONTROL: StringName = &"cab_control"


static func controller_step(train: StringName, delta: int) -> Dictionary:
	return {"type": CONTROLLER_STEP, "train": train, "delta": delta}


static func controller_set(train: StringName, position_id: String) -> Dictionary:
	return {"type": CONTROLLER_SET, "train": train, "position": position_id}


static func brake_valve_step(train: StringName, delta: int) -> Dictionary:
	return {"type": BRAKE_VALVE_STEP, "train": train, "delta": delta}


static func brake_valve_set(train: StringName, position_id: String) -> Dictionary:
	return {"type": BRAKE_VALVE_SET, "train": train, "position": position_id}


static func reverser_set(train: StringName, value: int) -> Dictionary:
	return {"type": REVERSER_SET, "train": train, "value": value}


static func switch_set(node: StringName, diverging: bool) -> Dictionary:
	return {"type": SWITCH_SET, "node": node, "diverging": diverging}


## Cab switch / button / held button. Buttons act on value = true.
static func cab_control(train: StringName, control: StringName, value: bool) -> Dictionary:
	return {"type": CAB_CONTROL, "train": train, "control": control, "value": value}
