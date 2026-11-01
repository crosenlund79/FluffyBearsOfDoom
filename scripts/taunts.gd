## Taunt lines and reaction animations for both modes. Edit freely.
extends RefCounted

const LINES := {
	"normal": {
		"stun": ["Boop!", "Nyah nyah!", "Nap time~", "Sorry not sorry!", "Ha! Fluffed!", "Bonk!", "Sweet dreams!", "Got your nose!"],
		"self_stun": ["Pfft, own goal!", "Hee hee, nice one!", "Smooth moves!", "Did you mean to do that?"],
		"steal": ["Mine now!", "Ooh, so fluffy!", "Yoink!", "Om nom nom!", "Thanks for sharing!", "Finders keepers!"],
		"greedy": ["I'm a BALLOON!", "So... round...", "Too much? Never!", "Wheee, wobble!"],
		"robbed": ["Hey! Give it back!", "My stuffing!", "Thief!!", "Not cool!", "I'm telling!"],
	},
	"horror": {
		"stun": ["Hush now.", "Sleep, little one.", "Shhhh...", "Don't fight it.", "Lie still.", "Heh heh heh..."],
		"self_stun": ["Clumsy, clumsy...", "It found you first.", "The nursery remembers."],
		"steal": ["So soft inside...", "Your stuffing is MINE.", "Just a little more...", "Join us.", "It doesn't hurt. Much."],
		"greedy": ["Fuller... FULLER...", "Can't... stop... eating...", "So heavy. So happy."],
		"robbed": ["Give... it... BACK.", "I'm so empty...", "I will find you.", "Cold... so cold..."],
	},
}

## Extra lines per bear, mixed in now and then.
const PERSONAL := {
	"normal": {
		"Oswald": ["Too easy, darling.", "Oswald wins again~"],
		"Harald": ["HARALD SMASH! ...gently.", "Hehe, squishy!"],
		"Theodor": ["Behold, Theodor the Magnificent!", "A tragedy... for YOU."],
	},
	"horror": {
		"Oswald": ["Oswald is never full.", "Pretty seams. I'll keep them."],
		"Harald": ["Harald wants to hug you. Forever.", "Hug. Hug. HUG."],
		"Theodor": ["Theodor sees you.", "I counted your stitches."],
	},
}

## Visual-only reactions (they never lock movement).
const ANIMS := {
	"normal": ["wiggle", "spin", "hop", "cheer"],
	"horror": ["tilt", "twitch", "lean", "shudder"],
}

const VOICE := {"Player": 1.0, "Player 1": 1.0, "Player 2": 1.18, "Oswald": 0.95, "Harald": 0.82, "Theodor": 1.1}


static func line(kind: String, who: String, rng: RandomNumberGenerator) -> String:
	var mode: String = Settings.style()
	var personal: Array = PERSONAL[mode].get(who, [])
	if not personal.is_empty() and kind in ["stun", "steal"] and rng.randf() < 0.3:
		return personal[rng.randi() % personal.size()]
	var lines: Array = LINES[mode][kind]
	return lines[rng.randi() % lines.size()]


static func anim(rng: RandomNumberGenerator) -> String:
	var list: Array = ANIMS[Settings.style()]
	return list[rng.randi() % list.size()]
