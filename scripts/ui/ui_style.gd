class_name UiStyle
extends RefCounted
## Shared look for menus: dark stone panels with a bronze border, bronze-lit
## buttons. Used by the main menu, pause menu and settings panel.

const BG := Color(0.06, 0.05, 0.08, 0.94)
const BORDER := Color(0.55, 0.42, 0.2)
const GOLD := Color(0.95, 0.75, 0.3)
const TEXT := Color(0.88, 0.85, 0.78)
const TEXT_DIM := Color(0.6, 0.57, 0.52)

static func panel_box(bg: Color = BG, border: Color = BORDER, margin: float = 18.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(margin)
	return s

static func style_button(b: Button, font_size: int = 22, min_width: float = 300.0) -> Button:
	b.custom_minimum_size = Vector2(min_width, font_size * 2.1)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := panel_box(Color(0.1, 0.08, 0.1, 0.9), Color(0.3, 0.25, 0.2), 8.0)
	var hover := panel_box(Color(0.2, 0.14, 0.08, 0.95), GOLD, 8.0)
	var pressed := panel_box(Color(0.3, 0.2, 0.1, 1.0), GOLD, 8.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	return b

static func make_button(text: String, callback: Callable, font_size: int = 22, min_width: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	return style_button(b, font_size, min_width)

static func make_label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
