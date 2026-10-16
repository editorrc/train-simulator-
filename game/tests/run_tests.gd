extends SceneTree
## Minimal headless test runner (see docs/DECISIONS.md, D-004).
## Usage:  godot --headless --path game -s res://tests/run_tests.gd [-- --filter=<substring>]
## Finds every res://tests/**/test_*.gd, runs each test_* method, exits 1 on failure.

const TESTS_ROOT: String = "res://tests"

var _errors: ErrorCounter = ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	var filter: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr("--filter=".length())
	var files: PackedStringArray = []
	_collect(TESTS_ROOT, files)
	files.sort()
	var passed: int = 0
	var failed: int = 0
	for path: String in files:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("ERROR  cannot load %s: %s" % [path, "; ".join(_errors.take())])
			failed += 1
			continue
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			if filter != "" and not (path + "::" + name).contains(filter):
				continue
			var instance: Object = script.new()
			var test: TestCase = instance as TestCase
			if test == null:
				print("ERROR  %s does not extend TestCase" % path)
				failed += 1
				break
			test._current_test = "%s::%s" % [path.get_file(), name]
			_errors.take()
			if test.has_method("before_each"):
				test.call("before_each")
			test.call(name)
			if test.has_method("after_each"):
				test.call("after_each")
			for e: String in _errors.take():
				test.fail("script error: " + e)
			if test.failures.is_empty():
				passed += 1
				print("ok     %s" % test._current_test)
			else:
				failed += 1
				for f: String in test.failures:
					print("FAIL   %s" % f)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
