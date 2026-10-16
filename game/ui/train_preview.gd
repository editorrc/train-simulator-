class_name TrainPreview
extends Control
## Menu preview: a head car and a motor car on a short piece of track under the wire.

var head: VehicleSpec
var motor: VehicleSpec
var livery: Dictionary = {}
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if head == null or livery.is_empty():
		return
	var length: float = head.length_m + motor.length_m + 0.8
	var ppm: float = minf(size.x / (length + 6.0), size.y / 8.5)
	var rail := Vector2((size.x - length * ppm) * 0.5, size.y - 1.0 * ppm)
	draw_rect(Rect2(0, rail.y, size.x, 0.2 * ppm), Color("8f9497"))
	var k: int = 0
	var x: float = 0.0
	while x < size.x:
		draw_rect(Rect2(x, rail.y + 0.2 * ppm, 0.26 * ppm, 0.2 * ppm), Color("62615c"))
		x += 0.55 * ppm
		k += 1
	draw_line(
		Vector2(0, rail.y - 6.0 * ppm), Vector2(size.x, rail.y - 6.0 * ppm), Color("3b332c"), 2.0
	)
	var panto: float = clampf(0.5 + 0.5 * sin(_t * 0.8), 0.0, 1.0)
	var opts: Dictionary = {
		"lead_right": true, "panto_top": 6.0, "headlights": true, "cab_right": false, "panto": panto
	}
	draw_set_transform(rail, 0.0, Vector2(ppm, ppm))
	TrainPainter.draw_car(self, motor, livery, opts)
	draw_set_transform(rail + Vector2((motor.length_m + 0.8) * ppm, 0), 0.0, Vector2(ppm, ppm))
	var hopts: Dictionary = opts.duplicate()
	hopts["cab_right"] = true
	hopts["panto"] = -1.0
	TrainPainter.draw_car(self, head, livery, hopts)
	draw_set_transform(rail + Vector2(motor.length_m * ppm, 0), 0.0, Vector2(ppm, ppm))
	TrainPainter.draw_gangway(self, 0.0, 0.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
