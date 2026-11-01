## In-match interface: four character cards in the side columns (by spawn
## corner), Time of Doom above the arena, banners, toasts, a hideable controls
## strip, pause and results. The arena itself is never covered.
extends CanvasLayer

const UiStyle = preload("res://scripts/ui_style.gd")
const StitchPanel = preload("res://scripts/stitch_panel.gd")
const BearVisual = preload("res://scripts/bear_visual.gd")
const Tuning = preload("res://scripts/tuning.gd")
const Maps = preload("res://scripts/arena_maps.gd")
const AudioPanel = preload("res://scripts/audio_panel.gd")
const NowPlaying = preload("res://scripts/now_playing.gd")
const Mode = preload("res://scripts/mode_theme.gd")

# Layout (1280x720): arena frame at x 270..1010, cards in the columns either side.
const ARENA_RECT := Rect2(280, 52, 720, 624)
const CARD_SIZE := Vector2(250, 322)
const CARD_SLOTS := [Vector2(10, 10), Vector2(1020, 388), Vector2(1020, 10), Vector2(10, 388)]  # = Arena.SPAWNS corners

var game
var root: Control
var timer_label: Label
var doom_label: Label
var cards: Array = []
var banner_label: Label
var toast_box: VBoxContainer
var controls_box: Control
var controls_hint: Label
var pause_panel: Control
var results_panel: Control
var _order: Array = []          # bears, best first (last announced ranking)
var _pending: Array = []        # candidate new order and how long it has held
var _pending_t := 0.0
var _announce_cd := 0.0


## One player's card: rank, name, big portrait, score beneath it (blinks while
## someone is pulling its stuffing out), fluff bar and a one-word status.
class BearCard extends Control:
	var bear
	var hud
	var font: Font
	var shown := 100.0
	var rank := 1
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		shown = lerpf(shown, bear.fluff, 1.0 - exp(-delta * 10.0))
		queue_redraw()

	func being_robbed() -> bool:
		for b in bear.game.bears:
			if b != bear and b.stealing and b.steal_target == bear:
				return true
		return false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, UiStyle.PAPER)
		draw_rect(Rect2(0, 0, size.x, 8), bear.color)
		UiStyle.stitch_rect(self, r.grow(-5), Color(bear.color.darkened(0.2), 0.75), 1.4, 5.0)
		# rank badge (a little crown for the leader)
		var bc := Vector2(30, 34)
		draw_circle(bc, 17.0, UiStyle.ROSE_DARK if rank == 1 else UiStyle.BAR)
		draw_string(font, bc + Vector2(-17, 7), "#%d" % rank, HORIZONTAL_ALIGNMENT_CENTER, 34, 17,
			UiStyle.PAPER if rank == 1 else UiStyle.INK)
		if rank == 1:
			var cr := bc + Vector2(0, -21)
			draw_colored_polygon(PackedVector2Array([cr + Vector2(-9, 4), cr + Vector2(-9, -4), cr + Vector2(-4, 0),
				cr + Vector2(0, -7), cr + Vector2(4, 0), cr + Vector2(9, -4), cr + Vector2(9, 4)]), UiStyle.GOLD)
		# name and who's playing it
		draw_string(font, Vector2(52, 34), bear.bear_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 70, 22, UiStyle.INK)
		draw_string(font, Vector2(12, 58), bear.ctrl_label, HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, 13, UiStyle.INK_SOFT)
		# the character's own head and face, growing a little with its stuffing
		var g: float = clampf(shown / Tuning.START_FLUFF, 0.0, 5.0)
		var robbed := being_robbed()
		var face_i := 3 if bear.is_stunned() else (1 if bear.stealing else (2 if robbed or bear.robbed_t > 0.0 else 0))
		var wob := Vector2(sin(t * 40.0), 0) * 2.0 if robbed else Vector2.ZERO
		var fit := BearVisual.fit_portrait(bear.species, Rect2(16, 66, size.x - 32, 128), 38.0 + 6.0 * sqrt(g))
		BearVisual.draw_portrait(self, fit[1] + wob, fit[0], bear.species, bear.color, face_i)
		# the score, right beneath the portrait
		var blink := robbed and fmod(t * 6.0, 1.0) < 0.5
		var sc := UiStyle.ROSE_DARK if blink else UiStyle.INK
		var fs := 46 if not blink else 50
		draw_string(font, Vector2(0, 238), "%d" % roundi(shown), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, sc)
		draw_string(font, Vector2(0, 256), "fluff", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, UiStyle.INK_SOFT)
		# fluff bar: towards the instant-win line when that's on
		var goal: float = Settings.instant_win if Settings.instant_win > 0.0 else Tuning.START_FLUFF * 4.0
		var bar := Rect2(20, 266, size.x - 40, 14)
		draw_rect(bar, UiStyle.BAR)
		var frac := clampf(shown / goal, 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), bear.color.darkened(0.08))
		var start_x := bar.position.x + bar.size.x * clampf(Tuning.START_FLUFF / goal, 0.0, 1.0)
		draw_rect(Rect2(start_x, bar.position.y, 1.5, bar.size.y), Color(UiStyle.INK, 0.35))
		draw_rect(bar, Color(UiStyle.INK, 0.35), false, 1.0)
		if Settings.instant_win > 0.0:
			draw_string(font, Vector2(bar.position.x, bar.end.y + 13), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.INK_SOFT)
			draw_string(font, Vector2(bar.position.x, bar.end.y + 13), "%d wins" % int(goal), HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x, 11, UiStyle.INK_SOFT)
		# status (no power-up info: that's what the pickup pops are for)
		var status := ""
		var scol := UiStyle.INK_SOFT
		if bear.is_stunned():
			status = "stunned!"
			scol = UiStyle.ROSE_DARK
		elif robbed:
			status = "being robbed!"
			scol = UiStyle.ROSE_DARK if blink else UiStyle.INK
		elif bear.stealing:
			status = "stealing stuffing..."
			scol = UiStyle.GOOD
		elif g > 2.5:
			status = "dangerously huggable"
		elif g < 0.4:
			status = "sadly deflated"
		draw_string(font, Vector2(0, 310), status, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, scol)


