## Scripted checks for this iteration's mechanics: `godot -- --feature-test`.
## Bears are frozen (no AI) and each scenario sets up the board directly.
extends Node

class Idle:
	func update(_delta: float) -> void:
		pass

var game
var fails := 0
const PowerupScript = preload("res://scripts/powerup.gd")


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
	for c in game._floor_cells():
		if arena.terrain_at(c) != biome:
			uniform = false
	_expect(uniform, "biome shuffle covers the whole floor with one biome (%d)" % biome)
	game.shuffle_t = 0.05
	await _wait(0.3)
	_expect(arena.terrain == before and game.shuffle_phase == "", "biome shuffle restores the previous floor exactly")

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

	# --- key rebinding: conflicts swap instead of leaving an action unbound
	Settings.reset_bindings()
	var swapped := Settings.rebind("p1_bomb", [KEY_E, KEY_LOCATION_UNSPECIFIED])
	_expect(swapped == "p1_special" and Settings.keys_for("p1_special")[0][0] == KEY_SPACE, "rebinding onto a used key swaps the two actions")
	Settings.reset_bindings()
	_expect(Settings.keys_for("p2_special")[0][0] == KEY_R, "reset restores defaults")



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
