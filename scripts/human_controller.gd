## Reads one or more input schemes ("p1".."p4") into a bear's inputs.
extends RefCounted

var bear
var schemes: Array = []
var _last_axis := 0  # 0 = horizontal, 1 = vertical: the most recently pressed axis wins
var _prev := Vector2.ZERO


func _init(b, s: Array) -> void:
	bear = b
	schemes = s


func update(_delta: float) -> void:
	var v := Vector2.ZERO
	var bomb := false
	var steal := false
	for p in schemes:
		v.x += Input.get_action_strength(p + "_right") - Input.get_action_strength(p + "_left")
		v.y += Input.get_action_strength(p + "_down") - Input.get_action_strength(p + "_up")
		bomb = bomb or Input.is_action_just_pressed(p + "_bomb")
		steal = steal or Input.is_action_pressed(p + "_steal")
	var sx := signf(v.x) if absf(v.x) > 0.3 else 0.0
	var sy := signf(v.y) if absf(v.y) > 0.3 else 0.0
	if sx != 0.0 and _prev.x == 0.0:
		_last_axis = 0
	if sy != 0.0 and _prev.y == 0.0:
		_last_axis = 1
	_prev = Vector2(sx, sy)
	var dir := Vector2.ZERO
	if sx != 0.0 and sy != 0.0:
		dir = Vector2(sx, 0) if _last_axis == 0 else Vector2(0, sy)
	elif sx != 0.0:
		dir = Vector2(sx, 0)
	elif sy != 0.0:
		dir = Vector2(0, sy)
	bear.input_dir = dir
	if bomb:
		bear.want_bomb = true
	bear.want_steal = steal
