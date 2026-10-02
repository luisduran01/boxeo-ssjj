class_name CareerMenu
extends Control

const BACKGROUND := preload("res://menus/Menú de carrera de boxeo cinemático.png")
const Sections = preload("res://scripts/ui/career_sections.gd")
const Database = preload("res://scripts/data/fighter_database.gd")

const SECTION_DEFINITIONS := [
	[&"summary", "RESUMEN", "Summary"],
	[&"training", "ENTRENAMIENTO", "Training"],
	[&"calendar", "CALENDARIO", "Calendar"],
	[&"team", "EQUIPO", "Team"],
	[&"contracts", "CONTRATOS", "Contracts"],
	[&"ranking", "RANKING", "Ranking"],
	[&"news", "NOTICIAS", "News"],
	[&"statistics", "ESTADÍSTICAS", "Statistics"],
]

var current_section: StringName = &"summary"
var section_buttons: Array[Button] = []
var section_holder: VBoxContainer

func _ready() -> void:
	_build_ui()
	show_section(&"summary")
	if not section_buttons.is_empty(): section_buttons[0].grab_focus.call_deferred()

func _build_ui() -> void:
	var screen := MenuComponents.create_screen(self, BACKGROUND, "CAREER")
	(screen.shade as ColorRect).color = Color(0.01, 0.015, 0.025, 0.86)
	var column := screen.column as VBoxContainer
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	for tab in [["CARRERA", &"summary"], ["ENTRENAMIENTO", &"training"], ["PELEAS", &"calendar"], ["RANKING", &"ranking"], ["CONTRATOS", &"contracts"], ["ESTADÍSTICAS", &"statistics"]]:
		var button := Button.new()
		button.text = tab[0]
		button.pressed.connect(show_section.bind(tab[1]))
		tabs.add_child(button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	column.add_child(body)
	var navigation := VBoxContainer.new()
	navigation.custom_minimum_size.x = 285
	navigation.add_theme_constant_override("separation", 7)
	body.add_child(navigation)
	for definition in SECTION_DEFINITIONS:
		var button := MenuComponents.action_button(definition[1])
		button.name = "Section%s" % definition[2]
		button.custom_minimum_size = Vector2(280, 48)
		button.pressed.connect(show_section.bind(definition[0]))
		navigation.add_child(button)
		section_buttons.append(button)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	section_holder = VBoxContainer.new()
	section_holder.name = "SectionContent"
	section_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_holder.add_theme_constant_override("separation", 12)
	scroll.add_child(section_holder)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	var back := MenuComponents.action_button("VOLVER")
	back.name = "BackButton"
	back.custom_minimum_size.x = 220
	back.pressed.connect(_back)
	footer.add_child(back)
	_link_focus(back)

func show_section(section: StringName) -> void:
	if not _is_valid_section(section): return
	current_section = section
	for child in section_holder.get_children():
		section_holder.remove_child(child)
		child.queue_free()
	section_holder.add_child(Sections.build(section, SaveSystem.career))
	match section:
		&"training": _add_training_actions()
		&"calendar": _add_calendar_actions()
		&"contracts": _add_contract_actions()
	for index in range(section_buttons.size()):
		section_buttons[index].button_pressed = SECTION_DEFINITIONS[index][0] == section

func train_for_test(attribute: StringName) -> void:
	if attribute not in [&"power", &"speed", &"stamina", &"defense", &"technique"]: return
	SaveSystem.advance_week(attribute)
	show_section(&"training")

func rest_for_test() -> void:
	SaveSystem.advance_week(&"rest")
	show_section(&"calendar")

func advance_for_test() -> void:
	SaveSystem.advance_week(&"advance")
	show_section(&"calendar")

func current_section_text() -> String:
	var lines: Array[String] = []
	_collect_text(section_holder, lines)
	return "\n".join(lines)

func _add_training_actions() -> void:
	var row := HBoxContainer.new()
	row.name = "TrainingActions"
	row.add_theme_constant_override("separation", 8)
	section_holder.add_child(row)
	for entry in [[&"power", "POTENCIA", "Power"], [&"speed", "VELOCIDAD", "Speed"], [&"stamina", "RESISTENCIA", "Stamina"], [&"defense", "DEFENSA", "Defense"], [&"technique", "TÉCNICA", "Technique"]]:
		var button := Button.new()
		button.name = "Train%s" % entry[2]
		button.text = entry[1]
		button.pressed.connect(train_for_test.bind(entry[0]))
		row.add_child(button)

func _add_calendar_actions() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	section_holder.add_child(row)
	var rest := MenuComponents.action_button("DESCANSAR")
	rest.name = "RestButton"
	rest.pressed.connect(rest_for_test)
	row.add_child(rest)
	var advance := MenuComponents.action_button("AVANZAR SEMANA")
	advance.name = "AdvanceButton"
	advance.pressed.connect(advance_for_test)
	row.add_child(advance)

func _add_contract_actions() -> void:
	var accept := MenuComponents.action_button("ACEPTAR OFERTA DE PELEA")
	accept.name = "AcceptFightButton"
	accept.pressed.connect(_accept_contract)
	section_holder.add_child(accept)

func _accept_contract() -> void:
	var player_id := StringName(str(SaveSystem.career.get("fighter", "fighter_1")))
	var opponent_id := StringName(str(SaveSystem.career.get("next_opponent", "fighter_2")))
	if Database.by_id(player_id) == null: player_id = &"fighter_1"
	if Database.by_id(opponent_id) == null or opponent_id == player_id:
		opponent_id = &"fighter_2" if player_id != &"fighter_2" else &"fighter_3"
	SaveSystem.session.mode = "career"
	SaveSystem.session.selected_player = str(player_id)
	SaveSystem.session.selected_opponent = str(opponent_id)
	get_tree().change_scene_to_file("res://scenes/menus/fighter_select.tscn")

func _link_focus(back: Button) -> void:
	for index in range(section_buttons.size()):
		var previous: Control = section_buttons[index - 1] if index > 0 else back
		var next: Control = section_buttons[index + 1] if index + 1 < section_buttons.size() else back
		section_buttons[index].focus_neighbor_top = section_buttons[index].get_path_to(previous)
		section_buttons[index].focus_neighbor_bottom = section_buttons[index].get_path_to(next)
	back.focus_neighbor_top = back.get_path_to(section_buttons[-1])
	back.focus_neighbor_bottom = back.get_path_to(section_buttons[0])

func _is_valid_section(section: StringName) -> bool:
	for definition in SECTION_DEFINITIONS:
		if definition[0] == section: return true
	return false

func _collect_text(node: Node, lines: Array[String]) -> void:
	if node is Label: lines.append((node as Label).text)
	if node is Button: lines.append((node as Button).text)
	for child in node.get_children(): _collect_text(child, lines)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
