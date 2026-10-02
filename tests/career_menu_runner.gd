extends SceneTree

const SETTINGS_FIXTURE := "user://career_ui_settings.cfg"
const CAREER_FIXTURE := "user://career_ui_save.json"
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CAREER_MENU: " + message)

func _run() -> void:
	var requested_size := OS.get_environment("BOXING_TEST_SIZE")
	if not requested_size.is_empty():
		var parts := requested_size.split("x")
		if parts.size() == 2: get_root().content_scale_size = Vector2i(int(parts[0]), int(parts[1]))
	SaveSystem.configure_paths(SETTINGS_FIXTURE, CAREER_FIXTURE)
	SaveSystem.settings = SaveSystem.default_settings()
	SaveSystem.career = SaveSystem.default_career()
	SaveSystem.career.money = 9876
	SaveSystem.career.fight_history = [{"result": "WIN", "method": "TKO", "round": 4, "opponent": "fighter_2", "date": "2026-09-10"}]
	SaveSystem.save_career()
	var packed := load("res://scenes/menus/career.tscn") as PackedScene
	_expect(packed != null, "career scene must load")
	if packed:
		var menu := packed.instantiate()
		get_root().add_child(menu)
		await process_frame
		await process_frame
		var sections := ["Summary", "Training", "Calendar", "Team", "Contracts", "Ranking", "News", "Statistics"]
		for section in sections: _expect(menu.find_child("Section%s" % section, true, false) is Button, "missing section %s" % section)
		var first := menu.find_child("SectionSummary", true, false) as Button
		_expect(get_root().gui_get_focus_owner() == first, "Summary section must receive initial focus")
		for section in sections:
			var button := menu.find_child("Section%s" % section, true, false) as Button
			_expect(button != null and button.get_global_rect().end.x <= get_root().get_visible_rect().end.x + 1.0, "%s must fit the viewport" % section)
		_expect(menu.has_method("show_section") and menu.has_method("train_for_test"), "career menu must expose functional section and training APIs")
		if not menu.has_method("show_section") or not menu.has_method("train_for_test"):
			menu.queue_free()
			_finish()
			return
		menu.show_section(&"summary")
		var text: String = menu.current_section_text()
		_expect(text.contains("9876"), "summary must display persisted money")
		_expect(text.contains("TKO") and text.contains("fighter_2"), "summary must display complete recent history")
		var before: Dictionary = SaveSystem.career.attributes.duplicate()
		menu.train_for_test(&"power")
		_expect(SaveSystem.career.attributes.power == mini(100, int(before.power) + 2), "power training must alter only power")
		for key in [&"speed", &"stamina", &"defense", &"technique"]: _expect(SaveSystem.career.attributes[key] == before[key], "power training must not alter %s" % key)
		SaveSystem.career.fatigue = 50
		SaveSystem.career.fitness = 60
		menu.rest_for_test()
		_expect(SaveSystem.career.fatigue < 50 and SaveSystem.career.fitness > 60, "rest must recover fatigue and fitness")
		var week: int = SaveSystem.career.current_week
		menu.advance_for_test()
		_expect(SaveSystem.career.current_week == week + 1, "advance time must increment the week")
		menu.show_section(&"ranking")
		_expect(menu.current_section_text().contains("FIGHTER 1") and menu.current_section_text().contains("FIGHTER 2") and menu.current_section_text().contains("FIGHTER 3"), "ranking must list all three fighters")
		_expect(menu.find_child("BackButton", true, false) is Button, "career must expose Back")
		menu.queue_free()
	for path in [SETTINGS_FIXTURE, CAREER_FIXTURE]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_finish()

func _finish() -> void:
	if failures == 0:
		print("CAREER MENU TESTS PASSED")
		quit(0)
	else:
		push_error("CAREER MENU TESTS FAILED: %d" % failures)
		quit(1)
