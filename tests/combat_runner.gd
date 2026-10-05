extends SceneTree

var failures := 0
var fight


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("COMBAT INTEGRATION: " + message)


func _run() -> void:
	change_scene_to_file("res://fight/fight.tscn")
	await process_frame
	await process_frame
	fight = current_scene
	fight.manager.state = FightManager.State.FIGHTING
	fight.player.fight_enabled = true
	fight.enemy.fight_enabled = false
	_test_movement_and_footwork()
	_test_all_attacks_damage_with_animation()
	_test_visual_camera_and_collision_resources()
	_test_guard_reduces_damage_and_releases()
	_test_ai_attacks_and_defends_reliably()
	_test_ai_states_and_activity()
	await _test_round_scoring_and_transition()
	_test_knockdown_ko_tko_states()
	Input.action_release("move_forward")
	Input.action_release("block_left")
	await _cleanup_scene()
	if failures == 0:
		print("COMBAT INTEGRATION TESTS PASSED")
		quit(0)
	else:
		push_error("COMBAT INTEGRATION TESTS FAILED: %d" % failures)
		quit(1)


func _cleanup_scene() -> void:
	if is_instance_valid(fight) and is_instance_valid(fight.manager) and is_instance_valid(fight.manager.audio):
		var audio: BoxingAudio = fight.manager.audio
		if is_instance_valid(audio.player):
			audio.player.stop()
			audio.player.stream = null
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame


func _test_movement_and_footwork() -> void:
	fight.player.global_position = Vector3(0, 0, 2.4)
	fight.enemy.global_position = Vector3(0, 0, -1.0)
	fight.player.rotation.y = 0.0
	var start_z: float = fight.player.global_position.z
	Input.action_press("move_forward")
	for step in range(8): fight.player._physics_process(0.05)
	Input.action_release("move_forward")
	var blend: Vector2 = fight.player.animation_tree.get("parameters/Footwork/blend_position")
	_expect(fight.player.global_position.z < start_z, "W must move Player toward Enemy")
	_expect(blend.y > 0.25, "W must drive step_forward in Footwork blend")
	_expect(fight.player.animation_tree.active, "Footwork AnimationTree must stay active during locomotion")
	var facing: float = -fight.player.global_basis.z.dot((fight.enemy.global_position - fight.player.global_position).normalized())
	_expect(facing > 0.75, "Player must remain oriented toward Enemy")
	fight.player._smoothed_velocity = Vector3.ZERO
	fight.player.velocity = Vector3.ZERO
	start_z = fight.player.global_position.z
	Input.action_press("move_backward")
	for step in range(8): fight.player._physics_process(0.05)
	Input.action_release("move_backward")
	blend = fight.player.animation_tree.get("parameters/Footwork/blend_position")
	_expect(fight.player.global_position.z > start_z and blend.y < -0.25, "S must retreat using step_backward")
	fight.player._smoothed_velocity = Vector3.ZERO
	fight.player.velocity = Vector3.ZERO
	var start_x: float = fight.player.global_position.x
	Input.action_press("move_left")
	for step in range(8): fight.player._physics_process(0.05)
	Input.action_release("move_left")
	blend = fight.player.animation_tree.get("parameters/Footwork/blend_position")
	_expect(fight.player.global_position.x < start_x and blend.x < -0.25, "A must circle left using step_left")
	fight.player._smoothed_velocity = Vector3.ZERO
	fight.player.velocity = Vector3.ZERO
	start_x = fight.player.global_position.x
	Input.action_press("move_right")
	for step in range(8): fight.player._physics_process(0.05)
	Input.action_release("move_right")
	blend = fight.player.animation_tree.get("parameters/Footwork/blend_position")
	_expect(fight.player.global_position.x > start_x and blend.x > 0.25, "D must circle right using step_right")


