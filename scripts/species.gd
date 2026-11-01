## The four playable characters. They all share the bear rig (body, belly,
## head, ears, arms, legs, four faces); each has its own sprite sheet in
## assets/sprites/bears/ (+ horror/) and a couple of optional accessory cells:
##   cell 10 = tail ("puff" / "long") or skirt,   cell 11 = head topper.
## The plain teddy bear sheet keeps the original 10-cell layout.
extends RefCounted

const SPECIES := {
	"bear": {"label": "Teddy Bear", "sheet": "bears/bear", "cells": 10,
		"ear_pos": Vector2(36, -38), "ear_offset": -0.06, "ear_scale": 1.0, "ear_flop": 1.0,
		"tail": "", "skirt": false, "topper": ""},
	"bunny": {"label": "Teddy Bunny", "sheet": "bears/bunny", "cells": 12,
		"ear_pos": Vector2(20, -34), "ear_offset": -0.3, "ear_scale": 1.0, "ear_flop": 2.2,
		"tail": "puff", "tail_tint": false, "skirt": false,
		"topper": "front", "topper_pos": Vector2(32, -40), "topper_rot": 0.35, "topper_scale": 0.42, "topper_tint": false},
	"dino": {"label": "Small Dino", "sheet": "bears/dino", "cells": 12,
		"ear_pos": Vector2(30, -40), "ear_offset": -0.06, "ear_scale": 0.85, "ear_flop": 0.35,
		"tail": "long", "tail_tint": true, "skirt": false,
		"topper": "back", "topper_pos": Vector2(0, -42), "topper_rot": 0.0, "topper_scale": 0.85, "topper_tint": true},
	"princess": {"label": "Teddy Bear Princess", "sheet": "bears/princess", "cells": 12,
		"ear_pos": Vector2(36, -38), "ear_offset": -0.06, "ear_scale": 1.0, "ear_flop": 1.0,
		"tail": "", "skirt": true,
		"topper": "front", "topper_pos": Vector2(0, -50), "topper_rot": 0.0, "topper_scale": 0.55, "topper_tint": false},
}

## Who is what. Player 2 takes the character of whichever AI sits out.
const BY_NAME := {"Player": "bear", "Player 1": "bear", "Oswald": "bunny", "Harald": "dino", "Theodor": "princess"}


static func for_name(n: String) -> String:
	if n == "Player 2":
		return BY_NAME[Settings.AI_NAMES[Settings.sitting_out]]
	return BY_NAME.get(n, "bear")


## The spec for a species. If its sheet (and every placeholder for it) is missing,
## the character falls back to the plain teddy bear rig.
static func info(s: String) -> Dictionary:
	var sp: Dictionary = SPECIES.get(s, SPECIES["bear"])
	if sp != SPECIES["bear"] and Assets.resolve(sp["sheet"]) == "":
		return SPECIES["bear"]
	return sp
