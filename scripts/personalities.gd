## The ten named AI opponents. They reuse the four existing bear rigs with a
## colour tint each, and differ only in HOW they decide (weights read by the one
## shared tactical AI in ai_controller.gd), never in speed or information.
## The difficulty level (Easy / Normal / Hard) is their skill on top of this.
extends RefCounted

## Weights (1.0 / 0.0 = neutral):
##   aggro    hunting rivals and bombing them         greed    robbing stunned bears, looting chairs
##   pickup   chasing power-ups                       caution  extra seconds of slack before blasts
##   blocks   clearing cushion blocks                 kick     kicking bombs (and chain set-ups)
##   trap     choke-point / corridor traps            timing   predicts movement, chains and timing
##   erratic  chance per decision of a whim          home     how strongly it guards its own quarter
##   patience only strikes at weakened bears         blunder  extra chance of a careless bomb
const ROSTER := [
	{"name": "Oswald", "species": "bunny", "color": Color("8eaecb"), "threat": 3,
		"blurb": "Balanced, cautious, opportunistic.",
		"w": {"caution": 0.15, "greed": 1.15, "pickup": 1.1}},
	{"name": "Harald", "species": "dino", "color": Color("a3bf8c"), "threat": 6,
		"blurb": "Aggressive bomber. Constant pressure.",
		"w": {"aggro": 1.9, "caution": -0.1, "blocks": 1.2, "blunder": 0.03}},
	{"name": "Theodor", "species": "princess", "color": Color("c39bcb"), "threat": 2,
		"blurb": "Defensive. Plans every escape.",
		"w": {"aggro": 0.55, "caution": 0.35, "blocks": 0.85}},
	{"name": "Mabel", "species": "bunny", "color": Color("e0a07a"), "threat": 5,
		"blurb": "Stuffing thief. Smells a stunned bear a mile off.",
		"w": {"greed": 2.0, "aggro": 0.75, "pickup": 0.8, "blocks": 0.85}},
	{"name": "Grimble", "species": "dino", "color": Color("7f9c88"), "threat": 5,
		"blurb": "Trap specialist. Loves choke points and sticky floors.",
		"w": {"trap": 1.0, "aggro": 1.1, "caution": 0.1}},
	{"name": "Balthazar", "species": "bear", "color": Color("8a7fb0"), "threat": 8,
		"blurb": "Calculating strategist. Impeccable bomb timing.",
		"w": {"timing": 1.0, "aggro": 1.25, "caution": 0.1, "trap": 0.5}},
	{"name": "Pip", "species": "bunny", "color": Color("f0d070"), "threat": 2,
		"blurb": "Fast thinking, faster grabbing, no plan at all.",
		"w": {"pickup": 1.8, "erratic": 0.22, "caution": -0.05, "blunder": 0.04}},
	{"name": "Brunhilde", "species": "princess", "color": Color("d07a8a"), "threat": 4,
		"blurb": "Territorial. Her quarter, her rules.",
		"w": {"home": 1.0, "aggro": 1.2, "blocks": 1.1}},
	{"name": "Knuckles", "species": "bear", "color": Color("b0896a"), "threat": 6,
		"blurb": "Bomb-kicking specialist. Chain reactions are art.",
		"w": {"kick": 1.0, "aggro": 1.2, "pickup": 1.1}},
	{"name": "Vesper", "species": "dino", "color": Color("6f7c9e"), "threat": 7,
		"blurb": "Patient hunter. Waits for weakness.",
		"w": {"patience": 1.0, "greed": 1.35, "caution": 0.2, "timing": 0.5}},
]

const DEFAULTS := {"aggro": 1.0, "greed": 1.0, "pickup": 1.0, "caution": 0.0, "blocks": 1.0,
	"kick": 0.0, "trap": 0.0, "timing": 0.0, "erratic": 0.0, "home": 0.0, "patience": 0.0, "blunder": 0.0}


static func names() -> Array:
	return ROSTER.map(func(p): return p["name"])


static func find(n: String) -> Dictionary:
	for p in ROSTER:
		if p["name"] == n:
			return p
	return {}


## Full weight set for a bear name (neutral for anyone not in the roster, e.g. the human).
static func weights(n: String) -> Dictionary:
	var w := DEFAULTS.duplicate()
	var p := find(n)
	if not p.is_empty():
		w.merge(p["w"], true)
	return w


## A roster entry for Game (see Settings.roster()).
static func roster_entry(n: String, level: String) -> Dictionary:
	var p := find(n)
	return {"name": n, "color": p["color"], "controller": level, "schemes": [], "species": p["species"]}
