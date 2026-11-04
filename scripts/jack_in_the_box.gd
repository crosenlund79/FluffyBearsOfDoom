## Horror (and Custom) hazard. Custom art: objects/custom/clown.png (head, mallet,
## box) plus optional animation strips clown_enter / clown_attack / clown_exit /
## clown_hit (see README: "Custom characters"); each falls back to Horror, then
## to the built-in animation.
## Hazard: one wooden pillar carries a striped box with a hatch from
## the start of the round. Every so often it rattles and flashes, the hatch
## creaks open, a pause... the clown rises out, a pause... it cackles
## frantically, locks on to the nearest bear (wherever it is), and lunges on its
## spring neck to hammer it, looming bigger as it arcs toward you and shrinking
## as it comes down. It never changes the grid, so it can't block anyone's way.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")

enum { IDLE, WARN, HATCH, PAUSE1, BURST, PAUSE2, AIM, STRIKE, SLAM, RETRACT }

const WARN_TIME := 1.0
const HATCH_TIME := 0.55
const PAUSE1_TIME := 0.45
const BURST_TIME := 0.35
const PAUSE2_TIME := 0.4
const AIM_TIME := 1.0             # the frantic laughter
const STRIKE_SPEED := 2400.0      # px/s: crosses the whole arena in about a third of a second
const SLAM_TIME := 0.35
const RETRACT_TIME := 0.5

var game
var arena
var pillar := Vector2i.ZERO
var phase := IDLE
var hatch := 0.0                  # 0 shut .. 1 wide open
var zoom := 1.0                   # looms bigger mid-lunge (toward the camera)
var strike_len := 1.0
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


## Start an attack (from IDLE only).
func trigger() -> void:
	if phase == IDLE:
		_next(WARN)


## The Time of Doom shut our pillar: the box moves to another pillar (an
## attack that hadn't really started yet is called off).
func on_cells_closed(shut: Dictionary) -> void:
	if not shut.has(pillar):
		return
	if phase in [WARN, HATCH, PAUSE1]:
		_finish()
	var p = game.pick_clown_pillar()
	if p != null:
		pillar = p
		head_rest = _box_top() + Vector2(0, -arena.T * 1.25)
		if phase == IDLE:
			head = _box_top()


func _finish() -> void:
	phase = IDLE
	t = 0.0
	hatch = 0.0
	zoom = 1.0
	target = null
	head = _box_top()
	game.clown = null


func _next(p: int) -> void:
	phase = p
	t = 0.0


