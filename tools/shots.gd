## `godot -- --shots-demo=DIR [--mode=horror]`: screenshots of the new screens and
## of a tournament round and a spectator match at real speed (needs a display).
## Uses throwaway tournament data; the player's saves are backed up and restored.
extends Node

const Tournament = preload("res://scripts/tournament.gd")

var main
var dir := ""


func run(m, d: String) -> void:
	main = m
	dir = d
	var files := ["user://tournament.cfg", "user://leaderboards.cfg"]
	var backup := {}
	for f in files:
		backup[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
	await _shoot()
	for f in files:
		if backup[f] == null:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		else:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(backup[f])
			fa.close()
	get_tree().quit()


func _snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [dir, Settings.mode, tag])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shoot() -> void:
	main.show_menu()
	await _wait(1.0)
	await _snap("menu")
	main.show_tournament_hub()
	await _wait(0.5)
	await _snap("hub")
	main.show_spectate()
	await _wait(0.5)
	await _snap("spectate_setup")
	# a real tournament round at 1x
	main.start_tournament("normal", "Chris")
	var g = main.current
	await _wait(1.0)
	await _snap("round_ready")
	g.start_round()
	for i in 10:
		await _wait(1.6)
		await _snap("round_%02d" % i)
	# end it and look at the results and the board
	g.time_left = 0.2
	await _wait(1.5)
	await _snap("round_results")
	main.show_tournament_board()
	await _wait(0.6)
	await _snap("board")
	# spectator at 2x
	main.start_spectator({"picks": ["Harald", "Mabel", "Knuckles", "Vesper"], "level": "hard"})
	main.set_speed(2.0)
	for i in 6:
		await _wait(3.0)
		await _snap("spectate_%02d" % i)
	main.set_speed(1.0)
	# leaderboards and the final screen with sample data
	var was: bool = Settings.dev_flags
	Settings.dev_flags = false
	for i in 4:
		var r = Tournament.new_run("normal", ["Chris", "Mum", "Pip's Fan", "Grandpa"][i])
		r.status = "won"
		r.total_time = 640.0 + 37.3 * i
		r.total_lost = 210.0 - 33.0 * i
		r.total_gained = 900.0 + 50 * i
		r.attempts = 10 + i % 2
		r.submit()
	var champ = Tournament.new_run("normal", "Chris")
	champ.status = "won"
	champ.round_index = 10
	champ.total_time = 612.34
	champ.total_lost = 140.0
	champ.total_gained = 1100.0
	champ.attempts = 11
	champ.lives = 2
	var rec: Dictionary = champ.submit()
	Settings.dev_flags = was
	var sc = main._screen()
	sc.show_final(champ, rec)
	await _wait(1.2)
	await _snap("final")
	sc.show_leaderboards("normal")
	await _wait(0.5)
	await _snap("leaderboards")
