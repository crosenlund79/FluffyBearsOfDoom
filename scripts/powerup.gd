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
## What each power-up does (menu overview).
const DESC := [
	"Carry one more bomb at a time (up to 8).",
	"Your confetti reaches one tile further (up to 8).",
	"Run faster and get going quicker.",
	"Reshuffles patches of floor (ice, honey, bouncy...) after a short warning.",
	"Every bear already kicks bombs by walking into them, so this one no longer drops.",
	"Special key with no remote bombs out: lay all your free bombs in a line ahead.",
	"Kicked bombs bounce off walls instead of stopping.",
	"20 s of no stuns and no stuffing theft.",
	"Curse! 12 s of flipped steering, and it spreads to bears you touch.",
	"Curse! For 10 s your bombs drop all by themselves.",
	"Your bombs wait until you press the special key (backup fuse 10 s).",
]
## Order for the menu overview (droppable ones first, the retired Kick last).
const OVERVIEW := [BOMB, FIRE, SPEED, REMOTE, LINE, RUBBER, IMMORTAL, SHUFFLE, REVERSE, DIARRHEA, KICK]
## Short pickup labels for the floating text.
const SHORT := ["+1 Bomb", "+Blast", "Speed!", "Shuffle!", "Kick", "Line Bomb", "Rubber!",
	"Immortal!", "Reversed!", "Diarrhea!", "Remote!"]
## Kinds that get orbiting sparkles (the rare, exciting ones).
const SPECIAL := [SHUFFLE, LINE, RUBBER, IMMORTAL, REMOTE]

var kind := BOMB
var cell := Vector2i.ZERO
var t := 0.0
var tex: Texture2D


## Halo / feedback colour for a kind, styled for the current mode.
static func glow_color(k: int) -> Color:
	var horror := Settings.mode == "horror"
	if k in BAD:
		return Color(0.55, 0.85, 0.2) if horror else Color(0.62, 0.86, 0.3)
	if horror:
		match k:
			IMMORTAL: return Color(0.95, 0.85, 0.55)
			SHUFFLE, REMOTE: return Color(0.75, 0.35, 0.95)
			_: return Color(0.92, 0.18, 0.15)
	match k:
		BOMB, FIRE: return Color(1.0, 0.72, 0.3)
		SPEED: return Color(0.45, 0.85, 1.0)
		SHUFFLE: return Color(0.75, 0.55, 1.0)
		IMMORTAL: return Color(1.0, 0.92, 0.45)
		REMOTE: return Color(1.0, 0.45, 0.5)
		_: return Color(1.0, 0.85, 0.45)


