## The fixed grid: walls, cushion blocks, terrain and their drawing.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Mode = preload("res://scripts/mode_theme.gd")

enum { EMPTY, WALL, BORDER, BLOCK, CLOSED }   # CLOSED: shut by the Time of Doom (permanent)

## The four starting corners: top-left, bottom-right, top-right, bottom-left.
const SPAWNS := [Vector2i(1, 1), Vector2i(Tuning.COLS - 2, Tuning.ROWS - 2), Vector2i(Tuning.COLS - 2, 1), Vector2i(1, Tuning.ROWS - 2)]

var cols := Tuning.COLS
var rows := Tuning.ROWS
var T := Tuning.TILE
var cells := PackedInt32Array()
var terrain := PackedInt32Array()
var base_terrain := PackedInt32Array()
var hidden_powerups := {}   # Vector2i -> power-up kind hidden under a block
var bombs := {}    # Vector2i -> bomb node
var warn := {}     # Vector2i -> upcoming terrain (shuffle warning)
var warn_t := 0.0
var map_name := ""
var tiles_tex: Texture2D
var anim_t := 0.0
var has_conveyors := false
var shake := 0.0
var _origin := Vector2.ZERO
var closing := {}   # Vector2i -> seconds since the cell slammed shut (drop-in animation)
const SLAM_TIME := 0.32


func setup(map: Dictionary, rng: RandomNumberGenerator) -> void:
	tiles_tex = Assets.tex("tiles/tiles")
	map_name = map["name"]
	_origin = position
	cells.resize(cols * rows)
	terrain.resize(cols * rows)
	var rows_def: Array = map.get("terrain", [])
	for y in rows:
		for x in cols:
			var i := y * cols + x
			var t := Terrain.NORMAL
			if y < rows_def.size() and x < String(rows_def[y]).length():
				t = Terrain.CHARS.get(String(rows_def[y])[x], Terrain.NORMAL)
			terrain[i] = t
			if Terrain.is_conveyor(t):
				has_conveyors = true
			if x == 0 or y == 0 or x == cols - 1 or y == rows - 1:
				cells[i] = BORDER
			elif x % 2 == 0 and y % 2 == 0:
				cells[i] = WALL
			elif _is_spawn_zone(Vector2i(x, y)):
				cells[i] = EMPTY
			elif rng.randf() < map.get("block_density", Tuning.BLOCK_DENSITY):
				cells[i] = BLOCK
			else:
				cells[i] = EMPTY
	limit_conveyors(Tuning.MAX_H_BELTS, Tuning.MAX_V_BELTS)
	base_terrain = terrain.duplicate()
	queue_redraw()


func _is_spawn_zone(c: Vector2i) -> bool:
	for s in SPAWNS:
		if absi(c.x - s.x) + absi(c.y - s.y) <= 1:
			return true
	return false


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func cell_type(c: Vector2i) -> int:
	if not in_bounds(c):
		return BORDER
	return cells[c.y * cols + c.x]


## Walls, the border and closed cells: nothing breaks them and blasts stop there.
func is_hard(c: Vector2i) -> bool:
	var t := cell_type(c)
	return t == WALL or t == BORDER or t == CLOSED


## Shut a cell for good (Time of Doom). Its block and hidden power-up are gone.
func close_cell(c: Vector2i) -> void:
	if not in_bounds(c) or cell_type(c) == BORDER:
		return
	cells[c.y * cols + c.x] = CLOSED
	hidden_powerups.erase(c)
	warn.erase(c)
	closing[c] = 0.0
	queue_redraw()


func is_solid(c: Vector2i) -> bool:
	return cell_type(c) != EMPTY


func is_walkable(c: Vector2i) -> bool:
	return not is_solid(c) and not bombs.has(c)


func blocks_bear(c: Vector2i, bear) -> bool:
	if is_solid(c):
		return true
	var b = bombs.get(c)
	return b != null and not b.pass_through.has(bear)


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * T, (c.y + 0.5) * T)


func terrain_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return Terrain.NORMAL
	return terrain[c.y * cols + c.x]


func set_terrain(c: Vector2i, t: int) -> void:
	if in_bounds(c):
		terrain[c.y * cols + c.x] = t
		if Terrain.is_conveyor(t):
			has_conveyors = true
		queue_redraw()


## Every cell holding a cushion block (row by row).
func block_cells() -> Array:
	var out := []
	for y in rows:
		for x in cols:
			if cells[y * cols + x] == BLOCK:
				out.append(Vector2i(x, y))
	return out


