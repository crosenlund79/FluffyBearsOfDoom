## Music playlist. Tracks are discovered automatically from:
##   res://assets/audio/music/   (mp3 / ogg / wav, imported by Godot, works in exports)
##   <game folder>/music/ and user://music/   (mp3 / ogg, drop in after exporting)
## Plays through the list, loops it, optionally shuffles. Silent if empty.
extends Node

signal track_changed(title: String)

const RES_DIR := "res://assets/audio/music"
const EXTS := ["mp3", "ogg", "wav"]

var tracks: Array[String] = []
var order: Array = []
var pos := -1
var player: AudioStreamPlayer
var title := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	add_child(player)
	player.finished.connect(next_track)
	scan()


func scan() -> void:
	tracks.clear()
	_scan(RES_DIR, true)
	if not OS.has_feature("editor"):
		_scan(OS.get_executable_path().get_base_dir().path_join("music"), false)
	_scan("user://music", false)
	order.clear()
	pos = -1


func _scan(dir_path: String, imported: bool) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		# exported builds list imported files as "song.ogg.import" / ".remap"
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		var ext := name.get_extension().to_lower()
		if not ext in EXTS or (not imported and ext == "wav"):
			continue
		var path := dir_path.path_join(name)
		if not path in tracks:
			tracks.append(path)


func has_tracks() -> bool:
	return not tracks.is_empty()


## Start the playlist unless something is already playing.
func ensure_playing() -> void:
	if not player.playing and has_tracks():
		next_track()


func next_track() -> void:
	if not has_tracks():
		return
	if order.size() != tracks.size():
		_build_order()
	pos += 1
	if pos >= order.size():
		_build_order()
		pos = 0
	var path: String = tracks[order[pos]]
	var stream := _load(path)
	if stream == null:
		push_warning("Could not load music: " + path)
		return
	if "loop" in stream:
		stream.loop = false
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	player.stream = stream
	player.play()
	title = path.get_file().get_basename().replace("_", " ")
	track_changed.emit(title)


func stop() -> void:
	player.stop()


func _build_order() -> void:
	order = range(tracks.size())
	if Settings.shuffle_music:
		order.shuffle()


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
