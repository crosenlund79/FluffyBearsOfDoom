## The carnival claw: it hangs from a rail along the top edge of the arena and is
## always there, parked in the top-left corner with a stuffed chair in its prongs.
## Before a delivery the warning lights along the rail race toward the drop
## point; the claw rides along the rail, lowers over its target (a pulsing
## marker on the floor), opens its prongs and drops the chair, then rides back
## and picks up a fresh one. The landed chair (chair.gd) is looted for fluff.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Mode = preload("res://scripts/mode_theme.gd")

enum { PARKED, WARN, ENTER, LOWER, HOVER, DROP, RAISE, RETURN }
const WARN_TIME := 1.8

var game
var arena
var target := Vector2i.ZERO
var phase := PARKED
var t := 0.0              # time in the current phase
var age := 0.0
var hook := Vector2.ZERO  # claw position (arena-local)
var chair_y := 0.0        # falling chair's offset below the claw
var chair_v := 0.0
var swing := 0.0
var swing_v := 0.0
var carrying := true      # a chair in its prongs
var prongs := 0.0         # 0 closed .. 1 open
var _creak := 0.0
var _rng := RandomNumberGenerator.new()


func setup(g) -> void:
	game = g
	arena = g.arena
	_rng.randomize()
	hook = _park()


## The rail runs just above the arena's top edge; the claw parks over the corner.
func _rail_y() -> float:
	return -arena.T * 0.22   # on the raised rim, clear of the timer above


func _park() -> Vector2:
	return Vector2(arena.T * 0.5, _rail_y() + arena.T * 0.35)


func busy() -> bool:
	return phase != PARKED


## Start a delivery to `cell`: lights first, then off it goes.
func deploy(cell: Vector2i) -> void:
	target = cell
	carrying = true
	_next(WARN)
	Sfx.play("doom_warn", 1.6, -8.0)


## Hook height that leaves the chair dangling about a tile above its cell.
func _hang_y() -> float:
	return _land_top() - 28.0 - arena.T


## Top edge of the chair once it stands on its cell (matches chair.gd).
func _land_top() -> float:
	return arena.cell_center(target).y + arena.T * 0.4 - arena.T * 1.02


func _physics_process(delta: float) -> void:
	age += delta
	t += delta
	# pendulum swing of the load
	swing_v += (-18.0 * swing - 1.6 * swing_v) * delta + sin(age * 1.3) * 0.15 * delta
	swing += swing_v * delta
	if phase in [ENTER, LOWER, RAISE, RETURN]:
		_creak -= delta
		if _creak <= 0.0:
			_creak = 1.6
			Sfx.play("crane", _rng.randf_range(0.9, 1.1), -6.0)
	var tc: Vector2 = arena.cell_center(target)
	var step := Tuning.CRANE_SPEED * delta
	match phase:
		WARN:
			if t >= WARN_TIME:
				_next(ENTER)
		ENTER:
			if absf(tc.x - hook.x) <= step:
				hook.x = tc.x
				swing_v -= 2.5 * signf(tc.x - _park().x)   # sudden stop sets the chair swinging
				_next(LOWER)
			else:
				hook.x += signf(tc.x - hook.x) * step
		LOWER:
			hook.y = lerpf(_park().y, _hang_y(), smoothstep(0.0, 1.0, t / 0.9))
			if t >= 0.9:
				_next(HOVER)
		HOVER:
			hook.y = _hang_y() + sin(t * 9.0) * 1.5
			if t >= Tuning.CRANE_HOVER:
				_next(DROP)
				chair_v = 60.0
				Sfx.play("pop", 0.6, -4.0)   # clunk of the release
		DROP:
			prongs = minf(1.0, prongs + delta * 6.0)
			chair_v += 1400.0 * delta
			chair_y += chair_v * delta
			if hook.y + 28.0 + chair_y >= _land_top():
				carrying = false
				chair_y = 0.0
				game.land_chair(target)
				_next(RAISE)
		RAISE:
			prongs = maxf(0.0, prongs - delta * 2.0)
			hook.y = maxf(_park().y, hook.y - 220.0 * delta)
			if hook.y <= _park().y:
				_next(RETURN)
		RETURN:
			if absf(_park().x - hook.x) <= step:
				hook = _park()
				carrying = true   # a fresh chair, ready for next time
				_next(PARKED)
				game.crane_returned()
			else:
				hook.x += signf(_park().x - hook.x) * step
	queue_redraw()