func _ready() -> void:
	tex = Assets.tex("powerups/powerups")


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var horror := Settings.mode == "horror"
	var bad: bool = kind in BAD
	var col := glow_color(kind)
	var appear := clampf(t * 4.0, 0.0, 1.0)
	# pop in with an overshoot, then breathe
	var s := 40.0 * (appear + 0.25 * sin(appear * PI)) * (1.0 + 0.04 * sin(t * 4.2))
	var bob := sin(t * 3.0) * 2.5
	# shadow shrinks as the badge bobs up
	draw_set_transform(Vector2(0, 15), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, s * (0.4 - bob * 0.01), Color(0.1, 0.05, 0.05, 0.3 if horror else 0.2))
	var c := Vector2(0, -2 + bob)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# pulsing halo: soft disc + ring, flickering in horror
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	if horror:
		pulse *= 0.75 + 0.25 * (1.0 if fmod(t * 7.3, 1.0) < 0.85 else 0.0)
	for i in 3:
		draw_circle(c, s * (0.62 - i * 0.07), Color(col.r, col.g, col.b, (0.08 + 0.07 * pulse) * appear))
	draw_arc(c, s * 0.58 + pulse * 2.0, 0, TAU, 28, Color(col.r, col.g, col.b, 0.55 * appear), 2.0)
	# light rays behind the special ones (normal) / dripping smoke (horror)
	if kind in SPECIAL and not horror:
		for i in 6:
			var a := t * 0.8 + i * TAU / 6.0
			var p1 := c + Vector2.from_angle(a) * s * 0.5
			var p2 := c + Vector2.from_angle(a) * s * (0.85 + 0.1 * pulse)
			draw_line(p1, p2, Color(col.r, col.g, col.b, 0.35 * appear), 3.0)
	if horror and not bad:
		for i in 2:
			var dy := fmod(t * 14.0 + i * 11.0, 22.0)
			var dx := -s * 0.15 + i * s * 0.3
			draw_circle(c + Vector2(dx, s * 0.32 + dy), 2.2 * (1.0 - dy / 22.0), Color(0.55, 0.05, 0.05, 0.8 * (1.0 - dy / 22.0)))
	var wob := sin(t * 2.0) * 0.08
	var off := Vector2.ZERO
	if bad:
		wob = sin(t * 9.0) * 0.12  # curses twitch suspiciously
		if fmod(t, 1.7) < 0.12:
			off = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	var rect := Rect2(-s * 0.5, -s * 0.5, s, s)
	var region := Assets.region(tex, Assets.POWERUP_CELLS, CELL[kind])
	# chunky silhouette: the badge drawn dark and slightly bigger behind itself
	var outline := Color(0.12, 0.02, 0.02, 0.85 * appear) if horror else Color(0.3, 0.18, 0.12, 0.6 * appear)
	draw_set_transform(c + off, wob, Vector2.ONE * 1.12)
	draw_texture_rect_region(tex, rect, region, outline)
	draw_set_transform(c + off, wob, Vector2.ONE)
	draw_texture_rect_region(tex, rect, region, Color(1, 1, 1, appear))
	if kind == REMOTE:
		draw_remote_antenna(self, Vector2(s * 0.18, -s * 0.2), s / 38.0, t)
	# a glint sweeping across the badge every couple of seconds
	var g := fmod(t * 0.55 + float(cell.x + cell.y) * 0.13, 1.0)
	if g < 0.25 and not horror:
		var gx := lerpf(-s * 0.45, s * 0.45, g / 0.25)
		draw_line(Vector2(gx - 4, s * 0.3), Vector2(gx + 6, -s * 0.3), Color(1, 1, 1, 0.55), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# orbiting sparkles (special kinds), sick bubbles (curses), embers (horror)
	if bad:
		for i in 3:
			var k := fmod(t * 0.7 + i / 3.0, 1.0)
			var p := c + Vector2(sin(t * 3.0 + i * 2.0) * s * 0.35, -s * 0.3 - k * 22.0)
			draw_arc(p, 2.0 + 2.5 * k, 0, TAU, 10, Color(col.r, col.g, col.b, 0.8 * (1.0 - k)), 1.4)
	elif kind in SPECIAL:
		for i in 3:
			var a := t * 2.4 + i * TAU / 3.0
			var p := c + Vector2(cos(a) * s * 0.62, sin(a) * s * 0.25)
			var r := 2.6 + 1.2 * sin(t * 6.0 + i)
			var sc := Color(1, 0.95, 0.8) if not horror else Color(1.0, 0.4, 0.3)
			draw_line(p - Vector2(r, 0), p + Vector2(r, 0), sc, 1.6)
			draw_line(p - Vector2(0, r), p + Vector2(0, r), sc, 1.6)


## A little radio antenna with a blinking tip and signal arcs (remote bombs and their badge).
static func draw_remote_antenna(ci: CanvasItem, base: Vector2, sc: float, t: float, tip := Color(0.9, 0.2, 0.25)) -> void:
	var top := base + Vector2(4, -12) * sc
	ci.draw_line(base, top, Color(0.25, 0.18, 0.15), 2.0 * sc)
	var on := fmod(t * 2.5, 1.0) < 0.55
	ci.draw_circle(top, 2.8 * sc, tip if on else tip.darkened(0.5))
	if on:
		for k in 2:
			ci.draw_arc(top, (5.0 + k * 3.5) * sc, -PI * 0.85, -PI * 0.15, 6, Color(tip.r, tip.g, tip.b, 0.75 - k * 0.3), 1.4 * sc)
