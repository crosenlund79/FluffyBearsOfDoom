## One match: arena, four bears, bombs, flames, power-ups, theft, Biome
## Shuffle, timer and results.
extends Node2D

signal quit_to_menu
signal restart_requested

const Tuning = preload("res://scripts/tuning.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Maps = preload("res://scripts/arena_maps.gd")
const ArenaScript = preload("res://scripts/arena.gd")
const BearScript = preload("res://scripts/bear.gd")
const BombScript = preload("res://scripts/bomb.gd")
const ExplosionScript = preload("res://scripts/explosion.gd")
const PowerupScript = preload("res://scripts/powerup.gd")
const ParticleScript = preload("res://scripts/particle.gd")
const PickupScript = preload("res://scripts/fluff_pickup.gd")
const HumanController = preload("res://scripts/human_controller.gd")
const AiController = preload("res://scripts/ai_controller.gd")
const HudScript = preload("res://scripts/hud.gd")
const UiStyle = preload("res://scripts/ui_style.gd")

enum State { COUNTDOWN, PLAYING, ENDED }

const ARENA_ORIGIN := Vector2(40, 52)
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var state := State.COUNTDOWN
var time_left := 150.0
var countdown := 3.0
var rng := RandomNumberGenerator.new()

var arena
var powerup_layer: Node2D
var bomb_layer: Node2D
var flame_layer: Node2D
var bear_layer: Node2D
var fx_layer: Node2D
var hud

var bears: Array = []
var bombs: Array = []
var flames := {}      # Vector2i -> seconds left
var powerups := {}    # Vector2i -> power-up node
var pickups: Array = []
var shuffle_events: Array = []
var fx_tex: Texture2D
var fluff_tex: Texture2D
var _steal_fx_t := 0.0
var _last_count := 4


func _ready() -> void:
	rng.randomize()
	Settings.apply_input_bindings()
	fx_tex = Assets.tex("effects/effects")
	fluff_tex = Assets.tex("objects/fluff")
	time_left = Tuning.ROUND_TIMES[Settings.round_time_index]

	arena = ArenaScript.new()
	arena.position = ARENA_ORIGIN
	add_child(arena)
	arena.setup(Maps.MAPS[Settings.arena_index], rng, PowerupScript.WEIGHTS)

	powerup_layer = _layer(1)
	bomb_layer = _layer(2)
	flame_layer = _layer(3)
	bear_layer = _layer(5)
	bear_layer.y_sort_enabled = true
	fx_layer = _layer(8)

	var roster: Array = Settings.roster()
	for i in roster.size():
		var r: Dictionary = roster[i]
		var b = BearScript.new()
		bear_layer.add_child(b)
		b.setup(self, i, r["name"], r["color"], ArenaScript.SPAWNS[i])
		if r["controller"] == "human":
			b.is_human = true
			b.controller = HumanController.new(b, r["schemes"])
			b.ctrl_label = "you" if Settings.human_count == 1 else ("WASD" if r["schemes"][0] == "p1" else "Arrows")
		else:
			b.controller = AiController.new(b, self, Settings.LEVELS.find(r["controller"]))
			b.ctrl_label = Settings.LEVEL_LABELS[Settings.LEVELS.find(r["controller"])] + " AI"
		bears.append(b)
	Music.ensure_playing()

	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)
	hud.banner("3", 1.0)
	Sfx.play("tick")


