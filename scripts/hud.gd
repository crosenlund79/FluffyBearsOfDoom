## In-match interface: the arena in the middle with a ranked stack of four
## player cards on BOTH sides (1st at the top), Time of Doom above the arena,
## banners, toasts, a hideable controls strip, pause and results.
extends CanvasLayer

const UiStyle = preload("res://scripts/ui_style.gd")
const StitchPanel = preload("res://scripts/stitch_panel.gd")
const BearVisual = preload("res://scripts/bear_visual.gd")
const Tuning = preload("res://scripts/tuning.gd")
const Maps = preload("res://scripts/arena_maps.gd")
const AudioPanel = preload("res://scripts/audio_panel.gd")
const NowPlaying = preload("res://scripts/now_playing.gd")
const Mode = preload("res://scripts/mode_theme.gd")
const RankCard = preload("res://scripts/rank_card.gd")
const CardSpider = preload("res://scripts/card_spider.gd")

# Layout (1280x720 design area): arena frame at x 270..1010, a card stack centred in each side column.
# the arena on screen (same formula as Game.ARENA_ORIGIN / ARENA_SIZE)
const ARENA_SIZE := Vector2(Tuning.COLS, Tuning.ROWS) * Tuning.TILE * Tuning.ARENA_SCALE
const ARENA_RECT := Rect2(Vector2(640.0 - ARENA_SIZE.x * 0.5, 52.0), ARENA_SIZE)
const CARD_SCALE := 0.8               # cards are drawn at 80% of RankCard.SIZE
const STACK_GAP := -10.0               # negative: cards overlap a little, like a dealt pile
const SLOT_TILT := [-0.06, 0.045, -0.035, 0.065]   # each slot's own slight rotation (radians)
const SLOT_JITTER := [-7.0, 6.0, -3.0, 8.0]        # ...and sideways offset (px)
const STACK_CENTRE_X := [135.0, 1145.0]   # left, right column centres
const SLIDE_K := 140.0                # card slide spring stiffness (critically damped)
const GLOW_TIME := 0.9                # gold promotion glow
const SPLAT_TIME := 1.0               # demotion splatter

var game
var root: Control
var timer_label: Label
var song_label: Label
var spider
var cards: Array = []           # 8 cards: one per player per side
var banner_label: Label
var toast_box: VBoxContainer
var pause_panel: Control
var results_panel: Control
var ranking: Array = []         # the one ranking both stacks show: bears, 1st first
var anim := {}                  # bear -> {pos, vel, target, dir, glow, splat, drops}: shared by both of its cards
var rank_changes := 0           # how many re-orderings happened (tests)
var _announce_cd := 0.0
var _rng := RandomNumberGenerator.new()


func setup(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.theme = UiStyle.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# the round timer, centred above the arena
	timer_label = UiStyle.label("2:30", 34)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(ARENA_RECT.get_center().x - 100, -6)
	timer_label.size = Vector2(200, 42)
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(timer_label)
	var arena_name := UiStyle.label(Maps.MAPS[Settings.arena_index]["name"], 14, UiStyle.INK_SOFT)
	arena_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arena_name.position = Vector2(ARENA_RECT.end.x - 230, 4)
	arena_name.size = Vector2(230, 24)
	root.add_child(arena_name)

	# the ranked card stacks, one on each side, both driven by the same ranking
	_rng.randomize()
	ranking = game.bears.duplicate()
	ranking = _resort(ranking)
	for i in ranking.size():
		var b = ranking[i]
		anim[b] = {"pos": float(i), "vel": 0.0, "target": i, "dir": 0, "glow": 0.0, "splat": 0.0, "drops": []}
	for side in [-1.0, 1.0]:
		for b in game.bears:
			var c := RankCard.new()
			c.hud = self
			c.bear = b
			c.side = side
			c.font = UiStyle.font()
			root.add_child(c)
			cards.append(c)

	# a big decorative spider roaming the card columns (never over the arena)
	spider = CardSpider.new()
	spider.z_index = 40
	root.add_child(spider)
	var rim := ARENA_RECT.grow(18.0)
	# (columns kept a leg's length away from the rim, so even its legs stay off the arena)
	spider.setup(Rect2(28, 60, rim.position.x - 28 - 34, 600), Rect2(rim.end.x + 34, 60, 1252 - rim.end.x - 34, 600), 12.0)

	# the song that's playing: a quiet line above the arena, left of the timer
	song_label = UiStyle.label("", 13, Color(UiStyle.INK_SOFT, 0.85))
	song_label.position = Vector2(ARENA_RECT.position.x, 4)
	song_label.size = Vector2(ARENA_RECT.size.x * 0.5 - 70, 24)
	song_label.clip_text = true
	song_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(song_label)
	Music.track_changed.connect(_on_track)
	_on_track(Music.title)


	banner_label = UiStyle.label("", 60, UiStyle.ROSE_DARK)
	banner_label.add_theme_color_override("font_outline_color", UiStyle.PAPER)
	banner_label.add_theme_constant_override("outline_size", 14)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_label.position = Vector2(ARENA_RECT.position.x, 250)
	banner_label.size = Vector2(ARENA_RECT.size.x, 150)
	banner_label.pivot_offset = banner_label.size * 0.5
	banner_label.modulate.a = 0.0
	root.add_child(banner_label)

	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(ARENA_RECT.position.x, 560)
	toast_box.size = Vector2(ARENA_RECT.size.x, 110)
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)


