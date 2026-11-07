## Switches between the menu and a match.
extends Node

const Menu = preload("res://scripts/menu.gd")
const Game = preload("res://scripts/game.gd")
const Tournament = preload("res://scripts/tournament.gd")
const TournamentScreen = preload("res://scripts/tournament_screen.gd")
const Commentary = preload("res://scripts/commentary.gd")
const Personalities = preload("res://scripts/personalities.gd")
const AiController = preload("res://scripts/ai_controller.gd")
const DEV_FLAGS := ["--seed=", "--rotate=", "--win=", "--feature-test", "--autotest", "--balance", "--perf",
	"--rank-test", "--tournament-test", "--fat", "--abilities", "--shots-demo="]

var tournament = null   # the Tournament run being played (tournament.gd)

var current: Node

## Everything is laid out for 1280x720. Wider (ultrawide) or taller windows get
## more wallpaper around it; the layout stays centred, nothing is stretched.
const DESIGN := Vector2(1280, 720)


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_view)
	for a in OS.get_cmdline_user_args():
		for f in DEV_FLAGS:
			if a.begins_with(f):
				Settings.dev_flags = true   # tests and cheats never reach the leaderboards
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			Settings.set_mode(a.get_slice("=", 1))  # dev/test override, not saved
		if a.begins_with("--seed="):
			Settings.match_seed = int(a.get_slice("=", 1))   # reproducible arena + power-ups
		if a.begins_with("--rotate="):
			Settings.spawn_rotation = int(a.get_slice("=", 1)) % 4   # who starts in which corner
		if a.begins_with("--win="):
			Settings.instant_win = float(a.get_slice("=", 1))  # dev/test override, not saved
		if a.begins_with("--menu-shot="):
			show_menu()
			if "--powerups" in OS.get_cmdline_user_args():
				current._show_powerups()   # screenshot the power-up overview
			if "--controls" in OS.get_cmdline_user_args():
				current._show_controls()   # screenshot the key remapping panel
			await get_tree().create_timer(1.5).timeout
			get_viewport().get_texture().get_image().save_png(a.get_slice("=", 1))
			get_tree().quit()
			return
	# `godot -- --rank-test` drives the HUD ranking through scripted scores (tools/rank_test.gd).
	if "--rank-test" in OS.get_cmdline_user_args():
		Settings.human_count = 0
		Settings.round_time_index = 2
		start_game()
		var shot_dir := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shots="):
				shot_dir = a.get_slice("=", 1)
		current.start_round.call_deferred()
		var tester = load("res://tools/rank_test.gd").new()
		add_child(tester)
		tester.run.call_deferred(current, shot_dir)
		return
	# `godot -- --balance [--matches=N] [--levels=hard,easy,easy,easy] [--seed=N] [--out=FILE]`
	# plays headless all-AI matches and writes one JSON line per match (tools/balance.gd).
	if "--balance" in OS.get_cmdline_user_args():
		var bal = load("res://tools/balance.gd").new()
		add_child(bal)
		bal.run.call_deferred(self)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-demo="):
			var sd = load("res://tools/shots.gd").new()
			add_child(sd)
			sd.run.call_deferred(self, a.get_slice("=", 1))
			return
	# `godot --headless -- --tournament-test` plays whole tournaments at 8x and checks the leaderboards.
	if "--tournament-test" in OS.get_cmdline_user_args():
		var tt = load("res://tools/tournament_test.gd").new()
		add_child(tt)
		tt.run.call_deferred(self)
		return
	# `godot -- --perf [--seconds=N] [--stress]` samples frame times, draw calls and memory.
	if "--perf" in OS.get_cmdline_user_args():
		var perf = load("res://tools/perf.gd").new()
		add_child(perf)
		perf.run.call_deferred(self)
		return
	# `godot -- --feature-test` checks knockback, shuffle, elimination, princess, doom order, rebinding.
	if "--feature-test" in OS.get_cmdline_user_args():
		Settings.human_count = 0
		Settings.round_time_index = 2
		start_game()
		var ft = load("res://tools/feature_test.gd").new()
		add_child(ft)
		ft.run.call_deferred(current)
		return
	# `godot -- --autotest` runs an all-AI match and prints the result (for CI / smoke tests).
	if "--autotest" in OS.get_cmdline_user_args():
		Settings.human_count = 0
		for a in OS.get_cmdline_user_args():
			if a == "--assets":
				for rel in ["bears/bear", "tiles/tiles", "effects/effects", "objects/bomb", "objects/duck"]:
					print("asset %s [%s] -> %s" % [rel, Settings.mode, Assets.resolve(rel)])
				get_tree().quit()
				return
		Settings.ai_levels = ["easy", "normal", "hard"]
		Settings.round_time_index = 0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--arena="):
				Settings.arena_index = int(a.get_slice("=", 1))
		Engine.physics_ticks_per_second = 240
		Engine.max_physics_steps_per_frame = 32
		Engine.time_scale = 4.0
		start_game()
		if "--fat" in OS.get_cmdline_user_args():
			current.bears[0].fluff = 340.0  # see an overstuffed bear in action
			current.bears[1].fluff = 15.0
		if "--abilities" in OS.get_cmdline_user_args():
			for b in current.bears:
				b.can_kick = true
				b.has_line = true
				b.bombs_max = 4
			current.bears[1].has_rubber = true
			current.bears[2].prox_charges = 3
			current.infect(current.bears[2])
			current.bears[3].diarrhea_t = 10.0
			current.bears[0].immortal_t = 20.0
		if "--duck" in OS.get_cmdline_user_args():
			current.duck_timer = 3.0
		if "--princess" in OS.get_cmdline_user_args():
			get_tree().create_timer(5.0).timeout.connect(func(): current.start_princess())
		if "--clown" in OS.get_cmdline_user_args():
			current.clown_timer = 1.0
		if "--crane" in OS.get_cmdline_user_args():
			current.crane_timer = 2.0
			current.duck_timer = 999.0
		current.start_round.call_deferred()   # no one to press Space: start right away
		_autotest.call_deferred()
		return
	show_menu()


