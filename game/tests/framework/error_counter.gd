class_name ErrorCounter
extends Logger
## Captures engine/script errors so the runner can fail a test that crashed mid-way
## (GDScript has no exceptions: a runtime error aborts the function silently).
## Logger callbacks may come from any thread, hence the mutex.

var _mutex: Mutex = Mutex.new()
var _messages: PackedStringArray = []


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array[ScriptBacktrace]
) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	_messages.append(
		"%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function]
	)
	_mutex.unlock()


func take() -> PackedStringArray:
	_mutex.lock()
	var out: PackedStringArray = _messages
	_messages = []
	_mutex.unlock()
	return out
