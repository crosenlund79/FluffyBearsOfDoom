## Nursery-of-Doom look for the UI: faded cream, dusty pinks, muted blues,
## nursery greens, serif type and stitched edges.
extends RefCounted

const CREAM := Color("f4ecdc")
const PAPER := Color("fbf5e8")
const INK := Color("5b4636")
const INK_SOFT := Color("8a7563")
const ROSE := Color("d8a0a6")
const ROSE_DARK := Color("b9787f")
const BLUE := Color("9db4c8")
const GREEN := Color("a9bf98")
const BROWN := Color("8a6a50")

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
		t.set_stylebox("hover", cls, _box(Color("fdeef0"), ROSE_DARK))
		t.set_stylebox("pressed", cls, _box(ROSE, ROSE_DARK))
		t.set_stylebox("focus", cls, _box(Color(0, 0, 0, 0), BLUE, 14, 3))
		t.set_stylebox("disabled", cls, _box(CREAM, Color("d9cdb9")))
		t.set_color("font_color", cls, INK)
		t.set_color("font_hover_color", cls, INK)
		t.set_color("font_pressed_color", cls, INK)
		t.set_color("font_focus_color", cls, INK)
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_focus_color", "CheckBox", INK)
	t.set_stylebox("slider", "HSlider", _box(Color("eadfcb"), Color("d9c7ac"), 6, 1))
	t.set_stylebox("grabber_area", "HSlider", _box(ROSE, ROSE_DARK, 6, 1))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(ROSE, ROSE_DARK, 6, 1))
	var pm := _box(PAPER, ROSE, 10)
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_stylebox("hover", "PopupMenu", _box(Color("f6dfe2"), Color(0, 0, 0, 0), 8, 0))
	var panel := _box(PAPER, Color("d9c7ac"), 18, 2)
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


## Gingham nursery wallpaper.
static func draw_wallpaper(ci: CanvasItem, rect: Rect2, base := CREAM, stripe := Color(0.85, 0.66, 0.68, 0.10)) -> void:
	ci.draw_rect(rect, base)
	var step := 36.0
	var x := rect.position.x
	while x < rect.end.x:
		ci.draw_rect(Rect2(x, rect.position.y, step * 0.5, rect.size.y), stripe)
		x += step
	var y := rect.position.y
	while y < rect.end.y:
		ci.draw_rect(Rect2(rect.position.x, y, rect.size.x, step * 0.5), stripe)
		y += step
