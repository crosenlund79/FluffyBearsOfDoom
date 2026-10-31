## A knitted yarn-ball bomb sitting on a grid cell.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")

var game
var owner_bear
var cell := Vector2i.ZERO
var blast_range := 2
var fuse: float = Tuning.BOMB_FUSE
var exploded := false
var pass_through: Array = []  # bears standing on it when placed may walk off
var tex: Texture2D
var fx: Texture2D
var t := 0.0


func setup(g, bear, c: Vector2i, r: int) -> void:
	game = g
	owner_bear = bear
	cell = c
	blast_range = r
	position = g.arena.cell_center(c)
	tex = Assets.tex("objects/bomb")
	fx = Assets.tex("effects/effects")


func _physics_process(delta: float) -> void:
	t += delta
	fuse -= delta
	for b in pass_through.duplicate():
		if not b.overlaps_cell(cell):
			pass_through.erase(b)
	if fuse <= 0.0 and not exploded:
		game.explode(self)
	queue_redraw()


func _draw() -> void:
	var T: float = game.arena.T
	var urgency := clampf(1.0 - fuse / Tuning.BOMB_FUSE, 0.0, 1.0)
	var pulse := sin(t * (7.0 + urgency * 20.0)) * (0.05 + 0.06 * urgency)
	var pop := 1.0 + 0.35 * exp(-t * 9.0) * sin(t * 30.0)
	var s := T * 0.95 * pop
	draw_set_transform(Vector2(0, T * 0.32), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, s * 0.36, Color(0.3, 0.2, 0.15, 0.22))
	draw_set_transform(Vector2(0, T * 0.3), 0.0, Vector2(1.0 + pulse, 1.0 - pulse))
	var col := Color.WHITE
	if fuse < 0.8 and fmod(t * 10.0, 1.0) < 0.5:
		col = Color(1.0, 0.75, 0.75)
	draw_texture_rect(tex, Rect2(-s * 0.5, -s - 2.0, s, s), false, col)
	# fizzing fuse spark
	var spark := Vector2(s * 0.31, -s * 0.94)
	var ss := 10.0 + sin(t * 40.0) * 3.0
	draw_texture_rect_region(fx, Rect2(spark - Vector2(ss, ss) * 0.5, Vector2(ss, ss)), Assets.region(fx, Assets.EFFECT_CELLS, 5), Color(1.0, 0.85, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
