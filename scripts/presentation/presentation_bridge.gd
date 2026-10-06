class_name PresentationBridge
extends RefCounted

const FighterViewScript := preload("res://scripts/presentation/fighter_view.gd")
const CombatEventViewScript := preload("res://scripts/presentation/combat_event_view.gd")

static func fighter_view(fighter: BoxerController, fighter_id := 0):
	return FighterViewScript.from_fighter(fighter, fighter_id)


static func combat_event(attacker: BoxerController, defender: BoxerController, result: Dictionary):
	return CombatEventViewScript.from_hit(attacker, defender, result)


static func sim_hash_is_stable_before_after(sim: RefCounted, callable: Callable) -> bool:
	var before := int(sim.call("snapshot_hash"))
	callable.call()
	var after := int(sim.call("snapshot_hash"))
	return before == after
