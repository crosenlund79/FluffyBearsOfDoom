## Princess Hunt (a one-time trap power-up): her crown peeks over the outer
## wall, she leaps in laughing, hunts the nearest active bear along the grid
## corridors (switching to whoever becomes closer), and on reaching it fires
## one devastating shotgun blast, then leaps back out over the wall.
## A bomb blast on her tile drives her off early. Against an immortal bear the
## shot is a harmless blank. She uses the princess character sheet, so custom
## and Horror art for "bears/princess" apply to her too.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const BearVisual = preload("res://scripts/bear_visual.gd")
const Mode = preload("res://scripts/mode_theme.gd")
const UiStyle = preload("res://scripts/ui_style.gd")

enum { WARN, LEAP_IN, HUNT, AIM, FIRE, LEAP_OUT, DONE }
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const LEAP_TIME := 0.75
const AIM_TIME := 0.6
const FIRE_TIME := 0.7

var game
var arena
var phase := WARN
var t := 0.0
var age := 0.0
var target = null
var path: Array = []
var _repath := 0.0
var hunt_time := 0.0               # time spent hunting since she landed
const SWITCH_MARGIN := 2.0         # another bear must be this many tiles closer to steal her attention
const HUNT_GIVE_UP := 10.0         # after this long on foot she just leaps at her prey
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var wall_spot := Vector2.ZERO      # where she peeks over the wall
var height := 0.0                  # jump height (drawn offset)
var defeated := false
var blank := false
var puppet
var visual
var font: Font


func setup(g) -> void:
	game = g
	arena = g.arena
	font = UiStyle.font()
	# a random point on the outer wall, and the open tile she'll land on
	var side := randi() % 4
	var c := Vector2i.ZERO
	match side:
		0: c = Vector2i(randi_range(2, arena.cols - 3), 0)
		1: c = Vector2i(randi_range(2, arena.cols - 3), arena.rows - 1)
		2: c = Vector2i(0, randi_range(2, arena.rows - 3))
		_: c = Vector2i(arena.cols - 1, randi_range(2, arena.rows - 3))
	wall_spot = arena.cell_center(c)
	var out: Vector2 = (wall_spot - arena.cell_center(Vector2i(arena.cols / 2, arena.rows / 2))).normalized()
	leap_from = wall_spot + out * arena.T * 1.4
	leap_to = arena.cell_center(game.nearest_open_cell(c))
	position = leap_from
	puppet = BearVisual.Puppet.new()
	puppet.fluff = 130.0
	puppet.smug = true
	visual = BearVisual.new()
	visual.species = "princess"
	visual.source = puppet
	visual.tint = Color(0.82, 0.74, 0.76) if Mode.horror() else Color("f2b3cf")
	visual.seed_offset = 3.3
	visual.scale = Vector2.ONE * perspective_scale()
	visual.visible = false
	add_child(visual)
	var gun := Gun.new()
	gun.owner_hunt = self
	add_child(gun)
	game.hud.banner("The Princess is coming!" if not Mode.horror() else "Her Highness hungers...", 1.8)
	Sfx.play("doom_warn", 1.3, -4.0)


## A bomb blast on her tile drives her off (she can't be stunned, but she's had enough).
func blasted() -> void:
	if defeated or not on_ground():
		return
	defeated = true
	game.on_princess_defeated(self)
	_leave()


func cell() -> Vector2i:
	return arena.world_to_cell(position)


func on_ground() -> bool:
	return phase in [HUNT, AIM, FIRE]


func _next(p: int) -> void:
	phase = p
	t = 0.0


