extends SceneTree

const BufferScript := preload("res://scripts/input/low_latency_input_buffer.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("INPUT LATENCY: " + message)


func _run() -> void:
	_test_sequences_at_3_6_and_10_frames()
	_test_1000_synthetic_events_latency()
	if failures.is_empty():
		print("INPUT_LATENCY_TESTS_PASSED")
		quit(0)
		return
	push_error("INPUT_LATENCY_TESTS_FAILED: %d" % failures.size())
	quit(1)


func _test_sequences_at_3_6_and_10_frames() -> void:
	for gap in [3, 6, 10]:
		var buffer = BufferScript.new()
		_push_action(buffer, &"jab", 100)
		_push_action(buffer, &"cross", 100 + gap)
		_push_action(buffer, &"left_hook", 100 + gap * 2)
		var sequence: Array[StringName] = []
		for frame in range(100, 100 + gap * 2 + 4):
			var bits: int = buffer.consume_bits_for_frame(frame)
			for action in buffer.actions_from_bits(bits):
				sequence.append(action)
			_expect(buffer.logical_latency_frames(frame) <= 3, "logical latency must stay <= 3 frames for %d frame gap" % gap)
		_expect(sequence == [&"jab", &"cross", &"left_hook"], "jab-cross-hook sequence must survive %d frame spacing" % gap)


func _test_1000_synthetic_events_latency() -> void:
	var buffer = BufferScript.new()
	for i in range(1000):
		_push_action(buffer, [&"jab", &"cross", &"left_hook"][i % 3], i)
	var consumed := 0
	var max_latency := 0
	for frame in range(1003):
		var bits: int = buffer.consume_bits_for_frame(frame)
		if bits != 0:
			consumed += buffer.actions_from_bits(bits).size()
			max_latency = maxi(max_latency, buffer.logical_latency_frames(frame))
	_expect(consumed == 1000, "all 1000 synthetic events must be consumed")
	_expect(max_latency <= 3, "1000 synthetic events must keep logical latency <= 3 frames")


func _push_action(buffer: RefCounted, action: StringName, frame: int) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	buffer.capture_event(event, frame)
