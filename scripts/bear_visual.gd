## The procedural teddy bear rig.
##
## Built from one shared sprite sheet (body, belly, head, ear, arm, leg and
## four faces), tinted per bear. Everything else - walking, waddling, belly
## jiggle, growth, deflation, stun flops, squash and stretch - is done here
## with springs and sine waves. All motion scales continuously with fluff.
##
## `source` can be any object exposing: velocity, fluff, facing, stun_t,
## stealing, steal_target, robbed_t, immune_t, on_bouncy, is_stunned().
extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Species = preload("res://scripts/species.gd")

enum Face { NORMAL, SMUG, INDIGNANT, STUNNED }

const PART_SCALE := 0.36   # world px per px of a 128px sheet cell
const BASE_CELL := 128.0

var source
var species := "bear"
var spec: Dictionary
var cells := 10
var tail: Sprite2D
var skirt: Sprite2D
var topper: Sprite2D
var tint := Color.WHITE
var seed_offset := 0.0

var sheet: Texture2D
var cw := 128.0
var unit := PART_SCALE

var body: Sprite2D
var belly: Sprite2D
var head: Sprite2D
var face: Sprite2D
var wrinkles: Wrinkles
var legs: Array[Sprite2D] = []
var arms: Array[Sprite2D] = []
var ears: Array[Sprite2D] = []

# Springs. *_off is displacement, *_v its velocity.
var body_off := Vector2.ZERO
var body_v := Vector2.ZERO
var belly_off := Vector2.ZERO
var belly_v := Vector2.ZERO
var squash := 0.0
var squash_v := 0.0
var lean := 0.0
var lean_v := 0.0
var flop := 0.0
var flop_v := 0.0
var flop_dir := 1.0
var ear_wob := 0.0
var ear_wob_v := 0.0

var g := 1.0               # smoothed fluff ratio (1.0 = start fluff)
var phase := 0.0           # walk cycle
var t := 0.0
var hop := 0.0
var last_vel := Vector2.ZERO
var face_idx := -1

# Exposed for the owner (shadow size, star position).
var shadow_w := 20.0
var head_top := -50.0
var head_r := 18.0

# Taunt reaction (cosmetic) and Horror-mode idle twitching
const TAUNT_TIME := 1.1
var taunt_kind := ""
var taunt_t := 0.0
var _twitch_t := 3.0
var _twitch := 0.0
var horror := false

# Optional outline (Settings > Bear outlines): a silhouette edge around the
# outer parts, done in a shader so any replacement sprite works.
const OUTLINE_SHADER := """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(0.24, 0.15, 0.11, 0.9);
uniform float width = 8.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;
		a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
	}
	vec4 base = tex * COLOR;
	vec4 edge = vec4(outline_color.rgb, outline_color.a * a * COLOR.a);
	COLOR = mix(edge, base, tex.a);
}
"""
static var _outline_mat: ShaderMaterial
var _outlined := false


class Wrinkles extends Node2D:
	var amount := 0.0
	var col := Color(0.3, 0.2, 0.15)

	func _draw() -> void:
		if amount < 0.05:
			return
		var c := Color(col.r, col.g, col.b, 0.45 * amount)
		for i in 4:
			var y := -26.0 + i * 15.0
			var x := sin(i * 1.9) * 12.0
			draw_arc(Vector2(x, y), 13.0, PI * 0.15, PI * 0.85, 8, c, 3.0)
		draw_arc(Vector2(-22, 10), 10.0, -PI * 0.2, PI * 0.4, 6, c, 3.0)
		draw_arc(Vector2(22, 10), 10.0, PI * 0.6, PI * 1.2, 6, c, 3.0)


## Stand-in data source for menus and the results screen.
class Puppet:
	var velocity := Vector2.ZERO
	var fluff := 100.0
	var facing := Vector2.DOWN
	var stun_t := 0.0
	var stealing := false
	var steal_target = null
	var robbed_t := 0.0
	var immune_t := 0.0
	var on_bouncy := false
	var smug := false

	func is_stunned() -> bool:
		return stun_t > 0.0


