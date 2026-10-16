class_name UiLayout
extends RefCounted
## Remembers where the player put each floating panel (user://ui_layout.cfg).

const PATH: String = "user://ui_layout.cfg"


static func save(panels: Array[FloatingPanel]) -> void:
	var cfg := ConfigFile.new()
	for p: FloatingPanel in panels:
		cfg.set_value("panels", p.panel_id, p.to_dict())
	cfg.save(PATH)


## Applies saved rectangles; returns false if there was nothing saved (use defaults).
static func restore(panels: Array[FloatingPanel], view: Vector2) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	var any: bool = false
	for p: FloatingPanel in panels:
		var d: Variant = cfg.get_value("panels", p.panel_id, null)
		if d is Dictionary:
			p.apply_dict(d as Dictionary)
			p.position = p.position.clamp(Vector2(-p.size.x + 60, 0), view - Vector2(60, 26))
			any = true
	return any


static func clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
