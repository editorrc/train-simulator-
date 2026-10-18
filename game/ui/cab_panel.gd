class_name CabPanel
extends Control
## The driver's desk (пульт машиніста) for the 2D demo: instruments, signal lamps, toggle
## switches and push buttons from cab.json, master controller, driver's brake valve №395 and
## the reverser. Clicks and keys become Commands; the panel never changes the world itself.

signal command(cmd: Dictionary)
signal announcement_requested

const PAINT := Color("3a4f47")
const PAINT_DARK := Color("2c3d37")
const PAINT_EDGE := Color("22302b")
const LABEL := Color("d9e4de")
const LABEL_DIM := Color("9fb3aa")
const LAMP_OFF := Color("2a2e2c")
const LAMP_COLORS: Dictionary[String, Color] = {
	"red": Color("ff4a3a"),
	"yellow": Color("ffc93a"),
	"green": Color("57e38a"),
	"white": Color("f4f2e6"),
	"blue": Color("5aa8ff"),
}
const BUTTON_COLORS: Dictionary[String, Color] = {
	"neutral": Color("8a9490"),
	"green": Color("2f9e5a"),
	"red": Color("c23b2f"),
	"yellow": Color("d8a52a"),
}

var bindings: ControlBindings
var world: SimWorld
var cab_def: Dictionary = {}
## Hit regions rebuilt every draw: [{rect: Rect2, kind: String, id: String}]
var _hits: Array[Dictionary] = []
var _held: String = ""
var _draw_scale: float = 1.0
var _toggle_pitch: float = 70.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _process(_delta: float) -> void:
	queue_redraw()


func _train() -> Train:
	return world.player()


func _send(cmd: Dictionary) -> void:
	command.emit(cmd)


# ------------------------------------------------------------------ input


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mb.pressed:
		if _held != "":
			_send(Commands.cab_control(world.player_train_id, StringName(_held), false))
			_held = ""
		return
	for h: Dictionary in _hits:
		if (h["rect"] as Rect2).has_point(mb.position / _draw_scale):
			_click(h)
			accept_event()
			return


func _click(h: Dictionary) -> void:
	var p: StringName = world.player_train_id
	var id: String = str(h["id"])
	match str(h["kind"]):
		"announcer":
			announcement_requested.emit()
		"toggle":
			_send(Commands.cab_control(p, StringName(id), not _train().cab.is_on(StringName(id))))
		"button":
			_send(Commands.cab_control(p, StringName(id), true))
		"hold":
			_held = id
			_send(Commands.cab_control(p, StringName(id), true))
		"controller":
			_send(Commands.controller_set(p, id))
		"valve":
			_send(Commands.brake_valve_set(p, id))
		"reverser":
			_send(Commands.reverser_set(p, int(id)))


## Actions are shared with the controls editor; model interlocks remain in SimWorld.
func apply_action(id: String, pressed: bool) -> bool:
	var p: StringName = world.player_train_id
	for raw: Variant in cab_def.get("controls", []):
		var control: Dictionary = raw
		if str(control["id"]) != id:
			continue
		match str(control["type"]):
			"hold":
				_send(Commands.cab_control(p, StringName(id), pressed))
			"toggle":
				if pressed:
					_send(
						Commands.cab_control(
							p, StringName(id), not _train().cab.is_on(StringName(id))
						)
					)
			"button":
				if pressed:
					_send(Commands.cab_control(p, StringName(id), true))
		return true
	if not pressed:
		return false
	match id:
		"controller_up":
			_send(Commands.controller_step(p, 1))
		"controller_down":
			_send(Commands.controller_step(p, -1))
		"brake_release":
			_send(Commands.brake_valve_step(p, -1))
		"brake_apply":
			_send(Commands.brake_valve_step(p, 1))
		"emergency":
			_send(Commands.brake_valve_set(p, "VI"))
		"reverser_forward":
			_send(Commands.reverser_set(p, 1))
		"reverser_neutral":
			_send(Commands.reverser_set(p, 0))
		"reverser_reverse":
			_send(Commands.reverser_set(p, -1))
		_:
			return false
	return true


