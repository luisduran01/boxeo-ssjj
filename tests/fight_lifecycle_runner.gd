extends SceneTree

const FIGHT_SCENE := preload("res://scripts/fight/fight_scene.gd")
const Judges := preload("res://scripts/managers/judges.gd")

var failures := 0
var fight: Node


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FIGHT LIFECYCLE: " + message)


func _run() -> void:
	await _spawn_fight({"mode": "sparring", "rounds": 1, "round_duration": 0.12, "selected_player": "fighter_1", "selected_opponent": "fighter_2"})
	await create_timer(2.1).timeout
	_test_short_forced_round_reaches_decision()
	await _spawn_fight({"mode": "sparring", "rounds": 2, "round_duration": 1.0, "selected_player": "fighter_1", "selected_opponent": "fighter_2"})
	await create_timer(0.35).timeout
	_test_end_round_is_idempotent()
	await _spawn_fight({"mode": "sparring", "rounds": 3, "round_duration": 60.0, "selected_player": "fighter_1", "selected_opponent": "fighter_2"})
	await create_timer(0.35).timeout
	await _test_first_knockdown_recovers()
	await _spawn_fight({"mode": "sparring", "rounds": 3, "round_duration": 60.0, "selected_player": "fighter_1", "selected_opponent": "fighter_2"})
	await create_timer(0.35).timeout
	await _test_tko_limit_finishes_cleanly()
	_test_majority_decisions_are_named()
	_test_fight_end_restores_time_scale()
	if failures > 0:
		push_error("FIGHT LIFECYCLE TESTS FAILED: %d" % failures)
		quit(1)
	else:
		print("FIGHT LIFECYCLE TESTS PASSED")
		quit(0)


func _spawn_fight(session: Dictionary) -> void:
	if is_instance_valid(fight):
		fight.queue_free()
		await process_frame
	SaveSystem.load_all()
	SaveSystem.session = session
	fight = FIGHT_SCENE.new()
	get_root().add_child(fight)
	await process_frame


func _test_short_forced_round_reaches_decision() -> void:
	_expect(fight.manager.state == FightManager.State.FIGHT_END, "one forced short Quick Fight must reach FIGHT_END")
	_expect(str(fight.manager.result.get("method", "")) != "", "finished Quick Fight must include a result method")
	_expect(fight.manager.result.has("scorecards"), "finished Quick Fight must include scorecards")
	_expect(fight.manager.result.has("stats"), "finished Quick Fight must include stats")


func _test_end_round_is_idempotent() -> void:
	fight.manager.state = FightManager.State.FIGHTING
	fight.manager.current_round = 1
	fight.manager.round_manager.configure(2, 0.1, 0.05)
	fight.manager.round_manager.current_round = 1
	fight.manager.round_manager.round_time = 0.0
	fight.manager.fight_stats.reset(fight.player, fight.enemy)
	fight.manager.fight_stats.start_round(1)
	fight.manager.fight_stats.record_punch_thrown(fight.player, "jab")
	fight.manager.fight_stats.record_punch_landed(fight.player, fight.enemy, "jab", {"damage": 8.0, "zone": "head_center", "counter": false, "blocked": false})
	fight.manager._end_round()
	fight.manager._end_round()
	_expect(fight.manager.scores.size() == 1, "duplicate _end_round calls must record one legacy score")
	_expect(fight.manager.judges.scorecards[0].rounds.size() == 1, "duplicate _end_round calls must score one judge round")


func _test_first_knockdown_recovers() -> void:
	fight.manager.state = FightManager.State.FIGHTING
	fight.manager._knockdown_in_progress = false
	fight.player.knockdowns = 0
	fight.player.stats.stamina = 100.0
	fight.player.fight_enabled = true
	fight.enemy.fight_enabled = true
	fight.manager._on_knockdown(fight.player)
	await create_timer(7.2).timeout
	_expect(fight.manager.state == FightManager.State.FIGHTING, "first knockdown with stamina must resume fighting")
	_expect(fight.player.fight_enabled and fight.enemy.fight_enabled, "both fighters must be enabled after get-up")
	_expect(not fight.manager._knockdown_in_progress, "knockdown flag must clear after get-up")


func _test_tko_limit_finishes_cleanly() -> void:
	fight.manager.state = FightManager.State.FIGHTING
	fight.manager._knockdown_in_progress = false
	fight.player.knockdowns = fight.manager.tko_knockdown_limit - 1
	fight.player.stats.stamina = 100.0
	fight.manager._on_knockdown(fight.player)
	await create_timer(1.0).timeout
	_expect(fight.manager.state == FightManager.State.FIGHT_END, "configured knockdown limit must end the fight")
	_expect(fight.manager.result.get("method", "") == "TKO", "configured knockdown limit must end by TKO")
	_expect(not fight.manager._knockdown_in_progress, "knockdown flag must clear after TKO")


func _test_majority_decisions_are_named() -> void:
	var judges := Judges.new()
	var majority := judges.decide(fight.player, fight.enemy, [
		{"player": 30, "enemy": 28},
		{"player": 29, "enemy": 29},
		{"player": 30, "enemy": 28},
	])
	_expect(majority.method == "Majority Decision" and majority.winner == fight.player, "two winning cards plus one draw must produce Majority Decision")
	var majority_draw := judges.decide(fight.player, fight.enemy, [
		{"player": 29, "enemy": 29},
		{"player": 30, "enemy": 28},
		{"player": 28, "enemy": 30},
	])
	_expect(majority_draw.method == "Majority Draw" and majority_draw.winner == null, "one card each way plus one draw must produce Majority Draw")
	judges.free()


func _test_fight_end_restores_time_scale() -> void:
	Engine.time_scale = 0.38
	fight.manager._end_fight(fight.enemy, "KO")
	_expect(Engine.time_scale == 1.0, "fight end must restore Engine.time_scale")
