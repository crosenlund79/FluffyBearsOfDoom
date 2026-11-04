## Computer opponents. They only press the same three "buttons" a human has,
## so an overstuffed AI bear wobbles, slides and overshoots just like you.
##
## EASY   - slow to react, sometimes misses danger, bombs carelessly, never
##          brakes early (so it overshoots), steals for a random short while.
## NORMAL - understands blast lines, escapes, bombs opponents in line,
##          seeks power-ups and theft, releases the stick to brake in time.
## HARD   - predicts chain reactions and timing, traps opponents, prefers
##          rich targets, weighs theft risk, counter-steers to brake, avoids
##          ice when it is heavy, kicks bombs and lays line bombs at rivals,
##          and charges recklessly while immortal.
## Everyone struggles under Reverse Controls: the curse flips the AI's stick
## too, and it only sometimes remembers to compensate.
extends RefCounted

const Tuning = preload("res://scripts/tuning.gd")
const Terrain = preload("res://scripts/terrain.gd")
const ArenaScript = preload("res://scripts/arena.gd")

enum { EASY, NORMAL, HARD }

const THINK_TIME := Tuning.AI_THINK_TIME
const NOTICE_DANGER := Tuning.AI_NOTICE_DANGER
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const FAR := 999.0
const COMPENSATE := [0.15, 0.45, 0.62]  # chance to correctly counter-steer while cursed
const PowerupScript = preload("res://scripts/powerup.gd")

var bear
var game
var arena
var level := NORMAL
var rng := RandomNumberGenerator.new()

var path: Array = []
var goal := "idle"
var goal_cell := Vector2i(-1, -1)
var think_t := 0.0
var stuck_t := 0.0
var last_pos := Vector2.ZERO
var steal_victim = null
var steal_budget := 0.0
var clock := 0.0
var curse_t := 0.0
var compensating := false
var hesitate_t := 0.0
var rob_choice := {}  # (Easy) bear -> [its stun count, whether we go rob it]
var traps := {}      # Vector2i -> seconds until a rival's proximity bomb covering it is armed
var bad_spots := {}  # Vector2i -> clock time until which bombing there is pointless


func _init(b, g, lvl: int) -> void:
	bear = b
	game = g
	arena = g.arena
	level = lvl
	rng.seed = g.rng.randi()   # follows the match seed
	think_t = rng.randf_range(0.2, 0.6)


func update(delta: float) -> void:
	think_t -= delta
	clock += delta
	if bear.stealing:
		steal_budget -= delta
	if not path.is_empty() and bear.position.distance_to(last_pos) < 0.4:
		stuck_t += delta
	else:
		stuck_t = 0.0
	last_pos = bear.position
	if stuck_t > 0.7:
		path.clear()
		stuck_t = 0.0
		think_t = 0.0
	if think_t <= 0.0:
		think_t = THINK_TIME[level] * rng.randf_range(0.8, 1.25)
		_think()
	_steer(delta)


# --- decision making -----------------------------------------------------------

