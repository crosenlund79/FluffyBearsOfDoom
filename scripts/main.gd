## Switches between the menu and a match.
extends Node

const Menu = preload("res://scripts/menu.gd")
const Game = preload("res://scripts/game.gd")

var current: Node

## Everything is laid out for 1280x720. Wider (ultrawide) or taller windows get
## more wallpaper around it; the layout stays centred, nothing is stretched.
const DESIGN := Vector2(1280, 720)


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_view)
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
	var m := Menu.new()
	_swap(m)
	m.start_requested.connect(start_game)
	m.mode_changed.connect(show_menu)


func start_game() -> void:
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
