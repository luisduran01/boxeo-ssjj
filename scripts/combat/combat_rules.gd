class_name CombatRules
extends RefCounted

## Central tuning for the four real imported punch clips. Cross stays reserved.
const ATTACKS := {
	"jab": {"attack_name":"jab", "animation_name":"jab", "hand":"left", "attack_type":"straight", "target_level":"head", "startup":0.12, "active_time":0.09, "recovery":0.23, "damage":6.5, "stamina_cost":5.5, "min_range":0.72, "range":1.58, "power":0.82, "stun":5.5, "counter_bonus":1.18, "movement_allowed":0.78, "tracking_strength":0.72, "step_in":0.16, "hit_stop":0.014, "camera_feedback":0.002, "animation_speed":1.04, "cancel_window":0.11},
	"cross": {"attack_name":"cross", "animation_name":"cross", "hand":"right", "attack_type":"straight", "target_level":"head", "startup":0.16, "active_time":0.09, "recovery":0.28, "damage":8.8, "stamina_cost":7.4, "min_range":0.68, "range":1.52, "power":0.96, "stun":8.0, "counter_bonus":1.20, "movement_allowed":0.65, "tracking_strength":0.62, "step_in":0.12, "hit_stop":0.019, "camera_feedback":0.004, "animation_speed":1.03, "cancel_window":0.12},
	"left_hook": {"attack_name":"left_hook", "animation_name":"left_hook", "hand":"left", "attack_type":"hook", "target_level":"head", "startup":0.19, "active_time":0.10, "recovery":0.33, "damage":10.5, "stamina_cost":9.5, "min_range":0.58, "range":1.30, "power":1.10, "stun":11.5, "counter_bonus":1.22, "movement_allowed":0.48, "tracking_strength":0.48, "step_in":0.05, "hit_stop":0.026, "camera_feedback":0.007, "animation_speed":1.0, "cancel_window":0.13},
	"right_hook": {"attack_name":"right_hook", "animation_name":"right_hook", "hand":"right", "attack_type":"hook", "target_level":"head", "startup":0.22, "active_time":0.11, "recovery":0.37, "damage":12.5, "stamina_cost":11.5, "min_range":0.60, "range":1.34, "power":1.22, "stun":13.5, "counter_bonus":1.24, "movement_allowed":0.42, "tracking_strength":0.44, "step_in":0.04, "hit_stop":0.031, "camera_feedback":0.009, "animation_speed":1.01, "cancel_window":0.14},
	"uppercut": {"attack_name":"uppercut", "animation_name":"uppercut", "hand":"right", "attack_type":"uppercut", "target_level":"head", "startup":0.24, "active_time":0.11, "recovery":0.43, "damage":14.5, "stamina_cost":14.0, "min_range":0.48, "range":1.12, "power":1.42, "stun":18.0, "counter_bonus":1.28, "movement_allowed":0.27, "tracking_strength":0.34, "step_in":0.02, "hit_stop":0.040, "camera_feedback":0.013, "animation_speed":1.02, "cancel_window":0.15},
}

static func fresh_stats() -> Dictionary:
	return {"max_health":100.0, "health":100.0, "max_stamina":100.0, "stamina":100.0, "head_health":100.0, "body_health":100.0, "stun":0.0, "max_stun":100.0, "damage_multiplier":1.0, "defense":0.12, "movement_speed":2.15, "punch_speed":1.0, "recovery":1.0}

static func attack_data(attack_name: String) -> Dictionary:
	if not ATTACKS.has(attack_name): return {}
	var data: Dictionary = ATTACKS[attack_name].duplicate(true)
	data["active"] = data.active_time
	data["cost"] = data.stamina_cost
	data["zone"] = data.target_level
	return data

static func stamina_cost(attack_name: String, missed: bool) -> float:
	var data := attack_data(attack_name)
	return 0.0 if data.is_empty() else float(data.stamina_cost) * (1.12 if missed else 1.0)

static func calculate_hit(attack_name: String, zone: String, attacker_stamina: float, defender_defense: float, blocked: bool, counter: bool, impact_quality := 1.0, momentum := 1.0) -> Dictionary:
	var attack := attack_data(attack_name)
	if attack.is_empty(): return {}
	var stamina_factor := lerpf(0.72, 1.0, clampf(attacker_stamina / 100.0, 0.0, 1.0))
	var counter_factor: float = float(attack.counter_bonus) if counter else 1.0
	var quality_factor := lerpf(0.62, 1.08, clampf(impact_quality, 0.0, 1.0))
	var damage: float = float(attack.damage) * float(attack.power) * stamina_factor * (1.10 if zone == "head" else 0.86) * counter_factor * quality_factor * clampf(momentum, 0.88, 1.08) * (0.25 if blocked else 1.0) * clampf(1.0 - defender_defense, 0.55, 1.0)
	return {"result":"BLOCKED" if blocked else ("COUNTER" if counter else ("CLEAN_HIT" if impact_quality >= 0.72 else "GLANCING")), "damage":damage, "stun":float(attack.stun) * stamina_factor * counter_factor * quality_factor * (0.28 if blocked else 1.0), "stamina_damage":float(attack.damage) * (0.72 if blocked else (0.58 if zone == "body" else 0.16)), "counter_bonus":counter_factor, "blocked":blocked, "counter":counter, "impact_quality":impact_quality, "momentum":momentum, "severity":"HEAVY" if (counter or damage >= 14.0) else ("MEDIUM" if damage >= 8.0 else "LIGHT")}
