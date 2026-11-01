## Pickup feedback: a shockwave ring, the badge popping up and away, and a
## floating label saying what you got.
extends Node2D

const Powerup = preload("res://scripts/powerup.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const LIFE := 1.1

var kind := 0
var age := 0.0


func _process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := age / LIFE
	var col: Color = Powerup.glow_color(kind)
	# shockwave ring
	var r := 10.0 + 46.0 * sqrt(k)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.9 * (1.0 - k)), 5.0 * (1.0 - k) + 1.0)
	draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 24, Color(1, 1, 1, 0.5 * (1.0 - k)), 2.0)
	# badge pops up and floats away
	var tex: Texture2D = Assets.tex("powerups/powerups")
	var up := -34.0 * (1.0 - pow(1.0 - k, 3.0))
	var s := 38.0 * (1.0 + 0.6 * sin(minf(k * 3.0, 1.0) * PI * 0.5)) * (1.0 - 0.5 * k)
	var a := 1.0 - clampf((k - 0.5) / 0.5, 0.0, 1.0)
	draw_texture_rect_region(tex, Rect2(Vector2(-s * 0.5, up - s * 0.5), Vector2(s, s)),
		Assets.region(tex, Assets.POWERUP_CELLS, Powerup.CELL[kind]), Color(1, 1, 1, a))
	# floating label
	var font := UiStyle.font()
	var label: String = Powerup.SHORT[kind]
	var y := -30.0 - 40.0 * k
	var outline := Color(0.08, 0.04, 0.04, a) if Settings.mode == "horror" else Color(1, 0.98, 0.94, a)
	for o in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
		draw_string(font, Vector2(-60, y) + o, label, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, outline)
	draw_string(font, Vector2(-60, y), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color(col.darkened(0.35), a))
