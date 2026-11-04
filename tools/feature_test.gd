## Scripted checks for this iteration's mechanics: `godot -- --feature-test`.
## Bears are frozen (no AI) and each scenario sets up the board directly.
extends Node

class Idle:
	func update(_delta: float) -> void:
		pass

var game
var fails := 0
const PowerupScript = preload("res://scripts/powerup.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Tuning = preload("res://scripts/tuning.gd")


func run(g) -> void:
	game = g
	# rebinding saves settings: keep the player's real settings file intact
	var saved := FileAccess.get_file_as_bytes(Settings.SAVE_PATH) if FileAccess.file_exists(Settings.SAVE_PATH) else PackedByteArray()
	await _run_checks()
	if saved.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.SAVE_PATH))
	else:
		var f := FileAccess.open(Settings.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(saved)
		f.close()
	print("FEATURE TEST: %s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit()


func _run_checks() -> void:
	Settings.instant_win = 0.0
	game.duck_timer = 9999.0
	game.crane_timer = 9999.0
	game.clown_timer = 9999.0
	for b in game.bears:
		b.controller = Idle.new()
	game.bears[0].is_human = true   # to show the human-player card highlight
	# --- pre-round: everyone dances, nothing else moves until Space/Enter
	var t0: float = game.time_left
	var spots: Array = game.bears.map(func(x): return x.position)
	var rig_y: Array = game.bears.map(func(x): return x.visual.position.y)
	await _wait(1.0)
	await _shot("preround")
	var moved := false
	for i in game.bears.size():
		if game.bears[i].position.distance_to(spots[i]) > 0.5:
			moved = true
	var danced: bool = game.bears.any(func(x): return absf(x.visual.position.y - rig_y[game.bears.find(x)]) > 0.5 or absf(x.visual.rotation) > 0.05)
	_expect(game.state == game.State.READY and game.time_left == t0 and not moved and game.bombs.is_empty(), "pre-round: paused (timer, bears, bombs) until Space/Enter")
	_expect(danced and game.hud.ready_label != null, "pre-round: bears dance and the start prompt shows")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(0.3)
	_expect(game.state == game.State.PLAYING and game.time_left < t0 and game.hud.ready_label == null, "Enter starts the round for everyone")
	var arena = game.arena

	# --- sounds: the supplied recordings are loaded and named as expected
	for n in ["explosion", "impact", "kick", "eliminated", "defeat", "princess_laugh", "shotgun", "shotgun_hit", "shell_drop", "footsteps/wood", "footsteps/ice"]:
		_expect(Sfx.has_recording(n), "recording loaded: " + n)

	# --- knockback: blown along the corridor to the wall, collecting a power-up on the way
	var a = game.bears[0]
	var b = game.bears[1]
	_clear_row(3)
	_park_others([a])
	a.position = arena.cell_center(Vector2i(3, 3))
	var pu = PowerupScript.new()
	pu.kind = PowerupScript.REVERSE   # an unwanted one: still collected
	pu.cell = Vector2i(6, 3)
	pu.position = arena.cell_center(pu.cell)
	game.powerup_layer.add_child(pu)
	game.powerups[pu.cell] = pu
	game._hit_bears([Vector2i(3, 3)], Vector2i(2, 3), b, true)   # b's bomb went off next to a
	await _wait(0.12)
	await _shot("knockback_growl")
	await _wait(0.18)
	var growled: bool = b.growl_t > 0.0 and b.visual.growl_t > 0.0
	await _wait(1.1)
	_expect(a.cell() == Vector2i(game.arena.cols - 2, 3), "knockback slides to the last open tile before the border wall (%s)" % a.cell())
	_expect(a.reverse_t > 0.0 and not game.powerups.has(Vector2i(6, 3)), "knockback collects power-ups on the way (Reverse Controls)")
	_expect(not arena.is_solid(a.cell()) and absf(a.position.y - arena.cell_center(a.cell()).y) < 0.5, "knocked bear ends centred on an open tile")
	_expect(growled, "the bomber growls when its bomb stuns someone")
	a.stun_t = 0.0
	a.reverse_t = 0.0

	# --- bomb damage happens only at the instant of detonation, once per bear
	_expect(not a.can_kick and not b.can_kick, "kick is not built in: bears start without it")
	a.position = arena.cell_center(Vector2i(3, 3))
	b.position = arena.cell_center(Vector2i(1, game.arena.rows - 2))
	a.immune_t = 0.0
	a.stun_t = 0.0
	b.bombs_max = 3
	b.bomb_range = 2
	game._spawn_bomb(b, Vector2i(7, 3))
	var bomb1 = arena.bombs[Vector2i(7, 3)]
	bomb1.fuse = 0.05
	await _wait(0.12)
	_expect(a.stun_t <= 0.0 and game.flames.has(Vector2i(6, 3)), "a bear outside the blast at detonation isn't hit")
	a.position = arena.cell_center(Vector2i(6, 3))   # walk into the lingering flames
	await _wait(0.25)
	_expect(not a.is_stunned(), "lingering flames are harmless: damage only at detonation")
	# two bombs going off together (a chain) still hit a bear just once
	game._spawn_bomb(b, Vector2i(3, 3))
	game._spawn_bomb(b, Vector2i(5, 3))
	var hits_before: int = b.bomb_hits
	a.position = arena.cell_center(Vector2i(4, 3))
	arena.bombs[Vector2i(3, 3)].fuse = 0.02
	await _wait(0.15)
	_expect(a.is_stunned() and b.bomb_hits - hits_before == 1, "a chain blast hits the bear once (%d hits)" % (b.bomb_hits - hits_before))
	a.stun_t = 0.0
	a.immune_t = 0.0
	await _wait(0.6)

	# --- proximity bombs: 3-2-1 arming, owner-proof, a rival sets them off
	a.position = arena.cell_center(Vector2i(3, 3))
	b.position = arena.cell_center(Vector2i(1, game.arena.rows - 2))
	a.prox_charges = 3
	a.bombs_max = 3
	a.active_bombs = 0
	var placed: bool = game.place_proximity(a)
	var pb = arena.bombs.get(Vector2i(3, 3))
	_expect(placed and pb != null and pb.proximity and a.prox_charges == 2, "special key lays a proximity bomb (charges 3 -> %d)" % a.prox_charges)
	await _wait(0.3)
	await _shot("prox_countdown")
	_expect(is_instance_valid(pb) and not pb.armed() and pb.arm_left > 2.0 and ceili(pb.arm_left) == 3, "it counts down 3-2-1 while arming (%.1f)" % (pb.arm_left if is_instance_valid(pb) else -1.0))
	b.position = arena.cell_center(Vector2i(4, 3))   # a rival right next to it before it's armed
	await _wait(0.4)
	_expect(is_instance_valid(pb) and not pb.triggered, "an unarmed proximity bomb ignores rivals")
	b.position = arena.cell_center(Vector2i(1, game.arena.rows - 2))
	await _wait(2.5)
	_expect(is_instance_valid(pb) and pb.armed(), "armed after 3 s")
	await _shot("prox_armed")
	_expect(game.trap_cells(b).has(Vector2i(4, 3)) and not game.trap_cells(a).has(Vector2i(4, 3)), "AI sees the trap zone (rivals only)")
	await _wait(0.5)
	_expect(is_instance_valid(pb) and not pb.triggered, "its owner standing on it can't set it off")
	a.position = arena.cell_center(Vector2i(game.arena.cols - 2, 3))
	b.immune_t = 0.0
	b.stun_t = 0.0
	b.position = arena.cell_center(Vector2i(4, 3))   # the rival steps next to it
	await _wait(0.4)
	_expect(not is_instance_valid(pb) or pb.exploded, "a rival stepping close sets it off")
	_expect(b.is_stunned() and b.last_hit_by == a, "the blast belongs to its owner")
	b.stun_t = 0.0
	b.immune_t = 0.0
	b.position = arena.cell_center(Vector2i(1, game.arena.rows - 2))
	a.prox_charges = 0
	await _wait(0.6)

	# --- biome shuffle: the whole floor turns into one biome, then exactly back
	var before: PackedInt32Array = arena.terrain.duplicate()
	game.biome_shuffle()
	await _wait(2.2)
	await _shot("shuffle")
	var biome: int = game.shuffle_biome
	var uniform := true
	if Terrain.is_conveyor(biome):
		var runs: Dictionary = arena.conveyor_runs()
		uniform = runs["h"].size() <= Tuning.MAX_H_BELTS and runs["v"].size() <= Tuning.MAX_V_BELTS and runs["h"].size() + runs["v"].size() > 0
		_expect(uniform, "Conveyor Chaos lays at most 2 horizontal + 2 vertical belts (%d + %d)" % [runs["h"].size(), runs["v"].size()])
	else:
		for c in game._floor_cells():
			if arena.terrain_at(c) != biome:
				uniform = false
		_expect(uniform, "biome shuffle covers the whole floor with one biome (%d)" % biome)
	game.shuffle_t = 0.05
	await _wait(0.3)
	_expect(arena.terrain == before and game.shuffle_phase == "", "biome shuffle restores the previous floor exactly")

	# --- conveyors: never more than 2 + 2 belts, even with every shuffle
	var belts_ok := true
	var worst := Vector2i.ZERO
	for i in 40:
		var plan: Dictionary = game._conveyor_plan_for_test()
		var tarr: PackedInt32Array = arena.terrain.duplicate()
		for c in plan:
			tarr[c.y * arena.cols + c.x] = plan[c]
		var r: Dictionary = arena.conveyor_runs(tarr)
		worst = Vector2i(maxi(worst.x, r["h"].size()), maxi(worst.y, r["v"].size()))
		if r["h"].size() > Tuning.MAX_H_BELTS or r["v"].size() > Tuning.MAX_V_BELTS:
			belts_ok = false
		var on_belts := 0
		for c in plan:
			if Terrain.is_conveyor(plan[c]):
				on_belts += 1
		if on_belts > (Tuning.MAX_H_BELTS + Tuning.MAX_V_BELTS) * Tuning.SHUFFLE_BELT_LEN.y:
			belts_ok = false
	_expect(belts_ok, "40 Conveyor Chaos plans: belts stay in corridors, max %d horizontal + %d vertical" % [worst.x, worst.y])
	var crowded := []
	for y in arena.rows:
		crowded.append(">>>>>>>>>>>>>>>>>" if y % 2 == 1 else "vvvvvvvvvvvvvvvvv")
	var test_arena = load("res://scripts/arena.gd").new()
	var trng := RandomNumberGenerator.new()
	test_arena.setup({"name": "t", "terrain": crowded}, trng)
	var tr: Dictionary = test_arena.conveyor_runs()
	_expect(tr["h"].size() <= 2 and tr["v"].size() <= 2, "a map with too many belts is trimmed to 2 + 2 (%d + %d)" % [tr["h"].size(), tr["v"].size()])
	test_arena.free()

	# --- power-up distribution: 24 items by category, fair corners, rares far, seeded
	var PlanScript = load("res://scripts/powerup_plan.gd")
	var cat_ok := true
	var caps_ok := true
	var fair_ok := true
	var rare_ok := true
	var totals := {}
	var princess_rounds := 0
	var cat_of := {}
	for cat in Tuning.PU_CATEGORIES:
		for k in cat["kinds"]:
			cat_of[k] = cat["name"]
	for sd in range(1, 201):
		var r2 := RandomNumberGenerator.new()
		r2.seed = sd
		var ta = load("res://scripts/arena.gd").new()
		ta.setup(game.Maps.MAPS[sd % game.Maps.MAPS.size()], r2)
		var plan = PlanScript.new()
		plan.build(r2, ta.block_cells(), ta.SPAWNS, true)
		var kinds: Array = plan.hidden.values() + plan.reserve
		var per_cat := {}
		for k in kinds:
			per_cat[cat_of[k]] = per_cat.get(cat_of[k], 0) + 1
			totals[k] = totals.get(k, 0) + 1
		if per_cat.get("core", 0) != 10 or per_cat.get("mobility", 0) != 6 or per_cat.get("tactical", 0) != 4 or per_cat.get("chaos", 0) != 3 or per_cat.get("special", 0) > 1:
			cat_ok = false
			print("   seed %d categories %s" % [sd, per_cat])
		if per_cat.get("special", 0) == 1:
			princess_rounds += 1
		for k in Tuning.PU_CAPS:
			if kinds.count(k) > Tuning.PU_CAPS[k]:
				caps_ok = false
		# each corner's nearest items: same total value
		var vals := []
		for sp in ta.SPAWNS:
			var v := 0.0
			for c in plan.hidden:
				if absi(c.x - sp.x) + absi(c.y - sp.y) <= Tuning.PU_EARLY_RADIUS and not PlanScript.is_rare(plan.hidden[c]):
					v += PlanScript.value(plan.hidden[c])
			vals.append(v)
		if vals.max() - vals.min() > 0.01:
			fair_ok = false
			print("   seed %d corner values %s" % [sd, vals])
		for c in plan.hidden:
			if PlanScript.is_rare(plan.hidden[c]):
				for sp in ta.SPAWNS:
					if absi(c.x - sp.x) + absi(c.y - sp.y) < Tuning.PU_RARE_MIN_DIST:
						rare_ok = false
		ta.free()
	_expect(cat_ok, "200 seeds: 10 core, 6 mobility, 4 tactical, 3 chaos, at most 1 special")
	_expect(caps_ok, "per-kind caps are never exceeded")
	_expect(fair_ok, "every spawn corner gets the same early value")
	_expect(rare_ok, "rare items are hidden away from the spawns")
	_expect(princess_rounds > 40 and princess_rounds < 140, "Princess Hunt is a maximum, not a guarantee (%d / 200 rounds)" % princess_rounds)
	print("   item totals over 200 rounds: %s" % [totals])
	# diseases off: redistributed, never dropped
	var r3 := RandomNumberGenerator.new()
	var dis_ok := true
	for sd in range(1, 101):
		r3.seed = sd
		var plan2 = PlanScript.new()
		var items: Array = plan2.draw_items(r3, false)
		if items.has(PowerupScript.REVERSE) or items.has(PowerupScript.DIARRHEA) or items.size() < 23:
			dis_ok = false
	_expect(dis_ok, "diseases off: no curses, and their slots go to other categories (23-24 items)")
	# same seed, same layout
	var layouts := []
	for i in 2:
		var r4 := RandomNumberGenerator.new()
		r4.seed = 4242
		var ta2 = load("res://scripts/arena.gd").new()
		ta2.setup(game.Maps.MAPS[0], r4)
		var plan3 = PlanScript.new()
		plan3.build(r4, ta2.block_cells(), ta2.SPAWNS, true)
		layouts.append([ta2.block_cells(), plan3.hidden, plan3.reserve])
		ta2.free()
	_expect(layouts[0] == layouts[1], "a seed reproduces blocks, hidden items and the reserve exactly")
	_expect(game.pu_plan.reserve.size() == Tuning.PU_RESERVE and game.reserve_drops.size() <= Tuning.PU_RESERVE, "the reserve waits to drop later in the round")

	# --- zero fluff: deflated, out, can't act
	var z = game.bears[2]
	z.fluff = 0.0
	await _wait(0.6)
	await _shot("eliminated")
	_expect(z.eliminated and z.is_stunned() and not z.can_act(), "zero fluff eliminates the bear for good")
	z.stun_t = 0.0
	await _wait(0.3)
	_expect(z.is_stunned(), "an eliminated bear never recovers")
	_expect(game.hud.rank_of(z) == 4, "eliminated bear ranks last")

	# --- princess: blank against an immortal bear, real blast otherwise, at most once per round
	var victim = game.bears[3]
	victim.position = arena.cell_center(Vector2i(7, 5))
	victim.fluff = 120.0
	for x in game.bears:
		x.immortal_t = 30.0   # everyone untouchable: whoever she picks, it must be a blank
	game.start_princess()
	var p = game.princess
	_expect(p != null, "princess appears")
	var rim_scale: float = p.perspective_scale() if p != null else 0.0   # outside the wall, before her leap
	var guard := 0
	while is_instance_valid(p) and p.phase != p.FIRE and guard < 600:
		await get_tree().physics_frame
		guard += 1
	var floor_scale: float = p.perspective_scale() if is_instance_valid(p) else 0.0   # down in the arena, firing
	_expect(rim_scale > floor_scale and floor_scale > 1.2, "princess: bigger on the raised rim (%.2f) than down in the arena (%.2f), always bigger than a bear (1.0)" % [rim_scale, floor_scale])
	var shot_at = p.target if is_instance_valid(p) else null
	_expect(shot_at != null and not shot_at.eliminated and p.blank, "princess hunts an active bear (%s) and fires a blank at an immortal one" % (shot_at.bear_name if shot_at else "-"))
	_expect(shot_at != null and shot_at.stun_t <= 0.0, "the blank does no harm")
	while is_instance_valid(p) and guard < 1200:
		await get_tree().physics_frame
		guard += 1
	_expect(game.princess == null, "she leaves over the wall afterwards")
	game.start_princess()
	_expect(game.princess == null, "a second Princess Hunt in the same round is refused")

	# --- princess, second scenario in a fresh state: real shot + driven off by a bomb
	game.princess_used = false
	for x in game.bears:
		x.immortal_t = 0.0
		x.immune_t = 0.0
		x.stun_t = 0.0
	game.start_princess()
	p = game.princess
	guard = 0
	await _wait(0.5)
	await _shot("princess_warn")
	var had := 0.0
	while is_instance_valid(p) and p.phase != p.FIRE and guard < 1500:
		if p.target != null:
			had = p.target.fluff   # stuffing just before the shot
		await get_tree().physics_frame
		guard += 1
	if guard >= 1500 and is_instance_valid(p):
		print("   princess stuck? phase=%d cell=%s target=%s at %s path=%s age=%.1f" % [p.phase, p.cell(), p.target.bear_name if p.target else "-", p.target.cell() if p.target else "-", p.path, p.age])
	var hit = p.target if is_instance_valid(p) else null
	var was_blank: bool = is_instance_valid(p) and p.blank
	var protected: bool = hit != null and (hit.immortal_t > 0.0 or hit.immune_t > 0.0)
	await _wait(0.05)
	await _shot("princess_fire")
	await _wait(0.2)
	_expect(hit != null and ((was_blank and protected) or (not was_blank and hit.is_stunned() and hit.fluff < had * 0.85)), "her shot (blank only if protected) stuns %s and blows out stuffing (%d -> %d) blank=%s immortal=%.1f immune=%.1f" % [hit.bear_name if hit else "-", roundi(had), roundi(hit.fluff if hit else 0.0), p.blank if is_instance_valid(p) else "?", hit.immortal_t if hit else 0.0, hit.immune_t if hit else 0.0])
	while is_instance_valid(p):
		await get_tree().physics_frame
	game.princess_used = false
	game.start_princess()
	p = game.princess
	guard = 0
	while is_instance_valid(p) and p.phase != p.HUNT and guard < 600:
		await get_tree().physics_frame
		guard += 1
	if is_instance_valid(p):
		game._hit_bears([p.cell()], p.cell(), null, true)   # a blast right where she landed
	await _wait(0.2)
	_expect(is_instance_valid(p) == false or p.defeated, "a bomb blast drives the princess off")

	# --- Time of Doom: tiles close one at a time, clockwise, outermost ring first
	var doom = game.doom
	var first: Array = doom.order.slice(0, 4)
	_expect(first == [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)], "doom closes clockwise from the outer ring's corner")
	var rings_ok := true
	for i in range(1, doom.order.size()):
		if doom.ring_of(doom.order[i]) < doom.ring_of(doom.order[i - 1]):
			rings_ok = false
	game.time_left = game.round_duration * (1.0 - 0.6) - 9.0   # jump ahead into the Time of Doom
	await _wait(1.5)
	await _shot("doom")
	_expect(rings_ok and doom.order.size() == 180, "five rings, outermost first (%d tiles)" % doom.order.size())
	var times_ok := true
	for i in range(1, doom.order.size()):
		if doom.close_at[doom.order[i]] <= doom.close_at[doom.order[i - 1]]:
			times_ok = false
	_expect(times_ok and doom.close_at[doom.order[-1]] < game.round_duration, "one tile at a time, all shut before the timer ends")

	# --- custom character art: optional strips resolve Custom -> Horror -> none
	await _check_strip_fallback()

	# --- key rebinding: conflicts swap instead of leaving an action unbound
	Settings.reset_bindings()
	var swapped := Settings.rebind("p1_bomb", [KEY_E, KEY_LOCATION_UNSPECIFIED])
	_expect(swapped == "p1_special" and Settings.keys_for("p1_special")[0][0] == KEY_SPACE, "rebinding onto a used key swaps the two actions")
	Settings.reset_bindings()
	_expect(Settings.keys_for("p2_special")[0][0] == KEY_R, "reset restores defaults")

	# --- simultaneous eliminations: the last bear with stuffing wins at once
	game.bears[0].fluff = 50.0
	game.bears[0].immortal_t = 0.0
	for k in [1, 3]:
		game.bears[k].fluff = 0.0   # both emptied on the same frame
	await _wait(0.4)
	var order: Array = game.final_ranking()
	_expect(game.state == game.State.ENDED and order[0] == game.bears[0], "last bear standing ends the round as the winner")
	_expect(order[3] == game.bears[2], "eliminated earlier ranks lower (%s last)" % order[3].bear_name)



## Uses a throwaway folder (never the real custom/ folders) with a 2-frame Horror
## strip and a 3-frame Custom strip, checks each mode picks the right one, then cleans up.
func _check_strip_fallback() -> void:
	var root := "res://assets/sprites/_strip_test/"
	DirAccess.make_dir_recursive_absolute(root + "custom")
	DirAccess.make_dir_recursive_absolute(root + "horror")
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png(root + "horror/anim.png")
	img = Image.create(96, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLUE)
	img.save_png(root + "custom/anim.png")
	img.save_png(root + "custom/only_custom.png")
	var keep: String = Settings.mode
	var got := {}
	for m in ["normal", "horror", "custom"]:
		Settings.mode = m
		var a: Texture2D = Assets.strip("_strip_test/anim")
		var c: Texture2D = Assets.strip("_strip_test/only_custom")
		got[m] = [Assets.strip_frames(a) if a != null else 0, c != null]
	Settings.mode = keep
	DirAccess.remove_absolute(root + "custom/anim.png")
	DirAccess.remove_absolute(root + "custom/only_custom.png")
	DirAccess.remove_absolute(root + "horror/anim.png")
	DirAccess.remove_absolute(root + "custom")
	DirAccess.remove_absolute(root + "horror")
	DirAccess.remove_absolute(root)
	_expect(got["custom"] == [3, true], "Custom uses its own strip first (%s)" % [got["custom"]])
	_expect(got["horror"] == [2, false], "Horror uses the Horror strip, never Custom's (%s)" % [got["horror"]])
	_expect(got["normal"] == [0, false], "Normal ignores Horror/Custom strips (%s)" % [got["normal"]])
	Settings.mode = "custom"
	var clown_strips := ["clown_enter", "clown_attack", "clown_exit", "clown_hit", "princess_enter", "princess_walk", "princess_attack", "princess_exit", "princess_shot", "princess_idle"].filter(func(n): return Assets.strip("objects/" + n) != null)
	Settings.mode = keep
	var paths := {}
	for m in ["horror", "custom"]:
		Settings.mode = m
		paths[m] = Assets.resolve("objects/clown")
	Settings.mode = keep
	_expect(paths["horror"].ends_with("objects/horror/template_clown.png") and paths["custom"].ends_with("objects/custom/clown.png"), "clown sheet: Horror keeps its template, Custom uses custom/clown.png (%s)" % [paths])
	print("   optional character strips present in Custom: %s" % [clown_strips])


func _clear_row(y: int) -> void:
	for x in range(1, game.arena.cols - 1):
		var c := Vector2i(x, y)
		if game.arena.cell_type(c) == game.arena.BLOCK:
			game.arena.destroy_block(c)


func _park_others(keep: Array) -> void:
	var spots := [Vector2i(1, game.arena.rows - 2), Vector2i(game.arena.cols - 2, game.arena.rows - 2), Vector2i(1, game.arena.rows - 4)]
	var i := 0
	for b in game.bears:
		if not b in keep:
			b.position = game.arena.cell_center(spots[i])
			i += 1


## Screenshot (only with --shots=DIR and a display).
func _shot(tag: String) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/ft_%s.png" % [a.get_slice("=", 1), tag])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1
