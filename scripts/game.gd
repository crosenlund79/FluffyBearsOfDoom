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
const FootprintsScript = preload("res://scripts/footprints.gd")
const Species = preload("res://scripts/species.gd")
const ChairScript = preload("res://scripts/chair.gd")
const CraneScript = preload("res://scripts/crane_event.gd")
const PickupFx = preload("res://scripts/pickup_fx.gd")
const DoomRings = preload("res://scripts/doom_rings.gd")
const JackInTheBox = preload("res://scripts/jack_in_the_box.gd")
const PrincessHunt = preload("res://scripts/princess_hunt.gd")

enum State { COUNTDOWN, PLAYING, ENDED }

const ARENA_ORIGIN := Vector2(280, 52)   # centred: the HUD lives in the side columns
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
var flame_origin := {} # Vector2i -> the bomb cell that blast came from (knockback direction)
var decal_layer: Node2D
var footprints
var bloody := {}       # Vector2i -> game clock until which a blood splat lies there
var clock := 0.0
var world_tint: CanvasModulate
var _flicker := 0.0
var powerups := {}    # Vector2i -> power-up node
var pickups: Array = []
var fx_tex: Texture2D
var fluff_tex: Texture2D
var _steal_fx_t := 0.0
var _last_count := 4
var duck_layer: Node2D
var parade = null
var crane = null          # the crane event in progress
var chair = null          # a delivered chair waiting to be looted
var crane_timer := 0.0
var crane_layer: Node2D
var duck_timer := 0.0
var doom = null           # Time of Doom ring closer
var clown = null          # (Horror) the jack-in-the-box in progress
var princess = null       # the Princess Hunt in progress
var princess_used := false   # she comes at most once per round
var clown_timer := 0.0
var clown_layer: Node2D
var round_duration := 150.0


func _ready() -> void:
	rng.randomize()
	Settings.apply_input_bindings()
	fx_tex = Assets.tex("effects/effects")
	fluff_tex = Assets.tex("objects/fluff")
	time_left = Tuning.ROUND_TIMES[Settings.round_time_index]
	round_duration = time_left

	arena = ArenaScript.new()
	arena.position = ARENA_ORIGIN
	add_child(arena)
	arena.setup(Maps.MAPS[Settings.arena_index], rng, PowerupScript.WEIGHTS)
	# rarely, one block hides the Princess Hunt trap (never more than one)
	if rng.randf() < Tuning.PRINCESS_CHANCE and not arena.hidden_powerups.is_empty():
		var spots: Array = arena.hidden_powerups.keys().filter(func(c): return arena.hidden_powerups[c] != PowerupScript.SHUFFLE)
		if not spots.is_empty():
			arena.hidden_powerups[spots[rng.randi() % spots.size()]] = PowerupScript.PRINCESS

	decal_layer = _layer(1)
	footprints = FootprintsScript.new()
	_layer(1).add_child(footprints)
	powerup_layer = _layer(1)
	bomb_layer = _layer(2)
	duck_layer = _layer(4)
	duck_timer = rng.randf_range(Tuning.DUCK_FIRST_DELAY[0], Tuning.DUCK_FIRST_DELAY[1])
	flame_layer = _layer(3)
	bear_layer = _layer(5)
	bear_layer.y_sort_enabled = true
	fx_layer = _layer(8)
	crane_layer = _layer(9)   # the crane swings in above everything
	clown_layer = _layer(7)   # over the bears, under the particles
	clown_timer = rng.randf_range(Tuning.CLOWN_FIRST_DELAY[0], Tuning.CLOWN_FIRST_DELAY[1])
	if Tuning.DOOM_ENABLED:
		doom = DoomRings.new()
		_layer(1).add_child(doom)   # warnings sit on the floor, over blocks, under bears
		doom.setup(self, round_duration)
	crane_timer = rng.randf_range(Tuning.CRANE_FIRST_DELAY[0], Tuning.CRANE_FIRST_DELAY[1])

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
			b.ctrl_label = Species.info(b.species)["label"] + " · " + b.ctrl_label
		else:
			b.controller = AiController.new(b, self, Settings.LEVELS.find(r["controller"]))
			b.ctrl_label = Species.info(b.species)["label"] + " · " + Settings.LEVEL_LABELS[Settings.LEVELS.find(r["controller"])] + " AI"
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
	tr.position = Vector2(220, -56)
	tr.size = Vector2(840, 840)  # centred on the arena; the HUD columns stay readable
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
	UiStyle.draw_wallpaper(self, Rect2(-position, get_viewport_rect().size))   # whole window, even ultrawide
	# a stitched frame around the play area
	var r := Rect2(ARENA_ORIGIN - Vector2(10, 10), Vector2(Tuning.COLS, Tuning.ROWS) * Tuning.TILE + Vector2(20, 20))
	draw_rect(r, UiStyle.FRAME)
	UiStyle.stitch_rect(self, r.grow(-4), Color(UiStyle.ROSE_DARK, 0.6), 1.6, 6.0)