func _physics_process(delta: float) -> void:
	if phase == DONE:
		return
	t += delta
	age += delta
	if game.state != game.State.PLAYING and phase != LEAP_OUT:
		_leave()

	# the Time of Doom shut her tile: hop to open ground
	if phase == HUNT and arena.is_solid(cell()):
		_leap_to(arena.cell_center(game.nearest_open_cell(cell())), HUNT)
	if age > Tuning.PRINCESS_MAX_TIME and phase in [HUNT, AIM]:
		_leave()
	match phase:
		WARN:
			if t >= Tuning.PRINCESS_WARN:
				visual.visible = true
				Sfx.play("princess_laugh")
				_leap_to(leap_to, HUNT)
		LEAP_IN:
			var k := clampf(t / LEAP_TIME, 0.0, 1.0)
			position = leap_from.lerp(leap_to, k)
			height = sin(k * PI) * arena.T * 2.2
			if k >= 1.0:
				height = 0.0
				z_index = 0
				visual.kick(0.5)
				game.spawn_dust(position + Vector2(0, 12), 6)
				arena.add_shake(4.0)
				_next(_after_leap)
		HUNT:
			_hunt(delta)
		AIM:
			puppet.velocity = Vector2.ZERO
			if not is_instance_valid(target) or target.eliminated:
				_next(HUNT)
			elif t >= AIM_TIME:
				_fire()
		FIRE:
			if t >= 0.45 and t - delta < 0.45:
				Sfx.play("shell_drop", randf_range(0.95, 1.05), -6.0)
			if t >= FIRE_TIME:
				_leave()
		LEAP_OUT:
			var k := clampf(t / LEAP_TIME, 0.0, 1.0)
			position = leap_from.lerp(leap_to, k)
			height = sin(k * PI) * arena.T * 2.4
			modulate.a = 1.0 - clampf((k - 0.75) / 0.25, 0.0, 1.0)
			if k >= 1.0:
				phase = DONE
				game.princess = null
				queue_free()
				return
	queue_redraw()


var _after_leap := HUNT


func _leap_to(dest: Vector2, then: int) -> void:
	leap_from = position
	leap_to = dest
	_after_leap = then
	z_index = 4   # sails over walls and bears
	_next(LEAP_IN)


## Leave over the nearest stretch of outer wall.
func _leave() -> void:
	if phase in [LEAP_OUT, DONE]:
		return
	visual.visible = true
	var p := position
	var w: float = arena.cols * arena.T
	var h: float = arena.rows * arena.T
	var exits := [Vector2(p.x, -arena.T * 1.6), Vector2(p.x, h + arena.T * 1.6), Vector2(-arena.T * 1.6, p.y), Vector2(w + arena.T * 1.6, p.y)]
	var best: Vector2 = exits[0]
	for e in exits:
		if p.distance_to(e) < p.distance_to(best):
			best = e
	leap_from = p
	leap_to = best
	z_index = 4
	Sfx.play("princess_laugh", 1.15, -4.0)
	_next(LEAP_OUT)


# --- hunting ----------------------------------------------------------------------------

func _hunt(delta: float) -> void:
	_repath -= delta
	hunt_time += delta
	if hunt_time > HUNT_GIVE_UP and target != null and is_instance_valid(target) and not target.eliminated:
		hunt_time = 0.0
		_leap_at_target()
		return
	var here := cell()
	if _repath <= 0.0 or path.is_empty():
		_repath = 0.2
		_choose_target(here)
	if target == null:
		_leave()
		return
	if position.distance_to(target.position) < arena.T * 1.15:
		puppet.velocity = Vector2.ZERO
		Sfx.play("princess_laugh", 1.05, -2.0)   # caught up: laugh, aim, fire
		_next(AIM)
		return
	if path.is_empty():
		# no corridor leads there (blocks, bombs): she simply leaps over
		_leap_at_target()
		return
	var goal: Vector2 = arena.cell_center(path[0])
	var to := goal - position
	var step: float = Tuning.PRINCESS_SPEED * delta
	if to.length() <= step:
		position = goal
		path.pop_front()
	else:
		position += to.normalized() * step
	puppet.velocity = to.normalized() * Tuning.PRINCESS_SPEED
	puppet.facing = Vector2(signf(to.x), 0) if absf(to.x) > absf(to.y) else Vector2(0, signf(to.y))


