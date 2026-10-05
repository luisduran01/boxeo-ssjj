class_name PracticeDummy
extends Node

var mode := "passive"
var frame_data_visible := true
var buffer_visible := true
var damage_visible := true
var distance_visible := true
var guard_level := "head"
var preferred_distance := "MID_RANGE"


func configure(p_mode: String, options := {}) -> void:
	mode = p_mode if p_mode in ["passive", "block", "counter", "loop_attack"] else "passive"
	if options is Dictionary:
		guard_level = str(options.get("guard", guard_level))
		preferred_distance = str(options.get("distance", preferred_distance))


func next_response(_incoming_attack := "") -> String:
	match mode:
		"block":
			return "block"
		"counter":
			return "counter"
		"loop_attack":
			return "jab"
	return "hold"


func frame_data_snapshot(move_id: String, buffered_frames: int, damage: float, distance: String) -> Dictionary:
	return {
		"move": move_id,
		"buffered_frames": buffered_frames,
		"damage": damage,
		"distance": distance,
		"mode": mode,
		"guard": guard_level,
		"frame_data_visible": frame_data_visible,
		"buffer_visible": buffer_visible,
		"damage_visible": damage_visible,
		"distance_visible": distance_visible,
	}
