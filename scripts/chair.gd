## A chair dropped by the crane, stuffed full of fluff. Bears loot it like a
## stunned bear: stand next to it and hold Steal. It isn't solid, and a blast
## bursts it open, scattering the rest of its stuffing as pickups.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")

var game
var cell := Vector2i.ZERO
var fluff: float = Tuning.CHAIR_FLUFF
var robbed_t := 0.0      # set while being looted (shared with bear theft code)
var stun_t := 999.0      # never "wakes up" (lets the AI treat it like a victim)
var landed := true
var t := 0.0
var squash := 0.0
var squash_v := 0.0
var _last_fluff := fluff


func setup(g, c: Vector2i) -> void:
	game = g
	cell = c
	position = g.arena.cell_center(c)
	squash_v = 9.0


func fill() -> float:
	return clampf(fluff / Tuning.CHAIR_FLUFF, 0.0, 1.0)


func _process(delta: float) -> void:
	t += delta
	robbed_t = maxf(0.0, robbed_t - delta)
	if fluff < _last_fluff - 0.01:
		squash_v += (_last_fluff - fluff) * 0.9   # each tug makes it puff and sag
	_last_fluff = fluff
	# fixed substeps keep the stiff spring stable on long frames
	var steps := ceili(delta / 0.008)
	var dt := delta / maxf(steps, 1)
	for i in steps:
		squash_v += (-260.0 * squash - 2.0 * sqrt(260.0) * 0.18 * squash_v) * dt
		squash += squash_v * dt
	squash = clampf(squash, -0.6, 0.6)
	queue_redraw()


func _draw() -> void:
	var T: float = game.arena.T
	var f := fill()
	var tex: Texture2D = Assets.tex("objects/chair")
	var w := T * 1.02
	var h := w * (0.78 + 0.22 * f) * (1.0 - squash * 0.25)
	var shake := Vector2.ZERO
	if robbed_t > 0.0:
		shake = Vector2(sin(t * 47.0), cos(t * 39.0)) * 1.6
	draw_set_transform(Vector2(0, T * 0.34), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, w * 0.48, Color(0.15, 0.1, 0.08, 0.32))
	draw_set_transform(shake, 0.0, Vector2(1.0 + squash * 0.25, 1.0))
	draw_texture_rect(tex, Rect2(-w * 0.5, T * 0.4 - h, w, h), false)
	# stuffing still poking out of the top, more when fuller
	var tuft: Texture2D = Assets.tex("objects/fluff")
	var n := ceili(f * 5.0)
	for i in n:
		var x := (i - (n - 1) * 0.5) * 8.0
		var bob := sin(t * 3.0 + i * 1.3) * 1.5
		var s := 10.0 + 4.0 * f
		draw_texture_rect(tuft, Rect2(x - s * 0.5, T * 0.4 - h - s * 0.45 + bob, s, s), false, preload("res://scripts/mode_theme.gd").stuffing_color())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
