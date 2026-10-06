extends SceneTree

const PhasePlan := preload("res://scripts/managers/combat_phase_plan.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("THREE PHASE PLAN: " + message)


func _run() -> void:
	_test_phase_contract()
	_test_phase_lookup_and_telemetry_ids()
	_test_fight_manager_uses_phase_telemetry_id()
	if failures.is_empty():
		print("THREE_PHASE_PLAN_TESTS_PASSED")
		quit(0)
		return
	push_error("THREE_PHASE_PLAN_TESTS_FAILED: %d" % failures.size())
	quit(1)


func _test_phase_contract() -> void:
	var phases := PhasePlan.all_phases()
	_expect(phases.size() == 3, "implementation plan must expose exactly three phases")
	for index in range(phases.size()):
		var phase: Dictionary = phases[index]
		_expect(int(phase.get("phase", 0)) == index + 1, "phase numbers must be sequential")
		_expect(str(phase.get("name", "")) != "", "phase must expose a name")
		_expect(str(phase.get("telemetry_id", "")) != "", "phase must expose a telemetry id")
		_expect(Array(phase.get("required_runners", [])).size() >= 3, "phase must define at least three required runners")
		_expect(Array(phase.get("exit_criteria", [])).size() >= 3, "phase must define exit criteria")


func _test_phase_lookup_and_telemetry_ids() -> void:
	_expect(PhasePlan.telemetry_id_for_phase(1) == "phase_1_base_jugable", "phase 1 telemetry id must be stable")
	_expect(PhasePlan.telemetry_id_for_phase(2) == "phase_2_combate_maestro", "phase 2 telemetry id must be stable")
	_expect(PhasePlan.telemetry_id_for_phase(3) == "phase_3_produccion_final", "phase 3 telemetry id must be stable")
	_expect(PhasePlan.phase_for_runner("res://tests/fight_lifecycle_runner.gd") == 1, "fight lifecycle runner belongs to phase 1")
	_expect(PhasePlan.phase_for_runner("res://tests/technical_combat_runner.gd") == 2, "technical combat runner belongs to phase 2")
	_expect(PhasePlan.phase_for_runner("res://tests/settings_application_runner.gd") == 3, "settings runner belongs to phase 3")


func _test_fight_manager_uses_phase_telemetry_id() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/managers/fight_manager.gd")
	_expect(source.contains("CombatPhasePlan.telemetry_id_for_phase(1)"), "FightManager must start telemetry with the phase 1 id")
