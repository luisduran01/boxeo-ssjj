extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MAX LEVEL FOUNDATION: " + message)


func _run() -> void:
	_test_fightsim_is_deterministic_and_node_free()
	_test_low_latency_ring_buffer_consumes_next_tick()
	_test_manual_animation_driver_freezes_on_hitstop()
	_test_hitbox_sweep_is_deterministic_and_zone_based()
	if failures.is_empty():
		print("MAX_LEVEL_FOUNDATION_TESTS_PASSED")
		quit(0)
		return
	push_error("MAX_LEVEL_FOUNDATION_TESTS_FAILED: %d" % failures.size())
	quit(1)


func _test_fightsim_is_deterministic_and_node_free() -> void:
	var script: Script = load("res://scripts/sim/fight_sim.gd")
	_expect(script != null, "FightSim script must exist")
	if script == null:
		return
	var sim_a = script.new(1234)
	var sim_b = script.new(1234)
	_expect(not sim_a is Node, "FightSim must be node-free")
	for tick in range(12):
		var inputs := PackedInt32Array([1 if tick == 0 else 0, 0])
		sim_a.step(inputs)
		sim_b.step(inputs)
	_expect(sim_a.snapshot_hash() == sim_b.snapshot_hash(), "same seed and inputs must produce identical snapshots")
	_expect(sim_a.frame == 12, "FightSim must advance one fixed tick per step")
	sim_a.apply_hitstop(0, 3)
	var before: Dictionary = sim_a.fighter_snapshot(0)
	sim_a.step(PackedInt32Array([0, 0]))
	sim_a.step(PackedInt32Array([0, 0]))
	_expect(sim_a.fighter_snapshot(0).phase_frame == before.phase_frame, "hitstop must freeze that fighter phase")
	_expect(sim_a.telemetry_seed == 1234, "FightSim must expose the seed for telemetry")


func _test_low_latency_ring_buffer_consumes_next_tick() -> void:
	var script: Script = load("res://scripts/input/low_latency_input_buffer.gd")
	_expect(script != null, "low latency input buffer script must exist")
	if script == null:
		return
	var buffer = script.new()
	_expect(Input.use_accumulated_input == false, "low latency input must disable accumulated input")
	var event := InputEventAction.new()
	event.action = &"jab"
	event.pressed = true
	buffer.capture_event(event, 40)
	_expect(buffer.consume_bits_for_frame(39) == 0, "input must not be consumed before its physics frame")
	_expect(buffer.consume_bits_for_frame(40) != 0, "input must be consumed on the next sim tick")
	_expect(buffer.logical_latency_frames(40) <= 1, "ring buffer logical latency must be one frame or less in tests")
	_expect(ProjectSettings.has_setting("autoload/LowLatencyInput"), "low latency input must be registered as an autoload")


func _test_manual_animation_driver_freezes_on_hitstop() -> void:
	var script: Script = load("res://scripts/presentation/manual_animation_driver.gd")
	_expect(script != null, "manual animation driver script must exist")
	if script == null:
		return
	var driver = script.new()
	var fake_tree := FakeManualTree.new()
	driver.bind_tree(fake_tree)
	driver.apply_state({"hitstop": 0, "stamina": 80.0})
	var before_hitstop_advances := fake_tree.advance_calls
	driver.apply_state({"hitstop": 6, "stamina": 80.0})
	driver.apply_state({"hitstop": 6, "stamina": 80.0})
	_expect(fake_tree.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "AnimationTree must be in manual mode")
	_expect(fake_tree.advance_calls == before_hitstop_advances, "manual animation must not advance while hitstop is active")
	_expect(driver.look_at_weight_for_state({"phase": "NEUTRAL"}) == 0.6, "neutral LookAt weight must match spec")
	_expect(driver.look_at_weight_for_state({"phase": "WOBBLE"}) == 0.2, "wobble LookAt weight must drop")
	_expect(driver.look_at_weight_for_state({"phase": "KNOCKDOWN"}) == 0.0, "knockdown LookAt weight must disable")


func _test_hitbox_sweep_is_deterministic_and_zone_based() -> void:
	var script: Script = load("res://scripts/combat/hitbox_query.gd")
	_expect(script != null, "hitbox query script must exist")
	if script == null:
		return
	var query = script.new()
	query.add_hurtbox(12, "head", Vector3(0.0, 1.55, 0.0), 0.22)
	query.add_hurtbox(4, "liver_left", Vector3(0.18, 1.05, 0.0), 0.18)
	query.add_hurtbox(8, "torso", Vector3(0.0, 1.1, 0.0), 0.28)
	var hits: Array = query.sweep_hit(Vector3(-0.6, 1.1, 0.0), Vector3(0.4, 1.1, 0.0), 0.16, 3)
	_expect(hits.size() >= 2, "sweep query must catch fast glove movement")
	_expect(int(hits[0].zone_id) < int(hits[1].zone_id), "sweep hits must be sorted deterministically by zone id")
	_expect(query.register_active_hit("jab", 4), "first active hit on a hurtbox must register")
	_expect(not query.register_active_hit("jab", 4), "same active phase must not hit the same hurtbox twice")


class FakeManualTree:
	extends RefCounted
	var callback_mode_process := 0
	var advance_calls := 0
	var parameters := {}

	func advance(_delta: float) -> void:
		advance_calls += 1

	func set_param(path: StringName, value: Variant) -> void:
		parameters[path] = value
