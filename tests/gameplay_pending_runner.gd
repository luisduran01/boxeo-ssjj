extends SceneTree

const PLAYER_SCENE := preload("res://fighters/boxer_02/boxer_02.tscn")
const RIVAL_SCENE := preload("res://fighters/boxer_green/boxer_green.tscn")
const CameraScript := preload("res://scripts/camera/boxing_camera.gd")
const HudScript := preload("res://scripts/ui/fight_hud.gd")
const DummyScript := preload("res://scripts/practice/practice_dummy.gd")
const TutorialScript := preload("res://scripts/practice/tutorial_flow.gd")
const VersusScript := preload("res://scripts/input/local_versus_manager.gd")
const BatchScript := preload("res://scripts/balance/ai_balance_batch.gd")

var failures: Array[String] = []
var player: BoxerController
var rival: BoxerController


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("GAMEPLAY PENDING: " + message)


func _run() -> void:
	player = PLAYER_SCENE.instantiate()
	rival = RIVAL_SCENE.instantiate()
	root.add_child(player)
	root.add_child(rival)
	await process_frame
	_setup_pair()
	await _test_clinch_break_is_visual_and_mid_range()
	await _test_camera_and_hud_pending_contracts()
	_test_practice_lessons_are_playable()
	_test_real_right_stick_flick_mapping()
	_test_local_versus_profiles_selection_disconnect_rematch()
	_test_ai_style_batches_are_distinct_and_exported()
	_test_balance_final_csv_contract()
	player.queue_free()
	rival.queue_free()
	await process_frame
	if failures.is_empty():
		print("GAMEPLAY_PENDING_TESTS_PASSED")
		quit(0)
		return
	push_error("GAMEPLAY_PENDING_TESTS_FAILED: %d" % failures.size())
	quit(1)


func _setup_pair() -> void:
	player.is_player = true
	rival.is_player = false
	player.opponent = rival
	rival.opponent = player
	player.global_position = Vector3(0.0, 0.0, 0.35)
	rival.global_position = Vector3(0.0, 0.0, 0.0)
	player._finish_action()
	rival._finish_action()


func _test_clinch_break_is_visual_and_mid_range() -> void:
	_setup_pair()
	_expect(player.try_clinch(), "clinch must start from too-close range")
	_expect(player.clinch_animation_name != "", "clinch must expose a dedicated animation contract")
	player.force_clinch_break("runner")
	await process_frame
	_expect(player.combat_state != "CLINCH" and rival.combat_state != "CLINCH", "clinch break must release both fighters")
	_expect(player.clinch_cooldown > 0.0 and rival.clinch_cooldown > 0.0, "clinch break must apply cooldown to both fighters")
	var distance := player.global_position.distance_to(rival.global_position)
	_expect(distance >= player.mid_range_distance * 0.92, "clinch break must exit stably to MID_RANGE")


func _test_camera_and_hud_pending_contracts() -> void:
	var camera_controller := CameraScript.new()
	root.add_child(camera_controller)
	camera_controller.setup(player, rival)
	var referee := Node3D.new()
	root.add_child(referee)
	referee.global_position = (player.global_position + rival.global_position) * 0.5
	camera_controller.set_referee(referee)
	player.combat_state = "STARTUP"
	camera_controller._process(0.16)
	_expect(camera_controller.anti_occlusion_active, "camera must detect referee anti-occlusion")
	_expect(camera_controller.startup_visible, "camera must keep STARTUP actions visible")

	var hud := HudScript.new()
	root.add_child(hud)
	await process_frame
	hud.setup(player, rival)
	player.guard_stamina = 44.0
	player.counter_window = 0.2
	hud.set_guard_counter_indicators(player)
	_expect(hud.guard_indicator.text.contains("44"), "HUD must show guard resource")
	_expect(hud.counter_indicator.visible, "HUD must show counter indicator")
	var previous: Variant = SaveSystem.settings.get("show_hud", true)
	SaveSystem.settings["show_hud"] = false
	hud.apply_visibility_settings()
	_expect(not hud.top_bar.visible, "HUD must support no-HUD mode")
	SaveSystem.settings["show_hud"] = previous
	camera_controller.queue_free()
	referee.queue_free()
	hud.queue_free()