# ------------------------------------------------------------------ drawing


func _draw() -> void:
	if world == null:
		return
	_hits.clear()
	_draw_scale = minf(size.y / 360.0, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _draw_scale)
	var w: float = size.x / _draw_scale
	var h: float = size.y / _draw_scale
	# Painted steel desk with a darker top lip.
	draw_rect(Rect2(0, 0, w, h), PAINT)
	draw_rect(Rect2(0, 0, w, 10), PAINT_EDGE)
	draw_rect(Rect2(0, 10, w, 3), PAINT.lightened(0.12))
	var col1: float = w * 0.33
	var col2: float = w * 0.68
	draw_rect(Rect2(col1, 22, 2, h - 34), PAINT_EDGE)
	draw_rect(Rect2(col2, 22, 2, h - 34), PAINT_EDGE)
	_draw_instruments(Rect2(10, 18, col1 - 20, h - 26))
	_draw_switchboard(Rect2(col1 + 14, 18, col2 - col1 - 28, h - 26))
	_draw_handles(Rect2(col2 + 14, 18, w - col2 - 24, h - 26))


func _kgf(pa: float) -> float:
	return Units.pa_to_kgf_cm2(pa)


func _draw_instruments(r: Rect2) -> void:
	var t: Train = _train()
	var avail_h: float = r.size.y - 30.0
	var big: float = minf(avail_h * 0.48, r.size.x * 0.2)
	var small: float = minf(avail_h * 0.235, (r.size.x - big * 2.0 - 40.0) / 4.4)
	var cy: float = r.position.y + avail_h * 0.5 + 4.0
	var sx: float = r.position.x + big + 10
	var limit: float = t.last_speed_limit_ms
	var marks: Array[Dictionary] = []
	if not is_inf(limit):
		marks.append({"value": Units.ms_to_kmh(limit), "color": Color("d43b2c")})
	var v_kmh: float = Units.ms_to_kmh(absf(t.speed_ms))
	# Dial range follows the series: 150 km/h for the ER9 family, 200 for the EKr1.
	var dial_max: float = 150.0 if Units.ms_to_kmh(t.consist.max_speed_ms()) <= 130.0 else 200.0
	Gauge.draw(
		self,
		Vector2(sx, cy),
		big,
		0,
		dial_max,
		20,
		5,
		"ШВИДКІСТЬ",
		"км/год",
		[{"value": v_kmh, "color": Color("c0392b")}],
		marks,
		"%5.1f" % v_kmh
	)
	var gx0: float = sx + big + small + 22
	var gx1: float = gx0 + small * 2.0 + 16
	var gy0: float = cy - small - 8
	var gy1: float = cy + small + 8
	(
		Gauge
		. draw(
			self,
			Vector2(gx0, gy0),
			small,
			0,
			10,
			2,
			0.5,
			"ГР / ГМ",
			"кгс/см²",
			[
				{"value": _kgf(t.air.p_gr), "color": Color("c0392b")},
				{"value": _kgf(t.air.p_tm), "color": Color("111111")},
			]
		)
	)
	Gauge.draw(
		self,
		Vector2(gx0, gy1),
		small,
		0,
		6,
		1,
		0.5,
		"ГЦ",
		"кгс/см²",
		[{"value": _kgf(t.air.p_tc), "color": Color("111111")}]
	)
	Gauge.draw(
		self,
		Vector2(gx1, gy0),
		small,
		0,
		30,
		10,
		2,
		"КМ",
		"кВ",
		[{"value": t.power.line_voltage / 1000.0, "color": Color("111111")}],
		[{"value": 29.0, "color": Color("d43b2c")}]
	)
	Gauge.draw(
		self,
		Vector2(gx1, gy1),
		small,
		0,
		6,
		1,
		0.5,
		tr("ПОВ. СП"),
		"кгс/см²",
		[{"value": _kgf(t.air.p_panto), "color": Color("111111")}],
		[{"value": 3.5, "color": Color("d8a52a")}]
	)
	# Traction effort bar.
	var bar := Rect2(r.position.x + 8, r.end.y - 14, r.size.x * 0.4, 9)
	draw_rect(bar, PAINT_DARK)
	var frac: float = clampf(
		absf(t.last_traction_n) / maxf(t.consist.max_traction_force_n(), 1.0), 0, 1
	)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color("57e38a"))
	var font: Font = get_theme_default_font()
	draw_string(
		font,
		bar.position + Vector2(bar.size.x + 8, 9),
		tr("Тяга %d кН") % roundi(t.last_traction_n / 1000.0),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		LABEL
	)