func setup(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.theme = UiStyle.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Time of Doom, centred above the arena
	doom_label = UiStyle.label("Time of Doom", 16, UiStyle.ROSE_DARK)
	doom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	doom_label.position = Vector2(ARENA_RECT.position.x, 6)
	doom_label.size = Vector2(ARENA_RECT.size.x * 0.5 - 8, 34)
	doom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(doom_label)
	timer_label = UiStyle.label("2:30", 34)
	timer_label.position = Vector2(ARENA_RECT.get_center().x, 0)
	timer_label.size = Vector2(200, 42)
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(timer_label)
	var arena_name := UiStyle.label(Maps.MAPS[Settings.arena_index]["name"], 14, UiStyle.INK_SOFT)
	arena_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arena_name.position = Vector2(ARENA_RECT.end.x - 230, 12)
	arena_name.size = Vector2(230, 24)
	root.add_child(arena_name)

	for i in game.bears.size():
		var c := BearCard.new()
		c.bear = game.bears[i]
		c.hud = self
		c.font = UiStyle.font()
		c.position = CARD_SLOTS[i % CARD_SLOTS.size()]
		c.size = CARD_SIZE
		root.add_child(c)
		cards.append(c)
	_order = game.bears.duplicate()
	_update_ranks()

	# little title + music note in the gaps between the cards
	var title := UiStyle.label("Fluffy Bears of Doom", 20, UiStyle.ROSE_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(1020, 342)
	title.size = Vector2(250, 40)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(title)
	var np := NowPlaying.new()
	np.position = Vector2(10, 349)
	np.size = Vector2(250, 26)
	root.add_child(np)

	# controls: their own strip under the arena, hideable with H
	controls_box = Control.new()
	controls_box.position = Vector2(ARENA_RECT.position.x - 10, 688)
	controls_box.size = Vector2(ARENA_RECT.size.x + 20, 32)
	controls_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(controls_box)
	var help := UiStyle.label(_controls_text(), 12, UiStyle.INK_SOFT)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.set_anchors_preset(Control.PRESET_FULL_RECT)
	help.add_theme_constant_override("line_spacing", -3)
	controls_box.add_child(help)
	controls_hint = UiStyle.label("H: show controls", 12, Color(UiStyle.INK_SOFT, 0.7))
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint.position = controls_box.position + Vector2(0, 8)
	controls_hint.size = controls_box.size
	root.add_child(controls_hint)
	_apply_controls_visibility()

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


func _controls_text() -> String:
	var p1 := "P1: WASD / Space (bomb) / Left Shift (steal) / E (special)"
	var p2 := "P2: Arrows / Enter (bomb) / Right Ctrl (steal) / R (special)"
	if Settings.human_count == 1:   # a lone player can use either layout
		return "%s   ·   Esc pause   ·   N next song\n%s   ·   both work for you   ·   H hide" % [p1, p2]
	return "%s   ·   Esc pause   ·   N next song\n%s   ·   H hide" % [p1, p2]


func _apply_controls_visibility() -> void:
	controls_box.visible = Settings.show_controls
	controls_hint.visible = not Settings.show_controls


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_controls"):
		Settings.show_controls = not Settings.show_controls
		Settings.save()
		_apply_controls_visibility()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if game == null:
		return
	var t: float = maxf(game.time_left, 0.0)
	timer_label.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	var doom_on: bool = game.doom != null and game.round_duration - t >= game.round_duration * Tuning.DOOM_START
	var warn: bool = game.doom != null and game.doom.warning_active()
	var pulse := fmod(Time.get_ticks_msec() / 1000.0 * (6.0 if warn else 2.0), 1.0) > 0.5
	timer_label.add_theme_color_override("font_color", UiStyle.ROSE_DARK if ((t < 10.0 or warn) and pulse and game.controls_enabled()) else UiStyle.INK)
	doom_label.text = "THE ARENA CLOSES  ·  Time of Doom" if warn else ("Time of Doom" if not doom_on else "Doom is here  ·  Time of Doom")
	doom_label.add_theme_color_override("font_color", UiStyle.ROSE_DARK if (doom_on or warn) else UiStyle.INK_SOFT)
	if game.controls_enabled():
		_track_ranks(delta)
	_update_ranks()   # ties can break without the order changing


# --- ranking ------------------------------------------------------------------------

func _sorted_bears() -> Array:
	var order: Array = _order.duplicate()
	# stable sort: equal fluff keeps the previous order (no flicker on ties)
	var idx := {}
	for i in order.size():
		idx[order[i]] = i
	order.sort_custom(func(a, b):
		if absf(a.fluff - b.fluff) > 0.5:
			return a.fluff > b.fluff
		return idx[a] < idx[b])
	return order


func _update_ranks() -> void:
	var place := 1
	for i in _order.size():
		if i > 0 and absf(_order[i].fluff - _order[i - 1].fluff) >= 0.5:
			place = i + 1
		for c in cards:
			if c.bear == _order[i]:
				c.rank = place


## Ranks update at once on the cards; an overtake is announced once the new
## order has held for a moment (stealing makes scores swap back and forth).
func _track_ranks(delta: float) -> void:
	_announce_cd -= delta
	var now := _sorted_bears()
	if now == _order:
		_pending.clear()
		return
	if now != _pending:
		_pending = now
		_pending_t = 0.0
		return
	_pending_t += delta
	if _pending_t < 0.35:
		return
	var before := _order
	_order = now
	_pending.clear()
	_update_ranks()
	# who moved up, and past whom?
	for i in now.size():
		var b = now[i]
		var old_i: int = before.find(b)
		if old_i <= i:
			continue
		var passed = before[i]   # whoever used to hold the place it took
		if _announce_cd > 0.0:
			break
		_announce_cd = 1.2
		if i == 0:
			toast("%s takes the lead!" % b.bear_name, b.color)
		else:
			toast("%s overtakes %s  (#%d)" % [b.bear_name, passed.bear_name, i + 1], b.color)
		Sfx.play("overtake", 1.0 + 0.1 * (3 - i), -3.0)
		break


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
