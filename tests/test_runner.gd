extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_combat_rules()
	_test_score_rules()
	_test_fight_state()
	if failures == 0:
		print("TESTS PASSED")
		quit(0)
	else:
		push_error("TESTS FAILED: %d" % failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _test_combat_rules() -> void:
	var script := load("res://scripts/combat/combat_rules.gd")
	_expect(script != null, "combat_rules.gd must exist")
	if script == null:
		return
	var fresh: Dictionary = script.fresh_stats()
	_expect(fresh.health == 100.0 and fresh.stamina == 100.0, "fresh fighter stats must be full")
	var clean_head: Dictionary = script.calculate_hit("right_hook", "head", 100.0, 0.0, false, true)
	var guarded: Dictionary = script.calculate_hit("right_hook", "head", 100.0, 0.0, true, false)
	_expect(clean_head.damage > guarded.damage, "blocking must reduce damage")
	_expect(clean_head.stun > guarded.stun, "blocking must reduce stun")
	_expect(clean_head.counter_bonus > 1.0, "counter punch must receive a moderate bonus")
	_expect(script.stamina_cost("uppercut", false) > script.stamina_cost("jab", false), "uppercut must cost more stamina than jab")


func _test_score_rules() -> void:
	var script := load("res://scripts/managers/score_rules.gd")
	_expect(script != null, "score_rules.gd must exist")
	if script == null:
		return
	var close_round: Dictionary = script.score_round({"clean_hits": 12, "damage": 19.0, "knockdowns": 0}, {"clean_hits": 10, "damage": 16.0, "knockdowns": 0})
	_expect(close_round.player == 10 and close_round.enemy == 9, "round winner must receive 10-9")
	var knockdown_round: Dictionary = script.score_round({"clean_hits": 14, "damage": 25.0, "knockdowns": 1}, {"clean_hits": 8, "damage": 12.0, "knockdowns": 0})
	_expect(knockdown_round.player == 10 and knockdown_round.enemy == 8, "a dominant knockdown round must score 10-8")


func _test_fight_state() -> void:
	var script := load("res://scripts/managers/fight_rules.gd")
	_expect(script != null, "fight_rules.gd must exist")
	if script == null:
		return
	_expect(script.should_knockdown(0.0, 45.0, 20.0, 18.0), "zero health must trigger knockdown")
	_expect(script.should_knockdown(75.0, 0.0, 20.0, 18.0), "zero head health must trigger knockdown")
	_expect(script.can_get_up(1, 72.0, 7), "first knockdown with stamina must allow get up")
	_expect(not script.can_get_up(3, 12.0, 9), "third knockdown with low stamina must be a KO")
	_expect(script.has_method("should_tko"), "fight rules must expose a configurable TKO rule")
	if script.has_method("should_tko"):
		_expect(script.should_tko(3, 3), "configured knockdown limit must trigger TKO")
