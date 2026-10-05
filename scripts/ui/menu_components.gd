class_name MenuComponents
extends RefCounted


static func create_screen(root: Control, background: Texture2D, title: String) -> Dictionary:
	var viewport_size := Vector2(root.get_tree().root.size)
	var compact := viewport_size.x < 640.0 or viewport_size.y < 360.0
	if compact:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		root.get_viewport().size = Vector2i(1280, 720)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = BoxingTheme.create()
	root.set_meta("compact_menu_layout", compact)
	for child in root.get_children():
		if child is TextureRect and str(child.name).contains("Backdrop"):
			child.queue_free()
	var backdrop := TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.texture = background
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var shade := ColorRect.new()
	shade.name = "BackdropShade"
	shade.color = Color(0.01, 0.015, 0.025, 0.68)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin_size := 1 if compact else 36
	margin.add_theme_constant_override("margin_left", margin_size)
	margin.add_theme_constant_override("margin_top", 1 if compact else 28)
	margin.add_theme_constant_override("margin_right", margin_size)
	margin.add_theme_constant_override("margin_bottom", 1 if compact else 28)
	root.add_child(margin)
	var column := VBoxContainer.new()
	column.name = "ScreenColumn"
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var heading := Label.new()
	heading.name = "ScreenTitle"
	heading.text = title
	heading.add_theme_font_size_override("font_size", 6 if compact else 46)
	heading.add_theme_color_override("font_color", BoxingTheme.palette().bright_gold)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	root.scale = Vector2.ONE
	return {"backdrop": backdrop, "shade": shade, "content": margin, "column": column, "title": heading}


static func action_button(text: String, index: int = -1) -> Button:
	var button := Button.new()
	button.text = ("%02d   %s" % [index, text]) if index >= 0 else text
	button.custom_minimum_size = Vector2(360, 56)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_stylebox_override("focus", BoxingTheme.button_focus_style())
	bind_interaction(button)
	return button


static func panel(title: String = "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	if not title.is_empty():
		var heading := Label.new()
		heading.text = title
		heading.add_theme_font_size_override("font_size", 21)
		heading.add_theme_color_override("font_color", BoxingTheme.palette().bright_gold)
		box.add_child(heading)
		box.add_child(HSeparator.new())
	return box


static func stat_bar(label_text: String, value: float) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 30
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 130
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.name = "Value"
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = clampf(value, 0.0, 100.0)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	var number := Label.new()
	number.name = "Number"
	number.text = str(roundi(bar.value))
	number.custom_minimum_size.x = 34
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(number)
	return row


static func option_row(label_text: String, values: Array[String]) -> OptionButton:
	var options := OptionButton.new()
	options.name = _control_name(label_text) + "Option"
	options.tooltip_text = label_text
	options.custom_minimum_size = Vector2(220, 48)
	for value in values:
		options.add_item(value)
	bind_interaction(options)
	return options


static func toggle_row(label_text: String, enabled: bool) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = _control_name(label_text) + "Toggle"
	toggle.text = label_text
	toggle.button_pressed = enabled
	toggle.custom_minimum_size.y = 48
	bind_interaction(toggle)
	return toggle


static func slider_row(label_text: String, value: float, minimum: float, maximum: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.name = _control_name(label_text) + "Slider"
	slider.tooltip_text = label_text
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = clampf(value, minimum, maximum)
	slider.custom_minimum_size = Vector2(220, 48)
	bind_interaction(slider)
	return slider


static func bind_interaction(control: Control) -> void:
	if control.has_meta("menu_interaction_bound"):
		return
	control.set_meta("menu_interaction_bound", true)
	if control is BaseButton:
		var button := control as BaseButton
		control.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.pressed.connect(play_ui_cue.bind(&"accept"))
	control.pivot_offset = control.size * 0.5
	control.focus_entered.connect(func() -> void:
		play_ui_cue(&"focus")
		_animate_scale(control, Vector2.ONE)
	)
	control.focus_exited.connect(func() -> void: _animate_scale(control, Vector2.ONE))
	control.mouse_entered.connect(func() -> void:
		if control.focus_mode != Control.FOCUS_NONE:
			control.grab_focus()
	)
	control.mouse_exited.connect(func() -> void:
		if not control.has_focus():
			_animate_scale(control, Vector2.ONE)
	)

static func animate_screen_in(root: Control) -> Tween:
	root.modulate.a = 0.0
	var content := root.find_child("ContentMargin", true, false) as Control
	if content != null:
		content.position.y += 18.0
	var tween := root.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if content != null:
		tween.parallel().tween_property(content, "position:y", content.position.y - 18.0, 0.24)
	tween.tween_property(root, "modulate:a", 1.0, 0.22)
	return tween

static func bind_focus_feedback(root: Control) -> void:
	_bind_focus_feedback_recursive(root)

static func play_ui_cue(cue: StringName) -> void:
	if AudioServer.get_bus_index("UI") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "UI")

static func _bind_focus_feedback_recursive(node: Node) -> void:
	if node is Control:
		var control := node as Control
		if control is BaseButton and (control as BaseButton).disabled:
			control.focus_mode = Control.FOCUS_NONE
		elif control is Button or control is OptionButton or control is CheckButton or control is Slider:
			control.focus_mode = Control.FOCUS_ALL
			bind_interaction(control)
	for child in node.get_children():
		_bind_focus_feedback_recursive(child)

static func _animate_scale(control: Control, target: Vector2) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		control.scale = target
		return
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", target, 0.15)


static func _control_name(value: String) -> String:
	return value.to_pascal_case().replace(" ", "")
