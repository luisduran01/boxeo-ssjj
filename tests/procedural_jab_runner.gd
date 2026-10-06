extends SceneTree

const MotorScript := preload("res://scripts/presentation/procedural_fighter_motor.gd")
const ViewScript := preload("res://scripts/presentation/fighter_view.gd")
const EventScript := preload("res://scripts/presentation/combat_event_view.gd")
const OwnershipScript := preload("res://scripts/presentation/bone_ownership_config.gd")
const FightSimScript := preload("res://scripts/sim/fight_sim.gd")
const PLAYER_SCENE := preload("res://fighters/boxer_02/boxer_02.tscn")
const RIVAL_SCENE := preload("res://fighters/boxer_green/boxer_green.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PROCEDURAL JAB: " + message)


func _run() -> void:
	_test_move_data_enables_procedural_ab()
	_test_bone_ownership_contract()
	_test_jab_bezier_timing_and_retract()
	_test_head_neck_spring_reacts_by_impact_direction()
	_test_presentation_does_not_mutate_fightsim_hash()
	await _test_real_skeleton_pose_changes_and_ab()
	if failures.is_empty():
		print("PROCEDURAL_JAB_TESTS_PASSED")
		quit(0)
		return
	push_error("PROCEDURAL_JAB_TESTS_FAILED: %d" % failures.size())
	quit(1)


func _test_move_data_enables_procedural_ab() -> void:
	var jab := CombatRules.attack_data("jab")
	_expect(jab.has("procedural_strength"), "MoveData must expose procedural_strength")
	_expect(float(jab.procedural_strength) == 1.0, "jab must default to procedural strength 1 for Phase A")
	var cross := CombatRules.attack_data("cross")
	_expect(float(cross.get("procedural_strength", 0.0)) == 0.0, "non-jab attacks must stay clip-backed in Phase A")


func _test_bone_ownership_contract() -> void:
	var ownership = OwnershipScript.new()
	_expect(ownership.validate_unique_owners().is_empty(), "BoneOwnershipConfig must assign one owner per bone")
	_expect(ownership.owner_for_bone("mixamorig_Head") == "ReactionSpring", "head must be owned by reaction spring")
	_expect(ownership.owner_for_bone("mixamorig_LeftHand") == "ProceduralMotor", "jab hand must be owned by procedural motor")
	var clamped := ownership.clamp_euler("Head", Vector3(99.0, 99.0, 99.0))
	_expect(absf(clamped.x) <= deg_to_rad(35.0) + 0.001, "head pitch must be angular-limited")


func _test_jab_bezier_timing_and_retract() -> void:
	var motor = MotorScript.new()
	var move := CombatRules.attack_data("jab")
	var startup := int(round(float(move.startup_frames)))
	var idle_view = _view("STARTUP", &"jab", 0)
	var start_targets: Dictionary = motor.tick(idle_view, move, 1.0 / 60.0)
	var first_pose = motor.tick(_view("STARTUP", &"jab", 1), move, 1.0 / 60.0)
	_expect(first_pose.left_hand.distance_to(start_targets.left_guard) > 0.005, "input must create first visible pose within 3 frames")
	var active_targets = motor.tick(_view("ACTIVE", &"jab", startup), move, 1.0 / 60.0)
	_expect(float(active_targets.contact_frame_error) <= 1.0, "visual contact must align with first ACTIVE frame within one frame")
	_expect(active_targets.left_hand.distance_to(active_targets.impact_target) < 0.035, "jab hand must reach calculated target on ACTIVE")
	_expect(bool(active_targets.chin_protected), "opposite hand must protect chin during jab")
	_expect(not bool(active_targets.has_nan), "procedural targets must not contain NaN")
	var recovery_targets = motor.tick(_view("RECOVERY", &"jab", int(round(float(move.recovery_frames)))), move, 1.0 / 60.0)
	_expect(recovery_targets.left_hand.distance_to(recovery_targets.left_guard) < 0.04, "retract must return jab hand to guard")


func _test_head_neck_spring_reacts_by_impact_direction() -> void:
	var left_motor = MotorScript.new()
	var right_motor = MotorScript.new()
	var left_event = EventScript.new()
	left_event.move_id = &"jab"
	left_event.power_norm = 0.8
	left_event.punch_dir = Vector3(-1.0, 0.0, 0.2).normalized()
	var right_event = EventScript.new()
	right_event.move_id = &"jab"
	right_event.power_norm = 0.8
	right_event.punch_dir = Vector3(1.0, 0.0, 0.2).normalized()
	left_motor.add_impact(left_event)
	right_motor.add_impact(right_event)
	var view = _view("IDLE", &"", 0)
	var left_targets = left_motor.tick(view, {"procedural_strength": 0.0}, 1.0 / 60.0)
	var right_targets = right_motor.tick(view, {"procedural_strength": 0.0}, 1.0 / 60.0)
	_expect(left_targets.head_reaction.z * right_targets.head_reaction.z < 0.0, "left and right jabs must produce opposite head reaction directions")
	var first_len: float = left_targets.head_reaction.length()
	for _i in range(24):
		left_targets = left_motor.tick(view, {"procedural_strength": 0.0}, 1.0 / 60.0)
	_expect(left_targets.head_reaction.length() < first_len, "spring reaction must recover gradually toward neutral")