func _process(delta: float) -> void:
	if game == null:
		return
	var t: float = maxf(game.time_left, 0.0)
	timer_label.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	var warn: bool = game.doom != null and game.doom.warning_active()
	var pulse := fmod(Time.get_ticks_msec() / 1000.0 * (6.0 if warn else 2.0), 1.0) > 0.5
	timer_label.add_theme_color_override("font_color", UiStyle.ROSE_DARK if ((t < 10.0 or warn) and pulse and game.controls_enabled()) else UiStyle.INK)
	if ready_label != null:
		var rp := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
		ready_label.scale = Vector2.ONE * (1.0 + 0.04 * rp)
		ready_label.modulate.a = 0.75 + 0.25 * rp
	_update_ranking(delta)


var ready_label: Label


## "Press SPACE or ENTER to start", pulsing over the arena while everyone dances.
func show_ready(on: bool) -> void:
	if on and ready_label == null:
		ready_label = UiStyle.label("Press SPACE or ENTER to start", 40, UiStyle.ROSE_DARK)
		ready_label.add_theme_color_override("font_outline_color", UiStyle.PAPER)
		ready_label.add_theme_constant_override("outline_size", 12)
		ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ready_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ready_label.position = Vector2(ARENA_RECT.position.x, ARENA_RECT.get_center().y - 50)
		ready_label.size = Vector2(ARENA_RECT.size.x, 100)
		ready_label.pivot_offset = ready_label.size * 0.5
		root.add_child(ready_label)
	elif not on and ready_label != null:
		ready_label.queue_free()
		ready_label = null


func _on_track(title: String) -> void:
	song_label.text = ("Now playing: " + title) if title != "" else ""


# --- ranking ------------------------------------------------------------------------

## The score a card shows (and the ranking uses): whole fluff.
func score_of(bear) -> int:
	return roundi(bear.fluff)


## Shared rank number: ties share it (two bears on 120 are both 2nd, say).
func rank_of(bear) -> int:
	var mine := score_of(bear)
	var r := 1
	for b in ranking:
		if score_of(b) > mine:
			r += 1
	return r


## On-screen size of a card and the distance between slots.
func card_size() -> Vector2:
	return RankCard.SIZE * CARD_SCALE


func slot_step() -> float:
	return card_size().y + STACK_GAP


## Top-left corner (on screen) of slot `pos` (0 = 1st; fractional while sliding).
func slot_top_left(side: float, pos: float) -> Vector2:
	var total: float = 4.0 * card_size().y + 3.0 * STACK_GAP
	var x: float = (STACK_CENTRE_X[0] if side < 0.0 else STACK_CENTRE_X[1]) - card_size().x * 0.5
	return Vector2(x + _slot_value(SLOT_JITTER, pos) * side, 360.0 - total * 0.5 + pos * slot_step())


