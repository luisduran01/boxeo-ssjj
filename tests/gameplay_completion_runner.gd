extends SceneTree

const PLAYER_SCENE := preload("res://fighters/boxer_02/boxer_02.tscn")
const RIVAL_SCENE := preload("res://fighters/boxer_green/boxer_green.tscn")
const FeedbackScript := preload("res://scripts/presentation/hit_feedback_system.gd")
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
		push_error("GAMEPLAY COMPLETION: " + message)


func _run() -> void:
	player = PLAYER_SCENE.instantiate()
	rival = RIVAL_SCENE.instantiate()
	root.add_child(player)
	root.add_child(rival)
	await process_frame
	_reset_pair()
	await _test_hit_feedback_is_local_and_physical()
	_test_whiff_clean_dirty_and_spam_rules()
	_test_defense_timing_and_guard_rules()
	_test_advanced_footwork_and_range_consequences()
	_test_move_variants_and_zones()
	await _test_clinch_never_sticks()
	_test_ai_advanced_contracts()
	_test_practice_tutorial_controls_versus()
	_test_balance_batch_contract()
	player.queue_free()
	rival.queue_free()
	if failures.is_empty():
		print("GAMEPLAY_COMPLETION_TESTS_PASSED")
		quit(0)
	else:
		push_error("GAMEPLAY_COMPLETION_TESTS_FAILED: %d" % failures.size())
		quit(1)


func _reset_pair() -> void:
	player.is_player = true
	rival.is_player = false
	player.opponent = rival
	rival.opponent = player
	player.global_position = Vector3(0.0, 0.0, 1.0)
	rival.global_position = Vector3(0.0, 0.0, 0.0)
	player.rotation = Vector3.ZERO
	rival.rotation = Vector3(0.0, PI, 0.0)
	for fighter in [player, rival]:
		fighter._finish_action()
		fighter.stats = CombatRules.fresh_stats()
		fighter.fight_enabled = true
		fighter._clear_attack_buffer()
		fighter.guard_stamina = fighter.max_guard_stamina
		fighter.stability = fighter.max_stability


func _test_hit_feedback_is_local_and_physical() -> void:
	_reset_pair()
	var feedback := FeedbackScript.new()
	root.add_child(feedback)
	var before := rival.global_position
	Engine.time_scale = 1.0
	feedback.apply_hit_feedback(player, rival, {"attack_name": "right_hook", "damage": 16.0, "blocked": false, "counter_bonus": 1.0})
	_expect(Engine.time_scale == 1.0, "hit feedback must not use global Engine.time_scale")
	_expect(rival.global_position.distance_to(before) > 0.01, "hit feedback must apply pushback/stagger")
	_expect(rival.rotation.x != 0.0 or rival.rotation.z != 0.0, "hit feedback must apply visible head snap/body snap")
	await create_timer(0.08, true, false, true).timeout
	_expect(is_equal_approx(player.animation_player.speed_scale, 1.0), "local hitstop must restore attacker animation speed")
	_expect(is_equal_approx(rival.animation_player.speed_scale, 1.0), "local hitstop must restore defender animation speed")
	feedback.queue_free()


func _test_whiff_clean_dirty_and_spam_rules() -> void:
	var clean := CombatRules.impact_quality_for_distance("jab", 1.12, 0.02)
	var dirty := CombatRules.impact_quality_for_distance("jab", 1.57, 0.08)
	_expect(clean > dirty, "sweet spot must make clean hits stronger than dirty edge hits")
	var normal := CombatRules.calculate_hit("jab", "head", 100.0, 0.12, false, false, clean, 1.0, 0)
	var repeated := CombatRules.calculate_hit("jab", "head", 100.0, 0.12, false, false, clean, 1.0, 5)
	var counter := CombatRules.calculate_hit("cross", "head", 100.0, 0.12, false, true, clean)
	_expect(float(repeated.damage) < float(normal.damage), "anti-spam must reduce repeated punch damage")
	_expect(float(counter.damage) > float(normal.damage), "counter bonus must raise damage/stability")
	_expect(CombatRules.stamina_cost("cross", true) > CombatRules.stamina_cost("cross", false), "whiff cost must exceed hit cost")


func _test_defense_timing_and_guard_rules() -> void:
	_reset_pair()
	var perfect := player.defense_quality_for_impact(2)
	var normal := player.defense_quality_for_impact(8)
	var late := player.defense_quality_for_impact(-2)
	_expect(perfect == "PERFECT" and normal == "NORMAL" and late == "LATE", "defense timing must classify perfect, normal and late")
	var before: float = float(player.stats.stamina)
	player.request_defense("high_block")
	player.request_defense("high_block")
	player.request_defense("high_block")
	_expect(player.stats.stamina < before, "defense spam must cost stamina")
	player.change_guard_level("body")
	_expect(player.guard_switch_frames_left > 0, "high/low guard changes must take frames")
	player.apply_defense_quality("PERFECT")
	_expect(player.counter_window > 0.0, "perfect defense must open a counter window")