func _think() -> void:
	var me: Vector2i = bear.cell()
	var danger: Dictionary = game.compute_danger(level, bear)
	traps = game.trap_cells(bear)
	var fearless: bool = level > EASY and bear.immortal_t > 2.5
	if fearless:
		danger = {}  # can't be stunned: ignore blasts entirely
		traps = {}

	# 0. Kick a nearby bomb at a rival.
	if bear.can_kick and level > EASY and _try_kick(me):
		return

	# 1. Get out of blast lines.
	if _threat(danger, me) and rng.randf() < NOTICE_DANGER[level]:
		bear.want_steal = false
		if level == HARD or goal != "flee" or path.is_empty() or not _path_safe(path, danger):
			path = _escape_path(me, danger, FAR)
			goal = "flee"
		return
	if level > EASY and not path.is_empty() and not _path_safe(path, danger):
		path.clear()

	# 2. Rob a stunned bear right next to us.
	var victim = game.find_steal_target(bear)
	if victim == null:
		victim = game.find_chair(bear)   # or loot a delivered chair
	if victim != null and _should_steal(victim, danger):
		bear.want_steal = true
		path.clear()
		goal = "steal"
		return
	bear.want_steal = false

	# 3. Drop a bomb when it is worth it and we can get away.
	if bear.can_place_bomb():
		var reason := _bomb_reason(me)
		if reason != "":
			var esc := _escape_after_bomb(me, danger)
			var careless: bool = rng.randf() < Tuning.AI_CARELESS_BOMB[level]
			if not esc.is_empty() or careless or fearless:
				bear.want_bomb = true
				path = esc
				goal = "flee"
				return
			if reason == "block":
				bad_spots[me] = clock + 8.0  # nowhere to hide from here; pick another spot
				goal = "idle"

	# 3b. Set a proximity trap where rivals will pass.
	if bear.prox_charges > 0 and bear.can_place_bomb() and _try_proximity(me, danger, fearless):
		return

	# 4. Lay a line of bombs toward a rival.
	if bear.has_line and bear.prox_charges == 0 and level > EASY and bear.bombs_max - bear.active_bombs >= 2 and _try_line(me, danger, fearless):
		return

	if goal == "flee" and not path.is_empty():
		return
	_choose_goal(me, danger)


## Proximity bombs: a trap is worth laying in a corridor rivals are heading
## through (Hard), near a rival (Normal), or just whenever one is about (Easy).
## We must be able to walk out of its blast before it arms.
func _try_proximity(me: Vector2i, danger: Dictionary, fearless: bool) -> bool:
	if arena.bombs.has(me) or _threat(danger, me):
		return false
	for b in game.bombs:
		if b.proximity and b.owner_bear == bear and absi(b.cell.x - me.x) + absi(b.cell.y - me.y) <= 3:
			return false   # spread them out
	var near := 99
	for o in game.bears:
		if _targetable(o):
			var oc: Vector2i = o.cell()
			near = mini(near, absi(oc.x - me.x) + absi(oc.y - me.y))
	match level:
		EASY:
			if near > 5 or rng.randf() > 0.25:
				return false
		NORMAL:
			if near > 4 or near < 2:
				return false
		_:
			# a chokepoint (few exits) on the way between us and a rival, not on top of them
			if near > 6 or near < 2 or _exits(me) > 2:
				return false
	var d2 := danger.duplicate()
	for c in game.blast_cells(me, bear.bomb_range):
		d2[c] = minf(d2.get(c, FAR), Tuning.PROX_ARM_TIME)
	var esc := _escape_path(me, d2, Tuning.PROX_ARM_TIME - 0.6)
	if (esc.is_empty() or d2.has(esc[esc.size() - 1])) and not fearless:
		return false
	bear.want_special = true
	path = esc
	goal = "flee"
	return true


func _targetable(b) -> bool:
	return b != bear and not b.is_stunned() and b.immortal_t <= 0.5 and b.immune_t <= 0.4


func _try_kick(me: Vector2i) -> bool:
	for d in DIRS:
		var n: Vector2i = me + d
		var bomb = arena.bombs.get(n)
		if bomb == null or bomb.is_moving() or bomb.fuse < 0.6:
			continue
		var c: Vector2i = n + d
		for i in 9:
			if arena.is_solid(c) or arena.bombs.has(c):
				break
			for b in game.bears:
				if _targetable(b) and b.cell() == c and (level == HARD or rng.randf() < 0.5):
					path = [n]
					goal = "kick"
					return true
			c += d
	return false


func _try_line(me: Vector2i, danger: Dictionary, fearless: bool) -> bool:
	var cells: Array = game.line_cells(bear)
	if cells.size() < 2:
		return false
	var d2 := danger.duplicate()
	for c in cells:
		for x in game.blast_cells(c, bear.bomb_range):
			d2[x] = minf(d2.get(x, FAR), Tuning.BOMB_FUSE)
	var hits := false
	for b in game.bears:
		if _targetable(b) and d2.has(b.cell()) and not danger.has(b.cell()):
			hits = true
	if not hits:
		return false
	var esc := _escape_path(me, d2, Tuning.BOMB_FUSE - 0.45)
	if not fearless and (esc.is_empty() or d2.has(esc[esc.size() - 1])):
		return false
	bear.want_special = true
	path = esc
	goal = "flee"
	return true


