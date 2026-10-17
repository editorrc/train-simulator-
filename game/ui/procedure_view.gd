class_name ProcedureView
extends Control
## Startup checklist from cab.json: done steps ticked, the next step highlighted with a hint.

var world: SimWorld
var steps: Array = []


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var font: Font = get_theme_default_font()
	var t: Train = world.player()
	var y: float = 18.0
	var next_found: bool = false
	for s: Variant in steps:
		var sd: Dictionary = s
		var done: bool = t.check(str(sd["check"]))
		var is_next: bool = not done and not next_found
		if is_next:
			next_found = true
			draw_rect(Rect2(2, y - 14, size.x - 4, 20), Color(0.95, 0.75, 0.25, 0.16))
		var mark: String = "✓" if done else ("▶" if is_next else "·")
		var col: Color = (
			Color("57e38a") if done else (Color("ffd36a") if is_next else Color("9fb3aa"))
		)
		draw_string(font, Vector2(8, y), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		draw_string(
			font,
			Vector2(28, y),
			str(sd["label_uk"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 34,
			14,
			col
		)
		y += 20.0
		if is_next and sd.has("hint_uk"):
			var hint: String = str(sd["hint_uk"])
			var width: float = maxf(size.x - 40.0, 1.0)
			var est: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var lines: int = mini(3, 1 + int(est / width))
			draw_multiline_string(
				font, Vector2(28, y), hint, HORIZONTAL_ALIGNMENT_LEFT, width, 12, 3, Color("dfe8e3")
			)
			y += 16.0 * lines + 2.0
	if not next_found:
		draw_string(
			font,
			Vector2(8, y + 6),
			tr("Поїзд готовий. Кран у II; наберіть позицію контролера."),
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 16,
			13,
			Color("57e38a")
		)