## Conveyor belts as straight runs of one direction: {"h": [[cells]], "v": [[cells]]}.
func conveyor_runs(t_arr: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var src := terrain if t_arr.is_empty() else t_arr
	var h := []
	var v := []
	var seen := {}
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var t: int = src[y * cols + x]
			if not Terrain.is_conveyor(t) or seen.has(c):
				continue
			var horiz: bool = t == Terrain.CONVEYOR_R or t == Terrain.CONVEYOR_L
			var step := Vector2i(1, 0) if horiz else Vector2i(0, 1)
			var run := []
			var k := c
			while in_bounds(k) and src[k.y * cols + k.x] == t and not seen.has(k):
				run.append(k)
				seen[k] = true
				k += step
			(h if horiz else v).append(run)
	return {"h": h, "v": v}


## Keeps at most `max_h` horizontal and `max_v` vertical belts (the longest);
## the rest become plain floor.
func limit_conveyors(max_h: int, max_v: int) -> void:
	var runs := conveyor_runs()
	for pair in [[runs["h"], max_h], [runs["v"], max_v]]:
		var list: Array = pair[0]
		list.sort_custom(func(a, b): return a.size() > b.size())
		for i in range(pair[1], list.size()):
			for c in list[i]:
				terrain[c.y * cols + c.x] = Terrain.NORMAL
	has_conveyors = not conveyor_runs()["h"].is_empty() or not conveyor_runs()["v"].is_empty()


## Destroys a cushion block, returning the hidden power-up kind or -1.
func destroy_block(c: Vector2i) -> int:
	if cell_type(c) != BLOCK:
		return -1
	cells[c.y * cols + c.x] = EMPTY
	queue_redraw()
	var p: int = hidden_powerups.get(c, -1)
	hidden_powerups.erase(c)
	return p


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func _process(delta: float) -> void:
	anim_t += delta
	if warn.size() > 0:
		warn_t += delta
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 30.0)
		position = _origin + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	elif position != _origin:
		position = _origin
	if not closing.is_empty():
		for c in closing.keys():
			closing[c] += delta
			if closing[c] >= SLAM_TIME:
				closing.erase(c)
	if has_conveyors or warn.size() > 0 or not closing.is_empty():
		queue_redraw()


func _tile(index: int) -> Rect2:
	return Assets.region(tiles_tex, Assets.TILE_CELLS, index)


func _draw() -> void:
	# soft drop shadow under the whole arena
	draw_rect(Rect2(Vector2(6, 10), Vector2(cols, rows) * T), Color(0.35, 0.25, 0.2, 0.18))
	# floors
	for y in rows:
		for x in cols:
			var i := y * cols + x
			var r := Rect2(x * T, y * T, T, T)
			if cells[i] == BORDER or (cells[i] == CLOSED and not closing.has(Vector2i(x, y))):
				continue
			var t := terrain[i]
			var p := Terrain.props(t)
			var idx: int = p["tile"]
			if t == Terrain.NORMAL and (x + y) % 2 == 1 and not Mode.horror_dressing():
				idx = 1   # (Horror keeps the floor calm: no checkerboard)
			if Terrain.is_conveyor(t):
				draw_set_transform(r.get_center(), Terrain.conveyor_rotation(t), Vector2.ONE)
				draw_texture_rect_region(tiles_tex, Rect2(-T * 0.5, -T * 0.5, T, T), _tile(idx))
				# moving chevrons
				var off := fmod(anim_t * 40.0, T / 3.0)
				for k in 3:
					var cx := -T * 0.5 + off + k * T / 3.0
					if cx > T * 0.5 - 4:
						continue
					draw_polyline(PackedVector2Array([Vector2(cx - 4, -7), Vector2(cx + 3, 0), Vector2(cx - 4, 7)]), Color(1, 1, 1, 0.55), 2.5)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture_rect_region(tiles_tex, r, _tile(idx))
	# shadows cast by walls and blocks
	for y in rows:
		for x in cols:
			var ct := cells[y * cols + x]
			if ct == WALL:
				draw_rect(Rect2(x * T + 5, y * T + 8, T - 2, T - 4), Color(0.2, 0.12, 0.08, 0.3))
			elif ct == BLOCK:
				draw_rect(Rect2(x * T + 5, y * T + 8, T - 2, T - 4), Color(0.3, 0.2, 0.15, 0.16))
	# shuffle warnings: pulsing stitched squares showing the coming terrain
	if warn.size() > 0:
		var pulse := 0.5 + 0.5 * sin(warn_t * 14.0)
		for c in warn:
			var r := Rect2(c.x * T, c.y * T, T, T)
			var col: Color = Terrain.props(warn[c])["color"]
			draw_rect(r.grow(-3), Color(col.r, col.g, col.b, 0.35 + 0.4 * pulse))
			_stitch(r.grow(-5), Color(0.55, 0.3, 0.35, 0.5 + 0.5 * pulse))
	# walls, pillars and cushion blocks with a little pseudo height.
	# Permanent walls are tinted darker so they read clearly against floor and cushions.
	var wall_col := Mode.wall_tint()
	var border_col := Mode.border_tint()
	for y in rows:
		for x in cols:
			var ct := cells[y * cols + x]
			var r := Rect2(x * T, y * T, T, T)
			if ct == BORDER:
				draw_texture_rect_region(tiles_tex, r, _tile(8), border_col)
			elif ct == CLOSED:
				_draw_closed(Vector2i(x, y), r, border_col)
			elif ct == WALL:
				draw_texture_rect_region(tiles_tex, Rect2(r.position - Vector2(0, 6), Vector2(T, T + 6)), _tile(6), wall_col)
			elif ct == BLOCK:
				var squish := 1.0 + 0.02 * sin(anim_t * 2.0 + x * 1.3 + y * 0.7)
				var h := (T + 4) * squish
				draw_texture_rect_region(tiles_tex, Rect2(Vector2(r.position.x, r.end.y - h), Vector2(T, h)), _tile(7))

	_draw_sunken_shadow()
	if Mode.horror_dressing():
		_draw_horror_decor()


