class_name FighterSelectMenu
extends Control

const BACKGROUND := preload("res://menus/fighterselect.png")
const Database = preload("res://scripts/data/fighter_database.gd")
const Preview = preload("res://scripts/ui/fighter_preview.gd")

var fighters: Array[FighterData] = []
var selected_player: StringName = &""
var selected_opponent: StringName = &""
var highlighted: StringName = &"fighter_1"
var preview: FighterPreview
var stats_label: Label
var phase_label: Label
var confirm_button: Button
var card_buttons: Array[Button] = []

func _ready() -> void:
	SaveSystem.load_all()
	fighters = Database.valid_for_fight()
	_build_ui()
	if not fighters.is_empty(): _highlight(fighters[0].id)

func select_player(id: StringName) -> bool:
	if Database.by_id(id) == null: return false
	selected_player = id
	if selected_opponent == id: selected_opponent = &""
	_highlight(id)
	_refresh_selection()
	return true

func select_opponent(id: StringName) -> bool:
	if Database.by_id(id) == null or id == selected_player: return false
	selected_opponent = id
	_highlight(id)
	_refresh_selection()
	return true

func random_opponent() -> StringName:
	if selected_player == &"" and not fighters.is_empty(): select_player(fighters[0].id)
	var candidates: Array[FighterData] = []
	for fighter in fighters:
		if fighter.id != selected_player: candidates.append(fighter)
	if candidates.is_empty(): return &""
	var pick := candidates[randi() % candidates.size()]
	select_opponent(pick.id)
	return pick.id

func prepare_fight() -> bool:
	var player_data := Database.by_id(selected_player)
	var enemy_data := Database.by_id(selected_opponent)
	if player_data == null or enemy_data == null or player_data == enemy_data: return false
	SaveSystem.session.selected_player = str(player_data.id)
	SaveSystem.session.selected_opponent = str(enemy_data.id)
	SaveSystem.session.player_scene = player_data.scene.resource_path
	SaveSystem.session.enemy_scene = enemy_data.scene.resource_path
	SaveSystem.session.rounds = int(SaveSystem.settings.rounds)
	SaveSystem.session.round_duration = float(SaveSystem.settings.round_duration)
	return true

func _build_ui() -> void:
	var screen := MenuComponents.create_screen(self, BACKGROUND, "SELECT FIGHTER")
	(screen.shade as ColorRect).color = Color(0.01, 0.015, 0.025, 0.84)
	var column := screen.column as VBoxContainer
	phase_label = Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_color_override("font_color", BoxingTheme.palette().gold)
	column.add_child(phase_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	column.add_child(body)
	var stats_panel := _panel_container("FIGHTER DATA")
	stats_panel.custom_minimum_size.x = 290
	body.add_child(stats_panel)
	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_font_size_override("font_size", 18)
	(stats_panel.get_child(0) as VBoxContainer).add_child(stats_label)
	preview = Preview.new()
	preview.name = "FighterPreview"
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(preview)
	var selection_panel := _panel_container("SELECTION")
	selection_panel.custom_minimum_size.x = 310
	body.add_child(selection_panel)
	var selection_box := selection_panel.get_child(0) as VBoxContainer
	var player_value := Label.new()
	player_value.name = "PlayerValue"
	selection_box.add_child(player_value)
	var opponent_value := Label.new()
	opponent_value.name = "OpponentValue"
	selection_box.add_child(opponent_value)
	var cards := HBoxContainer.new()
	cards.name = "FighterCards"
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 12)
	column.add_child(cards)
	for index in range(fighters.size()):
		var fighter := fighters[index]
		var card := Button.new()
		card.name = "FighterCard%d" % (index + 1)
		card.text = fighter.display_name
		card.custom_minimum_size = Vector2(180, 72)
		card.pressed.connect(_on_card_pressed.bind(fighter.id))
		card.focus_entered.connect(_highlight.bind(fighter.id))
		cards.add_child(card)
		card_buttons.append(card)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	var random_button := MenuComponents.action_button("RANDOM")
	random_button.name = "RandomButton"
	random_button.pressed.connect(random_opponent)
	actions.add_child(random_button)
	confirm_button = MenuComponents.action_button("CONFIRM FIGHT")
	confirm_button.name = "ConfirmButton"
	confirm_button.disabled = true
	confirm_button.pressed.connect(_confirm)
	actions.add_child(confirm_button)
	var back := MenuComponents.action_button("BACK")
	back.name = "BackButton"
	back.pressed.connect(_back)
	actions.add_child(back)
	_link_focus()
	if not card_buttons.is_empty(): card_buttons[0].grab_focus.call_deferred()
	_refresh_selection()

func _panel_container(title: String) -> PanelContainer:
	var container := PanelContainer.new()
	container.theme_type_variation = &"GoldPanel"
	var box := MenuComponents.panel(title)
	container.add_child(box)
	return container

func _on_card_pressed(id: StringName) -> void:
	if selected_player == &"": select_player(id)
	else: select_opponent(id)

func _highlight(id: StringName) -> void:
	var data := Database.by_id(id)
	if data == null: return
	highlighted = id
	if is_instance_valid(preview): preview.show_fighter(data)
	if is_instance_valid(stats_label):
		stats_label.text = "%s\n\n%d kg\n%d cm\nALCANCE %d cm\n%s\n\nPOTENCIA  %d\nVELOCIDAD  %d\nRESISTENCIA  %d\nDEFENSA  %d\nTÉCNICA  %d" % [data.display_name, data.weight_kg, data.height_cm, data.reach_cm, data.style, data.power, data.speed, data.stamina, data.defense, data.technique]

func _refresh_selection() -> void:
	if not is_instance_valid(phase_label): return
	phase_label.text = "SELECT PLAYER" if selected_player == &"" else ("SELECT OPPONENT" if selected_opponent == &"" else "READY TO FIGHT")
	var player_data := Database.by_id(selected_player)
	var enemy_data := Database.by_id(selected_opponent)
	var player_value := find_child("PlayerValue", true, false) as Label
	var opponent_value := find_child("OpponentValue", true, false) as Label
	player_value.text = "PLAYER\n%s" % (player_data.display_name if player_data else "—")
	opponent_value.text = "OPPONENT\n%s" % (enemy_data.display_name if enemy_data else "—")
	confirm_button.disabled = player_data == null or enemy_data == null
	for index in range(card_buttons.size()):
		var id := fighters[index].id
		card_buttons[index].disabled = selected_player != &"" and selected_opponent == &"" and id == selected_player

func _link_focus() -> void:
	for index in range(card_buttons.size()):
		var previous := card_buttons[(index - 1 + card_buttons.size()) % card_buttons.size()]
		var next := card_buttons[(index + 1) % card_buttons.size()]
		card_buttons[index].focus_neighbor_left = card_buttons[index].get_path_to(previous)
		card_buttons[index].focus_neighbor_right = card_buttons[index].get_path_to(next)

func _confirm() -> void:
	if prepare_fight(): get_tree().change_scene_to_file("res://fight/fight.tscn")

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
