## Tiny procedural placeholder sounds. Drop an .ogg or .wav with the same name
## into res://assets/audio/ to replace one (e.g. assets/audio/squeak.ogg).
extends Node

const RATE := 22050
var _streams := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["squeak"] = _tone(0.13, 1100.0, 1750.0, 0.5, 28.0, 0.0)
	_streams["bump"] = _tone(0.09, 700.0, 520.0, 0.4, 0.0, 0.05)
	_streams["boom"] = _boom()
	_streams["pop"] = _tone(0.07, 620.0, 300.0, 0.5, 0.0, 0.0)
	_streams["stun"] = _tone(0.4, 520.0, 170.0, 0.45, 11.0, 0.0)
	_streams["steal"] = _tone(0.05, 1300.0, 1600.0, 0.25, 0.0, 0.15)
	_streams["pickup"] = _concat([_samples(0.07, 660.0, 660.0, 0.4, 0.0, 0.0), _samples(0.1, 990.0, 990.0, 0.4, 0.0, 0.0)])
	_streams["tick"] = _tone(0.08, 880.0, 880.0, 0.35, 0.0, 0.0)
	_streams["go"] = _concat([_samples(0.08, 660.0, 660.0, 0.4, 0.0, 0.0), _samples(0.08, 880.0, 880.0, 0.4, 0.0, 0.0), _samples(0.2, 1320.0, 1320.0, 0.4, 6.0, 0.0)])
	_streams["shuffle"] = _tone(0.6, 250.0, 950.0, 0.3, 9.0, 0.35)
	_streams["boing"] = _tone(0.25, 300.0, 600.0, 0.45, 18.0, 0.0)
	_streams["fanfare"] = _concat([_samples(0.14, 523.0, 523.0, 0.4, 0.0, 0.0), _samples(0.14, 659.0, 659.0, 0.4, 0.0, 0.0), _samples(0.14, 784.0, 784.0, 0.4, 0.0, 0.0), _samples(0.4, 1046.0, 1046.0, 0.4, 5.0, 0.0)])
	for n in _streams.keys():
		for ext in ["ogg", "wav"]:
			var path := "res://assets/audio/%s.%s" % [n, ext]
			if ResourceLoader.exists(path):
				_streams[n] = load(path)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	var s = _streams.get(sound)
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = clampf(pitch, 0.3, 3.0)
			p.volume_db = volume_db
			p.play()
			return


func _samples(dur: float, f0: float, f1: float, vol: float, vibrato: float, noise: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		var f := lerpf(f0, f1, k) * (1.0 + 0.06 * sin(TAU * vibrato * i / RATE))
		phase += TAU * f / RATE
		var env := minf(1.0, k * 30.0) * pow(1.0 - k, 1.5)
		var v := sin(phase) * 0.8 + sin(phase * 2.0) * 0.15
		v = v * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		out[i] = v * env * vol
	return out


func _boom() -> AudioStreamWAV:
	# A soft pillowy "fwump" rather than a lethal bang.
	var n := int(0.45 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.08)
		phase += TAU * lerpf(120.0, 45.0, k) / RATE
		var env := minf(1.0, k * 60.0) * pow(1.0 - k, 2.2)
		out[i] = (lp * 1.6 + sin(phase) * 0.7) * env * 0.55
	return _wav(out)


func _tone(dur: float, f0: float, f1: float, vol: float, vibrato: float, noise: float) -> AudioStreamWAV:
	return _wav(_samples(dur, f0, f1, vol, vibrato, noise))


func _concat(parts: Array) -> AudioStreamWAV:
	var all := PackedFloat32Array()
	for p in parts:
		all.append_array(p)
	return _wav(all)


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
