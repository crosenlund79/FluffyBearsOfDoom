## Title menu: players, AI difficulty, arena, round length, audio, controls.
extends Control

signal start_requested
signal mode_changed
signal tournament_requested
signal spectate_requested
signal leaderboards_requested

const UiStyle = preload("res://scripts/ui_style.gd")
const StitchPanel = preload("res://scripts/stitch_panel.gd")
const AudioPanel = preload("res://scripts/audio_panel.gd")
const BearVisual = preload("res://scripts/bear_visual.gd")
const Maps = preload("res://scripts/arena_maps.gd")
const Mode = preload("res://scripts/mode_theme.gd")
const NowPlaying = preload("res://scripts/now_playing.gd")
const Species = preload("res://scripts/species.gd")
const Powerup = preload("res://scripts/powerup.gd")
const ControlsPanel = preload("res://scripts/controls_panel.gd")

var puppets: Array = []
var holders: Array = []
var t := 0.0
var map_desc: Label
var start_button: Button
var sit_row: Control
var overlay: Control


func _ready() -> void:
	theme = UiStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)

	var title := UiStyle.label("Fluffy Horror Bears", 64, UiStyle.ROSE_DARK)
	title.add_theme_color_override("font_outline_color", UiStyle.PAPER)
	title.add_theme_constant_override("outline_size", 12)
	title.position = Vector2(48, 40)
	add_child(title)
	var sub := UiStyle.label(Mode.text(Mode.SUBTITLE), 22, UiStyle.INK_SOFT)
	sub.position = Vector2(54, 124)
	add_child(sub)

	# A parade of bears at different stuffing levels, waddling back and forth.
	var fluffs := [25.0, 100.0, 210.0, 360.0]
	var names := ["Player", "Oswald", "Harald", "Theodor"]
	var colors := [Settings.HUMAN_COLORS[0]] + Settings.AI_COLORS
	for i in 4:
		var holder := Node2D.new()
		holder.position = Vector2(110 + i * 150, 430)
		holder.scale = Vector2(1.6, 1.6)
		add_child(holder)
		var p := BearVisual.Puppet.new()
		p.fluff = fluffs[i]
		var vis := BearVisual.new()
		vis.species = Species.for_name(names[i])
		vis.source = p
		vis.tint = Mode.bear_color(colors[i])
		vis.seed_offset = i * 2.0
		holder.add_child(vis)
		puppets.append(p)
		holders.append(holder)
		var cap := UiStyle.label("%s\n%s" % [names[i], Species.label(Species.for_name(names[i]))], 16, UiStyle.INK_SOFT)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.position = Vector2(30 + i * 150, 470)
		cap.size = Vector2(160, 50)
		add_child(cap)

	var blurb := UiStyle.label(Mode.text(Mode.BLURB), 16, UiStyle.INK)
	blurb.position = Vector2(54, 560)
	blurb.size = Vector2(640, 60)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(blurb)

	var panel := StitchPanel.new()
	panel.position = Vector2(740, 70)
	panel.size = Vector2(500, 590)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	# Normal / Horror / Custom: same game, different nursery. Switches immediately.
	# Custom = your own sprites from assets/sprites/<folder>/custom/, Normal for the rest.
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	mrow.add_child(_fixed(UiStyle.label("Mode", 24, UiStyle.ROSE_DARK), 110))
	var group := ButtonGroup.new()
	for m in [["Normal", "normal"], ["Horror", "horror"], ["Custom", "custom"]]:
		var mb := Button.new()
		mb.text = m[0]
		mb.toggle_mode = true
		mb.button_group = group
		mb.button_pressed = Settings.mode == m[1]
		mb.custom_minimum_size = Vector2(96, 38)
		if m[1] == "custom":
			mb.tooltip_text = "Your own sprites from assets/sprites/<folder>/custom/ (Normal art where none exists)"
		var mode_id: String = m[1]
		mb.pressed.connect(func(): _set_mode(mode_id))
		mrow.add_child(mb)
	v.add_child(mrow)

	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	prow.add_child(_fixed(UiStyle.label("Players", 24, UiStyle.ROSE_DARK), 140))
	var mode := OptionButton.new()
	mode.add_item("One Human")
	mode.add_item("Two Humans")
	mode.add_item("Pure AI (watch)")   # every bear AI-controlled
	mode.selected = [2, 0, 1][clampi(Settings.human_count, 0, 2)]
	mode.custom_minimum_size = Vector2(220, 38)
	mode.item_selected.connect(func(idx):
		Settings.human_count = [1, 2, 0][idx]
		_refresh()
		Settings.save())
	prow.add_child(mode)
	v.add_child(prow)

	v.add_child(UiStyle.label("Opponents", 22, UiStyle.ROSE_DARK))
	for i in Settings.AI_NAMES.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var sw := ColorRect.new()
		sw.color = Mode.bear_color(Settings.AI_COLORS[i])
		sw.custom_minimum_size = Vector2(22, 22)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var who := UiStyle.label(Settings.AI_NAMES[i], 20)
		who.tooltip_text = Species.label(Species.for_name(Settings.AI_NAMES[i]))
		row.add_child(_fixed(who, 120))
		var ob := OptionButton.new()
		for lbl in Settings.LEVEL_LABELS:
			ob.add_item(lbl)
		ob.selected = Settings.LEVELS.find(Settings.ai_levels[i])
		ob.custom_minimum_size = Vector2(170, 36)
		ob.item_selected.connect(func(idx):
			Settings.ai_levels[i] = Settings.LEVELS[idx]
			Settings.save())
		row.add_child(ob)
		v.add_child(row)
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 12)
	sr.add_child(_fixed(UiStyle.label("Sitting out", 18, UiStyle.INK_SOFT), 154))
	var sit := OptionButton.new()
	for n in Settings.AI_NAMES:
		sit.add_item(n)
	sit.selected = Settings.sitting_out
	sit.custom_minimum_size = Vector2(170, 36)
	sit.item_selected.connect(func(idx):
		Settings.sitting_out = idx
		Settings.save())
	sr.add_child(sit)
	sit_row = sr
	v.add_child(sr)

	v.add_child(UiStyle.label("Arena", 22, UiStyle.ROSE_DARK))
	var arena_ob := OptionButton.new()
	for m in Maps.MAPS:
		arena_ob.add_item(m["name"])
	arena_ob.selected = Settings.arena_index
	arena_ob.custom_minimum_size = Vector2(0, 36)
	v.add_child(arena_ob)
	map_desc = UiStyle.label(Maps.MAPS[Settings.arena_index]["desc"], 15, UiStyle.INK_SOFT)
	map_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_desc.custom_minimum_size = Vector2(440, 40)
	v.add_child(map_desc)
	arena_ob.item_selected.connect(func(idx):
		Settings.arena_index = idx
		map_desc.text = Maps.MAPS[idx]["desc"]
		Settings.save())

	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 12)
	trow.add_child(_fixed(UiStyle.label("Round length", 20), 140))
	var time_ob := OptionButton.new()
	for lbl in ["1:30", "2:30", "4:00"]:
		time_ob.add_item(lbl)
	time_ob.selected = Settings.round_time_index
	time_ob.item_selected.connect(func(idx):
		Settings.round_time_index = idx
		Settings.save())
	trow.add_child(time_ob)
	v.add_child(trow)

	start_button = Button.new()
	start_button.text = "Start Game"
	start_button.custom_minimum_size = Vector2(0, 54)
	start_button.add_theme_font_size_override("font_size", 26)
	start_button.pressed.connect(func():
		Sfx.play("go")
		start_requested.emit())
	v.add_child(start_button)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in [["Settings", _show_audio], ["Controls", _show_controls], ["Power-ups", _show_powerups], ["Quit", func(): get_tree().quit()]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(104, 40)
		btn.pressed.connect(b[1])
		brow.add_child(btn)
	v.add_child(brow)
	var tour_row := HBoxContainer.new()
	tour_row.add_theme_constant_override("separation", 10)
	tour_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in [["Tournament", func(): tournament_requested.emit()], ["Watch AI", func(): spectate_requested.emit()], ["Leaderboards", func(): leaderboards_requested.emit()]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(140, 40)
		btn.pressed.connect(b[1])
		tour_row.add_child(btn)
	v.add_child(tour_row)

	var np := NowPlaying.new()
	np.position = Vector2(54, 664)
	np.size = Vector2(640, 26)
	add_child(np)

	for c in _all_buttons(panel):
		c.focus_entered.connect(func(): Sfx.play("menu", 1.0, -8.0))
	_refresh()
	start_button.grab_focus()
	Music.play_context("menu")


func _set_mode(m: String) -> void:
	if m == Settings.mode:
		return
	Settings.set_mode(m)
	Settings.save()
	Sfx.play("mode")
	mode_changed.emit()  # main rebuilds the menu in the new look; music switches


func _fixed(c: Control, w: float) -> Control:
	c.custom_minimum_size = Vector2(w, 0)
	return c


func _all_buttons(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is BaseButton:
			out.append(c)
		out.append_array(_all_buttons(c))
	return out


func _refresh() -> void:
	sit_row.visible = Settings.human_count == 2


func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	start_button.grab_focus()


func _show_audio() -> void:
	_close_overlay()
	Sfx.play("menu")
	var ap := AudioPanel.new()
	ap.position = Vector2(420, 150)
	add_child(ap)
	ap.closed.connect(func():
		overlay = null
		start_button.grab_focus())
	overlay = ap


func _show_controls() -> void:
	_close_overlay()
	Sfx.play("menu")
	var p = ControlsPanel.new()
	p.position = Vector2(290, 80)
	add_child(p)
	p.closed.connect(func():
		overlay = null
		start_button.grab_focus())
	overlay = p


## Every power-up with its badge (current mode's art), name and effect.
func _show_powerups() -> void:
	_close_overlay()
	Sfx.play("menu")
	var p := StitchPanel.new()
	p.position = Vector2(140, 100)
	p.size = Vector2(1000, 500)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UiStyle.label("Power-ups", 30, UiStyle.ROSE_DARK))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	for k in Powerup.OVERVIEW:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := PowerupIcon.new()
		icon.kind = k
		row.add_child(icon)
		var txt := VBoxContainer.new()
		txt.add_theme_constant_override("separation", 0)
		var bad: bool = k in Powerup.BAD
		txt.add_child(UiStyle.label(Powerup.NAMES[k], 18,
			UiStyle.CURSE if bad else UiStyle.INK))
		var d := UiStyle.label(Powerup.DESC[k], 14, UiStyle.INK_SOFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(390, 0)
		txt.add_child(d)
		row.add_child(txt)
		grid.add_child(row)
	v.add_child(grid)
	var close := Button.new()
	close.text = "Done"
	close.pressed.connect(_close_overlay)
	v.add_child(close)
	close.grab_focus()
	overlay = p


## A power-up badge for the overview (same art and antenna as in the arena).
class PowerupIcon extends Control:
	var kind := 0
	var t := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(46, 46)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col: Color = Powerup.glow_color(kind)
		draw_circle(c, 22.0, Color(col.r, col.g, col.b, 0.18))
		Powerup.draw_badge(self, c, 40.0, kind, t)


func _process(delta: float) -> void:
	t += delta
	# waddle back and forth: heavier bears are slower and clumsier
	for i in puppets.size():
		var p = puppets[i]
		var g: float = p.fluff / 100.0
		var w := 1.4 / (0.6 + 0.4 * g)
		var amp := 34.0
		var x := sin(t * w + i) * amp
		var vx := cos(t * w + i) * amp * w
		holders[i].position.x = 110 + i * 150 + x
		p.velocity = Vector2(vx * 1.6, 0)
		p.facing = Vector2(signf(vx), 0) if absf(vx) > 12.0 else Vector2.DOWN
	queue_redraw()


func _draw() -> void:
	UiStyle.draw_wallpaper(self, Rect2(-position, get_viewport_rect().size))   # whole window, even ultrawide
	draw_rect(Rect2(40, 380, 640, 90), Color(UiStyle.FRAME, 0.8))
	UiStyle.stitch_rect(self, Rect2(46, 386, 628, 78), Color(UiStyle.ROSE_DARK, 0.6), 1.6, 6.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and overlay:
		_close_overlay()
		get_viewport().set_input_as_handled()
