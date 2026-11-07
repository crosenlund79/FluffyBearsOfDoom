## Atmospheric 2D lighting on top of the existing arena (no new art): a soft
## ambient tone, warm decor lamps, a glow on every bomb and a brief flash from
## each explosion. Horror is darker with flickering light; Custom keeps light
## neutral so custom art keeps its colours. Settings.lighting: "high", "low"
## (bombs and blasts only) or "off" (exactly the old look).
extends Node

const Mode = preload("res://scripts/mode_theme.gd")

const BOMB_LIGHTS := {"high": 10, "low": 5}
const FLASHES := {"high": 6, "low": 3}

var game
var arena
var quality := "high"
var tex: Texture2D
var bomb_pool: Array = []
var flash_pool: Array = []      # [light, time left, peak energy]
var decor: Array = []           # [light, base energy, phase]
var t := 0.0
var _dip := 0.0                 # Horror: an occasional brief brown-out of the lamps
var _rng := RandomNumberGenerator.new()


func setup(g) -> void:
	game = g
	arena = g.arena
	quality = Settings.lighting
	if quality == "off":
		return
	_rng.randomize()
	tex = _radial()
	# ambient: never dark enough to hide a bomb or a bear
	if Mode.horror():
		game.ambient = Color(0.86, 0.84, 0.88)
	elif Settings.mode == "custom":
		game.ambient = Color(0.96, 0.96, 0.96)
	else:
		game.ambient = Color(0.93, 0.92, 0.9)
	game.world_tint.color = Mode.world_modulate() * game.ambient
	for i in BOMB_LIGHTS[quality]:
		bomb_pool.append(_light(Color.WHITE, 0.0, 1.0))
	for i in FLASHES[quality]:
		flash_pool.append([_light(Color.WHITE, 0.0, 1.0), 0.0, 0.0])
	if quality == "high":
		_place_decor()
	game.game_event.connect(_on_event)


## A soft round light texture (white centre fading to nothing).
func _radial() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.45, Color(1, 1, 1, 0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	return gt


func _light(col: Color, energy: float, scale_k: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex
	l.color = col
	l.energy = energy
	l.texture_scale = scale_k
	l.enabled = energy > 0.0
	arena.add_child(l)
	return l


## Warm lamps: the four outer corners in Normal/Custom, the pumpkins on the
## outer wall in Horror (same spots the arena decorates).
func _place_decor() -> void:
	var spots := []
	if Mode.horror_dressing():
		for y in arena.rows:
			for x in arena.cols:
				if arena.cell_type(Vector2i(x, y)) != arena.BORDER:
					continue
				var corner: bool = (x == 0 or x == arena.cols - 1) and (y == 0 or y == arena.rows - 1)
				var h: int = (x * 73856093) ^ (y * 19349663)
				if not corner and absi(h) % 7 == 0:
					spots.append(arena.cell_center(Vector2i(x, y)))
	else:
		for c in [Vector2i(0, 0), Vector2i(arena.cols - 1, 0), Vector2i(0, arena.rows - 1), Vector2i(arena.cols - 1, arena.rows - 1)]:
			spots.append(arena.cell_center(c))
	var col := Color(1.0, 0.62, 0.25) if Mode.horror() else (Color(1.0, 0.9, 0.75) if Settings.mode == "custom" else Color(1.0, 0.82, 0.55))
	var energy := 0.55 if Mode.horror() else 0.3
	for p in spots.slice(0, 8):
		var l := _light(col, energy, 1.1)
		l.position = p
		decor.append([l, energy, _rng.randf() * TAU])


func _on_event(kind: String, data: Dictionary) -> void:
	if kind != "blast" or flash_pool.is_empty():
		return
	var slot = flash_pool[0]
	for f in flash_pool:
		if f[1] <= 0.0:
			slot = f
			break
	var l: PointLight2D = slot[0]
	l.position = arena.cell_center(data["cell"])
	l.color = Color(1.0, 0.45, 0.25) if Mode.horror() else Color(1.0, 0.85, 0.55)
	l.texture_scale = 2.0 + 0.12 * data.get("size", 5)
	slot[1] = 0.35
	slot[2] = 1.5 if Mode.horror() else 0.9
	l.enabled = true


func _process(delta: float) -> void:
	if quality == "off" or game == null:
		return
	t += delta
	# bombs: a small glow, pulsing faster as the fuse runs out (red when a proximity bomb is armed)
	var bombs: Array = game.bombs
	for i in bomb_pool.size():
		var l: PointLight2D = bomb_pool[i]
		if i >= bombs.size() or not is_instance_valid(bombs[i]):
			l.enabled = false
			continue
		var b = bombs[i]
		var urgency := clampf(1.0 - b.fuse / 3.0, 0.0, 1.0)
		if b.proximity and not b.triggered:
			urgency = 0.0
		l.enabled = true
		l.position = b.position + Vector2(0, -6)
		var armed: bool = b.proximity and b.armed()
		l.color = Color(1.0, 0.2, 0.15) if armed or Mode.horror() else Color(1.0, 0.75, 0.45)
		var pulse := 0.5 + 0.5 * sin(t * (5.0 + 20.0 * urgency))
		l.energy = (0.35 if not Mode.horror() else 0.55) * (0.7 + 0.3 * pulse) * (1.0 + urgency)
		l.texture_scale = 0.65 + 0.25 * urgency
	# explosion flashes fade out fast
	for f in flash_pool:
		if f[1] > 0.0:
			f[1] -= delta
			var k := clampf(f[1] / 0.35, 0.0, 1.0)
			f[0].energy = f[2] * k * k
			if f[1] <= 0.0:
				f[0].enabled = false
	# decor lamps; Horror flickers, with the odd brown-out
	if Mode.horror() and _dip <= 0.0 and _rng.randf() < delta * 0.08:
		_dip = _rng.randf_range(0.12, 0.4)
	_dip = maxf(0.0, _dip - delta)
	for d in decor:
		var e: float = d[1]
		if Mode.horror():
			e *= 0.8 + 0.2 * sin(t * 13.0 + d[2]) * sin(t * 7.3 + d[2] * 2.0)
			if _dip > 0.0:
				e *= 0.35
		else:
			e *= 0.92 + 0.08 * sin(t * 1.5 + d[2])
		d[0].energy = e
