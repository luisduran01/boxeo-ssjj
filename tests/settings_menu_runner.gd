extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _expect(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error("SETTINGS_MENU: " + message)
func _run() -> void:
	var requested := OS.get_environment("BOXING_TEST_SIZE").split("x")
	if requested.size() == 2: get_root().content_scale_size = Vector2i(int(requested[0]), int(requested[1]))
	SaveSystem.settings = SaveSystem.default_settings()
	var menu = (load("res://scenes/menus/settings.tscn") as PackedScene).instantiate(); get_root().add_child(menu); await process_frame; await process_frame
	for name in ["General", "Controls", "Sound", "Graphics", "Gameplay", "Camera", "Language", "Accessibility", "Credits"]: _expect(menu.find_child("Category%s" % name, true, false) is Button, "missing %s" % name)
	_expect(get_root().gui_get_focus_owner() == menu.find_child("CategoryGeneral", true, false), "General must receive focus")
	menu.show_category(&"general"); _expect((menu.find_child("DifficultyOption", true, false) as OptionButton).item_count == 3, "difficulty values"); _expect((menu.find_child("RoundsOption", true, false) as OptionButton).item_count == 5, "round values")
	menu.show_category(&"graphics"); _expect((menu.find_child("ResolutionOption", true, false) as OptionButton).item_count == 4, "resolution values"); _expect((menu.find_child("FpsLimitOption", true, false) as OptionButton).item_count == 5, "FPS values")
	menu.show_category(&"sound"); var music := menu.find_child("MusicSlider", true, false) as HSlider; music.value = 0.31; _expect(is_equal_approx(float(SaveSystem.settings.music), music.value), "audio updates live")
	_expect(menu.find_child("ApplyButton", true, false) is Button and menu.find_child("ResetButton", true, false) is Button, "Apply and Reset required")
	menu.queue_free()
	if failures == 0: print("SETTINGS MENU TESTS PASSED"); quit(0)
	else: push_error("SETTINGS MENU TESTS FAILED: %d" % failures); quit(1)
