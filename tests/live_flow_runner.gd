extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("LIVE FLOW: " + message)


func _load_fight() -> Node:
	change_scene_to_file("res://fight/fight.tscn")
	await process_frame
	await process_frame
	return current_scene


func _wait_for_state(manager: FightManager, expected: int, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while manager.state != expected:
		if Time.get_ticks_msec() - started >= timeout_ms: return false
		await process_frame
	return true


func _wait_for_recovery(fight, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while fight.player._knocked_down or fight.manager.state != FightManager.State.FIGHTING:
		if Time.get_ticks_msec() - started >= timeout_ms: return false
		await process_frame
	return true


func _run() -> void:
	Engine.time_scale = 12.0
	SaveSystem.session = {"mode": "sparring", "rounds": 2, "round_duration": 0.25, "player_scene": "res://fighters/boxer_green/boxer_green.tscn", "enemy_scene": "res://fighters/boxer_green/boxer_green.tscn"}
	var fight = await _load_fight()
	await _wait_for_state(fight.manager, FightManager.State.FIGHT_END, 5000)
	_expect(fight.manager.scores.size() == 2, "two live round timers must produce two scores")
	_expect(fight.manager.state == FightManager.State.FIGHT_END, "final live round must end by decision")
	_expect(fight.hud.banner.text.contains("DECISIÓN"), "decision result must be shown")
	SaveSystem.session = {"mode": "sparring", "rounds": 3, "round_duration": 120.0, "player_scene": "res://fighters/boxer_green/boxer_green.tscn", "enemy_scene": "res://fighters/boxer_green/boxer_green.tscn"}
	fight = await _load_fight()
	await _wait_for_state(fight.manager, FightManager.State.FIGHTING, 4000)
	fight.player.stats.stamina = 100.0
	fight.manager._on_knockdown(fight.player)
	await _wait_for_recovery(fight, 4000)
	_expect(not fight.player._knocked_down and fight.manager.state == FightManager.State.FIGHTING, "live count must let first knockdown get up")
	fight.player.knockdowns = 2
	fight.manager._knockdown_in_progress = false
	fight.manager.state = FightManager.State.FIGHTING
	fight.manager._on_knockdown(fight.player)
	await _wait_for_state(fight.manager, FightManager.State.FIGHT_END, 4000)
	_expect(fight.manager.state == FightManager.State.FIGHT_END and fight.hud.banner.text.contains("TKO"), "live third knockdown must end by TKO")
	Engine.time_scale = 1.0
	if failures == 0:
		print("LIVE FLOW TESTS PASSED")
		quit(0)
	else:
		push_error("LIVE FLOW TESTS FAILED: %d" % failures)
		quit(1)