## The tilt of slot `pos` (mirrored on the right; blends while a card slides).
func slot_rotation(side: float, pos: float) -> float:
	return _slot_value(SLOT_TILT, pos) * -side


func _slot_value(table: Array, pos: float) -> float:
	var p := clampf(pos, 0.0, 3.0)
	var i := mini(int(floor(p)), 2)
	return lerpf(table[i], table[i + 1], p - i)


## Re-sort `order` by score, only swapping neighbours when the lower one is
## strictly ahead: ties keep their current order, so nothing flickers.
func _resort(order: Array) -> Array:
	var o := order.duplicate()
	var swapped := true
	while swapped:
		swapped = false
		for i in range(o.size() - 1):
			if score_of(o[i + 1]) > score_of(o[i]):
				var tmp = o[i]
				o[i] = o[i + 1]
				o[i + 1] = tmp
				swapped = true
	return o


## Every frame: re-rank immediately; cards whose slot changed get a new target
## (gold glow when going up, splatter when going down) and slide there.
func _update_ranking(delta: float) -> void:
	var now := _resort(ranking)
	if now != ranking:
		var before := ranking
		ranking = now
		rank_changes += 1
		var mover = null
		for i in now.size():
			var b = now[i]
			var old_i: int = before.find(b)
			if old_i == i:
				continue
			var st: Dictionary = anim[b]
			st["target"] = i
			if i < old_i:
				st["dir"] = -1
				st["glow"] = 1.0
				st["splat"] = 0.0
				if mover == null or i < now.find(mover):
					mover = b
			else:
				st["dir"] = 1
				st["splat"] = 1.0
				st["glow"] = 0.0
				st["drops"] = _make_drops()
		if mover != null:
			_announce(mover, before)
	_announce_cd -= delta
	# slide (critically damped spring per player; re-targeting mid-slide is smooth)
	var c := 2.0 * sqrt(SLIDE_K)
	var steps := maxi(1, ceili(delta / 0.004))   # fixed small substeps: stable at any frame rate
	var dt := delta / steps
	for b in anim:
		var st: Dictionary = anim[b]
		for _i in steps:
			var acc: float = SLIDE_K * (float(st["target"]) - st["pos"]) - c * st["vel"]
			st["vel"] += acc * dt
			st["pos"] += st["vel"] * dt
		if absf(st["pos"] - st["target"]) < 0.002 and absf(st["vel"]) < 0.01:
			st["pos"] = float(st["target"])
			st["vel"] = 0.0
			st["dir"] = 0
		st["glow"] = maxf(0.0, st["glow"] - delta / GLOW_TIME)
		st["splat"] = maxf(0.0, st["splat"] - delta / SPLAT_TIME)


## Splatter drops for a demoted card: on its frame, top corners and spilling
## off the sides, never across the score and bar.
func _make_drops() -> Array:
	var out := []
	var sz: Vector2 = RankCard.SIZE
	var keep_clear := Rect2(16, 96, sz.x - 32, 46)
	while out.size() < 11:
		var p := Vector2(_rng.randf_range(-8, sz.x + 8), _rng.randf_range(-6, sz.y + 4))
		if keep_clear.has_point(p):
			continue
		var big := out.size() < 3
		out.append([p, _rng.randf_range(4.5, 7.5) if big else _rng.randf_range(1.5, 3.5), _rng.randf_range(6, 16) if _rng.randf() < 0.35 else 0.0])
	return out


func _announce(b, before: Array) -> void:
	if _announce_cd > 0.0 or not game.controls_enabled():
		return
	_announce_cd = 1.0
	var i: int = ranking.find(b)
	if i == 0:
		toast("%s takes the lead!" % b.bear_name, b.color)
	else:
		toast("%s overtakes %s  (#%d)" % [b.bear_name, before[i].bear_name, i + 1], b.color)
	Sfx.play("overtake", 1.0 + 0.1 * (3 - i), -3.0)


func banner(text: String, duration: float) -> void:
	banner_label.text = text
	banner_label.modulate.a = 1.0
	banner_label.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(banner_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(duration - 0.6, 0.1))
	tw.tween_property(banner_label, "modulate:a", 0.0, 0.3)


