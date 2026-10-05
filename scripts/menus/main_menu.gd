extends Control

const BACKGROUND := preload("res://menus/Menuboxeo.png")

var menu_buttons: Array[Button] = []

func _ready() -> void:
	SaveSystem.load_all()
	_build_ui()
	MenuComponents.bind_focus_feedback(self)
	MenuComponents.animate_screen_in(self)
	if not menu_buttons.is_empty(): menu_buttons[0].grab_focus.call_deferred()

func _build_ui() -> void:
	var screen := MenuComponents.create_screen(self, BACKGROUND, "")
	(screen.shade as ColorRect).color = Color(0.01, 0.01, 0.015, 0.58)
	var column := screen.column as VBoxContainer
	(screen.title as Label).queue_free()
	var layout := HBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(layout)
	var navigation := VBoxContainer.new()
	navigation.name = "Navigation"
	var compact := bool(get_meta("compact_menu_layout", false))
	navigation.custom_minimum_size = Vector2(20, 0) if compact else Vector2(520, 0)
	navigation.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	navigation.add_theme_constant_override("separation", 0 if compact else 12)
	layout.add_child(navigation)
	var logo := Label.new()
	logo.text = "♛\nBOXEO SSSJ"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 4 if compact else 48)
	logo.add_theme_color_override("font_color", BoxingTheme.palette().bright_gold)
	navigation.add_child(logo)
	var subtitle := Label.new()
	subtitle.text = "F I G H T   N I G H T"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 3 if compact else 16)
	subtitle.add_theme_color_override("font_color", BoxingTheme.palette().gold)
	navigation.add_child(subtitle)
	navigation.add_child(_action("QuickFightButton", "QUICK FIGHT", 1, "res://scenes/menus/fighter_select.tscn", _quick_fight))
	navigation.add_child(_action("CareerButton", "CAREER", 2, "res://scenes/menus/career.tscn", _career))
	navigation.add_child(_action("FightersButton", "FIGHTERS", 3, "res://scenes/menus/fighter_select.tscn", _fighters))
	navigation.add_child(_action("SettingsButton", "SETTINGS", 4, "res://scenes/menus/settings.tscn", _settings))
	navigation.add_child(_action("ExitButton", "EXIT", 5, "quit", get_tree().quit))
	var visual_space := Control.new()
	visual_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(visual_space)
	var footer := Label.new()
	footer.text = "✕  SELECT     ○  BACK"
	footer.add_theme_color_override("font_color", BoxingTheme.palette().gray_text)
	footer.add_theme_font_size_override("font_size", 3 if compact else 18)
	column.add_child(footer)
	_link_focus()

func _action(node_name: String, label_text: String, index: int, target: String, callback: Callable) -> Button:
	var button := MenuComponents.action_button(label_text, index)
	button.name = node_name
	if bool(get_meta("compact_menu_layout", false)):
		button.custom_minimum_size = Vector2(20, 4)
		button.add_theme_font_size_override("font_size", 3)
	button.set_meta("target", target)
	button.pressed.connect(callback)
	menu_buttons.append(button)
	return button

func _link_focus() -> void:
	for index in range(menu_buttons.size()):
		var previous := menu_buttons[(index - 1 + menu_buttons.size()) % menu_buttons.size()]
		var next := menu_buttons[(index + 1) % menu_buttons.size()]
		menu_buttons[index].focus_neighbor_top = menu_buttons[index].get_path_to(previous)
		menu_buttons[index].focus_neighbor_bottom = menu_buttons[index].get_path_to(next)

func set_mode_for_test(mode: StringName) -> void:
	SaveSystem.session = {"mode": str(mode), "rounds": int(SaveSystem.settings.rounds), "round_duration": float(SaveSystem.settings.round_duration)}

func _quick_fight() -> void:
	set_mode_for_test(&"quick")
	get_tree().change_scene_to_file("res://scenes/menus/fighter_select.tscn")

func _fighters() -> void:
	set_mode_for_test(&"roster")
	get_tree().change_scene_to_file("res://scenes/menus/fighter_select.tscn")

func _career() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/career.tscn")

func _settings() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/settings.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
