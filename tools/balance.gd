## Headless balance runner: `godot --headless -- --balance --matches=40
##   --levels=hard,easy,easy,easy --seed=1000 --out=results.jsonl [--round=1]`
## Plays all-AI matches back to back. Match i uses seed (seed + i), spawn
## rotation i % 4 and arena (i / 4) % maps, so every difficulty starts from every
## corner on every arena equally often. One JSON object per match is written.
extends Node

const AiController = preload("res://scripts/ai_controller.gd")
const Maps = preload("res://scripts/arena_maps.gd")
const LEVELS := {"easy": 0, "normal": 1, "hard": 2}
const Personalities = preload("res://scripts/personalities.gd")

var main


func run(m) -> void:
	main = m
	var matches := 40
	var levels := ["hard", "easy", "easy", "easy"]
	var base_seed := 1000
	var out_path := ""
	var round_index := 1
	var scale := 16.0
	var first := 0
	var names: Array = []   # --names=all: the ten personalities, four per match, rotating
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--matches="):
			matches = int(a.get_slice("=", 1))
		elif a.begins_with("--levels="):
			levels = Array(a.get_slice("=", 1).split(","))
		elif a.begins_with("--seed="):
			base_seed = int(a.get_slice("=", 1))
		elif a.begins_with("--out="):
			out_path = a.get_slice("=", 1)
		elif a.begins_with("--round="):
			round_index = int(a.get_slice("=", 1))
		elif a.begins_with("--speed="):
			scale = float(a.get_slice("=", 1))
		elif a.begins_with("--names="):
			names = Personalities.names()
		elif a.begins_with("--first="):
			first = int(a.get_slice("=", 1))   # match index to start at (for parallel shards)
	Settings.human_count = 0
	Settings.round_time_index = round_index
	Settings.instant_win = Tuning_default()
	Engine.physics_ticks_per_second = int(60 * scale)
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = scale
	AudioServer.set_bus_mute(0, true)
	var f: FileAccess = null
	if out_path != "":
		f = FileAccess.open(out_path, FileAccess.WRITE)
	var t0 := Time.get_ticks_msec()
	for i in range(first, first + matches):
		Settings.match_seed = base_seed + i
		Settings.spawn_rotation = i % 4
		Settings.arena_index = (i / 4) % Maps.MAPS.size()
		if not names.is_empty():
			# four different personalities per match; every one meets every other over time
			var r := RandomNumberGenerator.new()
			r.seed = base_seed + i
			var pool := names.duplicate()
			for k in range(pool.size() - 1, 0, -1):
				var j := r.randi() % (k + 1)
				var tmp = pool[k]
				pool[k] = pool[j]
				pool[j] = tmp
			Settings.roster_override = pool.slice(0, 4).map(func(n): return Personalities.roster_entry(n, levels[0]))
		main.start_game()
		var g = main.current
		for k in g.bears.size():
			g.bears[k].controller = AiController.new(g.bears[k], g, LEVELS[levels[k]])
		g.start_round()
		var frames := 0
		var spikes := 0
		var last := Time.get_ticks_usec()
		while g.state != g.State.ENDED:
			await get_tree().physics_frame
			frames += 1
		var rec := _record(g, i, levels)
		rec["wall_s"] = 0.0
		var line := JSON.stringify(rec)
		if f != null:
			f.store_line(line)
			f.flush()
		print("MATCH ", line)
	print("BALANCE DONE %d matches in %.1f s" % [matches, (Time.get_ticks_msec() - t0) / 1000.0])
	if f != null:
		f.close()
	get_tree().quit()


func Tuning_default() -> float:
	return preload("res://scripts/tuning.gd").INSTANT_WIN_FLUFF


func _record(g, i: int, levels: Array) -> Dictionary:
	var ranking: Array = g.final_ranking()
	var instant := false
	for b in g.bears:
		if Settings.instant_win > 0.0 and b.fluff >= Settings.instant_win:
			instant = true
	var bears := []
	for k in g.bears.size():
		var b = g.bears[k]
		bears.append({
			"level": levels[k], "name": b.bear_name, "kicks": b.kicks_made, "fluff": roundi(b.fluff), "rank": ranking.find(b) + 1,
			"stole": roundi(b.stolen_total), "stunned": b.times_stunned, "bombs": b.bombs_placed,
			"hits": b.bomb_hits, "self_hits": b.self_hits, "pickups": b.pickups,
			"out": b.eliminated, "out_at": snappedf(b.eliminated_at, 0.1),
		})
	return {"i": i, "seed": Settings.match_seed, "arena": Settings.arena_index, "rot": Settings.spawn_rotation,
		"winner": g.bears.find(ranking[0]), "winner_level": levels[g.bears.find(ranking[0])],
		"instant": instant, "time": snappedf(g.round_duration - g.time_left, 0.1), "bears": bears}
