class_name CombatEventView
extends RefCounted

var tick := 0
var kind := "HIT"
var attacker := 0
var defender := 0
var move_id := &""
var zone := "head"
var clean := false
var counter := false
var blocked := false
var power_norm := 0.0
var hit_point := Vector3.ZERO
var punch_dir := Vector3.FORWARD


static func from_hit(attacker_node: BoxerController, defender_node: BoxerController, result: Dictionary):
	var event = load("res://scripts/presentation/combat_event_view.gd").new()
	event.kind = "BLOCK" if bool(result.get("blocked", false)) else "HIT"
	event.attacker = attacker_node.get_instance_id()
	event.defender = defender_node.get_instance_id()
	event.move_id = StringName(str(result.get("attack_name", attacker_node._current_attack)))
	event.zone = str(result.get("zone", result.get("target_group", "head")))
	event.clean = str(result.get("result", "")) in ["CLEAN_HIT", "COUNTER"]
	event.counter = bool(result.get("counter", false))
	event.blocked = bool(result.get("blocked", false))
	event.power_norm = clampf(float(result.get("damage", 0.0)) / 18.0, 0.0, 1.0)
	event.hit_point = defender_node.global_position + Vector3(0.0, defender_node.body_height * 0.9, 0.0)
	var dir := defender_node.global_position - attacker_node.global_position
	dir.y = 0.0
	event.punch_dir = dir.normalized() if dir.length_squared() > 0.0001 else -attacker_node.global_basis.z
	return event