func _physics_process(delta: float) -> void:
	clock += delta
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
			_update_crane(delta)
			if doom != null:
				doom.update(delta, round_duration - time_left)
			_update_clown(delta)
			_check_instant_win()
			if state == State.PLAYING and time_left <= 0.0:
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
			if b != bear and b.cell() == c and not b.eliminated:
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
			if arena.is_hard(c):
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
			if arena.is_hard(c):
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
		flame_origin[c] = origin
	_destroy_powerups(hit)
	_blast_chair(hit)
	_break_blocks(broken)
	_finish_bomb(bomb, origin, hit, segs, chain)


func _finish_bomb(bomb, origin: Vector2i, hit: Array, segs: Array, chain: Array) -> void:
	bomb.queue_free()
	_apply_blast(origin, hit, segs, chain, 14)
	arena.add_shake(4.0)
	Sfx.play("explosion", randf_range(0.92, 1.08), -4.0)   # supplied recording
	Sfx.play("confetti", randf_range(0.85, 1.15), -6.0)   # plus the paper crackle


## Power-ups lying in a blast are destroyed (ones revealed by this blast survive).
func _destroy_powerups(cells: Array) -> void:
	var destroyed := false
	for c in cells:
		if powerups.has(c):
			var p = powerups[c]
			powerups.erase(c)
			spawn_dust(p.position, 4)
			_burst(p.position, fx_tex, Assets.region(fx_tex, Assets.EFFECT_CELLS, 5), 5, 11.0, Color(1, 0.9, 0.75))
			p.queue_free()
			destroyed = true
	if destroyed:
		Sfx.play("pop", 0.7, -4.0)


## Detonate all of `bear`'s remote bombs. Returns true if there were any.
func detonate_remote(bear) -> bool:
	var any := false
	for b in bombs:
		if b.remote and b.owner_bear == bear and not b.exploded:
			b.fuse = 0.0
			any = true
	if any:
		Sfx.play("tick", 1.6, -2.0)
	return any


func add_footprint(pos: Vector2, dir: Vector2, strength: float) -> void:
	footprints.add(pos, dir, strength)


func is_bloody(c: Vector2i) -> bool:
	return bloody.get(c, -1.0) > clock


func _break_blocks(broken: Array) -> void:
	for c in broken:
		var kind: int = arena.destroy_block(c)
		if kind == PowerupScript.PRINCESS and princess_used:
			kind = PowerupScript.BOMB   # she's already been
		spawn_dust(arena.cell_center(c), 4)
		_burst(arena.cell_center(c), fluff_tex, Rect2(Vector2.ZERO, fluff_tex.get_size()), 3, 12.0, Color(0.95, 0.85, 0.85))
		if kind >= 0:
			var p = PowerupScript.new()
			p.kind = kind
			p.cell = c
			p.position = arena.cell_center(c)
			powerup_layer.add_child(p)
			powerups[c] = p
			# a little reveal flourish
			_burst(p.position, fx_tex, Assets.region(fx_tex, Assets.EFFECT_CELLS, 5), 6, 13.0, PowerupScript.glow_color(kind))


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
			flame_origin.erase(c)
	_check_flame_hits(Vector2i(-1, -1))


func _check_flame_hits(origin: Vector2i) -> void:
	for b in bears:
		if flames.has(b.cell()) and not b.is_stunned() and b.immune_t <= 0.0:
			var src: Vector2 = arena.cell_center(origin) if origin.x >= 0 else b.position - b.velocity.normalized() * 10.0
			b.last_hit_by = flame_owner.get(b.cell())
			var from: Vector2i = flame_origin.get(b.cell(), Vector2i(-1, -1))
			b.stun(src)
			if b.is_stunned() and from.x >= 0:
				_knock_back(b, from)
				if b.last_hit_by != null and b.last_hit_by != b:
					b.last_hit_by.growl()   # the bomber snarls in triumph


