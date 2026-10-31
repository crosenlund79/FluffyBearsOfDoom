## Switches between the menu and a match.
extends Node

const Menu = preload("res://scripts/menu.gd")
const Game = preload("res://scripts/game.gd")

var current: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--menu-shot="):
			show_menu()
			await get_tree().create_timer(1.5).timeout
			get_viewport().get_texture().get_image().save_png(a.get_slice("=", 1))
			get_tree().quit()
			return
	# `godot -- --autotest` runs an all-AI match and prints the result (for CI / smoke tests).
	if "--autotest" in OS.get_cmdline_user_args():
		Settings.slots = ["hard", "easy", "normal", "hard"]
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
		_autotest.call_deferred()
		return
	show_menu()


func _autotest() -> void:
	var g = current
	while g.state != g.State.ENDED:
		await get_tree().create_timer(2.0).timeout
		var line := "t=%5.1f " % g.time_left
		for b in g.bears:
			line += "%s:%d%s[%s %s] " % [b.bear_name, roundi(b.fluff), "(z)" if b.is_stunned() else "", b.controller.goal, b.cell()]
		print(line)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shots="):
				get_viewport().get_texture().get_image().save_png("%s/shot_%03d.png" % [a.get_slice("=", 1), int(90.0 - g.time_left)])
	await get_tree().create_timer(1.0).timeout
	for b in g.bears:
		print("%s fluff=%d stole=%d stunned=%d bombs=%d range=%d speed=%d" % [b.bear_name, roundi(b.fluff), roundi(b.stolen_total), b.times_stunned, b.bombs_max, b.bomb_range, b.speed_level])
	get_tree().quit()


func show_menu() -> void:
	var m := Menu.new()
	_swap(m)
	m.start_requested.connect(start_game)


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
