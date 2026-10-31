## A blast of confetti. Each covered cell gets a pastel hazard tint, a
## confetti burst sprite and fluttering paper pieces.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const CONFETTI := [Color("f2a7b5"), Color("a7c8e8"), Color("f5dc8a"), Color("a8dcc0"), Color("c9b2e3"), Color("f6c1a0")]

# Each segment: {"pos": Vector2, "kind": 0 centre / 1 arm / 2 end, "rot": float}
var segments: Array = []
var age := 0.0
var tex: Texture2D
var T := Tuning.TILE


func _ready() -> void:
	tex = Assets.tex("effects/effects")


func _process(delta: float) -> void:
	age += delta
	if age > Tuning.FLAME_TIME + 0.3:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := age / Tuning.FLAME_TIME
	var grow := clampf(k * 6.0, 0.0, 1.0)
	var fade := 1.0 - clampf((k - 0.8) / 0.5, 0.0, 1.0)
	for si in segments.size():
		var seg: Dictionary = segments[si]
		var p: Vector2 = seg["pos"]
		# readable hazard area
		var hz: Color = CONFETTI[si % CONFETTI.size()]
		draw_rect(Rect2(p - Vector2(T, T) * 0.5, Vector2(T, T)).grow(-2), Color(hz.r, hz.g, hz.b, 0.4 * fade))
		var wob := 1.0 + 0.08 * sin(age * 30.0 + p.x * 0.1 + p.y * 0.07)
		var sc := grow * wob
		draw_set_transform(p, seg["rot"], Vector2(1.0, sc) if seg["kind"] != 0 else Vector2(sc, sc))
		var size := T * (1.3 if seg["kind"] == 0 else 1.1)
		draw_texture_rect_region(tex, Rect2(-size * 0.5, -size * 0.5, size, size), Assets.region(tex, Assets.EFFECT_CELLS, seg["kind"]), Color(1, 1, 1, fade))
		# fluttering paper pieces
		for i in 6:
			var h := float((si * 7 + i * 13) % 17) / 17.0
			var h2 := float((si * 11 + i * 5) % 13) / 13.0
			var start := Vector2((h - 0.5) * T * 0.8, (h2 - 0.5) * T * 0.6)
			var off := start + Vector2(sin(age * 9.0 + i) * 4.0, age * 40.0 * (0.5 + h))
			var c: Color = CONFETTI[(si + i) % CONFETTI.size()]
			draw_set_transform(p + off, age * (6.0 + i * 2.0) + h * 6.0, Vector2(1.0, 0.5 + 0.5 * absf(sin(age * 12.0 + i))))
			draw_rect(Rect2(-3, -2, 6, 4), Color(c.r, c.g, c.b, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