## A bear stunned by a bomb is blown along the blast direction.
func _knock_back(b, origin: Vector2i) -> void:
	var c: Vector2i = b.cell()
	var d := c - origin
	var dir := Vector2i.ZERO
	if d != Vector2i.ZERO:
		dir = Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
	else:
		# sitting on the bomb itself: thrown backwards (or any open way)
		var back := Vector2i(-int(signf(b.facing.x)), -int(signf(b.facing.y)))
		var tries := [back] + DIRS
		for t in tries:
			if t != Vector2i.ZERO and not arena.is_solid(c + t) and not arena.bombs.has(c + t):
				dir = t
				break
	if dir != Vector2i.ZERO:
		b.knock_back(dir)


## Power-up on `c`, collected by `b` whether it wants it or not (knockback).
func collect_powerup_at(b, c: Vector2i) -> void:
	if powerups.has(c):
		_apply_powerup(b, powerups[c])
		powerups[c].queue_free()
		powerups.erase(c)


# --- Doom Duck Parade ------------------------------------------------------------

# --- Crane chair drop ---------------------------------------------------------------

func _update_crane(delta: float) -> void:
	if chair != null and is_instance_valid(chair) and chair.fluff <= 0.5:
		_remove_chair(false)   # looted bare
	if not Tuning.CRANE_ENABLED or crane != null or chair != null or parade != null:
		return
	crane_timer -= delta
	if crane_timer <= 0.0 and time_left > 14.0:
		start_crane()


func start_crane() -> void:
	var cells := []
	for y in arena.rows:
		for x in arena.cols:
			var c := Vector2i(x, y)
			if not arena.is_walkable(c) or powerups.has(c) or arena._is_spawn_zone(c):
				continue
			if doom != null and doom.time_until_close(c) < 25.0:
				continue   # don't deliver into a ring that's about to shut
			var open := 0
			for d in DIRS:
				if arena.is_walkable(c + d):
					open += 1
			if open >= 2:
				cells.append(c)
	if cells.is_empty():
		crane_timer = 5.0
		return
	crane = CraneScript.new()
	crane_layer.add_child(crane)
	crane.setup(self, cells[rng.randi() % cells.size()])
	hud.banner("Something is coming down..." if Mode.horror() else "Special delivery!", 1.6)


func land_chair(c: Vector2i) -> void:
	chair = ChairScript.new()
	bear_layer.add_child(chair)   # y-sorted with the bears
	chair.setup(self, c)
	spawn_dust(arena.cell_center(c) + Vector2(0, 14), 6)
	_burst(arena.cell_center(c) + Vector2(0, -10), fluff_tex, Rect2(Vector2.ZERO, fluff_tex.get_size()), 5, 12.0, Mode.stuffing_color())
	arena.add_shake(6.0)
	Sfx.play("chair_thud")
	for b in bears:
		b.visual.kick(0.15)   # everyone jiggles at the thud


## A landed chair within stealing reach of `thief`, or null.
func find_chair(thief):
	if chair == null or not is_instance_valid(chair) or chair.fluff <= 0.5:
		return null
	if thief.position.distance_to(chair.position) <= Tuning.STEAL_RANGE * arena.T:
		return chair
	return null


# --- Horror jack-in-the-box ---------------------------------------------------------

func _update_clown(delta: float) -> void:
	if not Tuning.CLOWN_ENABLED or not Mode.horror() or clown != null:
		return
	clown_timer -= delta
	if clown_timer <= 0.0 and time_left > Tuning.CLOWN_WARN + 3.0:
		start_clown()


func start_clown() -> void:
	var pillars := []
	for y in arena.rows:
		for x in arena.cols:
			var c := Vector2i(x, y)
			if arena.cell_type(c) != ArenaScript.WALL:
				continue
			if doom != null and doom.time_until_close(c) < Tuning.CLOWN_WARN + 4.0:
				continue   # its ring shuts before it would get going
			if parade != null and is_instance_valid(parade) and parade.wall == c:
				continue   # the duck portal is busy
			pillars.append(c)
	clown_timer = rng.randf_range(Tuning.CLOWN_INTERVAL[0], Tuning.CLOWN_INTERVAL[1])
	if pillars.is_empty():
		return
	clown = JackInTheBox.new()
	clown_layer.add_child(clown)
	clown.setup(self, pillars[rng.randi() % pillars.size()])
	hud.toast("Something is rattling...", Color(0.7, 0.1, 0.12))


