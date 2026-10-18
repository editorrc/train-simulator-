class_name CachedCanvas
extends SubViewportContainer
## Keeps a heavy hand-drawn panel (desk, track map, charts) in its own texture.
## The panel is re-recorded and re-rendered at most `max_fps` times a second, plus at once
## after a click on it; in every other frame the screen shows the cached texture with a
## single draw call. Without this, the desk alone cost ~300 draw calls per frame, which is
## expensive on macOS (OpenGL over Metal, GL Compatibility renderer).
##
## The content keeps its own logic and input: mouse events reach it through the container.
## It must not call queue_redraw() every frame itself (set its `auto_redraw` to false).
## If it has `state_key() -> int` (a hash of what it shows, quantised to what the eye can
## see), the texture is refreshed only when that key changes: a train standing still costs
## nothing. Without a key, or once a second as a safety net, it refreshes by time alone.

var content: Control
var max_fps: float = 30.0
var _viewport: SubViewport
var _since: float = 0.0
var _last_key: int = 0


func _init(p_content: Control, p_max_fps: float = 30.0) -> void:
	content = p_content
	max_fps = p_max_fps
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	if "auto_redraw" in content:
		content.set("auto_redraw", false)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(content)
	resized.connect(refresh)
	visibility_changed.connect(refresh)
	gui_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				refresh.call_deferred()
	)


func _process(delta: float) -> void:
	_since += delta
	if not is_visible_in_tree() or _since < 1.0 / max_fps:
		return
	if content.has_method("state_key") and _since < 1.0:
		var key: int = content.call("state_key")
		if key == _last_key:
			return
		_last_key = key
	refresh()


## Redraw now (after input, resize or a state change the user should see at once).
func refresh() -> void:
	_since = 0.0
	if content == null or _viewport == null:
		return
	content.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## A mouse release outside the panel would never enter the sub-viewport; forward it so a
## held control (whistle, horn) always ends.
func _input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and not mb.pressed and not get_global_rect().has_point(mb.position):
		_viewport.push_input(mb, true)
