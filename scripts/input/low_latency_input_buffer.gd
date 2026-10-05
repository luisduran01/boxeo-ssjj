class_name LowLatencyInputBuffer
extends RefCounted

const ACTION_BITS := {
	&"jab": 1,
	&"cross": 2,
	&"left_hook": 4,
	&"right_hook": 8,
	&"uppercut": 16,
	&"body_modifier": 32,
}

var max_frames := 8
var max_events := 2048
var _entries: Array[Dictionary] = []
var _last_consumed_latency := 0


func _init() -> void:
	Input.use_accumulated_input = false


func capture_event(event: InputEvent, physics_frame: int) -> void:
	var bit := action_to_bit(event)
	if bit == 0:
		return
	_entries.append({"frame": physics_frame, "bit": bit})
	while _entries.size() > max_events:
		_entries.pop_front()


func consume_bits_for_frame(physics_frame: int) -> int:
	var bits := 0
	var remaining: Array[Dictionary] = []
	_last_consumed_latency = 0
	for entry in _entries:
		if int(entry.frame) <= physics_frame:
			bits |= int(entry.bit)
			_last_consumed_latency = maxi(_last_consumed_latency, physics_frame - int(entry.frame))
		else:
			remaining.append(entry)
	_entries = remaining
	return bits


func logical_latency_frames(_physics_frame: int) -> int:
	return _last_consumed_latency


func actions_from_bits(bits: int) -> Array[StringName]:
	var actions: Array[StringName] = []
	for action in ACTION_BITS.keys():
		if bits & int(ACTION_BITS[action]) != 0:
			actions.append(action)
	return actions


func action_to_bit(event: InputEvent) -> int:
	if event == null or not event.is_pressed():
		return 0
	if event is InputEventAction:
		return int(ACTION_BITS.get((event as InputEventAction).action, 0))
	for action in ACTION_BITS.keys():
		if event.is_action_pressed(action):
			return int(ACTION_BITS[action])
	return 0
