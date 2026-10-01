class_name FightManager
extends Node

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
var _knockdown_in_progress := false


func setup(p_player: BoxerController, p_enemy: BoxerController, p_hud: FightHUD, p_audio: BoxingAudio, p_referee: RefereeController = null) -> void:
	player = p_player
	enemy = p_enemy
	hud = p_hud
	audio = p_audio
	referee = p_referee
	total_rounds = int(SaveSystem.session.get("rounds", 3))
	round_duration = float(SaveSystem.session.get("round_duration", 120.0))
	round_time = round_duration
	player.knockdown_requested.connect(_on_knockdown)
	enemy.knockdown_requested.connect(_on_knockdown)
	await get_tree().create_timer(0.8).timeout
	_start_round()


func _process(delta: float) -> void:
	if state != State.FIGHTING:
		return
	round_time = maxf(0.0, round_time - delta)
	hud.set_clock(current_round, round_time)
	if round_time <= 0.0:
		_end_round()


func _start_round() -> void:
	state = State.READY
	player.reset_for_round(Vector3(0, 0, 1.9))
	enemy.reset_for_round(Vector3(0, 0, -1.9))
	hud.set_clock(current_round, round_time)
	hud.announce("ROUND %d" % current_round, 1.1)
	await get_tree().create_timer(1.15).timeout
	audio.play_cue("bell")
	hud.announce("FIGHT!", 0.8)
	player.fight_enabled = true
	enemy.fight_enabled = true
	state = State.FIGHTING


func _end_round() -> void:
	if state != State.FIGHTING:
		return
	state = State.ROUND_END
	player.fight_enabled = false
	enemy.fight_enabled = false
	audio.play_cue("bell")
	var score := ScoreRules.score_round(
		{"clean_hits": player.round_hits, "damage": player.round_damage, "knockdowns": player.round_knockdowns},
		{"clean_hits": enemy.round_hits, "damage": enemy.round_damage, "knockdowns": enemy.round_knockdowns})
	scores.append(score)
	hud.announce("FIN DEL ROUND", 2.2)
	if current_round >= total_rounds:
		await get_tree().create_timer(2.3).timeout
		_end_by_decision()
		return
	current_round += 1
	round_time = round_duration
	await get_tree().create_timer(3.2).timeout
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
	if is_instance_valid(referee):
		referee.begin_count(fighter, standing)
	standing.round_damage += 4.0
	audio.play_cue("ko")
	if FightRules.should_tko(fighter.knockdowns, tko_knockdown_limit):
		hud.announce("EL ÁRBITRO DETIENE LA PELEA", 1.4)
		await get_tree().create_timer(1.5).timeout
		_end_fight(standing, "TKO")
		return
	await get_tree().create_timer(0.55).timeout
	for count in range(1, 11):
		if is_instance_valid(referee):
			referee.count(count)
		hud.announce(str(count), 0.86)
		await get_tree().create_timer(0.9).timeout
		if count >= 7 and FightRules.can_get_up(fighter.knockdowns, fighter.stats.stamina, count):
			await fighter.recover_from_knockdown()
			standing.release_from_neutral()
			if is_instance_valid(referee):
				referee.resume_fight()
			hud.announce("BOX!", 0.7)
			hud.set_knockdown_mode(false)
			player.fight_enabled = true
			enemy.fight_enabled = true
			state = State.FIGHTING
			_knockdown_in_progress = false
			return
	_end_fight(standing, "KO")


func _end_by_decision() -> void:
	var player_total := 0
	var enemy_total := 0
	for score in scores:
		player_total += score.player
		enemy_total += score.enemy
	var winner := player if player_total >= enemy_total else enemy
	_end_fight(winner, "DECISIÓN %d-%d" % [player_total, enemy_total])


func _end_fight(winner: BoxerController, reason: String) -> void:
	state = State.FIGHT_END
	player.fight_enabled = false
	enemy.fight_enabled = false
	player.release_from_neutral()
	enemy.release_from_neutral()
	if is_instance_valid(referee):
		referee.finish_fight(reason)
	var elapsed := round_duration - round_time
	hud.show_result("WINNER\n%s\n%s\nROUND %d  TIME %d:%02d" % [winner.fighter_name.to_upper(), reason, current_round, int(elapsed) / 60, int(elapsed) % 60])
	if str(SaveSystem.session.get("mode", "quick")) != "sparring":
		SaveSystem.record_result(winner == player, reason in ["KO", "TKO"])
