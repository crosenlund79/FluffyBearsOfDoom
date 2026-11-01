## The Doom Duck Parade: a portal opens in a permanent wall, a wind-up mother
## duck and three ducklings march the corridors, the clockwork speeds up,
## and the mother bursts into confetti that flows around corners.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const OPEN_TIME := 0.9      # portal swirl before the mother appears
const PORTAL_LINGER := 4.0  # portal stays while the ducklings come out
const DUCKLINGS := 3

var game
var arena
var wall := Vector2i.ZERO
var tex: Texture2D
var fx: Texture2D
var font: Font

var t := 0.0
var marching := false
var countdown: float = Tuning.DUCK_TIME
var mother_pos := Vector2.ZERO
var cur_cell := Vector2i.ZERO
var next_cell := Vector2i.ZERO
var heading := Vector2i(0, 1)
var trail: Array[Vector2] = []
var phase := 0.0
var _tick_t := 0.0
var _quack_t := 1.0
var _warn_t := 0.0
var _pending: Array = []  # [time, sound, pitch]
var _rng := RandomNumberGenerator.new()


func setup(g, wall_cell: Vector2i) -> void:
	game = g
	arena = g.arena
	wall = wall_cell
	tex = Assets.tex("objects/duck")
	fx = Assets.tex("effects/effects")
	font = UiStyle.font()
	_rng.randomize()
	mother_pos = _portal_pos()
	trail.append(mother_pos)
	cur_cell = wall
	next_cell = wall + Vector2i(0, 1)
	Sfx.play("portal")


func _portal_pos() -> Vector2:
	# the visible (front) face of the wall block
	return arena.cell_center(wall) + Vector2(0, arena.T * 0.3)


## Put the mother duck down on `c` (the Time of Doom closed her cell).
func relocate(c: Vector2i) -> void:
	mother_pos = arena.cell_center(c)
	cur_cell = c
	next_cell = c
	trail.clear()
	trail.append(mother_pos)
	_choose_next()


## True once the ducks are out and the countdown is running.
func armed() -> bool:
	return marching


func urgency() -> float:
	return clampf(1.0 - countdown / Tuning.DUCK_TIME, 0.0, 1.0)


func mother_cell() -> Vector2i:
	return arena.world_to_cell(mother_pos)


func _physics_process(delta: float) -> void:
	t += delta
	if not marching:
		if t >= OPEN_TIME:
			marching = true
		queue_redraw()
		return
	countdown -= delta
	var u := urgency()
	_march(delta, u)
	_sounds(delta, u)
	if countdown <= 0.0:
		game.duck_explode(self)
		queue_free()
		return
	queue_redraw()


func _march(delta: float, u: float) -> void:
	var speed := Tuning.DUCK_SPEED * (1.0 + 0.35 * u)
	phase += delta * (9.0 + 10.0 * u)
	var target: Vector2 = arena.cell_center(next_cell)
	var to := target - mother_pos
	var step := speed * delta
	if to.length() <= step:
		mother_pos = target
		cur_cell = next_cell
		_choose_next()
	else:
		mother_pos += to.normalized() * step
	if trail.is_empty() or mother_pos.distance_to(trail[trail.size() - 1]) > 1.5:
		trail.append(mother_pos)
		var max_len := int(Tuning.DUCKLING_SPACING * (DUCKLINGS + 2) / 1.5) + 10
		if trail.size() > max_len:
			trail.remove_at(0)


func _choose_next() -> void:
	var options := []
	for d in DIRS:
		var n: Vector2i = cur_cell + d
		if d == -heading:
			continue
		if not arena.is_solid(n) and not arena.bombs.has(n):
			options.append(d)
	if options.is_empty():
		var back: Vector2i = cur_cell - heading
		if not arena.is_solid(back) and not arena.bombs.has(back):
			options.append(-heading)
	if options.is_empty():
		next_cell = cur_cell  # boxed in: march on the spot
		return
	var d: Vector2i = options[_rng.randi() % options.size()]
	if heading in options and _rng.randf() < 0.45:
		d = heading
	heading = d
	next_cell = cur_cell + d


func _sounds(delta: float, u: float) -> void:
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = lerpf(0.42, 0.07, pow(u, 1.3))
		Sfx.play("clock_tick", 1.0 + u * 0.4 + _rng.randf_range(-0.05, 0.05), -9.0)
	_quack_t -= delta
	if _quack_t <= 0.0:
		_quack_t = lerpf(1.9, 0.38, u)
		Sfx.play("quack", _rng.randf_range(0.92, 1.05) + u * 0.25, -2.0)
		for i in DUCKLINGS:  # the little ones answer
			_pending.append([0.16 + i * 0.11, "duckling_quack", _rng.randf_range(1.0, 1.2) + u * 0.3])
	if countdown < Tuning.DUCK_WARNING:
		_warn_t -= delta
		if _warn_t <= 0.0:
			_warn_t = lerpf(0.4, 0.12, 1.0 - countdown / Tuning.DUCK_WARNING)
			Sfx.play("duck_warning", 1.0 + (1.0 - countdown / Tuning.DUCK_WARNING) * 0.5, -6.0)
	for p in _pending.duplicate():
		p[0] -= delta
		if p[0] <= 0.0:
			_pending.erase(p)
			Sfx.play(p[1], p[2], -5.0)