func _autotest() -> void:
	var g = current
	while g.state != g.State.ENDED:
		await get_tree().create_timer(0.5 if ("--duck" in OS.get_cmdline_user_args() or "--crane" in OS.get_cmdline_user_args() or "--clown" in OS.get_cmdline_user_args()) else 2.0).timeout
		var line := "t=%5.1f " % g.time_left
		for b in g.bears:
			line += "%s:%d%s[%s %s] " % [b.bear_name, roundi(b.fluff), "(z)" if b.is_stunned() else "", b.controller.goal, b.cell()]
		if g.princess != null and is_instance_valid(g.princess):
			line += "princess=%d tgt=%s " % [g.princess.phase, g.princess.target.bear_name if g.princess.target != null else "-"]
		var out: int = g.bears.filter(func(x): return x.eliminated).size()
		if out > 0:
			line += "out=%d " % out
		if g.clown != null:
			line += "clown=%d tgt=%s " % [g.clown.phase, g.clown.target.bear_name if g.clown.target != null else "-"]
		if g.doom != null:
			line += "doom=%d/%d%s " % [g.doom.closed_count(), g.doom.order.size(), "!" if g.doom.warning_active() else ""]
		if g.crane != null and g.crane.busy():
			line += "crane=%d " % g.crane.phase
		if g.chair != null and is_instance_valid(g.chair):
			line += "chair=%s fluff=%d " % [g.chair.cell, roundi(g.chair.fluff)]
		print(line)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shots="):
				get_viewport().get_texture().get_image().save_png("%s/shot_%03d.png" % [a.get_slice("=", 1), int((90.0 - g.time_left) * 10.0)])
	await get_tree().create_timer(1.0).timeout
	var counts := []
	for k in Music.playlists:
		counts.append("%s:%d" % [k, Music.playlists[k].size()])
	print("music context=%s playing=%s tracks=%s" % [Music.context, Music.title, ", ".join(counts)])
	for b in g.bears:
		print("%s taunts=%d" % [b.bear_name, b.taunt_count])
	var bad := 0
	for b in g.bears:
		if g.arena.is_solid(b.cell()):
			bad += 1
	print("bears inside solid cells: %d" % bad)
	var binds := []
	for a in ["p1_special", "p2_special", "pause"]:
		binds.append("%s=%s" % [a, "/".join(Settings.keys_for(a).map(func(k): return Settings.key_name(k)))])
	print("bindings: ", ", ".join(binds))
	var recs := []
	for k in Sfx._over["normal"]:
		recs.append("%s:%d" % [k, Sfx._over["normal"][k].size()])
	recs.sort()
	print("sfx recordings: ", ", ".join(recs))
	for b in g.bears:
		print("%s fluff=%d stole=%d stunned=%d bombs=%d range=%d speed=%d" % [b.bear_name, roundi(b.fluff), roundi(b.stolen_total), b.times_stunned, b.bombs_max, b.bomb_range, b.speed_level])
	get_tree().quit()


func show_menu() -> void:
	_plain_rules()
	var m := Menu.new()
	_swap(m)
	m.start_requested.connect(start_game)
	m.mode_changed.connect(show_menu)
	m.tournament_requested.connect(show_tournament_hub)
	m.spectate_requested.connect(show_spectate)
	m.leaderboards_requested.connect(func(): _screen().show_leaderboards("normal"))


## Back to the menu's own set-up and normal speed.
func _plain_rules() -> void:
	Settings.roster_override = []
	Settings.match_rules = {}
	set_speed(1.0)


static func set_speed(x: float) -> void:
	Engine.time_scale = x
	Engine.physics_ticks_per_second = int(60 * x)   # same 1/60 s steps at any speed
	Engine.max_physics_steps_per_frame = maxi(8, int(8 * x))


