## Everything that differs between Normal and Horror mode, in one place.
## Gameplay is identical; only looks, sounds and words change.
## To add more mode-specific content, add a value here and read it through
## these helpers (assets and sounds also look in a "<mode>/" sub-folder first).
extends RefCounted

const CONFETTI := {
	"normal": [Color("f2a7b5"), Color("a7c8e8"), Color("f5dc8a"), Color("a8dcc0"), Color("c9b2e3"), Color("f6c1a0")],
	"horror": [Color("7a0f16"), Color("a3141e"), Color("5c0a10"), Color("c9b8a0"), Color("2a1c1e"), Color("8c2a2a")],
}
const SUBTITLE := {
	"normal": "Four adorable teddy bears. One finite supply of stuffing.",
	"horror": "Four teddy bears. They are hungry. They are always hungry.",
}
const BLURB := {
	"normal": "Confetti bombs don't hurt - they stun. Hold Steal beside a stunned bear to pull out its fluff.\nThe more you steal, the rounder, wobblier and harder to stop you become.",
	"horror": "The bombs only stun. The stuffing comes out anyway.\nThe more you take, the heavier you get. Nothing that full can run.",
}


static func mode() -> String:
	return Settings.mode


static func horror() -> bool:
	return Settings.mode == "horror"


static func confetti() -> Array:
	return CONFETTI[mode()]


static func text(table: Dictionary) -> String:
	return table[mode()]


## Bear fabric colour: faded, grimy and cold in Horror.
static func bear_color(c: Color) -> Color:
	if horror():
		return c.lerp(Color(0.5, 0.46, 0.46), 0.5).darkened(0.12)
	return c


## Bomb fabric: pastel in Normal, dirty and dim in Horror.
## Darker than the floor and cushions so bombs stand out (still fabric-coloured).
static func bomb_tint(c: Color, rubber: bool) -> Color:
	if horror():
		return Color.from_hsv(c.h, 0.35 if rubber else 0.25, 0.48 if rubber else 0.36)
	if rubber:
		return Color.from_hsv(fmod(c.h + 0.08, 1.0), 0.62, 0.78)
	return Color.from_hsv(c.h, 0.48, 0.66)


## Tint for permanent walls/pillars and the border (darker than cushions and floor).
static func wall_tint() -> Color:
	return Color(0.7, 0.62, 0.62) if horror() else Color(0.62, 0.52, 0.46)


static func border_tint() -> Color:
	return Color(0.75, 0.68, 0.68) if horror() else Color(0.74, 0.64, 0.58)


## Bear outline colour (Settings > Bear outlines).
static func outline_color() -> Color:
	return Color(0.05, 0.02, 0.02, 0.95) if horror() else Color(0.24, 0.15, 0.11, 0.9)


## Colour of stolen stuffing tufts.
static func stuffing_color() -> Color:
	return Color(0.8, 0.28, 0.3) if horror() else Color.WHITE


## Floor decal left where a bear was stunned (fluff puff / blood splatter).
static func splat_color() -> Color:
	return Color(0.5, 0.03, 0.07, 0.85) if horror() else Color(1, 1, 1, 0.8)


## Tint of the whole arena (darker environment in Horror).
static func world_modulate() -> Color:
	return Color(0.74, 0.66, 0.68) if horror() else Color.WHITE


static func bubble_colors() -> Array:
	# [background, text, outline]
	if horror():
		return [Color(0.1, 0.06, 0.07, 0.88), Color("d9c9b6"), Color(0.55, 0.06, 0.1)]
	return [Color(1.0, 0.98, 0.94, 0.92), Color("5b4636"), Color("d8a0a6")]
