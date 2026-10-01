extends SceneTree

const PLAYER_SCENE := preload("res://fighters/boxer_green/boxer_green.tscn")
const ENEMY_SCENE := preload("res://fighters/boxer_02/boxer_02.tscn")

var failures := 0
var player
var enemy


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FOOTWORK CONTROLLER: " + message)


func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if str(property.name) == property_name:
			return true
	return false


func _run() -> void:
	player = PLAYER_SCENE.instantiate()
	enemy = ENEMY_SCENE.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	await process_frame
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	player.is_player = true
	enemy.is_player = false
	player.opponent = enemy
	enemy.opponent = player
	player.fight_enabled = true
	enemy.fight_enabled = true
	_test_public_contract()
	if player.has_method("set_movement_intent") and _has_property(player, "range_state"):
		_test_target_lock_and_ranges()
		_test_player_only_input_and_relative_motion()
		_test_acceleration_and_long_latch()
		_test_debug_snapshot()
	Input.action_release("move_forward")
	Input.action_release("move_right")
	player.queue_free()
	enemy.queue_free()
	if failures == 0:
		print("BOXING FOOTWORK CONTROLLER TESTS PASSED")
		quit(0)
	else:
		push_error("BOXING FOOTWORK CONTROLLER TESTS FAILED: %d" % failures)
		quit(1)


func _test_public_contract() -> void:
	for property_name in [
		"debug_boxing_movement", "input_deadzone", "short_step_threshold",
		"medium_step_threshold", "long_step_threshold", "long_step_rearm_threshold",
		"long_step_duration", "long_step_cooldown", "forward_speed", "backward_speed",
		"lateral_speed", "acceleration", "deceleration", "turn_responsiveness",
		"minimum_fighter_distance", "hard_separation_distance",
		"soft_separation_strength", "maximum_separation_speed", "range_state",
		"movement_intensity", "locomotion_state"
	]:
		_expect(_has_property(player, property_name), "controller must expose %s" % property_name)
	_expect(player.has_method("set_movement_intent"), "controller must expose set_movement_intent")
	_expect(player.has_method("request_pivot"), "controller must expose request_pivot")
	_expect(player.has_method("get_boxing_movement_debug"), "controller must expose movement debug snapshot")


func _reset_positions() -> void:
	player.global_position = Vector3(0.0, 0.0, 2.0)
	enemy.global_position = Vector3(0.0, 0.0, -2.0)
	player.velocity = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	player._smoothed_velocity = Vector3.ZERO
	enemy._smoothed_velocity = Vector3.ZERO


func _test_target_lock_and_ranges() -> void:
	_reset_positions()
	player.rotation.y = PI * 0.5
	var before: float = player.rotation.y
	player._face_opponent(0.016)
	_expect(player.rotation.y != before and absf(player.rotation.y) > 0.01, "target lock must rotate progressively, not snap")
	for i in range(90):
		player._face_opponent(0.016)
	var planar_target: Vector3 = enemy.global_position - player.global_position
	planar_target.y = 0.0
	var alignment: float = -player.global_basis.z.dot(planar_target.normalized())
	_expect(alignment > 0.98, "player body must settle facing the opponent")
	player._update_range_state()
	_expect(str(player.get_range_state_name()) == "OUTSIDE", "four metres must classify as OUTSIDE")
	enemy.global_position = Vector3(0.0, 0.0, 0.5)
	player._update_range_state()
	_expect(str(player.get_range_state_name()) == "MID_RANGE", "1.5 metres must classify as MID_RANGE")
	enemy.global_position = Vector3(0.0, 0.0, 1.4)
	player._update_range_state()
	_expect(str(player.get_range_state_name()) == "TOO_CLOSE", "0.6 metres must classify as TOO_CLOSE")


func _test_player_only_input_and_relative_motion() -> void:
	_reset_positions()
	player.rotation.y = 0.0
	enemy.rotation.y = PI
	var player_start: Vector3 = player.global_position
	var enemy_start: Vector3 = enemy.global_position
	Input.action_press("move_forward")
	for i in range(6):
		player._physics_process(0.05)
		enemy.fight_enabled = false
		enemy._physics_process(0.05)
	Input.action_release("move_forward")
	_expect(player.global_position.distance_to(enemy.global_position) < player_start.distance_to(enemy_start), "player forward input must close distance")
	_expect(enemy.global_position.distance_to(enemy_start) < 0.01, "player input must not move the AI")
	_reset_positions()
	var retreat_start: float = player.global_position.distance_to(enemy.global_position)
	Input.action_press("move_backward")
	for i in range(6):
		player._physics_process(0.05)
	Input.action_release("move_backward")
	_expect(player.global_position.distance_to(enemy.global_position) > retreat_start, "backward input must open distance")
	var facing: float = -player.global_basis.z.dot((enemy.global_position - player.global_position).normalized())
	_expect(facing > 0.9, "retreat must keep target lock")
	_reset_positions()
	Input.action_press("move_right")
	for i in range(5):
		player._physics_process(0.05)
	Input.action_release("move_right")
	_expect(absf(player.global_position.x) > 0.02, "lateral input must circle in the combat basis")


func _test_acceleration_and_long_latch() -> void:
	_reset_positions()
	player._long_step_armed = true
	player._long_step_cooldown = 0.0
	Input.action_press("move_forward")
	player._physics_process(0.016)
	var first_speed: float = player.velocity.length()
	var first_long_time: float = player._long_step_time
	player._physics_process(0.016)
	Input.action_release("move_forward")
	_expect(first_speed > 0.0 and first_speed < player.forward_speed, "acceleration must avoid an instant velocity snap")
	_expect(first_long_time > 0.0 and player._long_step_time <= first_long_time, "held full input must trigger one Long pulse without restarting its timer")
	for i in range(8):
		player._physics_process(0.05)
	_expect(player.movement_intensity < player.long_step_threshold and player._long_step_armed, "release must settle to idle and re-arm Long")


func _test_debug_snapshot() -> void:
	player.debug_boxing_movement = false
	_expect(player.get_boxing_movement_debug().is_empty(), "movement debug must be silent and empty when disabled")
	player.debug_boxing_movement = true
	var snapshot: Dictionary = player.get_boxing_movement_debug()
	for key in ["distance", "range_state", "input_vector", "movement_intensity", "locomotion_state", "target", "speed", "target_speed", "facing_alignment", "separation_correction"]:
		_expect(snapshot.has(key), "debug snapshot must include %s" % key)
