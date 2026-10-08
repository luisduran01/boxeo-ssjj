extends SceneTree

var fight
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	SaveSystem.session = {"mode":"sparring", "rounds":3, "round_duration":120.0, "selected_player":"fighter_1", "selected_opponent":"fighter_2"}
	change_scene_to_file("res://fight/fight.tscn")
	await process_frame
	await process_frame
	fight = current_scene
	while not is_instance_valid(fight.manager) or fight.manager.state != FightManager.State.FIGHTING or not fight.player.fight_enabled:
		await process_frame
	fight.enemy.fight_enabled = false
	for index in range(20):
		var result := await _run_one(index + 1)
		print("JAB_CYCLE #%02d instance=%d phases=%s durations=%s final=%s cancel=%s" % [index + 1, result.instance, result.phases, result.durations, result.final_state, result.cancel])
		if not result.complete: failures += 1
	if failures == 0:
		print("JAB CYCLES: 20/20 PASS")
		quit(0)
	else:
		push_error("JAB CYCLES FAILED: %d/20" % failures)
		quit(1)

func _run_one(number: int) -> Dictionary:
	while fight.player.combat_state != "IDLE" or fight.player._current_attack != "":
		await physics_frame
	# Keep the cycle test independent of resource depletion; this does not change combat rules.
	fight.player.stats.stamina = fight.player.stats.max_stamina
	fight.player.request_attack("jab")
	var instance := int(fight.player._attack_instance_id)
	var phases: Array[String] = []
	var phase_ticks := {}
	var cancel := ""
	var started := false
	for tick in range(120):
		await physics_frame
		var state := str(fight.player.combat_state)
		if state in ["STARTUP", "ACTIVE", "RECOVERY"]:
			started = true
			if not phases.has(state): phases.append(state); phase_ticks[state] = tick
		if state == "IDLE" and started:
			phases.append("IDLE")
			phase_ticks.IDLE = tick
			break
		if state in ["WOBBLED", "STUNNED", "BLOCK_HIT", "GUARD_BREAK", "KNOCKDOWN"]:
			cancel = state
			break
	var complete := phases == ["STARTUP", "ACTIVE", "RECOVERY", "IDLE"]
	var durations := {}
	for phase in ["STARTUP", "ACTIVE", "RECOVERY"]:
		if phase_ticks.has(phase):
			var next_phase := "ACTIVE" if phase == "STARTUP" else ("RECOVERY" if phase == "ACTIVE" else "IDLE")
			durations[phase] = int(phase_ticks.get(next_phase, phase_ticks[phase])) - int(phase_ticks[phase])
	return {"instance":instance,"phases":phases,"durations":durations,"final_state":str(fight.player.combat_state),"cancel":cancel,"complete":complete}
