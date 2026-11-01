## Nursery-of-Doom look for the UI: faded cream, dusty pinks, muted blues,
## nursery greens, serif type and stitched edges.
extends RefCounted

# Palette (switched by apply_mode; read as UiStyle.INK etc.)
static var CREAM := Color("f4ecdc")
static var PAPER := Color("fbf5e8")
static var INK := Color("5b4636")
static var INK_SOFT := Color("8a7563")
static var ROSE := Color("d8a0a6")
static var ROSE_DARK := Color("b9787f")
static var BLUE := Color("9db4c8")
static var GREEN := Color("a9bf98")
static var BROWN := Color("8a6a50")
static var STRIPE := Color(0.85, 0.66, 0.68, 0.10)
static var BAR := Color("eadfcb")
static var FRAME := Color(0.86, 0.76, 0.66)
static var GOOD := Color("6c8f5e")
static var GOLD := Color("b08a2e")
static var CURSE := Color("7a5a8c")
static var _mode := "normal"

const PALETTES := {
	"normal": {"CREAM": "f4ecdc", "PAPER": "fbf5e8", "INK": "5b4636", "INK_SOFT": "8a7563", "ROSE": "d8a0a6",
		"ROSE_DARK": "b9787f", "BLUE": "9db4c8", "GREEN": "a9bf98", "BROWN": "8a6a50", "STRIPE": "d9a8ad1a",
		"BAR": "eadfcb", "FRAME": "dbc2a8", "GOOD": "6c8f5e", "GOLD": "b08a2e", "CURSE": "7a5a8c"},
	"horror": {"CREAM": "1e1719", "PAPER": "2e2426", "INK": "e3d4c1", "INK_SOFT": "a08d82", "ROSE": "6e1f27",
		"ROSE_DARK": "c9363f", "BLUE": "3e4a57", "GREEN": "4f5a44", "BROWN": "4a3329", "STRIPE": "00000040",
		"BAR": "3e3033", "FRAME": "3b2a2a", "GOOD": "9fae78", "GOLD": "d1a548", "CURSE": "a77fc0"},
}


## Switch the palette (and rebuild the UI theme) for "normal" or "horror".
static func apply_mode(mode: String) -> void:
	if not PALETTES.has(mode):
		mode = "normal"
	_mode = mode
	var p: Dictionary = PALETTES[mode]
	CREAM = Color(p["CREAM"])
	PAPER = Color(p["PAPER"])
	INK = Color(p["INK"])
	INK_SOFT = Color(p["INK_SOFT"])
	ROSE = Color(p["ROSE"])
	ROSE_DARK = Color(p["ROSE_DARK"])
	BLUE = Color(p["BLUE"])
	GREEN = Color(p["GREEN"])
	BROWN = Color(p["BROWN"])
	STRIPE = Color(p["STRIPE"])
	BAR = Color(p["BAR"])
	FRAME = Color(p["FRAME"])
	GOOD = Color(p["GOOD"])
	GOLD = Color(p["GOLD"])
	CURSE = Color(p["CURSE"])
	_theme = null


static var _font: Font
static var _theme: Theme


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Palatino", "Book Antiqua", "Bookman Old Style", "DejaVu Serif", "Liberation Serif", "Noto Serif", "serif"])
		_font = f
	return _font


static func _box(bg: Color, border: Color, radius := 14, bw := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.shadow_color = Color(0.36, 0.27, 0.2, 0.18)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, _box(PAPER, ROSE))
		t.set_stylebox("hover", cls, _box(PAPER.lerp(ROSE, 0.15), ROSE_DARK))
		t.set_stylebox("pressed", cls, _box(ROSE, ROSE_DARK))
		t.set_stylebox("focus", cls, _box(Color(0, 0, 0, 0), BLUE, 14, 3))
		t.set_stylebox("disabled", cls, _box(CREAM, BAR))
		t.set_color("font_color", cls, INK)
		t.set_color("font_hover_color", cls, INK)
		t.set_color("font_pressed_color", cls, INK)
		t.set_color("font_focus_color", cls, INK)
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_focus_color", "CheckBox", INK)
	t.set_stylebox("slider", "HSlider", _box(BAR, FRAME, 6, 1))
	t.set_stylebox("grabber_area", "HSlider", _box(ROSE, ROSE_DARK, 6, 1))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(ROSE, ROSE_DARK, 6, 1))
	var pm := _box(PAPER, ROSE, 10)
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_stylebox("hover", "PopupMenu", _box(PAPER.lerp(ROSE, 0.3), Color(0, 0, 0, 0), 8, 0))
	var panel := _box(PAPER, FRAME.lerp(INK_SOFT, 0.3), 18, 2)
	panel.set_content_margin_all(22)
	t.set_stylebox("panel", "PanelContainer", panel)
	_theme = t
	return t


## Dashed "stitch" outline inset inside `rect`.
static func stitch_rect(ci: CanvasItem, rect: Rect2, color: Color, width := 2.0, dash := 7.0) -> void:
	var a := rect.position
	var b := rect.position + Vector2(rect.size.x, 0)
	var c := rect.end
	var d := rect.position + Vector2(0, rect.size.y)
	ci.draw_dashed_line(a, b, color, width, dash)
	ci.draw_dashed_line(b, c, color, width, dash)
	ci.draw_dashed_line(c, d, color, width, dash)
	ci.draw_dashed_line(d, a, color, width, dash)


static func label(text: String, size := 18, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Gingham nursery wallpaper (dim and stained in Horror mode).
static func draw_wallpaper(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect, CREAM)
	var step := 36.0
	var x := rect.position.x
	while x < rect.end.x:
		ci.draw_rect(Rect2(x, rect.position.y, step * 0.5, rect.size.y), STRIPE)
		x += step
	var y := rect.position.y
	while y < rect.end.y:
		ci.draw_rect(Rect2(rect.position.x, y, rect.size.x, step * 0.5), STRIPE)
		y += step
	if _mode == "horror":
		# old stains and drips running down the wallpaper
		for i in 14:
			var dx := rect.position.x + fmod(i * 397.0, rect.size.x)
			var len := 60.0 + fmod(i * 131.0, 220.0)
			var col := Color(0.35, 0.02, 0.05, 0.35)
			ci.draw_rect(Rect2(dx, rect.position.y, 3.0 + fmod(i, 3.0), len), col)
			ci.draw_circle(Vector2(dx + 2.0, rect.position.y + len), 4.0, col)
			ci.draw_circle(Vector2(dx + fmod(i * 53.0, 90.0), rect.position.y + fmod(i * 211.0, rect.size.y)), 10.0 + fmod(i * 7.0, 18.0), Color(0.0, 0.0, 0.0, 0.18))
