class_name TrackNode
extends RefCounted
## A point where segment ends meet.
## - END:    buffer stop / end of modelled track, one connection.
## - JOINT:  plain connection of exactly two segment ends.
## - SWITCH: стрілочний перевід. `trunk` is the toe side (вістряки); `straight` and
##           `diverging` are the two frog-side routes. `state` selects the route taken
##           by a train coming from the trunk.

enum Kind { END, JOINT, SWITCH }
enum SwitchState { STRAIGHT, DIVERGING }

var id: StringName
var kind: Kind
## END and JOINT: the connected ends (1 or 2 of them).
var ends: Array[TrackEnd] = []
## SWITCH only.
var trunk: TrackEnd
var straight: TrackEnd
var diverging: TrackEnd
var state: SwitchState = SwitchState.STRAIGHT


func all_ends() -> Array[TrackEnd]:
	if kind == Kind.SWITCH:
		return [trunk, straight, diverging]
	return ends


## The end a train continues onto after arriving at this node through `arrived_from`.
## Returns a Dictionary: { "next": TrackEnd or null, "event": StringName or &"" }.
## Events: &"end_of_track", &"switch_trailed" (trailing through a switch set against the
## train, i.e. взріз стрілки — the train still passes, the event is a rules violation).
func pass_through(arrived_from: TrackEnd) -> Dictionary:
	match kind:
		Kind.END:
			return {"next": null, "event": &"end_of_track"}
		Kind.JOINT:
			for e: TrackEnd in ends:
				if not e.equals(arrived_from):
					return {"next": e, "event": &""}
			return {"next": null, "event": &"end_of_track"}
		Kind.SWITCH:
			if arrived_from.equals(trunk):
				return {
					"next": straight if state == SwitchState.STRAIGHT else diverging, "event": &""
				}
			var set_for_us: bool = (
				(arrived_from.equals(straight) and state == SwitchState.STRAIGHT)
				or (arrived_from.equals(diverging) and state == SwitchState.DIVERGING)
			)
			return {"next": trunk, "event": &"" if set_for_us else &"switch_trailed"}
	return {"next": null, "event": &"end_of_track"}


static func kind_from_string(s: String) -> Kind:
	match s:
		"end":
			return Kind.END
		"joint":
			return Kind.JOINT
		"switch":
			return Kind.SWITCH
	push_error("TrackNode: unknown kind '%s'" % s)
	return Kind.END


static func from_dict(d: Dictionary) -> TrackNode:
	var n := TrackNode.new()
	n.id = StringName(str(d["id"]))
	n.kind = kind_from_string(str(d["kind"]))
	if n.kind == Kind.SWITCH:
		n.trunk = TrackEnd.from_dict(d["trunk"])
		n.straight = TrackEnd.from_dict(d["straight"])
		n.diverging = TrackEnd.from_dict(d["diverging"])
		n.state = (
			SwitchState.DIVERGING
			if str(d.get("state", "straight")) == "diverging"
			else SwitchState.STRAIGHT
		)
	else:
		for e: Variant in d["ends"]:
			n.ends.append(TrackEnd.from_dict(e as Dictionary))
	return n
