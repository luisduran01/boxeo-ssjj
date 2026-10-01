extends SceneTree

var failures := 0
var fight
var player: BoxerController
var enemy: BoxerController


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FOOTWORK INTEGRATION: " + message)


func _run() -> void:
	change_scene_to_file("res://fight/fight.tscn")
	await process_frame
	await process_frame
	fight = current_scene
	player = fight.player
	enemy = fight.enemy
	await _test_fight_enter_flow()
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	player.fight_enabled = true
	enemy.fight_enabled = true
	_test_face_to_face()
	_test_ai_intentions_are_held()
	_test_pivot_motion()
	_test_stable_separation()
	_test_collision_and_combat_nodes()
	_test_movement_debug_route()
	if failures == 0:
		print("BOXING FOOTWORK INTEGRATION TESTS PASSED")
		quit(0)
	else:
		push_error("BOXING FOOTWORK INTEGRATION TESTS FAILED: %d" % failures)
		quit(1)


func _test_fight_enter_flow() -> void:
	for fighter in [player, enemy]:
		var playback := fighter.animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		_expect(fighter.animation_tree.active, "%s AnimationTree must start active" % fighter.name)
		var current := str(playback.get_current_node()) if playback != null else "NONE"
		_expect(playback != null and current in ["Start", "Boxing_fight_enter", "Footwork"], "%s must begin on the FightEnter path, got %s" % [fighter.name, current])
	await create_timer(1.1).timeout
	for fighter in [player, enemy]:
		var playback := fighter.animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		_expect(playback != null and playback.get_current_node() == "Footwork", "%s FightEnter must resolve to Footwork" % fighter.name)


func _reset_positions(distance := 1.8) -> void:
	player.global_position = Vector3(0.0, 0.0, distance)
	enemy.global_position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	enemy.rotation = Vector3(0.0, PI, 0.0)
	player.velocity = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	player._smoothed_velocity = Vector3.ZERO
	enemy._smoothed_velocity = Vector3.ZERO
	player._pivot_time = 0.0
	enemy._pivot_time = 0.0


func _test_face_to_face() -> void:
	_reset_positions(1.8)
	player.rotation.y = PI * 0.5
	enemy.rotation.y = -PI * 0.5
	for i in range(100):
		player._face_opponent(0.016)
		enemy._face_opponent(0.016)
	var player_to_enemy: Vector3 = (enemy.global_position - player.global_position).normalized()
	var enemy_to_player: Vector3 = -player_to_enemy
	_expect(-player.global_basis.z.dot(player_to_enemy) > 0.98, "player must face AI")
	_expect(-enemy.global_basis.z.dot(enemy_to_player) > 0.98, "AI must face player")
	_expect(absf(player.rotation.x) < 0.001 and absf(player.rotation.z) < 0.001, "target lock must not tilt the player")


func _test_ai_intentions_are_held() -> void:
	_reset_positions(3.2)
	enemy._ai_think_time = 0.0
	var approach: Vector2 = enemy._ai_input(0.5)
	var held: Vector2 = enemy._ai_input(0.01)
	_expect(enemy.ai_state == "APPROACH" and approach.y > 0.0, "AI must approach from OUTSIDE")
	_expect(held.is_equal_approx(approach), "AI must hold one decision until its timer expires")
	player.global_position = Vector3(0.0, 0.0, 0.45)
	enemy.global_position = Vector3.ZERO
	enemy._ai_think_time = 0.0
	var retreat: Vector2 = enemy._ai_input(0.5)
	_expect(enemy.ai_state == "RETREAT" and retreat.y < 0.0, "AI must retreat from TOO_CLOSE")


func _test_pivot_motion() -> void:
	_reset_positions(1.55)
	player._update_range_state()
	var start: Vector3 = player.global_position
	var radial: Vector3 = (enemy.global_position - player.global_position).normalized()
	_expect(player.request_pivot(1.0), "valid close-range right pivot must start")
	for i in range(8):
		player._physics_process(0.05)
	var displacement: Vector3 = player.global_position - start
	_expect(displacement.length() > 0.04 and displacement.length() < 0.9, "pivot must move smoothly without teleporting")
	_expect(absf(displacement.dot(radial)) < displacement.length() * 0.65, "pivot displacement must be primarily tangential")
	for i in range(8):
		player._physics_process(0.05)
	var playback := player.animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_expect(player._pivot_time <= 0.0 and playback.get_current_node() == "Footwork", "pivot must recover to Footwork")


func _test_stable_separation() -> void:
	_reset_positions(0.58)
	player.fight_enabled = false
	enemy.fight_enabled = false
	var start_distance: float = player.global_position.distance_to(enemy.global_position)
	var maximum_speed_seen := 0.0
	for i in range(24):
		player._physics_process(0.025)
		enemy._physics_process(0.025)
		maximum_speed_seen = maxf(maximum_speed_seen, maxf(player.velocity.length(), enemy.velocity.length()))
	var end_distance: float = player.global_position.distance_to(enemy.global_position)
	_expect(end_distance > start_distance and end_distance >= player.hard_separation_distance - 0.08, "overlapping fighters must separate without teleporting")
	_expect(maximum_speed_seen <= player.maximum_separation_speed + 0.08, "hard separation must remain speed-capped, got %.3f" % maximum_speed_seen)
	player.fight_enabled = true
	enemy.fight_enabled = true


func _test_collision_and_combat_nodes() -> void:
	for fighter in [player, enemy]:
		_expect(fighter.body_collider != null and fighter.body_collider.shape is CapsuleShape3D and not fighter.body_collider.disabled, "%s body capsule must remain active" % fighter.name)
		_expect((fighter.collision_layer & 1) != 0 and (fighter.collision_mask & 1) != 0, "%s must keep fighter/ring collision" % fighter.name)
		for path in ["Hitboxes/LeftFist", "Hitboxes/RightFist", "Hurtboxes/Head", "Hurtboxes/Body"]:
			var area := fighter.get_node(path) as Area3D
			_expect(area != null and area.get_child_count() > 0 and area.get_child(0) is CollisionShape3D, "%s must retain %s collision shape" % [fighter.name, path])


func _test_movement_debug_route() -> void:
	player.debug_boxing_movement = false
	fight._process(0.016)
	_expect(fight.hud.debug_label.text == "", "movement debug must stay silent when disabled")
	player.debug_boxing_movement = true
	player._update_range_state()
	fight._process(0.016)
	_expect(fight.hud.debug_label.text.contains("FOOTWORK") and fight.hud.debug_label.text.contains("RANGE"), "enabled movement debug must reach the existing debug label")