func _test_advanced_footwork_and_range_consequences() -> void:
	_expect(player.backward_speed < player.forward_speed, "backward movement must be slower than forward movement")
	_expect(player.lateral_speed < player.forward_speed, "lateral movement must be slower than forward movement")
	_expect(player.range_modifier_for_state("POCKET").damage_mult > player.range_modifier_for_state("LONG_RANGE").damage_mult, "range states must affect damage")
	var before: float = float(player.stats.stamina)
	player.step_in()
	player.step_out()
	_expect(player.stats.stamina < before, "step-in and step-out must cost stamina")
	var pivot := player.request_pivot(1.0)
	_expect(pivot and rival.positional_disadvantage_frames > 0, "successful pivot must create positional advantage")


func _test_move_variants_and_zones() -> void:
	for move_id in [&"jab_body", &"cross_body", &"left_hook_body", &"right_hook_body", &"uppercut_body", &"overhand", &"double_jab", &"feint"]:
		var data := MoveLibrary.attack_data(move_id)
		_expect(not data.is_empty(), "MoveLibrary must expose %s" % move_id)
	_expect(player.zone_for_hurtbox("Head") == "head", "head hurtbox must resolve to head zone")
	_expect(player.zone_for_hurtbox("Body") == "body", "body hurtbox must resolve to body zone")


func _test_clinch_never_sticks() -> void:
	_reset_pair()
	player.global_position = Vector3(0.0, 0.0, 0.62)
	_expect(player.try_clinch(), "fighter must enter clinch from pocket/too-close")
	_expect(player.combat_state == "CLINCH" and rival.combat_state == "CLINCH", "clinch must be shared")
	await create_timer(0.15).timeout
	player.force_clinch_break("test")
	_expect(player.combat_state != "CLINCH" and rival.combat_state != "CLINCH", "clinch break must release both fighters")
	_expect(player.clinch_cooldown > 0.0, "clinch break must start cooldown")


func _test_ai_advanced_contracts() -> void:
	rival.difficulty = "Legend"
	_expect(rival.ai_reaction_delay_frames() <= 6, "Legend AI reaction delay must be fast but explicit")
	rival.remember_opponent_punch("jab")
	rival.remember_opponent_punch("jab")
	rival.remember_opponent_punch("jab")
	rival.remember_opponent_punch("jab")
	_expect(rival.ai_should_answer_jab_spam(), "AI must detect jab spam from short memory")
	rival.stats.stamina = 10.0
	rival.stats.health = 20.0
	_expect(rival.ai_tactical_mode() == "SURVIVE", "hurt/tired AI must enter SURVIVE")
	player.combat_state = "WOBBLED"
	rival.stats.stamina = 80.0
	rival.stats.health = 80.0
	_expect(rival.ai_tactical_mode() == "FINISH", "AI must enter FINISH when rival is wobbled")


func _test_practice_tutorial_controls_versus() -> void:
	var dummy := DummyScript.new()
	dummy.configure("counter")
	_expect(dummy.mode == "counter" and dummy.frame_data_visible, "practice dummy must expose configurable modes and frame data")
	var tutorial := TutorialScript.new()
	root.add_child(dummy)
	root.add_child(tutorial)
	_expect(tutorial.lesson_count() == 6, "tutorial must expose six lessons")
	_expect(player.gesture_to_attack(Vector2.RIGHT, false) == "cross", "right-stick flicks must map to punches")
	_expect(player.gesture_to_attack(Vector2.RIGHT, true) == "cross_body", "body modifier must route flicks to body variants")
	_expect(player.prompt_for_device("playstation").contains("Square"), "prompts must support PlayStation")
	_expect(player.prompt_for_device("xbox").contains("X"), "prompts must support Xbox")
	var versus := VersusScript.new()
	root.add_child(versus)
	versus.assign_player_device(1, 0)
	versus.assign_player_device(2, 1)
	_expect(versus.device_for_player(1) == 0 and versus.device_for_player(2) == 1, "versus must support independent input profiles")
	versus.mark_device_disconnected(1)
	_expect(versus.should_pause_for_disconnect(), "versus must pause when a mapped controller disconnects")
	dummy.queue_free()
	tutorial.queue_free()
	versus.queue_free()


func _test_balance_batch_contract() -> void:
	var batch := BatchScript.new()
	var report := batch.run_batch(1000)
	_expect(int(report.fights) == 1000, "balance batch must simulate 1000 fights")
	_expect(float(report.punches_per_round) >= 40.0 and float(report.punches_per_round) <= 70.0, "balance punches per round must be in target range")
	_expect(float(report.accuracy) >= 0.25 and float(report.accuracy) <= 0.40, "balance accuracy must be in target range")
	_expect(float(report.knockdowns_per_fight) >= 0.3 and float(report.knockdowns_per_fight) <= 1.0, "balance knockdowns must be in target range")
	_expect(float(report.ko_tko_rate) >= 0.15 and float(report.ko_tko_rate) <= 0.35, "balance KO/TKO rate must be in target range")
	_expect(float(report.max_punch_share) <= 0.45, "no punch may exceed 45 percent usage")
	_expect(float(report.mid_pocket_share) > 0.5, "most time must be in MID_RANGE/POCKET")
