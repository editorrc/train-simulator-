class_name EventLogView
extends Control
## Scrolling log of what happened (events, rejected commands with reasons).

const MAX_LINES: int = 40

var _lines: Array[Dictionary] = []


func push(text: String, level: String = "info") -> void:
	_lines.append({"text": text, "level": level})
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var rows: int = int(size.y / 17.0)
	var from: int = maxi(0, _lines.size() - rows)
	var y: float = 15.0
	for i: int in range(from, _lines.size()):
		var l: Dictionary = _lines[i]
		var col: Color = (
			{"info": Color("cfe3d8"), "warn": Color("ffd36a"), "bad": Color("ff8b7d")}
			. get(str(l["level"]), Color.WHITE)
		)
		draw_string(
			font, Vector2(6, y), str(l["text"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 10, 13, col
		)
		y += 17.0
