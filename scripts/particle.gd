## A tiny sprite particle: stars, dust, tufts of stuffing.
## If `target` is set it flies in an arc toward that node (stolen fluff).
extends Node2D

var tex: Texture2D
var region := Rect2()
var vel := Vector2.ZERO
var gravity := 0.0
var drag := 0.0
var life := 0.6
var age := 0.0
var spin := 0.0
var size := 16.0
var grow := 0.0
var color := Color.WHITE
var target: Node2D = null
var start := Vector2.ZERO
var arc := 26.0


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	if target != null and is_instance_valid(target):
		var k := age / life
		var e := k * k * (3.0 - 2.0 * k)
		position = start.lerp(target.position + Vector2(0, -22), e) + Vector2(0, -sin(k * PI) * arc)
		size = lerpf(size, 8.0, delta * 2.0)
	else:
		vel *= maxf(0.0, 1.0 - drag * delta)
		vel.y += gravity * delta
		position += vel * delta
	rotation += spin * delta
	size += grow * delta
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - clampf((age / life - 0.6) / 0.4, 0.0, 1.0)
	if tex == null:  # a confetti paper piece
		var flip := 0.35 + 0.65 * absf(sin(age * 14.0 + spin))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, flip))
		draw_rect(Rect2(-size * 0.5, -size * 0.3, size, size * 0.6), Color(color.r, color.g, color.b, color.a * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_texture_rect_region(tex, Rect2(-size * 0.5, -size * 0.5, size, size), region, Color(color.r, color.g, color.b, color.a * a))
