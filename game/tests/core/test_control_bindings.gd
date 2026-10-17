extends TestCase


func _bindings() -> ControlBindings:
	return ControlBindings.new(load_json("res://content/base/rolling_stock/er9m/cab.json"))


func _event(key: int, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	return event


func test_defaults_have_no_conflicts_or_required_function_keys() -> void:
	var bindings := _bindings()
	for action: Dictionary in bindings.actions:
		var key: int = bindings.binding(str(action["id"]))
		assert_eq(bindings.conflict(key, str(action["id"])), "", str(action["id"]))
		assert_false((key & KEY_CODE_MASK) >= KEY_F1 and (key & KEY_CODE_MASK) <= KEY_F35)


func test_physical_key_survives_ukrainian_layout_and_shortcuts_are_exact() -> void:
	var bindings := _bindings()
	var event: InputEventKey = _event(KEY_V)
	event.keycode = 0x041C
	assert_eq(bindings.consume(event)[0]["id"], "whistle")
	bindings.release_all()
	event.meta_pressed = true
	assert_true(bindings.consume(event).is_empty(), "Command V must not play whistle")


func test_holds_ignore_echo_and_release_after_modifier_change() -> void:
	var bindings := _bindings()
	assert_true(bindings.assign("horn", KEY_SPACE | KEY_MASK_ALT))
	var event: InputEventKey = _event(KEY_SPACE)
	event.alt_pressed = true
	assert_eq(bindings.consume(event).size(), 1)
	event.echo = true
	assert_true(bindings.consume(event).is_empty())
	var release: InputEventKey = _event(KEY_SPACE, false)
	assert_eq(bindings.consume(release)[0], {"id": "horn", "pressed": false})
	assert_true(bindings.release_all().is_empty())


func test_focus_release_and_rebinding_conflicts() -> void:
	var bindings := _bindings()
	bindings.consume(_event(KEY_SPACE))
	bindings.consume(_event(KEY_V))
	assert_eq(bindings.release_all().size(), 2)
	assert_true(bindings.release_all().is_empty())
	assert_false(bindings.assign("horn", KEY_V))
	assert_false(bindings.assign("horn", KEY_ESCAPE))
	assert_true(bindings.assign("horn", KEY_O))
	var restored := ControlBindings.new({}, bindings.overrides)
	assert_eq(restored.binding("horn"), KEY_O)
