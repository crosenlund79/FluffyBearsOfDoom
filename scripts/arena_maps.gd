## Arena definitions. Walls follow the classic pillar grid; "terrain" rows use
##   .  rug    i  ice    h  honey    b  bouncy    > v < ^  conveyor belts
## Leave "terrain" empty for a plain rug everywhere.
extends RefCounted

const MAPS := [
	{
		"name": "Traditional Nursery",
		"desc": "A cosy rug, pillow blocks and wooden toy pillars. Honest, classic mayhem.",
		"block_density": 0.72,
		"terrain": [],
	},
	{
		"name": "Frozen Nursery",
		"desc": "Somebody left the window open. Tiny feet, slippery floor, enormous bellies.",
		"block_density": 0.62,
		"terrain": [
			".................",
			".................",
			"....iiiiiiiii....",
			"....iiiiiiiii....",
			".iiiiiiiiiiiiiii.",
			".iiiiiii.iiiiiii.",
			".iiiiiii.iiiiiii.",
			".iiiii.....iiiii.",
			".iiiiiii.iiiiiii.",
			".iiiiiii.iiiiiii.",
			".iiiiiiiiiiiiiii.",
			"....iiiiiiiii....",
			"....iiiiiiiii....",
			".................",
			".................",
		],
	},
	{
		"name": "Playroom Mayhem",
		"desc": "Honey spills, bouncy mattresses and toy-train conveyor belts.",
		"block_density": 0.66,
		"terrain": [
			".................",
			".................",
			".....>>>>>>>.....",
			".................",
			"..hh.........bb..",
			"..hh.........bb..",
			"....v.......^....",
			"....v..iii..^....",
			"....v.......^....",
			"..bb.........hh..",
			"..bb.........hh..",
			".................",
			".....<<<<<<<.....",
			".................",
			".................",
		],
	},
]