## Nearest active bear by corridor distance (bombs and solid tiles block);
## re-evaluated several times a second, so she switches to a closer one.
func _choose_target(here: Vector2i) -> void:
	var dist := {here: 0}
	var parent := {}
	var q := [here]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in DIRS:
			var n: Vector2i = c + d
			if dist.has(n) or arena.is_solid(n) or arena.bombs.has(n):
				continue
			dist[n] = dist[c] + 1
			parent[n] = c
			q.append(n)
	var best = null
	var best_d := INF
	var current_d := INF
	for b in game.bears:
		if b.eliminated:
			continue
		var bc: Vector2i = b.cell()
		var d: float = dist.get(bc, 1000.0 + b.position.distance_to(position) / arena.T)
		if b == target:
			current_d = d
		if d < best_d:
			best_d = d
			best = b
	# keep chasing the current prey unless someone is clearly closer (no dithering)
	if target != null and is_instance_valid(target) and not target.eliminated and current_d <= best_d + SWITCH_MARGIN:
		best = target
	target = best
	path.clear()
	if best == null or not dist.has(best.cell()):
		return
	var c: Vector2i = best.cell()
	while c != here:
		path.push_front(c)
		c = parent[c]


## Leap next to the target, or, if she's already as close as open ground
## allows (or within shotgun range), take aim right where she stands.
func _leap_at_target() -> void:
	var near: Vector2i = game.nearest_open_cell(target.cell())
	if near == cell() or position.distance_to(target.position) < arena.T * 2.5:
		puppet.velocity = Vector2.ZERO
		Sfx.play("princess_laugh", 1.05, -2.0)
		_next(AIM)
		return
	_leap_to(arena.cell_center(near), HUNT)


func _fire() -> void:
	_next(FIRE)
	blank = target.immortal_t > 0.0 or target.immune_t > 0.0
	Sfx.play("shotgun", randf_range(0.97, 1.03), 0.0)
	arena.add_shake(9.0 if not blank else 3.0)
	game.on_princess_shot(self, target, blank)


# --- drawing ------------------------------------------------------------------------------

## Perspective: the arena is a pit below the raised rim, so she looks biggest
## up on the rim / outside the wall and in mid-leap, and a little smaller once
## she's down on the playfield, where she is still clearly bigger than a bear.
const SCALE_FLOOR := 1.3     # down in the arena (bears are 1.0)
const SCALE_RIM := 1.65      # up on the raised rim, outside the wall


func perspective_scale() -> float:
	var T: float = arena.T
	var inner := Rect2(Vector2(T, T), Vector2(arena.cols - 2, arena.rows - 2) * T)
	var outside := 0.0
	if not inner.has_point(position):
		var dx := maxf(inner.position.x - position.x, position.x - inner.end.x)
		var dy := maxf(inner.position.y - position.y, position.y - inner.end.y)
		outside = clampf(maxf(dx, dy) / T, 0.0, 1.0)
	var lift := clampf(height / (T * 2.4), 0.0, 1.0)
	return lerpf(SCALE_FLOOR, SCALE_RIM, maxf(outside, lift * 0.8))


func _process(_delta: float) -> void:
	if visual != null:
		visual.position = Vector2(0, -height)
		visual.scale = Vector2.ONE * perspective_scale()
	queue_redraw()


