class_name RecordedStream
extends RefCounted
## AudioStreamWAV.data is compressed for QOA/ADPCM; loop offsets always count PCM frames.


static func configure_loop(stream: AudioStreamWAV, enabled: bool) -> void:
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
