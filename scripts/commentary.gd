## Ringside commentary for tournament and spectator matches: short, reactive
## text lines about what is really happening, in a small panel beside the arena
## (bottom left, under the card stack). Major moments win; minor ones wait for
## a cooldown, and recently used lines are not repeated. Optional event feed
## (bottom right) for spectators: a compact log of everything notable.
extends Node

const UiStyle = preload("res://scripts/ui_style.gd")
const StitchPanel = preload("res://scripts/stitch_panel.gd")
const Personalities = preload("res://scripts/personalities.gd")

const GAP := 3.2          # seconds between minor lines
const KIND_GAP := 8.0     # the same kind of moment is not commented again for this long
const QUIET := 10.0       # after this long without a line, a word about someone's style
const MEMORY := 14        # recently used lines (never repeated while remembered)

## {b} = the bear in question, {o} = the other bear (owner / victim), {n} = a number.
const LINES := {
	"intro": ["Welcome to the Tournament of Doom! Stuffing will be lost tonight.",
		"The nursery falls silent. Four bears. One winner. Plenty of seams.",
		"Ladies, gentlemen and haunted plushies: the round begins!"],
	"chain": ["A spectacular chain reaction! Was that intentional?",
		"{o} sets off a {n}-bomb chain! The nursery shakes!",
		"BOOM, boom, boom! {o} has discovered dominoes.",
		"Chain reaction! Somebody call the upholsterer."],
	"multi_hit": ["{o} flattens {n} bears with one bomb! Ruthless!",
		"Two birds, one bomb. {o} is very pleased.",
		"A multi-stun from {o}! The crowd gasps!"],
	"close_escape": ["{b} survives by approximately one whisker!",
		"Ooh! {b} felt the heat on that one!",
		"{b} slips out of the blast with a seam to spare!",
		"Close! {b}'s fur is slightly singed."],
	"kick": ["{b} sends a bomb travelling across the arena!",
		"What a kick from {b}! Mind your toes!",
		"{b} punts it! Somebody's getting a surprise delivery."],
	"theft": ["{b}'s at it again! Someone check their stuffing!",
		"{b} is pulling stuffing like there's no tomorrow!",
		"A daring heist by {b}: {n} fluff, gone!",
		"{b} helps themselves. Generously."],
	"big_loss": ["{b} just lost {n} fluff! That's going to leave a dent.",
		"Ouch! {b} is looking decidedly deflated.",
		"{b} is leaking stuffing everywhere!"],
	"self_hit": ["{b} blew themselves up. Bold strategy.",
		"Er... {b}, the bomb is meant for the OTHER bears.",
		"An unusual move from {b}: self-detonation!"],
	"lead": ["{b} takes the lead!", "New leader: {b}! The cards are shuffling!",
		"{b} storms to the top of the pile!"],
	"comeback": ["What a comeback! {b} from last to first!",
		"Never count out {b}! From the bottom of the pile to the top!"],
	"eliminated": ["{b} is out of stuffing! Just an empty pillowcase now.",
		"And {b} is DEFLATED! Pour one out.",
		"{b} has been unstuffed. Ghastly."],
	"survivor": ["{b} is the last bear stuffed!", "Only {b} remains! The nursery belongs to them!"],
	"combo": ["{b} has kick AND extras! That's a dangerous toolbox.",
		"{b} is collecting power-ups like rare stamps!"],
	"princess": ["The princess is coming! Everybody pretend to be furniture.",
		"Her Highness has arrived. Royal decree: somebody gets shot."],
	"princess_shot": ["The princess blasts {b}! Royalty is brutal.", "{b} meets the royal shotgun. Ouch."],
	"clown": ["The box is rattling... nobody look at the box.", "Here comes the clown. Nobody laugh."],
	"clown_hit": ["BONK! The clown hammers {b}!", "{b} gets a mallet to the head. Hilarious, says the clown."],
	"duck": ["The Doom Duck Parade waddles in! Ducks: deadly and adorable."],
	"shuffle": ["Biome Shuffle! Hold on to your fluff!", "The floor is changing! Again!"],
	"winner": ["{b} wins the round! The stuffing is theirs!",
		"And it's {b}! Fluffiest bear in the nursery!",
		"Victory for {b}! The others are looking a little flat."],
	"tournament": ["{b} is the CHAMPION of the Tournament of Doom!"],
}

