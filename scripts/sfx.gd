## Sound effects. Each is a tiny procedural placeholder. To replace one, drop
## a file with the same name (ogg / wav / mp3) into res://assets/audio/sfx/
## (both modes) or res://assets/audio/sfx/horror/ (Horror only), or a FOLDER
## with that name holding several takes (one is picked at random each time).
## Supplied recordings live in such folders (explosion/, impact/, footsteps/wood/ ...).
## Lookup in Horror: sfx/horror/<name> -> sfx/<name> -> built-in horror
## placeholder -> built-in normal placeholder (played lower and slower).
extends Node

const RATE := 22050
const SFX_DIR := "res://assets/audio/sfx/"
var _streams := {}
var _horror := {}       # built-in horror variants
var _over := {}         # "normal" / "horror" -> {name: replacement}
var _players: Array[AudioStreamPlayer] = []
var _started := {}      # player -> time it started (the oldest one is reused when all are busy)
const EXTS := ["ogg", "wav", "mp3"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 28:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_streams["place"] = _tone(0.09, 420.0, 260.0, 0.5, 0.0, 0.1)
	_streams["fuse"] = _tone(0.04, 1500.0, 1400.0, 0.2, 0.0, 0.4)
	_streams["confetti"] = _confetti()
	_streams["concussion"] = _concat([_bonk(), _samples(0.05, 0.0, 0.0, 0.0, 0.0, 0.0),
		_samples(0.09, 2300.0, 3100.0, 0.25, 35.0, 0.0), _samples(0.04, 0.0, 0.0, 0.0, 0.0, 0.0),
		_samples(0.09, 2400.0, 3300.0, 0.25, 35.0, 0.0), _samples(0.12, 2600.0, 2000.0, 0.22, 30.0, 0.0)])
	_streams["steal"] = _tone(0.05, 1300.0, 1600.0, 0.25, 0.0, 0.15)
	_streams["pickup"] = _concat([_samples(0.07, 660.0, 660.0, 0.4, 0.0, 0.0), _samples(0.1, 990.0, 990.0, 0.4, 0.0, 0.0)])
	_streams["curse"] = _concat([_samples(0.18, 400.0, 340.0, 0.4, 7.0, 0.0), _samples(0.3, 330.0, 220.0, 0.4, 7.0, 0.0)])
	_streams["squeak"] = _tone(0.13, 1100.0, 1750.0, 0.5, 28.0, 0.0)
	_streams["bump"] = _tone(0.09, 700.0, 520.0, 0.4, 0.0, 0.05)
	_streams["kick"] = _tone(0.08, 220.0, 120.0, 0.6, 0.0, 0.3)
	_streams["boing"] = _tone(0.25, 300.0, 600.0, 0.45, 18.0, 0.0)
	_streams["prox_armed"] = _concat([_samples(0.06, 900.0, 900.0, 0.3, 0.0, 0.0), _samples(0.09, 1350.0, 1350.0, 0.3, 0.0, 0.0)])
	_streams["prox_alert"] = _concat([_samples(0.05, 1800.0, 1800.0, 0.4, 0.0, 0.0), _samples(0.05, 1800.0, 1800.0, 0.0, 0.0, 0.0), _samples(0.05, 1800.0, 1800.0, 0.4, 0.0, 0.0)])
	_streams["pop"] = _tone(0.07, 620.0, 300.0, 0.5, 0.0, 0.0)
	_streams["menu"] = _tone(0.04, 900.0, 1100.0, 0.3, 0.0, 0.0)
	_streams["tick"] = _tone(0.08, 880.0, 880.0, 0.35, 0.0, 0.0)
	_streams["go"] = _concat([_samples(0.08, 660.0, 660.0, 0.4, 0.0, 0.0), _samples(0.08, 880.0, 880.0, 0.4, 0.0, 0.0), _samples(0.2, 1320.0, 1320.0, 0.4, 6.0, 0.0)])
	_streams["shuffle"] = _tone(0.6, 250.0, 950.0, 0.3, 9.0, 0.35)
	_streams["immortal"] = _concat([_samples(0.1, 784.0, 784.0, 0.35, 0.0, 0.0), _samples(0.1, 988.0, 988.0, 0.35, 0.0, 0.0), _samples(0.25, 1568.0, 1568.0, 0.3, 8.0, 0.0)])
	_streams["victory"] = _concat([_samples(0.14, 523.0, 523.0, 0.4, 0.0, 0.0), _samples(0.14, 659.0, 659.0, 0.4, 0.0, 0.0), _samples(0.14, 784.0, 784.0, 0.4, 0.0, 0.0), _samples(0.4, 1046.0, 1046.0, 0.4, 5.0, 0.0)])
	# Doom Duck Parade
	_streams["portal"] = _concat([_samples(0.5, 200.0, 1200.0, 0.3, 14.0, 0.25), _samples(0.25, 1200.0, 900.0, 0.2, 20.0, 0.1)])
	_streams["clock_tick"] = _tone(0.025, 2600.0, 2200.0, 0.35, 0.0, 0.6)
	_streams["quack"] = _wav(_quack(0.2, 330.0))
	_streams["duckling_quack"] = _wav(_quack(0.11, 560.0))
	_streams["duck_warning"] = _tone(0.06, 1760.0, 1760.0, 0.3, 0.0, 0.0)
	_streams["duck_confetti"] = _concat([_quack(0.16, 300.0), _confetti_samples(0.9)])
	# Crane chair drop
	_streams["crane"] = _concat([_samples(0.35, 140.0, 118.0, 0.35, 5.0, 0.3), _samples(0.35, 150.0, 112.0, 0.3, 6.0, 0.35)])
	_streams["chair_thud"] = _concat([_bonk(), _samples(0.25, 110.0, 55.0, 0.5, 0.0, 0.45)])
	# Time of Doom (closing rings) and ranking changes
	_streams["doom_warn"] = _concat([_samples(0.45, 220.0, 440.0, 0.35, 6.0, 0.1), _samples(0.45, 220.0, 440.0, 0.35, 6.0, 0.1)])
	_streams["doom_slam"] = _concat([_bonk(), _samples(0.5, 90.0, 40.0, 0.6, 2.0, 0.5)])
	_streams["overtake"] = _concat([_samples(0.07, 880.0, 880.0, 0.3, 0.0, 0.0), _samples(0.14, 1320.0, 1400.0, 0.3, 6.0, 0.0)])
	# Horror jack-in-the-box (only used in Horror)
	_streams["clown_rattle"] = _tone(0.05, 380.0, 300.0, 0.4, 0.0, 0.7)
	_streams["clown_burst"] = _concat([_samples(0.05, 1200.0, 300.0, 0.5, 0.0, 0.6), _samples(0.35, 180.0, 720.0, 0.45, 22.0, 0.0)])
	_streams["clown_laugh"] = _wav(_cackle())
	_streams["clown_hammer"] = _concat([_bonk(), _samples(0.04, 0.0, 0.0, 0.0, 0.0, 0.0), _samples(0.3, 140.0, 60.0, 0.6, 0.0, 0.55)])
	_streams["rip"] = _tone(0.16, 900.0, 300.0, 0.4, 40.0, 0.85)   # fabric tearing
	_streams["growl"] = _concat([_samples(0.12, 95.0, 120.0, 0.45, 26.0, 0.55), _samples(0.45, 120.0, 85.0, 0.5, 22.0, 0.6)])
	_streams["taunt"] = _concat([_samples(0.07, 700.0, 1100.0, 0.35, 0.0, 0.0), _samples(0.07, 900.0, 1300.0, 0.35, 0.0, 0.0), _samples(0.12, 800.0, 1500.0, 0.35, 12.0, 0.0)])
	_streams["mode"] = _concat([_samples(0.08, 784.0, 784.0, 0.35, 0.0, 0.0), _samples(0.08, 988.0, 988.0, 0.35, 0.0, 0.0), _samples(0.2, 1175.0, 1175.0, 0.3, 6.0, 0.0)])
	_build_horror()
	_over = {"normal": _scan(SFX_DIR), "horror": _scan(SFX_DIR + "horror/")}


## Replacements in `dir`: name -> [streams]. "<name>.ogg" files and "<name>/"
## folders of takes (nested folders give names like "footsteps/wood").
func _scan(dir: String, prefix := "") -> Dictionary:
	var out := {}
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var seen := {}
	for f in (d.get_files() if prefix == "" else PackedStringArray()):   # sub-folders are take-sets
		# exported games list imported files as "x.wav.import" / ".remap"
		var file := f.trim_suffix(".import").trim_suffix(".remap")
		if not file.get_extension().to_lower() in EXTS or seen.has(file):
			continue
		seen[file] = true
		var s = _load(dir + file)
		if s != null:
			var key := prefix + file.get_basename()
			out[key] = (out.get(key, []) as Array) + [s]
	for sub in d.get_directories():
		if prefix == "" and sub == "horror":
			continue
		var takes := []
		var sd := DirAccess.open(dir + sub)
		var names := sd.get_files()
		names.sort()
		for f in names:
			var file := f.trim_suffix(".import").trim_suffix(".remap")
			if file.get_extension().to_lower() in EXTS and not takes.any(func(t): return t.resource_path == dir + sub + "/" + file):
				var s = _load(dir + sub + "/" + file)
				if s != null:
					takes.append(s)
		if not takes.is_empty():
			out[prefix + sub] = takes
		out.merge(_scan(dir + sub + "/", prefix + sub + "/"))
	return out


func _load(path: String):
	if ResourceLoader.exists(path):
		return load(path)
	return null


## True if a recording (not just a placeholder) exists for `sound`.
func has_recording(sound: String) -> bool:
	return _over["normal"].has(sound) or (Settings.mode == "horror" and _over["horror"].has(sound))


## Darker built-in variants for Horror mode.
func _build_horror() -> void:
	_horror["taunt"] = _wav(_chuckle())
	_horror["confetti"] = _wav(_splat(0.5))
	_horror["duck_confetti"] = _concat([_quack(0.2, 180.0), _splat(0.9)])
	_horror["concussion"] = _concat([_bonk(), _samples(0.08, 0.0, 0.0, 0.0, 0.0, 0.0), _samples(0.35, 900.0, 500.0, 0.3, 6.0, 0.45)])
	_horror["pickup"] = _concat([_samples(0.1, 330.0, 330.0, 0.4, 0.0, 0.0), _samples(0.18, 311.0, 311.0, 0.4, 4.0, 0.0)])
	_horror["victory"] = _concat([_samples(0.25, 440.0, 440.0, 0.4, 0.0, 0.0), _samples(0.25, 415.0, 415.0, 0.4, 0.0, 0.0), _samples(0.25, 392.0, 392.0, 0.4, 0.0, 0.0), _samples(0.6, 370.0, 370.0, 0.4, 5.0, 0.0)])
	_horror["mode"] = _concat([_samples(0.5, 110.0, 70.0, 0.5, 3.0, 0.2), _samples(0.4, 233.0, 220.0, 0.25, 8.0, 0.3)])
	_horror["steal"] = _wav(_splat(0.08))
	_horror["growl"] = _concat([_samples(0.15, 70.0, 85.0, 0.5, 30.0, 0.65), _samples(0.6, 85.0, 50.0, 0.55, 25.0, 0.7)])


## A frantic, wobbling "HA-HA-HA-HA-HEE": rising, out-of-tune, breathy.
func _cackle() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in 7:
		var f := 330.0 + k * 38.0 + (60.0 if k % 2 == 0 else -20.0)
		out.append_array(_samples(0.085, f * 1.15, f * 0.8, 0.42, 30.0, 0.35))
		out.append_array(_samples(0.035, 0.0, 0.0, 0.0, 0.0, 0.0))
	out.append_array(_samples(0.4, 760.0, 1300.0, 0.38, 40.0, 0.3))
	return out


## A low, breathy "heh heh heh".
func _chuckle() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in 3:
		out.append_array(_samples(0.11, 150.0 - k * 12.0, 110.0, 0.4, 0.0, 0.55))
		out.append_array(_samples(0.05, 0.0, 0.0, 0.0, 0.0, 0.0))
	return out


## A wet, muffled splat.
func _splat(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.05 + 0.1 * (1.0 - k))
		var drip := 0.0
		if randf() < 0.004 * (1.0 - k):
			drip = randf_range(-0.6, 0.6)
		out[i] = (lp * 2.2 * pow(1.0 - k, 2.5) + drip) * 0.6
	return out


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	var s = null
	if Settings.mode == "horror":
		s = _over["horror"].get(sound)
		if s == null:
			s = _over["normal"].get(sound)
		if s == null:
			s = _horror.get(sound)
		if s == null:
			s = _streams.get(sound)
			pitch *= 0.8  # borrowed cheerful placeholder, slowed into something worse
	else:
		s = _over["normal"].get(sound, _streams.get(sound))
	if s is Array:
		s = s[randi() % s.size()]
	if s == null:
		return
	var use: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			use = p
			break
	if use == null:   # all busy: cut the oldest (usually a long explosion tail)
		use = _players[0]
		for p in _players:
			if _started.get(p, 0) < _started.get(use, 0):
				use = p
	use.stream = s
	use.pitch_scale = clampf(pitch, 0.3, 3.0)
	use.volume_db = volume_db
	use.play()
	_started[use] = Time.get_ticks_msec()


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


## Cartoon "BONK": a hollow wood-block knock with a falling pitch.
func _bonk() -> PackedFloat32Array:
	var n := int(0.16 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(820.0, 380.0, pow(k, 0.5)) / RATE
		out[i] = (sin(ph) * 0.8 + sin(ph * 2.7) * 0.25) * pow(1.0 - k, 3.0) * 0.7
	return out


## A nasal, buzzy toy quack: square-ish wave with a pitch dip, two humps.
func _quack(dur: float, f: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * f * (1.0 + 0.25 * sin(k * PI) - 0.3 * k) / RATE
		var w := signf(sin(ph)) * 0.5 + sin(ph * 3.0) * 0.3 + sin(ph * 5.0) * 0.15
		var env := minf(1.0, k * 25.0) * (1.0 - k) * (0.7 + 0.3 * sin(k * TAU * 2.0))
		out[i] = w * env * 0.35
	return out


## A party-popper: a sharp pop followed by papery crackle.
func _confetti() -> AudioStreamWAV:
	return _wav(_confetti_samples(0.5))


func _confetti_samples(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(300.0, 90.0, k) / RATE
		var pop := sin(ph) * pow(maxf(0.0, 1.0 - k * 6.0), 2.0)
		var crackle := 0.0
		if randf() < 0.05 * (1.0 - k):
			crackle = randf_range(-1.0, 1.0)
		var hiss := randf_range(-1.0, 1.0) * 0.25 * pow(1.0 - k, 2.0)
		out[i] = (pop * 0.8 + crackle * 0.6 + hiss) * 0.55
	return out


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
