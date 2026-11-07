## A teddy bear: grid-corridor movement with fluff-dependent inertia,
## bombs, stuns and stuffing theft. Humans and AI drive it through the same
## inputs (input_dir, want_bomb, want_steal, want_special), so both get identical
## physics - and identical curses.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Terrain = preload("res://scripts/terrain.gd")
const BearVisual = preload("res://scripts/bear_visual.gd")
const Taunts = preload("res://scripts/taunts.gd")
const Mode = preload("res://scripts/mode_theme.gd")
const Species = preload("res://scripts/species.gd")

var slot := 0
var bear_name := ""
var color := Color.WHITE
var is_human := false
var species := "bear"
var ctrl_label := ""
var game
var arena
var controller

var fluff: float = Tuning.START_FLUFF:
	set(v):
		# every change is booked once: losses are never erased by later gains
		if v < fluff:
			fluff_lost += fluff - v
		elif v > fluff:
			fluff_gained += v - fluff
		fluff = v
var fluff_lost := 0.0     # stats: stuffing lost this round (stolen, blown out, spilled)
var fluff_gained := 0.0   # stats: stuffing collected this round
var velocity := Vector2.ZERO
var facing := Vector2.DOWN

# Controller inputs
var input_dir := Vector2.ZERO
var want_bomb := false
var want_steal := false
var want_special := false

# Power-ups
var bombs_max := Tuning.START_BOMBS
var bomb_range := Tuning.START_RANGE
var speed_level := 0
var active_bombs := 0
var can_kick := false   # the Bomb Kick power-up (every round starts without it)
var bomb_hits := 0      # stats: other bears stunned by our bombs
var self_hits := 0      # stats: times we stunned ourselves
var bombs_placed := 0   # stats
var pickups := 0        # stats: power-ups collected
var eliminated_at := -1.0   # stats: seconds into the round
var prox_charges := 0     # proximity bombs left (Proximity Bombs power-up)
var has_line := false
var has_rubber := false

# Timed effects
var immortal_t := 0.0
var reverse_t := 0.0
var diarrhea_t := 0.0
var infect_cd := 0.0          # can't pass reverse on yet
var reinfect_immune := 0.0    # just cured
var _diarrhea_cd := 0.0

# Horror footprints (cosmetic)
var blood_feet := 0.0
var _stride := 0.0
var _foot_side := 1.0

# Taunts (purely cosmetic)
var last_hit_by = null
var bubble_text := ""
var bubble_t := 0.0
var taunt_cd := 0.0
var taunt_count := 0
var fluff_at_stun := 0.0
var _rng := RandomNumberGenerator.new()

# State
var stun_t := 0.0
var growl_t := 0.0     # snarling after its bomb stunned someone (arena + ranking cards)
var eliminated := false   # out of stuffing: a limp, empty plush for the rest of the round
const GROWL_TIME := 1.1
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


