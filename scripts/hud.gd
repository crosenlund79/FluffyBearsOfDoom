## In-match interface: timer, bear cards, banners, pause and results.
extends CanvasLayer

const UiStyle = preload("res://scripts/ui_style.gd")
const StitchPanel = preload("res://scripts/stitch_panel.gd")
const BearVisual = preload("res://scripts/bear_visual.gd")
const Tuning = preload("res://scripts/tuning.gd")
const Maps = preload("res://scripts/arena_maps.gd")
const AudioPanel = preload("res://scripts/audio_panel.gd")

var game
var root: Control
var timer_label: Label
var cards: Array = []
var banner_label: Label
var toast_box: VBoxContainer
var pause_panel: Control
var results_panel: Control


## A compact stitched card per bear: face, name, fluff, stats and state.
class BearCard extends Control:
	var bear
	var font: Font
	var icons: Texture2D
	var shown := 100.0

	func _ready() -> void:
		custom_minimum_size = Vector2(440, 104)
		icons = Assets.tex("powerups/powerups")

	func _process(delta: float) -> void:
		shown = lerpf(shown, bear.fluff, 1.0 - exp(-delta * 10.0))
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := Color("fbf5e8")
		draw_rect(r, bg)
		draw_rect(Rect2(0, 0, 8, size.y), bear.color)
		UiStyle.stitch_rect(self, r.grow(-5), Color(bear.color.darkened(0.2), 0.7), 1.4, 5.0)
		# little bear face
		var c := Vector2(48, 52)
		var g: float = clampf(shown / Tuning.START_FLUFF, 0.0, 5.0)
		var rad := 18.0 + 3.0 * sqrt(g)
		draw_circle(c + Vector2(-rad * 0.75, -rad * 0.72), rad * 0.38, bear.color)
		draw_circle(c + Vector2(rad * 0.75, -rad * 0.72), rad * 0.38, bear.color)
		draw_circle(c, rad, bear.color)
		draw_circle(c + Vector2(0, rad * 0.35), rad * 0.42, Color("f7ead8"))
		var eye_y := c.y - rad * 0.15
		if bear.is_stunned():
			for ex in [-1.0, 1.0]:
				var e := Vector2(c.x + ex * rad * 0.4, eye_y)
				draw_line(e - Vector2(3, 3), e + Vector2(3, 3), UiStyle.INK, 2.0)
				draw_line(e - Vector2(3, -3), e + Vector2(3, -3), UiStyle.INK, 2.0)
		else:
			draw_circle(Vector2(c.x - rad * 0.4, eye_y), 2.8, UiStyle.INK)
			draw_circle(Vector2(c.x + rad * 0.4, eye_y), 2.8, UiStyle.INK)
		draw_circle(c + Vector2(0, rad * 0.25), 2.6, Color("4a3127"))
		# name + controller
		draw_string(font, Vector2(84, 32), bear.bear_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.INK)
		var who: String = bear.ctrl_label
		draw_string(font, Vector2(84, 52), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.INK_SOFT)
		# fluff
		draw_string(font, Vector2(size.x - 220, 40), "%d" % roundi(shown), HORIZONTAL_ALIGNMENT_RIGHT, 200, 30, UiStyle.INK)
		draw_string(font, Vector2(size.x - 220, 58), "fluff", HORIZONTAL_ALIGNMENT_RIGHT, 200, 13, UiStyle.INK_SOFT)
		var bar := Rect2(84, 64, size.x - 170, 10)
		draw_rect(bar, Color("eadfcb"))
		var frac := clampf(shown / (Tuning.START_FLUFF * 4.0), 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), bear.color)
		draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.25, 0), Vector2(1, bar.size.y)), Color(0.4, 0.3, 0.25, 0.4))
		# stats: bombs ready/capacity, blast range, speed, then owned abilities
		var x := 84.0
		var vals := ["%d/%d" % [bear.bombs_max - bear.active_bombs, bear.bombs_max], str(bear.bomb_range), str(bear.speed_level)]
		for i in 3:
			draw_texture_rect_region(icons, Rect2(x, 77, 20, 20), Assets.region(icons, Assets.POWERUP_CELLS, i))
			draw_string(font, Vector2(x + 22, 93), vals[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiStyle.INK)
			x += 58.0 if i == 0 else 44.0
		for ab in [[bear.can_kick, 4], [bear.has_line, 5], [bear.has_rubber, 6]]:
			if ab[0]:
				draw_texture_rect_region(icons, Rect2(x, 77, 20, 20), Assets.region(icons, Assets.POWERUP_CELLS, ab[1]))
				x += 23.0
		var status := ""
		var scol := UiStyle.INK_SOFT
		var timed := []
		if bear.immortal_t > 0.0:
			timed.append("immortal %ds" % ceili(bear.immortal_t))
		if bear.reverse_t > 0.0:
			timed.append("reversed %ds" % ceili(bear.reverse_t))
		if bear.diarrhea_t > 0.0:
			timed.append("bomb diarrhea %ds" % ceili(bear.diarrhea_t))
		if bear.is_stunned():
			status = "stunned!"
			scol = UiStyle.ROSE_DARK
		elif bear.stealing:
			status = "stealing stuffing..."
			scol = Color("6c8f5e")
		elif bear.robbed_t > 0.0:
			status = "robbed!!"
			scol = UiStyle.ROSE_DARK
		elif not timed.is_empty():
			status = " · ".join(timed)
			scol = Color("b08a2e") if bear.immortal_t > 0.0 and timed.size() == 1 else Color("7a5a8c")
		elif g > 2.5:
			status = "dangerously huggable"
		elif g < 0.4:
			status = "sadly deflated"
		draw_string(font, Vector2(size.x - 230, 93), status, HORIZONTAL_ALIGNMENT_RIGHT, 210, 13, scol)


func setup(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.theme = UiStyle.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var side := VBoxContainer.new()
	side.position = Vector2(800, 18)
	side.size = Vector2(450, 690)
	side.add_theme_constant_override("separation", 8)
	root.add_child(side)
	var title := UiStyle.label("Fluffy Bears of Doom", 30, UiStyle.ROSE_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(title)
	var sub := UiStyle.label(Maps.MAPS[Settings.arena_index]["name"], 16, UiStyle.INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(sub)
	timer_label = UiStyle.label("2:30", 40)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(timer_label)
	for b in game.bears:
		var c := BearCard.new()
		c.bear = b
		c.font = UiStyle.font()
		side.add_child(c)
		cards.append(c)
	var help := UiStyle.label(_controls_text(), 13, UiStyle.INK_SOFT)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(help)

	banner_label = UiStyle.label("", 64, UiStyle.ROSE_DARK)
	banner_label.add_theme_color_override("font_outline_color", Color("fbf5e8"))
	banner_label.add_theme_constant_override("outline_size", 14)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.position = Vector2(40, 260)
	banner_label.size = Vector2(720, 120)
	banner_label.pivot_offset = banner_label.size * 0.5
	banner_label.modulate.a = 0.0
	root.add_child(banner_label)

	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(40, 600)
	toast_box.size = Vector2(720, 80)
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)


func _controls_text() -> String:
	if Settings.human_count == 1:
		return "Move WASD/Arrows · Bomb Space/Enter · Steal (hold) L-Shift/R-Ctrl\nLine Bomb E/R-Shift · Pause Esc · Next song N"
	return "P1: WASD · Space bomb · L-Shift steal · E line bomb\nP2: Arrows · Enter bomb · R-Ctrl steal · R-Shift line bomb · Esc pause"


func _process(_delta: float) -> void:
	if game == null:
		return
	var t: float = maxf(game.time_left, 0.0)
	timer_label.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	if t < 10.0 and game.controls_enabled():
		timer_label.add_theme_color_override("font_color", UiStyle.ROSE_DARK if fmod(t, 1.0) > 0.5 else UiStyle.INK)


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
	l.add_theme_color_override("font_outline_color", Color("fbf5e8"))
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
	p.position = Vector2(400, 364) - sz * 0.5
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
	v.add_child(_button("Audio settings", func():
		var ap = AudioPanel.new()
		ap.position = Vector2(180, 160)
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


func show_results(ranking: Array) -> void:
	results_panel = _panel(Vector2(640, 470))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	results_panel.add_child(v)
	var winner = ranking[0]
	var tie: bool = ranking.size() > 1 and absf(ranking[1].fluff - winner.fluff) < 0.5
	var title := UiStyle.label("Time's up!", 24, UiStyle.INK_SOFT)
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
