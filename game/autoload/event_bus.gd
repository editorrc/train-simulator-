extends Node
## Relays simulation events to views, audio, UI and scoring.
## The core never references this node: SimWorld collects events per step and the
## game layer forwards them here. Views subscribe; nothing in core/ subscribes.

## Generic simulation event: {type: StringName, tick: int, ...payload}.
signal sim_event(event: Dictionary)
## A rules violation (ПТЕ, regulations), see docs/SIMULATION.md §7.
signal rule_violation(violation: Dictionary)
## Radio traffic line for the radio log / subtitles.
signal radio_message(message: Dictionary)