## The clown's mallet lands on `bear`.
func clown_hit(bear, at: Vector2) -> void:
	arena.add_shake(10.0)
	Sfx.play("clown_hammer")
	Sfx.play("impact", randf_range(0.9, 1.0), -1.0)
	_burst(at, fx_tex, Assets.region(fx_tex, Assets.EFFECT_CELLS, 3), 6, 16.0, Color.WHITE, 220.0)
	_splat(bear.position + Vector2(0, 10), 40.0)
	var was_stunned: bool = bear.is_stunned()
	bear.last_hit_by = null
	bear.stun(at + Vector2(0, -20))
	if bear.is_stunned() and not was_stunned:
		bear.stun_t = Tuning.CLOWN_STUN
	bear.visual.kick(0.6)


# --- Princess Hunt -----------------------------------------------------------------------

func start_princess() -> void:
	if princess_used or princess != null or state != State.PLAYING:
		hud.toast("The princess is busy elsewhere.", Color(0.7, 0.4, 0.55))
		return
	princess_used = true
	princess = PrincessHunt.new()
	bear_layer.add_child(princess)   # y-sorted with the bears
	princess.setup(self)


## Her one shot. A blank against an immortal/immune bear; otherwise a long
## stun, a big puff of stuffing and a shove away from her.
func on_princess_shot(p, b, blank: bool) -> void:
	if blank:
		Sfx.play("pop", 1.6, -2.0)
		hud.toast("Click! A blank: %s is untouchable." % b.bear_name, b.color)
		return
	Sfx.play("shotgun_hit")
	Sfx.play("impact", 0.85, -2.0)
	var was: bool = b.is_stunned()
	b.last_hit_by = null
	b.stun(p.position)
	if b.is_stunned() and not was:
		b.stun_t = Tuning.PRINCESS_STUN
	spill_fluff(b, b.fluff * Tuning.PRINCESS_SPILL)
	_splat(b.position + Vector2(0, 10), 60.0)
	_burst(b.position + Vector2(0, -16), fx_tex, Assets.region(fx_tex, Assets.EFFECT_CELLS, 3), 6, 16.0, Color.WHITE, 220.0)
	var d: Vector2 = b.position - p.position
	var dir := Vector2i(int(signf(d.x)), 0) if absf(d.x) >= absf(d.y) else Vector2i(0, int(signf(d.y)))
	if dir != Vector2i.ZERO and not arena.is_solid(b.cell() + dir) and not b.eliminated:
		b.knock_back(dir)
	hud.toast("The princess blasted %s!" % b.bear_name, b.color)


func on_princess_defeated(p) -> void:
	Sfx.play("concussion", 0.8)
	_burst(p.position + Vector2(0, -20), fx_tex, Assets.region(fx_tex, Assets.EFFECT_CELLS, 3), 6, 14.0, Color.WHITE)
	hud.banner("The princess was blown away!", 1.6)


## Blow `amount` of `b`'s stuffing out as pickups on open tiles nearby.
func spill_fluff(b, amount: float) -> void:
	amount = minf(amount, b.fluff)
	if amount < 1.0:
		return
	b.fluff -= amount
	var c: Vector2i = b.cell()
	var spots := []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var n := c + Vector2i(dx, dy)
			if arena.is_walkable(n) and absi(dx) + absi(dy) <= 2:
				spots.append(n)
	var n_p := clampi(ceili(amount / 10.0), 1, 4)
	for i in n_p:
		var dest: Vector2i = spots[rng.randi() % spots.size()] if not spots.is_empty() else c
		var pk = PickupScript.new()
		pk.game = self
		pk.amount = amount / n_p
		pk.from = b.position
		pk.to = arena.cell_center(dest) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		pk.cell = dest
		powerup_layer.add_child(pk)
		pickups.append(pk)


# --- Time of Doom ---------------------------------------------------------------------

