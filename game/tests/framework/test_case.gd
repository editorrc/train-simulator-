class_name TestCase
extends RefCounted
## Base class for tests. Any method named test_* is a test case.
## Assertions record failures and let the test continue, so one run shows all problems.
## Optional hooks: before_each(), after_each().

var failures: PackedStringArray = []
var _current_test: String = ""


func fail(message: String) -> void:
	failures.append("%s: %s" % [_current_test, message])


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("expected <%s>, got <%s> %s" % [expected, actual, message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		fail("did not expect <%s> %s" % [actual, message])


func assert_almost_eq(
	actual: float, expected: float, tolerance: float, message: String = ""
) -> void:
	if absf(actual - expected) > tolerance:
		fail("expected %s ± %s, got %s %s" % [expected, tolerance, actual, message])


func assert_between(actual: float, low: float, high: float, message: String = "") -> void:
	if actual < low or actual > high:
		fail("expected in [%s, %s], got %s %s" % [low, high, actual, message])


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		fail("expected null, got <%s> %s" % [value, message])


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		fail("expected non-null %s" % message)


## Reads a JSON file relative to res:// and returns it as a Dictionary.
func load_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	fail("cannot parse JSON %s" % path)
	return {}