## A word on somebody's style, for quiet moments.
const STYLE := {
	"Oswald": ["Oswald watches, waits, and pounces. Classic Oswald.", "Oswald is weighing his options. Carefully."],
	"Harald": ["Harald has apparently declared war on the entire nursery!", "Harald has never met a bomb he didn't like."],
	"Theodor": ["Theodor is playing defensively. Very defensively.", "Theodor has an escape plan for his escape plan."],
	"Mabel": ["Mabel is sniffing around for stunned bears...", "Keep an eye on your stuffing near Mabel."],
	"Grimble": ["Grimble is lurking near a choke point. Suspicious.", "Grimble loves a sticky floor. And a trapped bear."],
	"Balthazar": ["Balthazar is calculating. Something is about to go off.", "Balthazar's timing is impeccable. Worryingly so."],
	"Pip": ["Pip has a plan. Probably. Maybe.", "Pip is everywhere at once. Nobody knows why."],
	"Brunhilde": ["Brunhilde is guarding her corner like a dragon.", "Do NOT wander into Brunhilde's territory."],
	"Knuckles": ["Knuckles is looking for something to kick.", "Knuckles dreams of chain reactions."],
	"Vesper": ["And Vesper is waiting for the perfect moment...", "Vesper circles. Patiently. Hungrily."],
}

var game
var feed_enabled := false
var panel: Control
var line_label: Label
var feed_box: VBoxContainer
var _rng := RandomNumberGenerator.new()
var _since := 99.0          # seconds since the last line
var _kind_at := {}          # kind -> time of its last line
var _recent: Array = []
var _clock := 0.0
var _poll := 0.0
var _track := {}            # bear -> {stolen, fluff, window:[...], out, worst_rank}
var _leader = null
var _intro_done := false
var _survivor_said := false
var lines_said: Array = []  # [kind, text] for tests


func setup(g, with_feed: bool) -> void:
	game = g
	feed_enabled = with_feed
	_rng.randomize()
	game.game_event.connect(_on_event)
	var root: Control = game.hud.root
	panel = StitchPanel.new()
	panel.position = Vector2(14, 604)
	panel.size = Vector2(250, 104)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var head := UiStyle.label("Ringside", 13, UiStyle.ROSE_DARK)
	v.add_child(head)
	line_label = UiStyle.label("", 15, UiStyle.INK)
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.custom_minimum_size = Vector2(226, 0)
	v.add_child(line_label)
	if feed_enabled:
		var fp := StitchPanel.new()
		fp.position = Vector2(1016, 604)
		fp.size = Vector2(250, 104)
		fp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fp)
		feed_box = VBoxContainer.new()
		feed_box.add_theme_constant_override("separation", -2)
		feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fp.add_child(feed_box)
		var head2 := HBoxContainer.new()
		head2.add_theme_constant_override("separation", 4)
		var ev := UiStyle.label("Events", 13, UiStyle.ROSE_DARK)
		ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head2.add_child(ev)
		for x in [1, 2, 4]:
			var sb := Button.new()
			sb.text = "%d×" % x
			sb.focus_mode = Control.FOCUS_NONE
			sb.custom_minimum_size = Vector2(30, 18)
			sb.add_theme_font_size_override("font_size", 12)
			sb.pressed.connect(func(): set_speed(x))
			head2.add_child(sb)
		feed_box.add_child(head2)
	for b in game.bears:
		_track[b] = {"stolen": b.stolen_total, "window": [], "out": false, "worst": 1}


func set_speed(x: float) -> void:
	Engine.time_scale = x
	Engine.physics_ticks_per_second = int(60 * x)   # same 1/60 s steps at any speed
	Engine.max_physics_steps_per_frame = maxi(8, int(8 * x))
	_feed("Speed %d×" % int(x))


func _unhandled_input(event: InputEvent) -> void:
	if feed_enabled and event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: set_speed(1.0)
			KEY_2: set_speed(2.0)
			KEY_4: set_speed(4.0)


func _process(delta: float) -> void:
	if game == null or game.state != game.State.PLAYING:
		return
	_clock += delta
	_since += delta
	if not _intro_done:
		_intro_done = true
		say("intro", 3, {})
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		_watch()
	if _since > QUIET:
		var ais: Array = game.bears.filter(func(b): return not b.is_human and not b.eliminated and STYLE.has(b.bear_name))
		if not ais.is_empty():
			var b = ais[_rng.randi() % ais.size()]
			_say_text("style", 1, _pick(STYLE[b.bear_name]))


