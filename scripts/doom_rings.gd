## Time of Doom: from 60% of the round the arena closes in from the edge, one
## tile ring at a time (four rings, evenly staged up to 95%). Each ring flashes
## first (faster and faster, with ticking), then slams shut: its cells become
## permanently solid. Game.doom_close() clears the cells and shoves bears inward.
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Mode = preload("res://scripts/mode_theme.gd")

var game
var arena
var duration := 150.0
var warn_time := 4.0
var stages: Array = []     # [{ring, warn_at, close_at, state (0 pending, 1 warning, 2 closed), cells}]
var elapsed := 0.0
var t := 0.0
var _tick := 0.0
var slams := {}            # Vector2i -> seconds since it slammed shut (drop-in animation)


func setup(g, round_duration: float) -> void:
	game = g
	arena = g.arena
	duration = round_duration
	warn_time = minf(Tuning.DOOM_WARN, round_duration * 0.04)
	var n: int = Tuning.DOOM_RINGS
	for i in n:
		var f: float = Tuning.DOOM_START + (Tuning.DOOM_LAST - Tuning.DOOM_START) * (float(i) / maxf(n - 1, 1))
		stages.append({"ring": i + 1, "warn_at": f * duration, "close_at": f * duration + warn_time,
			"state": 0, "cells": ring_cells(i + 1)})


## Ring index of a cell: 0 = the border, 1 = the outermost playable ring, ...
func ring_of(c: Vector2i) -> int:
	return mini(mini(c.x, c.y), mini(arena.cols - 1 - c.x, arena.rows - 1 - c.y))


func ring_cells(k: int) -> Array:
	var out := []
	for y in arena.rows:
		for x in arena.cols:
			if ring_of(Vector2i(x, y)) == k:
				out.append(Vector2i(x, y))
	return out


## Seconds until `c` closes (INF if never / already closed).
func time_until_close(c: Vector2i) -> float:
	for st in stages:
		if st["state"] < 2 and st["ring"] == ring_of(c):
			return st["close_at"] - elapsed
	return INF


## Cells of rings currently flashing -> seconds left (for the AI's danger map).
func warning_cells() -> Dictionary:
	var d := {}
	for st in stages:
		if st["state"] == 1:
			for c in st["cells"]:
				d[c] = maxf(st["close_at"] - elapsed, 0.0)
	return d


func warning_active() -> bool:
	for st in stages:
		if st["state"] == 1:
			return true
	return false


## Called every physics tick while the round is running.
func update(delta: float, round_elapsed: float) -> void:
	elapsed = round_elapsed
	for st in stages:
		if st["state"] == 0 and elapsed >= st["warn_at"]:
			st["state"] = 1
			_tick = 0.0
			var first: bool = st["ring"] == 1
			if first:
				game.hud.banner("Time of Doom!" if not Mode.horror() else "The walls are hungry...", 1.8)
			else:
				game.hud.toast("The arena closes in!", Color(0.85, 0.35, 0.3))
			Sfx.play("doom_warn")
		if st["state"] == 1:
			var left: float = st["close_at"] - elapsed
			_tick -= delta
			if _tick <= 0.0:
				_tick = lerpf(0.12, 0.5, clampf(left / warn_time, 0.0, 1.0))
				Sfx.play("clock_tick", 1.0 + (1.0 - left / warn_time) * 0.5, -6.0)
			if left <= 0.0:
				st["state"] = 2
				for c in st["cells"]:
					slams[c] = 0.0
				game.doom_close(st["cells"])


func _process(delta: float) -> void:
	t += delta
	for c in slams.keys():
		slams[c] += delta
		if slams[c] > 0.6:
			slams.erase(c)
	queue_redraw()


func _draw() -> void:
	var T: float = arena.T
	var horror := Mode.horror()
	# flashing warning on the ring about to close, faster as time runs out
	for st in stages:
		if st["state"] != 1:
			continue
		var left: float = st["close_at"] - elapsed
		var u := 1.0 - clampf(left / warn_time, 0.0, 1.0)
		var freq := lerpf(3.0, 14.0, u * u)
		var pulse := 0.5 + 0.5 * sin(t * TAU * freq * 0.5)
		var col := Color(0.75, 0.05, 0.08) if horror else Color(0.95, 0.42, 0.35)
		for c in st["cells"]:
			if arena.cell_type(c) == arena.BORDER:
				continue
			var r := Rect2(Vector2(c) * T, Vector2(T, T))
			draw_rect(r.grow(-2), Color(col.r, col.g, col.b, 0.18 + 0.32 * pulse * (0.5 + 0.5 * u)))
			arena._stitch(r.grow(-5), Color(col.r, col.g, col.b, 0.5 + 0.5 * pulse))
			# little inward arrows so it reads as "get out, go that way"
			if fmod(float(c.x * 7 + c.y * 3), 3.0) < 1.0:
				var inward := (Vector2(arena.cols, arena.rows) * 0.5 - (Vector2(c) + Vector2(0.5, 0.5)))
				var d := Vector2(signf(inward.x), 0) if absf(inward.x) > absf(inward.y) else Vector2(0, signf(inward.y))
				var ctr := r.get_center() + d * (4.0 + 4.0 * pulse)
				var side := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([ctr + d * 8.0, ctr - d * 4.0 + side * 7.0, ctr - d * 4.0 - side * 7.0]),
					Color(1, 1, 1, 0.55 + 0.4 * pulse) if not horror else Color(0.9, 0.75, 0.7, 0.5 + 0.4 * pulse))
	# fresh closures: a bright flash and a puff ring where the tile slammed down
	for c in slams:
		var k: float = slams[c] / 0.6
		var r := Rect2(Vector2(c) * T, Vector2(T, T))
		var flash := Color(1, 0.95, 0.85, 0.6 * (1.0 - k)) if not horror else Color(0.6, 0.0, 0.05, 0.6 * (1.0 - k))
		draw_rect(r.grow(4.0 * k), flash, false, 3.0 * (1.0 - k) + 1.0)
