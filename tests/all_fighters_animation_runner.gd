extends SceneTree

const FIGHTER_SCENES := [
	"res://fighters/boxer_green/boxer_green.tscn",
	"res://fighters/boxer_02/boxer_02.tscn",
	"res://fighters/boxer_03/boxer_03.tscn",
]

const REQUIRED_BOXING_ANIMATIONS := [
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
	"get_up",
]

const SHARED_SCRIPT_PATH := "res://fighters/shared/boxer_controller.gd"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("ALL FIGHTERS ANIMATION: " + message)


func _run() -> void:
	for scene_path in FIGHTER_SCENES:
		await _assert_fighter_scene(scene_path)
	if failures > 0:
		push_error("ALL FIGHTERS ANIMATION TESTS FAILED: %d" % failures)
		quit(1)
	else:
		print("ALL FIGHTERS ANIMATION TESTS PASSED")
		quit(0)


func _assert_fighter_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "%s must load as PackedScene" % scene_path)
	if packed == null:
		return
	var boxer := packed.instantiate()
	root.add_child(boxer)
	await process_frame
	_expect(boxer is BoxerController, "%s root must be BoxerController" % scene_path)
	var script := boxer.get_script() as Script
	_expect(script != null and script.resource_path == SHARED_SCRIPT_PATH, "%s must use shared controller script" % scene_path)
	var skeleton := boxer.get_node_or_null(boxer.skeleton_path) as Skeleton3D
	_expect(skeleton != null and skeleton.get_bone_count() >= 20, "%s skeleton_path must resolve to a populated Skeleton3D" % scene_path)
	var player := boxer.get_node_or_null(boxer.animation_player_path) as AnimationPlayer
	_expect(player != null, "%s animation_player_path must resolve to AnimationPlayer" % scene_path)
	if player != null:
		_expect(player.has_animation_library("Boxing"), "%s must expose Boxing library" % scene_path)
		_expect(player.has_animation_library("UnarmedSupport"), "%s must expose UnarmedSupport library" % scene_path)
		for animation_name in REQUIRED_BOXING_ANIMATIONS:
			_expect(player.has_animation("Boxing/" + animation_name), "%s missing Boxing/%s" % [scene_path, animation_name])
	var tree := boxer.get_node_or_null("AnimationTree") as AnimationTree
	_expect(tree != null and tree.active, "%s AnimationTree must be active after _ready" % scene_path)
	if tree != null:
		var playback := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		var current_node := StringName("")
		if playback != null:
			current_node = playback.get_current_node()
		_expect(playback != null and current_node == &"Footwork", "%s must start in Footwork, got %s" % [scene_path, current_node])
	boxer.queue_free()
	await process_frame
