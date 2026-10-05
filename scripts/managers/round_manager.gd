class_name RoundManager
extends Node

signal round_started(round_number: int)
signal round_ended(round_number: int)
signal break_started(next_round: int, seconds: float)
signal fight_time_expired
signal bell(round_number: int, opening: bool)

var total_rounds := 3
var round_duration := 180.0
var break_duration := 3.0
var current_round := 1
var round_time := 180.0
var in_break := false


func configure(rounds: int, duration: float, rest_seconds := 3.0) -> void:
	total_rounds = _normalize_rounds(rounds)
	round_duration = maxf(0.05, duration)
	break_duration = maxf(0.0, rest_seconds)
	current_round = 1
	round_time = round_duration
	in_break = false


func start_round(round_number: int = current_round) -> void:
	current_round = clampi(round_number, 1, total_rounds)
	round_time = round_duration
	in_break = false
	bell.emit(current_round, true)
	round_started.emit(current_round)


func tick(delta: float) -> bool:
	if in_break:
		return false
	round_time = maxf(0.0, round_time - delta)
	if round_time <= 0.0:
		round_ended.emit(current_round)
		if current_round >= total_rounds:
			fight_time_expired.emit()
		return true
	return false


func begin_break() -> void:
	in_break = true
	break_started.emit(current_round + 1, break_duration)


func advance_round() -> bool:
	if current_round >= total_rounds:
		return false
	current_round += 1
	round_time = round_duration
	in_break = false
	return true


static func _normalize_rounds(rounds: int) -> int:
	return rounds if rounds in [3, 4, 6, 8, 10, 12] else 3
