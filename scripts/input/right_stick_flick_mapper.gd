class_name RightStickFlickMapper
extends RefCounted

var deadzone := 0.42
var tolerance := 0.18
var _stick := Vector2.ZERO


func attack_for_event(event: InputEvent, body_modifier := false) -> String:
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_RIGHT_X:
			_stick.x = motion.axis_value
		elif motion.axis == JOY_AXIS_RIGHT_Y:
			_stick.y = motion.axis_value
		else:
			return ""
		return attack_for_vector(_stick, body_modifier)
	return ""


func attack_for_vector(direction: Vector2, body_modifier := false) -> String:
	if direction.length() < deadzone:
		return ""
	var normalized := direction.normalized()
	var attack := ""
	if normalized.x > 1.0 - tolerance:
		attack = "cross"
	elif normalized.x < -1.0 + tolerance:
		attack = "left_hook"
	elif normalized.y < -1.0 + tolerance:
		attack = "jab"
	elif normalized.y > 1.0 - tolerance:
		attack = "uppercut"
	else:
		attack = "right_hook" if normalized.x > 0.0 else "left_hook"
	if body_modifier and attack in ["jab", "cross", "left_hook", "right_hook", "uppercut"]:
		return attack + "_body"
	return attack


func reset() -> void:
	_stick = Vector2.ZERO
