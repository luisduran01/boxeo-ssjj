extends SceneTree

var failures := 0

func _initialize() -> void: _run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("MAIN_MENU: " + message)

func _run() -> void:
	var requested_size := OS.get_environment("BOXING_TEST_SIZE")
	if not requested_size.is_empty():
		var parts := requested_size.split("x")
		if parts.size() == 2: get_root().size = Vector2i(int(parts[0]), int(parts[1]))
	var packed := load("res://scenes/menus/main_menu.tscn") as PackedScene
	_expect(packed != null, "main menu scene must load")
	if packed != null:
		var menu := packed.instantiate()
		get_root().add_child(menu)
		await process_frame
		await process_frame
		var expected := {
			"QuickFightButton": ["01", "QUICK FIGHT", "res://scenes/menus/fighter_select.tscn"],
			"CareerButton": ["02", "CAREER", "res://scenes/menus/career.tscn"],
			"FightersButton": ["03", "FIGHTERS", "res://scenes/menus/fighter_select.tscn"],
			"SettingsButton": ["04", "SETTINGS", "res://scenes/menus/settings.tscn"],
			"ExitButton": ["05", "EXIT", "quit"],
		}
		for node_name in expected:
			var button := menu.find_child(node_name, true, false) as Button
			_expect(button != null, "%s must exist" % node_name)
			if button:
				_expect(button.text.contains(expected[node_name][0]) and button.text.contains(expected[node_name][1]), "%s label must be exact" % node_name)
				_expect(str(button.get_meta("target")) == expected[node_name][2], "%s destination must be exact" % node_name)
				_expect(button.focus_neighbor_top != NodePath("") and button.focus_neighbor_bottom != NodePath(""), "%s must have explicit vertical focus neighbors" % node_name)
				var bounds := button.get_global_rect()
				_expect(bounds.end.x <= get_root().size.x + 1 and bounds.end.y <= get_root().size.y + 1, "%s must remain inside the viewport" % node_name)
		var quick := menu.find_child("QuickFightButton", true, false) as Button
		_expect(get_root().gui_get_focus_owner() == quick, "QuickFightButton must receive initial focus")
		_expect(menu.has_method("set_mode_for_test"), "menu must expose mode setup for navigation verification")
		if menu.has_method("set_mode_for_test"):
			menu.set_mode_for_test(&"quick")
			_expect(SaveSystem.session.mode == "quick", "Quick Fight must store quick mode")
			menu.set_mode_for_test(&"roster")
			_expect(SaveSystem.session.mode == "roster", "Fighters must store roster mode")
		var before := current_scene
		var cancel := InputEventAction.new()
		cancel.action = &"ui_cancel"
		cancel.pressed = true
		menu._unhandled_input(cancel)
		_expect(current_scene == before, "ui_cancel on root menu must not leave the scene")
		menu.queue_free()
	if failures == 0:
		print("MAIN MENU TESTS PASSED")
		quit(0)
	else:
		push_error("MAIN MENU TESTS FAILED: %d" % failures)
		quit(1)
