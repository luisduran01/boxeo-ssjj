extends SceneTree

const HITBOX_QUERY := preload("res://scripts/combat/hitbox_query.gd")
var fight
var failures := 0
var positive := ["jab", "cross", "right_hook", "uppercut"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	SaveSystem.session = {"mode":"sparring", "rounds":3, "round_duration":120.0, "selected_player":"fighter_1", "selected_opponent":"fighter_2"}
	change_scene_to_file("res://fight/fight.tscn")
	await process_frame
	await process_frame
	fight = current_scene
	# Wait for FightManager's real READY -> FIGHTING transition before requesting attacks.
	while not is_instance_valid(fight.manager) or fight.manager.state != FightManager.State.FIGHTING or not fight.player.fight_enabled:
		await process_frame
	# Keep the real SceneTree physics loop enabled. The controller owns one update per tick.
	fight.player.opponent = fight.enemy
	fight.enemy.opponent = fight.player
	# FightManager owns fight_enabled; do not force it in the runner.
	await _test_positive_attacks()
	await _test_negative_attacks()
	await _test_defenses()
	if failures == 0:
		print("ACTIVE SWEEP TESTS PASSED")
		quit(0)
	else:
		push_error("ACTIVE SWEEP TESTS FAILED: %d" % failures)
		quit(1)

func _test_positive_attacks() -> void:
	for attack in positive:
		var result := await _run_attack(attack, false, "head_center")
		print("POSITIVE attack=%s physical=%s hits=%d instance=%d active_tick=%d prev=%s cur=%s" % [attack, result.physical, result.hits.size(), result.instance, result.tick, result.prev, result.cur])
		if result.hits.is_empty(): failures += 1
	var body := await _run_attack("uppercut", false, "body_center")
	print("POSITIVE attack=body_uppercut physical=%s hits=%d zones=%s" % [body.physical, body.hits.size(), body.hits.map(func(h): return h.zone)])
	if body.hits.is_empty(): failures += 1

func _test_negative_attacks() -> void:
	for attack in ["jab", "cross", "right_hook", "uppercut", "left_hook"]:
		var result := await _run_attack(attack, true, "head_center")
		print("NEGATIVE attack=%s physical=%s hits=%d distance=%.3f" % [attack, result.physical, result.hits.size(), result.distance])
		if not result.hits.is_empty(): failures += 1

func _test_defenses() -> void:
	for item in [["jab","slip_left"],["jab","slip_right"],["cross","slip_left"],["cross","slip_right"],["right_hook","duck"],["jab","high_block"],["cross","high_block"],["right_hook","high_block"],["uppercut","body_block"]]:
		var result := await _run_attack(item[0], false, "body_center" if item[1] == "body_block" else "head_center", item[1])
		print("DEFENSE attack=%s defense=%s physical_hits=%d logical=%s zones=%s" % [item[0],item[1],result.hits.size(),result.logical,result.hits.map(func(h): return h.zone)])

func _run_attack(attack: String, out_of_range: bool, zone: String, defense := "") -> Dictionary:
	fight.player.global_position = Vector3(0,0,0)
	var lateral := -0.35 if attack in ["cross", "right_hook", "uppercut"] else 0.30
	fight.enemy.global_position = Vector3(lateral,0,3.2 if out_of_range else 0.15)
	fight.player.rotation = Vector3.ZERO
	fight.enemy.rotation = Vector3(0,PI,0)
	_reset(fight.player); _reset(fight.enemy)
	if defense != "": fight.enemy.request_defense(defense)
	fight.player.request_attack(attack)
	var previous: Vector3 = _fist(fight.player, attack)
	var active_seen := false
	var active_tick := -1
	var instance := int(fight.player._attack_instance_id)
	var hits: Array[Dictionary] = []
	var current := previous
	for tick in range(80):
		await physics_frame
		current = _fist(fight.player, attack)
		if fight.player.combat_state == "ACTIVE":
			active_seen = true; active_tick = tick
			var query := HITBOX_QUERY.new()
			hits = query.query_fighter(fight.enemy, previous, current, 0.16, 5)
			if tick == active_tick: print("CONTACT_DEBUG attack=%s hurtboxes=%s" % [attack, query.hurtboxes])
			if not hits.is_empty(): break
		previous = current
		if active_seen and fight.player.combat_state != "ACTIVE": break
	var logical: Dictionary = fight.enemy.receive_hit(attack, zone, 100.0, false) if active_seen else {"result":"NO_ACTIVE"}
	return {"hits":hits,"physical":not hits.is_empty(),"logical":logical.get("result",""),"instance":instance,"tick":active_tick,"prev":previous,"cur":current,"distance":fight.player.global_position.distance_to(fight.enemy.global_position)}

func _fist(fighter, attack: String) -> Vector3:
	var hand := "right" if attack in ["cross","right_hook","uppercut"] else "left"
	var node = fighter.right_fist if hand == "right" else fighter.left_fist
	return node.global_position

func _reset(fighter) -> void:
	fighter._finish_action(); fighter.stats=CombatRules.fresh_stats(); fighter.block_state=""; fighter.evasion_state=""; fighter.guard_stamina=fighter.max_guard_stamina; fighter.stability=fighter.max_stability
