extends SceneTree

const FIGHTERS := {
	"boxer_01": "res://fighters/boxer_green/boxer_green.tscn",
	"boxer_02": "res://fighters/boxer_02/boxer_02.tscn",
	"boxer_03": "res://fighters/boxer_03/boxer_03.tscn",
}
const REQUIRED_BOXING := [
	"boxing_idle",
	"step_forward",
	"step_backward",
	"step_left",
	"step_right",
	"jab",
	"cross",
	"left_hook",
	"right_hook",
	"uppercut",
	"block_left",
	"block_right",
	"block_body",
	"hit_reaction",
	"get_up",
]
const REQUIRED_UNARMED := [
	"block",
	"block_get_hit_1",
	"block_get_hit_2",
	"dodge_backward",
	"dodge_left",
	"dodge_right",
	"get_hit_back",
	"get_hit_front",
	"get_hit_left",
	"get_hit_right",
	"get_up",
	"idle_injured",
	"knockdown",
	"stunned",
]

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FIGHTER ANIMATION RUNTIME: " + message)


func _run() -> void:
	for fighter_id in FIGHTERS:
		await _assert_fighter_runtime(fighter_id, FIGHTERS[fighter_id])
	if failures == 0:
		print("FIGHTER ANIMATION RUNTIME TESTS PASSED")
		quit(0)
	else:
		push_error("FIGHTER ANIMATION RUNTIME TESTS FAILED: %d" % failures)
		quit(1)


func _assert_fighter_runtime(fighter_id: String, scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "%s scene must load" % fighter_id)
	if packed == null:
		return
	var fighter := packed.instantiate()
	root.add_child(fighter)
	await process_frame
	var player := fighter.get_node_or_null(fighter.animation_player_path) as AnimationPlayer
	var skeleton := fighter.get_node_or_null(fighter.skeleton_path) as Skeleton3D
	var tree := fighter.get_node_or_null("AnimationTree") as AnimationTree
	_expect(player != null, "%s AnimationPlayer path must resolve" % fighter_id)
	_expect(skeleton != null and skeleton.get_bone_count() >= 20, "%s Skeleton3D path must resolve" % fighter_id)
	_expect(tree != null and tree.tree_root is AnimationNodeStateMachine, "%s AnimationTree must use a state machine" % fighter_id)
	if player == null or skeleton == null or tree == null:
		fighter.queue_free()
		return
	_assert_animation_set(fighter_id, player)
	tree.active = true
	var playback := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_expect(playback != null, "%s AnimationTree playback must exist" % fighter_id)
	if playback != null:
		playback.travel("Footwork")
	tree.set("parameters/Footwork/blend_position", Vector2.ZERO)
	await _process_animation_frames(10)
	var idle_pose := _hand_pose_sample(skeleton)
	player.play("Boxing/jab")
	player.advance(0.18)
	skeleton.force_update_all_bone_transforms()
	var jab_delta := _pose_delta(idle_pose, _hand_pose_sample(skeleton))
	_expect(jab_delta > 0.05, "%s Boxing tracks must move the real Skeleton3D, delta %.3f" % [fighter_id, jab_delta])
	fighter.fight_enabled = true
	fighter.request_attack("jab")
	await _process_animation_frames(5)
	_expect(player.is_playing() and player.current_animation == "Boxing/jab", "%s jab must play through AnimationPlayer" % fighter_id)
	fighter.request_defense("slip_left")
	await _process_animation_frames(3)
	fighter._play_reaction_animation("UnarmedSupport/stunned")
	await _process_animation_frames(3)
	_expect(player.current_animation == "UnarmedSupport/stunned", "%s stun must play from UnarmedSupport" % fighter_id)
	player.advance(0.20)
	skeleton.force_update_all_bone_transforms()
	var stunned_delta := _pose_delta(idle_pose, _hand_pose_sample(skeleton))
	_expect(stunned_delta > 0.05, "%s UnarmedSupport tracks must move the real Skeleton3D, delta %.3f" % [fighter_id, stunned_delta])
	fighter.queue_free()


func _assert_animation_set(fighter_id: String, player: AnimationPlayer) -> void:
	_expect(player.has_animation_library("Boxing"), "%s must expose Boxing library" % fighter_id)
	_expect(player.has_animation_library("UnarmedSupport"), "%s must expose UnarmedSupport library" % fighter_id)
	for animation_name in REQUIRED_BOXING:
		_expect(player.has_animation("Boxing/" + animation_name), "%s missing Boxing/%s" % [fighter_id, animation_name])
	for animation_name in REQUIRED_UNARMED:
		_expect(player.has_animation("UnarmedSupport/" + animation_name), "%s missing UnarmedSupport/%s" % [fighter_id, animation_name])


func _process_animation_frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _hand_pose_sample(skeleton: Skeleton3D) -> Dictionary:
	var left := skeleton.find_bone("mixamorig_LeftHand")
	var right := skeleton.find_bone("mixamorig_RightHand")
	return {
		"left": skeleton.get_bone_global_pose(left).origin if left >= 0 else Vector3.ZERO,
		"right": skeleton.get_bone_global_pose(right).origin if right >= 0 else Vector3.ZERO,
	}


func _pose_delta(before: Dictionary, after: Dictionary) -> float:
	return (before.left as Vector3).distance_to(after.left) + (before.right as Vector3).distance_to(after.right)
