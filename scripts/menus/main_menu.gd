extends Control


func _ready() -> void:
	SaveSystem.load_all()
	var box := MenuStyle.base(self, "RINGSIDE LEGACY")
	var subtitle := MenuStyle.title("BOXEO 3D", 18)
	subtitle.modulate = Color("84a9bd")
	box.add_child(subtitle)
	_add_button(box, "QUICK FIGHT", _quick_fight)
	_add_button(box, "CAREER", func(): get_tree().change_scene_to_file("res://scenes/menus/career.tscn"))
	_add_button(box, "SPARRING", _sparring)
	_add_button(box, "SETTINGS", func(): get_tree().change_scene_to_file("res://scenes/menus/settings.tscn"))
	_add_button(box, "EXIT", get_tree().quit)


func _add_button(box: VBoxContainer, text: String, callback: Callable) -> void:
	var button := MenuStyle.button(text)
	button.pressed.connect(callback)
	box.add_child(button)


func _quick_fight() -> void:
	SaveSystem.session = {"mode": "quick", "rounds": 3, "round_duration": 120.0}
	get_tree().change_scene_to_file("res://scenes/menus/fighter_select.tscn")


func _sparring() -> void:
	SaveSystem.session = {"mode": "sparring", "rounds": 4, "round_duration": 90.0}
	get_tree().change_scene_to_file("res://scenes/menus/fighter_select.tscn")
