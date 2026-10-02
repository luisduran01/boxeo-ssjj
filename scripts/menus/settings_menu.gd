class_name SettingsMenu
extends Control

const BACKGROUND := preload("res://menus/Menú de ajustes de BOXEO SSSJ.png")
const Rows = preload("res://scripts/ui/settings_sections.gd")
const CATEGORIES := [[&"general", "GENERAL", "General"], [&"controls", "CONTROLES", "Controls"], [&"sound", "SONIDO", "Sound"], [&"graphics", "GRÁFICOS", "Graphics"], [&"gameplay", "JUGABILIDAD", "Gameplay"], [&"camera", "CÁMARA", "Camera"], [&"language", "IDIOMA", "Language"], [&"accessibility", "ACCESIBILIDAD", "Accessibility"], [&"credits", "CRÉDITOS", "Credits"]]

var category_buttons: Array[Button] = []
var content: VBoxContainer
var current_category := &"general"

func _ready() -> void:
	var screen := MenuComponents.create_screen(self, BACKGROUND, "SETTINGS")
	(screen.shade as ColorRect).color.a = 0.88
	var column := screen.column as VBoxContainer
	var body := HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(body)
	var nav := VBoxContainer.new(); nav.custom_minimum_size.x = 270; body.add_child(nav)
	for definition in CATEGORIES:
		var button := MenuComponents.action_button(definition[1]); button.name = "Category%s" % definition[2]; button.custom_minimum_size = Vector2(265, 44)
		button.pressed.connect(show_category.bind(definition[0])); nav.add_child(button); category_buttons.append(button)
	var panel := PanelContainer.new(); panel.theme_type_variation = &"GoldPanel"; panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(panel)
	var scroll := ScrollContainer.new(); scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; panel.add_child(scroll)
	content = VBoxContainer.new(); content.name = "SettingsContent"; content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(content)
	var footer := HBoxContainer.new(); footer.alignment = BoxContainer.ALIGNMENT_END; column.add_child(footer)
	var reset := MenuComponents.action_button("RESTABLECER"); reset.name = "ResetButton"; reset.pressed.connect(_reset_defaults); footer.add_child(reset)
	var save := MenuComponents.action_button("GUARDAR Y VOLVER"); save.name = "ApplyButton"; save.pressed.connect(_save_and_return); footer.add_child(save)
	for i in range(category_buttons.size()):
		category_buttons[i].focus_neighbor_top = category_buttons[i].get_path_to(category_buttons[i - 1] if i > 0 else save)
		category_buttons[i].focus_neighbor_bottom = category_buttons[i].get_path_to(category_buttons[i + 1] if i + 1 < category_buttons.size() else save)
	show_category(&"general"); MenuComponents.bind_focus_feedback(self); MenuComponents.animate_screen_in(self); category_buttons[0].grab_focus.call_deferred()

