extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if property.name == property_name:
			return true
	return false


func _run() -> void:
	change_scene_to_file("res://fight/fight.tscn")
	await process_frame
	await process_frame
	var fight = current_scene
	_test_body_collision(fight)
	await _test_broadcast_hud(fight)
	_test_soft_separation(fight)
	_test_referee_priority(fight)
	_test_referee_stays_at_observation_post(fight)
	if failures.is_empty():
		print("PROFESSIONAL_POLISH_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("PROFESSIONAL_POLISH_TESTS_FAILED: ", failures.size())
		quit(1)


func _test_body_collision(fight) -> void:
	for fighter in [fight.player, fight.enemy]:
		_expect(_has_property(fighter, "body_radius"), "%s needs a configurable body radius" % fighter.name)
		var collider := fighter.get_node("CollisionShape3D") as CollisionShape3D
		_expect(collider.shape is CapsuleShape3D, "%s needs a capsule body collider" % fighter.name)
		if collider.shape is CapsuleShape3D and _has_property(fighter, "body_radius"):
			var world_radius: float = (collider.shape as CapsuleShape3D).radius * fighter.scale.x
			_expect(absf(world_radius - fighter.body_radius) < 0.025, "%s collider must match body_radius" % fighter.name)
		_expect((fighter.collision_mask & 16) != 0, "%s must collide with the referee body layer" % fighter.name)
	_expect((fight.player.left_fist.collision_layer & fight.player.collision_layer) == 0, "Punch hitboxes must be separate from body collision")


func _test_soft_separation(fight) -> void:
	var player = fight.player
	var enemy = fight.enemy
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	var required: float = player.body_radius + enemy.body_radius
	var scenarios := [
		_pressure_scenario(player, enemy, Vector3(0, 0, 0.42), Vector3(0, 0, -0.42), Vector2(0, 1), Vector2(0, 1)),
		_pressure_scenario(player, enemy, Vector3(0, 0, 0.42), Vector3(0, 0, -0.42), Vector2(0, 1), Vector2.ZERO),
		_pressure_scenario(player, enemy, Vector3(0, 0, 0.42), Vector3(0, 0, -0.42), Vector2.ZERO, Vector2(0, 1)),
		_pressure_scenario(player, enemy, Vector3(2.65, 0, 2.65), Vector3(2.65, 0, 1.81), Vector2(0, 1), Vector2(0, 1)),
	]
	for index in range(scenarios.size()):
		var result: Dictionary = scenarios[index]
		_expect(float(result.minimum) >= required - 0.045, "Fighters fused in pressure scenario %d" % index)
		_expect(float(result.maximum_step) < 0.075, "Body separation jittered in pressure scenario %d" % index)
	_expect(absf(player.global_position.x) <= 3.39 and absf(player.global_position.z) <= 3.39, "Corner pressure pushed Player through the ropes")
	_expect(absf(enemy.global_position.x) <= 3.39 and absf(enemy.global_position.z) <= 3.39, "Corner pressure pushed Enemy through the ropes")


func _pressure_scenario(player: BoxerController, enemy: BoxerController, player_start: Vector3, enemy_start: Vector3, player_input: Vector2, enemy_input: Vector2) -> Dictionary:
	player.global_position = player_start
	enemy.global_position = enemy_start
	player._smoothed_velocity = Vector3.ZERO
	enemy._smoothed_velocity = Vector3.ZERO
	var minimum_seen := INF
	var maximum_step := 0.0
	var previous_distance: float = player.global_position.distance_to(enemy.global_position)
	for frame in range(240):
		player._move_relative_to_opponent(player_input, 1.0 / 60.0)
		enemy._move_relative_to_opponent(enemy_input, 1.0 / 60.0)
		var distance: float = player.global_position.distance_to(enemy.global_position)
		minimum_seen = minf(minimum_seen, distance)
		maximum_step = maxf(maximum_step, absf(distance - previous_distance))
		previous_distance = distance
	return {"minimum": minimum_seen, "maximum_step": maximum_step}


func _test_referee_priority(fight) -> void:
	var referee = fight.referee
	_expect((referee.collision_layer & 16) != 0 and (referee.collision_mask & 2) != 0, "Referee collision must recognize fighter bodies")
	_expect(_has_property(referee, "body_radius"), "Referee needs a configurable body radius")
	_expect(referee.has_method("_avoid_fighters"), "Referee needs explicit right-of-way avoidance")
	fight.player.global_position = Vector3.ZERO
	fight.enemy.global_position = Vector3(0, 0, -2.0)
	referee.global_position = Vector3(0.46, 0, 0)
	var away: Vector3 = referee.global_position - fight.player.global_position
	away.y = 0.0
	var avoidance: Vector3 = referee._avoid_fighters(Vector3.ZERO)
	_expect(avoidance.dot(away.normalized()) > 0.0, "Referee must move away and yield right-of-way to an approaching fighter")


func _test_referee_stays_at_observation_post(fight) -> void:
	var referee = fight.referee
	fight.player.global_position = Vector3(1.0, 0, 1.0)
	fight.enemy.global_position = Vector3(1.0, 0, -1.0)
	referee.state = RefereeController.State.OBSERVING
	referee.global_position = Vector3(-2.7, 0, 0)
	referee.velocity = Vector3.ZERO
	var start: Vector3 = referee.global_position
	for frame in range(12):
		referee._physics_process(1.0 / 60.0)
	_expect(referee.global_position.distance_to(start) < 0.001, "Referee must remain at his observation post during normal fighting")
	_expect(referee.velocity.length() < 0.001, "Observing referee must not carry movement velocity toward the fighters")


func _test_broadcast_hud(fight) -> void:
	var hud = fight.hud
	_expect(hud.player_name_label.text == fight.player.fighter_name, "HUD must bind the real Player name")
	_expect(hud.enemy_name_label.text == fight.enemy.fighter_name, "HUD must bind the real Enemy name")
	_expect(hud.player_health.value == fight.player.stats.health, "Player health must use real stats")
	_expect(hud.enemy_stamina.value == fight.enemy.stats.stamina, "Enemy stamina must use real stats")
	_expect(hud.player_health_trail is ProgressBar and hud.enemy_health_trail is ProgressBar, "HUD needs delayed damage bars")
	_expect(hud.player_stun is ProgressBar and hud.enemy_stun is ProgressBar, "HUD needs compact stun indicators")
	_expect(hud.clock_card is PanelContainer, "Round and timer need a broadcast card")
	_expect(hud.top_bar.offset_left >= 32.0 and hud.top_bar.offset_right <= -32.0, "HUD needs a responsive safe area")
	get_root().size = Vector2i(1920, 1080)
	await process_frame
	_expect(absf(hud.top_bar.size.x - (hud._root.size.x - 80.0)) < 2.0, "HUD must preserve its logical safe area when stretched to 1920x1080")
	get_root().size = Vector2i(1280, 720)
	await process_frame
	_expect(absf(hud.top_bar.size.x - (hud._root.size.x - 80.0)) < 2.0, "HUD must retain its logical safe area at 1280x720")
	hud.set_clock(2, 9.5)
	_expect(hud.round_label.text == "ROUND 2" and hud.timer_label.text == "0:09", "Clock must bind real round/time and format the final ten seconds")
	var original_health: float = fight.player.stats.health
	fight.player.stats.health = 70.0
	fight.player.stats_changed.emit(fight.player)
	await create_timer(0.19).timeout
	_expect(hud.player_health.value < hud.player_health_trail.value, "Delayed damage bar must trail recent damage")
	await create_timer(0.55).timeout
	_expect(absf(hud.player_health_trail.value - 70.0) < 0.5, "Delayed damage bar must settle on real health")
	fight.referee.count(4)
	hud.announce("4", 0.2)
	_expect(fight.referee.current_count == int(hud.banner.text), "HUD knockdown count must match the referee's logical count")
	fight.player.stats.health = original_health
	fight.player.stats_changed.emit(fight.player)