func _ready() -> void:
	spec = Species.info(species)
	sheet = Assets.tex(spec["sheet"])
	cells = spec["cells"]
	cw = float(sheet.get_width()) / cells
	unit = PART_SCALE * BASE_CELL / cw
	if spec["tail"] != "":
		tail = _part(10, tint if spec["tail_tint"] else Color.WHITE)   # behind everything
		if spec["tail"] == "long":
			tail.offset = Vector2(0.39 * cw, 0)   # pivot at the tail's base
	for i in 2:
		var leg := _part(5, tint)
		leg.offset = Vector2(0, -0.12 * cw)  # pivot near the hip
		legs.append(leg)
	body = _part(0, tint)
	belly = _part(1, tint.lerp(Color.WHITE, 0.72), body)
	wrinkles = Wrinkles.new()
	wrinkles.col = tint.darkened(0.6)
	body.add_child(wrinkles)
	if spec["skirt"]:
		skirt = _part(10, Color.WHITE)
	for i in 2:
		var arm := _part(4, tint)
		arm.offset = Vector2(0, 0.2 * cw)   # pivot at the shoulder
		arms.append(arm)
	head = _part(2, tint)
	for i in 2:
		var ear := _part(3, tint, head)
		ear.show_behind_parent = true
		ear.offset = Vector2(0, spec["ear_offset"] * cw)
		ear.scale = Vector2.ONE * spec["ear_scale"]
		ears.append(ear)
	if spec["topper"] == "back":
		topper = _part(11, tint if spec["topper_tint"] else Color.WHITE, head)
		topper.show_behind_parent = true
	face = _part(6, Color.WHITE, head)
	if spec["topper"] == "front":
		topper = _part(11, tint if spec["topper_tint"] else Color.WHITE, head)
	if topper:
		topper.position = spec["topper_pos"]
		topper.rotation = spec["topper_rot"]
		topper.scale = Vector2.ONE * spec["topper_scale"]
	g = _target_g()
	horror = Settings.mode == "horror"