func toast(text: String, col: Color) -> void:
	var l := UiStyle.label(text, 18, col.darkened(0.45))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", UiStyle.PAPER)
	l.add_theme_constant_override("outline_size", 8)
	toast_box.add_child(l)
	if toast_box.get_child_count() > 3:
		toast_box.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _panel(sz: Vector2) -> PanelContainer:
	var p := StitchPanel.new()
	p.size = sz
	p.position = ARENA_RECT.get_center() - sz * 0.5
	root.add_child(p)
	return p


func show_pause(paused: bool) -> void:
	if not paused:
		if pause_panel:
			pause_panel.queue_free()
			pause_panel = null
		return
	pause_panel = _panel(Vector2(360, 300))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	pause_panel.add_child(v)
	var l := UiStyle.label("Paused", 36, UiStyle.ROSE_DARK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var resume := _button("Resume", func():
		get_tree().paused = false
		show_pause(false))
	v.add_child(resume)
	v.add_child(_button("Settings", func():
		var ap = AudioPanel.new()
		ap.position = ARENA_RECT.get_center() - Vector2(220, 245)
		root.add_child(ap)))
	v.add_child(_button("Restart match", game.request_restart))
	v.add_child(_button("Back to menu", game.request_menu))
	resume.grab_focus()


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b


func show_results(ranking: Array, instant_winner = null) -> void:
	results_panel = _panel(Vector2(640, 470))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	results_panel.add_child(v)
	var winner = ranking[0]
	var tie: bool = instant_winner == null and ranking.size() > 1 and absf(ranking[1].fluff - winner.fluff) < 0.5
	var title := UiStyle.label("Instant win: %d fluff reached!" % int(Settings.instant_win) if instant_winner != null else "Time's up!", 24, UiStyle.INK_SOFT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var head_text: String = "It's a fluffy tie!" if tie else "%s is the fluffiest!" % winner.bear_name
	var head := UiStyle.label(head_text, 38, winner.color.darkened(0.45))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)

	# The champion, smug and wobbling.
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(600, 150)
	v.add_child(stage)
	var holder := Node2D.new()
	holder.position = Vector2(300, 118)
	holder.scale = Vector2(1.9, 1.9)
	stage.add_child(holder)
	var puppet := BearVisual.Puppet.new()
	puppet.fluff = maxf(winner.fluff, 20.0)
	puppet.smug = true
	var vis := BearVisual.new()
	vis.species = winner.species
	vis.source = puppet
	vis.tint = winner.color
	holder.add_child(vis)
	var wob := create_tween().set_loops()
	wob.tween_callback(func(): vis.kick(0.25)).set_delay(0.9)

	var place := 1
	for i in ranking.size():
		var b = ranking[i]
		if i > 0 and absf(b.fluff - ranking[i - 1].fluff) >= 0.5:
			place = i + 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var medal := UiStyle.label(["1st", "2nd", "3rd", "4th"][place - 1], 22, UiStyle.ROSE_DARK if place == 1 else UiStyle.INK_SOFT)
		medal.custom_minimum_size = Vector2(60, 0)
		row.add_child(medal)
		var swatch := ColorRect.new()
		swatch.color = b.color
		swatch.custom_minimum_size = Vector2(18, 18)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var name_l := UiStyle.label(b.bear_name, 22)
		name_l.custom_minimum_size = Vector2(130, 0)
		row.add_child(name_l)
		var fl := UiStyle.label("%d fluff" % roundi(b.fluff), 22)
		fl.custom_minimum_size = Vector2(120, 0)
		row.add_child(fl)
		row.add_child(UiStyle.label("stole %d · stunned %d×" % [roundi(b.stolen_total), b.times_stunned], 16, UiStyle.INK_SOFT))
		v.add_child(row)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	var again := _button("Rematch", game.request_restart)
	buttons.add_child(again)
	buttons.add_child(_button("Menu", game.request_menu))
	v.add_child(buttons)
	again.grab_focus()
	results_panel.modulate.a = 0.0
	create_tween().tween_property(results_panel, "modulate:a", 1.0, 0.4)
