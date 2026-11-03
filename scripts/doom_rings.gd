## Time of Doom: from 60% of the round the arena closes in ONE TILE AT A TIME,
## walking clockwise around the outermost playable ring, then the next ring in,
## for four rings, finishing shortly before the timer runs out. Every tile
## flashes (faster and faster) before it slams shut; closed tiles are solid for
## good. Game.doom_close() clears each tile and shoves bears inward.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Mode = preload("res://scripts/mode_theme.gd")

var game
var arena
var duration := 150.0
var warn_time := 2.5
var order: Array = []        # all tiles to close, in closing order
var close_at := {}           # Vector2i -> round time (s) it shuts
var ring_start := {}         # ring -> round time its first tile starts flashing
var next := 0                # index into `order` of the next tile to shut
var elapsed := 0.0
var t := 0.0
var _announced := {}
var _tick := 0.0
var slams := {}              # Vector2i -> seconds since it slammed shut


func setup(g, round_duration: float) -> void:
	game = g
	arena = g.arena
	duration = round_duration
	warn_time = clampf(round_duration * 0.03, 1.8, Tuning.DOOM_WARN)
	for k in range(1, Tuning.DOOM_RINGS + 1):
		order.append_array(ring_cells(k))
	# first tile starts flashing at DOOM_START, last one shuts at DOOM_END
	var t0: float = Tuning.DOOM_START * duration + warn_time
	var t1: float = Tuning.DOOM_END * duration
	var step := (t1 - t0) / maxf(order.size() - 1, 1)
	for i in order.size():
		close_at[order[i]] = t0 + i * step
		var r := ring_of(order[i])
		if not ring_start.has(r):
			ring_start[r] = close_at[order[i]] - warn_time


## Ring index of a cell: 0 = the border, 1 = the outermost playable ring, ...
func ring_of(c: Vector2i) -> int:
	return mini(mini(c.x, c.y), mini(arena.cols - 1 - c.x, arena.rows - 1 - c.y))


## Ring `k` clockwise from its top-left corner.
func ring_cells(k: int) -> Array:
	var x0 := k
	var y0 := k
	var x1: int = arena.cols - 1 - k
	var y1: int = arena.rows - 1 - k
	var out := []
	for x in range(x0, x1 + 1):
		out.append(Vector2i(x, y0))
	for y in range(y0 + 1, y1 + 1):
		out.append(Vector2i(x1, y))
	for x in range(x1 - 1, x0 - 1, -1):
		out.append(Vector2i(x, y1))
	for y in range(y1 - 1, y0, -1):
		out.append(Vector2i(x0, y))
	return out


## Seconds until `c` closes (INF if never / already closed).
func time_until_close(c: Vector2i) -> float:
	if not close_at.has(c) or arena.cell_type(c) == arena.CLOSED:
		return INF
	return close_at[c] - elapsed


## Tiles currently flashing -> seconds left (for the AI's danger map).
func warning_cells() -> Dictionary:
	var d := {}
	for i in range(next, order.size()):
		var left: float = close_at[order[i]] - elapsed
		if left > warn_time:
			break
		d[order[i]] = maxf(left, 0.0)
	return d


func warning_active() -> bool:
	return next < order.size() and close_at[order[next]] - elapsed <= warn_time


func closed_count() -> int:
	return next


## Called every physics tick while the round is running.
func update(delta: float, round_elapsed: float) -> void:
	elapsed = round_elapsed
	for r in ring_start:
		if not _announced.has(r) and elapsed >= ring_start[r]:
			_announced[r] = true
			if r == 1:
				game.hud.banner("Time of Doom!" if not Mode.horror() else "The walls are hungry...", 1.8)
			else:
				game.hud.toast("The arena closes in: ring %d of %d" % [r, Tuning.DOOM_RINGS], Color(0.85, 0.35, 0.3))
			Sfx.play("doom_warn")
	if warning_active():
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.22
			Sfx.play("clock_tick", 1.2, -10.0)
	while next < order.size() and elapsed >= close_at[order[next]]:
		var c: Vector2i = order[next]
		next += 1
		slams[c] = 0.0
		game.doom_close([c])


func _process(delta: float) -> void:
	t += delta
	for c in slams.keys():
		slams[c] += delta
		if slams[c] > 0.6:
			slams.erase(c)
	queue_redraw()


func _draw() -> void:
	var T: float = arena.T
	var horror := Mode.horror()
	var col := Color(0.75, 0.05, 0.08) if horror else Color(0.95, 0.42, 0.35)
	var centre := Vector2(arena.cols, arena.rows) * 0.5
	# the next tiles in line flash, faster as their moment comes
	for i in range(next, order.size()):
		var c: Vector2i = order[i]
		var left: float = close_at[c] - elapsed
		if left > warn_time:
			break
		if arena.cell_type(c) == arena.BORDER:
			continue
		var u := 1.0 - clampf(left / warn_time, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(t * TAU * lerpf(2.5, 12.0, u * u) * 0.5)
		var r := Rect2(Vector2(c) * T, Vector2(T, T))
		draw_rect(r.grow(-2), Color(col.r, col.g, col.b, 0.15 + 0.4 * pulse * (0.4 + 0.6 * u)))
		_stitch(r.grow(-5), Color(col.r, col.g, col.b, 0.45 + 0.55 * pulse))
		# an inward arrow on the tile about to go: "get off, go that way"
		if u > 0.5:
			var inward := centre - (Vector2(c) + Vector2(0.5, 0.5))
			var d := Vector2(signf(inward.x), 0) if absf(inward.x) > absf(inward.y) else Vector2(0, signf(inward.y))
			var ctr := r.get_center() + d * (3.0 + 4.0 * pulse)
			var side := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([ctr + d * 8.0, ctr - d * 4.0 + side * 7.0, ctr - d * 4.0 - side * 7.0]),
				Color(1, 1, 1, 0.5 + 0.45 * pulse) if not horror else Color(0.9, 0.75, 0.7, 0.5 + 0.4 * pulse))
	# fresh closures: a flash ring where the tile slammed down
	for c in slams:
		var k: float = slams[c] / 0.6
		var r := Rect2(Vector2(c) * T, Vector2(T, T))
		var flash := Color(1, 0.95, 0.85, 0.6 * (1.0 - k)) if not horror else Color(0.6, 0.0, 0.05, 0.6 * (1.0 - k))
		draw_rect(r.grow(4.0 * k), flash, false, 3.0 * (1.0 - k) + 1.0)


func _stitch(r: Rect2, col: Color) -> void:
	draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), col, 2.0, 5.0)
	draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, col, 2.0, 5.0)
	draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), col, 2.0, 5.0)
	draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, col, 2.0, 5.0)