## Imminent danger (a far-off duck countdown isn't worth panicking over yet).
func _threat(danger: Dictionary, c: Vector2i) -> bool:
	return danger.has(c) and danger[c] < 4.0


func _should_steal(victim, danger: Dictionary) -> bool:
	if _threat(danger, bear.cell()):
		return false
	if victim != steal_victim:
		steal_victim = victim
		steal_budget = rng.randf_range(Tuning.AI_STEAL_BUDGET_EASY[0], Tuning.AI_STEAL_BUDGET_EASY[1]) if level == EASY else FAR
		if rng.randf() < Tuning.AI_STEAL_SKIP[level]:
			steal_budget = 0.0
	if steal_budget <= 0.0:
		return false
	if level == HARD:
		if victim.stun_t < 0.15:
			return false
		# Greed check: a bulging bear with an armed opponent nearby takes the loot and runs.
		var threat = _nearest_threat(3)
		if threat != null and bear.fluff_ratio() > 2.2 and threat.can_place_bomb():
			return false
	return true


func _nearest_threat(max_dist: int):
	var me: Vector2i = bear.cell()
	for b in game.bears:
		if b == bear or b.is_stunned():
			continue
		var c: Vector2i = b.cell()
		if absi(c.x - me.x) + absi(c.y - me.y) <= max_dist:
			return b
	return null


func _bomb_reason(me: Vector2i) -> String:
	var blast: Array = game.blast_cells(me, bear.bomb_range)
	for b in game.bears:
		if not _targetable(b):
			continue
		var bc: Vector2i = b.cell()
		if blast.has(bc):
			if level == EASY and rng.randf() < 0.5:
				continue
			return "opponent"
		if level == HARD:
			var predicted: Vector2i = arena.world_to_cell(b.position + b.velocity * 0.6)
			if blast.has(predicted):
				return "opponent"
			if absi(bc.x - me.x) + absi(bc.y - me.y) <= 3 and _is_trapped(b, me, blast):
				return "trap"
	if goal == "block" and me == goal_cell:
		return "block"
	if level == EASY and rng.randf() < 0.06 and _count_blocks(blast) > 0:
		return "block"
	return ""


