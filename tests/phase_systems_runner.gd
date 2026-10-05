extends SceneTree

const PLAYER_SCENE := preload("res://fighters/boxer_02/boxer_02.tscn")
const RIVAL_SCENE := preload("res://fighters/boxer_green/boxer_green.tscn")
const AIScript := preload("res://scripts/ai/boxing_ai_planner.gd")
const CameraScript := preload("res://scripts/camera/boxing_camera.gd")

var failures: Array[String] = []
var player: BoxerController
var rival: BoxerController


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PHASE SYSTEMS: " + message)


func _run() -> void:
	player = PLAYER_SCENE.instantiate()
	rival = RIVAL_SCENE.instantiate()
	root.add_child(player)
	root.add_child(rival)
	await process_frame
	_reset_pair()
	_test_ring_limits_stop_backpedal_at_ropes()
	_test_ai_uses_human_reaction_parameters()
	_test_camera_keeps_startup_readable()
	player.queue_free()
	rival.queue_free()
	if failures.is_empty():
		print("PHASE_SYSTEMS_TESTS_PASSED")
		quit(0)
	else:
		push_error("PHASE_SYSTEMS_TESTS_FAILED: %d" % failures.size())
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


func _test_ring_limits_stop_backpedal_at_ropes() -> void:
	_reset_pair()
	player.ring_limit = 3.25
	player.global_position = Vector3(3.40, 0.0, 0.0)
	player.velocity = Vector3(1.0, 0.0, 0.0)
	player._apply_ring_limit()
	_expect(player.global_position.x <= player.ring_limit, "ring limit must clamp fighters at the ropes")
	_expect(is_zero_approx(player.velocity.x), "ring limit must remove outward velocity at the ropes")


func _test_ai_uses_human_reaction_parameters() -> void:
	var planner := AIScript.new()
	root.add_child(planner)
	planner.setup(rival)
	rival.difficulty = "Easy"
	var rookie_delay := planner.reaction_frames_for_difficulty()
	rival.difficulty = "Hard"
	var hard_delay := planner.reaction_frames_for_difficulty()
	_expect(rookie_delay > hard_delay, "AI difficulty must use slower reaction frames on low difficulty")
	_expect(planner.defensive_error_chance() > 0.0, "AI must expose a defensive error chance instead of perfect reads")
	planner.queue_free()


func _test_camera_keeps_startup_readable() -> void:
	var camera := CameraScript.new()
	root.add_child(camera)
	camera.setup(player, rival)
	player.request_attack("jab")
	camera._process(0.016)
	_expect(camera.camera.fov >= camera.base_fov - 4.1, "gameplay camera must avoid over-zooming during startup")
	_expect(camera.camera.current, "gameplay camera must remain the active camera")
	camera.queue_free()
