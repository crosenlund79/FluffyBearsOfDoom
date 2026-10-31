## A teddy bear: grid-corridor movement with fluff-dependent inertia,
## bombs, stuns and stuffing theft. Humans and AI drive it through the same
## three inputs (input_dir, want_bomb, want_steal), so both get identical physics.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Terrain = preload("res://scripts/terrain.gd")
const BearVisual = preload("res://scripts/bear_visual.gd")

var slot := 0
var bear_name := ""
var color := Color.WHITE
var is_human := false
var game
var arena
var controller

var fluff: float = Tuning.START_FLUFF
var velocity := Vector2.ZERO
var facing := Vector2.DOWN

# Controller inputs
var input_dir := Vector2.ZERO
var want_bomb := false
var want_steal := false

# Power-ups
var bombs_max := Tuning.START_BOMBS
var bomb_range := Tuning.START_RANGE
var speed_level := 0
var active_bombs := 0

# State
var stun_t := 0.0
var immune_t := 0.0
var robbed_t := 0.0
var stealing := false
var steal_target = null
var on_bouncy := false
var terrain_id := 0

# Stats for the results screen
var stolen_total := 0.0
var times_stunned := 0

var visual
var overlay
var _steal_sfx_t := 0.0


## Drawn above the rig: dizzy stars, the human player's marker.
class Overlay extends Node2D:
	var bear
	var tex: Texture2D

	func _ready() -> void:
		tex = Assets.tex("effects/effects")

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var v = bear.visual
		if v == null or v.head == null:
			return
		var head: Vector2 = v.head.global_position - global_position
		if bear.is_stunned():
			var region := Assets.region(tex, Assets.EFFECT_CELLS, 3)
			for i in 3:
				var a: float = v.t * 4.0 + i * TAU / 3.0
				var p := head + Vector2(cos(a) * 17.0, sin(a) * 6.0 - 14.0)
				var s := 13.0 + sin(a) * 2.0
				draw_texture_rect_region(tex, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), region)
		elif bear.is_human:
			var y: float = v.position.y + v.head_top - 12.0
			var c := Color(bear.color.darkened(0.25), 0.9)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, y - 8), Vector2(6, y - 8), Vector2(0, y)]), c)


func setup(g, s: int, n: String, col: Color, spawn: Vector2i) -> void:
	game = g
	arena = g.arena
	slot = s
	bear_name = n
	color = col
	position = arena.cell_center(spawn)
	visual = BearVisual.new()
	visual.source = self
	visual.tint = col
	visual.seed_offset = s * 1.7
	add_child(visual)
	overlay = Overlay.new()
	overlay.bear = self
	add_child(overlay)


# --- fluff-dependent physical properties ------------------------------------------

func fluff_ratio() -> float:
	return fluff / Tuning.START_FLUFF


func mass() -> float:
	return Tuning.MASS_MIN + Tuning.MASS_PER_RATIO * fluff_ratio()


func max_speed() -> float:
	var m := mass()
	return Tuning.BASE_SPEED * clampf(1.0 + Tuning.SPEED_MASS_FALLOFF * (1.0 - m), 0.55, 1.18) + speed_level * Tuning.SPEED_UP_SPEED


func accel() -> float:
	return minf(Tuning.BASE_ACCEL / pow(mass(), Tuning.ACCEL_EXP) * (1.0 + speed_level * Tuning.SPEED_UP_ACCEL), 4500.0)


func brake() -> float:
	return minf(Tuning.BASE_BRAKE / pow(mass(), Tuning.BRAKE_EXP), 6000.0)


func cell() -> Vector2i:
	return arena.world_to_cell(position)


func is_stunned() -> bool:
	return stun_t > 0.0


func can_act() -> bool:
	return not is_stunned() and game.controls_enabled()


func can_place_bomb() -> bool:
	return active_bombs < bombs_max and not arena.bombs.has(cell())


func overlaps_cell(c: Vector2i) -> bool:
	var h := Tuning.HITBOX_HALF
	var r := Rect2(position - Vector2(h, h), Vector2(h, h) * 2.0)
	var cr := Rect2(Vector2(c) * arena.T, Vector2(arena.T, arena.T))
	return r.intersects(cr)


