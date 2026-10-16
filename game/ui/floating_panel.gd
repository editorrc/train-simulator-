class_name FloatingPanel
extends Control
## A movable, resizable, collapsible window over the train scene.
## Drag the title bar to move (snaps to screen edges and to the horizontal centre),
## drag the bottom-right grip to resize, click ▾ or double-click the title to collapse.
## Content is a single child Control laid out in the body.

signal layout_changed(panel: FloatingPanel)

const TITLE_H: float = 26.0
const GRIP: float = 16.0
const SNAP_PX: float = 18.0
const MIN_SIZE := Vector2(180, 90)

var panel_id: String = ""
var title: String = ""
var collapsed: bool = false
## Background opacity of the body (0..1).
var opacity: float = 0.9
var content: Control
var expanded_height: float = 0.0

var _drag: String = ""
var _drag_from := Vector2.ZERO
var _rect_from := Rect2()


func _init(p_id: String = "", p_title: String = "", p_content: Control = null) -> void:
	panel_id = p_id
	title = p_title
	if p_content != null:
		content = p_content
		add_child(content)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	resized.connect(_layout_content)
	_layout_content()


func _layout_content() -> void:
	if content == null:
		return
	content.visible = not collapsed
	content.position = Vector2(4, TITLE_H + 2)
	content.size = Vector2(size.x - 8, maxf(size.y - TITLE_H - GRIP, 0))
	queue_redraw()


func set_collapsed(value: bool) -> void:
	if value == collapsed:
		return
	if value:
		expanded_height = size.y
		collapsed = true
		size = Vector2(size.x, TITLE_H)
	else:
		collapsed = false
		size = Vector2(size.x, maxf(expanded_height, MIN_SIZE.y))
	_layout_content()
	layout_changed.emit(self)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var body := StyleBoxFlat.new()
	body.bg_color = Color(0.07, 0.09, 0.085, opacity)
	body.border_color = Color(1, 1, 1, 0.12)
	body.set_border_width_all(1)
	body.set_corner_radius_all(6)
	draw_style_box(body, Rect2(Vector2.ZERO, size))
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(0.16, 0.21, 0.19, minf(1.0, opacity + 0.1))
	bar.corner_radius_top_left = 6
	bar.corner_radius_top_right = 6
	if collapsed:
		bar.corner_radius_bottom_left = 6
		bar.corner_radius_bottom_right = 6
	draw_style_box(bar, Rect2(0, 0, size.x, TITLE_H))
	draw_string(
		font, Vector2(28, 18), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 60, 14, Color("dfe8e3")
	)
	# Collapse arrow.
	var a := Vector2(14, 13)
	var tri: PackedVector2Array = (
		PackedVector2Array([a + Vector2(-5, -3), a + Vector2(5, -3), a + Vector2(0, 4)])
		if not collapsed
		else PackedVector2Array([a + Vector2(-3, -5), a + Vector2(-3, 5), a + Vector2(4, 0)])
	)
	draw_colored_polygon(tri, Color("bcd0c6"))
	# Grip dots.
	draw_string(
		font, Vector2(size.x - 44, 18), "⠿", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.35)
	)
	if not collapsed:
		for k: int in 3:
			var o: float = 4.0 + k * 4.0
			draw_line(
				Vector2(size.x - o, size.y - 3),
				Vector2(size.x - 3, size.y - o),
				Color(1, 1, 1, 0.35),
				1.0
			)


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			move_to_front()
			if mb.position.y <= TITLE_H:
				if mb.double_click or mb.position.x < 26:
					set_collapsed(not collapsed)
				else:
					_start("move", mb.global_position)
			elif not collapsed and mb.position.x > size.x - GRIP and mb.position.y > size.y - GRIP:
				_start("resize", mb.global_position)
			accept_event()
		elif _drag != "":
			_drag = ""
			layout_changed.emit(self)
			accept_event()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _drag != "":
		var delta: Vector2 = mm.global_position - _drag_from
		var view: Vector2 = get_viewport_rect().size
		if _drag == "move":
			position = _snap(_rect_from.position + delta, view)
		else:
			size = (_rect_from.size + delta).max(MIN_SIZE).min(view - position)
		accept_event()


func _start(kind: String, at: Vector2) -> void:
	_drag = kind
	_drag_from = at
	_rect_from = Rect2(position, size)


func _snap(p: Vector2, view: Vector2) -> Vector2:
	var out := p.clamp(Vector2(-size.x + 60, 0), view - Vector2(60, TITLE_H))
	if absf(out.x) < SNAP_PX:
		out.x = 0
	if absf(out.y) < SNAP_PX:
		out.y = 0
	if absf(out.x + size.x - view.x) < SNAP_PX:
		out.x = view.x - size.x
	if absf(out.y + size.y - view.y) < SNAP_PX:
		out.y = view.y - size.y
	var centered: float = (view.x - size.x) * 0.5
	if absf(out.x - centered) < SNAP_PX:
		out.x = centered
	return out


func to_dict() -> Dictionary:
	return {
		"x": position.x,
		"y": position.y,
		"w": size.x,
		"h": expanded_height if collapsed else size.y,
		"collapsed": collapsed,
	}


func apply_dict(d: Dictionary) -> void:
	position = Vector2(float(d["x"]), float(d["y"]))
	size = Vector2(float(d["w"]), float(d["h"]))
	expanded_height = size.y
	collapsed = false
	if bool(d.get("collapsed", false)):
		set_collapsed(true)
	_layout_content()
