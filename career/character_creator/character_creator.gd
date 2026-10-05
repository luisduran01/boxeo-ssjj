class_name CharacterCreator
extends Control

const CareerFighterScript := preload("res://career/character_creator/career_fighter.gd")

var categories := ["Nombre", "Apellido", "Apodo", "Edad", "País", "Mano dominante", "Guardia", "Altura", "Peso", "Color de piel", "Corte de pelo", "Color de pelo", "Barba", "Color de barba", "Short", "Color de short", "Guantes", "Color de guantes", "Zapatos", "Estilo de pelea"]
var appearance: Resource
var current_category := "Nombre"
var _category_index := 0
var _camera_tween: Tween

@onready var fighter_name: LineEdit = $LeftPanel/VBoxContainer/FighterName
@onready var category_title: Label = $LeftPanel/VBoxContainer/CategoryTitle
@onready var options: GridContainer = $LeftPanel/VBoxContainer/Options
@onready var preview: Node3D = $SubViewportContainer/SubViewport/PreviewWorld/FighterPreview
@onready var camera: Camera3D = $SubViewportContainer/SubViewport/PreviewWorld/Camera3D
@onready var bottom_controls: Label = $BottomControls


func _ready() -> void:
	_ensure_rotation_actions()
	appearance = CareerFighterScript.new()
	fighter_name.text = "%s \"%s\" %s" % [appearance.first_name, appearance.nickname, appearance.last_name]
	fighter_name.text_changed.connect(func(text: String) -> void:
		appearance.first_name = text.strip_edges()
		_refresh_title()
	)
	bottom_controls.text = "Q/E ROTAR  |  L2/R2 ROTAR  |  ENTER CONFIRMAR  |  ESC VOLVER"
	preview.apply_appearance(appearance)
	preview.play_preview_animation("idle")
	select_category(current_category)


func _process(delta: float) -> void:
	var rotation_axis := Input.get_axis("creator_rotate_left", "creator_rotate_right")
	if not is_zero_approx(rotation_axis):
		preview.rotate_preview(rotation_axis * delta * 2.35)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_select_relative_category(-1)
	elif event.is_action_pressed("ui_right"):
		_select_relative_category(1)
	elif event.is_action_pressed("ui_accept"):
		confirm_creation()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/menus/career.tscn")


func select_category(category: String) -> void:
	if category not in categories:
		return
	current_category = category
	_category_index = categories.find(category)
	category_title.text = category.to_upper()
	_rebuild_options()
	_focus_camera_for(category)


func select_option_for_test(option_value: String) -> void:
	_apply_option(option_value)


func rotate_preview_for_test(direction: float) -> void:
	preview.rotate_preview(direction * 0.28)


func set_identity_for_test(first_name: String, last_name: String, nickname: String, age: int) -> void:
	appearance.first_name = first_name
	appearance.last_name = last_name
	appearance.nickname = nickname
	appearance.age = age
	_refresh_title()


func confirm_creation() -> void:
	SaveSystem.career = SaveSystem.career if SaveSystem.career is Dictionary else SaveSystem.default_career()
	SaveSystem.career.name = "%s %s" % [appearance.first_name, appearance.last_name]
	SaveSystem.career.fighter = "career_created"
	SaveSystem.career.created_fighter = appearance.to_dictionary()
	SaveSystem.save_career()


func _select_relative_category(offset: int) -> void:
	_category_index = wrapi(_category_index + offset, 0, categories.size())
	select_category(categories[_category_index])


func _rebuild_options() -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	var values := _values_for_category(current_category)
	if values.is_empty():
		var edit := LineEdit.new()
		edit.name = "OptionText"
		edit.text = str(appearance.get(_property_for_category(current_category)))
		edit.text_changed.connect(func(text: String) -> void: _apply_option(text))
		options.add_child(edit)
		return
	for value in values:
		var button := Button.new()
		button.text = str(value)
		button.name = "Option%s" % str(value).to_pascal_case()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(132, 42)
		button.pressed.connect(_apply_option.bind(str(value)))
		options.add_child(button)
	MenuComponents.bind_focus_feedback(options)


