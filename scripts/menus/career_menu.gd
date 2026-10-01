extends Control

var box: VBoxContainer


func _ready() -> void:
	SaveSystem.load_all()
	box = MenuStyle.base(self, "CAREER")
	_refresh()


func _refresh() -> void:
	for child in box.get_children():
		if child.get_meta("dynamic", false): child.queue_free()
	var card := Label.new()
	card.set_meta("dynamic", true)
	card.text = "%s\nRANKING  #%d\nRÉCORD  %d-%d  (%d KO)\nDINERO  $%d\nFANS  %d\nPUNTOS DE ENTRENAMIENTO  %d" % [SaveSystem.career.name, SaveSystem.career.ranking, SaveSystem.career.wins, SaveSystem.career.losses, SaveSystem.career.kos, SaveSystem.career.money, SaveSystem.career.fans, SaveSystem.career.training_points]
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_theme_font_size_override("font_size", 19)
	box.add_child(card)
	var train := MenuStyle.button("ENTRENAR")
	train.set_meta("dynamic", true)
	train.pressed.connect(_train)
	box.add_child(train)
	var offer := MenuStyle.button("ACEPTAR OFERTA DE PELEA")
	offer.set_meta("dynamic", true)
	offer.pressed.connect(_fight_offer)
	box.add_child(offer)
	var back := MenuStyle.button("VOLVER")
	back.set_meta("dynamic", true)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn"))
	box.add_child(back)


func _train() -> void:
	if SaveSystem.career.money >= 100:
		SaveSystem.career.money -= 100
		SaveSystem.career.training_points += 1
		SaveSystem.save_career()
		_refresh()


func _fight_offer() -> void:
	SaveSystem.session = {"mode": "career", "rounds": 3, "round_duration": 120.0}
	get_tree().change_scene_to_file("res://scenes/menus/fighter_select.tscn")
