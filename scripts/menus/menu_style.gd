class_name MenuStyle
extends RefCounted


static func title(text: String, size := 46) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f5f7f8"))
	return label


static func button(text: String) -> Button:
	var value := Button.new()
	value.text = text
	value.custom_minimum_size = Vector2(360, 54)
	value.add_theme_font_size_override("font_size", 18)
	return value


static func base(root: Control, heading: String) -> VBoxContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("08121b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var accent := ColorRect.new()
	accent.color = Color("c72735")
	accent.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	accent.offset_right = 9
	background.add_child(accent)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-260, -300)
	box.size = Vector2(520, 600)
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	box.add_child(title(heading))
	var line := HSeparator.new()
	line.modulate = Color("c72735")
	box.add_child(line)
	return box
