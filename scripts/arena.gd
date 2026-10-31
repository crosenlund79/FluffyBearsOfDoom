## The fixed grid: walls, cushion blocks, terrain and their drawing.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Terrain = preload("res://scripts/terrain.gd")

enum { EMPTY, WALL, BORDER, BLOCK }

const SPAWNS := [Vector2i(1, 1), Vector2i(13, 11), Vector2i(13, 1), Vector2i(1, 11)]

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


func setup(map: Dictionary, rng: RandomNumberGenerator, powerup_weights: Array) -> void:
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
	base_terrain = terrain.duplicate()
	# Hide power-ups under some blocks, guaranteeing a couple of Biome Shuffles.
	var blocks := []
	for y in rows:
		for x in cols:
			if cells[y * cols + x] == BLOCK:
				blocks.append(Vector2i(x, y))
	blocks.shuffle()
	var total_w := 0.0
	for w in powerup_weights:
		total_w += w
	for c in blocks:
		if rng.randf() < Tuning.POWERUP_CHANCE:
			var r := rng.randf() * total_w
			for k in powerup_weights.size():
				r -= powerup_weights[k]
				if r <= 0.0:
					hidden_powerups[c] = k
					break
	var shuffles := 0
	for c in hidden_powerups:
		if hidden_powerups[c] == 3:
			shuffles += 1
	for c in blocks:
		if shuffles >= 2:
			break
		if not hidden_powerups.has(c) or hidden_powerups[c] != 3:
			hidden_powerups[c] = 3
			shuffles += 1
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
	if has_conveyors or warn.size() > 0:
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
			if cells[i] == BORDER:
				continue
			var t := terrain[i]
			var p := Terrain.props(t)
			var idx: int = p["tile"]
			if t == Terrain.NORMAL and (x + y) % 2 == 1:
				idx = 1
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
			if ct == WALL or ct == BLOCK:
				draw_rect(Rect2(x * T + 5, y * T + 8, T - 2, T - 4), Color(0.3, 0.2, 0.15, 0.16))
	# shuffle warnings: pulsing stitched squares showing the coming terrain
	if warn.size() > 0:
		var pulse := 0.5 + 0.5 * sin(warn_t * 14.0)
		for c in warn:
			var r := Rect2(c.x * T, c.y * T, T, T)
			var col: Color = Terrain.props(warn[c])["color"]
			draw_rect(r.grow(-3), Color(col.r, col.g, col.b, 0.35 + 0.4 * pulse))
			_stitch(r.grow(-5), Color(0.55, 0.3, 0.35, 0.5 + 0.5 * pulse))
	# walls, pillars and cushion blocks with a little pseudo height
	for y in rows:
		for x in cols:
			var ct := cells[y * cols + x]
			var r := Rect2(x * T, y * T, T, T)
			if ct == BORDER:
				draw_texture_rect_region(tiles_tex, r, _tile(8))
			elif ct == WALL:
				draw_texture_rect_region(tiles_tex, Rect2(r.position - Vector2(0, 6), Vector2(T, T + 6)), _tile(6))
			elif ct == BLOCK:
				var squish := 1.0 + 0.02 * sin(anim_t * 2.0 + x * 1.3 + y * 0.7)
				var h := (T + 4) * squish
				draw_texture_rect_region(tiles_tex, Rect2(Vector2(r.position.x, r.end.y - h), Vector2(T, h)), _tile(7))


func _stitch(r: Rect2, col: Color) -> void:
	draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), col, 2.0, 5.0)
	draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, col, 2.0, 5.0)
	draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), col, 2.0, 5.0)
	draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, col, 2.0, 5.0)