# --- per-frame ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if controller and can_act():
		controller.update(delta)
	else:
		input_dir = Vector2.ZERO
		want_bomb = false
		want_steal = false
	if stun_t > 0.0:
		stun_t -= delta
		if stun_t <= 0.0:
			_recover()
	immune_t = maxf(0.0, immune_t - delta)
	robbed_t = maxf(0.0, robbed_t - delta)
	if want_bomb:
		want_bomb = false
		game.try_place_bomb(self)
	_update_steal(delta)
	_move(delta)
	queue_redraw()


func _update_steal(delta: float) -> void:
	if want_steal and can_act():
		var target = game.find_steal_target(self)
		if target != null:
			if not stealing:
				Sfx.play("squeak", 1.4, -4.0)
			stealing = true
			steal_target = target
			var amount := minf(Tuning.STEAL_RATE * delta, target.fluff)
			target.fluff -= amount
			fluff += amount
			stolen_total += amount
			target.robbed_t = Tuning.ROBBED_GRUMPY
			var d: Vector2 = target.position - position
			facing = Vector2(signf(d.x), 0) if absf(d.x) > absf(d.y) else Vector2(0, signf(d.y))
			_steal_sfx_t -= delta
			if _steal_sfx_t <= 0.0:
				_steal_sfx_t = 0.12
				Sfx.play("steal", randf_range(0.9, 1.4) / sqrt(maxf(fluff_ratio(), 0.3)), -8.0)
			return
	stealing = false
	steal_target = null


func _move(delta: float) -> void:
	terrain_id = arena.terrain_at(cell())
	var tp: Dictionary = Terrain.props(terrain_id)
	on_bouncy = terrain_id == Terrain.BOUNCY
	var ms: float = max_speed() * tp["speed"]
	var ac: float = accel() * tp["accel"]
	var br: float = brake() * tp["brake"]
	var dir := input_dir if (can_act() and not stealing) else Vector2.ZERO

	if dir == Vector2.ZERO:
		velocity.x = move_toward(velocity.x, 0.0, br * delta)
		velocity.y = move_toward(velocity.y, 0.0, br * delta)
	else:
		facing = dir
		var lane := _lane_offset(dir)
		var lane_v := clampf(lane * Tuning.LANE_PULL, -ms, ms)
		if dir.x != 0.0:
			velocity.x = _drive(velocity.x, dir.x * ms, ac, br, delta)
			velocity.y = _align(velocity.y, lane_v, ac * Tuning.ALIGN_ACCEL, br * Tuning.ALIGN_ACCEL, delta)
		else:
			velocity.y = _drive(velocity.y, dir.y * ms, ac, br, delta)
			velocity.x = _align(velocity.x, lane_v, ac * Tuning.ALIGN_ACCEL, br * Tuning.ALIGN_ACCEL, delta)

	var push: Vector2 = tp["push"]
	var motion := (velocity + push) * delta
	var restitution: float = tp["bounce"] + 0.06 * minf(fluff_ratio(), 4.0)
	if _sweep(0, motion.x):
		_on_wall(0, restitution)
	if _sweep(1, motion.y):
		_on_wall(1, restitution)


## Accelerate along the pressed axis; reversing uses brake + accel.
func _drive(v: float, target: float, ac: float, br: float, dt: float) -> float:
	if v != 0.0 and signf(v) != signf(target):
		return move_toward(v, target, (ac + br) * dt)
	if absf(v) > absf(target):
		return move_toward(v, target, br * dt)
	return move_toward(v, target, ac * dt)


## The perpendicular axis: steer into the lane, but momentum only bleeds off
## through braking - this is what makes heavy bears overshoot intersections.
func _align(v: float, target: float, ac: float, br: float, dt: float) -> float:
	if absf(v) > absf(target) or (v != 0.0 and signf(v) != signf(target)):
		return move_toward(v, target, br * dt)
	return move_toward(v, target, ac * dt)


