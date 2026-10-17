extends SceneTree
var errors: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)


func _run() -> void:
	root.get_node("Settings").set_value("audio", "auto_announcements", false)
	change_scene_to_file("res://scenes/drive.tscn")
	await process_frame
	while current_scene == null:
		await process_frame
	var scene: Node = current_scene
	var world: SimWorld = scene.get("world")
	var sound: Node = scene.get("audio")
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	var skips_before: int = (
		(sound.get("_joint_playback") as AudioStreamGeneratorPlayback).get_skips()
	)
	for i: int in 60:
		world.player().speed_ms = minf(40, float(i))
		await process_frame
		OS.delay_msec(350 if i % 4 == 0 else 55)
	var skips_after: int = (
		(sound.get("_joint_playback") as AudioStreamGeneratorPlayback).get_skips()
	)
	print("JOINT_UNDERRUNS ", skips_before, " -> ", skips_after)
	check(skips_after <= skips_before + 1, "audio worker survives 350ms render stalls")
	check((sound.get("_clack") as AudioStreamPlayer).playing, "continuous wheel rhythm")
	for control: StringName in [&"horn", &"whistle"]:
		var player: AudioStreamPlayer = sound.get("_" + str(control))
		var stream: AudioStreamWAV = player.stream
		check(
			stream.format == AudioStreamWAV.FORMAT_16_BITS, "signals use exact PCM loop boundaries"
		)
		check(
			stream.loop_end == roundi(stream.get_length() * stream.mix_rate),
			"loop spans the complete sustain, independent of import compression"
		)
		var signal_bus: int = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(signal_bus, "SignalQA")
		var signal_record := AudioEffectRecord.new()
		signal_record.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(signal_bus, signal_record)
		player.bus = "SignalQA"
		signal_record.set_recording_active(true)
		scene.call("_command", Commands.cab_control(world.player_train_id, control, true))
		for period: int in 16:
			await create_timer(.2).timeout
			check(player.playing, "held signal stays active through multiple complete loops")
		signal_record.set_recording_active(false)
		signal_record.get_recording().save_to_wav("/tmp/train-held-" + str(control) + ".wav")
		scene.call("_command", Commands.cab_control(world.player_train_id, control, false))
		await create_timer(.12).timeout
		check(player.playing, "released signal continues during fade")
		var gain: float = db_to_linear(player.volume_db)
		check(gain > 0.0 and gain < .38, "signal gain declines")
		scene.call("_command", Commands.cab_control(world.player_train_id, control, true))
		await create_timer(.08).timeout
		check(db_to_linear(player.volume_db) > gain, "repress recovers gain")
		scene.call("_command", Commands.cab_control(world.player_train_id, control, false))
		await create_timer(.65).timeout
		check(not player.playing, "signal stops after release tail")
		player.bus = "TrainMix"
		AudioServer.remove_bus(signal_bus)
	recorder.set_recording_active(false)
	var recording: AudioStreamWAV = recorder.get_recording()
	check(recording.data.size() > 44100 * 4, "audio captured during frame stalls")
	recording.save_to_wav("/tmp/train-audio-output.wav")
	var announcer: Node = scene.get("announcer")
	announcer.call("repeat")
	await create_timer(.25).timeout
	check(
		(announcer.get("_player") as AudioStreamPlayer).stream != null,
		"offline station voice loads"
	)
	print("AUDIO_QA ", "PASS" if errors.is_empty() else "FAIL", " bytes=", recording.data.size())
	quit(0 if errors.is_empty() else 1)
