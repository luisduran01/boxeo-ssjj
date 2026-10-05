class_name ManualAnimationDriver
extends RefCounted

var anim_tree: Object
var tick_seconds := 1.0 / 60.0


func bind_tree(tree: Object) -> void:
	anim_tree = tree
	if anim_tree == null:
		return
	anim_tree.set("callback_mode_process", AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL)
	if anim_tree.has_method("advance"):
		anim_tree.call("advance", 0.0)


func apply_state(state: Dictionary) -> void:
	if anim_tree == null:
		return
	_set_parameter(&"parameters/stamina/blend_amount", float(state.get("stamina", 100.0)) / 100.0)
	_set_parameter(&"parameters/look_at/weight", look_at_weight_for_state(state))
	if int(state.get("hitstop", 0)) <= 0 and anim_tree.has_method("advance"):
		anim_tree.call("advance", tick_seconds)


func look_at_weight_for_state(state: Dictionary) -> float:
	match str(state.get("phase", "NEUTRAL")).to_upper():
		"WOBBLE", "WOBBLED":
			return 0.2
		"KNOCKDOWN", "DOWN":
			return 0.0
	return 0.6


func _set_parameter(path: StringName, value: Variant) -> void:
	if anim_tree == null:
		return
	if anim_tree.has_method("set_param"):
		anim_tree.call("set_param", path, value)
	else:
		anim_tree.set(path, value)
