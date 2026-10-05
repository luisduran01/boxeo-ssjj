extends SceneTree

const BOXER02 := preload("res://fighters/boxer_02/boxer_02.tscn")
const RIVAL := preload("res://fighters/boxer_green/boxer_green.tscn")

var failures := 0
var boxer
var rival


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("BOXER02 MOVEMENT SEQUENCE: " + message)


func _run() -> void:
	boxer = BOXER02.instantiate()
	rival = RIVAL.instantiate()
	root.add_child(boxer)
	root.add_child(rival)
	await process_frame
	boxer.is_player = true
	rival.is_player = false
	boxer.opponent = rival
	rival.opponent = boxer
	boxer.fight_enabled = true
	rival.fight_enabled = false
	boxer.global_position = Vector3(0.0, 0.0, 1.7)
	rival.global_position = Vector3(0.0, 0.0, 0.0)
	boxer.rotation.y = 0.0
	_release_all_inputs()

	_step_idle()
	_step_move("move_forward", "advance must close distance", true)
	_step_move("move_backward", "retreat must open distance", false)
	_step_lateral("move_left", -1.0)
	_step_lateral("move_right", 1.0)
	_step_circle()
	_step_jab_while_advancing()
	_step_jab_cross_buffer()
	_step_block_and_exit()
	_step_return_to_idle()

	_release_all_inputs()
	boxer.queue_free()
	rival.queue_free()
	if failures == 0:
		print("BOXER02 MOVEMENT SEQUENCE TESTS PASSED")
		quit(0)
	else:
		push_error("BOXER02 MOVEMENT SEQUENCE TESTS FAILED: %d" % failures)
		quit(1)


func _physics_steps(count: int, delta := 0.016) -> void:
	for i in range(count):
		boxer._physics_process(delta)
		_expect(_facing_alignment() > 0.72, "boxer_02 must keep facing rival during sequence")
		_expect(boxer.global_position.distance_to(rival.global_position) >= boxer.hard_separation_distance - 0.04, "boxer_02 must not overlap rival body")
		_expect(absf(boxer.global_position.x) <= boxer.ring_limit + 0.01 and absf(boxer.global_position.z) <= boxer.ring_limit + 0.01, "boxer_02 must stay inside ring limit")


func _step_idle() -> void:
	_physics_steps(8)
	_expect(boxer.animation_tree.active, "idle must keep AnimationTree active")


func _step_move(action: String, message: String, should_close: bool) -> void:
	var before: float = boxer.global_position.distance_to(rival.global_position)
	Input.action_press(action)
	_physics_steps(12)
	Input.action_release(action)
	var after: float = boxer.global_position.distance_to(rival.global_position)
	_expect(after < before if should_close else after > before, message)


func _step_lateral(action: String, sign: float) -> void:
	var before_x: float = boxer.global_position.x
	Input.action_press(action)
	_physics_steps(12)
	Input.action_release(action)
	_expect(signf(boxer.global_position.x - before_x) == sign or absf(boxer.global_position.x - before_x) > 0.03, "%s must create lateral/circling displacement" % action)


func _step_circle() -> void:
	var before_angle: float = atan2(boxer.global_position.z - rival.global_position.z, boxer.global_position.x - rival.global_position.x)
	Input.action_press("move_right")
	Input.action_press("move_forward")
	_physics_steps(18)
	Input.action_release("move_forward")
	Input.action_release("move_right")
	var after_angle: float = atan2(boxer.global_position.z - rival.global_position.z, boxer.global_position.x - rival.global_position.x)
	_expect(absf(wrapf(after_angle - before_angle, -PI, PI)) > 0.05, "diagonal input must circle around rival")


func _step_jab_while_advancing() -> void:
	Input.action_press("move_forward")
	boxer.request_attack("jab")
	_physics_steps(8)
	Input.action_release("move_forward")
	_expect(boxer.combat_state in ["STARTUP", "ACTIVE", "RECOVERY"], "forward jab must enter attack phases without freezing movement system")
	boxer._update_attack(1.0)
	_expect(boxer.animation_tree.active, "jab must return smoothly to locomotion")


func _step_jab_cross_buffer() -> void:
	boxer.stats.stamina = 100.0
	boxer.request_attack("jab")
	boxer.request_attack("cross")
	_expect(boxer.get_next_buffered_attack() == "cross", "cross must buffer after jab")
	var jab := CombatRules.attack_data("jab")
	boxer._update_attack(float(jab.startup) + float(jab.active_time) + maxf(0.0, float(jab.recovery) - float(jab.cancel_window)) + 0.01)
	_expect(boxer._current_attack == "cross", "jab to cross must chain from player input buffer")
	boxer._update_attack(1.0)


func _step_block_and_exit() -> void:
	Input.action_press("block_left")
	boxer._update_defense()
	Input.action_release("block_left")
	_expect(boxer.block_state == "left" and boxer.combat_state == "BLOCK", "block must respond immediately from locomotion")
	Input.action_press("move_left")
	_physics_steps(10)
	Input.action_release("move_left")
	boxer._finish_action()


func _step_return_to_idle() -> void:
	_release_all_inputs()
	_physics_steps(18)
	_expect(boxer.velocity.length() < 0.45 and boxer.animation_tree.active, "release must brake back toward idle locomotion")


func _facing_alignment() -> float:
	var to_rival: Vector3 = rival.global_position - boxer.global_position
	to_rival.y = 0.0
	return -boxer.global_basis.z.dot(to_rival.normalized()) if to_rival.length_squared() > 0.0001 else 1.0


func _release_all_inputs() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right", "block_left", "block_right", "block_body"]:
		Input.action_release(action)