func _draw_switchboard(r: Rect2) -> void:
	var font: Font = get_theme_default_font()
	var t: Train = _train()
	# Signal lamps.
	var lamps: Array = cab_def.get("lamps", [])
	var lw: float = minf(64.0, r.size.x / maxf(lamps.size(), 1))
	for i: int in lamps.size():
		var ld: Dictionary = lamps[i]
		var c := Vector2(r.position.x + lw * (i + 0.5), r.position.y + 26)
		var cond: String = str(ld["when"])
		var lit: bool = (not t.check(cond.substr(1))) if cond.begins_with("!") else t.check(cond)
		lit = lit and t.cab.is_on(&"battery")
		var col: Color = LAMP_COLORS.get(str(ld["color"]), Color.WHITE)
		draw_circle(c, 17, PAINT_EDGE)
		draw_circle(c, 13, col if lit else LAMP_OFF)
		if lit:
			draw_circle(c, 22, Color(col, 0.18))
			draw_circle(c + Vector2(-4, -4), 4, Color(1, 1, 1, 0.5))
		var txt: String = str(ld["label_uk"])
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, c + Vector2(-tw * 0.5, 34), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, LABEL)
	# Toggles and buttons from cab.json, in two rows.
	var toggles: Array[Dictionary] = []
	var buttons: Array[Dictionary] = []
	for c: Variant in cab_def.get("controls", []):
		var cd: Dictionary = c
		if str(cd["type"]) == "toggle":
			toggles.append(cd)
		else:
			buttons.append(cd)
	var row1_y: float = r.position.y + 100
	var cw: float = r.size.x / maxf(toggles.size(), 1)
	_toggle_pitch = cw
	for i: int in toggles.size():
		_toggle(Vector2(r.position.x + cw * (i + 0.5), row1_y), toggles[i])
	var row2_y: float = r.position.y + r.size.y - 62
	var bw: float = r.size.x / maxf(buttons.size(), 1)
	for i: int in buttons.size():
		_push_button(Vector2(r.position.x + bw * (i + 0.5), row2_y), buttons[i])


func _toggle(c: Vector2, cd: Dictionary) -> void:
	var font: Font = get_theme_default_font()
	var id := StringName(str(cd["id"]))
	var on: bool = _train().cab.is_on(id)
	var plate := Rect2(c + Vector2(-26, -30), Vector2(52, 60))
	draw_rect(plate, PAINT_DARK)
	draw_rect(plate, PAINT_EDGE, false, 2.0)
	draw_circle(c, 9, Color("1b1f1d"))
	var tip: Vector2 = c + Vector2(0, -22 if on else 22)
	draw_line(c, tip, Color("c9cfcc"), 6.0, true)
	draw_circle(tip, 6, Color("e7ecea"))
	draw_string(
		font, plate.position + Vector2(4, 12), "УВІМК", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LABEL_DIM
	)
	draw_string(
		font, plate.position + Vector2(4, 57), "ВИМК", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, LABEL_DIM
	)
	var y: float = _centered_words(
		c + Vector2(0, 46), str(cd["label_uk"]), _toggle_pitch - 6.0, 12, LABEL
	)
	var hk: String = (
		bindings.label_for(str(cd["id"])) if bindings != null else str(cd.get("hotkey", ""))
	)
	if hk != "":
		_centered_words(Vector2(c.x, y), "[%s]" % hk, 80.0, 11, LABEL_DIM)
	_hits.append({"rect": plate.grow(6), "kind": "toggle", "id": str(id)})


