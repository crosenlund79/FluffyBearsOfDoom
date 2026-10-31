## A loose tuft of stuffing that popped out of a stunned bear.
extends Node2D

var game
var amount := 5.0
var from := Vector2.ZERO
var to := Vector2.ZERO
var cell := Vector2i.ZERO
var t := 0.0
var flight := 0.5
var landed := false
var tex: Texture2D


func _ready() -> void:
	tex = Assets.tex("objects/fluff")
	position = from


func _process(delta: float) -> void:
	t += delta
	if not landed:
		var k := minf(t / flight, 1.0)
		position = from.lerp(to, k)
		if k >= 1.0:
			landed = true
	queue_redraw()


func _draw() -> void:
	var hop := 0.0
	if not landed:
		hop = sin(minf(t / flight, 1.0) * PI) * 34.0
	else:
		hop = 3.0 + sin(t * 3.0) * 2.0
	var s := 16.0 + amount * 1.2
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, s * 0.4, Color(0.3, 0.2, 0.15, 0.18))
	draw_set_transform(Vector2(0, -hop), sin(t * 2.0) * 0.2, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
