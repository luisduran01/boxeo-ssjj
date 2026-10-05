class_name CombatRules
extends RefCounted

const MoveLibraryScript = preload("res://scripts/combat/move_library.gd")
const Balance = preload("res://scripts/combat/gameplay_balance.gd")

## Central tuning for the five real imported punch clips.
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
	var data: Dictionary = MoveLibraryScript.attack_data(StringName(attack_name))
	if data.is_empty() and ATTACKS.has(attack_name):
		data = ATTACKS[attack_name].duplicate(true)
	if data.is_empty():
		return {}
	data["active"] = data.active_time
	data["cost"] = data.stamina_cost
	data["zone"] = data.target_level
	return data

static func stamina_cost(attack_name: String, missed: bool) -> float:
	var data := attack_data(attack_name)
	return 0.0 if data.is_empty() else float(data.stamina_cost) * (float(data.get("whiff_stamina_mult", 1.5)) if missed else 1.0)


static func impact_quality_for_distance(attack_name: String, distance: float, active_elapsed: float = 0.0) -> float:
	var attack := attack_data(attack_name)
	if attack.is_empty():
		return 0.0
	var sweet_min := float(attack.get("sweet_spot_min", attack.min_range))
	var sweet_max := float(attack.get("sweet_spot_max", attack.range))
	var active_time := maxf(float(attack.get("active_time", 0.1)), 0.01)
	var frame_quality := 1.0 - clampf(active_elapsed / active_time, 0.0, 1.0) * 0.28
	if distance >= sweet_min and distance <= sweet_max:
		return 1.0 * frame_quality
	var nearest := clampf(distance, float(attack.min_range), float(attack.range))
	var span := maxf(float(attack.range) - float(attack.min_range), 0.01)
	return clampf(1.0 - absf(distance - nearest) / span - 0.35, 0.25, 0.72) * frame_quality

static func zone_group(zone: String) -> String:
	return "body" if zone.begins_with("body") else "head"

static func stamina_performance_scale(stamina: float, max_stamina := 100.0) -> float:
	var ratio := clampf(stamina / maxf(max_stamina, 0.01), 0.0, 1.0)
	if ratio >= 0.60:
		return 1.0
	if ratio >= 0.30:
		return lerpf(0.88, 1.0, (ratio - 0.30) / 0.30)
	if ratio >= 0.10:
		return lerpf(0.68, 0.88, (ratio - 0.10) / 0.20)
	return lerpf(0.55, 0.68, ratio / 0.10)

static func calculate_hit(attack_name: String, zone: String, attacker_stamina: float, defender_defense: float, blocked: bool, counter: bool, impact_quality := 1.0, momentum := 1.0, combo_index := 0) -> Dictionary:
	var attack := attack_data(attack_name)
	if attack.is_empty(): return {}
	var stamina_factor := lerpf(0.72, 1.0, clampf(attacker_stamina / 100.0, 0.0, 1.0))
	var counter_factor: float = float(attack.counter_bonus) if counter else 1.0
	var quality_factor := lerpf(0.62, 1.08, clampf(impact_quality, 0.0, 1.0))
	var target_group := zone_group(zone)
	var combo_scale := clampf(1.0 - float(maxi(combo_index, 0)) * 0.08, 0.72, 1.0)
	if attack.has("counter_mult") and counter:
		counter_factor = maxf(counter_factor, float(attack.counter_mult))
	var damage: float = float(attack.damage) * float(attack.power) * stamina_factor * (1.10 if target_group == "head" else 0.86) * counter_factor * quality_factor * clampf(momentum, 0.88, 1.08) * combo_scale * (0.25 if blocked else 1.0) * clampf(1.0 - defender_defense, 0.55, 1.0)
	var stun := float(attack.stun) * stamina_factor * counter_factor * quality_factor * combo_scale * (0.28 if blocked else 1.0)
	var stability_loss := float(attack.power) * float(attack.stun) * quality_factor * counter_factor * (1.0 if target_group == "head" else 0.34) * (0.18 if blocked else 1.0)
	return {"result":"BLOCKED" if blocked else ("COUNTER" if counter else ("CLEAN_HIT" if impact_quality >= 0.72 else "GLANCING")), "damage":damage, "stun":stun, "stamina_damage":float(attack.damage) * (0.72 if blocked else (0.58 if target_group == "body" else 0.16)), "counter_bonus":counter_factor, "blocked":blocked, "counter":counter, "is_counter_hit":counter, "impact_quality":impact_quality, "momentum":momentum, "target_group":target_group, "zone":zone, "combo_scale":combo_scale, "stability_loss":stability_loss, "severity":"HEAVY" if (counter or damage >= 14.0) else ("MEDIUM" if damage >= 8.0 else "LIGHT")}