func start_game() -> void:
	if not "--balance" in OS.get_cmdline_user_args() and not "--autotest" in OS.get_cmdline_user_args() and not "--perf" in OS.get_cmdline_user_args():
		Settings.roster_override = []
		Settings.match_rules = {}
	var g := Game.new()
	_swap(g)
	g.quit_to_menu.connect(show_menu)
	g.restart_requested.connect(start_game)


func _swap(n: Node) -> void:
	get_tree().paused = false
	if current:
		current.queue_free()
	current = n
	add_child(n)
	_fit_view.call_deferred()


## Offset of the centred 1280x720 design area inside the actual viewport.
func view_offset() -> Vector2:
	return ((get_viewport().get_visible_rect().size - DESIGN) * 0.5).floor()


func _fit_view() -> void:
	if current == null or not is_instance_valid(current):
		return
	var off := view_offset()
	if current is Control:
		current.set_anchors_preset(Control.PRESET_TOP_LEFT)
		current.position = off
		current.size = DESIGN
	elif current is Node2D:
		current.position = off
	for layer in current.find_children("*", "CanvasLayer", true, false):
		layer.offset = off
	if current is CanvasItem:
		current.queue_redraw()


func _screen() -> Control:
	_plain_rules()
	var sc := TournamentScreen.new(self)
	_swap(sc)
	return sc


# --- Tournament of Doom ---------------------------------------------------------------------

func show_tournament_hub() -> void:
	_screen().show_hub()


func show_tournament_board() -> void:
	_screen().show_board(tournament)


func start_tournament(level: String, player: String) -> void:
	tournament = Tournament.new_run(level, player)
	tournament.save()
	play_tournament_round()


func continue_tournament(run) -> void:
	tournament = run
	play_tournament_round()


func play_tournament_round() -> void:
	set_speed(1.0)
	tournament.prepare_round()
	var g := Game.new()
	g.session = TournamentSession.new(self, tournament)
	_swap(g)
	g.quit_to_menu.connect(show_menu)
	_add_commentary(g, false)


func submit_result(run) -> Dictionary:
	var rec: Dictionary = run.submit()
	Tournament.clear_saved()
	return rec


func _add_commentary(g, feed: bool) -> void:
	var c := Commentary.new()
	c.name = "Commentary"
	g.add_child(c)
	c.setup(g, feed)


class TournamentSession:
	var main
	var run
	var spectator := false

	func _init(m, r) -> void:
		main = m
		run = r

	func on_match_end(game, ranking: Array, _instant) -> void:
		run.record_round(game, ranking)

	func results_note() -> String:
		var h: Dictionary = run.history[-1]
		match run.status:
			"won":
				return "Round 10 won: you are the CHAMPION!"
			"failed":
				return "Round %d lost, and that was your last life. Tournament over." % h["round"]
		if h["won"]:
			return "Round %d won! On to round %d of 10." % [h["round"], run.round_index + 1]
		return "Round %d lost: %d %s left. Try again!" % [h["round"], run.lives, "life" if run.lives == 1 else "lives"]

	func results_buttons() -> Array:
		return [["Continue", main.show_tournament_board]]

	func pause_buttons() -> Array:
		return [["Forfeit round", func():
			run.forfeit_round()
			main.show_tournament_board()]]


# --- AI spectator ---------------------------------------------------------------------------

var spectate_cfg := {}


func show_spectate(cfg: Dictionary = {}) -> void:
	_screen().show_spectate(cfg if not cfg.is_empty() else spectate_cfg)


func start_spectator(cfg: Dictionary) -> void:
	spectate_cfg = cfg
	var pool: Array = Personalities.names()
	pool.shuffle()
	var chosen := []
	for p in cfg["picks"]:
		if p != "Random" and not p in chosen:
			chosen.append(p)
		else:
			chosen.append("")
	for i in chosen.size():
		if chosen[i] == "":
			for n in pool:
				if not n in chosen:
					chosen[i] = n
					break
	Settings.roster_override = chosen.map(func(n): return Personalities.roster_entry(n, cfg["level"]))
	Settings.match_rules = {"human_count": 0}
	var keep_speed := Engine.time_scale
	var g := Game.new()
	g.session = SpectatorSession.new(self, cfg)
	_swap(g)
	g.quit_to_menu.connect(show_menu)
	_add_commentary(g, true)
	set_speed(keep_speed)
	g.start_round.call_deferred()   # nobody to press Space


class SpectatorSession:
	var main
	var cfg: Dictionary
	var spectator := true

	func _init(m, c: Dictionary) -> void:
		main = m
		cfg = c

	func on_match_end(_game, _ranking: Array, _instant) -> void:
		pass   # spectator matches never touch the tournament or its leaderboards

	func results_note() -> String:
		return "An all-AI match. Nobody's records were harmed."

	func results_buttons() -> Array:
		return [["Watch another", func(): main.start_spectator(cfg)], ["Change line-up", func(): main.show_spectate(cfg)]]

	func pause_buttons() -> Array:
		return [["Change line-up", func(): main.show_spectate(cfg)]]

