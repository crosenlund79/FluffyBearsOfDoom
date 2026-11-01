## Horror mode: fading bloody footprints left by bears with blood on their feet.
## One node draws all prints (cheap even with hundreds). Purely cosmetic.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")

var prints: Array = []  # [pos: Vector2, angle: float, strength: float, age: float]


func add(pos: Vector2, dir: Vector2, strength: float) -> void:
	prints.append([pos, dir.angle(), strength, 0.0])
	if prints.size() > Tuning.FOOTPRINT_MAX:
		prints.remove_at(0)


func _process(delta: float) -> void:
	if prints.is_empty():
		return
	for p in prints:
		p[3] += delta
	while not prints.is_empty() and prints[0][3] >= Tuning.FOOTPRINT_LIFE:
		prints.remove_at(0)
	queue_redraw()


func _draw() -> void:
	for p in prints:
		var fade: float = 1.0 - clampf(p[3] / Tuning.FOOTPRINT_LIFE, 0.0, 1.0)
		var a: float = 0.75 * p[2] * fade
		if a < 0.02:
			continue
		var col := Color(0.42, 0.02, 0.06, a)
		# a little plush paw print: pad + three toe beans, pointing along the motion
		draw_set_transform(p[0], p[1] + PI * 0.5, Vector2(1.0, 1.25))
		draw_circle(Vector2(0, 1.5), 3.2, col)
		draw_set_transform(p[0], p[1] + PI * 0.5, Vector2.ONE)
		for k in 3:
			draw_circle(Vector2((k - 1) * 2.6, -3.6 + absf(k - 1) * 0.8), 1.25, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