## Offset (along the perpendicular axis) to the lane centre that leads in `dir`.
func _lane_offset(dir: Vector2) -> float:
	var c := cell()
	var ctr: Vector2 = arena.cell_center(c)
	if dir.x != 0.0:
		var off := position.y - ctr.y
		var cand := [c.y]
		if absf(off) > 2.0:
			cand.append(c.y + (1 if off > 0.0 else -1))
		for r in cand:
			if not arena.blocks_bear(Vector2i(c.x, r), self) and not arena.blocks_bear(Vector2i(c.x + int(dir.x), r), self):
				return arena.cell_center(Vector2i(c.x, r)).y - position.y
		return ctr.y - position.y
	var offx := position.x - ctr.x
	var candx := [c.x]
	if absf(offx) > 2.0:
		candx.append(c.x + (1 if offx > 0.0 else -1))
	for q in candx:
		if not arena.blocks_bear(Vector2i(q, c.y), self) and not arena.blocks_bear(Vector2i(q, c.y + int(dir.y)), self):
			return arena.cell_center(Vector2i(q, c.y)).x - position.x
	return ctr.x - position.x


## Moves along one axis; clamps against solid cells. Returns true on contact.
func _sweep(axis: int, amount: float) -> bool:
	if amount == 0.0:
		return false
	var h := Tuning.HITBOX_HALF
	var T: float = arena.T
	var pos := position
	pos[axis] += amount
	var minc: Vector2i = arena.world_to_cell(pos - Vector2(h, h))
	var maxc: Vector2i = arena.world_to_cell(pos + Vector2(h, h) - Vector2(0.001, 0.001))
	var hit := false
	for cx in range(minc.x, maxc.x + 1):
		for cy in range(minc.y, maxc.y + 1):
			var c := Vector2i(cx, cy)
			if not arena.blocks_bear(c, self):
				continue
			hit = true
			if axis == 0:
				if amount > 0.0:
					pos.x = minf(pos.x, cx * T - h - 0.001)
				else:
					pos.x = maxf(pos.x, (cx + 1) * T + h + 0.001)
			else:
				if amount > 0.0:
					pos.y = minf(pos.y, cy * T - h - 0.001)
				else:
					pos.y = maxf(pos.y, (cy + 1) * T + h + 0.001)
	position = pos
	return hit


func _on_wall(axis: int, restitution: float) -> void:
	var impact := absf(velocity[axis])
	var dir := signf(velocity[axis])
	velocity[axis] = -velocity[axis] * restitution
	if impact > Tuning.BUMP_MIN_SPEED:
		visual.bump(axis, impact, dir)
		var pitch := 1.25 / sqrt(maxf(fluff_ratio(), 0.35))
		if on_bouncy:
			Sfx.play("boing", pitch * randf_range(0.9, 1.1), -6.0)
		else:
			Sfx.play("squeak" if impact > 140.0 else "bump", pitch * randf_range(0.9, 1.1), linear_to_db(clampf(impact / 220.0, 0.2, 1.0)) - 6.0)
		if impact > 150.0:
			game.spawn_dust(position + Vector2(dir * Tuning.HITBOX_HALF if axis == 0 else 0.0, dir * Tuning.HITBOX_HALF if axis == 1 else 0.0), 2)


# --- events -------------------------------------------------------------------------

func stun(from_pos: Vector2) -> void:
	if is_stunned() or immune_t > 0.0:
		return
	stun_t = Tuning.STUN_TIME
	times_stunned += 1
	stealing = false
	steal_target = null
	var away := position - from_pos
	if away.length() > 1.0:
		velocity += away.normalized() * 90.0
	visual.on_stunned(signf(away.x) if absf(away.x) > 1.0 else 0.0)
	Sfx.play("stun", randf_range(0.9, 1.1) / sqrt(maxf(fluff_ratio(), 0.35)))
	game.on_bear_stunned(self)


func _recover() -> void:
	stun_t = 0.0
	immune_t = Tuning.STUN_IMMUNE
	visual.on_recover()
	Sfx.play("pop", 1.3)


func add_fluff(amount: float) -> void:
	fluff += amount
	visual.kick(0.12)


func _draw() -> void:
	# Soft plush shadow, independent of the rig's flopping and hopping.
	if visual == null:
		return
	var w: float = visual.shadow_w * (1.0 - visual.hop * 0.02)
	draw_set_transform(Vector2(0, 15), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, w, Color(0.3, 0.2, 0.15, 0.2))
	draw_circle(Vector2.ZERO, w * 0.7, Color(0.3, 0.2, 0.15, 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
