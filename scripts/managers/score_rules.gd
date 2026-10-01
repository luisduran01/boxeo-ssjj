class_name ScoreRules
extends RefCounted


static func score_round(player: Dictionary, enemy: Dictionary) -> Dictionary:
	var player_value := float(player.get("damage", 0.0)) + float(player.get("clean_hits", 0)) * 0.7 + float(player.get("knockdowns", 0)) * 12.0
	var enemy_value := float(enemy.get("damage", 0.0)) + float(enemy.get("clean_hits", 0)) * 0.7 + float(enemy.get("knockdowns", 0)) * 12.0
	if is_equal_approx(player_value, enemy_value):
		return {"player": 10, "enemy": 10}
	var player_won := player_value > enemy_value
	var winner_knockdowns := int(player.get("knockdowns", 0) if player_won else enemy.get("knockdowns", 0))
	return {"player": 10 if player_won else (8 if winner_knockdowns > 0 else 9), "enemy": (8 if winner_knockdowns > 0 else 9) if player_won else 10}
