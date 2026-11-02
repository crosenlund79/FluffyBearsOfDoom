## One compact, playing-card-style leaderboard card. There are two per player
## (one in each stack beside the arena); both read the same shared state from
## the HUD (slot position, promotion glow, demotion splatter), so the two
## stacks are always the same ranking, moving in lockstep.
extends Control

const UiStyle = preload("res://scripts/ui_style.gd")
const BearVisual = preload("res://scripts/bear_visual.gd")
const Tuning = preload("res://scripts/tuning.gd")
const Mode = preload("res://scripts/mode_theme.gd")

const SIZE := Vector2(140, 156)

var hud
var bear
var side := -1.0          # -1 = left stack, +1 = right stack ("outward" direction)
var font: Font
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	pivot_offset = SIZE * 0.5


func _process(delta: float) -> void:
	t += delta
	var st: Dictionary = hud.anim[bear]
	var base: Vector2 = hud.stack_origin(side)
	var moving: float = clampf(absf(st["pos"] - st["target"]), 0.0, 1.0)
	# promoted cards swing outward and demoted ones tuck in, so passing cards don't collide
	# (separate lanes: about half of each passing card stays visible, names included)
	var lateral: float = side * moving * (36.0 if st["dir"] < 0 else -32.0)
	position = base + Vector2(lateral, st["pos"] * (SIZE.y + hud.STACK_GAP))
	# a wobble while sliding, settling as it arrives
	rotation = sin(t * 24.0 + bear.slot) * 0.075 * moving + sin(t * 9.0) * 0.02 * st["glow"]
	scale = Vector2.ONE * (1.0 + 0.05 * moving)
	z_index = 3 if (moving > 0.02 and st["dir"] < 0) else (2 if moving > 0.02 else 1)
	queue_redraw()


func being_robbed() -> bool:
	for b in bear.game.bears:
		if b != bear and b.stealing and b.steal_target == bear:
			return true
	return false


