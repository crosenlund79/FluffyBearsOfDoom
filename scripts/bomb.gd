## A stitched fabric toy bomb on a grid cell. Ordinary bombs burn a timed fuse;
## rubber bombs bounce off obstacles when kicked; proximity bombs (special key)
## count down 3-2-1 while arming, then go off when a rival steps next to them.
## The owner can never trip their own. A ring in the owner's colour shows whose
## bomb it is.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Powerup = preload("res://scripts/powerup.gd")

var game
var arena
var owner_bear
var cell := Vector2i.ZERO
var blast_range := 2
var fuse: float = Tuning.BOMB_FUSE
var exploded := false
var rubber := false
var proximity := false  # arms, then waits for a rival to come close
var arm_left := 0.0     # seconds until a proximity bomb is armed
var triggered := false  # a rival tripped it: the short trigger fuse is burning
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


func setup(g, bear, c: Vector2i, r: int, prox := false) -> void:
	game = g
	arena = g.arena
	owner_bear = bear
	cell = c
	blast_range = r
	rubber = bear.has_rubber
	proximity = prox
	if proximity:
		arm_left = Tuning.PROX_ARM_TIME
		fuse = Tuning.PROX_ARM_TIME + Tuning.PROX_LIFETIME   # goes off on its own eventually
	position = arena.cell_center(c)
	tex = Assets.tex("objects/bomb")
	fx = Assets.tex("effects/effects")
	# pastel version of the owner's colour; rubber bombs are brighter
	tint = preload("res://scripts/mode_theme.gd").bomb_tint(bear.color, rubber)


func armed() -> bool:
	return proximity and arm_left <= 0.0 and not triggered


## Cells a rival can stand in to trip this bomb (its own cell and the four around it).
func trip_cells() -> Array:
	var out := [cell]
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not arena.is_solid(cell + d):
			out.append(cell + d)
	return out


func _proximity(delta: float) -> void:
	if triggered:
		return
	if arm_left > 0.0:
		var before := ceili(arm_left)
		arm_left -= delta
		if arm_left <= 0.0:
			arm_left = 0.0
			squash_v -= 6.0
			Sfx.play("prox_armed", 1.0, -6.0)
		elif ceili(arm_left) != before:
			Sfx.play("fuse", 0.8, -12.0)
		return
	if is_moving():
		return
	var reach: float = Tuning.PROX_RANGE * arena.T
	for b in game.bears:
		if b == owner_bear or b.eliminated:
			continue
		if b.position.distance_to(position) <= reach:
			triggered = true
			fuse = minf(fuse, Tuning.PROX_TRIGGER_DELAY)
			squash_v += 10.0
			Sfx.play("prox_alert", 1.0, -3.0)
			return


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
	if proximity:
		_proximity(delta)
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
		if b.cell() == c and not pass_through.has(b) and not b.eliminated:
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
	if proximity and not triggered:
		urgency = 0.0
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
	draw_circle(Vector2.ZERO, s * 0.4, Color(0.15, 0.1, 0.08, 0.38))
	# owner ring on the floor
	var own: Color = owner_bear.color
	draw_arc(Vector2.ZERO, s * 0.5, 0.0, TAU, 28, Color(own.r, own.g, own.b, 0.95), 4.0)
	draw_arc(Vector2.ZERO, s * 0.5, 0.0, TAU, 28, Color(own.darkened(0.5), 0.6), 1.5)
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
	if proximity and not triggered:
		# sensor antenna instead of a burning fuse; blinks red once armed
		var tip: Color = Color(1.0, 0.15, 0.15) if armed() and fmod(t * 2.0, 1.0) < 0.5 else owner_bear.color.lightened(0.2)
		Powerup.draw_sensor_antenna(self, Vector2(s * 0.24, -s * 0.98), s / 40.0, t, tip)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if arm_left > 0.0:
			_draw_countdown(T)
		else:
			# detection range on the floor, so everyone can see the trap
			draw_set_transform(Vector2(0, T * 0.32), 0.0, Vector2(1.0, 0.45))
			var glow := 0.5 + 0.5 * sin(t * 5.0)
			var reach: float = Tuning.PROX_RANGE * T
			draw_circle(Vector2.ZERO, reach, Color(1.0, 0.15, 0.15, 0.08 + 0.08 * glow))
			draw_arc(Vector2.ZERO, reach, 0.0, TAU, 40, Color(0.9, 0.1, 0.1, 0.5 + 0.4 * glow), 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# brightening stitched fuse spark
	var spark := Vector2(s * 0.26, -s * 1.02)
	var ss := 8.0 + urgency * 8.0 + sin(t * 40.0) * 3.0
	var spark_col := Color(1.0, 0.95, 0.8).lerp(Color(1.0, 0.6, 0.55), urgency)
	draw_texture_rect_region(fx, Rect2(spark - Vector2(ss, ss) * 0.5, Vector2(ss, ss)), Assets.region(fx, Assets.EFFECT_CELLS, 5), spark_col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Big 3-2-1 on the bomb while a proximity bomb arms.
func _draw_countdown(T: float) -> void:
	var n := ceili(arm_left)
	var frac := arm_left - floorf(arm_left)   # 1 -> 0 within each second
	var font := ThemeDB.fallback_font
	var size := int(T * (0.5 + 0.18 * frac))
	var txt := str(n)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-w * 0.5, -T * 0.05)
	draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.1, 0.05, 0.05, 0.9))
	draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.95, 0.6))
