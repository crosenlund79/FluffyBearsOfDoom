## Visual of a blast: soft puffs of stuffing instead of fire.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")

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
	var fade := 1.0 - clampf((k - 0.75) / 0.5, 0.0, 1.0)
	var a := fade
	for seg in segments:
		var wob := 1.0 + 0.08 * sin(age * 30.0 + seg["pos"].x * 0.1 + seg["pos"].y * 0.07)
		var sc := grow * wob * (0.85 + 0.25 * fade)
		draw_set_transform(seg["pos"], seg["rot"], Vector2(1.0, sc) if seg["kind"] != 0 else Vector2(sc, sc))
		var size := T * (1.25 if seg["kind"] == 0 else 1.1)
		draw_texture_rect_region(tex, Rect2(-size * 0.5, -size * 0.5, size, size), Assets.region(tex, Assets.EFFECT_CELLS, seg["kind"]), Color(1.0, 0.86, 0.84, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