func _next(p: int) -> void:
	phase = p
	t = 0.0


func _draw() -> void:
	var T: float = arena.T
	var horror := Mode.horror()
	var metal := Color(0.32, 0.27, 0.27) if horror else Color(0.55, 0.5, 0.55)
	var dark := Color(0.12, 0.08, 0.08) if horror else Color(0.25, 0.2, 0.2)
	var w: float = arena.cols * T
	var ry := _rail_y()
	# the rail with its carnival bulbs
	draw_rect(Rect2(-T * 0.2, ry - 5, w + T * 0.4, 10), dark)
	draw_rect(Rect2(-T * 0.2, ry - 3, w + T * 0.4, 3), metal)
	var n: int = arena.cols
	for i in n:
		var bx := (i + 0.5) * T
		var lit := 0.25
		if phase == WARN:
			# lights chase from the claw toward the drop point, faster and faster
			var from: float = _park().x
			var to: float = arena.cell_center(target).x
			var k: float = clampf(t / WARN_TIME, 0.0, 1.0)
			var chase := fmod(age * (4.0 + 10.0 * k), 1.0)
			var along := (bx - from) / maxf(absf(to - from), 1.0) * signf(to - from + 0.001)
			if along >= -0.05 and along <= 1.05:
				lit = 1.0 if absf(fmod(along - chase + 2.0, 0.34)) < 0.12 else 0.45
		elif phase in [ENTER, LOWER, HOVER, DROP]:
			lit = 0.5 + 0.5 * sin(age * 8.0 + i * 0.8)
		var bulb := Color(1.0, 0.25, 0.15) if horror else Color(1.0, 0.8, 0.3)
		draw_circle(Vector2(bx, ry + 7), 4.0, Color(bulb.r * lit, bulb.g * lit, bulb.b * lit, 1.0))
		if lit > 0.8:
			draw_circle(Vector2(bx, ry + 7), 9.0, Color(bulb.r, bulb.g, bulb.b, 0.25))
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
	# trolley on the rail and the cable down to the claw
	draw_rect(Rect2(Vector2(hook.x - 12, ry - 9), Vector2(24, 12)), metal)
	draw_rect(Rect2(Vector2(hook.x - 12, ry - 9), Vector2(24, 12)), dark, false, 1.5)
	draw_line(Vector2(hook.x, ry), hook + Vector2(0, -10), dark, 3.0)
	if horror:
		for k in 3:
			var y := lerpf(ry, hook.y, 0.3 + k * 0.25)
			draw_circle(Vector2(hook.x + 2, y + fmod(age * 30.0 + k * 20.0, 14.0)), 1.6, Color(0.5, 0.03, 0.07, 0.8))
	# the claw: a domed head and three prongs that open to let go
	draw_circle(hook + Vector2(0, -6), 9.0, metal)
	draw_arc(hook + Vector2(0, -6), 9.0, PI, TAU, 12, dark, 1.5)
	for k in [-1.0, 0.0, 1.0]:
		var spread: float = k * (0.35 + 0.6 * prongs)
		var a: float = PI * 0.5 + spread
		var p1 := hook + Vector2(k * 5.0, -2)
		var p2 := p1 + Vector2.from_angle(a) * 16.0
		var p3 := p2 + Vector2.from_angle(a - k * (0.9 - 0.7 * prongs)) * 10.0
		draw_line(p1, p2, metal, 3.0)
		draw_line(p2, p3, metal, 2.5)
	# the chair in the prongs (or falling out of them)
	if carrying:
		var tex: Texture2D = Assets.tex("objects/chair")
		var cw := T * 1.02
		draw_set_transform(hook + Vector2(0, 4 + chair_y), swing * 0.35, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-cw * 0.5, 6, cw, cw), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