## Shut `cells` for good. Bombs, power-ups, blocks and flames there are cleared
## safely (no explosions), loose stuffing and the chair are moved/burst inward,
## and bears caught there are shoved to the nearest open cell and stunned.
func doom_close(cells: Array) -> void:
	var shut := {}
	for c in cells:
		if arena.cell_type(c) != ArenaScript.BORDER:
			shut[c] = true
	if shut.is_empty():
		return
	# bombs vanish with a puff; their owners get the bomb back
	for b in bombs.duplicate():
		if shut.has(b.cell) and not b.exploded:
			b.exploded = true
			bombs.erase(b)
			arena.bombs.erase(b.cell)
			b.owner_bear.active_bombs = maxi(0, b.owner_bear.active_bombs - 1)
			spawn_dust(b.position, 4)
			b.queue_free()
	for c in shut:
		flames.erase(c)
		flame_owner.erase(c)
		if powerups.has(c):
			spawn_dust(powerups[c].position, 3)
			powerups[c].queue_free()
			powerups.erase(c)
	for c in shut:
		arena.close_cell(c)
	# a chair in the way bursts open; its stuffing lands further in
	if chair != null and is_instance_valid(chair) and shut.has(chair.cell):
		_blast_chair([chair.cell])
	# loose tufts hop inward instead of being lost
	for p in pickups:
		if shut.has(p.cell):
			var dest := nearest_open_cell(p.cell)
			p.from = p.position
			p.to = arena.cell_center(dest)
			p.cell = dest
			p.t = 0.0
			p.landed = false
	# bears: shoved inward and stunned (never eliminated)
	for b in bears:
		var caught: bool = shut.has(b.cell())
		if not caught:
			for c in shut:
				if b.overlaps_cell(c):
					b.position = arena.cell_center(b.cell())   # just brushing it: square up in its own cell
					b.velocity = Vector2.ZERO
					break
			continue
		var from: Vector2 = b.position
		b.knock_dir = Vector2i.ZERO
		var dest := nearest_open_cell(b.cell())
		b.position = arena.cell_center(dest)
		b.velocity = Vector2.ZERO
		spawn_dust(from, 5)
		spawn_dust(b.position + Vector2(0, 12), 4)
		var was_stunned: bool = b.is_stunned()
		b.stun(from)
		if b.is_stunned() and not was_stunned:
			b.stun_t = Tuning.DOOM_STUN
		b.visual.kick(0.4)
	# the duck and the crane keep to open ground too
	if parade != null and is_instance_valid(parade) and shut.has(parade.mother_cell()):
		parade.relocate(nearest_open_cell(parade.mother_cell()))
	if crane != null and is_instance_valid(crane) and shut.has(crane.target):
		crane.target = nearest_open_cell(crane.target)
	if clown != null and is_instance_valid(clown):
		clown.on_cells_closed(shut)
	arena.add_shake(2.5)
	Sfx.play("doom_slam", randf_range(0.9, 1.1), -9.0)
	for c in shut:
		if rng.randf() < 0.35:
			spawn_dust(arena.cell_center(c), 2)


