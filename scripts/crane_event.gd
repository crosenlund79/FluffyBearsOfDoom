## Rare event: a crane hook swings in from off-screen carrying an overstuffed
## chair, dangles over a cell (with a target marker as warning), drops it and
## leaves. The landed chair (chair.gd) is then looted for its fluff.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Mode = preload("res://scripts/mode_theme.gd")

enum { ENTER, LOWER, HOVER, DROP, LEAVE }

var game
var arena
var target := Vector2i.ZERO
var phase := ENTER
var t := 0.0              # time in the current phase
var age := 0.0
var hook := Vector2.ZERO  # hook position (arena-local)
var side := 1.0
var chair_y := 0.0        # falling chair's offset below the hook
var chair_v := 0.0
var swing := 0.0
var swing_v := 0.0
var done := false
var carrying := true
var _creak := 0.0
var _rng := RandomNumberGenerator.new()


func setup(g, cell: Vector2i) -> void:
	game = g
	arena = g.arena
	target = cell
	_rng.randomize()
	side = 1.0 if _rng.randf() < 0.5 else -1.0
	var tc: Vector2 = arena.cell_center(cell)
	hook = Vector2(tc.x - side * 900.0, _travel_y())
	swing_v = side * 1.5
	Sfx.play("crane")


func _travel_y() -> float:
	return maxf(arena.cell_center(target).y - 150.0, -20.0)


## Hook height that leaves the chair dangling about a tile above its cell.
func _hang_y() -> float:
	return _land_top() - 28.0 - arena.T


## Top edge of the chair once it stands on its cell (matches chair.gd).
func _land_top() -> float:
	return arena.cell_center(target).y + arena.T * 0.4 - arena.T * 1.02


func _physics_process(delta: float) -> void:
	if done:
		return
	age += delta
	t += delta
	# pendulum swing of the load
	swing_v += (-18.0 * swing - 1.6 * swing_v) * delta
	swing += swing_v * delta
	_creak -= delta
	if _creak <= 0.0 and phase != LEAVE:
		_creak = 1.6
		Sfx.play("crane", _rng.randf_range(0.9, 1.1), -6.0)
	var tc: Vector2 = arena.cell_center(target)
	match phase:
		ENTER:
			var step := Tuning.CRANE_SPEED * delta
			if absf(tc.x - hook.x) <= step:
				hook.x = tc.x
				swing_v -= side * 2.5   # sudden stop sets the chair swinging
				_next(LOWER)
			else:
				hook.x += signf(tc.x - hook.x) * step
		LOWER:
			hook.y = lerpf(_travel_y(), _hang_y(), smoothstep(0.0, 1.0, t / 0.9))
			if t >= 0.9:
				_next(HOVER)
		HOVER:
			hook.y = _hang_y() + sin(t * 9.0) * 1.5
			if t >= Tuning.CRANE_HOVER:
				_next(DROP)
				chair_v = 60.0
				Sfx.play("pop", 0.6, -4.0)   # clunk of the release
		DROP:
			chair_v += 1400.0 * delta
			chair_y += chair_v * delta
			hook.y -= 120.0 * delta
			if hook.y + 28.0 + chair_y >= _land_top():
				carrying = false
				game.land_chair(target)
				_next(LEAVE)
		LEAVE:
			hook.y -= 260.0 * delta
			hook.x += side * 120.0 * delta
			if hook.y < -420.0:
				done = true
				game.crane = null
				queue_free()
	queue_redraw()


func _next(p: int) -> void:
	phase = p
	t = 0.0


func _draw() -> void:
	var T: float = arena.T
	var horror := Mode.horror()
	var metal := Color(0.32, 0.27, 0.27) if horror else Color(0.48, 0.44, 0.47)
	var dark := Color(0.12, 0.08, 0.08) if horror else Color(0.25, 0.2, 0.2)
	# target marker on the floor while it dangles (the drop warning)
	if phase in [LOWER, HOVER] or (phase == DROP and carrying):
		var c: Vector2 = arena.cell_center(target)
		var pulse := 0.5 + 0.5 * sin(age * 10.0)
		var col := Color(0.75, 0.1, 0.12) if horror else UiStyle.ROSE_DARK
		draw_set_transform(c + Vector2(0, 8), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, T * 0.44, Color(col.r, col.g, col.b, 0.14 + 0.12 * pulse))
		draw_arc(Vector2.ZERO, T * 0.44, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.6 + 0.4 * pulse), 2.4)
		draw_arc(Vector2.ZERO, T * 0.24, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.5 + 0.4 * pulse), 1.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# cable from the top of the screen
	var top := Vector2(hook.x, -80.0)
	draw_line(top, hook + Vector2(0, -8), dark, 3.0)
	if horror:
		for k in 3:
			var y := lerpf(top.y, hook.y, 0.3 + k * 0.25)
			draw_circle(Vector2(hook.x + 2, y + fmod(age * 30.0 + k * 20.0, 14.0)), 1.6, Color(0.5, 0.03, 0.07, 0.8))
	# hook block + claw
	draw_rect(Rect2(hook + Vector2(-8, -14), Vector2(16, 12)), metal)
	draw_rect(Rect2(hook + Vector2(-8, -14), Vector2(16, 12)), dark, false, 1.5)
	var claw := hook + Vector2(0, -2)
	draw_arc(claw + Vector2(0, 10), 9.0, -PI * 0.1, PI * 1.15, 14, metal, 3.5)
	# the chair hanging from (or falling off) the hook
	if carrying:
		var tex: Texture2D = Assets.tex("objects/chair")
		var w := T * 1.02
		var anchor := hook + Vector2(0, 14 + chair_y)
		draw_set_transform(anchor, swing * 0.35, Vector2.ONE)
		if phase != DROP:
			draw_line(Vector2.ZERO, Vector2(-w * 0.3, 18), dark, 1.6)   # straps
			draw_line(Vector2.ZERO, Vector2(w * 0.3, 18), dark, 1.6)
		draw_texture_rect(tex, Rect2(-w * 0.5, 14, w, w * 1.0), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
