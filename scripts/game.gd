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
const DuckParade = preload("res://scripts/duck_parade.gd")
const Mode = preload("res://scripts/mode_theme.gd")
const DecalScript = preload("res://scripts/decal.gd")

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
var flame_owner := {} # Vector2i -> bear whose bomb made it (for taunts)
var decal_layer: Node2D
var world_tint: CanvasModulate
var _flicker := 0.0
var powerups := {}    # Vector2i -> power-up node
var pickups: Array = []
var shuffle_events: Array = []
var fx_tex: Texture2D
var fluff_tex: Texture2D
var _steal_fx_t := 0.0
var _last_count := 4
var duck_layer: Node2D
var parade = null
var duck_timer := 0.0


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

	decal_layer = _layer(1)
	powerup_layer = _layer(1)
	bomb_layer = _layer(2)
	duck_layer = _layer(4)
	duck_timer = rng.randf_range(Tuning.DUCK_FIRST_DELAY[0], Tuning.DUCK_FIRST_DELAY[1])
	flame_layer = _layer(3)
	bear_layer = _layer(5)
	bear_layer.y_sort_enabled = true
	fx_layer = _layer(8)

	var roster: Array = Settings.roster()
	for i in roster.size():
		var r: Dictionary = roster[i]
		var b = BearScript.new()
		bear_layer.add_child(b)
		b.setup(self, i, r["name"], Mode.bear_color(r["color"]), ArenaScript.SPAWNS[i])
		if r["controller"] == "human":
			b.is_human = true
			b.controller = HumanController.new(b, r["schemes"])
			b.ctrl_label = "you" if Settings.human_count == 1 else ("WASD" if r["schemes"][0] == "p1" else "Arrows")
		else:
			b.controller = AiController.new(b, self, Settings.LEVELS.find(r["controller"]))
			b.ctrl_label = Settings.LEVEL_LABELS[Settings.LEVELS.find(r["controller"])] + " AI"
		bears.append(b)
	Music.play_context("gameplay")
	_setup_mode_atmosphere()

	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)
	hud.banner("3", 1.0)
	Sfx.play("tick")


## Darker, flickering nursery with a vignette in Horror mode.
func _setup_mode_atmosphere() -> void:
	world_tint = CanvasModulate.new()
	world_tint.color = Mode.world_modulate()
	add_child(world_tint)
	if not Mode.horror():
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0.05, 0.0, 0.01, 0.75))
	grad.add_point(0.55, Color(0, 0, 0, 0.05))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.position = Vector2(-40, -60)
	tr.size = Vector2(840, 840)  # centred on the arena; the HUD side stays readable
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tr)


func _process(delta: float) -> void:
	if world_tint == null or not Mode.horror():
		return
	# the nursery lamp flickers now and then
	_flicker -= delta
	if _flicker <= 0.0 and rng.randf() < delta * 0.35:
		_flicker = rng.randf_range(0.05, 0.18)
	world_tint.color = Mode.world_modulate() * (0.6 if _flicker > 0.0 else 1.0)
	world_tint.color.a = 1.0


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
	draw_rect(r, UiStyle.FRAME)
	UiStyle.stitch_rect(self, r.grow(-4), Color(UiStyle.ROSE_DARK, 0.6), 1.6, 6.0)


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
			_update_ducks(delta)
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
		flame_owner[c] = bomb.owner_bear
	_break_blocks(broken)
	_finish_bomb(bomb, origin, hit, segs, chain)


func _finish_bomb(bomb, origin: Vector2i, hit: Array, segs: Array, chain: Array) -> void:
	bomb.queue_free()
	_apply_blast(origin, hit, segs, chain, 14)
	arena.add_shake(4.0)
	Sfx.play("confetti", randf_range(0.85, 1.15))


func _break_blocks(broken: Array) -> void:
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


## Shared by bombs and the duck: confetti visuals, chained bombs, stuns.
func _apply_blast(origin: Vector2i, hit: Array, segs: Array, chain: Array, confetti: int) -> void:
	var ex = ExplosionScript.new()
	ex.segments = segs
	flame_layer.add_child(ex)
	_confetti(arena.cell_center(origin), confetti)
	for i in range(1, hit.size(), 2):
		_confetti(arena.cell_center(hit[i]), 2)
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
			flame_owner.erase(c)
	_check_flame_hits(Vector2i(-1, -1))


func _check_flame_hits(origin: Vector2i) -> void:
	for b in bears:
		if flames.has(b.cell()) and not b.is_stunned() and b.immune_t <= 0.0:
			var src: Vector2 = arena.cell_center(origin) if origin.x >= 0 else b.position - b.velocity.normalized() * 10.0
			b.last_hit_by = flame_owner.get(b.cell())
			b.stun(src)


# --- Doom Duck Parade ------------------------------------------------------------

func _update_ducks(delta: float) -> void:
	if not Tuning.DUCK_ENABLED or parade != null:
		return
	duck_timer -= delta
	if duck_timer <= 0.0 and time_left > Tuning.DUCK_TIME + 4.0:
		start_duck_parade()


