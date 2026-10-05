extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("MENU_POLISH: " + message)

func _run() -> void:
	await _test_main_menu_polish()
	await _test_fighter_select_polish()
	await _test_career_polish()
	await _test_settings_polish()
	if failures == 0:
		print("MENU POLISH TESTS PASSED")
		quit(0)
	else:
		push_error("MENU POLISH TESTS FAILED: %d" % failures)
		quit(1)

func _open(path: String) -> Control:
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s must load" % path)
	if packed == null:
		return null
	var scene := packed.instantiate() as Control
	get_root().add_child(scene)
	await process_frame
	await process_frame
	return scene

func _test_main_menu_polish() -> void:
	var menu := await _open("res://scenes/menus/main_menu.tscn")
	if menu == null: return
	_expect(menu.find_child("MenuReadabilityGradient", true, false) is ColorRect, "Main Menu must add a dedicated dark readability gradient")
	_expect(_text_count(menu, "BOXEO SSSJ") == 1, "Main Menu must expose one visible BOXEO SSSJ logo")
	for label in ["QUICK FIGHT", "CAREER", "FIGHTERS", "SETTINGS", "EXIT"]:
		_expect(_button_count(menu, label) == 1, "Main Menu must expose one %s button" % label)
	var focus := get_root().gui_get_focus_owner() as Button
	_expect(focus != null and focus.name == "QuickFightButton", "Main Menu must focus Quick Fight initially")
	_expect(focus != null and focus.has_theme_stylebox_override("focus"), "focused Main Menu button must have a gold focus override")
	menu.queue_free()
	await process_frame

func _test_fighter_select_polish() -> void:
	var menu := await _open("res://scenes/menus/fighter_select.tscn") as FighterSelectMenu
	if menu == null: return
	_expect(menu.find_child("LegacyBackdropMask", true, false) is ColorRect, "Fighter Select must mask old baked text/panels")
	_expect(menu.find_children("FighterCard*", "Button", true, false).size() == 3, "Fighter Select must keep exactly three fighter cards")
	_expect(menu.preview.has_method("is_pose_safe"), "Fighter preview must expose a pose safety check")
	_expect(menu.preview.is_pose_safe(), "Fighter preview must not show unsafe T-pose")
	menu.select_player(&"fighter_1")
	menu.select_opponent(&"fighter_2")
	var confirm := menu.find_child("ConfirmButton", true, false) as Button
	_expect(confirm != null and not confirm.disabled, "Confirm Fight must enable only after player and opponent")
	_expect(not menu.select_opponent(&"fighter_1"), "Fighter Select must reject mirror match")
	menu.queue_free()
	await process_frame

func _test_career_polish() -> void:
	var menu := await _open("res://scenes/menus/career.tscn") as CareerMenu
	if menu == null: return
	_expect(menu.find_child("CareerPrimaryTabs", true, false) == null, "Career must avoid redundant top tabs")
	for section in [&"summary", &"training", &"calendar", &"team", &"contracts", &"ranking", &"news", &"statistics"]:
		menu.show_section(section)
		await process_frame
		var text := menu.current_section_text()
		_expect(text.length() > 20, "Career section %s must render real content" % section)
	_expect(menu.current_section_text().contains("KO"), "Career statistics must expose combat stats")
	menu.queue_free()
	await process_frame

func _test_settings_polish() -> void:
	var menu := await _open("res://scenes/menus/settings.tscn") as SettingsMenu
	if menu == null: return
	var expected := {
		&"general": "GENERAL",
		&"controls": "CONTROLES",
		&"sound": "SONIDO",
		&"graphics": "GRÁFICOS",
		&"gameplay": "JUGABILIDAD",
		&"camera": "CÁMARA",
		&"language": "IDIOMA",
		&"accessibility": "ACCESIBILIDAD",
		&"credits": "CRÉDITOS",
	}
	for category in expected:
		menu.show_category(category)
		await process_frame
		var heading := menu.find_child("CategoryHeading", true, false) as Label
		_expect(heading != null and heading.text == expected[category], "Settings heading must match %s" % category)
	menu.show_category(&"controls")
	await process_frame
	_expect(menu.current_category_text().contains("move_forward") or menu.current_category_text().contains("move_left"), "Controls must show real InputMap actions")
	menu.show_category(&"graphics")
	await process_frame
	_expect(menu.find_child("FullscreenToggle", true, false) is CheckButton, "Graphics must expose fullscreen toggle")
	menu.queue_free()
	await process_frame

func _text_count(root: Node, needle: String) -> int:
	var count := 0
	for node in root.find_children("*", "Label", true, false):
		if (node as Label).visible and (node as Label).text.contains(needle):
			count += 1
	return count

func _button_count(root: Node, needle: String) -> int:
	var count := 0
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).visible and (node as Button).text.contains(needle):
			count += 1
	return count
