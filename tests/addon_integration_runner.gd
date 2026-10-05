extends SceneTree

const FIGHT_SCENE := preload("res://fight/fight.tscn")
const SETTINGS_SCENE := preload("res://scenes/menus/settings.tscn")
const ENEMY_SCENE := preload("res://fighters/boxer_02/boxer_02.tscn")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("ADDON INTEGRATION: " + message)


func _run() -> void:
	_assert_project_addon_bootstrap()
	await _assert_phantom_camera_in_fight()
	await _assert_limbo_ai_planner_contract()
	await _assert_runtime_controls_settings_ui()
	if failures == 0:
		print("ADDON INTEGRATION TESTS PASSED")
		quit(0)
	else:
		push_error("ADDON INTEGRATION TESTS FAILED: %d" % failures)
		quit(1)


func _assert_project_addon_bootstrap() -> void:
	_expect(ProjectSettings.has_setting("autoload/ControlsRemap"), "Runtime Controls Remap autoload must be enabled")
	_expect(ProjectSettings.has_setting("autoload/PhantomCameraManager"), "Phantom Camera manager autoload must be enabled")
	var remappable: Array = ProjectSettings.get_setting("addons/Controls Remap/Remappable Actions", [])
	for action in [&"move_forward", &"move_backward", &"move_left", &"move_right", &"jab", &"cross", &"left_hook", &"right_hook", &"uppercut", &"block_left", &"block_right", &"block_body", &"slip_left", &"slip_right", &"duck", &"pause"]:
		_expect(remappable.has(action), "controls remap must include %s" % action)


func _assert_phantom_camera_in_fight() -> void:
	SaveSystem.session = {"mode": "sparring", "rounds": 1, "round_duration": 30, "selected_player": "fighter_1", "selected_opponent": "fighter_2"}
	var fight := FIGHT_SCENE.instantiate()
	root.add_child(fight)
	await process_frame
	await process_frame
	_expect(fight.camera_rig != null, "fight scene must create BoxingCamera")
	if fight.camera_rig != null:
		_expect(fight.camera_rig.get_node_or_null("PhantomCameraHost") != null, "BoxingCamera must own a PhantomCameraHost")
		_expect(fight.camera_rig.get_node_or_null("CombatPhantomCamera") != null, "BoxingCamera must own a combat PhantomCamera3D")
		_expect(fight.camera_rig.has_method("set_knockdown_focus"), "BoxingCamera must expose knockdown focus hook")
	fight.queue_free()


func _assert_limbo_ai_planner_contract() -> void:
	var enemy := ENEMY_SCENE.instantiate()
	root.add_child(enemy)
	await process_frame
	enemy.is_player = false
	var planner := enemy.get_node_or_null("BoxingAIPlanner")
	_expect(planner != null, "AI boxer must create BoxingAIPlanner")
	if planner != null:
		_expect(planner.has_method("decide"), "planner must expose decide(delta)")
		_expect(planner.has_method("last_decision"), "planner must expose last_decision")
		_expect(planner.get_node_or_null("BTPlayer") != null or planner.get("limbo_available") == false, "planner must integrate a LimboAI BTPlayer when the class is available")
		enemy.fight_enabled = true
		enemy.stats.stamina = 8.0
		planner.decide(0.5)
		_expect(str(planner.last_decision()) in ["recover_stamina", "retreat", "escape_ropes", "block"], "low stamina decision must be defensive/recovery-oriented")
	enemy.queue_free()


func _assert_runtime_controls_settings_ui() -> void:
	var menu := SETTINGS_SCENE.instantiate()
	root.add_child(menu)
	await process_frame
	menu.show_category(&"controls")
	await process_frame
	var jab_keyboard := menu.find_child("RemapJabKeyboard", true, false)
	var jab_gamepad := menu.find_child("RemapJabGamepad", true, false)
	_expect(jab_keyboard is InputRemapButton, "controls settings must expose keyboard remap buttons")
	_expect(jab_gamepad is InputRemapButton, "controls settings must expose gamepad remap buttons")
	_expect(menu.has_method("input_conflict_for_test"), "settings menu must expose conflict detection for tests")
	if menu.has_method("input_conflict_for_test"):
		var event := InputEventKey.new()
		event.physical_keycode = KEY_J
		_expect(str(menu.input_conflict_for_test(&"cross", event)) == "jab", "conflict detection must find existing keyboard binds")
	menu.queue_free()