func _push_button(c: Vector2, cd: Dictionary) -> void:
	var font: Font = get_theme_default_font()
	var id: String = str(cd["id"])
	var col: Color = BUTTON_COLORS.get(str(cd.get("color", "neutral")), BUTTON_COLORS["neutral"])
	var pressed: bool = (
		_held == id or (str(cd["type"]) == "hold" and _train().cab.is_on(StringName(id)))
	)
	draw_circle(c, 24, PAINT_EDGE)
	draw_circle(c, 20, Color("1b1f1d"))
	draw_circle(c, 16 if pressed else 17, col.darkened(0.25) if pressed else col)
	if not pressed:
		draw_circle(c + Vector2(-5, -6), 5, Color(1, 1, 1, 0.35))
	var y: float = _centered_words(c + Vector2(0, 40), str(cd["label_uk"]), 84.0, 12, LABEL)
	var hk: String = (
		bindings.label_for(str(cd["id"])) if bindings != null else str(cd.get("hotkey", ""))
	)
	if hk != "":
		_centered_words(Vector2(c.x, y), "[%s]" % hk, 84.0, 11, LABEL_DIM)
	_hits.append(
		{"rect": Rect2(c - Vector2(26, 26), Vector2(52, 52)), "kind": str(cd["type"]), "id": id}
	)