func _test_all_attacks_damage_with_animation() -> void:
	for attack_name in ["jab", "cross", "left_hook", "right_hook", "uppercut"]:
		fight.player._finish_action()
		fight.player.global_position = Vector3(0, 0, 0.95)
		fight.enemy.global_position = Vector3(0, 0, 0)
		fight.player.rotation.y = 0.0
		fight.enemy.block_state = ""
		fight.enemy.stats.health = 100.0
		fight.enemy.stats.head_health = 100.0
		fight.enemy.stats.body_health = 100.0
		fight.enemy.stats.stun = 0.0
		fight.player.stats.stamina = 100.0
		fight.player.request_attack(attack_name)
		_expect(fight.player.animation_player.current_animation == "Boxing/" + attack_name, attack_name + " must play its animation")
		var attack := CombatRules.attack_data(attack_name)
		if attack.is_empty():
			continue
		fight.player._update_attack(float(attack.startup) + 0.01)
		fight.player._update_attack(float(attack.active) + 0.01)
		fight.player._update_attack(float(attack.recovery) + 0.01)
		_expect(fight.enemy.stats.health < 100.0, attack_name + " must apply damage")
		_expect(not fight.player.left_fist.monitoring and not fight.player.right_fist.monitoring, attack_name + " hitbox must deactivate")
		_expect(fight.player.animation_tree.active, attack_name + " must return to Footwork")
	for area in [fight.player.left_fist, fight.player.right_fist, fight.player.get_node("Hurtboxes/Head"), fight.player.get_node("Hurtboxes/Body")]:
		_expect(area.get_child_count() > 0 and area.get_child(0) is CollisionShape3D, str(area.name) + " must have CollisionShape3D")


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children(): result.append_array(_descendants(child))
	return result


func _test_visual_camera_and_collision_resources() -> void:
	var has_mesh := false
	var has_rig := false
	for node in _descendants(fight.player):
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null: has_mesh = true
		if node is Skeleton3D and (node as Skeleton3D).get_bone_count() > 0: has_rig = true
	_expect(has_mesh, "Player must contain a visible mesh resource")
	_expect(has_rig, "Player must contain a populated Skeleton3D")
	for animation_name in ["boxing_idle", "step_short", "medium_step", "step_forward", "step_backward", "step_left", "step_right", "jab", "cross", "left_hook", "right_hook", "uppercut", "block_left", "block_right", "block_body", "get_up"]:
		_expect(fight.player.animation_player.has_animation("Boxing/" + animation_name), "Animation library must expose " + animation_name)
	fight.player.global_position = Vector3(0, 0, 2.0)
	fight.enemy.global_position = Vector3(0, 0, -2.0)
	fight.camera_rig._process(1.0)
	_expect(not fight.camera_rig.camera.is_position_behind(fight.player.global_position + Vector3.UP), "camera must keep Player in front")
	_expect(not fight.camera_rig.camera.is_position_behind(fight.enemy.global_position + Vector3.UP), "camera must keep Enemy in front")
	_expect((fight.player.collision_layer & 1) != 0 and (fight.player.collision_mask & 1) != 0, "Player must collide with ring and Enemy")
	_expect((fight.enemy.collision_layer & 1) != 0 and (fight.enemy.collision_mask & 1) != 0, "Enemy must collide with ring and Player")


func _test_guard_reduces_damage_and_releases() -> void:
	fight.player._finish_action()
	fight.player.stats.health = 100.0
	fight.player.stats.head_health = 100.0
	fight.player.stats.stun = 0.0
	var unblocked := CombatRules.calculate_hit("right_hook", "head", 100.0, fight.player.stats.defense, false, false)
	Input.action_press("block_left")
	fight.player._update_defense()
	_expect(fight.player.block_state == "left", "block_left input must enter left guard")
	_expect(fight.player.animation_player.current_animation == "Boxing/block_left", "guard must play block_left")
	var before: float = fight.player.stats.health
	fight.player.receive_hit("right_hook", "head", 100.0, false)
	_expect(before - float(fight.player.stats.health) < float(unblocked.damage), "guard must reduce damage")
	_expect(fight.player.stats.stamina < 100.0, "blocking a strong hit must consume stamina")
	Input.action_release("block_left")
	fight.player._update_defense()
	fight.player._finish_action()
	_expect(fight.player.block_state == "" and fight.player.animation_tree.active, "releasing guard must return to Footwork")


func _test_ai_states_and_activity() -> void:
	fight.enemy.fight_enabled = true
	fight.enemy.difficulty = "Hard"
	fight.enemy._ai_attack_cooldown = 0.0
	fight.enemy._ai_guard_time = 0.0
	fight.enemy._ai_guard_cooldown = 0.0
	fight.enemy.block_state = ""
	fight.enemy.global_position = Vector3(0, 0, -1.3)
	fight.player.global_position = Vector3(0, 0, 0)
	fight.player.combat_state = "RECOVERY"
	fight.enemy._ai_think_time = 0.0
	fight.enemy._ai_input(0.3)
	_expect(fight.enemy.ai_state == "COUNTER", "Hard AI must enter COUNTER against recovery")
	fight.enemy._finish_action()
	fight.player.combat_state = "IDLE"
	fight.enemy.global_position = Vector3(0, 0, -1.45)
	var states := {}
	for i in range(80):
		fight.enemy.stats.stamina = 100.0
		fight.enemy._ai_think_time = 0.0
		fight.enemy._ai_input(0.4)
		states[fight.enemy.ai_state] = true
		fight.enemy._finish_action()
	_expect(states.has("RANGE_CONTROL") and states.has("ATTACK") and states.has("DEFEND") and states.has("CIRCLE"), "AI combat states must be reachable, got %s" % [states.keys()])
	fight.enemy.global_position = Vector3(0, 0, -3.0)
	fight.enemy.stats.stamina = 100.0
	fight.enemy._ai_think_time = 0.0
	var command: Vector2 = fight.enemy._ai_input(0.4)
	_expect(fight.enemy.ai_state == "APPROACH" and command.y > 0.0, "distant AI must approach")


