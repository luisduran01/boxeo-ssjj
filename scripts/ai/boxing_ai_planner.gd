class_name BoxingAIPlanner
extends Node

var controller: BoxerController
var limbo_available := false
var _last_decision := "hold"
var _decision_index := 0

const REACTION_FRAMES := {
	"Rookie": 24,
	"Easy": 24,
	"Amateur": 18,
	"Medium": 18,
	"Pro": 12,
	"Hard": 12,
	"Elite": 9,
	"Legend": 6,
}
const DEFENSIVE_ERROR := {
	"Rookie": 0.25,
	"Easy": 0.25,
	"Amateur": 0.18,
	"Medium": 0.14,
	"Pro": 0.12,
	"Hard": 0.08,
	"Elite": 0.07,
	"Legend": 0.04,
}


func setup(p_controller: BoxerController) -> void:
	controller = p_controller
	_setup_limbo_bridge()


func _setup_limbo_bridge() -> void:
	if ClassDB.class_exists("BTPlayer"):
		var player := ClassDB.instantiate("BTPlayer") as Node
		if player != null:
			player.name = "BTPlayer"
			player.set("active", false)
			add_child(player)
			limbo_available = true


func last_decision() -> String:
	return _last_decision


func reaction_frames_for_difficulty() -> int:
	return int(REACTION_FRAMES.get(controller.difficulty if is_instance_valid(controller) else "Medium", 18))


func defensive_error_chance() -> float:
	return float(DEFENSIVE_ERROR.get(controller.difficulty if is_instance_valid(controller) else "Medium", 0.14))


func decide(delta: float) -> Vector2:
	if not is_instance_valid(controller) or controller.is_player:
		_last_decision = "hold"
		return Vector2.ZERO
	controller._update_range_state()
	var opponent := controller.opponent as BoxerController
	var distance := controller.get_distance_to_opponent()
	var stamina := float(controller.stats.stamina)
	var ring_pressure := maxf(absf(controller.global_position.x), absf(controller.global_position.z))
	if ring_pressure > controller.ring_limit - 0.12:
		_last_decision = "escape_ropes"
		controller.ai_state = "RING_ESCAPE"
		return controller._world_direction_to_input(-Vector3(controller.global_position.x, 0.0, controller.global_position.z).normalized())
	if stamina < 14.0:
		_last_decision = "recover_stamina"
		controller.ai_state = "RETREAT"
		return Vector2(controller._ai_lateral_direction * 0.25, -0.72)
	if is_instance_valid(opponent) and controller.difficulty == "Hard" and str(opponent.combat_state) in ["STARTUP", "RECOVERY"] and distance <= 1.65 and controller._ai_attack_cooldown <= 0.0:
		_last_decision = "counterattack"
		controller.ai_state = "COUNTER"
		controller.request_attack("jab" if distance > 1.25 else "cross")
		if controller._current_attack != "":
			controller._ai_attack_cooldown = controller._next_ai_attack_cooldown()
		return Vector2.ZERO
	if is_instance_valid(opponent) and str(opponent.combat_state) in ["STARTUP", "ACTIVE"] and distance <= 1.55:
		if controller.stats.stamina > 18.0 and controller.consume_counter_opportunity():
			_last_decision = "counterattack"
			controller.ai_state = "COUNTER"
			controller.request_attack("cross")
			return Vector2.ZERO
		_last_decision = "block"
		controller.ai_state = "DEFEND"
		controller.ai_block()
		return Vector2.ZERO
	if is_instance_valid(opponent) and str(opponent.combat_state) in ["STUNNED", "WOBBLED", "GUARD_BREAK"]:
		_last_decision = "pressure_hurt_rival"
		controller.ai_state = "PRESSURE"
		if distance > 1.12:
			return Vector2(0.0, 0.84)
		controller.request_attack("cross" if controller.stats.stamina > 24.0 else "jab")
		return Vector2.ZERO
	if distance > controller.long_range_distance:
		_last_decision = "advance"
		controller.ai_state = "APPROACH"
		return Vector2(controller._ai_lateral_direction * 0.18, 0.86)
	if distance < controller.too_close_distance + 0.14:
		_last_decision = "retreat"
		controller.ai_state = "RETREAT"
		return Vector2(controller._ai_lateral_direction * 0.38, -0.78)
	if distance <= 1.55 and controller.stats.stamina > 18.0:
		var slot := _decision_index % 4
		_decision_index += 1
		if controller._ai_attack_cooldown <= 0.0 and slot == 0:
			_last_decision = "attack"
			controller.ai_state = "ATTACK"
			controller.ai_attack()
		elif slot == 1:
			_last_decision = "defend"
			controller.ai_state = "DEFEND"
			controller.ai_block()
		elif slot == 2:
			_last_decision = "range_control"
			controller.ai_state = "RANGE_CONTROL"
			return Vector2(controller._ai_lateral_direction * 0.42, -0.22)
		else:
			_last_decision = "circle"
			controller.ai_state = "CIRCLE"
			return Vector2(controller._ai_lateral_direction * 0.62, 0.0)
		return Vector2.ZERO
	_last_decision = "circle"
	controller.ai_state = "CIRCLE"
	if randf() < 0.16:
		controller._ai_lateral_direction *= -1.0
	return Vector2(controller._ai_lateral_direction * 0.58, randf_range(-0.10, 0.16))
