## A collectible power-up badge on a grid cell.
extends Node2D

enum { BOMB, FIRE, SPEED, SHUFFLE }
const NAMES := ["Extra Bomb", "Bigger Blast", "Springy Stitching", "Biome Shuffle"]
const WEIGHTS := [36.0, 34.0, 18.0, 12.0]

var kind := BOMB
var cell := Vector2i.ZERO
var t := 0.0
var tex: Texture2D


func _ready() -> void:
	tex = Assets.tex("powerups/powerups")


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var appear := clampf(t * 4.0, 0.0, 1.0)
	var s := 38.0 * (appear + 0.2 * sin(appear * PI))
	var bob := sin(t * 3.0) * 2.5
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, s * 0.38, Color(0.3, 0.2, 0.15, 0.2))
	draw_set_transform(Vector2(0, -2 + bob), sin(t * 2.0) * 0.08, Vector2.ONE)
	draw_texture_rect_region(tex, Rect2(-s * 0.5, -s * 0.5, s, s), Assets.region(tex, Assets.POWERUP_CELLS, kind))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