func _test_ai_attacks_and_defends_reliably() -> void:
	fight.enemy._finish_action()
	fight.enemy.fight_enabled = true
	fight.enemy.difficulty = "Medium"
	fight.enemy.global_position = Vector3(0, 0, -1.25)
	fight.player.global_position = Vector3.ZERO
	fight.player.combat_state = "STARTUP"
	fight.enemy.block_state = ""
	fight.enemy._ai_think_time = 0.0
	fight.enemy._ai_input(0.4)
	_expect(fight.enemy.ai_state == "DEFEND" and fight.enemy.block_state != "", "AI must raise a guard against a nearby punch startup")
	fight.enemy._update_defense()
	_expect(fight.enemy.combat_state == "BLOCK" and fight.enemy.animation_player.current_animation.begins_with("Boxing/block_"), "AI defense must visibly play a block animation")
	fight.enemy._finish_action()
	fight.enemy.block_state = ""
	fight.player.combat_state = "IDLE"
	fight.enemy._ai_think_time = 0.0
	var has_attack_cooldown := false
	for property in fight.enemy.get_property_list():
		if property.name == "_ai_attack_cooldown":
			has_attack_cooldown = true
			break
	_expect(has_attack_cooldown, "AI must expose an internal attack cadence timer")
	if not has_attack_cooldown:
		return
	fight.enemy.set("_ai_attack_cooldown", 0.0)
	fight.enemy.set("_ai_guard_time", 0.0)
	fight.enemy.set("_ai_guard_cooldown", 0.0)
	fight.enemy._ai_input(0.4)
	_expect(fight.enemy.ai_state == "ATTACK" and fight.enemy._current_attack != "" and fight.enemy.combat_state == "STARTUP", "AI at punching range must start an attack when its cadence is ready")
	fight.enemy._update_defense()
	_expect(fight.enemy.combat_state == "STARTUP", "AI defense update must not erase an attack startup")
	fight.enemy._update_attack(2.0)
	_expect(fight.enemy._current_attack == "" and fight.enemy.animation_tree.active, "AI attack must complete and recover to Footwork")
	var attacked_during_cooldown := false
	seed(12345)
	for decision in range(12):
		fight.enemy._finish_action()
		fight.enemy._ai_think_time = 0.0
		fight.enemy._ai_input(0.0)
		if fight.enemy._current_attack != "":
			attacked_during_cooldown = true
			break
	_expect(not attacked_during_cooldown, "AI attack cadence must prevent a second attack while cooldown is active")


func _test_round_scoring_and_transition() -> void:
	fight.manager.total_rounds = 2
	fight.manager.current_round = 1
	fight.manager.round_time = 0.0
	fight.manager.state = FightManager.State.FIGHTING
	fight.manager._end_round()
	await create_timer(0.7).timeout
	_expect(fight.manager.current_round == 2, "round end must advance round number")
	_expect(fight.manager.scores.size() == 1, "round end must append a score")
	_expect(fight.player.fight_enabled and fight.enemy.fight_enabled, "combat must resume after round break")


func _test_knockdown_ko_tko_states() -> void:
	fight.player.begin_knockdown()
	_expect(fight.player._knocked_down and fight.player.combat_state == "KNOCKDOWN", "knockdown must interrupt fighter")
	_expect(FightRules.can_get_up(1, 100.0, 7), "first knockdown must allow get-up")
	fight.player._knocked_down = false
	fight.player.rotation.z = 0.0
	fight.player._finish_action()
	fight.manager._end_fight(fight.enemy, "KO")
	_expect(fight.manager.state == FightManager.State.FIGHT_END and fight.hud.banner.text.contains("KO"), "KO must reach result state")
	_expect(FightRules.should_tko(3, fight.manager.tko_knockdown_limit), "third knockdown must satisfy TKO rule")
	fight.manager.state = FightManager.State.FIGHTING
	fight.manager._end_fight(fight.enemy, "TKO")
	_expect(fight.hud.banner.text.contains("TKO"), "TKO must identify result method")
