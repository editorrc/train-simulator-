class_name RecordedStream
extends RefCounted
## AudioStreamWAV.data is compressed for QOA/ADPCM; loop offsets always count PCM frames.


## A loop start stored in the WAV 'smpl' chunk (held signals: the attack plays once, see
## tools/prepare_audio_loops.py) is kept; the loop always ends at the last frame.
static func configure_loop(stream: AudioStreamWAV, enabled: bool) -> void:
	var detected: bool = stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
	stream.loop_begin = stream.loop_begin if detected else 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
