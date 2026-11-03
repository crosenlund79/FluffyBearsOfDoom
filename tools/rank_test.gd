## Scripted check of the ranked HUD stacks: `godot -- --rank-test [--shots=DIR]`.
## Bears stand still (no AI) while this drives their fluff through ties, swaps,
## simultaneous and rapid re-rankings, then checks after each step that both
## stacks show the same, correct order with every card settled in its slot.
extends Node

class Idle:
	func update(_delta: float) -> void:
		pass

var game
var shots := ""
var fails := 0


func run(g, shot_dir: String) -> void:
	game = g
	shots = shot_dir
	Settings.instant_win = 0.0
	game.duck_timer = 9999.0
	game.crane_timer = 9999.0
	game.clown_timer = 9999.0
	for b in game.bears:
		b.controller = Idle.new()
	var names: Array = game.bears.map(func(b): return b.bear_name)
	print("rank-test bears: ", names)
	await _wait(0.5)
	_check("start, all tied", names)

	# 1. ties: scores wobbling inside the same whole number never swap anything
	var before: int = game.hud.rank_changes
	for i in 60:
		game.bears[3].fluff = 100.3 if i % 2 == 0 else 99.7
		game.bears[1].fluff = 100.45 if i % 3 == 0 else 99.6
		await get_tree().physics_frame
	_expect(game.hud.rank_changes == before, "jittering tied scores cause no re-ranking (%d changes)" % (game.hud.rank_changes - before))

	# 2. one overtake: the last bear jumps to the top
	_set_scores([100, 100, 100, 130])
	await _shot_mid("one_up")
	await _wait(0.9)
	_check("4th takes the lead", [names[3], names[0], names[1], names[2]])

	# 3. all four change place at once (full reversal)
	_set_scores([140, 120, 110, 90])
	await _shot_mid("all_four")
	await _wait(0.9)
	_check("simultaneous full re-order", [names[0], names[1], names[2], names[3]])

	# 4. tie at the top: equal scores keep their current order and share rank 1
	_set_scores([140, 140, 110, 90])
	await _wait(0.6)
	_check("tie keeps order", [names[0], names[1], names[2], names[3]])
	_expect(game.hud.rank_of(game.bears[0]) == 1 and game.hud.rank_of(game.bears[1]) == 1, "tied leaders both show rank 1")
	game.bears[1].fluff = 140.4   # still 140 on screen: no swap
	await _wait(0.3)
	_check("sub-point lead is still a tie", [names[0], names[1], names[2], names[3]])
	game.bears[1].fluff = 141.0
	await _wait(0.9)
	_check("a real point breaks the tie", [names[1], names[0], names[2], names[3]])

	# 5. rapid consecutive changes, faster than a slide takes
	var seq := [[50, 60, 70, 80], [80, 70, 60, 50], [60, 90, 55, 70], [100, 20, 99, 101], [10, 11, 12, 13], [13, 12, 11, 10]]
	for k in seq.size():
		_set_scores(seq[k])
		if k == 2:
			await _shot_mid("rapid")
		else:
			await _wait(0.12)
	await _wait(1.1)
	_check("after rapid changes", [names[0], names[1], names[2], names[3]])

	# 6. gradual stealing: one bear drains another point by point
	_set_scores([100, 100, 100, 100])
	await _wait(0.9)
	var start_changes: int = game.hud.rank_changes
	for i in 400:
		game.bears[2].fluff += 0.25
		game.bears[0].fluff -= 0.25
		await get_tree().physics_frame
	await _wait(1.0)
	_check("steady stealing", [names[2], names[1], names[3], names[0]])
	print("steady stealing re-rankings: %d" % (game.hud.rank_changes - start_changes))
	_expect(game.hud.rank_changes - start_changes <= 3, "steady stealing re-ranks only when places really change")

	print("RANK TEST: %s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit()


func _set_scores(vals: Array) -> void:
	for i in vals.size():
		game.bears[i].fluff = float(vals[i])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## Screenshot part-way through a slide (if --shots was given).
func _shot_mid(tag: String) -> void:
	await _wait(0.16)
	if shots != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/rank_%s.png" % [shots, tag])


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


## Ranking is `expected`, and in BOTH stacks the cards sit exactly in their slots
## (sorted top to bottom in that order, no overlaps, nothing still moving).
func _check(what: String, expected: Array) -> void:
	var hud = game.hud
	var got: Array = hud.ranking.map(func(b): return b.bear_name)
	var ok: bool = got == expected
	for side in [-1.0, 1.0]:
		var col: Array = hud.cards.filter(func(c): return c.side == side)
		col.sort_custom(func(a, b): return a.position.y < b.position.y)
		var order: Array = col.map(func(c): return c.bear.bear_name)
		if order != expected:
			ok = false
		for i in col.size():
			var want: Vector2 = hud.slot_top_left(side, i) - col[i].size * (1.0 - hud.CARD_SCALE) * 0.5
			if col[i].position.distance_to(want) > 0.5 or absf(col[i].rotation) > 0.01 or absf(col[i].scale.x - hud.CARD_SCALE) > 0.001:
				ok = false
			if i > 0 and col[i].position.y < col[i - 1].position.y + hud.card_size().y:
				ok = false
	if not ok:
		for c in hud.cards:
			print("   card %s side=%d pos=%s rot=%.3f anim=%s" % [c.bear.bear_name, c.side, c.position, c.rotation, hud.anim[c.bear]["pos"]])
	_expect(ok, "%s: %s" % [what, got])
