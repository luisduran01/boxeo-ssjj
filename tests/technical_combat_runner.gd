extends SceneTree

const PLAYER_SCENE := preload("res://fighters/boxer_02/boxer_02.tscn")
const RIVAL_SCENE := preload("res://fighters/boxer_green/boxer_green.tscn")

var failures := 0
var player
var rival


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("TECHNICAL COMBAT: " + message)


func _run() -> void:
	player = PLAYER_SCENE.instantiate()
	rival = RIVAL_SCENE.instantiate()
	root.add_child(player)
	root.add_child(rival)
	await process_frame
	player.is_player = true
	rival.is_player = false
	player.opponent = rival
	rival.opponent = player
	player.fight_enabled = true
	rival.fight_enabled = true
	_reset_pair()
	_test_public_technical_contract()
	_test_block_damage_guard_break_and_zones()
	_test_slip_duck_lean_evasion()
	_test_counter_window_and_damage_scaling()
	_test_stamina_fatigue_and_body_damage()
	_test_stun_wobble_knockdown_get_up()
	_test_defense_cancel_rules()
	player.queue_free()
	rival.queue_free()
	if failures == 0:
		print("TECHNICAL COMBAT TESTS PASSED")
		quit(0)
	else:
		push_error("TECHNICAL COMBAT TESTS FAILED: %d" % failures)
		quit(1)


func _reset_pair() -> void:
	player.global_position = Vector3(0.0, 0.0, 1.0)
	rival.global_position = Vector3(0.0, 0.0, 0.0)
	player.rotation = Vector3.ZERO
	rival.rotation = Vector3(0.0, PI, 0.0)
	for fighter in [player, rival]:
		fighter._finish_action()
		fighter.stats = CombatRules.fresh_stats()
		fighter.fight_enabled = true
		fighter.block_state = ""
		fighter.evasion_state = ""
		fighter.guard_stamina = fighter.max_guard_stamina
		fighter.stability = fighter.max_stability
		fighter.head_damage = 0.0
		fighter.body_damage = 0.0
		fighter.long_term_fatigue = 0.0
		fighter.counter_window = 0.0


func _test_public_technical_contract() -> void:
	for method_name in ["request_defense", "get_guard_ratio", "get_stability_ratio", "get_technical_combat_debug", "is_counter_hit"]:
		_expect(player.has_method(method_name), "fighter must expose " + method_name)
	for property_name in ["guard_stamina", "max_guard_stamina", "stability", "max_stability", "long_term_fatigue", "head_damage", "body_damage", "counter_window", "evasion_state"]:
		_expect(_has_property(player, property_name), "fighter must expose " + property_name)


func _test_block_damage_guard_break_and_zones() -> void:
	_reset_pair()
	var open_head: Dictionary = player.receive_hit("cross", "head_center", 100.0, false)
	_reset_pair()
	player.request_defense("high_block")
	var blocked_head: Dictionary = player.receive_hit("cross", "head_center", 100.0, false)
	_expect(bool(blocked_head.blocked), "high block must classify a head cross as blocked")
	_expect(float(blocked_head.damage) < float(open_head.damage) * 0.45, "blocked head shot must do much less damage")
	_expect(player.guard_stamina < player.max_guard_stamina, "blocked shots must drain guard stamina")
	_expect(player.animation_player.current_animation.contains("block"), "blocked shot must use a block reaction animation")
	player.guard_stamina = 3.0
	var guard_broken: Dictionary = player.receive_hit("right_hook", "head_left", 100.0, false)
	_expect(bool(guard_broken.guard_broken), "low guard stamina must trigger guard break")
	_expect(player.combat_state == "GUARD_BREAK", "guard break must enter a distinct state")
	_reset_pair()
	var before_body: float = player.body_damage
	player.receive_hit("uppercut", "body_right", 100.0, false)
	_expect(player.body_damage > before_body and player.head_damage == 0.0, "body shot must increase body damage without head damage")


