## Terrain types and their physical properties. Purely data: the look of a
## terrain is only the "tile" index into the tile sheet.
extends RefCounted

enum { NORMAL, ICE, HONEY, BOUNCY, CONVEYOR_R, CONVEYOR_D, CONVEYOR_L, CONVEYOR_U }
const COUNT := 8

# accel/brake/speed multiply the bear's own values. bounce = wall restitution.
# push = conveyor belt velocity (px/s). tile = index in the tile sheet.
# brake_min = braking (px/s^2) a bear always keeps here, however stuffed (keeps ice controllable).
const PROPS := [
	{"name": "Rug", "accel": 1.0, "brake": 1.0, "speed": 1.0, "bounce": 0.15, "push": Vector2(0, 0), "brake_min": 0.0, "tile": 0, "color": Color(0.94, 0.9, 0.82)},
	{"name": "Ice", "accel": 0.5, "brake": 0.22, "speed": 1.08, "bounce": 0.3, "push": Vector2(0, 0), "brake_min": 110.0, "tile": 2, "color": Color(0.75, 0.9, 0.97)},
	{"name": "Honey", "accel": 0.75, "brake": 2.6, "speed": 0.45, "bounce": 0.0, "push": Vector2(0, 0), "brake_min": 0.0, "tile": 3, "color": Color(0.93, 0.72, 0.3)},
	{"name": "Bouncy", "accel": 1.0, "brake": 0.8, "speed": 1.05, "bounce": 0.95, "push": Vector2(0, 0), "brake_min": 0.0, "tile": 4, "color": Color(0.95, 0.68, 0.76)},
	{"name": "Conveyor", "accel": 1.0, "brake": 1.0, "speed": 1.0, "bounce": 0.15, "push": Vector2(75, 0), "brake_min": 0.0, "tile": 5, "color": Color(0.67, 0.71, 0.75)},
	{"name": "Conveyor", "accel": 1.0, "brake": 1.0, "speed": 1.0, "bounce": 0.15, "push": Vector2(0, 75), "brake_min": 0.0, "tile": 5, "color": Color(0.67, 0.71, 0.75)},
	{"name": "Conveyor", "accel": 1.0, "brake": 1.0, "speed": 1.0, "bounce": 0.15, "push": Vector2(-75, 0), "brake_min": 0.0, "tile": 5, "color": Color(0.67, 0.71, 0.75)},
	{"name": "Conveyor", "accel": 1.0, "brake": 1.0, "speed": 1.0, "bounce": 0.15, "push": Vector2(0, -75), "brake_min": 0.0, "tile": 5, "color": Color(0.67, 0.71, 0.75)},
]

const CHARS := {".": NORMAL, "i": ICE, "h": HONEY, "b": BOUNCY, ">": CONVEYOR_R, "v": CONVEYOR_D, "<": CONVEYOR_L, "^": CONVEYOR_U}


static func props(t: int) -> Dictionary:
	return PROPS[clampi(t, 0, COUNT - 1)]


static func is_conveyor(t: int) -> bool:
	return t >= CONVEYOR_R


static func conveyor_rotation(t: int) -> float:
	return float(t - CONVEYOR_R) * PI * 0.5
