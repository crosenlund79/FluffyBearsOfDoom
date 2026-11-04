## Performance probe: `godot -- --perf [--seconds=60] [--mode=horror] [--stress]`
## Plays an all-Hard AI match at real speed and samples the engine monitors
## every frame: frame/process/physics times, draw calls, objects, nodes and
## static memory. --stress turns on every hazard plus abilities for everyone.
extends Node

const AiController = preload("res://scripts/ai_controller.gd")

var main


func run(m) -> void:
	main = m
	var seconds := 60.0
	var stress := "--stress" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seconds="):
			seconds = float(a.get_slice("=", 1))
	Settings.human_count = 0
	Settings.round_time_index = 2
	Settings.instant_win = 0.0
	if Settings.match_seed == 0:
		Settings.match_seed = 4242
	if stress:
		Settings.arena_index = 2   # belts, honey and bouncy floors
	main.start_game()
	var g = main.current
	for b in g.bears:
		b.controller = AiController.new(b, g, 2)
	g.start_round()
	if stress:
		for b in g.bears:
			b.can_kick = true
			b.has_line = true
			b.bombs_max = 6
			b.bomb_range = 5
			b.prox_charges = 3
		g.duck_timer = 4.0
		g.crane_timer = 6.0
		g.clown_timer = 8.0
		get_tree().create_timer(10.0).timeout.connect(func(): g.start_princess())
		get_tree().create_timer(15.0).timeout.connect(func(): g.biome_shuffle())
	var frames := []
	var proc := []
	var phys := []
	var draws := []
	var mem := []
	var objs := []
	var nodes := []
	var t0 := Time.get_ticks_usec()
	var last := t0
	await get_tree().process_frame
	while (Time.get_ticks_usec() - t0) / 1e6 < seconds and g.state != g.State.ENDED:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		var pm := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		if pm > 50.0 and (phys.is_empty() or phys[-1] != pm):
			print("PERF physics spike %.0f ms at %.2f s (frame %d)" % [pm, (now - t0) / 1e6, frames.size()])
		phys.append(pm)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if frames.size() % 600 == 0:
			print("PERF sample t=%.0fs mem=%.1fMB objects=%d nodes=%d" % [(now - t0) / 1e6, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		if frames.size() % 30 == 0:
			mem.append(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
			objs.append(Performance.get_monitor(Performance.OBJECT_COUNT))
			nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	frames.remove_at(0)
	print("PERF frames=%d seconds=%.1f fps=%.1f" % [frames.size(), seconds, frames.size() / seconds])
	print("PERF frame_ms %s" % _stats(frames))
	print("PERF process_ms %s" % _stats(proc))
	print("PERF physics_ms %s" % _stats(phys))
	print("PERF draw_calls %s" % _stats(draws))
	print("PERF frames>33ms=%d >50ms=%d" % [frames.filter(func(x): return x > 33.3).size(), frames.filter(func(x): return x > 50.0).size()])
	if mem.size() > 2:
		print("PERF memory_mb start=%.1f end=%.1f max=%.1f" % [mem[0], mem[-1], mem.max()])
		print("PERF objects start=%d end=%d max=%d  nodes start=%d end=%d max=%d" % [objs[0], objs[-1], objs.max(), nodes[0], nodes[-1], nodes.max()])
	get_tree().quit()


func _stats(a: Array) -> String:
	var s := a.duplicate()
	s.sort()
	var n := s.size()
	if n == 0:
		return "-"
	var sum := 0.0
	for x in s:
		sum += x
	return "avg=%.2f p50=%.2f p95=%.2f p99=%.2f max=%.2f" % [sum / n, s[n / 2], s[int(n * 0.95)], s[int(n * 0.99)], s[-1]]
