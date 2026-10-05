class_name BoxingTheme
extends RefCounted

const COLORS := {
	"background": Color("07090d"),
	"panel": Color("0b0d12e6"),
	"panel_secondary": Color("101319"),
	"gold": Color("c6a34a"),
	"bright_gold": Color("e5cb78"),
	"white": Color("f4f4f4"),
	"gray_text": Color("a9adb5"),
}


static func palette() -> Dictionary:
	return COLORS.duplicate()


static func create(high_contrast: bool = false, text_scale: float = 1.0) -> Theme:
	var theme := Theme.new()
	var foreground: Color = Color.WHITE if high_contrast else COLORS.white
	var secondary: Color = Color("d7d9dd") if high_contrast else COLORS.gray_text
	var safe_scale := clampf(text_scale, 0.8, 1.5)
	theme.default_font_size = roundi(18.0 * safe_scale)
	theme.set_color(&"font_color", &"Label", foreground)
	theme.set_color(&"font_color", &"Button", foreground)
	theme.set_color(&"font_hover_color", &"Button", COLORS.bright_gold)
	theme.set_color(&"font_focus_color", &"Button", COLORS.bright_gold)
	theme.set_color(&"font_pressed_color", &"Button", COLORS.background)
	theme.set_color(&"font_disabled_color", &"Button", secondary.darkened(0.35))
	theme.set_color(&"font_color", &"OptionButton", foreground)
	theme.set_color(&"font_color", &"CheckButton", foreground)
	theme.set_color(&"font_color", &"LineEdit", foreground)
	theme.set_color(&"font_color", &"RichTextLabel", foreground)
	theme.set_font_size(&"font_size", &"Button", roundi(19.0 * safe_scale))
	theme.set_font_size(&"font_size", &"Label", roundi(17.0 * safe_scale))
	theme.set_font_size(&"font_size", &"OptionButton", roundi(17.0 * safe_scale))
	theme.set_stylebox(&"normal", &"Button", _button_style(COLORS.panel_secondary, Color("535861"), 1))
	theme.set_stylebox(&"hover", &"Button", _button_style(Color("17191d"), COLORS.gold, 2))
	theme.set_stylebox(&"focus", &"Button", _button_style(Color("17191d"), COLORS.bright_gold, 2))
	theme.set_stylebox(&"pressed", &"Button", _button_style(COLORS.bright_gold, COLORS.bright_gold, 2))
	theme.set_stylebox(&"disabled", &"Button", _button_style(Color("0b0d12"), Color("343840"), 1))
	theme.set_stylebox(&"panel", &"PanelContainer", _panel_style(COLORS.panel, Color("535861")))
	theme.set_stylebox(&"panel", &"GoldPanel", _panel_style(COLORS.panel, COLORS.gold))
	theme.set_color(&"font_color", &"SecondaryLabel", secondary)
	return theme


static func button_focus_style() -> StyleBoxFlat:
	var style := _button_style(Color("18191d"), COLORS.bright_gold, 2)
	style.shadow_color = Color(0.95, 0.76, 0.25, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2.ZERO
	return style


static func _button_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


static func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
