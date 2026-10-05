extends Node

signal fight_started
signal round_started(round_number: int)
signal round_ended(round_number: int, cards: Array)
signal punch_thrown(attacker: Node, attack_name: String)
signal punch_landed(attacker: Node, defender: Node, result: Dictionary)
signal punch_blocked(attacker: Node, defender: Node, result: Dictionary)
signal punch_missed(attacker: Node, attack_name: String)
signal punch_slipped(attacker: Node, defender: Node, result: Dictionary)
signal guard_broken(attacker: Node, defender: Node, result: Dictionary)
signal stunned(fighter: Node, source: Node, result: Dictionary)
signal wobbled(fighter: Node, source: Node, result: Dictionary)
signal clinch_started(initiator: Node, receiver: Node)
signal clinch_ended(initiator: Node, receiver: Node, reason: String)
signal counter_hit(attacker: Node, defender: Node, result: Dictionary)
signal knockdown_started(fallen: Node, standing: Node)
signal fight_finished(result: Dictionary)
