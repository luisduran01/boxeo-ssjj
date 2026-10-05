class_name Judges
extends Node

signal round_scored(round_number: int, cards: Array)
signal decision_ready(result: Dictionary)

var scorecards: Array[Dictionary] = []


func _init() -> void:
	reset()


func reset() -> void:
	scorecards = []
	for index in range(3):
		scorecards.append({"name": "Judge %d" % (index + 1), "rounds": [], "player_total": 0, "enemy_total": 0})


func score_round(round_number: int, player_stats: Dictionary, enemy_stats: Dictionary) -> Array:
	var cards := []
	for index in range(scorecards.size()):
		var card := _score_for_judge(player_stats, enemy_stats, index)
		card.round = round_number
		scorecards[index].rounds.append(card)
		scorecards[index].player_total += int(card.player)
		scorecards[index].enemy_total += int(card.enemy)
		cards.append(card)
	round_scored.emit(round_number, cards)
	return cards


func decide(player: BoxerController, enemy: BoxerController, cards: Array = []) -> Dictionary:
	var source := cards if not cards.is_empty() else scorecards
	var player_votes := 0
	var enemy_votes := 0
	var draw_votes := 0
	var totals := []
	for card in source:
		var player_total := int(card.get("player_total", card.get("player", 0)))
		var enemy_total := int(card.get("enemy_total", card.get("enemy", 0)))
		totals.append({"player": player_total, "enemy": enemy_total})
		if player_total > enemy_total:
			player_votes += 1
		elif enemy_total > player_total:
			enemy_votes += 1
		else:
			draw_votes += 1
	var result := {"winner": null, "method": "Draw", "scorecards": totals, "player_votes": player_votes, "enemy_votes": enemy_votes, "draw_votes": draw_votes}
	if player_votes >= 2:
		result.winner = player
		if player_votes == 3:
			result.method = "Unanimous Decision"
		elif draw_votes > 0:
			result.method = "Majority Decision"
		else:
			result.method = "Split Decision"
	elif enemy_votes >= 2:
		result.winner = enemy
		if enemy_votes == 3:
			result.method = "Unanimous Decision"
		elif draw_votes > 0:
			result.method = "Majority Decision"
		else:
			result.method = "Split Decision"
	elif draw_votes == 3:
		result.method = "Draw"
	elif draw_votes > 0:
		result.method = "Majority Draw"
	decision_ready.emit(result)
	return result


func _score_for_judge(player_stats: Dictionary, enemy_stats: Dictionary, judge_index: int) -> Dictionary:
	var player_value := _round_value(player_stats, judge_index)
	var enemy_value := _round_value(enemy_stats, judge_index)
	if absf(player_value - enemy_value) < 0.45:
		return {"player": 10, "enemy": 10}
	var player_won := player_value > enemy_value
	var loser_penalty: int = maxi(1, int(player_stats.get("knocked_down", 0) if player_won else enemy_stats.get("knocked_down", 0)) + 1)
	return {"player": 10 if player_won else maxi(7, 10 - loser_penalty), "enemy": maxi(7, 10 - loser_penalty) if player_won else 10}


func _round_value(stats: Dictionary, judge_index: int) -> float:
	var clean := float(stats.get("punches_landed", stats.get("clean_hits", 0)))
	var damage := float(stats.get("damage", 0.0))
	var counters := float(stats.get("counters", 0))
	var defense := float(stats.get("blocks", 0)) * 0.18 + float(stats.get("slips", 0)) * 0.28
	var control := maxf(0.0, float(stats.get("punches_thrown", 0)) - float(stats.get("knocked_down", 0)) * 6.0) * 0.05
	var knockdowns := float(stats.get("knockdowns", 0)) * 4.5
	var preference: float = [1.0, 1.08, 0.94][judge_index]
	return clean * 0.9 * preference + damage * 0.55 + counters * 1.15 + defense + control + knockdowns