func _draw() -> void:
	var st: Dictionary = hud.anim[bear]
	var r := Rect2(Vector2.ZERO, SIZE)
	var rank: int = hud.rank_of(bear)
	var glow: float = st["glow"]
	var splat: float = st["splat"]
	var gold := Color(1.0, 0.82, 0.3)
	# promotion: a golden halo behind the card
	if glow > 0.0:
		for i in 4:
			var g := 3.0 + i * 4.0
			draw_rect(r.grow(g), Color(gold.r, gold.g, gold.b, 0.22 * glow * (1.0 - i * 0.22)), false, 4.0)
	# the card
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.18))   # drop shadow
	draw_rect(r, UiStyle.PAPER)
	draw_rect(Rect2(0, 0, SIZE.x, 5), bear.color)
	var edge: Color = bear.color.darkened(0.2).lerp(gold, glow)
	UiStyle.stitch_rect(self, r.grow(-4), Color(edge, 0.8), 1.3, 4.0)
	if glow > 0.0:
		draw_rect(r, Color(gold.r, gold.g, gold.b, 0.18 * glow))
		draw_rect(r.grow(-1), Color(gold.r, gold.g, gold.b, glow), false, 2.5)
	# rank badge (1st gold with a crown, 2nd silver, 3rd bronze)
	var medal: Array = [gold.darkened(0.15), Color(0.72, 0.72, 0.76), Color(0.78, 0.52, 0.32), UiStyle.BAR]
	var bc := Vector2(19, 22)
	draw_circle(bc, 13.0, medal[clampi(rank - 1, 0, 3)])
	draw_arc(bc, 13.0, 0.0, TAU, 20, Color(UiStyle.INK, 0.35), 1.2)
	draw_string(font, bc + Vector2(-13, 6), "%d" % rank, HORIZONTAL_ALIGNMENT_CENTER, 26, 17,
		Color(0.2, 0.12, 0.08) if rank <= 3 else UiStyle.INK)
	if rank == 1:
		var cr := bc + Vector2(0, -15)
		draw_colored_polygon(PackedVector2Array([cr + Vector2(-7, 3), cr + Vector2(-7, -3), cr + Vector2(-3, 0),
			cr + Vector2(0, -5), cr + Vector2(3, 0), cr + Vector2(7, -3), cr + Vector2(7, 3)]), gold)
	# name
	draw_string(font, Vector2(34, 27), bear.bear_name, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x - 40, 16, UiStyle.INK)
	# portrait (fitted to its box: tall ears and crowns stay on the card)
	var robbed := being_robbed()
	var face_i := 3 if bear.is_stunned() else (1 if bear.stealing else (2 if robbed or bear.robbed_t > 0.0 else 0))
	if splat > 0.4:
		face_i = 2   # indignant while being knocked down the table
	var wob := Vector2(sin(t * 40.0), 0) * 1.5 if robbed else Vector2.ZERO
	var fit := BearVisual.fit_portrait(bear.species, Rect2(14, 34, SIZE.x - 28, 60), 30.0)
	BearVisual.draw_portrait(self, fit[1] + wob, fit[0], bear.species, bear.color, face_i)
	# score (blinks while someone is pulling the stuffing out)
	var blink := robbed and fmod(t * 6.0, 1.0) < 0.5
	var score: int = hud.score_of(bear)
	draw_string(font, Vector2(0, 124), str(score), HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 30,
		UiStyle.ROSE_DARK if blink else UiStyle.INK)
	# small fluff bar, towards the instant-win line when that's on
	var goal: float = Settings.instant_win if Settings.instant_win > 0.0 else Tuning.START_FLUFF * 4.0
	var bar := Rect2(14, 131, SIZE.x - 28, 7)
	draw_rect(bar, UiStyle.BAR)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(bear.fluff / goal, 0.0, 1.0), bar.size.y)), bear.color.darkened(0.08))
	draw_rect(bar, Color(UiStyle.INK, 0.3), false, 1.0)
	# one-word status
	var status := ""
	var scol := UiStyle.INK_SOFT
	if bear.is_stunned():
		status = "stunned"
		scol = UiStyle.ROSE_DARK
	elif robbed:
		status = "robbed!"
		scol = UiStyle.ROSE_DARK
	elif bear.stealing:
		status = "stealing"
		scol = UiStyle.GOOD
	if status != "":
		draw_string(font, Vector2(0, 151), status, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 11, scol)
	# arrows: which way it just moved
	if glow > 0.05:
		_arrow(Vector2(SIZE.x - 14, 46), -1.0, Color(gold.darkened(0.2), glow))
	# demotion: a splatter across the card's edges (kept off the score)
	if splat > 0.0:
		_splatter(st, splat)
		_arrow(Vector2(SIZE.x - 14, 46), 1.0, Color(_blood(), splat))


func _arrow(at: Vector2, dir: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, 7 * dir), at + Vector2(-7, -4 * dir), at + Vector2(7, -4 * dir)]), col)


func _blood() -> Color:
	return Color(0.5, 0.02, 0.05) if Mode.horror() else Color(0.78, 0.08, 0.12)


func _splatter(st: Dictionary, a: float) -> void:
	var col := _blood()
	for d in st["drops"]:
		# d = [position, radius, drip length]; drops land on the frame, portrait corners and outside
		var p: Vector2 = d[0]
		var rad: float = d[1] * (0.6 + 0.4 * minf(1.0, (1.0 - a) * 6.0 + 0.4))
		draw_circle(p, rad, Color(col.r, col.g, col.b, 0.9 * a))
		if d[2] > 0.0:
			var drip: float = d[2] * (1.0 - a * 0.6)
			draw_line(p, p + Vector2(0, drip), Color(col.r, col.g, col.b, 0.85 * a), rad * 0.7)
			draw_circle(p + Vector2(0, drip), rad * 0.45, Color(col.r, col.g, col.b, 0.85 * a))
