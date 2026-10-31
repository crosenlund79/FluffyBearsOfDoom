## Match settings chosen in the menu + input bindings for up to four humans.
extends Node

const NAMES := ["Player", "Oswald", "Harald", "Theodor"]
const COLORS := [Color("d9a66b"), Color("8eaecb"), Color("a3bf8c"), Color("c39bcb")]
const CONTROLLERS := ["human", "easy", "normal", "hard"]
const CONTROLLER_LABELS := ["Human", "AI: Easy", "AI: Normal", "AI: Hard"]

# One entry per slot: "human", "easy", "normal" or "hard".
var slots: Array = ["human", "normal", "normal", "normal"]
var arena_index := 0
var round_time_index := 1

const ACTIONS := ["up", "down", "left", "right", "bomb", "steal"]

# Keyboard schemes per human player (physical keys, layout independent).
const KEYS := [
	{"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D], "bomb": [KEY_SPACE], "steal": [KEY_E, -KEY_SHIFT]},
	{"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT], "bomb": [KEY_ENTER, KEY_KP_ENTER], "steal": [KEY_SHIFT]},
	{"up": [KEY_I], "down": [KEY_K], "left": [KEY_J], "right": [KEY_L], "bomb": [KEY_O], "steal": [KEY_U]},
	{"up": [KEY_KP_8], "down": [KEY_KP_5], "left": [KEY_KP_4], "right": [KEY_KP_6], "bomb": [KEY_KP_0], "steal": [KEY_KP_PERIOD]},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		_add_key("pause", KEY_ESCAPE)
		_add_key("pause", KEY_P)
		var jb := InputEventJoypadButton.new()
		jb.button_index = JOY_BUTTON_START
		jb.device = -1
		InputMap.action_add_event("pause", jb)
	apply_input_bindings()


func human_slots() -> Array:
	var out := []
	for i in slots.size():
		if slots[i] == "human":
			out.append(i)
	return out


## Which input schemes ("p1".."p4") a human in `slot` listens to.
func schemes_for_slot(slot: int) -> Array:
	var humans := human_slots()
	if humans.size() == 1:
		return ["p1", "p2"]  # a lone human may use WASD or arrows
	var idx := humans.find(slot)
	return ["p%d" % (idx + 1)]


func apply_input_bindings() -> void:
	var solo := human_slots().size() <= 1
	for p in 4:
		for a in ACTIONS:
			var action := "p%d_%s" % [p + 1, a]
			if InputMap.has_action(action):
				InputMap.erase_action(action)
			InputMap.add_action(action, 0.4)
			# Right/left shift are told apart by key location (negative = left).
			for k in KEYS[p][a]:
				var ev := InputEventKey.new()
				ev.physical_keycode = absi(k)
				if k == KEY_SHIFT:
					ev.location = KEY_LOCATION_RIGHT
				elif k == -KEY_SHIFT:
					ev.location = KEY_LOCATION_LEFT
				InputMap.action_add_event(action, ev)
			var device := -1 if solo else p
			if solo and p > 0:
				continue  # the solo player's pad is bound once, via p1
			_add_pad(action, a, device)


func _add_pad(action: String, a: String, device: int) -> void:
	var buttons := {"up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN], "left": [JOY_BUTTON_DPAD_LEFT],
		"right": [JOY_BUTTON_DPAD_RIGHT], "bomb": [JOY_BUTTON_A], "steal": [JOY_BUTTON_X, JOY_BUTTON_B]}
	for b in buttons[a]:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		jb.device = device
		InputMap.action_add_event(action, jb)
	var axes := {"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0], "left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0]}
	if axes.has(a):
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[a][0]
		jm.axis_value = axes[a][1]
		jm.device = device
		InputMap.action_add_event(action, jm)
	if a == "steal":
		var jt := InputEventJoypadMotion.new()
		jt.axis = JOY_AXIS_TRIGGER_RIGHT
		jt.axis_value = 1.0
		jt.device = device
		InputMap.action_add_event(action, jt)


func _add_key(action: String, key: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
