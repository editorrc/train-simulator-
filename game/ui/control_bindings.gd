class_name ControlBindings
extends RefCounted
## Physical-key bindings shared by the driver, captions and preferences. No world state.

const GROUPS: Array[String] = ["Рух", "Двері та сигнали", "Живлення", "Огляд та інтерфейс"]
var actions: Array[Dictionary] = []
var overrides: Dictionary = {}
var _held: Dictionary = {}


func _init(cab: Dictionary = {}, saved: Dictionary = {}) -> void:
	overrides = saved.duplicate(true)
	_add("controller_up", "Контролер: наступна позиція", KEY_UP, 0)
	_add("controller_down", "Контролер: попередня позиція", KEY_DOWN, 0)
	_add("brake_release", "Кран: до відпускання", KEY_LEFT, 0)
	_add("brake_apply", "Кран: до гальмування", KEY_RIGHT, 0)
	_add("emergency", "Екстрене гальмування", KEY_BACKSPACE, 0)
	_add("reverser_forward", "Реверсор: уперед", KEY_R, 0)
	_add("reverser_neutral", "Реверсор: нейтраль", KEY_R | KEY_MASK_SHIFT, 0)
	_add("reverser_reverse", "Реверсор: назад", KEY_R | KEY_MASK_ALT, 0)
	for raw: Variant in cab.get("controls", []):
		var control: Dictionary = raw
		var id: String = str(control["id"])
		var key: int = OS.find_keycode_from_string(str(control.get("hotkey", "")))
		_add(
			id,
			str(control["label_uk"]),
			key,
			1 if id in ["horn", "whistle", "doors_left", "doors_right", "headlights"] else 2,
			str(control["type"]) == "hold"
		)
	_add("announcer", "Повторити оголошення", KEY_I, 1)
	_add("camera", "Наступний ракурс", KEY_TAB, 3)
	_add("platform", "Вид з боку платформи", KEY_F, 3)
	_add("desk", "Розгорнути пульт", KEY_D, 3)
	_add("map", "Розгорнути схему колій", KEY_M, 3)
	_add("pause", "Пауза / продовжити", KEY_P, 3)
	var primary: int = KEY_MASK_META if OS.get_name() == "macOS" else KEY_MASK_CTRL
	_add("settings", "Налаштування", KEY_COMMA | primary, 3)
	_add("controls", "Налаштування керування", KEY_SLASH | primary, 3)
	_add("panels", "Сховати / показати панелі", KEY_H | KEY_MASK_SHIFT, 3)
	_add("layout", "Відновити розташування панелей", KEY_0 | primary, 3)
	_add("zoom_in", "Наблизити", KEY_EQUAL, 3)
	_add("zoom_out", "Віддалити", KEY_MINUS, 3)


func _add(id: String, label: String, key: int, group: int, hold: bool = false) -> void:
	actions.append({"id": id, "label": label, "key": key, "group": group, "hold": hold})


func binding(id: String) -> int:
	if overrides.has(id):
		return int(overrides[id])
	for action: Dictionary in actions:
		if action["id"] == id:
			return int(action["key"])
	return 0


static func chord(event: InputEventKey) -> int:
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if event.shift_pressed:
		key |= KEY_MASK_SHIFT
	if event.alt_pressed:
		key |= KEY_MASK_ALT
	if event.ctrl_pressed:
		key |= KEY_MASK_CTRL
	if event.meta_pressed:
		key |= KEY_MASK_META
	return key


func label_for(id: String, mac: bool = OS.get_name() == "macOS") -> String:
	var key: int = binding(id)
	var prefix: String = ""
	for pair: Array in [
		[KEY_MASK_META, "⌘" if mac else "Meta+"],
		[KEY_MASK_CTRL, "⌃" if mac else "Ctrl+"],
		[KEY_MASK_ALT, "⌥" if mac else "Alt+"],
		[KEY_MASK_SHIFT, "⇧" if mac else "Shift+"]
	]:
		if key & int(pair[0]):
			prefix += str(pair[1])
	var code: int = key & KEY_CODE_MASK
	var names: Dictionary = {
		KEY_UP: "↑",
		KEY_DOWN: "↓",
		KEY_LEFT: "←",
		KEY_RIGHT: "→",
		KEY_SPACE: "Пробіл",
		KEY_BACKSPACE: "⌫" if mac else "Backspace",
		KEY_TAB: "Tab",
		KEY_COMMA: ",",
		KEY_SLASH: "/"
	}
	return prefix + str(names.get(code, OS.get_keycode_string(code)))


func conflict(key: int, except_id: String = "") -> String:
	for action: Dictionary in actions:
		if action["id"] != except_id and binding(str(action["id"])) == key:
			return str(action["label"])
	return ""


func assign(id: String, key: int) -> bool:
	var code: int = key & KEY_CODE_MASK
	if (
		code in [0, KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
		or not conflict(key, id).is_empty()
	):
		return false
	# Keep operating-system close/quit/minimize shortcuts available.
	if key & (KEY_MASK_META | KEY_MASK_CTRL) and code in [KEY_Q, KEY_W, KEY_M]:
		return false
	overrides[id] = key
	return true


## Emits only edges. Releases use the original physical key even if modifiers changed.
func consume(event: InputEventKey) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var physical: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if not event.pressed:
		if _held.has(physical):
			result.append({"id": _held[physical], "pressed": false})
			_held.erase(physical)
		return result
	if event.echo:
		return result
	for action: Dictionary in actions:
		if binding(str(action["id"])) == chord(event):
			if bool(action["hold"]):
				if _held.has(physical):
					return result
				_held[physical] = action["id"]
			result.append({"id": action["id"], "pressed": true})
			break
	return result


func release_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in _held.values():
		result.append({"id": id, "pressed": false})
	_held.clear()
	return result
