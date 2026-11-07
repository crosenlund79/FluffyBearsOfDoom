## Tournament of Doom: ten rounds, you against three of the ten named AI bears
## each round. Win a round (the normal victory rule: most stuffing at the
## whistle, an instant win, or last bear stuffed) to advance. Lose and it costs
## one of three lives and the round is replayed; lose with no lives left and the
## run is over. Progress autosaves after every round (user://tournament.cfg).
##
## Leaderboards (user://leaderboards.cfg) take only finished, legitimate wins:
## no sped-up clock and no developer switches. They are kept apart per difficulty
## and rules version so only comparable runs compete.
extends RefCounted

const Personalities = preload("res://scripts/personalities.gd")
const SAVE_PATH := "user://tournament.cfg"
const BOARD_PATH := "user://leaderboards.cfg"
const RULES_VERSION := 1     # bump when the schedule or rules change (keeps leaderboards comparable)
const ROUNDS := 10
const LIVES := 3
const ROUND_TIME_INDEX := 0  # 90 s rounds: short and chaotic
const TOP := 10
const POINTS := [4, 2, 1, 0] # standings points for 1st..4th

## Every opponent appears in exactly three rounds; the combined threat rises
## round by round (7, 8, 10, 11, 14, 15, 18, 19, 21, 21).
const SCHEDULE := [
	["Oswald", "Theodor", "Pip"],
	["Theodor", "Pip", "Brunhilde"],
	["Oswald", "Mabel", "Pip"],
	["Theodor", "Grimble", "Brunhilde"],
	["Oswald", "Harald", "Mabel"],
	["Knuckles", "Grimble", "Brunhilde"],
	["Harald", "Vesper", "Mabel"],
	["Knuckles", "Balthazar", "Grimble"],
	["Harald", "Vesper", "Balthazar"],
	["Knuckles", "Balthazar", "Vesper"],
]
const ARENAS := [0, 1, 2, 0, 1, 2, 0, 1, 2, 2]

var difficulty := "normal"
var mode := "normal"           # theme when the run started ("mixed" if it changed)
var player_name := "Player"
var round_index := 0           # the next round to play (0-based)
var lives := LIVES
var attempts := 0              # rounds played, including lost ones
var history: Array = []        # one entry per round played (see record_round)
var standings := {}            # bear name -> points
var total_time := 0.0          # active gameplay seconds, all rounds played
var total_lost := 0.0          # stuffing the player lost, all rounds played
var total_gained := 0.0        # stuffing the player collected, all rounds played
var valid := true              # false once the clock was sped up or a dev switch used
var status := "active"         # "active", "won" or "failed"
var in_round := false          # a round is being played right now (quitting it forfeits)
var started := ""


static func new_run(level: String, name: String) -> RefCounted:
	var t = load("res://scripts/tournament.gd").new()
	t.difficulty = level
	t.player_name = name.strip_edges() if name.strip_edges() != "" else "Player"
	if t.player_name in Personalities.names():
		t.player_name += " (you)"   # never share a name with an opponent
	t.mode = Settings.mode
	t.started = Time.get_datetime_string_from_system(false, true)
	t.valid = not Settings.dev_flags
	for n in Personalities.names():
		t.standings[n] = 0
	t.standings[t.player_name] = 0
	return t


func opponents(r: int) -> Array:
	return SCHEDULE[clampi(r, 0, ROUNDS - 1)]


## The next three opponents after this round (for the board).
func upcoming(count := 3) -> Array:
	var out := []
	for r in range(round_index + 1, ROUNDS):
		for n in SCHEDULE[r]:
			if not n in out and not n in opponents(round_index):
				out.append(n)
	return out.slice(0, count)


## Line-up and rules for the next round (Settings.roster_override / match_rules).
func prepare_round() -> void:
	var line := [{"name": player_name, "color": Settings.HUMAN_COLORS[0], "controller": "human", "schemes": ["p1", "p2"]}]
	for n in opponents(round_index):
		line.append(Personalities.roster_entry(n, difficulty))
	Settings.roster_override = line
	Settings.match_rules = {"arena_index": ARENAS[round_index], "round_time_index": ROUND_TIME_INDEX,
		"instant_win": preload("res://scripts/tuning.gd").INSTANT_WIN_FLUFF, "diseases": true, "human_count": 1}
	if Settings.mode != mode:
		mode = "mixed"
	in_round = true
	save()