func start_duck_parade() -> void:
	var walls := []
	for y in arena.rows:
		for x in arena.cols:
			var c := Vector2i(x, y)
			var below := c + Vector2i(0, 1)
			if arena.cell_type(c) == ArenaScript.WALL and arena.cell_type(below) == ArenaScript.EMPTY and not arena.bombs.has(below):
				walls.append(c)
	if walls.is_empty():
		duck_timer = 5.0
		return
	parade = DuckParade.new()
	duck_layer.add_child(parade)
	parade.setup(self, walls[rng.randi() % walls.size()])
	hud.banner("Doom Duck Parade!", 1.6)


## Flood fill from `origin` along walkable cells, up to `reach` steps. Turns
## corners; permanent walls block it; cushion blocks stop it (and break).
func duck_blast_cells(origin: Vector2i, reach: int) -> Array:
	var dist := {origin: 0}
	var out := [origin]
	var queue := [origin]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if dist[c] >= reach:
			continue
		for d in DIRS:
			var n: Vector2i = c + d
			if dist.has(n):
				continue
			var t: int = arena.cell_type(n)
			if t == ArenaScript.WALL or t == ArenaScript.BORDER:
				continue
			dist[n] = dist[c] + 1
			out.append(n)
			if t != ArenaScript.BLOCK:
				queue.append(n)
	return out


func duck_explode(p) -> void:
	var origin: Vector2i = p.mother_cell()
	var hit := duck_blast_cells(origin, Tuning.DUCK_BLAST_RANGE)
	var broken := []
	var chain := []
	var segs := []
	for c in hit:
		flames[c] = Tuning.FLAME_TIME
		flame_owner.erase(c)  # nobody to gloat: the duck did it
		if arena.cell_type(c) == ArenaScript.BLOCK:
			broken.append(c)
		if arena.bombs.has(c):
			chain.append(arena.bombs[c])
		segs.append({"pos": arena.cell_center(c), "kind": 0, "rot": rng.randf() * TAU})
	_break_blocks(broken)
	_apply_blast(origin, hit, segs, chain, 30)
	for c in hit:
		_confetti(arena.cell_center(c), 2)
	arena.add_shake(8.0)
	Sfx.play("duck_confetti")
	parade = null
	duck_timer = rng.randf_range(Tuning.DUCK_INTERVAL[0], Tuning.DUCK_INTERVAL[1])


## Danger map for the AI: cell -> seconds until it is ablaze (0 = burning now).
## level: 0 easy, 1 normal, 2 hard.
func compute_danger(level: int) -> Dictionary:
	var chain := level == 2
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
	# The duck: Easy only notices at the very end, Hard plans for its walk.
	if parade != null and is_instance_valid(parade) and parade.armed():
		var rem: float = parade.countdown
		if level == 2 or (level == 1 and rem < 6.0) or (level == 0 and rem < 2.5):
			var reach: int = Tuning.DUCK_BLAST_RANGE + (1 if level == 2 else 0)
			var origins := [parade.mother_cell()]
			if level == 2:
				origins.append(parade.next_cell)
			for o in origins:
				for c in duck_blast_cells(o, reach):
					d[c] = minf(d.get(c, 999.0), rem)
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
	_splat(bear.position + Vector2(0, 10), 34.0 + 10.0 * minf(bear.fluff_ratio(), 3.0))
	if Mode.horror():
		_confetti(bear.position + Vector2(0, -12), 10)  # a spray of red
	_gloat(bear)
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


## Floor mark where a bear went down (stuffing / blood). Old ones are recycled.
func _splat(pos: Vector2, size: float) -> void:
	var d = DecalScript.new()
	d.position = pos
	d.size = size
	d.color = Mode.splat_color()
	decal_layer.add_child(d)
	if decal_layer.get_child_count() > 30:
		decal_layer.get_child(0).queue_free()


# --- taunts -----------------------------------------------------------------------

## Someone stunned `victim`: the bomber gloats; an own goal gets mocked by a bystander.
func _gloat(victim) -> void:
	var attacker = victim.last_hit_by
	if attacker != null and is_instance_valid(attacker) and attacker != victim:
		attacker.taunt("stun")
		return
	if attacker == victim:
		var best = null
		var best_d: float = 7.0 * arena.T
		for b in bears:
			if b != victim and not b.is_stunned() and b.position.distance_to(victim.position) < best_d:
				best_d = b.position.distance_to(victim.position)
				best = b
		if best != null:
			best.taunt("self_stun")


func on_steal_started(thief, _victim) -> void:
	if rng.randf() < 0.7:
		thief.taunt("greedy" if thief.fluff_ratio() > 2.5 else "steal")


func bubble_count() -> int:
	var n := 0
	for b in bears:
		if b.bubble_t > 0.0:
			n += 1
	return n


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
			p.color = Mode.stuffing_color()
			fx_layer.add_child(p)


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
		var pal: Array = Mode.confetti()
		p.color = pal[rng.randi() % pal.size()]
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
	if parade != null and is_instance_valid(parade):
		parade.queue_free()  # the ducks wind down quietly
		parade = null
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
