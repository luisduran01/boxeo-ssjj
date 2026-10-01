extends SceneTree

var failures: Array[String] = []
var fight


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PUNCH SYSTEM: " + message)


func _run() -> void:
	change_scene_to_file("res://fight/fight.tscn")
	await process_frame
	await process_frame
	fight = current_scene
	fight.player.fight_enabled = true
	fight.enemy.fight_enabled = false
	_test_catalog()
	_test_mobile_jab()
	_test_ranges_and_results()
	_test_phases_buffer_and_unique_hit()
	_test_shared_ai_and_debug()
	if failures.is_empty():
		print("PUNCH_SYSTEM_TESTS_OK")
		quit(0)
	else:
		push_error("PUNCH_SYSTEM_TESTS_FAILED: %d" % failures.size())
		quit(1)


func _reset(distance: float) -> void:
	fight.player._buffered_attack = ""
	fight.player._buffer_time = 0.0
	fight.enemy._buffered_attack = ""
	fight.enemy._buffer_time = 0.0
	fight.player._finish_action()
	fight.enemy._finish_action()
	fight.player.global_position = Vector3(0, 0, distance)
	fight.enemy.global_position = Vector3.ZERO
	fight.player.rotation.y = 0.0
	fight.enemy.rotation.y = PI
	fight.player.stats = CombatRules.fresh_stats()
	fight.enemy.stats = CombatRules.fresh_stats()
	fight.player._smoothed_velocity = Vector3.ZERO
	fight.player.velocity = Vector3.ZERO
	fight.enemy.block_state = ""


func _test_catalog() -> void:
	for attack_name in ["jab", "left_hook", "right_hook", "uppercut"]:
		var data := CombatRules.attack_data(attack_name)
		for field in ["attack_name", "animation_name", "hand", "attack_type", "target_level", "startup", "active_time", "recovery", "damage", "stamina_cost", "min_range", "range", "power", "stun", "counter_bonus", "movement_allowed", "tracking_strength", "hit_stop", "camera_feedback", "animation_speed", "cancel_window"]:
			_expect(data.has(field), "%s missing %s" % [attack_name, field])
	_expect(CombatRules.attack_data("cross").is_empty(), "cross must remain reserved without a fake animation")
	_expect(float(CombatRules.attack_data("jab").movement_allowed) > float(CombatRules.attack_data("uppercut").movement_allowed), "jab must retain more footwork than uppercut")
	_expect(float(CombatRules.attack_data("jab").range) > float(CombatRules.attack_data("uppercut").range), "jab must outrange uppercut")


func _test_mobile_jab() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right"]:
		_reset(1.35)
		Input.action_press(action)
		fight.player._physics_process(0.05)
		var before: Vector3 = fight.player.global_position
		fight.player.request_attack("jab")
		fight.player._physics_process(0.06)
		Input.action_release(action)
		_expect(fight.player.global_position.distance_to(before) > 0.002, "jab must remain mobile with %s" % action)


func _test_ranges_and_results() -> void:
	for case in [["jab", 1.95, false], ["jab", 1.35, true], ["left_hook", 1.65, false], ["left_hook", 1.05, true], ["uppercut", 1.45, false], ["uppercut", 0.92, true]]:
		_reset(float(case[1]))
		var before: float = fight.enemy.stats.health
		fight.player.request_attack(str(case[0]))
		fight.player._update_attack(float(CombatRules.attack_data(str(case[0])).startup) + 0.01)
		_expect((fight.enemy.stats.health < before) == bool(case[2]), "%s distance %.2f hit expectation mismatch" % [case[0], case[1]])
	_reset(1.1)
	fight.enemy.block_state = "left"
	var blocked: Dictionary = fight.player.preview_hit("left_hook")
	_expect(str(blocked.result) == "BLOCKED", "valid guard must classify BLOCKED")
	_reset(1.1)
	fight.enemy.combat_state = "STARTUP"
	var counter: Dictionary = fight.player.preview_hit("right_hook")
	_expect(str(counter.result) == "COUNTER", "startup vulnerability must classify COUNTER")


func _test_phases_buffer_and_unique_hit() -> void:
	_reset(1.25)
	fight.player.request_attack("jab")
	var first_id: int = fight.player._attack_instance_id
	_expect(fight.player.combat_state == "STARTUP", "attack begins in STARTUP")
	var startup_remaining: float = fight.player._action_time
	fight.player._update_attack(startup_remaining + 0.001)
	_expect(fight.player.combat_state == "ACTIVE", "startup advances to ACTIVE")
	var health_after: float = fight.enemy.stats.health
	fight.player._attempt_strike()
	_expect(is_equal_approx(health_after, float(fight.enemy.stats.health)), "same attack instance cannot hit twice")
	fight.player.request_attack("right_hook")
	_expect(fight.player._buffered_attack == "right_hook", "attack input is buffered")
	fight.player._update_attack(float(CombatRules.attack_data("jab").active_time) + float(CombatRules.attack_data("jab").recovery) + 0.02)
	_expect(fight.player._attack_instance_id > first_id and fight.player._current_attack == "right_hook", "late recovery consumes buffered combo")


func _test_shared_ai_and_debug() -> void:
	_expect(fight.player.get_script() == fight.enemy.get_script(), "player and AI use the same combat controller")
	_expect(fight.enemy._choose_ai_attack(2.0) == "jab", "AI long range selection uses jab")
	for i in range(20):
		_expect(fight.enemy._choose_ai_attack(0.9) in ["left_hook", "right_hook", "uppercut"], "AI close range selection uses close punches")
	_expect(not fight.player.punch_debug_enabled, "punch debug is off by default")
	var debug: Dictionary = fight.player.get_punch_debug()
	for field in ["attack", "phase", "hand", "range", "target", "hitbox_active", "hit_result", "damage", "stamina_cost", "counter", "distance"]:
		_expect(debug.has(field), "debug snapshot missing %s" % field)