## Position and travel direction `dist` px back along the mother's path.
func _back_along(dist: float) -> Array:
	var remaining := dist
	var i := trail.size() - 1
	var p: Vector2 = mother_pos
	while i >= 0:
		var q: Vector2 = trail[i]
		var seg := p.distance_to(q)
		if seg >= remaining and seg > 0.0:
			var pos := p.lerp(q, remaining / seg)
			return [pos, (p - q).normalized(), true]
		remaining -= seg
		p = q
		i -= 1
	return [p, Vector2.DOWN, false]  # still inside the portal


# --- drawing -----------------------------------------------------------------------

func _draw() -> void:
	var T: float = arena.T
	var u := urgency()
	# portal swirl on the wall's front face
	var open := clampf(t / 0.5, 0.0, 1.0) * (1.0 - clampf((t - OPEN_TIME - PORTAL_LINGER) / 0.6, 0.0, 1.0))
	if open > 0.0:
		var pc := _portal_pos() + Vector2(0, -2)
		var cols := [Color("c9b2e3"), Color("f2a7b5"), Color("a8dcc0"), Color("a7c8e8")]
		draw_set_transform(pc, 0.0, Vector2(1.0, 0.7) * open)
		draw_circle(Vector2.ZERO, T * 0.42, Color(0.35, 0.25, 0.45, 0.85))
		for k in 4:
			var r := T * (0.38 - k * 0.08)
			var a0 := t * (3.0 + k) * (1 if k % 2 == 0 else -1)
			draw_arc(Vector2.ZERO, r, a0, a0 + TAU * 0.7, 18, cols[k], 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var sp := Assets.region(fx, Assets.EFFECT_CELLS, 5)
		for k in 3:
			var a := t * 2.0 + k * TAU / 3.0
			var p := pc + Vector2(cos(a) * T * 0.5, sin(a) * T * 0.3)
			draw_texture_rect_region(fx, Rect2(p - Vector2(5, 5), Vector2(10, 10)), sp, Color(1, 1, 1, open))
	if not marching:
		return
	# imminent detonation: show exactly where the confetti will flow
	var warn := countdown < Tuning.DUCK_WARNING
	if warn:
		var pulse := 0.5 + 0.5 * sin(t * (10.0 + 14.0 * u))
		for c in game.duck_blast_cells(mother_cell(), Tuning.DUCK_BLAST_RANGE):
			var r := Rect2(Vector2(c) * T, Vector2(T, T)).grow(-3)
			draw_rect(r, Color(0.95, 0.55, 0.62, 0.12 + 0.18 * pulse))
			UiStyle.stitch_rect(self, r.grow(-2), Color(0.75, 0.3, 0.4, 0.4 + 0.5 * pulse), 1.6, 4.0)
	# ducklings from the back, then the mother on top
	for i in range(DUCKLINGS, 0, -1):
		var info := _back_along(i * Tuning.DUCKLING_SPACING)
		if info[2]:
			_draw_duck(info[0], info[1], 0.62, phase - i * 1.3, u, false)
	_draw_duck(mother_pos, Vector2(heading), 1.0, phase, u, warn)


func _draw_duck(pos: Vector2, dir: Vector2, sc: float, ph: float, u: float, warn: bool) -> void:
	var T: float = arena.T
	var size := T * 1.15 * sc
	if warn:
		size *= 1.0 + 0.08 * absf(sin(t * 18.0))
	var flip := -1.0 if dir.x < -0.1 else 1.0
	var bob := absf(sin(ph)) * 3.0 * sc
	var wobble := sin(ph * 0.5) * (0.08 + 0.25 * u * u) + (sin(t * 47.0 + sc) * 0.12 * u if warn else 0.0)
	# shadow
	draw_set_transform(pos + Vector2(0, T * 0.3), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, size * 0.4, Color(0.3, 0.2, 0.15, 0.2))
	var base := pos + Vector2(0, T * 0.32 - bob)
	draw_set_transform(base, wobble * flip, Vector2(flip, 1.0))
	# spinning wind-up key on the back
	var key_spin := cos(t * (6.0 + 22.0 * u))
	var kr := Assets.region(tex, 2, 1)
	draw_set_transform(base + Vector2(-size * 0.28 * flip, -size * 0.62).rotated(wobble * flip), wobble * flip, Vector2(flip * 0.55 * key_spin, 0.55))
	draw_texture_rect_region(tex, Rect2(-size * 0.5, -size * 0.5, size, size), kr)
	draw_set_transform(base, wobble * flip, Vector2(flip, 1.0))
	var col := Color(0.78, 0.7, 0.68) if Settings.mode == "horror" else Color.WHITE
	if warn and fmod(t * (4.0 + 10.0 * u), 1.0) < 0.5:
		col = Color(1.0, 0.68, 0.7)
	draw_texture_rect_region(tex, Rect2(-size * 0.5, -size, size, size), Assets.region(tex, 2, 0), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if warn:
		var b := pos + Vector2(0, -size * 0.95 - 6.0)
		draw_circle(b, 9.0, Color("fbf5e8"))
		draw_arc(b, 9.0, 0, TAU, 16, Color(0.75, 0.3, 0.4), 2.0)
		draw_string(font, b + Vector2(-8, 6), "!", HORIZONTAL_ALIGNMENT_CENTER, 16, 16, Color(0.75, 0.3, 0.4))
