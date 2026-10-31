## Title menu: choose controllers / AI difficulty per bear, arena and round length.
extends Control

signal start_requested

const UiStyle = preload("res://scripts/ui_style.gd")
const StitchPanel = preload("res://scripts/stitch_panel.gd")
const BearVisual = preload("res://scripts/bear_visual.gd")
const Maps = preload("res://scripts/arena_maps.gd")

var puppets: Array = []
var holders: Array = []
var t := 0.0
var map_desc: Label
var start_button: Button


func _ready() -> void:
	theme = UiStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)

	var title := UiStyle.label("Fluffy Bears of Doom", 64, UiStyle.ROSE_DARK)
	title.add_theme_color_override("font_outline_color", Color("fbf5e8"))
	title.add_theme_constant_override("outline_size", 12)
	title.position = Vector2(48, 40)
	add_child(title)
	var sub := UiStyle.label("Four adorable teddy bears. One finite supply of stuffing.", 22, UiStyle.INK_SOFT)
	sub.position = Vector2(54, 124)
	add_child(sub)

	# A parade of bears at different stuffing levels, waddling back and forth.
	var fluffs := [35.0, 100.0, 210.0, 360.0]
	for i in 4:
		var holder := Node2D.new()
		holder.position = Vector2(110 + i * 150, 430)
		holder.scale = Vector2(1.6, 1.6)
		add_child(holder)
		var p := BearVisual.Puppet.new()
		p.fluff = fluffs[i]
		var vis := BearVisual.new()
		vis.source = p
		vis.tint = Settings.COLORS[i]
		vis.seed_offset = i * 2.0
		holder.add_child(vis)
		puppets.append(p)
		holders.append(holder)
		var cap := UiStyle.label("%s\n%d fluff" % [Settings.NAMES[i], fluffs[i]], 16, UiStyle.INK_SOFT)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.position = Vector2(50 + i * 150, 470)
		cap.size = Vector2(120, 50)
		add_child(cap)

	var blurb := UiStyle.label("Bombs don't hurt - they stun. Hold Steal beside a stunned bear to pull out its fluff.\nThe more you steal, the rounder, wobblier and harder to stop you become.", 16, UiStyle.INK)
	blurb.position = Vector2(54, 560)
	blurb.size = Vector2(640, 60)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(blurb)

	var panel := StitchPanel.new()
	panel.position = Vector2(740, 150)
	panel.size = Vector2(500, 520)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var hdr := UiStyle.label("The Bears", 26, UiStyle.ROSE_DARK)
	v.add_child(hdr)
	for i in 4:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var sw := ColorRect.new()
		sw.color = Settings.COLORS[i]
		sw.custom_minimum_size = Vector2(22, 22)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var nl := UiStyle.label(Settings.NAMES[i], 20)
		nl.custom_minimum_size = Vector2(120, 0)
		row.add_child(nl)
		var ob := OptionButton.new()
		for lbl in Settings.CONTROLLER_LABELS:
			ob.add_item(lbl)
		ob.selected = Settings.CONTROLLERS.find(Settings.slots[i])
		ob.custom_minimum_size = Vector2(200, 38)
		ob.item_selected.connect(func(idx): Settings.slots[i] = Settings.CONTROLLERS[idx])
		row.add_child(ob)
		v.add_child(row)

	v.add_child(UiStyle.label("Arena", 22, UiStyle.ROSE_DARK))
	var arena_ob := OptionButton.new()
	for m in Maps.MAPS:
		arena_ob.add_item(m["name"])
	arena_ob.selected = Settings.arena_index
	arena_ob.custom_minimum_size = Vector2(0, 38)
	v.add_child(arena_ob)
	map_desc = UiStyle.label(Maps.MAPS[Settings.arena_index]["desc"], 15, UiStyle.INK_SOFT)
	map_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_desc.custom_minimum_size = Vector2(440, 40)
	v.add_child(map_desc)
	arena_ob.item_selected.connect(func(idx):
		Settings.arena_index = idx
		map_desc.text = Maps.MAPS[idx]["desc"])

	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 12)
	trow.add_child(UiStyle.label("Round length", 20))
	var time_ob := OptionButton.new()
	for lbl in ["1:30", "2:30", "4:00"]:
		time_ob.add_item(lbl)
	time_ob.selected = Settings.round_time_index
	time_ob.item_selected.connect(func(idx): Settings.round_time_index = idx)
	trow.add_child(time_ob)
	v.add_child(trow)

	start_button = Button.new()
	start_button.text = "Start the mayhem"
	start_button.custom_minimum_size = Vector2(0, 56)
	start_button.add_theme_font_size_override("font_size", 26)
	start_button.pressed.connect(func(): start_requested.emit())
	v.add_child(start_button)

	var ctl := UiStyle.label("Move WASD / Arrows · Bomb Space / Enter · Steal (hold) E / Shift · Pause Esc\nGamepad: stick / d-pad · A bomb · X, B or RT steal", 13, UiStyle.INK_SOFT)
	ctl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ctl.custom_minimum_size = Vector2(440, 0)
	v.add_child(ctl)
	start_button.grab_focus()


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
	UiStyle.draw_wallpaper(self, Rect2(Vector2.ZERO, size))
	# a rug for the parade
	draw_rect(Rect2(40, 380, 640, 90), Color(0.9, 0.82, 0.74, 0.8))
	UiStyle.stitch_rect(self, Rect2(46, 386, 628, 78), Color(0.7, 0.5, 0.48, 0.6), 1.6, 6.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and not start_button.has_focus():
		start_requested.emit()
