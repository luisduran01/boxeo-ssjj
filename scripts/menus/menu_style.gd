class_name MenuStyle
extends RefCounted


static func title(text: String, size := 46) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", BoxingTheme.palette().white)
	return label


static func button(text: String) -> Button:
	return MenuComponents.action_button(text)


static func base(root: Control, heading: String) -> VBoxContainer:
	var screen := MenuComponents.create_screen(root, null, heading)
	var column := screen.column as VBoxContainer
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 520
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	column.add_child(box)
	var line := HSeparator.new()
	line.modulate = BoxingTheme.palette().gold
	box.add_child(line)
	return box