func _test_practice_lessons_are_playable() -> void:
	var tutorial := TutorialScript.new()
	root.add_child(tutorial)
	for index in range(tutorial.lesson_count()):
		var scene: Node = tutorial.call("create_lesson_scene", index)
		root.add_child(scene)
		_expect(scene.get_meta("playable", false), "tutorial lesson %d must be playable" % index)
		_expect(scene.has_node("PracticeDummy"), "tutorial lesson %d must include a dummy" % index)
		scene.queue_free()
	var dummy := DummyScript.new()
	dummy.call("configure", "counter", {"guard": "body", "distance": "MID_RANGE"})
	var snapshot: Dictionary = dummy.call("frame_data_snapshot", "jab", 4, 0.31, "MID_RANGE")
	_expect(snapshot.get("frame_data_visible", false), "practice dummy must expose frame data")
	_expect(snapshot.get("distance", "") == "MID_RANGE", "practice dummy must expose distance")
	dummy.free()
	tutorial.queue_free()


func _test_real_right_stick_flick_mapping() -> void:
	var script: Script = load("res://scripts/input/right_stick_flick_mapper.gd")
	_expect(script != null, "right-stick flick mapper script must exist")
	if script == null:
		return
	var mapper: RefCounted = script.new()
	mapper.deadzone = 0.35
	mapper.tolerance = 0.2
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_RIGHT_X
	event.axis_value = 0.86
	_expect(mapper.attack_for_event(event, false) == "cross", "right-stick joypad event must map to cross")
	_expect(mapper.attack_for_event(event, true) == "cross_body", "body modifier must map right flick to body cross")
	var weak := InputEventJoypadMotion.new()
	weak.axis = JOY_AXIS_RIGHT_X
	weak.axis_value = 0.1
	_expect(mapper.attack_for_event(weak, false) == "", "right-stick mapper must honor deadzone")


func _test_local_versus_profiles_selection_disconnect_rematch() -> void:
	var versus := VersusScript.new()
	root.add_child(versus)
	versus.assign_player_device(1, 0)
	versus.assign_player_device(2, 1)
	versus.set_player_profile(1, {"scheme": "classic", "body_modifier": "L2"})
	versus.set_player_profile(2, {"scheme": "right_stick", "body_modifier": "LT"})
	versus.select_fighter(1, "boxer_02")
	versus.select_fighter(2, "boxer_green")
	_expect(versus.profile_for_player(2).scheme == "right_stick", "versus must keep independent profiles")
	_expect(versus.selected_fighter_for_player(1) != versus.selected_fighter_for_player(2), "versus must keep independent P1/P2 selection")
	versus.handle_joy_connection_changed(1, false)
	_expect(versus.should_pause_for_disconnect(), "versus must pause when P2 controller disconnects")
	versus.request_rematch()
	_expect(versus.consume_rematch_requested(), "versus must expose rematch flow")
	versus.queue_free()


func _test_ai_style_batches_are_distinct_and_exported() -> void:
	var batch := BatchScript.new()
	var report: Dictionary = batch.call("run_style_batch", 40)
	_expect(report.styles.size() >= 4, "AI batch must report metrics per style")
	_expect(batch.styles_are_distinct(report), "AI styles must validate as measurably distinct")
	_expect(FileAccess.file_exists(str(report.csv_path)), "AI style batch must export CSV")


func _test_balance_final_csv_contract() -> void:
	var batch := BatchScript.new()
	var report: Dictionary = batch.run_batch(1000)
	_expect(int(report.fights) == 1000, "final balance must run 1000 fights")
	_expect(FileAccess.file_exists(str(report.csv_path)), "final balance must export CSV")
	_expect(float(report.punches_per_round) >= 40.0 and float(report.punches_per_round) <= 70.0, "punches per round must be valid")
	_expect(float(report.accuracy) >= 0.25 and float(report.accuracy) <= 0.40, "accuracy must be valid")
	_expect(float(report.knockdowns_per_fight) >= 0.3 and float(report.knockdowns_per_fight) <= 1.0, "knockdowns must be valid")
	_expect(float(report.ko_tko_rate) >= 0.15 and float(report.ko_tko_rate) <= 0.35, "KO/TKO must be valid")
	_expect(float(report.max_punch_share) <= 0.45, "max punch share must be valid")
