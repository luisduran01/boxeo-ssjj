extends SceneTree

const UNARMED_SCENE_PATH := "res://animations/rpg_pack/Unarmed.glb"
const BOXER_SCENE_PATH := "res://fighters/boxer_02/boxer_02.tscn"
const OUTPUT_DIR := "res://fighters/boxer_02/animations/unarmed_support"

const EXPORTS := {
	"UnarmedBlock": "unarmed_block",
	"UnarmedBlockGetHit1": "unarmed_block_get_hit_1",
	"UnarmedBlockGetHit2": "unarmed_block_get_hit_2",
	"UnarmedDodgeBackward": "unarmed_dodge_backward",
	"UnarmedDodgeLeft": "unarmed_dodge_left",
	"UnarmedDodgeRight": "unarmed_dodge_right",
	"UnarmedGetHitB1": "unarmed_get_hit_back",
	"UnarmedGetHitF1": "unarmed_get_hit_front",
	"UnarmedGetHitL1": "unarmed_get_hit_left",
	"UnarmedGetHitR1": "unarmed_get_hit_right",
	"UnarmedGetup1": "unarmed_get_up",
	"UnarmedIdleInjured": "unarmed_idle_injured",
	"UnarmedKnockdown1": "unarmed_knockdown",
	"UnarmedStunned": "unarmed_stunned",
}

const LOOPING_EXPORTS := {
	"UnarmedIdleInjured": true,
}

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _fail(message: String) -> void:
	failures += 1
	push_error("BOXER02 UNARMED EXPORT: " + message)


func _run() -> void:
	var unarmed_packed := load(UNARMED_SCENE_PATH) as PackedScene
	var boxer_packed := load(BOXER_SCENE_PATH) as PackedScene
	if unarmed_packed == null:
		_fail("Could not load %s" % UNARMED_SCENE_PATH)
	if boxer_packed == null:
		_fail("Could not load %s" % BOXER_SCENE_PATH)
	if failures > 0:
		quit(1)
		return

	var unarmed := unarmed_packed.instantiate()
	var boxer := boxer_packed.instantiate()
	root.add_child(unarmed)
	root.add_child(boxer)
	await process_frame

	var unarmed_player := unarmed.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	var boxer_skeleton := boxer.get_node_or_null("boxer_02/GeneralSkeleton") as Skeleton3D
	if unarmed_player == null:
		_fail("Unarmed pack has no AnimationPlayer")
	if boxer_skeleton == null:
		_fail("boxer_02 has no GeneralSkeleton")
	if failures > 0:
		quit(1)
		return

	var allowed_bones := _collect_bones(boxer_skeleton)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	for source_name in EXPORTS.keys():
		if not unarmed_player.has_animation(source_name):
			_fail("Missing Unarmed animation: %s" % source_name)
			continue
		var exported := _retarget_animation(unarmed_player.get_animation(source_name), allowed_bones)
		exported.loop_mode = Animation.LOOP_LINEAR if LOOPING_EXPORTS.has(source_name) else Animation.LOOP_NONE
		var target_path := "%s/%s.res" % [OUTPUT_DIR, EXPORTS[source_name]]
		var error := ResourceSaver.save(exported, target_path)
		if error != OK:
			_fail("Could not save %s error=%d" % [target_path, error])
		else:
			print("EXPORTED %s -> %s tracks=%d" % [source_name, target_path, exported.get_track_count()])

	unarmed.queue_free()
	boxer.queue_free()
	if failures == 0:
		print("BOXER02 UNARMED EXPORT PASSED")
		quit(0)
	else:
		quit(1)


func _collect_bones(skeleton: Skeleton3D) -> Dictionary:
	var bones := {}
	for bone_index in range(skeleton.get_bone_count()):
		bones[skeleton.get_bone_name(bone_index)] = true
	return bones


func _retarget_animation(source: Animation, allowed_bones: Dictionary) -> Animation:
	var animation := source.duplicate(true) as Animation
	var track_index := animation.get_track_count() - 1
	while track_index >= 0:
		var path := str(animation.track_get_path(track_index))
		if path.begins_with("%GeneralSkeleton:"):
			path = path.replace("%GeneralSkeleton:", "Skeleton3D:")
			animation.track_set_path(track_index, NodePath(path))
		elif path.begins_with("Armature/GeneralSkeleton:"):
			path = path.replace("Armature/GeneralSkeleton:", "Skeleton3D:")
			animation.track_set_path(track_index, NodePath(path))
		elif path.begins_with("Skeleton3D:"):
			pass
		else:
			animation.remove_track(track_index)
			track_index -= 1
			continue

		var bone_name := path.get_slice(":", 1).get_slice("/", 0)
		if bone_name == "Root" or not allowed_bones.has(bone_name):
			animation.remove_track(track_index)
		elif bone_name == "Hips" and animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D:
			animation.remove_track(track_index)
		track_index -= 1
	return animation