func _test_slip_duck_lean_evasion() -> void:
	_reset_pair()
	player.request_defense("slip_left")
	var slipped: Dictionary = player.receive_hit("jab", "head_center", 100.0, false)
	_expect(str(slipped.result) == "EVADED", "slip must evade a straight head shot during its window")
	_expect(player.counter_window > 0.0, "successful slip must open counter window")
	var body_still_hits: Dictionary = player.receive_hit("cross", "body_center", 100.0, false)
	_expect(str(body_still_hits.result) != "EVADED", "slip must not evade body shots universally")
	_reset_pair()
	player.request_defense("duck")
	var ducked: Dictionary = player.receive_hit("jab", "head_center", 100.0, false)
	var hook_lands: Dictionary = player.receive_hit("left_hook", "head_left", 100.0, false)
	_expect(str(ducked.result) == "EVADED", "duck must avoid straight high shots")
	_expect(str(hook_lands.result) != "EVADED", "duck must remain vulnerable to hooks")
	_reset_pair()
	player.request_defense("lean_back")
	var leaned: Dictionary = player.receive_hit("cross", "head_center", 100.0, false)
	var body_risk: Dictionary = player.receive_hit("uppercut", "body_center", 100.0, false)
	_expect(str(leaned.result) == "EVADED", "lean back must help against straights")
	_expect(float(body_risk.damage) > 0.0 and str(body_risk.result) != "EVADED", "lean back must leave body risk")


func _test_counter_window_and_damage_scaling() -> void:
	_reset_pair()
	player.request_defense("slip_right")
	player.receive_hit("jab", "head_center", 100.0, false)
	var counter: bool = player.consume_counter_opportunity()
	_expect(counter, "counter opportunity must be consumable after a successful evasion")
	var normal := CombatRules.calculate_hit("cross", "head_center", 100.0, 0.12, false, false)
	var boosted := CombatRules.calculate_hit("cross", "head_center", 100.0, 0.12, false, true)
	_expect(float(boosted.damage) > float(normal.damage) and float(boosted.damage) < float(normal.damage) * 1.35, "counter bonus must be real but moderate")
	var scaled: Dictionary = Callable(CombatRules, "calculate_hit").callv(["right_hook", "head_center", 100.0, 0.12, false, false, 1.0, 1.0, 3])
	_expect(float(scaled.damage) < float(normal.damage) * 1.8, "rapid combo damage must scale down moderately")


func _test_stamina_fatigue_and_body_damage() -> void:
	_reset_pair()
	var full_speed: float = player._stamina_performance_scale()
	player.stats.stamina = 20.0
	var tired_speed: float = player._stamina_performance_scale()
	_expect(tired_speed < full_speed and tired_speed > 0.55, "low stamina must apply gradual performance penalties")
	player.stats.stamina = 80.0
	player.body_damage = 55.0
	player.long_term_fatigue = 24.0
	player._update_stamina(1.0)
	_expect(player.stats.stamina < 89.0, "body damage and fatigue must slow stamina recovery")
	var before_defense_stamina: float = player.stats.stamina
	player.request_defense("slip_left")
	_expect(player.stats.stamina < before_defense_stamina, "defensive movement must cost stamina")


func _test_stun_wobble_knockdown_get_up() -> void:
	_reset_pair()
	player.stats.stamina = 18.0
	player.head_damage = 60.0
	player.stability = 35.0
	var heavy: Dictionary = player.receive_hit("right_hook", "head_right", 100.0, true, 1.0, 1.05)
	_expect(float(heavy.stability_loss) > 0.0, "clean counter hook must reduce stability")
	_expect(player.combat_state in ["WOBBLED", "KNOCKDOWN"], "stability loss must lead to wobble before or into knockdown")
	if player.combat_state == "WOBBLED":
		player.stability = 8.0
		player.receive_hit("uppercut", "head_center", 100.0, true, 1.0, 1.05)
	_expect(player.combat_state == "KNOCKDOWN" and player._knocked_down, "stability exhaustion must trigger knockdown independent of HP")
	player.recover_from_knockdown()
	await create_timer(0.8).timeout
	_expect(not player._knocked_down and player.stats.stamina >= 20.0 and player.stability > 20.0, "get-up must restore partial stamina and stability")


func _test_defense_cancel_rules() -> void:
	_reset_pair()
	_expect(player.request_defense("body_block"), "body block must start from idle")
	player._finish_action()
	player.request_attack("right_hook")
	_expect(not player.request_defense("slip_left"), "heavy startup must not cancel instantly into defense")
	player._update_attack(float(CombatRules.attack_data("right_hook").startup) + float(CombatRules.attack_data("right_hook").active_time) + 0.02)
	_expect(not player.request_defense("duck"), "heavy active/recovery must keep defensive cancel consequence")
	player._finish_action()
	player.request_attack("jab")
	player._update_attack(float(CombatRules.attack_data("jab").startup) + float(CombatRules.attack_data("jab").active_time) + 0.08)
	_expect(player.request_defense("high_block"), "light attack late recovery may cancel to defense")


func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if str(property.name) == property_name:
			return true
	return false
