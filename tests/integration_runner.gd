extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("INTEGRATION: " + message)


func _goto(path: String) -> void:
	var error := change_scene_to_file(path)
	_expect(error == OK, "scene must load: " + path)
	await process_frame
	await process_frame


func _all_of_type(node: Node, type_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	if node.is_class(type_name): result.append(node)
	for child in node.get_children(): result.append_array(_all_of_type(child, type_name))
	return result


func _all_boxers(node: Node) -> Array[BoxerController]:
	var result: Array[BoxerController] = []
	if node is BoxerController: result.append(node as BoxerController)
	for child in node.get_children(): result.append_array(_all_boxers(child))
	return result


func _button(text_value: String) -> Button:
	for node in _all_of_type(current_scene, &"Button"):
		var button := node as Button
		if button.text == text_value or button.text.ends_with(text_value): return button
	return null


func _assert_button(text_value: String) -> Button:
	var button := _button(text_value)
	_expect(button != null, "visible button must exist: " + text_value)
	if button: _expect(button.pressed.get_connections().size() > 0, "button must be connected: " + text_value)
	return button


func _run() -> void:
	await _test_main_menu_and_quick_fight()
	await _test_fight_runtime_and_result_controls()
	await _test_pause_controls()
	await _test_settings_application()
	await _test_all_menu_controls_and_persistence()
	await _test_fighters_roster_flow()
	await _test_sparring_does_not_change_career()
	if failures == 0:
		print("INTEGRATION TESTS PASSED")
		quit(0)
	else:
		push_error("INTEGRATION TESTS FAILED: %d" % failures)
		quit(1)


func _test_main_menu_and_quick_fight() -> void:
	await _goto("res://scenes/menus/main_menu.tscn")
	for label in ["QUICK FIGHT", "CAREER", "FIGHTERS", "SETTINGS", "EXIT"]: _assert_button(label)
	var quick := _button("QUICK FIGHT")
	quick.pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene.scene_file_path == "res://scenes/menus/fighter_select.tscn", "Quick Fight must open Fighter Select")
	_expect(current_scene.find_children("FighterCard*", "Button", true, false).size() == 3, "Fighter Select must expose three fighter cards")
	_expect(current_scene.find_child("ConfirmButton", true, false) is Button, "Fighter Select must expose fight confirmation")
	_expect(current_scene.find_child("BackButton", true, false) is Button, "Fighter Select must expose Back")


func _test_fight_runtime_and_result_controls() -> void:
	await _goto("res://fight/fight.tscn")
	await create_timer(0.15).timeout
	var fight = current_scene
	_expect(fight.get_node_or_null("BoxingRing") != null, "Fight must use the BoxingRing scene")
	var old_rings := fight.get_children().filter(func(child: Node) -> bool: return child is RingBuilder)
	_expect(old_rings.is_empty(), "Fight must not build the legacy RingBuilder arena")
	_expect(_all_boxers(fight).size() == 2, "Fight must contain exactly two boxers")
	_expect(fight.player is BoxerController and fight.enemy is BoxerController, "Fight must spawn Player and Enemy")
	_expect(fight.player.scale.is_equal_approx(Vector3.ONE * 1.55), "Player must use the corrected 1.55 ring scale")
	_expect(fight.enemy.scale.is_equal_approx(Vector3.ONE * 1.55), "Enemy must use the corrected 1.55 ring scale")
	_expect(fight.player.opponent == fight.enemy and fight.enemy.opponent == fight.player, "fighters must reference each other")
	_expect(fight.camera_rig.camera.current, "boxing camera must be current")
	_expect(fight.hud.player_health.value == fight.player.stats.health, "HUD player health must use real stats")
	_expect(fight.hud.enemy_stamina.value == fight.enemy.stats.stamina, "HUD enemy stamina must use real stats")
	SaveSystem.session.mode = "sparring"
	fight.manager.state = FightManager.State.FIGHT_END
	fight.manager._end_fight(fight.player, "KO")
	await process_frame
	_assert_button("REMATCH")
	_assert_button("MAIN MENU")
	_expect(fight.hud.banner.text.contains("ROUND") and fight.hud.banner.text.contains("TIME"), "result must show round and time")
	var rematch := _button("REMATCH")
	rematch.pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene.scene_file_path == "res://fight/fight.tscn", "Rematch must reload Fight")
	current_scene.manager._end_fight(current_scene.player, "KO")
	var menu := _button("MAIN MENU")
	menu.pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene.scene_file_path == "res://scenes/menus/main_menu.tscn", "Result Main Menu must return to main menu")


