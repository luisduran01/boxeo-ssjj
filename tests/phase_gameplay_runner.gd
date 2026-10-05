extends SceneTree

const PLAYER_SCENE := preload("res://fighters/boxer_02/boxer_02.tscn")
const RIVAL_SCENE := preload("res://fighters/boxer_green/boxer_green.tscn")

var failures: Array[String] = []
var player: BoxerController
var rival: BoxerController


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PHASE GAMEPLAY: " + message)


func _run() -> void:
	player = PLAYER_SCENE.instantiate()
	rival = RIVAL_SCENE.instantiate()
	root.add_child(player)
	root.add_child(rival)
	await process_frame
	_reset_pair()
	_test_input_buffer_replaces_oldest_at_three_actions()
	_test_move_data_exposes_feel_fields()
	_test_whiff_cost_is_meaningfully_higher_than_hit_cost()
	player.queue_free()
	rival.queue_free()
	if failures.is_empty():
		print("PHASE_GAMEPLAY_TESTS_PASSED")
		quit(0)
	else:
		push_error("PHASE_GAMEPLAY_TESTS_FAILED: %d" % failures.size())
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


func _test_input_buffer_replaces_oldest_at_three_actions() -> void:
	_reset_pair()
	player.request_attack("jab")
	player.request_attack("cross")
	player.request_attack("left_hook")
	player.request_attack("right_hook")
	player.request_attack("uppercut")
	_expect(player.get_buffered_attack_count() == 3, "attack buffer must keep a maximum of three queued actions")
	_expect(player.get_next_buffered_attack() == "left_hook", "full attack buffer must replace the oldest queued action")


func _test_move_data_exposes_feel_fields() -> void:
	var jab := CombatRules.attack_data("jab")
	for field in ["hitstop_frames", "pushback", "sweet_spot_min", "sweet_spot_max", "whiff_recovery_extra", "whiff_stamina_mult", "magnetism", "stun_power", "counter_mult", "cancel_start_frame", "cancel_end_frame"]:
		_expect(jab.has(field), "MoveData attack data missing feel field %s" % field)
	_expect(float(jab.whiff_stamina_mult) >= 1.3, "whiff stamina multiplier must be meaningful")
	_expect(float(jab.whiff_recovery_extra) > 0.0, "whiff recovery extra must be positive")


func _test_whiff_cost_is_meaningfully_higher_than_hit_cost() -> void:
	var hit_cost := CombatRules.stamina_cost("cross", false)
	var miss_cost := CombatRules.stamina_cost("cross", true)
	_expect(miss_cost >= hit_cost * 1.3, "missed punches must cost substantially more stamina than landed punches")
