extends SceneTree

const FighterDatabaseScript = preload("res://scripts/data/fighter_database.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_boxer_02_scene()
	_test_playstation_input_map()
	_test_referee_scene()
	_test_fight_scene_wiring()
	if failures.is_empty():
		print("GAMEPLAY_UPGRADE_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GAMEPLAY_UPGRADE_TESTS_FAILED: ", failures.size())
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_boxer_02_scene() -> void:
	var packed := load("res://fighters/boxer_02/boxer_02.tscn") as PackedScene
	_expect(packed != null, "Boxer02 scene must load")
	if packed == null:
		return
	var boxer := packed.instantiate()
	get_root().add_child(boxer)
	_expect(boxer is BoxerController, "Boxer02 must use the shared BoxerController")
	_expect(boxer.scale.y >= 1.80, "Boxer02 must have an adult human scale")
	var skeletons := boxer.find_children("*", "Skeleton3D", true, false)
	_expect(not skeletons.is_empty() and (skeletons[0] as Skeleton3D).get_bone_count() >= 30, "Boxer02 must use its imported rig")
	var meshes := boxer.find_children("*", "MeshInstance3D", true, false)
	_expect(not meshes.is_empty() and (meshes[0] as MeshInstance3D).mesh != null, "Boxer02 must use its real mesh")
	var anim_players := boxer.find_children("*", "AnimationPlayer", true, false)
	var animations: PackedStringArray = []
	for candidate in anim_players:
		animations.append_array((candidate as AnimationPlayer).get_animation_list())
	for required in ["Boxing/boxing_idle", "Boxing/step_forward", "Boxing/step_backward", "Boxing/jab", "Boxing/left_hook", "Boxing/right_hook", "Boxing/uppercut", "Boxing/get_up"]:
		_expect(required in animations, "Boxer02 missing animation %s" % required)
	var visual := boxer.get_node_or_null("boxer_02") as Node3D
	_expect(visual != null and visual.basis.z.dot(Vector3.BACK) < -0.9, "Boxer02 visual forward correction must preserve its rig")
	boxer.queue_free()


func _test_playstation_input_map() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right", "punch_left", "punch_right", "hook_modifier", "uppercut_modifier", "body_modifier", "gamepad_guard"]:
		_expect(InputMap.has_action(action), "Missing InputMap action %s" % action)
	var has_analog := false
	for event in InputMap.action_get_events("move_forward"):
		if event is InputEventJoypadMotion:
			has_analog = true
	_expect(has_analog, "Left stick movement must be analog")


func _test_referee_scene() -> void:
	var packed := load("res://referee/referee.tscn") as PackedScene
	_expect(packed != null, "Real referee scene must exist")
	if packed == null:
		return
	var referee := packed.instantiate()
	get_root().add_child(referee)
	_expect(referee is CharacterBody3D, "Referee must be an independent CharacterBody3D")
	_expect(referee.has_method("setup") and referee.has_method("begin_count") and referee.has_method("finish_fight"), "Referee controller API is incomplete")
	var skeletons := referee.find_children("*", "Skeleton3D", true, false)
	_expect(not skeletons.is_empty() and (skeletons[0] as Skeleton3D).get_bone_count() >= 60, "Referee must use the real Mixamo rig")
	var anim_players := referee.find_children("*", "AnimationPlayer", true, false)
	var animations: PackedStringArray = []
	for candidate in anim_players:
		animations.append_array((candidate as AnimationPlayer).get_animation_list())
	for required in ["Referee/ref_idle", "Referee/ref_walk", "Referee/ref_count", "Referee/ref_intercept", "Referee/ref_stop_fight"]:
		_expect(required in animations, "Referee missing animation %s" % required)
	referee.queue_free()


func _test_fight_scene_wiring() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/fight/fight_scene.gd")
	var boxer_02: FighterData = FighterDatabaseScript.by_id(&"fighter_2")
	_expect(boxer_02 != null and boxer_02.scene.resource_path == "res://fighters/boxer_02/boxer_02.tscn", "FighterDatabase must expose Boxer02 as a selectable opponent")
	_expect("res://ring/boxing_ring.tscn" in source, "Fight must use the approved BoxingRing scene")
	_expect("res://referee/referee.tscn" in source, "Fight must spawn the real referee scene")
