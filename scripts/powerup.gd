## A collectible power-up badge on a grid cell.
extends Node2D

enum { BOMB, FIRE, SPEED, SHUFFLE, KICK, LINE, RUBBER, IMMORTAL, REVERSE, DIARRHEA, REMOTE }
const NAMES := ["Extra Bomb", "Bigger Blast", "Springy Stitching", "Biome Shuffle", "Bomb Kick",
	"Line Bomb", "Rubber Bombs", "Immortality", "Reverse Controls!", "Bomb Diarrhea!", "Remote Detonator"]
# Every bear can kick now, so Bomb Kick no longer drops (its sheet cell is kept for compatibility).
const WEIGHTS := [22.0, 20.0, 9.0, 6.0, 0.0, 7.0, 5.0, 4.0, 9.0, 7.0, 7.0]
## Sheet cell for each kind. The Remote Detonator reuses the bomb badge plus a drawn
## antenna, so existing 10-cell replacement sheets keep working.
const CELL := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
const BAD := [REVERSE, DIARRHEA]

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
	var wob := sin(t * 2.0) * 0.08
	if kind in BAD:
		wob = sin(t * 9.0) * 0.12  # curses twitch suspiciously
	draw_set_transform(Vector2(0, -2 + bob), wob, Vector2.ONE)
	draw_texture_rect_region(tex, Rect2(-s * 0.5, -s * 0.5, s, s), Assets.region(tex, Assets.POWERUP_CELLS, CELL[kind]))
	if kind == REMOTE:
		draw_remote_antenna(self, Vector2(s * 0.18, -s * 0.2), s / 38.0, t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A little radio antenna with a blinking tip and signal arcs (remote bombs and their badge).
static func draw_remote_antenna(ci: CanvasItem, base: Vector2, sc: float, t: float, tip := Color(0.9, 0.2, 0.25)) -> void:
	var top := base + Vector2(4, -12) * sc
	ci.draw_line(base, top, Color(0.25, 0.18, 0.15), 2.0 * sc)
	var on := fmod(t * 2.5, 1.0) < 0.55
	ci.draw_circle(top, 2.8 * sc, tip if on else tip.darkened(0.5))
	if on:
		for k in 2:
			ci.draw_arc(top, (5.0 + k * 3.5) * sc, -PI * 0.85, -PI * 0.15, 6, Color(tip.r, tip.g, tip.b, 0.75 - k * 0.3), 1.4 * sc)