## Things we see rather than are told: theft, losses, lead changes, comebacks,
## eliminations, the last bear standing and power-up hoards.
func _watch() -> void:
	var ranking: Array = game.hud.ranking
	for b in game.bears:
		var tr: Dictionary = _track[b]
		var got: float = b.stolen_total - tr["stolen"]
		if got >= 25.0:
			say("theft", 2, {"b": b, "n": roundi(got)})
			_feed("%s steals %d" % [b.bear_name, roundi(got)])
			tr["stolen"] = b.stolen_total
		elif b.stealing == false:
			tr["stolen"] = b.stolen_total
		# losses over the last 3 s
		tr["window"].append([_clock, b.fluff_lost])
		while tr["window"].size() > 1 and _clock - tr["window"][0][0] > 3.0:
			tr["window"].pop_front()
		var lost: float = b.fluff_lost - tr["window"][0][1]
		if lost >= 35.0:
			say("big_loss", 2, {"b": b, "n": roundi(lost)})
			_feed("%s loses %d" % [b.bear_name, roundi(lost)])
			tr["window"] = [[_clock, b.fluff_lost]]
		if b.eliminated and not tr["out"]:
			tr["out"] = true
			say("eliminated", 3, {"b": b})
			_feed("%s is out!" % b.bear_name)
		var r := ranking.find(b) + 1
		if r > 0 and _clock > 15.0:
			tr["worst"] = maxi(tr["worst"], r)
		var combo := int(b.can_kick) + int(b.has_line) + int(b.has_rubber) + int(b.prox_charges > 0) + int(b.immortal_t > 0.0)
		if combo >= 3 and not tr.get("combo", false):
			tr["combo"] = true
			say("combo", 1, {"b": b})
	if not ranking.is_empty() and ranking[0] != _leader:
		var lead = ranking[0]
		if _leader != null and _clock > 8.0:
			if _track[lead]["worst"] >= 4:
				say("comeback", 3, {"b": lead})
				_track[lead]["worst"] = 1
			else:
				say("lead", 2, {"b": lead})
			_feed("%s leads" % lead.bear_name)
		_leader = lead
	var alive: Array = game.bears.filter(func(b): return not b.eliminated)
	if alive.size() == 1 and not _survivor_said:
		_survivor_said = true
		say("survivor", 3, {"b": alive[0]})


func _on_event(kind: String, data: Dictionary) -> void:
	match kind:
		"chain":
			say("chain", 3, {"o": data.get("owner"), "n": data.get("count", 2)})
			_feed("Chain x%d" % data.get("count", 2))
		"multi_hit":
			say("multi_hit", 3, {"o": data.get("owner"), "n": data.get("count", 2)})
			var who = data.get("owner")
			_feed("%s stuns %d" % [who.bear_name if who != null else "Blast", data.get("count", 2)])
		"close_escape":
			say("close_escape", 1, data)
		"kick":
			say("kick", 1, data)
			_feed("%s kicks" % data["bear"].bear_name)
		"self_hit":
			say("self_hit", 2, data)
			_feed("%s self-stun" % data["bear"].bear_name)
		"princess", "clown", "duck", "shuffle":
			say(kind, 2, data)
			_feed(kind.capitalize() + "!")
		"princess_shot", "clown_hit":
			say(kind, 2, data)
			_feed("%s hit by the %s" % [data["bear"].bear_name, "princess" if kind == "princess_shot" else "clown"])
		"match_end":
			var alive: Array = game.bears.filter(func(b): return not b.eliminated)
			if alive.size() == 1 and not _survivor_said:
				_survivor_said = true
				_kind_at.erase("survivor")
				say("survivor", 4, {"b": alive[0]})
			else:
				say("winner", 4, {"b": data["winner"]})
			_feed("%s wins" % data["winner"].bear_name)


## Say something about `kind` if it's worth it right now (priority 1 minor .. 4 must).
func say(kind: String, priority: int, data: Dictionary) -> void:
	if not LINES.has(kind):
		return
	var text := _pick(LINES[kind])
	for key in ["b", "o"]:
		var who = data.get(key)
		text = text.replace("{%s}" % key, who.bear_name if who != null and is_instance_valid(who) else "Somebody")
	text = text.replace("{n}", str(data.get("n", 2)))
	_say_text(kind, priority, text)


func _say_text(kind: String, priority: int, text: String) -> void:
	if not Settings.commentary:
		return
	if priority < 4:
		if _clock - _kind_at.get(kind, -99.0) < KIND_GAP:
			return
		if priority < 3 and _since < GAP:
			return
		if priority >= 3 and _since < 1.0:
			return
	_kind_at[kind] = _clock
	_since = 0.0
	_recent.append(text)
	if _recent.size() > MEMORY:
		_recent.pop_front()
	lines_said.append([kind, text])
	line_label.text = text
	line_label.modulate.a = 0.0
	line_label.scale = Vector2(0.96, 0.96)
	var tw := line_label.create_tween()
	tw.tween_property(line_label, "modulate:a", 1.0, 0.18)
	if priority >= 3:
		Sfx.play("menu", 1.25, -12.0)   # a soft tick for the big moments


func _pick(options: Array) -> String:
	var fresh := options.filter(func(t): return not t in _recent)
	var pool: Array = fresh if not fresh.is_empty() else options
	return pool[_rng.randi() % pool.size()]


func _feed(text: String) -> void:
	if feed_box == null:
		return
	var l := UiStyle.label("%d:%02d  %s" % [int(game.active_time) / 60, int(game.active_time) % 60, text], 13, UiStyle.INK_SOFT)
	l.clip_text = true
	l.custom_minimum_size = Vector2(226, 0)
	feed_box.add_child(l)
	while feed_box.get_child_count() > 6:   # title + last five
		feed_box.get_child(1).free()
