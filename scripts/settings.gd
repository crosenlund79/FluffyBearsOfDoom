## Match setup, input bindings and saved audio preferences.
extends Node

const AI_NAMES := ["Oswald", "Harald", "Theodor"]
const AI_COLORS := [Color("8eaecb"), Color("a3bf8c"), Color("c39bcb")]
const HUMAN_COLORS := [Color("d9a66b"), Color("e3a1a8")]
const LEVELS := ["easy", "normal", "hard"]
const LEVEL_LABELS := ["Easy", "Normal", "Hard"]
const SAVE_PATH := "user://settings.cfg"

var human_count := 1
var ai_levels := ["normal", "normal", "normal"]  # per AI_NAMES
var sitting_out := 2                              # which AI sits out in two-human mode
var arena_index := 0
var round_time_index := 1

# Audio (0..1)
var master_volume := 0.9
var music_volume := 0.6
var sfx_volume := 0.85
var muted := false
var shuffle_music := true
var bear_outlines := true  # dark outline around bears for visibility
var instant_win: float = preload("res://scripts/tuning.gd").INSTANT_WIN_FLUFF   # fluff that ends a round at once (0 = off)
var show_controls := true  # the in-match controls strip (H toggles it; player stats always stay)
const MODES := ["normal", "horror", "custom"]
var mode := "normal"  # "normal", "horror" or "custom": same gameplay, different look (and sound)

const ACTIONS := ["up", "down", "left", "right", "bomb", "steal", "special"]
# Keys per scheme. Negative values = left-hand key location, positive modifiers = right-hand.
const KEYS := [
	{"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D], "bomb": [KEY_SPACE], "steal": [-KEY_SHIFT], "special": [KEY_E]},
	{"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT], "bomb": [KEY_ENTER, KEY_KP_ENTER], "steal": [KEY_CTRL], "special": [KEY_R, KEY_SHIFT]},
]
const MODIFIERS := [KEY_SHIFT, KEY_CTRL, KEY_ALT]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	set_mode(mode)
	_ensure_buses()
	apply_audio()
	for a in [["pause", [KEY_ESCAPE, KEY_P], JOY_BUTTON_START], ["next_track", [KEY_N], JOY_BUTTON_BACK], ["toggle_controls", [KEY_H], JOY_BUTTON_RIGHT_STICK]]:
		if InputMap.has_action(a[0]):
			continue
		InputMap.add_action(a[0])
		for k in a[1]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a[0], ev)
		var jb := InputEventJoypadButton.new()
		jb.button_index = a[2]
		jb.device = -1
		InputMap.action_add_event(a[0], jb)
	apply_input_bindings()


## The four bears of the next match: [{name, color, controller, schemes}].
func roster() -> Array:
	var out := []
	if human_count == 0:  # demo / smoke test: a Hard AI plays the player's bear
		out.append({"name": "Player", "color": HUMAN_COLORS[0], "controller": "hard", "schemes": []})
	elif human_count == 1:
		out.append({"name": "Player", "color": HUMAN_COLORS[0], "controller": "human", "schemes": ["p1", "p2"]})
	else:
		out.append({"name": "Player 1", "color": HUMAN_COLORS[0], "controller": "human", "schemes": ["p1"]})
		out.append({"name": "Player 2", "color": HUMAN_COLORS[1], "controller": "human", "schemes": ["p2"]})
	for i in AI_NAMES.size():
		if human_count == 2 and i == sitting_out:
			continue
		out.append({"name": AI_NAMES[i], "color": AI_COLORS[i], "controller": ai_levels[i], "schemes": []})
	return out


func apply_input_bindings() -> void:
	var solo := human_count <= 1
	for p in 2:
		for a in ACTIONS:
			var action := "p%d_%s" % [p + 1, a]
			if InputMap.has_action(action):
				InputMap.erase_action(action)
			InputMap.add_action(action, 0.4)
			for k in KEYS[p][a]:
				var ev := InputEventKey.new()
				ev.physical_keycode = absi(k)
				if absi(k) in MODIFIERS:
					ev.location = KEY_LOCATION_LEFT if k < 0 else KEY_LOCATION_RIGHT
				InputMap.action_add_event(action, ev)
			if solo and p > 0:
				continue  # a lone player's pad (any device) is bound once, via p1
			_add_pad(action, a, -1 if solo else p)


func _add_pad(action: String, a: String, device: int) -> void:
	var buttons := {"up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN], "left": [JOY_BUTTON_DPAD_LEFT],
		"right": [JOY_BUTTON_DPAD_RIGHT], "bomb": [JOY_BUTTON_A], "steal": [JOY_BUTTON_X, JOY_BUTTON_B],
		"special": [JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER]}
	for b in buttons[a]:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		jb.device = device
		InputMap.action_add_event(action, jb)
	var axes := {"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0], "left": [JOY_AXIS_LEFT_X, -1.0],
		"right": [JOY_AXIS_LEFT_X, 1.0], "steal": [JOY_AXIS_TRIGGER_RIGHT, 1.0]}
	if axes.has(a):
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[a][0]
		jm.axis_value = axes[a][1]
		jm.device = device
		InputMap.action_add_event(action, jm)


func set_mode(m: String) -> void:
	mode = m if m in MODES else "normal"
	preload("res://scripts/ui_style.gd").apply_mode(style())


## The behaviour/audio/UI flavour of the current mode. Custom only swaps sprites
## (assets/sprites/<folder>/custom/); everything else plays exactly like Normal.
func style() -> String:
	return "horror" if mode == "horror" else "normal"


# --- audio ----------------------------------------------------------------------

func _ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


func apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))


func save() -> void:
	var cf := ConfigFile.new()
	for k in ["master_volume", "music_volume", "sfx_volume", "muted", "shuffle_music", "human_count",
			"ai_levels", "sitting_out", "arena_index", "round_time_index", "mode", "bear_outlines", "show_controls", "instant_win"]:
		cf.set_value("settings", k, get(k))
	cf.save(SAVE_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for k in cf.get_section_keys("settings"):
		if k in self:
			set(k, cf.get_value("settings", k))
