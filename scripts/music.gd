## Music playlists per screen and mode, discovered automatically (no code changes):
##   assets/audio/music/menu/normal/      assets/audio/music/menu/horror/
##   assets/audio/music/gameplay/normal/  assets/audio/music/gameplay/horror/
## Loose files directly in menu/ or gameplay/ are shared by both modes.
## (mp3 / ogg / wav, imported by Godot, so they are packed into exports.)
## After exporting you can also drop mp3 / ogg files into the same sub-folders
## under music/ next to the game's .exe, or under user://music/.
## If a Horror playlist is empty, the Normal tracks play slowed down and
## detuned instead (HORROR_FALLBACK_PITCH) - nothing is invented or copied.
## Only one track ever plays: switching fades the old one out first.
extends Node

signal track_changed(title: String)

const ROOT := "res://assets/audio/music"
const SCREENS := ["menu", "gameplay"]
const MODES := ["normal", "horror"]
const EXTS := ["mp3", "ogg", "wav"]
const FADE_OUT := 0.7
const FADE_IN := 0.8
const SILENT_DB := -40.0
const HORROR_FALLBACK_PITCH := 0.82

var playlists := {}   # "menu/normal" -> [paths]
var orders := {}
var positions := {}
var context := ""     # "menu/horror" etc.
var title := ""
var player: AudioStreamPlayer
var _tween: Tween
var _switch := 0
var _source := ""     # playlist key actually used (after fallback)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	add_child(player)
	player.finished.connect(_on_finished)
	scan()


func scan() -> void:
	var ext_root := OS.get_executable_path().get_base_dir().path_join("music")
	for screen in SCREENS:
		for mode in MODES:
			var key: String = screen + "/" + mode
			playlists[key] = []
			orders[key] = []
			positions[key] = -1
			for base in [ROOT, "user://music"] + ([] if OS.has_feature("editor") else [ext_root]):
				_scan(base.path_join(screen).path_join(mode), base == ROOT, key)
				_scan(base.path_join(screen), base == ROOT, key)  # shared by both modes


func _scan(dir_path: String, imported: bool, key: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		# in exported builds imported files are listed as "song.ogg.import" / ".remap"
		var file_name := f.trim_suffix(".import").trim_suffix(".remap")
		var ext := file_name.get_extension().to_lower()
		if not ext in EXTS or (not imported and ext == "wav"):
			continue  # Godot can't decode loose wav files at runtime
		var path := dir_path.path_join(file_name)
		if not path in playlists[key]:
			playlists[key].append(path)


func _key(screen: String) -> String:
	return screen + "/" + ("horror" if Settings.mode in ["horror", "custom"] else "normal")   # Custom plays the Horror music


## The playlist that will really play for `key`, applying the Horror fallback.
func _resolve(key: String) -> String:
	if not playlists.get(key, []).is_empty():
		return key
	if key.ends_with("/horror"):
		var normal := key.replace("/horror", "/normal")
		if not playlists.get(normal, []).is_empty():
			return normal
	return key


func has_tracks(screen := "") -> bool:
	var key := context if screen == "" else _key(screen)
	return key != "" and not playlists.get(_resolve(key), []).is_empty()


## Switch to "menu" or "gameplay" music for the current mode, fading out first.
func play_context(screen: String) -> void:
	var key := _key(screen)
	if key == context and player.playing:
		return
	context = key
	_switch += 1
	_fade_then(_switch, _start_next)


func stop_music() -> void:
	context = ""
	_switch += 1
	_fade_then(_switch, func(): pass)


func next_track() -> void:
	if context == "" or not has_tracks():
		return
	_switch += 1
	_fade_then(_switch, _start_next)


func reshuffle() -> void:
	for k in orders:
		orders[k] = []


func _fade_then(id: int, then: Callable) -> void:
	if _tween:
		_tween.kill()
	if not player.playing:
		player.stop()
		then.call()
		return
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(player, "volume_db", SILENT_DB, FADE_OUT)
	_tween.tween_callback(func():
		if id != _switch:
			return  # a newer switch took over
		player.stop()
		then.call())


func _start_next() -> void:
	title = ""
	if context == "":
		return
	_source = _resolve(context)
	var list: Array = playlists.get(_source, [])
	if list.is_empty():
		track_changed.emit(title)
		return
	if orders[_source].size() != list.size():
		_build_order(_source)
	positions[_source] += 1
	if positions[_source] >= orders[_source].size():
		_build_order(_source)
		positions[_source] = 0
	var path: String = list[orders[_source][positions[_source]]]
	var stream := _load(path)
	if stream == null:
		push_warning("Could not load music: " + path)
		track_changed.emit(title)
		return
	if "loop" in stream:
		stream.loop = false
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	player.stream = stream
	player.pitch_scale = HORROR_FALLBACK_PITCH if _source != context else 1.0
	player.volume_db = SILENT_DB
	player.play()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(player, "volume_db", 0.0, FADE_IN)
	title = path.get_file().get_basename().replace("_", " ")
	if _source != context:
		title += " (slowed - no horror track yet)"
	track_changed.emit(title)


func _on_finished() -> void:
	if context != "":
		_start_next()


func _build_order(key: String) -> void:
	var o := range(playlists[key].size())
	if Settings.shuffle_music:
		o.shuffle()
	orders[key] = o


func _load(path: String) -> AudioStream:
	if path.begins_with("res://"):
		return load(path) as AudioStream
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			var s := AudioStreamMP3.new()
			s.data = FileAccess.get_file_as_bytes(path)
			return s
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_track"):
		next_track()