func _apply_option(value: String) -> void:
	var property := _property_for_category(current_category)
	if property == "":
		return
	if property in ["age", "height_cm", "weight_kg"]:
		appearance.set(property, int(value))
	else:
		appearance.set(property, value)
	_refresh_title()
	preview.apply_appearance(appearance)
	match str(appearance.fight_style):
		"Aggressive":
			preview.play_preview_animation("shadow_boxing")
		"Defensive":
			preview.play_preview_animation("guard")
		"Showman":
			preview.play_preview_animation("victory")
		_:
			preview.play_preview_animation("breathing")


func _refresh_title() -> void:
	fighter_name.text = "%s \"%s\" %s" % [appearance.first_name, appearance.nickname, appearance.last_name]


func _focus_camera_for(category: String) -> void:
	var face_categories := ["Color de piel", "Corte de pelo", "Color de pelo", "Barba", "Color de barba", "Nombre", "Apellido", "Apodo", "Edad", "País"]
	var target_position := Vector3(0.0, 1.55, 2.05) if category in face_categories else Vector3(0.0, 1.28, 3.55)
	var look_target := Vector3(0.0, 1.48, 0.0) if category in face_categories else Vector3(0.0, 1.05, 0.0)
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.tween_property(camera, "position", target_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_callback(func() -> void: camera.look_at(look_target, Vector3.UP))


func _values_for_category(category: String) -> Array:
	match category:
		"Edad":
			return [18, 21, 24, 28, 32, 36]
		"País":
			return ["Chile", "México", "Argentina", "USA", "Japan", "UK"]
		"Mano dominante":
			return ["Right", "Left"]
		"Guardia":
			return ["Orthodox", "Southpaw", "Philly Shell", "Peek-a-boo"]
		"Altura":
			return [168, 172, 178, 184, 190]
		"Peso":
			return [60, 66, 72, 79, 86, 95]
		"Color de piel":
			return ["Pale", "Medium", "Tan", "Dark"]
		"Corte de pelo":
			return ["None", "Short", "Fade", "Curly", "Mohawk"]
		"Color de pelo", "Color de barba":
			return ["Black", "Brown", "Blonde", "Red"]
		"Barba":
			return ["None", "Goatee", "Full", "Stubble"]
		"Short":
			return ["Classic", "Long", "Retro"]
		"Color de short", "Color de guantes":
			return ["Black", "Red", "Blue", "White", "Gold"]
		"Guantes":
			return ["Pro", "Compact", "Classic"]
		"Zapatos":
			return ["High Top", "Low Cut", "Black", "White"]
		"Estilo de pelea":
			return ["Balanced", "Aggressive", "Defensive", "Counter", "Showman"]
	return []


func _property_for_category(category: String) -> String:
	return {
		"Nombre": "first_name",
		"Apellido": "last_name",
		"Apodo": "nickname",
		"Edad": "age",
		"País": "country",
		"Mano dominante": "dominant_hand",
		"Guardia": "guard",
		"Altura": "height_cm",
		"Peso": "weight_kg",
		"Color de piel": "skin_tone",
		"Corte de pelo": "hair_style",
		"Color de pelo": "hair_color",
		"Barba": "beard_style",
		"Color de barba": "beard_color",
		"Short": "shorts",
		"Color de short": "shorts_color",
		"Guantes": "gloves",
		"Color de guantes": "glove_color",
		"Zapatos": "shoes",
		"Estilo de pelea": "fight_style",
	}.get(category, "")


func _ensure_rotation_actions() -> void:
	var definitions := {
		"creator_rotate_left": [KEY_Q, JOY_BUTTON_LEFT_SHOULDER],
		"creator_rotate_right": [KEY_E, JOY_BUTTON_RIGHT_SHOULDER],
	}
	for action in definitions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var key := InputEventKey.new()
			key.physical_keycode = definitions[action][0]
			InputMap.action_add_event(action, key)
			var joy := InputEventJoypadButton.new()
			joy.button_index = definitions[action][1]
			InputMap.action_add_event(action, joy)
