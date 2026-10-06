class_name FightManager
extends Node

const RoundManagerScript := preload("res://scripts/managers/round_manager.gd")
const FightStatsScript := preload("res://scripts/managers/fight_stats.gd")
const FightTelemetryScript := preload("res://scripts/managers/fight_telemetry.gd")
const JudgesScript := preload("res://scripts/managers/judges.gd")
const CombatPhasePlan := preload("res://scripts/managers/combat_phase_plan.gd")

signal fight_started
signal round_started(round_number: int)
signal round_ended(round_number: int, cards: Array)
signal knockdown_started(fallen: BoxerController, standing: BoxerController)
signal count_updated(count: int)
signal fight_finished(result: Dictionary)

enum State { INTRO, READY, FIGHTING, KNOCKDOWN, ROUND_END, FIGHT_END, PAUSED }

var state := State.INTRO
var total_rounds := 3
var round_duration := 120.0
var tko_knockdown_limit := 3
var current_round := 1
var round_time := 120.0
var player: BoxerController
var enemy: BoxerController
var hud: FightHUD
var audio: BoxingAudio
var referee: RefereeController
var scores: Array[Dictionary] = []
var result: Dictionary = {}
var round_manager: Node
var fight_stats: Node
var fight_telemetry: Node
var judges: Node
var _knockdown_in_progress := false


func setup(p_player: BoxerController, p_enemy: BoxerController, p_hud: FightHUD, p_audio: BoxingAudio, p_referee: RefereeController = null) -> void:
	player = p_player
	enemy = p_enemy
	hud = p_hud
	audio = p_audio
	referee = p_referee
	total_rounds = int(SaveSystem.session.get("rounds", SaveSystem.settings.get("rounds", 3)))
	round_duration = float(SaveSystem.session.get("round_duration", SaveSystem.settings.get("round_duration", 120.0)))
	round_manager = RoundManagerScript.new()
	round_manager.name = "RoundManager"
	add_child(round_manager)
	round_manager.configure(total_rounds, round_duration, 0.55)
	fight_stats = FightStatsScript.new()
	fight_stats.name = "FightStats"
	add_child(fight_stats)
	fight_stats.reset(player, enemy)
	fight_telemetry = FightTelemetryScript.new()
	fight_telemetry.name = "FightTelemetry"
	add_child(fight_telemetry)
	fight_telemetry.start_fight(CombatPhasePlan.telemetry_id_for_phase(1))
	judges = JudgesScript.new()
	judges.name = "Judges"
	add_child(judges)
	_connect_fighter(player)
	_connect_fighter(enemy)
	player.knockdown_requested.connect(_on_knockdown)
	enemy.knockdown_requested.connect(_on_knockdown)
	await get_tree().create_timer(0.25).timeout
	_start_round()


func _process(delta: float) -> void:
	if state != State.FIGHTING:
		return
	round_manager.tick(delta)
	round_time = round_manager.round_time
	hud.set_clock(current_round, round_time)
	if round_time <= 0.0:
		_end_round()


func _connect_fighter(fighter: BoxerController) -> void:
	if not fighter.punch_thrown.is_connected(_on_punch_thrown):
		fighter.punch_thrown.connect(_on_punch_thrown)
	if not fighter.punch_landed.is_connected(_on_punch_landed):
		fighter.punch_landed.connect(_on_punch_landed)
	if not fighter.defense_used.is_connected(_on_defense_used):
		fighter.defense_used.connect(_on_defense_used)


func _start_round() -> void:
	if state == State.FIGHT_END:
		return
	state = State.READY
	current_round = round_manager.current_round
	round_time = round_manager.round_time
	player.reset_for_round(Vector3(0, 0, 1.9))
	enemy.reset_for_round(Vector3(0, 0, -1.9))
	fight_stats.start_round(current_round)
	hud.set_clock(current_round, round_time)
	hud.announce("ROUND %d" % current_round, 0.35)
	await get_tree().create_timer(0.35).timeout
	if state == State.FIGHT_END:
		return
	round_manager.start_round(current_round)
	audio.play_cue("bell")
	hud.announce("FIGHT!", 0.35)
	player.fight_enabled = true
	enemy.fight_enabled = true
	state = State.FIGHTING
	fight_started.emit()
	_emit_event("fight_started")
	round_started.emit(current_round)
	_emit_event("round_started", [current_round])


