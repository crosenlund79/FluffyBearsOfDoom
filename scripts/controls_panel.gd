## Settings > Controls: every key can be remapped. Click a key, press the new
## one (Esc cancels). If that key belonged to another action they swap, so
## nothing is ever left unbound. Saved with the other settings.
extends "res://scripts/stitch_panel.gd"

signal closed

const LABELS := {"up": "Up", "down": "Down", "left": "Left", "right": "Right", "bomb": "Place bomb",
	"steal": "Steal fluff (hold)", "special": "Special (remote / Line Bomb)"}

var _buttons := {}        # action -> Button
var _waiting := ""        # action waiting for a key
var _note: Label
var _first: Button


func _ready() -> void:
	size = Vector2(700, 560)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UiStyle.label("Controls", 30, UiStyle.ROSE_DARK))
	v.add_child(UiStyle.label("Click a key, then press the new one (Esc cancels).", 15, UiStyle.INK_SOFT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	for h in ["", "Player 1", "Player 2"]:
		grid.add_child(UiStyle.label(h, 18, UiStyle.ROSE_DARK))
	for a in Settings.ACTIONS:
		grid.add_child(UiStyle.label(LABELS[a], 17))
		for p in ["p1_", "p2_"]:
			grid.add_child(_key_button(p + a))
	for g in [["pause", "Pause"], ["next_track", "Next song"]]:
		grid.add_child(UiStyle.label(g[1], 17))
		grid.add_child(_key_button(g[0]))
		grid.add_child(Control.new())
	v.add_child(grid)
	_note = UiStyle.label("Playing alone? Both layouts work for you. Gamepads: stick/d-pad, A bomb, X/B/RT steal, Y/LB special.", 14, UiStyle.INK_SOFT)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(640, 0)
	v.add_child(_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.pressed.connect(func():
		Settings.reset_bindings()
		_refresh()
		_note.text = "All keys are back to their defaults.")
	row.add_child(reset)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(160, 0)
	done.pressed.connect(func():
		Sfx.play("menu")
		closed.emit()
		queue_free())
	row.add_child(done)
	v.add_child(row)
	_refresh()
	_first.grab_focus()


func _key_button(action: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 32)
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(func(): _start_capture(action))
	_buttons[action] = b
	if _first == null:
		_first = b
	return b


func _refresh() -> void:
	for a in _buttons:
		var keys: Array = Settings.keys_for(a)
		_buttons[a].text = " / ".join(keys.map(func(k): return Settings.key_name(k))) if not keys.is_empty() else "(none)"


func _start_capture(action: String) -> void:
	Sfx.play("menu")
	_refresh()
	_waiting = action
	_buttons[action].text = "Press a key..."


func _input(event: InputEvent) -> void:
	if _waiting == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var action := _waiting
	_waiting = ""
	if event.physical_keycode == KEY_ESCAPE and action != "pause":
		_refresh()
		return
	var loc: int = event.location if event.physical_keycode in Settings.MODIFIERS else KEY_LOCATION_UNSPECIFIED
	var key := [int(event.physical_keycode), loc]
	var swapped := Settings.rebind(action, key)
	_refresh()
	_note.text = "%s is now %s." % [_pretty(action), Settings.key_name(key)]
	if swapped != "":
		_note.text += "  (It was used by %s, which now has %s.)" % [_pretty(swapped), _buttons[swapped].text]
	Sfx.play("pickup", 1.2, -4.0)


func _pretty(action: String) -> String:
	if action.begins_with("p1_") or action.begins_with("p2_"):
		return "Player %s %s" % [action[1], LABELS[action.substr(3)]]
	return "Pause" if action == "pause" else "Next song"
