extends SceneTree

const FIGHT_SCENE := preload("res://scripts/fight/fight_scene.gd")
const FightStats := preload("res://scripts/managers/fight_stats.gd")
const Judges := preload("res://scripts/managers/judges.gd")
const RoundManager := preload("res://scripts/managers/round_manager.gd")

var failures := 0
var fight: Node


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FIGHT SYSTEM: " + message)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveSystem.settings.rounds = 3
	SaveSystem.settings.round_duration = 60
	SaveSystem.session = {"mode": "sparring", "rounds": 3, "round_duration": 0.2, "selected_player": "fighter_1", "selected_opponent": "fighter_2"}
	fight = FIGHT_SCENE.new()
	get_root().add_child(fight)
	await process_frame
	await create_timer(1.35).timeout
	_test_managers_are_connected()
	_test_stats_capture_thrown_landed_defense_and_accuracy()
	_test_rounds_pause_combat_and_score_judges()
	_test_decision_types()
	_test_knockdown_count_ko_tko_rules()
	_test_quick_fight_reaches_result()
	if failures > 0:
		push_error("FIGHT SYSTEM TESTS FAILED: %d" % failures)
		quit(1)
	else:
		print("FIGHT SYSTEM TESTS PASSED")
		quit(0)


func _test_managers_are_connected() -> void:
	_expect(fight.manager.round_manager is RoundManager, "FightManager must own RoundManager")
	_expect(fight.manager.fight_stats is FightStats, "FightManager must own FightStats")
	_expect(fight.manager.judges is Judges, "FightManager must own Judges")
	_expect(fight.manager.has_signal("fight_finished"), "FightManager must expose fight_finished signal")
	_expect(fight.manager.has_signal("round_started"), "FightManager must expose round_started signal")
	_expect(fight.player.has_signal("punch_thrown"), "BoxerController must emit punch_thrown for stats")


func _test_stats_capture_thrown_landed_defense_and_accuracy() -> void:
	var stats: FightStats = fight.manager.fight_stats
	stats.reset(fight.player, fight.enemy)
	stats.record_punch_thrown(fight.player, "jab")
	stats.record_punch_thrown(fight.player, "cross")
	stats.record_punch_landed(fight.player, fight.enemy, "jab", {"damage": 7.0, "zone": "head_center", "counter": true, "blocked": false})
	stats.record_defense(fight.enemy, "block")
	stats.record_defense(fight.player, "slip")
	stats.record_knockdown(fight.player, fight.enemy)
	var total := stats.total_for(fight.player)
	_expect(total.punches_thrown == 2, "stats must count punches thrown")
	_expect(total.punches_landed == 1 and total.jab.landed == 1 and total.cross.thrown == 1, "stats must split punches by type")
	_expect(total.head_shots == 1 and total.counters == 1 and total.knockdowns == 1, "stats must track head shots, counters and knockdowns")
	_expect(total.accuracy == 0.5, "stats must calculate accuracy")
	_expect(stats.total_for(fight.enemy).blocks == 1 and total.slips == 1, "stats must track blocks and slips")


func _test_rounds_pause_combat_and_score_judges() -> void:
	fight.manager.state = FightManager.State.FIGHTING
	fight.player.fight_enabled = true
	fight.enemy.fight_enabled = true
	fight.manager.round_manager.configure(2, 0.1, 0.05)
	fight.manager.current_round = 1
	fight.manager.round_time = 0.0
	fight.manager.fight_stats.reset(fight.player, fight.enemy)
	fight.manager.fight_stats.record_punch_thrown(fight.player, "jab")
	fight.manager.fight_stats.record_punch_landed(fight.player, fight.enemy, "jab", {"damage": 8.0, "zone": "head_center", "counter": false, "blocked": false})
	fight.manager._end_round()
	_expect(not fight.player.fight_enabled and not fight.enemy.fight_enabled, "combat must be disabled during round break")
	_expect(fight.manager.judges.scorecards.size() == 3, "three judges must keep scorecards")
	_expect(fight.manager.judges.scorecards[0].rounds.size() >= 1, "judges must score completed rounds")


func _test_decision_types() -> void:
	var judges := Judges.new()
	var unanimous := judges.decide(fight.player, fight.enemy, [
		{"player": 30, "enemy": 27}, {"player": 29, "enemy": 28}, {"player": 30, "enemy": 27}
	])
	_expect(unanimous.method == "Unanimous Decision" and unanimous.winner == fight.player, "judges must produce unanimous decision")
	var split := judges.decide(fight.player, fight.enemy, [
		{"player": 29, "enemy": 28}, {"player": 28, "enemy": 29}, {"player": 29, "enemy": 28}
	])
	_expect(split.method == "Split Decision" and split.winner == fight.player, "judges must produce split decision")
	var majority_draw := judges.decide(fight.player, fight.enemy, [
		{"player": 28, "enemy": 28}, {"player": 29, "enemy": 28}, {"player": 28, "enemy": 29}
	])
	_expect(majority_draw.method == "Majority Draw" and majority_draw.winner == null, "judges must produce majority draw")
	var draw := judges.decide(fight.player, fight.enemy, [
		{"player": 28, "enemy": 28}, {"player": 29, "enemy": 29}, {"player": 30, "enemy": 30}
	])
	_expect(draw.method == "Draw" and draw.winner == null, "judges must produce draw")
	judges.free()


func _test_knockdown_count_ko_tko_rules() -> void:
	fight.manager.state = FightManager.State.FIGHTING
	fight.player.stats.stamina = 100.0
	fight.player.knockdowns = 0
	fight.manager._on_knockdown(fight.player)
	await create_timer(7.2).timeout
	_expect(fight.manager.state == FightManager.State.FIGHTING, "first knockdown with stamina must get up before ten")
	_expect(fight.referee.current_count >= 7, "referee must count knockdown")
	_expect(fight.player.fight_enabled and fight.enemy.fight_enabled, "combat must resume after get-up")
	fight.player.knockdowns = fight.manager.tko_knockdown_limit - 1
	fight.manager.state = FightManager.State.FIGHTING
	fight.manager._knockdown_in_progress = false
	fight.manager._on_knockdown(fight.player)
	await create_timer(1.8).timeout
	_expect(fight.manager.state == FightManager.State.FIGHT_END and fight.manager.result.method == "TKO", "configured knockdown limit must end by TKO")


func _test_quick_fight_reaches_result() -> void:
	SaveSystem.session = {"mode": "sparring", "rounds": 1, "round_duration": 0.12, "selected_player": "fighter_1", "selected_opponent": "fighter_2"}
	var quick := FIGHT_SCENE.new()
	get_root().add_child(quick)
	await process_frame
	await create_timer(2.1).timeout
	_expect(quick.manager.state == FightManager.State.FIGHT_END, "short Quick Fight must reach result screen")
	_expect(quick.manager.result.has("method") and quick.manager.result.has("scorecards") and quick.manager.result.has("stats"), "result must include method, scorecards and stats")
	quick.queue_free()
