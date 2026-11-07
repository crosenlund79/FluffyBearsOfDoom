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
	var moving: float = clampf(absf(st["pos"] - st["target"]), 0.0, 1.0)
	# promoted cards swing outward and demoted ones tuck in, so passing cards don't collide
	# (separate lanes: about half of each passing card stays visible, names included)
	var lateral: float = side * moving * (30.0 if st["dir"] < 0 else -26.0)
	var sc: float = hud.CARD_SCALE * (1.0 + 0.05 * moving)
	# position is the unscaled rect; scaling pivots on the centre
	position = hud.slot_top_left(side, st["pos"]) + Vector2(lateral, 0) - SIZE * (1.0 - hud.CARD_SCALE) * 0.5
	# each slot has its own slight tilt (a messy pile of playing cards), plus a
	# wobble while sliding that settles as the card arrives
	rotation = hud.slot_rotation(side, st["pos"]) + sin(t * 24.0 + bear.slot) * 0.075 * moving + sin(t * 9.0) * 0.02 * st["glow"]
	scale = Vector2.ONE * sc
	# cards higher in the ranking lie on top of the ones below; moving cards above all
	z_index = 20 if (moving > 0.02 and st["dir"] < 0) else (15 if moving > 0.02 else 10 - int(round(st["pos"])))
	queue_redraw()