func _draw() -> void:
	var T: float = arena.T
	if phase == WARN:
		# her crown and fingertips peek over the wall, with a pulsing alarm
		var k := clampf(t / Tuning.PRINCESS_WARN, 0.0, 1.0)
		var p := wall_spot - position
		var pulse := 0.5 + 0.5 * sin(age * 14.0)
		draw_circle(p, T * (0.7 + 0.2 * pulse), Color(0.95, 0.3, 0.55, 0.25 + 0.25 * pulse) if not Mode.horror() else Color(0.6, 0.0, 0.05, 0.3 + 0.3 * pulse))
		var cr := p + Vector2(0, -T * 0.25 - 6.0 * k)
		draw_colored_polygon(PackedVector2Array([cr + Vector2(-14, 6), cr + Vector2(-14, -6), cr + Vector2(-7, 0),
			cr + Vector2(0, -10), cr + Vector2(7, 0), cr + Vector2(14, -6), cr + Vector2(14, 6)]), Color(0.95, 0.78, 0.25))
		draw_string(font, p + Vector2(-8, -T * 0.75), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.9, 0.1, 0.25, 0.6 + 0.4 * pulse))
		return
	# shadow on the floor (stays down while she's in the air)
	var sh := 1.0 - clampf(height / (T * 2.4), 0.0, 0.7)
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 20.0 * sh, Color(0.1, 0.05, 0.05, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# while aiming: a laser-dot line to the victim
	if phase == AIM and is_instance_valid(target):
		var blink := 0.5 + 0.5 * sin(age * 30.0)
		draw_dashed_line(Vector2(0, -18), target.position - position + Vector2(0, -18), Color(1, 0.1, 0.2, 0.5 + 0.5 * blink), 2.0, 7.0)
		draw_circle(target.position - position + Vector2(0, -18), 4.0 + 2.0 * blink, Color(1, 0.1, 0.2, 0.8))


## Her (toy, or very much not toy in Horror) shotgun and its blast, drawn over the rig.
class Gun extends Node2D:
	var owner_hunt

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var h = owner_hunt
		if h.phase in [h.WARN, h.DONE] or not h.visual.visible:
			return
		var horror := Mode.horror()
		var aim := Vector2(h.puppet.facing.x, 0) if absf(h.puppet.facing.x) > 0.0 else Vector2(1, 0)
		if (h.phase == h.AIM or h.phase == h.FIRE) and is_instance_valid(h.target):
			aim = (h.target.position - h.position).normalized()
		var base := Vector2(0, -22 - h.height)
		var tip := base + aim * 30.0
		var stock := Color(0.35, 0.2, 0.12) if horror else Color(0.95, 0.55, 0.75)
		var barrel := Color(0.25, 0.25, 0.28) if horror else Color(0.75, 0.45, 0.85)
		draw_line(base - aim * 8.0, base + aim * 6.0, stock, 7.0)
		draw_line(base + aim * 4.0, tip, barrel, 4.5)
		if h.phase == h.FIRE and h.t < 0.25:
			var k: float = h.t / 0.25
			var flash := Color(1.0, 0.85, 0.3, 1.0 - k) if not h.blank else Color(0.8, 0.8, 0.8, 0.8 - k)
			draw_circle(tip + aim * 8.0, 10.0 * (1.0 - k) + 3.0, flash)
			if not h.blank:
				var to: Vector2 = h.target.position - h.position + Vector2(0, -18)
				for i in 7:   # the spread of pellets (or glitter in Normal)
					var off := Vector2(-aim.y, aim.x) * (i - 3) * 4.0 * (0.3 + k)
					var pc := Color(1, 0.9, 0.5, 1.0 - k) if horror else Color.from_hsv(fmod(i * 0.14, 1.0), 0.5, 1.0, 1.0 - k)
					draw_line(tip, tip.lerp(to + off, minf(1.0, k * 2.5)), pc, 2.0)
		if h.phase == h.FIRE and h.blank and h.t < h.FIRE_TIME:
			var a: float = 1.0 - h.t / h.FIRE_TIME
			draw_circle(tip + aim * 10.0 + Vector2(0, -h.t * 30.0), 8.0 + h.t * 20.0, Color(0.85, 0.85, 0.85, 0.5 * a))
			draw_string(h.font, tip + Vector2(-24, -24), "BLANK!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.4, 0.45, a))