## The arena sits a step below the raised rim around it: the rim casts a soft
## shadow onto the top and left edges, and a faint highlight catches the far side.
func _draw_sunken_shadow() -> void:
	var w := cols * T
	var h := rows * T
	for i in 6:
		var a := 0.22 * (1.0 - i / 6.0)
		draw_rect(Rect2(0, i * 4.0, w, 4.0), Color(0.05, 0.02, 0.02, a))
		draw_rect(Rect2(i * 4.0, 0, 4.0, h), Color(0.05, 0.02, 0.02, a * 0.8))
	draw_rect(Rect2(0, h - 3.0, w, 3.0), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(w - 3.0, 0, 3.0, h), Color(1, 1, 1, 0.06))


## Horror dressing, purely visual (no collision): pumpkins, skulls, spiders,
## bats and webs on the outer wall, and faint cobwebs in corridor corners.
func _draw_horror_decor() -> void:
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var h := (x * 73856093) ^ (y * 19349663)
			var r := Rect2(x * T, y * T, T, T)
			var ct := cells[y * cols + x]
			if ct == BORDER:
				var corner := (x == 0 or x == cols - 1) and (y == 0 or y == rows - 1)
				if corner:
					_web(r.position + Vector2(T if x > 0 else 0.0, T if y > 0 else 0.0), T * 1.1, Vector2(-1 if x > 0 else 1, -1 if y > 0 else 1), 0.55)
					continue
				match absi(h) % 7:
					0: _pumpkin(r.get_center() + Vector2(0, 4))
					1: _skull(r.get_center() + Vector2(0, 6), 0.9)
					2: _spider(r.get_center() + Vector2(0, -4))
					3: _bat(r.get_center() + Vector2(0, -6))
			elif ct == EMPTY and absi(h) % 9 == 0:
				# a cobweb tucked into the corner of a corridor tile, faint and small
				var k := absi(h / 9) % 4
				var corner_pt := r.position + Vector2(T if k % 2 == 1 else 0.0, T if k >= 2 else 0.0)
				_web(corner_pt, T * 0.45, Vector2(-1 if k % 2 == 1 else 1, -1 if k >= 2 else 1), 0.22)


func _web(origin: Vector2, size: float, dir: Vector2, a: float) -> void:
	var col := Color(0.85, 0.85, 0.85, a)
	var ends := []
	for i in 5:
		var ang := (i / 4.0) * PI * 0.5
		var e := origin + Vector2(cos(ang) * dir.x, sin(ang) * dir.y) * size
		ends.append(e)
		draw_line(origin, e, col, 1.0)
	for ring in [0.35, 0.62, 0.9]:
		for i in 4:
			draw_line(origin.lerp(ends[i], ring), origin.lerp(ends[i + 1], ring), col, 1.0)