## Rank skulls, drawn in code. 4th: small and weak; 3rd: bigger, mean slanted
## eyes; 2nd: heavy brow, fangs, red glints; 1st: huge muscular jaw and brow,
## cheekbones, fangs and glowing eyes.
static func draw_skull(ci: CanvasItem, c: Vector2, rank: int, t: float) -> void:
	var lvl := 4 - rank                      # 0 (weak) .. 3 (brutal)
	var s := 0.75 + 0.17 * lvl
	var bone := Color(0.93, 0.9, 0.82).lerp(Color(0.86, 0.8, 0.68), lvl / 3.0)
	var dark := Color(0.12, 0.06, 0.06)
	var line := Color(0.3, 0.22, 0.18)
	# jaw: grows wider than the cranium as the rank rises
	var jw := (7.0 + 3.5 * lvl) * s
	var jaw := PackedVector2Array([c + Vector2(-jw, 3 * s), c + Vector2(jw, 3 * s), c + Vector2(jw * 0.75, (12 + lvl) * s), c + Vector2(-jw * 0.75, (12 + lvl) * s)])
	ci.draw_colored_polygon(jaw, bone)
	ci.draw_polyline(jaw + PackedVector2Array([jaw[0]]), line, 1.2)
	# cranium (1st: broad and lumpy, like a clenched muscle)
	ci.draw_circle(c + Vector2(0, -3 * s), 10.0 * s, bone)
	if lvl >= 3:
		ci.draw_circle(c + Vector2(-7, -5) * s, 6.5 * s, bone)
		ci.draw_circle(c + Vector2(7, -5) * s, 6.5 * s, bone)
		for sx in [-1.0, 1.0]:   # cheekbones
			ci.draw_circle(c + Vector2(sx * 9.5, 2) * s, 3.4 * s, bone)
	ci.draw_arc(c + Vector2(0, -3 * s), 10.0 * s, PI * 1.05, PI * 1.95, 12, line, 1.2)
	# eyes: round and sad -> slanted -> furious, glowing
	var glow := 0.6 + 0.4 * sin(t * 6.0)
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(sx * 4.0, -2.5) * s
		if lvl == 0:
			ci.draw_circle(e, 2.6 * s, dark)
		else:
			var slant := 1.0 + lvl * 0.8
			ci.draw_colored_polygon(PackedVector2Array([e + Vector2(-sx * 3.4, -slant) * s, e + Vector2(sx * 3.2, slant * 0.7) * s,
				e + Vector2(sx * 0.5, 3.0) * s, e + Vector2(-sx * 2.8, 2.4) * s]), dark)
			if lvl >= 2:
				ci.draw_circle(e + Vector2(0, 0.8) * s, (0.9 + 0.4 * lvl) * s, Color(1.0, 0.15, 0.1, glow))
	# brow ridge: from none to a heavy, angry shelf
	if lvl >= 1:
		for sx in [-1.0, 1.0]:
			ci.draw_line(c + Vector2(sx * 8.0, -5.0 - lvl * 1.2) * s, c + Vector2(sx * 1.0, -2.5) * s, line if lvl < 3 else dark, (1.2 + lvl * 0.9) * s)
	# nose and teeth (fangs from 2nd up)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 1) * s, c + Vector2(-1.6, 4) * s, c + Vector2(1.6, 4) * s]), dark)
	var n := 3 + lvl
	for i in n:
		var x := lerpf(-jw * 0.6, jw * 0.6, (i + 0.5) / n)
		ci.draw_line(c + Vector2(x, 6 * s), c + Vector2(x, (9 + lvl) * s), line, 1.0)
	if lvl >= 2:
		for sx in [-1.0, 1.0]:
			var f := c + Vector2(sx * jw * 0.45, 5.5 * s)
			ci.draw_colored_polygon(PackedVector2Array([f + Vector2(-1.6, 0), f + Vector2(1.6, 0), f + Vector2(0, (4 + lvl) * s)]), Color(1, 0.98, 0.9))
	if lvl == 0:   # a crack: this one's had a hard life
		ci.draw_line(c + Vector2(2, -12) * s, c + Vector2(4, -6) * s, line, 1.0)


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
	var out: bool = bear.eliminated
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.18))   # drop shadow
	draw_rect(r, UiStyle.PAPER if not out else UiStyle.PAPER.darkened(0.25))
	draw_rect(Rect2(0, 0, SIZE.x, 5), bear.color)
	# the human player's cards: a thick frame in their colour and a "YOU" tab
	# (on the card itself, so it rides along with every slide and effect)
	if bear.is_human:
		var hc: Color = bear.color.darkened(0.15)
		draw_rect(r.grow(2.0), hc, false, 5.0)
		var tag: String = "YOU" if Settings.rule("human_count") <= 1 else ("P1" if bear.bear_name.ends_with("1") else "P2")
		var tw := 44.0
		var tab := Rect2(SIZE.x * 0.5 - tw * 0.5, -13, tw, 16)
		draw_rect(tab, hc)
		draw_string(font, Vector2(tab.position.x, tab.end.y - 3), tag, HORIZONTAL_ALIGNMENT_CENTER, tw, 13, UiStyle.PAPER)
	var edge: Color = bear.color.darkened(0.2).lerp(gold, glow)
	UiStyle.stitch_rect(self, r.grow(-4), Color(edge, 0.8), 1.3, 4.0)
	if glow > 0.0:
		draw_rect(r, Color(gold.r, gold.g, gold.b, 0.18 * glow))
		draw_rect(r.grow(-1), Color(gold.r, gold.g, gold.b, glow), false, 2.5)
	# rank skull: the higher the rank, the bigger and nastier the skull
	var bc := Vector2(19, 24)
	draw_skull(self, bc, clampi(rank, 1, 4), t)
	draw_string(font, bc + Vector2(6, 21), "%d" % rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.INK)
	# name
	draw_string(font, Vector2(34, 28), bear.bear_name, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x - 38, 19, UiStyle.INK)
	# portrait (fitted to its box: tall ears and crowns stay on the card)
	var robbed := being_robbed()
	var face_i := 3 if bear.is_stunned() else (1 if bear.stealing else (2 if robbed or bear.robbed_t > 0.0 else 0))
	if splat > 0.4 or bear.growl_t > 0.0:
		face_i = 2   # indignant while knocked down the table, or snarling
	if out:
		face_i = 3
	var wob := Vector2(sin(t * 40.0), 0) * 1.5 if robbed else Vector2.ZERO
	if bear.growl_t > 0.0:
		wob = Vector2(sin(t * 55.0), cos(t * 47.0)) * 2.5
	var fit := BearVisual.fit_portrait(bear.species, Rect2(14, 34, SIZE.x - 28, 60), 30.0)
	BearVisual.draw_portrait(self, fit[1] + wob, fit[0], bear.species, bear.color.darkened(0.45) if out else bear.color, face_i)
	if bear.growl_t > 0.0 and not out:
		var ga := clampf(bear.growl_t * 3.0, 0.0, 1.0)
		var gc := Color(0.55, 0.05, 0.06, ga) if Mode.horror() else Color(0.75, 0.25, 0.15, ga)
		draw_set_transform(Vector2(SIZE.x - 50, 52), -0.2, Vector2.ONE)
		draw_string(font, Vector2(1, 1), "GRRR!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.97, 0.9, ga))
		draw_string(font, Vector2.ZERO, "GRRR!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, gc)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# score (blinks while someone is pulling the stuffing out)
	var blink := robbed and fmod(t * 6.0, 1.0) < 0.5
	var score: int = hud.score_of(bear)
	draw_string(font, Vector2(0, 126), str(score), HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 34,
		UiStyle.ROSE_DARK if blink else UiStyle.INK)
	# small fluff bar, towards the instant-win line when that's on
	var goal: float = Settings.rule("instant_win") if Settings.rule("instant_win") > 0.0 else Tuning.START_FLUFF * 4.0
	var bar := Rect2(14, 133, SIZE.x - 28, 8)
	draw_rect(bar, UiStyle.BAR)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(bear.fluff / goal, 0.0, 1.0), bar.size.y)), bear.color.darkened(0.08))
	draw_rect(bar, Color(UiStyle.INK, 0.3), false, 1.0)
	# one-word status
	var status := ""
	var scol := UiStyle.INK_SOFT
	if out:
		status = "OUT"
		scol = UiStyle.ROSE_DARK
	elif bear.is_stunned():
		status = "stunned"
		scol = UiStyle.ROSE_DARK
	elif robbed:
		status = "robbed!"
		scol = UiStyle.ROSE_DARK
	elif bear.stealing:
		status = "stealing"
		scol = UiStyle.GOOD
	if status != "":
		draw_string(font, Vector2(0, 151), status, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 13, scol)
	if out:   # a stamp across the card (not over the score)
		draw_set_transform(Vector2(SIZE.x * 0.5, 66), -0.3, Vector2.ONE)
		draw_rect(Rect2(-58, -15, 116, 30), Color(UiStyle.ROSE_DARK, 0.85), false, 3.0)
		draw_string(font, Vector2(-58, 8), "DEFLATED", HORIZONTAL_ALIGNMENT_CENTER, 116, 15, Color(UiStyle.ROSE_DARK, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