## The nearest cell to `from` a bear can stand on: open, no bomb, not about to
## close. Searched outward ring by ring, so it always works (a block may be
## cleared as a last resort).
func nearest_open_cell(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var fallback := Vector2i(-1, -1)
	var best_d := INF
	for y in arena.rows:
		for x in arena.cols:
			var c := Vector2i(x, y)
			var d := float(absi(c.x - from.x) + absi(c.y - from.y))
			if doom != null:
				d -= 0.01 * doom.ring_of(c)   # on ties, prefer the cell further in
			if arena.is_walkable(c):
				var soon: bool = doom != null and doom.time_until_close(c) < 3.0
				if not soon and d < best_d:
					best_d = d
					best = c
				elif fallback.x < 0:
					fallback = c
	if best.x >= 0:
		return best
	if fallback.x >= 0:
		return fallback
	# nothing open at all (practically impossible): carve out the nearest block
	for r in range(1, 20):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := from + Vector2i(dx, dy)
				if arena.cell_type(c) == ArenaScript.BLOCK:
					arena.destroy_block(c)
					return c
	return from


## A blast bursts the chair open: its remaining stuffing flies out as pickups.
func _blast_chair(cells: Array) -> void:
	if chair == null or not is_instance_valid(chair) or not chair.cell in cells:
		return
	var left: float = chair.fluff
	var n := clampi(ceili(left / 12.0), 1, 5)
	var spots := []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c: Vector2i = chair.cell + Vector2i(dx, dy)
			if arena.is_walkable(c) and absi(dx) + absi(dy) <= 2:
				spots.append(c)
	for i in n:
		var dest: Vector2i = spots[rng.randi() % spots.size()] if not spots.is_empty() else chair.cell
		var p = PickupScript.new()
		p.game = self
		p.amount = left / n
		p.from = chair.position
		p.to = arena.cell_center(dest) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		p.cell = dest
		powerup_layer.add_child(p)
		pickups.append(p)
	_remove_chair(true)


func _remove_chair(burst: bool) -> void:
	var pos: Vector2 = chair.position
	spawn_dust(pos, 8 if burst else 5)
	_burst(pos + Vector2(0, -10), fluff_tex, Rect2(Vector2.ZERO, fluff_tex.get_size()), 8 if burst else 4, 13.0, Mode.stuffing_color())
	Sfx.play("pop", 0.55 if burst else 0.8)
	chair.queue_free()
	chair = null
	crane_timer = rng.randf_range(Tuning.CRANE_INTERVAL[0], Tuning.CRANE_INTERVAL[1])


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
			if arena.is_hard(n):
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
		flame_origin.erase(c)  # (and no knockback: it isn't a bomb)
		if arena.cell_type(c) == ArenaScript.BLOCK:
			broken.append(c)
		if arena.bombs.has(c):
			chain.append(arena.bombs[c])
		segs.append({"pos": arena.cell_center(c), "kind": 0, "rot": rng.randf() * TAU})
	_destroy_powerups(hit)
	_blast_chair(hit)
	_break_blocks(broken)
	_apply_blast(origin, hit, segs, chain, 30)
	for c in hit:
		_confetti(arena.cell_center(c), 2)
	arena.add_shake(8.0)
	Sfx.play("duck_confetti")
	Sfx.play("explosion", 0.8, -2.0)
	parade = null
	duck_timer = rng.randf_range(Tuning.DUCK_INTERVAL[0], Tuning.DUCK_INTERVAL[1])


## Danger map for the AI: cell -> seconds until it is ablaze (0 = burning now).
## level: 0 easy, 1 normal, 2 hard.
func compute_danger(level: int, asker = null) -> Dictionary:
	var chain := level == 2
	var d := {}
	for c in flames:
		d[c] = 0.0
	var times := {}
	for b in bombs:
		times[b] = b.fuse
		if b.remote and b.owner_bear != asker:
			times[b] = minf(b.fuse, Tuning.REMOTE_THREAT_TIME)  # could be set off any moment
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
	# Time of Doom: a flashing ring is about to become solid.
	if doom != null:
		var w: Dictionary = doom.warning_cells()
		for c in w:
			d[c] = minf(d.get(c, 999.0), w[c])
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


func on_bear_eliminated(bear) -> void:
	_splat(bear.position + Vector2(0, 10), 54.0)
	spawn_dust(bear.position, 6)
	_burst(bear.position + Vector2(0, -10), fluff_tex, Rect2(Vector2.ZERO, fluff_tex.get_size()), 6, 10.0, Mode.stuffing_color())
	hud.banner("%s is out of stuffing!" % bear.bear_name if not Mode.horror() else "%s is empty." % bear.bear_name, 1.8)
	arena.add_shake(4.0)


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
	if Mode.horror():
		bloody[arena.world_to_cell(pos)] = clock + d.life
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
		PowerupScript.REMOTE:
			b.has_remote = true
		PowerupScript.IMMORTAL:
			b.immortal_t = Tuning.IMMORTAL_TIME
			Sfx.play("immortal")
		PowerupScript.REVERSE:
			infect(b)
		PowerupScript.DIARRHEA:
			b.diarrhea_t = Tuning.DIARRHEA_TIME
		PowerupScript.PRINCESS:
			start_princess()
	var bad: bool = p.kind in PowerupScript.BAD
	var fxn = PickupFx.new()
	fxn.kind = p.kind
	fxn.position = p.position
	fx_layer.add_child(fxn)
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
			if b == a or b.eliminated or b.reverse_t > 0.0 or b.reinfect_immune > 0.0:
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

const SHUFFLE_BIOMES := [
	[Terrain.ICE, "Ice Rink!"], [Terrain.HONEY, "Honey Flood!"], [Terrain.BOUNCY, "Bouncy Castle!"],
	[-1, "Conveyor Chaos!"],
]
var shuffle_snapshot = null    # terrain before the shuffle (restored afterwards)
var shuffle_biome := -1
var shuffle_phase := ""        # "", "warn" (tiles show what's coming), "active"
var shuffle_t := 0.0


## Biome Shuffle: after a short warning the WHOLE playable floor becomes one
## random biome (ice, honey, bouncy or a conveyor belt in one direction) with
## its physics, then goes back to exactly what it was. Walls, blocks, bombs
## and power-ups are untouched.
func biome_shuffle() -> void:
	Sfx.play("shuffle")
	var pick: Array = SHUFFLE_BIOMES[rng.randi() % SHUFFLE_BIOMES.size()]
	var biome: int = pick[0]
	if biome == -1:
		biome = Terrain.CONVEYOR_R + rng.randi() % 4
	if shuffle_snapshot == null:
		shuffle_snapshot = arena.terrain.duplicate()   # a shuffle during a shuffle still restores the original
	shuffle_biome = biome
	hud.banner("Biome Shuffle: " + pick[1], 1.8)
	shuffle_phase = "warn"
	shuffle_t = Tuning.SHUFFLE_WARN
	arena.warn.clear()
	for c in _floor_cells():
		arena.warn[c] = biome
	arena.warn_t = 0.0


## Every cell that has a floor (not the border, not shut by the Time of Doom).
func _floor_cells() -> Array:
	var out := []
	for y in arena.rows:
		for x in arena.cols:
			var c := Vector2i(x, y)
			var ct: int = arena.cell_type(c)
			if ct != ArenaScript.BORDER and ct != ArenaScript.CLOSED:
				out.append(c)
	return out


func _update_shuffles(delta: float) -> void:
	if shuffle_phase == "":
		return
	shuffle_t -= delta
	if shuffle_phase == "warn":
		if shuffle_t <= 0.0:
			arena.warn.clear()
			for c in _floor_cells():
				arena.set_terrain(c, shuffle_biome)
			shuffle_phase = "active"
			shuffle_t = Tuning.SHUFFLE_DURATION
		return
	# active: show the way back shortly before it wears off
	if shuffle_t < Tuning.SHUFFLE_WARN and arena.warn.is_empty():
		for c in _floor_cells():
			arena.warn[c] = shuffle_snapshot[c.y * arena.cols + c.x]
		arena.warn_t = 0.0
	if shuffle_t <= 0.0:
		arena.warn.clear()
		for y in arena.rows:
			for x in arena.cols:
				arena.set_terrain(Vector2i(x, y), shuffle_snapshot[y * arena.cols + x])
		shuffle_snapshot = null
		shuffle_phase = ""
		hud.toast("The floor settles back.", Color(0.5, 0.45, 0.6))


# --- end of round ---------------------------------------------------------------------

## A bear stuffed past the threshold wins on the spot.
func _check_instant_win() -> void:
	if Settings.instant_win <= 0.0:
		return
	for b in bears:
		if b.fluff >= Settings.instant_win:
			hud.banner("%s is stuffed to bursting!" % b.bear_name, 2.0)
			_end_match(b)
			return


func _end_match(instant_winner = null) -> void:
	state = State.ENDED
	if parade != null and is_instance_valid(parade):
		parade.queue_free()  # the ducks wind down quietly
		parade = null
	if crane != null and is_instance_valid(crane):
		crane.queue_free()
		crane = null
	if clown != null and is_instance_valid(clown):
		clown.queue_free()
		clown = null
	for b in bears:
		b.stealing = false
	var ranking := bears.duplicate()
	ranking.sort_custom(func(a, b): return a.fluff > b.fluff)
	if instant_winner != null:   # the bear that hit the threshold is the winner, full stop
		ranking.erase(instant_winner)
		ranking.push_front(instant_winner)
	# a human who didn't win hears one of the supplied "you lost" stings instead
	var humans := bears.filter(func(b): return b.is_human)
	if not humans.is_empty() and not ranking[0].is_human and Sfx.has_recording("defeat"):
		Sfx.play("defeat")
	else:
		Sfx.play("victory")
	hud.show_results(ranking, instant_winner)


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
