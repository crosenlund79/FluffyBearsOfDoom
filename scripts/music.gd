## Two playlists, discovered automatically - no code changes needed:
##   assets/audio/music/menu/       played on the title menu
##   assets/audio/music/gameplay/   played during matches
## (mp3 / ogg / wav; imported by Godot, so they are packed into exports).
## After exporting you can also drop mp3 / ogg files into music/menu and
## music/gameplay next to the game's .exe, or into user://music/<context>/.
## Files placed directly in assets/audio/music/ count as gameplay music.
## Only one track ever plays: switching fades the old one out first.
extends Node

signal track_changed(title: String)

const ROOT := "res://assets/audio/music"
const CONTEXTS := ["menu", "gameplay"]
const EXTS := ["mp3", "ogg", "wav"]
const FADE_OUT := 0.7
const FADE_IN := 0.8
const SILENT_DB := -40.0

var playlists := {"menu": [], "gameplay": []}
var orders := {"menu": [], "gameplay": []}
var positions := {"menu": -1, "gameplay": -1}
var context := ""
var title := ""
var player: AudioStreamPlayer
var _tween: Tween
var _switch := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	add_child(player)
	player.finished.connect(_on_finished)
	scan()


func scan() -> void:
	for ctx in CONTEXTS:
		playlists[ctx] = []
		orders[ctx] = []
		positions[ctx] = -1
		_scan(ROOT.path_join(ctx), true, ctx)
		if not OS.has_feature("editor"):
			_scan(OS.get_executable_path().get_base_dir().path_join("music").path_join(ctx), false, ctx)
		_scan("user://music".path_join(ctx), false, ctx)
	_scan(ROOT, true, "gameplay")  # loose files from the older single-folder layout


func _scan(dir_path: String, imported: bool, ctx: String) -> void:
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
		if not path in playlists[ctx]:
			playlists[ctx].append(path)


func has_tracks(ctx := "") -> bool:
	if ctx == "":
		ctx = context
	return not playlists.get(ctx, []).is_empty()


## Switch to "menu" or "gameplay" music, fading out whatever is playing.
func play_context(ctx: String) -> void:
	if ctx == context and player.playing:
		return
	context = ctx
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
	for ctx in CONTEXTS:
		orders[ctx] = []


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
	var list: Array = playlists.get(context, [])
	if list.is_empty():
		track_changed.emit(title)
		return
	if orders[context].size() != list.size():
		_build_order(context)
	positions[context] += 1
	if positions[context] >= orders[context].size():
		_build_order(context)
		positions[context] = 0
	var path: String = list[orders[context][positions[context]]]
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
	player.volume_db = SILENT_DB
	player.play()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(player, "volume_db", 0.0, FADE_IN)
	title = path.get_file().get_basename().replace("_", " ")
	track_changed.emit(title)


func _on_finished() -> void:
	if context != "":
		_start_next()


func _build_order(ctx: String) -> void:
	var o := range(playlists[ctx].size())
	if Settings.shuffle_music:
		o.shuffle()
	orders[ctx] = o


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
