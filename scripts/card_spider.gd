## A big decorative spider with glowing red eyes that crawls around the ranking
## card stacks (and along the top edge of the screen to the other side). Now and
## then it stops and shoots a web strand between cards, leaving a cobweb that
## fades away. It is drawn only inside the card columns and the strip above
## them, never over the arena, and it has no effect on gameplay.
extends Control

const UiStyle = preload("res://scripts/ui_style.gd")

const SPEED := 70.0
const MAX_WEBS := 6
const WEB_LIFE := 9.0

var columns: Array = []       # [left Rect2, right Rect2]: where it may roam and spin
var top_y := 16.0             # the crossing strip above the arena
var pos := Vector2.ZERO
var heading := Vector2.RIGHT
var path: Array = []
var pause_t := 0.0
var t := 0.0
var side := 0                 # which column it is in (0 left, 1 right)
var webs: Array = []          # [{from, to, age, grow}]
var _rng := RandomNumberGenerator.new()


func setup(left: Rect2, right: Rect2, strip_y: float) -> void:
	columns = [left, right]
	top_y = strip_y
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	side = _rng.randi() % 2
	pos = _corner(side, 0)
	_plan()


## Corners of a column, clockwise from top-left.
func _corner(col: int, i: int) -> Vector2:
	var r: Rect2 = columns[col]
	return [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)][i % 4]


## Next stretch: a lap (or part of one) around its column's edge, cutting across
## the cards now and then; sometimes over the top to the other column.
func _plan() -> void:
	path.clear()
	if _rng.randf() < 0.25:
		var other := 1 - side
		path.append(Vector2(pos.x, top_y))
		path.append(Vector2(columns[other].get_center().x, top_y))
		path.append(_corner(other, 0 if other == 0 else 1))
		side = other
		return
	var start := _rng.randi() % 4
	for i in _rng.randi_range(2, 5):
		var p: Vector2 = _corner(side, start + i)
		if _rng.randf() < 0.35:   # wander across the cards on the way
			var r: Rect2 = columns[side]
			p = Vector2(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.end.y))
		path.append(p)


func _process(delta: float) -> void:
	t += delta
	for w in webs:
		w["age"] += delta
	webs = webs.filter(func(w): return w["age"] < WEB_LIFE)
	if pause_t > 0.0:
		pause_t -= delta
	elif path.is_empty():
		_plan()
	else:
		var goal: Vector2 = path[0]
		var to := goal - pos
		var step := SPEED * delta
		if to.length() <= step:
			pos = goal
			path.pop_front()
			if _rng.randf() < 0.35:
				pause_t = _rng.randf_range(0.6, 1.6)
				if _rng.randf() < 0.6:
					_shoot_web()
		else:
			heading = heading.lerp(to.normalized(), 1.0 - exp(-delta * 8.0)).normalized()
			pos += to.normalized() * step
	queue_redraw()


## A strand from the spider to another spot in the same column, where a little
## cobweb appears. Both ends stay inside the column, so it never crosses the arena.
func _shoot_web() -> void:
	var col := -1
	for i in columns.size():
		if columns[i].grow(2.0).has_point(pos):
			col = i
	if col < 0:
		return
	var r: Rect2 = columns[col]
	var to := Vector2(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.end.y))
	webs.append({"from": pos, "to": to, "age": 0.0, "size": _rng.randf_range(14.0, 26.0), "rot": _rng.randf() * TAU})
	if webs.size() > MAX_WEBS:
		webs.remove_at(0)
	Sfx.play("squeak", 2.2, -18.0)


func _draw() -> void:
	# webs first (under the spider)
	for w in webs:
		var a: float = 1.0 - clampf((w["age"] - WEB_LIFE + 2.0) / 2.0, 0.0, 1.0)
		var shoot := clampf(w["age"] / 0.25, 0.0, 1.0)
		var col := Color(0.92, 0.92, 0.95, 0.55 * a)
		var from: Vector2 = w["from"]
		var to: Vector2 = from.lerp(w["to"], shoot)
		draw_line(from, to, col, 1.0)
		if shoot >= 1.0:
			_cobweb(w["to"], w["size"], w["rot"], col)
	_draw_spider(pos, heading)


func _cobweb(c: Vector2, s: float, rot: float, col: Color) -> void:
	var spokes := 7
	var pts := []
	for i in spokes:
		var d := Vector2.from_angle(rot + i * TAU / spokes)
		pts.append(d)
		draw_line(c, c + d * s, col, 1.0)
	for ring in [0.35, 0.65, 1.0]:
		for i in spokes:
			draw_line(c + pts[i] * s * ring, c + pts[(i + 1) % spokes] * s * ring, col, 1.0)


func _draw_spider(p: Vector2, dir: Vector2) -> void:
	var ang := dir.angle()
	var walking := pause_t <= 0.0 and not path.is_empty()
	var body := Color(0.07, 0.04, 0.05)
	var hair := Color(0.2, 0.12, 0.12)
	draw_set_transform(p, ang, Vector2.ONE)
	# eight legs, two sets stepping in turn
	for side_s in [-1.0, 1.0]:
		for i in 4:
			var phase := t * 12.0 + i * 1.3 + (0.0 if side_s > 0.0 else PI)
			var swing := sin(phase) * (0.35 if walking else 0.05)
			var base := Vector2(-2.0 + i * 3.0, side_s * 5.0)
			var a := (-0.9 + i * 0.6) + swing
			var knee := base + Vector2(cos(a) * 14.0, side_s * (12.0 + absf(sin(a)) * 4.0))
			var foot := knee + Vector2(cos(a) * 12.0 + 4.0, side_s * 10.0)
			draw_line(base, knee, body, 3.0)
			draw_line(knee, foot, body, 2.2)
	# abdomen with a red hourglass, then head
	draw_set_transform(p + Vector2(-13, 0).rotated(ang), ang, Vector2(1.25, 1.0))
	draw_circle(Vector2.ZERO, 11.0, body)
	draw_arc(Vector2.ZERO, 11.0, 0, TAU, 20, hair, 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -3), Vector2(4, -3), Vector2(0, 0), Vector2(4, 3), Vector2(-4, 3), Vector2(0, 0)]), Color(0.7, 0.05, 0.05))
	draw_set_transform(p, ang, Vector2.ONE)
	draw_circle(Vector2(3, 0), 7.5, body)
	# glowing red eyes (a cluster of eight)
	var glow := 0.65 + 0.35 * sin(t * 5.0)
	for e in [Vector2(8, -3), Vector2(8, 3), Vector2(6, -5), Vector2(6, 5), Vector2(9.5, -1.2), Vector2(9.5, 1.2), Vector2(5, -2), Vector2(5, 2)]:
		draw_circle(e, 2.4, Color(1.0, 0.1, 0.05, 0.25 * glow))
		draw_circle(e, 1.1, Color(1.0, 0.25 * glow, 0.15, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
