## A stitched fabric toy bomb on a grid cell. Can be kicked; rubber bombs
## bounce off obstacles instead of stopping.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")

var game
var arena
var owner_bear
var cell := Vector2i.ZERO
var blast_range := 2
var fuse: float = Tuning.BOMB_FUSE
var exploded := false
var rubber := false
var pass_through: Array = []  # bears overlapping it may walk off it
var move_dir := Vector2i.ZERO
var bounces := 0
var tint := Color.WHITE
var tex: Texture2D
var fx: Texture2D
var t := 0.0
var squash := 0.0
var squash_v := 0.0
var _last_tick := 3


func setup(g, bear, c: Vector2i, r: int) -> void:
	game = g
	arena = g.arena
	owner_bear = bear
	cell = c
	blast_range = r
	rubber = bear.has_rubber
	position = arena.cell_center(c)
	tex = Assets.tex("objects/bomb")
	fx = Assets.tex("effects/effects")
	# pastel version of the owner's colour; rubber bombs are brighter
	tint = preload("res://scripts/mode_theme.gd").bomb_tint(bear.color, rubber)


func is_moving() -> bool:
	return move_dir != Vector2i.ZERO


func kick(dir: Vector2i) -> void:
	if is_moving() or exploded:
		return
	if not _free(cell + dir):
		return
	move_dir = dir
	bounces = 0
	squash_v -= 8.0
	Sfx.play("kick", randf_range(0.9, 1.1))


func _physics_process(delta: float) -> void:
	t += delta
	fuse -= delta
	var sq := 2.0 * sqrt(300.0) * 0.18
	squash_v += (-300.0 * squash - sq * squash_v) * delta
	squash += squash_v * delta
	if is_moving():
		_slide(delta)
	for b in pass_through.duplicate():
		if not b.overlaps_cell(cell):
			pass_through.erase(b)
	var tick := ceili(fuse / 0.33)
	if fuse < 1.0 and tick != _last_tick:
		_last_tick = tick
		Sfx.play("fuse", 1.0 + (1.0 - fuse) * 0.5, -10.0)
	if fuse <= 0.0 and not exploded:
		game.explode(self)
	queue_redraw()


func _free(c: Vector2i) -> bool:
	if arena.is_solid(c) or arena.bombs.has(c):
		return false
	for b in game.bears:
		if b.cell() == c and not pass_through.has(b):
			return false
	return true


func _slide(delta: float) -> void:
	var step := Tuning.KICK_SPEED * delta
	var dirv := Vector2(move_dir)
	var center: Vector2 = arena.cell_center(cell)
	var ahead := (center - position).dot(dirv)
	if ahead > step:
		position += dirv * step
		return
	# at the centre of a cell: carry on, bounce or stop
	if _free(cell + move_dir):
		position += dirv * step
		var nc: Vector2i = arena.world_to_cell(position)
		if nc != cell:
			arena.bombs.erase(cell)
			cell = nc
			arena.bombs[cell] = self
			for b in game.bears:
				if b.overlaps_cell(cell) and not pass_through.has(b):
					pass_through.append(b)
		return
	position = center
	if rubber and bounces < Tuning.RUBBER_MAX_BOUNCES and _free(cell - move_dir):
		move_dir = -move_dir
		bounces += 1
		squash_v += 14.0
		Sfx.play("boing", randf_range(1.1, 1.4), -6.0)
	else:
		move_dir = Vector2i.ZERO
		squash_v += 6.0


func _draw() -> void:
	var T: float = arena.T
	var urgency := clampf(1.0 - fuse / Tuning.BOMB_FUSE, 0.0, 1.0)
	# ticking: a pulse and little hops that get faster
	var rate := 6.0 + urgency * urgency * 26.0
	var pulse := sin(t * rate) * (0.04 + 0.07 * urgency)
	var hop := maxf(0.0, sin(t * rate * 0.5)) * (1.0 + 4.0 * urgency)
	var pop := 1.0 + 0.35 * exp(-t * 9.0) * sin(t * 30.0)
	var final := 0.0
	if fuse < 0.35:
		final = (0.35 - fuse) / 0.35  # last-moment swell
	var s := T * 0.92 * pop * (1.0 + final * 0.25)
	var sx := (1.0 + pulse + squash * 0.5)
	var sy := (1.0 - pulse - squash * 0.5)
	if is_moving():
		var horiz := move_dir.x != 0
		sx *= 1.12 if horiz else 0.9
		sy *= 0.9 if horiz else 1.12
	draw_set_transform(Vector2(0, T * 0.32), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, s * 0.36, Color(0.3, 0.2, 0.15, 0.22))
	var twitch := sin(t * 47.0) * 0.08 * final
	draw_set_transform(Vector2(0, T * 0.3 - hop), twitch + (sin(t * 12.0) * 0.1 if is_moving() else 0.0), Vector2(sx, sy))
	var col := tint
	if fuse < 0.8 and fmod(t * 10.0, 1.0) < 0.5:
		col = tint.lerp(Color(1.0, 0.82, 0.82), 0.6)
	var rect := Rect2(-s * 0.5, -s - 2.0, s, s)
	draw_texture_rect(tex, rect, false, col)
	if rubber:
		# candy stripes mark a rubber bomb
		var c := rect.get_center() + Vector2(-s * 0.02, s * 0.075)
		for k in [-0.18, 0.0, 0.18]:
			var y: float = c.y + k * s
			var hw: float = sqrt(maxf(0.0, 0.09 - k * k)) * s
			draw_line(Vector2(c.x - hw, y), Vector2(c.x + hw, y), Color(1, 1, 1, 0.75), s * 0.05)
	# brightening stitched fuse spark
	var spark := Vector2(s * 0.26, -s * 1.02)
	var ss := 8.0 + urgency * 8.0 + sin(t * 40.0) * 3.0
	var spark_col := Color(1.0, 0.95, 0.8).lerp(Color(1.0, 0.6, 0.55), urgency)
	draw_texture_rect_region(fx, Rect2(spark - Vector2(ss, ss) * 0.5, Vector2(ss, ss)), Assets.region(fx, Assets.EFFECT_CELLS, 5), spark_col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
