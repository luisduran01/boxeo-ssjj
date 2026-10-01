class_name BoxingAudio
extends Node

var player: AudioStreamPlayer


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "SFX"
	add_child(player)


func play_cue(cue: String) -> void:
	var frequency: float = float({"bell": 920.0, "jab": 150.0, "hook": 105.0, "uppercut": 82.0, "block": 235.0, "ko": 58.0}.get(cue, 125.0))
	var duration := 0.34 if cue == "bell" else 0.075
	var sample_rate := 22050
	var data := PackedByteArray()
	data.resize(int(duration * sample_rate) * 2)
	for i in range(int(duration * sample_rate)):
		var envelope := 1.0 - float(i) / (duration * sample_rate)
		var value := int(sin(TAU * frequency * float(i) / sample_rate) * envelope * 9000.0)
		data.encode_s16(i * 2, value)
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = sample_rate
	wave.data = data
	player.stream = wave
	player.play()
