## A floor mark left where a bear was knocked out: a scatter of stuffing in
## Normal mode, a blood splatter in Horror. Uses effects-sheet cell 7.
extends Node2D

var tex: Texture2D
var color := Color.WHITE
var size := 40.0
var life := 25.0
var age := 0.0


func _ready() -> void:
	tex = Assets.tex("effects/effects")
	rotation = randf() * TAU


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	if age < 0.3 or age > life - 3.0:
		queue_redraw()


func _draw() -> void:
	var grow := clampf(age / 0.15, 0.0, 1.0)
	var a := color.a * clampf((life - age) / 3.0, 0.0, 1.0)
	var s := size * (0.6 + 0.4 * grow)
	draw_texture_rect_region(tex, Rect2(-s * 0.5, -s * 0.5, s, s), Assets.region(tex, Assets.EFFECT_CELLS, 7), Color(color.r, color.g, color.b, a))
