extends SceneTree

const BOXER_SCENE := preload("res://fighters/boxer_02/boxer_02.tscn")
const UNARMED_SCENE_PATH := "res://animations/rpg_pack/Unarmed.glb"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("BOXER02 ANIMATION CLEANLINESS: " + message)


func _run() -> void:
	var boxer := BOXER_SCENE.instantiate()
	root.add_child(boxer)
	await process_frame
	var model := boxer.get_node_or_null("boxer_02") as Node3D
	var skeleton := boxer.get_node_or_null(boxer.skeleton_path) as Skeleton3D
	var player := boxer.get_node_or_null("boxer_02/AnimationPlayer2") as AnimationPlayer
	_expect(model != null, "boxer_02 visual model must exist")
	_expect(skeleton != null and skeleton.get_bone_count() >= 20, "boxer_02 skeleton path must resolve to a populated Skeleton3D")
	_expect(player != null and player.has_animation_library("Boxing"), "AnimationPlayer2 must expose the Boxing library")
	_expect(player != null and player.has_animation_library("UnarmedSupport"), "AnimationPlayer2 must expose retargeted UnarmedSupport animations")
	if skeleton != null and player != null:
		_assert_boxing_tracks_resolve(model, skeleton, player)
		_assert_required_boxing_animation_set(player)
		_assert_unarmed_support_tracks_resolve(skeleton, player)
	await _assert_unarmed_pack_has_retargetable_humanoid_core()
	boxer.queue_free()
	if failures == 0:
		print("BOXER02 ANIMATION CLEANLINESS TESTS PASSED")
		quit(0)
	else:
		push_error("BOXER02 ANIMATION CLEANLINESS TESTS FAILED: %d" % failures)
		quit(1)


func _assert_boxing_tracks_resolve(model: Node3D, skeleton: Skeleton3D, player: AnimationPlayer) -> void:
	var bone_names := {}
	for bone_index in range(skeleton.get_bone_count()):
		bone_names[skeleton.get_bone_name(bone_index)] = true
	var unresolved := PackedStringArray()
	var important_bones := {
		"mixamorig_Hips": true,
		"mixamorig_Spine": true,
		"mixamorig_Spine1": true,
		"mixamorig_Spine2": true,
		"mixamorig_Neck": true,
		"mixamorig_Head": true,
		"mixamorig_LeftShoulder": true,
		"mixamorig_LeftArm": true,
		"mixamorig_LeftForeArm": true,
		"mixamorig_LeftHand": true,
		"mixamorig_RightShoulder": true,
		"mixamorig_RightArm": true,
		"mixamorig_RightForeArm": true,
		"mixamorig_RightHand": true,
		"mixamorig_LeftUpLeg": true,
		"mixamorig_LeftLeg": true,
		"mixamorig_LeftFoot": true,
		"mixamorig_RightUpLeg": true,
		"mixamorig_RightLeg": true,
		"mixamorig_RightFoot": true,
	}
	for animation_name in player.get_animation_list():
		if not str(animation_name).begins_with("Boxing/"):
			continue
		var animation := player.get_animation(animation_name)
		for track_index in range(animation.get_track_count()):
			var path := str(animation.track_get_path(track_index))
			if not path.begins_with("Skeleton3D:"):
				continue
			var bone_name := path.get_slice(":", 1).get_slice("/", 0)
			if important_bones.has(bone_name) and not bone_names.has(bone_name):
				unresolved.append("%s -> %s" % [animation_name, path])
	_expect(unresolved.is_empty(), "Boxing animations must not reference missing important bones: %s" % [", ".join(unresolved)])


func _assert_required_boxing_animation_set(player: AnimationPlayer) -> void:
	for animation_name in [
		"Boxing/boxing_idle",
		"Boxing/step_forward",
		"Boxing/step_backward",
		"Boxing/step_left",
		"Boxing/step_right",
		"Boxing/jab",
		"Boxing/cross",
		"Boxing/left_hook",
		"Boxing/right_hook",
		"Boxing/uppercut",
		"Boxing/block_left",
		"Boxing/block_right",
		"Boxing/block_body",
		"Boxing/get_up",
	]:
		_expect(player.has_animation(animation_name), "Required boxer_02 animation must exist: %s" % animation_name)


func _assert_unarmed_support_tracks_resolve(skeleton: Skeleton3D, player: AnimationPlayer) -> void:
	for animation_name in [
		"UnarmedSupport/block",
		"UnarmedSupport/block_get_hit_1",
		"UnarmedSupport/block_get_hit_2",
		"UnarmedSupport/dodge_backward",
		"UnarmedSupport/dodge_left",
		"UnarmedSupport/dodge_right",
		"UnarmedSupport/get_hit_back",
		"UnarmedSupport/get_hit_front",
		"UnarmedSupport/get_hit_left",
		"UnarmedSupport/get_hit_right",
		"UnarmedSupport/get_up",
		"UnarmedSupport/idle_injured",
		"UnarmedSupport/knockdown",
		"UnarmedSupport/stunned",
	]:
		_expect(player.has_animation(animation_name), "Retargeted UnarmedSupport animation must exist: %s" % animation_name)
		if not player.has_animation(animation_name):
			continue
		var animation := player.get_animation(animation_name)
		_expect(animation.get_track_count() >= 20, "%s must keep the shared humanoid core tracks" % animation_name)
		for track_index in range(animation.get_track_count()):
			var path := str(animation.track_get_path(track_index))
			_expect(path.begins_with("Skeleton3D:"), "%s must target boxer_02 Skeleton3D, got %s" % [animation_name, path])
			var bone_name := path.get_slice(":", 1).get_slice("/", 0)
			_expect(bone_name != "Root", "%s must not carry Unarmed root motion tracks" % animation_name)
			_expect(not (bone_name == "Hips" and animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D), "%s must leave character translation to BoxerController" % animation_name)


func _assert_unarmed_pack_has_retargetable_humanoid_core() -> void:
	var packed := load(UNARMED_SCENE_PATH) as PackedScene
	_expect(packed != null, "Unarmed.glb must load as a PackedScene from %s" % UNARMED_SCENE_PATH)
	if packed == null:
		return
	var unarmed := packed.instantiate()
	root.add_child(unarmed)
	await process_frame
	var skeletons := unarmed.find_children("*", "Skeleton3D", true, false)
	var skeleton := skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	var player := unarmed.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	_expect(skeleton != null and skeleton.get_bone_count() >= 20, "Unarmed.glb must expose a populated Skeleton3D")
	_expect(player != null and not player.get_animation_list().is_empty(), "Unarmed.glb must expose importable animations")
	if skeleton != null:
		var required := [
			"Hips", "Spine", "Head",
			"LeftUpperArm", "LeftLowerArm", "LeftHand",
			"RightUpperArm", "RightLowerArm", "RightHand",
			"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
			"RightUpperLeg", "RightLowerLeg", "RightFoot",
		]
		var missing := PackedStringArray()
		for bone_name in required:
			if skeleton.find_bone(bone_name) < 0 and skeleton.find_bone("mixamorig_" + bone_name) < 0:
				missing.append(bone_name)
		_expect(missing.is_empty(), "Unarmed.glb must contain retargetable humanoid core bones: %s" % [", ".join(missing)])
	unarmed.queue_free()