func _test_pause_controls() -> void:
	await _goto("res://fight/fight.tscn")
	await create_timer(0.1).timeout
	var hud = current_scene.hud
	hud._toggle_pause()
	_expect(paused and hud.pause_panel.visible, "Pause must stop the tree and show its panel")
	for label in ["CONTINUAR", "SETTINGS", "REINICIAR PELEA", "MAIN MENU"]: _assert_button(label)
	var before: float = current_scene.manager.round_time
	await create_timer(0.08, true, false, true).timeout
	_expect(is_equal_approx(before, current_scene.manager.round_time), "round timer must freeze while paused")
	var resume := _button("CONTINUAR")
	resume.pressed.emit()
	await process_frame
	_expect(not paused, "Resume must unpause the tree")
	hud._toggle_pause()
	var settings_button := _button("SETTINGS")
	settings_button.pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene.scene_file_path == "res://scenes/menus/settings.tscn", "Pause Settings must open Settings")
	_button("GUARDAR Y VOLVER").pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene.scene_file_path == "res://fight/fight.tscn", "Pause Settings Back must return to Fight")
	var previous_fight := current_scene
	current_scene.hud._toggle_pause()
	_button("REINICIAR PELEA").pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene.scene_file_path == "res://fight/fight.tscn" and current_scene != previous_fight, "Pause Restart must reload Fight")
	current_scene.hud._toggle_pause()
	_button("MAIN MENU").pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene.scene_file_path == "res://scenes/menus/main_menu.tscn", "Pause Main Menu must return to main menu")


func _test_settings_application() -> void:
	var save_script := load("res://scripts/managers/save_system.gd")
	_expect(save_script.has_method("ensure_audio_buses"), "SaveSystem must expose audio bus integration")
	if save_script.has_method("ensure_audio_buses"): save_script.call("ensure_audio_buses")
	_expect(AudioServer.get_bus_index("Music") >= 0, "Music bus must exist")
	_expect(AudioServer.get_bus_index("SFX") >= 0, "SFX bus must exist")
	_expect(AudioServer.get_bus_index("Crowd") >= 0, "Crowd bus must exist")
	var old := SaveSystem.settings.duplicate(true)
	SaveSystem.settings.master = 0.55
	SaveSystem.settings.music = 0.35
	SaveSystem.settings.sfx = 0.45
	SaveSystem.settings.crowd = 0.25
	SaveSystem.settings.graphics = "Low"
	SaveSystem.save_settings()
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0: _expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)), 0.35), "Music setting must reach Music bus")
	_expect(root.msaa_3d == Viewport.MSAA_DISABLED, "Low graphics must apply to viewport")
	SaveSystem.settings = old
	SaveSystem.save_settings()


func _test_all_menu_controls_and_persistence() -> void:
	await _goto("res://scenes/menus/settings.tscn")
	for control in _all_of_type(current_scene, &"HSlider"):
		_expect((control as HSlider).value_changed.get_connections().size() > 0, "every Settings slider must be connected")
	for control in _all_of_type(current_scene, &"OptionButton"):
		_expect((control as OptionButton).item_selected.get_connections().size() > 0, "every Settings option must be connected")
	for control in _all_of_type(current_scene, &"CheckButton"):
		_expect((control as CheckButton).toggled.get_connections().size() > 0, "every Settings check must be connected")
	var save := _assert_button("GUARDAR Y VOLVER")
	var sliders := _all_of_type(current_scene, &"HSlider")
	var old_master: float = float(SaveSystem.settings.master)
	(sliders[0] as HSlider).value = 0.45
	save.pressed.emit()
	await process_frame
	await process_frame
	await _goto("res://scenes/menus/settings.tscn")
	var reopened := _all_of_type(current_scene, &"HSlider")
	_expect(is_equal_approx((reopened[0] as HSlider).value, 0.45), "Settings value must persist after reopening")
	SaveSystem.settings.master = old_master
	SaveSystem.save_settings()
	await _goto("res://scenes/menus/career.tscn")
	for label in ["RESUMEN", "ENTRENAMIENTO", "CALENDARIO", "EQUIPO", "CONTRATOS", "RANKING", "NOTICIAS", "ESTADÍSTICAS", "VOLVER"]: _assert_button(label)
	var back := _button("VOLVER")
	back.pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene.scene_file_path == "res://scenes/menus/main_menu.tscn", "Career Back must return to main menu")


func _test_fighters_roster_flow() -> void:
	await _goto("res://scenes/menus/main_menu.tscn")
	var fighters := _button("FIGHTERS")
	fighters.pressed.emit()
	await process_frame
	await process_frame
	_expect(SaveSystem.session.mode == "roster", "Fighters button must configure roster mode")
	_expect(current_scene.scene_file_path == "res://scenes/menus/fighter_select.tscn", "Fighters must open Fighter Select")


func _test_sparring_does_not_change_career() -> void:
	await _goto("res://fight/fight.tscn")
	await create_timer(0.1).timeout
	SaveSystem.session.mode = "sparring"
	var before := SaveSystem.career.duplicate(true)
	current_scene.manager._end_fight(current_scene.player, "KO")
	_expect(SaveSystem.career == before, "Sparring result must not alter Career record")
	SaveSystem.career = before
	SaveSystem.save_career()