func show_category(category: StringName) -> void:
	if not CATEGORIES.any(func(item: Array) -> bool: return item[0] == category): return
	current_category = category
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	content.add_child(Rows.heading(_title(category)))
	match category:
		&"general":
			_add_option("DIFICULTAD IA", &"difficulty", ["Easy", "Normal", "Hard"])
			_add_option("ROUNDS", &"rounds", ["3", "6", "8", "10", "12"], [3, 6, 8, 10, 12])
			_add_option("DURACIÓN", &"round_duration", ["1 MIN", "2 MIN", "3 MIN"], [60, 120, 180])
		&"controls":
			_add_info("DISPOSITIVO DETECTADO", "TECLADO / GAMEPAD %d" % Input.get_connected_joypads().size()); _add_info("MAPEO", "WASD · J · U/I · O"); _add_toggle("VIBRACIÓN", &"vibration")
		&"sound":
			for e in [["MASTER", &"master"], ["MÚSICA", &"music"], ["SFX", &"sfx"], ["VOCES", &"voice"], ["PÚBLICO", &"crowd"], ["INTERFAZ", &"ui"]]: _add_slider(e[0], e[1], 0.0, 1.0, false, true)
		&"graphics":
			_add_option("MODO", &"display_mode", ["Windowed", "Fullscreen", "Borderless"]); _add_option("RESOLUCIÓN", &"resolution", ["1280x720", "1600x900", "1920x1080", "2560x1440"]); _add_option("FPS", &"fps_limit", ["30", "60", "120", "144", "Unlimited"], [30, 60, 120, 144, 0]); _add_option("CALIDAD", &"graphics", ["Low", "Medium", "High"]); _add_toggle("VSYNC", &"vsync")
		&"gameplay":
			_add_toggle("MOSTRAR HUD", &"show_hud"); _add_toggle("DAÑO VISIBLE", &"visible_damage", true); _add_toggle("REPETICIONES", &"replays", true)
		&"camera":
			_add_slider("SENSIBILIDAD", &"camera_sensitivity", 0.5, 1.5); _add_slider("SACUDIDA", &"camera_shake", 0.0, 1.0); _add_slider("DISTANCIA", &"camera_distance", 0.5, 1.5); _add_slider("ALTURA", &"camera_height", 0.5, 1.5); _add_slider("CAMPO DE VISIÓN", &"camera_fov", 50.0, 100.0)
		&"language": _add_option("IDIOMA", &"language", ["Español", "English"], ["es", "en"])
		&"accessibility":
			_add_slider("ESCALA DE TEXTO", &"text_scale", 0.8, 1.5); _add_toggle("SUBTÍTULOS", &"subtitles"); _add_toggle("ALTO CONTRASTE", &"high_contrast"); _add_info("FILTROS DE COLOR", "PENDIENTE")
		&"credits": _add_info("BOXEO SSSJ", "Desarrollado con Godot 4.7.2")
	MenuComponents.bind_focus_feedback(self)

func _add_option(label: String, key: StringName, labels: Array, values: Array = []) -> void:
	var option := OptionButton.new(); option.name = "%sOption" % str(key).to_pascal_case()
	for item in labels: option.add_item(str(item))
	var source := values if not values.is_empty() else labels; option.select(maxi(0, source.find(SaveSystem.settings.get(key)))); option.item_selected.connect(func(i: int) -> void: SaveSystem.update_setting(key, source[i], false)); content.add_child(Rows.row(label, option))

func _add_slider(label: String, key: StringName, minimum: float, maximum: float, pending := false, live_audio := false) -> void:
	var slider := MenuComponents.slider_row(label, float(SaveSystem.settings[key]), minimum, maximum, 0.05); slider.name = "%sSlider" % str(key).to_pascal_case()
	slider.value_changed.connect(func(value: float) -> void: SaveSystem.update_setting(key, value, false); if live_audio: SaveSystem.apply_audio_settings()); content.add_child(Rows.row(label, slider, pending))

func _add_toggle(label: String, key: StringName, pending := false) -> void:
	var toggle := MenuComponents.toggle_row(label, bool(SaveSystem.settings[key])); toggle.name = "%sToggle" % str(key).to_pascal_case(); toggle.toggled.connect(func(value: bool) -> void: SaveSystem.update_setting(key, value, false)); content.add_child(Rows.row(label, toggle, pending))

func _add_info(label: String, value: String) -> void:
	var text := Label.new(); text.text = value; content.add_child(Rows.row(label, text))

func _title(category: StringName) -> String:
	for definition in CATEGORIES:
		if definition[0] == category: return definition[1]
	return str(category).to_upper()

func _reset_defaults() -> void: SaveSystem.settings = SaveSystem.default_settings(); SaveSystem.apply_settings(); show_category(current_category)
func _save_and_return() -> void:
	SaveSystem.save_settings(); var return_scene := str(SaveSystem.session.get("settings_return_scene", "res://scenes/menus/main_menu.tscn")); SaveSystem.session.erase("settings_return_scene"); get_tree().change_scene_to_file(return_scene)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): get_viewport().set_input_as_handled(); _save_and_return()