func _pumpkin(p: Vector2) -> void:
	for dx in [-7.0, 7.0, 0.0]:
		draw_set_transform(p + Vector2(dx, 0), 0.0, Vector2(0.75, 1.0))
		draw_circle(Vector2.ZERO, 11.0, Color(0.85, 0.42, 0.08) if dx == 0.0 else Color(0.72, 0.33, 0.06))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(p + Vector2(0, -10), p + Vector2(3, -16), Color(0.25, 0.3, 0.1), 3.0)
	var glow := Color(1.0, 0.85, 0.3)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -3), p + Vector2(-3, -3), p + Vector2(-5.5, -7)]), glow)
	draw_colored_polygon(PackedVector2Array([p + Vector2(3, -3), p + Vector2(8, -3), p + Vector2(5.5, -7)]), glow)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 3), p + Vector2(8, 3), p + Vector2(5, 7), p + Vector2(0, 5), p + Vector2(-5, 7)]), glow)


func _skull(p: Vector2, s: float) -> void:
	var bone := Color(0.9, 0.87, 0.78)
	draw_circle(p + Vector2(0, -3) * s, 9.0 * s, bone)
	draw_rect(Rect2(p + Vector2(-5, 2) * s, Vector2(10, 6) * s), bone)
	draw_circle(p + Vector2(-3.5, -3) * s, 2.6 * s, Color(0.1, 0.05, 0.05))
	draw_circle(p + Vector2(3.5, -3) * s, 2.6 * s, Color(0.1, 0.05, 0.05))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, 0) * s, p + Vector2(-1.5, 3) * s, p + Vector2(1.5, 3) * s]), Color(0.1, 0.05, 0.05))
	for i in 3:
		draw_line(p + Vector2(-3 + i * 3, 5) * s, p + Vector2(-3 + i * 3, 8) * s, Color(0.3, 0.25, 0.2), 1.0)


func _spider(p: Vector2) -> void:
	var c := Color(0.08, 0.05, 0.06)
	draw_line(p + Vector2(0, -14), p, Color(0.8, 0.8, 0.8, 0.5), 1.0)   # its thread
	for sx in [-1.0, 1.0]:
		for i in 4:
			var a := -0.6 + i * 0.4
			var knee := p + Vector2(sx * 7, -3 + i * 2.5)
			draw_line(p, knee, c, 1.5)
			draw_line(knee, knee + Vector2(sx * 4, 4 + a * 2), c, 1.5)
	draw_circle(p + Vector2(0, 2), 5.0, c)
	draw_circle(p + Vector2(0, -3), 3.2, c)
	draw_circle(p + Vector2(-1.2, -3.5), 0.9, Color(0.9, 0.1, 0.1))
	draw_circle(p + Vector2(1.2, -3.5), 0.9, Color(0.9, 0.1, 0.1))


func _bat(p: Vector2) -> void:
	var c := Color(0.1, 0.06, 0.08)
	for sx in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(sx * 6, -6), p + Vector2(sx * 15, -3),
			p + Vector2(sx * 12, 2), p + Vector2(sx * 9, 0), p + Vector2(sx * 6, 3)]), c)
	draw_circle(p, 4.0, c)
	draw_circle(p + Vector2(-1.5, -1), 0.8, Color(0.95, 0.2, 0.2))
	draw_circle(p + Vector2(1.5, -1), 0.8, Color(0.95, 0.2, 0.2))


## A closed cell: a border tile dropped in, laced shut with heavy stitches.
func _draw_closed(c: Vector2i, r: Rect2, border_col: Color) -> void:
	var k := 1.0
	if closing.has(c):
		k = clampf(closing[c] / SLAM_TIME, 0.0, 1.0)
	var drop := (1.0 - k * k) * T * 2.2
	var rr := Rect2(r.position - Vector2(0, drop), r.size)
	var a := clampf(k * 2.0, 0.0, 1.0)
	draw_texture_rect_region(tiles_tex, rr, _tile(8), Color(Mode.closed_tint(), a))
	var thread := Mode.closed_thread()
	thread.a *= a
	draw_line(rr.position + Vector2(8, 8), rr.end - Vector2(8, 8), thread, 3.0)
	draw_line(Vector2(rr.end.x - 8, rr.position.y + 8), Vector2(rr.position.x + 8, rr.end.y - 8), thread, 3.0)
	_stitch(rr.grow(-4), Color(thread, thread.a * 0.7))


func _stitch(r: Rect2, col: Color) -> void:
	draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), col, 2.0, 5.0)
	draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, col, 2.0, 5.0)
	draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), col, 2.0, 5.0)
	draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, col, 2.0, 5.0)
