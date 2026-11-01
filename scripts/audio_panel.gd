## Audio settings: volumes, mute, shuffle, next track. Saved automatically.
extends "res://scripts/stitch_panel.gd"

signal closed


var now_playing: Label


func _ready() -> void:
	size = Vector2(440, 400)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UiStyle.label("Audio", 30, UiStyle.ROSE_DARK))
	for row in [["Master", "master_volume"], ["Music", "music_volume"], ["Sound effects", "sfx_volume"]]:
		var h := HBoxContainer.new()
		var l := UiStyle.label(row[0], 18)
		l.custom_minimum_size = Vector2(140, 0)
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = Settings.get(row[1])
		sl.custom_minimum_size = Vector2(230, 28)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = row[1]
		sl.value_changed.connect(func(val):
			Settings.set(key, val)
			Settings.apply_audio()
			Settings.save())
		sl.drag_ended.connect(func(_c): Sfx.play("menu"))
		h.add_child(sl)
		v.add_child(h)
	var mute := CheckBox.new()
	mute.text = "Mute everything"
	mute.button_pressed = Settings.muted
	mute.toggled.connect(func(on):
		Settings.muted = on
		Settings.apply_audio()
		Settings.save())
	v.add_child(mute)
	var shuf := CheckBox.new()
	shuf.text = "Shuffle music"
	shuf.button_pressed = Settings.shuffle_music
	shuf.toggled.connect(func(on):
		Settings.shuffle_music = on
		Music.reshuffle()
		Settings.save())
	v.add_child(shuf)
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 12)
	var nxt := Button.new()
	nxt.text = "Next track  (N)"
	nxt.pressed.connect(Music.next_track)
	h2.add_child(nxt)
	now_playing = UiStyle.label("", 14, UiStyle.INK_SOFT)
	now_playing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	now_playing.custom_minimum_size = Vector2(200, 0)
	h2.add_child(now_playing)
	v.add_child(h2)
	var close := Button.new()
	close.text = "Done"
	close.pressed.connect(func():
		Sfx.play("menu")
		closed.emit()
		queue_free())
	v.add_child(close)
	Music.track_changed.connect(_on_track)
	_on_track(Music.title)
	close.grab_focus()


func _on_track(title: String) -> void:
	if not Music.has_tracks():
		now_playing.text = "No music found for %s. Add mp3/ogg/wav files to assets/audio/music/%s/" % [Music.context, Music.context]
	else:
		now_playing.text = "Now playing: " + (title if title != "" else "-")
