extends Node
class_name SoundManager
## Harici ses dosyası zorunluluğu olmadan 16-bit PCM AudioStreamWAV üreten prosedürel ses motoru.

const SAMPLE_RATE: int = 22050
const PLAYER_POOL_SIZE: int = 6
const SOUNDS_DIR: String = "res://assets/sounds/"

var sound_enabled: bool = true
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}


func _ready() -> void:
	for i: int in range(PLAYER_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)

	_initialize_sound_bank()


func _initialize_sound_bank() -> void:
	_register_sound("select", _generate_tone_sequence([520.0, 760.0], [0.04, 0.05], 0.35))
	_register_sound("blocked", _generate_tone_sequence([160.0, 125.0], [0.07, 0.09], 0.40, true))
	_register_sound("place", _generate_tone_sequence([420.0], [0.05], 0.28))
	_register_sound("match", _generate_tone_sequence([523.25, 659.25, 783.99, 1046.50], [0.06, 0.06, 0.06, 0.14], 0.38))
	_register_sound("undo", _generate_tone_sequence([620.0, 440.0], [0.05, 0.06], 0.30))
	_register_sound("hint", _generate_tone_sequence([587.33, 880.0, 1174.66], [0.05, 0.05, 0.11], 0.34))
	_register_sound("shuffle", _generate_tone_sequence([330.0, 440.0, 392.0, 523.25, 659.25], [0.035, 0.035, 0.035, 0.035, 0.08], 0.34))
	_register_sound("button", _generate_tone_sequence([600.0], [0.035], 0.25))
	_register_sound("win", _generate_tone_sequence([523.25, 659.25, 783.99, 1046.50, 1318.51], [0.08, 0.08, 0.08, 0.10, 0.22], 0.40))
	_register_sound("lose", _generate_tone_sequence([392.0, 349.23, 311.13, 261.63], [0.10, 0.10, 0.10, 0.22], 0.38, true))


func _register_sound(sound_name: String, fallback_stream: AudioStreamWAV) -> void:
	var wav_path: String = SOUNDS_DIR + sound_name + ".wav"
	var ogg_path: String = SOUNDS_DIR + sound_name + ".ogg"
	if ResourceLoader.exists(wav_path):
		_streams[sound_name] = load(wav_path)
	elif ResourceLoader.exists(ogg_path):
		_streams[sound_name] = load(ogg_path)
	else:
		_streams[sound_name] = fallback_stream


func play_sfx(sound_name: String) -> void:
	if not sound_enabled or not _streams.has(sound_name):
		return

	var stream: AudioStream = _streams[sound_name]
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			player.stream = stream
			player.play()
			return

	_players[0].stream = stream
	_players[0].play()


func _generate_tone_sequence(freqs: Array[float], durations: Array[float], volume: float, add_harmonics: bool = false) -> AudioStreamWAV:
	var total_samples: int = 0
	var note_sample_counts: Array[int] = []

	for dur: float in durations:
		var count: int = int(dur * float(SAMPLE_RATE))
		note_sample_counts.append(count)
		total_samples += count

	var pcm_bytes: PackedByteArray = PackedByteArray()
	pcm_bytes.resize(total_samples * 2)

	var byte_index: int = 0
	var phase: float = 0.0

	for n_idx: int in range(freqs.size()):
		var freq: float = freqs[n_idx]
		var sample_count: int = note_sample_counts[n_idx]
		var attack_samples: int = maxi(1, int(float(sample_count) * 0.12))

		for s: int in range(sample_count):
			var env: float = 1.0
			if s < attack_samples:
				env = float(s) / float(attack_samples)
			else:
				var decay_progress: float = float(s - attack_samples) / float(maxi(1, sample_count - attack_samples))
				env = 1.0 - decay_progress * 0.85

			phase += TAU * freq / float(SAMPLE_RATE)
			var wave: float = sin(phase)
			if add_harmonics:
				wave = (wave * 0.65) + (sin(phase * 2.0) * 0.25) + (sin(phase * 3.0) * 0.10)

			var sample_val: int = int(clampf(wave * env * volume, -1.0, 1.0) * 32767.0)
			pcm_bytes[byte_index] = sample_val & 0xFF
			pcm_bytes[byte_index + 1] = (sample_val >> 8) & 0xFF
			byte_index += 2

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm_bytes
	return stream