## Would `victim` have no safe cell within reach if we bombed `bomb_cell`?
func _is_trapped(victim, bomb_cell: Vector2i, blast: Array) -> bool:
	var start: Vector2i = victim.cell()
	var seen := {start: 0}
	var queue := [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if not blast.has(c):
			return false
		if seen[c] >= 4:
			continue
		for d in DIRS:
			var n: Vector2i = c + d
			if seen.has(n) or n == bomb_cell or not arena.is_walkable(n):
				continue
			seen[n] = seen[c] + 1
			queue.append(n)
	return true


func _count_blocks(blast: Array) -> int:
	var n := 0
	for c in blast:
		if arena.cell_type(c) == ArenaScript.BLOCK:
			n += 1
	return n


func _choose_goal(me: Vector2i, danger: Dictionary) -> void:
	var search := _dijkstra(me, danger)
	var dist: Dictionary = search[0]
	var parent: Dictionary = search[1]
	var best_score := -FAR
	var best_cell := me
	var best_goal := "idle"
	var tpt := _time_per_tile()

	# Stunned bears are walking treasure chests.
	for b in game.bears:
		if b == bear or not b.is_stunned() or b.fluff < 3.0:
			continue
		var c: Vector2i = b.cell()
		if not dist.has(c):
			continue
		var d: float = dist[c]
		if d * tpt > b.stun_t + (0.6 if level == EASY else 0.2):
			continue
		var score := 0.0
		match level:
			EASY:
				# decided once per stun (no dithering between robbing and wandering)
				if not rob_choice.has(b) or rob_choice[b][0] != b.times_stunned:
					rob_choice[b] = [b.times_stunned, rng.randf() < Tuning.AI_EASY_ROB_CHANCE]
				score = 45.0 if rob_choice[b][1] else -FAR
			NORMAL:
				score = 70.0
			HARD:
				score = 40.0 + b.fluff * Tuning.AI_ROB_GREED[level]
		score -= d * 4.0
		if score > best_score:
			best_score = score
			best_cell = c
			best_goal = "rob"

	# A crane-delivered chair stuffed with fluff.
	if game.chair != null and is_instance_valid(game.chair) and game.chair.fluff > 1.0:
		var cc: Vector2i = game.chair.cell
		if dist.has(cc):
			var cv: float = 40.0 + 0.5 * game.chair.fluff
			if level == EASY:
				cv = 30.0 if rng.randf() < 0.6 else -FAR
			var score: float = cv - dist[cc] * 3.0
			if score > best_score:
				best_score = score
				best_cell = cc
				best_goal = "loot"

	# Power-ups.
	if level != EASY or rng.randf() < 0.4:
		for c in game.powerups:
			if not dist.has(c):
				continue
			var kind: int = game.powerups[c].kind
			var value := 35.0
			match kind:
				PowerupScript.REVERSE, PowerupScript.DIARRHEA, PowerupScript.PRINCESS:
					if level != EASY:
						continue  # Easy doesn't read the labels
				PowerupScript.IMMORTAL:
					value = 55.0
				PowerupScript.KICK, PowerupScript.LINE:
					value = 32.0 if not (bear.can_kick if kind == PowerupScript.KICK else bear.has_line) else 8.0
				PowerupScript.RUBBER:
					value = 22.0 if not bear.has_rubber else 6.0
				PowerupScript.PROXIMITY:
					value = (34.0 if level == HARD else 28.0) if bear.prox_charges < Tuning.PROX_CHARGES else 6.0
			if level == HARD:
				if kind == PowerupScript.SHUFFLE:
					value = 30.0 if bear.fluff_ratio() < 1.3 else 12.0
				elif kind == PowerupScript.SPEED:
					value = 30.0 + 10.0 * bear.fluff_ratio()
			var score: float = value - dist[c] * 4.0
			if score > best_score:
				best_score = score
				best_cell = c
				best_goal = "powerup"

	# Places from which a bomb would open up cushion blocks.
	for c in dist:
		if dist[c] > 9.0 or bad_spots.get(c, -1.0) > clock:
			continue
		var blocks := _count_blocks(game.blast_cells(c, bear.bomb_range))
		if blocks == 0:
			continue
		var score: float = 14.0 + 6.0 * blocks - dist[c] * 3.0
		if c == goal_cell and goal == "block":
			score += 4.0  # a little stubbornness avoids dithering
		if score > best_score:
			best_score = score
			best_cell = c
			best_goal = "block"

	# Hunt opponents.
	for b in game.bears:
		if not _targetable(b):
			continue
		var c: Vector2i = b.cell()
		if not dist.has(c):
			continue
		var score := 0.0
		match level:
			EASY:
				score = 6.0 + rng.randf() * 10.0
			NORMAL:
				score = 16.0
			HARD:
				score = 10.0 + b.fluff * 0.1 - maxf(bear.fluff_ratio() - 2.5, 0.0) * 8.0
		score -= dist[c] * 1.5
		if score > best_score:
			best_score = score
			best_cell = c
			best_goal = "hunt"

	if best_score < 0.0 and dist.size() > 1:
		var keys := dist.keys()
		best_cell = keys[rng.randi() % keys.size()]
		best_goal = "wander"

	goal = best_goal
	goal_cell = best_cell
	path = _reconstruct(parent, me, best_cell)


# --- path finding -----------------------------------------------------------------

func _time_per_tile() -> float:
	return arena.T / maxf(bear.max_speed(), 30.0) * (1.0 + 0.12 * bear.fluff_ratio())


## A cell is unsafe if it will be ablaze around the time we'd be in it.
func _unsafe(c: Vector2i, arrival: float, danger: Dictionary) -> bool:
	# rivals' proximity traps stay deadly once armed (Easy only respects armed ones)
	if traps.has(c) and (traps[c] <= 0.0 or (level > EASY and arrival + 0.3 >= traps[c])):
		return true
	if not danger.has(c):
		return false
	var t: float = danger[c]
	match level:
		EASY, NORMAL:
			return t < arrival + Tuning.AI_DANGER_MARGIN[level]
		_:
			return t < arrival + Tuning.AI_DANGER_MARGIN[level] and t > arrival - 0.6 - Tuning.FLAME_TIME
	return false


func _step_cost(c: Vector2i) -> float:
	var cost := 1.0
	if level == EASY:
		return cost
	var tr: int = arena.terrain_at(c)
	if tr == Terrain.HONEY:
		cost += 1.0
	if level == HARD and tr == Terrain.ICE:
		cost += 0.5 * minf(bear.fluff_ratio(), 4.0)
	return cost


## Returns [dist, parent] over walkable, safe cells (cost-weighted).
func _dijkstra(start: Vector2i, danger: Dictionary, limit := 30.0) -> Array:
	var dist := {start: 0.0}
	var parent := {}
	var steps := {start: 0}
	var open := [start]
	var tpt := _time_per_tile()
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if dist[open[i]] < dist[open[bi]]:
				bi = i
		var c: Vector2i = open[bi]
		open.remove_at(bi)
		if dist[c] > limit:
			continue
		for d in DIRS:
			var n: Vector2i = c + d
			if not arena.is_walkable(n):
				continue
			if level != EASY and game.powerups.has(n) and game.powerups[n].kind in PowerupScript.BAD:
				continue
			var s: int = steps[c] + 1
			if _unsafe(n, s * tpt, danger):
				continue
			var nd: float = dist[c] + _step_cost(n)
			if not dist.has(n) or nd < dist[n]:
				dist[n] = nd
				steps[n] = s
				parent[n] = c
				if not open.has(n):
					open.append(n)
	return [dist, parent]


func _reconstruct(parent: Dictionary, start: Vector2i, goal_c: Vector2i) -> Array:
	var out := []
	var c := goal_c
	while c != start and parent.has(c):
		out.push_front(c)
		c = parent[c]
	return out


func _path_safe(p: Array, danger: Dictionary) -> bool:
	var tpt := _time_per_tile()
	for i in p.size():
		if not arena.is_walkable(p[i]):
			return false
		if i < p.size() - 1 and _unsafe(p[i], (i + 1) * tpt, danger):
			return false
		if i == p.size() - 1 and danger.has(p[i]) and goal != "flee":
			return false
	return true


## Path to the nearest cell outside every blast line.
func _escape_path(start: Vector2i, danger: Dictionary, max_time: float) -> Array:
	var search := _dijkstra(start, danger, 14.0)
	var dist: Dictionary = search[0]
	var best := start
	var best_d := FAR
	var fallback := start
	var fallback_t := -1.0
	for c in dist:
		if not danger.has(c):
			var d: float = dist[c]
			if level == HARD:
				d -= _exits(c) * 0.3  # prefer hiding spots that aren't dead ends
			if d < best_d:
				best_d = d
				best = c
		elif danger[c] > fallback_t:
			fallback_t = danger[c]
			fallback = c
	if best == start and danger.has(start):
		best = fallback
	var p := _reconstruct(search[1], start, best)
	if max_time < FAR and _travel_time(start, p) > max_time:
		return []
	if danger.has(best):
		return [] if max_time < FAR else p
	return p


func _exits(c: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if arena.is_walkable(c + d):
			n += 1
	return n


## How long the path would take - each level estimates differently.
func _travel_time(start: Vector2i, p: Array) -> float:
	if p.is_empty():
		return 0.0
	match level:
		EASY:
			return p.size() * 0.22  # forgets that it's heavy!
		NORMAL:
			return p.size() * _time_per_tile() * 1.1 + 0.15
	var ms: float = bear.max_speed()
	var turns := 0
	var prev := start
	var prev_dir := Vector2i.ZERO
	for c in p:
		var d: Vector2i = c - prev
		if prev_dir != Vector2i.ZERO and d != prev_dir:
			turns += 1
		prev_dir = d
		prev = c
	return p.size() * arena.T / ms + ms / bear.accel() + turns * ms / bear.brake() * 0.5 + 0.1


func _escape_after_bomb(me: Vector2i, danger: Dictionary) -> Array:
	var d2 := danger.duplicate()
	for c in game.blast_cells(me, bear.bomb_range):
		d2[c] = minf(d2.get(c, FAR), Tuning.BOMB_FUSE)
	var p := _escape_path(me, d2, Tuning.BOMB_FUSE - (0.25 if level == EASY else 0.45))
	if p.is_empty() or d2.has(p[p.size() - 1]):
		return []
	return p


# --- steering ------------------------------------------------------------------------

func _steer(delta: float) -> void:
	if bear.stealing or (bear.want_steal and goal == "steal"):
		bear.input_dir = Vector2.ZERO
		return
	while not path.is_empty():
		var c0: Vector2i = path[0]
		var center: Vector2 = arena.cell_center(c0)
		if bear.position.distance_to(center) < 7.0:
			path.pop_front()
			continue
		if bear.cell() == c0 and path.size() > 1:
			var nd: Vector2i = path[1] - c0
			if nd.x != 0 and absf(bear.position.y - center.y) < 6.0:
				path.pop_front()
				continue
			if nd.y != 0 and absf(bear.position.x - center.x) < 6.0:
				path.pop_front()
				continue
		break
	if path.is_empty():
		bear.input_dir = Vector2.ZERO
		return
	var target: Vector2 = arena.cell_center(path[0])
	var d: Vector2 = target - bear.position
	var dir := Vector2(signf(d.x), 0) if absf(d.x) > absf(d.y) else Vector2(0, signf(d.y))
	# Brake early for the next turn or stop (Easy never does: it overshoots).
	if level >= NORMAL:
		var v_along: float = bear.velocity.dot(dir)
		if v_along > 20.0:
			var stop_pt := _stop_point(dir)
			var dist: float = (stop_pt - bear.position).dot(dir)
			var br: float = bear.brake() * Terrain.props(arena.terrain_at(bear.cell()))["brake"]
			var need := v_along * v_along / (2.0 * maxf(br, 1.0))
			var margin := 1.15 if level == HARD else 1.0
			if dist < need * margin + 2.0:
				dir = -dir if (level == HARD and dist < need * 0.8) else Vector2.ZERO
	bear.input_dir = _cursed(dir, delta)


## Under Reverse Controls the bear flips our stick. We only sometimes remember
## to flip it back, and now and then freeze up in confusion.
func _cursed(dir: Vector2, delta: float) -> Vector2:
	if bear.reverse_t <= 0.0:
		return dir
	curse_t -= delta
	hesitate_t -= delta
	if curse_t <= 0.0:
		curse_t = rng.randf_range(0.3, 0.9)
		compensating = rng.randf() < COMPENSATE[level]
		if rng.randf() < 0.25:
			hesitate_t = rng.randf_range(0.15, 0.45)
	if hesitate_t > 0.0:
		return Vector2.ZERO
	return -dir if compensating else dir


## The centre of the last cell before the path turns or ends.
func _stop_point(dir: Vector2) -> Vector2:
	var di := Vector2i(int(dir.x), int(dir.y))
	var last: Vector2i = path[0]
	for i in range(1, path.size()):
		if path[i] - path[i - 1] != di:
			break
		last = path[i]
	return arena.cell_center(last)
