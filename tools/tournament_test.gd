## `godot --headless -- --tournament-test`: plays whole Tournaments of Doom at 8x
## through the real menus/flow (an AI stands in for the human), simulates an
## application restart between rounds, checks the leaderboards' maths and
## eligibility rules, and runs an AI spectator match. The player's own saved
## settings, tournament and leaderboards are backed up and restored.
extends Node

const Tournament = preload("res://scripts/tournament.gd")
const Personalities = preload("res://scripts/personalities.gd")
const AiController = preload("res://scripts/ai_controller.gd")

var main
var fails := 0
var seen := {}            # opponent -> rounds played
var persona_stats := {}   # name -> {bombs, stole, kicks, pickups, self, rounds}
var max_bears := 0
var commentary_lines := 0
var place_anim_ok := 0
var place_anim_bad := 0
var _kicks := {}


func run(m) -> void:
	main = m
	var files := ["user://tournament.cfg", "user://leaderboards.cfg", Settings.SAVE_PATH]
	var backup := {}
	for f in files:
		backup[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
	Tournament.clear_saved()
	if FileAccess.file_exists("user://leaderboards.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://leaderboards.cfg"))
	await _checks()
	for f in files:
		if backup[f] == null:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		else:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(backup[f])
			fa.close()
	main.set_speed(1.0)
	print("TOURNAMENT TEST: %s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit()


func _checks() -> void:
	# --- stuffing accounting: losses stick, gains are separate
	main.start_game()
	await get_tree().process_frame
	var b = main.current.bears[1]
	b.fluff = 100.0
	var l0: float = b.fluff_lost
	var g0: float = b.fluff_gained
	b.fluff = 70.0
	b.fluff = 90.0
	b.fluff = 60.0
	var lost: float = b.fluff_lost - l0
	var gained: float = b.fluff_gained - g0
	_expect(is_equal_approx(lost, 60.0) and is_equal_approx(gained, 20.0), "stuffing losses are booked once each and never erased by gains (100->70->90->60: lost %d, gained %d)" % [roundi(lost), roundi(gained)])

	# --- whole tournaments at 8x
	var level := "easy"
	var runs := 0
	var won_run = null
	while runs < 4 and won_run == null:
		runs += 1
		main.start_tournament(level, "Tester")
		var guard := 0
		while main.tournament.status == "active" and guard < 30:
			guard += 1
			await _play_round()
			# simulate quitting and restarting the application between rounds
			var before: Dictionary = {"r": main.tournament.round_index, "l": main.tournament.lives, "h": main.tournament.history.size(), "t": main.tournament.total_time}
			var loaded = Tournament.load_saved()
			var same: bool = loaded != null and loaded.round_index == before["r"] and loaded.lives == before["l"] and loaded.history.size() == before["h"] and is_equal_approx(loaded.total_time, before["t"])
			if not same:
				_expect(false, "progress survives a restart (round %d)" % before["r"])
			if main.tournament.status == "active":
				main.continue_tournament(loaded)
		print("   run %d: %s after %d rounds played, %d lives left, time %s, lost %d" % [runs, main.tournament.status, main.tournament.attempts, main.tournament.lives, Tournament.fmt_time(main.tournament.total_time), roundi(main.tournament.total_lost)])
		if main.tournament.status == "won":
			won_run = main.tournament
		elif main.tournament.status == "failed":
			_expect(main.tournament.lives == 0, "a failed run has no lives left and ends clearly")
	_expect(won_run != null, "a full 10-round tournament is completed (%d runs)" % runs)
	_expect(max_bears == 4, "every match has exactly four bears")
	var all: bool = Personalities.names().all(func(n): return seen.get(n, 0) >= 3)
	_expect(all, "every one of the ten opponents appears (rounds each: %s)" % [seen])
	_expect(commentary_lines > 20, "commentary reacted during the tournament (%d lines)" % commentary_lines)
	_expect(place_anim_ok > 20 and place_anim_bad == 0, "bomb placement pose + drop for human and AI bears (%d ok, %d bad)" % [place_anim_ok, place_anim_bad])
	if won_run != null:
		_expect(won_run.round_index == 10 and won_run.rounds_won() == 10, "ten rounds won in order")
		var rec: Dictionary = main.submit_result(won_run)
		_expect(not rec["eligible"] and Tournament.boards(level)["fastest"].is_empty(), "accelerated / developer runs never reach the leaderboards")
		_expect(not won_run.valid, "the run is marked invalid (sped-up clock)")
		_expect(Tournament.load_saved() == null, "a finished tournament clears its autosave")
	# personalities in numbers
	print("   persona stats per round (bombs, stolen, kicks, pickups, self-stuns):")
	for n in persona_stats:
		var s: Dictionary = persona_stats[n]
		var r: float = maxf(1.0, s["rounds"])
		print("     %-10s %5.1f %6.1f %4.1f %4.1f %4.1f" % [n, s["bombs"] / r, s["stole"] / r, s["kicks"] / r, s["pickups"] / r, s["self"] / r])

	# --- forfeits: leaving (or the app closing) mid-round costs a life
	var f = Tournament.new_run("normal", "Quitter")
	f.prepare_round()
	var l0f: int = f.lives
	var back = Tournament.load_saved()
	_expect(back != null and back.lives == l0f - 1 and back.history.size() == 1, "a round left unfinished counts as lost after a restart")
	Tournament.clear_saved()

	# --- leaderboards: maths, tie-break, top 10, persistence, eligibility
	Settings.dev_flags = false
	var cases := [[600.0, 50.0], [540.0, 80.0], [700.0, 50.0], [500.0, 120.0], [650.0, 30.0]]
	for i in cases.size():
		var r = Tournament.new_run("hard", "P%d" % i)
		r.status = "won"
		r.valid = true
		r.total_time = cases[i][0]
		r.total_lost = cases[i][1]
		r.submit()
	var bad = Tournament.new_run("hard", "Cheat")
	bad.status = "won"
	bad.valid = false
	bad.total_time = 1.0
	bad.total_lost = 0.0
	bad.submit()
	var unfinished = Tournament.new_run("hard", "Quit")
	unfinished.status = "failed"
	unfinished.total_time = 1.0
	unfinished.submit()
	var bd: Dictionary = Tournament.boards("hard")
	var fast: Array = bd["fastest"].map(func(e): return e["name"])
	var least: Array = bd["least_lost"].map(func(e): return e["name"])
	_expect(fast == ["P3", "P1", "P0", "P4", "P2"], "fastest board: lowest total time first (%s)" % [fast])
	_expect(least == ["P4", "P0", "P2", "P1", "P3"], "least-lost board: lowest loss, ties to the faster time (%s)" % [least])
	_expect(not "Cheat" in fast and not "Quit" in fast, "invalid or unfinished runs are rejected")
	for i in 12:
		var r = Tournament.new_run("hard", "Z%d" % i)
		r.status = "won"
		r.total_time = 800.0 + i
		r.total_lost = 200.0 + i
		r.submit()
	bd = Tournament.boards("hard")
	_expect(bd["fastest"].size() == 10 and bd["least_lost"].size() == 10, "only the top 10 are kept")
	_expect(Tournament.boards("normal")["fastest"].is_empty(), "difficulties keep separate boards")
	var pb = Tournament.new_run("hard", "P3")
	pb.status = "won"
	pb.total_time = 400.0
	pb.total_lost = 500.0
	var res: Dictionary = pb.submit()
	_expect(res["fastest"] == 1 and res["pb_time"] and not res["pb_lost"], "personal bests and new record places are reported (%s)" % [res])
	_expect(Tournament.fmt_time(83.456) == "1:23.46", "times shown as m:ss.cc (%s)" % Tournament.fmt_time(83.456))
	Settings.dev_flags = true

	# --- AI spectator: four AIs, no input, finishes by itself, no records touched
	var before_boards := FileAccess.get_file_as_bytes("user://leaderboards.cfg")
	main.start_spectator({"picks": ["Pip", "Pip", "Random", "Vesper"], "level": "normal"})
	main.set_speed(4.0)
	var g = main.current
	var names: Array = g.bears.map(func(x): return x.bear_name)
	_expect(g.bears.size() == 4 and g.bears.all(func(x): return not x.is_human), "spectator: four AI bears (%s)" % [names])
	var uniq := {}
	for n in names:
		uniq[n] = true
	_expect(uniq.size() == 4, "spectator: duplicate picks are replaced, no bear twice")
	var t0 := Time.get_ticks_msec()
	while g.state != g.State.ENDED and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().create_timer(0.5).timeout
	_expect(g.state == g.State.ENDED and g.hud.results_panel != null, "spectator: the match plays out and shows the standings by itself")
	_expect(FileAccess.get_file_as_bytes("user://leaderboards.cfg") == before_boards and Tournament.load_saved() == null, "spectator matches don't touch tournament saves or leaderboards")
	var c = g.get_node_or_null("Commentary")
	_expect(c != null and c.feed_box != null and c.feed_box.get_child_count() > 1, "spectator: event feed shows events")
	main.set_speed(1.0)


## Play the current tournament round to its end at 8x with an AI in the human's seat.
func _play_round() -> void:
	main.set_speed(8.0)
	var g = main.current
	await get_tree().process_frame
	max_bears = maxi(max_bears, g.bears.size())
	for b in g.bears:
		if b.is_human:
			b.controller = AiController.new(b, g, 2)   # stand-in player
		else:
			seen[b.bear_name] = seen.get(b.bear_name, 0) + 1
	g.game_event.connect(func(kind, data):
		if kind == "kick":
			_kicks[data["bear"].bear_name] = _kicks.get(data["bear"].bear_name, 0) + 1)
	_kicks = {}
	g.start_round()
	var placed := {}
	var t0 := Time.get_ticks_msec()
	while g.state != g.State.ENDED and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().physics_frame
		for bomb in g.bombs:
			if not placed.has(bomb) and is_instance_valid(bomb):
				placed[bomb] = true
				var o = bomb.owner_bear
				# the pose plays on its bear and the bomb drops from its paws, without changing its fuse
				var fuse_ok: bool = bomb.proximity or bomb.fuse > preload("res://scripts/tuning.gd").BOMB_FUSE - 0.2
				if o.visual.place_t > 0.0 and bomb.place_from != Vector2.ZERO and fuse_ok:
					place_anim_ok += 1
				elif bomb.t < 0.05:
					place_anim_bad += 1
	var c = g.get_node_or_null("Commentary")
	if c != null:
		commentary_lines += c.lines_said.size()
	for b in g.bears:
		if b.is_human:
			continue
		var s: Dictionary = persona_stats.get(b.bear_name, {"bombs": 0, "stole": 0.0, "kicks": 0, "pickups": 0, "self": 0, "rounds": 0})
		s["bombs"] += b.bombs_placed
		s["stole"] += b.stolen_total
		s["kicks"] += _kicks.get(b.bear_name, 0)
		s["pickups"] += b.pickups
		s["self"] += b.self_hits
		s["rounds"] += 1
		persona_stats[b.bear_name] = s
	await get_tree().create_timer(0.3).timeout
	main.set_speed(1.0)


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1
