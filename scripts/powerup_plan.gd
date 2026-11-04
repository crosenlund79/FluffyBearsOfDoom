## Controlled, seeded power-up distribution for one round.
##
## A fixed budget of items (Tuning.PU_TOTAL, 24 by default) is drawn per
## category (core / mobility / tactical / chaos / special) with weights and
## per-kind caps from tuning.gd. Items whose kind is switched off (diseases off,
## Princess not rolled) are redistributed to categories that still have room.
##
## Placement: most items are hidden under cushion blocks, the rest are kept as
## a reserve that drops onto the floor later in the round. Every spawn corner
## gets an identical "early" set in the blocks closest to it, so no start
## position is luckier; rare items go in the blocks furthest from all spawns.
##
## Everything uses the given RandomNumberGenerator: same seed, same layout.
extends RefCounted

const P = preload("res://scripts/powerup.gd")
const Tuning = preload("res://scripts/tuning.gd")

var hidden := {}       # Vector2i -> kind (under blocks)
var reserve: Array = []  # kinds dropped later in the round
var counts := {}       # kind -> how many in this round (for tests / reports)


## `blocks`: cells holding cushion blocks. `spawns`: the four start corners.
## `diseases`: whether Reverse Controls / Bomb Diarrhea may appear.
func build(rng: RandomNumberGenerator, blocks: Array, spawns: Array, diseases: bool) -> void:
	var items := draw_items(rng, diseases)
	_place(rng, items, blocks, spawns)


## The round's item list (kinds), category by category.
func draw_items(rng: RandomNumberGenerator, diseases: bool) -> Array:
	counts = {}
	var items := []
	var leftover := 0
	var cats: Array = Tuning.PU_CATEGORIES
	for cat in cats:
		var n: int = cat["count"]
		if cat.get("chance", 1.0) < 1.0 and rng.randf() >= cat["chance"]:
			continue   # Special: a maximum, not a guarantee (an empty slot isn't refilled)
		for i in n:
			var k := _pick(rng, cat["kinds"], diseases)
			if k < 0:
				leftover += 1   # nothing eligible left here
			else:
				items.append(k)
				counts[k] = counts.get(k, 0) + 1
	# redistribute to categories with eligible kinds, in proportion to their size
	var guard := 0
	while leftover > 0 and guard < 200:
		guard += 1
		var total := 0.0
		for cat in cats:
			if cat.get("refill", true) and _has_room(cat["kinds"], diseases):
				total += cat["count"]
		if total <= 0.0:
			break
		var r := rng.randf() * total
		for cat in cats:
			if not (cat.get("refill", true) and _has_room(cat["kinds"], diseases)):
				continue
			r -= cat["count"]
			if r <= 0.0:
				var k := _pick(rng, cat["kinds"], diseases)
				if k >= 0:
					items.append(k)
					counts[k] = counts.get(k, 0) + 1
					leftover -= 1
				break
	return items


func _eligible(kind: int, diseases: bool) -> bool:
	if not diseases and kind in [P.REVERSE, P.DIARRHEA]:
		return false
	return counts.get(kind, 0) < Tuning.PU_CAPS.get(kind, 99)


func _has_room(kinds: Dictionary, diseases: bool) -> bool:
	for k in kinds:
		if kinds[k] > 0.0 and _eligible(k, diseases):
			return true
	return false


func _pick(rng: RandomNumberGenerator, kinds: Dictionary, diseases: bool) -> int:
	var total := 0.0
	for k in kinds:
		if _eligible(k, diseases):
			total += kinds[k]
	if total <= 0.0:
		return -1
	var r := rng.randf() * total
	for k in kinds:
		if not _eligible(k, diseases):
			continue
		r -= kinds[k]
		if r <= 0.0:
			return k
	return -1


## How much an item helps early on (used to even out the four corners).
static func value(kind: int) -> float:
	return Tuning.PU_VALUE.get(kind, 0.5)


static func is_rare(kind: int) -> bool:
	return kind in Tuning.PU_RARE


func _place(rng: RandomNumberGenerator, items: Array, blocks: Array, spawns: Array) -> void:
	hidden = {}
	reserve = []
	_shuffle(rng, items)
	var commons := items.filter(func(k): return not is_rare(k))
	var rares := items.filter(func(k): return is_rare(k))
	# 1. the early set for every corner: one item per slot group (Tuning.PU_EARLY_SET)
	var early := []   # per corner: list of kinds
	for i in spawns.size():
		early.append([])
	for group in Tuning.PU_EARLY_SET:
		var picks := []
		for i in spawns.size():
			var got := -1
			for k in commons:
				if k in group:
					got = k
					break
			if got < 0:
				break
			commons.erase(got)
			picks.append(got)
		if picks.size() < spawns.size():
			commons.append_array(picks)   # not enough for every corner: nobody gets one
			continue
		for i in spawns.size():
			early[i].append(picks[i])
	# 2. the reserve, from what's left (commons first: blocks keep the surprises)
	for i in mini(Tuning.PU_RESERVE, commons.size() + rares.size()):
		reserve.append(commons.pop_back() if not commons.is_empty() else rares.pop_back())
	# blocks: nearest spawn and distance
	var free := blocks.duplicate()
	_shuffle(rng, free)   # ties broken randomly (but reproducibly)
	var near := []
	for s in spawns:
		near.append([])
	var by_dist := []
	for c in free:
		var best := 0
		var bd := 999
		for i in spawns.size():
			var d: int = absi(c.x - spawns[i].x) + absi(c.y - spawns[i].y)
			if d < bd:
				bd = d
				best = i
		if bd <= Tuning.PU_EARLY_RADIUS:
			near[best].append([bd, c])
		by_dist.append([bd, c])
	by_dist.sort_custom(func(a, b): return a[0] > b[0])   # furthest from every spawn first
	var used := {}
	for i in spawns.size():
		near[i].sort_custom(func(a, b): return a[0] < b[0])
		var slot := 0
		var step := 2 if near[i].size() >= early[i].size() * 2 else 1   # spread them out when there's room
		for k in early[i]:
			if slot >= near[i].size():
				commons.append(k)   # (a corner with too few blocks) back to the pool
				continue
			var c: Vector2i = near[i][slot][1]
			hidden[c] = k
			used[c] = true
			slot += step
	# 3. rares: furthest from every spawn
	for k in rares:
		var placed := false
		for e in by_dist:
			if not used.has(e[1]) and e[0] >= Tuning.PU_RARE_MIN_DIST:
				hidden[e[1]] = k
				used[e[1]] = true
				placed = true
				break
		if not placed:
			commons.append(k)
	# 4. the remaining commons: mid-field (outside every corner's region) when possible
	var mid := []
	var rest := []
	for e in by_dist:
		if used.has(e[1]):
			continue
		(mid if e[0] > Tuning.PU_EARLY_RADIUS else rest).append(e[1])
	_shuffle(rng, mid)
	_shuffle(rng, rest)
	for k in commons:
		var pool: Array = mid if not mid.is_empty() else rest
		if pool.is_empty():
			reserve.append(k)   # more items than blocks: they drop later instead
			continue
		hidden[pool.pop_back()] = k


func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