## Draws text centred under a control, wrapping on spaces and shrinking the font until the
## longest word fits. Returns the next baseline y.
func _centered_words(at: Vector2, text: String, max_w: float, size_px: int, col: Color) -> float:
	var font: Font = get_theme_default_font()
	var fs: int = size_px
	for word: String in text.split(" "):
		while fs > 8 and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
			fs -= 1
	var lines: PackedStringArray = []
	var line: String = ""
	for word: String in text.split(" "):
		var trial: String = word if line == "" else line + " " + word
		if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
			lines.append(line)
			line = word
		else:
			line = trial
	lines.append(line)
	var y: float = at.y
	for l: String in lines:
		var tw: float = font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(at.x - tw * 0.5, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		y += fs + 2
	return y


## Master controller, brake valve and reverser as rotary handles over position arcs.
func _draw_handles(r: Rect2) -> void:
	var t: Train = _train()
	var rad: float = minf(r.size.y * 0.3, r.size.x * 0.15)
	var cy: float = r.position.y + r.size.y * 0.6
	var ctl_ids: Array[String] = []
	for p: Dictionary in t.consist.controller_positions:
		ctl_ids.append(str(p["id"]))
	_rotary(
		Vector2(r.position.x + rad + 20, cy),
		rad,
		tr("КОНТРОЛЕР"),
		ctl_ids,
		t.controller_index,
		"controller",
		Color("2f9e5a"),
		-150.0,
		-30.0
	)
	var valve_ids: Array[String] = []
	for p: Dictionary in t.consist.brake_valve_positions:
		valve_ids.append(str(p["id"]))
	_rotary(
		Vector2(r.position.x + r.size.x * 0.55, cy),
		rad * 1.1,
		tr("КРАН МАШИНІСТА"),
		valve_ids,
		t.brake_valve_index,
		"valve",
		Color("c23b2f"),
		-200.0,
		20.0
	)
	var name: String = str(t.consist.brake_valve_positions[t.brake_valve_index].get("name_uk", ""))
	var font: Font = get_theme_default_font()
	var nw: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(
		font,
		Vector2(r.position.x + r.size.x * 0.55 - nw * 0.5, r.end.y - 8),
		name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		LABEL
	)
	var announce_rect := Rect2(r.position.x + 12, r.position.y + 6, r.size.x - 125, 32)
	draw_rect(announce_rect, PAINT_DARK)
	draw_string(
		font,
		announce_rect.position + Vector2(12, 23),
		tr("Інформатор") + " · " + (bindings.label_for("announcer") if bindings != null else "I"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		LABEL
	)
	_hits.append({"rect": announce_rect, "kind": "announcer", "id": ""})
	# Reverser: three key positions.
	var rx: float = r.end.x - 46
	var labels: Array[String] = [tr("Уперед"), "0", tr("Назад")]
	var values: Array[int] = [1, 0, -1]
	draw_string(
		font,
		Vector2(rx - 34, r.position.y + 20),
		tr("РЕВЕРСОР"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		LABEL_DIM
	)
	for i: int in 3:
		var rect := Rect2(rx - 40, r.position.y + 34 + i * 48, 80, 40)
		var active: bool = t.reverser == values[i]
		draw_rect(rect, Color("d8a52a") if active else PAINT_DARK)
		draw_rect(rect, PAINT_EDGE, false, 2.0)
		var lw2: float = font.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(
			font,
			rect.get_center() + Vector2(-lw2 * 0.5, 6),
			labels[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			15,
			Color("1b1307") if active else LABEL
		)
		_hits.append({"rect": rect, "kind": "reverser", "id": str(values[i])})


func _rotary(
	c: Vector2,
	rad: float,
	title: String,
	ids: Array[String],
	current: int,
	kind: String,
	knob: Color,
	deg_from: float,
	deg_to: float
) -> void:
	var font: Font = get_theme_default_font()
	var tw: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(
		font, c + Vector2(-tw * 0.5, -rad - 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, LABEL_DIM
	)
	draw_arc(c, rad, deg_to_rad(deg_from), deg_to_rad(deg_to), 32, PAINT_EDGE, 14.0)
	var n: int = ids.size()
	var angles: Array[float] = []
	for i: int in n:
		angles.append(deg_to_rad(lerpf(deg_from, deg_to, float(i) / maxf(n - 1, 1))))
	for i: int in n:
		var d := Vector2(cos(angles[i]), sin(angles[i]))
		var p: Vector2 = c + d * (rad + 22)
		var lbl: String = ids[i]
		var fs: int = 16 if i == current else 14
		var sz: Vector2 = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var col: Color = Color("ffe08a") if i == current else LABEL
		# Dense scales (EKr1: 0…100% in tens): label every other notch and the current one.
		var labelled: bool = n <= 7 or i == current or (i % 2 == 0 and absi(i - current) != 1)
		if labelled:
			draw_string(
				font,
				p + Vector2(-sz.x * 0.5, sz.y * 0.3),
				lbl,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				fs,
				col
			)
		draw_line(c + d * (rad - 7), c + d * (rad + 7), LABEL_DIM, 2.0)
		_hits.append({"rect": Rect2(p - Vector2(20, 16), Vector2(40, 32)), "kind": kind, "id": lbl})
	# Handle.
	var a: float = angles[current]
	var hd := Vector2(cos(a), sin(a))
	draw_circle(c, rad * 0.32, Color("1b1f1d"))
	draw_line(c, c + hd * rad * 0.95, Color("cfd5d2"), 10.0, true)
	draw_circle(c + hd * rad * 0.95, 13, knob)
	draw_circle(c + hd * rad * 0.95 + Vector2(-3, -4), 4, Color(1, 1, 1, 0.4))
	draw_circle(c, rad * 0.16, Color("8a9490"))


func release_holds() -> void:
	if world == null:
		return
	for id: StringName in CabState.HOLDS:
		if _train().cab.is_on(id):
			_send(Commands.cab_control(world.player_train_id, id, false))
	_held = ""


func _input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _held != "":
		_send(Commands.cab_control(world.player_train_id, StringName(_held), false))
		_held = ""
