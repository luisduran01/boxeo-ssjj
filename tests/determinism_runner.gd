extends SceneTree

const FightSimScript := preload("res://scripts/sim/fight_sim.gd")
const PLAYER_SCENE := preload("res://fighters/boxer_02/boxer_02.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("DETERMINISM: " + message)


func _run() -> void:
	_test_full_fight_runs_without_scene()
	_test_same_seed_same_inputs_for_100_ai_fights()
	await _test_boxer_controller_reads_fighter_state_as_adapter()
	if failures.is_empty():
		print("DETERMINISM_TESTS_PASSED")
		quit(0)
		return
	push_error("DETERMINISM_TESTS_FAILED: %d" % failures.size())
	quit(1)


func _test_full_fight_runs_without_scene() -> void:
	var sim := FightSimScript.new(991)
	var result: Dictionary = sim.run_ai_fight(991, 60 * 60)
	_expect(int(result.frames) > 0, "FightSim must run a complete fight without loading a scene")
	_expect(str(result.method) in ["KO", "TKO", "DECISION"], "FightSim must return a complete fight result")
	_expect(float(result.p1.stamina) < 100.0 or float(result.p2.stamina) < 100.0, "real stamina must change during headless fight")
	_expect(float(result.p1.stability) < 100.0 or float(result.p2.stability) < 100.0, "real stability must change during headless fight")
	_expect(Vector2(float(result.p1.x), float(result.p1.z)).distance_to(Vector2(-0.6, 0.0)) > 0.01, "movement must migrate into FightSim state")


func _test_same_seed_same_inputs_for_100_ai_fights() -> void:
	var hashes_a: Array[int] = []
	var hashes_b: Array[int] = []
	for index in range(100):
		hashes_a.append(int(FightSimScript.run_ai_fight_hash(7000 + index, 60 * 35)))
		hashes_b.append(int(FightSimScript.run_ai_fight_hash(7000 + index, 60 * 35)))
	_expect(hashes_a == hashes_b, "same seed and same AI inputs must produce the same final hash for 100 fights")


func _test_boxer_controller_reads_fighter_state_as_adapter() -> void:
	var boxer: BoxerController = PLAYER_SCENE.instantiate()
	root.add_child(boxer)
	await process_frame
	var state := {
		"phase": "ACTIVE",
		"phase_frame": 2,
		"stamina": 72.0,
		"stability": 63.0,
		"guard": 48.0,
		"x": 1.25,
		"z": -0.75,
		"yaw": 0.4,
		"hitstop": 0,
		"attack": "jab",
	}
	_expect(boxer.has_method("apply_fighter_state"), "BoxerController must expose apply_fighter_state adapter")
	if boxer.has_method("apply_fighter_state"):
		boxer.apply_fighter_state(state)
		_expect(boxer.combat_state == "ACTIVE", "BoxerController must read phase from FighterState")
		_expect(is_equal_approx(boxer.stats.stamina, 72.0), "BoxerController must read stamina from FighterState")
		_expect(is_equal_approx(boxer.stability, 63.0), "BoxerController must read stability from FighterState")
		_expect(boxer.global_position.distance_to(Vector3(1.25, 0.0, -0.75)) < 0.01, "BoxerController must read movement position from FighterState")
	boxer.queue_free()
	await process_frame
