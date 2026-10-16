extends Node2D
## M2 demo: 2D schematic + HUD + keyboard driving of the player train (T2.2–T2.4).
## Game layer glue: builds the world from ContentDB, steps it from SimClock, turns input
## into Commands and forwards core events to EventBus.

const SCENARIO: StringName = &"polygon_free_drive"
const ZOOM_STEP: float = 1.15

var world: SimWorld
var follow: bool = true

@onready var map: TrackMap2D = $TrackMap
@onready var camera: Camera2D = $Camera
@onready var hud: DriverHud = $HudLayer/Hud


func _ready() -> void:
	world = ContentDB.build_world(SCENARIO)
	if world == null:
		push_error("demo: cannot build scenario %s" % SCENARIO)
		return
	var route: Dictionary = ContentDB.get_entry(
		&"route", StringName(str(ContentDB.get_entry(&"scenario", SCENARIO)["route"]))
	)
	map.setup(world, RouteGeometry.from_dict(route["geometry"]), route["stations"])
	map.switch_clicked.connect(_on_switch_clicked)
	hud.world = world
	camera.zoom = Vector2(0.6, 0.6)
	SimClock.step.connect(_on_sim_step)
	hud.push_event("Сценарій: %s" % ContentDB.get_entry(&"scenario", SCENARIO)["name_uk"])


func _on_sim_step(_dt: float, _tick: int) -> void:
	for e: Dictionary in world.step():
		EventBus.sim_event.emit(e)
		hud.push_event(_describe(e))


func _process(_delta: float) -> void:
	if world != null and follow:
		camera.position = map.track_point(world.player().head)


func _command(cmd: Dictionary) -> void:
	if not world.apply_command(cmd):
		hud.push_event("Команду відхилено: %s" % cmd["type"])


func _on_switch_clicked(node_id: StringName) -> void:
	var n: TrackNode = world.graph.get_node_by_id(node_id)
	var to_diverging: bool = n.state == TrackNode.SwitchState.STRAIGHT
	if world.apply_command(Commands.switch_set(node_id, to_diverging)):
		hud.push_event("Стрілка %s → %s" % [node_id, "на бічний" if to_diverging else "прямо"])
	else:
		hud.push_event("Стрілка %s замкнена під поїздом" % node_id)


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= ZOOM_STEP
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom /= ZOOM_STEP
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		follow = false
		camera.position -= mm.relative / camera.zoom
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or world == null:
		return
	var p: StringName = world.player_train_id
	match key.keycode:
		KEY_W:
			_command(Commands.controller_step(p, 1))
		KEY_S:
			_command(Commands.controller_step(p, -1))
		KEY_Q:
			_command(Commands.brake_valve_step(p, -1))
		KEY_E:
			_command(Commands.brake_valve_step(p, 1))
		KEY_BACKSPACE:
			_command(Commands.brake_valve_set(p, "VI"))
		KEY_R:
			var next: int = {1: 0, 0: -1, -1: 1}[world.player().reverser]
			_command(Commands.reverser_set(p, next))
		KEY_1:
			_on_switch_clicked(&"sw_b_west")
		KEY_2:
			_on_switch_clicked(&"sw_b_east")
		KEY_P:
			hud.paused = not hud.paused
			SimClock.set_paused(hud.paused)
		KEY_T:
			var scales: Array[float] = SimConfig.TIME_SCALES
			hud.time_scale = scales[(scales.find(hud.time_scale) + 1) % scales.size()]
			SimClock.set_time_scale(hud.time_scale)
		KEY_F:
			follow = not follow


func _describe(e: Dictionary) -> String:
	match e["type"]:
		&"wheel_slip":
			return "⚠ Боксування!"
		&"buffer_stop_collision":
			return (
				"✖ Зіткнення з упором на %.0f км/год" % Units.ms_to_kmh(absf(float(e["speed_ms"])))
			)
		&"end_of_track":
			return "Кінець колії"
		&"switch_trailed":
			return "✖ Взріз стрілки %s (ПТЕ)" % e["node"]
	return str(e["type"])
