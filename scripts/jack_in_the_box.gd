## Horror-only hazard: a wooden pillar starts to rattle and flash (faster and
## faster), a jack-in-the-box clown bursts out of it cackling, locks on to the
## nearest bear (wherever it is), lunges on its spring neck and hammers it.
## It never changes the grid, so it can't block anyone's way.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")

enum { WARN, BURST, AIM, STRIKE, SLAM, RETRACT }

const BURST_TIME := 0.35
const AIM_TIME := 0.6
const STRIKE_SPEED := 2400.0      # px/s: crosses the whole arena in about a third of a second
const SLAM_TIME := 0.35
const RETRACT_TIME := 0.5

var game
var arena
var pillar := Vector2i.ZERO
var phase := WARN
var t := 0.0
var age := 0.0
var done := false
var target = null
var head := Vector2.ZERO          # head position (arena-local)
var head_rest := Vector2.ZERO
var lunge_from := Vector2.ZERO
var swing := 0.0                  # mallet angle
var _rattle := 0.0
var _rng := RandomNumberGenerator.new()


func setup(g, cell: Vector2i) -> void:
	game = g
	arena = g.arena
	pillar = cell
	_rng.randomize()
	head_rest = _box_top() + Vector2(0, -arena.T * 1.25)
	head = _box_top()


func _box_top() -> Vector2:
	return arena.cell_center(pillar) + Vector2(0, -arena.T * 0.62)


## Time of Doom shut our pillar while we were still rattling: the box is gone.
func on_cells_closed(shut: Dictionary) -> void:
	if shut.has(pillar) and phase == WARN:
		_finish()


func _finish() -> void:
	done = true
	game.clown = null
	queue_free()


func _next(p: int) -> void:
	phase = p
	t = 0.0


func _physics_process(delta: float) -> void:
	if done:
		return
	t += delta
	age += delta
	match phase:
		WARN:
			var u := clampf(t / Tuning.CLOWN_WARN, 0.0, 1.0)
			_rattle -= delta
			if _rattle <= 0.0:
				_rattle = lerpf(0.35, 0.06, u * u)
				Sfx.play("clown_rattle", 0.9 + 0.4 * u + _rng.randf_range(-0.05, 0.05), -4.0)
			if t >= Tuning.CLOWN_WARN:
				_next(BURST)
				Sfx.play("clown_burst")
				Sfx.play("clown_laugh", _rng.randf_range(0.95, 1.08), 2.0)
				arena.add_shake(5.0)
				game.spawn_dust(_box_top(), 6)
		BURST:
			var k := clampf(t / BURST_TIME, 0.0, 1.0)
			head = _box_top().lerp(head_rest, _overshoot(k))
			if t >= BURST_TIME:
				target = _pick_target()
				_next(AIM if target != null else RETRACT)
		AIM:
			head = head_rest + Vector2(sin(age * 40.0), cos(age * 33.0)) * 2.0   # shaking with glee
			swing = lerpf(swing, -1.2, 1.0 - exp(-delta * 10.0))                 # wind up
			if t >= AIM_TIME:
				lunge_from = head
				_next(STRIKE)
				Sfx.play("clown_laugh", 1.25, -2.0)
		STRIKE:
			var goal := _target_point()
			var to := goal - head
			var step := STRIKE_SPEED * delta
			if to.length() <= step + 6.0:
				head = goal
				_impact()
				_next(SLAM)
			else:
				head += to.normalized() * step
		SLAM:
			head = _target_point()
			swing = lerpf(swing, 0.0, 1.0 - exp(-delta * 25.0))
			if t >= SLAM_TIME:
				lunge_from = head
				_next(RETRACT)
		RETRACT:
			var k := clampf(t / RETRACT_TIME, 0.0, 1.0)
			head = lunge_from.lerp(_box_top(), k * k)
			swing = 0.0
			if t >= RETRACT_TIME:
				_finish()
				return
	queue_redraw()


static func _overshoot(k: float) -> float:
	return 1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0)


## The nearest bear to the box, however far away; awake and mortal ones first.
func _pick_target():
	var best = null
	var best_d := INF
	for pass_i in 2:
		for b in game.bears:
			if b.eliminated:
				continue
			if pass_i == 0 and (b.is_stunned() or b.immortal_t > 0.0):
				continue
			var d: float = b.position.distance_to(arena.cell_center(pillar))
			if d < best_d:
				best_d = d
				best = b
		if best != null:
			return best
	return best


func _target_point() -> Vector2:
	return target.position + Vector2(0, -arena.T * 0.75)


func _impact() -> void:
	swing = 1.1
	game.clown_hit(target, head)


# --- drawing ------------------------------------------------------------------------

