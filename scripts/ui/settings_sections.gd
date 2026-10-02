class_name SettingsSections
extends RefCounted

static func row(label_text: String, control: Control, pending: bool = false) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.custom_minimum_size.y = 50
	var label := Label.new()
	label.text = label_text + ("  ·  PENDIENTE" if pending else "")
	label.custom_minimum_size.x = 260
	line.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if control is BaseButton: (control as BaseButton).disabled = pending
	line.add_child(control)
	return line

static func heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", BoxingTheme.palette().bright_gold)
	return label
