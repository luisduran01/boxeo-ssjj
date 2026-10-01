extends Control


func _ready() -> void:
	SaveSystem.load_all()
	var box := MenuStyle.base(self, "SETTINGS")
	_add_slider(box, "MASTER VOLUME", "master")
	_add_slider(box, "MUSIC", "music")
	_add_slider(box, "SFX", "sfx")
	_add_slider(box, "CROWD", "crowd")
	_add_slider(box, "CAMERA SHAKE", "camera_shake")
	var fullscreen := CheckButton.new()
	fullscreen.text = "FULLSCREEN"
	fullscreen.button_pressed = bool(SaveSystem.settings.fullscreen)
	fullscreen.toggled.connect(func(value: bool): SaveSystem.settings.fullscreen = value)
	box.add_child(fullscreen)
	_add_options(box, "RESOLUTION", ["1280x720", "1600x900", "1920x1080"], "resolution")
	_add_options(box, "GRAPHICS QUALITY", ["Low", "Medium", "High"], "graphics")
	var debug := CheckButton.new()
	debug.text = "DEBUG OVERLAY"
	debug.button_pressed = bool(SaveSystem.settings.debug)
	debug.toggled.connect(func(value: bool): SaveSystem.settings.debug = value)
	box.add_child(debug)
	var controls := Label.new()
	controls.text = "WASD Mover  •  J Jab  •  U/I Hooks  •  O Uppercut\nH/L Guardia alta  •  SPACE Guardia al cuerpo"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(controls)
	var save := MenuStyle.button("GUARDAR Y VOLVER")
	save.pressed.connect(_save_and_return)
	box.add_child(save)


func _save_and_return() -> void:
	SaveSystem.save_settings()
	var return_scene := str(SaveSystem.session.get("settings_return_scene", "res://scenes/menus/main_menu.tscn"))
	SaveSystem.session.erase("settings_return_scene")
	get_tree().change_scene_to_file(return_scene)


func _add_slider(box: VBoxContainer, label_text: String, key: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 190
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(SaveSystem.settings[key])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float): SaveSystem.settings[key] = value)
	row.add_child(slider)
	box.add_child(row)


func _add_options(box: VBoxContainer, label_text: String, values: Array[String], key: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 190
	row.add_child(label)
	var options := OptionButton.new()
	for value in values: options.add_item(value)
	options.select(maxi(0, values.find(str(SaveSystem.settings[key]))))
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.item_selected.connect(func(index: int): SaveSystem.settings[key] = values[index])
	row.add_child(options)
	box.add_child(row)