func _layer(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	arena.add_child(n)
	return n


func controls_enabled() -> bool:
	return state == State.PLAYING


func _draw() -> void:
	UiStyle.draw_wallpaper(self, Rect2(Vector2.ZERO, Vector2(1280, 720)))
	# a stitched frame around the play area
	var r := Rect2(ARENA_ORIGIN - Vector2(10, 10), Vector2(Tuning.COLS, Tuning.ROWS) * Tuning.TILE + Vector2(20, 20))
	draw_rect(r, Color(0.86, 0.76, 0.66))
	UiStyle.stitch_rect(self, r.grow(-4), Color(0.6, 0.45, 0.4, 0.7), 1.6, 6.0)


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			countdown -= delta
			var n := ceili(countdown)
			if n != _last_count and n > 0:
				_last_count = n
				hud.banner(str(n), 1.0)
				Sfx.play("tick")
			if countdown <= 0.0:
				state = State.PLAYING
				hud.banner("Steal the stuffing!", 1.4)
				Sfx.play("go")
		State.PLAYING:
			time_left -= delta
			if time_left <= 0.0:
				time_left = 0.0
				_end_match()
	_update_flames(delta)
	_update_pickups()
	_update_shuffles(delta)
	_update_steal_fx(delta)
	_update_contagion()


# --- bombs and blasts ------------------------------------------------------------

func try_place_bomb(bear) -> void:
	if not bear.can_place_bomb():
		return
	var c: Vector2i = bear.cell()
	if arena.is_solid(c):
		return
	_spawn_bomb(bear, c)
	Sfx.play("place", randf_range(0.8, 1.0))


## Cells a Line Bomb from `bear` would fill (its facing direction).
func line_cells(bear) -> Array:
	var out := []
	var c: Vector2i = bear.cell()
	var d := Vector2i(int(bear.facing.x), int(bear.facing.y))
	var free_bombs: int = bear.bombs_max - bear.active_bombs
	if not arena.bombs.has(c) and not arena.is_solid(c):
		out.append(c)
	while out.size() < free_bombs and d != Vector2i.ZERO:
		c += d
		if not arena.is_walkable(c):
			break
		var occupied := false
		for b in bears:
			if b != bear and b.cell() == c:
				occupied = true
		if occupied:
			break
		out.append(c)
	return out


func place_line(bear) -> void:
	var cells := line_cells(bear)
	for c in cells:
		_spawn_bomb(bear, c)
	if not cells.is_empty():
		Sfx.play("place", 0.8)
		Sfx.play("place", 1.1, -4.0)


func _spawn_bomb(bear, c: Vector2i) -> void:
	var b = BombScript.new()
	b.setup(self, bear, c, bear.bomb_range)
	for other in bears:
		if other.overlaps_cell(c):
			b.pass_through.append(other)
	bomb_layer.add_child(b)
	bombs.append(b)
	arena.bombs[c] = b
	bear.active_bombs += 1


## Cells a blast from `origin` would cover (stops at walls, includes the first block).
func blast_cells(origin: Vector2i, length: int) -> Array:
	var out := [origin]
	for d in DIRS:
		for i in range(1, length + 1):
			var c: Vector2i = origin + d * i
			var t: int = arena.cell_type(c)
			if t == ArenaScript.WALL or t == ArenaScript.BORDER:
				break
			out.append(c)
			if t == ArenaScript.BLOCK or arena.bombs.has(c):
				break
	return out


func explode(bomb) -> void:
	if bomb.exploded:
		return
	bomb.exploded = true
	bombs.erase(bomb)
	arena.bombs.erase(bomb.cell)
	bomb.owner_bear.active_bombs = maxi(0, bomb.owner_bear.active_bombs - 1)
	var origin: Vector2i = bomb.cell
	var T: float = arena.T
	var segs := [{"pos": arena.cell_center(origin), "kind": 0, "rot": 0.0}]
	var hit := [origin]
	var chain := []
	var broken := []
	for d in DIRS:
		var rot := Vector2(d).angle()
		for i in range(1, bomb.blast_range + 1):
			var c: Vector2i = origin + d * i
			var t: int = arena.cell_type(c)
			if t == ArenaScript.WALL or t == ArenaScript.BORDER:
				if i > 1:
					segs[segs.size() - 1]["kind"] = 2
				break
			hit.append(c)
			var last: bool = i == bomb.blast_range or t == ArenaScript.BLOCK or arena.bombs.has(c)
			segs.append({"pos": arena.cell_center(c), "kind": 2 if last else 1, "rot": rot})
			if t == ArenaScript.BLOCK:
				broken.append(c)
				break
			if arena.bombs.has(c):
				chain.append(arena.bombs[c])
				break
	for c in hit:
		flames[c] = Tuning.FLAME_TIME
	for c in broken:
		var kind: int = arena.destroy_block(c)
		spawn_dust(arena.cell_center(c), 4)
		_burst(arena.cell_center(c), fluff_tex, Rect2(Vector2.ZERO, fluff_tex.get_size()), 3, 12.0, Color(0.95, 0.85, 0.85))
		if kind >= 0:
			var p = PowerupScript.new()
			p.kind = kind
			p.cell = c
			p.position = arena.cell_center(c)
			powerup_layer.add_child(p)
			powerups[c] = p
	var ex = ExplosionScript.new()
	ex.segments = segs
	flame_layer.add_child(ex)
	_confetti(arena.cell_center(origin), 14)
	for i in range(1, hit.size(), 2):
		_confetti(arena.cell_center(hit[i]), 2)
	bomb.queue_free()
	arena.add_shake(4.0)
	Sfx.play("confetti", randf_range(0.85, 1.15))
	for other in chain:
		if is_instance_valid(other) and not other.exploded:
			other.fuse = minf(other.fuse, 0.06)
	_check_flame_hits(origin)


func _update_flames(delta: float) -> void:
	if flames.is_empty():
		return
	for c in flames.keys():
		flames[c] -= delta
		if flames[c] <= 0.0:
			flames.erase(c)
	_check_flame_hits(Vector2i(-1, -1))


func _check_flame_hits(origin: Vector2i) -> void:
	for b in bears:
		if flames.has(b.cell()) and not b.is_stunned() and b.immune_t <= 0.0:
			var src: Vector2 = arena.cell_center(origin) if origin.x >= 0 else b.position - b.velocity.normalized() * 10.0
			b.stun(src)


## Danger map for the AI: cell -> seconds until it is ablaze (0 = burning now).
func compute_danger(chain: bool) -> Dictionary:
	var d := {}
	for c in flames:
		d[c] = 0.0
	var times := {}
	for b in bombs:
		times[b] = b.fuse
	if chain:
		for _i in 4:
			for b in bombs:
				for c in blast_cells(b.cell, b.blast_range):
					var other = arena.bombs.get(c)
					if other != null and other != b and times[b] < times[other]:
						times[other] = times[b]
	for b in bombs:
		for c in blast_cells(b.cell, b.blast_range):
			d[c] = minf(d.get(c, 999.0), times[b])
	return d


# --- stuffing -----------------------------------------------------------------------

func find_steal_target(thief):
	var best = null
	var best_d: float = Tuning.STEAL_RANGE * arena.T
	for b in bears:
		if b == thief or not b.is_stunned() or b.fluff <= 0.01 or b.immortal_t > 0.0:
			continue
		var d: float = thief.position.distance_to(b.position)
		if d <= best_d:
			best_d = d
			best = b
	return best


func on_bear_stunned(bear) -> void:
	_burst(bear.position + Vector2(0, -20), fx_tex, Assets.region(fx_tex, Assets.EFFECT_CELLS, 3), 4, 14.0, Color.WHITE)
	# A little stuffing pops out and lands nearby.
	var amount := minf(Tuning.STUN_SPILL, bear.fluff)
	if amount < 1.0:
		return
	bear.fluff -= amount
	var c: Vector2i = bear.cell()
	var options := []
	for d in DIRS:
		if arena.is_walkable(c + d):
			options.append(c + d)
	var dest: Vector2i = options[rng.randi() % options.size()] if not options.is_empty() else c
	var p = PickupScript.new()
	p.game = self
	p.amount = amount
	p.from = bear.position
	p.to = arena.cell_center(dest) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
	p.cell = dest
	powerup_layer.add_child(p)
	pickups.append(p)


func _update_pickups() -> void:
	for b in bears:
		if b.is_stunned():
			continue
		var c: Vector2i = b.cell()
		if powerups.has(c):
			_apply_powerup(b, powerups[c])
			powerups[c].queue_free()
			powerups.erase(c)
		for p in pickups.duplicate():
			if p.landed and p.cell == c:
				b.add_fluff(p.amount)
				pickups.erase(p)
				p.queue_free()
				Sfx.play("pickup", 1.3)


func _apply_powerup(b, p) -> void:
	match p.kind:
		PowerupScript.BOMB:
			b.bombs_max = mini(b.bombs_max + 1, Tuning.MAX_BOMBS)
		PowerupScript.FIRE:
			b.bomb_range = mini(b.bomb_range + 1, Tuning.MAX_RANGE)
		PowerupScript.SPEED:
			b.speed_level = mini(b.speed_level + 1, Tuning.MAX_SPEED_LEVEL)
		PowerupScript.SHUFFLE:
			biome_shuffle()
		PowerupScript.KICK:
			b.can_kick = true
		PowerupScript.LINE:
			b.has_line = true
		PowerupScript.RUBBER:
			b.has_rubber = true
			b.can_kick = true  # rubber bombs need a kick to start bouncing
		PowerupScript.IMMORTAL:
			b.immortal_t = Tuning.IMMORTAL_TIME
			Sfx.play("immortal")
		PowerupScript.REVERSE:
			infect(b)
		PowerupScript.DIARRHEA:
			b.diarrhea_t = Tuning.DIARRHEA_TIME
	var bad: bool = p.kind in PowerupScript.BAD
	Sfx.play("curse" if bad else "pickup")
	b.visual.kick(0.2)
	_burst(p.position, fx_tex, Assets.region(fx_tex, Assets.EFFECT_CELLS, 5), 6, 12.0, Color(0.8, 0.95, 0.75) if bad else Color(1, 0.95, 0.8))
	if b.is_human or bad or p.kind in [PowerupScript.SHUFFLE, PowerupScript.IMMORTAL]:
		hud.toast("%s: %s" % [b.bear_name, PowerupScript.NAMES[p.kind]], b.color)


func infect(b) -> void:
	b.reverse_t = Tuning.REVERSE_TIME
	b.infect_cd = Tuning.INFECT_DELAY
	b.visual.kick(0.3)


## Reverse Controls is contagious: bumping into a cursed bear passes it on.
func _update_contagion() -> void:
	if state != State.PLAYING:
		return
	var reach: float = Tuning.INFECT_DIST * arena.T
	for a in bears:
		if a.reverse_t <= 0.0 or a.infect_cd > 0.0:
			continue
		for b in bears:
			if b == a or b.reverse_t > 0.0 or b.reinfect_immune > 0.0:
				continue
			if a.position.distance_to(b.position) < reach:
				infect(b)
				a.infect_cd = Tuning.INFECT_DELAY
				Sfx.play("curse", 1.2)
				_burst((a.position + b.position) * 0.5 + Vector2(0, -20), fx_tex, Assets.region(fx_tex, Assets.EFFECT_CELLS, 5), 5, 10.0, Color(0.75, 0.9, 0.65))
				hud.toast("%s caught Reverse Controls from %s!" % [b.bear_name, a.bear_name], b.color)


func _update_steal_fx(delta: float) -> void:
	_steal_fx_t -= delta
	if _steal_fx_t > 0.0:
		return
	_steal_fx_t = 0.07
	for b in bears:
		if b.stealing and b.steal_target != null:
			var v = b.steal_target
			var p = ParticleScript.new()
			p.tex = fluff_tex
			p.region = Rect2(Vector2.ZERO, fluff_tex.get_size())
			p.start = v.position + Vector2(rng.randf_range(-10, 10), -18 + rng.randf_range(-8, 8))
			p.position = p.start
			p.target = b
			p.life = 0.45
			p.size = rng.randf_range(10, 16)
			p.spin = rng.randf_range(-6, 6)
			p.arc = rng.randf_range(14, 34)
			fx_layer.add_child(p)


const CONFETTI := [Color("f2a7b5"), Color("a7c8e8"), Color("f5dc8a"), Color("a8dcc0"), Color("c9b2e3"), Color("f6c1a0")]


func _confetti(pos: Vector2, n: int) -> void:
	for i in n:
		var p = ParticleScript.new()
		p.position = pos + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
		var a := rng.randf_range(0, TAU)
		p.vel = Vector2(cos(a), sin(a) - 0.9) * rng.randf_range(60.0, 190.0)
		p.gravity = 200.0
		p.drag = 3.5
		p.life = rng.randf_range(0.6, 1.1)
		p.size = rng.randf_range(5.0, 8.0)
		p.spin = rng.randf_range(-10, 10)
		p.color = CONFETTI[rng.randi() % CONFETTI.size()]
		fx_layer.add_child(p)


func spawn_dust(pos: Vector2, n: int) -> void:
	_burst(pos, fx_tex, Assets.region(fx_tex, Assets.EFFECT_CELLS, 4), n, 22.0, Color(1, 1, 1, 0.9), 60.0)


func _burst(pos: Vector2, tex: Texture2D, region: Rect2, n: int, size: float, col: Color, speed := 140.0) -> void:
	for i in n:
		var p = ParticleScript.new()
		p.tex = tex
		p.region = region
		p.position = pos
		var a := rng.randf_range(0, TAU)
		p.vel = Vector2(cos(a), sin(a) - 0.6) * rng.randf_range(speed * 0.4, speed)
		p.gravity = 260.0
		p.drag = 2.0
		p.life = rng.randf_range(0.4, 0.75)
		p.size = size * rng.randf_range(0.7, 1.2)
		p.spin = rng.randf_range(-8, 8)
		p.color = col
		fx_layer.add_child(p)


# --- Biome Shuffle -----------------------------------------------------------------

func biome_shuffle() -> void:
	Sfx.play("shuffle")
	hud.banner("Biome Shuffle!", 1.6)
	# "cycle" turns rug -> ice -> honey -> rug; others paint the whole patch.
	var choices := [-2, -2, -2, Terrain.ICE, Terrain.BOUNCY, Terrain.BOUNCY, -1]
	var cycle := {Terrain.NORMAL: Terrain.ICE, Terrain.ICE: Terrain.HONEY, Terrain.HONEY: Terrain.NORMAL}
	var used := {}
	for i in Tuning.SHUFFLE_REGIONS:
		var w := rng.randi_range(3, 5)
		var h := rng.randi_range(3, 4)
		var x0 := rng.randi_range(1, Tuning.COLS - 1 - w)
		var y0 := rng.randi_range(1, Tuning.ROWS - 1 - h)
		var t: int = choices[rng.randi() % choices.size()]
		if t == -1:
			t = Terrain.CONVEYOR_R + rng.randi() % 4
		var region := {}
		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				var c := Vector2i(x, y)
				if used.has(c) or arena.cell_type(c) == ArenaScript.BORDER:
					continue
				var cur: int = arena.terrain_at(c)
				var nt := t
				if t == -2:
					nt = cycle.get(cur, Terrain.NORMAL)
				elif cur == t:
					nt = Terrain.NORMAL
				used[c] = true
				region[c] = nt
		shuffle_events.append({"t": Tuning.SHUFFLE_WARN, "cells": region, "revert": false})
	for e in shuffle_events:
		for c in e["cells"]:
			arena.warn[c] = e["cells"][c]
	arena.warn_t = 0.0


func _update_shuffles(delta: float) -> void:
	for e in shuffle_events.duplicate():
		e["t"] -= delta
		if e["t"] > 0.0:
			# warn shortly before a temporary shuffle wears off
			if e["revert"] and e["t"] < Tuning.SHUFFLE_WARN and not e.get("warned", false):
				e["warned"] = true
				for c in e["cells"]:
					if arena.terrain_at(c) == e["set"][c]:
						arena.warn[c] = arena.base_terrain[c.y * arena.cols + c.x]
			continue
		shuffle_events.erase(e)
		if not e["revert"]:
			for c in e["cells"]:
				arena.set_terrain(c, e["cells"][c])
				arena.warn.erase(c)
			shuffle_events.append({"t": Tuning.SHUFFLE_DURATION, "cells": e["cells"], "set": e["cells"], "revert": true})
		else:
			for c in e["cells"]:
				arena.warn.erase(c)
				if arena.terrain_at(c) == e["set"][c]:
					arena.set_terrain(c, arena.base_terrain[c.y * arena.cols + c.x])


# --- end of round ---------------------------------------------------------------------

func _end_match() -> void:
	state = State.ENDED
	for b in bears:
		b.stealing = false
	var ranking := bears.duplicate()
	ranking.sort_custom(func(a, b): return a.fluff > b.fluff)
	Sfx.play("victory")
	hud.show_results(ranking)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state != State.ENDED:
		get_tree().paused = not get_tree().paused
		hud.show_pause(get_tree().paused)
		get_viewport().set_input_as_handled()


func request_restart() -> void:
	get_tree().paused = false
	restart_requested.emit()


func request_menu() -> void:
	get_tree().paused = false
	quit_to_menu.emit()
