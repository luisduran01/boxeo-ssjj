class_name FightStats
extends Node

signal stats_updated(snapshot: Dictionary)

const PUNCH_TYPES := ["jab", "cross", "left_hook", "right_hook", "uppercut"]

var _fighters: Array[BoxerController] = []
var _totals: Dictionary = {}
var _rounds: Dictionary = {}


func reset(player: BoxerController, enemy: BoxerController) -> void:
	_fighters = [player, enemy]
	_totals.clear()
	_rounds.clear()
	for fighter in _fighters:
		_totals[fighter] = _blank_line()
		_rounds[fighter] = {}
	stats_updated.emit(snapshot())


func start_round(round_number: int) -> void:
	for fighter in _fighters:
		_rounds[fighter][round_number] = _blank_line()
	stats_updated.emit(snapshot())


func record_punch_thrown(fighter: BoxerController, attack_name: String) -> void:
	for line in _lines_for(fighter):
		line.punches_thrown += 1
		_ensure_punch(line, attack_name).thrown += 1
		_update_accuracy(line)
	stats_updated.emit(snapshot())


func record_punch_landed(attacker: BoxerController, defender: BoxerController, attack_name: String, result: Dictionary) -> void:
	if bool(result.get("blocked", false)):
		record_defense(defender, "block")
		return
	for line in _lines_for(attacker):
		line.punches_landed += 1
		_ensure_punch(line, attack_name).landed += 1
		if str(result.get("target_group", result.get("zone", ""))).contains("body"):
			line.body_shots += 1
		else:
			line.head_shots += 1
		if bool(result.get("counter", result.get("is_counter_hit", false))):
			line.counters += 1
		line.damage += float(result.get("damage", 0.0))
		_update_accuracy(line)
	stats_updated.emit(snapshot())


func record_defense(fighter: BoxerController, defense_type: String) -> void:
	for line in _lines_for(fighter):
		if defense_type == "slip":
			line.slips += 1
		else:
			line.blocks += 1
	stats_updated.emit(snapshot())


func record_knockdown(attacker: BoxerController, defender: BoxerController) -> void:
	for line in _lines_for(attacker):
		line.knockdowns += 1
	for line in _lines_for(defender):
		line.knocked_down += 1
	stats_updated.emit(snapshot())


func total_for(fighter: BoxerController) -> Dictionary:
	return _totals.get(fighter, _blank_line())


func round_for(fighter: BoxerController, round_number: int) -> Dictionary:
	return _rounds.get(fighter, {}).get(round_number, _blank_line())


func snapshot() -> Dictionary:
	var data := {"totals": {}, "rounds": {}}
	for fighter in _fighters:
		if not is_instance_valid(fighter):
			continue
		data.totals[fighter.fighter_name] = total_for(fighter).duplicate(true)
		var rounds := {}
		for round_number in _rounds.get(fighter, {}):
			rounds[round_number] = _rounds[fighter][round_number].duplicate(true)
		data.rounds[fighter.fighter_name] = rounds
	return data


func _lines_for(fighter: BoxerController) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if _totals.has(fighter):
		lines.append(_totals[fighter])
	var round_map: Dictionary = _rounds.get(fighter, {})
	if not round_map.is_empty():
		var keys := round_map.keys()
		keys.sort()
		lines.append(round_map[keys[-1]])
	return lines


func _blank_line() -> Dictionary:
	var line := {
		"punches_thrown": 0,
		"punches_landed": 0,
		"head_shots": 0,
		"body_shots": 0,
		"counters": 0,
		"blocks": 0,
		"slips": 0,
		"knockdowns": 0,
		"knocked_down": 0,
		"damage": 0.0,
		"accuracy": 0.0,
	}
	for attack_name in PUNCH_TYPES:
		line[attack_name] = {"thrown": 0, "landed": 0}
	line.hooks = {"thrown": 0, "landed": 0}
	return line


func _ensure_punch(line: Dictionary, attack_name: String) -> Dictionary:
	var key := attack_name
	if attack_name in ["left_hook", "right_hook"]:
		key = "hooks"
	if not line.has(key):
		line[key] = {"thrown": 0, "landed": 0}
	return line[key]


func _update_accuracy(line: Dictionary) -> void:
	line.accuracy = 0.0 if int(line.punches_thrown) <= 0 else float(line.punches_landed) / float(line.punches_thrown)