## Book a finished round. `ranking` is the game's final order (bears).
func record_round(game, ranking: Array) -> void:
	in_round = false
	attempts += 1
	var me = null
	for b in game.bears:
		if b.is_human:
			me = b
	var place := ranking.find(me) + 1
	var won := place == 1
	var entry := {"round": round_index + 1, "attempt": attempts, "won": won, "place": place,
		"time": game.active_time, "lost": me.fluff_lost, "gained": me.fluff_gained,
		"fluff": roundi(me.fluff), "order": [], "winner": ranking[0].bear_name}
	for i in ranking.size():
		var b = ranking[i]
		entry["order"].append({"name": b.bear_name, "fluff": roundi(b.fluff), "lost": roundi(b.fluff_lost), "gained": roundi(b.fluff_gained)})
		var key: String = player_name if b.is_human else b.bear_name
		standings[key] = standings.get(key, 0) + POINTS[i]
	history.append(entry)
	total_time += game.active_time
	total_lost += me.fluff_lost
	total_gained += me.fluff_gained
	if game.speed_tampered:
		valid = false
	if won:
		round_index += 1
		if round_index >= ROUNDS:
			status = "won"
	else:
		lives -= 1
		if lives <= 0:
			status = "failed"
	save()


## Leaving a round before it ends counts as losing it (no free retries).
func forfeit_round() -> void:
	if not in_round:
		return
	in_round = false
	attempts += 1
	history.append({"round": round_index + 1, "attempt": attempts, "won": false, "place": 4, "time": 0.0,
		"lost": 0.0, "gained": 0.0, "fluff": 0, "order": [], "winner": "(forfeit)"})
	lives -= 1
	if lives <= 0:
		status = "failed"
	save()


func eligible() -> bool:
	return status == "won" and valid and not Settings.dev_flags


func rounds_won() -> int:
	return history.filter(func(h): return h["won"]).size()


func result_text() -> String:
	if status == "won":
		return "Champion (%d/%d lives left)" % [lives, LIVES]
	if status == "failed":
		return "Knocked out in round %d" % (round_index + 1)
	return "Round %d of %d" % [round_index + 1, ROUNDS]


# --- persistence ---------------------------------------------------------------------

const FIELDS := ["difficulty", "mode", "player_name", "round_index", "lives", "attempts", "history",
	"standings", "total_time", "total_lost", "total_gained", "valid", "status", "in_round", "started"]


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("run", "rules_version", RULES_VERSION)
	for k in FIELDS:
		cf.set_value("run", k, get(k))
	cf.save(SAVE_PATH)


## The saved run, or null. A round that was still being played when the game
## closed counts as forfeited.
static func load_saved() -> RefCounted:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK or cf.get_value("run", "rules_version", 0) != RULES_VERSION:
		return null
	var t = load("res://scripts/tournament.gd").new()
	for k in FIELDS:
		if cf.has_section_key("run", k):
			t.set(k, cf.get_value("run", k))
	if t.in_round:
		t.forfeit_round()
	return t


static func clear_saved() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# --- leaderboards -----------------------------------------------------------------------

## Runs only compete with runs of the same difficulty and rules version.
static func bucket(level: String) -> String:
	return "v%d_%s" % [RULES_VERSION, level]


static func boards(level: String) -> Dictionary:
	var cf := ConfigFile.new()
	cf.load(BOARD_PATH)
	return {"fastest": cf.get_value(bucket(level), "fastest", []), "least_lost": cf.get_value(bucket(level), "least_lost", [])}


## Fastest: lowest total active time. Least lost: lowest total stuffing lost,
## ties broken by the faster time.
static func sort_fastest(a: Dictionary, b: Dictionary) -> bool:
	return a["time"] < b["time"]


static func sort_least_lost(a: Dictionary, b: Dictionary) -> bool:
	if absf(a["lost"] - b["lost"]) > 0.001:
		return a["lost"] < b["lost"]
	return a["time"] < b["time"]


## Add this run to both boards. Returns {"fastest": rank or 0, "least_lost": rank
## or 0, "pb_time": bool, "pb_lost": bool}. Ineligible runs are never saved.
func submit() -> Dictionary:
	var out := {"fastest": 0, "least_lost": 0, "pb_time": false, "pb_lost": false, "eligible": eligible()}
	if not eligible():
		return out
	var entry := {"name": player_name, "date": Time.get_datetime_string_from_system(false, true),
		"time": total_time, "lost": total_lost, "gained": total_gained, "result": result_text(),
		"difficulty": difficulty, "mode": mode, "rules": RULES_VERSION, "rounds": attempts}
	var cf := ConfigFile.new()
	cf.load(BOARD_PATH)
	var key := bucket(difficulty)
	for board in ["fastest", "least_lost"]:
		var list: Array = cf.get_value(key, board, [])
		var mine := list.filter(func(e): return e["name"] == player_name)
		if board == "fastest":
			out["pb_time"] = mine.is_empty() or mine.all(func(e): return total_time < e["time"])
		else:
			out["pb_lost"] = mine.is_empty() or mine.all(func(e): return total_lost < e["lost"] - 0.001)
		list.append(entry)
		list.sort_custom(sort_fastest if board == "fastest" else sort_least_lost)
		list = list.slice(0, TOP)
		out[board] = list.find(entry) + 1
		cf.set_value(key, board, list)
	cf.save(BOARD_PATH)
	return out


## 1:23.45
static func fmt_time(sec: float) -> String:
	var cs := roundi(sec * 100.0)
	return "%d:%02d.%02d" % [cs / 6000, (cs / 100) % 60, cs % 100]