func _part(index: int, col: Color, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = sheet
	s.region_enabled = true
	s.region_rect = Assets.region(sheet, cells, index)
	s.self_modulate = col
	if parent == null:
		add_child(s)
		s.scale = Vector2(unit, unit)
	else:
		parent.add_child(s)
	return s


func _outline_parts() -> Array:
	return legs + [body] + arms + [head] + ears


func _apply_outline(on: bool) -> void:
	_outlined = on
	if on and _outline_mat == null:
		var sh := Shader.new()
		sh.code = OUTLINE_SHADER
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = sh
	if on:
		_outline_mat.set_shader_parameter("outline_color", preload("res://scripts/mode_theme.gd").outline_color())
	for part in _outline_parts():
		part.material = _outline_mat if on else null


func _target_g() -> float:
	if source == null:
		return 1.0
	return clampf(source.fluff / Tuning.START_FLUFF, 0.0, 6.0)


# --- reactions -------------------------------------------------------------------

## Wall bump. axis 0 = horizontal impact, 1 = vertical.
func bump(axis: int, impact: float, dir: float) -> void:
	var k := clampf(impact / 220.0, 0.2, 1.6)
	if axis == 0:
		squash_v -= 7.0 * k
		body_v.x += dir * impact * 0.35
		belly_v.x += dir * impact * 0.6
	else:
		squash_v += 7.0 * k
		body_v.y += dir * impact * 0.3
		belly_v.y += dir * impact * 0.5
	ear_wob_v += dir * 12.0 * k


func kick(amount: float) -> void:
	squash_v += amount * 10.0
	belly_v.y += amount * 120.0


func on_stunned(from_dir: float) -> void:
	flop_dir = from_dir if from_dir != 0.0 else (1.0 if randf() < 0.5 else -1.0)
	flop_v += flop_dir * 6.0
	squash_v += 9.0
	ear_wob_v += 20.0 * flop_dir


func play_taunt(kind: String) -> void:
	taunt_kind = kind
	taunt_t = TAUNT_TIME
	squash_v += 4.0


func on_recover() -> void:
	squash_v -= 8.0
	flop_v -= flop_dir * 3.0


# --- animation --------------------------------------------------------------------

func _spring(x: float, v: float, target: float, k: float, zeta: float, dt: float) -> Vector2:
	var c := 2.0 * sqrt(k) * zeta
	v += (k * (target - x) - c * v) * dt
	x += v * dt
	return Vector2(x, v)


func _process(delta: float) -> void:
	if source == null:
		return
	if Settings.bear_outlines != _outlined:
		_apply_outline(Settings.bear_outlines)
	delta = minf(delta, 0.05)
	t += delta
	var vel: Vector2 = source.velocity
	g = lerpf(g, _target_g(), 1.0 - exp(-delta * 5.0))
	var acc := ((vel - last_vel) / maxf(delta, 0.001)).limit_length(5000.0)
	last_vel = vel
	var speed := vel.length()
	var soft := 0.6 + 0.4 * g             # how squishy / laggy the plush is
	var sag := clampf((0.6 - g) / 0.6, 0.0, 1.0)  # deflation amount
	var stunned: bool = source.is_stunned()

	# Body lags behind acceleration (delayed mass), with less damping when stuffed.
	var wob := 1.45 + 0.3 * minf(g, 4.0)   # overall wobble gain, grows with stuffing
	var kb := 160.0 / soft
	var zb := clampf(0.55 / (0.6 + 0.5 * g), 0.09, 0.8)
	var cb := 2.0 * sqrt(kb) * zb
	body_v += (-kb * body_off - cb * body_v - acc * 0.010 * soft * wob) * delta
	body_off += body_v * delta
	body_off = body_off.limit_length(10.0 + 7.0 * g)

	# Belly: a softer secondary spring riding on the body.
	var kl := 110.0 / soft
	var zl := clampf(0.32 / (0.6 + 0.55 * g), 0.05, 0.6)
	var cl := 2.0 * sqrt(kl) * zl
	belly_v += (-kl * belly_off - cl * belly_v - acc * 0.008 * soft * wob * 1.2 - body_v * 0.6) * delta
	belly_off += belly_v * delta
	belly_off = belly_off.limit_length(8.0 + 8.0 * g)

	# Sudden speed or direction changes (starting, turning, braking) squash the plush.
	squash_v += clampf(acc.length() / 4000.0, 0.0, 1.0) * (0.8 + 0.6 * minf(g, 4.0)) * delta * 9.0

	var sq := _spring(squash, squash_v, 0.0, 260.0 / soft, clampf(0.3 / (0.6 + 0.4 * g), 0.07, 0.5), delta)
	squash = clampf(sq.x, -0.5, 0.5)
	squash_v = sq.y

	# Delayed leaning into motion and away from braking.
	var lean_target := clampf(vel.x / 300.0, -1.0, 1.0) * (0.12 + 0.06 * g) - clampf(acc.x / 3000.0, -1.0, 1.0) * 0.2 * soft
	if stunned:
		lean_target = 0.0
	var ln := _spring(lean, lean_v, lean_target, 70.0 / soft, clampf(0.45 / (0.6 + 0.4 * g), 0.1, 0.7), delta)
	lean = ln.x
	lean_v = ln.y

	var ew := _spring(ear_wob, ear_wob_v, -body_v.x * 0.01, 120.0, 0.18, delta)
	ear_wob = clampf(ew.x, -0.9, 0.9)
	ear_wob_v = ew.y

	# Stun flop: falls over with an overshooting wobble, pops back up after.
	var fl := _spring(flop, flop_v, flop_dir * 1.45 if stunned else 0.0, 90.0, 0.22, delta)
	flop = fl.x
	flop_v = fl.y

	# Walk cycle: heavier bears take frantic tiny steps.
	var moving := clampf(speed / 60.0, 0.0, 1.0)
	if stunned:
		moving = 0.0
	var stride := 18.0 / (0.5 + 0.5 * pow(maxf(g, 0.2), 1.3))
	var prev_phase := phase
	phase += speed * delta / stride * (0.0 if stunned else 1.0)
	if floori(phase / PI) != floori(prev_phase / PI) and moving > 0.3:
		_on_step(moving)
	var bob := -absf(sin(phase)) * (1.4 + 1.6 * g) * moving
	var sway := sin(phase) * (0.045 + 0.06 * g) * moving
	var idle := 1.0 - moving
	var breathe := sin(t * 2.4 + seed_offset) * 0.025 * (0.5 + 0.5 * g) * idle
	sway += sin(t * 1.7 + seed_offset) * 0.02 * maxf(g - 0.8, 0.0) * idle

	# Bouncy floors make bears boing.
	if source.on_bouncy and not stunned:
		var target_hop := absf(sin(t * 7.0 + seed_offset)) * maxf(10.0 - 1.5 * g, 4.0)
		hop = lerpf(hop, target_hop, 1.0 - exp(-delta * 18.0))
	else:
		hop = lerpf(hop, 0.0, 1.0 - exp(-delta * 10.0))

	# --- proportions, all continuous in g ---
	var gb := maxf(g, 0.0)
	var bsx := 0.62 + 0.38 * pow(gb, 0.9)
	var bsy := (0.68 + 0.32 * pow(gb, 0.75)) * (1.0 - 0.22 * sag)
	bsx = lerpf(bsx, 0.8, sag * 0.6)  # an empty bear flattens like a pillowcase
	var s := squash + breathe
	if stunned:
		s += 0.08 + 0.05 * minf(g, 4.0)  # a big bear collapses into a heap
	var sx := bsx * (1.0 + s)
	var sy := bsy * (1.0 - s)
	body.scale = Vector2(sx, sy) * unit
	var body_hw := 46.0 * PART_SCALE * sx
	var body_hh := 50.0 * PART_SCALE * sy
	var leg_h := 7.0
	var body_y := -leg_h - body_hh * 0.9 + bob
	body.position = Vector2(body_off.x * 0.6, body_y + body_off.y * 0.4)
	body.rotation = sway * 0.5
	body.self_modulate = tint.lerp(Color(0.72, 0.7, 0.68), 0.3 * sag)

	# Belly grows faster than the body and jiggles on its own spring.
	var brel := clampf(0.55 + 0.17 * g, 0.42, 0.98)
	var jig := clampf(belly_off.y * 0.012, -0.2, 0.2)
	belly.scale = Vector2(brel * (1.0 + jig) * (1.0 - 0.15 * sag), brel * (1.0 - jig))
	belly.position = Vector2(belly_off.x * 1.6, 10.0 + 4.0 * minf(g, 4.0) + belly_off.y * 1.4) / maxf(bsx, 0.3)
	wrinkles.amount = sag
	wrinkles.queue_redraw()

	# Head sits on the body, grows a little, lags a little more.
	var hs := 0.9 + 0.12 * sqrt(gb)
	head.scale = Vector2(hs * (1.0 + s * 0.3), hs * (1.0 - s * 0.3)) * unit
	head_r = 50.0 * PART_SCALE * hs
	head.position = Vector2(body_off.x * 1.1 + sin(phase) * 1.2 * moving, body_y - body_hh * 0.82 - head_r * 0.55 + body_off.y * 0.7 + bob * 0.3)
	head.rotation = sway * 0.7 + sag * sin(t * 1.3) * 0.08 - lean * 0.25
	head_top = head.position.y - head_r

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ep: Vector2 = spec["ear_pos"]
		var flop: float = spec["ear_flop"]
		ears[i].position = Vector2(side * ep.x, ep.y + sag * 10.0)
		ears[i].rotation = side * (0.12 + sag * 0.75) + (ear_wob * (1.0 + 0.4 * i) + sin(phase * 2.0) * 0.06 * moving) * flop

	# Arms stick out further on a round bear and swing with the waddle.
	var steal_dir := Vector2.ZERO
	if source.stealing and source.steal_target != null and is_instance_valid(source.steal_target):
		steal_dir = (source.steal_target.global_position - global_position).normalized()
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		arms[i].position = Vector2(side * body_hw * 0.9 + body_off.x * 0.8, body_y - body_hh * 0.25 + body_off.y * 0.5)
		var spread := 0.25 + 0.2 * minf(g, 4.0) - sag * 0.25
		var swing := sin(phase + PI * i) * 0.5 * moving
		var rot := -side * spread + swing
		if steal_dir != Vector2.ZERO:
			# grabby little paws pulling at the victim's stuffing
			rot = steal_dir.angle() - PI * 0.5 + sin(t * 16.0 + i * 1.7) * 0.35
		elif stunned:
			rot = -side * (1.2 + sin(t * 3.0 + i) * 0.1)
		arms[i].rotation = rot
		arms[i].scale = Vector2.ONE * unit * (0.85 + 0.1 * minf(g, 4.0))

	# Taunt reactions: purely visual, layered on top of the normal animation.
	var taunt_rot := 0.0
	var taunt_off := Vector2.ZERO
	if taunt_t > 0.0 and not stunned:
		taunt_t -= delta
		var k := 1.0 - taunt_t / TAUNT_TIME          # 0 -> 1 progress
		var env := sin(clampf(k, 0.0, 1.0) * PI)       # ease in and out
		match taunt_kind:
			"wiggle":
				body.rotation += sin(t * 30.0) * 0.3 * env
				belly_v.x += sin(t * 30.0) * 40.0 * env * delta * 60.0
			"spin":
				taunt_rot = TAU * (k * k * (3.0 - 2.0 * k))
			"hop":
				taunt_off.y = -sin(k * PI) * 16.0
			"cheer":
				for i in 2:
					var side := -1.0 if i == 0 else 1.0
					arms[i].rotation = side * (2.7 + sin(t * 22.0 + i) * 0.35)
			"tilt":
				head.rotation += 1.15 * env
			"twitch":
				head.rotation += (0.7 if fmod(t * 9.0, 1.0) < 0.5 else -0.5) * env
				taunt_off.x = (1.5 if fmod(t * 13.0, 1.0) < 0.5 else -1.5) * env
			"lean":
				taunt_rot = 0.4 * env * (1.0 if seed_offset > 2.0 else -1.0)
				head.rotation -= 0.5 * env
			"shudder":
				taunt_off.x = randf_range(-2.5, 2.5) * env
				body.rotation += randf_range(-0.1, 0.1) * env
	if horror and not stunned:
		# every so often the head snaps sideways, holds... and snaps back
		_twitch_t -= delta
		if _twitch_t <= 0.0:
			_twitch_t = randf_range(3.0, 8.0)
			_twitch = 0.35
		if _twitch > 0.0:
			_twitch -= delta
			head.rotation += 0.55 * (1.0 if fmod(seed_offset, 2.0) < 1.0 else -1.0)

	# Tiny legs that barely grow at all.
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var lift := maxf(0.0, sin(phase + PI * i)) * 3.5 * moving
		legs[i].position = Vector2(side * (5.5 + 1.8 * minf(g, 4.0)) + body_off.x * 0.15, -lift + 1.0)
		legs[i].rotation = sin(phase + PI * i) * 0.35 * moving + (side * 0.6 if stunned else 0.0)
		legs[i].scale = Vector2.ONE * unit * (0.82 + 0.05 * minf(g, 3.0))

	# Expression
	var f := Face.NORMAL
	if stunned:
		f = Face.STUNNED
	elif source.stealing or (source is Puppet and source.smug):
		f = Face.SMUG
	elif source.robbed_t > 0.0:
		f = Face.INDIGNANT
	if f != face_idx:
		face_idx = f
		face.region_rect = Assets.region(sheet, cells, 6 + f)
	var facing: Vector2 = source.facing
	face.visible = stunned or facing.y >= 0.0 or absf(facing.x) > 0.0
	face.position = Vector2(facing.x * 11.0, maxf(facing.y, 0.0) * 4.0)
	_update_accessories(body_hw, body_hh, body_y, sx, s, moving, stunned)

	# Whole rig: lean + stun flop, pivoting at the feet. Hop on bouncy floors.
	rotation = lean + flop + taunt_rot
	position = Vector2(-flop * 10.0, 14.0 - hop) + taunt_off
	shadow_w = body_hw * 1.15 + 4.0
	modulate.a = 1.0
	if source.immune_t > 0.0 and not stunned:
		modulate.a = 0.55 if fmod(t * 12.0, 1.0) < 0.5 else 1.0


## Tail wags behind the body, the tutu jiggles with the belly.
func _update_accessories(body_hw: float, body_hh: float, body_y: float, sx: float, s: float, moving: float, stunned: bool) -> void:
	var facing: Vector2 = source.facing
	if tail:
		var side := -signf(facing.x) if absf(facing.x) > 0.0 else 1.0   # trails behind, peeks out when facing you
		var wag := sin(phase * 0.5) * 0.25 * moving + sin(t * 3.0 + seed_offset) * 0.12 + body_v.x * 0.004
		if spec["tail"] == "long":
			tail.position = Vector2(side * body_hw * 0.55 + body_off.x * 0.4, body_y + body_hh * 0.55)
			tail.scale = Vector2(side, 1.0) * unit * (0.62 + 0.1 * minf(g, 4.0))
			tail.rotation = (wag + (0.5 if stunned else 0.0)) * side
		else:
			tail.position = Vector2(side * body_hw * 0.8 + body_off.x * 0.4, body_y + body_hh * 0.5)
			tail.scale = Vector2.ONE * unit * (0.38 + 0.06 * minf(g, 4.0))
			tail.rotation = wag
	if skirt:
		skirt.position = Vector2(body_off.x * 0.6, body_y + body_hh * 0.42 + belly_off.y * 0.35)
		skirt.scale = Vector2(sx * 0.9 + 0.12, (0.62 + 0.08 * minf(g, 4.0)) * (1.0 - s * 0.4)) * unit
		skirt.rotation = body.rotation + belly_off.x * 0.01


## A head-and-face portrait of a character (HUD cards); radius = head radius in px.
## Uses the same sheet cells and texel positions as the rig, so replacement art shows too.
static func draw_portrait(ci: CanvasItem, center: Vector2, radius: float, species_id: String, tint_col: Color, face_index: int) -> void:
	var sp: Dictionary = Species.info(species_id)
	var tex: Texture2D = Assets.tex(sp["sheet"])
	var n: int = sp["cells"]
	var cell := float(tex.get_width()) / n
	var k := radius / (50.0 * cell / BASE_CELL)   # px per texel (head content radius is ~50 base texels)
	var ep: Vector2 = sp["ear_pos"]
	var ear_shift := Vector2(0, float(sp["ear_offset"]) * cell * float(sp["ear_scale"]))
	var parts := []                                # [cell index, position (texels), rotation, scale, colour]
	if sp["topper"] == "back":
		parts.append([11, sp["topper_pos"], sp["topper_rot"], sp["topper_scale"], tint_col if sp["topper_tint"] else Color.WHITE])
	for side in [-1.0, 1.0]:
		parts.append([3, Vector2(side * ep.x, ep.y) + ear_shift, side * 0.12, sp["ear_scale"], tint_col])
	parts.append([2, Vector2.ZERO, 0.0, 1.0, tint_col])
	parts.append([6 + face_index, Vector2.ZERO, 0.0, 1.0, Color.WHITE])
	if sp["topper"] == "front":
		parts.append([11, sp["topper_pos"], sp["topper_rot"], sp["topper_scale"], tint_col if sp["topper_tint"] else Color.WHITE])
	for part in parts:
		var sz: float = cell * k * float(part[3])
		ci.draw_set_transform(center + Vector2(part[1]) * k, part[2], Vector2.ONE)
		ci.draw_texture_rect_region(tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), Assets.region(tex, n, part[0]), part[4])
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_step(moving: float) -> void:
	squash_v += 0.6 * moving * (0.3 + 0.3 * g)
	belly_v.y += 22.0 * g * moving
	ear_wob_v += (randf() - 0.5) * 2.0 * moving