func _physics_process(delta: float) -> void:
	t += delta
	age += delta
	match phase:
		IDLE:
			pass
		WARN:
			var u := clampf(t / WARN_TIME, 0.0, 1.0)
			_rattle -= delta
			if _rattle <= 0.0:
				_rattle = lerpf(0.3, 0.07, u * u)
				Sfx.play("clown_rattle", 0.9 + 0.4 * u + _rng.randf_range(-0.05, 0.05), -4.0)
			if t >= WARN_TIME:
				_next(HATCH)
				Sfx.play("clown_rattle", 0.55, 0.0)   # the hatch creaks open
		HATCH:
			hatch = clampf(t / HATCH_TIME, 0.0, 1.0)
			if t >= HATCH_TIME:
				_next(PAUSE1)
		PAUSE1:
			if t >= PAUSE1_TIME:   # ...something moves in the dark...
				_next(BURST)
				Sfx.play("clown_burst")
				arena.add_shake(5.0)
				game.spawn_dust(_box_top(), 6)
		BURST:
			var k := clampf(t / BURST_TIME, 0.0, 1.0)
			head = _box_top().lerp(head_rest, _overshoot(k))
			if t >= BURST_TIME:
				_next(PAUSE2)
		PAUSE2:
			head = head_rest
			if t >= PAUSE2_TIME:   # it stares... then it laughs
				target = _pick_target()
				if target == null:
					_next(RETRACT)
				else:
					_next(AIM)
					Sfx.play("clown_laugh", _rng.randf_range(0.95, 1.08), 2.0)
		AIM:
			# frantic laughter: shaking all over, bobbing on its spring
			head = head_rest + Vector2(sin(age * 47.0) * 4.0, cos(age * 39.0) * 3.0 - absf(sin(age * 9.0)) * 6.0)
			swing = lerpf(swing, -1.2, 1.0 - exp(-delta * 10.0))   # wind up
			if t >= AIM_TIME:
				lunge_from = head
				strike_len = maxf(head.distance_to(_target_point()), 1.0)
				_next(STRIKE)
				Sfx.play("clown_laugh", 1.25, -2.0)
		STRIKE:
			var goal := _target_point()
			var to := goal - head
			var step := STRIKE_SPEED * delta
			# looms toward the camera at the top of its arc, smaller as it comes down
			var prog := clampf(1.0 - to.length() / strike_len, 0.0, 1.0)
			zoom = 1.0 + 0.9 * sin(prog * PI)
			if to.length() <= step + 6.0:
				head = goal
				_impact()
				_next(SLAM)
			else:
				head += to.normalized() * step
		SLAM:
			head = _target_point()
			zoom = lerpf(zoom, 1.0, 1.0 - exp(-delta * 20.0))
			swing = lerpf(swing, 0.0, 1.0 - exp(-delta * 25.0))
			if t >= SLAM_TIME:
				lunge_from = head
				_next(RETRACT)
		RETRACT:
			var k := clampf(t / RETRACT_TIME, 0.0, 1.0)
			head = lunge_from.lerp(_box_top(), k * k)
			zoom = 1.0
			swing = 0.0
			hatch = 1.0 - clampf((t - RETRACT_TIME * 0.6) / (RETRACT_TIME * 0.4), 0.0, 1.0)
			if t >= RETRACT_TIME:
				_finish()
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
	var u := clampf(t / WARN_TIME, 0.0, 1.0) if phase == WARN else 1.0
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
	# the hatch: a hinged trapdoor on top (rattling when it's about to go)
	var lid_a := -2.2 * hatch + (sin(age * 30.0) * 0.12 * u if phase == WARN else 0.0)
	if hatch > 0.05:
		draw_rect(Rect2(box.position + Vector2(3, -2), Vector2(box.size.x - 6, 6)), Color(0.02, 0.0, 0.0))   # the dark inside
		if phase == PAUSE1:   # eyes in the dark
			for ex in [-5.0, 5.0]:
				draw_circle(Vector2(box.get_center().x + ex, box.position.y + 1), 1.6, Color(1, 0.15, 0.1, 0.6 + 0.4 * sin(age * 20.0)))
	draw_set_transform(box.position + Vector2(0, 2), lid_a, Vector2.ONE)
	draw_rect(Rect2(0, -6, box.size.x, 6), Color(0.35, 0.06, 0.09))
	draw_rect(Rect2(0, -6, box.size.x, 6), Color(0.07, 0.02, 0.02), false, 1.5)
	draw_circle(Vector2(box.size.x - 4, -3), 2.0, Color(0.7, 0.6, 0.4))   # hinge latch
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if phase in [IDLE, WARN, HATCH, PAUSE1]:
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
	var lean := clampf(axis.x / 300.0, -0.6, 0.6)
	# a replacement animation strip for this phase, if one exists (Custom -> Horror)
	var anim := _anim_strip()
	if anim.size() > 0:
		var st: Texture2D = anim[0]
		var fs := T * 2.2 * zoom
		var flip := -1.0 if target != null and target.position.x < head.x else 1.0
		draw_set_transform(head, lean * 0.5, Vector2(flip, 1.0))
		draw_texture_rect_region(st, Rect2(-fs * 0.5, -fs * 0.6, fs, fs), Assets.strip_frame(st, anim[1], anim[2]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_impact(T)
		return
	# ruff collar, head (leaning toward its victim), mallet
	for i in 8:
		var a := TAU * i / 8.0 + age * 2.0
		draw_circle(head + Vector2(0, T * 0.45) + Vector2(cos(a) * 16.0, sin(a) * 6.0), 8.0, Color(0.45, 0.04, 0.08) if i % 2 else Color(0.78, 0.72, 0.62))
	var hs := T * 1.45 * (1.0 + 0.06 * sin(age * 18.0)) * zoom
	draw_set_transform(head, lean + sin(age * 25.0) * 0.08, Vector2.ONE)
	draw_texture_rect_region(tex, Rect2(-hs * 0.5, -hs * 0.5, hs, hs), Assets.region(tex, 3, 0))
	# the mallet in a little gloved fist beside the head
	var hand := Vector2(T * 0.75, T * 0.2) * zoom
	draw_set_transform(head + hand.rotated(lean), lean + swing, Vector2.ONE)
	var ms := T * 1.3 * zoom
	draw_texture_rect_region(tex, Rect2(-ms * 0.5, -ms * 0.95, ms, ms), Assets.region(tex, 3, 1))
	draw_circle(Vector2.ZERO, 8.0, Color(0.9, 0.88, 0.84))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_impact(T)


## The hammer's impact: a replacement effect strip (clown_hit) or the red shock ring.
func _draw_impact(T: float) -> void:
	if phase != SLAM:
		return
	var k := t / SLAM_TIME
	var fx: Texture2D = Assets.strip("objects/clown_hit")
	if fx != null:
		var s := T * 1.8
		draw_texture_rect_region(fx, Rect2(_target_point() + Vector2(-s * 0.5, -s * 0.3), Vector2(s, s)), Assets.strip_frame(fx, k))
		return
	draw_arc(_target_point() + Vector2(0, T * 0.7), T * (0.4 + 1.1 * k), 0.0, TAU, 24, Color(0.85, 0.05, 0.08, 1.0 - k), 4.0 * (1.0 - k) + 1.0)


## [strip, progress 0..1, loop] for the current phase, or [] for the built-in look.
## enter = bursting out and staring (BURST + PAUSE2), attack = cackling, lunging
## and hammering (AIM + STRIKE + SLAM), exit = sinking back into the box.
func _anim_strip() -> Array:
	var rel := ""
	var p := 0.0
	match phase:
		BURST:
			rel = "objects/clown_enter"
			p = t / (BURST_TIME + PAUSE2_TIME)
		PAUSE2:
			rel = "objects/clown_enter"
			p = (BURST_TIME + t) / (BURST_TIME + PAUSE2_TIME)
		AIM:
			rel = "objects/clown_attack"
			p = 0.5 * clampf(t / AIM_TIME, 0.0, 1.0)
		STRIKE:
			rel = "objects/clown_attack"
			p = 0.5 + 0.25 * clampf(1.0 - head.distance_to(_target_point()) / strike_len, 0.0, 1.0)
		SLAM:
			rel = "objects/clown_attack"
			p = 0.75 + 0.25 * clampf(t / SLAM_TIME, 0.0, 1.0)
		RETRACT:
			rel = "objects/clown_exit"
			p = t / RETRACT_TIME
	if rel == "":
		return []
	var st: Texture2D = Assets.strip(rel)
	if st == null:
		return []
	return [st, clampf(p, 0.0, 0.999), false]