func _test_presentation_does_not_mutate_fightsim_hash() -> void:
	var sim = FightSimScript.new(99)
	var motor = MotorScript.new()
	sim.step(PackedInt32Array([FightSim.INPUT_JAB, 0]))
	var before := sim.snapshot_hash()
	var _targets = motor.tick(_view("STARTUP", &"jab", 1), CombatRules.attack_data("jab"), 1.0 / 60.0)
	var event = EventScript.new()
	event.move_id = &"jab"
	event.power_norm = 1.0
	event.punch_dir = Vector3.FORWARD
	motor.add_impact(event)
	motor.tick(_view("ACTIVE", &"jab", 4), CombatRules.attack_data("jab"), 1.0 / 60.0)
	_expect(sim.snapshot_hash() == before, "presentation ON/OFF must not change FightSim hash")


func _test_real_skeleton_pose_changes_and_ab() -> void:
	var player: BoxerController = PLAYER_SCENE.instantiate()
	var rival: BoxerController = RIVAL_SCENE.instantiate()
	root.add_child(player)
	root.add_child(rival)
	await process_frame
	player.is_player = true
	rival.is_player = false
	player.opponent = rival
	rival.opponent = player
	player.global_position = Vector3(0.0, 0.0, 0.0)
	rival.global_position = Vector3(0.0, 0.0, 1.12)
	player.fight_enabled = true
	rival.fight_enabled = true
	var hand_bone := _find_bone(player.skeleton, ["mixamorig_LeftHand", "LeftHand", "Left_Hand"])
	var head_bone := _find_bone(rival.skeleton, ["mixamorig_Head", "Head"])
	_expect(hand_bone >= 0, "test fighter must expose a left hand bone")
	_expect(head_bone >= 0, "test rival must expose a head bone")
	if hand_bone < 0 or head_bone < 0:
		player.queue_free()
		rival.queue_free()
		return
	var before_hand := player.skeleton.get_bone_pose_position(hand_bone)
	player.request_attack("jab")
	for _i in range(4):
		player._physics_process(1.0 / 60.0)
	var procedural_hand := player.skeleton.get_bone_pose_position(hand_bone)
	_expect(procedural_hand.distance_to(before_hand) > 0.01, "procedural jab must modify the real Skeleton3D hand pose")
	var debug := player.get_procedural_debug()
	_expect(float(debug.get("active_contact_error", 999.0)) <= 1.0 or int(debug.get("frame", 0)) <= 4, "procedural skeleton pose must be driven during startup/active")
	player._finish_action()
	player.procedural_presentation_enabled = false
	var clip_before := player.skeleton.get_bone_pose_position(hand_bone)
	player.request_attack("jab")
	for _i in range(4):
		player._physics_process(1.0 / 60.0)
	var clip_hand := player.skeleton.get_bone_pose_position(hand_bone)
	_expect(clip_hand.distance_to(clip_before) < procedural_hand.distance_to(before_hand) * 0.5, "procedural_strength 0/disabled must look different from procedural jab")
	var before_head_rot := rival.skeleton.get_bone_pose_rotation(head_bone)
	rival.receive_hit("jab", "head", 100.0, false, 1.0, 1.0, -1.0)
	for _i in range(3):
		rival._physics_process(1.0 / 60.0)
	var after_head_rot := rival.skeleton.get_bone_pose_rotation(head_bone)
	_expect(not after_head_rot.is_equal_approx(before_head_rot), "jab impact must visibly rotate the rival head/neck skeleton")
	player.queue_free()
	rival.queue_free()


func _view(phase: String, move_id: StringName, frame: int):
	var view = ViewScript.new()
	view.id = 1
	view.pos = Vector3.ZERO
	view.facing = Vector3.FORWARD
	view.move_id = move_id
	view.move_frame = frame
	view.phase = phase
	view.stamina_ratio = 1.0
	view.stability = 1.0
	view.opp_head_pos = Vector3(0.0, 1.52, 1.18)
	view.opp_body_pos = Vector3(0.0, 1.05, 1.05)
	return view


func _find_bone(skeleton: Skeleton3D, names: Array) -> int:
	for name in names:
		var index := skeleton.find_bone(str(name))
		if index >= 0:
			return index
	return -1
