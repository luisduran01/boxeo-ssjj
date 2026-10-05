extends SceneTree

const TelemetryScript := preload("res://scripts/managers/fight_telemetry.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("TELEMETRY: " + message)


func _run() -> void:
	var telemetry := TelemetryScript.new()
	root.add_child(telemetry)
	telemetry.start_fight("test_phase")
	var attacker := Node.new()
	attacker.name = "Attacker"
	var defender := Node.new()
	defender.name = "Defender"
	root.add_child(attacker)
	root.add_child(defender)
	var events := root.get_node("/root/Events")
	events.emit_signal("round_started", 1)
	events.emit_signal("punch_thrown", attacker, "jab")
	events.emit_signal("punch_landed", attacker, defender, {"attack_name": "jab", "damage": 6.0, "blocked": false, "zone": "head"})
	events.emit_signal("punch_blocked", attacker, defender, {"attack_name": "cross", "blocked": true})
	events.emit_signal("punch_missed", attacker, "left_hook")
	events.emit_signal("knockdown_started", defender, attacker)
	var path := telemetry.finish_fight({"method": "TEST"})
	_expect(FileAccess.file_exists(path), "finish_fight must write a telemetry CSV")
	var csv := FileAccess.get_file_as_string(path)
	_expect(csv.contains("version_id"), "CSV must include version_id")
	_expect(csv.contains("punches_thrown"), "CSV must include punches_thrown")
	_expect(csv.contains("punches_landed"), "CSV must include punches_landed")
	_expect(csv.contains("punches_blocked"), "CSV must include punches_blocked")
	_expect(csv.contains("punches_missed"), "CSV must include punches_missed")
	_expect(csv.contains("knockdowns"), "CSV must include knockdowns")
	attacker.queue_free()
	defender.queue_free()
	telemetry.queue_free()
	if failures.is_empty():
		print("TELEMETRY_TESTS_PASSED")
		quit(0)
	else:
		push_error("TELEMETRY_TESTS_FAILED: %d" % failures.size())
		quit(1)
