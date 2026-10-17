extends TestCase


func test_pcm_loop_length_counts_frames_and_channels() -> void:
	for stereo: bool in [false, true]:
		var stream := AudioStreamWAV.new()
		stream.stereo = stereo
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var pcm := PackedByteArray()
		pcm.resize(22050 * 2 * (2 if stereo else 1))
		stream.data = pcm
		RecordedStream.configure_loop(stream, true)
		assert_eq(stream.loop_end, 22050)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)


func test_compressed_loop_does_not_use_compressed_byte_count() -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_IMA_ADPCM
	var encoded := PackedByteArray()
	encoded.resize(1024)
	stream.data = encoded
	RecordedStream.configure_loop(stream, true)
	assert_eq(stream.loop_end, roundi(stream.get_length() * stream.mix_rate))
	assert_true(
		stream.loop_end > encoded.size() / 2, "compressed size cannot shorten a held signal"
	)


func test_one_shots_remain_unlooped() -> void:
	var stream := AudioStreamWAV.new()
	RecordedStream.configure_loop(stream, false)
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)