func _end_round() -> void:
	if state != State.FIGHTING:
		return
	state = State.ROUND_END
	player.fight_enabled = false
	enemy.fight_enabled = false
	audio.play_cue("bell")
	var cards: Array = judges.score_round(current_round, fight_stats.round_for(player, current_round), fight_stats.round_for(enemy, current_round))
	var legacy_score: Dictionary = ScoreRules.score_round(fight_stats.round_for(player, current_round), fight_stats.round_for(enemy, current_round))
	scores.append(legacy_score)
	round_ended.emit(current_round, cards)
	_emit_event("round_ended", [current_round, cards])
	hud.announce("FIN DEL ROUND", 0.45)
	if current_round >= total_rounds:
		await get_tree().create_timer(0.35).timeout
		_end_by_decision()
		return
	round_manager.begin_break()
	_recover_between_rounds()
	await get_tree().create_timer(round_manager.break_duration).timeout
	if not round_manager.advance_round():
		_end_by_decision()
		return
	current_round = round_manager.current_round
	round_time = round_manager.round_time
	_start_round()


func _on_knockdown(fighter: BoxerController) -> void:
	if _knockdown_in_progress or state != State.FIGHTING:
		return
	_knockdown_in_progress = true
	state = State.KNOCKDOWN
	hud.set_knockdown_mode(true)
	player.fight_enabled = false
	enemy.fight_enabled = false
	fighter.begin_knockdown()
	var standing := enemy if fighter == player else player
	standing.move_to_neutral(fighter.global_position)
	fight_stats.record_knockdown(standing, fighter)
	knockdown_started.emit(fighter, standing)
	_emit_event("knockdown_started", [fighter, standing])
	if is_instance_valid(referee):
		referee.begin_count(fighter, standing)
	audio.play_cue("ko")
	if FightRules.should_tko(fighter.knockdowns, tko_knockdown_limit):
		hud.announce("EL ÁRBITRO DETIENE LA PELEA", 0.55)
		await get_tree().create_timer(0.55).timeout
		_end_fight(standing, "TKO")
		return
	await get_tree().create_timer(0.25).timeout
	for count in range(1, 11):
		if is_instance_valid(referee):
			referee.count(count)
		count_updated.emit(count)
		hud.announce(str(count), 0.42)
		await get_tree().create_timer(0.36).timeout
		if count >= 7 and FightRules.can_get_up(fighter.knockdowns, fighter.stats.stamina, count):
			await fighter.recover_from_knockdown()
			standing.release_from_neutral()
			if is_instance_valid(referee):
				referee.resume_fight()
			hud.announce("BOX!", 0.35)
			hud.set_knockdown_mode(false)
			player.fight_enabled = true
			enemy.fight_enabled = true
			state = State.FIGHTING
			_knockdown_in_progress = false
			return
	_end_fight(standing, "KO")


func _end_by_decision() -> void:
	var decision: Dictionary = judges.decide(player, enemy)
	if decision.winner == null:
		_end_fight(null, "DECISIÓN Draw", decision)
		return
	_end_fight(decision.winner, "DECISIÓN " + str(decision.method), decision)


