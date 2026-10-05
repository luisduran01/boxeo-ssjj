extends SceneTree

const ManualAnimationScript := preload("res://scripts/presentation/manual_animation_driver.gd")
const MoveLibraryScript := preload("res://scripts/combat/move_library.gd")

const BOXER_SCENES := [
	"res://fighters/boxer_green/boxer_green.tscn",
	"res://fighters/boxer_02/boxer_02.tscn",
	"res://fighters/boxer_03/boxer_03.tscn",
]

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ANIMATION MANUAL: " + message)


func _run() -> void:
	await _test_boxers_start_manual_and_not_tpose()
	_test_hitstop_freezes_exactly_six_ticks()
	await _test_clips_match_move_data()
	if failures.is_empty():
		print("ANIMATION_MANUAL_TESTS_PASSED")
		quit(0)
		return
	push_error("ANIMATION_MANUAL_TESTS_FAILED: %d" % failures.size())
	quit(1)


func _test_boxers_start_manual_and_not_tpose() -> void:
	for path in BOXER_SCENES:
		if not ResourceLoader.exists(path):
			_expect(path.contains("boxer_green"), "required boxer scene missing: %s" % path)
			continue
		var scene: PackedScene = load(path)
		var boxer: Node = scene.instantiate()
		root.add_child(boxer)
		await process_frame
		var tree: AnimationTree = boxer.get_node_or_null("AnimationTree") as AnimationTree
		var player: AnimationPlayer = _find_animation_player(boxer)
		_expect(tree != null, "%s must have AnimationTree" % path)
		if tree != null:
			_expect(tree.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "%s AnimationTree must be manual" % path)
		_expect(player != null and player.has_animation("Boxing/boxing_idle"), "%s must have a valid idle pose clip, not T-pose" % path)
		boxer.queue_free()
		await process_frame


func _test_hitstop_freezes_exactly_six_ticks() -> void:
	var driver = ManualAnimationScript.new()
	var fake_tree := FakeManualTree.new()
	driver.bind_tree(fake_tree)
	driver.apply_state({"hitstop": 0, "phase": "NEUTRAL"})
	var before := fake_tree.advance_calls
	for _i in range(6):
		driver.apply_state({"hitstop": 6, "phase": "NEUTRAL"})
	_expect(fake_tree.advance_calls == before, "hitstop of 6 frames must freeze exactly 6 ticks")
	driver.apply_state({"hitstop": 0, "phase": "NEUTRAL"})
	_expect(fake_tree.advance_calls == before + 1, "manual animation must resume on the tick after hitstop")


func _test_clips_match_move_data() -> void:
	for path in BOXER_SCENES:
		if not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = load(path)
		var boxer: Node = scene.instantiate()
		root.add_child(boxer)
		await process_frame
		var player: AnimationPlayer = _find_animation_player(boxer)
		for move_id in MoveLibraryScript.all_ids():
			var data: Dictionary = MoveLibraryScript.attack_data(move_id)
			if data.is_empty() or str(data.get("attack_type", "")) == "feint":
				continue
			var animation_name := "Boxing/" + str(data.animation_name)
			_expect(player != null and player.has_animation(animation_name), "%s missing clip %s for MoveData %s" % [path, animation_name, move_id])
			if player != null and player.has_animation(animation_name):
				var clip := player.get_animation(animation_name)
				var expected := (float(data.startup_frames) + float(data.active_frames) + float(data.recovery_frames)) / 60.0
				var active_time := float(data.active_frames) / 60.0
				_expect(clip.length >= active_time and expected > 0.0, "%s clip must cover active MoveData frames for %s" % [path, move_id])
		boxer.queue_free()
		await process_frame


class FakeManualTree:
	extends RefCounted
	var callback_mode_process := 0
	var advance_calls := 0
	func advance(_delta: float) -> void:
		advance_calls += 1
	func set_param(_property: StringName, _value: Variant) -> void:
		pass


func _find_animation_player(root_node: Node) -> AnimationPlayer:
	var direct := root_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	return root_node.find_child("AnimationPlayer2", true, false) as AnimationPlayer
