## Tournament of Doom screens (hub, between-round board, final results,
## leaderboards) and the AI spectator set-up. Plain menu styling: wallpaper,
## stitched panels, the menu theme. `main` (main.gd) does the switching.
extends Control

const UiStyle = preload("res://scripts/ui_style.gd")
const StitchPanel = preload("res://scripts/stitch_panel.gd")
const BearVisual = preload("res://scripts/bear_visual.gd")
const Personalities = preload("res://scripts/personalities.gd")
const Tournament = preload("res://scripts/tournament.gd")
const Species = preload("res://scripts/species.gd")
const Mode = preload("res://scripts/mode_theme.gd")

var main
var panel: StitchPanel
var body: VBoxContainer
var first_button: Button
var view := ""        # "hub", "board", "final", "boards", "spectate" (tests)


func _init(m) -> void:
	main = m


func _ready() -> void:
	theme = UiStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)


func _draw() -> void:
	UiStyle.draw_wallpaper(self, Rect2(-position, get_viewport_rect().size))


func _frame(title: String, sz := Vector2(1180, 660)) -> void:
	for c in get_children():
		c.queue_free()
	panel = StitchPanel.new()
	panel.size = sz
	panel.position = (Vector2(1280, 720) - sz) * 0.5
	add_child(panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(m)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	m.add_child(body)
	var t := UiStyle.label(title, 38, UiStyle.ROSE_DARK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(t)
	first_button = null


func _text(s: String, sz := 18, col := UiStyle.INK) -> Label:
	var l := UiStyle.label(s, sz, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, cb: Callable, w := 210.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func():
		Sfx.play("menu")
		cb.call())
	if first_button == null:
		first_button = b
	return b


func _buttons(list: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	for e in list:
		h.add_child(_btn(e[0], e[1]))
	return h


func _focus() -> void:
	if first_button != null:
		first_button.grab_focus.call_deferred()


## A small swatch + name for an opponent.
func _who(n: String, sz := 18) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var p := Personalities.find(n)
	var sw := ColorRect.new()
	sw.color = Mode.bear_color(p["color"]) if not p.is_empty() else Settings.HUMAN_COLORS[0]
	sw.custom_minimum_size = Vector2(14, 14)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	h.add_child(UiStyle.label(n, sz))
	return h


# --- hub ---------------------------------------------------------------------------------

func show_hub() -> void:
	view = "hub"
	_frame("Tournament of Doom")
	body.add_child(_text("Ten rounds. You against three of the nursery's ten most notorious bears each round; every one of them turns up three times, and the line-ups get nastier as you go. Win a round to advance (most stuffing at the whistle, an instant win, or last bear stuffed). A lost round costs one of your three lives and is replayed. Leaving a round counts as losing it.", 17, UiStyle.INK_SOFT))
	var saved = Tournament.load_saved()
	if saved != null and saved.status == "active":
		body.add_child(_text("Saved run: %s · round %d of 10 · %d lives · %s · %s" % [saved.player_name, saved.round_index + 1, saved.lives, saved.difficulty.capitalize(), Tournament.fmt_time(saved.total_time)], 20, UiStyle.ROSE_DARK))
		body.add_child(_buttons([["Continue", func(): main.continue_tournament(saved)], ["Show board", func(): show_board(saved)]]))
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 14)
	form.add_child(UiStyle.label("Your name", 20))
	var name_edit := LineEdit.new()
	name_edit.text = Settings.player_name
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(260, 40)
	form.add_child(name_edit)
	form.add_child(UiStyle.label("Opponents", 20))
	var diff := OptionButton.new()
	for l in Settings.LEVEL_LABELS:
		diff.add_item(l)
	diff.selected = 1
	form.add_child(diff)
	body.add_child(form)
	body.add_child(_buttons([["New tournament", func():
		Settings.player_name = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Player"
		Settings.save()
		main.start_tournament(Settings.LEVELS[diff.selected], Settings.player_name)],
		["Leaderboards", func(): show_leaderboards(Settings.LEVELS[diff.selected])],
		["Back", main.show_menu]]))
	body.add_child(_text("The roster:", 18, UiStyle.ROSE_DARK))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	for p in Personalities.ROSTER:
		var h := _who(p["name"], 17)
		h.add_child(UiStyle.label("· " + p["blurb"], 15, UiStyle.INK_SOFT))
		grid.add_child(h)
	body.add_child(grid)
	_focus()


# --- the board between rounds -----------------------------------------------------------------

func show_board(run) -> void:
	view = "board"
	var title := "Tournament of Doom"
	if run.status == "failed":
		title = "Tournament over"
	_frame(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	body.add_child(cols)
	# left: the last round
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(540, 0)
	cols.add_child(left)
	if not run.history.is_empty():
		var h: Dictionary = run.history[-1]
		left.add_child(UiStyle.label("Round %d (attempt %d): %s" % [h["round"], h["attempt"], "WON" if h["won"] else "LOST"], 24, UiStyle.ROSE_DARK if h["won"] else UiStyle.INK))
		left.add_child(UiStyle.label("Winner: %s · %s played" % [h["winner"], Tournament.fmt_time(h["time"])], 18))
		for i in h["order"].size():
			var o: Dictionary = h["order"][i]
			var row := _who(o["name"], 17)
			row.add_child(UiStyle.label("%s · %d fluff (+%d / -%d)" % [["1st", "2nd", "3rd", "4th"][i], o["fluff"], o["gained"], o["lost"]], 16, UiStyle.INK_SOFT))
			left.add_child(row)
		left.add_child(UiStyle.label("Your stuffing: +%d collected, -%d lost" % [roundi(h["gained"]), roundi(h["lost"])], 17))
	left.add_child(UiStyle.label("Lives: %s   Time so far: %s   Lost so far: %d" % ["♥".repeat(run.lives) + "♡".repeat(Tournament.LIVES - run.lives), Tournament.fmt_time(run.total_time), roundi(run.total_lost)], 17, UiStyle.ROSE_DARK))
	if run.status == "active":
		var nxt := UiStyle.label("Next up (round %d): %s" % [run.round_index + 1, ", ".join(run.opponents(run.round_index))], 18)
		left.add_child(nxt)
		var up: Array = run.upcoming()
		if not up.is_empty():
			left.add_child(UiStyle.label("Then: " + ", ".join(up), 15, UiStyle.INK_SOFT))
	# standings
	left.add_child(UiStyle.label("Standings (4 / 2 / 1 / 0 points per round)", 16, UiStyle.ROSE_DARK))
	var st: Array = run.standings.keys()
	st.sort_custom(func(a, b): return run.standings[a] > run.standings[b])
	var sg := GridContainer.new()
	sg.columns = 4
	sg.add_theme_constant_override("h_separation", 18)
	for n in st.slice(0, 8):
		sg.add_child(UiStyle.label("%s %d" % [n, run.standings[n]], 15, UiStyle.ROSE_DARK if n == run.player_name else UiStyle.INK_SOFT))
	left.add_child(sg)
	# right: the ten rounds
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	cols.add_child(right)
	right.add_child(UiStyle.label("Progression", 20, UiStyle.ROSE_DARK))
	for r in Tournament.ROUNDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var tries: Array = run.history.filter(func(x): return x["round"] == r + 1)
		var mark := "·"
		if tries.any(func(x): return x["won"]):
			mark = "✔"
		elif not tries.is_empty():
			mark = "✘" if run.status == "failed" and r == run.round_index else "…"
		var cur: bool = r == run.round_index and run.status == "active"
		var l := UiStyle.label("%s %2d  %s" % [mark, r + 1, ", ".join(Tournament.SCHEDULE[r])], 16, UiStyle.ROSE_DARK if cur else UiStyle.INK)
		row.add_child(l)
		if not tries.is_empty():
			var last: Dictionary = tries[-1]
			row.add_child(UiStyle.label("%s %s" % [["1st", "2nd", "3rd", "4th"][clampi(last["place"] - 1, 0, 3)], Tournament.fmt_time(last["time"])], 14, UiStyle.INK_SOFT))
		right.add_child(row)
	if not run.valid:
		body.add_child(_text("This run used a sped-up clock or a developer switch: it can't enter the leaderboards.", 15, UiStyle.INK_SOFT))
	match run.status:
		"active":
			body.add_child(_buttons([["Next round", func(): main.play_tournament_round()], ["Save & menu", main.show_menu]]))
		"failed":
			body.add_child(_buttons([["Retry tournament", func(): main.start_tournament(run.difficulty, run.player_name)], ["Menu", main.show_menu]]))
		"won":
			body.add_child(_buttons([["Final results", func(): show_final(run, main.submit_result(run))]]))
	_focus()


# --- final results -------------------------------------------------------------------------

func show_final(run, rec: Dictionary) -> void:
	view = "final"
	_frame("Champion of the Tournament of Doom!")
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(1100, 170)
	body.add_child(stage)
	var holder := Node2D.new()
	holder.position = Vector2(550, 150)
	holder.scale = Vector2(2.2, 2.2)
	stage.add_child(holder)
	var puppet := BearVisual.Puppet.new()
	puppet.fluff = 180.0
	puppet.smug = true
	var vis := BearVisual.new()
	vis.species = Species.for_name("Player")
	vis.source = puppet
	vis.tint = Mode.bear_color(Settings.HUMAN_COLORS[0])
	holder.add_child(vis)
	var wob := create_tween().set_loops()
	wob.tween_callback(func(): vis.kick(0.3)).set_delay(0.8)
	var head := _text("%s is the CHAMPION of the Tournament of Doom!" % run.player_name, 26, UiStyle.ROSE_DARK)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(head)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 30)
	var pb_t := "  ★ personal best!" if rec.get("pb_time", false) else ""
	var pb_l := "  ★ personal best!" if rec.get("pb_lost", false) else ""
	for pair in [["Total time", Tournament.fmt_time(run.total_time) + pb_t], ["Stuffing collected", str(roundi(run.total_gained))],
			["Stuffing lost", str(roundi(run.total_lost)) + pb_l], ["Rounds played", "%d (%d lives left)" % [run.attempts, run.lives]],
			["Difficulty / theme", "%s / %s" % [run.difficulty.capitalize(), run.mode.capitalize()]]]:
		g.add_child(UiStyle.label(pair[0], 20, UiStyle.INK_SOFT))
		g.add_child(UiStyle.label(pair[1], 20))
	body.add_child(g)
	if rec.get("eligible", false):
		var parts := []
		if rec["fastest"] > 0:
			parts.append("#%d on Fastest Tournament" % rec["fastest"])
		if rec["least_lost"] > 0:
			parts.append("#%d on Least Stuffing Lost" % rec["least_lost"])
		body.add_child(_text("New record: " + ", ".join(parts) if not parts.is_empty() else "No new leaderboard places this time.", 20, UiStyle.ROSE_DARK))
	else:
		body.add_child(_text("Not eligible for the leaderboards (sped-up clock or developer switch).", 18, UiStyle.INK_SOFT))
	body.add_child(_text("Defeated: " + ", ".join(Personalities.names()), 16, UiStyle.INK_SOFT))
	body.add_child(_buttons([["Leaderboards", func(): show_leaderboards(run.difficulty)], ["Menu", main.show_menu]]))
	Sfx.play("victory")
	_focus()


# --- leaderboards -------------------------------------------------------------------------

func show_leaderboards(level: String) -> void:
	view = "boards"
	_frame("Tournament Leaderboards")
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	for i in Settings.LEVELS.size():
		var lv: String = Settings.LEVELS[i]
		var b := _btn(Settings.LEVEL_LABELS[i] + (" ◆" if lv == level else ""), func(): show_leaderboards(lv), 150)
		tabs.add_child(b)
	body.add_child(tabs)
	body.add_child(_text("Only complete tournament wins at normal speed count. Each difficulty has its own boards (rules v%d)." % Tournament.RULES_VERSION, 15, UiStyle.INK_SOFT))
	var boards: Dictionary = Tournament.boards(level)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	body.add_child(cols)
	for spec in [["Fastest Tournament", "fastest"], ["Least Stuffing Lost", "least_lost"]]:
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(555, 0)
		v.add_child(UiStyle.label(spec[0], 24, UiStyle.ROSE_DARK))
		var list: Array = boards[spec[1]]
		if list.is_empty():
			v.add_child(UiStyle.label("No champions yet.", 17, UiStyle.INK_SOFT))
		for i in list.size():
			var e: Dictionary = list[i]
			var main_val: String = Tournament.fmt_time(e["time"]) if spec[1] == "fastest" else "%d lost" % roundi(e["lost"])
			var extra: String = "%d lost" % roundi(e["lost"]) if spec[1] == "fastest" else Tournament.fmt_time(e["time"])
			v.add_child(UiStyle.label("%2d. %s  %s" % [i + 1, e["name"], main_val], 18))
			v.add_child(UiStyle.label("     %s · +%d collected · %d rounds · %s · %s" % [extra, roundi(e["gained"]), e["rounds"], e["mode"], str(e["date"]).substr(0, 10)], 13, UiStyle.INK_SOFT))
		cols.add_child(v)
	body.add_child(_buttons([["Back", main.show_tournament_hub]]))
	_focus()


# --- AI spectator set-up --------------------------------------------------------------------

func show_spectate(prev: Dictionary = {}) -> void:
	view = "spectate"
	_frame("Watch the AI")
	body.add_child(_text("Four AI bears, no humans. Pick the line-up (or Random), sit back and enjoy the carnage. Speed 1× / 2× / 4× with the buttons in the match or the keys 1, 2 and 4. Spectator matches never touch the tournament leaderboards.", 17, UiStyle.INK_SOFT))
	var picks: Array = []
	var options := ["Random"] + Personalities.names()
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	for i in 4:
		g.add_child(UiStyle.label("Bear %d" % (i + 1), 20))
		var ob := OptionButton.new()
		for o in options:
			ob.add_item(o)
		var want: String = prev.get("picks", ["Random", "Random", "Random", "Random"])[i]
		ob.selected = maxi(0, options.find(want))
		ob.custom_minimum_size = Vector2(240, 40)
		g.add_child(ob)
		picks.append(ob)
	g.add_child(UiStyle.label("Skill", 20))
	var diff := OptionButton.new()
	for l in Settings.LEVEL_LABELS:
		diff.add_item(l)
	diff.selected = maxi(0, Settings.LEVELS.find(prev.get("level", "normal")))
	g.add_child(diff)
	body.add_child(g)
	body.add_child(_buttons([["Start match", func():
		main.start_spectator({"picks": picks.map(func(o): return options[o.selected]), "level": Settings.LEVELS[diff.selected]})],
		["Back", main.show_menu]]))
	_focus()