func _end_fight(winner: BoxerController, method: String, decision: Dictionary = {}) -> void:
	if state == State.FIGHT_END and not result.is_empty():
		Engine.time_scale = 1.0
		_knockdown_in_progress = false
		return
	Engine.time_scale = 1.0
	_knockdown_in_progress = false
	state = State.FIGHT_END
	player.fight_enabled = false
	enemy.fight_enabled = false
	player.release_from_neutral()
	enemy.release_from_neutral()
	if is_instance_valid(referee):
		referee.finish_fight(method)
	var elapsed := round_duration - round_time
	result = {
		"winner": winner,
		"winner_name": winner.fighter_name if winner != null else "DRAW",
		"method": method,
		"round": current_round,
		"time": elapsed,
		"scorecards": judges.scorecards,
		"stats": fight_stats.snapshot(),
	}
	if not decision.is_empty():
		result.decision = decision
	var result_text := _format_result(result)
	result["presentation_text"] = result_text
	hud.show_result(result_text)
	fight_finished.emit(result)
	_emit_event("fight_finished", [result])
	if str(SaveSystem.session.get("mode", "quick")) != "sparring" and winner != null:
		SaveSystem.record_result(winner == player, method in ["KO", "TKO"])


func _on_punch_thrown(fighter: BoxerController, attack_name: String) -> void:
	if state != State.FIGHTING:
		return
	fight_stats.record_punch_thrown(fighter, attack_name)
	_emit_event("punch_thrown", [fighter, attack_name])


func _on_punch_landed(attacker: BoxerController, defender: BoxerController, hit: Dictionary) -> void:
	if state != State.FIGHTING:
		return
	fight_stats.record_punch_landed(attacker, defender, attacker._current_attack, hit)
	var event_hit := hit.duplicate(true)
	event_hit["attack_name"] = attacker._current_attack
	_emit_event("punch_landed", [attacker, defender, event_hit])
	if bool(event_hit.get("blocked", false)):
		_emit_event("punch_blocked", [attacker, defender, event_hit])
	if bool(event_hit.get("guard_broken", false)):
		_emit_event("guard_broken", [attacker, defender, event_hit])
	if bool(event_hit.get("is_counter_hit", event_hit.get("counter", false))):
		_emit_event("counter_hit", [attacker, defender, event_hit])


func _emit_event(signal_name: StringName, args: Array = []) -> void:
	var events := get_node_or_null("/root/Events")
	if events != null and events.has_signal(signal_name):
		events.emit_signal.callv([signal_name] + args)


func _on_defense_used(fighter: BoxerController, defense_name: String) -> void:
	if state != State.FIGHTING:
		return
	fight_stats.record_defense(fighter, defense_name)


func _recover_between_rounds() -> void:
	for fighter in [player, enemy]:
		fighter.stats.stamina = minf(fighter.stats.max_stamina, fighter.stats.stamina + 22.0)
		fighter.stats.stun = maxf(0.0, fighter.stats.stun - 45.0)
		fighter.guard_stamina = fighter.max_guard_stamina
		fighter.stats_changed.emit(fighter)


func _format_result(data: Dictionary) -> String:
	var elapsed := int(data.time)
	var winner_name := str(data.winner_name).to_upper()
	var method := str(data.method)
	var lines := ["WINNER", winner_name, method, "ROUND %d  TIME %d:%02d" % [int(data.round), elapsed / 60, elapsed % 60]]
	if method.contains("DECISIÓN") or method == "Draw":
		lines.append(_format_scorecards())
	lines.append(_format_stats_summary())
	return "\n".join(lines)


func _format_scorecards() -> String:
	var parts: Array[String] = []
	for card in judges.scorecards:
		parts.append("%d-%d" % [int(card.player_total), int(card.enemy_total)])
	return "JUDGES  " + " / ".join(parts)


func _format_stats_summary() -> String:
	var player_total: Dictionary = fight_stats.total_for(player)
	var enemy_total: Dictionary = fight_stats.total_for(enemy)
	return "STATS  %s %d/%d %.0f%%  %s %d/%d %.0f%%" % [
		player.fighter_name,
		int(player_total.punches_landed),
		int(player_total.punches_thrown),
		float(player_total.accuracy) * 100.0,
		enemy.fighter_name,
		int(enemy_total.punches_landed),
		int(enemy_total.punches_thrown),
		float(enemy_total.accuracy) * 100.0,
	]
