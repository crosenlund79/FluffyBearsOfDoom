## A small "now playing" pill that slides in briefly when a track starts or
## changes. Sits outside the play area so it never hides gameplay.
extends Control

const UiStyle = preload("res://scripts/ui_style.gd")
const SHOW_TIME := 4.0

var title := ""
var age := 99.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Music.track_changed.connect(_on_track)
	# a track that started a moment before this screen appeared still gets announced
	if Music.player.playing and Music.title != "" and Music.player.get_playback_position() < 1.5:
		_on_track(Music.title)


func _on_track(t: String) -> void:
	if t == "":
		return
	title = t
	age = 0.0


func _process(delta: float) -> void:
	if age < SHOW_TIME + 1.0:
		age += delta
		queue_redraw()


func _draw() -> void:
	if title == "" or age > SHOW_TIME + 0.6:
		return
	var appear := clampf(age / 0.35, 0.0, 1.0)
	var fade := 1.0 - clampf((age - SHOW_TIME) / 0.6, 0.0, 1.0)
	var a := appear * fade
	var font := UiStyle.font()
	var text := "Now playing: " + title
	var fs := 15
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 44.0
	var x := -18.0 * (1.0 - appear)
	var r := Rect2(x, 0, w, 26)
	draw_rect(r, Color(UiStyle.PAPER, 0.9 * a))
	draw_rect(r, Color(UiStyle.ROSE_DARK, 0.8 * a), false, 1.4)
	# a little drawn music note (no special glyph needed)
	var n := Vector2(x + 14, 18)
	var ink := Color(UiStyle.ROSE_DARK, a)
	draw_circle(n, 3.6, ink)
	draw_line(n + Vector2(3.2, 0), n + Vector2(3.2, -11), ink, 1.6)
	draw_line(n + Vector2(3.2, -11), n + Vector2(8, -8), ink, 1.6)
	draw_string(font, Vector2(x + 28, 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiStyle.INK, a))