func _draw() -> void:
	var T: float = arena.T
	var tex: Texture2D = Assets.tex("objects/clown")
	var pc: Vector2 = arena.cell_center(pillar)
	var u := clampf(t / Tuning.CLOWN_WARN, 0.0, 1.0) if phase == WARN else 1.0
	# the pillar flashes blood-red, faster and faster, and the box rattles
	if phase == WARN:
		var freq := lerpf(2.0, 16.0, u * u)
		var pulse := 0.5 + 0.5 * sin(age * TAU * freq * 0.5)
		var r := Rect2(Vector2(pillar) * T - Vector2(0, 6), Vector2(T, T + 6))
		draw_rect(r.grow(4.0 + 4.0 * pulse * u), Color(0.75, 0.0, 0.05, 0.15 + 0.35 * pulse))
		draw_rect(r, Color(1.0, 0.1, 0.1, 0.25 + 0.45 * pulse * (0.4 + 0.6 * u)))
		draw_rect(r.grow(2.0), Color(0.1, 0.0, 0.0, 0.8), false, 2.0)
	var jitter := Vector2.ZERO
	if phase == WARN:
		jitter = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * (0.5 + 3.0 * u * u)
	# the box on top of the pillar
	var box := Rect2(pc + Vector2(-T * 0.42, -T * 0.95) + jitter, Vector2(T * 0.84, T * 0.7))
	draw_texture_rect_region(tex, box, Assets.region(tex, 3, 2))
	var lid_open := phase != WARN
	var lid_a := -2.2 if lid_open else (sin(age * 30.0) * 0.12 * u)
	draw_set_transform(box.position + Vector2(0, 2), lid_a, Vector2.ONE)
	draw_rect(Rect2(0, -6, box.size.x, 6), Color(0.35, 0.06, 0.09))
	draw_rect(Rect2(0, -6, box.size.x, 6), Color(0.07, 0.02, 0.02), false, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if phase == WARN:
		return
	# telegraph: a shaking dashed line and a crosshair on the victim
	if phase == AIM and target != null:
		var tp := _target_point()
		var blink := 0.5 + 0.5 * sin(age * 30.0)
		var col := Color(0.9, 0.05, 0.1, 0.5 + 0.5 * blink)
		draw_dashed_line(head, tp, col, 2.5, 9.0)
		var foot: Vector2 = target.position + Vector2(0, 8)
		draw_set_transform(foot, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, T * 0.55, 0.0, TAU, 28, col, 3.0)
		draw_arc(Vector2.ZERO, T * 0.3, 0.0, TAU, 20, col, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var bang := tp + Vector2(0, -T * 0.9)
		draw_circle(bang, 10.0, Color(0.1, 0.02, 0.03, 0.9))
		draw_string(ThemeDB.fallback_font, bang + Vector2(-4, 7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.2, 0.2))
	# the spring neck: a coil stretched from the box to the head
	var base := _box_top()
	var axis := head - base
	var n := 14
	var side := Vector2(-axis.y, axis.x).normalized() if axis.length() > 1.0 else Vector2.RIGHT
	var pts := PackedVector2Array()
	for i in n + 1:
		var k := float(i) / n
		var w := 7.0 * (1.0 if i % 2 == 0 else -1.0) * (0.0 if i == 0 or i == n else 1.0)
		pts.append(base + axis * k + side * w)
	draw_polyline(pts, Color(0.12, 0.1, 0.1), 6.0)
	draw_polyline(pts, Color(0.72, 0.68, 0.64), 3.0)
	# ruff collar, head (leaning toward its victim), mallet
	var lean := clampf(axis.x / 300.0, -0.6, 0.6)
	for i in 8:
		var a := TAU * i / 8.0 + age * 2.0
		draw_circle(head + Vector2(0, T * 0.45) + Vector2(cos(a) * 16.0, sin(a) * 6.0), 8.0, Color(0.45, 0.04, 0.08) if i % 2 else Color(0.78, 0.72, 0.62))
	var hs := T * 1.45 * (1.0 + 0.06 * sin(age * 18.0))
	draw_set_transform(head, lean + sin(age * 25.0) * 0.08, Vector2.ONE)
	draw_texture_rect_region(tex, Rect2(-hs * 0.5, -hs * 0.5, hs, hs), Assets.region(tex, 3, 0))
	# the mallet in a little gloved fist beside the head
	var hand := Vector2(T * 0.75, T * 0.2)
	draw_set_transform(head + hand.rotated(lean), lean + swing, Vector2.ONE)
	var ms := T * 1.3
	draw_texture_rect_region(tex, Rect2(-ms * 0.5, -ms * 0.95, ms, ms), Assets.region(tex, 3, 1))
	draw_circle(Vector2.ZERO, 8.0, Color(0.9, 0.88, 0.84))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# impact burst
	if phase == SLAM:
		var k := t / SLAM_TIME
		draw_arc(_target_point() + Vector2(0, T * 0.7), T * (0.4 + 1.1 * k), 0.0, TAU, 24, Color(0.85, 0.05, 0.08, 1.0 - k), 4.0 * (1.0 - k) + 1.0)
