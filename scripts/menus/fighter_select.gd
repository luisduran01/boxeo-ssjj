extends Control


func _ready() -> void:
	var data: FighterData = load("res://data/fighters/boxer_green.tres")
	var box := MenuStyle.base(self, "FIGHTER SELECT")
	box.add_child(MenuStyle.title(data.display_name, 28))
	var stats := Label.new()
	stats.text = "%d cm  •  %d kg  •  Alcance %d cm\n%s\n\nPOTENCIA  %d\nVELOCIDAD  %d\nSTAMINA  %d\nDEFENSA  %d" % [data.height_cm, data.weight_kg, data.reach_cm, data.stance, data.power, data.speed, data.stamina, data.defense]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 17)
	box.add_child(stats)
	var player_label := Label.new()
	player_label.text = "PLAYER"
	box.add_child(player_label)
	var player_select := OptionButton.new()
	player_select.name = "PlayerSelect"
	player_select.add_item(data.display_name)
	player_select.set_item_metadata(0, data.scene.resource_path)
	player_select.item_selected.connect(func(index: int): SaveSystem.session.player_scene = str(player_select.get_item_metadata(index)))
	box.add_child(player_select)
	var enemy_label := Label.new()
	enemy_label.text = "ENEMY"
	box.add_child(enemy_label)
	var enemy_select := OptionButton.new()
	enemy_select.name = "EnemySelect"
	enemy_select.add_item(data.display_name)
	enemy_select.set_item_metadata(0, data.scene.resource_path)
	enemy_select.item_selected.connect(func(index: int): SaveSystem.session.enemy_scene = str(enemy_select.get_item_metadata(index)))
	box.add_child(enemy_select)
	SaveSystem.session.player_scene = data.scene.resource_path
	SaveSystem.session.enemy_scene = data.scene.resource_path
	var difficulty := OptionButton.new()
	difficulty.name = "DifficultySelect"
	for value in ["Easy", "Medium", "Hard"]: difficulty.add_item(value)
	difficulty.select(["Easy", "Medium", "Hard"].find(SaveSystem.settings.difficulty))
	difficulty.item_selected.connect(func(index: int): SaveSystem.settings.difficulty = difficulty.get_item_text(index))
	box.add_child(difficulty)
	var fight := MenuStyle.button("INICIAR PELEA")
	fight.pressed.connect(func(): get_tree().change_scene_to_file("res://fight/fight.tscn"))
	box.add_child(fight)
	var back := MenuStyle.button("VOLVER")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn"))
	box.add_child(back)
