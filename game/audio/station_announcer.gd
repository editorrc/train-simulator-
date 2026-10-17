class_name StationAnnouncer
extends Node
## Offline Ukrainian announcements. user://announcements/<id>_{station,next}.wav overrides.

signal caption(text: String)
var world: SimWorld
var stations: Dictionary = {}
var paused: bool = false
var enabled_route: bool = false
var _player: AudioStreamPlayer
var _queue: Array[String] = []
var _names: Dictionary[String, String] = {}
var _cues := StationCues.new()
var _delay: float = 1.0
var _caption_remaining: float = 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Announcer"
	_player.volume_db = -3.0
	add_child(_player)
	for st: Variant in stations.get("stations", []):
		_names[str(st["id"])] = str(st["name_uk"])


func info() -> Dictionary:
	var t: Train = world.player()
	var head_ch: float = world.graph.chainage_at(t.head)
	var total: float = 0.0
	for seg: TrackSegment in world.graph.segments.values():
		total = maxf(total, seg.chainage_at_a_m + seg.length_m)
	var at: String = ""
	var next: String = ""
	var distance: float = INF
	for st: Variant in stations.get("stations", []):
		var platform: Dictionary = st["platforms"][0]
		var seg: TrackSegment = world.graph.get_segment(StringName(str(platform["segment"])))
		var from: float = seg.chainage_at_a_m + float(platform["from_m"])
		var to: float = seg.chainage_at_a_m + float(platform["to_m"])
		if head_ch >= from and head_ch <= to:
			at = str(st["id"])
		var d: float = fposmod(to - head_ch, total) if enabled_route else to - head_ch
		if d > .1 and d < distance and str(st["id"]) != at:
			distance = d
			next = str(st["id"])
	return {"at": at, "next": next, "distance": distance}


func route_text() -> String:
	var state: Dictionary = info()
	if str(state["at"]) != "":
		return tr("Станція: %s") % _names.get(str(state["at"]), "")
	return (
		tr("Наступна: %s · %.0f м") % [_names.get(str(state["next"]), ""), float(state["distance"])]
	)


func repeat() -> void:
	var state: Dictionary = info()
	var at: String = str(state["at"])
	enqueue(at + "_station" if at != "" else str(state["next"]) + "_next")


func enqueue(id: String) -> void:
	if id not in _queue:
		_queue.append(id)


func _process(delta: float) -> void:
	_player.stream_paused = paused
	if paused:
		return
	_delay -= delta
	if _delay > 0:
		return
	var state: Dictionary = info()
	if enabled_route and bool(Settings.get_value("audio", "auto_announcements", true)):
		for id: String in _cues.update(
			str(state["at"]), str(state["next"]), float(state["distance"])
		):
			enqueue(id)
	_caption_remaining -= delta
	if not _player.playing and _caption_remaining <= 0:
		if _queue.is_empty():
			caption.emit("")
		else:
			_play(_queue.pop_front())


func _play(id: String) -> void:
	var is_next: bool = id.ends_with("_next")
	var key: String = id.trim_suffix("_next") if is_next else id.trim_suffix("_station")
	var text: String = (
		(tr("Наступна станція — %s") if is_next else tr("Станція — %s")) % _names.get(key, key)
	)
	if id == "doors_closing":
		text = tr("Обережно! Двері зачиняються.")
	caption.emit(text)
	var stream: AudioStreamWAV
	var custom: String = "user://announcements/" + id + ".wav"
	if FileAccess.file_exists(custom):
		stream = AudioStreamWAV.load_from_file(custom)
	else:
		var path: String = "res://audio/announcements/" + id + ".wav"
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStreamWAV
	_caption_remaining = 4.0
	if stream != null:
		_player.stream = stream
		_player.play()
		_caption_remaining = stream.get_length() + .25


func is_announcing() -> bool:
	return _player.playing or _caption_remaining > 0