## Drawn above the rig: cartoon birds and stars, curse icons, the
## immortality halo, the human players' markers.
class Overlay extends Node2D:
	const Taunts_BUBBLE := 1.7
	const Mode = preload("res://scripts/mode_theme.gd")
	var bear
	var tex: Texture2D
	var icons: Texture2D
	var font: Font

	func _ready() -> void:
		tex = Assets.tex("effects/effects")
		icons = Assets.tex("powerups/powerups")
		font = preload("res://scripts/ui_style.gd").font()

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var v = bear.visual
		if v == null or v.head == null:
			return
		var head: Vector2 = v.head.global_position - global_position
		var above := head + Vector2(0, -v.head_r - 10.0)
		var t: float = v.t
		if bear.bubble_t > 0.0:
			_draw_bubble(above + Vector2(0, -30.0 if bear.is_stunned() else -24.0))
		if bear.immortal_t > 0.0:
			var a := 0.25 + 0.15 * sin(t * 6.0)
			if bear.immortal_t < 3.0 and fmod(t * 6.0, 1.0) < 0.5:
				a *= 0.3
			draw_set_transform(Vector2(0, -v.head_r), 0.0, Vector2(1.0, 1.15))
			draw_circle(Vector2.ZERO, v.shadow_w + 14.0, Color(1.0, 0.9, 0.55, a))
			draw_set_transform(above + Vector2(0, 4), 0.0, Vector2(1.0, 0.3))
			draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color(0.95, 0.78, 0.35, 0.95), 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if bear.eliminated:
			return   # nothing circles an empty plush
		if bear.growl_t > 0.0 and not bear.is_stunned():
			_draw_growl(head, v.head_r, t)
		if bear.is_stunned():
			# old-cartoon concussion: birds and stars circling above the head
			var star := Assets.region(tex, Assets.EFFECT_CELLS, 3)
			var bird := Assets.region(tex, Assets.EFFECT_CELLS, 6)
			var rx: float = 16.0 + v.head_r * 0.4
			for i in 4:
				var a: float = t * 3.5 + i * TAU / 4.0
				var p := above + Vector2(cos(a) * rx, sin(a) * 6.0)
				var front := sin(a) > 0.0
				var sz := (15.0 if front else 12.0)
				if i % 2 == 0:
					var flap := 0.75 + 0.25 * sin(t * 30.0 + i)
					var dir := -1.0 if sin(a) > 0.0 else 1.0  # flies the way it orbits
					draw_set_transform(p, 0.0, Vector2(dir, flap))
					draw_texture_rect_region(tex, Rect2(-Vector2(sz, sz) * 0.6, Vector2(sz, sz) * 1.2), bird)
				else:
					draw_set_transform(p, t * 4.0, Vector2.ONE)
					draw_texture_rect_region(tex, Rect2(-Vector2(sz, sz) * 0.5, Vector2(sz, sz)), star)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		var x := -10.0 if (bear.reverse_t > 0.0 and bear.diarrhea_t > 0.0) else 0.0
		for curse in [[bear.reverse_t, 8], [bear.diarrhea_t, 9]]:
			if curse[0] > 0.0:
				var p := above + Vector2(x, -8.0 + sin(t * 5.0 + x) * 2.0)
				draw_set_transform(p, sin(t * 7.0 + x) * 0.25, Vector2.ONE)
				draw_texture_rect_region(icons, Rect2(-10, -10, 20, 20), Assets.region(icons, Assets.POWERUP_CELLS, curse[1]))
				x += 20.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if bear.is_human and bear.bubble_t <= 0.0:
			var y: float = above.y - (22.0 if x != 0.0 else 2.0)
			var c := Color(bear.color.darkened(0.3), 0.95)
			draw_colored_polygon(PackedVector2Array([Vector2(above.x - 6, y - 8), Vector2(above.x + 6, y - 8), Vector2(above.x, y)]), c)
			if bear.bear_name.begins_with("Player "):
				draw_string(font, Vector2(above.x - 20, y - 11), bear.bear_name.substr(7).insert(0, "P"), HORIZONTAL_ALIGNMENT_CENTER, 40, 13, c)

	## "GRRR!" in jagged letters beside the head, with anger ticks.
	func _draw_growl(head: Vector2, head_r: float, t: float) -> void:
		var k: float = bear.growl_t / bear.GROWL_TIME
		var a := clampf(k * 3.0, 0.0, 1.0)
		var col := Color(0.55, 0.05, 0.06, a) if Mode.horror() else Color(0.75, 0.25, 0.15, a)
		var p := head + Vector2(head_r + 6.0, -head_r * 0.6) + Vector2(sin(t * 60.0), cos(t * 47.0)) * 1.5
		draw_set_transform(p, -0.15, Vector2.ONE * (1.0 + 0.25 * (1.0 - k)))
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(font, o * 1.5, "GRRR!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.97, 0.9, a * 0.9))
		draw_string(font, Vector2.ZERO, "GRRR!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var m := head + Vector2(-head_r * 0.8, -head_r * 0.9)   # cartoon anger "vein" mark
		for i in 4:
			var ang := i * PI * 0.5 + 0.785
			draw_line(m + Vector2.from_angle(ang) * 3.0, m + Vector2.from_angle(ang) * 8.0, col, 2.5)

	## A small, short-lived speech bubble that never blocks much of the arena.
	func _draw_bubble(anchor: Vector2) -> void:
		var life: float = bear.bubble_t
		var pop := clampf((Taunts_BUBBLE - life) / 0.15, 0.0, 1.0)
		var fade := clampf(life / 0.3, 0.0, 1.0)
		var cols: Array = Mode.bubble_colors()
		var fs := 12
		var w := font.get_string_size(bear.bubble_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
		var h := 18.0
		var sc := 0.6 + 0.4 * pop
		var jitter := Vector2.ZERO
		if Mode.horror():
			jitter = Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))
		draw_set_transform(anchor + jitter, 0.0, Vector2(sc, sc))
		var r := Rect2(-w * 0.5, -h, w, h)
		var bg: Color = cols[0]
		var fg: Color = cols[1]
		var ol: Color = cols[2]
		draw_rect(r, Color(bg.r, bg.g, bg.b, bg.a * fade))
		draw_rect(r, Color(ol.r, ol.g, ol.b, fade), false, 1.2)
		draw_colored_polygon(PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(0, 6)]), Color(ol.r, ol.g, ol.b, fade))
		draw_string(font, Vector2(-w * 0.5 + 6, -5), bear.bubble_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(fg.r, fg.g, fg.b, fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func setup(g, s: int, n: String, col: Color, spawn: Vector2i) -> void:
	game = g
	arena = g.arena
	slot = s
	bear_name = n
	color = col
	position = arena.cell_center(spawn)
	visual = BearVisual.new()
	species = Species.for_name(n)
	visual.species = species
	visual.source = self
	visual.tint = col
	_rng.randomize()
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


## Eliminated bears count as stunned forever: they can't act, be robbed
## (they have no fluff), be targeted or pick anything up.
func is_stunned() -> bool:
	return stun_t > 0.0 or eliminated


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
	if eliminated:
		input_dir = Vector2.ZERO
		want_bomb = false
		want_steal = false
		want_special = false
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if fluff <= 0.05 and game.state == game.State.PLAYING:
		eliminate()
		return
	if controller and can_act():
		controller.update(delta)
	else:
		input_dir = Vector2.ZERO
		want_bomb = false
		want_steal = false
		want_special = false
	if stun_t > 0.0:
		stun_t -= delta
		if stun_t <= 0.0:
			_recover()
	immune_t = maxf(0.0, immune_t - delta)
	robbed_t = maxf(0.0, robbed_t - delta)
	immortal_t = maxf(0.0, immortal_t - delta)
	bubble_t = maxf(0.0, bubble_t - delta)
	growl_t = maxf(0.0, growl_t - delta)
	taunt_cd = maxf(0.0, taunt_cd - delta)
	infect_cd = maxf(0.0, infect_cd - delta)
	reinfect_immune = maxf(0.0, reinfect_immune - delta)
	if reverse_t > 0.0:
		reverse_t -= delta
		if reverse_t <= 0.0:
			reverse_t = 0.0
			reinfect_immune = Tuning.REVERSE_REINFECT_IMMUNE
	diarrhea_t = maxf(0.0, diarrhea_t - delta)
	_diarrhea_cd -= delta
	if diarrhea_t > 0.0 and game.controls_enabled() and not is_stunned() and _diarrhea_cd <= 0.0 and can_place_bomb():
		_diarrhea_cd = Tuning.DIARRHEA_INTERVAL
		want_bomb = true  # out it comes, whether you like it or not
	if want_special:
		want_special = false
		if game.controls_enabled() and not is_stunned():
			# special: a proximity bomb if we have any, otherwise lay a Line Bomb
			if prox_charges > 0:
				game.place_proximity(self)
			elif has_line:
				game.place_line(self)
	if want_bomb:
		want_bomb = false
		game.try_place_bomb(self)
	_update_steal(delta)
	if not _knock(delta):
		_move(delta)
	queue_redraw()


# --- bomb knockback ---------------------------------------------------------------------

var knock_dir := Vector2i.ZERO
const KNOCK_SPEED := 560.0


## Blown along `dir` by a blast: slide down the corridor until the next tile is
## a wall, block, closed tile or bomb.
var knock_delay := 0.0
const KNOCK_DELAY := 0.18   # a beat between the bang and the bear being blown away


func knock_back(dir: Vector2i) -> void:
	knock_dir = dir
	knock_delay = KNOCK_DELAY
	velocity = Vector2.ZERO
	stealing = false
	steal_target = null
	var cc: Vector2 = arena.cell_center(cell())
	if dir.x != 0:
		position.y = cc.y   # onto the corridor's centre line: nothing to clip on
	else:
		position.x = cc.x


func _knock(delta: float) -> bool:
	if knock_dir == Vector2i.ZERO:
		return false
	if knock_delay > 0.0:   # dazed for a split second, then launched
		knock_delay -= delta
		visual.kick(0.05)
		return true
	var c := cell()
	var dv := Vector2(knock_dir)
	var step := KNOCK_SPEED * delta
	var nxt: Vector2i = c + knock_dir
	if arena.is_solid(nxt) or arena.bombs.has(nxt):
		# glide to the middle of this tile and stop there
		var to: float = (arena.cell_center(c) - position).dot(dv)
		if to <= step:
			position += dv * maxf(to, 0.0)
			knock_dir = Vector2i.ZERO
			velocity = Vector2.ZERO
			visual.bump(0 if dv.x != 0.0 else 1, 420.0, dv.x if dv.x != 0.0 else dv.y)
			Sfx.play("impact", randf_range(0.95, 1.1), -6.0)
			arena.add_shake(2.5)
		else:
			position += dv * step
		return true
	position += dv * step
	if cell() != c:
		game.collect_powerup_at(self, cell())   # whatever lies in the way gets picked up, curses too
	return true


func _update_steal(delta: float) -> void:
	if want_steal and can_act() and input_dir == Vector2.ZERO:
		var target = game.find_steal_target(self)
		if target == null:
			target = game.find_chair(self)   # a delivered chair is looted the same way
		if target != null:
			if not stealing:
				Sfx.play("squeak", 1.4, -4.0)
				game.on_steal_started(self, target)
			stealing = true
			blood_feet = 1.0  # (Horror) grubby paws from rummaging in the stuffing
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
				# the violent part: the victim gets yanked and shaken, the thief tugs
				if target.has_method("is_stunned") and "visual" in target:
					target.visual.kick(0.35)
					target.visual.bump(0, 260.0, signf(target.position.x - position.x))
				visual.kick(0.15)
				if randf() < 0.35:
					Sfx.play("rip", randf_range(0.8, 1.2), -6.0)
					game.arena.add_shake(1.5)
			return
	stealing = false
	steal_target = null


func _move(delta: float) -> void:
	terrain_id = arena.terrain_at(cell())
	var tp: Dictionary = Terrain.props(terrain_id)
	on_bouncy = terrain_id == Terrain.BOUNCY
	var ms: float = max_speed() * tp["speed"]
	var ac: float = accel() * tp["accel"]
	var br: float = maxf(brake() * tp["brake"], tp["brake_min"])
	var dir := input_dir if (can_act() and not stealing) else Vector2.ZERO
	if reverse_t > 0.0:
		dir = -dir  # the curse: left is right, up is down

	var lane := 0.0
	if dir == Vector2.ZERO:
		velocity.x = move_toward(velocity.x, 0.0, br * delta)
		velocity.y = move_toward(velocity.y, 0.0, br * delta)
	else:
		facing = dir
		lane = _lane_offset(dir)
		var lane_v := clampf(lane * Tuning.LANE_PULL, -ms, ms)
		if dir.x != 0.0:
			velocity.x = _drive(velocity.x, dir.x * ms, ac, br, delta)
			velocity.y = _align(velocity.y, lane_v, ac * Tuning.ALIGN_ACCEL, br * Tuning.ALIGN_ACCEL, delta)
		else:
			velocity.y = _drive(velocity.y, dir.y * ms, ac, br, delta)
			velocity.x = _align(velocity.x, lane_v, ac * Tuning.ALIGN_ACCEL, br * Tuning.ALIGN_ACCEL, delta)

	# Gentle corridor-centering: slide into the lane you're steering for, whatever
	# your mass. Momentum is untouched; this only nudges position sideways.
	if dir != Vector2.ZERO and lane != 0.0 and absf(lane) < arena.T * 0.45:
		_sweep(1 if dir.x != 0.0 else 0, signf(lane) * minf(absf(lane), Tuning.CENTER_ASSIST_SPEED * delta), false)

	var before := position
	var push: Vector2 = tp["push"]
	var motion := (velocity + push) * delta
	var restitution: float = tp["bounce"] + 0.06 * minf(fluff_ratio(), 4.0)
	if _sweep(0, motion.x):
		_on_wall(0, restitution)
	if _sweep(1, motion.y):
		_on_wall(1, restitution)
	_footprints(position - before)
	_footsteps(position - before)


## Horror mode: bloody feet leave a fading trail of footprints.
## Footstep sounds from the supplied recordings, by floor material. Plush feet
## are soft, so they sit low in the mix; heavier bears step lower and slower.
const STEP_MATERIAL := {   # terrain -> footsteps/<material> (Normal / Custom, then Horror)
	"normal": ["wood", "ice", "mud", "snow", "concrete", "concrete", "concrete", "concrete"],
	"horror": ["gravel", "glass", "mud", "snow", "stone", "stone", "stone", "stone"],
}
var _step_dist := 0.0


func _footsteps(moved: Vector2) -> void:
	if is_stunned() or moved.length() < 0.05:
		return
	_step_dist += moved.length()
	var stride := 26.0 + 6.0 * minf(fluff_ratio(), 3.0)
	if _step_dist < stride:
		return
	_step_dist = 0.0
	var mats: Array = STEP_MATERIAL["horror" if Mode.horror() else "normal"]
	var heavy := minf(fluff_ratio(), 3.0)
	Sfx.play("footsteps/" + mats[clampi(terrain_id, 0, mats.size() - 1)],
		randf_range(0.95, 1.08) / (0.85 + 0.15 * heavy), -17.0 + 2.0 * heavy)


func _footprints(moved: Vector2) -> void:
	if not Mode.horror():
		return
	if game.flames.has(cell()) or game.is_bloody(cell()):
		blood_feet = 1.0  # stepped in it
	if blood_feet <= 0.02 or is_stunned():
		return
	_stride += moved.length()
	if _stride < Tuning.FOOTPRINT_STRIDE:
		return
	_stride = 0.0
	_foot_side = -_foot_side
	var d := moved.normalized() if moved.length() > 0.01 else facing
	var side := Vector2(-d.y, d.x) * _foot_side * (3.0 + 1.2 * minf(fluff_ratio(), 3.0))
	game.add_footprint(position + Vector2(0, 12) + side, d, blood_feet)
	blood_feet = maxf(0.0, blood_feet - Tuning.BLOOD_PER_PRINT)

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
	var m := 0 if dir.x != 0.0 else 1   # axis we want to move along
	var p := 1 - m                       # lanes are spaced along the other axis
	var step := int(dir[m])
	var pos_p: float = position[p]
	var center_p: float = arena.cell_center(c)[p]
	var off := pos_p - center_p
	var cand := [c[p]]
	if absf(off) > 2.0:
		cand.append(c[p] + (1 if off > 0.0 else -1))
	# Turn look-ahead: pressed a little early? Keep sliding to the next opening.
	if absf(velocity[p]) > 30.0:
		var ahead: int = c[p] + (1 if velocity[p] > 0.0 else -1)
		if not ahead in cand:
			cand.append(ahead)
	var best := INF
	var best_off := center_p - pos_p
	for lane in cand:
		var here := c
		here[p] = lane
		var next := here
		next[m] += step
		if arena.blocks_bear(here, self) or arena.blocks_bear(next, self):
			continue
		var lane_off: float = arena.cell_center(here)[p] - pos_p
		if lane != c[p] and absf(lane_off) > Tuning.TURN_LOOKAHEAD * arena.T:
			continue
		if absf(lane_off) < best:
			best = absf(lane_off)
			best_off = lane_off
	return best_off


## Moves along one axis; clamps against solid cells. Returns true on contact.
func _sweep(axis: int, amount: float, allow_kick := true) -> bool:
	if amount == 0.0:
		return false
	var h := Tuning.HITBOX_HALF
	var T: float = arena.T
	var pos := position
	pos[axis] += amount
	var minc: Vector2i = arena.world_to_cell(pos - Vector2(h, h))
	var maxc: Vector2i = arena.world_to_cell(pos + Vector2(h, h) - Vector2(0.001, 0.001))
	var hit := false
	var kicked = null
	for cx in range(minc.x, maxc.x + 1):
		for cy in range(minc.y, maxc.y + 1):
			var c := Vector2i(cx, cy)
			if not arena.blocks_bear(c, self):
				continue
			hit = true
			if can_kick and allow_kick and arena.bombs.has(c):
				kicked = arena.bombs[c]
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
	if kicked != null and not stunned_or_stealing():
		# only kick a bomb we're roughly lined up with
		var perp := 1 - axis
		if absf(position[perp] - kicked.position[perp]) < 14.0:
			var d := Vector2i.ZERO
			d[axis] = 1 if amount > 0.0 else -1
			if not kicked.is_moving():
				kicked.kick(d)
				if kicked.is_moving():
					game.event("kick", {"bear": self, "owner": kicked.owner_bear})
	return hit


func stunned_or_stealing() -> bool:
	return is_stunned() or stealing


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
	if is_stunned() or immune_t > 0.0 or immortal_t > 0.0:
		return
	stun_t = Tuning.STUN_TIME
	blood_feet = 1.0  # (Horror) bleeds into its own trail when it gets up
	times_stunned += 1
	fluff_at_stun = fluff
	stealing = false
	steal_target = null
	var away := position - from_pos
	if away.length() > 1.0:
		velocity += away.normalized() * 90.0
	visual.on_stunned(signf(away.x) if absf(away.x) > 1.0 else 0.0)
	Sfx.play("concussion", randf_range(0.95, 1.08) / pow(maxf(fluff_ratio(), 0.35), 0.25))
	game.on_bear_stunned(self)


## Zero stuffing: collapses into a deflated, lifeless plush and is out of the round.
func eliminate() -> void:
	eliminated = true
	eliminated_at = game.round_duration - game.time_left
	fluff = 0.0
	stun_t = 0.0
	velocity = Vector2.ZERO
	knock_dir = Vector2i.ZERO
	stealing = false
	steal_target = null
	reverse_t = 0.0
	diarrhea_t = 0.0
	immortal_t = 0.0
	growl_t = 0.0
	bubble_t = 0.0
	visual.on_eliminated()
	Sfx.play("eliminated")
	game.on_bear_eliminated(self)


## Our bomb just stunned someone: a visible, audible growl.
func growl() -> void:
	if is_stunned() or growl_t > 0.3:
		return
	growl_t = GROWL_TIME
	visual.play_growl()
	Sfx.play("growl", randf_range(0.9, 1.05) / pow(maxf(fluff_ratio(), 0.4), 0.2), -2.0)


func _recover() -> void:
	stun_t = 0.0
	immune_t = Tuning.STUN_IMMUNE
	visual.on_recover()
	if fluff_at_stun - fluff > 10.0:
		taunt("robbed", true)  # wakes up noticeably lighter
	Sfx.play("pop", 1.3)


## Show a cheeky (or creepy) line with a reaction animation and voice.
## Cosmetic only: never affects movement. Rate-limited so it can't clutter.
func taunt(kind: String, force := false) -> void:
	if not game.controls_enabled() and kind != "robbed":
		return
	if not force and (taunt_cd > 0.0 or game.bubble_count() >= 2):
		return
	bubble_text = Taunts.line(kind, bear_name, _rng)
	bubble_t = 1.7
	taunt_cd = 4.0
	taunt_count += 1
	visual.play_taunt(Taunts.anim(_rng))
	var pitch: float = Taunts.VOICE.get(bear_name, 1.0) * _rng.randf_range(0.93, 1.07) / pow(maxf(fluff_ratio(), 0.4), 0.2)
	Sfx.play("taunt", pitch, -3.0)


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
